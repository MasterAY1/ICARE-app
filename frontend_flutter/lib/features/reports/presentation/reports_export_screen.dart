// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/presentation/co_app_scaffold.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/app_error_formatter.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../data/datasources/reports_api_service.dart';
import '../data/models/report_models.dart';
import '../../shared/utils/file_download_helper.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import 'widgets/bank_reconciliation_form_widget.dart';

/// Target branch filter passed from external navigation (AM Dashboard, AM Portfolio, etc.)
final reportsTargetBranchProvider = StateProvider<String?>((ref) => null);

/// Target tab index (0: Monthly Executive Statements, 1: Area Branches Comparison, 2: Data Exports & Downloads)
final reportsTargetTabProvider = StateProvider<int?>((ref) => null);

/// Target sub-tab index within Monthly Executive Statements (0: Deposits, 1: Credit, 2: Receipts & Payments, 3: Annex-1, 4: Trial Balance, 5: CO Summary, 6: Bank Rec)
final reportsTargetSubTabProvider = StateProvider<int?>((ref) => null);

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


  // Monthly Executive Parity State (defaults to current calendar month & year)
  int _selectedExecMonth = DateTime.now().month;
  int _selectedExecYear = DateTime.now().year;
  int _selectedExecSubTab = 0; // 0: A. Deposit Statement, 1: B. Credit Statement, 2: Receipts & Payments, 3: Annex-1 Sundry, 4: Trial Balance, 5: CO Summary, 6: Bank Reconciliation
  String _selectedDepositProgramFilter = 'All'; // 'All', 'Monthly', 'Weekly', 'Daily'
  String _selectedCreditProgramFilter = 'Consolidated Total'; // 'Consolidated Total', 'Monthly', 'Weekly', 'Daily'
  bool _showRawTableOnMobile = false;
  bool _showAllParityCards = false;
  String _selectedTbSectionFilter = 'All';
  int _selectedRpSegmentIndex = 0; // 0: All Movements, 1: Receipts (Inflows), 2: Payments (Outflows)

  // Futures & Cache
  ReportsMeta? _cachedMeta;
  Future<ReportsMeta>? _metaFuture;
  Future<AreaComparisonData>? _areaFuture;
  Future<MonthlyParityData>? _parityFuture;
  Future<MonthlyExecutiveStatementsData>? _statementsFuture;
  Future<Annex1ReportData>? _annex1Future;
  Future<MonthlyReconciliationData>? _reconciliationFuture;
  Future<MonthlyWorkflowStatusModel>? _workflowStatusFuture;
  Future<List<MonthlyWorkflowPendingBranchModel>>? _pendingSubmissionsFuture;
  bool _isWorkflowSubmitting = false;

  final _currencyFormat = NumberFormat('#,##0.00');
  final _intFormat = NumberFormat('#,##0');
  final _dateFormat = DateFormat('yyyy-MM-dd');
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

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

    // Resolve external target parameters if passed from AM dashboard or portfolio
    final targetBranch = ref.read(reportsTargetBranchProvider);
    if (targetBranch != null) {
      _selectedBranchName = targetBranch;
    }
    final targetTab = ref.read(reportsTargetTabProvider);
    if (targetTab != null) {
      final auth = ref.read(authControllerProvider);
      final u = auth is AuthStateAuthenticated ? auth.user : null;
      final isAmUser = u?.role == 'Area Manager' || u?.role == 'AM';
      if (isAmUser) {
        if (targetTab == 0) {
          _selectedTabIndex = 1; // Branch Statements & Sign-Off
        } else if (targetTab == 1) {
          _selectedTabIndex = 0; // Regional Comparison
        } else {
          _selectedTabIndex = 2; // Data Exports
        }
      } else {
        _selectedTabIndex = targetTab;
      }
    }
    final targetSubTab = ref.read(reportsTargetSubTabProvider);
    if (targetSubTab != null) {
      _selectedExecSubTab = targetSubTab;
    }

    Future.microtask(() {
      if (mounted) {
        ref.read(reportsTargetBranchProvider.notifier).state = null;
        ref.read(reportsTargetTabProvider.notifier).state = null;
        ref.read(reportsTargetSubTabProvider.notifier).state = null;
      }
    });

    _initFutures();
  }

  void _initFutures() {
    final authState = ref.read(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    if (user == null) return;
    final role = user.role.trim();
    final isCoUser = role == 'Credit Officer' || role == 'CO' || role == 'Officer';
    if (isCoUser) return;

    final isAmUser = role == 'Area Manager' || role == 'AM';
    final isAdminUser = role == 'Admin' || role == 'Super Admin' || role == 'ADMIN' || role == 'Director' || role == 'DIRECTOR' || role == 'Executive Director';

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
    _workflowStatusFuture = api.getMonthlyWorkflowStatus(
      branchName: _selectedBranchName,
      year: _selectedExecYear,
      month: _selectedExecMonth,
    );
    if (isAmUser || isAdminUser) {
      _pendingSubmissionsFuture = api.getPendingAmMonthlySubmissions(
        year: _selectedExecYear,
        month: _selectedExecMonth,
      );
      _areaFuture = api.getAreaComparison(
        productName: _selectedProductName,
        asOfDate: asOfStr,
        startDate: startStr,
        endDate: endStr,
      );
    }

    // Fetch metadata asynchronously for branch/product/officer options
    _metaFuture = api.getReportsMeta().then((meta) {
      if (mounted) {
        setState(() {
          _cachedMeta = meta;
          if (_selectedBranchName == null) {
            if (meta.scopeLevel == 'BRANCH' && meta.defaultBranch != null) {
              _selectedBranchName = meta.defaultBranch;
            } else {
              _selectedBranchName = meta.defaultBranch ?? (meta.branches.isNotEmpty ? meta.branches.first.name : null);
            }
            _refreshCurrentTabData();
          }
        });
      }
      return meta;
    });
  }

  void _refreshCurrentTabData() {
    final authState = ref.read(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    if (user == null) return;
    final role = user.role.trim();
    final isCoUser = role == 'Credit Officer' || role == 'CO' || role == 'Officer';
    if (isCoUser) return;

    final isAmUser = role == 'Area Manager' || role == 'AM';
    final isAdminUser = role == 'Admin' || role == 'Super Admin' || role == 'ADMIN' || role == 'Director' || role == 'DIRECTOR' || role == 'Executive Director';

    final api = ref.read(reportsApiServiceProvider);
    final asOfStr = _dateMode == 'As of Date' ? _dateFormat.format(_asOfDate) : null;
    final startStr = _dateMode == 'Date Range' ? _dateFormat.format(_startDate) : null;
    final endStr = _dateMode == 'Date Range' ? _dateFormat.format(_endDate) : null;

    setState(() {
      if (isAmUser || isAdminUser) {
        _areaFuture = api.getAreaComparison(
          productName: _selectedProductName,
          asOfDate: asOfStr,
          startDate: startStr,
          endDate: endStr,
        );
        _pendingSubmissionsFuture = api.getPendingAmMonthlySubmissions(
          year: _selectedExecYear,
          month: _selectedExecMonth,
        );
      }
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
      _workflowStatusFuture = api.getMonthlyWorkflowStatus(
        branchName: _selectedBranchName,
        year: _selectedExecYear,
        month: _selectedExecMonth,
      );
    });
  }

  String _formatNgn(double value) => '₦${_currencyFormat.format(value)}';

  @override
  Widget build(BuildContext context) {
    // Reactive listeners for context updates while already mounted
    ref.listen<String?>(reportsTargetBranchProvider, (prev, next) {
      if (next != null) {
        setState(() => _selectedBranchName = next);
        _refreshCurrentTabData();
        Future.microtask(() {
          if (mounted) ref.read(reportsTargetBranchProvider.notifier).state = null;
        });
      }
    });

    ref.listen<int?>(reportsTargetTabProvider, (prev, next) {
      if (next != null) {
        final auth = ref.read(authControllerProvider);
        final u = auth is AuthStateAuthenticated ? auth.user : null;
        final isAmUser = u?.role == 'Area Manager' || u?.role == 'AM';
        final resolvedIndex = isAmUser
            ? (next == 0 ? 1 : (next == 1 ? 0 : 2))
            : next;
        setState(() => _selectedTabIndex = resolvedIndex);
        _refreshCurrentTabData();
        Future.microtask(() {
          if (mounted) ref.read(reportsTargetTabProvider.notifier).state = null;
        });
      }
    });

    ref.listen<int?>(reportsTargetSubTabProvider, (prev, next) {
      if (next != null) {
        setState(() => _selectedExecSubTab = next);
        _refreshCurrentTabData();
        Future.microtask(() {
          if (mounted) ref.read(reportsTargetSubTabProvider.notifier).state = null;
        });
      }
    });

    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;

    if (user == null) {
      return const Center(child: Text('Session expired. Please re-login.'));
    }

    final role = user.role.trim();
    final isCo = role == 'Credit Officer' || role == 'CO' || role == 'Officer';
    final isDirector = role == 'Director' || role == 'DIRECTOR' || role == 'Executive Director';
    final isAdmin = role == 'Admin' || role == 'Super Admin' || role == 'ADMIN' || isDirector;
    final isBm = role == 'Branch Manager' || role == 'BM';
    final isAm = role == 'Area Manager' || role == 'AM';
    final tokens = IcareSurfaceTokens.of(context);

    // Access guard: CO prohibited
    if (isCo) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: tokens.dangerBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.dangerBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.gpp_bad, color: tokens.dangerDot, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Access Denied: You do not have permission to access Reports & Export.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.dangerText),
              ),
            ),
          ],
        ),
      );
    }

    List<String> tabs;
    if (isAm) {
      tabs = [
        'Regional Comparison',
        'Branch Statements & Sign-Off',
        'Data Exports & Downloads',
      ];
    } else if (isAdmin) {
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

    ref.listen<int>(globalRefreshSignalProvider, (prev, next) {
      if (next != prev) {
        _refreshCurrentTabData();
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Role-Specific Header & Identity Banner
        _buildIdentityBanner(isAdmin, isBm, isAm, user.branch, isDirector: isDirector),
        const SizedBox(height: 16),

        // 2. Pill Tabs Navigation
        _buildPillTabs(tabs),
        const SizedBox(height: 16),

        // 3. Tab Content
        _buildActiveTabContent(tabs[_selectedTabIndex], isAdmin, isBm, isAm),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Identity Banner
  // ---------------------------------------------------------------------------
  Widget _buildIdentityBanner(bool isAdmin, bool isBm, bool isAm, String userBranch, {bool isDirector = false}) {
    final tokens = IcareSurfaceTokens.of(context);
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
      badgeBg = tokens.infoBg;
      badgeBorder = tokens.infoBorder;
      badgeText = tokens.infoText;
    } else if (isAm) {
      title = 'Area Manager Regional Executive Reports';
      subtitle = 'Multi-branch regional supervision, cross-branch comparative analysis, and operational performance.';
      badgeTitle = 'SUPERVISED AREA';
      badgeSubtitle = 'Regional Supervised Branches';
      badgeBg = tokens.brandSoftBg;
      badgeBorder = tokens.brandSoftBorder;
      badgeText = tokens.brandSoftText;
    } else {
      title = isDirector
          ? 'Director Executive Oversight Reports'
          : 'Enterprise Financial & Operational Reports';
      subtitle = 'Consolidated institutional double-entry trial balance, savings portfolios, collections, and multi-branch data exports.';
      badgeTitle = 'SCOPE LEVEL';
      badgeSubtitle = isDirector ? 'Institutional Scope (Read-Only)' : 'Institutional Scope';
      badgeBg = tokens.isDark ? const Color(0xFF2E1065) : const Color(0xFFFAF5FF);
      badgeBorder = tokens.isDark ? const Color(0xFF7E22CE) : const Color(0xFFA855F7);
      badgeText = tokens.isDark ? const Color(0xFFD8B4FE) : const Color(0xFF581C87);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 680;

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
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeText),
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
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                    const SizedBox(height: 10),
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
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                              fontFamily: 'Plus Jakarta Sans',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(fontSize: 13, color: tokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    badgeWidget,
                  ],
                ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Custom Export Filters Card (For Data Exports Tab)
  // ---------------------------------------------------------------------------
  Widget _buildExportFilterCard(bool isAdmin, bool isBm, bool isAm) {
    final tokens = IcareSurfaceTokens.of(context);
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

        if (_selectedBranchName != null && branches.isNotEmpty && !branchOptions.contains(_selectedBranchName)) {
          _selectedBranchName = branchOptions.first;
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(
                'Customize Export Parameters (Optional: Product, Officer, Date Range)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
              ),
              subtitle: Text(
                'Active: ${_selectedBranchName ?? 'All Branches'} • $_selectedProductName • $_selectedOfficerName • $_dateMode',
                style: TextStyle(fontSize: 11, color: tokens.textMuted),
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
                      Text('Branch Scope', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
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
                      Text('Loan Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
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
                      Text('Credit Officer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
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
                      Text('Date Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
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
                      Text('As of Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
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
                            color: tokens.surfaceSubtle,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: tokens.borderStrong),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_dateFormat.format(_asOfDate), style: TextStyle(fontSize: 13, color: tokens.textPrimary)),
                              Icon(Icons.calendar_today, size: 16, color: tokens.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );

                  final startDateWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
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
                            color: tokens.surfaceSubtle,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: tokens.borderStrong),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_dateFormat.format(_startDate), style: TextStyle(fontSize: 12, color: tokens.textPrimary)),
                              Icon(Icons.calendar_today, size: 14, color: tokens.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );

                  final endDateWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('End Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
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
                            color: tokens.surfaceSubtle,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: tokens.borderStrong),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_dateFormat.format(_endDate), style: TextStyle(fontSize: 12, color: tokens.textPrimary)),
                              Icon(Icons.calendar_today, size: 14, color: tokens.textMuted),
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
    final auth = ref.watch(authControllerProvider);
    final u = auth is AuthStateAuthenticated ? auth.user : null;
    final role = (u?.role ?? '').trim().toLowerCase();
    final isBm = role == 'branch manager' || role == 'bm';
    final isAm = role == 'area manager' || role == 'am';
    final tokens = IcareSurfaceTokens.of(context);
    final activeThemeColor = isBm
        ? const Color(0xFF1D4ED8)
        : (isAm ? tokens.brandPrimary : tokens.brandPrimaryDark);

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
                  color: isSelected ? activeThemeColor : tokens.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? activeThemeColor : tokens.borderSubtle,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: activeThemeColor.withValues(alpha: 0.18),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : tokens.textSecondary,
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
      case 'Regional Comparison':
      case 'Area Branches Comparison':
        return _buildAreaComparisonTab(isAdmin: isAdmin, isAm: isAm);
      case 'Branch Statements & Sign-Off':
      case 'Monthly Executive Statements':
      case 'Monthly Executive Parity':
        return _buildMonthlyExecutiveParityTab(isAdmin, isBm, isAm);
      case 'Data Exports & Downloads':
        return _buildDataExportsTab(isAdmin, isBm, isAm);
      default:
        return _buildMonthlyExecutiveParityTab(isAdmin, isBm, isAm);
    }
  }

  // ---------------------------------------------------------------------------
  // Supervised Branch Switcher Bar (Area Manager Exclusive)
  // ---------------------------------------------------------------------------
  Widget _buildAmBranchSwitcherBar() {
    final branches = _cachedMeta?.branches ?? [];
    if (branches.isEmpty) return const SizedBox.shrink();
    final tokens = IcareSurfaceTokens.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              Icon(Icons.apartment, size: 16, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Text(
                'Supervised Branch Switcher',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                'Viewing: ${_selectedBranchName ?? "Select Branch"}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: tokens.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final b in branches) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(
                        Icons.storefront,
                        size: 14,
                        color: _selectedBranchName == b.name ? Colors.white : tokens.brandPrimary,
                      ),
                      label: Text(
                        b.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _selectedBranchName == b.name ? FontWeight.w800 : FontWeight.w600,
                          color: _selectedBranchName == b.name ? Colors.white : tokens.textPrimary,
                        ),
                      ),
                      selected: _selectedBranchName == b.name,
                      selectedColor: tokens.brandPrimaryDark,
                      backgroundColor: tokens.surfaceSubtle,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(
                        color: _selectedBranchName == b.name ? tokens.brandPrimaryDark : tokens.borderStrong,
                      ),
                      onSelected: (selected) {
                        if (selected && _selectedBranchName != b.name) {
                          setState(() {
                            _selectedBranchName = b.name;
                            _refreshCurrentTabData();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tab 0: Monthly Executive Parity Suite
  // ---------------------------------------------------------------------------
  Widget _buildMonthlyExecutiveParityTab(bool isAdmin, bool isBm, bool isAm) {
    final tokens = IcareSurfaceTokens.of(context);
    final api = ref.read(reportsApiServiceProvider);
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final currentCalendarMonth = DateTime.now().month;
    final currentCalendarYear = DateTime.now().year;
    final lookbackPeriods = [
      for (final offset in [3, 2, 1, 0])
        DateTime(currentCalendarYear, currentCalendarMonth - offset, 1),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAm) ...[
          _buildAmBranchSwitcherBar(),
          const SizedBox(height: 12),
        ],
        // 1. Sleek Interactive Period Stepper & Export Action Bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: LayoutBuilder(
            builder: (layoutCtx, constraints) {
              final isNarrow = constraints.maxWidth < 750;

              // Interactive Period Stepper: [ < ] Month Year [ > ]
              final periodStepper = Container(
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, size: 18, color: tokens.brandPrimary),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Previous Month',
                      onPressed: () {
                        setState(() {
                          if (_selectedExecMonth == 1) {
                            _selectedExecMonth = 12;
                            _selectedExecYear -= 1;
                          } else {
                            _selectedExecMonth -= 1;
                          }
                          _refreshCurrentTabData();
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${monthNames[_selectedExecMonth - 1]} $_selectedExecYear',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, size: 18, color: tokens.brandPrimary),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Next Month',
                      onPressed: () {
                        setState(() {
                          if (_selectedExecMonth == 12) {
                            _selectedExecMonth = 1;
                            _selectedExecYear += 1;
                          } else {
                            _selectedExecMonth += 1;
                          }
                          _refreshCurrentTabData();
                        });
                      },
                    ),
                  ],
                ),
              );

              // Quick Month Selectors: [Jul] [Aug] [Sep] [Oct (Now)]
              final quickChips = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final dt in lookbackPeriods) ...[
                      Builder(
                        builder: (context) {
                          final m = dt.month;
                          final y = dt.year;
                          final isSelected = _selectedExecMonth == m && _selectedExecYear == y;
                          final isCurrent = m == currentCalendarMonth && y == currentCalendarYear;
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ChoiceChip(
                              label: Text(
                                isCurrent
                                    ? '${monthNames[m - 1].substring(0, 3)} (Now)'
                                    : (y != currentCalendarYear
                                        ? "${monthNames[m - 1].substring(0, 3)} '${(y % 100).toString().padLeft(2, '0')}"
                                        : monthNames[m - 1].substring(0, 3)),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? Colors.white : tokens.textSecondary,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: tokens.brandPrimaryDark,
                              backgroundColor: tokens.surfaceHover,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(
                                color: isSelected ? tokens.brandPrimaryDark : tokens.borderSubtle,
                              ),
                              onSelected: (selected) {
                                if (selected && !isSelected) {
                                  setState(() {
                                    _selectedExecMonth = m;
                                    _selectedExecYear = y;
                                    _refreshCurrentTabData();
                                  });
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              );

              // 3 Export Buttons: PDF, Excel, CSV
              final pdfBtn = OutlinedButton.icon(
                icon: Icon(Icons.picture_as_pdf_outlined, size: 13, color: tokens.dangerText),
                label: Text('PDF Statement (Print)', style: TextStyle(fontSize: 11, color: tokens.dangerText, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.dangerBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () async {
                  try {
                    final bytes = await api.downloadMonthlyParityPdf(
                      branchName: _selectedBranchName,
                      year: _selectedExecYear,
                      month: _selectedExecMonth,
                      officerName: _selectedOfficerName,
                      productName: _selectedProductName,
                    );
                    final saved = await downloadBlobFile(
                      bytes,
                      'Official_Executive_Financial_Statement_${_selectedExecYear}_${_selectedExecMonth.toString().padLeft(2, '0')}.pdf',
                      'application/pdf',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Executive PDF Statement downloaded${saved != null ? ' ($saved)' : ''}.')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('PDF Download failed: ${AppErrorDetails.from(e).message}')),
                      );
                    }
                  }
                },
              );

              final excelBtn = OutlinedButton.icon(
                icon: Icon(Icons.table_view_outlined, size: 13, color: tokens.brandPrimary),
                label: Text('Excel Statement (All Sheets)', style: TextStyle(fontSize: 11, color: tokens.brandPrimary, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.brandPrimary),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  visualDensity: VisualDensity.compact,
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
                    final saved = await downloadBlobFile(
                      bytes,
                      'Executive_Monthly_Report_${_selectedExecYear}_${_selectedExecMonth.toString().padLeft(2, '0')}.xlsx',
                      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Executive Workbook downloaded${saved != null ? ' ($saved)' : ''}.')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Download failed: ${AppErrorDetails.from(e).message}')),
                      );
                    }
                  }
                },
              );

              final csvBtn = OutlinedButton.icon(
                icon: Icon(Icons.grid_on_outlined, size: 13, color: tokens.textSecondary),
                label: Text('CO Summary CSV', style: TextStyle(fontSize: 11, color: tokens.textSecondary, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.borderStrong),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  visualDensity: VisualDensity.compact,
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
                    final saved = await downloadBlobFile(
                      bytes,
                      'CO_Monthly_Summary_${_selectedExecYear}_${_selectedExecMonth.toString().padLeft(2, '0')}.csv',
                      'text/csv',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('CO Summary CSV downloaded${saved != null ? ' ($saved)' : ''}.')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Download failed: ${AppErrorDetails.from(e).message}')),
                      );
                    }
                  }
                },
              );

              // Secondary Scope Controls: Branch, Officer, Product
              Widget? branchControl;
              if (isAdmin || isAm) {
                final branches = _cachedMeta?.branches ?? [];
                final options = isAm
                    ? ['All Assigned Branches (Consolidated Area View)', ...branches.map((b) => b.name)]
                    : ['All Branches (Consolidated)', ...branches.map((b) => b.name)];
                final currBranch = _selectedBranchName ?? (options.isNotEmpty ? options.first : null);
                branchControl = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: options.contains(currBranch) ? currBranch : (options.isNotEmpty ? options.first : null),
                      isDense: true,
                      dropdownColor: tokens.surfaceElevated,
                      items: options.map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(b, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary), overflow: TextOverflow.ellipsis),
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
                  ),
                );
              }

              final products = _cachedMeta != null ? ['All Products', ..._cachedMeta!.products] : ['All Products'];
              final officers = _cachedMeta != null
                  ? ['All Officers', ..._cachedMeta!.officers.map((o) => o.fullName)]
                  : ['All Officers'];

              final officerControl = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: officers.contains(_selectedOfficerName) ? _selectedOfficerName : officers.first,
                    isDense: true,
                    dropdownColor: tokens.surfaceElevated,
                    items: officers.map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(o, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary), overflow: TextOverflow.ellipsis),
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
                ),
              );

              final productControl = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: products.contains(_selectedProductName) ? _selectedProductName : products.first,
                    isDense: true,
                    dropdownColor: tokens.surfaceElevated,
                    items: products.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary), overflow: TextOverflow.ellipsis),
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
                ),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Period Navigation & Exports
                  if (isNarrow) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        periodStepper,
                        quickChips,
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (branchControl != null) branchControl,
                        officerControl,
                        productControl,
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        pdfBtn,
                        excelBtn,
                        csvBtn,
                      ],
                    ),
                  ] else ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            periodStepper,
                            quickChips,
                          ],
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            pdfBtn,
                            excelBtn,
                            csvBtn,
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (branchControl != null) branchControl,
                        officerControl,
                        productControl,
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Monthly Verification & Sign-Off Workflow Status Banner
        _buildWorkflowStatusCard(isAdmin, isBm, isAm),
        const SizedBox(height: 12),

        // Hero KPI Summary Strip (backed by _parityFuture)
        FutureBuilder<MonthlyParityData>(
          future: _parityFuture,
          builder: (context, snapshot) {
            if (_parityFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
              if (snapshot.hasError) {
                return _buildErrorCard(snapshot.error!, onRetry: _refreshCurrentTabData);
              }
              return const IcareTableSkeleton(rowCount: 2, hasFilterBar: false);
            }
            final data = snapshot.data!;
            final cards = data.summaryCards;

            return LayoutBuilder(
              builder: (ctx, constraints) {
                final isMobile = constraints.maxWidth < 650;
                final cardW = isMobile
                    ? (constraints.maxWidth - 8) / 2
                    : (constraints.maxWidth - 36) / 4;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Header: Branch & Period
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Executive Monthly Summary — ${data.branchName} (${data.monthLabel})',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          icon: Icon(
                            _showAllParityCards ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 16,
                            color: tokens.brandPrimary,
                          ),
                          label: Text(
                            _showAllParityCards ? 'Less Metrics' : 'More Metrics (4)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.brandPrimary),
                          ),
                          onPressed: () {
                            setState(() {
                              _showAllParityCards = !_showAllParityCards;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Hero 4 KPI Cards (Disbursed, Collections, Net Credit, GL Integrity)
                    Wrap(
                      spacing: isMobile ? 8 : 12,
                      runSpacing: isMobile ? 8 : 12,
                      children: [
                        _buildMetricCard('Principal Disbursed', _formatNgn(cards.disbursedPrincipal), width: cardW),
                        _buildMetricCard('Period Collections', _formatNgn(cards.collections), width: cardW),
                        _buildMetricCard('Net Active Credit', _formatNgn(cards.netActiveCredit), width: cardW),
                        _buildMetricCard(
                          'GL Balance Integrity',
                          cards.isGlBalanced ? '[BALANCED]' : '[OUT OF BALANCE]',
                          width: cardW,
                          isAccent: cards.isGlBalanced,
                          subtitle: 'Debits == Credits',
                        ),
                        if (_showAllParityCards) ...[
                          _buildMetricCard('Upfront Fees (5%)', _formatNgn(cards.upfrontFees), width: cardW),
                          _buildMetricCard('Closing Credit Portfolio', _formatNgn(cards.closingCredit), width: cardW),
                          _buildMetricCard('Closing Savings Balance', _formatNgn(cards.closingSavings), width: cardW),
                          _buildMetricCard('Transit Bank Deposits', _formatNgn(cards.bankDeposits), width: cardW),
                        ],
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),

        // Sub-Tab Switcher (Single-line horizontal scroll — decoupled from _parityFuture)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: tokens.surfaceHover,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
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
        const SizedBox(height: 14),

        // Sub-tab content view (each sub-tab manages its own FutureBuilder)
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
          FutureBuilder<MonthlyParityData>(
            future: _parityFuture,
            builder: (context, snapshot) {
              if (_parityFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
                if (snapshot.hasError) {
                  return _buildErrorCard(snapshot.error!, onRetry: _refreshCurrentTabData);
                }
                return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
              }
              return _buildCoMonthlySummaryTable(snapshot.data!);
            },
          )
        else
          _buildBankReconciliationView(),
      ],
    );
  }

  Widget _buildSubTabButton(String label, int index, {IconData? icon}) {
    final tokens = IcareSurfaceTokens.of(context);
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
          color: isSelected ? tokens.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.2 : 0.06), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? tokens.brandPrimary : tokens.textMuted,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? tokens.textPrimary : tokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramFilterChips(List<String> options, String selectedValue, ValueChanged<String> onSelected) {
    final tokens = IcareSurfaceTokens.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: options.map((opt) {
          final isSelected = selectedValue == opt || (selectedValue == 'All' && opt == 'All Programmes');
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(opt, style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : tokens.textSecondary,
              )),
              selected: isSelected,
              selectedColor: tokens.brandPrimaryDark,
              backgroundColor: tokens.surfaceHover,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? tokens.brandPrimaryDark : tokens.borderSubtle)),
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
    final tokens = IcareSurfaceTokens.of(context);
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
                color: isPrimary ? tokens.textPrimary : tokens.textMuted,
                fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isPrimary ? 13 : 12,
              fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w600,
              color: isPrimary ? tokens.brandPrimary : tokens.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _cleanCoMetricLabel(String metric) {
    return metric
        .replaceAll('(PC1)', '')
        .replaceAll('(PB3)', '')
        .replaceAll('(PB4)', '')
        .replaceAll('(PB2/PB6)', '')
        .replaceAll('(Acct 1050)', '')
        .replaceAll('(Acct 4000)', '')
        .replaceAll('•', '')
        .trim();
  }

  Widget _buildCoMonthlySummaryTable(MonthlyParityData data) {
    final tokens = IcareSurfaceTokens.of(context);
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
                    Text('Credit Officers Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                    IconButton(
                      tooltip: _showRawTableOnMobile ? 'Switch to Cards' : 'Switch to Table',
                      icon: Icon(_showRawTableOnMobile ? Icons.view_agenda_outlined : Icons.table_chart_outlined, color: tokens.brandPrimary),
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
                double getMetric(String m, [String? fallback]) {
                  final row = data.rows.firstWhere(
                    (r) => r.metric == m || (fallback != null && r.metric == fallback) || r.metric.toLowerCase().contains(m.toLowerCase()),
                    orElse: () => MonthlyParityMetricRow(metric: m, values: {}),
                  );
                  return (row.values[o.name] as num? ?? 0.0).toDouble();
                }
                int getCount(String m) => (data.rows.firstWhere((r) => r.metric == m, orElse: () => MonthlyParityMetricRow(metric: m, values: {})).values[o.name] as num? ?? 0).toInt();

                final disb = getMetric('Sales (Credit) / Principal Disbursed');
                final col = getMetric('Installment Collection (Repayments)');
                final closeCredit = getMetric('Closing Credit Balance');
                final sDep = getMetric('Savings Deposit (Month)');
                final sWth = getMetric('Savings Withdrawal (Month)');
                final sClose = getMetric('Savings Closing Balance');
                final bd = getMetric('Transit Bank Deposits Remitted', 'Bank Deposits Remitted (Acct 1050)');

                final trans = getMetric('Field Transport & Travel', 'Field Transport (PC1)');
                final stat = getMetric('Printing & Stationery', 'Stationery (PB3)');
                final ent = getMetric('Entertainment & Refreshment', 'Entertainment (PB4)');
                final util = getMetric('Utilities & Communication', 'Utilities & Phone (PB2/PB6)');
                final totOpEx = getMetric('Total Operating Expenses (OpEx)', 'Office Expenses (Acct 4000)');

                final actLoans = getCount('Active Loans Count');
                final actSavers = getCount('Active Savers Count');

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.borderSubtle),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.16 : 0.025), blurRadius: 4, offset: const Offset(0, 1))],
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
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tokens.brandPrimary),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: tokens.surfaceHover, borderRadius: BorderRadius.circular(12)),
                            child: Text(o.username ?? 'Credit Officer', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.textSecondary)),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      _buildMobileDetailRow('Transit Bank Deposits Remitted', _formatNgn(bd), isPrimary: true),
                      const SizedBox(height: 6),
                      _buildMobileDetailRow('Active Portfolio', '$actLoans loans | ${_formatNgn(closeCredit)}'),
                      _buildMobileDetailRow('Month Collections', _formatNgn(col)),
                      _buildMobileDetailRow('Month Disbursements', _formatNgn(disb)),
                      const Divider(height: 16),
                      _buildMobileDetailRow('Active Savers', '$actSavers savers | ${_formatNgn(sClose)}'),
                      _buildMobileDetailRow('Month Savings (In / Out)', '${_formatNgn(sDep)} / ${_formatNgn(sWth)}'),
                      const Divider(height: 16),
                      Text('Analysed Operational Expenses (OpEx):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.textMuted)),
                      const SizedBox(height: 4),
                      _buildMobileDetailRow('Field Transport & Travel', _formatNgn(trans)),
                      _buildMobileDetailRow('Printing & Stationery', _formatNgn(stat)),
                      _buildMobileDetailRow('Entertainment & Refreshment', _formatNgn(ent)),
                      _buildMobileDetailRow('Utilities & Communication', _formatNgn(util)),
                      _buildMobileDetailRow('Total Analysed OpEx Disbursed', _formatNgn(totOpEx), isPrimary: true),
                    ],
                  ),
                );
              }),
            ] else ...[
              _buildContainedTable(
                hint: 'Swipe horizontally to view all credit officers',
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(tokens.surfaceSubtle),
                  headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary, fontSize: 12),
                  dataTextStyle: TextStyle(fontSize: 12, color: tokens.textSecondary),
                  columnSpacing: 20,
                  columns: [
                    const DataColumn(label: Text('Financial Metric')),
                    ...officers.map((o) => DataColumn(numeric: true, label: Text(o.name))),
                    DataColumn(numeric: true, label: Text(data.totalColName, style: TextStyle(fontWeight: FontWeight.w800, color: tokens.textPrimary))),
                  ],
                  rows: data.rows.map((r) {
                    final isCount = r.metric.contains('Count');
                    final isHighlight = r.metric.contains('Total') || r.metric.contains('Expenses') || r.metric.contains('Bank');
                    return DataRow(
                      cells: [
                        DataCell(Text(_cleanCoMetricLabel(r.metric), style: TextStyle(fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600, color: isHighlight ? tokens.brandPrimary : tokens.textSecondary))),
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
                            return Text(disp, style: TextStyle(fontWeight: FontWeight.w800, color: tokens.textPrimary));
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
    final tokens = IcareSurfaceTokens.of(context);
    return FutureBuilder<MonthlyExecutiveStatementsData>(
      future: _statementsFuture,
      builder: (context, snapshot) {
        if (_statementsFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          if (snapshot.hasError) {
            return _buildErrorCard(snapshot.error!, onRetry: _refreshCurrentTabData);
          }
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }
        final data = snapshot.data!;
        final ds = data.depositStatement;
        if (ds == null || ds.rows.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text('No Deposit Statement records available for this period.', style: TextStyle(color: tokens.textMuted)),
          ));
        }

        final totRow = ds.rows.firstWhere((r) => r.programme == 'Total', orElse: () => ds.rows.last);
        final isAllPrograms = _selectedDepositProgramFilter == 'All' || _selectedDepositProgramFilter == 'All Programmes';
        final activeKpiRow = isAllPrograms
            ? totRow
            : ds.rows.firstWhere(
                (r) => r.programme.toLowerCase() == _selectedDepositProgramFilter.toLowerCase(),
                orElse: () => totRow,
              );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final cardW = isMobile ? (constraints.maxWidth - 8) / 2 : (constraints.maxWidth - 24) / 4;

            final filteredRows = isAllPrograms
                ? ds.rows
                : ds.rows.where((r) => r.programme.toLowerCase() == _selectedDepositProgramFilter.toLowerCase() || r.programme == 'Total').toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top KPI Summary cards (dynamically reflects selected programme filter)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetricCard(isAllPrograms ? 'Active Savers' : '$_selectedDepositProgramFilter Savers', '${activeKpiRow.balanceNo} Savers', width: cardW),
                    _buildMetricCard(isAllPrograms ? 'Deposit Balance' : '$_selectedDepositProgramFilter Balance', _formatNgn(activeKpiRow.balanceAmount), width: cardW),
                    _buildMetricCard(isAllPrograms ? 'Month Deposits' : '$_selectedDepositProgramFilter Deposits', _formatNgn(activeKpiRow.depositCurr), width: cardW),
                    _buildMetricCard(isAllPrograms ? 'Month Payouts' : '$_selectedDepositProgramFilter Payouts', _formatNgn(activeKpiRow.withdrawalCurrAmount + activeKpiRow.returnCurrAmount), width: cardW),
                  ],
                ),
                const SizedBox(height: 16),

                // Program Filter Chips & View Mode Toggle
                Row(
                  children: [
                    Expanded(
                      child: _buildProgramFilterChips(
                        ['All Programmes', 'Monthly', 'Weekly', 'Daily'],
                        _selectedDepositProgramFilter,
                        (val) {
                          setState(() {
                            _selectedDepositProgramFilter = val == 'All Programmes' ? 'All' : val;
                          });
                        },
                      ),
                    ),
                    if (isMobile)
                      IconButton(
                        tooltip: _showRawTableOnMobile ? 'Switch to Cards' : 'Switch to Table',
                        icon: Icon(_showRawTableOnMobile ? Icons.view_agenda_outlined : Icons.table_chart_outlined, color: tokens.brandPrimary),
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
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isTot ? tokens.successBg : tokens.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isTot ? tokens.successBorder : tokens.borderSubtle),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: isTot || filteredRows.length == 1,
                            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            title: Text(
                              isTot ? 'Consolidated Total' : '${r.programme} Programme',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isTot ? tokens.successText : tokens.brandPrimary,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isTot ? tokens.successBg : tokens.surfaceHover,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${r.balanceNo} Savers',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isTot ? tokens.successText : tokens.textSecondary,
                                ),
                              ),
                            ),
                            children: [
                              const Divider(height: 10),
                              _buildMobileDetailRow('Net Savings Balance', _formatNgn(r.balanceAmount), isPrimary: true),
                              const SizedBox(height: 4),
                              _buildMobileDetailRow('Month Deposits Received', _formatNgn(r.depositCurr)),
                              _buildMobileDetailRow('Cumulative Deposits (B/F + Month)', _formatNgn(r.depositTotal)),
                              const Divider(height: 10),
                              _buildMobileDetailRow('Normal Withdrawals (Partial)', '${r.withdrawalCurrNo} savers (${_formatNgn(r.withdrawalCurrAmount)})'),
                              _buildMobileDetailRow('Deposit Returns (Zero-Balance)', '${r.returnCurrNo} savers (${_formatNgn(r.returnCurrAmount)})'),
                              _buildMobileDetailRow('Cumulative Payouts', _formatNgn(r.withdrawalTotalAmount + r.returnTotalAmount)),
                              const Divider(height: 10),
                              _buildMobileDetailRow('Members Registered (B/F + Added)', '${r.memberPrev} + ${r.memberCurr} = ${r.memberTotal} members'),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ] else ...[
                  _buildContainedTable(
                    hint: 'Swipe horizontally to view all deposit columns across programmes',
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(tokens.surfaceSubtle),
                      headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary, fontSize: 11),
                      dataTextStyle: TextStyle(fontSize: 11, color: tokens.textSecondary),
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
                        final boldStyle = isTot
                            ? TextStyle(fontWeight: FontWeight.w800, color: tokens.textPrimary, fontSize: 11)
                            : TextStyle(fontSize: 11, color: tokens.textSecondary);
                        return DataRow(
                          color: isTot ? MaterialStateProperty.all(tokens.surfaceHover) : null,
                          cells: [
                            DataCell(Text(r.programme, style: isTot ? TextStyle(fontWeight: FontWeight.w800, color: tokens.brandPrimary) : TextStyle(fontWeight: FontWeight.w600, color: tokens.textPrimary))),
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
                            DataCell(Text('${r.balanceNo}', style: isTot ? TextStyle(fontWeight: FontWeight.w800, color: tokens.brandPrimary) : TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary))),
                            DataCell(Text(_formatNgn(r.balanceAmount), style: isTot ? TextStyle(fontWeight: FontWeight.w800, color: tokens.brandPrimary) : TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary))),
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

  String _cleanCreditItemLabel(String rawItem) {
    var s = rawItem.replaceAll('•', '').trim();
    s = s.replaceAll(RegExp(r'\s*\((₦\s*)?Col[^)]+\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  Widget _buildCreditSectionCard(List<CreditStatementRow> rows, String sectionTitle, IconData icon, {bool isHighlight = false}) {
    final tokens = IcareSurfaceTokens.of(context);
    final sectionRows = rows.where((r) {
      final s = r.section.toLowerCase();
      final target = sectionTitle.toLowerCase();
      if (target.contains('disbursed')) return s.contains('disbursed');
      if (target.contains('excess')) return s.contains('excess');
      if (target.contains('installment') || target.contains('repayment')) {
        return (s.contains('installment') || s.contains('collection')) && !s.contains('full') && !s.contains('excess');
      }
      if (target.contains('balance')) return s.contains('balance');
      if (target.contains('full')) return s.contains('full');
      return false;
    }).toList();

    if (sectionRows.isEmpty) return const SizedBox.shrink();

    double getRowVal(CreditStatementRow r) {
      if (_selectedCreditProgramFilter == 'Monthly') return r.monthly.toDouble();
      if (_selectedCreditProgramFilter == 'Weekly') return r.weekly.toDouble();
      if (_selectedCreditProgramFilter == 'Daily') return r.daily.toDouble();
      return r.total.toDouble();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isHighlight ? tokens.successBg : tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isHighlight ? tokens.successBorder : tokens.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: isHighlight || sectionTitle.contains('Disbursed') || sectionTitle.contains('Closing'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            leading: Icon(icon, size: 16, color: isHighlight ? tokens.successText : tokens.brandPrimary),
            title: Text(
              sectionTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isHighlight ? tokens.successText : tokens.textPrimary,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: tokens.surfaceHover, borderRadius: BorderRadius.circular(10)),
              child: Text(_selectedCreditProgramFilter, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.textSecondary)),
            ),
            children: [
              const Divider(height: 10),
              ...sectionRows.map((r) {
                final cleanItem = _cleanCreditItemLabel(r.item);
                final isCount = cleanItem.contains('Count');
                final val = getRowVal(r);
                final disp = isCount ? '${val.toInt()}' : _formatNgn(val);
                final isTot = cleanItem.contains('Total') || cleanItem.contains('Balance') || cleanItem.contains('Current');
                return _buildMobileDetailRow(cleanItem, disp, isPrimary: isTot);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditStatementView() {
    final tokens = IcareSurfaceTokens.of(context);
    return FutureBuilder<MonthlyExecutiveStatementsData>(
      future: _statementsFuture,
      builder: (context, snapshot) {
        if (_statementsFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          if (snapshot.hasError) {
            return _buildErrorCard(snapshot.error!, onRetry: _refreshCurrentTabData);
          }
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }
        final data = snapshot.data!;
        final cs = data.creditStatement;
        if (cs == null || cs.rows.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text('No Credit Statement records available for this period.', style: TextStyle(color: tokens.textMuted)),
          ));
        }

        const emptyRow = CreditStatementRow(section: '', item: '', monthly: 0, weekly: 0, daily: 0, total: 0);

        final balCountRow = cs.rows.firstWhere(
          (r) => r.item.contains('Active Loans'),
          orElse: () => emptyRow,
        );
        final balAmtRow = cs.rows.firstWhere(
          (r) => r.item.contains('Outstanding Credit') || r.item.contains('Credit Balance'),
          orElse: () => emptyRow,
        );
        final instCurrRow = cs.rows.firstWhere(
          (r) => r.item.contains('Current Month Installment') || (r.item.contains('Current') && r.item.contains('Installment')),
          orElse: () => emptyRow,
        );
        final payoffRow = cs.rows.firstWhere(
          (r) => r.item.contains('Current Full Repayment Count') || (r.item.contains('Current') && r.item.contains('Full') && r.item.contains('Count')),
          orElse: () => emptyRow,
        );

        double getCardVal(CreditStatementRow r) {
          if (_selectedCreditProgramFilter == 'Monthly') return r.monthly;
          if (_selectedCreditProgramFilter == 'Weekly') return r.weekly;
          if (_selectedCreditProgramFilter == 'Daily') return r.daily;
          return r.total;
        }

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
                    _buildMetricCard('Active Loans', '${getCardVal(balCountRow).toInt()} Loans', width: cardW),
                    _buildMetricCard('Active Credit', _formatNgn(getCardVal(balAmtRow)), width: cardW),
                    _buildMetricCard('Month Collections', _formatNgn(getCardVal(instCurrRow)), width: cardW),
                    _buildMetricCard('Month Full Payoffs', '${getCardVal(payoffRow).toInt()} Settled', width: cardW),
                  ],
                ),
                const SizedBox(height: 16),

                // Program Filter Chips & View Mode Toggle
                Row(
                  children: [
                    Expanded(
                      child: _buildProgramFilterChips(
                        ['Consolidated Total', 'Monthly', 'Weekly', 'Daily'],
                        _selectedCreditProgramFilter,
                        (val) {
                          setState(() {
                            _selectedCreditProgramFilter = val;
                          });
                        },
                      ),
                    ),
                    if (isMobile)
                      IconButton(
                        tooltip: _showRawTableOnMobile ? 'Switch to Cards' : 'Switch to Table',
                        icon: Icon(_showRawTableOnMobile ? Icons.view_agenda_outlined : Icons.table_chart_outlined, color: tokens.brandPrimary),
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
                      headingRowColor: MaterialStateProperty.all(tokens.surfaceSubtle),
                      headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary, fontSize: 11),
                      dataTextStyle: TextStyle(fontSize: 11, color: tokens.textSecondary),
                      columnSpacing: 16,
                      columns: [
                        const DataColumn(label: Text('Category')),
                        const DataColumn(label: Text('Reporting Metric')),
                        DataColumn(
                          numeric: true,
                          label: Text(
                            'Monthly',
                            style: TextStyle(
                              color: _selectedCreditProgramFilter == 'Monthly' ? tokens.brandPrimary : null,
                              fontWeight: _selectedCreditProgramFilter == 'Monthly' ? FontWeight.w800 : null,
                            ),
                          ),
                        ),
                        DataColumn(
                          numeric: true,
                          label: Text(
                            'Weekly',
                            style: TextStyle(
                              color: _selectedCreditProgramFilter == 'Weekly' ? tokens.brandPrimary : null,
                              fontWeight: _selectedCreditProgramFilter == 'Weekly' ? FontWeight.w800 : null,
                            ),
                          ),
                        ),
                        DataColumn(
                          numeric: true,
                          label: Text(
                            'Daily',
                            style: TextStyle(
                              color: _selectedCreditProgramFilter == 'Daily' ? tokens.brandPrimary : null,
                              fontWeight: _selectedCreditProgramFilter == 'Daily' ? FontWeight.w800 : null,
                            ),
                          ),
                        ),
                        DataColumn(
                          numeric: true,
                          label: Text(
                            'Consolidated\nTotal',
                            style: TextStyle(
                              color: _selectedCreditProgramFilter == 'Consolidated Total' ? tokens.brandPrimary : null,
                              fontWeight: _selectedCreditProgramFilter == 'Consolidated Total' ? FontWeight.w800 : null,
                            ),
                          ),
                        ),
                      ],
                      rows: cs.rows
                          .where((r) => !r.section.toLowerCase().contains('overdue') && (!r.item.toLowerCase().contains('overdue') || r.item.toLowerCase().contains('recovered')))
                          .map((r) {
                        final cleanItem = _cleanCreditItemLabel(r.item);
                        final isCount = cleanItem.contains('Count');
                        final isHighlight = cleanItem.contains('Total') || cleanItem.contains('Balance') || cleanItem.contains('Active');
                        final rowColor = isHighlight ? tokens.surfaceSubtle : null;
                        final textStyle = isHighlight
                            ? TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textPrimary)
                            : TextStyle(fontSize: 11, color: tokens.textSecondary);
                        final totStyle = isHighlight
                            ? TextStyle(fontWeight: FontWeight.w800, color: tokens.brandPrimary, fontSize: 11)
                            : TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: tokens.textPrimary);

                        final isMonthlySel = _selectedCreditProgramFilter == 'Monthly';
                        final isWeeklySel = _selectedCreditProgramFilter == 'Weekly';
                        final isDailySel = _selectedCreditProgramFilter == 'Daily';
                        final isTotalSel = _selectedCreditProgramFilter == 'Consolidated Total';

                        TextStyle colStyle(bool isSelected, TextStyle base) {
                          if (isSelected) {
                            return base.copyWith(
                              fontWeight: FontWeight.w800,
                              color: tokens.brandPrimary,
                            );
                          }
                          return base;
                        }

                        String formatVal(double v) => isCount ? '${v.toInt()}' : (v > 0 ? _formatNgn(v) : '-');

                        var sectionName = r.section;
                        if (sectionName.startsWith('5. Balance')) sectionName = '4. Balance (Portfolio)';
                        if (sectionName.startsWith('6. Full Repayment')) sectionName = '5. Full Repayment (Settled Loans)';

                        return DataRow(
                          color: rowColor != null ? MaterialStateProperty.all(rowColor) : null,
                          cells: [
                            DataCell(Text(sectionName, style: TextStyle(fontWeight: FontWeight.w600, color: tokens.brandPrimary, fontSize: 11))),
                            DataCell(Text(cleanItem, style: textStyle)),
                            DataCell(Text(formatVal(r.monthly), style: colStyle(isMonthlySel, textStyle))),
                            DataCell(Text(formatVal(r.weekly), style: colStyle(isWeeklySel, textStyle))),
                            DataCell(Text(formatVal(r.daily), style: colStyle(isDailySel, textStyle))),
                            DataCell(Text(formatVal(r.total), style: colStyle(isTotalSel, totStyle))),
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
    final tokens = IcareSurfaceTokens.of(context);
    return FutureBuilder<Annex1ReportData>(
      future: _annex1Future,
      builder: (context, snapshot) {
        if (_annex1Future == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          if (snapshot.hasError) {
            return _buildErrorCard(snapshot.error!, onRetry: _refreshCurrentTabData);
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
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.borderSubtle),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.16 : 0.025), blurRadius: 4, offset: const Offset(0, 1))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.arrow_downward, color: tokens.successText, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Section A: Sundry Inflows / Auxiliary Receipts',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatNgn(data.totalSundryReceipts),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tokens.successText, fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      ...data.sundryReceipts.map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Icon(Icons.subdirectory_arrow_right, size: 14, color: tokens.textMuted),
                            const SizedBox(width: 8),
                            Expanded(child: Text(r.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tokens.textSecondary))),
                            Text(_formatNgn(r.amount), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
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
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.borderSubtle),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.16 : 0.025), blurRadius: 4, offset: const Offset(0, 1))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.folder_open_outlined, size: 16, color: tokens.infoText),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      g.categoryName,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatNgn(g.subtotal),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: tokens.infoText, fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        ...g.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Row(
                            children: [
                              Icon(Icons.remove, size: 12, color: tokens.textLight),
                              const SizedBox(width: 8),
                              Expanded(child: Text(item.name, style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                              Text(_formatNgn(item.amount), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
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

  String _cleanTbItemName(String item) {
    final cleaned = item
        .replaceAll(RegExp(r'\s*\((?:Account|Acct)\s*\d+\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*Account\s*\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(\d{4}\)'), '')
        .replaceAll(RegExp(r'\s*\((?:PC|PB|RA)\d+(?:/(?:PC|PB|RA)\d+)?\)', caseSensitive: false), '')
        .trim();
    if (cleaned.toLowerCase() == 'cash in hand') {
      return 'Vault Cash';
    }
    return cleaned;
  }

  IconData _getSectionIcon(String section) {
    final s = section.toUpperCase();
    if (s.contains('ASSET')) return Icons.account_balance;
    if (s.contains('LIABILIT')) return Icons.receipt_long;
    if (s.contains('CAPITAL') || s.contains('RESERVE')) return Icons.corporate_fare;
    if (s.contains('INCOME')) return Icons.arrow_downward;
    if (s.contains('EXPENSE')) return Icons.arrow_upward;
    return Icons.folder_outlined;
  }

  Widget _buildOfficialTrialBalanceView() {
    final tokens = IcareSurfaceTokens.of(context);
    return FutureBuilder<MonthlyExecutiveStatementsData>(
      future: _statementsFuture,
      builder: (context, snapshot) {
        if (_statementsFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          if (snapshot.hasError) {
            return _buildErrorCard(snapshot.error!, onRetry: _refreshCurrentTabData);
          }
          return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
        }
        final data = snapshot.data!;
        final tb = data.trialBalance;

        // Group rows by section
        final Map<String, List<OfficialTrialBalanceRow>> groupedRows = {};
        for (final row in tb.rows) {
          groupedRows.putIfAbsent(row.section, () => []).add(row);
        }

        final sectionNames = ['All Sections', ...groupedRows.keys];
        final activeSections = (_selectedTbSectionFilter == 'All' || _selectedTbSectionFilter == 'All Sections')
            ? groupedRows
            : {
                if (groupedRows.containsKey(_selectedTbSectionFilter))
                  _selectedTbSectionFilter: groupedRows[_selectedTbSectionFilter]!
              };

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final isExpanded = constraints.maxWidth >= 1024;
            final cardW = isMobile ? (constraints.maxWidth - 8) / 2 : (constraints.maxWidth - 24) / 4;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Executive KPI Strip
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetricCard(
                      'Total Debits',
                      _formatNgn(tb.totalDebits),
                      subtitle: 'Assets & Operating Expenses',
                      width: cardW,
                    ),
                    _buildMetricCard(
                      'Total Credits',
                      _formatNgn(tb.totalCredits),
                      subtitle: 'Liabilities, Equity & Income',
                      width: cardW,
                    ),
                    _buildMetricCard(
                      'Equality Status',
                      tb.isBalanced ? 'Balanced' : 'Unbalanced',
                      subtitle: tb.isBalanced ? 'Zero Variance (₦0.00)' : 'Diff: ${_formatNgn(tb.variance)}',
                      isAccent: tb.isBalanced,
                      width: cardW,
                    ),
                    _buildMetricCard(
                      'Ledger Accounts',
                      '${tb.rows.length} Accounts',
                      subtitle: '${groupedRows.keys.length} Categories',
                      width: cardW,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Filter Chips & Mobile View Toggle
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: sectionNames.map((sec) {
                            final isSel = _selectedTbSectionFilter == sec;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(sec),
                                selected: isSel,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _selectedTbSectionFilter = sec);
                                  }
                                },
                                selectedColor: tokens.brandPrimaryDark,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                  color: isSel ? Colors.white : tokens.textSecondary,
                                ),
                                backgroundColor: tokens.surfaceHover,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isSel ? tokens.brandPrimaryDark : tokens.borderSubtle,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    if (isMobile)
                      IconButton(
                        tooltip: _showRawTableOnMobile ? 'Switch to Cards' : 'Switch to Table',
                        icon: Icon(
                          _showRawTableOnMobile ? Icons.view_agenda_outlined : Icons.table_chart_outlined,
                          color: tokens.brandPrimary,
                        ),
                        onPressed: () {
                          setState(() {
                            _showRawTableOnMobile = !_showRawTableOnMobile;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                if (isMobile && !_showRawTableOnMobile) ...[
                  // Mobile Cards grouped by Section
                  ...activeSections.entries.map((entry) {
                    final secName = entry.key;
                    final rows = entry.value;
                    final secDebits = rows.fold<double>(0.0, (sum, r) => sum + r.debit);
                    final secCredits = rows.fold<double>(0.0, (sum, r) => sum + r.credit);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tokens.borderSubtle),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.16 : 0.025), blurRadius: 4, offset: const Offset(0, 1))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: tokens.surfaceSubtle,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                              border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(_getSectionIcon(secName), size: 16, color: tokens.brandPrimary),
                                    const SizedBox(width: 8),
                                    Text(
                                      secName,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                                    ),
                                  ],
                                ),
                                Text(
                                  secDebits > 0 ? _formatNgn(secDebits) : _formatNgn(secCredits),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                    color: tokens.brandPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Section Items
                          ...rows.map((r) {
                            final cleanTitle = _cleanTbItemName(r.item);
                            final hasDebit = r.debit > 0;
                            final hasCredit = r.credit > 0;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      cleanTitle,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (hasDebit)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: tokens.successBg,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: tokens.successBorder),
                                      ),
                                      child: Text(
                                        'Dr ${_formatNgn(r.debit)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: tokens.successText,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ),
                                  if (hasCredit)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: tokens.infoBg,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: tokens.infoBorder),
                                      ),
                                      child: Text(
                                        'Cr ${_formatNgn(r.credit)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: tokens.infoText,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ),
                                  if (!hasDebit && !hasCredit)
                                    Text('-', style: TextStyle(fontSize: 12, color: tokens.textLight)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  // Desktop / Tablet Structured Material 3 Table
                  _buildContainedTable(
                    hint: 'Swipe horizontally to view full trial balance ledger accounts',
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(tokens.surfaceSubtle),
                      headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary, fontSize: 12),
                      dataTextStyle: TextStyle(fontSize: 12, color: tokens.textSecondary),
                      columnSpacing: isExpanded ? 32 : 18,
                      columns: const [
                        DataColumn(label: Text('Section')),
                        DataColumn(label: Text('Account / Line Item')),
                        DataColumn(numeric: true, label: Text('Debit (₦)')),
                        DataColumn(numeric: true, label: Text('Credit (₦)')),
                      ],
                      rows: [
                        ...activeSections.entries.expand((entry) {
                          return entry.value.map((r) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceHover,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      r.section,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tokens.brandPrimary),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _cleanTbItemName(r.item),
                                    style: TextStyle(fontWeight: FontWeight.w600, color: tokens.textPrimary),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    r.debit > 0 ? _formatNgn(r.debit) : '-',
                                    style: TextStyle(
                                      fontWeight: r.debit > 0 ? FontWeight.w700 : FontWeight.normal,
                                      color: r.debit > 0 ? tokens.successText : tokens.textLight,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    r.credit > 0 ? _formatNgn(r.credit) : '-',
                                    style: TextStyle(
                                      fontWeight: r.credit > 0 ? FontWeight.w700 : FontWeight.normal,
                                      color: r.credit > 0 ? tokens.infoText : tokens.textLight,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          });
                        }),
                        // Grand Total Row
                        DataRow(
                          color: MaterialStateProperty.all(tokens.successBg),
                          cells: [
                            DataCell(
                              Text(
                                'TOTALS',
                                style: TextStyle(fontWeight: FontWeight.w900, color: tokens.successText, fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  Icon(Icons.verified, size: 14, color: tokens.successText),
                                  const SizedBox(width: 6),
                                  Text(
                                    tb.isBalanced ? 'Trial Balance Balanced' : 'Unbalanced Variance',
                                    style: TextStyle(fontWeight: FontWeight.w800, color: tokens.successText, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                _formatNgn(tb.totalDebits),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: tokens.successText,
                                  fontSize: 12,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _formatNgn(tb.totalCredits),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: tokens.successText,
                                  fontSize: 12,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildReceiptsAndPaymentsView() {
    final tokens = IcareSurfaceTokens.of(context);
    return FutureBuilder<MonthlyExecutiveStatementsData>(
      future: _statementsFuture,
      builder: (context, snapshot) {
        if (_statementsFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          if (snapshot.hasError) {
            return _buildErrorCard(snapshot.error!, onRetry: _refreshCurrentTabData);
          }
          return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
        }
        final data = snapshot.data!;
        final rp = data.receiptsAndPayments;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final isExpanded = constraints.maxWidth >= 1024;

            final cardW = isMobile
                ? (constraints.maxWidth - 8) / 2
                : (constraints.maxWidth - 16) / 3;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Cash Flow KPI Strip
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetricCard(
                      'Total Inflows',
                      _formatNgn(rp.totalReceipts),
                      subtitle: 'Collections, Deposits & Sundry',
                      width: cardW,
                    ),
                    _buildMetricCard(
                      'Total Outflows',
                      _formatNgn(rp.totalPayments),
                      subtitle: 'Disbursements, Payouts & OpEx',
                      width: cardW,
                    ),
                    _buildMetricCard(
                      'Net Cash Float',
                      _formatNgn(rp.variance),
                      subtitle: rp.variance == 0.0 ? 'Balanced Reconciled Float' : 'Float Variance',
                      isAccent: rp.variance == 0.0,
                      width: isMobile ? constraints.maxWidth : cardW,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (isExpanded) ...[
                  // Desktop Web: Two Balanced Side-by-Side Inflow & Outflow Cards
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Cash Receipts (Inflows)
                      Expanded(
                        child: _buildCashFlowSideCard(
                          title: 'Cash Inflows (Receipts)',
                          icon: Icons.arrow_downward,
                          accentColor: tokens.successText,
                          headerBg: tokens.successBg,
                          borderColor: tokens.successBorder,
                          items: rp.receipts,
                          totalAmount: rp.totalReceipts,
                          isReceipt: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right: Cash Payments (Outflows)
                      Expanded(
                        child: _buildCashFlowSideCard(
                          title: 'Cash Outflows (Payments)',
                          icon: Icons.arrow_upward,
                          accentColor: tokens.infoText,
                          headerBg: tokens.infoBg,
                          borderColor: tokens.infoBorder,
                          items: rp.payments,
                          totalAmount: rp.totalPayments,
                          isReceipt: false,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Mobile & Tablet: Segmented Toggle View
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: tokens.surfaceHover,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildRpSegmentBtn('All Movements', 0, Icons.swap_vert),
                        const SizedBox(width: 4),
                        _buildRpSegmentBtn('Inflows (Receipts)', 1, Icons.arrow_downward),
                        const SizedBox(width: 4),
                        _buildRpSegmentBtn('Outflows (Payments)', 2, Icons.arrow_upward),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_selectedRpSegmentIndex == 0) ...[
                    // Combined List
                    _buildCashFlowCardList(
                      receipts: rp.receipts,
                      payments: rp.payments,
                      totalInflows: rp.totalReceipts,
                      totalOutflows: rp.totalPayments,
                    ),
                  ] else if (_selectedRpSegmentIndex == 1) ...[
                    // Receipts Only
                    _buildCashFlowSideCard(
                      title: 'Cash Inflows (Receipts)',
                      icon: Icons.arrow_downward,
                      accentColor: tokens.successText,
                      headerBg: tokens.successBg,
                      borderColor: tokens.successBorder,
                      items: rp.receipts,
                      totalAmount: rp.totalReceipts,
                      isReceipt: true,
                    ),
                  ] else ...[
                    // Payments Only
                    _buildCashFlowSideCard(
                      title: 'Cash Outflows (Payments)',
                      icon: Icons.arrow_upward,
                      accentColor: tokens.infoText,
                      headerBg: tokens.infoBg,
                      borderColor: tokens.infoBorder,
                      items: rp.payments,
                      totalAmount: rp.totalPayments,
                      isReceipt: false,
                    ),
                  ],
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRpSegmentBtn(String label, int index, IconData icon) {
    final tokens = IcareSurfaceTokens.of(context);
    final isSelected = _selectedRpSegmentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedRpSegmentIndex = index),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? tokens.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.2 : 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: isSelected ? tokens.brandPrimary : tokens.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? tokens.brandPrimary : tokens.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashFlowSideCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Color headerBg,
    required Color borderColor,
    required List<ReceiptsPaymentsItem> items,
    required double totalAmount,
    required bool isReceipt,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.16 : 0.025), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accentColor),
                    ),
                  ],
                ),
                Text(
                  _formatNgn(totalAmount),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          // Items
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No transactions recorded in this category.',
                  style: TextStyle(fontSize: 12, color: tokens.textLight),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: tokens.borderSubtle),
              itemBuilder: (context, index) {
                final it = items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.item,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                            ),
                            if (it.subDetail != null && it.subDetail!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                it.subDetail!,
                                style: TextStyle(fontSize: 11, color: tokens.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatNgn(it.amount),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isReceipt ? tokens.successText : tokens.infoText,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          // Subtotal footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              border: Border(top: BorderSide(color: tokens.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary),
                ),
                Text(
                  _formatNgn(totalAmount),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowCardList({
    required List<ReceiptsPaymentsItem> receipts,
    required List<ReceiptsPaymentsItem> payments,
    required double totalInflows,
    required double totalOutflows,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCashFlowSideCard(
          title: 'Cash Inflows (Receipts)',
          icon: Icons.arrow_downward,
          accentColor: tokens.successText,
          headerBg: tokens.successBg,
          borderColor: tokens.successBorder,
          items: receipts,
          totalAmount: totalInflows,
          isReceipt: true,
        ),
        const SizedBox(height: 14),
        _buildCashFlowSideCard(
          title: 'Cash Outflows (Payments)',
          icon: Icons.arrow_upward,
          accentColor: tokens.infoText,
          headerBg: tokens.infoBg,
          borderColor: tokens.infoBorder,
          items: payments,
          totalAmount: totalOutflows,
          isReceipt: false,
        ),
      ],
    );
  }

  Widget _buildBankReconciliationView() {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final role = user?.role.trim() ?? '';
    final isAm = role == 'Area Manager' || role == 'AM';
    final isBm = role == 'Branch Manager' || role == 'BM';
    final isDirector = role == 'Director' || role == 'DIRECTOR' || role == 'Executive Director';

    return FutureBuilder<MonthlyReconciliationData>(
      future: _reconciliationFuture,
      builder: (context, snapshot) {
        if (_reconciliationFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          if (snapshot.hasError) {
            return _buildErrorCard(snapshot.error!, onRetry: _refreshCurrentTabData);
          }
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }
        final data = snapshot.data!;

        final effectiveBranchName = (_selectedBranchName != null && !_selectedBranchName!.startsWith('All'))
            ? _selectedBranchName
            : (_cachedMeta?.branches.isNotEmpty == true ? _cachedMeta!.branches.first.name : _selectedBranchName);

        return FutureBuilder<MonthlyWorkflowStatusModel>(
          future: _workflowStatusFuture,
          builder: (context, wfSnapshot) {
            final wfStatus = wfSnapshot.data?.status ?? 'DRAFT';
            final isWorkflowLockedForBm = ['BM_SUBMITTED', 'AM_VERIFIED', 'AREA_SEALED', 'ADMIN_LOCKED'].contains(wfStatus);
            final isReadOnly = isAm || isDirector || wfStatus == 'ADMIN_LOCKED' || (isBm && isWorkflowLockedForBm);

            return BankReconciliationFormWidget(
              initialData: data,
              branchName: effectiveBranchName,
              year: _selectedExecYear,
              month: _selectedExecMonth,
              isReadOnly: isReadOnly,
              onSaved: () {
                _refreshCurrentTabData();
              },
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab: Regional Area Branches Comparison
  // ---------------------------------------------------------------------------
  Widget _buildAreaComparisonTab({bool isAdmin = false, bool isAm = false}) {
    final tokens = IcareSurfaceTokens.of(context);
    final products = _cachedMeta != null ? ['All Products', ..._cachedMeta!.products] : ['All Products'];

    final filterBar = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list, size: 15, color: tokens.brandPrimary),
              const SizedBox(width: 6),
              Text('Matrix Filters:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: products.contains(_selectedProductName) ? _selectedProductName : products.first,
                isDense: true,
                dropdownColor: tokens.surfaceElevated,
                items: products.map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(p, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedProductName = val);
                    _refreshCurrentTabData();
                  }
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _dateMode,
                isDense: true,
                dropdownColor: tokens.surfaceElevated,
                items: ['As of Date', 'Date Range', 'All Time'].map((m) => DropdownMenuItem(
                  value: m,
                  child: Text(m, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _dateMode = val);
                    _refreshCurrentTabData();
                  }
                },
              ),
            ),
          ),
          if (_dateMode == 'As of Date')
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.borderStrong),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 13, color: tokens.textMuted),
                    const SizedBox(width: 6),
                    Text('As of: ${_dateFormat.format(_asOfDate)}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                  ],
                ),
              ),
            ),
          if (_dateMode == 'Date Range') ...[
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.borderStrong),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 13, color: tokens.textMuted),
                    const SizedBox(width: 6),
                    Text('From: ${_dateFormat.format(_startDate)}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                  ],
                ),
              ),
            ),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.borderStrong),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 13, color: tokens.textMuted),
                    const SizedBox(width: 6),
                    Text('To: ${_dateFormat.format(_endDate)}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        filterBar,
        FutureBuilder<AreaComparisonData>(
          future: _areaFuture,
          builder: (context, snapshot) {
            if (_areaFuture == null || snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
              if (snapshot.hasError) {
                return _buildErrorCard(snapshot.error!, onRetry: _refreshCurrentTabData);
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
                color: tokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Regional Supervisory Area Performance Matrix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary)),
                          const SizedBox(height: 4),
                          Text('Side-by-side comparative analysis of all branches under your regional supervision.', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: tokens.successBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: tokens.successBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.domain, size: 14, color: tokens.successText),
                            const SizedBox(width: 6),
                            Text(
                              '${data.totalBranches} Branches Supervised',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: tokens.successText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Responsive 8-Metric KPI Grid
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
                  Divider(color: tokens.borderSubtle),
                  const SizedBox(height: 12),

                  // Branch Certification & Month-End Sign-Off Ribbon (AM / Admin)
                  if (isAm || isAdmin) ...[
                    _buildCertificationRibbon(isAm),
                    const SizedBox(height: 20),
                    Divider(color: tokens.borderSubtle),
                    const SizedBox(height: 12),
                  ],

                  // Comparative Matrix: Mobile Cards vs Desktop Table
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 650;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Branch-by-Branch Comparative Matrix',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isMobile)
                                TextButton.icon(
                                  icon: Icon(_showRawTableOnMobile ? Icons.view_agenda_outlined : Icons.table_chart_outlined, size: 14, color: tokens.brandPrimary),
                                  label: Text(
                                    _showRawTableOnMobile ? 'Show Cards' : 'Show 11-Col Table',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tokens.brandPrimary),
                                  ),
                                  onPressed: () => setState(() => _showRawTableOnMobile = !_showRawTableOnMobile),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (isMobile && !_showRawTableOnMobile)
                            Column(
                              children: data.rows.map((r) => _buildMobileBranchHealthCard(r, isAm)).toList(),
                            )
                          else
                            _buildContainedTable(
                              hint: 'Swipe horizontally to view all branch metrics',
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(tokens.surfaceSubtle),
                                headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: tokens.textPrimary),
                                dataTextStyle: TextStyle(color: tokens.textSecondary),
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
                                  DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: data.rows.map((r) {
                                  final isHealthy = r.status == 'HEALTHY';
                                  return DataRow(cells: [
                                    DataCell(Text(r.branch, style: TextStyle(fontWeight: FontWeight.w600, color: tokens.textPrimary))),
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
                                        color: isHealthy ? tokens.successBg : tokens.dangerBg,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: isHealthy ? tokens.successBorder : tokens.dangerBorder),
                                      ),
                                      child: Text(
                                        r.status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isHealthy ? tokens.successText : tokens.dangerText,
                                        ),
                                      ),
                                    )),
                                    DataCell(
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: tokens.brandPrimary,
                                          side: BorderSide(color: tokens.brandPrimary),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _selectedBranchName = r.branch;
                                            _selectedTabIndex = isAm ? 1 : 0;
                                          });
                                          _refreshCurrentTabData();
                                        },
                                        child: const Text('Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ]);
                                }).toList(),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Divider(color: tokens.borderSubtle),
                  const SizedBox(height: 12),

                  // Regional Actions Bar: Excel & CSV
                  Builder(
                    builder: (context) {
                      final isMobile = MediaQuery.of(context).size.width < 750;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: isMobile ? double.infinity : null,
                            child: ElevatedButton.icon(
                              onPressed: () => _triggerCsvDownload('area_comparison', 'area_branch_comparison.csv', forceConsolidated: true),
                              icon: const Icon(Icons.file_download, size: 16),
                              label: const Text('Download Area Comparison (CSV)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tokens.isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: isMobile ? double.infinity : null,
                            child: ElevatedButton.icon(
                              onPressed: () => _triggerExcelDownload(forceConsolidated: true),
                              icon: const Icon(Icons.table_chart, size: 16),
                              label: const Text('Download Regional Operational Report (Excel)'),
                              style: ElevatedButton.styleFrom(backgroundColor: tokens.brandPrimaryDark, foregroundColor: Colors.white),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileBranchHealthCard(AreaBranchRow r, bool isAm) {
    final tokens = IcareSurfaceTokens.of(context);
    final isHealthy = r.status == 'HEALTHY';
    final progress = (r.collectionEfficiency / 100.0).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
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
                r.branch,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: tokens.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isHealthy ? tokens.successBg : tokens.dangerBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isHealthy ? tokens.successBorder : tokens.dangerBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isHealthy ? tokens.successDot : tokens.dangerDot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      r.status,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isHealthy ? tokens.successText : tokens.dangerText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Collection Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Collection Efficiency', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                  Text(
                    '${r.collectionEfficiency.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isHealthy ? tokens.successText : tokens.warningText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: tokens.surfaceHover,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isHealthy ? tokens.brandPrimary : tokens.warningDot,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Key Metrics Grid
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Collections: ${_formatNgn(r.collectionsReceived)}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
                    Text('Expected: ${_formatNgn(r.expectedCollections)}', style: TextStyle(fontSize: 11.5, color: tokens.textMuted, fontFeatures: const [FontFeature.tabularFigures()])),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Outstanding: ${_formatNgn(r.outstandingPortfolio)}', style: TextStyle(fontSize: 11.5, color: tokens.textSecondary, fontFeatures: const [FontFeature.tabularFigures()])),
                    Text('PAR %: ${r.parPercentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: r.parPercentage > 5.0 ? tokens.dangerText : tokens.successText)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Active Loans: ${_intFormat.format(r.activeLoans)}', style: TextStyle(fontSize: 11.5, color: tokens.textMuted)),
                    Text('Total Savings: ${_formatNgn(r.totalSavings)}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.brandPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(Icons.description_outlined, size: 14, color: tokens.brandPrimary),
              label: Text('Inspect Branch Statements', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.brandPrimary)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: tokens.brandPrimary),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () {
                setState(() {
                  _selectedBranchName = r.branch;
                  _selectedTabIndex = isAm ? 1 : 0;
                });
                _refreshCurrentTabData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationRibbon(bool isAm) {
    final tokens = IcareSurfaceTokens.of(context);
    return FutureBuilder<List<MonthlyWorkflowPendingBranchModel>>(
      future: _pendingSubmissionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Checking branch monthly submission & certification status...', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorCard(snapshot.error!, onRetry: _refreshCurrentTabData);
        }

        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.successBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.successBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.verified, size: 18, color: tokens.successText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('All supervised branches have completed submissions for this period.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tokens.successText)),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Branch Certification & Month-End Sign-Off',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${list.length} Branches Tracked', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.brandPrimary)),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: list.map((b) {
                    final isSubmitted = b.status == 'BM_SUBMITTED';
                    final isEndorsed = b.status == 'AM_VERIFIED';
                    final isReturned = b.status == 'RETURNED_FOR_CORRECTION';

                    final cardBg = isSubmitted ? tokens.warningBg : (isEndorsed ? tokens.successBg : (isReturned ? tokens.dangerBg : tokens.surfaceSubtle));
                    final cardBorder = isSubmitted ? tokens.warningBorder : (isEndorsed ? tokens.successBorder : (isReturned ? tokens.dangerBorder : tokens.borderSubtle));
                    final pillBg = isSubmitted ? tokens.warningBg : (isEndorsed ? tokens.successBg : (isReturned ? tokens.dangerBg : tokens.surfaceHover));
                    final pillColor = isSubmitted ? tokens.warningText : (isEndorsed ? tokens.successText : (isReturned ? tokens.dangerText : tokens.textSecondary));
                    final pillText = isSubmitted ? 'AWAITING AM SIGN-OFF' : (isEndorsed ? 'AM ENDORSED' : (isReturned ? 'RETURNED TO BM' : 'PENDING BM SUBMISSION'));
                    final statusIcon = isSubmitted ? Icons.pending_actions : (isEndorsed ? Icons.verified : (isReturned ? Icons.assignment_return_outlined : Icons.edit_note));
                    final iconColor = isSubmitted ? tokens.warningDot : (isEndorsed ? tokens.successDot : (isReturned ? tokens.dangerDot : tokens.textMuted));

                    return Container(
                      width: isNarrow ? double.infinity : (constraints.maxWidth - 12) / 2,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(statusIcon, size: 16, color: iconColor),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        b.branchName,
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: tokens.textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(4), border: Border.all(color: cardBorder)),
                                child: Text(pillText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: pillColor)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isSubmitted
                                ? 'Certified by ${b.bmName ?? "Branch Manager"}${b.submittedAt != null ? " on ${_formatDateTime(b.submittedAt)}" : ""} • Collections: ${_formatNgn(b.collections)}'
                                : (isEndorsed
                                    ? 'Endorsed & locked for supervisory district • Collections: ${_formatNgn(b.collections)}'
                                    : (isReturned
                                        ? 'Queried: ${b.amQueryNotes ?? "Corrections requested"}'
                                        : 'BM reconciling vault • Books open for ${_monthNames[_selectedExecMonth - 1]} $_selectedExecYear')),
                            style: TextStyle(fontSize: 11.5, color: tokens.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedBranchName = b.branchName;
                                  _selectedTabIndex = isAm ? 1 : 0;
                                });
                                _refreshCurrentTabData();
                              },
                              icon: Icon(isSubmitted ? Icons.rate_review_outlined : Icons.visibility_outlined, size: 13),
                              label: Text(
                                isSubmitted ? 'Review & Endorse' : (isEndorsed ? 'View Certified Return' : 'Inspect Statements'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSubmitted ? const Color(0xFFB45309) : tokens.brandPrimaryDark,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab: Data Exports & Downloads (Dual-Card Architecture)
  // ---------------------------------------------------------------------------
  Widget _buildDataExportsTab(bool isAdmin, bool isBm, bool isAm) {
    final tokens = IcareSurfaceTokens.of(context);
    final isMobile = MediaQuery.of(context).size.width < 750;
    final effectiveSingleBranch = (_selectedBranchName != null && !_selectedBranchName!.startsWith('All'))
        ? _selectedBranchName
        : (_cachedMeta?.branches.isNotEmpty == true ? _cachedMeta!.branches.first.name : _selectedBranchName);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comprehensive Operational Data Exports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tokens.textPrimary)),
          const SizedBox(height: 4),
          Text('Direct in-memory generation of full operational datasets. All files download directly to your browser without external cloud dependencies.', style: TextStyle(fontSize: 13, color: tokens.textMuted)),
          const SizedBox(height: 20),

          // Optional Custom Export Filters
          _buildExportFilterCard(isAdmin, isBm, isAm),
          const SizedBox(height: 16),

          // For AM and Admin: Card 1 (Regional Consolidated Datasets)
          if (isAm || isAdmin) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.successBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: tokens.successBorder),
                        ),
                        child: Icon(Icons.hub_outlined, color: tokens.successText, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Card 1: Regional Consolidated Datasets (Supervisory Area Scope)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Multi-branch consolidated operational workbooks and raw ledgers across all assigned district branches.',
                              style: TextStyle(fontSize: 12, color: tokens.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Includes: Area Branch Comparison matrix, Consolidated Trial Balance, Savings Summary, Repayments Summary, and Raw Loan Records scoped to your area.',
                    style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _triggerExcelDownload(forceConsolidated: true),
                        icon: const Icon(Icons.table_chart, size: 16),
                        label: const Text('Download Master Regional Report (Excel)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.brandPrimaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _triggerCsvDownload('area_comparison', 'area_branch_comparison.csv', forceConsolidated: true),
                        icon: const Icon(Icons.file_download, size: 16),
                        label: const Text('Area Comparison (CSV)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _triggerCsvDownload('loans', 'regional_raw_loans.csv', forceConsolidated: true),
                        icon: const Icon(Icons.file_download, size: 16),
                        label: const Text('Regional Raw Loans (CSV)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _triggerCsvDownload('repayments', 'regional_raw_repayments.csv', forceConsolidated: true),
                        icon: const Icon(Icons.file_download, size: 16),
                        label: const Text('Regional Raw Repayments (CSV)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Card 2: Single-Branch Audited Package
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.infoBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tokens.infoBorder),
                      ),
                      child: Icon(Icons.account_balance, color: tokens.infoText, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAm || isAdmin
                                ? 'Card 2: Single-Branch Audited Package (Individual Extraction)'
                                : 'Branch Operational Statements & Audited Extraction',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Extract official regulatory statements and raw registers for an individual branch (Currently: ${effectiveSingleBranch ?? "Selected Branch"}).',
                            style: TextStyle(fontSize: 12, color: tokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      icon: Icon(Icons.picture_as_pdf_outlined, size: 14, color: tokens.dangerText),
                      label: Text('Official Statement (PDF Print)', style: TextStyle(fontSize: 12, color: tokens.dangerText, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: tokens.dangerBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () async {
                        try {
                          final bytes = await ref.read(reportsApiServiceProvider).downloadMonthlyParityPdf(
                            branchName: effectiveSingleBranch,
                            year: _selectedExecYear,
                            month: _selectedExecMonth,
                            officerName: _selectedOfficerName,
                            productName: _selectedProductName,
                          );
                          final saved = await downloadBlobFile(
                            bytes,
                            'Official_Executive_Statement_${effectiveSingleBranch ?? "Branch"}_${_selectedExecYear}_${_selectedExecMonth.toString().padLeft(2, '0')}.pdf',
                            'application/pdf',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Executive PDF Statement downloaded${saved != null ? ' ($saved)' : ''}.')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('PDF Download failed: ${AppErrorDetails.from(e).message}')),
                            );
                          }
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      icon: Icon(Icons.table_view_outlined, size: 14, color: tokens.brandPrimary),
                      label: Text('Branch Excel Workbook', style: TextStyle(fontSize: 12, color: tokens.brandPrimary, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: tokens.brandPrimary),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () async {
                        try {
                          final bytes = await ref.read(reportsApiServiceProvider).downloadMonthlyParityExcel(
                            branchName: effectiveSingleBranch,
                            year: _selectedExecYear,
                            month: _selectedExecMonth,
                            officerName: _selectedOfficerName,
                            productName: _selectedProductName,
                          );
                          final saved = await downloadBlobFile(
                            bytes,
                            'Branch_Monthly_Workbook_${effectiveSingleBranch ?? "Branch"}_${_selectedExecYear}_${_selectedExecMonth.toString().padLeft(2, '0')}.xlsx',
                            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Branch Workbook downloaded${saved != null ? ' ($saved)' : ''}.')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Download failed: ${AppErrorDetails.from(e).message}')),
                            );
                          }
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      icon: Icon(Icons.people_alt_outlined, size: 14, color: tokens.textSecondary),
                      label: Text('Credit Officer Summary (CSV)', style: TextStyle(fontSize: 12, color: tokens.textSecondary, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: tokens.borderStrong),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () async {
                        try {
                          final bytes = await ref.read(reportsApiServiceProvider).downloadMonthlyParityCsv(
                            branchName: effectiveSingleBranch,
                            year: _selectedExecYear,
                            month: _selectedExecMonth,
                            officerName: _selectedOfficerName,
                            productName: _selectedProductName,
                          );
                          final saved = await downloadBlobFile(
                            bytes,
                            'CO_Summary_${effectiveSingleBranch ?? "Branch"}_${_selectedExecYear}_${_selectedExecMonth.toString().padLeft(2, '0')}.csv',
                            'text/csv',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('CO Summary CSV downloaded${saved != null ? ' ($saved)' : ''}.')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Download failed: ${AppErrorDetails.from(e).message}')),
                            );
                          }
                        }
                      },
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _triggerCsvDownload('loans', '${effectiveSingleBranch ?? "branch"}_loans.csv', branchOverride: effectiveSingleBranch),
                      icon: const Icon(Icons.file_download, size: 14),
                      label: const Text('Branch Loans (CSV)', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.isDark ? const Color(0xFF1E293B) : const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _triggerCsvDownload('repayments', '${effectiveSingleBranch ?? "branch"}_repayments.csv', branchOverride: effectiveSingleBranch),
                      icon: const Icon(Icons.file_download, size: 14),
                      label: const Text('Branch Repayments (CSV)', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.isDark ? const Color(0xFF1E293B) : const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
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
  Future<void> _triggerExcelDownload({String? branchOverride, bool forceConsolidated = false}) async {
    final api = ref.read(reportsApiServiceProvider);
    final asOfStr = _dateMode == 'As of Date' ? _dateFormat.format(_asOfDate) : null;
    final startStr = _dateMode == 'Date Range' ? _dateFormat.format(_startDate) : null;
    final endStr = _dateMode == 'Date Range' ? _dateFormat.format(_endDate) : null;
    final targetBranch = forceConsolidated ? null : (branchOverride ?? _selectedBranchName);

    try {
      final bytes = await api.downloadExcel(
        branchName: targetBranch,
        productName: _selectedProductName,
        officerName: _selectedOfficerName,
        asOfDate: asOfStr,
        startDate: startStr,
        endDate: endStr,
      );
      final fileName = 'icare_master_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final saved = await downloadBlobFile(bytes, fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel report downloaded${saved != null ? ' ($saved)' : ''}.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download Excel report: ${AppErrorDetails.from(e).message}')),
        );
      }
    }
  }

  Future<void> _triggerCsvDownload(String reportType, String defaultFileName, {String? branchOverride, bool forceConsolidated = false}) async {
    final api = ref.read(reportsApiServiceProvider);
    final asOfStr = _dateMode == 'As of Date' ? _dateFormat.format(_asOfDate) : null;
    final startStr = _dateMode == 'Date Range' ? _dateFormat.format(_startDate) : null;
    final endStr = _dateMode == 'Date Range' ? _dateFormat.format(_endDate) : null;
    final targetBranch = forceConsolidated ? null : (branchOverride ?? _selectedBranchName);

    try {
      final bytes = await api.downloadCsv(
        reportType: reportType,
        branchName: targetBranch,
        productName: _selectedProductName,
        officerName: _selectedOfficerName,
        asOfDate: asOfStr,
        startDate: startStr,
        endDate: endStr,
      );
      final fileName = defaultFileName.replaceAll('.csv', '_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
      final saved = await downloadBlobFile(bytes, fileName, 'text/csv');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV exported${saved != null ? ' ($saved)' : ''}.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download CSV: ${AppErrorDetails.from(e).message}')),
        );
      }
    }
  }

  // ===========================================================================
  // MONTHLY REPORT THREE-TIER WORKFLOW (BM -> AM -> ADMIN)
  // ===========================================================================

  String _formatDateTime(String? isoStr) {
    if (isoStr == null || isoStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return isoStr;
    }
  }

  Widget _buildSnapshotRow(String label, String value, {bool isAccent = false, bool isDanger = false}) {
    final tokens = IcareSurfaceTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: tokens.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isAccent ? FontWeight.w800 : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isDanger
                  ? tokens.dangerText
                  : (isAccent ? tokens.successText : tokens.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStatusCard(bool isAdmin, bool isBm, bool isAm) {
    final tokens = IcareSurfaceTokens.of(context);
    if (_selectedBranchName == null || _selectedBranchName!.startsWith('All')) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_outlined, size: 20, color: tokens.brandPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Statement Verification & Sign-Off Workflow',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Select an individual branch from the dropdown above to review certification status, submit books, or execute supervisory endorsements.',
                    style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<MonthlyWorkflowStatusModel>(
      future: _workflowStatusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Checking monthly verification & sign-off status...', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          final errInfo = AppErrorDetails.from(snapshot.error!);
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.dangerBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.dangerBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: tokens.dangerDot),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Workflow status unavailable: ${errInfo.message}', style: TextStyle(fontSize: 12, color: tokens.dangerText)),
                ),
              ],
            ),
          );
        }

        final st = snapshot.data;
        if (st == null) return const SizedBox.shrink();

        return _renderWorkflowBanner(st, isAdmin, isBm, isAm);
      },
    );
  }

  Widget _renderWorkflowBanner(MonthlyWorkflowStatusModel st, bool isAdmin, bool isBm, bool isAm) {
    final tokens = IcareSurfaceTokens.of(context);
    final status = st.status;
    final authState = ref.read(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final role = user?.role.trim() ?? '';
    final isDirector = role == 'Director' || role == 'DIRECTOR' || role == 'Executive Director';
    final canMutateAdmin = isAdmin && !isDirector;
    final darkLockBg = tokens.isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A);

    Color bg;
    Color border;
    Color pillBg;
    Color pillText;
    String pillLabel;
    IconData icon;
    Color iconColor;
    String title;
    String description;
    List<Widget> actions = [];

    switch (status) {
      case 'BM_SUBMITTED':
        bg = tokens.warningBg;
        border = tokens.warningBorder;
        pillBg = tokens.warningBg;
        pillText = tokens.warningText;
        pillLabel = 'SUBMITTED FOR AM SIGN-OFF';
        icon = Icons.pending_actions;
        iconColor = tokens.warningDot;
        title = 'Submitted for Area Manager Endorsement';
        description = 'Certified by ${st.bmName ?? "Branch Manager"} on ${_formatDateTime(st.bmSubmittedAt)}. Books are locked pending Area Manager review.';

        if (isAm || canMutateAdmin) {
          actions.add(
            OutlinedButton.icon(
              onPressed: _isWorkflowSubmitting ? null : () => _showAmReturnDialog(st),
              icon: Icon(Icons.assignment_return_outlined, size: 14, color: tokens.dangerText),
              label: Text('Query / Return', style: TextStyle(color: tokens.dangerText, fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: tokens.dangerBorder),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          );
          actions.add(const SizedBox(width: 8));
          actions.add(
            ElevatedButton.icon(
              onPressed: _isWorkflowSubmitting ? null : () => _showAmEndorseDialog(st),
              icon: const Icon(Icons.check_circle_outline, size: 14, color: Colors.white),
              label: const Text('Endorse & Sign Off', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.brandPrimaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          );
        } else {
          actions.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: tokens.warningBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: tokens.warningBorder)),
              child: Text('Awaiting Supervisory Endorsement', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: tokens.warningText)),
            ),
          );
        }
        break;

      case 'RETURNED_FOR_CORRECTION':
        bg = tokens.dangerBg;
        border = tokens.dangerBorder;
        pillBg = tokens.dangerBg;
        pillText = tokens.dangerText;
        pillLabel = 'RETURNED FOR CORRECTION';
        icon = Icons.assignment_return_outlined;
        iconColor = tokens.dangerDot;
        title = 'Returned with Supervisory Queries';
        description = 'Area Manager ${st.amName != null ? "(${st.amName}) " : ""}has requested adjustments before sign-off.';

        if (isBm || canMutateAdmin) {
          actions.add(
            ElevatedButton.icon(
              onPressed: _isWorkflowSubmitting ? null : () => _showBmSubmitDialog(st),
              icon: const Icon(Icons.refresh, size: 14, color: Colors.white),
              label: const Text('Re-verify & Resubmit', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.brandPrimaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          );
        }
        break;

      case 'AM_VERIFIED':
        bg = tokens.successBg;
        border = tokens.successBorder;
        pillBg = tokens.successBg;
        pillText = tokens.successText;
        pillLabel = 'ENDORSED BY AREA MANAGER';
        icon = Icons.verified;
        iconColor = tokens.successDot;
        title = 'Supervisory Sign-Off Granted';
        description = 'Endorsed by Area Manager ${st.amName ?? ""} on ${_formatDateTime(st.amEndorsedAt)}. Ready for regional package seal or archival lock.';

        if (isAm || canMutateAdmin) {
          actions.add(
            OutlinedButton.icon(
              onPressed: _isWorkflowSubmitting ? null : () => _sealAreaMonthlyPackage(),
              icon: Icon(Icons.folder_special_outlined, size: 14, color: tokens.infoText),
              label: Text('Seal Regional Package', style: TextStyle(color: tokens.infoText, fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: tokens.infoBorder),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          );
        }
        if (canMutateAdmin) {
          if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
          actions.add(
            ElevatedButton.icon(
              onPressed: _isWorkflowSubmitting ? null : () => _showAdminLockDialog(st),
              icon: const Icon(Icons.lock_outline, size: 14, color: Colors.white),
              label: const Text('Lock & Archive', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: darkLockBg,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          );
        }
        if (actions.isEmpty) {
          actions.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: tokens.successBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: tokens.successBorder)),
              child: Text('Endorsed • Awaiting Regional Seal', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: tokens.successText)),
            ),
          );
        }
        break;

      case 'AREA_SEALED':
        bg = tokens.infoBg;
        border = tokens.infoBorder;
        pillBg = tokens.infoBg;
        pillText = tokens.infoText;
        pillLabel = 'REGIONAL PACKAGE SEALED';
        icon = Icons.folder_special;
        iconColor = tokens.infoDot;
        title = 'Regional Month-End Package Sealed';
        description = 'Sealed by Area Manager. Awaiting Executive Admin permanent archival lock.';

        if (canMutateAdmin) {
          actions.add(
            ElevatedButton.icon(
              onPressed: _isWorkflowSubmitting ? null : () => _showAdminLockDialog(st),
              icon: const Icon(Icons.lock_outline, size: 14, color: Colors.white),
              label: const Text('Execute Institutional Lock', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: darkLockBg,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          );
        } else {
          actions.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: tokens.infoBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: tokens.infoBorder)),
              child: Text('Sealed • Awaiting Admin Archival', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: tokens.infoText)),
            ),
          );
        }
        break;

      case 'ADMIN_LOCKED':
        bg = tokens.surfaceSubtle;
        border = tokens.borderStrong;
        pillBg = tokens.surfaceHover;
        pillText = tokens.textPrimary;
        pillLabel = 'LOCKED & ARCHIVED';
        icon = Icons.lock;
        iconColor = tokens.textPrimary;
        title = 'Permanent Institutional Record';
        description = 'Permanently archived by ${st.adminName ?? "Administrator"} on ${_formatDateTime(st.adminLockedAt)}. Books are permanently closed.';
        actions.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: tokens.surfaceHover, borderRadius: BorderRadius.circular(6)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 13, color: tokens.textPrimary),
                const SizedBox(width: 4),
                Text('Permanent Audit Record', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
              ],
            ),
          ),
        );
        break;

      default: // DRAFT
        bg = tokens.surfaceSubtle;
        border = tokens.borderSubtle;
        pillBg = tokens.surfaceHover;
        pillText = tokens.textSecondary;
        pillLabel = 'DRAFT — BOOKS OPEN';
        icon = Icons.edit_note;
        iconColor = tokens.textMuted;
        title = 'Month-End Statements in Preparation';
        description = 'Operational books are open for reconciliation. Ready to certify and submit to Area Manager?';

        if (isBm || canMutateAdmin) {
          actions.add(
            ElevatedButton.icon(
              onPressed: _isWorkflowSubmitting ? null : () => _showBmSubmitDialog(st),
              icon: const Icon(Icons.assignment_turned_in_outlined, size: 14, color: Colors.white),
              label: const Text('Verify & Submit to Area Manager', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.brandPrimaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          );
        } else {
          actions.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: tokens.surfaceHover, borderRadius: BorderRadius.circular(6)),
              child: Text('Awaiting Branch Submission', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textMuted)),
            ),
          );
        }
        break;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final isNarrow = constraints.maxWidth < 650;

          final headerDetails = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: border),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                          softWrap: true,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(4), border: Border.all(color: border)),
                          child: Text(
                            pillLabel,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pillText),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(description, style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
              if (st.amQueryNotes != null && st.amQueryNotes!.isNotEmpty && status == 'RETURNED_FOR_CORRECTION') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.dangerBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.help_outline, size: 15, color: tokens.dangerDot),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Query: ${st.amQueryNotes}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.dangerText),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerDetails,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: headerDetails),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: 16),
                Row(mainAxisSize: MainAxisSize.min, children: actions),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _sealAreaMonthlyPackage() async {
    setState(() => _isWorkflowSubmitting = true);
    try {
      final api = ref.read(reportsApiServiceProvider);
      final res = await api.sealAreaMonthlyWorkflow(
        areaName: _selectedBranchName ?? 'Regional Area',
        year: _selectedExecYear,
        month: _selectedExecMonth,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Regional monthly package sealed for all supervised branches.'),
            backgroundColor: const Color(0xFF1D4ED8),
          ),
        );
        _refreshCurrentTabData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Regional seal failed: ${AppErrorDetails.from(e).message}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorkflowSubmitting = false);
    }
  }

  Future<void> _showBmSubmitDialog(MonthlyWorkflowStatusModel st) async {
    final notesController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dTokens = IcareSurfaceTokens.of(ctx);
        return AlertDialog(
          backgroundColor: dTokens.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: dTokens.successBg, borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.assignment_turned_in_outlined, color: dTokens.successText, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Verify & Submit Monthly Report',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: dTokens.textPrimary),
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Branch: ${_selectedBranchName ?? "Current"} • Period: $_selectedExecYear-${_selectedExecMonth.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: dTokens.brandPrimary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dTokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: dTokens.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        _buildSnapshotRow('Disbursed Principal', _formatNgn(st.disbursedPrincipal)),
                        _buildSnapshotRow('Upfront Fees Deducted', _formatNgn(st.upfrontFees)),
                        _buildSnapshotRow('Period Loan Collections', _formatNgn(st.collections)),
                        _buildSnapshotRow('Closing Active Credit', _formatNgn(st.closingCredit), isAccent: true),
                        _buildSnapshotRow('Closing Savings Balance', _formatNgn(st.closingSavings)),
                        _buildSnapshotRow('Physical Vault Cash', _formatNgn(st.vaultCashAcct1000)),
                        const Divider(height: 12),
                        _buildSnapshotRow(
                          'General Ledger Status',
                          st.isGlBalanced ? 'Balanced (₦0.00)' : 'Variance: ${_formatNgn(st.glVariance)}',
                          isDanger: !st.isGlBalanced,
                          isAccent: st.isGlBalanced,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: dTokens.infoBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: dTokens.infoBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: dTokens.infoText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Submitting certifies the branch books and locks the statement for Area Manager review.',
                            style: TextStyle(fontSize: 11.5, color: dTokens.infoText),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Manager Verification Notes (Optional)',
                      hintText: 'Enter verification notes...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.send, size: 14, color: Colors.white),
              label: const Text('Certify & Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: dTokens.brandPrimaryDark, foregroundColor: Colors.white),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isWorkflowSubmitting = true);
    try {
      final api = ref.read(reportsApiServiceProvider);
      final res = await api.submitMonthlyWorkflow(
        branchName: _selectedBranchName,
        year: _selectedExecYear,
        month: _selectedExecMonth,
        notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Monthly report certified and submitted to Area Manager.'),
            backgroundColor: const Color(0xFF065F46),
          ),
        );
        _refreshCurrentTabData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: ${AppErrorDetails.from(e).message}'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorkflowSubmitting = false);
    }
  }

  Future<void> _showAmEndorseDialog(MonthlyWorkflowStatusModel st) async {
    final notesController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dTokens = IcareSurfaceTokens.of(ctx);
        return AlertDialog(
          backgroundColor: dTokens.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: dTokens.successBg, borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.check_circle_outline, color: dTokens.successDot, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Endorse & Sign Off Monthly Report',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: dTokens.textPrimary),
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Branch: ${_selectedBranchName ?? "Current"} • Certified by: ${st.bmName ?? "Branch Manager"}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: dTokens.brandPrimary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dTokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: dTokens.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        _buildSnapshotRow('Disbursed Principal', _formatNgn(st.disbursedPrincipal)),
                        _buildSnapshotRow('Period Loan Collections', _formatNgn(st.collections)),
                        _buildSnapshotRow('Closing Active Credit', _formatNgn(st.closingCredit), isAccent: true),
                        _buildSnapshotRow('Closing Savings Balance', _formatNgn(st.closingSavings)),
                        _buildSnapshotRow('Physical Vault Cash', _formatNgn(st.vaultCashAcct1000)),
                        _buildSnapshotRow(
                          'General Ledger Status',
                          st.isGlBalanced ? 'Balanced (₦0.00)' : 'Variance: ${_formatNgn(st.glVariance)}',
                          isDanger: !st.isGlBalanced,
                          isAccent: st.isGlBalanced,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Area Supervisory Remarks (Optional)',
                      hintText: 'Enter supervisory remarks...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check, size: 14, color: Colors.white),
              label: const Text('Confirm Endorsement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: dTokens.brandPrimaryDark, foregroundColor: Colors.white),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isWorkflowSubmitting = true);
    try {
      final api = ref.read(reportsApiServiceProvider);
      final res = await api.endorseMonthlyWorkflow(
        branchName: _selectedBranchName,
        year: _selectedExecYear,
        month: _selectedExecMonth,
        notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Branch monthly report successfully endorsed.'),
            backgroundColor: const Color(0xFF065F46),
          ),
        );
        _refreshCurrentTabData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Endorsement failed: ${AppErrorDetails.from(e).message}'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorkflowSubmitting = false);
    }
  }

  Future<void> _showAmReturnDialog(MonthlyWorkflowStatusModel st) async {
    final queryController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dTokens = IcareSurfaceTokens.of(ctx);
        return AlertDialog(
          backgroundColor: dTokens.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: dTokens.dangerBg, borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.assignment_return_outlined, color: dTokens.dangerDot, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Return Report with Queries',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: dTokens.textPrimary),
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Specify corrections or discrepancies required from ${st.bmName ?? "Branch Manager"} before endorsement.',
                  style: TextStyle(fontSize: 12.5, color: dTokens.textSecondary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: queryController,
                  decoration: const InputDecoration(
                    labelText: 'Supervisory Query Notes (Required)',
                    hintText: 'Enter supervisory query notes...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () {
                if (queryController.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.send, size: 14, color: Colors.white),
              label: const Text('Return to Branch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            ),
          ],
        );
      },
    );

    if (confirm != true || queryController.text.trim().isEmpty) return;

    setState(() => _isWorkflowSubmitting = true);
    try {
      final api = ref.read(reportsApiServiceProvider);
      final res = await api.returnMonthlyWorkflow(
        branchName: _selectedBranchName,
        year: _selectedExecYear,
        month: _selectedExecMonth,
        queryNotes: queryController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Report returned to Branch Manager with queries.'),
            backgroundColor: const Color(0xFFB45309),
          ),
        );
        _refreshCurrentTabData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: ${AppErrorDetails.from(e).message}'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorkflowSubmitting = false);
    }
  }

  Future<void> _showAdminLockDialog(MonthlyWorkflowStatusModel st) async {
    final notesController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dTokens = IcareSurfaceTokens.of(ctx);
        return AlertDialog(
          backgroundColor: dTokens.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: dTokens.surfaceHover, borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.lock, color: dTokens.textPrimary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Institutional Lock & Permanent Archival',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: dTokens.textPrimary),
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This executive action permanently locks the monthly statements into institutional archive records. Once locked, no further adjustments or operational entries can be posted.',
                  style: TextStyle(fontSize: 12.5, color: dTokens.textSecondary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Executive Archival Remarks (Optional)',
                    hintText: 'Enter archival remarks...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.lock, size: 14, color: Colors.white),
              label: const Text('Execute Lock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: dTokens.isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isWorkflowSubmitting = true);
    try {
      final api = ref.read(reportsApiServiceProvider);
      final res = await api.lockMonthlyWorkflow(
        branchName: _selectedBranchName,
        year: _selectedExecYear,
        month: _selectedExecMonth,
        notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Monthly report permanently locked and archived.'),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
        _refreshCurrentTabData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lock failed: ${AppErrorDetails.from(e).message}'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorkflowSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Reusable Component Helpers
  // ---------------------------------------------------------------------------
  Widget _buildMetricCard(String label, String value, {String? subtitle, bool isAccent = false, double? width}) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: width ?? 170,
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isAccent ? tokens.brandPrimaryDark : tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isAccent ? tokens.brandPrimaryDark : tokens.borderSubtle),
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
              color: isAccent ? const Color(0xFFA7F3D0) : tokens.textMuted,
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
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isAccent ? Colors.white : tokens.textPrimary,
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
                color: isAccent ? const Color(0xFFA7F3D0) : tokens.textMuted,
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
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
              ),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, size: 14, color: tokens.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hint ?? 'Swipe horizontally to view all columns',
                      style: TextStyle(fontSize: 11, color: tokens.textMuted, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
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
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Center(
        child: Text(message, style: TextStyle(fontSize: 13, color: tokens.textMuted)),
      ),
    );
  }

  Widget _buildErrorCard(Object error, {VoidCallback? onRetry}) {
    final details = AppErrorDetails.from(error);
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.dangerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.dangerBorder),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: tokens.dangerDot, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details.title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.dangerText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details.message,
                      style: TextStyle(fontSize: 12, color: tokens.dangerText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: onRetry ?? _refreshCurrentTabData,
            icon: Icon(Icons.refresh, size: 14, color: tokens.dangerText),
            label: Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.dangerText)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: tokens.dangerBorder),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    final tokens = IcareSurfaceTokens.of(context);
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: tokens.surfaceSubtle,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: tokens.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: tokens.borderStrong),
      ),
    );
  }
}
