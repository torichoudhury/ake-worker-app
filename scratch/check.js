require('dotenv').config({ path: require('path').resolve(__dirname, '../backend/.env') });
const db = require('../backend/src/config/db');

async function check() {
  console.log("=== Item Master ===");
  const items = await db.query('SELECT * FROM item_master LIMIT 5');
  console.log(items.rows);

  console.log("\n=== Sale Transactions ===");
  const txs = await db.query('SELECT * FROM sale_transaction LIMIT 5');
  console.log(txs.rows);

  console.log("\n=== Item Weight UoM Log ===");
  const logs = await db.query('SELECT * FROM item_weight_uom_log LIMIT 5');
  console.log(logs.rows);

  db.end();
}

check().catch(console.error);
