import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../data/models/bm_dashboard_models.dart';
import '../../data/models/master_cashbook_models.dart';

/// Shared tabular numeric text style for Branch Manager & Cashbook ledgers.
TextStyle bmTabularStyle({
  double fontSize = 13,
  FontWeight fontWeight = FontWeight.w600,
  Color? color,
  double? letterSpacing,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Live BM Dashboard Analytics Charts:
/// - Officer Expected vs Collected bar comparison
/// - Branch Vault & Cash Mix donut chart
/// Zero fabricated fallback series: renders honest zero states when inactive.
class BmDashboardAnalyticsSection extends StatelessWidget {
  final BmDashboardDataModel data;

  const BmDashboardAnalyticsSection({
    super.key,
    required this.data,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final barCard = _buildOfficerBarCard(tokens, animDuration);
        final pieCard = _buildCashMixCard(tokens, animDuration);

        if (!isWide) {
          return Column(
            children: [
              barCard,
              const SizedBox(height: 14),
              pieCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: barCard),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: pieCard),
          ],
        );
      },
    );
  }

  Widget _buildOfficerBarCard(
    IcareSurfaceTokens tokens,
    Duration animDuration,
  ) {
    final officers = data.officerCollectionStatus.take(8).toList();
    double maxVal = 0;
    for (final o in officers) {
      maxVal = math.max(maxVal, math.max(o.expected, o.collected));
    }
    final hasActivity = officers.isNotEmpty && maxVal > 0;
    final barTop = maxVal > 0 ? maxVal * 1.22 : 1000.0;

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
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Expected meeting schedule vs physical repayments recorded today',
            style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _BmLegendItem(
                color: tokens.infoDot,
                label: 'Expected',
                tokens: tokens,
              ),
              _BmLegendItem(
                color: tokens.successDot,
                label: 'Collected',
                tokens: tokens,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasActivity)
            _BmChartEmptyState(
              tokens: tokens,
              height: 195,
              message: officers.isEmpty
                  ? 'No officer collection rosters recorded for this branch'
                  : 'Zero scheduled or collected repayments for the selected date',
            )
          else
            SizedBox(
              height: 210,
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
                        final item = officers[group.x.toInt()];
                        final series = rodIndex == 0 ? 'Expected' : 'Collected';
                        return BarTooltipItem(
                          '${item.officerName}\n$series: ${CurrencyFormatter.format(rod.toY)}\nCompliance: ${item.compliancePct.toStringAsFixed(1)}%',
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
                        reservedSize: 50,
                        interval: barTop / 4,
                        getTitlesWidget: (val, _) {
                          if (val < 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              _compactNgn.format(val),
                              textAlign: TextAlign.right,
                              style: bmTabularStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: tokens.textMuted,
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
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= officers.length) {
                            return const SizedBox.shrink();
                          }
                          final raw = officers[idx].officerName.trim();
                          final short = raw.contains(' ')
                              ? raw.split(' ').first
                              : raw;
                          final label = short.length > 9
                              ? '${short.substring(0, 8)}.'
                              : short;
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
                    officers.length,
                    (idx) {
                      final o = officers[idx];
                      final rodWidth = officers.length <= 4 ? 16.0 : 11.0;
                      return BarChartGroupData(
                        x: idx,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: math.max(0.0, o.expected),
                            width: rodWidth,
                            color: tokens.infoDot,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: math.max(0.0, o.collected),
                            width: rodWidth,
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

  Widget _buildCashMixCard(
    IcareSurfaceTokens tokens,
    Duration animDuration,
  ) {
    final pos = data.branchCashPosition;
    final cashIn = math.max(0.0, pos.cashIn);
    final cashOut = math.max(0.0, pos.cashOut);
    final bankDeposit = math.max(0.0, pos.bankDeposit);
    final bankWithdrawal = math.max(0.0, pos.bankWithdrawal);
    final totalFlow = cashIn + cashOut + bankDeposit + bankWithdrawal;

    final slices = <({String label, double value, Color color})>[
      (label: 'Vault Inflows', value: cashIn, color: tokens.successDot),
      (label: 'Cash Disbursed', value: cashOut, color: tokens.warningDot),
      (label: 'Bank Deposits', value: bankDeposit, color: tokens.infoDot),
      (
        label: 'Bank Withdrawals',
        value: bankWithdrawal,
        color: tokens.brandPrimaryLight,
      ),
    ].where((s) => s.value > 0).toList();

    return IcareCard(
      padding: const EdgeInsets.all(16),
      topAccentColor: tokens.brandAccent,
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
                  'Vault Flow Breakdown',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Closing vault: ${CurrencyFormatter.format(pos.closingBalance)}',
            style: bmTabularStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: tokens.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          if (totalFlow <= 0 || slices.isEmpty)
            _BmChartEmptyState(
              tokens: tokens,
              height: 195,
              message: 'Zero vault cash movements posted for today',
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 155,
                  child: PieChart(
                    duration: animDuration,
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 34,
                      sections: slices.map((s) {
                        final pct = (s.value / totalFlow) * 100;
                        return PieChartSectionData(
                          value: s.value,
                          color: s.color,
                          radius: 36,
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(s.value),
                          style: bmTabularStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Live Daily Master Cashbook Chart Panel (Vault Bridge + Outflow Split).
class MasterCashbookDailyAnalyticsSection extends StatelessWidget {
  final MasterCashbookDailyData data;

  const MasterCashbookDailyAnalyticsSection({
    super.key,
    required this.data,
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

    final opening = math.max(0.0, data.inflows.openingBalance);
    final newInflows = math.max(0.0, data.totalInflows - opening);
    final outflows = math.max(0.0, data.totalOutflows);
    final closing = math.max(0.0, data.closingBalance);
    final bankDeposit = math.max(0.0, data.outflows.bankDeposit);
    final otherOutflows = math.max(0.0, outflows - bankDeposit);

    final maxY = [opening, newInflows, outflows, closing].fold(0.0, math.max);
    final hasData = maxY > 0;
    final barTop = maxY > 0 ? maxY * 1.24 : 1000.0;

    final bridgeBars = [
      (label: 'Opening', value: opening, color: tokens.textMuted),
      (label: 'Receipts', value: newInflows, color: tokens.successDot),
      (label: 'Outflows', value: outflows, color: tokens.dangerDot),
      (label: 'Closing', value: closing, color: tokens.brandPrimary),
    ];

    final splitTotal = bankDeposit + otherOutflows + closing;
    final pieSlices = [
      (label: 'Closing Vault', value: closing, color: tokens.brandPrimary),
      (label: 'Bank Deposited', value: bankDeposit, color: tokens.infoDot),
      (label: 'Other Outflows', value: otherOutflows, color: tokens.warningDot),
    ].where((s) => s.value > 0).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 880;
        final bridgeCard = IcareCard(
          padding: const EdgeInsets.all(16),
          topAccentColor: tokens.brandPrimary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.waterfall_chart_rounded,
                      size: 18, color: tokens.brandPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Daily Vault Cash Bridge',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Opening balance, daily inflows, disbursements & net vault close',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 14),
              if (!hasData)
                _BmChartEmptyState(
                  tokens: tokens,
                  height: 185,
                  message: 'No cashbook movements recorded for this date',
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
                          getTooltipItem: (group, _, rod, __) {
                            final item = bridgeBars[group.x.toInt()];
                            return BarTooltipItem(
                              '${item.label}\n${CurrencyFormatter.format(rod.toY)}',
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
                            reservedSize: 50,
                            interval: barTop / 4,
                            getTitlesWidget: (val, _) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                _compactNgn.format(val),
                                textAlign: TextAlign.right,
                                style: bmTabularStyle(
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
                            getTitlesWidget: (value, _) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= bridgeBars.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  bridgeBars[idx].label,
                                  style: TextStyle(
                                    fontSize: 11,
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
                        bridgeBars.length,
                        (idx) => BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: bridgeBars[idx].value,
                              width: 24,
                              color: bridgeBars[idx].color,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        final splitCard = IcareCard(
          padding: const EdgeInsets.all(16),
          topAccentColor: tokens.infoDot,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.donut_large_rounded,
                      size: 18, color: tokens.infoDot),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Custody & Outflow Mix',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Share of day liquidity held in vault vs banked/disbursed',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 14),
              if (splitTotal <= 0 || pieSlices.isEmpty)
                _BmChartEmptyState(
                  tokens: tokens,
                  height: 185,
                  message: 'No vault custody balance or outflows today',
                )
              else
                Column(
                  children: [
                    SizedBox(
                      height: 140,
                      child: PieChart(
                        duration: animDuration,
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 32,
                          sections: pieSlices.map((s) {
                            final pct = (s.value / splitTotal) * 100;
                            return PieChartSectionData(
                              value: s.value,
                              color: s.color,
                              radius: 34,
                              title:
                                  pct >= 10 ? '${pct.toStringAsFixed(0)}%' : '',
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
                    ...pieSlices.map(
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
                              CurrencyFormatter.format(s.value),
                              style: bmTabularStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );

        if (!isWide) {
          return Column(
            children: [
              bridgeCard,
              const SizedBox(height: 14),
              splitCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: bridgeCard),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: splitCard),
          ],
        );
      },
    );
  }
}

/// Live Monthly Ledger Trend Chart (Daily Closing Balance & Inflow/Outflow).
class MasterCashbookMonthlyAnalyticsSection extends StatelessWidget {
  final List<MonthlyLedgerRowData> rows;

  const MasterCashbookMonthlyAnalyticsSection({
    super.key,
    required this.rows,
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

    final recentRows = rows.length > 16 ? rows.sublist(rows.length - 16) : rows;
    double maxVal = 0;
    for (final r in recentRows) {
      maxVal = math.max(
        maxVal,
        math.max(r.closingBalance, math.max(r.totalInflows, r.totalOutflows)),
      );
    }
    final hasActivity = recentRows.isNotEmpty && maxVal > 0;
    final barTop = maxVal > 0 ? maxVal * 1.2 : 1000.0;

    return IcareCard(
      padding: const EdgeInsets.all(16),
      topAccentColor: tokens.brandPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded,
                  size: 18, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Monthly Daily Vault & Movement Trend',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Daily inflows vs outflows across active business days',
            style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _BmLegendItem(
                color: tokens.successDot,
                label: 'Total Inflows',
                tokens: tokens,
              ),
              _BmLegendItem(
                color: tokens.dangerDot,
                label: 'Total Outflows',
                tokens: tokens,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasActivity)
            _BmChartEmptyState(
              tokens: tokens,
              height: 180,
              message: 'No ledger rows recorded for this month',
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
                      getTooltipItem: (group, _, rod, rodIndex) {
                        final item = recentRows[group.x.toInt()];
                        final series = rodIndex == 0 ? 'Inflows' : 'Outflows';
                        return BarTooltipItem(
                          '${item.date}\n$series: ${CurrencyFormatter.format(rod.toY)}\nClose: ${CurrencyFormatter.format(item.closingBalance)}',
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
                        reservedSize: 50,
                        interval: barTop / 4,
                        getTitlesWidget: (val, _) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            _compactNgn.format(val),
                            textAlign: TextAlign.right,
                            style: bmTabularStyle(
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
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= recentRows.length) {
                            return const SizedBox.shrink();
                          }
                          final step = recentRows.length > 8 ? 2 : 1;
                          if (idx % step != 0 && idx != recentRows.length - 1) {
                            return const SizedBox.shrink();
                          }
                          final raw = recentRows[idx].date;
                          final label = raw.length >= 10
                              ? raw.substring(8, 10)
                              : raw;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label,
                              style: bmTabularStyle(
                                fontSize: 10,
                                color: tokens.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List<BarChartGroupData>.generate(
                    recentRows.length,
                    (idx) {
                      final r = recentRows[idx];
                      final w = recentRows.length <= 6 ? 12.0 : 8.0;
                      return BarChartGroupData(
                        x: idx,
                        barsSpace: 3,
                        barRods: [
                          BarChartRodData(
                            toY: math.max(0.0, r.totalInflows),
                            width: w,
                            color: tokens.successDot,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                          BarChartRodData(
                            toY: math.max(0.0, r.totalOutflows),
                            width: w,
                            color: tokens.dangerDot,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
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

class _BmLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final IcareSurfaceTokens tokens;

  const _BmLegendItem({
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

class _BmChartEmptyState extends StatelessWidget {
  final IcareSurfaceTokens tokens;
  final double height;
  final String message;

  const _BmChartEmptyState({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_chart_outlined_rounded,
              size: 28, color: tokens.textLight),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
