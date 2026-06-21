// src/routes/auth.js
// Authentication endpoints for Landing Authorization

const express = require('express');
const router  = express.Router();
const { body, query, validationResult } = require('express-validator');
const db = require('../config/db');
const { asyncHandler } = require('../middleware/errorHandler');

// In-memory counter for failed login attempts keyed by worker alias
const failedAttempts = new Map();

// Helper to get local timestamp string in YYYY-MM-DD HH:mm:ss format
function getLocalTimestamp() {
  const tzoffset = (new Date()).getTimezoneOffset() * 60000;
  return new Date(Date.now() - tzoffset).toISOString().slice(0, 19).replace('T', ' ');
}

// ─────────────────────────────────────────────
// GET /api/auth/check-alias
// Checks if the worker alias (uid) exists and is a worker
// ─────────────────────────────────────────────
router.get(
  '/check-alias',
  [
    query('alias').trim().notEmpty().withMessage('alias is required'),
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({ success: false, error: 'Validation failed', details: errors.array() });
    }

    const { alias } = req.query;

    const result = await db.query(
      `SELECT uid FROM user_login
       WHERE LOWER(TRIM(uid)) = LOWER(TRIM($1))
         AND LOWER(TRIM(role)) = 'worker'
       LIMIT 1`,
      [alias]
    );

    res.json({
      success: true,
      exists: result.rowCount > 0,
    });
  })
);

// ─────────────────────────────────────────────
// POST /api/auth/login
// Validates worker credentials (alias + PIN). Logs unauthorized login on 2nd failure.
// ─────────────────────────────────────────────
router.post(
  '/login',
  [
    body('alias').trim().notEmpty().withMessage('alias is required'),
    body('pin').trim().notEmpty().withMessage('pin is required'),
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({ success: false, error: 'Validation failed', details: errors.array() });
    }

    const { alias, pin } = req.body;
    const lowerAlias = alias.toLowerCase().trim();

    // 1. Fetch user by alias and verify role is 'worker'
    const result = await db.query(
      `SELECT uid, role, pin FROM user_login
       WHERE LOWER(TRIM(uid)) = $1
         AND LOWER(TRIM(role)) = 'worker'
       LIMIT 1`,
      [lowerAlias]
    );

    // If user is not found or not a worker, it counts as a failed login attempt for that alias name
    const user = result.rows[0];
    const isPinMatch = user && user.pin === pin;

    if (!isPinMatch) {
      const currentFailures = (failedAttempts.get(lowerAlias) || 0) + 1;
      failedAttempts.set(lowerAlias, currentFailures);

      let logged = false;
      if (currentFailures >= 2) {
        // Insert into unauthorized_login table
        const timestamp = getLocalTimestamp();
        await db.query(
          `INSERT INTO unauthorized_login (worker_alias, date)
           VALUES ($1, $2)`,
          [alias, timestamp]
        );
        // Reset counter after logging
        failedAttempts.delete(lowerAlias);
        logged = true;
      }

      return res.status(401).json({
        success: false,
        error: isPinMatch ? 'Unauthorized worker role' : 'Incorrect PIN',
        logged,
        message: logged
          ? 'Failed attempts limit reached. Unauthorized access logged.'
          : `Incorrect PIN. Attempt ${currentFailures} of 2.`,
      });
    }

    // Success: reset failures
    failedAttempts.delete(lowerAlias);

    res.json({
      success: true,
      user: {
        uid: user.uid,
        role: user.role,
      },
    });
  })
);

module.exports = router;
