const ALLOWED_TYPES = ['income', 'expense'];

/**
 * Sanitize user input string by stripping HTML/script tags and trimming whitespace.
 */
function sanitizeString(value, maxLength = 150) {
  if (typeof value !== 'string') return '';
  return value
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
    .replace(/<[^>]*>/g, '')
    .trim()
    .slice(0, maxLength);
}

/**
 * Validate transaction creation payload.
 */
function validateTransactionInput(body) {
  const errors = [];
  if (!body || typeof body !== 'object') {
    return { valid: false, errors: ['Payload harus berupa JSON object'] };
  }

  const title = sanitizeString(body.title, 150);
  if (!title) {
    errors.push('Judul transaksi (title) wajib diisi');
  }

  const rawAmount = Number(body.amount);
  if (!Number.isFinite(rawAmount) || rawAmount <= 0) {
    errors.push('Nominal (amount) harus berupa angka lebih dari 0');
  } else if (rawAmount > 1_000_000_000_000) {
    errors.push('Nominal (amount) melebihi batas maksimum');
  }

  const type = typeof body.type === 'string' ? body.type.trim().toLowerCase() : '';
  if (!ALLOWED_TYPES.includes(type)) {
    errors.push("Tipe transaksi (type) harus 'income' atau 'expense'");
  }

  const category = sanitizeString(body.category, 60);
  if (!category) {
    errors.push('Kategori (category) wajib diisi');
  }

  const note = sanitizeString(body.note || '', 500);

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return {
    valid: true,
    data: {
      title,
      amount: Math.round(rawAmount * 100) / 100,
      type,
      category,
      note,
    },
  };
}

/**
 * Compute financial summary from a list of transactions.
 */
function computeSummary(transactions) {
  let totalIncome = 0;
  let totalExpense = 0;
  const byCategoryMap = new Map();

  for (const tx of transactions) {
    const amount = Number(tx.amount) || 0;
    if (tx.type === 'income') {
      totalIncome += amount;
    } else if (tx.type === 'expense') {
      totalExpense += amount;
    }

    const key = `${tx.type}:${tx.category}`;
    const existing = byCategoryMap.get(key) || {
      category: tx.category,
      type: tx.type,
      total: 0,
      count: 0,
    };
    existing.total = Math.round((existing.total + amount) * 100) / 100;
    existing.count += 1;
    byCategoryMap.set(key, existing);
  }

  totalIncome = Math.round(totalIncome * 100) / 100;
  totalExpense = Math.round(totalExpense * 100) / 100;
  const balance = Math.round((totalIncome - totalExpense) * 100) / 100;

  return {
    totalIncome,
    totalExpense,
    balance,
    transactionCount: transactions.length,
    byCategory: Array.from(byCategoryMap.values()).sort((a, b) => b.total - a.total),
  };
}

module.exports = {
  sanitizeString,
  validateTransactionInput,
  computeSummary,
};
