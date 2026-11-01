class ExpenseTransaction {
  final int id;
  final String title;
  final double amount;
  final String type; // 'income' | 'expense'
  final String category;
  final String note;
  final String createdAt;

  const ExpenseTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.note,
    required this.createdAt,
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

  const FinancialSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.transactionCount,
    required this.byCategory,
    required this.containerId,
  });

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
