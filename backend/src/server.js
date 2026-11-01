const { Pool } = require('pg');
const { createApp } = require('./app');

const PORT = Number(process.env.PORT || 4000);

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'dompetku',
  password: process.env.DB_PASSWORD || 'dompetku_secret',
  database: process.env.DB_NAME || 'dompetku_db',
});

async function ensureSchemaWithRetry(retries = 15, delayMs = 2000) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS transactions (
          id SERIAL PRIMARY KEY,
          title VARCHAR(150) NOT NULL,
          amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
          type VARCHAR(20) NOT NULL CHECK (type IN ('income', 'expense')),
          category VARCHAR(60) NOT NULL,
          note TEXT DEFAULT '',
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
      `);
      console.log('[Backend] Terhubung ke PostgreSQL & skema siap.');
      return;
    } catch (err) {
      console.warn(`[Backend] Menunggu database siap (percobaan ${attempt}/${retries}): ${err.message}`);
      if (attempt === retries) throw err;
      await new Promise((r) => setTimeout(r, delayMs));
    }
  }
}

function mapRow(row) {
  return {
    id: Number(row.id),
    title: row.title,
    amount: Number(row.amount),
    type: row.type,
    category: row.category,
    note: row.note || '',
    createdAt: row.created_at instanceof Date ? row.created_at.toISOString() : row.created_at,
  };
}

const pgRepository = {
  async ping() {
    const res = await pool.query('SELECT 1 AS ok');
    return res.rowCount === 1;
  },

  async listTransactions({ type, category, search } = {}) {
    const conditions = [];
    const values = [];

    if (type) {
      values.push(type);
      conditions.push(`type = $${values.length}`);
    }
    if (category) {
      values.push(category);
      conditions.push(`category = $${values.length}`);
    }
    if (search) {
      values.push(`%${search}%`);
      conditions.push(`(title ILIKE $${values.length} OR category ILIKE $${values.length} OR note ILIKE $${values.length})`);
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    const sql = `
      SELECT id, title, amount, type, category, note, created_at
      FROM transactions
      ${whereClause}
      ORDER BY created_at DESC, id DESC
    `;
    const result = await pool.query(sql, values);
    return result.rows.map(mapRow);
  },

  async createTransaction({ title, amount, type, category, note }) {
    const sql = `
      INSERT INTO transactions (title, amount, type, category, note)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id, title, amount, type, category, note, created_at
    `;
    const result = await pool.query(sql, [title, amount, type, category, note]);
    return mapRow(result.rows[0]);
  },

  async deleteTransaction(id) {
    const result = await pool.query('DELETE FROM transactions WHERE id = $1 RETURNING id', [id]);
    return result.rowCount > 0;
  },
};

async function start() {
  await ensureSchemaWithRetry();
  const app = createApp(pgRepository);
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`[Backend] DompetKu REST API berjalan di http://0.0.0.0:${PORT}`);
  });
}

if (require.main === module) {
  start().catch((err) => {
    console.error('[Backend] Gagal memulai server:', err);
    process.exit(1);
  });
}

module.exports = { pgRepository };
