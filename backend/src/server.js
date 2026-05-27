// src/server.js
// Entry point for the AKE Worker App backend

require('dotenv').config();

const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');
const morgan  = require('morgan');

const itemsRouter        = require('./routes/items');
const transactionsRouter = require('./routes/transactions');
const customersRouter    = require('./routes/customers');
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
      if (!origin || allowedOrigins.includes(origin)) {
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
// Health check
// ─────────────────────────────────────────────

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'ake-worker-backend',
    version: require('../package.json').version,
  });
});

// ─────────────────────────────────────────────
// API Routes
// ─────────────────────────────────────────────

app.use('/api/items',        itemsRouter);
app.use('/api/transactions', transactionsRouter);
app.use('/api/customers',    customersRouter);

// ─────────────────────────────────────────────
// Error handling (must be last)
// ─────────────────────────────────────────────

app.use(notFoundHandler);
app.use(errorHandler);

// ─────────────────────────────────────────────
// Start server
// ─────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`\n🚀 AKE Worker Backend running on http://localhost:${PORT}`);
  console.log(`   Health check: http://localhost:${PORT}/health`);
  console.log(`   Environment: ${process.env.NODE_ENV || 'development'}\n`);
});

module.exports = app; // for testing
