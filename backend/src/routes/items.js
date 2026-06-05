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
    const { name, thread, length, head } = req.query;

    let baseParams = [];
    let baseWhere = '';

    if (name) {
      baseParams.push(name);
      baseWhere += ` AND name = $${baseParams.length}`;
    }

    // Threads only depend on name
    let threadsWhere = baseWhere;
    let threadsParams = [...baseParams];

    // Lengths depend on name and thread
    let lengthsWhere = threadsWhere;
    let lengthsParams = [...threadsParams];
    if (thread) {
      lengthsParams.push(thread);
      lengthsWhere += ` AND thread = $${lengthsParams.length}`;
    }

    // Heads depend on name, thread, and length
    let headsWhere = lengthsWhere;
    let headsParams = [...lengthsParams];
    if (length) {
      headsParams.push(length);
      headsWhere += ` AND length = $${headsParams.length}`;
    }

    // Colours depend on name, thread, length, and head
    let coloursWhere = headsWhere;
    let coloursParams = [...headsParams];
    if (head) {
      coloursParams.push(head);
      coloursWhere += ` AND head = $${coloursParams.length}`;
    }

    const [items, threads, lengths, heads, colours] = await Promise.all([
      db.query('SELECT DISTINCT name FROM item_master WHERE name IS NOT NULL ORDER BY name ASC'),
      db.query(`SELECT DISTINCT thread AS name FROM item_master WHERE thread IS NOT NULL ${threadsWhere} ORDER BY thread ASC`, threadsParams),
      db.query(`SELECT DISTINCT length AS value FROM item_master WHERE length IS NOT NULL ${lengthsWhere} ORDER BY length ASC`, lengthsParams),
      db.query(`SELECT DISTINCT head AS name FROM item_master WHERE head IS NOT NULL ${headsWhere} ORDER BY head ASC`, headsParams),
      db.query(`SELECT DISTINCT colour AS name FROM item_master WHERE colour IS NOT NULL ${coloursWhere} ORDER BY colour ASC`, coloursParams),
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
