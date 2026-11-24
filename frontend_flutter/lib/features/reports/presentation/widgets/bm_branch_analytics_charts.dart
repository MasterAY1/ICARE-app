import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../data/models/report_models.dart';

/// Branch-level interactive analytics charts for the Branch Manager workspace:
/// 1) Officer / Branch Disbursed vs Period Collections bar comparison.
/// 2) Branch Portfolio & Liquidity Mix donut breakdown.
class BmBranchAnalyticsCharts extends StatefulWidget {
  final MonthlyParityData parityData;

  const BmBranchAnalyticsCharts({
    super.key,
    required this.parityData,
  });

  @override
  State<BmBranchAnalyticsCharts> createState() =>
      _BmBranchAnalyticsChartsState();
}

class _BmBranchAnalyticsChartsState extends State<BmBranchAnalyticsCharts> {
  final NumberFormat _compactNgn = NumberFormat.compactCurrency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 1,
  );
  final NumberFormat _fullNgn = NumberFormat('#,##0.00');
  int _touchedPieIndex = -1;

  double _lookupOfficerMetric(
    MonthlyParityOfficer officer,
    List<String> metricFragments,
  ) {
    for (final row in widget.parityData.rows) {
      final lowerMetric = row.metric.toLowerCase();
      final matches = metricFragments.any((f) => lowerMetric.contains(f));
      if (!matches) continue;
      final dynamic raw =
          row.values[officer.name] ?? row.values[officer.officerId];
      if (raw is num) return raw.toDouble();
      if (raw is String) return double.tryParse(raw) ?? 0.0;
    }
    return 0.0;
  }

  List<_OfficerBarPoint> _buildOfficerSeries() {
    final List<_OfficerBarPoint> points = [];
    for (final o in widget.parityData.officers) {
      final double disbursed = _lookupOfficerMetric(
        o,
        const ['principal disbursed', 'sales (credit)', 'disbursed'],
      );
      final double collected = _lookupOfficerMetric(
        o,
        const [
          'collections received',
          'installment collection',
          'repayments',
        ],
      );
      points.add(
        _OfficerBarPoint(
          label: o.name,
          disbursed: math.max(0.0, disbursed),
          collected: math.max(0.0, collected),
        ),
      );
    }

    points.sort(
      (a, b) =>
          (b.collected + b.disbursed).compareTo(a.collected + a.disbursed),
    );

    final cards = widget.parityData.summaryCards;
    final bool allZero = points.isEmpty ||
        points.every((p) => p.disbursed <= 0 && p.collected <= 0);
    if (allZero && (cards.disbursedPrincipal > 0 || cards.collections > 0)) {
      return [
        _OfficerBarPoint(
          label: widget.parityData.branchName.isNotEmpty
              ? widget.parityData.branchName
              : 'Branch Total',
          disbursed: math.max(0.0, cards.disbursedPrincipal),
          collected: math.max(0.0, cards.collections),
        ),
      ];
    }

    if (points.isEmpty) {
      return [
        const _OfficerBarPoint(
          label: 'Branch Total',
          disbursed: 0.0,
          collected: 0.0,
        ),
      ];
    }

    return points.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final bool reduced = IcareFluidMotion.isReduced(context);
    final Duration animDuration =
        reduced ? Duration.zero : const Duration(milliseconds: 280);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;
        final Widget barCard = _buildOfficerBarChart(tokens, animDuration);
        final Widget mixCard = _buildLiquidityMixChart(tokens, animDuration);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 60, child: barCard),
              const SizedBox(width: 14),
              Expanded(flex: 40, child: mixCard),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            barCard,
            const SizedBox(height: 14),
            mixCard,
          ],
        );
      },
    );
  }

  Widget _buildOfficerBarChart(
    IcareSurfaceTokens tokens,
    Duration animDuration,
  ) {
    final List<_OfficerBarPoint> points = _buildOfficerSeries();
    double maxVal = 0.0;
    for (final p in points) {
      maxVal = math.max(maxVal, math.max(p.disbursed, p.collected));
    }
    final double chartTop = math.max(maxVal, 100000.0) * 1.18;

    return IcareCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 18,
                color: tokens.brandPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Officer Disbursed vs Period Collections',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.parityData.officers.length > 6
                          ? 'Top 6 credit officers by activity for ${widget.parityData.monthLabel}'
                          : 'Activity comparison across ${widget.parityData.monthLabel}',
                      softWrap: true,
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _LegendChip(
                color: const Color(0xFF1D4ED8),
                label: 'Disbursed Principal',
                tokens: tokens,
              ),
              _LegendChip(
                color: const Color(0xFF10B981),
                label: 'Period Collections',
                tokens: tokens,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 210,
            child: BarChart(
              duration: animDuration,
              BarChartData(
                maxY: chartTop,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartTop / 4,
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
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final point = points[group.x.toInt()];
                      final series =
                          rodIndex == 0 ? 'Disbursed' : 'Collections';
                      return BarTooltipItem(
                        '${point.label}\n$series: ₦${_fullNgn.format(rod.toY)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
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
                      reservedSize: 56,
                      interval: chartTop / 4,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          meta: meta,
                          space: 6,
                          child: Text(
                            _compactNgn.format(value),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: tokens.textMuted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (value, meta) {
                        final int idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final String rawName = points[idx].label;
                        final String shortName = rawName.length > 11
                            ? '${rawName.substring(0, 10)}...'
                            : rawName;
                        return SideTitleWidget(
                          meta: meta,
                          space: 8,
                          child: Text(
                            shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List<BarChartGroupData>.generate(
                  points.length,
                  (index) {
                    final item = points[index];
                    return BarChartGroupData(
                      x: index,
                      barsSpace: 5,
                      barRods: [
                        BarChartRodData(
                          toY: item.disbursed,
                          width: points.length <= 3 ? 18 : 12,
                          color: const Color(0xFF1D4ED8),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: item.collected,
                          width: points.length <= 3 ? 18 : 12,
                          color: const Color(0xFF10B981),
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
  }

  Widget _buildLiquidityMixChart(
    IcareSurfaceTokens tokens,
    Duration animDuration,
  ) {
    final cards = widget.parityData.summaryCards;
    final double closingCredit = math.max(0.0, cards.closingCredit);
    final double closingSavings = math.max(0.0, cards.closingSavings);
    final double bankDeposits = math.max(0.0, cards.bankDeposits);
    final double totalVolume = closingCredit + closingSavings + bankDeposits;

    final List<_MixSlice> slices = [
      _MixSlice(
        label: 'Closing Credit',
        amount: closingCredit,
        color: tokens.brandPrimaryDark,
      ),
      _MixSlice(
        label: 'Closing Savings',
        amount: closingSavings,
        color: const Color(0xFF10B981),
      ),
      _MixSlice(
        label: 'Transit Bank Deposits',
        amount: bankDeposits,
        color: const Color(0xFF2563EB),
      ),
    ];

    final List<_MixSlice> nonZeroSlices =
        slices.where((s) => s.amount > 0).toList();

    return IcareCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_outline_rounded,
                size: 18,
                color: tokens.brandPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Branch Portfolio & Liquidity Mix',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Closing balances across credit, savings, and bank remittances',
                      softWrap: true,
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  duration: animDuration,
                  PieChartData(
                    centerSpaceRadius: 44,
                    sectionsSpace: nonZeroSlices.isEmpty ? 0 : 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (nonZeroSlices.isEmpty) return;
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            _touchedPieIndex = -1;
                            return;
                          }
                          _touchedPieIndex =
                              response.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sections: nonZeroSlices.isEmpty
                        ? [
                            PieChartSectionData(
                              color: tokens.borderSubtle,
                              value: 1.0,
                              radius: 24,
                              showTitle: false,
                            ),
                          ]
                        : List<PieChartSectionData>.generate(
                            nonZeroSlices.length,
                            (index) {
                              final slice = nonZeroSlices[index];
                              final bool isTouched = index == _touchedPieIndex;
                              return PieChartSectionData(
                                color: slice.color,
                                value: slice.amount,
                                radius: isTouched ? 30 : 24,
                                showTitle: false,
                              );
                            },
                          ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _compactNgn.format(totalVolume),
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Text(
                      'Total Balances',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final slice in slices) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.5),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: slice.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      slice.label,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _compactNgn.format(slice.amount),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfficerBarPoint {
  final String label;
  final double disbursed;
  final double collected;

  const _OfficerBarPoint({
    required this.label,
    required this.disbursed,
    required this.collected,
  });
}

class _MixSlice {
  final String label;
  final double amount;
  final Color color;

  const _MixSlice({
    required this.label,
    required this.amount,
    required this.color,
  });
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  final IcareSurfaceTokens tokens;

  const _LegendChip({
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            softWrap: true,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
