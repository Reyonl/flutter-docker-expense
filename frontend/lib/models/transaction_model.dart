class ExpenseTransaction {
  final int id;
  final String title;
  final double amount;
  final String type; // 'income' | 'expense'
  final String category;
  final String note;
  final String createdAt;
  final String? docId;

  const ExpenseTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.note,
    required this.createdAt,
    this.docId,
  });

  bool get isIncome => type == 'income';

  factory ExpenseTransaction.fromJson(Map<String, dynamic> json) {
    return ExpenseTransaction(
      id: (json['id'] as num).toInt(),
      title: (json['title'] as String?) ?? '',
      amount: (json['amount'] as num).toDouble(),
      type: (json['type'] as String?) ?? 'expense',
      category: (json['category'] as String?) ?? 'Lainnya',
      note: (json['note'] as String?) ?? '',
      createdAt: (json['createdAt'] as String?) ?? '',
      docId: json['docId'] as String?,
    );
  }
}

class CategoryBreakdown {
  final String category;
  final String type;
  final double total;
  final int count;

  const CategoryBreakdown({
    required this.category,
    required this.type,
    required this.total,
    required this.count,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      category: (json['category'] as String?) ?? 'Lainnya',
      type: (json['type'] as String?) ?? 'expense',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class FinancialTier {
  final String currentLevel;
  final double targetBerikutnya;
  final double progressPercent;

  const FinancialTier({
    required this.currentLevel,
    required this.targetBerikutnya,
    required this.progressPercent,
  });

  factory FinancialTier.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const FinancialTier(
        currentLevel: 'Aman',
        targetBerikutnya: 104400000,
        progressPercent: 40.0,
      );
    }
    return FinancialTier(
      currentLevel: (json['currentLevel'] as String?) ?? 'Aman',
      targetBerikutnya: (json['targetBerikutnya'] as num?)?.toDouble() ?? 104400000,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 40.0,
    );
  }
}

class AssetPillars {
  final double dompetAkun;
  final double asetLikuid;
  final double asetTetap;

  const AssetPillars({
    required this.dompetAkun,
    required this.asetLikuid,
    required this.asetTetap,
  });

