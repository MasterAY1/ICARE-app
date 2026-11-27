import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../data/models/admin_dashboard_models.dart';

/// Live Cross-Branch Capital vs Active Book BarChart and Institutional Mix Donut
/// for the Executive Portfolio Analytics screen. Strictly zero FlowCards.
class AdminPortfolioChartsSection extends StatelessWidget {
  final List<BranchPerformanceItemModel> branches;
  final PerformanceSummaryModel summary;
  final int year;

  const AdminPortfolioChartsSection({
    super.key,
    required this.branches,
    required this.summary,
    required this.year,
  });

  static final NumberFormat _compactNgn = NumberFormat.compactCurrency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 1,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final reduced = IcareFluidMotion.isReduced(context);
    final animDuration =
        reduced ? Duration.zero : const Duration(milliseconds: 280);

    final topBranches = branches.take(8).toList();
    double maxVal = 0.0;
    for (final b in topBranches) {
      maxVal = math.max(maxVal, math.max(b.disbPrincipal, b.activeCreditBook));
    }
    final hasBarData = topBranches.isNotEmpty && maxVal > 0;
    final barTop = hasBarData ? maxVal * 1.24 : 1000.0;

    final activeBook = math.max(0.0, summary.totalActiveCredit);
    final savingsPool = math.max(0.0, summary.totalNetSavings);
    final overduePool = math.max(0.0, summary.totalOverdue);
    final mixTotal = activeBook + savingsPool + overduePool;
    final slices = [
      (label: 'Active Credit', value: activeBook, color: tokens.brandPrimary),
      (label: 'Net Savings', value: savingsPool, color: tokens.infoDot),
      (label: 'Overdue Arrears', value: overduePool, color: tokens.dangerDot),
    ].where((s) => s.value > 0).toList();

    final barCard = IcareCard(
      padding: const EdgeInsets.all(16),
      topAccentColor: tokens.brandPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded,
                  size: 18, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Disbursed Principal vs Active Credit ($year)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _PortfolioLegendItem(
                color: tokens.brandPrimary,
                label: 'Principal Disbursed',
                tokens: tokens,
              ),
              _PortfolioLegendItem(
                color: tokens.infoDot,
                label: 'Active Credit Book',
                tokens: tokens,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasBarData)
            _AdminChartEmptyState(
              tokens: tokens,
              height: 185,
              message: branches.isEmpty
                  ? 'No branch rankings available for $year'
                  : 'Zero disbursed principal or active credit recorded for $year',
            )
          else
            SizedBox(
              height: 205,
              child: BarChart(
                duration: animDuration,
                BarChartData(
                  maxY: barTop,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: barTop / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: tokens.borderSubtle,
                      strokeWidth: 1,
                      dashArray: const [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => tokens.brandPrimaryDark,
                      tooltipBorderRadius: BorderRadius.circular(8),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, _, rod, rodIdx) {
                        final b = topBranches[group.x.toInt()];
                        final series =
                            rodIdx == 0 ? 'Disbursed' : 'Active Book';
                        return BarTooltipItem(
                          '${b.branchName}\n$series: ${CurrencyFormatter.formatNaira(rod.toY)}\nPAR: ${b.parPct.toStringAsFixed(1)}%',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
                        reservedSize: 48,
                        interval: barTop / 4,
                        getTitlesWidget: (val, _) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            _compactNgn.format(val),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10,
                              color: tokens.textMuted,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
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
                          if (idx < 0 || idx >= topBranches.length) {
                            return const SizedBox.shrink();
                          }
                          final raw = topBranches[idx].branchName;
                          final label = raw.length > 9
                              ? '${raw.substring(0, 8)}.'
                              : raw;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: tokens.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List<BarChartGroupData>.generate(
                    topBranches.length,
                    (idx) {
                      final b = topBranches[idx];
                      final w = topBranches.length <= 4 ? 14.0 : 9.0;
                      return BarChartGroupData(
                        x: idx,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: math.max(0.0, b.disbPrincipal),
                            width: w,
                            color: tokens.brandPrimary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: math.max(0.0, b.activeCreditBook),
                            width: w,
                            color: tokens.infoDot,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final mixCard = IcareCard(
      padding: const EdgeInsets.all(16),
      topAccentColor: tokens.infoDot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_large_rounded, size: 18, color: tokens.infoDot),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Institutional Book & Reserve Mix',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Average PAR exposure: ${summary.averagePar.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11.5,
              color: tokens.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          if (mixTotal <= 0 || slices.isEmpty)
            _AdminChartEmptyState(
              tokens: tokens,
              height: 185,
              message: 'No active credit or savings reserve balances in $year',
            )
          else ...[
            SizedBox(
              height: 150,
              child: PieChart(
                duration: animDuration,
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 32,
                  sections: slices.map((s) {
                    final pct = (s.value / mixTotal) * 100;
                    return PieChartSectionData(
                      value: s.value,
                      color: s.color,
                      radius: 34,
                      title: pct >= 9 ? '${pct.toStringAsFixed(0)}%' : '',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...slices.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatNaira(s.value),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              barCard,
              const SizedBox(height: 14),
              mixCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: barCard),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: mixCard),
          ],
        );
      },
    );
  }
}

class _PortfolioLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final IcareSurfaceTokens tokens;

  const _PortfolioLegendItem({
    required this.color,
    required this.label,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(width: 6),
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

class _AdminChartEmptyState extends StatelessWidget {
  final IcareSurfaceTokens tokens;
  final double height;
  final String message;

  const _AdminChartEmptyState({
    required this.tokens,
    required this.height,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: tokens.textMuted,
        ),
      ),
    );
  }
}
