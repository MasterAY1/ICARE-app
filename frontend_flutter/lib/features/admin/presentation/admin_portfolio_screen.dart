import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../data/datasources/admin_api_service.dart';
import '../data/models/admin_dashboard_models.dart';

final adminPortfolioYearProvider = StateProvider.autoDispose<int>((ref) => DateTime.now().year);

class AdminPortfolioScreen extends ConsumerWidget {
  const AdminPortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(adminPortfolioYearProvider);
    final perfAsync = ref.watch(institutionPerformanceProvider(year));
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Executive Screen Header
          _buildScreenHeader(context, ref, year, isMobile),
          const SizedBox(height: 20),

          perfAsync.when(
            loading: () => const IcareSkeletonLoader(height: 140),
            error: (err, _) => _buildErrorBanner(
              'Unable to load institutional portfolio',
              'The backend service may be synchronizing. Please retry.',
              () => ref.invalidate(institutionPerformanceProvider(year)),
            ),
            data: (data) {
              final branches = data.branchRankings;
              final summary = data.summary;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Executive KPI Summary Cards
                  _buildKpiRibbon(summary, isMobile),
                  const SizedBox(height: 24),

                  // 3. Visual Cross-Branch Comparison Matrix (Charts & Progress Bars)
                  _buildBranchComparisonMatrix(branches, summary, isMobile),
                  const SizedBox(height: 24),

                  // 4. Authoritative Cross-Branch Comparative Table
                  _buildComparativeLeagueTable(branches, isMobile),
                  const SizedBox(height: 24),

                  // 5. Branch Top Performing Officers Spotlight
                  _buildTopOfficersSpotlight(branches, isMobile),
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
  Widget _buildScreenHeader(BuildContext context, WidgetRef ref, int year, bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart_outline, size: 18, color: Color(0xFF0F766E)),
                    SizedBox(width: 8),
                    Text(
                      'Institutional Portfolio Analytics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                if (!isMobile) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Cross-branch comparative performance, capital deployment, loan book dynamics, and savings liquidity.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: year,
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF475569)),
                    items: [2026, 2025, 2024].map((y) {
                      return DropdownMenuItem<int>(
                        value: y,
                        child: Text(
                          'Cycle $y',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
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
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => ref.invalidate(institutionPerformanceProvider(year)),
                icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF475569)),
                tooltip: 'Refresh Portfolio',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. EXECUTIVE KPI SUMMARY CARDS
  // =========================================================================
  Widget _buildKpiRibbon(PerformanceSummaryModel summary, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = isMobile ? 2 : (constraints.maxWidth > 1100 ? 5 : 3);
        final w = (constraints.maxWidth - ((count - 1) * 12)) / count;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              title: 'CAPITAL DISBURSED',
              value: CurrencyFormatter.formatNaira(summary.totalDisbursedYtd),
              subtitle: '${summary.totalDisbursedCount} Loans Disbursed',
              icon: Icons.payments_outlined,
              iconColor: const Color(0xFF0F766E),
              width: w,
            ),
            _buildMetricCard(
              title: 'ACTIVE CREDIT BOOK',
              value: CurrencyFormatter.formatNaira(summary.totalActiveCredit),
              subtitle: '${summary.totalActiveBorrowers} Active Borrowers',
              icon: Icons.account_balance_wallet_outlined,
              iconColor: const Color(0xFF2563EB),
              width: w,
            ),
            _buildMetricCard(
              title: 'EARLY FULL PAYOFFS',
              value: CurrencyFormatter.formatNaira(summary.totalFullPayoffsAmount),
              subtitle: '${summary.totalFullPayoffsCount} Accounts Settled',
              icon: Icons.check_circle_outline,
              iconColor: const Color(0xFF059669),
              width: w,
            ),
            _buildMetricCard(
              title: 'OVERDUE RECOVERED',
              value: CurrencyFormatter.formatNaira(summary.totalOverdueRecoveredYtd),
              subtitle: 'Arrears Pool: ${CurrencyFormatter.formatNaira(summary.totalOverdue)}',
              icon: Icons.restore_outlined,
              iconColor: const Color(0xFFD97706),
              width: w,
            ),
            _buildMetricCard(
              title: 'NET SAVINGS LIQUIDITY',
              value: CurrencyFormatter.formatNaira(summary.totalNetSavings),
              subtitle: 'PAR Exposure: ${summary.averagePar.toStringAsFixed(1)}%',
              icon: Icons.savings_outlined,
              iconColor: const Color(0xFF7C3AED),
              isAlert: summary.averagePar > 5.0,
              width: w,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required double width,
    bool isAlert = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isAlert ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.3),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. VISUAL CROSS-BRANCH COMPARISON MATRIX (CHARTS & BARS)
  // =========================================================================
  Widget _buildBranchComparisonMatrix(
    List<BranchPerformanceItemModel> branches,
    PerformanceSummaryModel summary,
    bool isMobile,
  ) {
    if (branches.isEmpty) return const SizedBox.shrink();

    final maxDisb = branches.map((b) => b.disbPrincipal).fold(0.0, (m, v) => v > m ? v : m);
    final maxActive = branches.map((b) => b.activeCreditBook).fold(0.0, (m, v) => v > m ? v : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, size: 18, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text(
                'Branch Capital Deployment & Portfolio Health Distribution',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Visual comparative breakdown of loan principal disbursed and active credit volume by branch.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#${b.rank}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            b.branchName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${b.bmName})',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            CurrencyFormatter.formatNaira(b.disbPrincipal),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F766E),
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: b.parPct <= 5.0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PAR ${b.parPct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: b.parPct <= 5.0 ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Dual visual comparison bars: Disbursed (Teal) & Active Credit (Blue)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 8,
                      width: double.infinity,
                      color: const Color(0xFFF1F5F9),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: disbRatio.clamp(0.02, 1.0),
                        child: Container(color: const Color(0xFF0F766E)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 5,
                      width: double.infinity,
                      color: const Color(0xFFF1F5F9),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: activeRatio.clamp(0.02, 1.0),
                        child: Container(color: const Color(0xFF3B82F6)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const Divider(height: 20, color: Color(0xFFE2E8F0)),
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: Color(0xFF0F766E)),
                  SizedBox(width: 6),
                  Text('Disbursed Principal', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                ],
              ),
              SizedBox(width: 16),
              Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: Color(0xFF3B82F6)),
                  SizedBox(width: 6),
                  Text('Active Credit Book', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
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
  Widget _buildComparativeLeagueTable(List<BranchPerformanceItemModel> branches, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.table_chart_outlined, size: 16, color: Color(0xFF475569)),
                SizedBox(width: 8),
                Text(
                  'Branch Performance & Portfolio Dynamics',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 52,
              horizontalMargin: 16,
              columnSpacing: 18,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('Rank', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                DataColumn(label: Text('Branch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                DataColumn(label: Text('Disbursed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                DataColumn(label: Text('Active vs Payoffs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                DataColumn(label: Text('Overdue Arrears', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                DataColumn(label: Text('Overdue Recovered', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                DataColumn(label: Text('Net Savings', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                DataColumn(label: Text('PAR Health', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                DataColumn(label: Text('Top Field Officer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
              ],
              rows: branches.map((b) {
                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: b.rank <= 3 ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${b.rank}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: b.rank <= 3 ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.branchName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          Text(b.bmName, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
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
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                          Text('${b.disbCount} loans', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
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
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            '${CurrencyFormatter.formatNaira(b.activeCreditBook)} active book',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFeatures: [FontFeature.tabularFigures()]),
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
                              color: b.overdueAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text('${b.defaultersCount} defaulters', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
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
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669), fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                          Text('${b.recoveryRatePct.toStringAsFixed(1)}% recovery rate', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        CurrencyFormatter.formatNaira(b.netSavingsBalance),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: b.netSavingsBalance >= 0 ? const Color(0xFF0F172A) : const Color(0xFFDC2626),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: b.parPct <= 5.0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${b.parPct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: b.parPct <= 5.0 ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: Color(0xFF0F766E)),
                          const SizedBox(width: 4),
                          Text(b.topOfficerName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
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
  Widget _buildTopOfficersSpotlight(List<BranchPerformanceItemModel> branches, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_outlined, size: 18, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text(
                'Branch Lead Field Officers',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Primary credit officer driving active portfolio expansion and collections for each operational branch.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0F2FE),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.person, size: 18, color: Color(0xFF0284C7)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.topOfficerName,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${b.branchName} · ${b.activeMembers} Accounts',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
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

  Widget _buildErrorBanner(String title, String detail, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF991B1B),
              side: const BorderSide(color: Color(0xFFF87171)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
