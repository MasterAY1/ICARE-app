import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import 'co_shared_widgets.dart';

/// Live `fl_chart` installment bar chart for loan schedule preview.
class CoScheduleAmortizationChart extends StatelessWidget {
  final List<dynamic> installments;

  const CoScheduleAmortizationChart({
    super.key,
    required this.installments,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    if (installments.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sample up to 16 evenly spaced installments when daily/long schedule has many bars
    final List<Map<String, dynamic>> sampled = [];
    if (installments.length <= 16) {
      for (final item in installments) {
        if (item is Map) sampled.add(Map<String, dynamic>.from(item));
      }
    } else {
      for (int i = 0; i < 16; i++) {
        final idx = ((i * (installments.length - 1)) / 15).round();
        final item = installments[idx];
        if (item is Map) sampled.add(Map<String, dynamic>.from(item));
      }
    }

    double maxDue = 0.0;
    for (final row in sampled) {
      final due = (row['total_due'] as num?)?.toDouble() ?? 0.0;
      if (due > maxDue) maxDue = due;
    }
    if (maxDue <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Projected Installment Cadence',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: BarChart(
            BarChartData(
              maxY: maxDue * 1.2,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: tokens.borderSubtle,
                  strokeWidth: 0.7,
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => tokens.surfaceElevated,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final row = sampled[groupIndex];
                    return BarTooltipItem(
                      '#${row['installment_number']} (${row['due_date']})\n${CurrencyFormatter.formatNaira(rod.toY)}',
                      coTabularStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (v, _) => Text(
                      v >= 1000 ? '₦${(v / 1000).toStringAsFixed(0)}k' : '₦${v.toInt()}',
                      style: coTabularStyle(fontSize: 9.5, color: tokens.textMuted),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= sampled.length) {
                        return const SizedBox.shrink();
                      }
                      if (sampled.length > 10 && idx % 3 != 0 && idx != sampled.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '#${sampled[idx]['installment_number']}',
                          style: coTabularStyle(fontSize: 9.5, color: tokens.textMuted),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(sampled.length, (i) {
                final due = (sampled[i]['total_due'] as num?)?.toDouble() ?? 0.0;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: due,
                      width: sampled.length > 10 ? 8 : 14,
                      color: tokens.brandPrimary,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

/// Live `fl_chart` breakdown for Pending Disbursements queue (Asset-Backed vs Cash Loans & Product Volumes).
class CoPendingDisbursementAnalyticsCard extends StatelessWidget {
  final List<dynamic> pendingLoans;

  const CoPendingDisbursementAnalyticsCard({
    super.key,
    required this.pendingLoans,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    if (pendingLoans.isEmpty) {
      return const SizedBox.shrink();
    }

    double cashVol = 0.0;
    double assetVol = 0.0;
    final Map<String, double> byProduct = {};

    for (final raw in pendingLoans) {
      if (raw is! Map) continue;
      final amt = (raw['loan_amount'] as num?)?.toDouble() ?? 0.0;
      final asset = (raw['asset_summary']?.toString() ?? '—').trim();
      final prod = (raw['loan_product']?.toString() ?? 'Standard').trim();
      if (asset.isNotEmpty && asset != '—') {
        assetVol += amt;
      } else {
        cashVol += amt;
      }
      byProduct[prod] = (byProduct[prod] ?? 0.0) + amt;
    }

    final totalVol = cashVol + assetVol;
    if (totalVol <= 0) return const SizedBox.shrink();

    final prodEntries = byProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topProds = prodEntries.take(6).toList();
    final maxProd = topProds.fold<double>(0.0, (m, e) => math.max(m, e.value));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 780;
        final donutCard = IcareCard(
          backgroundColor: tokens.surfaceSubtle,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending Queue Split (Cash vs Asset)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 140,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                    sections: [
                      if (cashVol > 0)
                        PieChartSectionData(
                          value: cashVol,
                          color: tokens.brandPrimary,
                          radius: 32,
                          title: '${((cashVol / totalVol) * 100).round()}%',
                          titleStyle: coTabularStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      if (assetVol > 0)
                        PieChartSectionData(
                          value: assetVol,
                          color: tokens.infoDot,
                          radius: 32,
                          title: '${((assetVol / totalVol) * 100).round()}%',
                          titleStyle: coTabularStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    'Cash Loans: ${CurrencyFormatter.formatNaira(cashVol, showDecimals: false)}',
                    style: coTabularStyle(fontSize: 11, color: tokens.brandPrimary),
                  ),
                  Text(
                    'Asset Financing: ${CurrencyFormatter.formatNaira(assetVol, showDecimals: false)}',
                    style: coTabularStyle(fontSize: 11, color: tokens.infoText),
                  ),
                ],
              ),
            ],
          ),
        );

        final prodBarCard = IcareCard(
          backgroundColor: tokens.surfaceSubtle,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Queued Disbursement Volume by Product',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    maxY: maxProd * 1.2,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: tokens.borderSubtle,
                        strokeWidth: 0.7,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => tokens.surfaceElevated,
                        getTooltipItem: (group, groupIndex, rod, _) {
                          final item = topProds[groupIndex];
                          return BarTooltipItem(
                            '${item.key}\n${CurrencyFormatter.formatNaira(rod.toY)}',
                            coTabularStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (v, _) => Text(
                            v >= 1000000
                                ? '₦${(v / 1000000).toStringAsFixed(1)}M'
                                : '₦${(v / 1000).toStringAsFixed(0)}k',
                            style: coTabularStyle(fontSize: 9.5, color: tokens.textMuted),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= topProds.length) {
                              return const SizedBox.shrink();
                            }
                            final raw = topProds[idx].key;
                            final short =
                                raw.length > 10 ? '${raw.substring(0, 9)}..' : raw;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                short,
                                style: TextStyle(fontSize: 9.5, color: tokens.textSecondary),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(topProds.length, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: topProds[i].value,
                            width: 14,
                            color: tokens.infoDot,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: donutCard),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: prodBarCard),
            ],
          );
        }
        return Column(
          children: [
            donutCard,
            const SizedBox(height: 12),
            prodBarCard,
          ],
        );
      },
    );
  }
}
