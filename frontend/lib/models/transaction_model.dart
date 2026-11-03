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

class FinancialSummary {
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final int transactionCount;
  final List<CategoryBreakdown> byCategory;
  final String containerId;
  final String cacheStatus; // 'HIT' | 'MISS'
  final bool redisConnected;

  const FinancialSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
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
    return FinancialSummary(
      totalIncome: (json['totalIncome'] as num?)?.toDouble() ?? 0,
      totalExpense: (json['totalExpense'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
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
