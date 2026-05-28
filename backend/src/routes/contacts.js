const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const db = require('../config/db');
const { asyncHandler } = require('../middleware/errorHandler');

const contactValidationRules = [
  body('type').isIn(['customer', 'vendor']).withMessage('type must be either customer or vendor'),
  body('alias').trim().notEmpty().withMessage('alias (short name) is required'),
  body('name').trim().notEmpty().withMessage('name is required'),
  body('address').optional({ nullable: true }).isString(),
  body('gst').optional({ nullable: true }).isString(),
  body('whatsapp').optional({ nullable: true, checkFalsy: true }).isNumeric(),
  body('phone').optional({ nullable: true }).isArray(),
  body('email').optional({ nullable: true, checkFalsy: true }).isEmail(),
];

router.post(
  '/',
  contactValidationRules,
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({
        success: false,
        error: 'Validation failed',
        details: errors.array(),
      });
    }

    const { type, alias, name, address, gst, whatsapp, phone, email } = req.body;

    // Custom validation: At least one of whatsapp or phone must be provided
    if (!whatsapp && (!phone || phone.length === 0)) {
      return res.status(422).json({
        success: false,
        error: 'Validation failed',
        details: [{ msg: 'Either WhatsApp or Phone number is required' }],
      });
    }

    const tableName = type === 'customer' ? 'customer_master' : 'vendor_master';
    
    // Convert arrays of string phone numbers to BIGINT array format for postgres
    // The pg library handles JavaScript arrays to Postgres arrays if we pass it directly.
    const phoneArray = phone && phone.length > 0 ? phone.map(p => parseInt(p, 10)) : null;
    const whatsappNum = whatsapp ? parseInt(whatsapp, 10) : null;

    try {
      const result = await db.query(
        `INSERT INTO ${tableName} 
         (alias, vendor_name, address, gst, whatsapp, phone, email) 
         VALUES ($1, $2, $3, $4, $5, $6, $7) 
         RETURNING alias`,
        [alias, name, address || null, gst || null, whatsappNum, phoneArray, email || null]
      );

      res.status(201).json({ success: true, data: result.rows[0] });
    } catch (e) {
      if (e.code === '23505') { // Unique constraint violation (Primary Key)
        return res.status(409).json({ success: false, error: 'A contact with this alias already exists.' });
      }
      throw e;
    }
  })
);

module.exports = router;
