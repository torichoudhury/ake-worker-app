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
  body('items.*.after_colour').optional({ nullable: true }).isString(),
  body('items.*.after_quantity').optional({ nullable: true }).isFloat(),
  body('items.*.after_uom').optional({ nullable: true }).isString(),
  body('items.*.after_packet').optional({ nullable: true }).isFloat(),
  body('items.*.after_per_packet').optional({ nullable: true }).isFloat(),
  body('items.*.after_uom_packet').optional({ nullable: true }).isString(),
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
        // Determine locations for Before and After rows
        let beforeFrom = from_location;
        let beforeTo = to_location;
        let afterFrom = from_location;
        let afterTo = to_location;

        if (from_location === 'Plating') {
          // Coming back from Plating
          // Before item was sent TO plating
          beforeFrom = to_location || 'Unknown';
          beforeTo = 'Plating';
          // After item is coming FROM plating
          afterFrom = 'Plating';
          afterTo = to_location || 'Unknown';
        } else if (to_location === 'Plating') {
          // Going TO Plating
          // Before item is going TO plating
          beforeFrom = from_location;
          beforeTo = 'Plating';
          // After item will come FROM plating
          afterFrom = 'Plating';
          afterTo = from_location;
        }

        // 1. Log BEFORE Plating (or normal movement) if quantity exists
        if (item.quantity !== null && item.quantity !== undefined) {
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
          const qty = parseFloat(item.quantity);
          const packet = item.packet !== null && item.packet !== undefined ? parseFloat(item.packet) : null;
          const perPacket = item.per_packet !== null && item.per_packet !== undefined ? parseFloat(item.per_packet) : null;

          const insertResult = await client.query(
            `INSERT INTO movement_logs
               (date, activity, item_id, quantity, uom, packet, per_packet, uom_packet, from_location, to_location)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
             RETURNING id`,
            [date, activity, itemId, qty, item.uom || null, packet, perPacket, item.uom_packet || null, beforeFrom, beforeTo || null]
          );

          if (firstInsertedId === null) {
            firstInsertedId = insertResult.rows[0].id;
          }
        }

        // 2. Log AFTER Plating if after_quantity exists
        if (item.after_quantity !== null && item.after_quantity !== undefined && item.after_colour) {
          const afterItemLookup = await client.query(
            `SELECT item_id FROM item_master
             WHERE name = $1 AND thread = $2 AND length = $3 AND head = $4 AND colour = $5
             LIMIT 1`,
            [item.item_name, item.thread, item.length, item.head, item.after_colour]
          );

          if (afterItemLookup.rowCount === 0) {
            throw new Error(`No matching item found for new colour: ${item.item_name} ${item.thread} ${item.length} ${item.head} ${item.after_colour}`);
          }

          const afterItemId = afterItemLookup.rows[0].item_id;
          const afterQty = parseFloat(item.after_quantity);
          const afterPacket = item.after_packet !== null && item.after_packet !== undefined ? parseFloat(item.after_packet) : null;
          const afterPerPacket = item.after_per_packet !== null && item.after_per_packet !== undefined ? parseFloat(item.after_per_packet) : null;

          const insertResult = await client.query(
            `INSERT INTO movement_logs
               (date, activity, item_id, quantity, uom, packet, per_packet, uom_packet, from_location, to_location)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
             RETURNING id`,
            [date, activity, afterItemId, afterQty, item.after_uom || null, afterPacket, afterPerPacket, item.after_uom_packet || null, afterFrom, afterTo || null]
          );

          if (firstInsertedId === null) {
            firstInsertedId = insertResult.rows[0].id;
          }
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
