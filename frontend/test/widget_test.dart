import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dompetku_app/main.dart';
import 'package:dompetku_app/models/transaction_model.dart';
import 'package:dompetku_app/services/api_service.dart';

class FakeExpenseApiClient implements ExpenseApiClient {
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
    return created;
  }

  @override
  Future<void> deleteTransaction(int id) async {
    _items.removeWhere((tx) => tx.id == id);
  }
}

void main() {
  testWidgets('DompetKu renders balance summary, container badge, and transactions',
      (WidgetTester tester) async {
    final fakeApi = FakeExpenseApiClient();
    await tester.pumpWidget(DompetKuApp(apiClient: fakeApi));
    await tester.pumpAndSettle();

    expect(find.text('DompetKu Docker'), findsOneWidget);
    expect(find.byKey(const Key('docker-container-badge')), findsOneWidget);
    expect(find.text('Container: docker-test-container-01'), findsOneWidget);
    expect(find.text('Rp 8.450.000'), findsOneWidget);
    expect(find.text('Gaji Bulanan'), findsOneWidget);
    expect(find.text('Kopi & Sarapan'), findsOneWidget);
  });

  testWidgets('AddTransactionDialog validates empty fields and creates transaction',
      (WidgetTester tester) async {
    final fakeApi = FakeExpenseApiClient();
    await tester.pumpWidget(DompetKuApp(apiClient: fakeApi));
    await tester.pumpAndSettle();

    // Open Add Transaction Dialog
    await tester.tap(find.byKey(const Key('open-add-transaction-button')));
    await tester.pumpAndSettle();

    // Negative test: click Simpan without filling inputs
    await tester.tap(find.byKey(const Key('submit-transaction-button')));
    await tester.pumpAndSettle();

    expect(find.text('Judul transaksi wajib diisi'), findsOneWidget);
    expect(find.text('Nominal wajib diisi'), findsOneWidget);

    // Positive test: fill valid transaction and submit
    await tester.enterText(find.byKey(const Key('input-title')), 'Beli Buku Docker');
    await tester.enterText(find.byKey(const Key('input-amount')), '150000');
    await tester.tap(find.byKey(const Key('submit-transaction-button')));
    await tester.pumpAndSettle();

    expect(find.text('Beli Buku Docker'), findsOneWidget);
    expect(find.text('Rp 8.300.000'), findsOneWidget);
  });
}
