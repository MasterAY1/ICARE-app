import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../data/models/am_dashboard_models.dart';

TextStyle _amSubTabular({
  double fontSize = 12,
  FontWeight fontWeight = FontWeight.w600,
  Color? color,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Live Area Portfolio Allocation Donut + Branch Disbursement vs Payoff Bar Chart.
/// Bound strictly to API data; zero hardcoded series and zero FlowCards.
class AmPortfolioAllocationChart extends StatelessWidget {
  final List<BranchPerformanceItemModel> branches;
  final String periodLabel;

  const AmPortfolioAllocationChart({
    super.key,
    required this.branches,
    required this.periodLabel,
  });

  static final NumberFormat _compactNgn = NumberFormat.compactCurrency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 1,
  );

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) return const SizedBox.shrink();

    final tokens = IcareSurfaceTokens.of(context);
    final reduced = IcareFluidMotion.isReduced(context);
    final animDuration =
        reduced ? Duration.zero : const Duration(milliseconds: 280);

    final palette = [
      tokens.brandPrimary,
      tokens.infoDot,
      tokens.warningDot,
      tokens.successDot,
      tokens.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
    ];

    final totalBook = branches.fold<double>(
      0.0,
      (sum, b) => sum + math.max(0.0, b.activeCreditDisbursedAmount),
    );
    final hasPieData = totalBook > 0;

    double maxBar = 0.0;
    for (final b in branches) {
      maxBar = math.max(
        maxBar,
        math.max(b.activeCreditDisbursedAmount, b.fullPaymentsActiveCredit),
      );
    }
    final hasBarData = maxBar > 0;
    final barTop = hasBarData ? maxBar * 1.24 : 1000.0;

    final pieCard = IcareCard(
      padding: const EdgeInsets.all(16),
      topAccentColor: tokens.brandPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded,
                  size: 18, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Regional Loan Book Distribution',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              Text(
                periodLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasPieData)
            _AmChartEmpty(
              tokens: tokens,
              height: 170,
              message: 'Zero active credit disbursed in this period',
            )
          else ...[
            SizedBox(
              height: 145,
              child: PieChart(
                duration: animDuration,
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: List<PieChartSectionData>.generate(
                    branches.length,
                    (i) {
                      final b = branches[i];
                      final val = math.max(0.0, b.activeCreditDisbursedAmount);
                      final pct = (val / totalBook) * 100;
                      return PieChartSectionData(
                        value: val > 0 ? val : 0.001,
                        color: palette[i % palette.length],
                        radius: 34,
                        title: pct >= 9 ? '${pct.toStringAsFixed(0)}%' : '',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...branches.asMap().entries.map((entry) {
              final i = entry.key;
              final b = entry.value;
              final val = math.max(0.0, b.activeCreditDisbursedAmount);
              final pct = totalBook > 0
                  ? (val / totalBook * 100).toStringAsFixed(1)
                  : '0.0';
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: palette[i % palette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        b.branchName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '$pct% · ${CurrencyFormatter.formatNaira(val)}',
                      style: _amSubTabular(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );

    final barCard = IcareCard(
      padding: const EdgeInsets.all(16),
      topAccentColor: tokens.infoDot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: tokens.infoDot),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Active Disbursements vs Full Payoffs',
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
              _LegendDot(
                color: tokens.successDot,
                label: 'Active Disbursed',
                tokens: tokens,
              ),
              _LegendDot(
                color: tokens.infoDot,
                label: 'Full Payoffs Settled',
                tokens: tokens,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasBarData)
            _AmChartEmpty(
              tokens: tokens,
              height: 170,
              message: 'No disbursement or payoff volumes in this period',
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
                            rodIdx == 0 ? 'Active Disbursed' : 'Full Payoffs';
                        return BarTooltipItem(
                          '${b.branchName}\n$series: ${CurrencyFormatter.formatNaira(rod.toY)}',
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
                            style: _amSubTabular(
                              fontSize: 10,
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
                        getTitlesWidget: (val, _) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= branches.length) {
                            return const SizedBox.shrink();
                          }
                          final raw = branches[idx].branchName;
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
                      final w = branches.length <= 4 ? 14.0 : 9.0;
                      return BarChartGroupData(
                        x: idx,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: math.max(0.0, b.activeCreditDisbursedAmount),
                            width: w,
                            color: tokens.successDot,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: math.max(0.0, b.fullPaymentsActiveCredit),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              pieCard,
              const SizedBox(height: 14),
              barCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: pieCard),
            const SizedBox(width: 16),
            Expanded(flex: 6, child: barCard),
          ],
        );
      },
    );
  }
}

/// Live Officer Expected vs Collected Bar Chart inside BranchInspectionScreen.
class BranchInspectionOfficerChart extends StatelessWidget {
  final List<dynamic> officers;

  const BranchInspectionOfficerChart({
    super.key,
    required this.officers,
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

    final slice = officers.take(8).toList();
    double maxVal = 0.0;
    for (final raw in slice) {
      final exp = (raw['Expected'] as num?)?.toDouble() ?? 0.0;
      final col = (raw['Collected'] as num?)?.toDouble() ?? 0.0;
      maxVal = math.max(maxVal, math.max(exp, col));
    }
    final hasData = slice.isNotEmpty && maxVal > 0;
    final barTop = hasData ? maxVal * 1.22 : 1000.0;

    return IcareCard(
      padding: const EdgeInsets.all(16),
      topAccentColor: tokens.brandPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Officer Target vs Collections',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _LegendDot(color: tokens.infoDot, label: 'Expected', tokens: tokens),
              _LegendDot(
                  color: tokens.successDot, label: 'Collected', tokens: tokens),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasData)
            _AmChartEmpty(
              tokens: tokens,
              height: 165,
              message: slice.isEmpty
                  ? 'No officer rosters scheduled for this date'
                  : 'Zero expected or collected volumes recorded today',
            )
          else
            SizedBox(
              height: 185,
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
                        final raw = slice[group.x.toInt()];
                        final name =
                            raw['Officer Name'] ?? raw['Officer'] ?? 'Officer';
                        final series = rodIdx == 0 ? 'Expected' : 'Collected';
                        return BarTooltipItem(
                          '$name\n$series: ${CurrencyFormatter.format(rod.toY)}',
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
                            style: _amSubTabular(
                              fontSize: 10,
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
                        getTitlesWidget: (val, _) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= slice.length) {
                            return const SizedBox.shrink();
                          }
                          final raw =
                              (slice[idx]['Officer Name'] ?? slice[idx]['Officer'] ?? '')
                                  .toString()
                                  .trim();
                          final first = raw.contains(' ') ? raw.split(' ').first : raw;
                          final label = first.length > 8
                              ? '${first.substring(0, 7)}.'
                              : first;
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
                    slice.length,
                    (idx) {
                      final raw = slice[idx];
                      final exp = (raw['Expected'] as num?)?.toDouble() ?? 0.0;
                      final col = (raw['Collected'] as num?)?.toDouble() ?? 0.0;
                      final w = slice.length <= 4 ? 14.0 : 10.0;
                      return BarChartGroupData(
                        x: idx,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: math.max(0.0, exp),
                            width: w,
                            color: tokens.infoDot,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: math.max(0.0, col),
                            width: w,
                            color: tokens.successDot,
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

/// Live Officer Productivity Comparison Chart inside OfficerProductivityModalSheet.
class OfficerProductivityComparisonChart extends StatelessWidget {
  final List<OfficerProductivityItemModel> officers;

  const OfficerProductivityComparisonChart({
    super.key,
    required this.officers,
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

    final slice = officers.take(6).toList();
    double maxVal = 0.0;
    for (final o in slice) {
      maxVal = math.max(
        maxVal,
        math.max(o.principalDisbursedAmount, o.fullPaymentsActiveCredit),
      );
    }
    final hasData = slice.isNotEmpty && maxVal > 0;
    final barTop = hasData ? maxVal * 1.24 : 1000.0;

    return IcareCard(
      padding: const EdgeInsets.all(14),
      topAccentColor: tokens.brandPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 17, color: tokens.brandPrimary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Disbursed Principal vs Full Payoffs by Officer',
                  style: TextStyle(
                    fontSize: 13,
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
            runSpacing: 4,
            children: [
              _LegendDot(
                color: tokens.successDot,
                label: 'Disbursed',
                tokens: tokens,
              ),
              _LegendDot(
                color: tokens.infoDot,
                label: 'Full Payoffs',
                tokens: tokens,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasData)
            _AmChartEmpty(
              tokens: tokens,
              height: 140,
              message: 'No disbursement or payoff activity for this period',
            )
          else
            SizedBox(
              height: 160,
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
                        final item = slice[group.x.toInt()];
                        final series =
                            rodIdx == 0 ? 'Disbursed' : 'Full Payoffs';
                        return BarTooltipItem(
                          '${item.fullName}\n$series: ${CurrencyFormatter.formatNaira(rod.toY)}',
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
                        reservedSize: 46,
                        interval: barTop / 4,
                        getTitlesWidget: (val, _) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            _compactNgn.format(val),
                            textAlign: TextAlign.right,
                            style: _amSubTabular(
                              fontSize: 9.5,
                              color: tokens.textMuted,
                            ),
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
                          if (idx < 0 || idx >= slice.length) {
                            return const SizedBox.shrink();
                          }
                          final raw = slice[idx].fullName.trim();
                          final short = raw.contains(' ')
                              ? raw.split(' ').first
                              : raw;
                          final label = short.length > 8
                              ? '${short.substring(0, 7)}.'
                              : short;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              label,
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
                  barGroups: List<BarChartGroupData>.generate(
                    slice.length,
                    (idx) {
                      final o = slice[idx];
                      final w = slice.length <= 4 ? 13.0 : 9.0;
                      return BarChartGroupData(
                        x: idx,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: math.max(0.0, o.principalDisbursedAmount),
                            width: w,
                            color: tokens.successDot,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: math.max(0.0, o.fullPaymentsActiveCredit),
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
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final IcareSurfaceTokens tokens;

  const _LegendDot({
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

class _AmChartEmpty extends StatelessWidget {
  final IcareSurfaceTokens tokens;
  final double height;
  final String message;

  const _AmChartEmpty({
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