  factory AssetPillars.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AssetPillars(
        dompetAkun: 6654332.27,
        asetLikuid: 55990129.40,
        asetTetap: 0.0,
      );
    }
    return AssetPillars(
      dompetAkun: (json['dompetAkun'] as num?)?.toDouble() ?? 0.0,
      asetLikuid: (json['asetLikuid'] as num?)?.toDouble() ?? 0.0,
      asetTetap: (json['asetTetap'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BudgetPacingItem {
  final String label;
  final double spentOrSaved;
  final double budget;
  final int percent;
  final String status;

  const BudgetPacingItem({
    required this.label,
    required this.spentOrSaved,
    required this.budget,
    required this.percent,
    required this.status,
  });

  factory BudgetPacingItem.fromJson(Map<String, dynamic>? json, {String defaultStatus = 'Masih aman'}) {
    if (json == null) {
      return BudgetPacingItem(
        label: 'KEBUTUHAN',
        spentOrSaved: 0,
        budget: 0,
        percent: 0,
        status: defaultStatus,
      );
    }
    return BudgetPacingItem(
      label: (json['label'] as String?) ?? '',
      spentOrSaved: (json['spent'] as num?)?.toDouble() ?? (json['saved'] as num?)?.toDouble() ?? 0.0,
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      percent: (json['percent'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? defaultStatus,
    );
  }
}

class BudgetPacing {
  final int currentDay;
  final int totalDays;
  final BudgetPacingItem needs;
  final BudgetPacingItem wants;
  final BudgetPacingItem savings;

  const BudgetPacing({
    required this.currentDay,
    required this.totalDays,
    required this.needs,
    required this.wants,
    required this.savings,
  });

  factory BudgetPacing.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const BudgetPacing(
        currentDay: 9,
        totalDays: 30,
        needs: BudgetPacingItem(label: 'KEBUTUHAN', spentOrSaved: 3900000, budget: 5000000, percent: 78, status: 'Masih aman'),
        wants: BudgetPacingItem(label: 'KEINGINAN', spentOrSaved: 0, budget: 3000000, percent: 0, status: 'Masih aman'),
        savings: BudgetPacingItem(label: 'TABUNGAN', spentOrSaved: 2040000, budget: 2000000, percent: 102, status: 'Cepat sekali'),
      );
    }
    return BudgetPacing(
      currentDay: (json['currentDay'] as num?)?.toInt() ?? 9,
      totalDays: (json['totalDays'] as num?)?.toInt() ?? 30,
      needs: BudgetPacingItem.fromJson(json['needs'] as Map<String, dynamic>?, defaultStatus: 'Masih aman'),
      wants: BudgetPacingItem.fromJson(json['wants'] as Map<String, dynamic>?, defaultStatus: 'Masih aman'),
      savings: BudgetPacingItem.fromJson(json['savings'] as Map<String, dynamic>?, defaultStatus: 'Cepat sekali'),
    );
  }
}

class DailyActivity {
  final String date;
  final double income;
  final double expense;
  final int count;

  const DailyActivity({
    required this.date,
    required this.income,
    required this.expense,
    required this.count,
  });

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    return DailyActivity(
      date: (json['date'] as String?) ?? '',
      income: (json['income'] as num?)?.toDouble() ?? 0.0,
      expense: (json['expense'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ParsedAiTransaction {
  final String title;
  final double amount;
  final String type;
  final String category;
  final String wallet;
  final String date;
  final String advice;

  const ParsedAiTransaction({
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.wallet,
    required this.date,
    required this.advice,
  });

  factory ParsedAiTransaction.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? json;
    return ParsedAiTransaction(
      title: (data['title'] as String?) ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 25000.0,
      type: (data['type'] as String?) ?? 'expense',
      category: (data['category'] as String?) ?? 'Makanan',
      wallet: (data['wallet'] as String?) ?? 'Blu',
      date: (data['date'] as String?) ?? DateTime.now().toIso8601String().split('T')[0],
      advice: (json['advice'] as String?) ?? 'Nih aku buatin transaksinya ya.',
    );
  }
}

class FinancialSummary {
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final double netWorth;
  final double runwayMonths;
  final FinancialTier financialTier;
  final AssetPillars assetPillars;
  final BudgetPacing budgetPacing;
  final List<DailyActivity> dailyActivities;
  final int transactionCount;
  final List<CategoryBreakdown> byCategory;
  final String containerId;
  final String cacheStatus; // 'HIT' | 'MISS'
  final bool redisConnected;

  const FinancialSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    this.netWorth = 0.0,
    this.runwayMonths = 21.6,
    this.financialTier = const FinancialTier(
      currentLevel: 'Aman',
      targetBerikutnya: 104400000,
      progressPercent: 40.0,
    ),
    this.assetPillars = const AssetPillars(
      dompetAkun: 6654332.27,
      asetLikuid: 55990129.40,
      asetTetap: 0.0,
    ),
    this.budgetPacing = const BudgetPacing(
      currentDay: 9,
      totalDays: 30,
      needs: BudgetPacingItem(label: 'KEBUTUHAN', spentOrSaved: 3900000, budget: 5000000, percent: 78, status: 'Masih aman'),
      wants: BudgetPacingItem(label: 'KEINGINAN', spentOrSaved: 0, budget: 3000000, percent: 0, status: 'Masih aman'),
      savings: BudgetPacingItem(label: 'TABUNGAN', spentOrSaved: 2040000, budget: 2000000, percent: 102, status: 'Cepat sekali'),
    ),
    this.dailyActivities = const [],
    required this.transactionCount,
    required this.byCategory,
    required this.containerId,
    this.cacheStatus = 'MISS',
    this.redisConnected = true,
  });

  double get savingsRatePercent {
    if (totalIncome <= 0) return 0;
    return ((totalIncome - totalExpense) / totalIncome * 100).clamp(-100.0, 100.0);
  }

  double get expenseRatioPercent {
    if (totalIncome <= 0) return totalExpense > 0 ? 100.0 : 0.0;
    return (totalExpense / totalIncome * 100).clamp(0.0, 100.0);
  }

  List<CategoryBreakdown> get expenseCategories =>
      byCategory.where((c) => c.type == 'expense').toList();

  List<CategoryBreakdown> get incomeCategories =>
      byCategory.where((c) => c.type == 'income').toList();

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    final rawList = (json['byCategory'] as List<dynamic>?) ?? const [];
    final rawDaily = (json['dailyActivities'] as List<dynamic>?) ?? const [];
    final bal = (json['balance'] as num?)?.toDouble() ?? 0;
    final nw = (json['netWorth'] as num?)?.toDouble() ?? bal;

    return FinancialSummary(
      totalIncome: (json['totalIncome'] as num?)?.toDouble() ?? 0,
      totalExpense: (json['totalExpense'] as num?)?.toDouble() ?? 0,
      balance: bal,
      netWorth: nw,
      runwayMonths: (json['runwayMonths'] as num?)?.toDouble() ?? 21.6,
      financialTier: FinancialTier.fromJson(json['financialTier'] as Map<String, dynamic>?),
      assetPillars: AssetPillars.fromJson(json['assetPillars'] as Map<String, dynamic>?),
      budgetPacing: BudgetPacing.fromJson(json['budgetPacing'] as Map<String, dynamic>?),
      dailyActivities: rawDaily
          .whereType<Map<String, dynamic>>()
          .map(DailyActivity.fromJson)
          .toList(),
      transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
      byCategory: rawList
          .whereType<Map<String, dynamic>>()
          .map(CategoryBreakdown.fromJson)
          .toList(),
      containerId: (json['containerId'] as String?) ?? 'local-dev',
      cacheStatus: (json['cacheStatus'] as String?) ?? 'MISS',
      redisConnected: (json['redisConnected'] as bool?) ?? false,
    );
  }
}

String formatRupiah(double value) {
  final isNegative = value < 0;
  final absVal = value.abs().round();
  final digits = absVal.toString();
  final buffer = StringBuffer();

  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }

  return '${isNegative ? '- ' : ''}Rp ${buffer.toString()}';
}

String formatRupiahShort(double value) {
  final absVal = value.abs();
  final isNegative = value < 0;
  final prefix = isNegative ? '-' : '+';

  if (absVal >= 1000000000) {
    final formatted = (absVal / 1000000000).toStringAsFixed(1).replaceAll('.0', '');
    return '$prefix${formatted}M';
  } else if (absVal >= 1000000) {
    final formatted = (absVal / 1000000).toStringAsFixed(1).replaceAll('.0', '');
    return '$prefix${formatted}JT';
  } else if (absVal >= 1000) {
    final formatted = (absVal / 1000).toStringAsFixed(0);
    return '$prefix${formatted}RB';
  } else {
    return '$prefix${absVal.toStringAsFixed(0)}';
  }
}
