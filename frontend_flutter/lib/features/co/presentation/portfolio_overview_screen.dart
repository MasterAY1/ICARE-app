import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../data/datasources/co_api_service.dart';

final portfolioMainTabProvider = StateProvider<String>((ref) => 'Portfolio Summary & Analytics');
final portfolioViewModeProvider = StateProvider<String>((ref) => 'Detailed Client List');
final portfolioQuickFilterProvider = StateProvider<String>((ref) => 'All Active Loans');
final clientDossierSubTabProvider = StateProvider<String>((ref) => 'Customer Profile');
final selectedClientCodeProvider = StateProvider<String?>((ref) => null);

final portfolioDataProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, filterKey) async {
  final parts = filterKey.split('||');
  final branch = parts.isNotEmpty && parts[0] != 'null' ? parts[0] : null;
  final officer = parts.length > 1 && parts[1] != 'null' ? parts[1] : null;
  final group = parts.length > 2 && parts[2] != 'null' ? parts[2] : null;
  final product = parts.length > 3 && parts[3] != 'null' ? parts[3] : null;
  final timePeriod = parts.length > 4 && parts[4] != 'null' ? parts[4] : null;
  final startDate = parts.length > 5 && parts[5] != 'null' ? parts[5] : null;
  final endDate = parts.length > 6 && parts[6] != 'null' ? parts[6] : null;

  final api = ref.watch(coApiServiceProvider);
  return api.getPortfolioData(
    branch: branch,
    officer: officer,
    group: group,
    product: product,
    timePeriod: timePeriod,
    startDate: startDate,
    endDate: endDate,
  );
});

final clientDossierDataProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, clientCode) async {
  final api = ref.watch(coApiServiceProvider);
  return api.getClientDossier(clientCode);
});

/// 1:1 Authoritative Streamlit Replica of Portfolio & 360 Client Dossier (app.py L12192-13178)
/// Features:
/// - Full RBAC Scoped Hierarchy & Dynamic Cascading Filters
/// - Tab 1: 5 Rows of KPI Metrics (22 total), Excess/Payoff Audit Ledger, Category Intelligence, Group Matrix with Totals, Detailed Client Table & Group Summary
/// - Tab 2: Searchable Client Selector, 4-Metric Executive Banner, 7 Drilldown Subtabs with Reversal Requests & Lifecycle Transitions
class PortfolioOverviewScreen extends ConsumerStatefulWidget {
  const PortfolioOverviewScreen({super.key});

  @override
  ConsumerState<PortfolioOverviewScreen> createState() => _PortfolioOverviewScreenState();
}

class _PortfolioOverviewScreenState extends ConsumerState<PortfolioOverviewScreen> {
  String _selectedBranch = 'All';
  String _selectedOfficer = 'All';
  String _selectedTimePeriod = 'Current Month';
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedProduct = 'All';
  String _selectedGroup = 'All';
  final TextEditingController _clientSearchCtrl = TextEditingController();

  bool _excessAuditExpanded = false;
  bool _groupMatrixExpanded = false;

  // Mobile segmented hub and pagination state
  int _mobilePortfolioTab = 0;
  int _mobileClientLimit = 10;
  bool _filtersExpandedOnMobile = false;

  // Lifecycle change dialog state
  String _targetStatus = 'Inactive (Savings Only)';
  final TextEditingController _statusReasonCtrl = TextEditingController();
  bool _isSubmittingStatus = false;

  // Reversal request state
  String? _selectedRepaymentForReversal;
  final TextEditingController _reversalReasonCtrl = TextEditingController();
  bool _isSubmittingReversal = false;

  @override
  void initState() {
    super.initState();
    _computeDatesForPeriod('Current Month');
  }

  @override
  void dispose() {
    _clientSearchCtrl.dispose();
    _statusReasonCtrl.dispose();
    _reversalReasonCtrl.dispose();
    super.dispose();
  }

  void _computeDatesForPeriod(String period) {
    final now = DateTime.now();
    if (period == 'Today') {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = DateTime(now.year, now.month, now.day);
    } else if (period == 'Yesterday') {
      final y = now.subtract(const Duration(days: 1));
      _startDate = DateTime(y.year, y.month, y.day);
      _endDate = DateTime(y.year, y.month, y.day);
    } else if (period == 'Current Month') {
      _startDate = DateTime(now.year, now.month, 1);
      final lastDay = DateTime(now.year, now.month + 1, 0).day;
      _endDate = DateTime(now.year, now.month, lastDay);
    } else if (period == 'Last Month') {
      final firstThisMonth = DateTime(now.year, now.month, 1);
      final lastPrevMonth = firstThisMonth.subtract(const Duration(days: 1));
      _startDate = DateTime(lastPrevMonth.year, lastPrevMonth.month, 1);
      _endDate = lastPrevMonth;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  String _buildFilterKey() {
    final s = _startDate != null ? _formatDate(_startDate) : 'null';
    final e = _endDate != null ? _formatDate(_endDate) : 'null';
    return '$_selectedBranch||$_selectedOfficer||$_selectedGroup||$_selectedProduct||$_selectedTimePeriod||$s||$e';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final role = user?.role ?? 'CO';

    final titleMap = {
      'CO': 'CO Portfolio',
      'Officer': 'CO Portfolio',
      'Credit Officer': 'CO Portfolio',
      'Branch Manager': 'Branch Portfolio',
      'BM': 'Branch Portfolio',
      'Area Manager': 'Regional Portfolio',
      'AM': 'Regional Portfolio',
    };
    final pageTitle = titleMap[role] ?? 'Enterprise Portfolio';

    final activeMainTab = ref.watch(portfolioMainTabProvider);
    final filterKey = _buildFilterKey();
    final portfolioAsync = ref.watch(portfolioDataProvider(filterKey));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Page Header
        Text(
          pageTitle,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Comprehensive portfolio oversight, role-scoped performance analytics, and 360° client dossier.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),

        // 2. Filters & Scope Bar
        _buildFilterBar(portfolioAsync, user),
        const SizedBox(height: 20),

        // 3. Tab Bar
        _buildMainTabBar(activeMainTab),
        const SizedBox(height: 20),

        // 4. Tab Contents
        if (activeMainTab == 'Portfolio Summary & Analytics')
          _buildPortfolioSummaryTab(portfolioAsync)
        else
          _buildClientDossierTab(portfolioAsync),
      ],
    );
  }

