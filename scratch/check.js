require('dotenv').config({ path: require('path').resolve(__dirname, '../backend/.env') });
const db = require('../backend/src/config/db');

async function check() {
  const res = await db.query('SELECT * FROM movement_logs');
  console.log("Movement Logs:");
  console.log(res.rows);
  db.end();
}

check().catch(console.error);
