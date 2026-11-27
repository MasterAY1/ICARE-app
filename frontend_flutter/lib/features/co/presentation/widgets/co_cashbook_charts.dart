import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import 'co_shared_widgets.dart';

/// Interactive 4-stage Vault Cashbook & Physical Reconciliation Pipeline.
/// Live `fl_chart` Analytics Section for Credit Officer Daily Cashbook.
class CoCashbookAnalyticsSection extends StatelessWidget {
  final double openingBalance;
  final double totalInflows;
  final double totalOutflows;
  final double closingBalance;
  final Map<String, dynamic> outflows;

  const CoCashbookAnalyticsSection({
    super.key,
    required this.openingBalance,
    required this.totalInflows,
    required this.totalOutflows,
    required this.closingBalance,
    required this.outflows,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);

    final bridgeBars = <({String label, String shortLabel, double value, Color color})>[
      (label: 'Opening Float', shortLabel: 'Opening', value: math.max(0, openingBalance), color: tokens.infoDot),
      (label: 'Total Inflows', shortLabel: 'Inflows', value: math.max(0, totalInflows), color: tokens.successDot),
      (label: 'Total Outflows', shortLabel: 'Outflows', value: math.max(0, totalOutflows), color: tokens.dangerDot),
      (label: 'Closing Balance', shortLabel: 'Closing', value: math.max(0, closingBalance), color: tokens.brandPrimary),
    ];

    final maxBar = bridgeBars.fold<double>(
      0.0,
      (prev, item) => math.max(prev, item.value),
    );

    final loansOut = ((outflows['active_loan_daily'] as num?)?.toDouble() ?? 0.0) +
        ((outflows['active_loan_120d'] as num?)?.toDouble() ?? 0.0) +
        ((outflows['active_loan_12w'] as num?)?.toDouble() ?? 0.0) +
        ((outflows['active_loan_24w'] as num?)?.toDouble() ?? 0.0) +
        ((outflows['active_loan_monthly'] as num?)?.toDouble() ?? 0.0);
    final savingsOut = ((outflows['product_withdrawal'] as num?)?.toDouble() ?? 0.0) +
        ((outflows['laps_returns'] as num?)?.toDouble() ?? 0.0);
    final opsExpense = (outflows['office_expenses'] as num?)?.toDouble() ?? 0.0;
    final bankDep = (outflows['bank_deposit'] as num?)?.toDouble() ?? 0.0;

    final mixSlices = <({String label, double value, Color color})>[
      (label: 'Disbursements', value: loansOut, color: tokens.brandPrimary),
      (label: 'Savings & LAPS', value: savingsOut, color: tokens.warningDot),
      (label: 'Bank Deposits', value: bankDep, color: tokens.infoDot),
      (label: 'Office Expenses', value: opsExpense, color: tokens.dangerDot),
    ].where((s) => s.value > 0).toList();

    final mixTotal = mixSlices.fold<double>(0.0, (sum, s) => sum + s.value);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;

        final barCard = IcareCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cash Position Bridge (Opening to Closing)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Direct vault comparison of opening float, daily inflows, outflows & closing cash',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 12),
              if (maxBar <= 0)
                const CoEmptyStateCard(
                  title: 'Zero Cashbook Movements',
                  message: 'Cash position bars populate once vault entries exist for this date.',
                  icon: Icons.bar_chart_rounded,
                )
              else
                SizedBox(
                  height: 185,
                  child: BarChart(
                    BarChartData(
                      maxY: maxBar * 1.22,
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
                            final item = bridgeBars[groupIndex];
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
                            reservedSize: 50,
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
                              if (idx < 0 || idx >= bridgeBars.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  bridgeBars[idx].shortLabel,
                                  style: TextStyle(fontSize: 9.5, color: tokens.textSecondary),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(bridgeBars.length, (i) {
                        final item = bridgeBars[i];
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: item.value,
                              width: 20,
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

        final donutCard = IcareCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cash Outflow Allocation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Split across disbursements, withdrawals, bank deposits & expenses',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 12),
              if (mixTotal <= 0)
                const CoEmptyStateCard(
                  title: 'No Cash Outflows Posted',
                  message: 'Outflow allocation renders once payouts or bank deposits are posted.',
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
                          sections: mixSlices
                              .map(
                                (item) => PieChartSectionData(
                                  value: item.value,
                                  color: item.color,
                                  radius: 32,
                                  title: '${((item.value / mixTotal) * 100).round()}%',
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
                      children: mixSlices
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
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textSecondary,
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