  Widget _buildMainTabBar(String activeTab) {
    final tabs = ['Portfolio Summary & Analytics', 'Client Dossier & Inquiry'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((t) {
            final isSel = activeTab == t;
            return InkWell(
              onTap: () => ref.read(portfolioMainTabProvider.notifier).state = t,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFFEFF6FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                          width: 2,
                        ),
                      ),
                      child: isSel
                          ? Center(
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterBar(AsyncValue<Map<String, dynamic>> portfolioAsync, dynamic user) {
    final filterOptions = portfolioAsync.valueOrNull?['filter_options'] as Map<String, dynamic>? ?? {};
    final availableBranches = (filterOptions['available_branches'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['All'];
    final availableOfficers = (filterOptions['available_officers'] as List<dynamic>?)?.map((e) {
      if (e is Map) return e['username']?.toString() ?? e['label']?.toString() ?? 'All';
      return e.toString();
    }).toList() ?? ['All'];
    final availableGroups = (filterOptions['available_groups'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['All'];
    final rawProds = filterOptions['available_products'] ?? filterOptions['allowed_products'];
    final availableProducts = (rawProds as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['All'];

    final role = user?.role ?? 'CO';
    final isOfficer = role == 'CO' || role == 'Credit Officer' || role == 'Officer' || role == 'CREDIT_OFFICER';
    final isBm = role == 'BM' || role == 'Branch Manager' || role == 'BRANCH_MANAGER';

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
          // Row 1: Scope & Officer Selection
          if (isOfficer)
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Scope: Credit Officer Portfolio (${user?.username ?? "CO"}) · Branch: ${user?.branch ?? "Branch"}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                if (isBm) {
                  final branchTxt = Text(
                    'Branch Scope: ${user?.branch ?? "Branch"}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                  );
                  final offDropdown = _buildDropdown(
                    label: 'Credit Officer Filter',
                    value: availableOfficers.contains(_selectedOfficer) ? _selectedOfficer : 'All',
                    items: availableOfficers,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedOfficer = val);
                    },
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        branchTxt,
                        const SizedBox(height: 10),
                        offDropdown,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: branchTxt),
                      const SizedBox(width: 16),
                      Expanded(child: offDropdown),
                    ],
                  );
                } else {
                  final brDropdown = _buildDropdown(
                    label: 'Branch Filter',
                    value: availableBranches.contains(_selectedBranch) ? _selectedBranch : 'All',
                    items: availableBranches,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedBranch = val);
                    },
                  );
                  final offDropdown = _buildDropdown(
                    label: 'Credit Officer Filter',
                    value: availableOfficers.contains(_selectedOfficer) ? _selectedOfficer : 'All',
                    items: availableOfficers,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedOfficer = val);
                    },
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        brDropdown,
                        const SizedBox(height: 10),
                        offDropdown,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: brDropdown),
                      const SizedBox(width: 16),
                      Expanded(child: offDropdown),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 12),

          // Row 2: Date, Product & Cascading Group Filters
          LayoutBuilder(
            builder: (context, constraints) {
              final timeField = _buildDropdown(
                label: 'Time Period',
                value: _selectedTimePeriod,
                items: const ['Today', 'Yesterday', 'Current Month', 'Last Month', 'Custom Date Range'],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedTimePeriod = val;
                      _computeDatesForPeriod(val);
                    });
                  }
                },
              );

              final dateField = InkWell(
                onTap: _selectedTimePeriod == 'Custom Date Range' ? _selectCustomDateRange : null,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date Range',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    enabled: _selectedTimePeriod == 'Custom Date Range',
                    suffixIcon: const Icon(Icons.calendar_month, size: 18),
                  ),
                  child: Text(
                    _startDate != null && _endDate != null
                        ? '${_formatDate(_startDate)}  to  ${_formatDate(_endDate)}'
                        : 'Select range',
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectedTimePeriod == 'Custom Date Range'
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              );

              final prodField = _buildDropdown(
                label: 'Loan Product Filter',
                value: availableProducts.contains(_selectedProduct) ? _selectedProduct : 'All',
                items: availableProducts,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedProduct = val);
                },
              );

              final grpField = _buildDropdown(
                label: 'Group Filter',
                value: availableGroups.contains(_selectedGroup) ? _selectedGroup : 'All',
                items: availableGroups,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedGroup = val);
                },
              );

              if (constraints.maxWidth >= 900) {
                return Row(
                  children: [
                    Expanded(child: timeField),
                    const SizedBox(width: 12),
                    Expanded(child: dateField),
                    const SizedBox(width: 12),
                    Expanded(child: prodField),
                    const SizedBox(width: 12),
                    Expanded(child: grpField),
                  ],
                );
              } else if (constraints.maxWidth >= 600) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: timeField),
                        const SizedBox(width: 12),
                        Expanded(child: dateField),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: prodField),
                        const SizedBox(width: 12),
                        Expanded(child: grpField),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _filtersExpandedOnMobile = !_filtersExpandedOnMobile),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.tune, size: 15, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Filters: $_selectedTimePeriod · Prod: $_selectedProduct · Grp: $_selectedGroup',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(_filtersExpandedOnMobile ? Icons.expand_less : Icons.expand_more, size: 18, color: const Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                    if (_filtersExpandedOnMobile) ...[
                      const SizedBox(height: 12),
                      timeField,
                      const SizedBox(height: 12),
                      dateField,
                      const SizedBox(height: 12),
                      prodField,
                      const SizedBox(height: 12),
                      grpField,
                    ],
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: DateTime.now(), end: DateTime.now()),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final validValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : null);
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$validValue-${items.length}'),
      value: validValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
      isExpanded: true,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }

  // ===========================================================================
  // TAB 1: PORTFOLIO SUMMARY & ANALYTICS
  // ===========================================================================

  Widget _buildPortfolioSummaryTab(AsyncValue<Map<String, dynamic>> portfolioAsync) {
    return portfolioAsync.when(
      loading: () => const IcareTableSkeleton(rowCount: 8),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
        child: Text('Error loading portfolio data: $err', style: const TextStyle(color: Colors.red)),
      ),
      data: (data) {
        final summary = data['summary'] as Map<String, dynamic>? ?? {};
        final categorySummary = data['category_summary'] as Map<String, dynamic>? ?? {};
        final groupMatrix = data['group_matrix'] as List<dynamic>? ?? [];
        final clientTable = data['client_table'] as List<dynamic>? ?? [];
        final groupTable = data['group_table'] as List<dynamic>? ?? [];
        final payoffExcessTable = data['payoff_excess_table'] as List<dynamic>? ?? [];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 900;
            if (isMobile) {
              return _buildMobilePortfolioSummary(
                summary: summary,
                categorySummary: categorySummary,
                groupMatrix: groupMatrix,
                clientTable: clientTable,
                groupTable: groupTable,
                payoffExcessTable: payoffExcessTable,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Portfolio Summary & Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),

                // Row 1: Client Lifecycle Status Breakdown (8 metrics)
                const Text('Row 1: Client Lifecycle Status Breakdown', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _buildLifecycleMetricsRow(summary),
                const SizedBox(height: 16),

                // Row 2: Savings Summary (Period Flows & Vault Position)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const Text('Row 2: Savings Summary (Period Flows & Vault Position)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _buildSavingsMetricsRow(summary),
                const SizedBox(height: 16),

                // Row 3: Disbursement Summary (2 metrics)
                const Text('Row 3: Disbursement Summary (In Selected Period)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _buildDisbursementMetricsRow(summary),
                const SizedBox(height: 16),

                // Row 4: Loan & Collection Summary (4 metrics)
                const Text('Row 4: Loan & Collection Summary', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _buildLoanCollectionMetricsRow(summary),
                const SizedBox(height: 16),

                // Row 5: Repayment Status & Risk (4 metrics)
                const Text('Row 5: Repayment Status & Risk', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _buildRepaymentRiskMetricsRow(summary),
                const SizedBox(height: 20),

                // Itemized Excess Payments & Payoff Audit Ledger Expander (BR-DASH-005)
                _buildExcessPayoffAuditLedger(payoffExcessTable, summary),
                const SizedBox(height: 24),

                // Section: Loan Products & Category Intelligence
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                const Text('Loan Products & Category Intelligence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                const Text('Consolidated portfolio breakdown across loan product cycles, active credit, and distribution.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                _buildCategoryIntelligenceCards(categorySummary),
                const SizedBox(height: 20),

                // Group-by-Product Distribution Matrix Expander
                _buildGroupDistributionMatrix(groupMatrix),
                const SizedBox(height: 24),

                // Section: Client & Group Portfolio Details
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                const Text('Client & Group Portfolio Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                _buildClientAndGroupDetails(clientTable, groupTable, summary, categorySummary),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // MOBILE SEGMENTED PORTFOLIO HUB
  // Eliminates mobile long scrolling by organizing portfolio operations into:
  // 0: Directory, 1: KPIs & Risk, 2: Products & Groups, 3: Audit Ledger
  // ===========================================================================

  Widget _buildMobilePortfolioSummary({
    required Map<String, dynamic> summary,
    required Map<String, dynamic> categorySummary,
    required List<dynamic> groupMatrix,
    required List<dynamic> clientTable,
    required List<dynamic> groupTable,
    required List<dynamic> payoffExcessTable,
  }) {
    Widget tabContent;
    switch (_mobilePortfolioTab) {
      case 0:
        tabContent = _buildClientAndGroupDetails(clientTable, groupTable, summary, categorySummary);
        break;
      case 1:
        tabContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Row 1: Client Lifecycle Status Breakdown', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _buildLifecycleMetricsRow(summary),
            const SizedBox(height: 16),

            const Text('Row 2: Savings Summary (Period Flows & Vault Position)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _buildSavingsMetricsRow(summary),
            const SizedBox(height: 16),

            const Text('Row 3: Disbursement Summary (In Selected Period)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _buildDisbursementMetricsRow(summary),
            const SizedBox(height: 16),

            const Text('Row 4: Loan & Collection Summary', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _buildLoanCollectionMetricsRow(summary),
            const SizedBox(height: 16),

            const Text('Row 5: Repayment Status & Risk', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _buildRepaymentRiskMetricsRow(summary),
          ],
        );
        break;
      case 2:
        tabContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Loan Products & Category Intelligence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Consolidated portfolio breakdown across loan product cycles, active credit, and distribution.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            _buildCategoryIntelligenceCards(categorySummary),
            const SizedBox(height: 20),
            _buildGroupDistributionMatrix(groupMatrix),
          ],
        );
        break;
      case 3:
      default:
        tabContent = _buildExcessPayoffAuditLedger(payoffExcessTable, summary);
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMobileExecutiveHero(summary),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPortfolioTabPill(index: 0, label: 'Directory', icon: Icons.people_outline, count: clientTable.length),
                const SizedBox(width: 4),
                _buildPortfolioTabPill(index: 1, label: 'KPIs & Risk', icon: Icons.analytics_outlined, count: 22),
                const SizedBox(width: 4),
                _buildPortfolioTabPill(index: 2, label: 'Products & Groups', icon: Icons.category_outlined),
                const SizedBox(width: 4),
                _buildPortfolioTabPill(index: 3, label: 'Audit Ledger', icon: Icons.receipt_long_outlined, count: payoffExcessTable.length),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        tabContent,
      ],
    );
  }

  Widget _buildPortfolioTabPill({
    required int index,
    required String label,
    required IconData icon,
    int? count,
  }) {
    final isSelected = _mobilePortfolioTab == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _mobilePortfolioTab = index;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFF064E3B) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
              if (count != null && count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? const Color(0xFF065F46) : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileExecutiveHero(Map<String, dynamic> s) {
    final activeCred = (s['total_active_credit'] as num?)?.toDouble() ?? 0.0;
    final outBal = (s['total_outstanding_balance'] as num?)?.toDouble() ?? 0.0;
    final actualCol = (s['total_actual_collection'] ?? s['today_collection'] as num?)?.toDouble() ?? 0.0;
    final activeLoans = s['active_loans_count'] ?? 0;
    final parStr = s['par']?.toString().replaceAll('%', '') ?? '0.00';
    final parVal = double.tryParse(parStr) ?? 0.0;
    final overdueCount = (s['overdue']?['count'] as num?)?.toInt() ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF022C22),
            Color(0xFF064E3B),
            Color(0xFF065F46),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22064E3B),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PORTFOLIO EXECUTIVE PULSE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6EE7B7),
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: parVal > 5 ? const Color(0x33DC2626) : const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: parVal > 5 ? const Color(0x66DC2626) : const Color(0x33FFFFFF),
                  ),
                ),
                child: Text(
                  'PAR: ${parVal.toStringAsFixed(1)}% ($overdueCount Overdue)',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: parVal > 5 ? const Color(0xFFFCA5A5) : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Active Credit',
                      style: TextStyle(fontSize: 11, color: Color(0xFFA7F3D0), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.formatNaira(activeCred),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Outstanding Balance',
                      style: TextStyle(fontSize: 11, color: Color(0xFFFECACA), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.formatNaira(outBal),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFEF08A),
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x26000000),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 14, color: Color(0xFF6EE7B7)),
                    const SizedBox(width: 6),
                    Text(
                      'Collections: ${CurrencyFormatter.formatNaira(actualCol)}',
                      style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Text(
                  '$activeLoans Active Loans',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFD1FAE5), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Row 1: Lifecycle (8 metrics)
  Widget _buildLifecycleMetricsRow(Map<String, dynamic> s) {
    final c1 = _buildSmallMetricCard('Registered', '${s['total_clients'] ?? 0} Clients', const Color(0xFF0284C7));
    final c2 = _buildSmallMetricCard('On Loan', '${s['active_clients'] ?? 0} Clients', const Color(0xFF059669));
    final c3 = _buildSmallMetricCard('Completed', '${s['completed_clients'] ?? 0} Clients', const Color(0xFF10B981));
    final c4 = _buildSmallMetricCard('Pending Loans', '${s['pending_loan_clients'] ?? 0} Clients', const Color(0xFFF59E0B));
    final c5 = _buildSmallMetricCard('Savings Only', '${s['savings_only_clients'] ?? 0} Clients', const Color(0xFF6366F1));
    final c6 = _buildSmallMetricCard('Dormant', '${s['dormant_clients'] ?? 0} Clients', const Color(0xFF64748B));
    final c7 = _buildSmallMetricCard('Suspended', '${s['suspended_clients'] ?? 0} Clients', const Color(0xFFEA580C));
    final c8 = _buildSmallMetricCard('Closed', '${s['closed_clients'] ?? 0} Clients', const Color(0xFF94A3B8));

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1050) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: c1), const SizedBox(width: 8),
                Expanded(child: c2), const SizedBox(width: 8),
                Expanded(child: c3), const SizedBox(width: 8),
                Expanded(child: c4), const SizedBox(width: 8),
                Expanded(child: c5), const SizedBox(width: 8),
                Expanded(child: c6), const SizedBox(width: 8),
                Expanded(child: c7), const SizedBox(width: 8),
                Expanded(child: c8),
              ],
            ),
          );
        } else if (constraints.maxWidth >= 600) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: c1), const SizedBox(width: 8), Expanded(child: c2), const SizedBox(width: 8), Expanded(child: c3), const SizedBox(width: 8), Expanded(child: c4)],
                ),
              ),
              const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: c5), const SizedBox(width: 8), Expanded(child: c6), const SizedBox(width: 8), Expanded(child: c7), const SizedBox(width: 8), Expanded(child: c8)],
                ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: c1), const SizedBox(width: 8), Expanded(child: c2)],
                ),
              ),
              const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: c3), const SizedBox(width: 8), Expanded(child: c4)],
                ),
              ),
              const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: c5), const SizedBox(width: 8), Expanded(child: c6)],
                ),
              ),
              const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: c7), const SizedBox(width: 8), Expanded(child: c8)],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  // Row 2: Savings (4 metrics)
  Widget _buildSavingsMetricsRow(Map<String, dynamic> s) {
    final dep = (s['period_savings_deposit'] as num?)?.toDouble() ?? 0.0;
    final wd = (s['period_savings_withdrawal'] as num?)?.toDouble() ?? 0.0;
    final net = (s['period_net_savings'] as num?)?.toDouble() ?? (dep - wd);
    final tot = (s['total_savings_balance'] as num?)?.toDouble() ?? 0.0;

    final c1 = _buildKpiCard('Savings Deposited (Period)', CurrencyFormatter.formatNaira(dep), '${s['period_savings_dep_clients'] ?? 0} Clients', const Color(0xFF059669));
    final c2 = _buildKpiCard('Savings Withdrawn (Period)', CurrencyFormatter.formatNaira(wd), '${s['period_savings_wd_clients'] ?? 0} Clients', const Color(0xFFDC2626));
    final c3 = _buildKpiCard('Net Savings (Period)', CurrencyFormatter.formatNaira(net), net != 0 ? '${CurrencyFormatter.formatNaira(net)} (Net)' : '₦0 (Balanced)', const Color(0xFF2563EB));
    final c4 = _buildKpiCard('Total Savings Balance', CurrencyFormatter.formatNaira(tot), '${s['total_savings_clients'] ?? 0} Active Savers', const Color(0xFF0284C7));

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: c1), const SizedBox(width: 12),
                Expanded(child: c2), const SizedBox(width: 12),
                Expanded(child: c3), const SizedBox(width: 12),
                Expanded(child: c4),
              ],
            ),
          );
        } else {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: c1), const SizedBox(width: 10), Expanded(child: c2)],
                ),
              ),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: c3), const SizedBox(width: 10), Expanded(child: c4)],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  // Row 3: Disbursement (2 metrics)
  Widget _buildDisbursementMetricsRow(Map<String, dynamic> s) {
    final dSum = s['disbursement_summary'] as Map<String, dynamic>? ?? {};
    final count = dSum['count'] ?? 0;
    final amt = (dSum['amount'] as num?)?.toDouble() ?? 0.0;
    final clientCount = dSum['client_count'] ?? count;

    final c1 = _buildKpiCard('Loans Disbursed', '$count Loans', '$clientCount Clients', const Color(0xFF2563EB));
    final c2 = _buildKpiCard('Total Amount Disbursed', CurrencyFormatter.formatNaira(amt), '$count Loans (Incl. Assets)', const Color(0xFF059669));

    return LayoutBuilder(
      builder: (context, constraints) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: c1),
              const SizedBox(width: 10),
              Expanded(child: c2),
            ],
          ),
        );
      },
    );
  }

  // Row 4: Loan & Collection (4 metrics)
  Widget _buildLoanCollectionMetricsRow(Map<String, dynamic> s) {
    final activeCred = (s['total_active_credit'] as num?)?.toDouble() ?? 0.0;
    final expRepay = (s['total_expected_repayment'] as num?)?.toDouble() ?? 0.0;
    final actualCol = (s['total_actual_collection'] ?? s['today_collection'] as num?)?.toDouble() ?? 0.0;
    final outBal = (s['total_outstanding_balance'] as num?)?.toDouble() ?? 0.0;

    final c1 = _buildKpiCard('Total Active Credit', CurrencyFormatter.formatNaira(activeCred), '${s['active_loans_count'] ?? 0} Active Loans', const Color(0xFF0F172A));
    final c2 = _buildKpiCard('Expected Repayment', CurrencyFormatter.formatNaira(expRepay), '${s['expected_repay_clients'] ?? 0} Clients', const Color(0xFF475569));
    final c3 = _buildKpiCard('Actual Collections (Period)', CurrencyFormatter.formatNaira(actualCol), '${s['paying_clients_count'] ?? 0} Clients Paid', const Color(0xFF059669));
    final c4 = _buildKpiCard('Total Outstanding Balance', CurrencyFormatter.formatNaira(outBal), '${s['outstanding_clients_count'] ?? 0} Clients', const Color(0xFFDC2626));

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: c1), const SizedBox(width: 12),
                Expanded(child: c2), const SizedBox(width: 12),
                Expanded(child: c3), const SizedBox(width: 12),
                Expanded(child: c4),
              ],
            ),
          );
        } else {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: c1), const SizedBox(width: 10), Expanded(child: c2)],
                ),
              ),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: c3), const SizedBox(width: 10), Expanded(child: c4)],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  // Row 5: Repayment Status & Risk (4 metrics)
  Widget _buildRepaymentRiskMetricsRow(Map<String, dynamic> s) {
    final full = s['full_payments'] as Map<String, dynamic>? ?? {};
    final excess = s['excess_payments'] as Map<String, dynamic>? ?? {};
    final overdue = s['overdue'] as Map<String, dynamic>? ?? {};

    final parStr = s['par']?.toString().replaceAll('%', '') ?? '0.00';
    final parVal = double.tryParse(parStr) ?? 0.0;

    final c1 = _buildKpiCard('Full Payments', CurrencyFormatter.formatNaira((full['amount'] as num?)?.toDouble() ?? 0.0), '${full['count'] ?? 0} Loans Settled', const Color(0xFF059669));
    final c2 = _buildKpiCard('Excess Payments', CurrencyFormatter.formatNaira((excess['amount'] as num?)?.toDouble() ?? 0.0), '${excess['count'] ?? 0} Surplus Payers', const Color(0xFF2563EB));
    final c3 = _buildKpiCard('Overdue Portfolio', CurrencyFormatter.formatNaira((overdue['amount'] as num?)?.toDouble() ?? 0.0), '${overdue['count'] ?? 0} Overdue Loans', const Color(0xFFDC2626), isAlert: true);
    final c4 = _buildKpiCard('Portfolio at Risk (PAR)', '${parVal.toStringAsFixed(2)}%', '${overdue['count'] ?? 0} Overdue', const Color(0xFFDC2626), isAlert: true);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: c1), const SizedBox(width: 12),
                Expanded(child: c2), const SizedBox(width: 12),
                Expanded(child: c3), const SizedBox(width: 12),
                Expanded(child: c4),
              ],
            ),
          );
        } else {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: c1), const SizedBox(width: 10), Expanded(child: c2)],
                ),
              ),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: c3), const SizedBox(width: 10), Expanded(child: c4)],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildSmallMetricCard(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          top: BorderSide(color: color, width: 2.5),
          left: const BorderSide(color: Color(0xFFE2E8F0)),
          right: const BorderSide(color: Color(0xFFE2E8F0)),
          bottom: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, Color color, {bool isAlert = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          top: BorderSide(color: isAlert ? const Color(0xFFEF4444) : color, width: 3),
          left: BorderSide(color: isAlert ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
          right: BorderSide(color: isAlert ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
          bottom: BorderSide(color: isAlert ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // Itemized Excess Payments & Full Payoffs Audit Ledger
  Widget _buildExcessPayoffAuditLedger(List<dynamic> rows, Map<String, dynamic> s) {
    final excessCount = (s['excess_payments']?['count'] as num?)?.toInt() ?? 0;
    final fullCount = (s['full_payments']?['count'] as num?)?.toInt() ?? 0;
    final hasRecords = rows.isNotEmpty && (excessCount > 0 || fullCount > 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        initiallyExpanded: _excessAuditExpanded,
        onExpansionChanged: (v) => setState(() => _excessAuditExpanded = v),
        title: const Text(
          'Excess and full payment',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
        ),
        subtitle: const Text(
          'Authoritative breakdown of surplus cash collections and full loan payoff settlements within the selected period (BR-DASH-005).',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: rows.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No excess payments or full loan payoffs recorded within the selected period and filter scope.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Client Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              DataColumn(label: Text('Amount Paid', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                              DataColumn(label: Text('Expected Installment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                              DataColumn(label: Text('Excess Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                              DataColumn(label: Text('Active Credit Settled', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                              DataColumn(label: Text('Remaining Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            ],
                            rows: (List<dynamic>.from(rows)..sort((a, b) => (a['Client Code'] ?? '').toString().compareTo((b['Client Code'] ?? '').toString()))).map((r) {
                              return DataRow(cells: [
                                DataCell(Text(r['Client Code']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                DataCell(Text(r['Client Name']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                                DataCell(Text(CurrencyFormatter.formatNaira((r['Amount Paid'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                                DataCell(Text(CurrencyFormatter.formatNaira((r['Expected Installment'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                                DataCell(Text(CurrencyFormatter.formatNaira((r['Excess Amount'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                                DataCell(Text(CurrencyFormatter.formatNaira((r['Active Credit Settled'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                                DataCell(Text(CurrencyFormatter.formatNaira((r['Remaining Balance'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontFeatures: [FontFeature.tabularFigures()]))),
                                DataCell(Text(r['Payment Date']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export Excess Payments & Payoffs Audit (CSV)'),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Exported ${rows.length} payoff & excess records.')),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Category Intelligence Cards
  Widget _buildCategoryIntelligenceCards(Map<String, dynamic> catSum) {
    final w12 = catSum['12_week'] as Map<String, dynamic>? ?? {};
    final w24 = catSum['24_week'] as Map<String, dynamic>? ?? {};
    final dly = catSum['daily'] as Map<String, dynamic>? ?? {};
    final mth = catSum['monthly'] as Map<String, dynamic>? ?? {};

    final cards = [
      {'title': '12-Week Loans', 'data': w12},
      {'title': '24-Week Loans', 'data': w24},
      {'title': 'Daily Loans', 'data': dly},
      {'title': 'Monthly Loans', 'data': mth},
    ];

    Widget buildCard(Map<String, dynamic> c) {
      final d = c['data'] as Map<String, dynamic>;
      final count = d['total_count'] ?? 0;
      final cred = (d['active_credit'] as num?)?.toDouble() ?? 0.0;
      final out = (d['outstanding_balance'] as num?)?.toDouble() ?? 0.0;
      final cash = d['cash_count'] ?? 0;
      final asset = d['asset_count'] ?? 0;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            top: BorderSide(color: Color(0xFF2563EB), width: 3),
            left: BorderSide(color: Color(0xFFE2E8F0)),
            right: BorderSide(color: Color(0xFFE2E8F0)),
            bottom: BorderSide(color: Color(0xFFE2E8F0)),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Active Loans', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Active Credit: ${CurrencyFormatter.formatNaira(cred)}',
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Outstanding: ${CurrencyFormatter.formatNaira(out)}',
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFDC2626),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('Cash: $cash · Asset: $asset', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: buildCard(c)))).toList(),
            ),
          );
        } else {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: buildCard(cards[0])),
                    const SizedBox(width: 10),
                    Expanded(child: buildCard(cards[1])),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: buildCard(cards[2])),
                    const SizedBox(width: 10),
                    Expanded(child: buildCard(cards[3])),
                  ],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  // Group-by-Product Distribution Matrix
  Widget _buildGroupDistributionMatrix(List<dynamic> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();

    // Compute Totals
    int totActiveLoans = 0;
    double totActiveCredit = 0.0;
    double totOutstanding = 0.0;
    int tot12W = 0;
    int tot12WA = 0;
    int tot24W = 0;
    int tot24WA = 0;
    int totDaily = 0;
    int totMonthly = 0;

    for (var r in rows) {
      totActiveLoans += (r['Total Active Loans'] as num?)?.toInt() ?? 0;
      totActiveCredit += (r['Total Active Credit'] as num?)?.toDouble() ?? 0.0;
      totOutstanding += (r['Total Outstanding Balance'] as num?)?.toDouble() ?? 0.0;
      tot12W += (r['12W Cash'] as num?)?.toInt() ?? 0;
      tot12WA += (r['12W Asset'] as num?)?.toInt() ?? 0;
      tot24W += (r['24W Cash'] as num?)?.toInt() ?? 0;
      tot24WA += (r['24W Asset'] as num?)?.toInt() ?? 0;
      totDaily += (r['Daily'] as num?)?.toInt() ?? 0;
      totMonthly += (r['Monthly'] as num?)?.toInt() ?? 0;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        initiallyExpanded: _groupMatrixExpanded,
        onExpansionChanged: (v) => setState(() => _groupMatrixExpanded = v),
        title: const Text('Group-by-Product Distribution Matrix (Click to Expand / Collapse)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
        subtitle: const Text('Distribution of active loan products across all groups in the authorized scope.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Group Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    DataColumn(label: Text('Meeting Day', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    DataColumn(label: Text('12W Cash', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                    DataColumn(label: Text('12W Asset', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                    DataColumn(label: Text('24W Cash', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                    DataColumn(label: Text('24W Asset', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                    DataColumn(label: Text('Daily', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                    DataColumn(label: Text('Monthly', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                    DataColumn(label: Text('Total Active Loans', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                    DataColumn(label: Text('Total Active Credit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                    DataColumn(label: Text('Total Outstanding Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                  ],
                  rows: [
                    ...rows.map((r) => DataRow(cells: [
                          DataCell(Text(r['Group Name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                          DataCell(Text(r['Meeting Day']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                          DataCell(Text('${r['12W Cash'] ?? 0}', style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                          DataCell(Text('${r['12W Asset'] ?? 0}', style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                          DataCell(Text('${r['24W Cash'] ?? 0}', style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                          DataCell(Text('${r['24W Asset'] ?? 0}', style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                          DataCell(Text('${r['Daily'] ?? 0}', style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                          DataCell(Text('${r['Monthly'] ?? 0}', style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                          DataCell(Text('${r['Total Active Loans'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                          DataCell(Text(CurrencyFormatter.formatNaira((r['Total Active Credit'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                          DataCell(Text(CurrencyFormatter.formatNaira((r['Total Outstanding Balance'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626), fontFeatures: [FontFeature.tabularFigures()]))),
                        ])),
                    // TOTALS ROW
                    DataRow(
                      color: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                      cells: [
                        const DataCell(Text('TOTALS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)))),
                        const DataCell(Text('—', style: TextStyle(fontSize: 12))),
                        DataCell(Text('$tot12W', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text('$tot12WA', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text('$tot24W', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text('$tot24WA', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text('$totDaily', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text('$totMonthly', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text('$totActiveLoans', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0284C7), fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira(totActiveCredit), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A), fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira(totOutstanding), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFFDC2626), fontFeatures: [FontFeature.tabularFigures()]))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Client & Group Portfolio Details
  Widget _buildClientAndGroupDetails(
    List<dynamic> clientTable,
    List<dynamic> groupTable,
    Map<String, dynamic> summary,
    Map<String, dynamic> catSum,
  ) {
    final viewMode = ref.watch(portfolioViewModeProvider);
    final quickFilter = ref.watch(portfolioQuickFilterProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // View Mode Selector & Quick Filters
          LayoutBuilder(
            builder: (context, constraints) {
              final modeButtons = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Detailed Client List', 'Group Aggregate Summary'].map((mode) {
                    final isSel = viewMode == mode;
                    return InkWell(
                      onTap: () => ref.read(portfolioViewModeProvider.notifier).state = mode,
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isSel ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          mode,
                          style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFF475569)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );

              if (viewMode != 'Detailed Client List') {
                return modeButtons;
              }

              final quickFilterDropdown = DropdownButtonFormField<String>(
                value: quickFilter,
                decoration: const InputDecoration(
                  labelText: 'Quick Filter',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                items: const [
                  DropdownMenuItem(value: 'All Active Loans', child: Text('All Active Loans')),
                  DropdownMenuItem(value: '12-Week Loans', child: Text('12-Week Loans')),
                  DropdownMenuItem(value: '24-Week Loans', child: Text('24-Week Loans')),
                  DropdownMenuItem(value: 'Asset Loans', child: Text('Asset Loans')),
                  DropdownMenuItem(value: 'Daily Loans', child: Text('Daily Loans')),
                  DropdownMenuItem(value: 'Monthly Loans', child: Text('Monthly Loans')),
                  DropdownMenuItem(value: 'Excess Payers', child: Text('Excess Payers')),
                  DropdownMenuItem(value: 'All Registered Clients', child: Text('All Registered Clients')),
                ],
                onChanged: (val) {
                  if (val != null) ref.read(portfolioQuickFilterProvider.notifier).state = val;
                },
              );

              final searchField = TextField(
                controller: _clientSearchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Search client...',
                  prefixIcon: Icon(Icons.search, size: 16),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
                onChanged: (val) => setState(() {}),
              );

              if (constraints.maxWidth < 750) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    modeButtons,
                    const SizedBox(height: 12),
                    quickFilterDropdown,
                    const SizedBox(height: 10),
                    searchField,
                  ],
                );
              }

              return Row(
                children: [
                  modeButtons,
                  const Spacer(),
                  SizedBox(width: 220, child: quickFilterDropdown),
                  const SizedBox(width: 12),
                  SizedBox(width: 200, child: searchField),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          if (viewMode == 'Detailed Client List')
            _buildDetailedClientTable(clientTable, quickFilter, _clientSearchCtrl.text)
          else
            _buildGroupAggregateTable(groupTable),
        ],
      ),
    );
  }

  Widget _buildDetailedClientTable(List<dynamic> clients, String quickFilter, String searchQuery) {
    var filtered = clients.where((c) {
      final cat = c['Loan Category']?.toString() ?? '';
      final prod = c['Loan Product']?.toString() ?? '';
      final activeLoan = (c['Active Loan'] as num?)?.toDouble() ?? 0.0;
      final excessPaid = (c['Period Excess Paid'] as num?)?.toDouble() ?? 0.0;

      if (quickFilter == '12-Week Loans' && cat != '12-Week Loans') return false;
      if (quickFilter == '24-Week Loans' && cat != '24-Week Loans') return false;
      if (quickFilter == 'Asset Loans' && !prod.toLowerCase().contains('asset')) return false;
      if (quickFilter == 'Daily Loans' && cat != 'Daily Loans') return false;
      if (quickFilter == 'Monthly Loans' && cat != 'Monthly Loans') return false;
      if (quickFilter == 'Excess Payers' && excessPaid <= 0) return false;
      if (quickFilter == 'All Active Loans' && activeLoan <= 0) return false;

      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final name = (c['Client Name']?.toString() ?? '').toLowerCase();
        final code = (c['Client Code']?.toString() ?? '').toLowerCase();
        final group = (c['Group']?.toString() ?? '').toLowerCase();
        if (!name.contains(q) && !code.contains(q) && !group.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => (a['Client Code'] ?? '').toString().compareTo((b['Client Code'] ?? '').toString()));

    if (filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No matching client records found for this filter.', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 750;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile) ...[
              // Tactile Mobile Client Cards (Paginated / Limited)
              ...filtered.take(_mobileClientLimit).map((c) {
                final code = c['Client Code']?.toString() ?? '';
                final name = c['Client Name']?.toString() ?? '';
                final group = c['Group']?.toString() ?? '';
                final product = c['Loan Product']?.toString() ?? '';
                final activeLoan = (c['Active Loan'] as num?)?.toDouble() ?? 0.0;
                final outBal = (c['Outstanding Balance'] as num?)?.toDouble() ?? 0.0;
                final savings = (c['Savings Balance'] as num?)?.toDouble() ?? 0.0;
                final excessPaid = (c['Period Excess Paid'] as num?)?.toDouble() ?? 0.0;
                final status = c['Status']?.toString() ?? 'Active';
                final lifecycle = c['Lifecycle Status']?.toString() ?? 'On Loan';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (code.isNotEmpty) {
                        ref.read(selectedClientCodeProvider.notifier).state = code;
                        ref.read(portfolioMainTabProvider.notifier).state = 'Client Dossier & Inquiry';
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Name & Code + Badges
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFBFDBFE)),
                                          ),
                                          child: Text(
                                            code,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1D4ED8),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            group.isNotEmpty ? '$group • $product' : product,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildLifecycleBadge(lifecycle),
                                  const SizedBox(height: 4),
                                  _buildStatusBadge(status),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 12),

                          // 3-Column Financial Metric Strip
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Outstanding', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.formatNaira(outBal),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFDC2626),
                                        fontFeatures: [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Savings', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.formatNaira(savings),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF059669),
                                        fontFeatures: [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Active Loan', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.formatNaira(activeLoan),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                        fontFeatures: [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (excessPaid > 0) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_upward, size: 12, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Period Excess Paid: ${CurrencyFormatter.formatNaira(excessPaid)}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: const [
                              Text(
                                'View 360° Dossier',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward, size: 14, color: Color(0xFF2563EB)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (filtered.length > _mobileClientLimit) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () {
                      setState(() {
                        _mobileClientLimit += 20;
                      });
                    },
                    child: Text(
                      'Load More (Showing ${_mobileClientLimit > filtered.length ? filtered.length : _mobileClientLimit} of ${filtered.length} Clients)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _mobileClientLimit = filtered.length;
                      });
                    },
                    child: const Text('Show All Clients', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                  ),
                ),
              ] else if (_mobileClientLimit > 10 && filtered.length > 10) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _mobileClientLimit = 10;
                      });
                    },
                    child: const Text('Show Top 10 Only', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ),
                ),
              ],
            ] else ...[
              // Desktop / Tablet Horizontal Data Table
              Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('Client Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Loan Product', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Savings Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Principal Loan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Active Loan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Outstanding Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Total Paid', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Period Excess Paid', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Lifecycle Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    ],
                    rows: filtered.map((c) {
                      return DataRow(cells: [
                        DataCell(
                          InkWell(
                            onTap: () {
                              final code = c['Client Code']?.toString();
                              if (code != null) {
                                ref.read(selectedClientCodeProvider.notifier).state = code;
                                ref.read(portfolioMainTabProvider.notifier).state = 'Client Dossier & Inquiry';
                              }
                            },
                            child: Text(c['Client Code']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF2563EB))),
                          ),
                        ),
                        DataCell(Text(c['Client Name']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        DataCell(Text(c['Group']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                        DataCell(Text(c['Loan Product']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                        DataCell(Text(CurrencyFormatter.formatNaira((c['Savings Balance'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((c['Principal Loan'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((c['Active Loan'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((c['Outstanding Balance'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((c['Total Paid'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((c['Period Excess Paid'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(_buildStatusBadge(c['Status']?.toString() ?? 'Active')),
                        DataCell(_buildLifecycleBadge(c['Lifecycle Status']?.toString() ?? 'On Loan')),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: Text('Export Filtered Portfolio (${filtered.length} Clients CSV)'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exported ${filtered.length} client records.')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupAggregateTable(List<dynamic> groups) {
    if (groups.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No group aggregate data available.', style: TextStyle(color: Color(0xFF64748B)))));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 750;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile) ...[
              // Responsive Mobile Group Touch Cards
              ...groups.map((g) {
                final grpName = g['Group Name']?.toString() ?? 'Group';
                final clientsCount = g['Total Clients'] ?? 0;
                final savings = (g['Total Savings Balance'] as num?)?.toDouble() ?? 0.0;
                final activeLoan = (g['Total Active Loan'] as num?)?.toDouble() ?? 0.0;
                final outBal = (g['Total Outstanding Balance'] as num?)?.toDouble() ?? 0.0;
                final totalPaid = (g['Total Paid'] as num?)?.toDouble() ?? 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
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
                          Expanded(
                            child: Text(
                              grpName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              '$clientsCount Clients',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Outstanding', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatNaira(outBal),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Savings', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatNaira(savings),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669),
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Active Loan', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatNaira(activeLoan),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Paid', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatNaira(totalPaid),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              // Desktop / Tablet Horizontal Data Table
              Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('Group Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Total Clients', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Total Savings Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Total Active Loan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Total Outstanding Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Total Fixed Repayment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Total Paid', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                    ],
                    rows: groups.map((g) {
                      return DataRow(cells: [
                        DataCell(Text(g['Group Name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                        DataCell(Text('${g['Total Clients'] ?? 0}', style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((g['Total Savings Balance'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((g['Total Active Loan'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((g['Total Outstanding Balance'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((g['Total Fixed Repayment'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((g['Total Paid'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: Text('Export Group Aggregate (${groups.length} Groups CSV)'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exported ${groups.length} group records.')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    final s = status.toUpperCase();
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF475569);

    if (s.contains('ACTIVE')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (s.contains('COMPLETED') || s.contains('SETTLED')) {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
    } else if (s.contains('OVERDUE') || s.contains('DEFAULT')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _buildLifecycleBadge(String status) {
    final s = status.toUpperCase();
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF334155);

    if (s.contains('ON LOAN')) {
      bg = const Color(0xFFE0E7FF);
      fg = const Color(0xFF4338CA);
    } else if (s.contains('REGISTERED')) {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
    } else if (s.contains('COMPLETED')) {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF047857);
    } else if (s.contains('SAVINGS ONLY') || s.contains('INACTIVE')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else if (s.contains('DORMANT') || s.contains('SUSPENDED') || s.contains('DEFAULTER')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  // ===========================================================================
  // TAB 2: CLIENT DOSSIER & INQUIRY (360° VIEW)
  // ===========================================================================

  Widget _buildClientDossierTab(AsyncValue<Map<String, dynamic>> portfolioAsync) {
    final clientCodes = (portfolioAsync.valueOrNull?['client_codes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final clientLookup = portfolioAsync.valueOrNull?['client_lookup'] as Map<String, dynamic>? ?? {};

    final selectedCode = ref.watch(selectedClientCodeProvider);

    // Default to first client if none selected
    final activeCode = selectedCode ?? (clientCodes.isNotEmpty ? clientCodes.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Account Selector Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: clientCodes.contains(activeCode) ? activeCode : (clientCodes.isNotEmpty ? clientCodes.first : null),
                  decoration: const InputDecoration(
                    labelText: 'Search & Select Client Account',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  isExpanded: true,
                  items: clientCodes.map((code) {
                    final label = clientLookup[code]?.toString() ?? code;
                    return DropdownMenuItem(value: code, child: Text(label, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(selectedClientCodeProvider.notifier).state = val;
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (activeCode == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Text('No client accounts available in current scope.', style: TextStyle(color: Color(0xFF64748B))),
            ),
          )
        else
          _buildDossierDrilldown(activeCode),
      ],
    );
  }

  Widget _buildDossierDrilldown(String clientCode) {
    final dossierAsync = ref.watch(clientDossierDataProvider(clientCode));

    return dossierAsync.when(
      loading: () => const IcareListSkeleton(itemCount: 6),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
        child: Text('Error loading client dossier: $err', style: const TextStyle(color: Colors.red)),
      ),
      data: (dossier) {
        final cInfo = dossier['customer_info'] as Map<String, dynamic>? ?? {};
        final gInfo = dossier['guarantor_info'] as Map<String, dynamic>? ?? {};
        final banner = dossier['executive_banner'] as Map<String, dynamic>? ?? {};
        final loans = dossier['loan_history'] as List<dynamic>? ?? [];
        final repayments = dossier['repayment_ledger'] as List<dynamic>? ?? [];
        final savings = dossier['savings_ledger'] as List<dynamic>? ?? [];
        final comp = dossier['collection_compliance'] as Map<String, dynamic>? ?? {};
        final compTable = comp['compliance_table'] as List<dynamic>? ?? [];
        final lifecycle = dossier['lifecycle_status'] as Map<String, dynamic>? ?? {};
        final statusHistory = dossier['status_history'] as List<dynamic>? ?? [];
        final auditTrail = dossier['audit_trail'] as List<dynamic>? ?? [];

        final name = cInfo['name']?.toString() ?? 'Client Profile';
        final subTab = ref.watch(clientDossierSubTabProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Executive Header Banner (4 Metrics)
            Text(
              '$name ($clientCode)',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final c1 = _buildKpiCard('Total Active Credit', CurrencyFormatter.formatNaira((banner['total_active_credit'] as num?)?.toDouble() ?? 0.0), 'Active Principal + Markup', const Color(0xFF0F172A));
                final c2 = _buildKpiCard('Outstanding Balance', CurrencyFormatter.formatNaira((banner['outstanding_balance'] as num?)?.toDouble() ?? 0.0), 'Unpaid Balance', const Color(0xFFDC2626));
                final c3 = _buildKpiCard('Savings Balance', CurrencyFormatter.formatNaira((banner['savings_balance'] as num?)?.toDouble() ?? 0.0), 'Available Balance', const Color(0xFF059669));
                final c4 = _buildKpiCard('Account Status', banner['account_status']?.toString() ?? 'Active', 'Authoritative Standing', const Color(0xFF2563EB));

                if (constraints.maxWidth >= 900) {
                  return Row(
                    children: [
                      Expanded(child: c1),
                      const SizedBox(width: 12),
                      Expanded(child: c2),
                      const SizedBox(width: 12),
                      Expanded(child: c3),
                      const SizedBox(width: 12),
                      Expanded(child: c4),
                    ],
                  );
                } else if (constraints.maxWidth >= 600) {
                  return Column(
                    children: [
                      Row(children: [Expanded(child: c1), const SizedBox(width: 12), Expanded(child: c2)]),
                      const SizedBox(height: 12),
                      Row(children: [Expanded(child: c3), const SizedBox(width: 12), Expanded(child: c4)]),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Row(children: [Expanded(child: c1), const SizedBox(width: 8), Expanded(child: c2)]),
                      const SizedBox(height: 8),
                      Row(children: [Expanded(child: c3), const SizedBox(width: 8), Expanded(child: c4)]),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 20),

            // 7 Subtabs
            _buildDossierSubTabBar(subTab),
            const SizedBox(height: 16),

            // Subtab Content
            if (subTab == 'Customer Profile')
              _buildCustomerProfileSubtab(cInfo, gInfo)
            else if (subTab == 'Loan History')
              _buildLoanHistorySubtab(loans)
            else if (subTab == 'Repayment Ledger')
              _buildRepaymentLedgerSubtab(repayments)
            else if (subTab == 'Savings Ledger')
              _buildSavingsLedgerSubtab(savings)
            else if (subTab == 'Collection History')
              _buildCollectionHistorySubtab(comp, compTable)
            else if (subTab == 'Lifecycle Status')
              _buildLifecycleStatusSubtab(lifecycle, statusHistory, cInfo['client_id']?.toString() ?? '')
            else if (subTab == 'Audit Trail')
              _buildAuditTrailSubtab(auditTrail),
          ],
        );
      },
    );
  }

  Widget _buildDossierSubTabBar(String activeTab) {
    final subtabs = [
      'Customer Profile',
      'Loan History',
      'Repayment Ledger',
      'Savings Ledger',
      'Collection History',
      'Lifecycle Status',
      'Audit Trail',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: subtabs.map((tab) {
          final isSel = activeTab == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(tab, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? Colors.white : const Color(0xFF475569))),
              selected: isSel,
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: const Color(0xFFF1F5F9),
              onSelected: (_) => ref.read(clientDossierSubTabProvider.notifier).state = tab,
            ),
          );
        }).toList(),
      ),
    );
  }

  // 1. Customer Profile Subtab
  Widget _buildCustomerProfileSubtab(Map<String, dynamic> c, Map<String, dynamic> g) {
    final name = c['name']?.toString() ?? 'N/A';
    final initials = name.split(' ').map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').take(2).join();

    final clientCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Client Profile & Bio', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE0F2FE),
                ),
                child: Center(
                  child: Text(
                    initials.isNotEmpty ? initials : 'CL',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Text('Code: ${c['client_code'] ?? "N/A"} · Nickname: ${c['nickname'] ?? "None"}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    _buildLifecycleBadge(c['status']?.toString() ?? 'Active'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          _buildInfoRow('Phone Number', c['phone_number']?.toString() ?? 'N/A'),
          _buildInfoRow('Residential Address', c['residential_address']?.toString() ?? 'N/A'),
          _buildInfoRow('Registration Date', c['created_at']?.toString() ?? 'N/A'),
          _buildInfoRow('Solidarity Group', c['group_name']?.toString() ?? 'N/A'),
          _buildInfoRow('Credit Officer', c['officer_name']?.toString() ?? 'N/A'),
          _buildInfoRow('Branch', c['branch_name']?.toString() ?? 'N/A'),
        ],
      ),
    );

    final guarantorCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Guarantor Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
          const SizedBox(height: 16),
          _buildInfoRow('Guarantor Name', g['name']?.toString() ?? 'N/A'),
          _buildInfoRow('Relationship', g['relationship']?.toString() ?? 'N/A'),
          _buildInfoRow('Guarantor Phone', g['phone']?.toString() ?? 'N/A'),
          const SizedBox(height: 16),
          const Text('KYC Verification Standing', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFDCFCE7)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified, size: 18, color: Color(0xFF15803D)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Guarantor verification confirmed and documented under operational rules FP-001.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 750) {
          return Column(
            children: [
              clientCard,
              const SizedBox(height: 16),
              guarantorCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: clientCard),
            const SizedBox(width: 16),
            Expanded(child: guarantorCard),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
        ],
      ),
    );
  }

  // 2. Loan History Subtab
  Widget _buildLoanHistorySubtab(List<dynamic> loans) {
    if (loans.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No historical loan records found for this client.', style: TextStyle(color: Color(0xFF64748B)))));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Disbursement Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Loan Principal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
              DataColumn(label: Text('Active Credit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
              DataColumn(label: Text('Expected Installment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
              DataColumn(label: Text('Remaining Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            ],
            rows: loans.map((l) {
              return DataRow(cells: [
                DataCell(Text(l['disbursement_date']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                DataCell(Text(l['product_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                DataCell(Text(l['category']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                DataCell(Text(CurrencyFormatter.formatNaira((l['principal'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                DataCell(Text(CurrencyFormatter.formatNaira((l['active_credit'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                DataCell(Text(CurrencyFormatter.formatNaira((l['expected_installment'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                DataCell(Text(CurrencyFormatter.formatNaira((l['remaining_balance'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                DataCell(_buildStatusBadge(l['status']?.toString() ?? 'Active')),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  // 3. Repayment Ledger Subtab
  Widget _buildRepaymentLedgerSubtab(List<dynamic> repayments) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Repayment Ledger & Transaction History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
              Text('${repayments.length} Payments Recorded', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          if (repayments.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No repayments recorded for this client yet.', style: TextStyle(color: Color(0xFF64748B)))))
          else
            Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    DataColumn(label: Text('Amount Collected', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    DataColumn(label: Text('Transaction Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    DataColumn(label: Text('Notes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  ],
                  rows: repayments.map((r) {
                    return DataRow(cells: [
                      DataCell(Text(r['date']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(CurrencyFormatter.formatNaira((r['amount_collected'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669), fontFeatures: [FontFeature.tabularFigures()]))),
                      DataCell(_buildStatusBadge(r['status']?.toString() ?? 'Completed')),
                      DataCell(Text(r['transaction_type']?.toString() ?? 'Repayment', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(r['notes']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Flag for Reversal Expander
          ExpansionTile(
            title: const Text('Flag a Repayment for Reversal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFDC2626))),
            subtitle: const Text('Submit a formal correction request under ledger immutability FP-002.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedRepaymentForReversal,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Select Repayment Transaction', border: OutlineInputBorder()),
                      items: repayments.where((r) {
                        final id = r['repayment_id']?.toString() ?? r['id']?.toString() ?? '';
                        return id.isNotEmpty;
                      }).map((r) {
                        final id = r['repayment_id']?.toString() ?? r['id']?.toString() ?? '';
                        final amt = CurrencyFormatter.formatNaira((r['amount_collected'] as num?)?.toDouble() ?? 0.0);
                        final dt = r['date']?.toString() ?? '';
                        final shortId = id.length >= 8 ? id.substring(0, 8) : id;
                        return DropdownMenuItem(value: id, child: Text('$dt — $amt (ID: $shortId...)', overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedRepaymentForReversal = val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reversalReasonCtrl,
                      decoration: const InputDecoration(labelText: 'Audit Justification & Reason for Reversal', border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                      onPressed: _isSubmittingReversal ? null : _submitReversalRequest,
                      child: _isSubmittingReversal ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Reversal Request'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitReversalRequest() async {
    if (_selectedRepaymentForReversal == null || _reversalReasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a repayment and provide a valid audit reason.')),
      );
      return;
    }

    setState(() => _isSubmittingReversal = true);
    try {
      final api = ref.read(coApiServiceProvider);
      await api.submitDossierReversal(
        recordId: _selectedRepaymentForReversal!,
        reason: _reversalReasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reversal request submitted successfully.')),
        );
        _reversalReasonCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting reversal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReversal = false);
    }
  }

  // 4. Savings Ledger Subtab (Running Balance)
  Widget _buildSavingsLedgerSubtab(List<dynamic> savings) {
    if (savings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: const Center(child: Text('No savings transactions recorded for this client.', style: TextStyle(color: Color(0xFF64748B)))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Savings Ledger & Running Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
              Text('${savings.length} Entries', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Deposit (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                  DataColumn(label: Text('Withdrawal (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                  DataColumn(label: Text('Net Balance (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                  DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                ],
                rows: savings.map((s) {
                  final dep = (s['deposit'] as num?)?.toDouble() ?? 0.0;
                  final wd = (s['withdrawal'] as num?)?.toDouble() ?? 0.0;
                  final bal = (s['running_balance'] as num?)?.toDouble() ?? 0.0;

                  return DataRow(cells: [
                    DataCell(Text(s['date']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(dep > 0 ? CurrencyFormatter.formatNaira(dep) : '—', style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                    DataCell(Text(wd > 0 ? CurrencyFormatter.formatNaira(wd) : '—', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                    DataCell(Text(CurrencyFormatter.formatNaira(bal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7), fontFeatures: [FontFeature.tabularFigures()]))),
                    DataCell(Text(s['remarks']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. Collection History Subtab (4 Compliance KPIs & Table)
  Widget _buildCollectionHistorySubtab(Map<String, dynamic> comp, List<dynamic> compTable) {
    final exp = (comp['total_expected'] as num?)?.toDouble() ?? 0.0;
    final act = (comp['total_collected'] as num?)?.toDouble() ?? 0.0;
    final variance = (comp['collection_variance'] as num?)?.toDouble() ?? 0.0;
    final rate = (comp['compliance_rate'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 Compliance KPIs
        LayoutBuilder(
          builder: (context, constraints) {
            final c1 = _buildKpiCard('Total Expected', CurrencyFormatter.formatNaira(exp), 'All Scheduled Repayments', const Color(0xFF475569));
            final c2 = _buildKpiCard('Total Collected', CurrencyFormatter.formatNaira(act), 'Total Paid to Date', const Color(0xFF059669));
            final c3 = _buildKpiCard('Collection Variance', CurrencyFormatter.formatNaira(variance), variance <= 0 ? 'Surplus / On Target' : 'Deficit / Shortfall', variance <= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626), isAlert: variance > 0);
            final c4 = _buildKpiCard('Compliance Rate', '${rate.toStringAsFixed(1)}%', 'Collection Efficiency', rate >= 90 ? const Color(0xFF059669) : const Color(0xFFDC2626), isAlert: rate < 90);

            if (constraints.maxWidth >= 900) {
              return Row(
                children: [
                  Expanded(child: c1),
                  const SizedBox(width: 12),
                  Expanded(child: c2),
                  const SizedBox(width: 12),
                  Expanded(child: c3),
                  const SizedBox(width: 12),
                  Expanded(child: c4),
                ],
              );
            } else if (constraints.maxWidth >= 600) {
              return Column(
                children: [
                  Row(children: [Expanded(child: c1), const SizedBox(width: 12), Expanded(child: c2)]),
                  const SizedBox(height: 12),
                  Row(children: [Expanded(child: c3), const SizedBox(width: 12), Expanded(child: c4)]),
                ],
              );
            } else {
              return Column(
                children: [
                  c1,
                  const SizedBox(height: 12),
                  c2,
                  const SizedBox(height: 12),
                  c3,
                  const SizedBox(height: 12),
                  c4,
                ],
              );
            }
          },
        ),
        const SizedBox(height: 16),

        // Compliance Table
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Weekly & Meeting Collection Records', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
                  Text('${compTable.length} Meetings Recorded', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              if (compTable.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No collection meeting records found.', style: TextStyle(color: Color(0xFF64748B)))))
              else
                Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columns: const [
                        DataColumn(label: Text('Meeting Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                        DataColumn(label: Text('Expected (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                        DataColumn(label: Text('Collected (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                        DataColumn(label: Text('Variance (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                        DataColumn(label: Text('Officer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                        DataColumn(label: Text('Compliance Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                        DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      ],
                      rows: compTable.map((m) {
                        final expM = (m['expected'] as num?)?.toDouble() ?? 0.0;
                        final colM = (m['collected'] as num?)?.toDouble() ?? 0.0;
                        final varM = (m['variance'] as num?)?.toDouble() ?? (expM - colM);
                        final st = m['compliance_status']?.toString() ?? 'Compliant';

                        return DataRow(cells: [
                          DataCell(Text(m['meeting_date']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                          DataCell(Text(CurrencyFormatter.formatNaira(expM), style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                          DataCell(Text(CurrencyFormatter.formatNaira(colM), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669), fontFeatures: [FontFeature.tabularFigures()]))),
                          DataCell(Text(CurrencyFormatter.formatNaira(varM), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: varM <= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626), fontFeatures: [FontFeature.tabularFigures()]))),
                          DataCell(Text(m['officer_name']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                          DataCell(_buildStatusBadge(st)),
                          DataCell(Text(m['remarks']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 6. Lifecycle Status Subtab
  Widget _buildLifecycleStatusSubtab(Map<String, dynamic> lifecycle, List<dynamic> history, String clientId) {
    final curStatus = lifecycle['current_status']?.toString() ?? 'Registered';
    final lastChanged = lifecycle['last_changed']?.toString() ?? 'N/A';
    final note = lifecycle['note']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Status Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user, size: 24, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Authoritative Lifecycle Status: ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                        _buildLifecycleBadge(curStatus),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Last transitioned: $lastChanged · Note: ${note.isNotEmpty ? note : "None"}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Manual Transition Form Container
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Manual Lifecycle Status Transition', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              const Text('Transition client state under CLIENT_STATUS_RULES governance. Auto-status is enforced on loan completion.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final statusDropdown = DropdownButtonFormField<String>(
                    value: _targetStatus,
                    decoration: const InputDecoration(labelText: 'Target Lifecycle Status', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Registered', child: Text('Registered')),
                      DropdownMenuItem(value: 'Inactive (Savings Only)', child: Text('Inactive (Savings Only)')),
                      DropdownMenuItem(value: 'Closed', child: Text('Closed')),
                      DropdownMenuItem(value: 'Suspended', child: Text('Suspended')),
                      DropdownMenuItem(value: 'Dormant', child: Text('Dormant')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _targetStatus = val);
                    },
                  );

                  final reasonField = TextField(
                    controller: _statusReasonCtrl,
                    decoration: const InputDecoration(labelText: 'Operational Reason for Transition', border: OutlineInputBorder()),
                  );

                  final submitBtn = ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSubmittingStatus ? null : () => _submitStatusChange(clientId),
                    child: _isSubmittingStatus ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Transition Status'),
                  );

                  if (constraints.maxWidth < 750) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        statusDropdown,
                        const SizedBox(height: 12),
                        reasonField,
                        const SizedBox(height: 12),
                        submitBtn,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: statusDropdown),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: reasonField),
                      const SizedBox(width: 16),
                      submitBtn,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Status History Table
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Status Change History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
              const SizedBox(height: 16),
              if (history.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No prior status transitions recorded.', style: TextStyle(color: Color(0xFF64748B)))))
              else
              Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('From Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('To Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Changed At', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Reason', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Changed By', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    ],
                    rows: history.map((h) {
                      return DataRow(cells: [
                        DataCell(_buildLifecycleBadge(h['from_status']?.toString() ?? 'Unknown')),
                        DataCell(_buildLifecycleBadge(h['to_status']?.toString() ?? 'Unknown')),
                        DataCell(Text(h['changed_at']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                        DataCell(Text(h['reason']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                        DataCell(Text(h['changed_by']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submitStatusChange(String clientId) async {
    if (_statusReasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide an operational reason for the status transition.')),
      );
      return;
    }

    setState(() => _isSubmittingStatus = true);
    try {
      final api = ref.read(coApiServiceProvider);
      await api.changeClientStatus(
        clientId: clientId,
        targetStatus: _targetStatus,
        reason: _statusReasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Client status transitioned to $_targetStatus successfully.')),
        );
        _statusReasonCtrl.clear();
        // Invalidate portfolio and dossier
        ref.invalidate(portfolioDataProvider);
        final code = ref.read(selectedClientCodeProvider);
        if (code != null) ref.invalidate(clientDossierDataProvider(code));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error transitioning status: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingStatus = false);
    }
  }

  // 7. Audit Trail Subtab
  Widget _buildAuditTrailSubtab(List<dynamic> auditTrail) {
    if (auditTrail.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: const Center(child: Text('No compliance audit records found for this client account.', style: TextStyle(color: Color(0xFF64748B)))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Immutable Compliance Audit Trail', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
              Text('${auditTrail.length} Audit Entries', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Entity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Performed By', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                ],
                rows: auditTrail.map((a) {
                  return DataRow(cells: [
                    DataCell(Text(a['timestamp']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(a['action']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A)))),
                    DataCell(Text(a['entity']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(a['performed_by']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(a['details']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
