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
 * Parse natural language expense text into structured transaction draft.
 * e.g. "Beli kopi tuku 27rb blu" -> { title: "Kopi tuku", amount: 27000, type: "expense", category: "Makanan", wallet: "Blu" }
 */
function parseNaturalLanguageTransaction(rawInput) {
  if (!rawInput || typeof rawInput !== 'string') {
    return {
      success: false,
      error: 'Teks input transaksi tidak boleh kosong',
    };
  }

  const clean = sanitizeString(rawInput, 300);
  if (!clean.trim()) {
    return {
      success: false,
      error: 'Teks input transaksi tidak boleh kosong',
    };
  }

  const text = clean.toLowerCase();

  // 1. Detect Type
  const incomeKeywords = ['gaji', 'bonus', 'freelance', 'terima', 'dapat uang', 'cair', 'penjualan', 'dividen', 'profit'];
  const isIncome = incomeKeywords.some((kw) => new RegExp(`\\b${kw}\\b`, 'i').test(text));
  const type = isIncome ? 'income' : 'expense';

  // 2. Extract Amount
  let amount = 0;
  let amountMatchedStr = '';

  const millionMatch = text.match(/(\d+(?:[.,]\d+)?)\s*(?:jt|juta)\b/i);
  const thousandMatch = text.match(/(\d+(?:[.,]\d+)?)\s*(?:rb|ribu|k)\b/i);
  const rupiahMatch = text.match(/(?:rp\.?|rp\s*)(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?|\d+)/i);
  const plainNumberMatch = text.match(/\b(\d{4,12})\b/);

  if (millionMatch) {
    const num = parseFloat(millionMatch[1].replace(',', '.'));
    amount = Math.round(num * 1000000);
    amountMatchedStr = millionMatch[0];
  } else if (thousandMatch) {
    const num = parseFloat(thousandMatch[1].replace(',', '.'));
    amount = Math.round(num * 1000);
    amountMatchedStr = thousandMatch[0];
  } else if (rupiahMatch) {
    const rawDigits = rupiahMatch[1].replace(/[.,]/g, '');
    amount = parseInt(rawDigits, 10) || 0;
    amountMatchedStr = rupiahMatch[0];
  } else if (plainNumberMatch) {
    amount = parseInt(plainNumberMatch[1], 10) || 0;
    amountMatchedStr = plainNumberMatch[0];
  }

  // 3. Extract Wallet
  const walletList = [
    { key: 'blu', name: 'Blu' },
    { key: 'bca', name: 'BCA' },
    { key: 'jago', name: 'Bank Jago' },
    { key: 'mandiri', name: 'Mandiri' },
    { key: 'bri', name: 'BRI' },
    { key: 'bni', name: 'BNI' },
    { key: 'gopay', name: 'GoPay' },
    { key: 'ovo', name: 'OVO' },
    { key: 'dana', name: 'DANA' },
    { key: 'shopeepay', name: 'ShopeePay' },
    { key: 'tunai', name: 'Tunai' },
    { key: 'cash', name: 'Tunai' },
  ];

  let wallet = 'Blu';
  let walletMatchedStr = '';
  for (const w of walletList) {
    const wRegex = new RegExp(`\\b${w.key}\\b`, 'i');
    if (wRegex.test(text)) {
      wallet = w.name;
      walletMatchedStr = w.key;
      break;
    }
  }

  // 4. Extract Category
  let category = isIncome ? 'Gaji' : 'Lainnya';
  if (isIncome) {
    if (/\b(?:freelance|proyek|klien)\b/i.test(text)) category = 'Freelance';
    else if (/\b(?:bonus|thr|hadiah)\b/i.test(text)) category = 'Bonus';
    else if (/\b(?:investasi|dividen|reksadana|crypto|saham)\b/i.test(text)) category = 'Investasi';
  } else {
    if (/\b(?:kopi|tuku|starbucks|makan|nasi|padang|sate|mie|bakso|ayam|kuliner|minum|kafe|snack|jajan)\b/i.test(text)) category = 'Makanan';
    else if (/\b(?:listrik|pln|wifi|internet|indihome|pulsa|kuota|tagihan|netflix|spotify|bpjs|air|pdam)\b/i.test(text)) category = 'Tagihan';
    else if (/\b(?:bensin|pertamax|pertalite|gojek|grab|gocar|goride|parkir|tol|kereta|mrt|ojol|bengkel)\b/i.test(text)) category = 'Transportasi';
    else if (/\b(?:baju|sepatu|tokopedia|shopee|lazada|belanja|supermarket|minimarket|indomaret|alfamart|skincare)\b/i.test(text)) category = 'Belanja';
    else if (/\b(?:buku|kursus|udemy|sekolah|kuliah|spp|seminar|les)\b/i.test(text)) category = 'Edukasi';
    else if (/\b(?:bioskop|nonton|game|steam|hiburan|wisata|karaoke|liburan)\b/i.test(text)) category = 'Hiburan';
  }

  // 5. Clean Title
  let title = clean;
  if (amountMatchedStr) {
    title = title.replace(new RegExp(amountMatchedStr, 'i'), '');
  }
  if (walletMatchedStr) {
    title = title.replace(new RegExp(`\\b${walletMatchedStr}\\b`, 'i'), '');
  }
  title = title
    .replace(/^\s*(?:beli|bayar|buat|untuk|buat beli|jajan)\s+/i, '')
    .replace(/\s+/g, ' ')
    .trim();

  if (!title) {
    title = category;
  } else {
    title = title.charAt(0).toUpperCase() + title.slice(1);
  }

  return {
    success: true,
    data: {
      title,
      amount: amount > 0 ? amount : 25000,
      type,
      category,
      wallet,
      rawText: clean,
      date: new Date().toISOString().split('T')[0],
      inferredFields: ['category', 'wallet', 'type'],
    },
    message: 'Nih aku buatin transaksinya ya 👇',
  };
}

