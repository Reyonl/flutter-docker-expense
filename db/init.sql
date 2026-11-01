-- ============================================================================
-- Skema Database PostgreSQL untuk DompetKu Docker (Money Expense Tracker)
-- File ini otomatis dijalankan oleh container Postgres saat pertama kali dibuat
-- (di-mount ke /docker-entrypoint-initdb.d/init.sql)
-- ============================================================================

CREATE TABLE IF NOT EXISTS transactions (
    id SERIAL PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    type VARCHAR(20) NOT NULL CHECK (type IN ('income', 'expense')),
    category VARCHAR(60) NOT NULL,
    note TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at DESC);

-- Seed data awal jika tabel masih kosong
INSERT INTO transactions (title, amount, type, category, note)
SELECT 'Gaji Bulanan', 8500000.00, 'income', 'Gaji', 'Pemasukan utama bulan ini'
WHERE NOT EXISTS (SELECT 1 FROM transactions LIMIT 1);

INSERT INTO transactions (title, amount, type, category, note)
SELECT 'Belanja Mingguan & Kopi', 350000.00, 'expense', 'Makanan', 'Kebutuhan dapur dan ngopi'
WHERE (SELECT COUNT(*) FROM transactions) = 1;

INSERT INTO transactions (title, amount, type, category, note)
SELECT 'Langganan Internet & Cloud', 450000.00, 'expense', 'Tagihan', 'WiFi rumah & server belajar Docker'
WHERE (SELECT COUNT(*) FROM transactions) = 2;
