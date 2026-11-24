import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../data/models/report_models.dart';

/// Regional supervisory charts for Area Manager (Tier-2) Reports & Export:
/// 1) Supervised Branches Collections vs Expected bar comparison.
/// 2) District Month-End Certification Pipeline breakdown donut chart.
class AmRegionalAnalyticsCharts extends StatefulWidget {
  final List<AreaBranchRow> branchRows;
  final List<MonthlyWorkflowPendingBranchModel> submissions;

  const AmRegionalAnalyticsCharts({
    super.key,
    required this.branchRows,
    required this.submissions,
  });

  @override
  State<AmRegionalAnalyticsCharts> createState() =>
      _AmRegionalAnalyticsChartsState();
}

class _AmRegionalAnalyticsChartsState extends State<AmRegionalAnalyticsCharts> {
  final NumberFormat _compactNgn = NumberFormat.compactCurrency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 1,
  );
  final NumberFormat _fullNgn = NumberFormat('#,##0.00');
  int _touchedPieIndex = -1;

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final bool reduced = IcareFluidMotion.isReduced(context);
    final Duration animDuration =
        reduced ? Duration.zero : const Duration(milliseconds: 280);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;
        final Widget barCard = _buildRegionalBarChart(tokens, animDuration);
        final Widget pipelineCard =
            _buildCertificationPipelineChart(tokens, animDuration);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 62, child: barCard),
              const SizedBox(width: 14),
              Expanded(flex: 38, child: pipelineCard),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            barCard,
            const SizedBox(height: 14),
            pipelineCard,
          ],
        );
      },
    );
  }

  Widget _buildRegionalBarChart(
    IcareSurfaceTokens tokens,
    Duration animDuration,
  ) {
    final List<AreaBranchRow> sorted =
        List<AreaBranchRow>.from(widget.branchRows)
          ..sort(
            (a, b) => (b.collectionsReceived + b.expectedCollections)
                .compareTo(a.collectionsReceived + a.expectedCollections),
          );
    final List<AreaBranchRow> topBranches = sorted.take(6).toList();

    final List<AreaBranchRow> series = topBranches.isNotEmpty
        ? topBranches
        : const [
            AreaBranchRow(
              branch: 'District',
              peopleOnLoan: 0,
              activeLoans: 0,
              activeSavers: 0,
              totalSavings: 0,
              collectionsReceived: 0,
              expectedCollections: 0,
              collectionEfficiency: 0,
              outstandingPortfolio: 0,
              parPercentage: 0,
              status: 'HEALTHY',
            ),
          ];

    double maxVal = 0.0;
    for (final b in series) {
      maxVal = math.max(
        maxVal,
        math.max(b.collectionsReceived, b.expectedCollections),
      );
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
                      'Supervised Branches: Collections vs Expected',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sorted.length > 6
                          ? 'Top 6 district branches ranked by collection volume'
                          : 'Comparative collection performance across ${widget.branchRows.length} supervised branch${widget.branchRows.length == 1 ? '' : 'es'}',
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
                color: const Color(0xFF475569),
                label: 'Expected Collections',
                tokens: tokens,
              ),
              _LegendChip(
                color: const Color(0xFF10B981),
                label: 'Collections Received',
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
                      final branch = series[group.x.toInt()];
                      final String label =
                          rodIndex == 0 ? 'Expected' : 'Received';
                      return BarTooltipItem(
                        '${branch.branch}\n$label: ₦${_fullNgn.format(rod.toY)} (${branch.collectionEfficiency.toStringAsFixed(1)}%)',
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
                        if (idx < 0 || idx >= series.length) {
                          return const SizedBox.shrink();
                        }
                        final String rawName = series[idx].branch;
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
                  series.length,
                  (index) {
                    final item = series[index];
                    return BarChartGroupData(
                      x: index,
                      barsSpace: 5,
                      barRods: [
                        BarChartRodData(
                          toY: math.max(0.0, item.expectedCollections),
                          width: series.length <= 3 ? 18 : 12,
                          color: const Color(0xFF475569),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: math.max(0.0, item.collectionsReceived),
                          width: series.length <= 3 ? 18 : 12,
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

  Widget _buildCertificationPipelineChart(
    IcareSurfaceTokens tokens,
    Duration animDuration,
  ) {
    final int awaitingAm =
        widget.submissions.where((s) => s.status == 'BM_SUBMITTED').length;
    final int amSignedOrSealed = widget.submissions
        .where(
          (s) => const {
            'AM_VERIFIED',
            'AREA_SEALED',
            'ADMIN_LOCKED',
          }.contains(s.status),
        )
        .length;
    final int returned = widget.submissions
        .where((s) => s.status == 'RETURNED_FOR_CORRECTION')
        .length;
    final int pendingBm =
        widget.submissions.where((s) => s.status == 'DRAFT').length;

    final int total = widget.submissions.length;
    final int submittedCount = total - pendingBm;

    final List<_PipelineSlice> slices = [
      _PipelineSlice(
        label: 'Awaiting AM Sign-Off',
        count: awaitingAm,
        color: const Color(0xFFD97706),
      ),
      _PipelineSlice(
        label: 'AM Signed / Sealed',
        count: amSignedOrSealed,
        color: const Color(0xFF10B981),
      ),
      _PipelineSlice(
        label: 'Returned to BM',
        count: returned,
        color: const Color(0xFFDC2626),
      ),
      _PipelineSlice(
        label: 'Pending BM Submission',
        count: pendingBm,
        color: tokens.textMuted,
      ),
    ];

    final List<_PipelineSlice> activeSlices =
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
                      'District Month-End Certification Pipeline',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'BM submission and supervisory endorsement readiness',
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
                    sectionsSpace: activeSlices.isEmpty ? 0 : 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (activeSlices.isEmpty) return;
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
                    sections: activeSlices.isEmpty
                        ? [
                            PieChartSectionData(
                              color: tokens.borderSubtle,
                              value: 1.0,
                              radius: 24,
                              showTitle: false,
                            ),
                          ]
                        : List<PieChartSectionData>.generate(
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
                      '$submittedCount/$total',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'Submitted',
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
                    '${slice.count} (${total > 0 ? ((slice.count / total) * 100).round() : 0}%)',
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

class _PipelineSlice {
  final String label;
  final int count;
  final Color color;

  const _PipelineSlice({
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
