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
        _errorMessage = e.toString();
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1000;
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
  }

  Widget _buildPortfolioContent(bool isMobile, bool isTablet, bool isDesktop, bool isBm, String branchName) {
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      key: const ValueKey('am_portfolio_content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2. Portfolio Share Segmented Bar
        _buildPortfolioShareBar(_dashboardData!.branchPerformance, isMobile),
        const SizedBox(height: 18),

        // 3. 6 Regional KPI Summary Cards
        _buildRegionalKpis(_dashboardData!.regionalSummary, isMobile, isTablet, isDesktop),
        const SizedBox(height: 24),

        // 4. Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.18 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isBm ? '$branchName Branch Portfolio' : 'Regional Command Center',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isBm
                                  ? (tokens.isDark ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB))
                                  : tokens.brandPrimaryDark,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isBm ? '${branchName.toUpperCase()} BRANCH' : 'AREA 1',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBm
                            ? 'Branch credit portfolio, capital deployment, and officer productivity'
                            : 'Consolidated branch supervision across Ogijo, Ikorodu, and Kola',
                        style: TextStyle(fontSize: 12, color: tokens.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              if (!isMobile) _buildPeriodSelector(),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p;
          return InkWell(
            onTap: () => _onPeriodChanged(p),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  // 2. Portfolio Share Segmented Bar
  Widget _buildPortfolioShareBar(List<BranchPerformanceItemModel> branches, bool isMobile) {
    if (branches.isEmpty) return const SizedBox.shrink();
    final tokens = IcareSurfaceTokens.of(context);

    // Palette for branches
    final palette = [
      tokens.brandPrimary,
      tokens.infoDot,
      tokens.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
      tokens.warningDot,
    ];

    double totalActiveCredit = branches.fold(0.0, (sum, b) => sum + (b.activeCreditDisbursedAmount > 0 ? b.activeCreditDisbursedAmount : 1.0));
    if (totalActiveCredit <= 0) totalActiveCredit = 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Regional Loan Book Distribution',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
              ),
              Text(
                'Period: $_selectedPeriod',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: branches.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final b = entry.value;
                  final vol = b.activeCreditDisbursedAmount > 0 ? b.activeCreditDisbursedAmount : 1.0;
                  final flex = ((vol / totalActiveCredit) * 1000).toInt().clamp(1, 1000);
                  final color = palette[idx % palette.length];
                  return Expanded(
                    flex: flex,
                    child: Container(color: color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: branches.asMap().entries.map((entry) {
              final idx = entry.key;
              final b = entry.value;
              final vol = b.activeCreditDisbursedAmount;
              final pct = totalActiveCredit > 0 ? (vol / totalActiveCredit * 100).toStringAsFixed(1) : '0.0';
              final color = palette[idx % palette.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    '${b.branchName}: $pct% (${CurrencyFormatter.formatNaira(vol)})',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 3. 6 Regional KPI Summary Cards
  Widget _buildRegionalKpis(RegionalSummaryModel reg, bool isMobile, bool isTablet, bool isDesktop) {
    final tokens = IcareSurfaceTokens.of(context);
    final borrowerPurple = tokens.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
    final kpis = [
      _KpiItem('Active Portfolio', CurrencyFormatter.formatNaira(reg.outstandingPortfolio), 'Total Outstanding Principal', Icons.account_balance_wallet_outlined, tokens.brandPrimary, tokens.brandSoftBg),
      _KpiItem('Total Savings Reserve', CurrencyFormatter.formatNaira(reg.totalSavings), 'Client Savings Reserves', Icons.savings_outlined, tokens.infoDot, tokens.infoBg),
      _KpiItem('Active Borrowers', '${reg.activeClients}', 'Clients with active credit', Icons.people_outline, borrowerPurple, borrowerPurple.withValues(alpha: tokens.isDark ? 0.18 : 0.09)),
      _KpiItem('Regional PAR > 30d', reg.par, 'Delinquency Rate', Icons.warning_amber_rounded, tokens.dangerDot, tokens.dangerBg),
      _KpiItem('Collection Compliance', '${reg.compliancePct.toStringAsFixed(1)}%', 'Period Collection Rate', Icons.verified_outlined, tokens.successDot, tokens.successBg),
      _KpiItem('Vault Cash Reserve', CurrencyFormatter.formatNaira(reg.vaultCashAcct1000), 'Consolidated Physical Cash', Icons.store_mall_directory_outlined, tokens.warningDot, tokens.warningBg),
    ];

    final crossAxisCount = isDesktop ? 6 : (isTablet ? 3 : 2);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kpis.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: isDesktop ? 1.55 : (isTablet ? 1.55 : 1.40),
      ),
      itemBuilder: (_, index) => _buildKpiCard(kpis[index]),
    );
  }

  Widget _buildKpiCard(_KpiItem kpi) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.16 : 0.025), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  kpi.label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: kpi.bgColor, borderRadius: BorderRadius.circular(6)),
                child: Icon(kpi.icon, size: 14, color: kpi.accentColor),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              kpi.value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                letterSpacing: -0.3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            kpi.caption,
            style: TextStyle(fontSize: 10, color: tokens.textLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 4. Branch Summary Cards Grid
  Widget _buildBranchCardsGrid(List<BranchPerformanceItemModel> branches, bool isMobile, bool isTablet, bool isDesktop) {
    final tokens = IcareSurfaceTokens.of(context);
    if (branches.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Center(
          child: Text('No supervised branches found for this Area Manager.', style: TextStyle(color: tokens.textMuted)),
        ),
      );
    }

    if (isMobile) {
      return Column(
        children: branches.map((b) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildBranchCard(b))).toList(),
      );
    }

    final crossAxisCount = isDesktop ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: branches.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isDesktop ? 0.88 : 0.95,
      ),
      itemBuilder: (_, index) => _buildBranchCard(branches[index]),
    );
  }

  // Individual Branch Card
  Widget _buildBranchCard(BranchPerformanceItemModel b) {
    final tokens = IcareSurfaceTokens.of(context);
    final isClosed = b.isClosed;
    final statusColor = isClosed
        ? tokens.dangerText
        : (b.eodStatus == 'BRANCH_CONFIRMED' || b.eodStatus == 'AREA_LOCKED'
            ? tokens.successText
            : tokens.brandPrimary);
    final statusBg = isClosed
        ? tokens.dangerBg
        : (b.eodStatus == 'BRANCH_CONFIRMED' || b.eodStatus == 'AREA_LOCKED'
            ? tokens.successBg
            : tokens.brandSoftBg);
    final statusBorder = isClosed
        ? tokens.dangerBorder
        : (b.eodStatus == 'BRANCH_CONFIRMED' || b.eodStatus == 'AREA_LOCKED'
            ? tokens.successBorder
            : tokens.brandSoftBorder);
    final statusLabel = isClosed ? 'Branch Closed' : (b.eodStatus == 'BRANCH_CONFIRMED' ? 'EOD Confirmed' : 'Active Operations');

    final isNetPositive = b.netLoanCount >= 0;
    final netColor = isNetPositive ? tokens.successText : tokens.warningText;
    final netBg = isNetPositive ? tokens.successBg : tokens.warningBg;
    final netBorder = isNetPositive ? tokens.successBorder : tokens.warningBorder;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Header: Branch Name, BM, Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${b.branchName} Branch',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                      ),
                      Text(
                        'BM: ${b.bmName}',
                        style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusBorder),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
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
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 16, color: tokens.brandPrimary),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Principal Cash Disbursed',
                          style: TextStyle(fontSize: 10.5, color: tokens.textMuted, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          CurrencyFormatter.formatNaira(b.principalDisbursedAmount),
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
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
                  icon: const Icon(Icons.people_outline, size: 15, color: Colors.white),
                  label: const Text('Inspect Officers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: tokens.dangerDot),
            const SizedBox(height: 12),
            Text(
              'Failed to load Regional Portfolio: $_errorMessage',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.dangerText, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPortfolioData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiItem {
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;

  _KpiItem(this.label, this.value, this.caption, this.icon, this.accentColor, this.bgColor);
}
