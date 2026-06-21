// src/routes/item_weight_uom.js
// Handles transactional entry and enquiry for item weight/rate per UoM
//
// Endpoints:
//   POST /api/item-weight-uom/entry   — record a dated weight + rate entry
//   GET  /api/item-weight-uom/enquiry — fetch avg weight + suggested rate for worker enquiry
//   GET  /api/item-weight-uom/entries — fetch history log for an item+uom

const express = require('express');
const router  = express.Router();
const { body, query, validationResult } = require('express-validator');
const db = require('../config/db');
const { asyncHandler } = require('../middleware/errorHandler');

const VALID_UOM = ['%', 'Gross', 'KG', 'Pcs', 'Bag', 'Box'];

// ─────────────────────────────────────────────
// UoM → quantity_per_uom conversion map
// ─────────────────────────────────────────────
const UOM_QTY_MAP = {
  'Pcs':   1,
  '%':     100,
  'Gross': 144,
  'KG':    null,
  'Bag':   null,
  'Box':   null,
};

// ─────────────────────────────────────────────
// Helper: resolve item_master primary key (id column) using individual
// item field params — same matching strategy as items.js (works reliably).
// Accepts query params: name, thread, length, head, colour
// Falls back to CONCAT match on item_id_uom if individual fields not provided.
// ─────────────────────────────────────────────
async function resolveItemId(pool, queryParams) {
  const { name, thread, length, head, colour, item_id_uom } = queryParams;

  // Prefer individual field matching (same as items.js / transactions.js)
  if (name && thread && length && head && colour) {
    const result = await pool.query(
      `SELECT item_id
       FROM item_master
       WHERE TRIM(LOWER(name))   = TRIM(LOWER($1))
         AND TRIM(LOWER(thread)) = TRIM(LOWER($2))
         AND length::text        = $3::text
         AND TRIM(LOWER(head))   = TRIM(LOWER($4))
         AND TRIM(LOWER(colour)) = TRIM(LOWER($5))
       LIMIT 1`,
      [name, thread, length, head, colour]
    );
    return result.rowCount > 0 ? result.rows[0].item_id : null;
  }

  // Fallback: match using existing item_id column directly
  if (item_id_uom) {
    const result = await pool.query(
      `SELECT item_id
       FROM item_master
       WHERE item_id = $1
       LIMIT 1`,
      [item_id_uom]
    );
    return result.rowCount > 0 ? result.rows[0].item_id : null;
  }

  return null;
}

