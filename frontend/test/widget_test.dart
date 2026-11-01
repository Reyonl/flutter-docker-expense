import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dompetku_app/main.dart';
import 'package:dompetku_app/models/transaction_model.dart';
import 'package:dompetku_app/services/api_service.dart';

class FakeExpenseApiClient implements ExpenseApiClient {
  String _cacheStatus = 'HIT';

  final List<ExpenseTransaction> _items = [
    const ExpenseTransaction(
      id: 1,
      title: 'Gaji Bulanan',
      amount: 8500000,
      type: 'income',
      category: 'Gaji',
      note: 'Pemasukan utama',
      createdAt: '2026-11-01T08:00:00Z',
    ),
    const ExpenseTransaction(
      id: 2,
      title: 'Kopi & Sarapan',
      amount: 50000,
      type: 'expense',
      category: 'Makanan',
      note: 'Ngopi pagi',
      createdAt: '2026-11-01T09:00:00Z',
    ),
  ];

  @override
  Future<FinancialSummary> fetchSummary() async {
    double inc = 0;
    double exp = 0;
    for (final tx in _items) {
      if (tx.isIncome) {
        inc += tx.amount;
      } else {
        exp += tx.amount;
      }
    }
    return FinancialSummary(
      totalIncome: inc,
      totalExpense: exp,
      balance: inc - exp,
      transactionCount: _items.length,
      byCategory: [
        CategoryBreakdown(
          category: 'Gaji',
          type: 'income',
          total: inc,
          count: 1,
        ),
        CategoryBreakdown(
          category: 'Makanan',
          type: 'expense',
          total: exp,
          count: 1,
        ),
      ],
      containerId: 'docker-test-container-01',
      cacheStatus: _cacheStatus,
      redisConnected: true,
    );
  }

  @override
  Future<List<ExpenseTransaction>> fetchTransactions({
    String? type,
    String? search,
  }) async {
    return _items.where((tx) {
      if (type != null && type.isNotEmpty && tx.type != type) return false;
      if (search != null && search.isNotEmpty) {
        return tx.title.toLowerCase().contains(search.toLowerCase());
      }
      return true;
    }).toList();
  }

  @override
  Future<ExpenseTransaction> createTransaction({
    required String title,
    required double amount,
    required String type,
    required String category,
    String note = '',
  }) async {
    final created = ExpenseTransaction(
      id: _items.length + 1,
      title: title,
      amount: amount,
      type: type,
      category: category,
      note: note,
      createdAt: '2026-11-01T10:00:00Z',
    );
    _items.insert(0, created);
    _cacheStatus = 'MISS';
    return created;
  }

  @override
  Future<ExpenseTransaction> updateTransaction({
    required int id,
    required String title,
    required double amount,
    required String type,
    required String category,
    String note = '',
  }) async {
    final index = _items.indexWhere((tx) => tx.id == id);
    final updated = ExpenseTransaction(
      id: id,
      title: title,
      amount: amount,
      type: type,
      category: category,
      note: note,
      createdAt: '2026-11-01T10:00:00Z',
    );
    if (index != -1) {
      _items[index] = updated;
    }
    _cacheStatus = 'MISS';
    return updated;
  }

  @override
  Future<void> deleteTransaction(int id) async {
    _items.removeWhere((tx) => tx.id == id);
    _cacheStatus = 'MISS';
  }

  @override
  Future<void> flushRedisCache() async {
    _cacheStatus = 'MISS';
  }
}

void main() {
  testWidgets(
      'DompetKu renders balance summary, Redis badge, container badge, and transactions',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fakeApi = FakeExpenseApiClient();
    await tester.pumpWidget(DompetKuApp(apiClient: fakeApi));
    await tester.pumpAndSettle();

    expect(find.text('DompetKu Docker'), findsOneWidget);
    expect(find.byKey(const Key('redis-cache-badge')), findsOneWidget);
    expect(find.text('Redis: HIT'), findsOneWidget);
    expect(find.byKey(const Key('docker-container-badge')), findsOneWidget);
    expect(find.text('Container: docker-test-container-01'), findsOneWidget);
    expect(find.byKey(const Key('donut-chart-card')), findsOneWidget);
    expect(find.byKey(const Key('cashflow-chart-card')), findsOneWidget);
    expect(find.text('Rp 8.450.000'), findsOneWidget);
    expect(find.text('Gaji Bulanan'), findsOneWidget);
    expect(find.text('Kopi & Sarapan'), findsOneWidget);
  });

  testWidgets(
      'TransactionFormDialog validates empty fields, creates transaction, and edits transaction',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fakeApi = FakeExpenseApiClient();
    await tester.pumpWidget(DompetKuApp(apiClient: fakeApi));
    await tester.pumpAndSettle();

    // 1. Open Add Transaction Dialog
    await tester.tap(find.byKey(const Key('open-add-transaction-button')));
    await tester.pumpAndSettle();

    // Negative test: click Simpan without filling inputs
    await tester.tap(find.byKey(const Key('submit-transaction-button')));
    await tester.pumpAndSettle();

    expect(find.text('Judul transaksi wajib diisi'), findsOneWidget);
    expect(find.text('Nominal wajib diisi'), findsOneWidget);

    // Positive test: fill valid transaction and submit
    await tester.enterText(
      find.byKey(const Key('input-title')),
      'Beli Buku Docker',
    );
    await tester.enterText(find.byKey(const Key('input-amount')), '150000');
    await tester.tap(find.byKey(const Key('submit-transaction-button')));
    await tester.pumpAndSettle();

    expect(find.text('Beli Buku Docker'), findsOneWidget);
    expect(find.text('Rp 8.300.000'), findsOneWidget);

    // 2. Edit existing transaction #2 ("Kopi & Sarapan" -> "Kopi Spesial", 100000)
    await tester.tap(find.byKey(const Key('edit-tx-2')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Transaksi'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('input-title')), 'Kopi Spesial');
    await tester.enterText(find.byKey(const Key('input-amount')), '100000');
    await tester.tap(find.byKey(const Key('submit-transaction-button')));
    await tester.pumpAndSettle();

    expect(find.text('Kopi Spesial'), findsOneWidget);
    expect(find.text('Rp 8.250.000'), findsOneWidget);
  });
}
