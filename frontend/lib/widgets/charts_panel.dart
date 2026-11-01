import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';

class FintechChartsPanel extends StatelessWidget {
  final FinancialSummary summary;

  const FintechChartsPanel({super.key, required this.summary});

  static const List<Color> chartPalette = [
    Color(0xFF3B82F6), // Blue
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Violet
    Color(0xFF10B981), // Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        final donutCard = _ExpenseDonutCard(summary: summary);
        final cashflowCard = _CashflowBarCard(summary: summary);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: donutCard),
              const SizedBox(width: 14),
              Expanded(child: cashflowCard),
            ],
          );
        }

        return Column(
          children: [
            donutCard,
            const SizedBox(height: 12),
            cashflowCard,
          ],
        );
      },
    );
  }
}

class _ExpenseDonutCard extends StatelessWidget {
  final FinancialSummary summary;

  const _ExpenseDonutCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final expenses = summary.expenseCategories;
    final totalExp = summary.totalExpense;

    return Container(
      key: const Key('donut-chart-card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF192134),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1F94A3B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.donut_large_rounded,
                size: 18,
                color: Color(0xFF3B82F6),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Distribusi Pengeluaran (Donut Chart)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (expenses.isEmpty || totalExp <= 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'Belum ada data pengeluaran',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(130, 130),
                        painter: _DonutChartPainter(
                          items: expenses,
                          total: totalExp,
                          colors: FintechChartsPanel.chartPalette,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Keluar',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${expenses.length} Kat',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
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
                      expenses.take(5).length,
                      (index) {
                        final item = expenses[index];
                        final color = FintechChartsPanel.chartPalette[
                            index % FintechChartsPanel.chartPalette.length];
                        final pct =
                            totalExp > 0 ? (item.total / totalExp * 100) : 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.category,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${pct.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
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

  _DonutChartPainter({
    required this.items,
    required this.total,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const strokeWidth = 18.0;

    final bgPaint = Paint()
      ..color = const Color(0xFF101A34)
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

      // Small gap between segments if more than 1 category
      final gap = items.length > 1 ? 0.04 : 0.0;
      final effectiveSweep = math.max(0.02, sweepAngle - gap);

      canvas.drawArc(rect, startAngle, effectiveSweep, false, segPaint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.items.length != items.length;
  }
}

class _CashflowBarCard extends StatelessWidget {
  final FinancialSummary summary;

  const _CashflowBarCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final inc = summary.totalIncome;
    final exp = summary.totalExpense;
    final maxVal = math.max(inc, math.max(exp, 1.0));
    final incRatio = (inc / maxVal).clamp(0.04, 1.0);
    final expRatio = (exp / maxVal).clamp(0.04, 1.0);
    final savingsRate = summary.savingsRatePercent;

    final isHealthy = savingsRate >= 20;
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
        color: const Color(0xFF192134),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1F94A3B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.bar_chart_rounded,
                      size: 18,
                      color: Color(0xFF059669),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Analisis Cashflow & Rasio Tabungan',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
                    color: isHealthy ? const Color(0xFF34D399) : statusColor,
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
          ),
          const SizedBox(height: 14),
          _buildBarRow(
            label: 'Pengeluaran (Expense)',
            amountText: formatRupiah(exp),
            ratio: expRatio,
            color: const Color(0xFFDC2626),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF101A34),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Rasio Pengeluaran vs Pemasukan',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${summary.expenseRatioPercent.toStringAsFixed(1)}% terpakai',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
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
            backgroundColor: const Color(0xFF101A34),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
