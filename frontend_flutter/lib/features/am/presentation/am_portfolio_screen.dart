// lib/features/am/presentation/am_portfolio_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import '../data/datasources/am_api_service.dart';
import '../data/models/am_dashboard_models.dart';
import '../../reports/presentation/reports_export_screen.dart';
import 'officer_productivity_sheet.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../../../core/errors/app_error_formatter.dart';
import '../../../core/widgets/icare_card.dart';
import '../../../core/widgets/icare_metric_card.dart';
import '../../../core/widgets/icare_status_badge.dart';
import 'widgets/am_subpage_charts.dart';

class AmPortfolioScreen extends ConsumerStatefulWidget {
  const AmPortfolioScreen({super.key});

  @override
  ConsumerState<AmPortfolioScreen> createState() => _AmPortfolioScreenState();
}

class _AmPortfolioScreenState extends ConsumerState<AmPortfolioScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  AmDashboardDataModel? _dashboardData;
  String _selectedPeriod = 'This Month'; // 'This Month', 'This Week', 'Today'

  @override
  void initState() {
    super.initState();
    _loadPortfolioData();
  }

  (String, String) _getPeriodDates(String period) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    if (period == 'Today') {
      return (todayStr, todayStr);
    } else if (period == 'This Week') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final s = DateFormat('yyyy-MM-dd').format(monday);
      return (s, todayStr);
    } else {
      // This Month (default)
      final firstDay = DateTime(now.year, now.month, 1);
      final s = DateFormat('yyyy-MM-dd').format(firstDay);
      return (s, todayStr);
    }
  }

  Future<void> _loadPortfolioData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final (startDate, endDate) = _getPeriodDates(_selectedPeriod);
      final apiService = ref.read(amApiServiceProvider);
      final data = await apiService.getAmDashboardData(
        startDate: startDate,
        endDate: endDate,
      );
      if (!mounted) return;
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppErrorDetails.from(e).message;
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(String newPeriod) {
    if (_selectedPeriod == newPeriod) return;
    setState(() {
      _selectedPeriod = newPeriod;
    });
    _loadPortfolioData();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(globalRefreshSignalProvider, (prev, next) {
      if (next != prev) {
        _loadPortfolioData();
      }
    });

    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final role = (user?.role ?? '').trim().toLowerCase();
    final isBm = role == 'branch manager' || role == 'bm';
    final branchName = user?.branch.isNotEmpty == true ? user!.branch : 'Branch';

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 680;
        final isTablet = screenWidth >= 680 && screenWidth < 1000;
        final isDesktop = screenWidth >= 1000;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Executive Command Header
            _buildExecutiveHeader(isMobile, isBm, branchName),
            const SizedBox(height: 16),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _isLoading
                  ? IcareAmPortfolioSkeleton(
                      key: const ValueKey('am_portfolio_skeleton'),
                      isMobile: isMobile,
                      isTablet: isTablet,
                      isDesktop: isDesktop,
                    )
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _dashboardData != null
                          ? _buildPortfolioContent(isMobile, isTablet, isDesktop, isBm, branchName)
                          : const SizedBox.shrink(key: ValueKey('am_portfolio_empty')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPortfolioContent(bool isMobile, bool isTablet, bool isDesktop, bool isBm, String branchName) {
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      key: const ValueKey('am_portfolio_content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2. Live Regional Portfolio Analytics (Donut + Branch Comparison BarChart)
        AmPortfolioAllocationChart(
          branches: _dashboardData!.branchPerformance,
          periodLabel: _selectedPeriod,
        ),
        const SizedBox(height: 18),

        // 3. 6 Regional KPI Summary Cards
        _buildRegionalKpis(_dashboardData!.regionalSummary, isMobile, isTablet, isDesktop),
        const SizedBox(height: 24),

        // 4. Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBm ? '$branchName Portfolio Operations' : 'Branch Performance Matrix',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isBm
                        ? 'Capital deployment, active credit progress, and officer productivity for $branchName.'
                        : 'Capital deployment, active credit progress, and officer productivity.',
                    style: TextStyle(fontSize: 12, color: tokens.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh Portfolio',
              onPressed: _loadPortfolioData,
              icon: Icon(Icons.refresh, size: 20, color: tokens.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 5. Branch Summary Cards Grid
        _buildBranchCardsGrid(_dashboardData!.branchPerformance, isMobile, isTablet, isDesktop),
        const SizedBox(height: 24),

        // 6. Governance Advisory Note
        _buildGovernanceCard(isBm),
        const SizedBox(height: 32),
      ],
    );
  }

  // 1. Executive Header with Period Selector
  Widget _buildExecutiveHeader(bool isMobile, bool isBm, String branchName) {
    final tokens = IcareSurfaceTokens.of(context);
    final rawArea = _dashboardData?.regionalSummary.areaName.trim() ?? '';
    final regionBadgeLabel = isBm
        ? '${branchName.toUpperCase()} BRANCH'
        : (rawArea.isNotEmpty ? rawArea.toUpperCase() : 'REGIONAL');

    return IcareCard(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      topAccentColor: tokens.brandPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isBm ? tokens.infoBg : tokens.brandSoftBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isBm ? tokens.infoBorder : tokens.brandSoftBorder),
                      ),
                      child: Icon(
                        Icons.account_balance,
                        color: isBm ? tokens.infoText : tokens.brandPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                isBm ? '$branchName Branch Portfolio' : 'Regional Command Center',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isBm ? tokens.brandPrimary : tokens.brandPrimaryDark,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  regionBadgeLabel,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isBm
                                ? 'Branch credit portfolio, capital deployment, and officer productivity'
                                : 'Consolidated regional branch supervision',
                            style: TextStyle(fontSize: 12, color: tokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 12),
                _buildPeriodSelector(),
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            _buildPeriodSelector(),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final tokens = IcareSurfaceTokens.of(context);
    final periods = ['This Month', 'This Week', 'Today'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Wrap(
        spacing: 2,
        runSpacing: 4,
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p;
          return InkWell(
            onTap: () => _onPeriodChanged(p),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? tokens.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.2 : 0.05), blurRadius: 3, offset: const Offset(0, 1))]
                    : null,
              ),
              child: Text(
                p,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? tokens.brandPrimary : tokens.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 3. 6 Regional KPI Summary Cards
  Widget _buildRegionalKpis(RegionalSummaryModel reg, bool isMobile, bool isTablet, bool isDesktop) {
    final tokens = IcareSurfaceTokens.of(context);
    final kpis = [
      IcareMetricCard(
        label: 'Active Portfolio',
        value: CurrencyFormatter.formatNaira(reg.outstandingPortfolio),
        delta: 'Outstanding Principal',
        icon: Icons.account_balance_wallet_outlined,
        isFullEmerald: true,
      ),
      IcareMetricCard(
        label: 'Total Savings Reserve',
        value: CurrencyFormatter.formatNaira(reg.totalSavings),
        delta: 'Client Savings Reserves',
        icon: Icons.savings_outlined,
        topBorderColor: tokens.infoDot,
      ),
      IcareMetricCard(
        label: 'Active Borrowers',
        value: '${reg.activeClients}',
        delta: 'Active credit clients',
        icon: Icons.people_outline,
        topBorderColor: tokens.brandPrimaryLight,
      ),
      IcareMetricCard(
        label: 'Regional PAR > 30d',
        value: reg.par,
        delta: 'Delinquency Rate',
        isInverseDelta: true,
        icon: Icons.warning_amber_rounded,
        topBorderColor: tokens.dangerDot,
      ),
      IcareMetricCard(
        label: 'Collection Compliance',
        value: '${reg.compliancePct.toStringAsFixed(1)}%',
        delta: 'Period Collection Rate',
        icon: Icons.verified_outlined,
        topBorderColor: tokens.successDot,
      ),
      IcareMetricCard(
        label: 'Vault Cash Reserve',
        value: CurrencyFormatter.formatNaira(reg.vaultCashAcct1000),
        delta: 'Physical Cash Held',
        icon: Icons.store_mall_directory_outlined,
        topBorderColor: tokens.warningDot,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 1100 ? 6 : (w >= 650 ? 3 : 2);
        final rows = <Widget>[];
        for (int i = 0; i < kpis.length; i += cols) {
          final slice = kpis.sublist(i, (i + cols).clamp(0, kpis.length));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int c = 0; c < cols; c++) ...[
                    if (c > 0) const SizedBox(width: 10),
                    Expanded(
                      child: c < slice.length ? slice[c] : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
          if (i + cols < kpis.length) rows.add(const SizedBox(height: 10));
        }
        return Column(children: rows);
      },
    );
  }

  // 4. Branch Summary Cards Grid
  Widget _buildBranchCardsGrid(List<BranchPerformanceItemModel> branches, bool isMobile, bool isTablet, bool isDesktop) {
    final tokens = IcareSurfaceTokens.of(context);
    if (branches.isEmpty) {
      return IcareCard(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text('No supervised branches found for this Area Manager.', style: TextStyle(color: tokens.textMuted)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 1080 ? 3 : (w >= 640 ? 2 : 1);
        if (cols == 1) {
          return Column(
            children: branches
                .map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildBranchCard(b),
                    ))
                .toList(),
          );
        }
        final rows = <Widget>[];
        for (int i = 0; i < branches.length; i += cols) {
          final slice = branches.sublist(i, (i + cols).clamp(0, branches.length));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int c = 0; c < cols; c++) ...[
                    if (c > 0) const SizedBox(width: 14),
                    Expanded(
                      child: c < slice.length ? _buildBranchCard(slice[c]) : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
          if (i + cols < branches.length) rows.add(const SizedBox(height: 14));
        }
        return Column(children: rows);
      },
    );
  }

  // Individual Branch Card
  Widget _buildBranchCard(BranchPerformanceItemModel b) {
    final tokens = IcareSurfaceTokens.of(context);
    final isClosed = b.isClosed;
    final statusVariant = isClosed
        ? IcareBadgeVariant.danger
        : (b.eodStatus == 'BRANCH_CONFIRMED' || b.eodStatus == 'AREA_LOCKED'
            ? IcareBadgeVariant.success
            : IcareBadgeVariant.info);
    final statusLabel = isClosed ? 'Branch Closed' : (b.eodStatus == 'BRANCH_CONFIRMED' ? 'EOD Confirmed' : 'Active Operations');
    final topAccent = isClosed
        ? tokens.dangerDot
        : (b.eodStatus == 'BRANCH_CONFIRMED' || b.eodStatus == 'AREA_LOCKED'
            ? tokens.successDot
            : tokens.brandPrimary);

    final isNetPositive = b.netLoanCount >= 0;
    final netColor = isNetPositive ? tokens.successText : tokens.warningText;
    final netBg = isNetPositive ? tokens.successBg : tokens.warningBg;
    final netBorder = isNetPositive ? tokens.successBorder : tokens.warningBorder;

    return IcareCard(
      padding: const EdgeInsets.all(18),
      topAccentColor: topAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Header: Branch Name, BM, Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: tokens.surfaceHover,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.location_city, color: tokens.textPrimary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b.branchName} Branch',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                          ),
                          Text(
                            'BM: ${b.bmName}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IcareStatusBadge(label: statusLabel, variant: statusVariant),
            ],
          ),
          Divider(height: 18, color: tokens.borderSubtle),

          // 2. Capital Deployed (Principal Cash Disbursed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 16, color: tokens.brandPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Principal Cash Disbursed',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10.5, color: tokens.textMuted, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              CurrencyFormatter.formatNaira(b.principalDisbursedAmount),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: tokens.surfaceHover,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${b.loansDisbursedCount} Loans',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. Active Loan Book Dynamics (Active Credit vs Full Payments)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.successBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.successBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Loans Disbursed',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tokens.successText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatNaira(b.activeCreditDisbursedAmount),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: tokens.successText),
                      ),
                      Text(
                        '${b.loansDisbursedCount} Active Loans',
                        style: TextStyle(fontSize: 9.5, color: tokens.successText.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.infoBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.infoBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Payments (Closed)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tokens.infoText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatNaira(b.fullPaymentsActiveCredit),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: tokens.infoText),
                      ),
                      Text(
                        '${b.fullPaymentsCount} Closed Members',
                        style: TextStyle(fontSize: 9.5, color: tokens.infoText.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4. Net Loan Progress Badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: netBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: netBorder),
            ),
            child: Row(
              children: [
                Icon(isNetPositive ? Icons.trending_up : Icons.trending_down, size: 14, color: netColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Net Progress: ${b.netLoanCount >= 0 ? "+" : ""}${b.netLoanCount} Loans (${b.netActiveCreditVolume >= 0 ? "+" : ""}${CurrencyFormatter.formatNaira(b.netActiveCreditVolume)} Active Credit)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: netColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 5. Collection Progress & Vault Cash
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Vault Cash',
                  CurrencyFormatter.formatNaira(b.vaultCashAcct1000),
                  Icons.store_mall_directory_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Compliance Rate',
                  '${b.compliancePct.toStringAsFixed(1)}%',
                  Icons.verified_outlined,
                  color: b.compliancePct >= 80 ? tokens.successText : tokens.warningText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'PAR > 30d',
                  b.par,
                  Icons.warning_amber_rounded,
                  color: b.par == '0.0%' ? tokens.successText : tokens.dangerText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 6. Action Row: "Inspect Officers" and "Branch Reports"
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () => _showOfficerProductivitySheet(b),
                  icon: const Icon(Icons.people_outline, size: 15),
                  label: const Text('Inspect Officers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(reportsTargetBranchProvider.notifier).state = b.branchName;
                    ref.read(activeCoPageProvider.notifier).state = 'Reports & Export';
                  },
                  icon: Icon(Icons.bar_chart_outlined, size: 14, color: tokens.textSecondary),
                  label: Text('Reports', style: TextStyle(fontSize: 11.5, color: tokens.textSecondary, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: tokens.borderStrong),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Officer Productivity Drill-Down Modal Sheet
  void _showOfficerProductivitySheet(BranchPerformanceItemModel branch) {
    showOfficerProductivitySheet(
      context: context,
      branchId: branch.branchId,
      branchName: branch.branchName,
      period: _selectedPeriod,
      dates: _getPeriodDates(_selectedPeriod),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, {Color? color}) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: tokens.textLight),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, color: tokens.textMuted, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color ?? tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGovernanceCard(bool isBm) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isBm ? Icons.shield_outlined : Icons.info_outline,
            color: isBm ? tokens.infoText : tokens.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBm ? 'Branch Portfolio Operational Invariant' : 'Regional Portfolio Governance Invariant',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  isBm
                      ? 'Individual borrower schedules, collection sheets, and dossier management are performed at the branch level by Credit Officers and the Branch Manager. The Branch Manager oversees officer loan book growth, portfolio quality, and daily collections.'
                      : 'Individual borrower schedules, collection sheets, and dossier management are performed at the branch level by Credit Officers and Branch Managers. The Area Manager command center maintains executive supervision, capital deployment oversight, and net portfolio growth tracking.',
                  style: TextStyle(fontSize: 11.5, color: tokens.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final tokens = IcareSurfaceTokens.of(context);
    return Center(
      key: const ValueKey('am_portfolio_error'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: IcareCard(
            padding: const EdgeInsets.all(24),
            topAccentColor: tokens.dangerDot,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 44, color: tokens.dangerDot),
                const SizedBox(height: 12),
                Text(
                  'Failed to load Regional Portfolio',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tokens.dangerText, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  _errorMessage ?? 'Please tap Retry to reload.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadPortfolioData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
