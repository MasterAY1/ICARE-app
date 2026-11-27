import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../data/models/am_dashboard_models.dart';

/// Live Multi-Chart Branch Comparison & Regional Portfolio Analytics.
/// Bound 100% to API records (zero fabricated fallback series).
class AmBranchPerformanceCharts extends StatefulWidget {
  final RegionalSummaryModel regionalSummary;
  final List<BranchPerformanceItemModel> branches;
  final ValueChanged<BranchPerformanceItemModel> onInspectBranch;

  const AmBranchPerformanceCharts({
    super.key,
    required this.regionalSummary,
    required this.branches,
    required this.onInspectBranch,
  });

  @override
  State<AmBranchPerformanceCharts> createState() =>
      _AmBranchPerformanceChartsState();
}

class _AmBranchPerformanceChartsState extends State<AmBranchPerformanceCharts> {
  /// 0 = Collections vs Target, 1 = Disbursed vs Full Payoffs, 2 = Vault Reserve
  int _chartMode = 0;

  final NumberFormat _compactNgn = NumberFormat.compactCurrency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 1,
  );
  final NumberFormat _fullNgn = NumberFormat('#,##0');

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final reduced = IcareFluidMotion.isReduced(context);
    final animDuration =
        reduced ? Duration.zero : const Duration(milliseconds: 280);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;
        final mainChart = _buildBranchBarChartCard(tokens, animDuration);
        final portfolioSplit = _buildRegionalSplitCard(tokens, animDuration);

        if (!isWide) {
          return Column(
            children: [
              mainChart,
              const SizedBox(height: 16),
              portfolioSplit,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: mainChart),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: portfolioSplit),
          ],
        );
      },
    );
  }

  Widget _buildBranchBarChartCard(
    IcareSurfaceTokens tokens,
    Duration animDuration,
  ) {
    final branches = widget.branches;
    double maxVal = 0.0;
    for (final b in branches) {
      if (_chartMode == 0) {
        maxVal = math.max(maxVal, math.max(b.expectedCollection, b.collected));
      } else if (_chartMode == 1) {
        maxVal = math.max(
          maxVal,
          math.max(b.principalDisbursedAmount, b.fullPaymentsActiveCredit),
        );
      } else {
        maxVal = math.max(maxVal, b.vaultCashAcct1000.abs());
      }
    }
    final hasChartActivity = branches.isNotEmpty && maxVal > 0;
    final barTop = maxVal > 0 ? maxVal * 1.24 : 1000.0;

    return IcareCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Branch Comparative Performance Analytics',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _chartMode == 0
                ? 'Live expected schedule collections vs actual repayments per supervised branch'
                : _chartMode == 1
                    ? 'Disbursed principal volume vs full loan payoffs settled'
                    : 'Verified physical vault cash reserve by branch',
            style: TextStyle(fontSize: 12, color: tokens.textMuted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ModeChip(
                label: 'Collections',
                selected: _chartMode == 0,
                tokens: tokens,
                onTap: () => setState(() => _chartMode = 0),
              ),
              _ModeChip(
                label: 'Disbursed vs Payoffs',
                selected: _chartMode == 1,
                tokens: tokens,
                onTap: () => setState(() => _chartMode = 1),
              ),
              _ModeChip(
                label: 'Vault Reserve',
                selected: _chartMode == 2,
                tokens: tokens,
                onTap: () => setState(() => _chartMode = 2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: _chartMode == 0
                ? [
                    _LegendItem(
                      color: tokens.infoDot,
                      label: 'Expected Target',
                      tokens: tokens,
                    ),
                    _LegendItem(
                      color: tokens.successDot,
                      label: 'Collected',
                      tokens: tokens,
                    ),
                  ]
                : _chartMode == 1
                    ? [
                        _LegendItem(
                          color: tokens.brandPrimary,
                          label: 'Principal Disbursed',
                          tokens: tokens,
                        ),
                        _LegendItem(
                          color: tokens.warningDot,
                          label: 'Full Payoffs Settled',
                          tokens: tokens,
                        ),
                      ]
                    : [
                        _LegendItem(
                          color: tokens.infoDot,
                          label: 'Physical Vault Cash',
                          tokens: tokens,
                        ),
                      ],
          ),
          const SizedBox(height: 16),
          if (!hasChartActivity)
            Container(
              height: 205,
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.insert_chart_outlined_rounded,
                    size: 30,
                    color: tokens.textLight,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    branches.isEmpty
                        ? 'No branches currently assigned to this area'
                        : 'No recorded activity for this metric on the selected date',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 225,
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
                    touchCallback: (event, response) {
                      if (event is FlTapUpEvent &&
                          response != null &&
                          response.spot != null) {
                        final idx = response.spot!.touchedBarGroupIndex;
                        if (idx >= 0 && idx < branches.length) {
                          widget.onInspectBranch(branches[idx]);
                        }
                      }
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => tokens.brandPrimaryDark,
                      tooltipBorderRadius: BorderRadius.circular(8),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final b = branches[group.x.toInt()];
                        String seriesLabel;
                        if (_chartMode == 0) {
                          seriesLabel =
                              rodIndex == 0 ? 'Expected' : 'Collected';
                        } else if (_chartMode == 1) {
                          seriesLabel =
                              rodIndex == 0 ? 'Disbursed' : 'Payoffs';
                        } else {
                          seriesLabel = 'Vault Cash';
                        }
                        return BarTooltipItem(
                          '${b.branchName}\n$seriesLabel: ₦${_fullNgn.format(rod.toY)}\nCompliance: ${b.compliancePct.toStringAsFixed(1)}% · PAR: ${b.par}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: _buildBranchTitles(tokens, branches),
                  barGroups: List<BarChartGroupData>.generate(
                    branches.length,
                    (idx) {
                      final b = branches[idx];
                      final rodWidth = branches.length <= 4 ? 18.0 : 12.0;
                      if (_chartMode == 0) {
                        return BarChartGroupData(
                          x: idx,
                          barsSpace: 4,
                          barRods: [
                            BarChartRodData(
                              toY: b.expectedCollection,
                              width: rodWidth,
                              color: tokens.infoDot,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                            BarChartRodData(
                              toY: b.collected,
                              width: rodWidth,
                              color: tokens.successDot,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }
                      if (_chartMode == 1) {
                        return BarChartGroupData(
                          x: idx,
                          barsSpace: 4,
                          barRods: [
                            BarChartRodData(
                              toY: b.principalDisbursedAmount,
                              width: rodWidth,
                              color: tokens.brandPrimary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                            BarChartRodData(
                              toY: b.fullPaymentsActiveCredit,
                              width: rodWidth,
                              color: tokens.warningDot,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }
                      return BarChartGroupData(
                        x: idx,
                        barRods: [
                          BarChartRodData(
                            toY: math.max(0.0, b.vaultCashAcct1000),
                            width: branches.length <= 4 ? 26.0 : 16.0,
                            color: tokens.infoDot,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          if (branches.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: branches.map((b) {
                return InkWell(
                  onTap: () => widget.onInspectBranch(b),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Text(
                      '${b.branchName} · ${b.compliancePct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  FlTitlesData _buildBranchTitles(
    IcareSurfaceTokens tokens,
    List<BranchPerformanceItemModel> branches,
  ) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 54,
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
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= branches.length || value != idx.toDouble()) {
              return const SizedBox.shrink();
            }
            final rawName = branches[idx].branchName;
            final shortName = rawName.length > 10
                ? '${rawName.substring(0, 9)}…'
                : rawName;
            return SideTitleWidget(
              meta: meta,
              space: 6,
              child: Text(
                shortName,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: branches[idx].isClosed
                      ? tokens.dangerText
                      : tokens.textSecondary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRegionalSplitCard(
    IcareSurfaceTokens tokens,
    Duration animDuration,
  ) {
    final reg = widget.regionalSummary;
    final collected = math.max(0.0, reg.todayCollected);
    final outstanding = math.max(0.0, reg.todayExpected - reg.todayCollected);
    final hasCollectionData = collected > 0 || outstanding > 0;
    final netCashDiff = widget.branches.fold<double>(
      0.0,
      (sum, b) => sum + b.cashVariance,
    );

    return IcareCard(
      padding: const EdgeInsets.all(18),
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
                child: Text(
                  'Collection & Risk Mix',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Daily target attainment and regional reconciliation posture',
            style: TextStyle(fontSize: 12, color: tokens.textMuted),
          ),
          const SizedBox(height: 14),
          if (!hasCollectionData)
            Container(
              height: 150,
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Text(
                'No collections due or posted for ${reg.businessDate}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
            )
          else
            SizedBox(
              height: 155,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    duration: animDuration,
                    PieChartData(
                      centerSpaceRadius: 42,
                      sectionsSpace: 2,
                      sections: [
                        if (collected > 0)
                          PieChartSectionData(
                            value: collected,
                            color: tokens.successDot,
                            radius: 20,
                            showTitle: false,
                          ),
                        if (outstanding > 0)
                          PieChartSectionData(
                            value: outstanding,
                            color: tokens.warningDot,
                            radius: 18,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${reg.compliancePct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: tokens.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'Attained',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          _SplitStatRow(
            color: tokens.successDot,
            label: 'Collected Today',
            value: CurrencyFormatter.formatNaira(reg.todayCollected),
            tokens: tokens,
          ),
          const SizedBox(height: 6),
          _SplitStatRow(
            color: tokens.warningDot,
            label: 'Remaining Target',
            value: CurrencyFormatter.formatNaira(outstanding),
            tokens: tokens,
          ),
          const SizedBox(height: 6),
          _SplitStatRow(
            color: netCashDiff == 0 ? tokens.successDot : tokens.dangerDot,
            label: 'Regional Cash Variance',
            value: CurrencyFormatter.formatNaira(netCashDiff),
            tokens: tokens,
          ),
          const SizedBox(height: 6),
          _SplitStatRow(
            color: reg.defaultersCount > 0
                ? tokens.dangerDot
                : tokens.successDot,
            label: 'Delinquency (PAR > 30d)',
            value: '${reg.par} (${reg.defaultersCount})',
            tokens: tokens,
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IcareSurfaceTokens tokens;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IcareTactileScale(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? tokens.brandPrimaryDark : tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? tokens.brandPrimaryDark : tokens.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : tokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final IcareSurfaceTokens tokens;

  const _LegendItem({
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

class _SplitStatRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final IcareSurfaceTokens tokens;

  const _SplitStatRow({
    required this.color,
    required this.label,
    required this.value,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
