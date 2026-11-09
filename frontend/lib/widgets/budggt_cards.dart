import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';

class BudggtTheme {
  static const Color darkCardBg = Color(0xFF1A1B22);
  static const Color darkCardInner = Color(0xFF242630);
  static const Color coralAccent = Color(0xFFFF7A6A);
  static const Color coralMuted = Color(0x33FF7A6A);
  static const Color purpleAccent = Color(0xFFA78BFA);
  static const Color greenAccent = Color(0xFF4ADE80);
  static const Color textMuted = Color(0xFF9CA3AF);
}

/// Hero Net Worth & Financial Runway Card ala Budggt (Screenshot 1)
class BudggtHeroNetWorthCard extends StatelessWidget {
  final FinancialSummary summary;
  final bool isDark;

  const BudggtHeroNetWorthCard({
    super.key,
    required this.summary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final netWorth = summary.netWorth != 0 ? summary.netWorth : summary.balance;
    final runway = summary.runwayMonths > 0 ? summary.runwayMonths : 21.6;
    final tier = summary.financialTier;
    final pillars = summary.assetPillars;

    return Container(
      key: const Key('budggt-hero-card'),
      decoration: BoxDecoration(
        color: BudggtTheme.darkCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Diamond + Label
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(2),
                ),
                transform: Matrix4.rotationZ(0.785398), // 45 deg diamond
              ),
              const SizedBox(width: 8),
              Text(
                'KEKAYAAN BERSIH',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Total Net Worth Display
          Text(
            formatRupiah(netWorth),
            key: const Key('budggt-networth-value'),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Runway Pill (Rocket)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: BudggtTheme.coralAccent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🚀', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'SETARA PENGELUARAN ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.6),
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          '${runway.toStringAsFixed(1)} Bulan',
                          key: const Key('budggt-runway-badge'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'dari aset yang bisa dicairkan',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Nested Level Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BudggtTheme.darkCardInner,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🏆', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LEVEL SAAT INI',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.5),
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              tier.currentLevel,
                              key: const Key('budggt-level-name'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TARGET BERIKUTNYA',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.5),
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          formatRupiah(tier.targetBerikutnya),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Progress Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PROGRES KE LEVEL BERIKUTNYA',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    Text(
                      '${tier.progressPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: BudggtTheme.coralAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (tier.progressPercent / 100).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(BudggtTheme.coralAccent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3-Pillar Asset Distribution
          Row(
            children: [
              Expanded(
                child: _buildPillarMiniCard(
                  label: 'DOMPET & AKUN',
                  amount: pillars.dompetAkun,
                  dotColor: BudggtTheme.purpleAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPillarMiniCard(
                  label: 'ASET LIKUID',
                  amount: pillars.asetLikuid,
                  dotColor: BudggtTheme.coralAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPillarMiniCard(
                  label: 'ASET TETAP',
                  amount: pillars.asetTetap,
                  dotColor: Colors.blueAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillarMiniCard({
    required String label,
    required double amount,
    required Color dotColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BudggtTheme.darkCardInner,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            formatRupiah(amount),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Budget Pacing Card 50/30/20 ala Budggt (Screenshot 2 Atas)
class BudgetPacingCard extends StatelessWidget {
  final BudgetPacing pacing;
  final bool isDark;

  const BudgetPacingCard({
    super.key,
    required this.pacing,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E212B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textMuted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB);

    final dayRatio = (pacing.currentDay / pacing.totalDays).clamp(0.0, 1.0);

    return Container(
      key: const Key('budggt-budget-pacing-card'),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Circular Day Indicator + Title
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: dayRatio,
                      strokeWidth: 4,
                      backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(BudggtTheme.coralAccent),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'HARI',
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                            color: textMuted,
                          ),
                        ),
                        Text(
                          '${pacing.currentDay}',
                          key: const Key('budggt-current-day-text'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progres Pengeluaran',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Hari ${pacing.currentDay} dari ${pacing.totalDays}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Needs Bar (Kebutuhan - 78%)
          _buildPacingRow(
            item: pacing.needs,
            barColor: BudggtTheme.purpleAccent,
            textPrimary: textPrimary,
            textMuted: textMuted,
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // Wants Bar (Keinginan - 0%)
          _buildPacingRow(
            item: pacing.wants,
            barColor: BudggtTheme.coralAccent,
            textPrimary: textPrimary,
            textMuted: textMuted,
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // Savings Bar (Tabungan - 102%)
          _buildPacingRow(
            item: pacing.savings,
            barColor: BudggtTheme.greenAccent,
            textPrimary: textPrimary,
            textMuted: textMuted,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPacingRow({
    required BudgetPacingItem item,
    required Color barColor,
    required Color textPrimary,
    required Color textMuted,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: item.percent > 100 ? BudggtTheme.coralAccent : textMuted,
                  ),
                ),
              ],
            ),
            Text(
              '${item.percent}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (item.percent / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

/// Kalender Finansial (Aktivitas Bulan Ini) ala Budggt (Screenshot 2 Bawah)
class FinancialCalendarCard extends StatefulWidget {
  final List<DailyActivity> activities;
  final bool isDark;
  final ValueChanged<String>? onSelectDate;

  const FinancialCalendarCard({
    super.key,
    required this.activities,
    required this.isDark,
    this.onSelectDate,
  });

  @override
  State<FinancialCalendarCard> createState() => _FinancialCalendarCardState();
}

class _FinancialCalendarCardState extends State<FinancialCalendarCard> {
  int _selectedDay = 9; // Default highlighted day

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1E212B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textMuted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB);

    final activityMap = <int, DailyActivity>{};
    for (final act in widget.activities) {
      final parts = act.date.split('-');
      if (parts.length == 3) {
        final day = int.tryParse(parts[2]);
        if (day != null) {
          activityMap[day] = act;
        }
      }
    }

    const weekdays = ['SN', 'SL', 'RB', 'KM', 'JM', 'SB', 'MG'];

    return Container(
      key: const Key('budggt-calendar-card'),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aktivitas Bulan Ini',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'NOVEMBER 2026',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 16),

          // Weekdays Row
          Row(
            children: weekdays.map((wd) {
              return Expanded(
                child: Center(
                  child: Text(
                    wd,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // 30 Days Grid (November 2026 starts on Sunday = MG, so 6 empty slots if Monday-first)
          // For clean layout, let's render 30 days grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 30,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = day == _selectedDay;
              final act = activityMap[day];

              return InkWell(
                onTap: () {
                  setState(() => _selectedDay = day);
                  if (widget.onSelectDate != null) {
                    final dayStr = day.toString().padLeft(2, '0');
                    widget.onSelectDate!('2026-11-$dayStr');
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? BudggtTheme.coralAccent.withValues(alpha: 0.12) : const Color(0xFFFFF1F0))
                        : (isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? BudggtTheme.coralAccent
                          : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9)),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? BudggtTheme.coralAccent : textPrimary,
                        ),
                      ),
                      if (act != null) ...[
                        if (act.expense > 0)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatRupiahShort(-act.expense),
                              style: const TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        if (act.income > 0)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatRupiahShort(act.income),
                              style: const TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// AI Advisor Bottom Sheet (Screenshot 3 - Sat-Set Input & Natural Language)
class AiAdvisorBottomSheet extends StatefulWidget {
  final ExpenseApiClient apiClient;
  final bool isDark;
  final VoidCallback onTransactionAdded;

  const AiAdvisorBottomSheet({
    super.key,
    required this.apiClient,
    required this.isDark,
    required this.onTransactionAdded,
  });

  @override
  State<AiAdvisorBottomSheet> createState() => _AiAdvisorBottomSheetState();
}

class _AiAdvisorBottomSheetState extends State<AiAdvisorBottomSheet> {
  final TextEditingController _textCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default greeting message from AI
    _messages.add({
      'role': 'ai',
      'text': 'Halo! Aku AI Advisor kamu. Ada yang bisa dibantu soal uang hari ini? 🚀',
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage([String? customText]) async {
    final input = customText ?? _textCtrl.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': input});
      _isLoading = true;
      _textCtrl.clear();
    });

    try {
      final parsed = await widget.apiClient.parseNaturalLanguage(input);
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'ai',
          'text': parsed.advice,
          'draft': parsed,
        });
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'ai',
          'text': 'Maaf, aku belum bisa memahami kalimat itu. Coba ketik seperti "Beli kopi tuku 27rb blu"',
        });
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApproveDraft(ParsedAiTransaction draft) async {
    setState(() => _isLoading = true);
    try {
      await widget.apiClient.createTransaction(
        title: draft.title,
        amount: draft.amount,
        type: draft.type,
        category: draft.category,
        note: 'Via AI Advisor (${draft.wallet})',
      );
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'ai',
          'text': '✅ Berhasil disimpan! Saldo dan kalender sudah diperbarui secara real-time.',
        });
        _isLoading = false;
      });
      widget.onTransactionAdded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'ai',
          'text': 'Gagal menyimpan transaksi: $e',
        });
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF191B24) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textMuted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final inputBg = isDark ? const Color(0xFF232634) : const Color(0xFFF3F4F6);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Text('✨', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI Advisor',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      '1897',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          // Quick prompt chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickChip('Beli kopi tuku 27rb blu'),
                const SizedBox(width: 8),
                _buildQuickChip('Makan sate padang 35k gopay'),
                const SizedBox(width: 8),
                _buildQuickChip('Bensin pertamax 50rb cash'),
                const SizedBox(width: 8),
                _buildQuickChip('Gaji freelance 3jt bca'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Chat messages
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, idx) {
                final msg = _messages[idx];
                final isAi = msg['role'] == 'ai';
                final draft = msg['draft'] as ParsedAiTransaction?;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
                    children: [
                      if (isAi) ...[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: BudggtTheme.coralAccent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text('🤖', style: TextStyle(fontSize: 14)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isAi
                                    ? (isDark ? const Color(0xFF252836) : const Color(0xFFF3F4F6))
                                    : BudggtTheme.coralAccent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                msg['text'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isAi ? textPrimary : Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (draft != null) ...[
                              const SizedBox(height: 8),
                              _buildDraftConfirmationCard(draft, isDark, textPrimary, textMuted),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    key: const Key('ai-advisor-input-field'),
                    decoration: InputDecoration(
                      hintText: 'Tanya apa saja tentang keuangan...',
                      hintStyle: TextStyle(fontSize: 13, color: textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onSubmitted: (val) => _handleSendMessage(),
                  ),
                ),
                IconButton(
                  key: const Key('ai-advisor-send-button'),
                  icon: const Icon(Icons.send_rounded, color: BudggtTheme.coralAccent),
                  onPressed: _handleSendMessage,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ℹ Saran AI hanya untuk tujuan informasi. • 🪙 1 kredit/pesan',
            style: TextStyle(fontSize: 9.5, color: textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    return InkWell(
      onTap: () => _handleSendMessage(label),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white70 : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  Widget _buildDraftConfirmationCard(
    ParsedAiTransaction draft,
    bool isDark,
    Color textPrimary,
    Color textMuted,
  ) {
    return Container(
      key: const Key('ai-draft-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2D3D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BudggtTheme.coralAccent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('📝', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(
                    'Tambah Transaksi?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Menunggu',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            draft.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          Text(
            formatRupiah(draft.amount),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: BudggtTheme.coralAccent,
            ),
          ),
          const Divider(height: 16),
          Row(
            children: [
              Text('Tipe: ', style: TextStyle(fontSize: 11, color: textMuted)),
              Text(
                draft.type == 'income' ? 'Pemasukan' : 'Pengeluaran',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textPrimary),
              ),
              const Spacer(),
              Text('Wallet: ', style: TextStyle(fontSize: 11, color: textMuted)),
              Text(
                draft.wallet,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('Kategori: ', style: TextStyle(fontSize: 11, color: textMuted)),
              Text(
                draft.category,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textPrimary),
              ),
              const Spacer(),
              Text('Tanggal: ', style: TextStyle(fontSize: 11, color: textMuted)),
              Text(
                draft.date,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('ai-approve-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: BudggtTheme.coralAccent,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _handleApproveDraft(draft),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('✓ Setujui', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('ai-discard-button'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    setState(() {
                      _messages.removeLast();
                    });
                  },
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('✕ Buang', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
