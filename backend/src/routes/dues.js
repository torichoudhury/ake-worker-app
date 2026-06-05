// src/routes/dues.js
const express = require('express');
const router = express.Router();
const { body, query, validationResult } = require('express-validator');
const db = require('../config/db');
const { asyncHandler } = require('../middleware/errorHandler');

// ─────────────────────────────────────────────
// GET /api/dues
// Expects: ?name=customer_name&phone=phone_number
// ─────────────────────────────────────────────
router.get(
  '/',
  [
    query('name').optional().isString(),
    query('phone').optional().isString(),
  ],
  asyncHandler(async (req, res) => {
    const { name, phone } = req.query;
    
    // We want to find transaction_treasury rows where due = true and it's the max iteration.
    // We join sale_transaction to get the date and party.
    // We join customer_master on alias or vendor_name to filter by name and phone.
    
    let baseQuery = `
      SELECT 
        tt.transaction_id,
        tt.amount,
        tt.due_amount,
        st.date,
        st.party
      FROM transaction_treasury tt
      JOIN (
        SELECT transaction_id, MAX(date) as date, MAX(party) as party 
        FROM sale_transaction 
        GROUP BY transaction_id
      ) st ON st.transaction_id = tt.transaction_id
      JOIN customer_master cm ON cm.alias = st.party OR cm.vendor_name = st.party
      WHERE tt.due = true
        AND tt.iteration = (
          SELECT MAX(iteration) 
          FROM transaction_treasury 
          WHERE transaction_id = tt.transaction_id
        )
    `;

    const params = [];
    let paramIndex = 1;

    if (name) {
      baseQuery += ` AND (cm.alias ILIKE $${paramIndex} OR cm.vendor_name ILIKE $${paramIndex})`;
      params.push(`%${name}%`);
      paramIndex++;
    }

    if (phone) {
      // Cast bigint whatsapp to text for ILIKE, or just exact match if provided
      baseQuery += ` AND cm.whatsapp::text ILIKE $${paramIndex}`;
      params.push(`%${phone}%`);
      paramIndex++;
    }

    baseQuery += ` ORDER BY tt.transaction_id DESC`;

    const result = await db.query(baseQuery, params);

    res.json({ success: true, data: result.rows });
  })
);

// ─────────────────────────────────────────────
// POST /api/dues/settle
// ─────────────────────────────────────────────
const settleValidationRules = [
  body('transaction_id').isInt().withMessage('transaction_id is required'),
  body('balance_settled').isFloat({ min: 0 }).withMessage('balance_settled must be a positive number'),
  body('date').optional({ nullable: true }).isString(),
];

router.post(
  '/settle',
  settleValidationRules,
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({
        success: false,
        error: 'Validation failed',
        details: errors.array(),
      });
    }

    const { transaction_id, balance_settled, date } = req.body;
    const settleAmount = parseFloat(balance_settled);
    const paymentDate = date || new Date().toISOString().split('T')[0];

    const client = await db.connect();

    try {
      await client.query('BEGIN');

      // Fetch the latest iteration for this transaction
      const latestResult = await client.query(
        `SELECT iteration, due_amount 
         FROM transaction_treasury 
         WHERE transaction_id = $1 
         ORDER BY iteration DESC LIMIT 1`,
        [transaction_id]
      );

      if (latestResult.rowCount === 0) {
        throw new Error('Transaction not found in treasury');
      }

      const { iteration: oldIteration, due_amount: oldDueAmount } = latestResult.rows[0];
      const newIteration = oldIteration + 1;
      const newOutstanding = parseFloat((oldDueAmount - settleAmount).toFixed(2));
      const isDue = newOutstanding > 0;

      // Insert new iteration
      await client.query(
        `INSERT INTO transaction_treasury (transaction_id, amount, due, iteration, due_amount, date)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [transaction_id, settleAmount, isDue, newIteration, newOutstanding, paymentDate]
      );

      // Update old iterations to due = false
      await client.query(
        `UPDATE transaction_treasury 
         SET due = false 
         WHERE transaction_id = $1 AND iteration < $2`,
        [transaction_id, newIteration]
      );

      await client.query('COMMIT');
      res.status(201).json({ success: true, data: { transaction_id, newOutstanding } });
    } catch (e) {
      await client.query('ROLLBACK');
      res.status(500).json({ success: false, error: e.message });
    } finally {
      client.release();
    }
  })
);

// ─────────────────────────────────────────────
// GET /api/dues/:transaction_id/history
// ─────────────────────────────────────────────
router.get(
  '/:transaction_id/history',
  asyncHandler(async (req, res) => {
    const transactionId = req.params.transaction_id;
    const result = await db.query(
      `SELECT 
         COALESCE(tt.date, (SELECT date FROM sale_transaction WHERE transaction_id = tt.transaction_id LIMIT 1)) as date, 
         CASE WHEN tt.iteration = 1 THEN (tt.amount - tt.due_amount) ELSE tt.amount END AS amount, 
         tt.due_amount, 
         tt.iteration 
       FROM transaction_treasury tt
       WHERE tt.transaction_id = $1 
         AND CASE WHEN tt.iteration = 1 THEN (tt.amount - tt.due_amount) ELSE tt.amount END > 0
       ORDER BY tt.iteration ASC`,
      [transactionId]
    );

    res.json({ success: true, data: result.rows });
  })
);

module.exports = router;
