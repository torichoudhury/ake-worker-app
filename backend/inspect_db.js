require('dotenv').config();
const db = require('./src/config/db');

async function run() {
  // List all tables
  const tables = await db.query(
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name"
  );
  console.log('\n📋 Tables in database:');
  tables.rows.forEach(r => console.log('  -', r.table_name));

  // List columns of tables that look like Item_Master and Customer_Master
  for (const row of tables.rows) {
    const name = row.table_name.toLowerCase();
    if (name.includes('item') || name.includes('customer') || name.includes('sale')) {
      const cols = await db.query(
        `SELECT column_name, data_type FROM information_schema.columns WHERE table_name = $1 AND table_schema = 'public' ORDER BY ordinal_position`,
        [row.table_name]
      );
      console.log(`\n🔍 Columns of "${row.table_name}":`);
      cols.rows.forEach(c => console.log(`  - ${c.column_name} (${c.data_type})`));
    }
  }

  await db.end();
}

run().catch(e => { console.error('Error:', e.message); process.exit(1); });
