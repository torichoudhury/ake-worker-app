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
// Helper: resolve item_id from item_master using item_id_uom composite key
// "Name_Thread_Length_Head_Colour"
// Returns the numeric item_master.id, or null if not found.
// ─────────────────────────────────────────────
async function resolveItemMasterId(client, item_id_uom) {
  // We match using CONCAT with ::text cast on numeric length column
  const result = await client.query(
    `SELECT id
     FROM item_master
     WHERE CONCAT(
       TRIM(name), '_',
       TRIM(thread), '_',
       TRIM(length::text), '_',
       TRIM(head), '_',
       TRIM(colour)
     ) = $1
     LIMIT 1`,
    [item_id_uom]
  );
  return result.rowCount > 0 ? result.rows[0].id : null;
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

    // Derive quantity_per_uom from UoM map
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

      // 2. Recompute aggregates from log table for this item+uom
      const aggResult = await client.query(
        `SELECT
           AVG(weight_per_uom)    AS avg_weight,
           AVG(sale_rate_per_uom) AS avg_rate,
           MAX(quantity_per_uom)  AS qty_per_uom
         FROM item_weight_uom_log
         WHERE item_id_uom = $1 AND LOWER(TRIM(uom)) = LOWER(TRIM($2))`,
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
// Query: item_id_uom, uom, customer (optional — "cash" or alias string)
//
// Weight source: item_weight_uom_log (avg of all recorded weights)
// Rate sources (COMBINED):
//   1. item_weight_uom_log entries (manually recorded rates)
//   2. sale_transaction table (actual sales rates)
//   First rate: earliest across both sources
//   Avg rate:   average across both sources (sliding window = all history)
//   Customer last rate: last rate from sale_transaction for the specific party + item + uom
//   Suggested rate: customer_last_rate (if specific customer) else avg_rate
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

    // ── 1. Average weight from item_weight_uom_log ──────────────────
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

    // ── 2. Combined rate stats from BOTH log + sale_transaction ──────
    // First find item_master.id for the join (needed for sale_transaction)
    // item_id_uom = "Name_Thread_Length_Head_Colour"
    // We'll match using a CONCAT on item_master columns.
    //
    // Build a UNION of rates:
    //   a) item_weight_uom_log.sale_rate_per_uom (manual entry)
    //   b) sale_transaction.rate WHERE item matches AND uom matches (actual sales)
    //
    // Use a subquery so we can compute AVG/MIN across both sources.

    const combinedRateResult = await db.query(
      `WITH all_rates AS (
         -- Source 1: manually recorded rates from log
         SELECT sale_rate_per_uom AS rate, id AS seq
         FROM item_weight_uom_log
         WHERE item_id_uom = $1
           AND LOWER(TRIM(uom)) = LOWER(TRIM($2))
           AND sale_rate_per_uom IS NOT NULL

         UNION ALL

         -- Source 2: actual sale rates from sale_transaction
         SELECT st.rate, st.id AS seq
         FROM sale_transaction st
         JOIN item_master im ON st.item_id = im.id
         WHERE CONCAT(
             TRIM(im.name), '_',
             TRIM(im.thread), '_',
             TRIM(im.length::text), '_',
             TRIM(im.head), '_',
             TRIM(im.colour)
           ) = $1
           AND LOWER(TRIM(st.uom)) = LOWER(TRIM($2))
           AND st.rate IS NOT NULL
           AND st.rate > 0
       )
       SELECT
         AVG(rate)  AS avg_rate,
         MIN(rate)  AS min_rate
       FROM all_rates`,
      [item_id_uom, uom]
    );

    // Get the first-ever rate (oldest by seq) across both sources
    const firstRateResult = await db.query(
      `WITH all_rates AS (
         SELECT sale_rate_per_uom AS rate, id AS seq
         FROM item_weight_uom_log
         WHERE item_id_uom = $1
           AND LOWER(TRIM(uom)) = LOWER(TRIM($2))
           AND sale_rate_per_uom IS NOT NULL

         UNION ALL

         SELECT st.rate, st.id AS seq
         FROM sale_transaction st
         JOIN item_master im ON st.item_id = im.id
         WHERE CONCAT(
             TRIM(im.name), '_',
             TRIM(im.thread), '_',
             TRIM(im.length::text), '_',
             TRIM(im.head), '_',
             TRIM(im.colour)
           ) = $1
           AND LOWER(TRIM(st.uom)) = LOWER(TRIM($2))
           AND st.rate IS NOT NULL
           AND st.rate > 0
       )
       SELECT rate AS first_rate
       FROM all_rates
       ORDER BY seq ASC
       LIMIT 1`,
      [item_id_uom, uom]
    );

    const avgRate   = combinedRateResult.rows[0]?.avg_rate != null
      ? parseFloat(combinedRateResult.rows[0].avg_rate).toFixed(2)
      : null;
    const firstRate = firstRateResult.rows[0]?.first_rate != null
      ? parseFloat(firstRateResult.rows[0].first_rate).toFixed(2)
      : null;

    // ── 3. Customer-specific last rate from sale_transaction ─────────
    let customerLastRate = null;
    if (!isCash && customer) {
      const custRateResult = await db.query(
        `SELECT st.rate
         FROM sale_transaction st
         JOIN item_master im ON st.item_id = im.id
         WHERE CONCAT(
             TRIM(im.name), '_',
             TRIM(im.thread), '_',
             TRIM(im.length::text), '_',
             TRIM(im.head), '_',
             TRIM(im.colour)
           ) = $1
           AND LOWER(TRIM(st.uom)) = LOWER(TRIM($2))
           AND LOWER(TRIM(st.party)) = LOWER(TRIM($3))
           AND st.rate IS NOT NULL
           AND st.rate > 0
         ORDER BY st.id DESC
         LIMIT 1`,
        [item_id_uom, uom, customer]
      );
      if (custRateResult.rowCount > 0) {
        customerLastRate = parseFloat(custRateResult.rows[0].rate).toFixed(2);
      }
    }

    // ── 4. Suggested rate ────────────────────────────────────────────
    //   Cash → avg across all sources (log + sale_transaction)
    //   Specific customer → customer's last rate, fallback to avg
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
      },
    });
  })
);

