import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import 'co_shared_widgets.dart';

/// Interactive 4-stage Savings Withdrawal & Maker-Checker Pipeline.
/// Live `fl_chart` Analytics Section for Daily Withdrawals tab.
class CoWithdrawalAnalyticsSection extends StatelessWidget {
  final double totalWithdrawn;
  final double loanFeesDeducted;
  final double cashBankPaid;
  final double debtOffsets;
  final double lapsReserved;
  final double waitingAmount;
  final int waitingCount;
  final bool showAll;

  const CoWithdrawalAnalyticsSection({
    super.key,
    required this.totalWithdrawn,
    required this.loanFeesDeducted,
    required this.cashBankPaid,
    required this.debtOffsets,
    required this.lapsReserved,
    required this.waitingAmount,
    required this.waitingCount,
    required this.showAll,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final lapsAccent = tokens.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);

    final categories = <({String label, String shortLabel, double amount, Color color})>[
      (label: 'Cash & Bank Paid', shortLabel: 'Payouts', amount: cashBankPaid, color: tokens.successDot),
      (label: 'Loan Fees Deducted', shortLabel: 'Fees', amount: loanFeesDeducted, color: tokens.infoDot),
      (label: 'Debt/Fee Offsets', shortLabel: 'Offsets', amount: debtOffsets, color: tokens.warningDot),
      (label: 'LAPS Reserve', shortLabel: 'LAPS', amount: lapsReserved, color: lapsAccent),
      (label: 'Waiting Approval', shortLabel: 'Pending', amount: waitingAmount, color: tokens.dangerDot),
    ];

    final maxVal = categories.fold<double>(
      0.0,
      (prev, item) => math.max(prev, item.amount),
    );
    final settledTotal = cashBankPaid + loanFeesDeducted + debtOffsets + lapsReserved;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;

        final barCard = IcareCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                showAll ? 'All-Dates Withdrawal Channel Volume' : 'Daily Withdrawal Channel Volume',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Direct comparison across cash/bank payouts, fee deductions, internal offsets, and pending queue',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 12),
              if (maxVal <= 0)
                const CoEmptyStateCard(
                  title: 'No Withdrawal Activity Yet',
                  message: 'Channel bars populate when savings withdrawals or deductions occur in this window.',
                  icon: Icons.bar_chart_rounded,
                )
              else
                SizedBox(
                  height: 185,
                  child: BarChart(
                    BarChartData(
                      maxY: maxVal * 1.22,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: tokens.borderSubtle,
                          strokeWidth: 0.7,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => tokens.surfaceElevated,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final item = categories[groupIndex];
                            return BarTooltipItem(
                              '${item.label}\n${CurrencyFormatter.formatNaira(rod.toY)}',
                              coTabularStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            getTitlesWidget: (v, _) => Text(
                              v >= 1000000
                                  ? '₦${(v / 1000000).toStringAsFixed(1)}M'
                                  : '₦${(v / 1000).toStringAsFixed(0)}k',
                              style: coTabularStyle(fontSize: 9.5, color: tokens.textMuted),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= categories.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  categories[idx].shortLabel,
                                  style: TextStyle(fontSize: 9.5, color: tokens.textSecondary),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(categories.length, (i) {
                        final item = categories[i];
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: item.amount,
                              width: 18,
                              color: item.color,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
            ],
          ),
        );

        final activeMix = categories.where((c) => c.amount > 0).toList();
        final mixDenom = activeMix.fold<double>(0.0, (a, b) => a + b.amount);

        final donutCard = IcareCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settlement & Queue Mix',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$waitingCount pending approval • ${CurrencyFormatter.formatNaira(settledTotal, showDecimals: false)} settled',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 12),
              if (mixDenom <= 0)
                const CoEmptyStateCard(
                  title: 'Zero Outflow Volume',
                  message: 'Distribution ring displays once withdrawals or deductions exist.',
                  icon: Icons.pie_chart_outline_rounded,
                )
              else
                Column(
                  children: [
                    SizedBox(
                      height: 145,
                      child: PieChart(
                        PieChartData(
                          centerSpaceRadius: 32,
                          sectionsSpace: 2,
                          sections: activeMix
                              .map(
                                (item) => PieChartSectionData(
                                  value: item.amount,
                                  color: item.color,
                                  radius: 32,
                                  title: '${((item.amount / mixDenom) * 100).round()}%',
                                  titleStyle: coTabularStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: activeMix
                          .map(
                            (item) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: item.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.shortLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: tokens.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
            ],
          ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: barCard),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: donutCard),
            ],
          );
        }
        return Column(
          children: [
            barCard,
            const SizedBox(height: 12),
            donutCard,
          ],
        );
      },
    );
  }
}
