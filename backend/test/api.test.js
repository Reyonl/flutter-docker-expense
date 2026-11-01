const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { createApp } = require('../src/app');
const { validateTransactionInput, computeSummary } = require('../src/validator');

function createInMemoryRepo() {
  let seq = 1;
  const rows = [];
  return {
    async ping() {
      return true;
    },
    async listTransactions({ type, category, search } = {}) {
      return rows
        .filter((r) => (!type || r.type === type))
        .filter((r) => (!category || r.category === category))
        .filter((r) => {
          if (!search) return true;
          const q = search.toLowerCase();
          return (
            r.title.toLowerCase().includes(q) ||
            r.category.toLowerCase().includes(q) ||
            r.note.toLowerCase().includes(q)
          );
        })
        .slice()
        .reverse();
    },
    async createTransaction(data) {
      const item = {
        id: seq++,
        title: data.title,
        amount: data.amount,
        type: data.type,
        category: data.category,
        note: data.note || '',
        createdAt: new Date().toISOString(),
      };
      rows.push(item);
      return item;
    },
    async deleteTransaction(id) {
      const idx = rows.findIndex((r) => r.id === id);
      if (idx === -1) return false;
      rows.splice(idx, 1);
      return true;
    },
  };
}

async function requestJson(baseUrl, path, { method = 'GET', body } = {}) {
  const res = await fetch(`${baseUrl}${path}`, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json();
  return { status: res.status, data };
}

test('Unit: validateTransactionInput rejects negative/zero amounts and strips XSS', () => {
  const neg = validateTransactionInput({
    title: 'Makan',
    amount: -5000,
    type: 'expense',
    category: 'Makanan',
  });
  assert.equal(neg.valid, false);

  const xss = validateTransactionInput({
    title: '<script>alert("xss")</script>Nasi Padang',
    amount: 25000,
    type: 'expense',
    category: '<b>Makanan</b>',
    note: '<img src=x onerror=alert(1)>Pedas',
  });
  assert.equal(xss.valid, true);
  assert.equal(xss.data.title, 'Nasi Padang');
  assert.equal(xss.data.category, 'Makanan');
  assert.equal(xss.data.note, 'Pedas');
});

test('Unit: computeSummary calculates income, expense, and balance accurately', () => {
  const summary = computeSummary([
    { amount: 5000000, type: 'income', category: 'Gaji' },
    { amount: 150000, type: 'expense', category: 'Makanan' },
    { amount: 50000, type: 'expense', category: 'Makanan' },
  ]);
  assert.equal(summary.totalIncome, 5000000);
  assert.equal(summary.totalExpense, 200000);
  assert.equal(summary.balance, 4800000);
  assert.equal(summary.transactionCount, 3);
  assert.equal(summary.byCategory.length, 2);
});

test('API Integration: Health, CRUD transactions, validation & summary', async () => {
  const repo = createInMemoryRepo();
  const app = createApp(repo);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  const baseUrl = `http://127.0.0.1:${port}`;

  try {
    // 1. Healthcheck
    const health = await requestJson(baseUrl, '/api/health');
    assert.equal(health.status, 200);
    assert.equal(health.data.status, 'ok');
    assert.equal(health.data.db, 'connected');

    // 2. Create Income
    const inc = await requestJson(baseUrl, '/api/transactions', {
      method: 'POST',
      body: {
        title: 'Gaji Freelance',
        amount: 3000000,
        type: 'income',
        category: 'Gaji',
        note: 'Proyek Flutter Docker',
      },
    });
    assert.equal(inc.status, 201);
    assert.equal(inc.data.item.title, 'Gaji Freelance');

    // 3. Create Expense
    const exp = await requestJson(baseUrl, '/api/transactions', {
      method: 'POST',
      body: {
        title: 'Beli Buku Docker',
        amount: 120000,
        type: 'expense',
        category: 'Edukasi',
      },
    });
    assert.equal(exp.status, 201);

    // 4. Negative Test: Invalid payload
    const bad = await requestJson(baseUrl, '/api/transactions', {
      method: 'POST',
      body: {
        title: '',
        amount: -100,
        type: 'hutang',
        category: '',
      },
    });
    assert.equal(bad.status, 400);
    assert.ok(Array.isArray(bad.data.errors));
    assert.equal(bad.data.errors.length, 4);

    // 5. Summary Check
    const sum = await requestJson(baseUrl, '/api/summary');
    assert.equal(sum.status, 200);
    assert.equal(sum.data.totalIncome, 3000000);
    assert.equal(sum.data.totalExpense, 120000);
    assert.equal(sum.data.balance, 2880000);

    // 6. Delete Transaction & 404 Check
    const del = await requestJson(baseUrl, `/api/transactions/${exp.data.item.id}`, {
      method: 'DELETE',
    });
    assert.equal(del.status, 200);
    assert.equal(del.data.deleted, true);

    const delAgain = await requestJson(baseUrl, `/api/transactions/${exp.data.item.id}`, {
      method: 'DELETE',
    });
    assert.equal(delAgain.status, 404);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
