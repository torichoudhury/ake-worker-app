// src/server.js
// Entry point for the AKE Worker App backend

// Force IPv4 DNS resolution — Render free tier cannot reach Supabase over IPv6
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');

require('dotenv').config();

const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');
const morgan  = require('morgan');

const itemsRouter           = require('./routes/items');
const transactionsRouter    = require('./routes/transactions');
const customersRouter       = require('./routes/customers');
const movementRoutes        = require('./routes/movement');
const duesRoutes            = require('./routes/dues');
const contactsRouter        = require('./routes/contacts');
const itemWeightUomRouter   = require('./routes/item_weight_uom');
const authRouter            = require('./routes/auth');
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');

// ─────────────────────────────────────────────
// App setup
// ─────────────────────────────────────────────

const app  = express();
const PORT = process.env.PORT || 3000;

// ─────────────────────────────────────────────
// Security & utility middleware
// ─────────────────────────────────────────────

app.use(helmet());
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// CORS — allow Flutter app origins
const allowedOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost')
  .split(',')
  .map((o) => o.trim());

app.use(
  cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (e.g., mobile apps, curl, Postman)
      if (
        !origin ||
        allowedOrigins.includes(origin) ||
        origin.startsWith('http://localhost') ||
        origin.startsWith('http://127.0.0.1')
      ) {
        callback(null, true);
      } else {
        callback(new Error(`CORS blocked for origin: ${origin}`));
      }
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  })
);

// ─────────────────────────────────────────────
// Root & Health check
// ─────────────────────────────────────────────

app.get('/', (req, res) => {
  res.json({
    success: true,
    service: 'ake-worker-backend',
    version: require('../package.json').version,
    status: 'running',
  });
});

app.get('/health', (req, res) => {
  res.json({
    success: true,
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'ake-worker-backend',
    version: require('../package.json').version,
  });
});

// ─────────────────────────────────────────────
// API Routes
// ─────────────────────────────────────────────

app.use('/api/items',             itemsRouter);
app.use('/api/transactions',      transactionsRouter);
app.use('/api/customers',         customersRouter);
app.use('/api/movement',          movementRoutes);
app.use('/api/dues',              duesRoutes);
app.use('/api/contacts',          contactsRouter);
app.use('/api/item-weight-uom',   itemWeightUomRouter);
app.use('/api/auth',              authRouter);

// ─────────────────────────────────────────────
// Error handling (must be last)
// ─────────────────────────────────────────────

app.use(notFoundHandler);
app.use(errorHandler);

// ─────────────────────────────────────────────
// Start server
// ─────────────────────────────────────────────

app.listen(PORT, '0.0.0.0', () => {
  console.log(`\n🚀 AKE Worker Backend listening on 0.0.0.0:${PORT}`);
  console.log(`   Health check: http://localhost:${PORT}/health`);
  console.log(`   Environment: ${process.env.NODE_ENV || 'development'}\n`);
});

module.exports = app; // for testing
