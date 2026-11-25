import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../data/models/admin_dashboard_models.dart';
import 'admin_responsive.dart';

/// Interactive Analytics Charts for the Admin Rankings Tab.
/// Displays:
/// 1. Branch Composite Score Leaderboard Bar Chart (tap bar to inspect 6 pillars)
/// 2. Selected Branch 6-Pillar Scorecard Breakdown Chart
/// 3. Top Credit Officers Disbursement vs Collection Bar Chart
class AdminRankingsAnalyticsSection extends StatefulWidget {
  final InstitutionPerformanceModel performance;
  final AdminSize size;

  const AdminRankingsAnalyticsSection({
    super.key,
    required this.performance,
    required this.size,
  });

  @override
  State<AdminRankingsAnalyticsSection> createState() =>
      _AdminRankingsAnalyticsSectionState();
}

class _AdminRankingsAnalyticsSectionState
    extends State<AdminRankingsAnalyticsSection> {
  int _selectedBranchIndex = 0;

  final NumberFormat _compactNgn = NumberFormat.compactCurrency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 1,
  );
  final NumberFormat _fullNgn = NumberFormat('#,##0');

  @override
  Widget build(BuildContext context) {
    final branches = widget.performance.branchRankings;
    final officers = widget.performance.officerRankings;
    if (branches.isEmpty && officers.isEmpty) {
      return const SizedBox.shrink();
    }

    final tokens = IcareSurfaceTokens.of(context);
    final reduced = IcareFluidMotion.isReduced(context);
    final animDuration =
        reduced ? Duration.zero : const Duration(milliseconds: 280);

    final safeIdx =
        branches.isEmpty ? 0 : _selectedBranchIndex.clamp(0, branches.length - 1);

    final branchScoreCard = branches.isNotEmpty
        ? _buildBranchScoreChart(tokens, branches, safeIdx, animDuration)
        : null;
    final pillarCard = branches.isNotEmpty
        ? _buildSixPillarChart(tokens, branches[safeIdx], animDuration)
        : null;
    final officerCard = officers.isNotEmpty
        ? _buildTopOfficersChart(tokens, officers, animDuration)
        : null;

    if (widget.size.isExpanded && branchScoreCard != null && pillarCard != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: branchScoreCard),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: pillarCard),
            ],
          ),
          if (officerCard != null) ...[
            const SizedBox(height: 16),
            officerCard,
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (branchScoreCard != null) branchScoreCard,
        if (pillarCard != null) ...[
          const SizedBox(height: 14),
          pillarCard,
        ],
        if (officerCard != null) ...[
          const SizedBox(height: 14),
          officerCard,
        ],
      ],
    );
  }

  Widget _buildBranchScoreChart(
    IcareSurfaceTokens tokens,
    List<BranchPerformanceItemModel> branches,
    int selectedIdx,
    Duration animDuration,
  ) {
    final shown = branches.take(8).toList();
    return IcareCard(
      padding: EdgeInsets.all(widget.size.isCompact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.leaderboard_outlined,
                  size: 18, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Branch Composite Scorecard (0–100)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    Text(
                      'Tap any branch bar to inspect its 6 performance pillars',
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 205,
            child: BarChart(
              duration: animDuration,
              BarChartData(
                maxY: 100,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
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
                    if (event is FlTapUpEvent && response?.spot != null) {
                      final idx = response!.spot!.touchedBarGroupIndex;
                      if (idx >= 0 && idx < shown.length) {
                        setState(() => _selectedBranchIndex = idx);
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
                        '#${b.rank} ${b.branchName}\nScore: ${b.compositeScore.toStringAsFixed(1)}/100 • PAR ${b.parPct.toStringAsFixed(1)}%',
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
                      reservedSize: 34,
                      interval: 25,
                      getTitlesWidget: (val, meta) => SideTitleWidget(
                        meta: meta,
                        space: 4,
                        child: Text(
                          '${val.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: tokens.textMuted,
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
                              fontWeight: idx == selectedIdx
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: idx == selectedIdx
                                  ? tokens.brandPrimary
                                  : tokens.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List<BarChartGroupData>.generate(shown.length, (idx) {
                  final b = shown[idx];
                  final score = b.compositeScore.clamp(0.0, 100.0);
                  final Color barColor = score >= 75
                      ? tokens.successDot
                      : score >= 50
                          ? tokens.warningDot
                          : tokens.dangerDot;
                  final isSel = idx == selectedIdx;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: score,
                        width: shown.length <= 4 ? 24 : 16,
                        color: barColor.withValues(alpha: isSel ? 1.0 : 0.72),
                        borderSide: isSel
                            ? BorderSide(color: tokens.textPrimary, width: 1.5)
                            : BorderSide.none,
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

  Widget _buildSixPillarChart(
    IcareSurfaceTokens tokens,
    BranchPerformanceItemModel branch,
    Duration animDuration,
  ) {
    final s = branch.scorecard;
    final pillars = [
      ('Capital', s.capitalDeploymentScore, 20.0, tokens.brandPrimary),
      ('PAR Ctrl', s.delinquencyControlScore, 25.0, tokens.successDot),
      ('Recovery', s.overdueRecoveryScore, 20.0, tokens.infoDot),
      ('Outreach', s.borrowerOutreachScore, 15.0, tokens.brandPrimaryLight),
      ('Comply', s.repaymentComplianceScore, 10.0, const Color(0xFF0EA5E9)),
      ('Vault', s.vaultDisciplineScore, 10.0, tokens.warningDot),
    ];

    return IcareCard(
      padding: EdgeInsets.all(widget.size.isCompact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_small_outlined,
                  size: 18, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '6-Pillar Breakdown: ${branch.branchName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    Text(
                      'Normalized pillar attainment (% of maximum pillar points)',
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 205,
            child: BarChart(
              duration: animDuration,
              BarChartData(
                maxY: 100,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
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
                      final p = pillars[group.x.toInt()];
                      return BarTooltipItem(
                        '${p.$1}\n${p.$2.toStringAsFixed(1)} / ${p.$3.toInt()} pts (${rod.toY.toStringAsFixed(0)}%)',
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
                      interval: 25,
                      getTitlesWidget: (val, meta) => SideTitleWidget(
                        meta: meta,
                        space: 4,
                        child: Text(
                          '${val.toInt()}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: tokens.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= pillars.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          space: 6,
                          child: Text(
                            pillars[idx].$1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: tokens.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List<BarChartGroupData>.generate(pillars.length, (i) {
                  final p = pillars[i];
                  final pct = ((p.$2 / p.$3) * 100.0).clamp(0.0, 100.0);
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: pct,
                        width: 16,
                        color: p.$4,
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

  Widget _buildTopOfficersChart(
    IcareSurfaceTokens tokens,
    List<OfficerPerformanceItemModel> officers,
    Duration animDuration,
  ) {
    final top = officers.take(6).toList();
    double maxVol = 0.0;
    for (final o in top) {
      maxVol = math.max(maxVol, math.max(o.disbPrincipal, o.collectedAmount));
    }
    if (maxVol <= 0) {
      return const SizedBox.shrink();
    }
    final topY = maxVol * 1.18;

    return IcareCard(
      padding: EdgeInsets.all(widget.size.isCompact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined,
                  size: 18, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Credit Officers: Disbursed vs. Collected',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    Text(
                      'Live annual comparison for top ${top.length} ranked officers',
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
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
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => tokens.brandPrimaryDark,
                    tooltipBorderRadius: BorderRadius.circular(8),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final o = top[group.x.toInt()];
                      final series = rodIndex == 0 ? 'Disbursed' : 'Collected';
                      return BarTooltipItem(
                        '#${o.rank} ${o.officerName}\n$series: ₦${_fullNgn.format(rod.toY)}',
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
                      getTitlesWidget: (val, meta) => SideTitleWidget(
                        meta: meta,
                        space: 6,
                        child: Text(
                          _compactNgn.format(val),
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
                      reservedSize: 30,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= top.length) {
                          return const SizedBox.shrink();
                        }
                        final raw = top[idx].officerName;
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
                barGroups: List<BarChartGroupData>.generate(top.length, (i) {
                  final o = top[i];
                  return BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: o.disbPrincipal,
                        width: 12,
                        color: tokens.brandPrimaryDark,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: o.collectedAmount,
                        width: 12,
                        color: tokens.successDot,
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
