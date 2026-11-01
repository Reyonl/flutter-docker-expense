import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'models/transaction_model.dart';
import 'services/api_service.dart';
import 'widgets/charts_panel.dart';

void main() {
  runApp(
    DompetKuApp(
      apiClient: HttpExpenseApiClient(),
      firebaseClient: FirebaseExpenseApiClient(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
    ),
  );
}

class DompetKuColors {
  static const Color background = Color(0xFF0F172A);
  static const Color card = Color(0xFF192134);
  static const Color muted = Color(0xFF101A34);
  static const Color primary = Color(0xFF1E40AF);
  static const Color secondary = Color(0xFF3B82F6);
  static const Color incomeGreen = Color(0xFF059669);
  static const Color expenseRed = Color(0xFFDC2626);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color glassBorder = Color(0x1F94A3B8);
}

class DompetKuApp extends StatelessWidget {
  final ExpenseApiClient apiClient;
  final ExpenseApiClient? firebaseClient;

  const DompetKuApp({
    super.key,
    required this.apiClient,
    this.firebaseClient,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DompetKu Docker Pro — Fintech Expense & Firebase Cloud',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: DompetKuColors.background,
        colorScheme: const ColorScheme.dark(
          primary: DompetKuColors.secondary,
          secondary: DompetKuColors.incomeGreen,
          surface: DompetKuColors.card,
          error: DompetKuColors.expenseRed,
        ),
        useMaterial3: true,
      ),
      home: ExpenseDashboardPage(
        apiClient: apiClient,
        firebaseClient: firebaseClient,
      ),
    );
  }
}

class ExpenseDashboardPage extends StatefulWidget {
  final ExpenseApiClient apiClient;
  final ExpenseApiClient? firebaseClient;

  const ExpenseDashboardPage({
    super.key,
    required this.apiClient,
    this.firebaseClient,
  });

  @override
  State<ExpenseDashboardPage> createState() => _ExpenseDashboardPageState();
}

class _ExpenseDashboardPageState extends State<ExpenseDashboardPage> {
  FinancialSummary? _summary;
  List<ExpenseTransaction> _transactions = const [];
  bool _isLoading = true;
  bool _isSyncingFirebase = false;
  String? _errorMessage;
  String _selectedFilter = 'all'; // 'all' | 'income' | 'expense'
  String _searchQuery = '';
  String _activeEngine = 'docker'; // 'docker' | 'firebase'
  final TextEditingController _searchController = TextEditingController();

  ExpenseApiClient get _currentClient {
    if (_activeEngine == 'firebase') {
      return widget.firebaseClient ?? FirebaseExpenseApiClient();
    }
    return widget.apiClient;
  }

  static const List<String> _expenseCategories = [
    'Makanan',
    'Tagihan',
    'Transportasi',
    'Belanja',
    'Edukasi',
    'Hiburan',
    'Lainnya',
  ];

  static const List<String> _incomeCategories = [
    'Gaji',
    'Freelance',
    'Investasi',
    'Bonus',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = _currentClient;
      final results = await Future.wait([
        client.fetchSummary(),
        client.fetchTransactions(
          type: _selectedFilter == 'all' ? null : _selectedFilter,
          search: _searchQuery,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _summary = results[0] as FinancialSummary;
        _transactions = results[1] as List<ExpenseTransaction>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSyncToFirebase() async {
    if (_isSyncingFirebase) return;
    setState(() => _isSyncingFirebase = true);
    try {
      final dockerItems = await widget.apiClient.fetchTransactions();
      final fbClient = widget.firebaseClient;
      int syncedCount = 0;
      if (fbClient is FirebaseExpenseApiClient) {
        syncedCount = await fbClient.syncFromDocker(dockerItems);
      } else {
        final realFb = FirebaseExpenseApiClient();
        syncedCount = await realFb.syncFromDocker(dockerItems);
      }
      if (!mounted) return;
      setState(() {
        _isSyncingFirebase = false;
        _activeEngine = 'firebase';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Berhasil sinkronisasi $syncedCount transaksi dari Docker ke Firebase Cloud (dompetku-4a2e1)!',
          ),
          backgroundColor: DompetKuColors.incomeGreen,
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncingFirebase = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal sync ke Firebase: $e'),
          backgroundColor: DompetKuColors.expenseRed,
        ),
      );
    }
  }

  Future<void> _handleFlushRedis() async {
    try {
      await _currentClient.flushRedisCache();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Redis Cache di-flush! Memuat ulang dari PostgreSQL (status akan menjadi MISS)...',
          ),
          backgroundColor: DompetKuColors.card,
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal flush Redis: $e'),
          backgroundColor: DompetKuColors.expenseRed,
        ),
      );
    }
  }