// ─────────────────────────────────────────────
// POST /api/item-weight-uom/entry
// Body: { item_id_uom, uom, date, weight_per_uom, weight_uom?, sale_rate_per_uom, quantity_per_uom? }
// 1. Inserts a row into item_weight_uom_log
// 2. Recomputes and upserts aggregate into item_weight_uom
// ─────────────────────────────────────────────
router.post(
  '/entry',
  [
    body('item_id_uom').trim().notEmpty().withMessage('item_id_uom is required'),
    body('uom').isIn(VALID_UOM).withMessage(`uom must be one of: ${VALID_UOM.join(', ')}`),
    body('date').trim().notEmpty().withMessage('date is required'),
    body('weight_per_uom').isFloat({ min: 0 }).withMessage('weight_per_uom must be a non-negative number'),
    body('sale_rate_per_uom').isFloat({ min: 0 }).withMessage('sale_rate_per_uom must be a non-negative number'),
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({ success: false, error: 'Validation failed', details: errors.array() });
    }

    const {
      item_id_uom,
      uom,
      date,
      weight_per_uom,
      weight_uom = 'KG',
      sale_rate_per_uom,
    } = req.body;

    const quantity_per_uom = (req.body.quantity_per_uom !== undefined)
      ? req.body.quantity_per_uom
      : (UOM_QTY_MAP[uom] ?? null);

    const client = await db.connect();
    try {
      await client.query('BEGIN');

      // 1. Insert into log table
      await client.query(
        `INSERT INTO item_weight_uom_log
           (item_id_uom, date, uom, weight_per_uom, weight_uom, sale_rate_per_uom, quantity_per_uom)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [item_id_uom, date, uom, weight_per_uom, weight_uom, sale_rate_per_uom, quantity_per_uom]
      );

      // 2. Recompute aggregates from log table
      const aggResult = await client.query(
        `SELECT
           AVG(weight_per_uom)    AS avg_weight,
           AVG(sale_rate_per_uom) AS avg_rate,
           MAX(quantity_per_uom)  AS qty_per_uom
         FROM item_weight_uom_log
         WHERE item_id_uom = $1
           AND LOWER(TRIM(uom)) = LOWER(TRIM($2))`,
        [item_id_uom, uom]
      );

      const agg = aggResult.rows[0];
      const avgWeight = agg.avg_weight !== null ? parseFloat(agg.avg_weight).toFixed(3) : parseFloat(weight_per_uom).toFixed(3);
      const avgRate   = agg.avg_rate   !== null ? parseFloat(agg.avg_rate).toFixed(3)   : parseFloat(sale_rate_per_uom).toFixed(3);

      // 3. Upsert into item_weight_uom (aggregate/inventory view)
      await client.query(
        `INSERT INTO item_weight_uom
           (item_id_uom, uom, quantity_per_uom, weight_per_uom, weight_uom, sale_rate_per_uom)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (item_id_uom) DO UPDATE SET
           uom               = EXCLUDED.uom,
           quantity_per_uom  = EXCLUDED.quantity_per_uom,
           weight_per_uom    = EXCLUDED.weight_per_uom,
           weight_uom        = EXCLUDED.weight_uom,
           sale_rate_per_uom = EXCLUDED.sale_rate_per_uom`,
        [
          item_id_uom,
          uom,
          agg.qty_per_uom !== null ? parseFloat(agg.qty_per_uom) : null,
          avgWeight,
          weight_uom,
          avgRate,
        ]
      );

      await client.query('COMMIT');
      res.status(201).json({ success: true, data: { item_id_uom, uom, date } });
    } catch (e) {
      await client.query('ROLLBACK');
      res.status(500).json({ success: false, error: e.message });
    } finally {
      client.release();
    }
  })
);

// ─────────────────────────────────────────────
// GET /api/item-weight-uom/enquiry
// Query: item_id_uom, uom, customer (optional — "cash" or party alias)
//
// Weight:   AVG from item_weight_uom_log
// Rates:    UNION of item_weight_uom_log + sale_transaction (no JOIN — use resolved item_id)
// ─────────────────────────────────────────────
router.get(
  '/enquiry',
  [
    query('item_id_uom').trim().notEmpty().withMessage('item_id_uom is required'),
    query('uom').isIn(VALID_UOM).withMessage(`uom must be one of: ${VALID_UOM.join(', ')}`),
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({ success: false, error: 'Validation failed', details: errors.array() });
    }

    const { item_id_uom, uom, customer } = req.query;
    const isCash = !customer || customer.toLowerCase() === 'cash';

    // ── 1. Resolve item_master.id (avoids any JOIN type mismatch) ──────
    const itemMasterId = await resolveItemId(db, req.query);

    // ── 2. Average weight from item_weight_uom_log ─────────────────────
    const weightResult = await db.query(
      `SELECT AVG(weight_per_uom) AS avg_weight
       FROM item_weight_uom_log
       WHERE item_id_uom = $1
         AND LOWER(TRIM(uom)) = LOWER(TRIM($2))`,
      [item_id_uom, uom]
    );
    const avgWeight = weightResult.rows[0]?.avg_weight != null
      ? parseFloat(weightResult.rows[0].avg_weight).toFixed(3)
      : null;

    // ── 3. Rate stats — combined from log + sale_transaction ───────────
    //    Use two separate queries then merge in JS to avoid JOIN type issues.

    // 3a. Rates from item_weight_uom_log (manual entries)
    const logRates = await db.query(
      `SELECT sale_rate_per_uom AS rate
       FROM item_weight_uom_log
       WHERE item_id_uom = $1
         AND LOWER(TRIM(uom)) = LOWER(TRIM($2))
         AND sale_rate_per_uom IS NOT NULL
       ORDER BY id ASC`,
      [item_id_uom, uom]
    );

    // 3b. Rates from sale_transaction — use resolved item_master.id directly (no JOIN)
    let stRates = { rows: [] };
    if (itemMasterId !== null) {
      stRates = await db.query(
        `SELECT rate
         FROM sale_transaction
         WHERE item_id = $1
           AND LOWER(TRIM(uom)) = LOWER(TRIM($2))
           AND rate IS NOT NULL
           AND rate::numeric > 0
         ORDER BY id ASC`,
        [itemMasterId, uom]
      );
    }

    // Merge all rates and compute stats in JS
    const allRates = [
      ...logRates.rows.map(r => parseFloat(r.rate)),
      ...stRates.rows.map(r => parseFloat(r.rate)),
    ].filter(r => !isNaN(r) && r > 0);

    const firstRate   = allRates.length > 0
      ? allRates[0].toFixed(2)
      : null;
    const avgRate     = allRates.length > 0
      ? (allRates.reduce((sum, r) => sum + r, 0) / allRates.length).toFixed(2)
      : null;

    // ── 4. Customer-specific last rate from sale_transaction ────────────
    let customerLastRate = null;
    if (!isCash && customer && itemMasterId !== null) {
      const custResult = await db.query(
        `SELECT rate
         FROM sale_transaction
         WHERE item_id = $1
           AND LOWER(TRIM(uom)) = LOWER(TRIM($2))
           AND LOWER(TRIM(party)) = LOWER(TRIM($3))
           AND rate IS NOT NULL
           AND rate::numeric > 0
         ORDER BY id DESC
         LIMIT 1`,
        [itemMasterId, uom, customer]
      );
      if (custResult.rowCount > 0) {
        customerLastRate = parseFloat(custResult.rows[0].rate).toFixed(2);
      }
    }

    // ── 5. Suggested rate ───────────────────────────────────────────────
    const suggestedRate = isCash
      ? avgRate
      : (customerLastRate ?? avgRate);

    res.json({
      success: true,
      data: {
        item_id_uom,
        uom,
        weight_per_uom:     avgWeight,
        weight_uom:         'KG',
        first_rate:         firstRate,
        avg_rate:           avgRate,
        customer_last_rate: customerLastRate,
        suggested_rate:     suggestedRate,
        item_found:         itemMasterId !== null,
      },
    });
  })
);

// ─────────────────────────────────────────────
// GET /api/item-weight-uom/entries
// Query: item_id_uom, uom (optional)
// Returns both manual log entries and actual sale transactions.
// ─────────────────────────────────────────────
router.get(
  '/entries',
  [
    query('item_id_uom').trim().notEmpty().withMessage('item_id_uom is required'),
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({ success: false, error: 'Validation failed', details: errors.array() });
    }

    const { item_id_uom, uom } = req.query;

    // Resolve item_master.id first (no JOIN required)
    const itemMasterId = await resolveItemId(db, req.query);

    // Build optional UoM filter
    const logUomClause = uom ? `AND LOWER(TRIM(uom)) = LOWER(TRIM($2))` : '';
    const logParams    = uom ? [item_id_uom, uom] : [item_id_uom];
    const stUomClause  = uom ? `AND LOWER(TRIM(uom)) = LOWER(TRIM($2))` : '';
    const stParams     = itemMasterId !== null
      ? (uom ? [itemMasterId, uom] : [itemMasterId])
      : null;

    // Run queries in parallel
    const [logResult, stResult] = await Promise.all([
      // Manual entries from item_weight_uom_log
      db.query(
        `SELECT
           id, item_id_uom, date, uom,
           weight_per_uom, weight_uom,
           sale_rate_per_uom, quantity_per_uom,
           'manual_entry' AS source
         FROM item_weight_uom_log
         WHERE item_id_uom = $1 ${logUomClause}
         ORDER BY id DESC`,
        logParams
      ),

      // Actual sales from sale_transaction — direct lookup, no JOIN
      stParams !== null
        ? db.query(
            `SELECT
               id, date, uom,
               rate AS sale_rate_per_uom,
               party, quantity, amount,
               'sale_transaction' AS source
             FROM sale_transaction
             WHERE item_id = $1 ${stUomClause}
             ORDER BY id DESC`,
            stParams
          )
        : Promise.resolve({ rows: [] }),
    ]);

    res.json({
      success: true,
      data: {
        manual_entries:    logResult.rows,
        sale_transactions: stResult.rows,
      },
    });
  })
);

module.exports = router;
