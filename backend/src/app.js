const express = require('express');
const cors = require('cors');
const os = require('os');
const { validateTransactionInput, computeSummary, sanitizeString } = require('./validator');

const noopCache = {
  async ping() {
    return false;
  },
  async getSummary() {
    return null;
  },
  async setSummary() {},
  async invalidateSummary() {},
};

function createApp(repository, cache = noopCache) {
  const app = express();

  app.disable('x-powered-by');
  app.use(cors());
  app.use(express.json({ limit: '100kb' }));

  // Security headers
  app.use((req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    next();
  });

  // Healthcheck & info container Docker + status PostgreSQL & Redis
  app.get('/api/health', async (req, res) => {
    try {
      const [dbOk, redisOk] = await Promise.all([
        repository.ping(),
        cache.ping().catch(() => false),
      ]);
      return res.status(dbOk ? 200 : 503).json({
        status: dbOk ? 'ok' : 'degraded',
        db: dbOk ? 'connected' : 'disconnected',
        redis: redisOk ? 'connected' : 'disconnected',
        containerId: os.hostname(),
        platform: `${os.type()} ${os.release()}`,
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      return res.status(503).json({
        status: 'error',
        db: 'disconnected',
        redis: 'disconnected',
        containerId: os.hostname(),
        error: err.message,
      });
    }
  });

  // Summary saldo, pemasukan, pengeluaran, breakdown kategori + Redis Cache HIT/MISS
  app.get('/api/summary', async (req, res) => {
    try {
      const cached = await cache.getSummary();
      if (cached) {
        return res.json({
          ...cached,
          cacheStatus: 'HIT',
          redisConnected: true,
          containerId: os.hostname(),
        });
      }

      const allTransactions = await repository.listTransactions({});
      const summary = computeSummary(allTransactions);
      await cache.setSummary(summary);
      const redisOk = await cache.ping().catch(() => false);

      return res.json({
        ...summary,
        cacheStatus: 'MISS',
        redisConnected: redisOk,
        containerId: os.hostname(),
      });
    } catch (err) {
      return res.status(500).json({ error: 'Gagal mengambil ringkasan keuangan', detail: err.message });
    }
  });

  // Endpoint interaktif untuk mengosongkan Redis Cache dari UI Flutter
  app.post('/api/cache/flush', async (req, res) => {
    try {
      await cache.invalidateSummary();
      return res.json({
        flushed: true,
        message: 'Redis cache berhasil dikosongkan. Request summary berikutnya akan bernilai MISS.',
        containerId: os.hostname(),
      });
    } catch (err) {
      return res.status(500).json({ error: 'Gagal mengosongkan cache', detail: err.message });
    }
  });

  // Daftar transaksi dengan filter opsional (?type=income|expense&category=...&search=...)
  app.get('/api/transactions', async (req, res) => {
    try {
      const type = req.query.type ? String(req.query.type).toLowerCase() : undefined;
      const category = req.query.category ? sanitizeString(String(req.query.category), 60) : undefined;
      const search = req.query.search ? sanitizeString(String(req.query.search), 100) : undefined;

      if (type && !['income', 'expense'].includes(type)) {
        return res.status(400).json({ error: "Filter type harus 'income' atau 'expense'" });
      }

      const items = await repository.listTransactions({ type, category, search });
      return res.json({
        items,
        count: items.length,
        containerId: os.hostname(),
      });
    } catch (err) {
      return res.status(500).json({ error: 'Gagal mengambil daftar transaksi', detail: err.message });
    }
  });

  // Tambah transaksi baru (otomatis invalidate Redis cache)
  app.post('/api/transactions', async (req, res) => {
    const validation = validateTransactionInput(req.body);
    if (!validation.valid) {
      return res.status(400).json({
        error: validation.errors[0],
        errors: validation.errors,
      });
    }

    try {
      const created = await repository.createTransaction(validation.data);
      await cache.invalidateSummary();
      return res.status(201).json({
        item: created,
        containerId: os.hostname(),
      });
    } catch (err) {
      return res.status(500).json({ error: 'Gagal menyimpan transaksi', detail: err.message });
    }
  });

  // Edit / Update transaksi berdasarkan ID (otomatis invalidate Redis cache)
  app.put('/api/transactions/:id', async (req, res) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ error: 'ID transaksi tidak valid' });
    }

    const validation = validateTransactionInput(req.body);
    if (!validation.valid) {
      return res.status(400).json({
        error: validation.errors[0],
        errors: validation.errors,
      });
    }

    try {
      const updated = await repository.updateTransaction(id, validation.data);
      if (!updated) {
        return res.status(404).json({ error: 'Transaksi tidak ditemukan' });
      }
      await cache.invalidateSummary();
      return res.json({
        item: updated,
        containerId: os.hostname(),
      });
    } catch (err) {
      return res.status(500).json({ error: 'Gagal memperbarui transaksi', detail: err.message });
    }
  });

  // Hapus transaksi berdasarkan ID (otomatis invalidate Redis cache)
  app.delete('/api/transactions/:id', async (req, res) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ error: 'ID transaksi tidak valid' });
    }

    try {
      const deleted = await repository.deleteTransaction(id);
      if (!deleted) {
        return res.status(404).json({ error: 'Transaksi tidak ditemukan' });
      }
      await cache.invalidateSummary();
      return res.json({
        deleted: true,
        id,
        containerId: os.hostname(),
      });
    } catch (err) {
      return res.status(500).json({ error: 'Gagal menghapus transaksi', detail: err.message });
    }
  });

  return app;
}

module.exports = { createApp };
