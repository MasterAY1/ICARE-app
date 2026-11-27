import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import 'co_shared_widgets.dart';

/// Interactive 4-stage Portfolio Lifecycle & Risk Intelligence Pipeline.
/// Live `fl_chart` Analytics Section for Portfolio Summary & Analytics.
class CoPortfolioAnalyticsSection extends StatelessWidget {
  final Map<String, dynamic> summary;
  final Map<String, dynamic> categorySummary;

  const CoPortfolioAnalyticsSection({
    super.key,
    required this.summary,
    required this.categorySummary,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);

    final catDefs = <({String key, String label, String fullLabel})>[
      (key: '12_week', label: '12W', fullLabel: '12-Week Loans'),
      (key: '24_week', label: '24W', fullLabel: '24-Week Loans'),
      (key: 'asset_all', label: 'Asset', fullLabel: 'Asset Financing'),
      (key: 'daily', label: 'Daily', fullLabel: 'Daily Loans'),
      (key: 'monthly', label: 'Monthly', fullLabel: 'Monthly Loans'),
    ];

    double maxCat = 0.0;
    final catValues = catDefs.map((c) {
      final m = categorySummary[c.key] as Map<String, dynamic>? ?? {};
      final cred = (m['active_credit'] as num?)?.toDouble() ?? 0.0;
      final out = (m['outstanding_balance'] as num?)?.toDouble() ?? 0.0;
      maxCat = math.max(maxCat, math.max(cred, out));
      return (label: c.label, fullLabel: c.fullLabel, credit: cred, outstanding: out);
    }).toList();

    final lifecycle = <({String label, int count, Color color})>[
      (label: 'On Loan', count: (summary['active_clients'] as num?)?.toInt() ?? 0, color: tokens.brandPrimary),
      (label: 'Completed', count: (summary['completed_clients'] as num?)?.toInt() ?? 0, color: tokens.successDot),
      (label: 'Registered', count: (summary['registered_clients'] as num?)?.toInt() ?? 0, color: tokens.infoDot),
      (label: 'Pending', count: (summary['pending_loan_clients'] as num?)?.toInt() ?? 0, color: tokens.warningDot),
      (label: 'Savings Only', count: (summary['savings_only_clients'] as num?)?.toInt() ?? 0, color: const Color(0xFF6366F1)),
      (label: 'Dormant', count: (summary['dormant_clients'] as num?)?.toInt() ?? 0, color: tokens.neutralDot),
      (label: 'Defaulters', count: (summary['defaulters'] as num?)?.toInt() ?? 0, color: tokens.dangerDot),
    ];

    final activeLifecycle = lifecycle.where((l) => l.count > 0).toList();
    final totalClients = activeLifecycle.fold<int>(0, (sum, item) => sum + item.count);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;

        final barCard = IcareCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product Category Exposure (Active Credit vs Outstanding)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Comparison of funded credit against remaining balance by product tenure',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 12),
              if (maxCat <= 0)
                const CoEmptyStateCard(
                  title: 'No Active Product Exposure',
                  message: 'Product exposure bars render once loans exist in this filtered scope.',
                  icon: Icons.bar_chart_rounded,
                )
              else
                Column(
                  children: [
                    SizedBox(
                      height: 190,
                      child: BarChart(
                        BarChartData(
                          maxY: maxCat * 1.2,
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
                                final item = catValues[groupIndex];
                                final lbl = rodIndex == 0 ? 'Active Credit' : 'Outstanding';
                                return BarTooltipItem(
                                  '${item.fullLabel}\n$lbl: ${CurrencyFormatter.formatNaira(rod.toY)}',
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
                                  if (idx < 0 || idx >= catValues.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      catValues[idx].label,
                                      style: TextStyle(fontSize: 9.5, color: tokens.textSecondary),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: List.generate(catValues.length, (i) {
                            final item = catValues[i];
                            return BarChartGroupData(
                              x: i,
                              barsSpace: 4,
                              barRods: [
                                BarChartRodData(
                                  toY: item.credit,
                                  width: 11,
                                  color: tokens.brandPrimary,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                ),
                                BarChartRodData(
                                  toY: item.outstanding,
                                  width: 11,
                                  color: tokens.warningDot,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        _LegendDot(color: tokens.brandPrimary, label: 'Active Credit'),
                        _LegendDot(color: tokens.warningDot, label: 'Outstanding Balance'),
                      ],
                    ),
                  ],
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
                'Client Lifecycle Distribution',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$totalClients categorized client profiles in active view',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 12),
              if (totalClients <= 0)
                const CoEmptyStateCard(
                  title: 'No Client Lifecycle Data',
                  message: 'Status distribution appears once client profiles match the filter.',
                  icon: Icons.pie_chart_outline_rounded,
                )
              else
                Column(
                  children: [
                    SizedBox(
                      height: 150,
                      child: PieChart(
                        PieChartData(
                          centerSpaceRadius: 32,
                          sectionsSpace: 2,
                          sections: activeLifecycle
                              .map(
                                (item) => PieChartSectionData(
                                  value: item.count.toDouble(),
                                  color: item.color,
                                  radius: 32,
                                  title: '${((item.count / totalClients) * 100).round()}%',
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
                      children: activeLifecycle
                          .map(
                            (item) => _LegendDot(
                              color: item.color,
                              label: '${item.label} (${item.count})',
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }
}