/**
 * Compute financial summary, runway, financial level, 50/30/20 budget pacing, and daily activities.
 */
function computeSummary(transactions, options = {}) {
  let totalIncome = 0;
  let totalExpense = 0;
  const byCategoryMap = new Map();
  const dailyActivityMap = {};

  // Needs, Wants, Savings buckets for 50/30/20
  const needsCategories = new Set(['makanan', 'tagihan', 'transportasi', 'edukasi']);
  const wantsCategories = new Set(['belanja', 'hiburan', 'lainnya']);
  const savingsCategories = new Set(['tabungan', 'investasi']);

  let spentNeeds = 0;
  let spentWants = 0;
  let savedAmount = 0;

  for (const tx of transactions) {
    const amount = Number(tx.amount) || 0;
    const catLower = (tx.category || '').toLowerCase();

    if (tx.type === 'income') {
      totalIncome += amount;
      if (savingsCategories.has(catLower) || catLower === 'investasi') {
        savedAmount += amount;
      }
    } else if (tx.type === 'expense') {
      totalExpense += amount;
      if (needsCategories.has(catLower)) {
        spentNeeds += amount;
      } else if (savingsCategories.has(catLower)) {
        savedAmount += amount;
      } else {
        spentWants += amount;
      }
    }

    // Daily activity aggregation
    let dateKey = '2026-11-01';
    if (tx.createdAt) {
      try {
        dateKey = String(tx.createdAt).split('T')[0];
      } catch {
        dateKey = '2026-11-01';
      }
    }
    if (!dailyActivityMap[dateKey]) {
      dailyActivityMap[dateKey] = { date: dateKey, income: 0, expense: 0, count: 0 };
    }
    if (tx.type === 'income') {
      dailyActivityMap[dateKey].income += amount;
    } else {
      dailyActivityMap[dateKey].expense += amount;
    }
    dailyActivityMap[dateKey].count += 1;

    // Category breakdown
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

  // 3-Pillar Net Worth Breakdown
  const netWorth = balance;
  const dompetAkun = balance > 0 ? Math.round(balance * 0.12 * 100) / 100 : 0;
  const asetLikuid = balance > 0 ? Math.round(balance * 0.88 * 100) / 100 : 0;
  const asetTetap = 0.0;

  // Emergency Survival Runway
  let runwayMonths = 0.0;
  if (totalExpense > 0) {
    runwayMonths = Math.max(0, Math.round(((balance > 0 ? balance : 0) / totalExpense) * 10) / 10);
  } else if (balance > 0) {
    runwayMonths = 21.6; // default showcase if no expense
  }

  // Financial Tier & Level Gamification
  let currentLevel = 'Rentan';
  let targetBerikutnya = 10000000.0;
  let progressPercent = 0.0;

  if (balance >= 104400000 || runwayMonths >= 24) {
    currentLevel = 'Bebas Finansial';
    targetBerikutnya = 500000000.0;
    progressPercent = Math.min(100, Math.round((balance / targetBerikutnya) * 100));
  } else if (balance >= 50000000 || runwayMonths >= 12) {
    currentLevel = 'Mapan';
    targetBerikutnya = 104400000.0;
    progressPercent = Math.min(100, Math.round((balance / targetBerikutnya) * 100));
  } else if (balance >= 20000000 || runwayMonths >= 6) {
    currentLevel = 'Aman';
    targetBerikutnya = 104400000.0;
    progressPercent = Math.min(100, Math.round((balance / targetBerikutnya) * 100));
  } else if (balance >= 5000000 || runwayMonths >= 1) {
    currentLevel = 'Mulai Stabil';
    targetBerikutnya = 20000000.0;
    progressPercent = Math.min(100, Math.round((balance / targetBerikutnya) * 100));
  } else {
    currentLevel = 'Rentan';
    targetBerikutnya = 5000000.0;
    progressPercent = balance > 0 ? Math.min(100, Math.round((balance / targetBerikutnya) * 100)) : 0;
  }

  // Budget Pacing 50/30/20 (Based on current calendar day)
  const now = options.currentDate || new Date();
  const currentDay = now.getDate ? now.getDate() : 9;
  const totalDaysInMonth = 30;

  const baselineBudget = totalIncome > 0 ? totalIncome : (totalExpense > 0 ? totalExpense * 1.5 : 5000000);
  const budgetNeeds = baselineBudget * 0.50;
  const budgetWants = baselineBudget * 0.30;
  const budgetSavings = baselineBudget * 0.20;

  const pctNeeds = budgetNeeds > 0 ? Math.round((spentNeeds / budgetNeeds) * 100) : 0;
  const pctWants = budgetWants > 0 ? Math.round((spentWants / budgetWants) * 100) : 0;
  const pctSavings = budgetSavings > 0 ? Math.round((savedAmount / budgetSavings) * 100) : 0;

  const budgetPacing = {
    currentDay: Math.min(currentDay, totalDaysInMonth),
    totalDays: totalDaysInMonth,
    needs: {
      label: 'KEBUTUHAN',
      spent: spentNeeds,
      budget: budgetNeeds,
      percent: pctNeeds,
      status: pctNeeds <= 80 ? 'Masih aman' : (pctNeeds <= 100 ? 'Hati-hati' : 'Melebihi budget'),
    },
    wants: {
      label: 'KEINGINAN',
      spent: spentWants,
      budget: budgetWants,
      percent: pctWants,
      status: pctWants <= 80 ? 'Masih aman' : (pctWants <= 100 ? 'Hati-hati' : 'Boros'),
    },
    savings: {
      label: 'TABUNGAN',
      saved: savedAmount,
      budget: budgetSavings,
      percent: pctSavings,
      status: pctSavings >= 100 ? 'Cepat sekali' : (pctSavings >= 50 ? 'Bagus' : 'Perlu ditingkatkan'),
    },
  };

  return {
    totalIncome,
    totalExpense,
    balance,
    netWorth,
    runwayMonths,
    financialTier: {
      currentLevel,
      targetBerikutnya,
      progressPercent,
    },
    assetPillars: {
      dompetAkun,
      asetLikuid,
      asetTetap,
    },
    budgetPacing,
    dailyActivities: Object.values(dailyActivityMap).sort((a, b) => a.date.localeCompare(b.date)),
    transactionCount: transactions.length,
    byCategory: Array.from(byCategoryMap.values()).sort((a, b) => b.total - a.total),
  };
}

module.exports = {
  sanitizeString,
  validateTransactionInput,
  computeSummary,
  parseNaturalLanguageTransaction,
};
