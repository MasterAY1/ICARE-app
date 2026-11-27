import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';

/// Onboarding Admin Analytics Charts:
/// - Staged Branch Savings vs Loan Portfolio BarChart
/// - Session Stage Readiness Donut
/// Driven 100% by live onboarding session payloads with honest empty states.
class OnboardingAdminOverviewCharts extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;

  const OnboardingAdminOverviewCharts({
    super.key,
    required this.sessions,
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

    final topSessions = List<Map<String, dynamic>>.from(sessions)
      ..sort((a, b) {
        final aTot =
            (double.tryParse(a['total_savings']?.toString() ?? '0') ?? 0) +
                (double.tryParse(a['total_current_balance']?.toString() ?? '0') ??
                    0);
        final bTot =
            (double.tryParse(b['total_savings']?.toString() ?? '0') ?? 0) +
                (double.tryParse(b['total_current_balance']?.toString() ?? '0') ??
                    0);
        return bTot.compareTo(aTot);
      });
    final bars = topSessions.take(7).toList();

    double maxVal = 0.0;
    for (final s in bars) {
      final sav = double.tryParse(s['total_savings']?.toString() ?? '0') ?? 0.0;
      final bal =
          double.tryParse(s['total_current_balance']?.toString() ?? '0') ?? 0.0;
      maxVal = math.max(maxVal, math.max(sav, bal));
    }
    final hasBarData = bars.isNotEmpty && maxVal > 0;
    final barTop = hasBarData ? maxVal * 1.24 : 1000.0;

    final draftCount = sessions.where((s) => s['status'] == 'draft').length;
    final submittedCount =
        sessions.where((s) => s['status'] == 'submitted').length;
    final approvedCount =
        sessions.where((s) => s['status'] == 'approved').length;

    final slices = [
      (label: 'Drafts In Progress', count: draftCount, color: tokens.warningDot),
      (label: 'Awaiting Sign-Off', count: submittedCount, color: tokens.infoDot),
      (label: 'Activated', count: approvedCount, color: tokens.successDot),
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
                  'Branch Staged Savings vs Outstanding Loan',
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
            'Top onboarding branches ranked by staged deposit and credit volume',
            style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _LegendDot(color: tokens.brandPrimary, label: 'Total Savings'),
              _LegendDot(color: tokens.infoDot, label: 'Loan Balance'),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasBarData)
            _OnboardingChartEmpty(
              message:
                  'No branch savings or loan balances have been staged yet.',
              tokens: tokens,
            )
          else
            SizedBox(
              height: 210,
              child: BarChart(
                BarChartData(
                  maxY: barTop,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: barTop / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: tokens.borderSubtle.withValues(alpha: 0.7),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 54,
                        getTitlesWidget: (val, _) => Text(
                          _compactNgn.format(val),
                          style: TextStyle(
                            fontSize: 10,
                            color: tokens.textMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
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
                          if (idx < 0 || idx >= bars.length) {
                            return const SizedBox.shrink();
                          }
                          final code = (bars[idx]['branch_code'] ??
                                  bars[idx]['branch_name'] ??
                                  '')
                              .toString();
                          final shortCode =
                              code.length > 6 ? code.substring(0, 6) : code;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              shortCode,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: tokens.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => tokens.surfaceElevated,
                      getTooltipItem: (group, groupIdx, rod, rodIdx) {
                        final name =
                            bars[group.x]['branch_name']?.toString() ?? 'Branch';
                        final label =
                            rodIdx == 0 ? 'Staged Savings' : 'Loan Balance';
                        return BarTooltipItem(
                          '$name\n$label: ${CurrencyFormatter.formatNaira(rod.toY)}',
                          TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(bars.length, (i) {
                    final sav = double.tryParse(
                            bars[i]['total_savings']?.toString() ?? '0') ??
                        0.0;
                    final bal = double.tryParse(
                            bars[i]['total_current_balance']?.toString() ??
                                '0') ??
                        0.0;
                    return BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: sav,
                          color: tokens.brandPrimary,
                          width: 11,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: bal,
                          color: tokens.infoDot,
                          width: 11,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
                duration: animDuration,
              ),
            ),
        ],
      ),
    );

    final pieCard = IcareCard(
      padding: const EdgeInsets.all(16),
      topAccentColor: tokens.infoDot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded,
                  size: 18, color: tokens.infoDot),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Session Activation Readiness',
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
            'Distribution across draft, review, and activated branch portals',
            style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
          ),
          const SizedBox(height: 14),
          if (slices.isEmpty)
            _OnboardingChartEmpty(
              message: 'No onboarding invitation sessions found.',
              tokens: tokens,
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 155,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 36,
                      sectionsSpace: 3,
                      sections: slices.map((s) {
                        final pct = (s.count / sessions.length) * 100;
                        return PieChartSectionData(
                          value: s.count.toDouble(),
                          color: s.color,
                          radius: 36,
                          title: '${pct.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        );
                      }).toList(),
                    ),
                    duration: animDuration,
                  ),
                ),
                const SizedBox(height: 12),
                ...slices.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: s.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            '${s.count}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 820) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: barCard),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: pieCard),
            ],
          );
        }
        return Column(
          children: [
            barCard,
            const SizedBox(height: 12),
            pieCard,
          ],
        );
      },
    );
  }
}

