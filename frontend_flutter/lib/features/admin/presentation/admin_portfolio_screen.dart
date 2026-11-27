import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error_formatter.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/icare_card.dart';
import '../../../core/widgets/icare_data_table.dart';
import '../../../core/widgets/icare_metric_card.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../../../core/widgets/icare_status_badge.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import '../data/datasources/admin_api_service.dart';
import '../data/models/admin_dashboard_models.dart';
import 'widgets/admin_portfolio_charts.dart';

final adminPortfolioYearProvider = StateProvider.autoDispose<int>((ref) => DateTime.now().year);

class AdminPortfolioScreen extends ConsumerWidget {
  const AdminPortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(adminPortfolioYearProvider);
    ref.listen<int>(globalRefreshSignalProvider, (prev, next) {
      if (next != prev) {
        ref.invalidate(institutionPerformanceProvider(year));
      }
    });

    final perfAsync = ref.watch(institutionPerformanceProvider(year));
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final tokens = IcareSurfaceTokens.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Executive Screen Header
          _buildScreenHeader(context, ref, tokens, year, isMobile),
          const SizedBox(height: 18),

          perfAsync.when(
            loading: () => const IcareDashboardSkeleton(),
            error: (err, _) {
              final details = AppErrorDetails.from(err);
              return _buildErrorBanner(
                tokens,
                details.title,
                details.message,
                () => ref.invalidate(institutionPerformanceProvider(year)),
              );
            },
            data: (data) {
              final branches = data.branchRankings;
              final summary = data.summary;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Executive KPI Summary Cards
                  _buildKpiRibbon(tokens, summary, isMobile),
                  const SizedBox(height: 20),

                  // 2.5 Live Institutional Charts
                  AdminPortfolioChartsSection(
                    branches: branches,
                    summary: summary,
                    year: year,
                  ),
                  const SizedBox(height: 20),

                  // 3. Visual Cross-Branch Comparison Matrix
                  _buildBranchComparisonMatrix(tokens, branches, summary, isMobile),
                  const SizedBox(height: 20),

                  // 4. Authoritative Cross-Branch Comparative Table
                  _buildComparativeLeagueTable(tokens, branches, isMobile),
                  const SizedBox(height: 20),

                  // 5. Branch Top Performing Officers Spotlight
                  _buildTopOfficersSpotlight(tokens, branches, isMobile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. SCREEN HEADER
  // =========================================================================
  Widget _buildScreenHeader(
      BuildContext context, WidgetRef ref, IcareSurfaceTokens tokens, int year, bool isMobile) {
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 112, maxWidth: 140),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.borderStrong),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: year,
                isExpanded: true,
                dropdownColor: tokens.surfaceElevated,
                isDense: true,
                icon: Icon(Icons.arrow_drop_down, size: 18, color: tokens.textSecondary),
                items: ({
                  DateTime.now().year,
                  DateTime.now().year - 1,
                  DateTime.now().year - 2,
                  year,
                }.toList()
                      ..sort((a, b) => b.compareTo(a)))
                    .map((y) {
                  return DropdownMenuItem<int>(
                    value: y,
                    child: Text(
                      'Cycle $y',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(adminPortfolioYearProvider.notifier).state = val;
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => ref.invalidate(institutionPerformanceProvider(year)),
          icon: Icon(Icons.refresh, size: 18, color: tokens.textSecondary),
          tooltip: 'Refresh Portfolio',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );

    return IcareCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      topAccentColor: tokens.brandPrimary,
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart_outline, size: 18, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Institutional Portfolio Analytics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Cross-branch comparative performance, capital deployment, and liquidity.',
                        style: TextStyle(fontSize: 12, color: tokens.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          controls,
        ],
      ),
    );
  }

  // =========================================================================
  // 2. EXECUTIVE KPI SUMMARY CARDS
  // =========================================================================
  Widget _buildKpiRibbon(
      IcareSurfaceTokens tokens, PerformanceSummaryModel summary, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = isMobile ? 2 : (constraints.maxWidth > 1100 ? 5 : 3);
        final w = (constraints.maxWidth - ((count - 1) * 12)) / count;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              tokens: tokens,
              title: 'CAPITAL DISBURSED',
              value: CurrencyFormatter.formatNaira(summary.totalDisbursedYtd),
              subtitle: '${summary.totalDisbursedCount} Loans Disbursed',
              icon: Icons.payments_outlined,
              iconColor: tokens.brandPrimary,
              width: w,
            ),
            _buildMetricCard(
              tokens: tokens,
              title: 'ACTIVE CREDIT BOOK',
              value: CurrencyFormatter.formatNaira(summary.totalActiveCredit),
              subtitle: '${summary.totalActiveBorrowers} Active Borrowers',
              icon: Icons.account_balance_wallet_outlined,
              iconColor: tokens.infoDot,
              width: w,
            ),
            _buildMetricCard(
              tokens: tokens,
              title: 'EARLY FULL PAYOFFS',
              value: CurrencyFormatter.formatNaira(summary.totalFullPayoffsAmount),
              subtitle: '${summary.totalFullPayoffsCount} Accounts Settled',
              icon: Icons.check_circle_outline,
              iconColor: tokens.successDot,
              width: w,
            ),
            _buildMetricCard(
              tokens: tokens,
              title: 'OVERDUE RECOVERED',
              value: CurrencyFormatter.formatNaira(summary.totalOverdueRecoveredYtd),
              subtitle: 'Arrears Pool: ${CurrencyFormatter.formatNaira(summary.totalOverdue)}',
              icon: Icons.restore_outlined,
              iconColor: tokens.warningDot,
              width: w,
            ),
            _buildMetricCard(
              tokens: tokens,
              title: 'NET SAVINGS LIQUIDITY',
              value: CurrencyFormatter.formatNaira(summary.totalNetSavings),
              subtitle: 'PAR Exposure: ${summary.averagePar.toStringAsFixed(1)}%',
              icon: Icons.savings_outlined,
              iconColor: tokens.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
              isAlert: summary.averagePar > 5.0,
              width: w,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IcareSurfaceTokens tokens,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required double width,
    bool isAlert = false,
  }) {
    return SizedBox(
      width: width,
      child: IcareMetricCard(
        label: title,
        value: value,
        delta: subtitle,
        isInverseDelta: isAlert,
        icon: icon,
        topBorderColor: isAlert ? tokens.dangerDot : iconColor,
        statusTextColor: isAlert ? tokens.dangerText : null,
      ),
    );
  }

  // =========================================================================
  // 3. VISUAL CROSS-BRANCH COMPARISON MATRIX (CHARTS & BARS)
  // =========================================================================
  Widget _buildBranchComparisonMatrix(
    IcareSurfaceTokens tokens,
    List<BranchPerformanceItemModel> branches,
    PerformanceSummaryModel summary,
    bool isMobile,
  ) {
    if (branches.isEmpty) return const SizedBox.shrink();

    final maxDisb = branches.map((b) => b.disbPrincipal).fold(0.0, (m, v) => v > m ? v : m);
    final maxActive = branches.map((b) => b.activeCreditBook).fold(0.0, (m, v) => v > m ? v : m);

    return IcareCard(
      padding: const EdgeInsets.all(16),
      topAccentColor: tokens.brandPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, size: 18, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Branch Capital Deployment & Portfolio Health Distribution',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Visual comparative breakdown of loan principal disbursed and active credit volume by branch.',
            style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
          ),
          const SizedBox(height: 16),

          ...branches.map((b) {
            final disbRatio = maxDisb > 0 ? (b.disbPrincipal / maxDisb) : 0.0;
            final activeRatio = maxActive > 0 ? (b.activeCreditBook / maxActive) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tokens.surfaceHover,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#${b.rank}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              b.branchName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '(${b.bmName})',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: tokens.textMuted),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            CurrencyFormatter.formatNaira(b.disbPrincipal),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.brandPrimary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 10),
                          IcareStatusBadge(
                            label: 'PAR ${b.parPct.toStringAsFixed(1)}%',
                            variant: b.parPct <= 5.0 ? IcareBadgeVariant.success : IcareBadgeVariant.danger,
                            showDot: false,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 8,
                      width: double.infinity,
                      color: tokens.surfaceHover,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: disbRatio.clamp(0.02, 1.0),
                        child: Container(color: tokens.brandPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 5,
                      width: double.infinity,
                      color: tokens.surfaceHover,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: activeRatio.clamp(0.02, 1.0),
                        child: Container(color: tokens.infoDot),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          Divider(height: 20, color: tokens.borderSubtle),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: tokens.brandPrimary),
                  const SizedBox(width: 6),
                  Text('Disbursed Principal', style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: tokens.infoDot),
                  const SizedBox(width: 6),
                  Text('Active Credit Book', style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. AUTHORITATIVE CROSS-BRANCH COMPARATIVE TABLE
  // =========================================================================
  Widget _buildComparativeLeagueTable(
      IcareSurfaceTokens tokens, List<BranchPerformanceItemModel> branches, bool isMobile) {
    final colStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.textSecondary);
    return IcareCard(
      padding: EdgeInsets.zero,
      topAccentColor: tokens.infoDot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.table_chart_outlined, size: 16, color: tokens.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Branch Performance & Portfolio Dynamics',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.borderSubtle),
          Padding(
            padding: const EdgeInsets.all(12),
            child: IcareDataTable(
              minWidth: 880,
              columns: [
                DataColumn(label: Text('Rank', style: colStyle)),
                DataColumn(label: Text('Branch', style: colStyle)),
                DataColumn(label: Text('Disbursed', style: colStyle)),
                DataColumn(label: Text('Active vs Payoffs', style: colStyle)),
                DataColumn(label: Text('Overdue Arrears', style: colStyle)),
                DataColumn(label: Text('Overdue Recovered', style: colStyle)),
                DataColumn(label: Text('Net Savings', style: colStyle)),
                DataColumn(label: Text('PAR Health', style: colStyle)),
                DataColumn(label: Text('Top Field Officer', style: colStyle)),
              ],
              rows: branches.map((b) {
                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: b.rank <= 3 ? tokens.infoBg : tokens.surfaceHover,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${b.rank}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: b.rank <= 3 ? tokens.infoText : tokens.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.branchName, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                          Text(b.bmName, style: TextStyle(fontSize: 10.5, color: tokens.textMuted)),
                        ],
                      ),
                    ),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CurrencyFormatter.formatNaira(b.disbPrincipal),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                          Text('${b.disbCount} loans', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
                        ],
                      ),
                    ),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b.activeMembers} Active · ${b.fullPayoffsCount} Settled',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                          ),
                          Text(
                            '${CurrencyFormatter.formatNaira(b.activeCreditBook)} active book',
                            style: TextStyle(fontSize: 10, color: tokens.textMuted, fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CurrencyFormatter.formatNaira(b.overdueAmount),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: b.overdueAmount > 0 ? tokens.dangerText : tokens.successDot,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text('${b.defaultersCount} defaulters', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
                        ],
                      ),
                    ),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CurrencyFormatter.formatNaira(b.overdueRecovered),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.successText, fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                          Text('${b.recoveryRatePct.toStringAsFixed(1)}% recovery rate', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        CurrencyFormatter.formatNaira(b.netSavingsBalance),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: b.netSavingsBalance >= 0 ? tokens.textPrimary : tokens.dangerText,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    DataCell(
                      IcareStatusBadge(
                        label: '${b.parPct.toStringAsFixed(1)}%',
                        variant: b.parPct <= 5.0 ? IcareBadgeVariant.success : IcareBadgeVariant.danger,
                        showDot: false,
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline, size: 14, color: tokens.brandPrimary),
                          const SizedBox(width: 4),
                          Text(b.topOfficerName, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. TOP OFFICERS SPOTLIGHT
  // =========================================================================
  Widget _buildTopOfficersSpotlight(
      IcareSurfaceTokens tokens, List<BranchPerformanceItemModel> branches, bool isMobile) {
    return IcareCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined, size: 18, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Branch Lead Field Officers',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Primary credit officer driving active portfolio expansion and collections for each operational branch.',
            style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: branches.map((b) {
              return Container(
                constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: tokens.infoBg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(Icons.person, size: 18, color: tokens.infoDot),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.topOfficerName,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${b.branchName} · ${b.activeMembers} Accounts',
                            style: TextStyle(fontSize: 10.5, color: tokens.textMuted),
                            overflow: TextOverflow.ellipsis,
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

  Widget _buildErrorBanner(
      IcareSurfaceTokens tokens, String title, String detail, VoidCallback onRetry) {
    return IcareCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      topAccentColor: tokens.dangerDot,
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: tokens.dangerDot, size: 20),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.dangerText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 14),
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.dangerText,
              side: BorderSide(color: tokens.dangerBorder),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            label: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
