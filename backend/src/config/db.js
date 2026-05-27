// src/config/db.js
// PostgreSQL connection pool — direct connection to Supabase via DATABASE_URL

const { Pool } = require('pg');

if (!process.env.DATABASE_URL) {
  throw new Error(
    'Missing DATABASE_URL environment variable. ' +
    'Set it in your .env file: postgresql://postgres:[PASSWORD]@db.<ref>.supabase.co:5432/postgres'
  );
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    // Supabase requires SSL; rejectUnauthorized false avoids cert issues
    rejectUnauthorized: false,
  },
  // Connection pool settings
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

// Log successful connection on startup
pool.on('connect', () => {
  console.log('✅ PostgreSQL connected to Supabase');
});

pool.on('error', (err) => {
  console.error('❌ PostgreSQL pool error:', err.message);
});

module.exports = pool;
