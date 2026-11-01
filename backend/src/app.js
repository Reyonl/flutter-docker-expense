const express = require('express');
const cors = require('cors');
const os = require('os');
const { validateTransactionInput, computeSummary, sanitizeString } = require('./validator');

function createApp(repository) {
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

  // Healthcheck & info container Docker
  app.get('/api/health', async (req, res) => {
    try {
      const dbOk = await repository.ping();
      return res.status(dbOk ? 200 : 503).json({
        status: dbOk ? 'ok' : 'degraded',
        db: dbOk ? 'connected' : 'disconnected',
        containerId: os.hostname(),
        platform: `${os.type()} ${os.release()}`,
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      return res.status(503).json({
        status: 'error',
        db: 'disconnected',
        containerId: os.hostname(),
        error: err.message,
      });
    }
  });

  // Summary saldo, pemasukan, pengeluaran, dan breakdown kategori
  app.get('/api/summary', async (req, res) => {
    try {
      const allTransactions = await repository.listTransactions({});
      const summary = computeSummary(allTransactions);
      return res.json({
        ...summary,
        containerId: os.hostname(),
      });
    } catch (err) {
      return res.status(500).json({ error: 'Gagal mengambil ringkasan keuangan', detail: err.message });
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

  // Tambah transaksi baru
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
      return res.status(201).json({
        item: created,
        containerId: os.hostname(),
      });
    } catch (err) {
      return res.status(500).json({ error: 'Gagal menyimpan transaksi', detail: err.message });
    }
  });

  // Hapus transaksi berdasarkan ID
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
