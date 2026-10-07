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

  // Tab 5: Inspect Officer
  String _inspectOfficer = 'All';

  // Monthly Executive Parity State
  int _selectedExecMonth = 9;
  int _selectedExecYear = 2026;
  int _selectedExecSubTab = 0; // 0: CO Summary, 1: Trial Balance, 2: Receipts & Payments

  // Futures
  late Future<ReportsMeta> _metaFuture;
  late Future<TrialBalanceData> _trialBalanceFuture;
  late Future<SavingsSummaryData> _savingsFuture;
  late Future<RepaymentSummaryData> _repaymentFuture;
  late Future<PortfolioPerformanceData> _portfolioFuture;
  late Future<AreaComparisonData> _areaFuture;
  late Future<MonthlyParityData> _parityFuture;
  late Future<MonthlyExecutiveStatementsData> _statementsFuture;

  final _currencyFormat = NumberFormat('#,##0.00');
  final _intFormat = NumberFormat('#,##0');
  final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _fetchMetaAndRefresh();
  }

  void _fetchMetaAndRefresh() {
    final api = ref.read(reportsApiServiceProvider);
    _metaFuture = api.getReportsMeta().then((meta) {
      if (_selectedBranchName == null) {
        if (meta.scopeLevel == 'BRANCH' && meta.defaultBranch != null) {
          _selectedBranchName = meta.defaultBranch;
        } else if (meta.scopeLevel == 'AREA') {
          _selectedBranchName = 'All Assigned Branches (Consolidated Area View)';
        } else {
          _selectedBranchName = 'All Branches (Consolidated)';
        }
      }
      _refreshCurrentTabData();
      return meta;
    });
  }

  void _refreshCurrentTabData() {
    final api = ref.read(reportsApiServiceProvider);
    final asOfStr = _dateMode == 'As of Date' ? _dateFormat.format(_asOfDate) : null;
    final startStr = _dateMode == 'Date Range' ? _dateFormat.format(_startDate) : null;
    final endStr = _dateMode == 'Date Range' ? _dateFormat.format(_endDate) : null;

    setState(() {
      _trialBalanceFuture = api.getTrialBalance(
        branchName: _selectedBranchName,
        asOfDate: asOfStr,
        startDate: startStr,
        endDate: endStr,
      );
      _savingsFuture = api.getSavingsSummary(
        branchName: _selectedBranchName,
        productName: _selectedProductName,
        officerName: _selectedOfficerName,
        asOfDate: asOfStr,
        startDate: startStr,
        endDate: endStr,
      );
      _repaymentFuture = api.getRepaymentSummary(
        branchName: _selectedBranchName,
        productName: _selectedProductName,
        officerName: _selectedOfficerName,
        startDate: startStr,
        endDate: endStr,
      );
      _portfolioFuture = api.getPortfolioPerformance(
        branchName: _selectedBranchName,
        productName: _selectedProductName,
        officerName: _selectedOfficerName,
        inspectOfficer: _inspectOfficer,
      );
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
        'Monthly Executive Parity',
        'Area Branches Comparison',
        'General Ledger & Trial Balance',
        'Savings Summary',
        'Repayment Summary',
        'Portfolio & Officer Performance',
        'Data Exports & Downloads',
      ];
    } else {
      tabs = [
        'Monthly Executive Parity',
        'General Ledger & Trial Balance',
        'Savings Summary',
        'Repayment Summary',
        'Portfolio & Officer Performance',
        'Data Exports & Downloads',
      ];
    }

    if (_selectedTabIndex >= tabs.length) {
      _selectedTabIndex = 0;
    }

    final isMobile = MediaQuery.of(context).size.width < 750;

    return SingleChildScrollView(
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

          // 2. Universal Filter Controls Card
          _buildFilterControlsCard(isAdmin, isBm, isAm),
          const SizedBox(height: 16),

          // 3. Pill Tabs Navigation
          _buildPillTabs(tabs),
          const SizedBox(height: 20),

          // 4. Tab Content
          _buildActiveTabContent(tabs[_selectedTabIndex], isAm),
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
  // 2. Filter Controls Card
  // ---------------------------------------------------------------------------
  Widget _buildFilterControlsCard(bool isAdmin, bool isBm, bool isAm) {
    return FutureBuilder<ReportsMeta>(
      future: _metaFuture,
      builder: (context, snapshot) {
        final meta = snapshot.data;
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Controls',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Builder(
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
            ],
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
  Widget _buildActiveTabContent(String tabName, bool isAm) {
    switch (tabName) {
      case 'Monthly Executive Parity':
        return _buildMonthlyExecutiveParityTab();
      case 'Area Branches Comparison':
        return _buildAreaComparisonTab();
      case 'General Ledger & Trial Balance':
        return _buildTrialBalanceTab();
      case 'Savings Summary':
        return _buildSavingsSummaryTab();
      case 'Repayment Summary':
        return _buildRepaymentSummaryTab();
      case 'Portfolio & Officer Performance':
        return _buildPortfolioPerformanceTab();
      case 'Data Exports & Downloads':
        return _buildDataExportsTab(isAm);
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // Tab 0: Monthly Executive Parity Suite
  // ---------------------------------------------------------------------------
  Widget _buildMonthlyExecutiveParityTab() {
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
          child: Wrap(
            spacing: 16,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Month: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(width: 6),
                  DropdownButton<int>(
                    value: _selectedExecMonth,
                    underline: const SizedBox(),
                    items: List.generate(12, (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(monthNames[index], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                  const SizedBox(width: 16),
                  const Text('Year: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(width: 6),
                  DropdownButton<int>(
                    value: _selectedExecYear,
                    underline: const SizedBox(),
                    items: [2024, 2025, 2026, 2027, 2028].map((y) => DropdownMenuItem(
                      value: y,
                      child: Text('$y', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 16, color: Color(0xFF0F766E)),
                    label: const Text('Excel Workbook', style: TextStyle(fontSize: 12, color: Color(0xFF0F766E), fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.table_chart, size: 16, color: Color(0xFF1E293B)),
                    label: const Text('CO Summary CSV', style: TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Future Builder for Data
        FutureBuilder<MonthlyParityData>(
          future: _parityFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
            }
            if (snapshot.hasError) {
              return _buildErrorCard(snapshot.error.toString());
            }
            final data = snapshot.data;
            if (data == null) {
              return _buildEmptyCard('No parity data available for selected month.');
            }

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

                  // 8 Summary Cards in Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final cardW = isMobile ? (constraints.maxWidth - 12) / 2 : 170.0;
                      return Column(
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildMetricCard('Principal Disbursed', _formatNgn(cards.disbursedPrincipal), width: cardW),
                              _buildMetricCard('Upfront Fees', _formatNgn(cards.upfrontFees), width: cardW),
                              _buildMetricCard('Net Active Credit', _formatNgn(cards.netActiveCredit), width: cardW),
                              _buildMetricCard('Collections', _formatNgn(cards.collections), width: cardW),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
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
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Sub-Tab Switcher
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Wrap(
                      spacing: 4,
                      children: [
                        _buildSubTabButton('Credit Officers Monthly Summary', 0),
                        _buildSubTabButton('Official Trial Balance', 1),
                        _buildSubTabButton('Receipts & Payments Account', 2),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sub-tab content
                  if (_selectedExecSubTab == 0)
                    _buildCoMonthlySummaryTable(data)
                  else if (_selectedExecSubTab == 1)
                    _buildOfficialTrialBalanceView()
                  else
                    _buildReceiptsAndPaymentsView(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubTabButton(String label, int index) {
    final isSelected = _selectedExecSubTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedExecSubTab = index;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildCoMonthlySummaryTable(MonthlyParityData data) {
    final officers = data.officers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScrollHint(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
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
        ),
      ],
    );
  }

  Widget _buildOfficialTrialBalanceView() {
    return FutureBuilder<MonthlyExecutiveStatementsData>(
      future: _statementsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }
        if (snapshot.hasError) {
          return _buildErrorCard(snapshot.error.toString());
        }
        final data = snapshot.data;
        if (data == null) {
          return _buildEmptyCard('No trial balance statements available.');
        }

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
            _buildScrollHint(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }
        if (snapshot.hasError) {
          return _buildErrorCard(snapshot.error.toString());
        }
        final data = snapshot.data;
        if (data == null) {
          return _buildEmptyCard('No receipts & payments statements available.');
        }

        final rp = data.receiptsAndPayments;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
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
                        Text(_formatNgn(rp.totalReceipts), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF166534), fontFamily: 'JetBrains Mono')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
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
                        Text(_formatNgn(rp.totalPayments), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF), fontFamily: 'JetBrains Mono')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildScrollHint(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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

  // ---------------------------------------------------------------------------
  // Tab 1: Area Branches Comparison (AM Exclusive)
  // ---------------------------------------------------------------------------
  Widget _buildAreaComparisonTab() {
    return FutureBuilder<AreaComparisonData>(
      future: _areaFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
        }
        if (snapshot.hasError) {
          return _buildErrorCard(snapshot.error.toString());
        }
        final data = snapshot.data;
        if (data == null || data.rows.isEmpty) {
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
                  final cardW = isMobile ? (constraints.maxWidth - 12) / 2 : 170.0;
                  return Column(
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildMetricCard('Supervised Branches', '${data.totalBranches}', width: cardW),
                          _buildMetricCard('People on Loan', '${_intFormat.format(data.totalPeopleOnLoan)} Clients', width: cardW),
                          _buildMetricCard('Active Savers', '${_intFormat.format(data.totalActiveSavers)} Savers', width: cardW),
                          _buildMetricCard('Active Loans Count', '${_intFormat.format(data.totalActiveLoans)} Loans', width: cardW),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildMetricCard('Regional Collections', _formatNgn(data.totalAreaCollections), width: cardW),
                          _buildMetricCard('Expected Collections', _formatNgn(data.totalAreaExpected), width: cardW),
                          _buildMetricCard('Area Efficiency', '${data.overallEfficiency.toStringAsFixed(1)}%', width: cardW),
                          _buildMetricCard('Area Savings Portfolio', _formatNgn(data.totalAreaSavings), width: cardW),
                        ],
                      ),
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
              _buildScrollHint(),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
  // Tab 2: General Ledger & Trial Balance
  // ---------------------------------------------------------------------------
  Widget _buildTrialBalanceTab() {
    return FutureBuilder<TrialBalanceData>(
      future: _trialBalanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
        }
        if (snapshot.hasError) return _buildErrorCard(snapshot.error.toString());
        final data = snapshot.data;
        if (data == null || data.rows.isEmpty) {
          return _buildEmptyCard('No ledger entries found for the selected scope.');
        }

        final isBalanced = data.isBalanced;

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
              const Text('General Ledger Trial Balance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              const Text('Double-entry verification of all Chart of Accounts balances. Total Debits must mathematically equal Total Credits.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),

              // Responsive KPI Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final cardW = isMobile ? (constraints.maxWidth - 12) / 2 : 170.0;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildMetricCard('Total Debits', _formatNgn(data.totalDebits), width: cardW),
                      _buildMetricCard('Total Credits', _formatNgn(data.totalCredits), width: cardW),
                      _buildMetricCard('Net Variance', _formatNgn(data.variance), width: cardW),
                      Container(
                        width: cardW,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isBalanced ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isBalanced ? const Color(0xFF166534) : const Color(0xFF991B1B)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LEDGER INTEGRITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                data.status,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isBalanced ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              // Table with mobile scroll cue
              _buildScrollHint(),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Account Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Gross Debits', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Gross Credits', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Debit Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Credit Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Net Position', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: data.rows.map((r) {
                    return DataRow(cells: [
                      DataCell(Text(r.accountCode, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono'))),
                      DataCell(Text(r.accountName)),
                      DataCell(Text(r.accountType)),
                      DataCell(Text(_formatNgn(r.grossDebits), style: const TextStyle(fontFamily: 'JetBrains Mono'))),
                      DataCell(Text(_formatNgn(r.grossCredits), style: const TextStyle(fontFamily: 'JetBrains Mono'))),
                      DataCell(Text(_formatNgn(r.debitBalance), style: const TextStyle(fontFamily: 'JetBrains Mono'))),
                      DataCell(Text(_formatNgn(r.creditBalance), style: const TextStyle(fontFamily: 'JetBrains Mono'))),
                      DataCell(Text(_formatNgn(r.netPosition), style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'JetBrains Mono'))),
                    ]);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              Builder(
                builder: (context) {
                  final isMobile = MediaQuery.of(context).size.width < 750;
                  return SizedBox(
                    width: isMobile ? double.infinity : null,
                    child: ElevatedButton.icon(
                      onPressed: () => _triggerCsvDownload('trial_balance', 'trial_balance.csv'),
                      icon: const Icon(Icons.file_download, size: 16),
                      label: const Text('Download Trial Balance (CSV)'),
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
  // Tab 3: Savings Summary
  // ---------------------------------------------------------------------------
  Widget _buildSavingsSummaryTab() {
    return FutureBuilder<SavingsSummaryData>(
      future: _savingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
        }
        if (snapshot.hasError) return _buildErrorCard(snapshot.error.toString());
        final data = snapshot.data;
        if (data == null || data.savers.isEmpty) {
          return _buildEmptyCard('No active savers found for the selected scope.');
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
              const Text('Savings Portfolio & Savers Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              const Text('Authoritative savings summary derived from individual deposits, group savings, and LAPS reserves.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),

              // Responsive KPI Rows
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final cardW = isMobile ? (constraints.maxWidth - 12) / 2 : 170.0;
                  return Column(
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildMetricCard('Individual Deposits', _formatNgn(data.totalIndividualDeposits), width: cardW),
                          _buildMetricCard('Individual Withdrawals', _formatNgn(data.totalIndividualWithdrawals), width: cardW),
                          _buildMetricCard('Net Individual Savings', _formatNgn(data.netIndividualSavings), width: cardW),
                          _buildMetricCard('Active Savers Count', '${_intFormat.format(data.activeSaversCount)} Clients', width: cardW),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildMetricCard('Net Group Savings', _formatNgn(data.netGroupSavings), width: cardW),
                          _buildMetricCard('LAPS Reserve', _formatNgn(data.lapsReserve), width: cardW),
                          _buildMetricCard('Consolidated Portfolio', _formatNgn(data.totalConsolidatedSavings), isAccent: true, width: cardW),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              const Text('Itemized Savers List', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),

              // DataTable with mobile scroll cue
              _buildScrollHint(),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Client ID', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Group', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Branch', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Officer', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Deposited', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Withdrawn', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Net Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: data.savers.take(100).map((s) {
                    return DataRow(cells: [
                      DataCell(Text(s.clientId, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(s.clientName)),
                      DataCell(Text(s.group)),
                      DataCell(Text(s.branch)),
                      DataCell(Text(s.officer)),
                      DataCell(Text(_formatNgn(s.totalDeposited))),
                      DataCell(Text(_formatNgn(s.totalWithdrawn))),
                      DataCell(Text(_formatNgn(s.netSavingsBalance), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
                    ]);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              Builder(
                builder: (context) {
                  final isMobile = MediaQuery.of(context).size.width < 750;
                  return SizedBox(
                    width: isMobile ? double.infinity : null,
                    child: ElevatedButton.icon(
                      onPressed: () => _triggerCsvDownload('savings', 'savings_summary.csv'),
                      icon: const Icon(Icons.file_download, size: 16),
                      label: const Text('Download Savings Summary (CSV)'),
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
  // Tab 4: Repayment Summary
  // ---------------------------------------------------------------------------
  Widget _buildRepaymentSummaryTab() {
    return FutureBuilder<RepaymentSummaryData>(
      future: _repaymentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
        }
        if (snapshot.hasError) return _buildErrorCard(snapshot.error.toString());
        final data = snapshot.data;
        if (data == null || data.repayments.isEmpty) {
          return _buildEmptyCard('No repayments recorded for the selected scope.');
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
              const Text('Repayments & Collections Performance Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              const Text('Granular collection summary detailing base scheduled collections, full early payoffs, and excess payments.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),

              // KPI Rows with responsive 2-col layout on mobile
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final cardW = isMobile ? (constraints.maxWidth - 12) / 2 : 180.0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildMetricCard('Total Collections', _formatNgn(data.totalCollected), width: cardW),
                          _buildMetricCard('Expected Collections', _formatNgn(data.totalExpected), width: cardW),
                          _buildMetricCard('Collection Efficiency', '${data.collectionEfficiency.toStringAsFixed(1)}%', width: cardW),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildMetricCard('Full Payoffs Settled', _formatNgn(data.fullPayoffAmount), subtitle: '${data.fullPayoffCount} Loans', width: cardW),
                          _buildMetricCard('Excess Surplus Cash', _formatNgn(data.excessPaymentAmount), subtitle: '${data.excessPaymentCount} Events', width: cardW),
                          _buildMetricCard('Overdue Collections', _formatNgn(data.totalOverdueCollected), width: cardW),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              const Text('Collections by Loan Product', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),

              // DataTable with mobile scroll cue
              _buildScrollHint(),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Loan Product', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Collections (NGN)', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Unique Clients', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: data.products.map((p) {
                    return DataRow(cells: [
                      DataCell(Text(p.loanProduct, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(_formatNgn(p.collectionsNgn))),
                      DataCell(Text(_intFormat.format(p.transactions))),
                      DataCell(Text(_intFormat.format(p.uniqueClients))),
                    ]);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              Builder(
                builder: (context) {
                  final isMobile = MediaQuery.of(context).size.width < 750;
                  return SizedBox(
                    width: isMobile ? double.infinity : null,
                    child: ElevatedButton.icon(
                      onPressed: () => _triggerCsvDownload('repayments', 'repayments_summary.csv'),
                      icon: const Icon(Icons.file_download, size: 16),
                      label: const Text('Download Repayments Log (CSV)'),
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
  // Tab 5: Portfolio & Officer Performance
  // ---------------------------------------------------------------------------
  Widget _buildPortfolioPerformanceTab() {
    return FutureBuilder<PortfolioPerformanceData>(
      future: _portfolioFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
        }
        if (snapshot.hasError) return _buildErrorCard(snapshot.error.toString());
        final data = snapshot.data;
        if (data == null) {
          return _buildEmptyCard('No portfolio data available.');
        }

        final risk = data.riskDistribution;

        return Column(
          children: [
            // Card 1: Portfolio Summary & Health
            Container(
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
                  const Text('Portfolio Summary & Health', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final cardW = isMobile ? (constraints.maxWidth - 12) / 2 : 180.0;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildMetricCard('Active Loans', '${data.activeLoans}', width: cardW),
                          _buildMetricCard('Total Portfolio', _formatNgn(data.totalPortfolio), width: cardW),
                          _buildMetricCard('PAR %', '${data.parPercentage.toStringAsFixed(2)}%', width: cardW),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: Officer Performance Breakdown
            Container(
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
                  Builder(
                    builder: (context) {
                      final isMobile = MediaQuery.of(context).size.width < 750;
                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Officer Performance Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: DropdownButtonFormField<String>(
                                value: _inspectOfficer,
                                decoration: _inputDecoration(),
                                items: ['All', ...data.officersList].map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _inspectOfficer = val);
                                    _refreshCurrentTabData();
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Officer Performance Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              value: _inspectOfficer,
                              decoration: _inputDecoration(),
                              items: ['All', ...data.officersList].map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _inspectOfficer = val);
                                  _refreshCurrentTabData();
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  if (data.officerRecords.isNotEmpty) ...[
                    _buildScrollHint(),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Client ID', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Group', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Active Credit', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Loan Repay', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Loan Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Savings', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Overdue', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: data.officerRecords.take(50).map((r) {
                          return DataRow(cells: [
                            DataCell(Text(r.clientId, style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text(r.clientName)),
                            DataCell(Text(r.group)),
                            DataCell(Text(r.product)),
                            DataCell(Text(_formatNgn(r.activeCredit))),
                            DataCell(Text(_formatNgn(r.loanRepay))),
                            DataCell(Text(_formatNgn(r.loanBalance))),
                            DataCell(Text(_formatNgn(r.savings))),
                            DataCell(Text(_formatNgn(r.overdue), style: TextStyle(color: r.overdue > 0 ? const Color(0xFFDC2626) : Colors.black))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ] else
                    const Text('No records found for the selected officer inspector.', style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: Client Risk Rating & Credit Intelligence
            Container(
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
                  const Text('Client Risk Rating & Credit Intelligence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  const Text('Automated credit risk evaluation, repayment compliance, and upgrade eligibility recommendations.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final cardW = isMobile ? (constraints.maxWidth - 12) / 2 : 150.0;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildRiskCard('EXCELLENT', 'Upgrade', risk['EXCELLENT'] ?? 0, const Color(0xFF166534), const Color(0xFFF0FDF4), width: cardW),
                          _buildRiskCard('GOOD', 'Maintain', risk['GOOD'] ?? 0, const Color(0xFF2563EB), const Color(0xFFEFF6FF), width: cardW),
                          _buildRiskCard('FAIR', 'Monitor', risk['FAIR'] ?? 0, const Color(0xFFD97706), const Color(0xFFFFFBEB), width: cardW),
                          _buildRiskCard('RISKY', 'No Increase', risk['RISKY'] ?? 0, const Color(0xFFEA580C), const Color(0xFFFFF7ED), width: cardW),
                          _buildRiskCard('HIGH RISK', 'Decline', risk['HIGH_RISK'] ?? 0, const Color(0xFFDC2626), const Color(0xFFFEF2F2), width: cardW),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 6: Data Exports & Downloads
  // ---------------------------------------------------------------------------
  Widget _buildDataExportsTab(bool isAm) {
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
          const SizedBox(height: 24),

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isAccent ? const Color(0xFF064E3B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isAccent ? const Color(0xFF064E3B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
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
                fontSize: 15,
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

  Widget _buildRiskCard(String level, String action, int count, Color textColor, Color bgColor, {double? width}) {
    return Container(
      width: width ?? 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('[$level] $action', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 6),
          Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor, fontFamily: 'JetBrains Mono')),
        ],
      ),
    );
  }

  Widget _buildScrollHint() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.swipe, size: 14, color: Color(0xFF94A3B8)),
          SizedBox(width: 6),
          Text('Scroll horizontally for complete table', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
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
