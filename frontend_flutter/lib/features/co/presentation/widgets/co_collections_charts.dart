import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import 'co_shared_widgets.dart';

/// Live `fl_chart` Analytics Section for Tab 2: Collection History & Audit.
class CoCollectionsHistoryAnalyticsSection extends StatelessWidget {
  final double totalRepayments;
  final double totalSavings;
  final List<dynamic> groups;
  final int paidCount;
  final int notPaidCount;

  const CoCollectionsHistoryAnalyticsSection({
    super.key,
    required this.totalRepayments,
    required this.totalSavings,
    required this.groups,
    required this.paidCount,
    required this.notPaidCount,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final grand = totalRepayments + totalSavings;
    final topGroups = groups.take(7).toList();
    double maxGrp = 0.0;
    for (final g in topGroups) {
      if (g is Map) {
        final rep = (g['total_repayment'] as num?)?.toDouble() ?? 0.0;
        final sav = (g['total_savings'] as num?)?.toDouble() ?? 0.0;
        maxGrp = math.max(maxGrp, math.max(rep, sav));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;

        final barCard = IcareCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Group Collections Breakdown (Repayment vs Savings)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Live posted inflows across active groups for the selected date',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 12),
              if (topGroups.isEmpty || maxGrp <= 0)
                const CoEmptyStateCard(
                  title: 'No Posted Group Cashflows',
                  message: 'Group bars populate once collections are recorded for this date.',
                  icon: Icons.bar_chart_rounded,
                )
              else
                SizedBox(
                  height: 185,
                  child: BarChart(
                    BarChartData(
                      maxY: maxGrp * 1.2,
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
                            final g = topGroups[groupIndex] as Map;
                            final gName = (g['group_name'] ?? 'Group').toString();
                            final lbl = rodIndex == 0 ? 'Repayments' : 'Savings';
                            return BarTooltipItem(
                              '$gName\n$lbl: ${CurrencyFormatter.formatNaira(rod.toY)}',
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
                              if (idx < 0 || idx >= topGroups.length) {
                                return const SizedBox.shrink();
                              }
                              final raw = (topGroups[idx]['group_name'] ?? 'Grp').toString();
                              final short = raw.length > 9 ? '${raw.substring(0, 8)}..' : raw;
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  short,
                                  style: TextStyle(fontSize: 9.5, color: tokens.textSecondary),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(topGroups.length, (i) {
                        final g = topGroups[i] as Map;
                        final rep = (g['total_repayment'] as num?)?.toDouble() ?? 0.0;
                        final sav = (g['total_savings'] as num?)?.toDouble() ?? 0.0;
                        return BarChartGroupData(
                          x: i,
                          barsSpace: 4,
                          barRods: [
                            BarChartRodData(
                              toY: rep,
                              width: 10,
                              color: tokens.brandPrimary,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                            BarChartRodData(
                              toY: sav,
                              width: 10,
                              color: tokens.infoDot,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
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
                'Cash Composition & Coverage',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$paidCount Paid • $notPaidCount Arrears entries',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 12),
              if (grand <= 0)
                const CoEmptyStateCard(
                  title: 'Zero Cash Collected',
                  message: 'Inflow split chart displays once collections are posted for this date.',
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
                          sections: [
                            if (totalRepayments > 0)
                              PieChartSectionData(
                                value: totalRepayments,
                                color: tokens.brandPrimary,
                                radius: 32,
                                title: '${((totalRepayments / grand) * 100).round()}%',
                                titleStyle: coTabularStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            if (totalSavings > 0)
                              PieChartSectionData(
                                value: totalSavings,
                                color: tokens.infoDot,
                                radius: 32,
                                title: '${((totalSavings / grand) * 100).round()}%',
                                titleStyle: coTabularStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text(
                          'Repayments: ${CurrencyFormatter.formatNaira(totalRepayments, showDecimals: false)}',
                          style: coTabularStyle(fontSize: 11, color: tokens.brandPrimary),
                        ),
                        Text(
                          'Savings: ${CurrencyFormatter.formatNaira(totalSavings, showDecimals: false)}',
                          style: coTabularStyle(fontSize: 11, color: tokens.infoText),
                        ),
                      ],
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
