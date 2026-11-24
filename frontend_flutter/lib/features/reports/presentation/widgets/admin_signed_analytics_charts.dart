import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../data/models/report_models.dart';

/// Executive data-visualization charts driven exclusively by AM-signed and reviewed
/// branch reports (`AM_VERIFIED`, `AREA_SEALED`, `ADMIN_LOCKED`).
class AdminSignedAnalyticsCharts extends StatefulWidget {
  final List<MonthlyWorkflowPendingBranchModel> signedReports;

  const AdminSignedAnalyticsCharts({
    super.key,
    required this.signedReports,
  });

  @override
  State<AdminSignedAnalyticsCharts> createState() =>
      _AdminSignedAnalyticsChartsState();
}

class _AdminSignedAnalyticsChartsState
    extends State<AdminSignedAnalyticsCharts> {
  final NumberFormat _compactNgn = NumberFormat.compactCurrency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 1,
  );
  final NumberFormat _fullNgn = NumberFormat('#,##0.00');
  int _touchedPieIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.signedReports.isEmpty) {
      return const SizedBox.shrink();
    }

    final tokens = IcareSurfaceTokens.of(context);
    final bool reduced = IcareFluidMotion.isReduced(context);
    final Duration animDuration =
        reduced ? Duration.zero : const Duration(milliseconds: 280);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;
        final Widget barCard =
            _buildBranchPerformanceChart(tokens, animDuration);
        final Widget statusCard =
            _buildWorkflowBreakdownChart(tokens, animDuration);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 62, child: barCard),
              const SizedBox(width: 14),
              Expanded(flex: 38, child: statusCard),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            barCard,
            const SizedBox(height: 14),
            statusCard,
          ],
        );
      },
    );
  }

  Widget _buildBranchPerformanceChart(
    IcareSurfaceTokens tokens,
    Duration animDuration,
  ) {
    final List<MonthlyWorkflowPendingBranchModel> sorted =
        List<MonthlyWorkflowPendingBranchModel>.from(widget.signedReports)
          ..sort(
            (a, b) => (b.collections + b.disbursedPrincipal)
                .compareTo(a.collections + a.disbursedPrincipal),
          );
    final List<MonthlyWorkflowPendingBranchModel> topBranches =
        sorted.take(6).toList();

    double maxVal = 0.0;
    for (final b in topBranches) {
      maxVal = math.max(maxVal, math.max(b.disbursedPrincipal, b.collections));
    }
    if (maxVal <= 0) maxVal = 100000.0;
    final double chartTop = maxVal * 1.18;

    return IcareCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded,
                  size: 18, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signed Branches: Disbursed vs Collections',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sorted.length > 6
                          ? 'Top 6 AM-signed branches by volume for selected period'
                          : 'Verified volume across ${topBranches.length} AM-signed branch${topBranches.length == 1 ? '' : 'es'}',
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                      softWrap: true,
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
                color: tokens.brandPrimaryDark,
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
                      final branch = topBranches[group.x.toInt()];
                      final series =
                          rodIndex == 0 ? 'Disbursed' : 'Collections';
                      return BarTooltipItem(
                        '${branch.branchName}\n$series: ₦${_fullNgn.format(rod.toY)}',
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
                        if (idx < 0 || idx >= topBranches.length) {
                          return const SizedBox.shrink();
                        }
                        final String rawName = topBranches[idx].branchName;
                        final String shortName = rawName.length > 10
                            ? '${rawName.substring(0, 9)}...'
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
                  topBranches.length,
                  (index) {
                    final item = topBranches[index];
                    return BarChartGroupData(
                      x: index,
                      barsSpace: 5,
                      barRods: [
                        BarChartRodData(
                          toY: item.disbursedPrincipal,
                          width: topBranches.length <= 3 ? 18 : 12,
                          color: tokens.brandPrimaryDark,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: item.collections,
                          width: topBranches.length <= 3 ? 18 : 12,
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

  Widget _buildWorkflowBreakdownChart(
    IcareSurfaceTokens tokens,
    Duration animDuration,
  ) {
    final int endorsedCount =
        widget.signedReports.where((r) => r.status == 'AM_VERIFIED').length;
    final int sealedCount =
        widget.signedReports.where((r) => r.status == 'AREA_SEALED').length;
    final int lockedCount =
        widget.signedReports.where((r) => r.status == 'ADMIN_LOCKED').length;
    final int total = widget.signedReports.length;

    final List<_StatusSlice> slices = [
      _StatusSlice(
        label: 'AM Signed (Ready to Lock)',
        count: endorsedCount,
        color: const Color(0xFF10B981),
      ),
      _StatusSlice(
        label: 'Regionally Sealed',
        count: sealedCount,
        color: const Color(0xFF2563EB),
      ),
      _StatusSlice(
        label: 'Locked & Archived',
        count: lockedCount,
        color:
            tokens.isDark ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
      ),
    ];

    final List<_StatusSlice> activeSlices =
        slices.where((s) => s.count > 0).toList();

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
                      'Executive Archival Progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Distribution of Area Manager-endorsed submissions',
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                      softWrap: true,
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
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
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
                    sections: List<PieChartSectionData>.generate(
                      activeSlices.length,
                      (index) {
                        final slice = activeSlices[index];
                        final bool isTouched = index == _touchedPieIndex;
                        return PieChartSectionData(
                          color: slice.color,
                          value: slice.count.toDouble(),
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
                    Text(
                      '$total',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'AM Signed',
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
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      softWrap: true,
                    ),
                  ),
                  Text(
                    '${slice.count} (${total > 0 ? ((slice.count / total) * 100).round() : 0}%)',
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

class _StatusSlice {
  final String label;
  final int count;
  final Color color;

  const _StatusSlice({
    required this.label,
    required this.count,
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
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }
}
