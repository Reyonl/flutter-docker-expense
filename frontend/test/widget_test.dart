import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dompetku_app/main.dart';
import 'package:dompetku_app/models/transaction_model.dart';
import 'package:dompetku_app/services/api_service.dart';

class FakeExpenseApiClient implements ExpenseApiClient {
  String _cacheStatus;
  final String containerId;
  final List<ExpenseTransaction> _items;

  FakeExpenseApiClient({
    String cacheStatus = 'HIT',
    this.containerId = 'docker-test-container-01',
    List<ExpenseTransaction>? initialItems,
  })  : _cacheStatus = cacheStatus,
        _items = initialItems ??
            [
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
      containerId: containerId,
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
  Future<void> deleteTransaction(int id, {String? docId}) async {
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
      'DompetKu renders balance summary, charts, and telemetry in Settings Dialog',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fakeApi = FakeExpenseApiClient();
    await tester.pumpWidget(DompetKuApp(apiClient: fakeApi));
    await tester.pumpAndSettle();

    // Verify main screen is clean (no dev telemetry strip by default)
    expect(find.text('DompetKu Docker'), findsOneWidget);
    expect(find.byKey(const Key('home-redis-cache-badge')), findsNothing);
    expect(find.byKey(const Key('donut-chart-card')), findsOneWidget);
    expect(find.byKey(const Key('income-donut-chart-card')), findsOneWidget);
    expect(find.byKey(const Key('cashflow-chart-card')), findsOneWidget);
    expect(find.text('Rp 8.450.000'), findsOneWidget);
    expect(find.text('Gaji Bulanan'), findsOneWidget);
    expect(find.text('Kopi & Sarapan'), findsOneWidget);

    // Open Settings & Backend Dialog
    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Pengaturan & Backend'), findsOneWidget);
    expect(find.byKey(const Key('redis-cache-badge')), findsOneWidget);
    expect(find.text('Redis: HIT'), findsOneWidget);
    expect(find.byKey(const Key('docker-container-badge')), findsOneWidget);
    expect(find.text('Container: docker-test-container-01'), findsOneWidget);

    // Close Dialog
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'Theme Toggle switches between Dark Mode and Light Mode',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fakeApi = FakeExpenseApiClient();
    await tester.pumpWidget(DompetKuApp(apiClient: fakeApi));
    await tester.pumpAndSettle();

    final themeBtn = find.byKey(const Key('theme-toggle-button'));
    expect(themeBtn, findsOneWidget);

    // Initial is Dark mode (Sun icon for switching to light)
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

    // Tap to switch to Light mode
    await tester.tap(themeBtn);
    await tester.pumpAndSettle();

    // Now in Light mode (Moon icon for switching back to dark)
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);

    // Tap again to switch back to Dark mode
    await tester.tap(themeBtn);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
  });

  testWidgets(
      'Analysis Tab displays dedicated Donut Pengeluaran, Donut Pemasukan, and Category Breakdown',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fakeApi = FakeExpenseApiClient();
    await tester.pumpWidget(DompetKuApp(apiClient: fakeApi));
    await tester.pumpAndSettle();

    // Tap on Tab Analisis & Chart
    final analysisTab = find.byKey(const Key('tab-analysis'));
    expect(analysisTab, findsOneWidget);
    await tester.tap(analysisTab);
    await tester.pumpAndSettle();

    // Verify Analysis View Elements
    expect(find.text('Analisis & Chart'), findsWidgets);
    expect(find.byKey(const Key('donut-chart-card')), findsOneWidget);
    expect(find.byKey(const Key('income-donut-chart-card')), findsOneWidget);
    expect(find.byKey(const Key('cashflow-chart-card')), findsOneWidget);
    expect(find.text('Rincian per Kategori (2)'), findsOneWidget);
    expect(find.text('Total: 2 Transaksi'), findsOneWidget);
  });

  testWidgets(
      'TransactionFormDialog validates empty fields, creates transaction, and edits transaction',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
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
    await tester.ensureVisible(find.byKey(const Key('edit-tx-2')));
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

  testWidgets(
      'Engine Switcher toggles between Docker Stack and Firebase Cloud (dompetku-4a2e1) in Settings',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fakeDocker = FakeExpenseApiClient();
    final fakeFirebase = FakeExpenseApiClient(
      cacheStatus: 'CLOUD',
      containerId: 'firebase:dompetku-4a2e1',
      initialItems: const [
        ExpenseTransaction(
          id: 99,
          title: 'Saldo Cloud Firestore',
          amount: 12000000,
          type: 'income',
          category: 'Gaji',
          note: 'Serverless Cloud DB',
          createdAt: '2026-11-01T11:00:00Z',
        ),
      ],
    );

    await tester.pumpWidget(
      DompetKuApp(apiClient: fakeDocker, firebaseClient: fakeFirebase),
    );
    await tester.pumpAndSettle();

    // Open Settings dialog
    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Container: docker-test-container-01'), findsOneWidget);

    // Switch to Firebase Cloud engine
    await tester.tap(find.byKey(const Key('engine-firebase-chip')));
    await tester.pumpAndSettle();

    expect(find.text('Container: firebase:dompetku-4a2e1'), findsOneWidget);
    expect(find.text('Redis: CLOUD'), findsOneWidget);

    // Close Dialog and verify main dashboard rendered Firebase items
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    expect(find.text('Saldo Cloud Firestore'), findsOneWidget);
    expect(find.text('Rp 12.000.000'), findsWidgets);
  });

  testWidgets(
      'Settings Dialog allows toggling Developer Telemetry bar on home screen',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fakeApi = FakeExpenseApiClient();
    await tester.pumpWidget(DompetKuApp(apiClient: fakeApi));
    await tester.pumpAndSettle();

    // Telemetry strip is hidden on home screen by default
    expect(find.byKey(const Key('home-redis-cache-badge')), findsNothing);

    // Open Settings dialog
    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    // Toggle on "Tampilkan Bar Telemetri di Beranda"
    await tester.tap(find.byKey(const Key('toggle-dev-telemetry-switch')));
    await tester.pumpAndSettle();

    // Close Settings
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    // Telemetry strip is now visible on home screen!
    expect(find.byKey(const Key('home-redis-cache-badge')), findsOneWidget);
    expect(find.text('Redis: HIT'), findsOneWidget);
    expect(find.byKey(const Key('home-docker-container-badge')), findsOneWidget);
  });

  testWidgets(
      'Transaction deletion works via card confirmation dialog and edit dialog',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fakeApi = FakeExpenseApiClient();
    await tester.pumpWidget(DompetKuApp(apiClient: fakeApi));
    await tester.pumpAndSettle();

    expect(find.text('Kopi & Sarapan'), findsOneWidget);

    // 1. Delete via card delete button
    await tester.tap(find.byKey(const Key('delete-tx-2')));
    await tester.pumpAndSettle();

    expect(find.text('Hapus Transaksi?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete-button')));
    await tester.pumpAndSettle();

    expect(find.text('Kopi & Sarapan'), findsNothing);

    // 2. Delete remaining transaction ("Gaji Bulanan") via Edit dialog delete button
    await tester.tap(find.byKey(const Key('edit-tx-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-delete-tx-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dialog-delete-tx-button')));
    await tester.pumpAndSettle();

    // Confirm inside dialog
    expect(find.text('Hapus Transaksi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();

    expect(find.text('Gaji Bulanan'), findsNothing);
  });
}
