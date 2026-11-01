import 'package:flutter/material.dart';
import 'models/transaction_model.dart';
import 'services/api_service.dart';

void main() {
  runApp(DompetKuApp(apiClient: HttpExpenseApiClient()));
}

class DompetKuColors {
  static const Color background = Color(0xFF0F172A);
  static const Color card = Color(0xFF192134);
  static const Color muted = Color(0xFF101A34);
  static const Color primary = Color(0xFF1E40AF);
  static const Color secondary = Color(0xFF3B82F6);
  static const Color incomeGreen = Color(0xFF059669);
  static const Color expenseRed = Color(0xFFDC2626);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color glassBorder = Color(0x1F94A3B8);
}

class DompetKuApp extends StatelessWidget {
  final ExpenseApiClient apiClient;

  const DompetKuApp({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DompetKu Docker — Money Expense Tracker',
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
      home: ExpenseDashboardPage(apiClient: apiClient),
    );
  }
}

class ExpenseDashboardPage extends StatefulWidget {
  final ExpenseApiClient apiClient;

  const ExpenseDashboardPage({super.key, required this.apiClient});

  @override
  State<ExpenseDashboardPage> createState() => _ExpenseDashboardPageState();
}

class _ExpenseDashboardPageState extends State<ExpenseDashboardPage> {
  FinancialSummary? _summary;
  List<ExpenseTransaction> _transactions = const [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all'; // 'all' | 'income' | 'expense'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
      final results = await Future.wait([
        widget.apiClient.fetchSummary(),
        widget.apiClient.fetchTransactions(
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

  Future<void> _handleDelete(ExpenseTransaction tx) async {
    try {
      await widget.apiClient.deleteTransaction(tx.id);
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

  Future<void> _openAddTransactionDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AddTransactionDialog(
        apiClient: widget.apiClient,
        expenseCategories: _expenseCategories,
        incomeCategories: _incomeCategories,
      ),
    );
    if (created == true) {
      await _loadData();
    }
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: DompetKuColors.card,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DompetKuColors.primary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: DompetKuColors.secondary.withValues(alpha: 0.4)),
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
                    'Flutter + Node.js API + PostgreSQL Container',
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
          if (summary != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: DompetKuColors.incomeGreen.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: DompetKuColors.incomeGreen.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.dns_outlined,
                      size: 14,
                      color: DompetKuColors.incomeGreen,
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
            ),
          IconButton(
            key: const Key('refresh-button'),
            tooltip: 'Muat Ulang Data',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('open-add-transaction-button'),
        onPressed: _openAddTransactionDialog,
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
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                children: [
                  if (_errorMessage != null) _buildErrorBanner(_errorMessage!),
                  _buildSummaryCards(summary),
                  const SizedBox(height: 12),
                  _buildFilterAndSearchBar(),
                  const SizedBox(height: 12),
                  _buildTransactionsSection(),
                  if (summary != null && summary.byCategory.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildCategoryBreakdown(summary),
                  ],
                ],
              ),
            ),
          ),
        ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        final cards = [
          _SummaryMetricCard(
            cardKey: const Key('summary-balance-card'),
            title: 'Total Saldo Bersih',
            value: formatRupiah(balance),
            subtitle: '${summary?.transactionCount ?? 0} total transaksi tercatat',
            icon: Icons.account_balance_wallet_outlined,
            accentColor: DompetKuColors.secondary,
            isPrimary: true,
          ),
          _SummaryMetricCard(
            cardKey: const Key('summary-income-card'),
            title: 'Total Pemasukan',
            value: formatRupiah(income),
            subtitle: 'Dana masuk (Income)',
            icon: Icons.trending_up_rounded,
            accentColor: DompetKuColors.incomeGreen,
          ),
          _SummaryMetricCard(
            cardKey: const Key('summary-expense-card'),
            title: 'Total Pengeluaran',
            value: formatRupiah(expense),
            subtitle: 'Dana keluar (Expense)',
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

  Widget _buildCategoryBreakdown(FinancialSummary summary) {
    final maxTotal = summary.byCategory.fold<double>(
      1,
      (prev, item) => item.total > prev ? item.total : prev,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DompetKuColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DompetKuColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.pie_chart_outline_rounded,
                size: 18,
                color: DompetKuColors.secondary,
              ),
              SizedBox(width: 8),
              Text(
                'Ringkasan per Kategori',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DompetKuColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...summary.byCategory.take(5).map((item) {
            final isIncome = item.type == 'income';
            final barColor =
                isIncome ? DompetKuColors.incomeGreen : DompetKuColors.expenseRed;
            final ratio = (item.total / maxTotal).clamp(0.05, 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.category} (${item.count}x)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: DompetKuColors.textPrimary,
                        ),
                      ),
                      Text(
                        formatRupiah(item.total),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 7,
                      backgroundColor: DompetKuColors.muted,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
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
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        decoration: BoxDecoration(
          color: DompetKuColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DompetKuColors.glassBorder),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 44,
              color: DompetKuColors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              'Belum ada transaksi pada filter ini',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DompetKuColors.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Klik tombol "Tambah Transaksi" di kanan bawah untuk mencatat keuangan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: DompetKuColors.textMuted, fontSize: 13),
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
          child: Text(
            'Riwayat Transaksi (${_transactions.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: DompetKuColors.textPrimary,
            ),
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
                  const SizedBox(width: 8),
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
      padding: const EdgeInsets.all(18),
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
          const SizedBox(height: 10),
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
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: DompetKuColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class AddTransactionDialog extends StatefulWidget {
  final ExpenseApiClient apiClient;
  final List<String> expenseCategories;
  final List<String> incomeCategories;

  const AddTransactionDialog({
    super.key,
    required this.apiClient,
    required this.expenseCategories,
    required this.incomeCategories,
  });

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _selectedType = 'expense';
  late String _selectedCategory;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.expenseCategories.first;
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

      await widget.apiClient.createTransaction(
        title: _titleController.text.trim(),
        amount: parsedAmount,
        type: _selectedType,
        category: _selectedCategory,
        note: _noteController.text.trim(),
      );

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
      title: const Text(
        'Tambah Transaksi Baru',
        style: TextStyle(
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
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
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
          label: Text(_isSubmitting ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    );
  }
}
