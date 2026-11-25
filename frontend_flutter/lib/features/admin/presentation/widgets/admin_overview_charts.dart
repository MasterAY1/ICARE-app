import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../../data/models/admin_dashboard_models.dart';
import '../admin_branch_detail_sheet.dart';
import '../admin_dashboard_screen.dart';
import 'admin_responsive.dart';

/// Interactive Weekly Cash Flow Chart for the Admin Overview Tab.
/// Supports Grouped Bars (Collections vs Disbursements) and Net Cash Trend Line,
/// plus Mon-Fri vs Full 7-Day window toggle. Bound 100% to live API payloads.
class AdminWeeklyCashFlowChart extends ConsumerStatefulWidget {
  final List<FinancialActivityDayModel> weekData;
  final AdminSize size;

  const AdminWeeklyCashFlowChart({
    super.key,
    required this.weekData,
    required this.size,
  });

  @override
  ConsumerState<AdminWeeklyCashFlowChart> createState() =>
      _AdminWeeklyCashFlowChartState();
}

class _AdminWeeklyCashFlowChartState
    extends ConsumerState<AdminWeeklyCashFlowChart> {
  /// 0 = Collections vs Disbursements Bars, 1 = Net Cash Trend Line
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
    final showFull7d = ref.watch(adminCalendarMode7dProvider);
    final displayedDays = showFull7d
        ? widget.weekData
        : widget.weekData
            .where((d) => d.day != 'Sat' && d.day != 'Sun')
            .toList();

    final reduced = IcareFluidMotion.isReduced(context);
    final animDuration =
        reduced ? Duration.zero : const Duration(milliseconds: 280);

    double totalCollectedWeek = 0.0;
    double totalDisbursedWeek = 0.0;
    double maxVal = 0.0;
    double minNet = 0.0;
    double maxNet = 0.0;

    for (final d in displayedDays) {
      totalCollectedWeek += d.collections;
      totalDisbursedWeek += d.disbursements;
      maxVal = math.max(maxVal, math.max(d.collections, d.disbursements));
      final net = d.collections - d.disbursements;
      minNet = math.min(minNet, net);
      maxNet = math.max(maxNet, net);
    }

    final bool hasAnyActivity =
        displayedDays.isNotEmpty && (totalCollectedWeek > 0 || totalDisbursedWeek > 0);
    final double netWeek = totalCollectedWeek - totalDisbursedWeek;
    final double barTop = maxVal > 0 ? maxVal * 1.2 : 1000.0;

    return IcareCard(
      padding: EdgeInsets.all(widget.size.isCompact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
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
                    child: Text(
                      'Weekly Cash Flow',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                showFull7d
                    ? 'Live repayments collected vs loans disbursed (Mon–Sun)'
                    : 'Live repayments collected vs loans disbursed (Working Days)',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MiniTogglePill(
                    tokens: tokens,
                    labels: const ['Grouped Bars', 'Net Trend'],
                    selectedIndex: _chartMode,
                    onChanged: (idx) => setState(() => _chartMode = idx),
                  ),
                  InkWell(
                    onTap: () => ref
                        .read(adminCalendarMode7dProvider.notifier)
                        .state = !showFull7d,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Text(
                        showFull7d ? 'All 7 Days' : 'Work Days Only (Mon–Fri)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_chartMode == 0) ...[
                _ChartLegendDot(
                  color: tokens.successDot,
                  label: 'Collected: ₦${_fullNgn.format(totalCollectedWeek)}',
                  tokens: tokens,
                ),
                _ChartLegendDot(
                  color: tokens.infoDot,
                  label: 'Disbursed: ₦${_fullNgn.format(totalDisbursedWeek)}',
                  tokens: tokens,
                ),
              ] else
                _ChartLegendDot(
                  color: netWeek >= 0 ? tokens.successDot : tokens.dangerDot,
                  label:
                      'Weekly Net Cash Position: ${netWeek < 0 ? '-' : ''}₦${_fullNgn.format(netWeek.abs())}',
                  tokens: tokens,
                ),
              if (displayedDays.any((d) => !d.isWorkingDay))
                const IcareStatusBadge(
                  label: 'Non-working days shaded',
                  variant: IcareBadgeVariant.warning,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasAnyActivity)
            Container(
              height: 170,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 28,
                    color: tokens.textLight,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No collections or disbursements recorded in this window',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (_chartMode == 0)
            SizedBox(
              height: 215,
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
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final day = displayedDays[group.x.toInt()];
                        final series =
                            rodIndex == 0 ? 'Collected' : 'Disbursed';
                        final dayTag = day.isWorkingDay
                            ? day.day
                            : '${day.day} (${day.statusReason.isNotEmpty ? day.statusReason : 'Closed'})';
                        return BarTooltipItem(
                          '$dayTag • ${day.date}\n$series: ₦${_fullNgn.format(rod.toY)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: _buildWeekTitles(tokens, displayedDays),
                  barGroups: List<BarChartGroupData>.generate(
                    displayedDays.length,
                    (idx) {
                      final d = displayedDays[idx];
                      final mutedAlpha = d.isWorkingDay ? 1.0 : 0.45;
                      return BarChartGroupData(
                        x: idx,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: d.collections,
                            width: displayedDays.length <= 5 ? 16 : 11,
                            color:
                                tokens.successDot.withValues(alpha: mutedAlpha),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: d.disbursements,
                            width: displayedDays.length <= 5 ? 16 : 11,
                            color: tokens.infoDot.withValues(alpha: mutedAlpha),
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
            )
          else
            _buildNetTrendLineChart(
              tokens: tokens,
              displayedDays: displayedDays,
              minNet: minNet,
              maxNet: maxNet,
              animDuration: animDuration,
            ),
        ],
      ),
    );
  }

  Widget _buildNetTrendLineChart({
    required IcareSurfaceTokens tokens,
    required List<FinancialActivityDayModel> displayedDays,
    required double minNet,
    required double maxNet,
    required Duration animDuration,
  }) {
    final double spread = math.max(maxNet - minNet, 1000.0);
    final double pad = spread * 0.2;
    final double chartMinY = math.min(0.0, minNet - pad);
    final double chartMaxY = math.max(0.0, maxNet + pad);
    final double interval = math.max((chartMaxY - chartMinY) / 4, 1.0);

    final spots = List<FlSpot>.generate(displayedDays.length, (idx) {
      final d = displayedDays[idx];
      return FlSpot(idx.toDouble(), d.collections - d.disbursements);
    });

    return SizedBox(
      height: 215,
      child: LineChart(
        duration: animDuration,
        LineChartData(
          minY: chartMinY,
          maxY: chartMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (val) => FlLine(
              color: val == 0 ? tokens.borderStrong : tokens.borderSubtle,
              strokeWidth: val == 0 ? 1.4 : 1,
              dashArray: val == 0 ? null : const [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => tokens.brandPrimaryDark,
              tooltipBorderRadius: BorderRadius.circular(8),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.x.toInt();
                  final day = displayedDays[idx];
                  final net = day.collections - day.disbursements;
                  final sign = net < 0 ? '-' : '+';
                  return LineTooltipItem(
                    '${day.day} • ${day.date}\nNet Flow: $sign₦${_fullNgn.format(net.abs())}',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          titlesData: _buildWeekTitles(tokens, displayedDays),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: tokens.brandPrimary,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isPos = spot.y >= 0;
                  return FlDotCirclePainter(
                    radius: 4.5,
                    color: isPos ? tokens.successDot : tokens.dangerDot,
                    strokeWidth: 2,
                    strokeColor: tokens.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: tokens.brandPrimary.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  FlTitlesData _buildWeekTitles(
    IcareSurfaceTokens tokens,
    List<FinancialActivityDayModel> displayedDays,
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
          reservedSize: 30,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= displayedDays.length || value != idx.toDouble()) {
              return const SizedBox.shrink();
            }
            final d = displayedDays[idx];
            return SideTitleWidget(
              meta: meta,
              space: 6,
              child: Text(
                d.day,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: d.isWorkingDay ? tokens.textSecondary : tokens.warningText,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Interactive Field Branch Collections vs Vault Liquidity Chart.
/// Tapping any branch bar opens `AdminBranchDetailSheet` for drilldown.
class AdminBranchLiquidityChart extends StatelessWidget {
  final List<BranchPerformanceRowModel> branches;
  final AdminSize size;

  const AdminBranchLiquidityChart({
    super.key,
    required this.branches,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final fieldBranches = branches.where((b) => !b.isHeadOffice).toList();
    if (fieldBranches.isEmpty) {
      return const SizedBox.shrink();
    }

    final compactNgn = NumberFormat.compactCurrency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 1,
    );
    final fullNgn = NumberFormat('#,##0');
    final reduced = IcareFluidMotion.isReduced(context);
    final animDuration =
        reduced ? Duration.zero : const Duration(milliseconds: 280);

    double maxVal = 0.0;
    for (final b in fieldBranches) {
      maxVal = math.max(maxVal, math.max(b.volume, b.vaultCash));
    }
    if (maxVal <= 0) {
      return const SizedBox.shrink();
    }
    final topY = maxVal * 1.18;

    return IcareCard(
      padding: EdgeInsets.all(size.isCompact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: tokens.brandPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Branch Collections vs. Vault Cash',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Tap any branch bar to open live vault & portfolio drilldown',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _ChartLegendDot(
                    color: tokens.successDot,
                    label: 'Today Collected',
                    tokens: tokens,
                  ),
                  _ChartLegendDot(
                    color: tokens.brandPrimaryDark,
                    label: 'Vault Cash',
                    tokens: tokens,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 205,
            child: BarChart(
              duration: animDuration,
              BarChartData(
                maxY: topY,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: topY / 4,
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
                        response?.spot != null &&
                        response!.spot!.touchedBarGroupIndex >= 0 &&
                        response.spot!.touchedBarGroupIndex <
                            fieldBranches.length) {
                      final tapped =
                          fieldBranches[response.spot!.touchedBarGroupIndex];
                      if (tapped.branchId.isNotEmpty) {
                        AdminBranchDetailSheet.show(
                          context,
                          branchId: tapped.branchId,
                          branchName: tapped.branchName,
                        );
                      }
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => tokens.brandPrimaryDark,
                    tooltipBorderRadius: BorderRadius.circular(8),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final b = fieldBranches[group.x.toInt()];
                      final series =
                          rodIndex == 0 ? 'Today Collected' : 'Vault Cash';
                      return BarTooltipItem(
                        '${b.branchName}\n$series: ₦${fullNgn.format(rod.toY)}',
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
                      reservedSize: 54,
                      interval: topY / 4,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        space: 6,
                        child: Text(
                          compactNgn.format(value),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: tokens.textMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= fieldBranches.length) {
                          return const SizedBox.shrink();
                        }
                        final raw = fieldBranches[idx].branchName;
                        final short =
                            raw.length > 10 ? '${raw.substring(0, 9)}...' : raw;
                        return SideTitleWidget(
                          meta: meta,
                          space: 6,
                          child: Text(
                            short,
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
                  fieldBranches.length,
                  (idx) {
                    final b = fieldBranches[idx];
                    final width = fieldBranches.length <= 4 ? 15.0 : 10.0;
                    return BarChartGroupData(
                      x: idx,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: b.volume,
                          width: width,
                          color: tokens.successDot,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: b.vaultCash,
                          width: width,
                          color: tokens.brandPrimaryDark,
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
}

class _MiniTogglePill extends StatelessWidget {
  final IcareSurfaceTokens tokens;
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _MiniTogglePill({
    required this.tokens,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (idx) {
          final selected = idx == selectedIndex;
          return InkWell(
            onTap: () => onChanged(idx),
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: IcareFluidMotion.microDuration,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? tokens.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                labels[idx],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? tokens.brandPrimary : tokens.textMuted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final IcareSurfaceTokens tokens;

  const _ChartLegendDot({
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
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
