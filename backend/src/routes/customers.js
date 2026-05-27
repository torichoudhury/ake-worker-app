// src/routes/customers.js
// GET /api/customers  — returns all customer aliases from customer_master

const express = require('express');
const router  = express.Router();
const db = require('../config/db');
const { asyncHandler } = require('../middleware/errorHandler');

// ─────────────────────────────────────────────
// GET /api/customers
// Returns: [{ alias, vendor_name }]
// alias is stored as party in sale_transaction
// ─────────────────────────────────────────────

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const result = await db.query(
      `SELECT alias, vendor_name FROM customer_master ORDER BY alias ASC`
    );

    res.json({ success: true, data: result.rows });
  })
);

module.exports = router;
