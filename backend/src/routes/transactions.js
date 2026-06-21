// src/routes/transactions.js
// POST /api/transactions  — create a sale transaction
// GET  /api/transactions  — list transactions (paginated)
// GET  /api/transactions/:id — get single transaction

const express = require('express');
const router  = express.Router();
const { body, query, validationResult } = require('express-validator');
const db = require('../config/db');
const { asyncHandler } = require('../middleware/errorHandler');

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────

const VALID_UOM  = ['%', 'Gross', 'KG', 'Pcs', 'Bag', 'Box'];
const VALID_MODE = ['cash', 'online', 'credit-slip', 'gst-cash', 'gst-bank', 'gst-credit'];

// ─────────────────────────────────────────────
// Validation rules
// ─────────────────────────────────────────────

const transactionValidationRules = [
  body('party').trim().notEmpty().withMessage('party is required'),
  body('date').trim().notEmpty().withMessage('date is required'),
  body('mode').isIn(VALID_MODE).withMessage(`mode must be one of: ${VALID_MODE.join(', ')}`),
  body('items').isArray({ min: 1 }).withMessage('items array must not be empty'),
  body('items.*.item_name').trim().notEmpty(),
  body('items.*.thread').trim().notEmpty(),
  body('items.*.length').trim().notEmpty(),
  body('items.*.head').trim().notEmpty(),
  body('items.*.colour').trim().notEmpty(),
  body('items.*.quantity').isFloat({ min: 0.01 }),
  body('items.*.uom').isIn(VALID_UOM),
  body('items.*.rate').isFloat({ min: 0 }),
  body('receipt').optional({ nullable: true }).isNumeric(),
  body('grand_total').isNumeric(),
  body('remaining').isNumeric(),
  body('location').optional({ nullable: true }).trim(),
];

// ─────────────────────────────────────────────
// POST /api/transactions
// ─────────────────────────────────────────────

router.post(
  '/',
  transactionValidationRules,
  asyncHandler(async (req, res) => {
    // 1. Validate input
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({
        success: false,
        error: 'Validation failed',
        details: errors.array(),
      });
    }

    const {
      party, date, mode, location = null,
      items, receipt = 0, grand_total, remaining
    } = req.body;

    const client = await db.connect();

    try {
      await client.query('BEGIN');

      // 2. Fetch the max transaction_id and add 1
      const maxTxResult = await client.query('SELECT COALESCE(MAX(transaction_id), 0) + 1 AS next_id FROM sale_transaction');
      const transactionId = parseInt(maxTxResult.rows[0].next_id, 10);

      // 3. Insert each item
      for (const item of items) {
        // Resolve item_id from item_master
        const itemLookup = await client.query(
          `SELECT item_id FROM item_master
           WHERE TRIM(LOWER(name)) = TRIM(LOWER($1))
             AND TRIM(LOWER(thread)) = TRIM(LOWER($2))
             AND length::text = $3::text
             AND TRIM(LOWER(head)) = TRIM(LOWER($4))
             AND TRIM(LOWER(colour)) = TRIM(LOWER($5))
           LIMIT 1`,
          [item.item_name, item.thread, item.length, item.head, item.colour]
        );

        if (itemLookup.rowCount === 0) {
          throw new Error(`No matching item found for: ${item.item_name} ${item.thread} ${item.length} ${item.head} ${item.colour}`);
        }

        const itemId = itemLookup.rows[0].item_id;
        const qty    = parseFloat(item.quantity);
        const rateVal= parseFloat(item.rate);
        const amount = parseFloat((qty * rateVal).toFixed(2));

        // Insert into sale_transaction using lowercase table and columns
        // Assuming reciept was text but user wants us to ignore modifying the DB, we just pass the raw receipt if it was text.
        // Wait, the user said "convert to real number" so they probably made it numeric or expect it. We will cast to string or number safely.
        await client.query(
          `INSERT INTO sale_transaction
             (transaction_id, date, party, item_id, quantity, uom, rate, mode, amount, reciept, location)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
          [transactionId, date, party, itemId, qty, item.uom, rateVal, mode, amount, receipt.toString(), location]
        );
      }

      // 4. Insert into transaction_treasury
      const due = parseFloat(remaining) > 0;
      await client.query(
        `INSERT INTO transaction_treasury (transaction_id, amount, due, iteration, due_amount)
         VALUES ($1, $2, $3, $4, $5)`,
        [transactionId, parseFloat(grand_total), due, 1, parseFloat(remaining)]
      );

      await client.query('COMMIT');
      res.status(201).json({ success: true, data: { transaction_id: transactionId } });

    } catch (e) {
      await client.query('ROLLBACK');
      res.status(500).json({ success: false, error: e.message });
    } finally {
      client.release();
    }
  })
);

// ─────────────────────────────────────────────
// GET /api/transactions?page=1&limit=20
// ─────────────────────────────────────────────

router.get(
  '/',
  [
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  ],
  asyncHandler(async (req, res) => {
    const page   = req.query.page  || 1;
    const limit  = req.query.limit || 20;
    const offset = (page - 1) * limit;

    const [dataResult, countResult] = await Promise.all([
      db.query(
        `SELECT
           st.id, st.date, st.party, st.item_id, st.quantity,
           st.uom, st.rate, st.mode, st.amount, st.reciept, st.location,
           im.name AS item_name, im.thread, im.length, im.head, im.colour
         FROM sale_transaction st
         LEFT JOIN item_master im ON st.item_id = im.item_id
         ORDER BY st.id DESC
         LIMIT $1 OFFSET $2`,
        [limit, offset]
      ),
      db.query('SELECT COUNT(*) FROM sale_transaction'),
    ]);

    const total = parseInt(countResult.rows[0].count, 10);

    res.json({
      success: true,
      data: dataResult.rows,
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    });
  })
);

// ─────────────────────────────────────────────
// GET /api/transactions/:id
// ─────────────────────────────────────────────

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const result = await db.query(
      `SELECT
         st.*, im.name AS item_name, im.thread, im.length, im.head, im.colour
       FROM sale_transaction st
       LEFT JOIN item_master im ON st.item_id = im.item_id
       WHERE st.id = $1`,
      [req.params.id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ success: false, error: 'Transaction not found' });
    }

    res.json({ success: true, data: result.rows[0] });
  })
);

module.exports = router;