  Future<void> _handleDelete(ExpenseTransaction tx) async {
    try {
      await _currentClient.deleteTransaction(tx.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaksi "${tx.title}" berhasil dihapus'),
          backgroundColor: DompetKuColors.card,
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus: $e'),
          backgroundColor: DompetKuColors.expenseRed,
        ),
      );
    }
  }

  Future<void> _openTransactionDialog({ExpenseTransaction? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => TransactionFormDialog(
        apiClient: _currentClient,
        expenseCategories: _expenseCategories,
        incomeCategories: _incomeCategories,
        existingTransaction: existing,
      ),
    );
    if (saved == true) {
      await _loadData();
    }
  }

  void _showAdminerGuideDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DompetKuColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: DompetKuColors.glassBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.storage_rounded, color: DompetKuColors.secondary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Panduan Database: Docker Adminer & Firebase Cloud',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Docker Local DB GUI (http://localhost:8081):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DompetKuColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            _CredentialItem(label: 'System', value: 'PostgreSQL'),
            _CredentialItem(label: 'Server', value: 'db'),
            _CredentialItem(label: 'Username', value: 'dompetku'),
            _CredentialItem(label: 'Password', value: 'dompetku_secret'),
            _CredentialItem(label: 'Database', value: 'dompetku_db'),
            SizedBox(height: 12),
            Text(
              '2. Production Cloud DB (Tanpa VPS):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DompetKuColors.warningAmber,
              ),
            ),
            SizedBox(height: 6),
            _CredentialItem(label: 'Project ID', value: 'dompetku-4a2e1'),
            _CredentialItem(label: 'Database', value: 'Cloud Firestore (asia-southeast2)'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category, bool isIncome) {
    switch (category.toLowerCase()) {
      case 'gaji':
      case 'freelance':
      case 'bonus':
        return Icons.payments_outlined;
      case 'investasi':
        return Icons.show_chart_rounded;
      case 'makanan':
        return Icons.restaurant_outlined;
      case 'tagihan':
        return Icons.receipt_long_outlined;
      case 'transportasi':
        return Icons.directions_car_outlined;
      case 'belanja':
        return Icons.shopping_bag_outlined;
      case 'edukasi':
        return Icons.school_outlined;
      case 'hiburan':
        return Icons.movie_outlined;
      default:
        return isIncome
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final isHit =
        summary?.cacheStatus == 'HIT' || summary?.cacheStatus == 'CLOUD';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: DompetKuColors.card,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DompetKuColors.primary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: DompetKuColors.secondary.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: DompetKuColors.secondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DompetKu Docker',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: DompetKuColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Hybrid Architecture: 5-Container Docker Stack + Firebase Cloud DB',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: DompetKuColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('adminer-info-button'),
            tooltip: 'Info Login Database GUI (Adminer :8081 & Firebase)',
            onPressed: _showAdminerGuideDialog,
            icon: const Icon(Icons.storage_rounded, size: 20),
          ),
          IconButton(
            key: const Key('flush-redis-button'),
            tooltip: 'Flush Redis Cache (Uji MISS vs HIT)',
            onPressed: _handleFlushRedis,
            icon: const Icon(Icons.cleaning_services_outlined, size: 20),
          ),
          IconButton(
            key: const Key('refresh-button'),
            tooltip: 'Muat Ulang Data (Uji Redis HIT)',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('open-add-transaction-button'),
        onPressed: () => _openTransactionDialog(),
        backgroundColor: DompetKuColors.secondary,
        foregroundColor: DompetKuColors.textPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Tambah Transaksi',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1020),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 88),
                children: [
                  if (summary != null) _buildDockerTelemetryStrip(summary, isHit),
                  if (_errorMessage != null) _buildErrorBanner(_errorMessage!),
                  _buildSummaryCards(summary),
                  const SizedBox(height: 10),
                  if (summary != null) ...[
                    FintechChartsPanel(summary: summary),
                    const SizedBox(height: 10),
                  ],
                  _buildFilterAndSearchBar(),
                  const SizedBox(height: 10),
                  _buildTransactionsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockerTelemetryStrip(FinancialSummary summary, bool isHit) {
    final badgeColor =
        isHit ? DompetKuColors.incomeGreen : DompetKuColors.warningAmber;
    final isDocker = _activeEngine == 'docker';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ChoiceChip(
            key: const Key('engine-docker-chip'),
            label: const Text('🐳 Docker Stack'),
            selected: isDocker,
            onSelected: (_) {
              if (_activeEngine != 'docker') {
                setState(() => _activeEngine = 'docker');
                _loadData();
              }
            },
            selectedColor: DompetKuColors.primary,
            backgroundColor: DompetKuColors.card,
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDocker
                  ? DompetKuColors.textPrimary
                  : DompetKuColors.textMuted,
            ),
          ),
          ChoiceChip(
            key: const Key('engine-firebase-chip'),
            label: const Text('🔥 Firebase Cloud (dompetku-4a2e1)'),
            selected: !isDocker,
            onSelected: (_) {
              if (_activeEngine != 'firebase') {
                setState(() => _activeEngine = 'firebase');
                _loadData();
              }
            },
            selectedColor: DompetKuColors.warningAmber.withValues(alpha: 0.28),
            backgroundColor: DompetKuColors.card,
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: !isDocker
                  ? DompetKuColors.warningAmber
                  : DompetKuColors.textMuted,
            ),
          ),
          ActionChip(
            key: const Key('sync-firebase-button'),
            avatar: _isSyncingFirebase
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.cloud_upload_outlined,
                    size: 14,
                    color: DompetKuColors.warningAmber,
                  ),
            label: Text(
              _isSyncingFirebase ? 'Syncing...' : 'Sync Docker ➔ Firebase',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DompetKuColors.textPrimary,
              ),
            ),
            backgroundColor: DompetKuColors.card,
            visualDensity: VisualDensity.compact,
            onPressed: _isSyncingFirebase ? null : _handleSyncToFirebase,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: DompetKuColors.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: DompetKuColors.secondary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.dns_outlined,
                  size: 13,
                  color: DompetKuColors.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Container: ${summary.containerId}',
                  key: const Key('docker-container-badge'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: DompetKuColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 14, color: badgeColor),
                const SizedBox(width: 4),
                Text(
                  'Redis: ${summary.cacheStatus}',
                  key: const Key('redis-cache-badge'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DompetKuColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DompetKuColors.expenseRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DompetKuColors.expenseRed),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: DompetKuColors.expenseRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: DompetKuColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: _loadData,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(FinancialSummary? summary) {
    final balance = summary?.balance ?? 0;
    final income = summary?.totalIncome ?? 0;
    final expense = summary?.totalExpense ?? 0;
    final savingsRate = summary?.savingsRatePercent ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        final cards = [
          _SummaryMetricCard(
            cardKey: const Key('summary-balance-card'),
            title: 'Total Saldo Bersih',
            value: formatRupiah(balance),
            subtitle:
                '${summary?.transactionCount ?? 0} transaksi • Rasio Tabungan ${savingsRate.toStringAsFixed(0)}%',
            icon: Icons.account_balance_wallet_outlined,
            accentColor: DompetKuColors.secondary,
            isPrimary: true,
          ),
          _SummaryMetricCard(
            cardKey: const Key('summary-income-card'),
            title: 'Total Pemasukan',
            value: formatRupiah(income),
            subtitle: '${summary?.incomeCategories.length ?? 0} kategori pemasukan',
            icon: Icons.trending_up_rounded,
            accentColor: DompetKuColors.incomeGreen,
          ),
          _SummaryMetricCard(
            cardKey: const Key('summary-expense-card'),
            title: 'Total Pengeluaran',
            value: formatRupiah(expense),
            subtitle: '${summary?.expenseCategories.length ?? 0} kategori pengeluaran',
            icon: Icons.trending_down_rounded,
            accentColor: DompetKuColors.expenseRed,
          ),
        ];

        if (isWide) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 14),
              Expanded(child: cards[1]),
              const SizedBox(width: 14),
              Expanded(child: cards[2]),
            ],
          );
        }

        return Column(
          children: [
            cards[0],
            const SizedBox(height: 12),
            cards[1],
            const SizedBox(height: 12),
            cards[2],
          ],
        );
      },
    );
  }

  Widget _buildFilterAndSearchBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DompetKuColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DompetKuColors.glassBorder),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip('all', 'Semua'),
              _buildFilterChip('income', 'Pemasukan'),
              _buildFilterChip('expense', 'Pengeluaran'),
            ],
          ),
          SizedBox(
            width: 280,
            child: TextField(
              key: const Key('search-input'),
              controller: _searchController,
              onSubmitted: (val) {
                setState(() => _searchQuery = val);
                _loadData();
              },
              decoration: InputDecoration(
                hintText: 'Cari transaksi / kategori...',
                hintStyle: const TextStyle(
                  color: DompetKuColors.textMuted,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: DompetKuColors.textMuted,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadData();
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: DompetKuColors.muted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: DompetKuColors.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: DompetKuColors.glassBorder),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _selectedFilter == value;
    return ChoiceChip(
      key: Key('filter-chip-$value'),
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedFilter = value);
        _loadData();
      },
      selectedColor: DompetKuColors.primary,
      backgroundColor: DompetKuColors.muted,
      labelStyle: TextStyle(
        color: selected ? DompetKuColors.textPrimary : DompetKuColors.textMuted,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _buildTransactionsSection() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: DompetKuColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DompetKuColors.glassBorder),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: DompetKuColors.textMuted,
            ),
            SizedBox(height: 10),
            Text(
              'Belum ada transaksi pada filter ini',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: DompetKuColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Riwayat Transaksi (${_transactions.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DompetKuColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Klik ikon pensil untuk Edit atau Hapus',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: DompetKuColors.textMuted),
                ),
              ),
            ],
          ),
        ),
        ..._transactions.map((tx) {
          final isIncome = tx.isIncome;
          final amountColor =
              isIncome ? DompetKuColors.incomeGreen : DompetKuColors.expenseRed;
          final prefix = isIncome ? '+ ' : '- ';

          return Container(
            key: ValueKey('tx-item-${tx.id}'),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: DompetKuColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DompetKuColors.glassBorder),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForCategory(tx.category, isIncome),
                  color: amountColor,
                ),
              ),
              title: Text(
                tx.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: DompetKuColors.textPrimary,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tx.note.isNotEmpty
                      ? '${tx.category} • ${tx.note}'
                      : tx.category,
                  style: const TextStyle(
                    color: DompetKuColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$prefix${formatRupiah(tx.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    key: Key('edit-tx-${tx.id}'),
                    tooltip: 'Edit Transaksi',
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: DompetKuColors.secondary,
                      size: 19,
                    ),
                    onPressed: () => _openTransactionDialog(existing: tx),
                  ),
                  IconButton(
                    key: Key('delete-tx-${tx.id}'),
                    tooltip: 'Hapus Transaksi',
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: DompetKuColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => _handleDelete(tx),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CredentialItem extends StatelessWidget {
  final String label;
  final String value;

  const _CredentialItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                color: DompetKuColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: DompetKuColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final Key? cardKey;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isPrimary;

  const _SummaryMetricCard({
    this.cardKey,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cardKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isPrimary
            ? LinearGradient(
                colors: [
                  DompetKuColors.primary.withValues(alpha: 0.65),
                  DompetKuColors.card,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPrimary ? null : DompetKuColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary
              ? DompetKuColors.secondary.withValues(alpha: 0.45)
              : DompetKuColors.glassBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: DompetKuColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: DompetKuColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: DompetKuColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionFormDialog extends StatefulWidget {
  final ExpenseApiClient apiClient;
  final List<String> expenseCategories;
  final List<String> incomeCategories;
  final ExpenseTransaction? existingTransaction;

  const TransactionFormDialog({
    super.key,
    required this.apiClient,
    required this.expenseCategories,
    required this.incomeCategories,
    this.existingTransaction,
  });

  @override
  State<TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<TransactionFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late String _selectedType;
  late String _selectedCategory;
  bool _isSubmitting = false;
  String? _submitError;

  bool get _isEditMode => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _amountController = TextEditingController(
      text: existing != null ? existing.amount.round().toString() : '',
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    _selectedType = existing?.type ?? 'expense';

    final allowed = _currentCategories;
    if (existing != null && allowed.contains(existing.category)) {
      _selectedCategory = existing.category;
    } else {
      _selectedCategory = allowed.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<String> get _currentCategories => _selectedType == 'income'
      ? widget.incomeCategories
      : widget.expenseCategories;

  Future<void> _submitForm() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final parsedAmount = double.parse(
        _amountController.text.replaceAll('.', '').replaceAll(',', '').trim(),
      );

      if (_isEditMode) {
        await widget.apiClient.updateTransaction(
          id: widget.existingTransaction!.id,
          title: _titleController.text.trim(),
          amount: parsedAmount,
          type: _selectedType,
          category: _selectedCategory,
          note: _noteController.text.trim(),
        );
      } else {
        await widget.apiClient.createTransaction(
          title: _titleController.text.trim(),
          amount: parsedAmount,
          type: _selectedType,
          category: _selectedCategory,
          note: _noteController.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DompetKuColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: DompetKuColors.glassBorder),
      ),
      title: Text(
        _isEditMode ? 'Edit Transaksi' : 'Tambah Transaksi Baru',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: DompetKuColors.textPrimary,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_submitError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DompetKuColors.expenseRed.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: DompetKuColors.expenseRed),
                    ),
                    child: Text(
                      _submitError!,
                      style: const TextStyle(
                        color: DompetKuColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'expense',
                      label: Text('Pengeluaran'),
                      icon: Icon(Icons.trending_down_rounded),
                    ),
                    ButtonSegment(
                      value: 'income',
                      label: Text('Pemasukan'),
                      icon: Icon(Icons.trending_up_rounded),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedType = selection.first;
                      _selectedCategory = _currentCategories.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('input-title'),
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul Transaksi',
                    hintText: 'Contoh: Makan Siang / Gaji Bulanan',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Judul transaksi wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('input-amount'),
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nominal (Rp)',
                    hintText: 'Contoh: 50000',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nominal wajib diisi';
                    }
                    final clean =
                        value.replaceAll('.', '').replaceAll(',', '').trim();
                    final parsed = double.tryParse(clean);
                    if (parsed == null || parsed <= 0) {
                      return 'Nominal harus berupa angka lebih dari 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey('category-$_selectedType'),
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  items: _currentCategories
                      .map(
                        (cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('input-note'),
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (Opsional)',
                    hintText: 'Keterangan tambahan...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          key: const Key('submit-transaction-button'),
          onPressed: _isSubmitting ? null : _submitForm,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(
            _isSubmitting
                ? 'Menyimpan...'
                : (_isEditMode ? 'Simpan Perubahan' : 'Simpan'),
          ),
        ),
      ],
    );
  }
}
