// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../data/datasources/reports_api_service.dart';
import '../data/models/report_models.dart';
import '../../shared/utils/file_download_helper.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';

class ReportsExportScreen extends ConsumerStatefulWidget {
  const ReportsExportScreen({super.key});

  @override
  ConsumerState<ReportsExportScreen> createState() => _ReportsExportScreenState();
}

class _ReportsExportScreenState extends ConsumerState<ReportsExportScreen> {
  // Navigation
  int _selectedTabIndex = 0;

  // Filter State
  String? _selectedBranchName;
  String _selectedProductName = 'All Products';
  String _selectedOfficerName = 'All Officers';
  String _dateMode = 'As of Date'; // 'As of Date', 'Date Range', 'All Time'
  DateTime _asOfDate = DateTime.now();
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();


  // Monthly Executive Parity State
  int _selectedExecMonth = 9;
  int _selectedExecYear = 2026;
  int _selectedExecSubTab = 0; // 0: A. Deposit Statement, 1: B. Credit Statement, 2: Receipts & Payments, 3: Annex-1 Sundry, 4: Trial Balance, 5: CO Summary, 6: Bank Reconciliation
  String _selectedProgramFilter = 'All'; // 'All', 'Monthly', 'Weekly', 'Daily'
  bool _showRawTableOnMobile = false;

  // Futures & Cache
  ReportsMeta? _cachedMeta;
  Future<ReportsMeta>? _metaFuture;
  Future<AreaComparisonData>? _areaFuture;
  Future<MonthlyParityData>? _parityFuture;
  Future<MonthlyExecutiveStatementsData>? _statementsFuture;
  Future<Annex1ReportData>? _annex1Future;
  Future<MonthlyReconciliationData>? _reconciliationFuture;

