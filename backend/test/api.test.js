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
    async updateTransaction(id, data) {
      const idx = rows.findIndex((r) => r.id === id);
      if (idx === -1) return null;
      rows[idx] = {
        ...rows[idx],
        title: data.title,
        amount: data.amount,
        type: data.type,
        category: data.category,
        note: data.note || '',
      };
      return rows[idx];
    },
    async deleteTransaction(id) {
      const idx = rows.findIndex((r) => r.id === id);
      if (idx === -1) return false;
      rows.splice(idx, 1);
      return true;
    },
  };
}

function createFakeRedisCache() {
  let cachedSummary = null;
  return {
    async ping() {
      return true;
    },
    async getSummary() {
      return cachedSummary;
    },
    async setSummary(data) {
      cachedSummary = { ...data };
    },
    async invalidateSummary() {
      cachedSummary = null;
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

test('API Integration: Health, CRUD + Update, Redis Cache HIT/MISS & validation', async () => {
  const repo = createInMemoryRepo();
  const cache = createFakeRedisCache();
  const app = createApp(repo, cache);
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
    assert.equal(health.data.redis, 'connected');

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

    // 4. First Summary Call -> Redis Cache MISS
    const sumMiss = await requestJson(baseUrl, '/api/summary');
    assert.equal(sumMiss.status, 200);
    assert.equal(sumMiss.data.cacheStatus, 'MISS');
    assert.equal(sumMiss.data.balance, 2880000);

    // 5. Second Summary Call -> Redis Cache HIT
    const sumHit = await requestJson(baseUrl, '/api/summary');
    assert.equal(sumHit.status, 200);
    assert.equal(sumHit.data.cacheStatus, 'HIT');
    assert.equal(sumHit.data.balance, 2880000);

    // 6. Edit / Update Transaction (PUT) -> Invalidates Redis Cache
    const updatedExp = await requestJson(baseUrl, `/api/transactions/${exp.data.item.id}`, {
      method: 'PUT',
      body: {
        title: 'Beli Buku Docker & Kubernetes',
        amount: 200000,
        type: 'expense',
        category: 'Edukasi',
        note: 'Paket bundling',
      },
    });
    assert.equal(updatedExp.status, 200);
    assert.equal(updatedExp.data.item.title, 'Beli Buku Docker & Kubernetes');
    assert.equal(updatedExp.data.item.amount, 200000);

    // 7. Summary after PUT -> Cache MISS with updated balance (3000000 - 200000 = 2800000)
    const sumAfterPut = await requestJson(baseUrl, '/api/summary');
    assert.equal(sumAfterPut.status, 200);
    assert.equal(sumAfterPut.data.cacheStatus, 'MISS');
    assert.equal(sumAfterPut.data.balance, 2800000);

    // 8. Negative Test: Invalid PUT payload & 404 PUT
    const badPut = await requestJson(baseUrl, `/api/transactions/${exp.data.item.id}`, {
      method: 'PUT',
      body: { title: '', amount: -10, type: 'expense', category: 'Edukasi' },
    });
    assert.equal(badPut.status, 400);

    const notFoundPut = await requestJson(baseUrl, '/api/transactions/9999', {
      method: 'PUT',
      body: { title: 'Valid', amount: 10000, type: 'expense', category: 'Edukasi' },
    });
    assert.equal(notFoundPut.status, 404);

    // 9. Delete Transaction & 404 Check
    const del = await requestJson(baseUrl, `/api/transactions/${exp.data.item.id}`, {
      method: 'DELETE',
    });
    assert.equal(del.status, 200);
    assert.equal(del.data.deleted, true);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
