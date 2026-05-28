// src/routes/movement.js
const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const db = require('../config/db');
const { asyncHandler } = require('../middleware/errorHandler');

const movementValidationRules = [
  body('date').trim().notEmpty().withMessage('date is required'),
  body('activity').trim().notEmpty().withMessage('activity is required'),
  body('from_location').trim().notEmpty().withMessage('from_location is required'),
  body('to_location').optional({ nullable: true }).isString(),
  body('items').isArray({ min: 1 }).withMessage('items array must not be empty'),
  body('items.*.item_name').trim().notEmpty(),
  body('items.*.thread').trim().notEmpty(),
  body('items.*.length').trim().notEmpty(),
  body('items.*.head').trim().notEmpty(),
  body('items.*.colour').trim().notEmpty(),
  body('items.*.quantity').optional({ nullable: true }).isFloat(),
  body('items.*.uom').optional({ nullable: true }).isString(),
  body('items.*.packet').optional({ nullable: true }).isFloat(),
  body('items.*.per_packet').optional({ nullable: true }).isFloat(),
  body('items.*.uom_packet').optional({ nullable: true }).isString(),
];

router.post(
  '/',
  movementValidationRules,
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({
        success: false,
        error: 'Validation failed',
        details: errors.array(),
      });
    }

    const { date, activity, from_location, to_location, items } = req.body;
    const client = await db.connect();
    let firstInsertedId = null;

    try {
      await client.query('BEGIN');

      for (const item of items) {
        // Resolve item_id (text field) from item_master
        const itemLookup = await client.query(
          `SELECT item_id FROM item_master
           WHERE name = $1 AND thread = $2 AND length = $3 AND head = $4 AND colour = $5
           LIMIT 1`,
          [item.item_name, item.thread, item.length, item.head, item.colour]
        );

        if (itemLookup.rowCount === 0) {
          throw new Error(`No matching item found for: ${item.item_name} ${item.thread} ${item.length} ${item.head} ${item.colour}`);
        }

        const itemId = itemLookup.rows[0].item_id;
        const qty = item.quantity !== null && item.quantity !== undefined ? parseFloat(item.quantity) : null;
        const packet = item.packet !== null && item.packet !== undefined ? parseFloat(item.packet) : null;
        const perPacket = item.per_packet !== null && item.per_packet !== undefined ? parseFloat(item.per_packet) : null;

        const insertResult = await client.query(
          `INSERT INTO movement_logs
             (date, activity, item_id, quantity, uom, packet, per_packet, uom_packet, from_location, to_location)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           RETURNING id`,
          [date, activity, itemId, qty, item.uom || null, packet, perPacket, item.uom_packet || null, from_location, to_location || null]
        );

        if (firstInsertedId === null) {
          firstInsertedId = insertResult.rows[0].id;
        }
      }

      await client.query('COMMIT');
      res.status(201).json({ success: true, data: { movement_id: firstInsertedId } });

    } catch (e) {
      await client.query('ROLLBACK');
      res.status(500).json({ success: false, error: e.message });
    } finally {
      client.release();
    }
  })
);

module.exports = router;
