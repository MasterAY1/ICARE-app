import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../data/models/co_dashboard_models.dart';
import 'co_shared_widgets.dart';

double _numVal(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;

/// Live `fl_chart` analytics section for the Credit Officer Dashboard.
/// Plots (1) Group Expected vs Collected Bar Chart and (2) Daily Repayment Status Donut.
class CoDashboardAnalyticsSection extends StatelessWidget {
  final CoDashboardData data;

  const CoDashboardAnalyticsSection({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _GroupCollectionBarCard(data: data)),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: _StatusMixDonutCard(data: data)),
            ],
          );
        }
        return Column(
          children: [
            _GroupCollectionBarCard(data: data),
            const SizedBox(height: 14),
            _StatusMixDonutCard(data: data),
          ],
        );
      },
    );
  }
}

class _GroupCollectionBarCard extends StatelessWidget {
  final CoDashboardData data;
  const _GroupCollectionBarCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final rows = data.meetingPortfolio.take(8).toList();

    final entries = rows.map((m) {
      final name = (m['Group Name'] ?? m['group_name'] ?? 'Group').toString();
      final exp = _numVal(
        m['Expected (₦)'] ??
            m['Expected Collection'] ??
            m['expected_repayment'] ??
            m['Expected'],
      );
      final col = _numVal(
        m['Collected (₦)'] ?? m['Collected'] ?? m['collected_repayment'],
      );
      return (name: name, expected: exp, collected: col);
    }).toList();

    double maxVal = 0.0;
    for (final e in entries) {
      maxVal = math.max(maxVal, math.max(e.expected, e.collected));
    }

    return IcareCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meeting Group Performance',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Expected target vs actual collections by group',
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
              _ChartLegendDot(color: tokens.infoDot, label: 'Expected'),
              const SizedBox(width: 10),
              _ChartLegendDot(color: tokens.brandPrimary, label: 'Collected'),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty || maxVal <= 0)
            const CoEmptyStateCard(
              title: 'No Scheduled Collection Bars Yet',
              message:
                  'Live group collection bars appear once meeting schedules or collections are loaded for today.',
              icon: Icons.bar_chart_rounded,
            )
          else
            SizedBox(
              height: 210,
              child: BarChart(
                BarChartData(
                  maxY: maxVal * 1.18,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: tokens.borderSubtle,
                      strokeWidth: 0.8,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => tokens.surfaceElevated,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final item = entries[groupIndex];
                        final tag = rodIndex == 0 ? 'Expected' : 'Collected';
                        return BarTooltipItem(
                          '${item.name}\n$tag: ${CurrencyFormatter.formatNaira(rod.toY)}',
                          coTabularStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        getTitlesWidget: (val, _) => Text(
                          _compactNaira(val),
                          style: coTabularStyle(
                            fontSize: 10,
                            color: tokens.textMuted,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (val, _) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          final raw = entries[idx].name;
                          final short =
                              raw.length > 9 ? '${raw.substring(0, 8)}..' : raw;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              short,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: tokens.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(entries.length, (i) {
                    final e = entries[i];
                    return BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: e.expected,
                          color: tokens.infoDot.withValues(alpha: 0.75),
                          width: entries.length > 5 ? 9 : 12,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: e.collected,
                          color: tokens.brandPrimary,
                          width: entries.length > 5 ? 9 : 12,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
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
  }
}

class _StatusMixDonutCard extends StatelessWidget {
  final CoDashboardData data;
  const _StatusMixDonutCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final st = data.repaymentStatus;

    final slices = <({String label, double value, Color color})>[
      (
        label: 'Normal Payment',
        value: _numVal(st['normal_payment']?['amount']),
        color: tokens.brandPrimary,
      ),
      (
        label: 'Full Payoff',
        value: _numVal(st['full_payment']?['amount']),
        color: const Color(0xFF0D9488),
      ),
      (
        label: 'Excess Payment',
        value: _numVal(st['excess_payment']?['amount']),
        color: tokens.infoDot,
      ),
      (
        label: 'Part Payment',
        value: _numVal(st['part_payment']?['amount']),
        color: tokens.warningDot,
      ),
      (
        label: 'Not Paid',
        value: _numVal(st['not_paid']?['amount']),
        color: tokens.dangerDot,
      ),
    ].where((s) => s.value > 0).toList();

    final total = slices.fold<double>(0.0, (sum, s) => sum + s.value);

    return IcareCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repayment Status Mix',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Share across payoff, on-schedule, part-pay & unpaid',
            style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
          ),
          const SizedBox(height: 14),
          if (slices.isEmpty || total <= 0)
            const CoEmptyStateCard(
              title: 'Zero Collection Status Volume',
              message:
                  'Status distribution appears once repayments or expected dues are active for the date.',
              icon: Icons.pie_chart_outline_rounded,
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 156,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 34,
                      sectionsSpace: 2,
                      sections: slices
                          .map(
                            (s) => PieChartSectionData(
                              value: s.value,
                              color: s.color,
                              radius: 34,
                              title:
                                  '${((s.value / total) * 100).toStringAsFixed(0)}%',
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: slices
                      .map(
                        (s) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: s.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${s.label}: ${CurrencyFormatter.formatNaira(s.value, showDecimals: false)}',
                              style: coTabularStyle(
                                fontSize: 11,
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
  }
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegendDot({required this.color, required this.label});

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
        const SizedBox(width: 5),
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

String _compactNaira(double val) {
  if (val >= 1000000) return '₦${(val / 1000000).toStringAsFixed(1)}M';
  if (val >= 1000) return '₦${(val / 1000).toStringAsFixed(0)}k';
  return '₦${val.toStringAsFixed(0)}';
}
