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

const VALID_UOM  = ['5', 'Gross', 'KH', 'Pcs', 'Box'];
const VALID_MODE = ['cash', 'online', 'credit-slip', 'gst-cash', 'gst-bank', 'gst-credit'];

// ─────────────────────────────────────────────
// Validation rules
// ─────────────────────────────────────────────

const transactionValidationRules = [
  body('item_name').trim().notEmpty().withMessage('item_name is required'),
  body('thread').trim().notEmpty().withMessage('thread is required'),
  body('length').trim().notEmpty().withMessage('length is required'),
  body('head').trim().notEmpty().withMessage('head is required'),
  body('colour').trim().notEmpty().withMessage('colour is required'),
  body('party').trim().notEmpty().withMessage('party (customer alias) is required'),
  body('date').trim().notEmpty().withMessage('date is required'),
  body('quantity').isFloat({ min: 0.01 }).withMessage('quantity must be a positive number'),
  body('uom').isIn(VALID_UOM).withMessage(`uom must be one of: ${VALID_UOM.join(', ')}`),
  body('rate').isFloat({ min: 0 }).withMessage('rate must be a non-negative number'),
  body('mode').isIn(VALID_MODE).withMessage(`mode must be one of: ${VALID_MODE.join(', ')}`),
  body('receipt').optional({ nullable: true }).trim(),
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
      item_name, thread, length, head, colour,
      party, date,
      quantity, uom, rate, mode,
      receipt = null,
      location = null,
    } = req.body;

    // 2. Resolve item_id from item_master using the 5-field combination
    //    Real column name is "name" (not "item_name")
    const itemLookup = await db.query(
      `SELECT id FROM item_master
       WHERE name = $1 AND thread = $2 AND length = $3 AND head = $4 AND colour = $5
       LIMIT 1`,
      [item_name, thread, length, head, colour]
    );

    if (itemLookup.rowCount === 0) {
      return res.status(422).json({
        success: false,
        error: 'No matching item found for the selected combination (item, thread, length, head, colour).',
      });
    }

    const itemId = itemLookup.rows[0].id;

    // 3. Compute amount = rate × quantity
    const qty     = parseFloat(quantity);
    const rateVal = parseFloat(rate);
    const amount  = parseFloat((qty * rateVal).toFixed(2));

    // 4. Insert into sale_transaction (all lowercase column names)
    const insertResult = await db.query(
      `INSERT INTO sale_transaction
         (date, party, item_id, quantity, uom, rate, mode, amount, reciept, location)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [date, party, itemId, qty, uom, rateVal, mode, amount, receipt, location]
    );

    res.status(201).json({ success: true, data: insertResult.rows[0] });
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
         LEFT JOIN item_master im ON st.item_id = im.id
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
       LEFT JOIN item_master im ON st.item_id = im.id
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
