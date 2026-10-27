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
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isBm
                      ? 'Capital deployment, active credit progress, and officer productivity for $branchName.'
                      : 'Capital deployment, active credit progress, and officer productivity.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Refresh Portfolio',
              onPressed: _loadPortfolioData,
              icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF64748B)),
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 2)),
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
                      color: isBm ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isBm ? const Color(0xFFDBEAFE) : const Color(0xFFCCFBF1)),
                    ),
                    child: Icon(
                      Icons.account_balance,
                      color: isBm ? const Color(0xFF2563EB) : const Color(0xFF0F766E),
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
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isBm ? const Color(0xFF2563EB) : const Color(0xFF0F766E),
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
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
    final periods = ['This Month', 'This Week', 'Today'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 3, offset: Offset(0, 1))]
                    : null,
              ),
              child: Text(
                p,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
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

    // Palette for branches
    final palette = [
      const Color(0xFF0F766E), // Emerald/Teal for Branch 1
      const Color(0xFF2563EB), // Royal Blue for Branch 2
      const Color(0xFF7C3AED), // Purple for Branch 3
      const Color(0xFFD97706), // Amber for Branch 4
    ];

    double totalActiveCredit = branches.fold(0.0, (sum, b) => sum + (b.activeCreditDisbursedAmount > 0 ? b.activeCreditDisbursedAmount : 1.0));
    if (totalActiveCredit <= 0) totalActiveCredit = 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Regional Loan Book Distribution',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              Text(
                'Period: $_selectedPeriod',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
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
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
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
    final kpis = [
      _KpiItem('Active Portfolio', CurrencyFormatter.formatNaira(reg.outstandingPortfolio), 'Total Outstanding Principal', Icons.account_balance_wallet_outlined, const Color(0xFF0F766E), const Color(0xFFF0FDFA)),
      _KpiItem('Total Savings Reserve', CurrencyFormatter.formatNaira(reg.totalSavings), 'Client Savings Reserves', Icons.savings_outlined, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
      _KpiItem('Active Borrowers', '${reg.activeClients}', 'Clients with active credit', Icons.people_outline, const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
      _KpiItem('Regional PAR > 30d', reg.par, 'Delinquency Rate', Icons.warning_amber_rounded, const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
      _KpiItem('Collection Compliance', '${reg.compliancePct.toStringAsFixed(1)}%', 'Period Collection Rate', Icons.verified_outlined, const Color(0xFF059669), const Color(0xFFECFDF5)),
      _KpiItem('Vault Cash Reserve', CurrencyFormatter.formatNaira(reg.vaultCashAcct1000), 'Consolidated Physical Cash', Icons.store_mall_directory_outlined, const Color(0xFFD97706), const Color(0xFFFFFBEB)),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 3, offset: Offset(0, 1))],
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
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            kpi.caption,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 4. Branch Summary Cards Grid
  Widget _buildBranchCardsGrid(List<BranchPerformanceItemModel> branches, bool isMobile, bool isTablet, bool isDesktop) {
    if (branches.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('No supervised branches found for this Area Manager.', style: TextStyle(color: Color(0xFF64748B))),
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
    final isClosed = b.isClosed;
    final statusColor = isClosed
        ? const Color(0xFFDC2626)
        : (b.eodStatus == 'BRANCH_CONFIRMED' || b.eodStatus == 'AREA_LOCKED'
            ? const Color(0xFF16A34A)
            : const Color(0xFF0F766E));
    final statusBg = isClosed
        ? const Color(0xFFFEF2F2)
        : (b.eodStatus == 'BRANCH_CONFIRMED' || b.eodStatus == 'AREA_LOCKED'
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFF0FDFA));
    final statusLabel = isClosed ? 'Branch Closed' : (b.eodStatus == 'BRANCH_CONFIRMED' ? 'EOD Confirmed' : 'Active Operations');

    final isNetPositive = b.netLoanCount >= 0;
    final netColor = isNetPositive ? const Color(0xFF059669) : const Color(0xFFD97706);
    final netBg = isNetPositive ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);
    final netBorder = isNetPositive ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
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
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_city, color: Color(0xFF0F172A), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${b.branchName} Branch',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'BM: ${b.bmName}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),

          // 2. Capital Deployed (Principal Cash Disbursed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF0F766E)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Principal Cash Disbursed',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                        Text(
                          CurrencyFormatter.formatNaira(b.principalDisbursedAmount),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${b.loansDisbursedCount} Loans',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
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
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Loans Disbursed',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatNaira(b.activeCreditDisbursedAmount),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF14532D)),
                      ),
                      Text(
                        '${b.loansDisbursedCount} Active Loans',
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF15803D)),
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
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Full Payments (Closed)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatNaira(b.fullPaymentsActiveCredit),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                      ),
                      Text(
                        '${b.fullPaymentsCount} Closed Members',
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF2563EB)),
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
                  color: b.compliancePct >= 80 ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'PAR > 30d',
                  b.par,
                  Icons.warning_amber_rounded,
                  color: b.par == '0.0%' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
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
                    backgroundColor: const Color(0xFF0F766E),
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
                  icon: const Icon(Icons.bar_chart_outlined, size: 14, color: Color(0xFF475569)),
                  label: const Text('Reports', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), overflow: TextOverflow.ellipsis),
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
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGovernanceCard(bool isBm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isBm ? Icons.shield_outlined : Icons.info_outline,
            color: isBm ? const Color(0xFF2563EB) : const Color(0xFF475569),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBm ? 'Branch Portfolio Operational Invariant' : 'Regional Portfolio Governance Invariant',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 3),
                Text(
                  isBm
                      ? 'Individual borrower schedules, collection sheets, and dossier management are performed at the branch level by Credit Officers and the Branch Manager. The Branch Manager oversees officer loan book growth, portfolio quality, and daily collections.'
                      : 'Individual borrower schedules, collection sheets, and dossier management are performed at the branch level by Credit Officers and Branch Managers. The Area Manager command center maintains executive supervision, capital deployment oversight, and net portfolio growth tracking.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      key: const ValueKey('am_portfolio_error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text(
              'Failed to load Regional Portfolio: $_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 14),
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
