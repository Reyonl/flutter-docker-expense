import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
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

class DompetKuTheme {
  // Dark Palette
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF192134);
  static const Color darkMuted = Color(0xFF101A34);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextMuted = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0x1F94A3B8);

  // Light Palette
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightMuted = Color(0xFFF1F5F9);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextMuted = Color(0xFF64748B);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Accent Colors
  static const Color primary = Color(0xFF1E40AF);
  static const Color secondary = Color(0xFF3B82F6);
  static const Color incomeGreen = Color(0xFF059669);
  static const Color expenseRed = Color(0xFFDC2626);
  static const Color warningAmber = Color(0xFFF59E0B);
}

class DompetKuApp extends StatefulWidget {
  final ExpenseApiClient apiClient;
  final ExpenseApiClient? firebaseClient;

  const DompetKuApp({
    super.key,
    required this.apiClient,
    this.firebaseClient,
  });

  @override
  State<DompetKuApp> createState() => _DompetKuAppState();
}

class _DompetKuAppState extends State<DompetKuApp> {
  bool _isDarkMode = true;

  void _toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DompetKu Pro — Fintech Expense & Firebase Cloud',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: DompetKuTheme.lightBg,
        colorScheme: const ColorScheme.light(
          primary: DompetKuTheme.secondary,
          secondary: DompetKuTheme.incomeGreen,
          surface: DompetKuTheme.lightCard,
          error: DompetKuTheme.expenseRed,
        ),
        cardColor: DompetKuTheme.lightCard,
        dividerColor: DompetKuTheme.lightBorder,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: DompetKuTheme.darkBg,
        colorScheme: const ColorScheme.dark(
          primary: DompetKuTheme.secondary,
          secondary: DompetKuTheme.incomeGreen,
          surface: DompetKuTheme.darkCard,
          error: DompetKuTheme.expenseRed,
        ),
        cardColor: DompetKuTheme.darkCard,
        dividerColor: DompetKuTheme.darkBorder,
        useMaterial3: true,
      ),
      home: ExpenseDashboardPage(
        apiClient: widget.apiClient,
        firebaseClient: widget.firebaseClient,
        isDarkMode: _isDarkMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class ExpenseDashboardPage extends StatefulWidget {
  final ExpenseApiClient apiClient;
  final ExpenseApiClient? firebaseClient;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const ExpenseDashboardPage({
    super.key,
    required this.apiClient,
    this.firebaseClient,
    required this.isDarkMode,
    required this.onToggleTheme,
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
  String _activeTab = 'transactions'; // 'transactions' | 'analysis'
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
    // Jika berjalan di Android APK fisik (HttpExpenseApiClient), default ke Firebase Cloud
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        widget.apiClient is HttpExpenseApiClient) {
      _activeEngine = 'firebase';
    }
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
      if (_activeEngine == 'docker' && widget.apiClient is HttpExpenseApiClient) {
        try {
          final fb = widget.firebaseClient ?? FirebaseExpenseApiClient();
          final fbResults = await Future.wait([
            fb.fetchSummary(),
            fb.fetchTransactions(
              type: _selectedFilter == 'all' ? null : _selectedFilter,
              search: _searchQuery,
            ),
          ]);
          if (!mounted) return;
          setState(() {
            _activeEngine = 'firebase';
            _summary = fbResults[0] as FinancialSummary;
            _transactions = fbResults[1] as List<ExpenseTransaction>;
            _isLoading = false;
          });
          return;
        } catch (_) {}
      }

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
          backgroundColor: DompetKuTheme.incomeGreen,
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncingFirebase = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal sync ke Firebase: $e'),
          backgroundColor: DompetKuTheme.expenseRed,
        ),
      );
    }
  }

  Future<void> _handleFlushRedis() async {
    try {
      await _currentClient.flushRedisCache();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Redis Cache di-flush! Memuat ulang dari PostgreSQL (status akan menjadi MISS)...',
          ),
          backgroundColor: widget.isDarkMode ? DompetKuTheme.darkCard : DompetKuTheme.lightCard,
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal flush Redis: $e'),
          backgroundColor: DompetKuTheme.expenseRed,
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
          backgroundColor: widget.isDarkMode ? DompetKuTheme.darkCard : DompetKuTheme.lightCard,
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus: $e'),
          backgroundColor: DompetKuTheme.expenseRed,
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
        isDark: widget.isDarkMode,
      ),
    );
    if (saved == true) {
      await _loadData();
    }
  }

  void _showAdminerGuideDialog() {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? DompetKuTheme.darkCard : DompetKuTheme.lightCard;
    final border = isDark ? DompetKuTheme.darkBorder : DompetKuTheme.lightBorder;
    final textPrimary = isDark ? DompetKuTheme.darkText : DompetKuTheme.lightText;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
        title: const Row(
          children: [
            Icon(Icons.storage_rounded, color: DompetKuTheme.secondary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Panduan Database: Docker & Firebase Cloud',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Docker Local DB GUI (http://localhost:8081):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _CredentialItem(label: 'System', value: 'PostgreSQL', isDark: isDark),
            _CredentialItem(label: 'Server', value: 'db', isDark: isDark),
            _CredentialItem(label: 'Username', value: 'dompetku', isDark: isDark),
            _CredentialItem(label: 'Password', value: 'dompetku_secret', isDark: isDark),
            _CredentialItem(label: 'Database', value: 'dompetku_db', isDark: isDark),
            const SizedBox(height: 12),
            const Text(
              '2. Production Cloud DB (Tanpa VPS):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DompetKuTheme.warningAmber,
              ),
            ),
            const SizedBox(height: 6),
            _CredentialItem(label: 'Project ID', value: 'dompetku-4a2e1', isDark: isDark),
            _CredentialItem(
              label: 'Database',
              value: 'Cloud Firestore (asia-southeast2)',
              isDark: isDark,
            ),
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
    final isDark = widget.isDarkMode;
    final summary = _summary;
    final isHit = summary?.cacheStatus == 'HIT' || summary?.cacheStatus == 'CLOUD';

    final cardBg = isDark ? DompetKuTheme.darkCard : DompetKuTheme.lightCard;
    final textPrimary = isDark ? DompetKuTheme.darkText : DompetKuTheme.lightText;
    final textMuted = isDark ? DompetKuTheme.darkTextMuted : DompetKuTheme.lightTextMuted;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: DompetKuTheme.secondary.withValues(alpha: 0.45),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/icon/app_icon.png',
                key: const Key('app-header-logo'),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: DompetKuTheme.secondary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DompetKu Docker',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Hybrid Fintech • Docker Stack & Firebase Cloud',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('theme-toggle-button'),
            tooltip: isDark ? 'Beralih ke Light Mode' : 'Beralih ke Dark Mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
              color: isDark ? DompetKuTheme.warningAmber : DompetKuTheme.secondary,
            ),
          ),
          IconButton(
            key: const Key('adminer-info-button'),
            tooltip: 'Info Login Database (Adminer :8081 & Firebase)',
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
        backgroundColor: DompetKuTheme.secondary,
        foregroundColor: Colors.white,
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
              constraints: const BoxConstraints(maxWidth: 1040),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 92),
                children: [
                  if (summary != null)
                    _buildDockerTelemetryStrip(summary, isHit, isDark),
                  if (_errorMessage != null)
                    _buildErrorBanner(_errorMessage!),
                  _buildSummaryCards(summary, isDark),
                  const SizedBox(height: 12),
                  _buildSectionNavigator(isDark),
                  const SizedBox(height: 12),
                  if (_activeTab == 'analysis') ...[
                    if (summary != null)
                      FintechChartsPanel(summary: summary, isDark: isDark),
                    const SizedBox(height: 14),
                    _buildDetailedBreakdownSection(summary, isDark),
                  ] else ...[
                    if (summary != null) ...[
                      FintechChartsPanel(summary: summary, isDark: isDark),
                      const SizedBox(height: 10),
                    ],
                    _buildFilterAndSearchBar(isDark),
                    const SizedBox(height: 10),
                    _buildTransactionsSection(isDark),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionNavigator(bool isDark) {
    final isTrans = _activeTab == 'transactions';
    final cardBg = isDark ? DompetKuTheme.darkCard : DompetKuTheme.lightCard;
    final border = isDark ? DompetKuTheme.darkBorder : DompetKuTheme.lightBorder;
    final textMuted = isDark ? DompetKuTheme.darkTextMuted : DompetKuTheme.lightTextMuted;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('tab-transactions'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _activeTab = 'transactions'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isTrans ? DompetKuTheme.secondary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 16,
                      color: isTrans ? Colors.white : textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Daftar Transaksi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isTrans ? Colors.white : textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              key: const Key('tab-analysis'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _activeTab = 'analysis'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: !isTrans ? DompetKuTheme.secondary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.analytics_rounded,
                      size: 16,
                      color: !isTrans ? Colors.white : textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Analisis & Chart',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: !isTrans ? Colors.white : textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedBreakdownSection(FinancialSummary? summary, bool isDark) {
    if (summary == null || summary.byCategory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? DompetKuTheme.darkCard : DompetKuTheme.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? DompetKuTheme.darkBorder : DompetKuTheme.lightBorder,
          ),
        ),
        child: Text(
          'Belum ada transaksi untuk dianalisis',
          style: TextStyle(
            color: isDark ? DompetKuTheme.darkTextMuted : DompetKuTheme.lightTextMuted,
          ),
        ),
      );
    }

    final cardBg = isDark ? DompetKuTheme.darkCard : DompetKuTheme.lightCard;
    final border = isDark ? DompetKuTheme.darkBorder : DompetKuTheme.lightBorder;
    final textPrimary = isDark ? DompetKuTheme.darkText : DompetKuTheme.lightText;
    final textMuted = isDark ? DompetKuTheme.darkTextMuted : DompetKuTheme.lightTextMuted;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rincian per Kategori (${summary.byCategory.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Text(
                'Total: ${summary.transactionCount} Transaksi',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...summary.byCategory.map((cat) {
            final isInc = cat.type == 'income';
            final color = isInc ? DompetKuTheme.incomeGreen : DompetKuTheme.expenseRed;
            final baseTotal = isInc ? summary.totalIncome : summary.totalExpense;
            final pct = baseTotal > 0 ? (cat.total / baseTotal * 100) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _iconForCategory(cat.category, isInc),
                      size: 18,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          '${cat.count} transaksi • ${pct.toStringAsFixed(1)}% dari ${isInc ? "pemasukan" : "pengeluaran"}',
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatRupiah(cat.total),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDockerTelemetryStrip(
    FinancialSummary summary,
    bool isHit,
    bool isDark,
  ) {
    final badgeColor = isHit ? DompetKuTheme.incomeGreen : DompetKuTheme.warningAmber;
    final isDocker = _activeEngine == 'docker';
    final cardBg = isDark ? DompetKuTheme.darkCard : DompetKuTheme.lightCard;
    final textMuted = isDark ? DompetKuTheme.darkTextMuted : DompetKuTheme.lightTextMuted;
    final textPrimary = isDark ? DompetKuTheme.darkText : DompetKuTheme.lightText;

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
            selectedColor: DompetKuTheme.primary,
            backgroundColor: cardBg,
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDocker ? Colors.white : textMuted,
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
            selectedColor: DompetKuTheme.warningAmber.withValues(alpha: 0.28),
            backgroundColor: cardBg,
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: !isDocker ? DompetKuTheme.warningAmber : textMuted,
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
                    color: DompetKuTheme.warningAmber,
                  ),
            label: Text(
              _isSyncingFirebase ? 'Syncing...' : 'Sync Docker ➔ Firebase',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            backgroundColor: cardBg,
            visualDensity: VisualDensity.compact,
            onPressed: _isSyncingFirebase ? null : _handleSyncToFirebase,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: DompetKuTheme.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: DompetKuTheme.secondary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.dns_outlined,
                  size: 13,
                  color: DompetKuTheme.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Container: ${summary.containerId}',
                  key: const Key('docker-container-badge'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
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
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
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
        color: DompetKuTheme.expenseRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DompetKuTheme.expenseRed),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: DompetKuTheme.expenseRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w500),
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

  Widget _buildSummaryCards(FinancialSummary? summary, bool isDark) {
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
            accentColor: DompetKuTheme.secondary,
            isPrimary: true,
            isDark: isDark,
          ),
          _SummaryMetricCard(
            cardKey: const Key('summary-income-card'),
            title: 'Total Pemasukan',
            value: formatRupiah(income),
            subtitle: '${summary?.incomeCategories.length ?? 0} kategori pemasukan',
            icon: Icons.trending_up_rounded,
            accentColor: DompetKuTheme.incomeGreen,
            isDark: isDark,
          ),
          _SummaryMetricCard(
            cardKey: const Key('summary-expense-card'),
            title: 'Total Pengeluaran',
            value: formatRupiah(expense),
            subtitle: '${summary?.expenseCategories.length ?? 0} kategori pengeluaran',
            icon: Icons.trending_down_rounded,
            accentColor: DompetKuTheme.expenseRed,
            isDark: isDark,
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

  Widget _buildFilterAndSearchBar(bool isDark) {
    final cardBg = isDark ? DompetKuTheme.darkCard : DompetKuTheme.lightCard;
    final border = isDark ? DompetKuTheme.darkBorder : DompetKuTheme.lightBorder;
    final mutedBg = isDark ? DompetKuTheme.darkMuted : DompetKuTheme.lightMuted;
    final textMuted = isDark ? DompetKuTheme.darkTextMuted : DompetKuTheme.lightTextMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
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
              _buildFilterChip('all', 'Semua', isDark),
              _buildFilterChip('income', 'Pemasukan', isDark),
              _buildFilterChip('expense', 'Pengeluaran', isDark),
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
                hintStyle: TextStyle(color: textMuted, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: textMuted,
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
                fillColor: mutedBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, bool isDark) {
    final selected = _selectedFilter == value;
    final mutedBg = isDark ? DompetKuTheme.darkMuted : DompetKuTheme.lightMuted;
    final textMuted = isDark ? DompetKuTheme.darkTextMuted : DompetKuTheme.lightTextMuted;

    return ChoiceChip(
      key: Key('filter-chip-$value'),
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedFilter = value);
        _loadData();
      },
      selectedColor: DompetKuTheme.primary,
      backgroundColor: mutedBg,
      labelStyle: TextStyle(
        color: selected ? Colors.white : textMuted,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _buildTransactionsSection(bool isDark) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final cardBg = isDark ? DompetKuTheme.darkCard : DompetKuTheme.lightCard;
    final border = isDark ? DompetKuTheme.darkBorder : DompetKuTheme.lightBorder;
    final textPrimary = isDark ? DompetKuTheme.darkText : DompetKuTheme.lightText;
    final textMuted = isDark ? DompetKuTheme.darkTextMuted : DompetKuTheme.lightTextMuted;

    if (_transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              'Belum ada transaksi pada filter ini',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textPrimary,
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Klik ikon pensil untuk Edit atau Hapus',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
              ),
            ],
          ),
        ),
        ..._transactions.map((tx) {
          final isIncome = tx.isIncome;
          final amountColor =
              isIncome ? DompetKuTheme.incomeGreen : DompetKuTheme.expenseRed;
          final prefix = isIncome ? '+ ' : '- ';

          return Container(
            key: ValueKey('tx-item-${tx.id}'),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
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
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tx.note.isNotEmpty
                      ? '${tx.category} • ${tx.note}'
                      : tx.category,
                  style: TextStyle(color: textMuted, fontSize: 12),
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
                      color: DompetKuTheme.secondary,
                      size: 19,
                    ),
                    onPressed: () => _openTransactionDialog(existing: tx),
                  ),
                  IconButton(
                    key: Key('delete-tx-${tx.id}'),
                    tooltip: 'Hapus Transaksi',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: textMuted,
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
  final bool isDark;

  const _CredentialItem({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? DompetKuTheme.darkTextMuted : DompetKuTheme.lightTextMuted;
    final textPrimary = isDark ? DompetKuTheme.darkText : DompetKuTheme.lightText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textPrimary,
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
  final bool isDark;

  const _SummaryMetricCard({
    this.cardKey,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.isPrimary = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? DompetKuTheme.darkCard : DompetKuTheme.lightCard;
    final border = isDark ? DompetKuTheme.darkBorder : DompetKuTheme.lightBorder;
    final textPrimary = isDark ? DompetKuTheme.darkText : DompetKuTheme.lightText;
    final textMuted = isDark ? DompetKuTheme.darkTextMuted : DompetKuTheme.lightTextMuted;

    return Container(
      key: cardKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isPrimary
            ? LinearGradient(
                colors: isDark
                    ? [
                        DompetKuTheme.primary.withValues(alpha: 0.65),
                        DompetKuTheme.darkCard,
                      ]
                    : [
                        DompetKuTheme.primary.withValues(alpha: 0.12),
                        DompetKuTheme.lightCard,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPrimary ? null : cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary
              ? DompetKuTheme.secondary.withValues(alpha: 0.45)
              : border,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textMuted,
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
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: textMuted),
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
  final bool isDark;

  const TransactionFormDialog({
    super.key,
    required this.apiClient,
    required this.expenseCategories,
    required this.incomeCategories,
    this.existingTransaction,
    this.isDark = true,
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
    final cardBg = widget.isDark ? DompetKuTheme.darkCard : DompetKuTheme.lightCard;
    final border = widget.isDark ? DompetKuTheme.darkBorder : DompetKuTheme.lightBorder;
    final textPrimary = widget.isDark ? DompetKuTheme.darkText : DompetKuTheme.lightText;

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      ),
      title: Text(
        _isEditMode ? 'Edit Transaksi' : 'Tambah Transaksi Baru',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
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
                      color: DompetKuTheme.expenseRed.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: DompetKuTheme.expenseRed),
                    ),
                    child: Text(
                      _submitError!,
                      style: TextStyle(
                        color: textPrimary,
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
