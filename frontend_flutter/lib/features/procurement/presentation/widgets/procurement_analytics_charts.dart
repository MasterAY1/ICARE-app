import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';

/// Live Asset & Procurement Analytics Charts:
/// - Branch Retail Value vs Wholesale Cost Value BarChart
/// - Catalog SKU Stock & Costing Readiness Donut
/// Bound strictly to live overview/matrix API payloads (zero FlowCards).
class ProcurementAnalyticsSection extends StatelessWidget {
  final List<Map<String, dynamic>> branchSummaries;
  final List<Map<String, dynamic>> matrixItems;

  const ProcurementAnalyticsSection({
    super.key,
    required this.branchSummaries,
    required this.matrixItems,
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

    final branches = branchSummaries.take(8).toList();
    double maxVal = 0.0;
    for (final b in branches) {
      final retail = (b['inventory_cash_value'] as num?)?.toDouble() ?? 0.0;
      final cost = (b['inventory_cost_value'] as num?)?.toDouble() ?? 0.0;
      maxVal = math.max(maxVal, math.max(retail, cost));
    }
    final hasBarData = branches.isNotEmpty && maxVal > 0;
    final barTop = hasBarData ? maxVal * 1.24 : 1000.0;

    final totalSkus = matrixItems.length;
    final readyAndStocked = matrixItems
        .where((x) =>
            x['has_cost_price'] == true &&
            ((x['total_available'] as num?)?.toInt() ?? 0) > 0)
        .length;
    final inStockPendingCost = matrixItems
        .where((x) =>
            x['has_cost_price'] != true &&
            ((x['total_available'] as num?)?.toInt() ?? 0) > 0)
        .length;
    final outOfStock = math.max(
        0, totalSkus - readyAndStocked - inStockPendingCost);

    final slices = [
      (
        label: 'Costed & In-Stock',
        count: readyAndStocked,
        color: tokens.successDot,
      ),
      (
        label: 'In-Stock (Cost Pending)',
        count: inStockPendingCost,
        color: tokens.warningDot,
      ),
      (
        label: 'Out of Stock',
        count: outOfStock,
        color: tokens.dangerDot,
      ),
    ].where((s) => s.count > 0).toList();

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
                  'Branch Stock Valuation Comparison',
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
              _ProcLegendDot(
                color: tokens.brandPrimary,
                label: 'Retail Cash Value',
                tokens: tokens,
              ),
              _ProcLegendDot(
                color: tokens.infoDot,
                label: 'Wholesale Cost Value',
                tokens: tokens,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasBarData)
            _ProcEmptyState(
              tokens: tokens,
              height: 175,
              message: branches.isEmpty
                  ? 'No active branches in procurement inventory summary'
                  : 'Zero physical inventory value recorded across branches',
            )
          else
            SizedBox(
              height: 195,
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
                        final b = branches[group.x.toInt()];
                        final series =
                            rodIdx == 0 ? 'Retail Value' : 'Cost Value';
                        return BarTooltipItem(
                          '${b['branch_name'] ?? 'Branch'}\n$series: ${CurrencyFormatter.formatNaira(rod.toY)}',
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
                          if (idx < 0 || idx >= branches.length) {
                            return const SizedBox.shrink();
                          }
                          final raw =
                              branches[idx]['branch_name']?.toString() ?? '';
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
                    branches.length,
                    (idx) {
                      final b = branches[idx];
                      final retail =
                          (b['inventory_cash_value'] as num?)?.toDouble() ??
                              0.0;
                      final cost =
                          (b['inventory_cost_value'] as num?)?.toDouble() ??
                              0.0;
                      final w = branches.length <= 4 ? 14.0 : 9.0;
                      return BarChartGroupData(
                        x: idx,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: math.max(0.0, retail),
                            width: w,
                            color: tokens.brandPrimary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: math.max(0.0, cost),
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

    final donutCard = IcareCard(
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
                  'Catalog Stock & Cost Readiness',
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
            '$totalSkus total catalog SKUs tracked',
            style: TextStyle(
              fontSize: 11.5,
              color: tokens.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          if (totalSkus == 0 || slices.isEmpty)
            _ProcEmptyState(
              tokens: tokens,
              height: 175,
              message: 'No asset catalog SKUs configured yet',
            )
          else ...[
            SizedBox(
              height: 140,
              child: PieChart(
                duration: animDuration,
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: slices.map((s) {
                    final pct = (s.count / totalSkus) * 100;
                    return PieChartSectionData(
                      value: s.count.toDouble(),
                      color: s.color,
                      radius: 32,
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
                      '${s.count} SKUs',
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
              donutCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: barCard),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: donutCard),
          ],
        );
      },
    );
  }
}

class _ProcLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final IcareSurfaceTokens tokens;

  const _ProcLegendDot({
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

class _ProcEmptyState extends StatelessWidget {
  final IcareSurfaceTokens tokens;
  final double height;
  final String message;

  const _ProcEmptyState({
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
