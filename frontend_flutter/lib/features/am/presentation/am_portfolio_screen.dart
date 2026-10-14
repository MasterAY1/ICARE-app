// lib/features/am/presentation/am_portfolio_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import '../data/datasources/am_api_service.dart';
import '../data/models/am_dashboard_models.dart';

class AmPortfolioScreen extends ConsumerStatefulWidget {
  const AmPortfolioScreen({super.key});

  @override
  ConsumerState<AmPortfolioScreen> createState() => _AmPortfolioScreenState();
}

class _AmPortfolioScreenState extends ConsumerState<AmPortfolioScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  AmDashboardDataModel? _dashboardData;

  @override
  void initState() {
    super.initState();
    _loadPortfolioData();
  }

  Future<void> _loadPortfolioData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ref.read(amApiServiceProvider);
      final data = await apiService.getAmDashboardData();
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final isDesktop = screenWidth >= 900;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Banner
          _buildHeaderBanner(isMobile),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: CircularProgressIndicator(color: Color(0xFF0F766E)),
              ),
            )
          else if (_errorMessage != null)
            _buildErrorState()
          else if (_dashboardData != null) ...[
            // 2. Executive Regional KPI Overview
            _buildRegionalKpis(_dashboardData!.regionalSummary, isMobile, isTablet, isDesktop),
            const SizedBox(height: 20),

            // 3. Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supervised Branch Summaries',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Aggregated branch portfolios, collections, and risk positions.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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

            // 4. Branch Summary Cards Grid
            _buildBranchCardsGrid(_dashboardData!.branchPerformance, isMobile, isTablet, isDesktop),
            const SizedBox(height: 20),

            // 5. Governance Advisory Card
            _buildGovernanceCard(),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(bool isMobile) {
    if (isMobile) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('AREA 1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5)),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Regional Portfolio',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: const Text(
                    'EXECUTIVE',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Consolidated branch summaries across Ogijo, Ikorodu, and Kola branches.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.account_balance_outlined, color: Color(0xFF2563EB), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Regional Portfolio — Area 1',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: const Text(
                        'AREA LEVEL',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Consolidated branch summaries across Ogijo, Ikorodu, and Kola branches. Executive-level portfolio visibility without individual borrower clutter.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionalKpis(RegionalSummaryModel reg, bool isMobile, bool isTablet, bool isDesktop) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Regional Portfolio Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF022C22), Color(0xFF064E3B), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x20064E3B), blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL ACTIVE PORTFOLIO',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF86EFAC),
                        letterSpacing: 0.8,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${reg.openBranchesCount} / ${reg.branchesCount} Branches Active',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.formatNaira(reg.outstandingPortfolio),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Consolidated Regional Credit Principal (Area 1)',
                  style: TextStyle(fontSize: 11, color: Color(0xCCFFFFFF)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2x2 Key Metric Grid
          Row(
            children: [
              Expanded(
                child: _buildModernPortfolioMetricTile(
                  label: 'Total Savings',
                  value: CurrencyFormatter.formatNaira(reg.totalSavings),
                  subtitle: 'Client Reserves',
                  icon: Icons.savings_outlined,
                  iconColor: const Color(0xFF2563EB),
                  iconBg: const Color(0xFFEFF6FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildModernPortfolioMetricTile(
                  label: 'Active Borrowers',
                  value: '${reg.activeClients}',
                  subtitle: 'Active Credit',
                  icon: Icons.people_outline,
                  iconColor: const Color(0xFF7C3AED),
                  iconBg: const Color(0xFFF5F3FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildModernPortfolioMetricTile(
                  label: 'Regional PAR > 30d',
                  value: reg.par,
                  subtitle: 'Portfolio at Risk',
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFDC2626),
                  iconBg: const Color(0xFFFEF2F2),
                  isAlert: reg.par != '0.0%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildModernPortfolioMetricTile(
                  label: 'Open Branches',
                  value: '${reg.openBranchesCount} / ${reg.branchesCount}',
                  subtitle: 'Area 1 Network',
                  icon: Icons.business_outlined,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFFFBEB),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final kpis = [
      _KpiItem('Active Portfolio', CurrencyFormatter.formatNaira(reg.outstandingPortfolio), 'Total Outstanding Principal', Icons.trending_up, const Color(0xFF0F766E), const Color(0xFFF0FDFA)),
      _KpiItem('Total Savings', CurrencyFormatter.formatNaira(reg.totalSavings), 'Client Savings Reserves', Icons.savings_outlined, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
      _KpiItem('Active Borrowers', '${reg.activeClients}', 'Clients with active credit', Icons.people_outline, const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
      _KpiItem('Regional PAR > 30d', reg.par, 'Portfolio At Risk band', Icons.warning_amber_rounded, const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
      _KpiItem('Supervised Branches', '${reg.openBranchesCount} / ${reg.branchesCount}', 'Active branches in Area 1', Icons.business_outlined, const Color(0xFFD97706), const Color(0xFFFFFBEB)),
    ];

    final crossAxisCount = isDesktop ? 5 : (isTablet ? 3 : 2);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kpis.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isDesktop ? 1.6 : 1.7,
      ),
      itemBuilder: (_, index) => _buildKpiCard(kpis[index]),
    );
  }

  Widget _buildModernPortfolioMetricTile({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    bool isAlert = false,
  }) {
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isAlert ? const Color(0xFFEF4444) : const Color(0xFF94A3B8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(_KpiItem kpi) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
              Text(kpi.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: kpi.bgColor, borderRadius: BorderRadius.circular(6)),
                child: Icon(kpi.icon, size: 16, color: kpi.accentColor),
              ),
            ],
          ),
          Text(
            kpi.value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
          ),
          Text(kpi.caption, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

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
        childAspectRatio: isDesktop ? 1.05 : 1.15,
      ),
      itemBuilder: (_, index) => _buildBranchCard(branches[index]),
    );
  }

  Widget _buildBranchCard(BranchPerformanceItemModel b) {
    final isConfirmed = b.eodStatus == 'BRANCH_CONFIRMED' || b.eodStatus == 'AREA_LOCKED';
    final statusColor = isConfirmed
        ? const Color(0xFF16A34A)
        : (b.eodStatus == 'PENDING' ? const Color(0xFFD97706) : const Color(0xFF64748B));
    final statusBg = isConfirmed
        ? const Color(0xFFF0FDF4)
        : (b.eodStatus == 'PENDING' ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Branch Name & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_city, color: Color(0xFF0F172A), size: 18),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  b.eodStatus,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          // 2x2 Metric Matrix
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Active Borrowers',
                  '${b.defaultersCount > 0 ? b.defaultersCount : b.expectedCollection > 0 ? "Active" : "Stable"}',
                  Icons.people_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Vault Cash (Acct 1000)',
                  CurrencyFormatter.formatNaira(b.vaultCashAcct1000),
                  Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Collected Today',
                  CurrencyFormatter.formatNaira(b.collected),
                  Icons.payments_outlined,
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
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'PAR > 30d',
                  b.par,
                  Icons.warning_amber_rounded,
                  color: b.par == '0.0%' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Cash Variance',
                  CurrencyFormatter.formatNaira(b.cashVariance),
                  Icons.balance_outlined,
                  color: b.cashVariance == 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(activeCoPageProvider.notifier).state = 'Dashboard';
                  },
                  icon: const Icon(Icons.dashboard_outlined, size: 14),
                  label: const Text('Dashboard', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.read(activeCoPageProvider.notifier).state = 'Reports & Export';
                  },
                  icon: const Icon(Icons.bar_chart_outlined, size: 14, color: Colors.white),
                  label: const Text('Reports', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF065F46),
                    padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _buildMetricTile(String label, String value, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGovernanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF475569), size: 22),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Governance Note: Individual borrower schedules, collection sheets, and dossier management are performed at the branch level by Credit Officers and Branch Managers. The Area Manager console maintains high-level branch oversight, cashbook inspection, and reconciliation governance.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
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
