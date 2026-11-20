import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';

import '../../../core/auth/auth_controller.dart';

import '../../../core/auth/auth_state.dart';

import '../../../core/widgets/icare_skeleton_loader.dart';

import '../../../core/theme/icare_theme_tokens.dart';

import '../../../core/errors/app_error_formatter.dart';

import '../../shared/utils/file_download_helper.dart';

import '../data/datasources/co_api_service.dart';

final portfolioMainTabProvider = StateProvider<String>((ref) => 'Portfolio Summary & Analytics');

final incomingTransfersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(coApiServiceProvider);
  return api.getIncomingTransfers();
});

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

  bool _recoveryAuditExpanded = false;

  String _auditLedgerSubView = 'Excess & Payoffs'; // 'Excess & Payoffs' or 'Overdue Recoveries'

  bool _groupMatrixExpanded = true;

  bool _matrixCardView = false;

  Future<void> _exportRecordsToCsv({
    required List<dynamic> rows,
    required List<String> columns,
    required String filePrefix,
    required String recordLabel,
  }) async {
    String escapeCsv(String val) {
      if (val.contains(',') || val.contains('"') || val.contains('\n')) {
        return '"${val.replaceAll('"', '""')}"';
      }
      return val;
    }

    final buffer = StringBuffer();
    buffer.writeln(columns.map(escapeCsv).join(','));
    for (final raw in rows) {
      final row = raw is Map ? raw : <String, dynamic>{};
      final line = columns.map((col) => escapeCsv((row[col] ?? '').toString())).join(',');
      buffer.writeln(line);
    }

    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '${filePrefix}_$stamp.csv';
    try {
      final savedPath = await downloadBlobFile(
        utf8.encode(buffer.toString()),
        fileName,
        'text/csv',
      );
      if (!mounted) return;
      if (savedPath == null || savedPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: unable to save $fileName to device storage.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        return;
      }
      final locationNote = ' ($savedPath)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${rows.length} $recordLabel$locationNote.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final err = AppErrorDetails.from(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${err.title}: ${err.message}'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  // Mobile segmented hub and pagination state

  int _mobilePortfolioTab = 0;

  int _mobileClientLimit = 10;

  // Lifecycle change dialog state

  String _targetStatus = 'Inactive (Savings Only)';

  final TextEditingController _statusReasonCtrl = TextEditingController();

  bool _isSubmittingStatus = false;

  // Reversal request state

  String? _selectedRepaymentForReversal;

  final TextEditingController _reversalReasonCtrl = TextEditingController();

  bool _isSubmittingReversal = false;

  bool _hideCancelledTransactions = true;

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
    final tokens = IcareSurfaceTokens.of(context);
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final role = user?.role ?? 'CO';
    final isOfficer = role == 'CO' || role == 'Credit Officer' || role == 'Officer' || role == 'CREDIT_OFFICER';
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
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        // 2. Filters & Scope Bar
        _buildFilterBar(portfolioAsync, user),
        const SizedBox(height: 20),
        // 3. Tab Bar
        _buildMainTabBar(activeMainTab, isOfficer: isOfficer),
        const SizedBox(height: 20),
        // 4. Tab Contents
        if (activeMainTab == 'Portfolio Summary & Analytics')
          _buildPortfolioSummaryTab(portfolioAsync)
        else if (activeMainTab.startsWith('Incoming Transfers'))
          _buildIncomingTransfersTab()
        else
          _buildClientDossierTab(portfolioAsync),
      ],
    );
  }

  Widget _buildMainTabBar(String activeTab, {bool isOfficer = false}) {
    final tokens = IcareSurfaceTokens.of(context);
    final incomingAsync = !isOfficer ? ref.watch(incomingTransfersProvider) : null;
    final incomingCount = incomingAsync?.valueOrNull?.length ?? 0;
    final incomingLabel = incomingCount > 0 ? 'Incoming Transfers ($incomingCount)' : 'Incoming Transfers';

    final tabs = [
      'Portfolio Summary & Analytics',
      'Client Dossier & Inquiry',
      if (!isOfficer) incomingLabel,
    ];

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((t) {
            final isSel = activeTab == t || (t.startsWith('Incoming Transfers') && activeTab.startsWith('Incoming Transfers'));
            return InkWell(
              onTap: () => ref.read(portfolioMainTabProvider.notifier).state = t,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? tokens.infoBg : Colors.transparent,
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
                          color: isSel ? tokens.infoDot : tokens.textMuted,
                          width: 2,
                        ),
                      ),
                      child: isSel
                          ? Center(
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: tokens.infoDot,
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
                        color: isSel ? tokens.infoText : tokens.textSecondary,
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
    final tokens = IcareSurfaceTokens.of(context);
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
    final scopeText = isOfficer
        ? '${user?.branch ?? "Branch"} · ${user?.username ?? "CO"}'
        : (isBm ? 'Branch: ${user?.branch ?? "Branch"}' : 'All Branches');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

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
              suffixIcon: Icon(Icons.calendar_month, size: 18, color: tokens.textMuted),
            ),
            child: Text(
              _startDate != null && _endDate != null
                  ? '${_formatDate(_startDate)}  to  ${_formatDate(_endDate)}'
                  : 'Select range',
              style: TextStyle(
                fontSize: 12,
                color: _selectedTimePeriod == 'Custom Date Range'
                    ? tokens.textPrimary
                    : tokens.textMuted,
              ),
            ),
          ),
        );

        final prodField = _buildDropdown(
          label: 'Loan Product',
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

        final offDropdown = _buildDropdown(
          label: 'Credit Officer',
          value: availableOfficers.contains(_selectedOfficer) ? _selectedOfficer : 'All',
          items: availableOfficers,
          onChanged: (val) {
            if (val != null) setState(() => _selectedOfficer = val);
          },
        );

        final brDropdown = _buildDropdown(
          label: 'Branch',
          value: availableBranches.contains(_selectedBranch) ? _selectedBranch : 'All',
          items: availableBranches,
          onChanged: (val) {
            if (val != null) setState(() => _selectedBranch = val);
          },
        );

        if (isMobile) {
          final hasActiveFilters = _selectedTimePeriod != 'Current Month' ||
              _selectedProduct != 'All' ||
              _selectedGroup != 'All' ||
              _selectedOfficer != 'All' ||
              _selectedBranch != 'All';

          return SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                // Scope badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 13, color: tokens.infoDot),
                      const SizedBox(width: 5),
                      Text(
                        scopeText,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Period Filter Chip
                _buildFilterChip(
                  label: _selectedTimePeriod,
                  icon: Icons.calendar_today_rounded,
                  isActive: _selectedTimePeriod != 'Current Month',
                  onTap: () => _showPeriodPicker(context),
                ),
                const SizedBox(width: 6),
                // Product Filter Chip
                _buildFilterChip(
                  label: _selectedProduct == 'All' ? 'Product: All' : _selectedProduct,
                  icon: Icons.local_offer_outlined,
                  isActive: _selectedProduct != 'All',
                  onTap: () => _showFilterOptionPicker(
                    context: context,
                    title: 'Select Loan Product',
                    currentValue: _selectedProduct,
                    items: availableProducts,
                    onSelected: (val) => setState(() => _selectedProduct = val),
                  ),
                ),
                const SizedBox(width: 6),
                // Group Filter Chip
                _buildFilterChip(
                  label: _selectedGroup == 'All' ? 'Group: All' : _selectedGroup,
                  icon: Icons.groups_outlined,
                  isActive: _selectedGroup != 'All',
                  onTap: () => _showFilterOptionPicker(
                    context: context,
                    title: 'Select Solidarity Group',
                    currentValue: _selectedGroup,
                    items: availableGroups,
                    onSelected: (val) => setState(() => _selectedGroup = val),
                  ),
                ),
                if (!isOfficer) ...[
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: _selectedOfficer == 'All' ? 'Officer: All' : _selectedOfficer,
                    icon: Icons.person_outline_rounded,
                    isActive: _selectedOfficer != 'All',
                    onTap: () => _showFilterOptionPicker(
                      context: context,
                      title: 'Select Credit Officer',
                      currentValue: _selectedOfficer,
                      items: availableOfficers,
                      onSelected: (val) => setState(() => _selectedOfficer = val),
                    ),
                  ),
                ],
                if (!isOfficer && !isBm) ...[
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: _selectedBranch == 'All' ? 'Branch: All' : _selectedBranch,
                    icon: Icons.account_balance_outlined,
                    isActive: _selectedBranch != 'All',
                    onTap: () => _showFilterOptionPicker(
                      context: context,
                      title: 'Select Branch',
                      currentValue: _selectedBranch,
                      items: availableBranches,
                      onSelected: (val) => setState(() => _selectedBranch = val),
                    ),
                  ),
                ],
                if (hasActiveFilters) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _resetFilters,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: tokens.dangerBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.dangerBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: 13, color: tokens.dangerText),
                          const SizedBox(width: 4),
                          Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.dangerText)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        // Desktop / Tablet layout
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.borderSubtle),
            boxShadow: const [
              BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: tokens.infoBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.shield_outlined, size: 14, color: tokens.infoDot),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Scope: $scopeText',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tokens.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (constraints.maxWidth >= 950)
                Row(
                  children: [
                    if (!isOfficer) ...[
                      if (!isBm) ...[
                        Expanded(child: brDropdown),
                        const SizedBox(width: 10),
                      ],
                      Expanded(child: offDropdown),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: timeField),
                    if (_selectedTimePeriod == 'Custom Date Range') ...[
                      const SizedBox(width: 10),
                      Expanded(child: dateField),
                    ],
                    const SizedBox(width: 10),
                    Expanded(child: prodField),
                    const SizedBox(width: 10),
                    Expanded(child: grpField),
                  ],
                )
              else
                Column(
                  children: [
                    if (!isOfficer) ...[
                      Row(
                        children: [
                          if (!isBm) ...[
                            Expanded(child: brDropdown),
                            const SizedBox(width: 10),
                          ],
                          Expanded(child: offDropdown),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(child: timeField),
                        if (_selectedTimePeriod == 'Custom Date Range') ...[
                          const SizedBox(width: 10),
                          Expanded(child: dateField),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: prodField),
                        const SizedBox(width: 10),
                        Expanded(child: grpField),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? tokens.infoBg : tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? tokens.infoBorder : tokens.borderSubtle,
            width: isActive ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? tokens.infoText : tokens.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? tokens.infoText : tokens.textSecondary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: isActive ? tokens.infoText : tokens.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterOptionPicker({
    required BuildContext context,
    required String title,
    required String currentValue,
    required List<String> items,
    required ValueChanged<String> onSelected,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: tokens.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: tokens.borderSubtle),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, idx) {
                    final item = items[idx];
                    final isSel = item == currentValue;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelected(item);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        color: isSel ? tokens.brandSoftBg : Colors.transparent,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                  color: isSel ? tokens.brandSoftText : tokens.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSel)
                              Icon(Icons.check, size: 16, color: tokens.brandSoftText),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPeriodPicker(BuildContext context) {
    const periods = ['Today', 'Yesterday', 'Current Month', 'Last Month', 'Custom Date Range'];
    _showFilterOptionPicker(
      context: context,
      title: 'Select Time Period',
      currentValue: _selectedTimePeriod,
      items: periods,
      onSelected: (p) {
        setState(() {
          _selectedTimePeriod = p;
          _computeDatesForPeriod(p);
        });
        if (p == 'Custom Date Range') {
          _selectCustomDateRange();
        }
      },
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedTimePeriod = 'Current Month';
      _computeDatesForPeriod('Current Month');
      _selectedProduct = 'All';
      _selectedGroup = 'All';
      _selectedOfficer = 'All';
      _selectedBranch = 'All';
    });
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
    final tokens = IcareSurfaceTokens.of(context);
    final validValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : null);
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$validValue-${items.length}'),
      value: validValue,
      dropdownColor: tokens.surfaceElevated,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: TextStyle(fontSize: 12, color: tokens.textPrimary),
      isExpanded: true,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }

  // ===========================================================================
  // TAB 1: PORTFOLIO SUMMARY & ANALYTICS
  // ===========================================================================
  Widget _buildPortfolioSummaryTab(AsyncValue<Map<String, dynamic>> portfolioAsync) {
    final tokens = IcareSurfaceTokens.of(context);
    return portfolioAsync.when(
      loading: () => const IcareTableSkeleton(rowCount: 8),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.dangerBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.dangerBorder),
        ),
        child: Text(AppErrorDetails.from(err).message, style: TextStyle(color: tokens.dangerText)),
      ),
      data: (data) {
        final summary = data['summary'] as Map<String, dynamic>? ?? {};
        final categorySummary = data['category_summary'] as Map<String, dynamic>? ?? {};
        final groupMatrix = data['group_matrix'] as List<dynamic>? ?? [];
        final clientTable = data['client_table'] as List<dynamic>? ?? [];
        final groupTable = data['group_table'] as List<dynamic>? ?? [];
        final payoffExcessTable = data['payoff_excess_table'] as List<dynamic>? ?? [];
        final overdueRecoveryTable = data['overdue_recovery_table'] as List<dynamic>? ?? [];

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
                overdueRecoveryTable: overdueRecoveryTable,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Portfolio Summary & Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                ),
                const SizedBox(height: 12),
                _buildSectionHeader(
                  'Client Lifecycle Status Breakdown',
                  icon: Icons.donut_large_outlined,
                ),
                _buildLifecycleMetricsRow(summary),
                const SizedBox(height: 20),
                _buildSectionHeader(
                  'Savings & Vault Flows',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                _buildSavingsMetricsRow(summary),
                const SizedBox(height: 20),
                _buildSectionHeader(
                  'Disbursement & Underwriting Activity',
                  icon: Icons.payments_outlined,
                ),
                _buildDisbursementMetricsRow(summary),
                const SizedBox(height: 20),
                _buildSectionHeader(
                  'Loan Portfolio & Collections',
                  icon: Icons.trending_up_outlined,
                ),
                _buildLoanCollectionMetricsRow(summary),
                const SizedBox(height: 20),
                _buildSectionHeader(
                  'Repayment Performance & Arrears Risk',
                  icon: Icons.shield_outlined,
                ),
                _buildRepaymentRiskMetricsRow(summary),
                const SizedBox(height: 20),
                _buildExcessPayoffAuditLedger(payoffExcessTable, summary),
                const SizedBox(height: 16),
                _buildOverdueRecoveryAuditLedger(overdueRecoveryTable, summary),
                const SizedBox(height: 24),
                Divider(color: tokens.borderSubtle),
                const SizedBox(height: 12),
                Text('Loan Products & Category Intelligence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                const SizedBox(height: 10),
                _buildCategoryIntelligenceCards(categorySummary),
                const SizedBox(height: 20),
                _buildGroupDistributionMatrix(groupMatrix),
                const SizedBox(height: 24),
                Divider(color: tokens.borderSubtle),
                const SizedBox(height: 12),
                Text('Client & Group Portfolio Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
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
  // ===========================================================================
  Widget _buildMobilePortfolioSummary({
    required Map<String, dynamic> summary,
    required Map<String, dynamic> categorySummary,
    required List<dynamic> groupMatrix,
    required List<dynamic> clientTable,
    required List<dynamic> groupTable,
    required List<dynamic> payoffExcessTable,
    required List<dynamic> overdueRecoveryTable,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    Widget tabContent;
    switch (_mobilePortfolioTab) {
      case 0:
        tabContent = _buildClientAndGroupDetails(clientTable, groupTable, summary, categorySummary);
        break;
      case 1:
        tabContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Client Lifecycle Status Breakdown',
              icon: Icons.donut_large_outlined,
            ),
            _buildLifecycleMetricsRow(summary),
            const SizedBox(height: 16),
            _buildSectionHeader(
              'Savings & Vault Flows',
              icon: Icons.account_balance_wallet_outlined,
            ),
            _buildSavingsMetricsRow(summary),
            const SizedBox(height: 16),
            _buildSectionHeader(
              'Disbursement & Underwriting',
              icon: Icons.payments_outlined,
            ),
            _buildDisbursementMetricsRow(summary),
            const SizedBox(height: 16),
            _buildSectionHeader(
              'Loan Portfolio & Collections',
              icon: Icons.trending_up_outlined,
            ),
            _buildLoanCollectionMetricsRow(summary),
            const SizedBox(height: 16),
            _buildSectionHeader(
              'Repayment Performance & Risk',
              icon: Icons.shield_outlined,
            ),
            _buildRepaymentRiskMetricsRow(summary),
          ],
        );
        break;
      case 2:
        tabContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loan Products & Category Intelligence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
            const SizedBox(height: 10),
            _buildCategoryIntelligenceCards(categorySummary),
            const SizedBox(height: 20),
            _buildGroupDistributionMatrix(groupMatrix),
          ],
        );
        break;
      case 3:
      default:
        tabContent = _buildCombinedAuditLedger(payoffExcessTable, overdueRecoveryTable, summary, isEmbeddedInTab: true);
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
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildPortfolioTabPill(index: 0, label: 'Directory', icon: Icons.people_outline, count: clientTable.length),
                const SizedBox(width: 4),
                _buildPortfolioTabPill(index: 1, label: 'KPIs & Risk', icon: Icons.analytics_outlined, count: 22),
                const SizedBox(width: 4),
                _buildPortfolioTabPill(index: 2, label: 'Products', icon: Icons.category_outlined, count: groupMatrix.length),
                const SizedBox(width: 4),
                _buildPortfolioTabPill(index: 3, label: 'Audit Ledger', icon: Icons.receipt_long_outlined, count: payoffExcessTable.length + overdueRecoveryTable.length),
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
    final tokens = IcareSurfaceTokens.of(context);
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? tokens.surfaceElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected && !tokens.isDark
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
                size: 14,
                color: isSelected ? tokens.brandPrimary : tokens.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? tokens.textPrimary : tokens.textMuted,
                ),
              ),
              if (count != null && count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected ? tokens.brandSoftBg : tokens.borderSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? tokens.brandSoftText : tokens.textSecondary,
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

  // =========================================================================

  // INSTITUTIONAL SECTION HEADERS & MICRO-KPIS

  // =========================================================================

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    final tokens = IcareSurfaceTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Icon(icon, size: 14, color: tokens.textSecondary),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroKpi(String label, String value, Color color) {
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: tokens.textMuted, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  // Lifecycle (8 metrics)

  Widget _buildLifecycleMetricsRow(Map<String, dynamic> s) {

    final c1 = _buildSmallMetricCard('Registered', '${s['registered_clients'] ?? 0} Clients', const Color(0xFF0284C7));

    final c2 = _buildSmallMetricCard('On Loan', '${s['active_clients'] ?? 0} Clients', const Color(0xFF059669));

    final c3 = _buildSmallMetricCard('Completed', '${s['completed_clients'] ?? 0} Clients', const Color(0xFF10B981));

    final c4 = _buildSmallMetricCard('Pending Loans', '${s['pending_loan_clients'] ?? 0} Clients', const Color(0xFFF59E0B));

    final c5 = _buildSmallMetricCard('Savings Only', '${s['savings_only_clients'] ?? 0} Clients', const Color(0xFF6366F1));

    final c6 = _buildSmallMetricCard('Dormant', '${s['dormant_clients'] ?? 0} Clients', const Color(0xFF64748B));

    final c7 = _buildSmallMetricCard('Suspended', '${s['suspended_clients'] ?? 0} Clients', const Color(0xFFEA580C));

    final c8 = _buildSmallMetricCard('Closed', '${s['closed_clients'] ?? 0} Clients', const Color(0xFF94A3B8));

    final c9 = _buildSmallMetricCard('Defaulters', '${s['defaulters'] ?? 0} Clients', const Color(0xFFB91C1C));

    return LayoutBuilder(

      builder: (context, constraints) {

        if (constraints.maxWidth >= 1150) {

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

                Expanded(child: c8), const SizedBox(width: 8),

                Expanded(child: c9),

              ],

            ),

          );

        } else if (constraints.maxWidth >= 600) {

          return Column(

            children: [

              IntrinsicHeight(

                child: Row(

                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [

                    Expanded(child: c1), const SizedBox(width: 8),

                    Expanded(child: c2), const SizedBox(width: 8),

                    Expanded(child: c3), const SizedBox(width: 8),

                    Expanded(child: c4), const SizedBox(width: 8),

                    Expanded(child: c5),

                  ],

                ),

              ),

              const SizedBox(height: 8),

              IntrinsicHeight(

                child: Row(

                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [

                    Expanded(child: c6), const SizedBox(width: 8),

                    Expanded(child: c7), const SizedBox(width: 8),

                    Expanded(child: c8), const SizedBox(width: 8),

                    Expanded(child: c9),

                  ],

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

              const SizedBox(height: 8),

              IntrinsicHeight(

                child: Row(

                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [Expanded(child: c9), const SizedBox(width: 8), const Spacer()],

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

    final c1 = _buildKpiCard('Savings Deposited (Period)', CurrencyFormatter.formatNaira(dep), '${s['period_savings_dep_clients'] ?? 0} Clients', const Color(0xFF059669), icon: Icons.arrow_downward_rounded);

    final c2 = _buildKpiCard('Savings Withdrawn (Period)', CurrencyFormatter.formatNaira(wd), '${s['period_savings_wd_clients'] ?? 0} Clients', const Color(0xFFDC2626), icon: Icons.arrow_upward_rounded);

    final c3 = _buildKpiCard('Net Savings (Period)', CurrencyFormatter.formatNaira(net), net != 0 ? '${CurrencyFormatter.formatNaira(net)} (Net)' : '₦0 (Balanced)', const Color(0xFF2563EB), icon: Icons.swap_vert_rounded);

    final c4 = _buildKpiCard('Total Savings Balance', CurrencyFormatter.formatNaira(tot), '${s['total_savings_clients'] ?? 0} Active Savers', const Color(0xFF0284C7), icon: Icons.account_balance_wallet_outlined);

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

    final c1 = _buildKpiCard('Loans Disbursed', '$count Loans', '$clientCount Clients', const Color(0xFF2563EB), icon: Icons.description_outlined);

    final c2 = _buildKpiCard('Total Amount Disbursed', CurrencyFormatter.formatNaira(amt), '$count Loans (Incl. Assets)', const Color(0xFF059669), icon: Icons.payments_outlined);

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
    final tokens = IcareSurfaceTokens.of(context);
    final activeCred = (s['total_active_credit'] as num?)?.toDouble() ?? 0.0;
    final expRepay = (s['total_expected_repayment'] as num?)?.toDouble() ?? 0.0;
    final actualCol = (s['total_actual_collection'] ?? s['today_collection'] as num?)?.toDouble() ?? 0.0;
    final outBal = (s['total_outstanding_balance'] as num?)?.toDouble() ?? 0.0;

    final c1 = _buildKpiCard('Total Active Credit', CurrencyFormatter.formatNaira(activeCred), '${s['active_loans_count'] ?? 0} Active Loans', tokens.textPrimary, icon: Icons.account_balance_outlined);
    final c2 = _buildKpiCard('Expected Repayment', CurrencyFormatter.formatNaira(expRepay), '${s['expected_repay_clients'] ?? 0} Clients', tokens.textSecondary, icon: Icons.event_note_outlined);
    final c3 = _buildKpiCard('Actual Collections (Period)', CurrencyFormatter.formatNaira(actualCol), '${s['paying_clients_count'] ?? 0} Clients Paid', tokens.brandAccent, icon: Icons.check_circle_outline);
    final c4 = _buildKpiCard('Total Outstanding Balance', CurrencyFormatter.formatNaira(outBal), '${s['outstanding_clients_count'] ?? 0} Clients', tokens.dangerDot, icon: Icons.pending_actions_outlined);

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

    final c1 = _buildKpiCard('Full Payments', CurrencyFormatter.formatNaira((full['amount'] as num?)?.toDouble() ?? 0.0), '${full['count'] ?? 0} Loans Settled', const Color(0xFF059669), icon: Icons.task_alt_outlined);
    final c2 = _buildKpiCard('Excess Payments', CurrencyFormatter.formatNaira((excess['amount'] as num?)?.toDouble() ?? 0.0), '${excess['count'] ?? 0} Surplus Payers', const Color(0xFF2563EB), icon: Icons.trending_up_outlined);
    final c3 = _buildKpiCard('Overdue Portfolio', CurrencyFormatter.formatNaira((overdue['amount'] as num?)?.toDouble() ?? 0.0), '${overdue['count'] ?? 0} Overdue Loans', const Color(0xFFDC2626), isAlert: (overdue['count'] as num? ?? 0) > 0, icon: Icons.warning_amber_rounded);
    final c4 = _buildKpiCard('Portfolio at Risk (PAR)', '${parVal.toStringAsFixed(2)}%', '${overdue['count'] ?? 0} Overdue', parVal > 5.0 ? const Color(0xFFDC2626) : const Color(0xFF059669), isAlert: parVal > 5.0, icon: Icons.security_outlined);

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
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    String subtitle,
    Color color, {
    bool isAlert = false,
    IconData? icon,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    final effectiveColor = isAlert ? tokens.dangerText : color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAlert ? tokens.dangerBg : tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlert ? tokens.dangerBorder : tokens.borderSubtle,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isAlert ? tokens.dangerText : tokens.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: tokens.isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 13, color: effectiveColor),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
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
                color: isAlert ? tokens.dangerText : tokens.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5,
              color: isAlert ? tokens.dangerText : tokens.textMuted,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Itemized Excess Payments & Full Payoffs Audit Ledger
  Widget _buildExcessPayoffAuditLedger(List<dynamic> rows, Map<String, dynamic> s, {bool isEmbeddedInTab = false}) {
    final tokens = IcareSurfaceTokens.of(context);
    final excessCount = (s['excess_payments']?['count'] as num?)?.toInt() ?? 0;
    final fullCount = (s['full_payments']?['count'] as num?)?.toInt() ?? 0;

    final sortedRows = List<dynamic>.from(rows)
      ..sort((a, b) => (a['Client Code'] ?? '').toString().compareTo((b['Client Code'] ?? '').toString()));

    Widget buildLedgerBody() {
      if (sortedRows.isEmpty) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.neutralBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified_outlined, size: 28, color: tokens.textMuted),
              ),
              const SizedBox(height: 12),
              Text(
                'No Excess Payments or Full Payoffs',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tokens.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'No surplus collections or complete loan payoffs were recorded in the active period.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: tokens.textMuted),
              ),
            ],
          ),
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 750;
          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...sortedRows.map((r) {
                  final code = r['Client Code']?.toString() ?? '';
                  final name = r['Client Name']?.toString() ?? '';
                  final amtPaid = (r['Amount Paid'] as num?)?.toDouble() ?? 0.0;
                  final expInst = (r['Expected Installment'] as num?)?.toDouble() ?? 0.0;
                  final excessAmt = (r['Excess Amount'] as num?)?.toDouble() ?? 0.0;
                  final settledAmt = (r['Active Credit Settled'] as num?)?.toDouble() ?? 0.0;
                  final remBal = (r['Remaining Balance'] as num?)?.toDouble() ?? 0.0;
                  final pDate = r['Payment Date']?.toString() ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: tokens.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(code, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.infoText)),
                                ],
                              ),
                            ),
                            if (excessAmt > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tokens.successBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: tokens.successBorder),
                                ),
                                child: Text(
                                  'Excess +${CurrencyFormatter.formatNaira(excessAmt)}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.successText),
                                ),
                              )
                            else if (settledAmt > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tokens.infoBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: tokens.infoBorder),
                                ),
                                child: Text(
                                  'Full Payoff Settled',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.infoText),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(height: 1, color: tokens.borderSubtle),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Paid: ${CurrencyFormatter.formatNaira(amtPaid)}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                            ),
                            Expanded(
                              child: Text('Expected: ${CurrencyFormatter.formatNaira(expInst)}', style: TextStyle(fontSize: 11.5, color: tokens.textSecondary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                remBal <= 0 ? 'Balance: Fully Settled' : 'Balance: ${CurrencyFormatter.formatNaira(remBal)}',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: remBal <= 0 ? tokens.successText : tokens.dangerText),
                              ),
                            ),
                            Text(pDate, style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: Text('Export Audit Records (${sortedRows.length} CSV)'),
                  onPressed: () => _exportRecordsToCsv(
                    rows: sortedRows,
                    columns: const [
                      'Client Code',
                      'Client Name',
                      'Amount Paid',
                      'Expected Installment',
                      'Excess Amount',
                      'Active Credit Settled',
                      'Remaining Balance',
                      'Payment Date',
                    ],
                    filePrefix: 'ICARE_Excess_Payoffs_Audit',
                    recordLabel: 'payoff & excess records',
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: DataTable(
                    columnSpacing: 16,
                    horizontalMargin: 12,
                    headingRowHeight: 40,
                    dataRowMinHeight: 38,
                    dataRowMaxHeight: 44,
                    headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                    columns: [
                      DataColumn(label: Text('Client Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                      DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                      DataColumn(label: Text('Amount Paid', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary)), numeric: true),
                      DataColumn(label: Text('Expected Installment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary)), numeric: true),
                      DataColumn(label: Text('Excess Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary)), numeric: true),
                      DataColumn(label: Text('Active Credit Settled', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary)), numeric: true),
                      DataColumn(label: Text('Remaining Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary)), numeric: true),
                      DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                    ],
                    rows: sortedRows.map((r) {
                      return DataRow(cells: [
                        DataCell(Text(r['Client Code']?.toString() ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary))),
                        DataCell(Text(r['Client Name']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textPrimary))),
                        DataCell(Text(CurrencyFormatter.formatNaira((r['Amount Paid'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((r['Expected Installment'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.textSecondary, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((r['Excess Amount'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.successText, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((r['Active Credit Settled'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.textSecondary, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((r['Remaining Balance'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.dangerText, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(r['Payment Date']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export Excess Payments & Payoffs Audit (CSV)'),
                onPressed: () => _exportRecordsToCsv(
                  rows: sortedRows,
                  columns: const [
                    'Client Code',
                    'Client Name',
                    'Amount Paid',
                    'Expected Installment',
                    'Excess Amount',
                    'Active Credit Settled',
                    'Remaining Balance',
                    'Payment Date',
                  ],
                  filePrefix: 'ICARE_Excess_Payoffs_Audit',
                  recordLabel: 'payoff & excess records',
                ),
              ),
            ],
          );
        },
      );
    }

    final headerBadges = [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: tokens.successBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.successBorder),
        ),
        child: Text(
          '$fullCount Full Payoffs',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.successText),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: tokens.infoBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.infoBorder),
        ),
        child: Text(
          '$excessCount Excess Payers',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.infoText),
        ),
      ),
    ];

    if (isEmbeddedInTab) {
      return Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tokens.infoBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.receipt_long_outlined, size: 18, color: tokens.infoDot),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Excess & Full Payment Audit Ledger',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tokens.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...headerBadges.map((b) => Padding(padding: const EdgeInsets.only(left: 4), child: b)),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.borderSubtle),
            Padding(
              padding: const EdgeInsets.all(16),
              child: buildLedgerBody(),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: ExpansionTile(
        initiallyExpanded: _excessAuditExpanded,
        onExpansionChanged: (v) => setState(() => _excessAuditExpanded = v),
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'Excess and Full Payment Audit Ledger',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tokens.textPrimary),
            ),
            ...headerBadges,
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: buildLedgerBody(),
          ),
        ],
      ),
    );
  }

  // Overdue Recovery Audit Ledger (Phase 9 - Invariants 8 & 9)
  Widget _buildOverdueRecoveryAuditLedger(List<dynamic> rows, Map<String, dynamic> s, {bool isEmbeddedInTab = false}) {
    final tokens = IcareSurfaceTokens.of(context);
    final totRecovered = (s['total_overdue_recovered'] as num?)?.toDouble() ??
        rows.fold<double>(0.0, (acc, r) => acc + ((r['Recovered Amount'] as num?)?.toDouble() ?? 0.0));
    final fullCount = (s['full_recoveries_count'] as num?)?.toInt() ??
        rows.where((r) => (r['Type'] ?? '').toString().toLowerCase().contains('full')).length;

    final sortedRows = List<dynamic>.from(rows)
      ..sort((a, b) => (b['Date'] ?? '').toString().compareTo((a['Date'] ?? '').toString()));

    Widget buildLedgerBody() {
      if (sortedRows.isEmpty) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.restore_outlined, size: 28, color: tokens.textMuted),
              ),
              const SizedBox(height: 12),
              Text(
                'No Overdue Recoveries Recorded',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tokens.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'No delinquent loan arrears were recovered during the selected period.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: tokens.textMuted),
              ),
            ],
          ),
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 750;
          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...sortedRows.map((r) {
                  final code = r['Client Code']?.toString() ?? '';
                  final name = r['Client Name']?.toString() ?? '';
                  final prod = r['Loan Product']?.toString() ?? 'Loan';
                  final rType = r['Type']?.toString() ?? 'Recovery';
                  final isFull = rType.toLowerCase().contains('full');
                  final ovBefore = (r['Overdue Before'] as num?)?.toDouble() ?? 0.0;
                  final recAmt = (r['Recovered Amount'] as num?)?.toDouble() ?? 0.0;
                  final ovAfter = (r['Overdue After'] as num?)?.toDouble() ?? 0.0;
                  final totPaid = (r['Total Repayment'] as num?)?.toDouble() ?? 0.0;
                  final officer = r['Officer']?.toString() ?? '';
                  final dtStr = (r['Timestamp'] ?? r['Date'])?.toString() ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: tokens.textPrimary)),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(code, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.infoText)),
                                      const SizedBox(width: 6),
                                      Text('• $prod', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isFull ? tokens.successBg : tokens.warningBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isFull ? tokens.successBorder : tokens.warningBorder),
                              ),
                              child: Text(
                                isFull ? 'Full Recovery' : 'Partial Recovery',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isFull ? tokens.successText : tokens.warningText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Recovered Arrears', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '+${CurrencyFormatter.formatNaira(recAmt)}',
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: tokens.brandPrimary, fontFeatures: const [FontFeature.tabularFigures()]),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Arrears Track', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${CurrencyFormatter.formatNaira(ovBefore)} → ${CurrencyFormatter.formatNaira(ovAfter)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: ovAfter <= 0 ? tokens.brandPrimary : tokens.dangerText,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Paid: ${CurrencyFormatter.formatNaira(totPaid)} • $officer',
                              style: TextStyle(fontSize: 10.5, color: tokens.textMuted),
                            ),
                            Text(dtStr, style: TextStyle(fontSize: 10.5, color: tokens.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                    headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: tokens.textSecondary, fontSize: 11.5),
                    dataTextStyle: TextStyle(fontSize: 11.5, color: tokens.textPrimary),
                    columnSpacing: 14,
                    horizontalMargin: 12,
                    columns: const [
                      DataColumn(label: Text('Date & Time')),
                      DataColumn(label: Text('Client Code')),
                      DataColumn(label: Text('Client Name')),
                      DataColumn(label: Text('Loan Product')),
                      DataColumn(label: Text('Status')),
                      DataColumn(numeric: true, label: Text('Overdue Before (₦)')),
                      DataColumn(numeric: true, label: Text('Recovered (₦)')),
                      DataColumn(numeric: true, label: Text('Overdue After (₦)')),
                      DataColumn(numeric: true, label: Text('Total Paid (₦)')),
                      DataColumn(label: Text('Officer')),
                    ],
                    rows: sortedRows.map((r) {
                      final rType = r['Type']?.toString() ?? 'Recovery';
                      final isFull = rType.toLowerCase().contains('full');
                      final dtStr = (r['Timestamp'] ?? r['Date'])?.toString() ?? '';

                      return DataRow(
                        cells: [
                          DataCell(Text(dtStr)),
                          DataCell(Text(r['Client Code']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: tokens.infoText))),
                          DataCell(Text(r['Client Name']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: tokens.textPrimary))),
                          DataCell(Text(r['Loan Product']?.toString() ?? '-')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isFull ? tokens.successBg : tokens.warningBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isFull ? 'Full Recovery' : 'Partial Recovery',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isFull ? tokens.successText : tokens.warningText),
                              ),
                            ),
                          ),
                          DataCell(Text(CurrencyFormatter.formatNaira((r['Overdue Before'] as num?)?.toDouble() ?? 0.0))),
                          DataCell(Text(
                            '+${CurrencyFormatter.formatNaira((r['Recovered Amount'] as num?)?.toDouble() ?? 0.0)}',
                            style: TextStyle(fontWeight: FontWeight.w700, color: tokens.brandPrimary),
                          )),
                          DataCell(Text(
                            CurrencyFormatter.formatNaira((r['Overdue After'] as num?)?.toDouble() ?? 0.0),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: ((r['Overdue After'] as num?)?.toDouble() ?? 0.0) <= 0 ? tokens.brandPrimary : tokens.dangerText,
                            ),
                          )),
                          DataCell(Text(CurrencyFormatter.formatNaira((r['Total Repayment'] as num?)?.toDouble() ?? 0.0))),
                          DataCell(Text(r['Officer']?.toString() ?? '-')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    final headerBadges = [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: tokens.brandSoftBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.brandSoftBorder),
        ),
        child: Text(
          '$fullCount Cleared Arrears',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.brandSoftText),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: tokens.successBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.successBorder),
        ),
        child: Text(
          CurrencyFormatter.formatNaira(totRecovered),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.successText),
        ),
      ),
    ];

    if (isEmbeddedInTab) {
      return Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tokens.brandSoftBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.restore_outlined, size: 18, color: tokens.brandPrimary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Overdue Recovery Audit Ledger',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tokens.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...headerBadges.map((b) => Padding(padding: const EdgeInsets.only(left: 4), child: b)),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.borderSubtle),
            Padding(
              padding: const EdgeInsets.all(16),
              child: buildLedgerBody(),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _recoveryAuditExpanded,
          onExpansionChanged: (v) => setState(() => _recoveryAuditExpanded = v),
          iconColor: tokens.textMuted,
          collapsedIconColor: tokens.textMuted,
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Overdue Recovery Audit Ledger',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tokens.textPrimary),
              ),
              ...headerBadges,
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: buildLedgerBody(),
            ),
          ],
        ),
      ),
    );
  }

  // Master Audit Ledger Container with Segmented Selector
  Widget _buildCombinedAuditLedger(
    List<dynamic> payoffRows,
    List<dynamic> recoveryRows,
    Map<String, dynamic> summary, {
    bool isEmbeddedInTab = false,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-Tab Switcher
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _auditLedgerSubView = 'Excess & Payoffs'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _auditLedgerSubView == 'Excess & Payoffs' ? tokens.surfaceElevated : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _auditLedgerSubView == 'Excess & Payoffs'
                          ? const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 1))]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 15,
                          color: _auditLedgerSubView == 'Excess & Payoffs' ? tokens.brandAccent : tokens.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Excess & Payoffs (${payoffRows.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _auditLedgerSubView == 'Excess & Payoffs' ? FontWeight.w700 : FontWeight.w600,
                            color: _auditLedgerSubView == 'Excess & Payoffs' ? tokens.brandAccent : tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _auditLedgerSubView = 'Overdue Recoveries'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _auditLedgerSubView == 'Overdue Recoveries' ? tokens.surfaceElevated : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _auditLedgerSubView == 'Overdue Recoveries'
                          ? const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 1))]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restore_outlined,
                          size: 15,
                          color: _auditLedgerSubView == 'Overdue Recoveries' ? tokens.successText : tokens.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Overdue Recoveries (${recoveryRows.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _auditLedgerSubView == 'Overdue Recoveries' ? FontWeight.w700 : FontWeight.w600,
                            color: _auditLedgerSubView == 'Overdue Recoveries' ? tokens.successText : tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_auditLedgerSubView == 'Excess & Payoffs')
          _buildExcessPayoffAuditLedger(payoffRows, summary, isEmbeddedInTab: isEmbeddedInTab)
        else
          _buildOverdueRecoveryAuditLedger(recoveryRows, summary, isEmbeddedInTab: isEmbeddedInTab),
      ],
    );
  }

  // Category Intelligence Cards
  Widget _buildCategoryIntelligenceCards(Map<String, dynamic> catSum) {
    final tokens = IcareSurfaceTokens.of(context);
    final w12 = catSum['12_week'] as Map<String, dynamic>? ?? {};
    final w24 = catSum['24_week'] as Map<String, dynamic>? ?? {};
    final astAll = catSum['asset_all'] as Map<String, dynamic>? ?? {};
    final dly = catSum['daily'] as Map<String, dynamic>? ?? {};
    final mth = catSum['monthly'] as Map<String, dynamic>? ?? {};

    final cards = [
      {'title': '12-Week Loans', 'data': w12},
      {'title': '24-Week Loans', 'data': w24},
      {'title': 'Asset Loans', 'data': astAll},
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
      final title = c['title'] as String;

      IconData cardIcon = Icons.calendar_today_rounded;
      Color cardColor = tokens.infoDot;
      if (title.contains('24-Week')) {
        cardIcon = Icons.date_range_rounded;
        cardColor = tokens.isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
      } else if (title.contains('Asset')) {
        cardIcon = Icons.shopping_bag_outlined;
        cardColor = tokens.warningDot;
      } else if (title.contains('Daily')) {
        cardIcon = Icons.today_rounded;
        cardColor = tokens.brandAccent;
      } else if (title.contains('Monthly')) {
        cardIcon = Icons.event_note_rounded;
        cardColor = tokens.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tokens.borderSubtle),
          boxShadow: const [
            BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: tokens.isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(cardIcon, size: 13, color: cardColor),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: tokens.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('Loans', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Credit: ${CurrencyFormatter.formatNaira(cred)}',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
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
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: out > 0 ? tokens.dangerText : tokens.successText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('Cash: $cash · Asset: $asset', style: TextStyle(fontSize: 10.5, color: tokens.textMuted)),
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
              children: List.generate(cards.length, (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 12),
                  child: buildCard(cards[i]),
                ),
              )),
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: buildCard(cards[4]),
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
    final tokens = IcareSurfaceTokens.of(context);

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
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: ExpansionTile(
        initiallyExpanded: _groupMatrixExpanded,
        onExpansionChanged: (v) => setState(() => _groupMatrixExpanded = v),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Group-by-Product Distribution Matrix',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tokens.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              onTap: () => setState(() => _matrixCardView = !_matrixCardView),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _matrixCardView ? tokens.infoBg : tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _matrixCardView ? tokens.infoBorder : tokens.borderStrong),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_matrixCardView ? Icons.table_chart_outlined : Icons.view_agenda_outlined, size: 12, color: tokens.infoText),
                    const SizedBox(width: 4),
                    Text(_matrixCardView ? 'Matrix' : 'Cards', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.infoText)),
                  ],
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: _matrixCardView
                ? Column(
                    children: rows.map((r) {
                      final gName = r['Group Name']?.toString() ?? 'Group';
                      final mDay = r['Meeting Day']?.toString() ?? 'N/A';
                      final actLoans = (r['Total Active Loans'] as num?)?.toInt() ?? 0;
                      final actCred = (r['Total Active Credit'] as num?)?.toDouble() ?? 0.0;
                      final outBal = (r['Total Outstanding Balance'] as num?)?.toDouble() ?? 0.0;
                      final p12w = (r['12W Cash'] as num?)?.toInt() ?? 0;
                      final p12wa = (r['12W Asset'] as num?)?.toInt() ?? 0;
                      final p24w = (r['24W Cash'] as num?)?.toInt() ?? 0;
                      final p24wa = (r['24W Asset'] as num?)?.toInt() ?? 0;
                      final pDaily = (r['Daily'] as num?)?.toInt() ?? 0;
                      final pMonthly = (r['Monthly'] as num?)?.toInt() ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(gName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tokens.textPrimary)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tokens.infoBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: tokens.infoBorder),
                                  ),
                                  child: Text(mDay, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tokens.infoText)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text('Active: $actLoans loans · ${CurrencyFormatter.formatNaira(actCred)}', style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
                                ),
                                Text('Bal: ${CurrencyFormatter.formatNaira(outBal)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.dangerText)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              children: [
                                if (p12w > 0) _buildMatrixBadge('12W Cash: $p12w', tokens.infoText),
                                if (p12wa > 0) _buildMatrixBadge('12W Asset: $p12wa', tokens.brandAccent),
                                if (p24w > 0) _buildMatrixBadge('24W Cash: $p24w', tokens.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED)),
                                if (p24wa > 0) _buildMatrixBadge('24W Asset: $p24wa', tokens.isDark ? const Color(0xFFF472B6) : const Color(0xFFC026D3)),
                                if (pDaily > 0) _buildMatrixBadge('Daily: $pDaily', tokens.warningText),
                                if (pMonthly > 0) _buildMatrixBadge('Monthly: $pMonthly', tokens.successText),
                                if (p12w == 0 && p12wa == 0 && p24w == 0 && p24wa == 0 && pDaily == 0 && pMonthly == 0)
                                  _buildMatrixBadge('No Active Products', tokens.textMuted),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: tokens.surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 16, color: tokens.infoDot),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Swipe horizontally to view all product columns & loan balances',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: DataTable(
                            columnSpacing: 14,
                            horizontalMargin: 8,
                            headingRowHeight: 38,
                            dataRowMinHeight: 36,
                            dataRowMaxHeight: 42,
                            headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                            columns: [
                              DataColumn(label: Text('Group Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                              DataColumn(label: Text('Meeting Day', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                              DataColumn(label: Text('12W Cash', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary)), numeric: true),
                              DataColumn(label: Text('12W Asset', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary)), numeric: true),
                              DataColumn(label: Text('24W Cash', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary)), numeric: true),
                              DataColumn(label: Text('24W Asset', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary)), numeric: true),
                              DataColumn(label: Text('Daily', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary)), numeric: true),
                              DataColumn(label: Text('Monthly', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary)), numeric: true),
                              DataColumn(label: Text('Total Active Loans', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary)), numeric: true),
                              DataColumn(label: Text('Total Active Credit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary)), numeric: true),
                              DataColumn(label: Text('Total Outstanding Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary)), numeric: true),
                            ],
                            rows: [
                              ...rows.map((r) => DataRow(cells: [
                                DataCell(Text(r['Group Name']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: tokens.textPrimary))),
                                DataCell(Text(r['Meeting Day']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                                DataCell(Text('${r['12W Cash'] ?? 0}', style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                DataCell(Text('${r['12W Asset'] ?? 0}', style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                DataCell(Text('${r['24W Cash'] ?? 0}', style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                DataCell(Text('${r['24W Asset'] ?? 0}', style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                DataCell(Text('${r['Daily'] ?? 0}', style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                DataCell(Text('${r['Monthly'] ?? 0}', style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                DataCell(Text('${r['Total Active Loans'] ?? 0}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                DataCell(Text(CurrencyFormatter.formatNaira((r['Total Active Credit'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                DataCell(Text(CurrencyFormatter.formatNaira((r['Total Outstanding Balance'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.dangerText, fontFeatures: const [FontFeature.tabularFigures()]))),
                              ])),
                              // TOTALS ROW
                              DataRow(
                                color: WidgetStateProperty.all(tokens.surfaceSubtle),
                                cells: [
                                  DataCell(Text('TOTALS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: tokens.textPrimary))),
                                  DataCell(Text('—', style: TextStyle(fontSize: 12, color: tokens.textMuted))),
                                  DataCell(Text('$tot12W', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                  DataCell(Text('$tot12WA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                  DataCell(Text('$tot24W', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                  DataCell(Text('$tot24WA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                  DataCell(Text('$totDaily', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                  DataCell(Text('$totMonthly', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                  DataCell(Text('$totActiveLoans', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: tokens.infoText, fontFeatures: const [FontFeature.tabularFigures()]))),
                                  DataCell(Text(CurrencyFormatter.formatNaira(totActiveCredit), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                  DataCell(Text(CurrencyFormatter.formatNaira(totOutstanding), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: tokens.dangerText, fontFeatures: const [FontFeature.tabularFigures()]))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixBadge(String label, Color color) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: tokens.isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
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
    final tokens = IcareSurfaceTokens.of(context);
    final viewMode = ref.watch(portfolioViewModeProvider);
    final quickFilter = ref.watch(portfolioQuickFilterProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
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
                      onTap: () {
                        if (mode == 'Group Aggregate Summary' &&
                            ref.read(portfolioQuickFilterProvider) == 'All Registered Clients') {
                          ref.read(portfolioQuickFilterProvider.notifier).state = 'All Active Loans';
                        }
                        ref.read(portfolioViewModeProvider.notifier).state = mode;
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? tokens.infoBg : tokens.surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isSel ? tokens.infoDot : tokens.borderStrong),
                        ),
                        child: Text(
                          mode,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? tokens.infoText : tokens.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );

              final allowedFilters = <String>[
                'All Active Loans',
                'Overdue Loans',
                '12-Week Loans',
                '24-Week Loans',
                'Asset Loans',
                'Daily Loans',
                'Monthly Loans',
                if (viewMode == 'Detailed Client List') 'All Registered Clients',
              ];

              final validQuickFilter = allowedFilters.contains(quickFilter)
                  ? quickFilter
                  : 'All Active Loans';

              final quickFilterDropdown = DropdownButtonFormField<String>(
                value: validQuickFilter,
                dropdownColor: tokens.surfaceElevated,
                decoration: InputDecoration(
                  labelText: 'Quick Filter',
                  labelStyle: TextStyle(color: tokens.textMuted),
                  filled: true,
                  fillColor: tokens.surfaceSubtle,
                  border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: TextStyle(fontSize: 12, color: tokens.textPrimary),
                items: allowedFilters
                    .map((f) => DropdownMenuItem(value: f, child: Text(f, style: TextStyle(color: tokens.textPrimary))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) ref.read(portfolioQuickFilterProvider.notifier).state = val;
                },
              );

              final searchField = TextField(
                controller: _clientSearchCtrl,
                decoration: InputDecoration(
                  hintText: viewMode == 'Detailed Client List' ? 'Search client...' : 'Search group...',
                  hintStyle: TextStyle(color: tokens.textMuted),
                  prefixIcon: Icon(Icons.search, size: 16, color: tokens.textMuted),
                  filled: true,
                  fillColor: tokens.surfaceSubtle,
                  border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: TextStyle(fontSize: 12, color: tokens.textPrimary),
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
            _buildGroupAggregateTable(groupTable, clientTable, quickFilter, _clientSearchCtrl.text),
        ],
      ),
    );
  }

  Widget _buildDetailedClientTable(List<dynamic> clients, String quickFilter, String searchQuery) {
    final tokens = IcareSurfaceTokens.of(context);
    bool isOverdueRecord(dynamic c) {
      final overdueAmt = (c['Overdue Amount'] as num?)?.toDouble() ?? 0.0;
      final statusVal = (c['Status']?.toString() ?? '').toLowerCase();
      return overdueAmt > 0.01 || statusVal == 'overdue';
    }

    var filtered = clients.where((c) {
      final cat = c['Loan Category']?.toString() ?? '';
      final prod = c['Loan Product']?.toString() ?? '';
      final activeLoan = (c['Active Loan'] as num?)?.toDouble() ?? 0.0;
      if (quickFilter == 'Overdue Loans' && !isOverdueRecord(c)) return false;
      if (quickFilter == '12-Week Loans' && cat != '12-Week Loans') return false;
      if (quickFilter == '24-Week Loans' && cat != '24-Week Loans') return false;
      if (quickFilter == 'Asset Loans' && !prod.toLowerCase().contains('asset')) return false;
      if (quickFilter == 'Daily Loans' && cat != 'Daily Loans') return false;
      if (quickFilter == 'Monthly Loans' && cat != 'Monthly Loans') return false;
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

    final overdueRows = filtered.where(isOverdueRecord).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No matching client records found for this filter.', style: TextStyle(color: tokens.textMuted)),
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
                final lifecycle = c['Lifecycle Status']?.toString() ?? 'On Loan';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: tokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.borderSubtle),
                    boxShadow: tokens.isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
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
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: tokens.infoBg,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: tokens.infoBorder),
                                          ),
                                          child: Text(
                                            code,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: tokens.infoText,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            group.isNotEmpty ? '$group • $product' : product,
                                            style: TextStyle(fontSize: 12, color: tokens.textMuted),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildLifecycleBadge(lifecycle),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(height: 1, color: tokens.borderSubtle),
                          const SizedBox(height: 12),
                          // 3-Column Financial Metric Strip
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Outstanding', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.formatNaira(outBal),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.dangerText,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Savings', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.formatNaira(savings),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.brandPrimary,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Active Loan', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.formatNaira(activeLoan),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.textPrimary,
                                        fontFeatures: const [FontFeature.tabularFigures()],
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
                                color: tokens.infoBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_upward, size: 12, color: tokens.infoText),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Period Excess Paid: ${CurrencyFormatter.formatNaira(excessPaid)}',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.infoText),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'View 360° Dossier',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.infoText),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward, size: 14, color: tokens.infoText),
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
                      side: BorderSide(color: tokens.borderStrong),
                      foregroundColor: tokens.textPrimary,
                    ),
                    onPressed: () {
                      setState(() {
                        _mobileClientLimit += 20;
                      });
                    },
                    child: Text(
                      'Load More (Showing ${_mobileClientLimit > filtered.length ? filtered.length : _mobileClientLimit} of ${filtered.length} Clients)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
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
                    child: Text('Show All Clients', style: TextStyle(fontSize: 12, color: tokens.infoText)),
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
                    child: Text('Show Top 10 Only', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
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
                    headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                    headingTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textSecondary),
                    dataTextStyle: TextStyle(fontSize: 12, color: tokens.textPrimary),
                    columns: const [
                      DataColumn(label: Text('Client Code')),
                      DataColumn(label: Text('Client Name')),
                      DataColumn(label: Text('Group')),
                      DataColumn(label: Text('Loan Product')),
                      DataColumn(label: Text('Savings Balance'), numeric: true),
                      DataColumn(label: Text('Principal Loan'), numeric: true),
                      DataColumn(label: Text('Active Loan'), numeric: true),
                      DataColumn(label: Text('Outstanding Balance'), numeric: true),
                      DataColumn(label: Text('Total Paid'), numeric: true),
                      DataColumn(label: Text('Period Excess Paid'), numeric: true),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Lifecycle Status')),
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
                            child: Text(c['Client Code']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.infoText)),
                          ),
                        ),
                        DataCell(Text(c['Client Name']?.toString() ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary))),
                        DataCell(Text(c['Group']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                        DataCell(Text(c['Loan Product']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                        DataCell(Text(CurrencyFormatter.formatNaira((c['Savings Balance'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.brandPrimary, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((c['Principal Loan'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((c['Active Loan'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((c['Outstanding Balance'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.dangerText, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((c['Total Paid'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((c['Period Excess Paid'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.infoText, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(_buildStatusBadge(c['Status']?.toString() ?? 'Active')),
                        DataCell(_buildLifecycleBadge(c['Lifecycle Status']?.toString() ?? 'On Loan')),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.download, size: 16),
                  label: Text('Export Filtered Portfolio (${filtered.length} Clients CSV)'),
                  onPressed: () => _exportRecordsToCsv(
                    rows: filtered,
                    columns: const [
                      'Client Code',
                      'Client Name',
                      'Group',
                      'Loan Product',
                      'Savings Balance',
                      'Principal Loan',
                      'Active Loan',
                      'Outstanding Balance',
                      'Overdue Amount',
                      'Total Paid',
                      'Period Excess Paid',
                      'Status',
                      'Lifecycle Status',
                    ],
                    filePrefix: 'ICARE_Client_Portfolio',
                    recordLabel: 'client records',
                  ),
                ),
                if (overdueRows.isNotEmpty)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.dangerText,
                      side: BorderSide(color: tokens.dangerBorder),
                    ),
                    icon: const Icon(Icons.warning_amber_rounded, size: 16),
                    label: Text('Export Overdue List (${overdueRows.length} Clients CSV)'),
                    onPressed: () => _exportRecordsToCsv(
                      rows: overdueRows,
                      columns: const [
                        'Client Code',
                        'Client Name',
                        'Group',
                        'Loan Product',
                        'Active Loan',
                        'Outstanding Balance',
                        'Overdue Amount',
                        'Total Paid',
                        'Status',
                        'Lifecycle Status',
                      ],
                      filePrefix: 'ICARE_Overdue_Portfolio',
                      recordLabel: 'overdue loan records',
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupAggregateTable(List<dynamic> groups, List<dynamic> clients, String quickFilter, String searchQuery) {
    final tokens = IcareSurfaceTokens.of(context);
    Set<String>? matchingGroupNames;
    if (quickFilter != 'All Active Loans' && quickFilter != 'All Registered Clients') {
      matchingGroupNames = clients.where((c) {
        final cat = c['Loan Category']?.toString() ?? '';
        final prod = c['Loan Product']?.toString() ?? '';
        final activeLoan = (c['Active Loan'] as num?)?.toDouble() ?? 0.0;
        final overdueAmt = (c['Overdue Amount'] as num?)?.toDouble() ?? 0.0;
        final statusVal = (c['Status']?.toString() ?? '').toLowerCase();
        if (activeLoan <= 0) return false;
        if (quickFilter == 'Overdue Loans' && overdueAmt <= 0.01 && statusVal != 'overdue') return false;
        if (quickFilter == '12-Week Loans' && cat != '12-Week Loans') return false;
        if (quickFilter == '24-Week Loans' && cat != '24-Week Loans') return false;
        if (quickFilter == 'Asset Loans' && !prod.toLowerCase().contains('asset')) return false;
        if (quickFilter == 'Daily Loans' && cat != 'Daily Loans') return false;
        if (quickFilter == 'Monthly Loans' && cat != 'Monthly Loans') return false;
        return true;
      }).map((c) => (c['Group'] ?? '').toString().toLowerCase()).toSet();
    }

    var filtered = groups.where((g) {
      final grpName = (g['Group Name']?.toString() ?? '').toLowerCase();
      final actLoan = (g['Total Active Loan'] as num?)?.toDouble() ?? 0.0;
      if (quickFilter == 'All Active Loans' && actLoan <= 0) return false;
      if (matchingGroupNames != null && !matchingGroupNames.contains(grpName)) return false;
      if (searchQuery.isNotEmpty) {
        if (!grpName.contains(searchQuery.toLowerCase())) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No matching group records found for this product filter.', style: TextStyle(color: tokens.textMuted)),
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
              // Responsive Mobile Group Touch Cards
              ...filtered.map((g) {
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
                    color: tokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.borderSubtle),
                    boxShadow: tokens.isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
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
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: tokens.infoBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: tokens.infoBorder),
                            ),
                            child: Text(
                              '$clientsCount Clients',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.infoText),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: tokens.borderSubtle),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Outstanding', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatNaira(outBal),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.dangerText,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Savings', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatNaira(savings),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.brandPrimary,
                                    fontFeatures: const [FontFeature.tabularFigures()],
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
                                Text('Active Loan', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatNaira(activeLoan),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textPrimary,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Paid', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatNaira(totalPaid),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.infoText,
                                    fontFeatures: const [FontFeature.tabularFigures()],
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
                    headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                    headingTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textSecondary),
                    dataTextStyle: TextStyle(fontSize: 12, color: tokens.textPrimary),
                    columns: const [
                      DataColumn(label: Text('Group Name')),
                      DataColumn(label: Text('Total Clients'), numeric: true),
                      DataColumn(label: Text('Total Savings Balance'), numeric: true),
                      DataColumn(label: Text('Total Active Loan'), numeric: true),
                      DataColumn(label: Text('Total Outstanding Balance'), numeric: true),
                      DataColumn(label: Text('Total Fixed Repayment'), numeric: true),
                      DataColumn(label: Text('Total Paid'), numeric: true),
                    ],
                    rows: filtered.map((g) {
                      return DataRow(cells: [
                        DataCell(Text(g['Group Name']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: tokens.textPrimary))),
                        DataCell(Text('${g['Total Clients'] ?? 0}', style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((g['Total Savings Balance'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.brandPrimary, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((g['Total Active Loan'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((g['Total Outstanding Balance'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.dangerText, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((g['Total Fixed Repayment'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira((g['Total Paid'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.brandPrimaryDark,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.download, size: 16),
              label: Text('Export Group Aggregate (${filtered.length} Groups CSV)'),
              onPressed: () => _exportRecordsToCsv(
                rows: filtered,
                columns: const [
                  'Group Name',
                  'Total Clients',
                  'Total Savings Balance',
                  'Total Active Loan',
                  'Total Outstanding Balance',
                  'Total Fixed Repayment',
                  'Total Paid',
                ],
                filePrefix: 'ICARE_Group_Portfolio',
                recordLabel: 'group records',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    final tokens = IcareSurfaceTokens.of(context);
    final s = status.toUpperCase();
    Color bg = tokens.surfaceSubtle;
    Color fg = tokens.textSecondary;
    if (s.contains('ACTIVE')) {
      bg = tokens.successBg;
      fg = tokens.successText;
    } else if (s.contains('COMPLETED') || s.contains('SETTLED')) {
      bg = tokens.infoBg;
      fg = tokens.infoText;
    } else if (s.contains('OVERDUE') || s.contains('DEFAULT')) {
      bg = tokens.dangerBg;
      fg = tokens.dangerText;
    } else if (s.contains('REVERSED') || s.contains('CANCELLED')) {
      bg = tokens.warningBg;
      fg = tokens.warningText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _buildLifecycleBadge(String rawStatus) {
    final tokens = IcareSurfaceTokens.of(context);
    const Map<String, String> uuidToStatus = {
      '11111111-1111-1111-1111-111111110001': 'Registered',
      '11111111-1111-1111-1111-111111110002': 'Pending Loan',
      '11111111-1111-1111-1111-111111110003': 'On Loan',
      '11111111-1111-1111-1111-111111110004': 'Completed',
      '11111111-1111-1111-1111-111111110005': 'Dormant',
      '11111111-1111-1111-1111-111111110006': 'Inactive (Savings Only)',
      '11111111-1111-1111-1111-111111110007': 'Closed',
      '11111111-1111-1111-1111-111111110008': 'Suspended',
      '11111111-1111-1111-1111-111111110009': 'Defaulter',
    };
    String cleanStatus = uuidToStatus[rawStatus] ?? rawStatus;
    if (cleanStatus.length > 25) {
      cleanStatus = 'On Loan';
    }
    final s = cleanStatus.toUpperCase();
    Color bg = tokens.surfaceSubtle;
    Color fg = tokens.textSecondary;
    if (s.contains('ON LOAN')) {
      bg = tokens.successBg;
      fg = tokens.successText;
    } else if (s.contains('REGISTERED') || s.contains('PENDING')) {
      bg = tokens.infoBg;
      fg = tokens.infoText;
    } else if (s.contains('COMPLETED')) {
      bg = tokens.brandSoftBg;
      fg = tokens.brandSoftText;
    } else if (s.contains('SAVINGS ONLY') || s.contains('INACTIVE')) {
      bg = tokens.warningBg;
      fg = tokens.warningText;
    } else if (s.contains('DORMANT') || s.contains('SUSPENDED') || s.contains('DEFAULTER')) {
      bg = tokens.dangerBg;
      fg = tokens.dangerText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(cleanStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  // ===========================================================================
  // TAB 2: CLIENT DOSSIER & INQUIRY (360° VIEW)
  // ===========================================================================
  Widget _buildClientDossierTab(AsyncValue<Map<String, dynamic>> portfolioAsync) {
    final tokens = IcareSurfaceTokens.of(context);
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
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: tokens.infoDot),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: clientCodes.contains(activeCode) ? activeCode : (clientCodes.isNotEmpty ? clientCodes.first : null),
                  dropdownColor: tokens.surfaceElevated,
                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Search & Select Client Account',
                    labelStyle: TextStyle(color: tokens.textMuted),
                    filled: true,
                    fillColor: tokens.surfaceSubtle,
                    border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  isExpanded: true,
                  items: clientCodes.map((code) {
                    final label = clientLookup[code]?.toString() ?? code;
                    return DropdownMenuItem(value: code, child: Text(label, style: TextStyle(color: tokens.textPrimary), overflow: TextOverflow.ellipsis));
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
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Text('No client accounts available in current scope.', style: TextStyle(color: tokens.textMuted)),
            ),
          )
        else
          _buildDossierDrilldown(activeCode),
      ],
    );
  }

  Widget _buildDossierDrilldown(String clientCode) {
    final tokens = IcareSurfaceTokens.of(context);
    final dossierAsync = ref.watch(clientDossierDataProvider(clientCode));
    return dossierAsync.when(
      loading: () => const IcareListSkeleton(itemCount: 6),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: tokens.dangerBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.dangerBorder)),
        child: Text(AppErrorDetails.from(err).message, style: TextStyle(color: tokens.dangerText)),
      ),
      data: (dossier) {
        final cInfo = dossier['customer_info'] as Map<String, dynamic>? ?? {};
        final gInfo = dossier['guarantor_info'] as Map<String, dynamic>? ?? {};
        final banner = dossier['executive_banner'] as Map<String, dynamic>? ?? {};
        final loans = dossier['loan_history'] as List<dynamic>? ?? [];
        final repayments = dossier['repayment_ledger'] as List<dynamic>? ?? [];
        final savings = dossier['savings_ledger'] as List<dynamic>? ?? [];
        final comp = dossier['collection_compliance'] as Map<String, dynamic>? ?? {};
        final compTable = (comp['compliance_table'] ?? comp['rows']) as List<dynamic>? ?? [];
        final loanSchedule = dossier['loan_schedule'] as List<dynamic>? ?? [];
        final riskRating = dossier['risk_rating'] as Map<String, dynamic>? ?? {};
        final lifecycle = dossier['lifecycle_status'] as Map<String, dynamic>? ?? {};
        final statusHistory = (dossier['status_history'] ?? lifecycle['history']) as List<dynamic>? ?? [];
        final auditTrail = (dossier['audit_trail'] ?? dossier['audit_history']) as List<dynamic>? ?? [];
        final name = cInfo['name']?.toString() ?? 'Client Profile';
        final subTab = ref.watch(clientDossierSubTabProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Executive Header Banner (4 Metrics)
            Text(
              '$name ($clientCode)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tokens.textPrimary),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final c1 = _buildKpiCard('Total Active Credit', CurrencyFormatter.formatNaira((banner['total_active_credit'] as num?)?.toDouble() ?? 0.0), 'Principal Net of Gap Fee', tokens.textPrimary, icon: Icons.credit_card_outlined);
                final c2 = _buildKpiCard('Outstanding Balance', CurrencyFormatter.formatNaira((banner['outstanding_balance'] as num?)?.toDouble() ?? 0.0), 'Unpaid Balance', tokens.dangerDot, isAlert: ((banner['outstanding_balance'] as num?)?.toDouble() ?? 0.0) > 0, icon: Icons.hourglass_bottom_outlined);
                final c3 = _buildKpiCard('Savings Balance', CurrencyFormatter.formatNaira((banner['savings_balance'] as num?)?.toDouble() ?? 0.0), 'Available Balance', tokens.brandPrimary, icon: Icons.savings_outlined);
                final c4 = _buildKpiCard('Account Status', banner['account_status']?.toString() ?? 'Active', 'Authoritative Standing', tokens.brandPrimaryDark, icon: Icons.verified_user_outlined);
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
            else if (subTab == 'Loan Schedule')
              _buildLoanScheduleSubtab(loanSchedule)
            else if (subTab == 'Repayment Ledger')
              _buildRepaymentLedgerSubtab(repayments)
            else if (subTab == 'Savings Ledger')
              _buildSavingsLedgerSubtab(savings)
            else if (subTab == 'Collection History')
              _buildCollectionHistorySubtab(comp, compTable)
            else if (subTab == 'Risk Rating')
              _buildRiskRatingSubtab(riskRating)
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
    final tokens = IcareSurfaceTokens.of(context);
    final subtabs = [
      {'name': 'Customer Profile', 'icon': Icons.badge_outlined},
      {'name': 'Loan History', 'icon': Icons.history_edu_outlined},
      {'name': 'Loan Schedule', 'icon': Icons.calendar_month_outlined},
      {'name': 'Repayment Ledger', 'icon': Icons.receipt_long_outlined},
      {'name': 'Savings Ledger', 'icon': Icons.account_balance_wallet_outlined},
      {'name': 'Collection History', 'icon': Icons.event_available_outlined},
      {'name': 'Risk Rating', 'icon': Icons.verified_outlined},
      {'name': 'Lifecycle Status', 'icon': Icons.sync_alt_outlined},
      {'name': 'Audit Trail', 'icon': Icons.security_outlined},
    ];
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      padding: const EdgeInsets.all(4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: subtabs.map((tab) {
            final name = tab['name'] as String;
            final icon = tab['icon'] as IconData;
            final isSel = activeTab == name;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => ref.read(clientDossierSubTabProvider.notifier).state = name,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? tokens.brandPrimaryDark : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSel && !tokens.isDark
                        ? const [
                            BoxShadow(color: Color(0x1A064E3B), blurRadius: 4, offset: Offset(0, 1)),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 15,
                        color: isSel ? const Color(0xFFA7F3D0) : tokens.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? Colors.white : tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // 1. Customer Profile Subtab
  Widget _buildCustomerProfileSubtab(Map<String, dynamic> c, Map<String, dynamic> g) {
    final tokens = IcareSurfaceTokens.of(context);
    final authState = ref.watch(authControllerProvider);
    final role = authState is AuthStateAuthenticated ? authState.user.role : 'CO';
    final isOfficer = role == 'CO' || role == 'Credit Officer' || role == 'Officer' || role == 'CREDIT_OFFICER';
    final name = c['name']?.toString() ?? 'N/A';
    final initials = name.split(' ').map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').take(2).join();
    final clientCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Client Profile & Bio', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: tokens.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.infoBg,
                ),
                child: Center(
                  child: Text(
                    initials.isNotEmpty ? initials : 'CL',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tokens.infoText),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Code: ${c['client_code'] ?? "N/A"} · Nickname: ${c['nickname'] ?? "None"}', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildLifecycleBadge(c['status']?.toString() ?? 'Active'),
                        if (!isOfficer) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              side: BorderSide(color: tokens.infoDot),
                            ),
                            icon: Icon(Icons.swap_horiz_rounded, size: 14, color: tokens.infoText),
                            label: Text('Transfer Portfolio', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.infoText)),
                            onPressed: () {
                              final cid = c['id']?.toString() ?? c['client_id']?.toString() ?? '';
                              final curBranchId = c['branch_id']?.toString();
                              final curOfficerId = c['officer_id']?.toString();
                              _showTransferClientDialog(
                                context,
                                cid,
                                name,
                                currentBranchId: curBranchId,
                                currentOfficerId: curOfficerId,
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: tokens.borderSubtle),
          const SizedBox(height: 8),
          _buildInfoRow('Phone Number', (c['phone_number'] ?? c['phone'])?.toString() ?? 'N/A'),
          _buildInfoRow('Residential Address', (c['residential_address'] ?? c['address'])?.toString() ?? 'N/A'),
          _buildInfoRow('Registration Date', (c['registration_date'] ?? c['created_at'])?.toString() ?? 'N/A'),
          _buildInfoRow('Solidarity Group', (c['solidarity_group'] ?? c['group_name'])?.toString() ?? 'N/A'),
          _buildInfoRow('Credit Officer', c['officer_name']?.toString() ?? 'Unassigned'),
          _buildInfoRow('Branch', c['branch_name']?.toString() ?? 'Unassigned'),
        ],
      ),
    );

    final guarantorCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Guarantor Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: tokens.textPrimary)),
          const SizedBox(height: 16),
          _buildInfoRow('Guarantor Name', g['name']?.toString() ?? 'N/A'),
          _buildInfoRow('Relationship', g['relationship']?.toString() ?? 'N/A'),
          _buildInfoRow('Guarantor Phone', g['phone']?.toString() ?? 'N/A'),
          const SizedBox(height: 16),
          Text('KYC Verification Standing', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: tokens.textPrimary)),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final gName = g['name']?.toString().trim() ?? '';
              final isVerified = g['is_verified'] == true || (gName.isNotEmpty && gName != 'N/A');
              if (isVerified) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.successBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.successBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, size: 18, color: tokens.successText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Guarantor verified under credit policy',
                          style: TextStyle(fontSize: 12, color: tokens.successText, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.warningBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.warningBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: tokens.warningText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No guarantor registered during initial onboarding',
                          style: TextStyle(fontSize: 12, color: tokens.warningText, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
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
    final tokens = IcareSurfaceTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 12, color: tokens.textMuted, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary))),
        ],
      ),
    );
  }

  // 2. Loan History Subtab

  Widget _buildLoanHistorySubtab(List<dynamic> loans) {
    final tokens = IcareSurfaceTokens.of(context);
    if (loans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.borderSubtle)),
        child: Center(child: Text('No historical loan records found for this client.', style: TextStyle(color: tokens.textMuted))),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 750) {
          return Column(
            children: loans.map((l) {
              final princ = (l['principal'] as num?)?.toDouble() ?? 0.0;
              final cred = (l['active_credit'] as num?)?.toDouble() ?? 0.0;
              final inst = (l['expected_installment'] as num?)?.toDouble() ?? 0.0;
              final rem = (l['remaining_balance'] as num?)?.toDouble() ?? 0.0;
              final status = l['status']?.toString() ?? 'Active';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.borderSubtle),
                  boxShadow: tokens.isDark
                      ? null
                      : const [
                          BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 1)),
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
                            l['product_name']?.toString() ?? 'Loan Facility',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Category: ${l['category'] ?? "General"} · Disbursed: ${l['disbursement_date'] ?? "N/A"}',
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    ),
                    Divider(color: tokens.borderSubtle, height: 18),
                    Row(
                      children: [
                        Expanded(child: _buildMicroKpi('Loan Principal', CurrencyFormatter.formatNaira(princ), tokens.textPrimary)),
                        Expanded(child: _buildMicroKpi('Active Credit', CurrencyFormatter.formatNaira(cred), tokens.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildMicroKpi('Expected Installment', CurrencyFormatter.formatNaira(inst), tokens.textPrimary)),
                        Expanded(child: _buildMicroKpi('Remaining Balance', CurrencyFormatter.formatNaira(rem), rem > 0 ? tokens.dangerText : tokens.brandPrimary)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.borderSubtle)),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                headingTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textSecondary),
                dataTextStyle: TextStyle(fontSize: 12, color: tokens.textPrimary),
                columns: const [
                  DataColumn(label: Text('Disbursement Date')),
                  DataColumn(label: Text('Product')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Loan Principal'), numeric: true),
                  DataColumn(label: Text('Active Credit'), numeric: true),
                  DataColumn(label: Text('Expected Installment'), numeric: true),
                  DataColumn(label: Text('Remaining Balance'), numeric: true),
                  DataColumn(label: Text('Status')),
                ],
                rows: loans.map((l) {
                  final rem = (l['remaining_balance'] as num?)?.toDouble() ?? 0.0;
                  return DataRow(cells: [
                    DataCell(Text(l['disbursement_date']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textPrimary))),
                    DataCell(Text(l['product_name']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: tokens.textPrimary))),
                    DataCell(Text(l['category']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                    DataCell(Text(CurrencyFormatter.formatNaira((l['principal'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                    DataCell(Text(CurrencyFormatter.formatNaira((l['active_credit'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                    DataCell(Text(CurrencyFormatter.formatNaira((l['expected_installment'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                    DataCell(Text(CurrencyFormatter.formatNaira(rem), style: TextStyle(fontSize: 12, color: rem > 0 ? tokens.dangerText : tokens.brandPrimary, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]))),
                    DataCell(_buildStatusBadge(l['status']?.toString() ?? 'Active')),
                  ]);
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  // 3. Repayment Ledger Subtab
  Widget _buildRepaymentLedgerSubtab(List<dynamic> repayments) {
    final tokens = IcareSurfaceTokens.of(context);
    final visibleReps = _hideCancelledTransactions
        ? repayments.where((r) => r['is_reversed'] != true && (r['amount_collected'] as num? ?? 0) > 0).toList()
        : repayments;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.borderSubtle)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Repayment Ledger & Transaction History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: tokens.textPrimary)),
              Row(
                children: [
                  Text('${visibleReps.length} Payments Recorded', style: TextStyle(fontSize: 12, color: tokens.textMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => setState(() => _hideCancelledTransactions = !_hideCancelledTransactions),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _hideCancelledTransactions ? tokens.infoBg : tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _hideCancelledTransactions ? tokens.infoBorder : tokens.borderStrong),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _hideCancelledTransactions ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 14,
                            color: _hideCancelledTransactions ? tokens.infoText : tokens.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _hideCancelledTransactions ? 'Hide Cancelled' : 'Show All (Audit)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _hideCancelledTransactions ? tokens.infoText : tokens.textMuted,
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
          const SizedBox(height: 16),
          if (visibleReps.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _hideCancelledTransactions && repayments.isNotEmpty
                      ? 'All repayments have been reversed or cancelled.'
                      : 'No repayments recorded for this client yet.',
                  style: TextStyle(color: tokens.textMuted),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 750) {
                  return Column(
                    children: visibleReps.map((r) {
                      final isRev = r['is_reversed'] == true;
                      final amt = (r['amount_collected'] as num?)?.toDouble() ?? 0.0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isRev ? tokens.surfaceSubtle : tokens.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  r['date']?.toString() ?? '',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                                ),
                                _buildStatusBadge(isRev ? 'REVERSED' : (r['status']?.toString() ?? 'Completed')),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  CurrencyFormatter.formatNaira(amt),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isRev ? tokens.textMuted : tokens.brandPrimary,
                                    decoration: isRev ? TextDecoration.lineThrough : null,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    r['transaction_type']?.toString() ?? 'Repayment',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                            if ((r['notes']?.toString() ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Note: ${r['notes']}', style: TextStyle(fontSize: 11.5, color: tokens.textMuted)),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  );
                }

                return Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                      headingTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textSecondary),
                      dataTextStyle: TextStyle(fontSize: 12, color: tokens.textPrimary),
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Amount Collected'), numeric: true),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Transaction Type')),
                        DataColumn(label: Text('Notes')),
                      ],
                      rows: visibleReps.map((r) {
                        final isRev = r['is_reversed'] == true;
                        final amt = (r['amount_collected'] as num?)?.toDouble() ?? 0.0;
                        return DataRow(cells: [
                          DataCell(Text(r['date']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textPrimary))),
                          DataCell(Text(
                            CurrencyFormatter.formatNaira(amt),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isRev ? tokens.textMuted : tokens.brandPrimary,
                              decoration: isRev ? TextDecoration.lineThrough : null,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          )),
                          DataCell(_buildStatusBadge(isRev ? 'REVERSED' : (r['status']?.toString() ?? 'Completed'))),
                          DataCell(Text(r['transaction_type']?.toString() ?? 'Repayment', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                          DataCell(Text(r['notes']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 20),

          // Flag for Reversal Expander
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              iconColor: tokens.dangerText,
              collapsedIconColor: tokens.dangerText,
              title: Text('Flag a Repayment for Reversal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tokens.dangerText)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedRepaymentForReversal,
                        isExpanded: true,
                        dropdownColor: tokens.surfaceElevated,
                        style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Select Repayment Transaction',
                          labelStyle: TextStyle(color: tokens.textMuted),
                          filled: true,
                          fillColor: tokens.surfaceSubtle,
                          border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                        ),
                        items: repayments.where((r) {
                          final id = r['repayment_id']?.toString() ?? r['id']?.toString() ?? '';
                          final isRev = r['is_reversed'] == true;
                          final amt = (r['amount_collected'] as num?)?.toDouble() ?? 0.0;
                          return id.isNotEmpty && !isRev && amt > 0;
                        }).map((r) {
                          final id = r['repayment_id']?.toString() ?? r['id']?.toString() ?? '';
                          final amt = CurrencyFormatter.formatNaira((r['amount_collected'] as num?)?.toDouble() ?? 0.0);
                          final dt = r['date']?.toString() ?? '';
                          final shortId = id.length >= 8 ? id.substring(0, 8) : id;
                          return DropdownMenuItem(value: id, child: Text('$dt — $amt (ID: $shortId...)', style: TextStyle(color: tokens.textPrimary), overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedRepaymentForReversal = val),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reversalReasonCtrl,
                        style: TextStyle(color: tokens.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Audit Justification & Reason for Reversal',
                          labelStyle: TextStyle(color: tokens.textMuted),
                          filled: true,
                          fillColor: tokens.surfaceSubtle,
                          border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                        onPressed: _isSubmittingReversal ? null : _submitReversalRequest,
                        child: _isSubmittingReversal ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit Reversal Request'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
        final err = AppErrorDetails.from(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${err.title}: ${err.message}', style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReversal = false);
    }
  }

  // 4. Savings Ledger Subtab (Running Balance)
  Widget _buildSavingsLedgerSubtab(List<dynamic> savings) {
    final tokens = IcareSurfaceTokens.of(context);
    final visibleSavings = _hideCancelledTransactions
        ? savings.where((s) => s['is_reversed'] != true).toList()
        : savings;

    if (visibleSavings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.borderSubtle)),
        child: Column(
          children: [
            Center(child: Text('No active savings transactions recorded for this client.', style: TextStyle(color: tokens.textMuted))),
            if (savings.isNotEmpty && _hideCancelledTransactions) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _hideCancelledTransactions = false),
                icon: const Icon(Icons.history, size: 14),
                label: const Text('Show Cancelled History', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.borderSubtle)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Savings Ledger & Running Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: tokens.textPrimary)),
              Row(
                children: [
                  Text('${visibleSavings.length} Entries', style: TextStyle(fontSize: 12, color: tokens.textMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => setState(() => _hideCancelledTransactions = !_hideCancelledTransactions),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _hideCancelledTransactions ? tokens.infoBg : tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _hideCancelledTransactions ? tokens.infoBorder : tokens.borderStrong),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _hideCancelledTransactions ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 14,
                            color: _hideCancelledTransactions ? tokens.infoText : tokens.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _hideCancelledTransactions ? 'Hide Cancelled' : 'Show All (Audit)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _hideCancelledTransactions ? tokens.infoText : tokens.textMuted,
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
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 750) {
                return Column(
                  children: visibleSavings.map((s) {
                    final dep = (s['deposit'] as num?)?.toDouble() ?? 0.0;
                    final wd = (s['withdrawal'] as num?)?.toDouble() ?? 0.0;
                    final bal = (s['net_balance'] as num?)?.toDouble() ?? (s['running_balance'] as num?)?.toDouble() ?? 0.0;
                    final isRev = s['is_reversed'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isRev ? tokens.surfaceSubtle : tokens.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(s['date']?.toString() ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
                              _buildStatusBadge(isRev ? 'REVERSED' : 'Posted'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    dep > 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                    size: 16,
                                    color: dep > 0 ? tokens.brandPrimary : tokens.dangerText,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    dep > 0 ? '+${CurrencyFormatter.formatNaira(dep)}' : (wd > 0 ? '-${CurrencyFormatter.formatNaira(wd)}' : '₦0'),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isRev ? tokens.textMuted : (dep > 0 ? tokens.brandPrimary : tokens.dangerText),
                                      decoration: isRev ? TextDecoration.lineThrough : null,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Balance', style: TextStyle(fontSize: 10.5, color: tokens.textMuted)),
                                  Text(
                                    CurrencyFormatter.formatNaira(bal),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.infoText, fontFeatures: const [FontFeature.tabularFigures()]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if ((s['remarks']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Remarks: ${s['remarks']}', style: TextStyle(fontSize: 11.5, color: tokens.textMuted)),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              }

              return Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                    headingTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textSecondary),
                    dataTextStyle: TextStyle(fontSize: 12, color: tokens.textPrimary),
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Deposit (₦)'), numeric: true),
                      DataColumn(label: Text('Withdrawal (₦)'), numeric: true),
                      DataColumn(label: Text('Net Balance (₦)'), numeric: true),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Remarks')),
                    ],
                    rows: visibleSavings.map((s) {
                      final dep = (s['deposit'] as num?)?.toDouble() ?? 0.0;
                      final wd = (s['withdrawal'] as num?)?.toDouble() ?? 0.0;
                      final bal = (s['net_balance'] as num?)?.toDouble() ?? (s['running_balance'] as num?)?.toDouble() ?? 0.0;
                      final isRev = s['is_reversed'] == true;
                      return DataRow(cells: [
                        DataCell(Text(s['date']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textPrimary))),
                        DataCell(Text(
                          dep != 0 ? CurrencyFormatter.formatNaira(dep) : '—',
                          style: TextStyle(
                            fontSize: 12,
                            color: isRev ? tokens.textMuted : tokens.brandPrimary,
                            fontWeight: FontWeight.w600,
                            decoration: isRev ? TextDecoration.lineThrough : null,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        )),
                        DataCell(Text(
                          wd != 0 ? CurrencyFormatter.formatNaira(wd) : '—',
                          style: TextStyle(
                            fontSize: 12,
                            color: isRev ? tokens.textMuted : tokens.dangerText,
                            fontWeight: FontWeight.w600,
                            decoration: isRev ? TextDecoration.lineThrough : null,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        )),
                        DataCell(Text(
                          CurrencyFormatter.formatNaira(bal),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.infoText, fontFeatures: const [FontFeature.tabularFigures()]),
                        )),
                        DataCell(_buildStatusBadge(isRev ? 'REVERSED' : 'Posted')),
                        DataCell(Text(s['remarks']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                      ]);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 5. Collection History Subtab (4 Compliance KPIs & Table)
  Widget _buildCollectionHistorySubtab(Map<String, dynamic> comp, List<dynamic> compTable) {
    final tokens = IcareSurfaceTokens.of(context);
    final compMetrics = comp['metrics'] as Map<String, dynamic>? ?? {};
    final exp = ((comp['total_expected'] ?? compMetrics['total_expected']) as num?)?.toDouble() ?? 0.0;
    final act = ((comp['total_collected'] ?? compMetrics['total_collected']) as num?)?.toDouble() ?? 0.0;
    final variance = ((comp['collection_variance'] ?? compMetrics['variance'] ?? compMetrics['collection_variance']) as num?)?.toDouble() ?? 0.0;
    final rate = ((comp['compliance_rate'] ?? compMetrics['compliance_rate']) as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 Compliance KPIs
        LayoutBuilder(
          builder: (context, constraints) {
            final c1 = _buildKpiCard('Total Expected', CurrencyFormatter.formatNaira(exp), 'All Scheduled Repayments', tokens.textSecondary, icon: Icons.event_note_outlined);
            final c2 = _buildKpiCard('Total Collected', CurrencyFormatter.formatNaira(act), 'Total Paid to Date', tokens.brandPrimary, icon: Icons.check_circle_outline);
            final c3 = _buildKpiCard('Collection Variance', CurrencyFormatter.formatNaira(variance), variance <= 0 ? 'Surplus / On Target' : 'Deficit / Shortfall', variance <= 0 ? tokens.brandPrimary : tokens.dangerDot, isAlert: variance > 0, icon: Icons.compare_arrows_rounded);
            final c4 = _buildKpiCard('Compliance Rate', '${rate.toStringAsFixed(1)}%', 'Collection Efficiency', rate >= 90 ? tokens.brandPrimary : tokens.dangerDot, isAlert: rate < 90, icon: Icons.speed_outlined);
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
        const SizedBox(height: 16),

        // Compliance Table
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.borderSubtle)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Weekly & Meeting Collection Records', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: tokens.textPrimary)),
                  Text('${compTable.length} Meetings Recorded', style: TextStyle(fontSize: 12, color: tokens.textMuted, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              if (compTable.isEmpty)
                Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No collection meeting records found.', style: TextStyle(color: tokens.textMuted))))
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 750) {
                      return Column(
                        children: compTable.map((m) {
                          final expM = ((m['expected'] ?? m['expected_amount']) as num?)?.toDouble() ?? 0.0;
                          final colM = ((m['collected'] ?? m['amount_paid'] ?? m['collected_amount']) as num?)?.toDouble() ?? 0.0;
                          final varM = (m['variance'] as num?)?.toDouble() ?? (expM - colM);
                          final st = m['compliance_status']?.toString() ?? m['status']?.toString() ?? 'Compliant';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: tokens.surfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: tokens.borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(m['meeting_date']?.toString() ?? '', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                                    _buildStatusBadge(st),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: _buildMicroKpi('Expected', CurrencyFormatter.formatNaira(expM), tokens.textSecondary)),
                                    Expanded(child: _buildMicroKpi('Collected', CurrencyFormatter.formatNaira(colM), tokens.brandPrimary)),
                                    Expanded(child: _buildMicroKpi('Variance', CurrencyFormatter.formatNaira(varM), varM <= 0 ? tokens.brandPrimary : tokens.dangerText)),
                                  ],
                                ),
                                if ((m['officer_name']?.toString() ?? '').isNotEmpty || (m['remarks']?.toString() ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Officer: ${m['officer_name'] ?? "Unassigned"} · Remarks: ${m['remarks'] ?? "None"}',
                                    style: TextStyle(fontSize: 11, color: tokens.textMuted),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    }

                    return Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                          headingTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textSecondary),
                          dataTextStyle: TextStyle(fontSize: 12, color: tokens.textPrimary),
                          columns: const [
                            DataColumn(label: Text('Meeting Date')),
                            DataColumn(label: Text('Expected (₦)'), numeric: true),
                            DataColumn(label: Text('Collected (₦)'), numeric: true),
                            DataColumn(label: Text('Variance (₦)'), numeric: true),
                            DataColumn(label: Text('Officer')),
                            DataColumn(label: Text('Compliance Status')),
                            DataColumn(label: Text('Remarks')),
                          ],
                          rows: compTable.map((m) {
                            final expM = ((m['expected'] ?? m['expected_amount']) as num?)?.toDouble() ?? 0.0;
                            final colM = ((m['collected'] ?? m['amount_paid'] ?? m['collected_amount']) as num?)?.toDouble() ?? 0.0;
                            final varM = (m['variance'] as num?)?.toDouble() ?? (expM - colM);
                            final st = m['compliance_status']?.toString() ?? m['status']?.toString() ?? 'Compliant';
                            return DataRow(cells: [
                              DataCell(Text(m['meeting_date']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textPrimary))),
                              DataCell(Text(CurrencyFormatter.formatNaira(expM), style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                              DataCell(Text(CurrencyFormatter.formatNaira(colM), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.brandPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                              DataCell(Text(CurrencyFormatter.formatNaira(varM), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: varM <= 0 ? tokens.brandPrimary : tokens.dangerText, fontFeatures: const [FontFeature.tabularFigures()]))),
                              DataCell(Text(m['officer_name']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                              DataCell(_buildStatusBadge(st)),
                              DataCell(Text(m['remarks']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                            ]);
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 6. Lifecycle Status Subtab
  Widget _buildLifecycleStatusSubtab(Map<String, dynamic> lifecycle, List<dynamic> history, String clientId) {
    final tokens = IcareSurfaceTokens.of(context);
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
            color: tokens.infoBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.infoBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_user, size: 24, color: tokens.infoText),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Authoritative Lifecycle Status: ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                        _buildLifecycleBadge(curStatus),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Last transitioned: $lastChanged · Note: ${note.isNotEmpty ? note : "None"}', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
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
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Manual Lifecycle Status Transition', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: tokens.textPrimary)),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final allowedTargets = <String>[
                    'Inactive (Savings Only)',
                    'Closed',
                    'Suspended',
                    if (curStatus.trim() == 'Dormant') 'Registered',
                  ];
                  final validTargetStatus = allowedTargets.contains(_targetStatus)
                      ? _targetStatus
                      : allowedTargets.first;

                  final statusDropdown = DropdownButtonFormField<String>(
                    value: validTargetStatus,
                    dropdownColor: tokens.surfaceElevated,
                    style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Target Lifecycle Status',
                      labelStyle: TextStyle(color: tokens.textMuted),
                      filled: true,
                      fillColor: tokens.surfaceSubtle,
                      border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                    ),
                    items: allowedTargets
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: tokens.textPrimary))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _targetStatus = val);
                    },
                  );

                  final reasonField = TextField(
                    controller: _statusReasonCtrl,
                    style: TextStyle(color: tokens.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Operational Reason for Transition',
                      labelStyle: TextStyle(color: tokens.textMuted),
                      filled: true,
                      fillColor: tokens.surfaceSubtle,
                      border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                    ),
                  );

                  final submitBtn = ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSubmittingStatus ? null : () => _submitStatusChange(clientId, targetStatus: validTargetStatus),
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
          decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.borderSubtle)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status Change History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: tokens.textPrimary)),
              const SizedBox(height: 16),
              if (history.isEmpty)
                Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('No prior status transitions recorded.', style: TextStyle(color: tokens.textMuted))))
              else
                Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                      headingTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textSecondary),
                      dataTextStyle: TextStyle(fontSize: 12, color: tokens.textPrimary),
                      columns: const [
                        DataColumn(label: Text('From Status')),
                        DataColumn(label: Text('To Status')),
                        DataColumn(label: Text('Changed At')),
                        DataColumn(label: Text('Reason')),
                        DataColumn(label: Text('Changed By')),
                      ],
                      rows: history.map((h) {
                        return DataRow(cells: [
                          DataCell(_buildLifecycleBadge(h['from_status']?.toString() ?? h['previous_status']?.toString() ?? 'Unknown')),
                          DataCell(_buildLifecycleBadge(h['to_status']?.toString() ?? h['new_status']?.toString() ?? 'Unknown')),
                          DataCell(Text(h['changed_at']?.toString() ?? h['date_time']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textPrimary))),
                          DataCell(Text(h['reason']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                          DataCell(Text(h['changed_by']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
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

  Future<void> _submitStatusChange(String clientId, {required String targetStatus}) async {
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
        targetStatus: targetStatus,
        reason: _statusReasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Client status transitioned to $targetStatus successfully.')),
        );
        _statusReasonCtrl.clear();
        // Invalidate portfolio and dossier
        ref.invalidate(portfolioDataProvider);
        final code = ref.read(selectedClientCodeProvider);
        if (code != null) ref.invalidate(clientDossierDataProvider(code));
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorDialog(context, e);
      }
    } finally {
      if (mounted) setState(() => _isSubmittingStatus = false);
    }
  }

  Future<void> _showTransferClientDialog(
    BuildContext context,
    String clientId,
    String clientName, {
    String? currentBranchId,
    String? currentOfficerId,
  }) async {
    final reasonCtrl = TextEditingController();
    bool isSubmitting = false;
    List<Map<String, dynamic>> branches = [];
    List<Map<String, dynamic>> allOfficers = [];
    List<Map<String, dynamic>> allGroups = [];
    bool isLoadingOptions = true;
    String? optionsError;
    String? selectedBranchId = currentBranchId;
    String? selectedOfficerId;
    String? selectedGroupId;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final tokens = IcareSurfaceTokens.of(ctx);
          if (isLoadingOptions) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                final api = ref.read(coApiServiceProvider);
                final opts = await api.getTransferOptions(branchId: currentBranchId);
                if (ctx.mounted) {
                  setDialogState(() {
                    branches = List<Map<String, dynamic>>.from(opts['branches'] ?? []);
                    allOfficers = List<Map<String, dynamic>>.from(opts['officers'] ?? []);
                    allGroups = List<Map<String, dynamic>>.from(opts['groups'] ?? []);
                    isLoadingOptions = false;
                    if (selectedBranchId == null && branches.isNotEmpty) {
                      selectedBranchId = branches.first['branch_id']?.toString();
                    }
                  });
                }
              } catch (e) {
                if (ctx.mounted) {
                  setDialogState(() {
                    isLoadingOptions = false;
                    optionsError = AppErrorDetails.from(e).message;
                  });
                }
              }
            });
          }

          final isInterBranch = selectedBranchId != null &&
              currentBranchId != null &&
              selectedBranchId!.toLowerCase() != currentBranchId.toLowerCase();

          // Intra-branch officers (same branch, excluding the client's current officer)
          final branchOfficers = allOfficers.where((o) =>
            o['officer_id'] != null &&
            o['officer_id'].toString().toLowerCase() != (currentOfficerId ?? '').toLowerCase() &&
            (selectedBranchId == null ||
             o['branch_id'] == null ||
             o['branch_id'] == '' ||
             o['branch_id'].toString().toLowerCase() == selectedBranchId!.toLowerCase())
          ).toList();

          final branchGroups = allGroups.where((g) =>
            selectedBranchId == null ||
            g['branch_id'] == null ||
            g['branch_id'] == '' ||
            g['branch_id'].toString().toLowerCase() == selectedBranchId!.toLowerCase()
          ).toList();

          return AlertDialog(
            backgroundColor: tokens.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.infoBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.swap_horiz_rounded, color: tokens.infoDot, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isInterBranch ? 'Initiate Inter-Branch Transfer' : 'Reassign Client Portfolio',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                      ),
                      Text(clientName, style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: isLoadingOptions
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : optionsError != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text('Failed to load transfer options: $optionsError', style: TextStyle(color: tokens.dangerText, fontSize: 13)),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isInterBranch
                                    ? 'Initiates an inter-branch transfer request requiring Area Manager sign-off. The destination Branch Manager will assign the client to a local Credit Officer and Solidarity Group upon acceptance.'
                                    : 'Reassigns client and active loan records to another Credit Officer within this branch. Takes effect immediately upon confirmation.',
                                style: TextStyle(fontSize: 12, color: tokens.textMuted, height: 1.4),
                              ),
                              const SizedBox(height: 16),

                              // Destination Branch Dropdown
                              Text('Destination Branch *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: branches.any((b) => b['branch_id'] == selectedBranchId) ? selectedBranchId : null,
                                dropdownColor: tokens.surfaceElevated,
                                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: tokens.surfaceSubtle,
                                  border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  hintText: 'Select destination branch',
                                  hintStyle: TextStyle(color: tokens.textMuted),
                                ),
                                items: branches.map((b) => DropdownMenuItem<String>(
                                  value: b['branch_id']?.toString(),
                                  child: Text(
                                    b['branch_id']?.toString().toLowerCase() == (currentBranchId ?? '').toLowerCase()
                                        ? '${b['name']} (Current Branch - Intra-Branch)'
                                        : (b['name']?.toString() ?? 'Branch'),
                                    style: TextStyle(color: tokens.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )).toList(),
                                onChanged: (val) {
                                  setDialogState(() {
                                    selectedBranchId = val;
                                    selectedOfficerId = null;
                                    selectedGroupId = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),

                              // IF INTER-BRANCH: Show Info Guidance Card (No Destination Officer or Group dropdowns)
                              if (isInterBranch) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: tokens.infoBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: tokens.infoBorder),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.info_outline_rounded, color: tokens.infoText, size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Inter-Branch Relocation Protocol: The receiving Branch Manager will assign the client to an existing local Credit Officer and Solidarity Group in their branch once this transfer is approved by the Area Manager.',
                                          style: TextStyle(fontSize: 12, color: tokens.infoText, height: 1.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ] else ...[
                                // INTRA-BRANCH: Destination Credit Officer Dropdown
                                Text('Destination Credit Officer *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: branchOfficers.any((o) => o['officer_id'] == selectedOfficerId) ? selectedOfficerId : null,
                                  dropdownColor: tokens.surfaceElevated,
                                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: tokens.surfaceSubtle,
                                    border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    hintText: 'Select destination credit officer',
                                    hintStyle: TextStyle(color: tokens.textMuted),
                                  ),
                                  items: branchOfficers.map((o) => DropdownMenuItem<String>(
                                    value: o['officer_id']?.toString(),
                                    child: Text(o['name']?.toString() ?? 'Credit Officer', style: TextStyle(color: tokens.textPrimary), overflow: TextOverflow.ellipsis),
                                  )).toList(),
                                  onChanged: (val) {
                                    setDialogState(() => selectedOfficerId = val);
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Destination Solidarity Group Dropdown (Optional)
                                Text('Destination Solidarity Group (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: selectedGroupId,
                                  dropdownColor: tokens.surfaceElevated,
                                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: tokens.surfaceSubtle,
                                    border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    hintText: 'Select solidarity group',
                                    hintStyle: TextStyle(color: tokens.textMuted),
                                  ),
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('None / Direct Client (Ungrouped)', style: TextStyle(color: tokens.textMuted)),
                                    ),
                                    ...branchGroups.map((g) => DropdownMenuItem<String>(
                                      value: g['group_id']?.toString(),
                                      child: Text(g['name']?.toString() ?? 'Group', style: TextStyle(color: tokens.textPrimary), overflow: TextOverflow.ellipsis),
                                    )),
                                  ],
                                  onChanged: (val) => setDialogState(() => selectedGroupId = val),
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Transfer Reason
                              Text('Transfer Reason *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: reasonCtrl,
                                maxLines: 2,
                                style: TextStyle(color: tokens.textPrimary),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: tokens.surfaceSubtle,
                                  hintText: 'Enter business justification for client portfolio transfer',
                                  hintStyle: TextStyle(color: tokens.textMuted),
                                  border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (isSubmitting || isLoadingOptions || selectedBranchId == null || (!isInterBranch && selectedOfficerId == null))
                    ? null
                    : () async {
                        final rText = reasonCtrl.text.trim();
                        if (rText.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please provide a reason for the transfer.')),
                          );
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        try {
                          final api = ref.read(coApiServiceProvider);
                          final res = await api.transferClient(
                            clientId: clientId,
                            toBranchId: selectedBranchId!,
                            toOfficerId: isInterBranch ? null : selectedOfficerId,
                            toGroupId: isInterBranch ? null : selectedGroupId,
                            reason: rText,
                          );
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Transfer processed successfully!', style: const TextStyle(color: Colors.white)),
                              backgroundColor: const Color(0xFF15803D),
                            ),
                          );
                          ref.invalidate(portfolioDataProvider);
                          final code = ref.read(selectedClientCodeProvider);
                          if (code != null) ref.invalidate(clientDossierDataProvider(code));
                        } catch (err) {
                          if (ctx.mounted) {
                            setDialogState(() => isSubmitting = false);
                            AppErrorFormatter.showErrorDialog(ctx, err);
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isInterBranch ? 'Submit for AM Sign-Off' : 'Reassign Client Portfolio'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // INCOMING CLIENT TRANSFERS (STAGE 3 BM ACCEPTANCE)
  // ==========================================
  Widget _buildIncomingTransfersTab() {
    final tokens = IcareSurfaceTokens.of(context);
    final incomingAsync = ref.watch(incomingTransfersProvider);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.infoBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.move_to_inbox_rounded, color: tokens.infoDot, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Incoming Client Transfers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tokens.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Review, accept, and assign incoming clients transferred from other branches to a local Credit Officer and Solidarity Group.', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.textSecondary,
                  side: BorderSide(color: tokens.borderStrong),
                ),
                onPressed: () => ref.invalidate(incomingTransfersProvider),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: tokens.borderSubtle),
          const SizedBox(height: 16),
          incomingAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Text('Failed to load incoming transfers: $err', style: TextStyle(color: tokens.dangerText, fontSize: 13)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(incomingTransfersProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (transfers) {
              if (transfers.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: tokens.textMuted),
                      const SizedBox(height: 12),
                      Text('No Pending Incoming Transfers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                      const SizedBox(height: 4),
                      Text('All client transfers assigned to this branch have been accepted and finalized.', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transfers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final t = transfers[idx] as Map<String, dynamic>;
                  final clientName = t['client_name']?.toString() ?? 'Client';
                  final clientCode = t['client_code']?.toString() ?? 'N/A';
                  final sourceBranch = t['source_branch_name']?.toString() ?? 'Branch';
                  final sourceOfficer = t['source_officer_name']?.toString() ?? 'Officer';
                  final reason = t['reason']?.toString() ?? 'No reason provided';
                  final outstanding = (t['outstanding_balance'] as num?)?.toDouble() ?? 0.0;
                  final savings = (t['savings_balance'] as num?)?.toDouble() ?? 0.0;
                  final requestedAt = t['requested_at']?.toString() ?? '';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: tokens.infoBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.person_pin_rounded, color: tokens.infoDot, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(clientName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(clientCode, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tokens.successBg,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: tokens.successBorder),
                                    ),
                                    child: Text('AM Approved', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.successText)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Originating Branch: $sourceBranch · Previous Officer: $sourceOfficer', style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
                              const SizedBox(height: 4),
                              Text('Reason: $reason', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: tokens.textMuted)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('Outstanding Loan: ₦${outstanding.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                                  const SizedBox(width: 16),
                                  Text('Savings Balance: ₦${savings.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.brandPrimary)),
                                  if (requestedAt.isNotEmpty) ...[
                                    const SizedBox(width: 16),
                                    Text('Requested: ${requestedAt.length >= 10 ? requestedAt.substring(0, 10) : requestedAt}', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D4ED8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.assignment_ind_rounded, size: 16),
                          label: const Text('Accept & Assign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          onPressed: () => _showAcceptIncomingTransferDialog(context, t),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAcceptIncomingTransferDialog(BuildContext context, Map<String, dynamic> item) async {
    final transferId = item['transfer_id']?.toString() ?? '';
    final clientName = item['client_name']?.toString() ?? 'Client';
    final clientCode = item['client_code']?.toString() ?? '';
    final sourceBranch = item['source_branch_name']?.toString() ?? '';

    bool isSubmitting = false;
    List<Map<String, dynamic>> officers = [];
    List<Map<String, dynamic>> groups = [];
    bool isLoadingOptions = true;
    String? optionsError;
    String? selectedOfficerId;
    String? selectedGroupId;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final tokens = IcareSurfaceTokens.of(ctx);
          if (isLoadingOptions) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                final authState = ref.read(authControllerProvider);
                final currentUser = authState is AuthStateAuthenticated ? authState.user : null;
                final api = ref.read(coApiServiceProvider);
                final opts = await api.getTransferOptions(branchId: currentUser?.branchId);
                if (ctx.mounted) {
                  setDialogState(() {
                    officers = List<Map<String, dynamic>>.from(opts['officers'] ?? []);
                    groups = List<Map<String, dynamic>>.from(opts['groups'] ?? []);
                    isLoadingOptions = false;
                    if (officers.isNotEmpty) {
                      selectedOfficerId = officers.first['officer_id']?.toString();
                    }
                  });
                }
              } catch (e) {
                if (ctx.mounted) {
                  setDialogState(() {
                    isLoadingOptions = false;
                    optionsError = AppErrorDetails.from(e).message;
                  });
                }
              }
            });
          }

          return AlertDialog(
            backgroundColor: tokens.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.infoBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.assignment_ind_rounded, color: tokens.infoDot, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Accept & Assign Incoming Client', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                      Text('$clientName ($clientCode) · From $sourceBranch', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: isLoadingOptions
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : optionsError != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text('Failed to load local options: $optionsError', style: TextStyle(color: tokens.dangerText, fontSize: 13)),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assign this incoming client to an active Credit Officer and Solidarity Group in your branch to finalize the transfer and update their account ownership.',
                              style: TextStyle(fontSize: 12, color: tokens.textMuted, height: 1.4),
                            ),
                            const SizedBox(height: 16),

                            // Assign Local Credit Officer
                            Text('Assign Local Credit Officer *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: officers.any((o) => o['officer_id'] == selectedOfficerId) ? selectedOfficerId : null,
                              dropdownColor: tokens.surfaceElevated,
                              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: tokens.surfaceSubtle,
                                border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                hintText: 'Select Credit Officer',
                                hintStyle: TextStyle(color: tokens.textMuted),
                              ),
                              items: officers.map((o) => DropdownMenuItem<String>(
                                value: o['officer_id']?.toString(),
                                child: Text(o['name']?.toString() ?? 'Credit Officer', style: TextStyle(color: tokens.textPrimary), overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (val) => setDialogState(() => selectedOfficerId = val),
                            ),
                            const SizedBox(height: 14),

                            // Assign Local Solidarity Group
                            Text('Assign Local Solidarity Group (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: selectedGroupId,
                              dropdownColor: tokens.surfaceElevated,
                              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: tokens.surfaceSubtle,
                                border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                hintText: 'Select solidarity group',
                                hintStyle: TextStyle(color: tokens.textMuted),
                              ),
                              items: [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('None / Direct Client (Ungrouped)', style: TextStyle(color: tokens.textMuted)),
                                ),
                                ...groups.map((g) => DropdownMenuItem<String>(
                                  value: g['group_id']?.toString(),
                                  child: Text(g['name']?.toString() ?? 'Group', style: TextStyle(color: tokens.textPrimary), overflow: TextOverflow.ellipsis),
                                )),
                              ],
                              onChanged: (val) => setDialogState(() => selectedGroupId = val),
                            ),
                          ],
                        ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (isSubmitting || isLoadingOptions || selectedOfficerId == null)
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          final api = ref.read(coApiServiceProvider);
                          final res = await api.acceptIncomingTransfer(
                            transferId: transferId,
                            toOfficerId: selectedOfficerId!,
                            toGroupId: selectedGroupId,
                          );
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Client accepted and assigned successfully!', style: const TextStyle(color: Colors.white)),
                              backgroundColor: const Color(0xFF15803D),
                            ),
                          );
                          ref.invalidate(incomingTransfersProvider);
                          ref.invalidate(portfolioDataProvider);
                          final code = ref.read(selectedClientCodeProvider);
                          if (code != null) ref.invalidate(clientDossierDataProvider(code));
                        } catch (err) {
                          if (ctx.mounted) {
                            setDialogState(() => isSubmitting = false);
                            AppErrorFormatter.showErrorDialog(ctx, err);
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm Acceptance & Reassign'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 7. Audit Trail Subtab
  Widget _buildAuditTrailSubtab(List<dynamic> auditTrail) {
    final tokens = IcareSurfaceTokens.of(context);
    if (auditTrail.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.borderSubtle)),
        child: Center(child: Text('No compliance audit records found for this client account.', style: TextStyle(color: tokens.textMuted))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.borderSubtle)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Immutable Compliance Audit Trail', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: tokens.textPrimary)),
              Text('${auditTrail.length} Audit Entries', style: TextStyle(fontSize: 12, color: tokens.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 750) {
                return Column(
                  children: auditTrail.map((a) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tokens.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: tokens.infoBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: tokens.infoBorder),
                                ),
                                child: Text(
                                  a['action']?.toString() ?? 'Action',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.infoText),
                                ),
                              ),
                              Text(
                                (a['timestamp'] ?? a['created_at'])?.toString() ?? '',
                                style: TextStyle(fontSize: 11, color: tokens.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (a['details'] ?? a['description'])?.toString() ?? 'No details logged',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tokens.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'By: ${a['performed_by'] ?? a['user_id'] ?? "System"} · Entity: ${a['entity'] ?? a['table_name'] ?? "Client"}',
                            style: TextStyle(fontSize: 11, color: tokens.textMuted),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }

              return Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                    headingTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textSecondary),
                    dataTextStyle: TextStyle(fontSize: 12, color: tokens.textPrimary),
                    columns: const [
                      DataColumn(label: Text('Timestamp')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('Entity')),
                      DataColumn(label: Text('Performed By')),
                      DataColumn(label: Text('Details')),
                    ],
                    rows: auditTrail.map((a) {
                      return DataRow(cells: [
                        DataCell(Text((a['timestamp'] ?? a['created_at'])?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                        DataCell(Text(a['action']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: tokens.textPrimary))),
                        DataCell(Text((a['entity'] ?? a['table_name'])?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                        DataCell(Text((a['performed_by'] ?? a['user_id'])?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                        DataCell(Text((a['details'] ?? a['description'])?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textPrimary))),
                      ]);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoanScheduleSubtab(List<dynamic> loanSchedule) {
    final tokens = IcareSurfaceTokens.of(context);
    final totalInstallments = loanSchedule.length;
    final paidCount = loanSchedule.where((s) => (s['status']?.toString() ?? '').toLowerCase() == 'paid').length;
    final overdueCount = loanSchedule.where((s) => (s['status']?.toString() ?? '').toLowerCase() == 'overdue').length;
    final totDue = loanSchedule.fold<double>(0.0, (sum, s) => sum + ((s['total_due'] as num?)?.toDouble() ?? 0.0));
    final totPaid = loanSchedule.fold<double>(0.0, (sum, s) => sum + ((s['paid_amount'] as num?)?.toDouble() ?? 0.0));
    final totRem = loanSchedule.fold<double>(0.0, (sum, s) => sum + ((s['remaining_due'] as num?)?.toDouble() ?? 0.0));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 18, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Text(
                'Repayment Schedule & Installments',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: tokens.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(width: 155, child: _buildSmallMetricCard('Installments', '$totalInstallments Total ($paidCount Paid)', tokens.infoDot)),
              SizedBox(width: 155, child: _buildSmallMetricCard('Overdue Items', '$overdueCount Overdue', overdueCount > 0 ? tokens.dangerDot : tokens.brandPrimary)),
              SizedBox(width: 175, child: _buildSmallMetricCard('Scheduled Total', CurrencyFormatter.formatNaira(totDue), tokens.textPrimary)),
              SizedBox(width: 175, child: _buildSmallMetricCard('Paid to Date', CurrencyFormatter.formatNaira(totPaid), tokens.brandPrimary)),
              SizedBox(width: 175, child: _buildSmallMetricCard('Remaining Due', CurrencyFormatter.formatNaira(totRem), totRem > 0 ? tokens.dangerDot : tokens.brandPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          if (loanSchedule.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No repayment schedule records found for this client.', style: TextStyle(color: tokens.textMuted)),
              ),
            )
          else
            Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                  headingTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textSecondary),
                  dataTextStyle: TextStyle(fontSize: 12, color: tokens.textPrimary),
                  columns: const [
                    DataColumn(numeric: true, label: Text('#')),
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Due Date')),
                    DataColumn(numeric: true, label: Text('Principal (₦)')),
                    DataColumn(numeric: true, label: Text('Interest (₦)')),
                    DataColumn(numeric: true, label: Text('Total Due (₦)')),
                    DataColumn(numeric: true, label: Text('Paid (₦)')),
                    DataColumn(numeric: true, label: Text('Remaining (₦)')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: loanSchedule.map((row) {
                    final st = row['status']?.toString() ?? 'Pending';
                    final stLower = st.toLowerCase();
                    Color badgeBg = tokens.surfaceSubtle;
                    Color badgeFg = tokens.textSecondary;
                    if (stLower == 'paid') {
                      badgeBg = tokens.successBg;
                      badgeFg = tokens.successText;
                    } else if (stLower == 'overdue') {
                      badgeBg = tokens.dangerBg;
                      badgeFg = tokens.dangerText;
                    } else if (stLower == 'partial') {
                      badgeBg = tokens.warningBg;
                      badgeFg = tokens.warningText;
                    }
                    final rem = (row['remaining_due'] as num?)?.toDouble() ?? 0.0;
                    return DataRow(
                      cells: [
                        DataCell(Text('${row['installment_number'] ?? ''}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary))),
                        DataCell(Text(row['product_name']?.toString() ?? 'Loan', style: TextStyle(fontSize: 12, color: tokens.textPrimary))),
                        DataCell(Text(row['due_date']?.toString() ?? '', style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                        DataCell(Text(CurrencyFormatter.formatNaira((row['principal_due'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.textPrimary))),
                        DataCell(Text(CurrencyFormatter.formatNaira((row['interest_due'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.textPrimary))),
                        DataCell(Text(CurrencyFormatter.formatNaira((row['total_due'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary))),
                        DataCell(Text(CurrencyFormatter.formatNaira((row['paid_amount'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 12, color: tokens.brandPrimary, fontWeight: FontWeight.w600))),
                        DataCell(Text(CurrencyFormatter.formatNaira(rem), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: rem > 0 ? tokens.dangerText : tokens.brandPrimary))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
                            child: Text(st, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeFg)),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiskRatingSubtab(Map<String, dynamic> riskRating) {
    final tokens = IcareSurfaceTokens.of(context);
    if (riskRating.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Center(
          child: Text('No behavioral risk rating telemetry available yet for this client.', style: TextStyle(color: tokens.textMuted)),
        ),
      );
    }

    final tier = riskRating['rating_tier']?.toString() ?? 'D';
    final label = riskRating['rating_label']?.toString() ?? 'Unrated';
    final scoreBand = riskRating['rating_score']?.toString() ?? 'NEW';
    final compPct = (riskRating['compliance_pct'] as num?)?.toDouble() ?? 0.0;
    final adjScore = (riskRating['adjusted_score'] as num?)?.toDouble() ?? 0.0;
    final paidM = (riskRating['paid_meetings'] as num?)?.toInt() ?? 0;
    final partM = (riskRating['part_payment_meetings'] as num?)?.toInt() ?? 0;
    final missedM = (riskRating['missed_meetings'] as num?)?.toInt() ?? 0;
    final consecMissed = (riskRating['consecutive_missed'] as num?)?.toInt() ?? 0;
    final totExp = (riskRating['total_expected'] as num?)?.toDouble() ?? 0.0;
    final totPaid = (riskRating['total_paid'] as num?)?.toDouble() ?? 0.0;
    final completed = (riskRating['loans_completed'] as num?)?.toInt() ?? 0;
    final overdueBal = (riskRating['overdue_balance'] as num?)?.toDouble() ?? 0.0;
    final recMax = (riskRating['recommended_max_loan'] as num?)?.toDouble() ?? 0.0;
    final upgradeOk = riskRating['eligible_for_upgrade'] == true;

    Color tierColor = tokens.brandPrimary;
    Color tierBg = tokens.brandSoftBg;
    if (tier == 'B') {
      tierColor = tokens.warningText;
      tierBg = tokens.warningBg;
    } else if (tier == 'C' || tier == 'D') {
      tierColor = tokens.dangerText;
      tierBg = tokens.dangerBg;
    }

    final payRatio = totExp > 0 ? (totPaid / totExp).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: tierBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tierColor.withValues(alpha: 0.35)),
                ),
                child: Center(
                  child: Text(
                    tier,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tierColor),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label ($scoreBand)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Adjusted Score: ${adjScore.toStringAsFixed(1)} · Raw Compliance: ${compPct.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: upgradeOk ? tokens.successBg : tokens.warningBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: upgradeOk ? tokens.successBorder : tokens.warningBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      upgradeOk ? Icons.check_circle_outline : Icons.pause_circle_outline,
                      size: 14,
                      color: upgradeOk ? tokens.successText : tokens.warningText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      upgradeOk ? 'Eligible for Loan Upgrade' : 'Upgrade Hold',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: upgradeOk ? tokens.successText : tokens.warningText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: tokens.borderSubtle),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(width: 185, child: _buildKpiCard('Recommended Cap', CurrencyFormatter.formatNaira(recMax), 'Based on credit behavior', tokens.brandPrimary, icon: Icons.workspace_premium_outlined)),
              SizedBox(width: 155, child: _buildSmallMetricCard('Paid Meetings', '$paidM Full', tokens.brandPrimary)),
              SizedBox(width: 155, child: _buildSmallMetricCard('Part Payments', '$partM Partial', tokens.warningDot)),
              SizedBox(width: 155, child: _buildSmallMetricCard('Missed Meetings', '$missedM Missed', missedM > 0 ? tokens.dangerDot : tokens.brandPrimary)),
              SizedBox(width: 165, child: _buildSmallMetricCard('Consecutive Missed', '$consecMissed Streak', consecMissed > 0 ? tokens.dangerDot : tokens.textMuted)),
              SizedBox(width: 155, child: _buildSmallMetricCard('Loans Completed', '$completed Settled', tokens.infoDot)),
              SizedBox(width: 175, child: _buildSmallMetricCard('Overdue Balance', CurrencyFormatter.formatNaira(overdueBal), overdueBal > 0 ? tokens.dangerDot : tokens.brandPrimary)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Cumulative Collection Progress (${CurrencyFormatter.formatNaira(totPaid)} / ${CurrencyFormatter.formatNaira(totExp)})',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: payRatio,
              minHeight: 10,
              backgroundColor: tokens.borderSubtle,
              color: tierColor,
            ),
          ),
        ],
      ),
    );
  }
}

