// src/routes/items.js
// GET /api/items/all — returns distinct dropdown values from item_master

const express = require('express');
const router  = express.Router();
const db = require('../config/db');
const { asyncHandler } = require('../middleware/errorHandler');

// ─────────────────────────────────────────────
// GET /api/items/all
// Returns distinct values for each of the 5 item attributes
// directly from item_master — all in one request
// ─────────────────────────────────────────────

router.get(
  '/all',
  asyncHandler(async (req, res) => {
    const name = req.query.name;
    let whereClause = '';
    let params = [];

    if (name) {
      whereClause = 'AND name = $1';
      params = [name];
    }

    const [items, threads, lengths, heads, colours] = await Promise.all([
      db.query('SELECT DISTINCT name FROM item_master WHERE name IS NOT NULL ORDER BY name ASC'),
      db.query(`SELECT DISTINCT thread AS name FROM item_master WHERE thread IS NOT NULL ${whereClause} ORDER BY thread ASC`, params),
      db.query(`SELECT DISTINCT length AS value FROM item_master WHERE length IS NOT NULL ${whereClause} ORDER BY length ASC`, params),
      db.query(`SELECT DISTINCT head AS name FROM item_master WHERE head IS NOT NULL ${whereClause} ORDER BY head ASC`, params),
      db.query(`SELECT DISTINCT colour AS name FROM item_master WHERE colour IS NOT NULL ${whereClause} ORDER BY colour ASC`, params),
    ]);

    res.json({
      success: true,
      data: {
        items:   items.rows,
        threads: threads.rows,
        lengths: lengths.rows,
        heads:   heads.rows,
        colours: colours.rows,
      },
    });
  })
);

module.exports = router;