/// Live Staged Group & Capital Analytics for Branch Onboarding Portal & Officer Workspace.
class OnboardingPortfolioChartsSection extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> members;
  final double miscSavings;
  final double lapsSavings;

  const OnboardingPortfolioChartsSection({
    super.key,
    required this.groups,
    required this.members,
    this.miscSavings = 0.0,
    this.lapsSavings = 0.0,
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

    // Aggregate per-group savings vs loan balance
    final List<({String code, String name, double savings, double balance})>
        groupTotals = [];
    for (final g in groups) {
      final ref = (g['group_reference'] ?? '').toString();
      final name = (g['group_name'] ?? ref).toString();
      final grpSav =
          double.tryParse(g['group_savings']?.toString() ?? '0') ?? 0.0;
      double memberSav = 0.0;
      double memberBal = 0.0;
      for (final m in members) {
        if ((m['group_reference'] ?? '').toString().toUpperCase() ==
            ref.toUpperCase()) {
          memberSav +=
              double.tryParse(m['savings_balance']?.toString() ?? '0') ?? 0.0;
          memberBal += double.tryParse(
                  (m['current_credit_balance'] ??
                              m['current_balance'] ??
                              m['active_credit'])
                          ?.toString() ??
                      '0') ??
              0.0;
        }
      }
      groupTotals.add((
        code: ref,
        name: name,
        savings: grpSav + memberSav,
        balance: memberBal,
      ));
    }

    groupTotals.sort((a, b) =>
        (b.savings + b.balance).compareTo(a.savings + a.balance));
    final bars = groupTotals.take(7).toList();

    double maxVal = 0.0;
    for (final item in bars) {
      maxVal = math.max(maxVal, math.max(item.savings, item.balance));
    }
    final hasBarData = bars.isNotEmpty && maxVal > 0;
    final barTop = hasBarData ? maxVal * 1.24 : 1000.0;

    double totalMemberSav = 0.0;
    for (final m in members) {
      totalMemberSav +=
          double.tryParse(m['savings_balance']?.toString() ?? '0') ?? 0.0;
    }
    double totalGroupSav = 0.0;
    for (final g in groups) {
      totalGroupSav +=
          double.tryParse(g['group_savings']?.toString() ?? '0') ?? 0.0;
    }

    final totalCapital =
        totalMemberSav + totalGroupSav + miscSavings + lapsSavings;
    final slices = [
      (
        label: 'Member Savings',
        amount: totalMemberSav,
        color: tokens.brandPrimary,
      ),
      (
        label: 'Group Savings',
        amount: totalGroupSav,
        color: tokens.infoDot,
      ),
      (
        label: 'Miscellaneous Reserve',
        amount: miscSavings,
        color: tokens.warningDot,
      ),
      (
        label: 'LAPS Fund',
        amount: lapsSavings,
        color: tokens.successDot,
      ),
    ].where((s) => s.amount > 0).toList();

    final barCard = IcareCard(
      padding: const EdgeInsets.all(14),
      topAccentColor: tokens.brandPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined,
                  size: 17, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Group Savings vs Loan Position',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _LegendDot(color: tokens.brandPrimary, label: 'Group + Member Savings'),
              _LegendDot(color: tokens.infoDot, label: 'Current Loan Balance'),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasBarData)
            _OnboardingChartEmpty(
              message:
                  'Add solidarity groups with opening savings or loan balances to preview distribution.',
              tokens: tokens,
            )
          else
            SizedBox(
              height: 195,
              child: BarChart(
                BarChartData(
                  maxY: barTop,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: barTop / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: tokens.borderSubtle.withValues(alpha: 0.7),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        getTitlesWidget: (val, _) => Text(
                          _compactNgn.format(val),
                          style: TextStyle(
                            fontSize: 10,
                            color: tokens.textMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (val, _) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= bars.length) {
                            return const SizedBox.shrink();
                          }
                          final code = bars[idx].code;
                          final shortCode =
                              code.length > 7 ? code.substring(0, 7) : code;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              shortCode,
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
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => tokens.surfaceElevated,
                      getTooltipItem: (group, _, rod, rodIdx) {
                        final item = bars[group.x];
                        final label = rodIdx == 0 ? 'Total Savings' : 'Loan Balance';
                        return BarTooltipItem(
                          '${item.code} (${item.name})\n$label: ${CurrencyFormatter.formatNaira(rod.toY)}',
                          TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(bars.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: bars[i].savings,
                          color: tokens.brandPrimary,
                          width: 11,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: bars[i].balance,
                          color: tokens.infoDot,
                          width: 11,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
                duration: animDuration,
              ),
            ),
        ],
      ),
    );

    final pieCard = IcareCard(
      padding: const EdgeInsets.all(14),
      topAccentColor: tokens.successDot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_large_rounded,
                  size: 17, color: tokens.successDot),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Opening Savings Mix',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (slices.isEmpty || totalCapital <= 0)
            _OnboardingChartEmpty(
              message: 'Opening savings deposits have not been staged yet.',
              tokens: tokens,
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 32,
                      sectionsSpace: 3,
                      sections: slices.map((s) {
                        final pct = (s.amount / totalCapital) * 100;
                        return PieChartSectionData(
                          value: s.amount,
                          color: s.color,
                          radius: 34,
                          title: '${pct.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        );
                      }).toList(),
                    ),
                    duration: animDuration,
                  ),
                ),
                const SizedBox(height: 10),
                ...slices.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: s.color,
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: tokens.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatNaira(s.amount),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 780) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: barCard),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: pieCard),
            ],
          );
        }
        return Column(
          children: [
            barCard,
            const SizedBox(height: 10),
            pieCard,
          ],
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
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

class _OnboardingChartEmpty extends StatelessWidget {
  final String message;
  final IcareSurfaceTokens tokens;

  const _OnboardingChartEmpty({
    required this.message,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(Icons.insert_chart_outlined, size: 28, color: tokens.textMuted),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: tokens.textMuted),
          ),
        ],
      ),
    );
  }
}