// ─────────────────────────────────────────────
// GET /api/item-weight-uom/entries
// Query: item_id_uom, uom (optional)
// Returns: combined log from item_weight_uom_log AND sale_transaction,
//          most recent first, each row tagged with source
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

    // Build optional UoM filter clause for log table
    const logUomClause = uom ? `AND LOWER(TRIM(uom)) = LOWER(TRIM($2))` : '';
    const logParams    = uom ? [item_id_uom, uom] : [item_id_uom];

    // Build optional UoM filter clause for sale_transaction
    const stUomClause = uom ? `AND LOWER(TRIM(st.uom)) = LOWER(TRIM($2))` : '';
    const stParams    = uom ? [item_id_uom, uom] : [item_id_uom];

    // Run both queries in parallel
    const [logResult, stResult] = await Promise.all([
      // From item_weight_uom_log (manual entries)
      db.query(
        `SELECT
           id,
           item_id_uom,
           date,
           uom,
           weight_per_uom,
           weight_uom,
           sale_rate_per_uom,
           quantity_per_uom,
           'manual_entry' AS source
         FROM item_weight_uom_log
         WHERE item_id_uom = $1 ${logUomClause}
         ORDER BY id DESC`,
        logParams
      ),

      // From sale_transaction (actual sales)
      db.query(
        `SELECT
           st.id,
           CONCAT(
             TRIM(im.name), '_',
             TRIM(im.thread), '_',
             TRIM(im.length::text), '_',
             TRIM(im.head), '_',
             TRIM(im.colour)
           ) AS item_id_uom,
           st.date,
           st.uom,
           NULL::numeric AS weight_per_uom,
           NULL AS weight_uom,
           st.rate AS sale_rate_per_uom,
           NULL::numeric AS quantity_per_uom,
           st.party,
           st.quantity,
           st.amount,
           'sale_transaction' AS source
         FROM sale_transaction st
         JOIN item_master im ON st.item_id = im.id
         WHERE CONCAT(
             TRIM(im.name), '_',
             TRIM(im.thread), '_',
             TRIM(im.length::text), '_',
             TRIM(im.head), '_',
             TRIM(im.colour)
           ) = $1
           ${stUomClause}
         ORDER BY st.id DESC`,
        stParams
      ),
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
