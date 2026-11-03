import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';

class FintechChartsPanel extends StatelessWidget {
  final FinancialSummary summary;
  final bool isDark;

  const FintechChartsPanel({
    super.key,
    required this.summary,
    this.isDark = true,
  });

  static const List<Color> chartPalette = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Violet
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF14B8A6), // Teal
  ];

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF192134) : Colors.white;
    final borderColor = isDark ? const Color(0x1F94A3B8) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final mutedBg = isDark ? const Color(0xFF101A34) : const Color(0xFFF1F5F9);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final expenseCard = _DonutChartCard(
          key: const Key('donut-chart-card'),
          title: 'Distribusi Pengeluaran',
          icon: Icons.donut_large_rounded,
          iconColor: const Color(0xFFDC2626),
          items: summary.expenseCategories,
          total: summary.totalExpense,
          emptyLabel: 'Belum ada data pengeluaran',
          centerLabel: 'Keluar',
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textMuted: textMuted,
          mutedBg: mutedBg,
        );

        final incomeCard = _DonutChartCard(
          key: const Key('income-donut-chart-card'),
          title: 'Sumber Pemasukan',
          icon: Icons.pie_chart_rounded,
          iconColor: const Color(0xFF059669),
          items: summary.incomeCategories,
          total: summary.totalIncome,
          emptyLabel: 'Belum ada data pemasukan',
          centerLabel: 'Masuk',
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textMuted: textMuted,
          mutedBg: mutedBg,
        );

        final cashflowCard = _CashflowBarCard(
          summary: summary,
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textMuted: textMuted,
          mutedBg: mutedBg,
        );

        if (isWide) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: expenseCard),
                  const SizedBox(width: 14),
                  Expanded(child: incomeCard),
                ],
              ),
              const SizedBox(height: 14),
              cashflowCard,
            ],
          );
        }

        return Column(
          children: [
            expenseCard,
            const SizedBox(height: 12),
            incomeCard,
            const SizedBox(height: 12),
            cashflowCard,
          ],
        );
      },
    );
  }
}

class _DonutChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<CategoryBreakdown> items;
  final double total;
  final String emptyLabel;
  final String centerLabel;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textMuted;
  final Color mutedBg;

  const _DonutChartCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.total,
    required this.emptyLabel,
    required this.centerLabel,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textMuted,
    required this.mutedBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                formatRupiah(total),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty || total <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  emptyLabel,
                  style: TextStyle(color: textMuted, fontSize: 13),
                ),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 124,
                  height: 124,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(124, 124),
                        painter: _DonutChartPainter(
                          items: items,
                          total: total,
                          colors: FintechChartsPanel.chartPalette,
                          trackColor: mutedBg,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            centerLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${items.length} Kat',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(
                      items.take(4).length,
                      (index) {
                        final item = items[index];
                        final color = FintechChartsPanel.chartPalette[
                            index % FintechChartsPanel.chartPalette.length];
                        final pct =
                            total > 0 ? (item.total / total * 100) : 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.category,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${pct.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<CategoryBreakdown> items;
  final double total;
  final List<Color> colors;
  final Color trackColor;

  _DonutChartPainter({
    required this.items,
    required this.total,
    required this.colors,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const strokeWidth = 16.0;

    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    if (total <= 0 || items.isEmpty) return;

    double startAngle = -math.pi / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 0; i < items.length; i++) {
      final sweepAngle = (items[i].total / total) * 2 * math.pi;
      if (sweepAngle <= 0) continue;

      final segPaint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      final gap = items.length > 1 ? 0.04 : 0.0;
      final effectiveSweep = math.max(0.02, sweepAngle - gap);

      canvas.drawArc(rect, startAngle, effectiveSweep, false, segPaint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total ||
        oldDelegate.items.length != items.length ||
        oldDelegate.trackColor != trackColor;
  }
}

class _CashflowBarCard extends StatelessWidget {
  final FinancialSummary summary;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textMuted;
  final Color mutedBg;

  const _CashflowBarCard({
    required this.summary,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textMuted,
    required this.mutedBg,
  });

  @override
  Widget build(BuildContext context) {
    final inc = summary.totalIncome;
    final exp = summary.totalExpense;
    final maxVal = math.max(inc, math.max(exp, 1.0));
    final incRatio = (inc / maxVal).clamp(0.04, 1.0);
    final expRatio = (exp / maxVal).clamp(0.04, 1.0);
    final savingsRate = summary.savingsRatePercent;

    final statusLabel = savingsRate >= 20
        ? 'Cashflow Sehat'
        : (savingsRate >= 0 ? 'Perlu Hemat' : 'Defisit Anggaran');
    final statusColor = savingsRate >= 20
        ? const Color(0xFF059669)
        : (savingsRate >= 0 ? const Color(0xFFF59E0B) : const Color(0xFFDC2626));

    return Container(
      key: const Key('cashflow-chart-card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
                child: Row(
                  children: [
                    const Icon(
                      Icons.bar_chart_rounded,
                      size: 18,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Analisis Cashflow & Rasio Tabungan',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '$statusLabel (${savingsRate.toStringAsFixed(0)}%)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildBarRow(
            label: 'Pemasukan (Income)',
            amountText: formatRupiah(inc),
            ratio: incRatio,
            color: const Color(0xFF059669),
            textMuted: textMuted,
            trackColor: mutedBg,
          ),
          const SizedBox(height: 14),
          _buildBarRow(
            label: 'Pengeluaran (Expense)',
            amountText: formatRupiah(exp),
            ratio: expRatio,
            color: const Color(0xFFDC2626),
            textMuted: textMuted,
            trackColor: mutedBg,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: mutedBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Rasio Pengeluaran vs Pemasukan',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${summary.expenseRatioPercent.toStringAsFixed(1)}% terpakai',
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _buildBarRow({
    required String label,
    required String amountText,
    required double ratio,
    required Color color,
    required Color textMuted,
    required Color trackColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amountText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 12,
            backgroundColor: trackColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
