import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../../data/models/admin_dashboard_models.dart';
import '../admin_branch_detail_sheet.dart';
import 'admin_responsive.dart';

/// Interactive Portfolio Risk & Recovery Analytics Charts for Admin Loan Health Tab.
/// All slices, bars, and telemetry read 100% from live backend API responses.
class AdminRiskAnalyticsCharts extends StatefulWidget {
  final AdminRiskHealthModel risk;
  final List<BranchPerformanceItemModel> branches;
  final AdminSize size;

  const AdminRiskAnalyticsCharts({
    super.key,
    required this.risk,
    required this.branches,
    required this.size,
  });

  @override
  State<AdminRiskAnalyticsCharts> createState() =>
      _AdminRiskAnalyticsChartsState();
}

class _AdminRiskAnalyticsChartsState extends State<AdminRiskAnalyticsCharts> {
  int _touchedPieIdx = -1;

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

    final exposureCard = _buildPortfolioExposureCard(tokens, animDuration);
    final recoveryBarCard = _buildRecoverySettlementBarCard(tokens, animDuration);
    final branchParCard = widget.branches.isNotEmpty
        ? _buildBranchParBarCard(tokens, animDuration)
        : null;

    if (widget.size.isExpanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: exposureCard),
              const SizedBox(width: 16),
              Expanded(flex: 7, child: recoveryBarCard),
            ],
          ),
          if (branchParCard != null) ...[
            const SizedBox(height: 16),
            branchParCard,
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        exposureCard,
        const SizedBox(height: 14),
        recoveryBarCard,
        if (branchParCard != null) ...[
          const SizedBox(height: 14),
          branchParCard,
        ],
      ],
    );
  }

  Widget _buildPortfolioExposureCard(
    IcareSurfaceTokens tokens,
    Duration animDuration,
  ) {
    final totalBook = math.max(0.0, widget.risk.totalActiveCredit);
    double overdueTotal = widget.branches.fold<double>(
      0.0,
      (sum, b) => sum + b.overdueAmount,
    );
    if (overdueTotal <= 0 && totalBook > 0 && widget.risk.parPct > 0) {
      overdueTotal = totalBook * (widget.risk.parPct / 100.0);
    }
    overdueTotal = overdueTotal.clamp(0.0, totalBook);
    final healthyTotal = math.max(0.0, totalBook - overdueTotal);
    final isElevated = widget.risk.parPct > 10.0;

    return IcareCard(
      padding: EdgeInsets.all(widget.size.isCompact ? 14 : 18),
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
                      'Active Loan Exposure Mix',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    Text(
                      'Healthy active book vs overdue principal exposure',
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (totalBook <= 0)
            Container(
              height: 170,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Text(
                'No active loan exposure currently on book',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 165,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    duration: animDuration,
                    PieChartData(
                      centerSpaceRadius: 46,
                      sectionsSpace: 2,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response?.touchedSection == null) {
                              _touchedPieIdx = -1;
                              return;
                            }
                            _touchedPieIdx =
                                response!.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sections: [
                        PieChartSectionData(
                          color: tokens.successDot,
                          value: healthyTotal > 0 ? healthyTotal : 0.0001,
                          radius: _touchedPieIdx == 0 ? 30 : 24,
                          showTitle: false,
                        ),
                        if (overdueTotal > 0)
                          PieChartSectionData(
                            color:
                                isElevated ? tokens.dangerDot : tokens.warningDot,
                            value: overdueTotal,
                            radius: _touchedPieIdx == 1 ? 30 : 24,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.risk.parPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isElevated
                              ? tokens.dangerText
                              : tokens.successText,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'PAR Ratio',
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _ExposureLegendItem(
                  tokens: tokens,
                  color: tokens.successDot,
                  label: 'Performing: ${CurrencyFormatter.format(healthyTotal)}',
                ),
                _ExposureLegendItem(
                  tokens: tokens,
                  color: isElevated ? tokens.dangerDot : tokens.warningDot,
                  label: 'Overdue: ${CurrencyFormatter.format(overdueTotal)}',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecoverySettlementBarCard(
    IcareSurfaceTokens tokens,
    Duration animDuration,
  ) {
    final bars = [
      (
        'Overdue Recovered',
        widget.risk.totalOverdueRecovered,
        tokens.infoDot,
      ),
      (
        'Early Full Payoffs',
        widget.risk.fullPayoffsSettledAmount,
        tokens.successDot,
      ),
      (
        'Extra Cash',
        widget.risk.excessCashCollected,
        tokens.brandPrimary,
      ),
    ];

    double maxVal = 0.0;
    for (final b in bars) {
      maxVal = math.max(maxVal, b.$2);
    }

    return IcareCard(
      padding: EdgeInsets.all(widget.size.isCompact ? 14 : 18),
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
                      'Recovery, Early Settlement & Surplus Mix',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    Text(
                      'Live recovered overdue amounts, full loan payoffs, and surplus cash',
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (maxVal <= 0)
            Container(
              height: 195,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Text(
                'No overdue recovery, full payoff, or surplus collections recorded yet',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            SizedBox(
              height: 195,
              child: BarChart(
                duration: animDuration,
                BarChartData(
                  maxY: maxVal * 1.2,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxVal * 1.2) / 4,
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
                        final item = bars[group.x.toInt()];
                        return BarTooltipItem(
                          '${item.$1}\n₦${_fullNgn.format(rod.toY)}',
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
                        interval: (maxVal * 1.2) / 4,
                        getTitlesWidget: (val, meta) => SideTitleWidget(
                          meta: meta,
                          space: 6,
                          child: Text(
                            _compactNgn.format(val),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
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
                        reservedSize: 32,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= bars.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            space: 6,
                            child: Text(
                              bars[idx].$1,
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
                  barGroups: List<BarChartGroupData>.generate(bars.length, (i) {
                    final item = bars[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: item.$2,
                          width: 28,
                          color: item.$3,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
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

  Widget _buildBranchParBarCard(
    IcareSurfaceTokens tokens,
    Duration animDuration,
  ) {
    final sorted = List<BranchPerformanceItemModel>.from(widget.branches)
      ..sort((a, b) => b.parPct.compareTo(a.parPct));
    final shown = sorted.take(10).toList();

    double maxPar = 15.0;
    for (final b in shown) {
      maxPar = math.max(maxPar, b.parPct * 1.2);
    }
    // Snap maxY to clean multiple of 5 so y = 10 policy line always aligns cleanly
    final double topY = (maxPar / 5.0).ceil() * 5.0;

    return IcareCard(
      padding: EdgeInsets.all(widget.size.isCompact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Branch Risk Exposure vs. 10% Policy Limit',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Text(
                    'Dashed crimson line marks the 10% PAR ceiling; tap any bar for branch detail',
                    style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                  ),
                ],
              ),
              const IcareStatusBadge(
                label: '10% Ceiling',
                variant: IcareBadgeVariant.danger,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 195,
            child: BarChart(
              duration: animDuration,
              BarChartData(
                maxY: topY,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5.0,
                  getDrawingHorizontalLine: (value) {
                    final isLimit = (value - 10.0).abs() < 0.05;
                    return FlLine(
                      color: isLimit ? tokens.dangerDot : tokens.borderSubtle,
                      strokeWidth: isLimit ? 1.6 : 1.0,
                      dashArray: isLimit ? const [6, 4] : const [4, 4],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent && response?.spot != null) {
                      final idx = response!.spot!.touchedBarGroupIndex;
                      if (idx >= 0 && idx < shown.length) {
                        final b = shown[idx];
                        if (b.branchId.isNotEmpty) {
                          AdminBranchDetailSheet.show(
                            context,
                            branchId: b.branchId,
                            branchName: b.branchName,
                          );
                        }
                      }
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => tokens.brandPrimaryDark,
                    tooltipBorderRadius: BorderRadius.circular(8),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final b = shown[group.x.toInt()];
                      return BarTooltipItem(
                        '${b.branchName}\nPAR: ${b.parPct.toStringAsFixed(1)}% • Overdue ${CurrencyFormatter.format(b.overdueAmount)}',
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
                      reservedSize: 38,
                      interval: 5.0,
                      getTitlesWidget: (val, meta) => SideTitleWidget(
                        meta: meta,
                        space: 4,
                        child: Text(
                          '${val.toInt()}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: (val - 10.0).abs() < 0.05
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: (val - 10.0).abs() < 0.05
                                ? tokens.dangerText
                                : tokens.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= shown.length) {
                          return const SizedBox.shrink();
                        }
                        final raw = shown[idx].branchName;
                        final short =
                            raw.length > 9 ? '${raw.substring(0, 8)}...' : raw;
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
                barGroups: List<BarChartGroupData>.generate(shown.length, (i) {
                  final b = shown[i];
                  final elevated = b.parPct > 10.0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: b.parPct,
                        width: shown.length <= 5 ? 20 : 14,
                        color: elevated ? tokens.dangerDot : tokens.successDot,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
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

/// Live Runtime Platform, Queue, EOD & Audit Health Card (zero static strings).
class AdminLiveTelemetryCard extends StatelessWidget {
  final AdminRiskHealthModel risk;
  final AdminSize size;

  const AdminLiveTelemetryCard({
    super.key,
    required this.risk,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final isDegraded =
        risk.projectionEngineStatus.toLowerCase().contains('degraded') ||
            risk.databaseCluster.toLowerCase().contains('unavailable');

    final items = [
      (
        'Engine & Metrics',
        risk.projectionEngineStatus,
        Icons.speed_outlined,
        isDegraded ? IcareBadgeVariant.danger : IcareBadgeVariant.success,
      ),
      (
        'Database Connection',
        risk.databaseCluster,
        Icons.storage_outlined,
        risk.databaseCluster.toLowerCase().contains('connected')
            ? IcareBadgeVariant.success
            : IcareBadgeVariant.warning,
      ),
      (
        'Pending Governance Queue',
        '${risk.pendingEventBacklog} items',
        Icons.pending_actions_outlined,
        risk.pendingEventBacklog > 0
            ? IcareBadgeVariant.warning
            : IcareBadgeVariant.success,
      ),
      (
        'Branch EOD Coverage',
        risk.offlineDeviceSyncStatus,
        Icons.domain_verification_outlined,
        IcareBadgeVariant.info,
      ),
      (
        'Ledger Trail Verification',
        risk.immutableAuditState,
        Icons.fact_check_outlined,
        risk.immutableAuditState.toLowerCase().contains('verified')
            ? IcareBadgeVariant.success
            : IcareBadgeVariant.warning,
      ),
    ];

    return IcareCard(
      padding: EdgeInsets.all(size.isCompact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.monitor_heart_outlined,
                size: 18,
                color: tokens.brandPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live System & Ledger Telemetry',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    Text(
                      'Real-time database response, pending approval queue, and branch EOD closure status',
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AdminResponsiveGrid(
            columns: size.isCompact ? 1 : (size.isMedium ? 2 : 3),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Row(
                  children: [
                    Icon(item.$3, size: 17, color: tokens.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: tokens.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          IcareStatusBadge(
                            label: item.$2,
                            variant: item.$4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ExposureLegendItem extends StatelessWidget {
  final IcareSurfaceTokens tokens;
  final Color color;
  final String label;

  const _ExposureLegendItem({
    required this.tokens,
    required this.color,
    required this.label,
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