  final _currencyFormat = NumberFormat('#,##0.00');
  final _intFormat = NumberFormat('#,##0');
  final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    // Resolve user branch immediately if Branch Manager
    final authState = ref.read(authControllerProvider);
    if (authState is AuthStateAuthenticated) {
      final user = authState.user;
      final role = user.role.trim();
      if (role == 'Branch Manager' || role == 'BM') {
        _selectedBranchName = user.branch;
      }
    }
    _initFutures();
  }

  void _initFutures() {
    final api = ref.read(reportsApiServiceProvider);
    final asOfStr = _dateMode == 'As of Date' ? _dateFormat.format(_asOfDate) : null;
    final startStr = _dateMode == 'Date Range' ? _dateFormat.format(_startDate) : null;
    final endStr = _dateMode == 'Date Range' ? _dateFormat.format(_endDate) : null;

    // Initialize all business futures immediately so frames never crash or show grey boxes
    _parityFuture = api.getMonthlyParity(
      branchName: _selectedBranchName,
      year: _selectedExecYear,
      month: _selectedExecMonth,
      officerName: _selectedOfficerName,
      productName: _selectedProductName,
    );
    _statementsFuture = api.getOfficialStatements(
      branchName: _selectedBranchName,
      year: _selectedExecYear,
      month: _selectedExecMonth,
      officerName: _selectedOfficerName,
      productName: _selectedProductName,
    );
    _annex1Future = api.getAnnex1Report(
      branchName: _selectedBranchName,
      year: _selectedExecYear,
      month: _selectedExecMonth,
    );
    _reconciliationFuture = api.getMonthlyReconciliation(
      branchName: _selectedBranchName,
      year: _selectedExecYear,
      month: _selectedExecMonth,
    );
    _areaFuture = api.getAreaComparison(
      productName: _selectedProductName,
      asOfDate: asOfStr,
      startDate: startStr,
      endDate: endStr,
    );

    // Fetch metadata asynchronously for branch/product/officer options
    _metaFuture = api.getReportsMeta().then((meta) {
      if (mounted) {
        setState(() {
          _cachedMeta = meta;
          if (_selectedBranchName == null) {
            if (meta.scopeLevel == 'BRANCH' && meta.defaultBranch != null) {
              _selectedBranchName = meta.defaultBranch;
            } else if (meta.scopeLevel == 'AREA') {
              _selectedBranchName = 'All Assigned Branches (Consolidated Area View)';
            } else {
              _selectedBranchName = 'All Branches (Consolidated)';
            }
            _refreshCurrentTabData();
          }
        });
      }
      return meta;
    });
  }

  void _refreshCurrentTabData() {
    final api = ref.read(reportsApiServiceProvider);
    final asOfStr = _dateMode == 'As of Date' ? _dateFormat.format(_asOfDate) : null;
    final startStr = _dateMode == 'Date Range' ? _dateFormat.format(_startDate) : null;
    final endStr = _dateMode == 'Date Range' ? _dateFormat.format(_endDate) : null;

    setState(() {
      _areaFuture = api.getAreaComparison(
        productName: _selectedProductName,
        asOfDate: asOfStr,
        startDate: startStr,
        endDate: endStr,
      );
      _parityFuture = api.getMonthlyParity(
        branchName: _selectedBranchName,
        year: _selectedExecYear,
        month: _selectedExecMonth,
        officerName: _selectedOfficerName,
        productName: _selectedProductName,
      );
      _statementsFuture = api.getOfficialStatements(
        branchName: _selectedBranchName,
        year: _selectedExecYear,
        month: _selectedExecMonth,
        officerName: _selectedOfficerName,
        productName: _selectedProductName,
      );
      _annex1Future = api.getAnnex1Report(
        branchName: _selectedBranchName,
        year: _selectedExecYear,
        month: _selectedExecMonth,
      );
      _reconciliationFuture = api.getMonthlyReconciliation(
        branchName: _selectedBranchName,
        year: _selectedExecYear,
        month: _selectedExecMonth,
      );
    });
  }

  String _formatNgn(double value) => '₦${_currencyFormat.format(value)}';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;

    if (user == null) {
      return const Center(child: Text('Session expired. Please re-login.'));
    }

    final role = user.role.trim();
    final isCo = role == 'Credit Officer' || role == 'CO' || role == 'Officer';
    final isAdmin = role == 'Admin' || role == 'Super Admin' || role == 'ADMIN' || role == 'Director';
    final isBm = role == 'Branch Manager' || role == 'BM';
    final isAm = role == 'Area Manager' || role == 'AM';

    // Access guard: CO prohibited
    if (isCo) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.gpp_bad, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Access Denied: You do not have permission to access Reports & Export.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
              ),
            ),
          ],
        ),
      );
    }

    List<String> tabs;
    if (isAm) {
      tabs = [
        'Monthly Executive Statements',
        'Area Branches Comparison',
        'Data Exports & Downloads',
      ];
    } else {
      tabs = [
        'Monthly Executive Statements',
        'Data Exports & Downloads',
      ];
    }

    if (_selectedTabIndex >= tabs.length) {
      _selectedTabIndex = 0;
    }

    final isMobile = MediaQuery.of(context).size.width < 750;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Role-Specific Header & Identity Banner
          _buildIdentityBanner(isAdmin, isBm, isAm, user.branch),
          const SizedBox(height: 16),

          // 2. Pill Tabs Navigation
          _buildPillTabs(tabs),
          const SizedBox(height: 16),

          // 3. Tab Content
          _buildActiveTabContent(tabs[_selectedTabIndex], isAdmin, isBm, isAm),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Identity Banner
  // ---------------------------------------------------------------------------
  Widget _buildIdentityBanner(bool isAdmin, bool isBm, bool isAm, String userBranch) {
    String title;
    String subtitle;
    String badgeTitle;
    String badgeSubtitle;
    Color badgeBg;
    Color badgeBorder;
    Color badgeText;

    if (isBm) {
      title = 'Branch Operational Reports — $userBranch Branch';
      subtitle = 'Single-branch double-entry trial balance, officer supervision, savings portfolio, and collections.';
      badgeTitle = 'SCOPE LEVEL';
      badgeSubtitle = 'Single Branch ($userBranch)';
      badgeBg = const Color(0xFFEFF6FF);
      badgeBorder = const Color(0xFF3B82F6);
      badgeText = const Color(0xFF1E3A8A);
    } else if (isAm) {
      title = 'Area Manager Regional Executive Reports';
      subtitle = 'Multi-branch regional supervision, cross-branch comparative analysis, and operational performance.';
      badgeTitle = 'SUPERVISED AREA';
      badgeSubtitle = 'Regional Supervised Branches';
      badgeBg = const Color(0xFFF0FDF4);
      badgeBorder = const Color(0xFF22C55E);
      badgeText = const Color(0xFF14532D);
    } else {
      title = 'Enterprise Financial & Operational Reports';
      subtitle = 'Consolidated institutional double-entry trial balance, savings portfolios, collections, and multi-branch data exports.';
      badgeTitle = 'SCOPE LEVEL';
      badgeSubtitle = 'Institutional Scope';
      badgeBg = const Color(0xFFFAF5FF);
      badgeBorder = const Color(0xFFA855F7);
      badgeText = const Color(0xFF581C87);
    }

    final isMobile = MediaQuery.of(context).size.width < 750;

    final badgeWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeBorder),
      ),
      child: Column(
        crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            badgeTitle,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeBorder),
          ),
          const SizedBox(height: 2),
          Text(
            badgeSubtitle,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: badgeText),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                badgeWidget,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                badgeWidget,
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Custom Export Filters Card (For Data Exports Tab)
  // ---------------------------------------------------------------------------
  Widget _buildExportFilterCard(bool isAdmin, bool isBm, bool isAm) {
    return FutureBuilder<ReportsMeta>(
      future: _metaFuture,
      builder: (context, snapshot) {
        final meta = snapshot.data ?? _cachedMeta;
        final branches = meta?.branches ?? [];
        final products = meta != null ? ['All Products', ...meta.products] : ['All Products'];
        final officers = meta != null
            ? ['All Officers', ...meta.officers.map((o) => o.fullName)]
            : ['All Officers'];

        // Branch options list
        List<String> branchOptions;
        if (isBm) {
          branchOptions = [_selectedBranchName ?? 'Current Branch'];
        } else if (isAm) {
          branchOptions = [
            'All Assigned Branches (Consolidated Area View)',
            ...branches.map((b) => b.name)
          ];
        } else {
          branchOptions = [
            'All Branches (Consolidated)',
            ...branches.map((b) => b.name)
          ];
        }

        if (_selectedBranchName != null && !branchOptions.contains(_selectedBranchName)) {
          _selectedBranchName = branchOptions.first;
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: const Text(
                'Customize Export Parameters (Optional: Product, Officer, Date Range)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              subtitle: Text(
                'Active: ${_selectedBranchName ?? 'All Branches'} • $_selectedProductName • $_selectedOfficerName • $_dateMode',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Builder(
                builder: (context) {
                  final isMobile = MediaQuery.of(context).size.width < 750;

                  final branchWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Branch Scope', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: _selectedBranchName ?? (branchOptions.isNotEmpty ? branchOptions.first : null),
                        isExpanded: true,
                        decoration: _inputDecoration(),
                        items: branchOptions.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: isBm
                            ? null
                            : (val) {
                                setState(() => _selectedBranchName = val);
                                _refreshCurrentTabData();
                              },
                      ),
                    ],
                  );

                  final productWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Loan Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: _selectedProductName,
                        isExpanded: true,
                        decoration: _inputDecoration(),
                        items: products.map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedProductName = val);
                            _refreshCurrentTabData();
                          }
                        },
                      ),
                    ],
                  );

                  final officerWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Credit Officer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: _selectedOfficerName,
                        isExpanded: true,
                        decoration: _inputDecoration(),
                        items: officers.map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedOfficerName = val);
                            _refreshCurrentTabData();
                          }
                        },
                      ),
                    ],
                  );

                  final dateModeWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: _dateMode,
                        isExpanded: true,
                        decoration: _inputDecoration(),
                        items: ['As of Date', 'Date Range', 'All Time'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _dateMode = val);
                            _refreshCurrentTabData();
                          }
                        },
                      ),
                    ],
                  );

                  final asOfWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('As of Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _asOfDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _asOfDate = picked);
                            _refreshCurrentTabData();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_dateFormat.format(_asOfDate), style: const TextStyle(fontSize: 13)),
                              const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );

                  final startDateWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _startDate = picked);
                            _refreshCurrentTabData();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_dateFormat.format(_startDate), style: const TextStyle(fontSize: 12)),
                              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );

                  final endDateWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('End Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _endDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _endDate = picked);
                            _refreshCurrentTabData();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_dateFormat.format(_endDate), style: const TextStyle(fontSize: 12)),
                              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );

                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        branchWidget,
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: productWidget),
                            const SizedBox(width: 8),
                            Expanded(child: officerWidget),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_dateMode == 'As of Date')
                          Row(
                            children: [
                              Expanded(child: dateModeWidget),
                              const SizedBox(width: 8),
                              Expanded(child: asOfWidget),
                            ],
                          )
                        else if (_dateMode == 'Date Range') ...[
                          dateModeWidget,
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: startDateWidget),
                              const SizedBox(width: 8),
                              Expanded(child: endDateWidget),
                            ],
                          ),
                        ] else ...[
                          dateModeWidget,
                        ],
                      ],
                    );
                  }

                  return Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(width: 240, child: branchWidget),
                      SizedBox(width: 200, child: productWidget),
                      SizedBox(width: 200, child: officerWidget),
                      SizedBox(width: 160, child: dateModeWidget),
                      if (_dateMode == 'As of Date') SizedBox(width: 160, child: asOfWidget),
                      if (_dateMode == 'Date Range') ...[
                        SizedBox(width: 140, child: startDateWidget),
                        SizedBox(width: 140, child: endDateWidget),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  },
);
}

  // ---------------------------------------------------------------------------
  // 3. Horizontal Pill Tabs Navigation
  // ---------------------------------------------------------------------------
  Widget _buildPillTabs(List<String> tabs) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final title = entry.value;
          final isSelected = _selectedTabIndex == idx;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() => _selectedTabIndex = idx);
                _refreshCurrentTabData();
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF064E3B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF064E3B) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Tab Content Router
  // ---------------------------------------------------------------------------
  Widget _buildActiveTabContent(String tabName, bool isAdmin, bool isBm, bool isAm) {
    switch (tabName) {
      case 'Monthly Executive Statements':
      case 'Monthly Executive Parity':
        return _buildMonthlyExecutiveParityTab(isAdmin, isBm, isAm);
      case 'Area Branches Comparison':
        return _buildAreaComparisonTab();
      case 'Data Exports & Downloads':
        return _buildDataExportsTab(isAdmin, isBm, isAm);
      default:
        return _buildMonthlyExecutiveParityTab(isAdmin, isBm, isAm);
    }
  }

  // ---------------------------------------------------------------------------
  // Tab 0: Monthly Executive Parity Suite
  // ---------------------------------------------------------------------------
  Widget _buildMonthlyExecutiveParityTab(bool isAdmin, bool isBm, bool isAm) {
    final api = ref.read(reportsApiServiceProvider);
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls Row: Month, Year, and Quick Export
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: LayoutBuilder(
            builder: (layoutCtx, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final monthDropdown = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Month: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(width: 4),
                  DropdownButton<int>(
                    value: _selectedExecMonth,
                    underline: const SizedBox(),
                    items: List.generate(12, (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(monthNames[index], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    )),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedExecMonth = val;
                          _refreshCurrentTabData();
                        });
                      }
                    },
                  ),
                ],
              );

              final yearDropdown = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Year: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(width: 4),
                  DropdownButton<int>(
                    value: _selectedExecYear,
                    underline: const SizedBox(),
                    items: [2024, 2025, 2026, 2027, 2028].map((y) => DropdownMenuItem(
                      value: y,
                      child: Text('$y', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedExecYear = val;
                          _refreshCurrentTabData();
                        });
                      }
                    },
                  ),
                ],
              );

              Widget? branchControl;
              if (isAdmin || isAm) {
                final branches = _cachedMeta?.branches ?? [];
                final options = isAm
                    ? ['All Assigned Branches (Consolidated Area View)', ...branches.map((b) => b.name)]
                    : ['All Branches (Consolidated)', ...branches.map((b) => b.name)];
                final currBranch = _selectedBranchName ?? (options.isNotEmpty ? options.first : null);
                branchControl = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Branch: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(width: 4),
                    DropdownButton<String>(
                      value: options.contains(currBranch) ? currBranch : (options.isNotEmpty ? options.first : null),
                      underline: const SizedBox(),
                      items: options.map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(b, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedBranchName = val;
                            _refreshCurrentTabData();
                          });
                        }
                      },
                    ),
                  ],
                );
              }

              final branchBadge = isBm
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'Branch: ${_selectedBranchName ?? 'Current'}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                    )
                  : null;

              final products = _cachedMeta != null ? ['All Products', ..._cachedMeta!.products] : ['All Products'];
              final officers = _cachedMeta != null
                  ? ['All Officers', ..._cachedMeta!.officers.map((o) => o.fullName)]
                  : ['All Officers'];

              final officerDropdown = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Officer: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(width: 4),
                  DropdownButton<String>(
                    value: officers.contains(_selectedOfficerName) ? _selectedOfficerName : officers.first,
                    underline: const SizedBox(),
                    items: officers.map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(o, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedOfficerName = val;
                          _refreshCurrentTabData();
                        });
                      }
                    },
                  ),
                ],
              );

              final productDropdown = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Product: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(width: 4),
                  DropdownButton<String>(
                    value: products.contains(_selectedProductName) ? _selectedProductName : products.first,
                    underline: const SizedBox(),
                    items: products.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedProductName = val;
                          _refreshCurrentTabData();
                        });
                      }
                    },
                  ),
                ],
              );

              final excelBtn = OutlinedButton.icon(
                icon: const Icon(Icons.download, size: 14, color: Color(0xFF0F766E)),
                label: const Text('Excel Workbook', style: TextStyle(fontSize: 11, color: Color(0xFF0F766E), fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0F766E)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: () async {
                  try {
                    final bytes = await api.downloadMonthlyParityExcel(
                      branchName: _selectedBranchName,
                      year: _selectedExecYear,
                      month: _selectedExecMonth,
                      officerName: _selectedOfficerName,
                      productName: _selectedProductName,
                    );
                    downloadBlobFile(
                      bytes,
                      'Executive_Monthly_Report_${_selectedExecYear}_${_selectedExecMonth.toString().padLeft(2, '0')}.xlsx',
                      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Executive Workbook downloaded successfully.')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Download failed: $e')),
                      );
                    }
                  }
                },
              );

              final csvBtn = OutlinedButton.icon(
                icon: const Icon(Icons.table_chart, size: 14, color: Color(0xFF1E293B)),
                label: const Text('CO Summary CSV', style: TextStyle(fontSize: 11, color: Color(0xFF1E293B), fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: () async {
                  try {
                    final bytes = await api.downloadMonthlyParityCsv(
                      branchName: _selectedBranchName,
                      year: _selectedExecYear,
                      month: _selectedExecMonth,
                      officerName: _selectedOfficerName,
                      productName: _selectedProductName,
                    );
                    downloadBlobFile(
                      bytes,
                      'CO_Monthly_Summary_${_selectedExecYear}_${_selectedExecMonth.toString().padLeft(2, '0')}.csv',
                      'text/csv',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('CO Summary CSV downloaded successfully.')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Download failed: $e')),
                      );
                    }
                  }
                },
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        monthDropdown,
                        yearDropdown,
                        if (branchControl != null) branchControl,
                        if (branchBadge != null) branchBadge,
                        officerDropdown,
                        productDropdown,
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: excelBtn),
                        const SizedBox(width: 8),
                        Expanded(child: csvBtn),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        monthDropdown,
                        yearDropdown,
                        if (branchControl != null) branchControl,
                        if (branchBadge != null) branchBadge,
                        officerDropdown,
                        productDropdown,
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      excelBtn,
                      const SizedBox(width: 8),
                      csvBtn,
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Future Builder for Data
        FutureBuilder<MonthlyParityData>(
          future: _parityFuture,
          builder: (context, snapshot) {
            if (_parityFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
              if (snapshot.hasError) {
                return _buildErrorCard(snapshot.error.toString());
              }
              return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
            }
            final data = snapshot.data!;

            final cards = data.summaryCards;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Executive Monthly Summary — ${data.branchName} Branch (${data.monthLabel})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 16),

                  // 8 Summary Cards in Grid (Responsive 2-col on mobile, 4-col on tablet/desktop)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final cardW = isMobile
                          ? (constraints.maxWidth - 10) / 2
                          : (constraints.maxWidth - 36) / 4;
                      return Wrap(
                        spacing: isMobile ? 10 : 12,
                        runSpacing: isMobile ? 10 : 12,
                        children: [
                          _buildMetricCard('Principal Disbursed', _formatNgn(cards.disbursedPrincipal), width: cardW),
                          _buildMetricCard('Upfront Fees', _formatNgn(cards.upfrontFees), width: cardW),
                          _buildMetricCard('Net Active Credit', _formatNgn(cards.netActiveCredit), width: cardW),
                          _buildMetricCard('Collections', _formatNgn(cards.collections), width: cardW),
                          _buildMetricCard('Closing Credit Portfolio', _formatNgn(cards.closingCredit), width: cardW),
                          _buildMetricCard('Closing Savings Balance', _formatNgn(cards.closingSavings), width: cardW),
                          _buildMetricCard('Bank Deposits (1050)', _formatNgn(cards.bankDeposits), width: cardW),
                          _buildMetricCard(
                            'GL Balance Integrity',
                            cards.isGlBalanced ? '[BALANCED]' : '[OUT OF BALANCE]',
                            width: cardW,
                            isAccent: cards.isGlBalanced,
                            subtitle: 'Debits == Credits',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Sub-Tab Switcher (Single-line horizontally scrollable pill bar on mobile, no multi-row wrap)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildSubTabButton('A. Deposit Statement', 0, icon: Icons.savings_outlined),
                          const SizedBox(width: 4),
                          _buildSubTabButton('B. Credit Statement', 1, icon: Icons.credit_card_outlined),
                          const SizedBox(width: 4),
                          _buildSubTabButton('Receipts & Payments Account', 2, icon: Icons.receipt_long_outlined),
                          const SizedBox(width: 4),
                          _buildSubTabButton('Annex-1 Sundry', 3, icon: Icons.pie_chart_outline),
                          const SizedBox(width: 4),
                          _buildSubTabButton('Official Trial Balance', 4, icon: Icons.balance_outlined),
                          const SizedBox(width: 4),
                          _buildSubTabButton('Credit Officers Summary', 5, icon: Icons.people_alt_outlined),
                          const SizedBox(width: 4),
                          _buildSubTabButton('Bank & Treasury Reconciliation', 6, icon: Icons.account_balance_outlined),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sub-tab content
                  if (_selectedExecSubTab == 0)
                    _buildDepositStatementView()
                  else if (_selectedExecSubTab == 1)
                    _buildCreditStatementView()
                  else if (_selectedExecSubTab == 2)
                    _buildReceiptsAndPaymentsView()
                  else if (_selectedExecSubTab == 3)
                    _buildAnnex1View()
                  else if (_selectedExecSubTab == 4)
                    _buildOfficialTrialBalanceView()
                  else if (_selectedExecSubTab == 5)
                    _buildCoMonthlySummaryTable(data)
                  else
                    _buildBankReconciliationView(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubTabButton(String label, int index, {IconData? icon}) {
    final isSelected = _selectedExecSubTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedExecSubTab = index;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [const BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramFilterChips(List<String> options, ValueChanged<String> onSelected) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: options.map((opt) {
          final isSelected = _selectedProgramFilter == opt;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(opt, style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              )),
              selected: isSelected,
              selectedColor: const Color(0xFF0F766E),
              backgroundColor: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0))),
              onSelected: (val) {
                if (val) {
                  onSelected(opt);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileDetailRow(String label, String value, {bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isPrimary ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isPrimary ? 13 : 12,
              fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w600,
              color: isPrimary ? const Color(0xFF0F766E) : const Color(0xFF0F172A),
              fontFamily: 'JetBrains Mono',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoMonthlySummaryTable(MonthlyParityData data) {
    final officers = data.officers;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Credit Officers Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    IconButton(
                      tooltip: _showRawTableOnMobile ? 'Switch to Cards' : 'Switch to Table',
                      icon: Icon(_showRawTableOnMobile ? Icons.view_agenda_outlined : Icons.table_chart_outlined, color: const Color(0xFF0F766E)),
                      onPressed: () {
                        setState(() {
                          _showRawTableOnMobile = !_showRawTableOnMobile;
                        });
                      },
                    ),
                  ],
                ),
              ),
            if (isMobile && !_showRawTableOnMobile) ...[
              // Mobile Cards per Officer
              ...officers.map((o) {
                double getMetric(String m) => (data.rows.firstWhere((r) => r.metric == m, orElse: () => MonthlyParityMetricRow(metric: m, values: {})).values[o.name] as num? ?? 0.0).toDouble();
                int getCount(String m) => (data.rows.firstWhere((r) => r.metric == m, orElse: () => MonthlyParityMetricRow(metric: m, values: {})).values[o.name] as num? ?? 0).toInt();

                final disb = getMetric('Sales (Credit) / Principal Disbursed');
                final col = getMetric('Installment Collection (Repayments)');
                final closeCredit = getMetric('Closing Credit Balance');
                final sDep = getMetric('Savings Deposit (Month)');
                final sWth = getMetric('Savings Withdrawal (Month)');
                final sClose = getMetric('Savings Closing Balance');
                final bd = getMetric('Bank Deposits Remitted (Acct 1050)');

                final trans = getMetric('Field Transport (PC1)');
                final stat = getMetric('Stationery (PB3)');
                final ent = getMetric('Entertainment (PB4)');
                final util = getMetric('Utilities & Phone (PB2/PB6)');
                final totOpEx = getMetric('Office Expenses (Acct 4000)');

                final actLoans = getCount('Active Loans Count');
                final actSavers = getCount('Active Savers Count');

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              o.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F766E)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                            child: Text(o.username ?? 'Credit Officer', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      _buildMobileDetailRow('Bank Deposits Remitted (Acct 1050)', _formatNgn(bd), isPrimary: true),
                      const SizedBox(height: 6),
                      _buildMobileDetailRow('Active Portfolio', '$actLoans loans | ${_formatNgn(closeCredit)}'),
                      _buildMobileDetailRow('Month Collections', _formatNgn(col)),
                      _buildMobileDetailRow('Month Disbursements', _formatNgn(disb)),
                      const Divider(height: 16),
                      _buildMobileDetailRow('Active Savers', '$actSavers savers | ${_formatNgn(sClose)}'),
                      _buildMobileDetailRow('Month Savings (In / Out)', '${_formatNgn(sDep)} / ${_formatNgn(sWth)}'),
                      const Divider(height: 16),
                      const Text('Analysed Operational Expenses (OpEx):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      _buildMobileDetailRow('  • Field Transport (PC1)', _formatNgn(trans)),
                      _buildMobileDetailRow('  • Stationery & Print (PB3)', _formatNgn(stat)),
                      _buildMobileDetailRow('  • Entertainment (PB4)', _formatNgn(ent)),
                      _buildMobileDetailRow('  • Utilities & Phone (PB2/PB6)', _formatNgn(util)),
                      _buildMobileDetailRow('Total Analysed OpEx Disbursed', _formatNgn(totOpEx), isPrimary: true),
                    ],
                  ),
                );
              }),
            ] else ...[
              _buildContainedTable(
                hint: 'Swipe horizontally to view all credit officers',
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontSize: 12),
                  dataTextStyle: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                  columnSpacing: 20,
                  columns: [
                    const DataColumn(label: Text('Financial Metric')),
                    ...officers.map((o) => DataColumn(numeric: true, label: Text(o.name))),
                    DataColumn(numeric: true, label: Text(data.totalColName, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
                  ],
                  rows: data.rows.map((r) {
                    final isCount = r.metric.contains('Count');
                    final isHighlight = r.metric.contains('Total') || r.metric.contains('Expenses') || r.metric.contains('Bank');
                    return DataRow(
                      cells: [
                        DataCell(Text(r.metric, style: TextStyle(fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600, color: isHighlight ? const Color(0xFF0F766E) : null))),
                        ...officers.map((o) {
                          final val = r.values[o.name];
                          String disp;
                          if (val == null) {
                            disp = '-';
                          } else if (isCount) {
                            disp = '${(val as num).toInt()}';
                          } else {
                            disp = _formatNgn((val as num).toDouble());
                          }
                          return DataCell(Text(disp));
                        }),
                        DataCell(
                          Builder(builder: (_) {
                            final val = r.values[data.totalColName];
                            String disp;
                            if (val == null) {
                              disp = '-';
                            } else if (isCount) {
                              disp = '${(val as num).toInt()}';
                            } else {
                              disp = _formatNgn((val as num).toDouble());
                            }
                            return Text(disp, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)));
                          }),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDepositStatementView() {
    return FutureBuilder<MonthlyExecutiveStatementsData>(
      future: _statementsFuture,
      builder: (context, snapshot) {
        if (_statementsFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          if (snapshot.hasError) {
            return _buildErrorCard(snapshot.error.toString());
          }
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }
        final data = snapshot.data!;
        final ds = data.depositStatement;
        if (ds == null || ds.rows.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text('No Deposit Statement records available for this period.', style: TextStyle(color: Color(0xFF64748B))),
          ));
        }

        final totRow = ds.rows.firstWhere((r) => r.programme == 'Total', orElse: () => ds.rows.last);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final cardW = isMobile ? (constraints.maxWidth - 8) / 2 : (constraints.maxWidth - 24) / 4;

            final filteredRows = _selectedProgramFilter == 'All' || _selectedProgramFilter == 'All Programmes'
                ? ds.rows
                : ds.rows.where((r) => r.programme.toLowerCase() == _selectedProgramFilter.toLowerCase() || r.programme == 'Total').toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top KPI Summary cards
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetricCard('Active Savers', '${totRow.balanceNo} Savers', width: cardW),
                    _buildMetricCard('Deposit Balance', _formatNgn(totRow.balanceAmount), width: cardW),
                    _buildMetricCard('Month Deposits', _formatNgn(totRow.depositCurr), width: cardW),
                    _buildMetricCard('Month Payouts', _formatNgn(totRow.withdrawalCurrAmount + totRow.returnCurrAmount), width: cardW),
                  ],
                ),
                const SizedBox(height: 16),

                // Program Filter Chips & View Mode Toggle
                Row(
                  children: [
                    Expanded(
                      child: _buildProgramFilterChips(
                        ['All Programmes', 'Monthly', 'Weekly', 'Daily'],
                        (val) {
                          setState(() {
                            _selectedProgramFilter = val == 'All Programmes' ? 'All' : val;
                          });
                        },
                      ),
                    ),
                    if (isMobile)
                      IconButton(
                        tooltip: _showRawTableOnMobile ? 'Switch to Cards' : 'Switch to Table',
                        icon: Icon(_showRawTableOnMobile ? Icons.view_agenda_outlined : Icons.table_chart_outlined, color: const Color(0xFF0F766E)),
                        onPressed: () {
                          setState(() {
                            _showRawTableOnMobile = !_showRawTableOnMobile;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (isMobile && !_showRawTableOnMobile) ...[
                  ...filteredRows.map((r) {
                    final isTot = r.programme == 'Total';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isTot ? const Color(0xFFF0FDF4) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isTot ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
                        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isTot ? 'Consolidated Total' : '${r.programme} Programme',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isTot ? const Color(0xFF166534) : const Color(0xFF0F766E),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isTot ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${r.balanceNo} Active Savers',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isTot ? const Color(0xFF15803D) : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          _buildMobileDetailRow('Net Savings Balance', _formatNgn(r.balanceAmount), isPrimary: true),
                          const SizedBox(height: 8),
                          _buildMobileDetailRow('Month Deposits Received', _formatNgn(r.depositCurr)),
                          _buildMobileDetailRow('Cumulative Deposits (B/F + Month)', _formatNgn(r.depositTotal)),
                          const Divider(height: 16),
                          _buildMobileDetailRow('Normal Withdrawals (Partial)', '${r.withdrawalCurrNo} savers (${_formatNgn(r.withdrawalCurrAmount)})'),
                          _buildMobileDetailRow('Deposit Returns (Zero-Balance)', '${r.returnCurrNo} savers (${_formatNgn(r.returnCurrAmount)})'),
                          _buildMobileDetailRow('Cumulative Payouts', _formatNgn(r.withdrawalTotalAmount + r.returnTotalAmount)),
                          const Divider(height: 16),
                          _buildMobileDetailRow('Members Registered (B/F + Added)', '${r.memberPrev} + ${r.memberCurr} = ${r.memberTotal} members'),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  _buildContainedTable(
                    hint: 'Swipe horizontally to view all deposit columns across programmes',
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontSize: 11),
                      dataTextStyle: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                      columnSpacing: 14,
                      columns: const [
                        DataColumn(label: Text('Programme')),
                        DataColumn(numeric: true, label: Text('Members\nB/F')),
                        DataColumn(numeric: true, label: Text('New\nMembers')),
                        DataColumn(numeric: true, label: Text('Total\nMembers')),
                        DataColumn(numeric: true, label: Text('Deposit\nB/F (₦)')),
                        DataColumn(numeric: true, label: Text('Current\nDeposit (₦)')),
                        DataColumn(numeric: true, label: Text('Total\nDeposit (₦)')),
                        DataColumn(numeric: true, label: Text('Withdrawals\nB/F (No, ₦)')),
                        DataColumn(numeric: true, label: Text('Current\nWithdrawals (No, ₦)')),
                        DataColumn(numeric: true, label: Text('Total\nWithdrawals (No, ₦)')),
                        DataColumn(numeric: true, label: Text('Cancellations\nB/F (No, ₦)')),
                        DataColumn(numeric: true, label: Text('Current\nCancellations (No, ₦)')),
                        DataColumn(numeric: true, label: Text('Total\nCancellations (No, ₦)')),
                        DataColumn(numeric: true, label: Text('Active\nSavers')),
                        DataColumn(numeric: true, label: Text('Net Deposit\nBalance (₦)')),
                      ],
                      rows: filteredRows.map((r) {
                        final isTot = r.programme == 'Total';
                        final boldStyle = isTot ? const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 11) : const TextStyle(fontSize: 11);
                        return DataRow(
                          color: isTot ? MaterialStateProperty.all(const Color(0xFFF1F5F9)) : null,
                          cells: [
                            DataCell(Text(r.programme, style: isTot ? const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F766E)) : const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text('${r.memberPrev}', style: boldStyle)),
                            DataCell(Text('${r.memberCurr}', style: boldStyle)),
                            DataCell(Text('${r.memberTotal}', style: boldStyle)),
                            DataCell(Text(_formatNgn(r.depositPrev), style: boldStyle)),
                            DataCell(Text(_formatNgn(r.depositCurr), style: boldStyle)),
                            DataCell(Text(_formatNgn(r.depositTotal), style: boldStyle)),
                            DataCell(Text('${r.withdrawalPrevNo} (${_formatNgn(r.withdrawalPrevAmount)})', style: boldStyle)),
                            DataCell(Text('${r.withdrawalCurrNo} (${_formatNgn(r.withdrawalCurrAmount)})', style: boldStyle)),
                            DataCell(Text('${r.withdrawalTotalNo} (${_formatNgn(r.withdrawalTotalAmount)})', style: boldStyle)),
                            DataCell(Text('${r.returnPrevNo} (${_formatNgn(r.returnPrevAmount)})', style: boldStyle)),
                            DataCell(Text('${r.returnCurrNo} (${_formatNgn(r.returnCurrAmount)})', style: boldStyle)),
                            DataCell(Text('${r.returnTotalNo} (${_formatNgn(r.returnTotalAmount)})', style: boldStyle)),
                            DataCell(Text('${r.balanceNo}', style: isTot ? const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F766E)) : const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_formatNgn(r.balanceAmount), style: isTot ? const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F766E)) : const TextStyle(fontWeight: FontWeight.w700))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCreditSectionCard(List<CreditStatementRow> rows, String sectionTitle, IconData icon, {bool isHighlight = false}) {
    final sectionRows = rows.where((r) {
      final s = r.section.toLowerCase();
      final target = sectionTitle.toLowerCase();
      if (target.contains('disbursed')) return s.contains('disbursed');
      if (target.contains('excess')) return s.contains('excess');
      if (target.contains('repayment')) return s.contains('repayment') && !s.contains('full');
      if (target.contains('balance')) return s.contains('balance');
      if (target.contains('full')) return s.contains('full');
      return false;
    }).toList();

    if (sectionRows.isEmpty) return const SizedBox.shrink();

    double getRowVal(CreditStatementRow r) {
      if (_selectedProgramFilter == 'Monthly') return r.monthly.toDouble();
      if (_selectedProgramFilter == 'Weekly') return r.weekly.toDouble();
      if (_selectedProgramFilter == 'Daily') return r.daily.toDouble();
      return r.total.toDouble();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isHighlight ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: isHighlight ? const Color(0xFF166534) : const Color(0xFF0F766E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sectionTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isHighlight ? const Color(0xFF166534) : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                child: Text(_selectedProgramFilter, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              ),
            ],
          ),
          const Divider(height: 16),
          ...sectionRows.map((r) {
            final isCount = r.item.contains('Count');
            final val = getRowVal(r);
            final disp = isCount ? '${val.toInt()}' : _formatNgn(val);
            final isTot = r.item.contains('Total') || r.item.contains('Balance') || r.item.contains('Current');
            return _buildMobileDetailRow(r.item.replaceAll('•', '').trim(), disp, isPrimary: isTot);
          }),
        ],
      ),
    );
  }

  Widget _buildCreditStatementView() {
    return FutureBuilder<MonthlyExecutiveStatementsData>(
      future: _statementsFuture,
      builder: (context, snapshot) {
        if (_statementsFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          if (snapshot.hasError) {
            return _buildErrorCard(snapshot.error.toString());
          }
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }
        final data = snapshot.data!;
        final cs = data.creditStatement;
        if (cs == null || cs.rows.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text('No Credit Statement records available for this period.', style: TextStyle(color: Color(0xFF64748B))),
          ));
        }

        final balCountRow = cs.rows.firstWhere((r) => r.item.contains('Active Loans Count'), orElse: () => cs.rows.first);
        final balAmtRow = cs.rows.firstWhere((r) => r.item.contains('Active Credit Balance'), orElse: () => cs.rows.first);
        final instCurrRow = cs.rows.firstWhere((r) => r.item.contains('Current Month Installments'), orElse: () => cs.rows.first);
        final payoffRow = cs.rows.firstWhere((r) => r.item.contains('Current Settled Loans Count'), orElse: () => cs.rows.first);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final cardW = isMobile ? (constraints.maxWidth - 8) / 2 : (constraints.maxWidth - 24) / 4;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top KPI Summary cards
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetricCard('Active Loans', '${balCountRow.total.toInt()} Loans', width: cardW),
                    _buildMetricCard('Active Credit', _formatNgn(balAmtRow.total), width: cardW),
                    _buildMetricCard('Month Collections', _formatNgn(instCurrRow.total), width: cardW),
                    _buildMetricCard('Month Full Payoffs', '${payoffRow.total.toInt()} Settled', width: cardW),
                  ],
                ),
                const SizedBox(height: 16),

                // Program Filter Chips & View Mode Toggle
                Row(
                  children: [
                    Expanded(
                      child: _buildProgramFilterChips(
                        ['Consolidated Total', 'Monthly', 'Weekly', 'Daily'],
                        (val) {
                          setState(() {
                            _selectedProgramFilter = val;
                          });
                        },
                      ),
                    ),
                    if (isMobile)
                      IconButton(
                        tooltip: _showRawTableOnMobile ? 'Switch to Cards' : 'Switch to Table',
                        icon: Icon(_showRawTableOnMobile ? Icons.view_agenda_outlined : Icons.table_chart_outlined, color: const Color(0xFF0F766E)),
                        onPressed: () {
                          setState(() {
                            _showRawTableOnMobile = !_showRawTableOnMobile;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (isMobile && !_showRawTableOnMobile) ...[
                  // Mobile Cards grouped by Section
                  _buildCreditSectionCard(cs.rows, '1. Disbursed Principal', Icons.payments_outlined),
                  _buildCreditSectionCard(cs.rows, '2. Excess Collections', Icons.trending_up_outlined),
                  _buildCreditSectionCard(cs.rows, '3. Installment Repayments', Icons.event_repeat_outlined),
                  _buildCreditSectionCard(cs.rows, '4. Balance (Portfolio)', Icons.account_balance_wallet_outlined, isHighlight: true),
                  _buildCreditSectionCard(cs.rows, '5. Full Repayment (Settled Loans)', Icons.task_alt_outlined),
                ] else ...[
                  // Desktop / Table View
                  _buildContainedTable(
                    hint: 'Swipe horizontally to view credit metrics across Monthly, Weekly, Daily programmes',
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontSize: 11),
                      dataTextStyle: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                      columnSpacing: 16,
                      columns: const [
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Reporting Metric')),
                        DataColumn(numeric: true, label: Text('Monthly')),
                        DataColumn(numeric: true, label: Text('Weekly')),
                        DataColumn(numeric: true, label: Text('Daily')),
                        DataColumn(numeric: true, label: Text('Consolidated\nTotal')),
                      ],
                      rows: cs.rows
                          .where((r) => !r.section.toLowerCase().contains('overdue') && !r.item.toLowerCase().contains('overdue'))
                          .map((r) {
                        final isCount = r.item.contains('Count');
                        final isHighlight = r.item.contains('Total') || r.item.contains('Balance') || r.item.contains('Active');
                        final rowColor = isHighlight ? const Color(0xFFF8FAFC) : null;
                        final textStyle = isHighlight ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 11) : const TextStyle(fontSize: 11);
                        final totStyle = isHighlight ? const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F766E), fontSize: 11) : const TextStyle(fontWeight: FontWeight.w600, fontSize: 11);

                        String formatVal(double v) => isCount ? '${v.toInt()}' : (v > 0 ? _formatNgn(v) : '-');

                        var sectionName = r.section;
                        if (sectionName.startsWith('5. Balance')) sectionName = '4. Balance (Portfolio)';
                        if (sectionName.startsWith('6. Full Repayment')) sectionName = '5. Full Repayment (Settled Loans)';

                        return DataRow(
                          color: rowColor != null ? MaterialStateProperty.all(rowColor) : null,
                          cells: [
                            DataCell(Text(sectionName, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F766E), fontSize: 11))),
                            DataCell(Text(r.item, style: textStyle)),
                            DataCell(Text(formatVal(r.monthly), style: textStyle)),
                            DataCell(Text(formatVal(r.weekly), style: textStyle)),
                            DataCell(Text(formatVal(r.daily), style: textStyle)),
                            DataCell(Text(formatVal(r.total), style: totStyle)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAnnex1View() {
    return FutureBuilder<Annex1ReportData>(
      future: _annex1Future,
      builder: (context, snapshot) {
        if (_annex1Future == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          if (snapshot.hasError) {
            return _buildErrorCard(snapshot.error.toString());
          }
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }
        final data = snapshot.data!;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final cardW = isMobile ? (constraints.maxWidth - 8) / 2 : (constraints.maxWidth - 16) / 3;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top KPI Summary cards
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetricCard('Sundry Receipts', _formatNgn(data.totalSundryReceipts), width: cardW),
                    _buildMetricCard('OpEx Paid (Annex-1)', _formatNgn(data.totalSundryPayments), width: cardW),
                    _buildMetricCard('Branch & Period', '${data.branchName} (${data.monthLabel})', width: isMobile ? constraints.maxWidth : cardW),
                  ],
                ),
                const SizedBox(height: 16),

                // Section A: Sundry Receipts
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.arrow_downward, color: Color(0xFF166534), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Section A: Sundry Inflows / Auxiliary Receipts',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          Text(
                            _formatNgn(data.totalSundryReceipts),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF166534), fontFamily: 'JetBrains Mono'),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      ...data.sundryReceipts.map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                              child: Text(r.code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(r.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                            Text(_formatNgn(r.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'JetBrains Mono')),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),

                // Section B: Sundry Payments / Operating Expenses Groups
                ...data.sundryPaymentsGroups.map((g) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1))],
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
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                                  child: Text(g.categoryCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  g.categoryName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            Text(
                              _formatNgn(g.subtotal),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8), fontFamily: 'JetBrains Mono'),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        ...g.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Row(
                            children: [
                              Text(item.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                              const SizedBox(width: 10),
                              Expanded(child: Text(item.name, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
                              Text(_formatNgn(item.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'JetBrains Mono')),
                            ],
                          ),
                        )),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOfficialTrialBalanceView() {
    return FutureBuilder<MonthlyExecutiveStatementsData>(
      future: _statementsFuture,
      builder: (context, snapshot) {
        if (_statementsFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          if (snapshot.hasError) {
            return _buildErrorCard(snapshot.error.toString());
          }
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }
        final data = snapshot.data!;

        final tb = data.trialBalance;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: tb.isBalanced ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tb.isBalanced ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
              ),
              child: Text(
                'TRIAL BALANCE STATUS: ${tb.isBalanced ? "BALANCED" : "OUT OF BALANCE"} | TOTAL DEBITS: ${_formatNgn(tb.totalDebits)} | TOTAL CREDITS: ${_formatNgn(tb.totalCredits)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: tb.isBalanced ? const Color(0xFF166534) : const Color(0xFF991B1B),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildContainedTable(
              hint: 'Swipe horizontally to view full trial balance',
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontSize: 12),
                dataTextStyle: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('Section')),
                  DataColumn(label: Text('Item Description')),
                  DataColumn(numeric: true, label: Text('Debit (₦)')),
                  DataColumn(numeric: true, label: Text('Credit (₦)')),
                ],
                rows: tb.rows.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(Text(r.section, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F766E)))),
                      DataCell(Text(r.item)),
                      DataCell(Text(r.debit > 0 ? _formatNgn(r.debit) : '-')),
                      DataCell(Text(r.credit > 0 ? _formatNgn(r.credit) : '-')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReceiptsAndPaymentsView() {
    return FutureBuilder<MonthlyExecutiveStatementsData>(
      future: _statementsFuture,
      builder: (context, snapshot) {
        if (_statementsFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          if (snapshot.hasError) {
            return _buildErrorCard(snapshot.error.toString());
          }
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }
        final data = snapshot.data!;

        final rp = data.receiptsAndPayments;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                final receiptsCard = Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Receipts (Inflows)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(_formatNgn(rp.totalReceipts), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF166534), fontFamily: 'JetBrains Mono')),
                      ),
                    ],
                  ),
                );

                final paymentsCard = Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Payments (Outflows)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(_formatNgn(rp.totalPayments), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF), fontFamily: 'JetBrains Mono')),
                      ),
                    ],
                  ),
                );

                if (isMobile) {
                  return Column(
                    children: [
                      receiptsCard,
                      const SizedBox(height: 8),
                      paymentsCard,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: receiptsCard),
                    const SizedBox(width: 12),
                    Expanded(child: paymentsCard),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _buildContainedTable(
              hint: 'Swipe horizontally to view full ledger rows',
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontSize: 12),
                dataTextStyle: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Receipts Item')),
                  DataColumn(label: Text('Receipts Detail')),
                  DataColumn(numeric: true, label: Text('Receipts (₦)')),
                  DataColumn(label: Text('Payments Item')),
                  DataColumn(label: Text('Payments Detail')),
                  DataColumn(numeric: true, label: Text('Payments (₦)')),
                ],
                rows: List.generate(
                  math.max(rp.receipts.length, rp.payments.length),
                  (index) {
                    final r = index < rp.receipts.length ? rp.receipts[index] : null;
                    final p = index < rp.payments.length ? rp.payments[index] : null;
                    return DataRow(
                      cells: [
                        DataCell(Text(r?.item ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(Text(r?.subDetail ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                        DataCell(Text(r != null ? _formatNgn(r.amount) : '-')),
                        DataCell(Text(p?.item ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(Text(p?.subDetail ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                        DataCell(Text(p != null ? _formatNgn(p.amount) : '-')),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBankReconciliationView() {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final role = user?.role.trim() ?? '';
    final isAm = role == 'Area Manager' || role == 'AM';

    return FutureBuilder<MonthlyReconciliationData>(
      future: _reconciliationFuture,
      builder: (context, snapshot) {
        if (_reconciliationFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          if (snapshot.hasError) {
            return _buildErrorCard(snapshot.error.toString());
          }
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }
        final data = snapshot.data!;

        return _BankReconciliationForm(
          initialData: data,
          branchName: _selectedBranchName,
          year: _selectedExecYear,
          month: _selectedExecMonth,
          isReadOnly: isAm,
          onSaved: () {
            _refreshCurrentTabData();
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Area Branches Comparison (AM Exclusive)
  // ---------------------------------------------------------------------------
  Widget _buildAreaComparisonTab() {
    return FutureBuilder<AreaComparisonData>(
      future: _areaFuture,
      builder: (context, snapshot) {
        if (_areaFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          if (snapshot.hasError) {
            return _buildErrorCard(snapshot.error.toString());
          }
          return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
        }
        final data = snapshot.data!;
        if (data.rows.isEmpty) {
          return _buildEmptyCard('No branch comparison data available for assigned area.');
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Regional Area Performance Matrix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              const Text('Side-by-side comparative analysis of all branches under your regional supervision.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),

              // Responsive KPI Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final cardW = isMobile
                      ? (constraints.maxWidth - 10) / 2
                      : (constraints.maxWidth - 36) / 4;
                  return Wrap(
                    spacing: isMobile ? 10 : 12,
                    runSpacing: isMobile ? 10 : 12,
                    children: [
                      _buildMetricCard('Supervised Branches', '${data.totalBranches}', width: cardW),
                      _buildMetricCard('People on Loan', '${_intFormat.format(data.totalPeopleOnLoan)} Clients', width: cardW),
                      _buildMetricCard('Active Savers', '${_intFormat.format(data.totalActiveSavers)} Savers', width: cardW),
                      _buildMetricCard('Active Loans Count', '${_intFormat.format(data.totalActiveLoans)} Loans', width: cardW),
                      _buildMetricCard('Regional Collections', _formatNgn(data.totalAreaCollections), width: cardW),
                      _buildMetricCard('Expected Collections', _formatNgn(data.totalAreaExpected), width: cardW),
                      _buildMetricCard('Area Efficiency', '${data.overallEfficiency.toStringAsFixed(1)}%', width: cardW),
                      _buildMetricCard('Area Savings Portfolio', _formatNgn(data.totalAreaSavings), width: cardW),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              const Text('Branch-by-Branch Comparative Matrix', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),

              // DataTable with mobile scroll cue
              _buildContainedTable(
                hint: 'Swipe horizontally to view all branch metrics',
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Branch', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('People on Loan', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Active Loans', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Active Savers', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Total Savings', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Collections', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Expected', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Efficiency', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Outstanding', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('PAR %', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: data.rows.map((r) {
                    final isHealthy = r.status == 'HEALTHY';
                    return DataRow(cells: [
                      DataCell(Text(r.branch, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(_intFormat.format(r.peopleOnLoan))),
                      DataCell(Text(_intFormat.format(r.activeLoans))),
                      DataCell(Text(_intFormat.format(r.activeSavers))),
                      DataCell(Text(_formatNgn(r.totalSavings))),
                      DataCell(Text(_formatNgn(r.collectionsReceived))),
                      DataCell(Text(_formatNgn(r.expectedCollections))),
                      DataCell(Text('${r.collectionEfficiency.toStringAsFixed(1)}%')),
                      DataCell(Text(_formatNgn(r.outstandingPortfolio))),
                      DataCell(Text('${r.parPercentage.toStringAsFixed(1)}%')),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isHealthy ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: isHealthy ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          r.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isHealthy ? const Color(0xFF166534) : const Color(0xFF991B1B),
                          ),
                        ),
                      )),
                    ]);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              // Download buttons
              Builder(
                builder: (context) {
                  final isMobile = MediaQuery.of(context).size.width < 750;
                  return SizedBox(
                    width: isMobile ? double.infinity : null,
                    child: ElevatedButton.icon(
                      onPressed: () => _triggerCsvDownload('area_comparison', 'area_branch_comparison.csv'),
                      icon: const Icon(Icons.file_download, size: 16),
                      label: const Text('Download Area Comparison (CSV)'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }



  // ---------------------------------------------------------------------------
  // Tab: Data Exports & Downloads
  // ---------------------------------------------------------------------------
  Widget _buildDataExportsTab(bool isAdmin, bool isBm, bool isAm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comprehensive Operational Data Exports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('Direct in-memory generation of full operational datasets. All files download directly to your browser without external cloud dependencies.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 20),

          // Optional Custom Export Filters
          _buildExportFilterCard(isAdmin, isBm, isAm),
          const SizedBox(height: 12),

          // Master Operational Report (Excel)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.table_chart, color: Color(0xFF064E3B), size: 20),
                    SizedBox(width: 8),
                    Text('Master Operational Report (Excel)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isAm
                      ? 'Contains synchronized worksheets: Area Branch Comparison, Trial Balance, Savings Summary, Repayment Summary, Portfolio Summary, and Raw Loan Records.'
                      : 'Contains synchronized worksheets: Trial Balance, Savings Summary, Repayment Summary, Portfolio Summary, and Raw Loan Records.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                Builder(
                  builder: (context) {
                    final isMobile = MediaQuery.of(context).size.width < 750;
                    return SizedBox(
                      width: isMobile ? double.infinity : null,
                      child: ElevatedButton.icon(
                        onPressed: _triggerExcelDownload,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download Master Operational Report (Excel)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF064E3B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Raw Operational Records (CSV)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.description, color: Color(0xFF2563EB), size: 20),
                    SizedBox(width: 8),
                    Text('Raw Operational Records (CSV)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Individual CSV exports for data analysis and external auditing.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 14),
                Builder(
                  builder: (context) {
                    final isMobile = MediaQuery.of(context).size.width < 750;
                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _triggerCsvDownload('loans', 'raw_loans.csv'),
                            icon: const Icon(Icons.file_download, size: 16),
                            label: const Text('Download Raw Loans (CSV)'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _triggerCsvDownload('repayments', 'raw_repayments.csv'),
                            icon: const Icon(Icons.file_download, size: 16),
                            label: const Text('Download Raw Repayments (CSV)'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
                          ),
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _triggerCsvDownload('loans', 'raw_loans.csv'),
                          icon: const Icon(Icons.file_download, size: 16),
                          label: const Text('Download Raw Loans (CSV)'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _triggerCsvDownload('repayments', 'raw_repayments.csv'),
                          icon: const Icon(Icons.file_download, size: 16),
                          label: const Text('Download Raw Repayments (CSV)'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
                        ),
                      ],
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

  // ---------------------------------------------------------------------------
  // Download Triggers
  // ---------------------------------------------------------------------------
  Future<void> _triggerExcelDownload() async {
    final api = ref.read(reportsApiServiceProvider);
    final asOfStr = _dateMode == 'As of Date' ? _dateFormat.format(_asOfDate) : null;
    final startStr = _dateMode == 'Date Range' ? _dateFormat.format(_startDate) : null;
    final endStr = _dateMode == 'Date Range' ? _dateFormat.format(_endDate) : null;

    try {
      final bytes = await api.downloadExcel(
        branchName: _selectedBranchName,
        productName: _selectedProductName,
        officerName: _selectedOfficerName,
        asOfDate: asOfStr,
        startDate: startStr,
        endDate: endStr,
      );
      final fileName = 'icare_master_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      downloadBlobFile(bytes, fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download Excel report: $e')));
      }
    }
  }

  Future<void> _triggerCsvDownload(String reportType, String defaultFileName) async {
    final api = ref.read(reportsApiServiceProvider);
    final asOfStr = _dateMode == 'As of Date' ? _dateFormat.format(_asOfDate) : null;
    final startStr = _dateMode == 'Date Range' ? _dateFormat.format(_startDate) : null;
    final endStr = _dateMode == 'Date Range' ? _dateFormat.format(_endDate) : null;

    try {
      final bytes = await api.downloadCsv(
        reportType: reportType,
        branchName: _selectedBranchName,
        productName: _selectedProductName,
        officerName: _selectedOfficerName,
        asOfDate: asOfStr,
        startDate: startStr,
        endDate: endStr,
      );
      final fileName = defaultFileName.replaceAll('.csv', '_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
      downloadBlobFile(bytes, fileName, 'text/csv');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download CSV: $e')));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Reusable Component Helpers
  // ---------------------------------------------------------------------------
  Widget _buildMetricCard(String label, String value, {String? subtitle, bool isAccent = false, double? width}) {
    return Container(
      width: width ?? 170,
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isAccent ? const Color(0xFF064E3B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isAccent ? const Color(0xFF064E3B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isAccent ? const Color(0xFFA7F3D0) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFamily: 'JetBrains Mono',
                color: isAccent ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isAccent ? const Color(0xFFA7F3D0) : const Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContainedTable({
    required Widget child,
    String? hint,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 750;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    hint ?? 'Swipe horizontally to view all columns',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(error, style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B)))),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
    );
  }
}

class _BankReconciliationForm extends ConsumerStatefulWidget {
  final MonthlyReconciliationData initialData;
  final String? branchName;
  final int year;
  final int month;
  final VoidCallback onSaved;
  final bool isReadOnly;

  const _BankReconciliationForm({
    required this.initialData,
    required this.branchName,
    required this.year,
    required this.month,
    required this.onSaved,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<_BankReconciliationForm> createState() => _BankReconciliationFormState();
}

class _BankReconciliationFormState extends ConsumerState<_BankReconciliationForm> {
  bool _isSaving = false;
  final Map<int, bool> _sectionExpanded = {
    1: true,
    2: true,
    3: true,
    4: true,
    5: true,
  };

  // Bank 1
  late TextEditingController _b1NameController;
  late TextEditingController _b1AccController;
  late TextEditingController _b1OpenController;
  late TextEditingController _b1ChgController;
  late TextEditingController _b1IntController;
  late TextEditingController _b1CloseController;

  // Bank 2
  late TextEditingController _b2NameController;
  late TextEditingController _b2AccController;
  late TextEditingController _b2OpenController;
  late TextEditingController _b2ChgController;
  late TextEditingController _b2IntController;
  late TextEditingController _b2CloseController;

  // Additional Treasury & Overdue
  late TextEditingController _cashBfController;
  late TextEditingController _overdueBfController;
  late TextEditingController _overdueCfController;
  late TextEditingController _profitController;
  late TextEditingController _ccController;
  late TextEditingController _lapseRetController;
  late TextEditingController _recOtherController;
  late TextEditingController _paidOtherController;
  late TextEditingController _retainedEarningsController;
  late TextEditingController _hoAssetAllocController;

  // Operational Table Overrides
  late TextEditingController _disbursedPrincipalController;
  late TextEditingController _upfrontFeesController;
  late TextEditingController _savingsDepositsController;
  late TextEditingController _collectionsController;

  // Remittances
  late TextEditingController _fRecHoAssetController;
  late TextEditingController _fRecHoMainController;
  late TextEditingController _fRecAreaController;
  late TextEditingController _fRecBrController;

  late TextEditingController _fPayHoAssetController;
  late TextEditingController _fPayHoMainController;
  late TextEditingController _fPayBrController;

  // Cumulative Trial Balance Expenses (Year-To-Date & Annex-1 Vouchers)
  late TextEditingController _tbSalaryController;
  late TextEditingController _tbRentController;
  late TextEditingController _tbElectricityController;
  late TextEditingController _tbStationeryController;
  late TextEditingController _tbEntertainmentController;
  late TextEditingController _tbTelephoneController;
  late TextEditingController _tbRepairOfficeController;
  late TextEditingController _tbTransportController;
  late TextEditingController _tbTrainingController;
  late TextEditingController _tbOtherExpensesController;

  // Cumulative Trial Balance Income & Reserves (Year-To-Date & Annex-1 Inflows)
  late TextEditingController _tbSalesProfitController;
  late TextEditingController _tbDamagesFineController;
  late TextEditingController _tbPassbookController;
  late TextEditingController _tbScrapsSalesController;
  late TextEditingController _tbApplicationFeeController;
  late TextEditingController _tbFundHoMainController;
  late TextEditingController _tbFundBranchController;
  late TextEditingController _tbFundOtherAreaController;
  late TextEditingController _tbFundInternalController;
  late TextEditingController _tbContingencyController;
  late TextEditingController _lapseDepositReserveController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final banks = widget.initialData.banks;
    final b1 = banks.isNotEmpty ? banks[0] : null;
    final b2 = banks.length > 1 ? banks[1] : null;

    _b1NameController = TextEditingController(text: b1?.bankName ?? '');
    _b1AccController = TextEditingController(text: b1?.accountNumber ?? '');
    _b1OpenController = TextEditingController(text: b1 != null && b1.openingBalance > 0 ? b1.openingBalance.toStringAsFixed(2) : '');
    _b1ChgController = TextEditingController(text: b1 != null && b1.bankCharges > 0 ? b1.bankCharges.toStringAsFixed(2) : '');
    _b1IntController = TextEditingController(text: b1 != null && b1.bankInterest > 0 ? b1.bankInterest.toStringAsFixed(2) : '');
    _b1CloseController = TextEditingController(text: b1 != null && b1.closingBalance > 0 ? b1.closingBalance.toStringAsFixed(2) : '');

    _b2NameController = TextEditingController(text: b2?.bankName ?? '');
    _b2AccController = TextEditingController(text: b2?.accountNumber ?? '');
    _b2OpenController = TextEditingController(text: b2 != null && b2.openingBalance > 0 ? b2.openingBalance.toStringAsFixed(2) : '');
    _b2ChgController = TextEditingController(text: b2 != null && b2.bankCharges > 0 ? b2.bankCharges.toStringAsFixed(2) : '');
    _b2IntController = TextEditingController(text: b2 != null && b2.bankInterest > 0 ? b2.bankInterest.toStringAsFixed(2) : '');
    _b2CloseController = TextEditingController(text: b2 != null && b2.closingBalance > 0 ? b2.closingBalance.toStringAsFixed(2) : '');

    final d = widget.initialData;
    _cashBfController = TextEditingController(text: d.cashInHandBf > 0 ? d.cashInHandBf.toStringAsFixed(2) : '');
    _overdueBfController = TextEditingController(text: d.overdueBf > 0 ? d.overdueBf.toStringAsFixed(2) : '');
    _overdueCfController = TextEditingController(text: d.overdueCf > 0 ? d.overdueCf.toStringAsFixed(2) : '');
    _profitController = TextEditingController(text: d.salesProfitMarkup > 0 ? d.salesProfitMarkup.toStringAsFixed(2) : '');
    _ccController = TextEditingController(text: d.salesCashAndCarry > 0 ? d.salesCashAndCarry.toStringAsFixed(2) : '');
    _lapseRetController = TextEditingController(text: d.lapseDepositReturn > 0 ? d.lapseDepositReturn.toStringAsFixed(2) : '');
    _recOtherController = TextEditingController(text: d.receivedFromOtherSources > 0 ? d.receivedFromOtherSources.toStringAsFixed(2) : '');
    _paidOtherController = TextEditingController(text: d.paidToOtherSources > 0 ? d.paidToOtherSources.toStringAsFixed(2) : '');
    _retainedEarningsController = TextEditingController(text: d.retainedEarnings > 0 ? d.retainedEarnings.toStringAsFixed(2) : '');
    _hoAssetAllocController = TextEditingController(text: d.headOfficeAssetAllocation > 0 ? d.headOfficeAssetAllocation.toStringAsFixed(2) : '');

    _disbursedPrincipalController = TextEditingController(text: d.disbursedPrincipal > 0 ? d.disbursedPrincipal.toStringAsFixed(2) : '');
    _upfrontFeesController = TextEditingController(text: d.upfrontFees > 0 ? d.upfrontFees.toStringAsFixed(2) : '');
    _savingsDepositsController = TextEditingController(text: d.savingsDeposits > 0 ? d.savingsDeposits.toStringAsFixed(2) : '');
    _collectionsController = TextEditingController(text: d.collections > 0 ? d.collections.toStringAsFixed(2) : '');

    _fRecHoAssetController = TextEditingController(text: d.fundCashHoAssetReceipt > 0 ? d.fundCashHoAssetReceipt.toStringAsFixed(2) : '');
    _fRecHoMainController = TextEditingController(text: d.fundCashHoMainReceipt > 0 ? d.fundCashHoMainReceipt.toStringAsFixed(2) : '');
    _fRecAreaController = TextEditingController(text: d.fundCashOtherAreaReceipt > 0 ? d.fundCashOtherAreaReceipt.toStringAsFixed(2) : '');
    _fRecBrController = TextEditingController(text: d.fundCashBranchReceipt > 0 ? d.fundCashBranchReceipt.toStringAsFixed(2) : '');

    _fPayHoAssetController = TextEditingController(text: d.fundCashHoAssetPayment > 0 ? d.fundCashHoAssetPayment.toStringAsFixed(2) : '');
    _fPayHoMainController = TextEditingController(text: d.fundCashHoMainPayment > 0 ? d.fundCashHoMainPayment.toStringAsFixed(2) : '');
    _fPayBrController = TextEditingController(text: d.fundCashBranchPayment > 0 ? d.fundCashBranchPayment.toStringAsFixed(2) : '');

    _tbSalaryController = TextEditingController(text: d.tbSalary > 0 ? d.tbSalary.toStringAsFixed(2) : '');
    _tbRentController = TextEditingController(text: d.tbRent > 0 ? d.tbRent.toStringAsFixed(2) : '');
    _tbElectricityController = TextEditingController(text: d.tbElectricity > 0 ? d.tbElectricity.toStringAsFixed(2) : '');
    _tbStationeryController = TextEditingController(text: d.tbStationery > 0 ? d.tbStationery.toStringAsFixed(2) : '');
    _tbEntertainmentController = TextEditingController(text: d.tbEntertainment > 0 ? d.tbEntertainment.toStringAsFixed(2) : '');
    _tbTelephoneController = TextEditingController(text: d.tbTelephone > 0 ? d.tbTelephone.toStringAsFixed(2) : '');
    _tbRepairOfficeController = TextEditingController(text: d.tbRepairOffice > 0 ? d.tbRepairOffice.toStringAsFixed(2) : '');
    _tbTransportController = TextEditingController(text: d.tbTransport > 0 ? d.tbTransport.toStringAsFixed(2) : '');
    _tbTrainingController = TextEditingController(text: d.tbTraining > 0 ? d.tbTraining.toStringAsFixed(2) : '');
    _tbOtherExpensesController = TextEditingController(text: d.tbOtherExpenses > 0 ? d.tbOtherExpenses.toStringAsFixed(2) : '');

    _tbSalesProfitController = TextEditingController(text: d.tbSalesProfit > 0 ? d.tbSalesProfit.toStringAsFixed(2) : '');
    _tbDamagesFineController = TextEditingController(text: d.tbDamagesFine > 0 ? d.tbDamagesFine.toStringAsFixed(2) : '');
    _tbPassbookController = TextEditingController(text: d.tbPassbook > 0 ? d.tbPassbook.toStringAsFixed(2) : '');
    _tbScrapsSalesController = TextEditingController(text: d.tbScrapsSales > 0 ? d.tbScrapsSales.toStringAsFixed(2) : '');
    _tbApplicationFeeController = TextEditingController(text: d.tbApplicationFee > 0 ? d.tbApplicationFee.toStringAsFixed(2) : '');
    _tbFundHoMainController = TextEditingController(text: d.tbFundHoMain > 0 ? d.tbFundHoMain.toStringAsFixed(2) : '');
    _tbFundBranchController = TextEditingController(text: d.tbFundBranch > 0 ? d.tbFundBranch.toStringAsFixed(2) : '');
    _tbFundOtherAreaController = TextEditingController(text: d.tbFundOtherArea > 0 ? d.tbFundOtherArea.toStringAsFixed(2) : '');
    _tbFundInternalController = TextEditingController(text: d.tbFundInternal > 0 ? d.tbFundInternal.toStringAsFixed(2) : '');
    _tbContingencyController = TextEditingController(text: d.tbContingency > 0 ? d.tbContingency.toStringAsFixed(2) : '');
    _lapseDepositReserveController = TextEditingController(text: d.lapseDepositReserve > 0 ? d.lapseDepositReserve.toStringAsFixed(2) : '');

    // Add listener to auto-update live totals
    for (final c in [
      _tbSalaryController, _tbElectricityController, _tbStationeryController,
      _tbEntertainmentController, _tbTelephoneController, _tbTransportController,
      _tbTrainingController, _tbRentController, _tbRepairOfficeController,
      _tbOtherExpensesController, _tbPassbookController, _tbApplicationFeeController,
      _tbScrapsSalesController, _tbDamagesFineController
    ]) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(_BankReconciliationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialData != widget.initialData ||
        oldWidget.branchName != widget.branchName ||
        oldWidget.year != widget.year ||
        oldWidget.month != widget.month) {
      _disposeControllers();
      _initControllers();
    }
  }

  void _disposeControllers() {
    _b1NameController.dispose();
    _b1AccController.dispose();
    _b1OpenController.dispose();
    _b1ChgController.dispose();
    _b1IntController.dispose();
    _b1CloseController.dispose();

    _b2NameController.dispose();
    _b2AccController.dispose();
    _b2OpenController.dispose();
    _b2ChgController.dispose();
    _b2IntController.dispose();
    _b2CloseController.dispose();

    _cashBfController.dispose();
    _overdueBfController.dispose();
    _overdueCfController.dispose();
    _profitController.dispose();
    _ccController.dispose();
    _lapseRetController.dispose();
    _recOtherController.dispose();
    _paidOtherController.dispose();
    _retainedEarningsController.dispose();
    _hoAssetAllocController.dispose();

    _disbursedPrincipalController.dispose();
    _upfrontFeesController.dispose();
    _savingsDepositsController.dispose();
    _collectionsController.dispose();

    _fRecHoAssetController.dispose();
    _fRecHoMainController.dispose();
    _fRecAreaController.dispose();
    _fRecBrController.dispose();

    _fPayHoAssetController.dispose();
    _fPayHoMainController.dispose();
    _fPayBrController.dispose();

    _tbSalaryController.dispose();
    _tbRentController.dispose();
    _tbElectricityController.dispose();
    _tbStationeryController.dispose();
    _tbEntertainmentController.dispose();
    _tbTelephoneController.dispose();
    _tbRepairOfficeController.dispose();
    _tbTransportController.dispose();
    _tbTrainingController.dispose();
    _tbOtherExpensesController.dispose();

    _tbSalesProfitController.dispose();
    _tbDamagesFineController.dispose();
    _tbPassbookController.dispose();
    _tbScrapsSalesController.dispose();
    _tbApplicationFeeController.dispose();
    _tbFundHoMainController.dispose();
    _tbFundBranchController.dispose();
    _tbFundOtherAreaController.dispose();
    _tbFundInternalController.dispose();
    _tbContingencyController.dispose();
    _lapseDepositReserveController.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  double _parseVal(TextEditingController c) {
    final text = c.text.replaceAll(',', '').trim();
    return double.tryParse(text) ?? 0.0;
  }

  Future<void> _handleSave() async {
    if (widget.isReadOnly) return;
    setState(() => _isSaving = true);
    try {
      final updatedData = MonthlyReconciliationData(
        banks: [
          BankStatementItem(
            bankName: _b1NameController.text.trim(),
            accountNumber: _b1AccController.text.trim(),
            openingBalance: _parseVal(_b1OpenController),
            bankCharges: _parseVal(_b1ChgController),
            bankInterest: _parseVal(_b1IntController),
            closingBalance: _parseVal(_b1CloseController),
          ),
          BankStatementItem(
            bankName: _b2NameController.text.trim(),
            accountNumber: _b2AccController.text.trim(),
            openingBalance: _parseVal(_b2OpenController),
            bankCharges: _parseVal(_b2ChgController),
            bankInterest: _parseVal(_b2IntController),
            closingBalance: _parseVal(_b2CloseController),
          ),
        ],
        cashInHandBf: _parseVal(_cashBfController),
        overdueBf: _parseVal(_overdueBfController),
        overdueCf: _parseVal(_overdueCfController),
        salesProfitMarkup: _parseVal(_profitController),
        salesCashAndCarry: _parseVal(_ccController),
        fundCashHoAssetReceipt: _parseVal(_fRecHoAssetController),
        fundCashHoMainReceipt: _parseVal(_fRecHoMainController),
        fundCashOtherAreaReceipt: _parseVal(_fRecAreaController),
        fundCashBranchReceipt: _parseVal(_fRecBrController),
        fundCashHoAssetPayment: _parseVal(_fPayHoAssetController),
        fundCashHoMainPayment: _parseVal(_fPayHoMainController),
        fundCashBranchPayment: _parseVal(_fPayBrController),
        depositWithdrawal: 0.0,
        lapseDepositReturn: _parseVal(_lapseRetController),
        paidToOtherSources: _parseVal(_paidOtherController),
        receivedFromOtherSources: _parseVal(_recOtherController),
        retainedEarnings: _parseVal(_retainedEarningsController),
        headOfficeAssetAllocation: _parseVal(_hoAssetAllocController),
        disbursedPrincipal: _parseVal(_disbursedPrincipalController),
        upfrontFees: _parseVal(_upfrontFeesController),
        savingsDeposits: _parseVal(_savingsDepositsController),
        collections: _parseVal(_collectionsController),
        tbSalary: _parseVal(_tbSalaryController),
        tbRent: _parseVal(_tbRentController),
        tbElectricity: _parseVal(_tbElectricityController),
        tbStationery: _parseVal(_tbStationeryController),
        tbEntertainment: _parseVal(_tbEntertainmentController),
        tbTelephone: _parseVal(_tbTelephoneController),
        tbRepairOffice: _parseVal(_tbRepairOfficeController),
        tbTransport: _parseVal(_tbTransportController),
        tbTraining: _parseVal(_tbTrainingController),
        tbOtherExpenses: _parseVal(_tbOtherExpensesController),
        tbSalesProfit: _parseVal(_tbSalesProfitController),
        tbDamagesFine: _parseVal(_tbDamagesFineController),
        tbPassbook: _parseVal(_tbPassbookController),
        tbScrapsSales: _parseVal(_tbScrapsSalesController),
        tbApplicationFee: _parseVal(_tbApplicationFeeController),
        tbFundHoMain: _parseVal(_tbFundHoMainController),
        tbFundBranch: _parseVal(_tbFundBranchController),
        tbFundOtherArea: _parseVal(_tbFundOtherAreaController),
        tbFundInternal: _parseVal(_tbFundInternalController),
        tbContingency: _parseVal(_tbContingencyController),
        lapseDepositReserve: _parseVal(_lapseDepositReserveController),
      );

      final api = ref.read(reportsApiServiceProvider);
      await api.saveMonthlyReconciliation(
        branchName: widget.branchName,
        year: widget.year,
        month: widget.month,
        data: updatedData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Monthly reconciliation saved successfully. Statements recalculated.'),
            backgroundColor: Color(0xFF166534),
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save reconciliation: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildField(String label, TextEditingController controller, {String? hint, bool isNumber = true, bool readOnly = false}) {
    final effectiveReadOnly = widget.isReadOnly || readOnly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: effectiveReadOnly,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: TextStyle(
            fontSize: 12,
            color: effectiveReadOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
            fontWeight: effectiveReadOnly ? FontWeight.w600 : FontWeight.normal,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: effectiveReadOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required int sectionIndex,
    required String title,
    String? subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final isExpanded = _sectionExpanded[sectionIndex] ?? true;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _sectionExpanded[sectionIndex] = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBankCard(
    String title,
    TextEditingController nameC,
    TextEditingController accC,
    TextEditingController openC,
    TextEditingController chgC,
    TextEditingController intC,
    TextEditingController closeC,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildField('Bank Name', nameC, hint: 'e.g., Sterling Bank', isNumber: false)),
              const SizedBox(width: 8),
              Expanded(child: _buildField('Account Number', accC, hint: 'e.g., Account No.', isNumber: false)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildField('Opening Balance B/F (₦) [Auto B/F]', openC, hint: '0.00', readOnly: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildField('Closing Balance C/F (₦)', closeC, hint: '0.00')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildField('Bank Charges (₦)', chgC, hint: '0.00')),
              const SizedBox(width: 8),
              Expanded(child: _buildField('Bank Interest Earned (₦)', intC, hint: '0.00')),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic calculations for Annex-1 live feedback
    final annex1ExpenseSum = _parseVal(_tbSalaryController) +
        _parseVal(_tbElectricityController) +
        _parseVal(_tbStationeryController) +
        _parseVal(_tbEntertainmentController) +
        _parseVal(_tbTelephoneController) +
        _parseVal(_tbTransportController) +
        _parseVal(_tbTrainingController) +
        _parseVal(_tbRentController) +
        _parseVal(_tbRepairOfficeController) +
        _parseVal(_tbOtherExpensesController);

    final annex1InflowSum = _parseVal(_tbPassbookController) +
        _parseVal(_tbApplicationFeeController) +
        _parseVal(_tbScrapsSalesController) +
        _parseVal(_tbDamagesFineController);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Commercial Bank Accounts (Statements)
            _buildSectionCard(
              sectionIndex: 1,
              title: '1. Commercial Bank Accounts (Statements)',
              icon: Icons.account_balance,
              child: isNarrow
                  ? Column(
                      children: [
                        _buildBankCard('Bank Account 1', _b1NameController, _b1AccController, _b1OpenController, _b1ChgController, _b1IntController, _b1CloseController),
                        const SizedBox(height: 12),
                        _buildBankCard('Bank Account 2 (Optional)', _b2NameController, _b2AccController, _b2OpenController, _b2ChgController, _b2IntController, _b2CloseController),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildBankCard('Bank Account 1', _b1NameController, _b1AccController, _b1OpenController, _b1ChgController, _b1IntController, _b1CloseController),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildBankCard('Bank Account 2 (Optional)', _b2NameController, _b2AccController, _b2OpenController, _b2ChgController, _b2IntController, _b2CloseController),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // Section 2: Monthly Operating Expenses (Annex-1 Vouchers)
            _buildSectionCard(
              sectionIndex: 2,
              title: '2. Monthly Operating Expenses (Annex-1 Vouchers)',
              icon: Icons.receipt_long,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, s2Constraints) {
                      final isMobile = s2Constraints.maxWidth < 600;
                      final isTablet = s2Constraints.maxWidth >= 600 && s2Constraints.maxWidth < 950;
                      final fieldW = isMobile
                          ? (s2Constraints.maxWidth - 8) / 2
                          : isTablet
                              ? (s2Constraints.maxWidth - 16) / 3
                              : (s2Constraints.maxWidth - 24) / 4;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          SizedBox(width: fieldW, child: _buildField('Personnel Gross Salary (₦)', _tbSalaryController, hint: 'e.g. 502335.00')),
                          SizedBox(width: fieldW, child: _buildField('Electricity/Gas/Water (₦)', _tbElectricityController, hint: 'e.g. 4200.00')),
                          SizedBox(width: fieldW, child: _buildField('Stationery/Office Mgmt (₦)', _tbStationeryController, hint: 'e.g. 36400.00')),
                          SizedBox(width: fieldW, child: _buildField('Entertainment (₦)', _tbEntertainmentController, hint: 'e.g. 7000.00')),
                          SizedBox(width: fieldW, child: _buildField('Telephone/Postage (₦)', _tbTelephoneController, hint: 'e.g. 3000.00')),
                          SizedBox(width: fieldW, child: _buildField('Transport Allowance (₦)', _tbTransportController, hint: 'e.g. 155000.00')),
                          SizedBox(width: fieldW, child: _buildField('Training Expenses (₦)', _tbTrainingController, hint: 'e.g. 331470.00')),
                          SizedBox(width: fieldW, child: _buildField('Office Rent (₦)', _tbRentController, hint: '0.00')),
                          SizedBox(width: fieldW, child: _buildField('Repair Cost Office (₦)', _tbRepairOfficeController, hint: '0.00')),
                          SizedBox(width: fieldW, child: _buildField('Other Operating Expenses (₦)', _tbOtherExpensesController, hint: '0.00')),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Annex-1 Monthly Expenses: ₦${annex1ExpenseSum.toStringAsFixed(2)} (Feeds Receipts & Payments Row 7 & YTD TB)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Monthly Sundry Receipts (Annex-1 Inflows)
            _buildSectionCard(
              sectionIndex: 3,
              title: '3. Monthly Sundry Receipts (Annex-1 Inflows)',
              icon: Icons.payments,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, s3Constraints) {
                      final isMobile = s3Constraints.maxWidth < 600;
                      final fieldW = isMobile
                          ? (s3Constraints.maxWidth - 8) / 2
                          : (s3Constraints.maxWidth - 24) / 4;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          SizedBox(width: fieldW, child: _buildField('Passbook Fees (₦) [Auto Cashbook]', _tbPassbookController, hint: '0.00', readOnly: true)),
                          SizedBox(width: fieldW, child: _buildField('Application Fees (₦) [Auto Cashbook]', _tbApplicationFeeController, hint: '0.00', readOnly: true)),
                          SizedBox(width: fieldW, child: _buildField('Scraps Sales / Bonus (₦) [Auto Cashbook]', _tbScrapsSalesController, hint: '0.00', readOnly: true)),
                          SizedBox(width: fieldW, child: _buildField('Damages and Fine (₦) [Auto Cashbook]', _tbDamagesFineController, hint: '0.00', readOnly: true)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Annex-1 Inflows: ₦${annex1InflowSum.toStringAsFixed(2)} (Feeds Receipts & Payments Row 10)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 4: Cashbook Remittances & Operational Collections
            _buildSectionCard(
              sectionIndex: 4,
              title: '4. Cashbook Remittances & Operational Collections',
              icon: Icons.sync_alt,
              child: LayoutBuilder(
                builder: (context, s4Constraints) {
                  final isMobile = s4Constraints.maxWidth < 600;
                  final isTablet = s4Constraints.maxWidth >= 600 && s4Constraints.maxWidth < 950;
                  final fieldW = isMobile
                      ? (s4Constraints.maxWidth - 8) / 2
                      : isTablet
                          ? (s4Constraints.maxWidth - 16) / 3
                          : (s4Constraints.maxWidth - 24) / 4;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      SizedBox(width: fieldW, child: _buildField('Sales Profit / Markup (₦) [Auto Cashbook]', _profitController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('Sales: Cash and Carry (₦) [Auto Cashbook]', _ccController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('Upfront Fees Collected (₦) [Auto Loans]', _upfrontFeesController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('Installment Collections (₦) [Auto Repayments]', _collectionsController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('Principal Disbursed (₦) [Auto Loans]', _disbursedPrincipalController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('Deposit Savings (₦) [Auto Savings]', _savingsDepositsController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('Lapse Deposit Return (₦) [Auto Cashbook]', _lapseRetController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('HO Asset Inflow (₦) [Auto Cashbook]', _fRecHoAssetController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('HO Main Inflow (₦) [Auto Cashbook]', _fRecHoMainController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('Branch Office Inflow (₦) [Auto Cashbook]', _fRecBrController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('Other Area Inflow (₦) [Auto Cashbook]', _fRecAreaController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('HO Asset Outflow (₦) [Auto Cashbook]', _fPayHoAssetController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('HO Main Outflow (₦) [Auto Cashbook]', _fPayHoMainController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('Branch Office Outflow (₦) [Auto Cashbook]', _fPayBrController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('Closing Overdue C/F (₦)', _overdueCfController, hint: 'e.g. 26900.00')),
                      SizedBox(width: fieldW, child: _buildField('Opening Overdue B/F (₦) [Auto B/F]', _overdueBfController, hint: '0.00', readOnly: true)),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Section 5: Capital Funds & Equity Adjustments (YTD)
            _buildSectionCard(
              sectionIndex: 5,
              title: '5. Capital Funds & Equity Adjustments (YTD)',
              icon: Icons.pie_chart,
              child: LayoutBuilder(
                builder: (context, s5Constraints) {
                  final isMobile = s5Constraints.maxWidth < 600;
                  final isTablet = s5Constraints.maxWidth >= 600 && s5Constraints.maxWidth < 950;
                  final fieldW = isMobile
                      ? (s5Constraints.maxWidth - 8) / 2
                      : isTablet
                          ? (s5Constraints.maxWidth - 16) / 3
                          : (s5Constraints.maxWidth - 24) / 4;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      SizedBox(width: fieldW, child: _buildField('HO Fund Main Debit (₦)', _tbFundHoMainController, hint: 'e.g. 36553628.00')),
                      SizedBox(width: fieldW, child: _buildField('Branch Office Fund (₦)', _tbFundBranchController, hint: 'e.g. 971000.00')),
                      SizedBox(width: fieldW, child: _buildField('Other Area Fund (₦)', _tbFundOtherAreaController, hint: 'e.g. 11300000.00')),
                      SizedBox(width: fieldW, child: _buildField('Internal Capital Fund (₦)', _tbFundInternalController, hint: 'e.g. 5018362.00')),
                      SizedBox(width: fieldW, child: _buildField('Retained Earnings (₦) [Auto B/F]', _retainedEarningsController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('HO Asset Allocation (₦) [Auto B/F]', _hoAssetAllocController, hint: '0.00', readOnly: true)),
                      SizedBox(width: fieldW, child: _buildField('Lapse Deposit Reserve (₦)', _lapseDepositReserveController, hint: '0.00')),
                      SizedBox(width: fieldW, child: _buildField('Sales Profit Cumulative YTD (₦)', _tbSalesProfitController, hint: 'e.g. 1671398.00')),
                      SizedBox(width: fieldW, child: _buildField('Contingency Reserve (₦)', _tbContingencyController, hint: '0.00')),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button or Read-Only Banner
            if (widget.isReadOnly)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 20, color: Color(0xFF64748B)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Read-Only Mode: Area Managers have inspection and export privileges. Statements and ledger reconciliations can only be modified by the Branch Manager or Head Office.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save, size: 20, color: Colors.white),
                  label: Text(
                    _isSaving ? 'Saving & Recalculating...' : 'Save & Recalculate Statements',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

