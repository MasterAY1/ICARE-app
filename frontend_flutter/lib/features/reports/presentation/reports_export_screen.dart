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
  int _selectedExecSubTab = 0; // 0: CO Summary, 1: Trial Balance, 2: Receipts & Payments, 3: Bank Statements & Treasury Reconciliation

  // Futures & Cache
  ReportsMeta? _cachedMeta;
  Future<ReportsMeta>? _metaFuture;
  Future<AreaComparisonData>? _areaFuture;
  Future<MonthlyParityData>? _parityFuture;
  Future<MonthlyExecutiveStatementsData>? _statementsFuture;
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
    );
    _statementsFuture = api.getOfficialStatements(
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
      );
      _statementsFuture = api.getOfficialStatements(
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
                  Wrap(
                    spacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      monthDropdown,
                      yearDropdown,
                      if (branchControl != null) branchControl,
                      if (branchBadge != null) branchBadge,
                    ],
                  ),
                  Row(
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
                  const SizedBox(height: 4),
                  const Text(
                    'Authoritative 100% reconciled monthly position across active credit, repayments, savings, and general ledger.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                          _buildSubTabButton('Credit Officers Summary', 0, icon: Icons.people_alt_outlined),
                          const SizedBox(width: 4),
                          _buildSubTabButton('Official Trial Balance', 1, icon: Icons.balance_outlined),
                          const SizedBox(width: 4),
                          _buildSubTabButton('Receipts & Payments Account', 2, icon: Icons.receipt_long_outlined),
                          const SizedBox(width: 4),
                          _buildSubTabButton('Bank & Treasury Reconciliation', 3, icon: Icons.account_balance_outlined),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sub-tab content
                  if (_selectedExecSubTab == 0)
                    _buildCoMonthlySummaryTable(data)
                  else if (_selectedExecSubTab == 1)
                    _buildOfficialTrialBalanceView()
                  else if (_selectedExecSubTab == 2)
                    _buildReceiptsAndPaymentsView()
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

  Widget _buildCoMonthlySummaryTable(MonthlyParityData data) {
    final officers = data.officers;
    return _buildContainedTable(
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
              return DataRow(
                cells: [
                  DataCell(Text(r.metric, style: const TextStyle(fontWeight: FontWeight.w600))),
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

  const _BankReconciliationForm({
    required this.initialData,
    required this.branchName,
    required this.year,
    required this.month,
    required this.onSaved,
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
          readOnly: readOnly,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: TextStyle(
            fontSize: 12,
            color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
            fontWeight: readOnly ? FontWeight.w600 : FontWeight.normal,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
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
              Expanded(child: _buildField('Opening Balance B/F (₦) [Auto B/F]', openC, hint: '0.00')),
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
                            'Annex-1 Monthly Expenses Total: ₦${annex1ExpenseSum.toStringAsFixed(2)} • Automatically feeds Receipts & Payments Row 7 and increments YTD Trial Balance',
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
                          SizedBox(width: fieldW, child: _buildField('Passbook Fees (₦)', _tbPassbookController, hint: 'e.g. 2000.00')),
                          SizedBox(width: fieldW, child: _buildField('Application Fees (₦)', _tbApplicationFeeController, hint: 'e.g. 58500.00')),
                          SizedBox(width: fieldW, child: _buildField('Scraps Sales / Bonus (₦)', _tbScrapsSalesController, hint: 'e.g. 420.00')),
                          SizedBox(width: fieldW, child: _buildField('Damages and Fine (₦)', _tbDamagesFineController, hint: '0.00')),
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
                            'Annex-1 Inflows Total: ₦${annex1InflowSum.toStringAsFixed(2)} • Automatically feeds Receipts & Payments Row 10',
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
                      SizedBox(width: fieldW, child: _buildField('Sales Profit / Markup (₦)', _profitController, hint: 'e.g. 2352890.00')),
                      SizedBox(width: fieldW, child: _buildField('Sales: Cash and Carry (₦)', _ccController, hint: 'e.g. 95000.00')),
                      SizedBox(width: fieldW, child: _buildField('Upfront Fees Collected (₦)', _upfrontFeesController, hint: 'e.g. 583000.00')),
                      SizedBox(width: fieldW, child: _buildField('Installment Collections (₦)', _collectionsController, hint: 'e.g. 17465675.00')),
                      SizedBox(width: fieldW, child: _buildField('Principal Disbursed (₦)', _disbursedPrincipalController, hint: 'e.g. 19549000.00')),
                      SizedBox(width: fieldW, child: _buildField('Deposit Savings (₦)', _savingsDepositsController, hint: 'e.g. 4292225.00')),
                      SizedBox(width: fieldW, child: _buildField('Lapse Deposit Return (₦)', _lapseRetController, hint: 'e.g. 16700.00')),
                      SizedBox(width: fieldW, child: _buildField('HO Asset Inflow (₦)', _fRecHoAssetController, hint: 'e.g. 1024000.00')),
                      SizedBox(width: fieldW, child: _buildField('HO Main Inflow (₦)', _fRecHoMainController, hint: 'e.g. 700000.00')),
                      SizedBox(width: fieldW, child: _buildField('Branch Office Inflow (₦)', _fRecBrController, hint: 'e.g. 900000.00')),
                      SizedBox(width: fieldW, child: _buildField('Other Area Inflow (₦)', _fRecAreaController, hint: 'e.g. 200000.00')),
                      SizedBox(width: fieldW, child: _buildField('HO Asset Outflow (₦)', _fPayHoAssetController, hint: 'e.g. 1024000.00')),
                      SizedBox(width: fieldW, child: _buildField('HO Main Outflow (₦)', _fPayHoMainController, hint: 'e.g. 2500000.00')),
                      SizedBox(width: fieldW, child: _buildField('Branch Office Outflow (₦)', _fPayBrController, hint: 'e.g. 200000.00')),
                      SizedBox(width: fieldW, child: _buildField('Closing Overdue C/F (₦)', _overdueCfController, hint: 'e.g. 26900.00')),
                      SizedBox(width: fieldW, child: _buildField('Opening Overdue B/F (₦) [Auto]', _overdueBfController, hint: 'e.g. 14500.00')),
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
                      SizedBox(width: fieldW, child: _buildField('Retained Earnings (₦) [B/F]', _retainedEarningsController, hint: '26351209.00')),
                      SizedBox(width: fieldW, child: _buildField('HO Asset Allocation (₦) [B/F]', _hoAssetAllocController, hint: '14730282.00')),
                      SizedBox(width: fieldW, child: _buildField('Lapse Deposit Reserve (₦)', _lapseDepositReserveController, hint: '1674054.00')),
                      SizedBox(width: fieldW, child: _buildField('Sales Profit Cumulative YTD (₦)', _tbSalesProfitController, hint: 'e.g. 1671398.00')),
                      SizedBox(width: fieldW, child: _buildField('Contingency Reserve (₦)', _tbContingencyController, hint: '0.00')),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
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

