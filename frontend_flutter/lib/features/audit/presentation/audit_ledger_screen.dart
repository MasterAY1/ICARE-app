// ignore_for_file: deprecated_member_use, unnecessary_const
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../data/datasources/audit_api_service.dart';
import '../data/models/audit_models.dart';
import '../../shared/utils/file_download_helper.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';

class AuditLedgerScreen extends ConsumerStatefulWidget {
  const AuditLedgerScreen({super.key});

  @override
  ConsumerState<AuditLedgerScreen> createState() => _AuditLedgerScreenState();
}

class _AuditLedgerScreenState extends ConsumerState<AuditLedgerScreen> {
  // Navigation State
  late String _activeTab;
  bool _tabsInitialized = false;
  bool? _useCardView;

  // Metadata Cache
  AuditMetaModel? _meta;

  // Selected Filter States
  late DateTime _globalFromDate;
  late DateTime _globalToDate;
  late DateTime _collectionsFromDate;

  // Per-Tab Filter Values
  String _selectedFeeType = 'ALL';
  String _selectedFeeBranch = 'All Branches';
  String _selectedFeeOfficer = 'All Officers';
  final _feeSearchCtrl = TextEditingController();
  int _selectedFeeInspectIdx = 0;
  bool _showRawFeeTech = false;

  String _selectedTrType = 'ALL';
  String _selectedTrBranch = 'All Branches';
  String _selectedTrOfficer = 'All Officers';
  final _trSearchCtrl = TextEditingController();
  int _selectedTrInspectIdx = 0;
  bool _showRawTrTech = false;

  String _selectedSavSub = 'ALL';
  String _selectedSavBranch = 'All Branches';
  String _selectedSavOfficer = 'All Officers';
  final _savSearchCtrl = TextEditingController();
  int _selectedSavInspectIdx = 0;
  bool _showRawSavTech = false;

  String _selectedLoanView = 'Loan Disbursements';
  String _selectedLoanProd = 'All Products';
  String _selectedLoanBranch = 'All Branches';
  String _selectedLoanOfficer = 'All Officers';
  final _loanSearchCtrl = TextEditingController();
  int _selectedLoanInspectIdx = 0;
  bool _showRawLoanTech = false;

  String _selectedCpBranch = 'All Branches';
  String _selectedCpOfficer = 'All Officers';
  String _selectedCpStatus = 'ALL';
  final _cpSearchCtrl = TextEditingController();
  int _selectedCpInspectIdx = 0;
  bool _showRawCpTech = false;

  // 360 Explorer State
  final _explorerSearchCtrl = TextEditingController();
  UniversalExplorerResponseModel? _explorerResult;
  bool _explorerLoading = false;
  String? _expandedTimelineLoanId;
  List<Map<String, dynamic>>? _loanTimelineData;
  bool _loadingTimeline = false;

  // Reconciliation Wizard State
  DateTime _rwDate = DateTime.now();
  bool _repairing = false;
  ReconciliationRepairResponseModel? _repairResult;
  String? _wizardBanner;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _globalFromDate = DateTime(now.year, now.month, 1);
    _globalToDate = now;
    _collectionsFromDate = now.subtract(const Duration(days: 30));
    _loadMetadata();
  }

  @override
  void dispose() {
    _feeSearchCtrl.dispose();
    _trSearchCtrl.dispose();
    _savSearchCtrl.dispose();
    _loanSearchCtrl.dispose();
    _cpSearchCtrl.dispose();
    _explorerSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    try {
      final authState = ref.read(authControllerProvider);
      final user = authState is AuthStateAuthenticated ? authState.user : null;
      final role = (user?.role ?? '').trim();
      final isAdmin = role == 'Admin' || role == 'Super Admin' || role == 'ADMIN' || role == 'Director' || role == 'Board Director';
      final isAm = role == 'AM' || role == 'Area Manager' || role == 'AREA_MANAGER';

      final meta = await ref.read(auditApiServiceProvider).getMetadata(
        branchId: (!isAdmin && !isAm) ? user?.branchId : null,
      );
      if (mounted) {
        setState(() {
          _meta = meta;
          final userBranch = user?.branch ?? (meta.branches.isNotEmpty ? meta.branches.first.name : 'Ogijo');
          if (!isAdmin) {
            _selectedFeeBranch = userBranch;
            _selectedTrBranch = userBranch;
            _selectedSavBranch = userBranch;
            _selectedLoanBranch = userBranch;
            _selectedCpBranch = userBranch;
          }
        });
      }
    } catch (_) {}
  }

  String _formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);
  String _formatCurrency(double val) => '₦${NumberFormat('#,##0.00').format(val)}';

  void _exportCsvFromRecords(List<Map<String, dynamic>> records, String baseName) {
    if (records.isEmpty) return;
    final clean = records.map((r) {
      final m = <String, dynamic>{};
      r.forEach((k, v) {
        if (!k.endsWith('_Raw') && !k.startsWith('_')) m[k] = v;
      });
      return m;
    }).toList();

    final keys = clean.first.keys.toList();
    final buffer = StringBuffer();
    buffer.writeln(keys.map((k) => '"$k"').join(','));

    for (final row in clean) {
      buffer.writeln(keys.map((k) {
        final val = row[k]?.toString() ?? '';
        return '"${val.replaceAll('"', '""')}"';
      }).join(','));
    }

    final bytes = utf8.encode(buffer.toString());
    final fileName = 'audit_${baseName}_${_formatDate(DateTime.now())}.csv';
    downloadBlobFile(bytes, fileName, 'text/csv');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final role = (user?.role ?? '').trim();

    final isOfficer = role == 'CO' || role == 'Officer' || role == 'Credit Officer' || role == 'CREDIT_OFFICER';
    final isBm = role == 'BM' || role == 'Branch Manager' || role == 'BRANCH_MANAGER';
    final isAm = role == 'AM' || role == 'Area Manager' || role == 'AREA_MANAGER';
    final isAdmin = role == 'Admin' || role == 'Super Admin' || role == 'ADMIN' || role == 'Director' || role == 'Board Director';

    // Establish Role-Based Available Tabs
    final List<String> availableTabs;
    final String pageTitle;
    final String pageCaption;

    if (isOfficer) {
      pageTitle = 'Credit Officer Audit Ledger';
      pageCaption = 'Personalized audit trail of your client savings, loans, and collections.';
      availableTabs = ['Savings Ledger', 'Loan Portfolio', 'Collection Performance'];
    } else if (isBm || isAm) {
      pageTitle = 'Branch Audit Ledger';
      pageCaption = 'Read-only branch audit trails, 6-way financial integrity verification, and 360° transaction explorer.';
      availableTabs = [
        '6-Way Integrity Match',
        'Fees Audit',
        'Treasury Audit',
        'Savings Ledger',
        'Loan Portfolio',
        'Collection Performance',
        '360° Explorer & Timeline'
      ];
    } else {
      pageTitle = 'Enterprise Audit & Reconciliation Center';
      pageCaption = 'Read-only executive ledgers, 6-way financial integrity verification, 360° universal explorer, and 15 automated exception reports.';
      availableTabs = [
        '6-Way Integrity Match',
        'Fees Audit',
        'Treasury Audit',
        'Savings Ledger',
        'Loan Portfolio',
        'Collection Performance',
        'Exception Reports',
        '360° Explorer & Timeline',
        'Performance Insights',
        'Reconciliation Wizard'
      ];
    }

    if (!_tabsInitialized) {
      _activeTab = availableTabs.first;
      _tabsInitialized = true;
    } else if (!availableTabs.contains(_activeTab)) {
      _activeTab = availableTabs.first;
    }

    final branchName = user?.branch.isNotEmpty == true ? user!.branch : 'All Branches';
    final branchId = user?.branchId ?? '';

    final isMobile = MediaQuery.of(context).size.width < 750;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Header
          Text(
            pageTitle,
            style: TextStyle(
              fontSize: isMobile ? 20 : 26,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pageCaption,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Authentic Streamlit Pill Tabs Bar
          _buildPillTabsBar(availableTabs),
          const SizedBox(height: 20),

          // Tab Content Dispatcher
          _buildTabContent(
            activeTab: _activeTab,
            branchName: branchName,
            branchId: branchId,
            isOfficer: isOfficer,
            isBm: isBm,
            isAm: isAm,
            isAdmin: isAdmin,
            user: user,
          ),
        ],
      ),
    );
  }

  IconData _getTabIcon(String tab) {
    switch (tab) {
      case '6-Way Integrity Match':
        return Icons.verified_outlined;
      case 'Fees Audit':
        return Icons.receipt_long_outlined;
      case 'Treasury Audit':
        return Icons.account_balance_outlined;
      case 'Savings Ledger':
        return Icons.savings_outlined;
      case 'Loan Portfolio':
        return Icons.payments_outlined;
      case 'Collection Performance':
        return Icons.trending_up;
      case 'Exception Reports':
        return Icons.warning_amber_rounded;
      case '360° Explorer & Timeline':
        return Icons.travel_explore;
      case 'Performance Insights':
        return Icons.insights;
      case 'Reconciliation Wizard':
        return Icons.auto_fix_high;
      default:
        return Icons.folder_outlined;
    }
  }

  Widget _buildPillTabsBar(List<String> tabs) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _activeTab == tab;
          final icon = _getTabIcon(tab);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _activeTab = tab),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2E86C1) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2E86C1) : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2E86C1).withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent({
    required String activeTab,
    required String branchName,
    required String branchId,
    required bool isOfficer,
    required bool isBm,
    required bool isAm,
    required bool isAdmin,
    required AuthUser? user,
  }) {
    switch (activeTab) {
      case '6-Way Integrity Match':
        return _buildTab1Integrity(branchId);
      case 'Fees Audit':
        return _buildTab2Fees(branchId, isOfficer, isBm, isAdmin);
      case 'Treasury Audit':
        return _buildTab3Treasury(branchId, isOfficer, isBm, isAdmin);
      case 'Savings Ledger':
        return _buildTab4Savings(branchId, isOfficer, isBm, isAdmin);
      case 'Loan Portfolio':
        return _buildTab5Loans(branchId, isOfficer, isBm, isAdmin);
      case 'Collection Performance':
        return _buildTab6Collections(branchId, isOfficer, isBm, isAdmin);
      case 'Exception Reports':
        return _buildTab7Exceptions(branchId);
      case '360° Explorer & Timeline':
        return _buildTab8Explorer(branchId);
      case 'Performance Insights':
        return _buildTab9Insights(branchId);
      case 'Reconciliation Wizard':
        return _buildTab10Wizard(branchId);
      default:
        return const SizedBox.shrink();
    }
  }

  // =========================================================================
  // TAB 1: 6-WAY FINANCIAL INTEGRITY
  // =========================================================================
  Widget _buildTab1Integrity(String branchId) {
    return FutureBuilder<Integrity6WayModel>(
      future: ref.read(auditApiServiceProvider).get6WayIntegrity(branchId: branchId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
        }
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
            child: Text('Error loading 6-Way Integrity check: ${snapshot.error}', style: const TextStyle(color: Color(0xFFDC2626))),
          );
        }

        final data = snapshot.data!;
        final isBal = data.isBalanced;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live 6-Way Financial Integrity Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Automated mathematical balance verification across General Ledger, Audit Views, Cashbooks, Dashboards, and Reports.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 16),

            // Status Banner (Strict Zero-Emoji, Rule 10)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isBal ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isBal ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isBal ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isBal ? Icons.verified_outlined : Icons.error_outline,
                      color: isBal ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBal ? 'FINANCIAL INTEGRITY VERIFIED' : 'VARIANCE DETECTED IN AUDIT LEDGER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isBal ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.statusText,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isBal ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 6 KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                final isMedium = constraints.maxWidth > 550;
                final cardW = isWide
                    ? (constraints.maxWidth - 50) / 6
                    : (isMedium ? (constraints.maxWidth - 20) / 3 : (constraints.maxWidth - 10) / 2);
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildKpiCard('1. General Ledger', _formatCurrency(data.ledgerTotal), width: cardW),
                    _buildKpiCard('2. Audit Views', _formatCurrency(data.auditViewsTotal), width: cardW),
                    _buildKpiCard('3. CO Cashbooks', _formatCurrency(data.coCashbooksTotal), width: cardW),
                    _buildKpiCard('4. Master Cashbook', _formatCurrency(data.masterCashbookTotal), width: cardW),
                    _buildKpiCard('5. Dashboard', _formatCurrency(data.dashboardTotal), width: cardW),
                    _buildKpiCard('6. Reports', _formatCurrency(data.reportsTotal), width: cardW),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Itemized Variance Breakdown Table
            if (data.variances.isNotEmpty) ...[
              const Text('Itemized Variance Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 10),
              _buildDynamicDataTable(
                data.variances.map((v) => {
                  'Source': v.source,
                  'Expected (₦)': _formatCurrency(v.expected),
                  'Actual (₦)': _formatCurrency(v.actual),
                  'Variance (₦)': _formatCurrency(v.variance),
                  'Cause': v.cause,
                  'Status': 'MISMATCH',
                }).toList(),
                ['Source', 'Expected (₦)', 'Actual (₦)', 'Variance (₦)', 'Cause', 'Status'],
              ),
            ],
          ],
        );
      },
    );
  }

  // =========================================================================
  // TAB 2: FEES AUDIT
  // =========================================================================
  Widget _buildTab2Fees(String branchId, bool isOfficer, bool isBm, bool isAdmin) {
    final bOptions = _getBranchOptions(isAdmin);
    final oOptions = _getOfficerOptions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fee Audit Ledgers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text('Itemized audit trail of loan origination fees, passbooks, and processing charges.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        // Responsive Filter Bar
        _buildFilterCard(
          onDateQuickSelect: (from, to) => setState(() {
            _globalFromDate = from;
            _globalToDate = to;
          }),
          child: Builder(
            builder: (context) {
              final isMobile = MediaQuery.of(context).size.width < 750;
              if (isMobile) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker('Date From', _globalFromDate, (d) => setState(() => _globalFromDate = d))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildDatePicker('Date To', _globalToDate, (d) => setState(() => _globalToDate = d))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            'Fee Type',
                            _selectedFeeType,
                            ['ALL', 'PROCESSING_FEE', 'MARKUP_11', 'MARKUP_20', 'CONTINGENCY', 'PASSBOOK', 'CREDIT_FORM_DAMAGE', 'BONUS'],
                            (v) => setState(() => _selectedFeeType = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDropdown(
                            'Branch',
                            _selectedFeeBranch,
                            bOptions,
                            (v) => setState(() => _selectedFeeBranch = v),
                            enabled: isAdmin,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            'Officer',
                            _selectedFeeOfficer,
                            oOptions,
                            (v) => setState(() => _selectedFeeOfficer = v),
                            enabled: !isOfficer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSearchField('Search Client / Ref', _feeSearchCtrl, () => setState(() {})),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: _buildDatePicker('Date From', _globalFromDate, (d) => setState(() => _globalFromDate = d))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _buildDatePicker('Date To', _globalToDate, (d) => setState(() => _globalToDate = d))),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Fee Type',
                      _selectedFeeType,
                      ['ALL', 'PROCESSING_FEE', 'MARKUP_11', 'MARKUP_20', 'CONTINGENCY', 'PASSBOOK', 'CREDIT_FORM_DAMAGE', 'BONUS'],
                      (v) => setState(() => _selectedFeeType = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Branch',
                      _selectedFeeBranch,
                      bOptions,
                      (v) => setState(() => _selectedFeeBranch = v),
                      enabled: isAdmin,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Officer',
                      _selectedFeeOfficer,
                      oOptions,
                      (v) => setState(() => _selectedFeeOfficer = v),
                      enabled: !isOfficer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildSearchField('Search Client / Ref', _feeSearchCtrl, () => setState(() {})),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Data Loader
        FutureBuilder<FeeLedgerResponseModel>(
          future: ref.read(auditApiServiceProvider).getFeeLedger(
            dateFrom: _formatDate(_globalFromDate),
            dateTo: _formatDate(_globalToDate),
            feeType: _selectedFeeType,
            branchId: _resolveTargetBranchId(_selectedFeeBranch, branchId),
            officerId: _resolveTargetOfficerId(_selectedFeeOfficer),
            search: _feeSearchCtrl.text.trim(),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFFDC2626)));
            }

            final data = snapshot.data!;
            final m = data.metrics;
            final records = data.records;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKpiRow5([
                  _KpiItem('Total Amount', _formatCurrency(m.totalAmount)),
                  _KpiItem('Transaction Count', m.totalCount.toString()),
                  _KpiItem('Average Transaction', _formatCurrency(m.averageAmount)),
                  _KpiItem('Last Txn Date', m.lastTransactionDate),
                  _KpiItem('Highest Txn', _formatCurrency(m.highestAmount)),
                ]),
                const SizedBox(height: 16),

                if (records.isEmpty)
                  _buildEmptyState('No fee records found for the selected filters.')
                else ...[
                  _buildDynamicDataTable(records, [
                    'Date', 'Client Code', 'Client Name', 'Fee Type', 'Amount', 'Officer', 'Branch', 'Reference', 'Status'
                  ]),
                  const SizedBox(height: 14),
                  _buildInspectorSection(
                    title: 'View Transaction Details',
                    records: records,
                    selectedIndex: _selectedFeeInspectIdx,
                    onIndexChanged: (idx) => setState(() => _selectedFeeInspectIdx = idx),
                    labelBuilder: (r) => '${r['Client Code']} — ${r['Client Name']} (${r['Amount']})',
                    detailsBuilder: (sel) => [
                      _DetailItem('Posting Date', sel['Date']),
                      _DetailItem('Fee Bucket', sel['Fee Type']),
                      _DetailItem('Customer', '${sel['Client Code']} (${sel['Client Name']})'),
                      _DetailItem('Financial Amount', sel['Amount']),
                      _DetailItem('Officer', sel['Officer']),
                      _DetailItem('Branch', sel['Branch']),
                      _DetailItem('Reference', sel['Reference']),
                      _DetailItem('Status', sel['Status']),
                    ],
                    showRawTech: _showRawFeeTech,
                    onToggleRawTech: (v) => setState(() => _showRawFeeTech = v),
                  ),
                  const SizedBox(height: 14),
                  _buildExportButton('Export $_selectedFeeType CSV', () => _exportCsvFromRecords(records, 'fees_${_selectedFeeType.toLowerCase()}')),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 3: TREASURY AUDIT
  // =========================================================================
  Widget _buildTab3Treasury(String branchId, bool isOfficer, bool isBm, bool isAdmin) {
    final bOptions = _getBranchOptions(isAdmin);
    final oOptions = _getOfficerOptions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Treasury Audit Ledgers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text('Audit trail of bank deposits, withdrawals, staff salaries, and inter-branch cash transfers.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        // Responsive Filter Bar
        _buildFilterCard(
          onDateQuickSelect: (from, to) => setState(() {
            _globalFromDate = from;
            _globalToDate = to;
          }),
          child: Builder(
            builder: (context) {
              final isMobile = MediaQuery.of(context).size.width < 750;
              if (isMobile) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker('Date From', _globalFromDate, (d) => setState(() => _globalFromDate = d))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildDatePicker('Date To', _globalToDate, (d) => setState(() => _globalToDate = d))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            'Category',
                            _selectedTrType,
                            ['ALL', 'BANK_DEPOSIT', 'BANK_WITHDRAWAL', 'OFFICE_EXPENSE', 'STAFF_SALARY', 'HO_TRANSFER_IN', 'HO_TRANSFER_OUT', 'BRANCH_TRANSFER_IN', 'BRANCH_TRANSFER_OUT', 'OTHER_AREA_TRANSFER', 'ASSET_PROGRAM', 'PRODUCT_FINANCE'],
                            (v) => setState(() => _selectedTrType = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDropdown(
                            'Branch',
                            _selectedTrBranch,
                            bOptions,
                            (v) => setState(() => _selectedTrBranch = v),
                            enabled: isAdmin,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            'Officer',
                            _selectedTrOfficer,
                            oOptions,
                            (v) => setState(() => _selectedTrOfficer = v),
                            enabled: !isOfficer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSearchField('Search Category / Ref', _trSearchCtrl, () => setState(() {})),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: _buildDatePicker('Date From', _globalFromDate, (d) => setState(() => _globalFromDate = d))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _buildDatePicker('Date To', _globalToDate, (d) => setState(() => _globalToDate = d))),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Category',
                      _selectedTrType,
                      ['ALL', 'BANK_DEPOSIT', 'BANK_WITHDRAWAL', 'OFFICE_EXPENSE', 'STAFF_SALARY', 'HO_TRANSFER_IN', 'HO_TRANSFER_OUT', 'BRANCH_TRANSFER_IN', 'BRANCH_TRANSFER_OUT', 'OTHER_AREA_TRANSFER', 'ASSET_PROGRAM', 'PRODUCT_FINANCE'],
                      (v) => setState(() => _selectedTrType = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Branch',
                      _selectedTrBranch,
                      bOptions,
                      (v) => setState(() => _selectedTrBranch = v),
                      enabled: isAdmin,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Officer',
                      _selectedTrOfficer,
                      oOptions,
                      (v) => setState(() => _selectedTrOfficer = v),
                      enabled: !isOfficer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildSearchField('Search Category / Ref', _trSearchCtrl, () => setState(() {})),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        FutureBuilder<TreasuryLedgerResponseModel>(
          future: ref.read(auditApiServiceProvider).getTreasuryLedger(
            dateFrom: _formatDate(_globalFromDate),
            dateTo: _formatDate(_globalToDate),
            category: _selectedTrType,
            branchId: _resolveTargetBranchId(_selectedTrBranch, branchId),
            officerId: _resolveTargetOfficerId(_selectedTrOfficer),
            search: _trSearchCtrl.text.trim(),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFFDC2626)));
            }

            final data = snapshot.data!;
            final m = data.metrics;
            final records = data.records;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKpiRow5([
                  _KpiItem('Total Amount', _formatCurrency(m.totalAmount)),
                  _KpiItem('Transaction Count', m.totalCount.toString()),
                  _KpiItem('Average Transaction', _formatCurrency(m.averageAmount)),
                  _KpiItem('Last Txn Date', m.lastTransactionDate),
                  _KpiItem('Highest Txn', _formatCurrency(m.highestAmount)),
                ]),
                const SizedBox(height: 16),

                if (records.isEmpty)
                  _buildEmptyState('No treasury records found for the selected filters.')
                else ...[
                  _buildDynamicDataTable(records, [
                    'Date', 'Category', 'Amount', 'Officer', 'Branch', 'Reference', 'Narration', 'Status'
                  ]),
                  const SizedBox(height: 14),
                  _buildInspectorSection(
                    title: 'View Transaction Details',
                    records: records,
                    selectedIndex: _selectedTrInspectIdx,
                    onIndexChanged: (idx) => setState(() => _selectedTrInspectIdx = idx),
                    labelBuilder: (r) => '${r['Category']} — ${r['Amount']} (${r['Date']})',
                    detailsBuilder: (sel) => [
                      _DetailItem('Date', sel['Date']),
                      _DetailItem('Category', sel['Category']),
                      _DetailItem('Amount', sel['Amount']),
                      _DetailItem('Reference', sel['Reference']),
                      _DetailItem('Officer', sel['Officer']),
                      _DetailItem('Branch', sel['Branch']),
                      _DetailItem('Narration', sel['Narration']),
                      _DetailItem('Status', sel['Status']),
                    ],
                    showRawTech: _showRawTrTech,
                    onToggleRawTech: (v) => setState(() => _showRawTrTech = v),
                  ),
                  const SizedBox(height: 14),
                  _buildExportButton('Export $_selectedTrType CSV', () => _exportCsvFromRecords(records, 'treasury_${_selectedTrType.toLowerCase()}')),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 4: SAVINGS AUDIT
  // =========================================================================
  Widget _buildTab4Savings(String branchId, bool isOfficer, bool isBm, bool isAdmin) {
    final bOptions = _getBranchOptions(isAdmin);
    final oOptions = _getOfficerOptions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Savings Audit Ledgers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text('Audit trail of voluntary individual deposits, group collateral savings, and laps reserves.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        // Responsive Filter Bar
        _buildFilterCard(
          onDateQuickSelect: (from, to) => setState(() {
            _globalFromDate = from;
            _globalToDate = to;
          }),
          child: Builder(
            builder: (context) {
              final isMobile = MediaQuery.of(context).size.width < 750;
              if (isMobile) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker('Date From', _globalFromDate, (d) => setState(() => _globalFromDate = d))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildDatePicker('Date To', _globalToDate, (d) => setState(() => _globalToDate = d))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            'Savings Ledger',
                            _selectedSavSub,
                            ['ALL', 'Individual Savings', 'Group Savings', 'Misc Savings', 'Laps Savings'],
                            (v) => setState(() => _selectedSavSub = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDropdown(
                            'Branch',
                            _selectedSavBranch,
                            bOptions,
                            (v) => setState(() => _selectedSavBranch = v),
                            enabled: isAdmin,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            'Officer',
                            _selectedSavOfficer,
                            oOptions,
                            (v) => setState(() => _selectedSavOfficer = v),
                            enabled: !isOfficer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSearchField('Search Client / Code', _savSearchCtrl, () => setState(() {})),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: _buildDatePicker('Date From', _globalFromDate, (d) => setState(() => _globalFromDate = d))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _buildDatePicker('Date To', _globalToDate, (d) => setState(() => _globalToDate = d))),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Savings Ledger',
                      _selectedSavSub,
                      ['ALL', 'Individual Savings', 'Group Savings', 'Misc Savings', 'Laps Savings'],
                      (v) => setState(() => _selectedSavSub = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Branch',
                      _selectedSavBranch,
                      bOptions,
                      (v) => setState(() => _selectedSavBranch = v),
                      enabled: isAdmin,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Officer',
                      _selectedSavOfficer,
                      oOptions,
                      (v) => setState(() => _selectedSavOfficer = v),
                      enabled: !isOfficer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildSearchField('Search Client / Code', _savSearchCtrl, () => setState(() {})),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        FutureBuilder<SavingsLedgerResponseModel>(
          future: ref.read(auditApiServiceProvider).getSavingsLedger(
            dateFrom: _formatDate(_globalFromDate),
            dateTo: _formatDate(_globalToDate),
            savingsLedger: _selectedSavSub,
            branchId: _resolveTargetBranchId(_selectedSavBranch, branchId),
            officerId: _resolveTargetOfficerId(_selectedSavOfficer),
            search: _savSearchCtrl.text.trim(),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFFDC2626)));
            }

            final data = snapshot.data!;
            final m = data.metrics;
            final records = data.records;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKpiRow5([
                  _KpiItem('Total Deposits', _formatCurrency(m.totalDeposits)),
                  _KpiItem('Total Withdrawals', _formatCurrency(m.totalWithdrawals)),
                  _KpiItem('Net Savings Movement', _formatCurrency(m.netSavingsMovement)),
                  _KpiItem('Transactions', m.transactionsCount.toString()),
                  _KpiItem('Active Accounts', m.activeAccountsCount.toString()),
                ]),
                const SizedBox(height: 16),

                if (records.isEmpty)
                  _buildEmptyState('No savings records found for the selected filters.')
                else ...[
                  _buildDynamicDataTable(records, [
                    'Date', 'Client Code', 'Client Name', 'Ledger', 'Deposit', 'Withdrawal', 'Available Balance', 'Officer', 'Branch', 'Remarks', 'Status'
                  ]),
                  const SizedBox(height: 14),
                  _buildInspectorSection(
                    title: 'View Transaction Details',
                    records: records,
                    selectedIndex: _selectedSavInspectIdx,
                    onIndexChanged: (idx) => setState(() => _selectedSavInspectIdx = idx),
                    labelBuilder: (r) => '${r['Client Code']} — ${r['Client Name']} (Avail: ${r['Available Balance'] ?? r['Balance']})',
                    detailsBuilder: (sel) => [
                      _DetailItem('Date', sel['Date']),
                      _DetailItem('Client Code', sel['Client Code']),
                      _DetailItem('Client Name', sel['Client Name']),
                      _DetailItem('Ledger', sel['Ledger']),
                      _DetailItem('Deposit', sel['Deposit']),
                      _DetailItem('Withdrawal', sel['Withdrawal']),
                      _DetailItem('Available Balance', sel['Available Balance'] ?? sel['Balance']),
                      _DetailItem('Officer', sel['Officer']),
                      _DetailItem('Branch', sel['Branch']),
                      _DetailItem('Remarks', sel['Remarks']),
                      _DetailItem('Status', sel['Status']),
                    ],
                    showRawTech: _showRawSavTech,
                    onToggleRawTech: (v) => setState(() => _showRawSavTech = v),
                  ),
                  const SizedBox(height: 14),
                  _buildExportButton('Export $_selectedSavSub CSV', () => _exportCsvFromRecords(records, 'savings_${_selectedSavSub.toLowerCase().replaceAll(' ', '_')}')),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 5: LOAN AUDIT
  // =========================================================================
  Widget _buildTab5Loans(String branchId, bool isOfficer, bool isBm, bool isAdmin) {
    final bOptions = _getBranchOptions(isAdmin);
    final oOptions = _getOfficerOptions();
    final pOptions = ['All Products'] + (_meta?.products.map((p) => p.name).toList() ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Loan Audit Ledgers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text('Audit trail of approved principal disbursements and loan repayment collections.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        // Responsive Filter Bar
        _buildFilterCard(
          onDateQuickSelect: (from, to) => setState(() {
            _globalFromDate = from;
            _globalToDate = to;
          }),
          child: Builder(
            builder: (context) {
              final isMobile = MediaQuery.of(context).size.width < 750;
              if (isMobile) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker('Date From', _globalFromDate, (d) => setState(() => _globalFromDate = d))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildDatePicker('Date To', _globalToDate, (d) => setState(() => _globalToDate = d))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            'Loan View',
                            _selectedLoanView,
                            ['Loan Disbursements', 'Repayments'],
                            (v) => setState(() => _selectedLoanView = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDropdown(
                            'Product',
                            _selectedLoanProd,
                            pOptions,
                            (v) => setState(() => _selectedLoanProd = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            'Branch',
                            _selectedLoanBranch,
                            bOptions,
                            (v) => setState(() => _selectedLoanBranch = v),
                            enabled: isAdmin,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDropdown(
                            'Officer',
                            _selectedLoanOfficer,
                            oOptions,
                            (v) => setState(() => _selectedLoanOfficer = v),
                            enabled: !isOfficer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSearchField('Search Loan / Client', _loanSearchCtrl, () => setState(() {})),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: _buildDatePicker('Date From', _globalFromDate, (d) => setState(() => _globalFromDate = d))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _buildDatePicker('Date To', _globalToDate, (d) => setState(() => _globalToDate = d))),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Loan View',
                      _selectedLoanView,
                      ['Loan Disbursements', 'Repayments'],
                      (v) => setState(() => _selectedLoanView = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Product',
                      _selectedLoanProd,
                      pOptions,
                      (v) => setState(() => _selectedLoanProd = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Branch',
                      _selectedLoanBranch,
                      bOptions,
                      (v) => setState(() => _selectedLoanBranch = v),
                      enabled: isAdmin,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Officer',
                      _selectedLoanOfficer,
                      oOptions,
                      (v) => setState(() => _selectedLoanOfficer = v),
                      enabled: !isOfficer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildSearchField('Search Loan / Client', _loanSearchCtrl, () => setState(() {})),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        FutureBuilder<LoanLedgerResponseModel>(
          future: ref.read(auditApiServiceProvider).getLoanLedger(
            viewType: _selectedLoanView,
            dateFrom: _formatDate(_globalFromDate),
            dateTo: _formatDate(_globalToDate),
            productId: _resolveTargetProductId(_selectedLoanProd),
            branchId: _resolveTargetBranchId(_selectedLoanBranch, branchId),
            officerId: _resolveTargetOfficerId(_selectedLoanOfficer),
            search: _loanSearchCtrl.text.trim(),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFFDC2626)));
            }

            final data = snapshot.data!;
            final records = data.records;
            final isDisb = data.viewType == 'Loan Disbursements';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDisb && data.disbursementMetrics != null)
                  _buildKpiRow5([
                    _KpiItem('Total Principal Disbursed', _formatCurrency(data.disbursementMetrics!.totalPrincipalDisbursed)),
                    _KpiItem('Loans Disbursed', data.disbursementMetrics!.loansDisbursed.toString()),
                    _KpiItem('Average Principal', _formatCurrency(data.disbursementMetrics!.averagePrincipal)),
                    _KpiItem('Borrowers Count', data.disbursementMetrics!.borrowersCount.toString()),
                    _KpiItem('Active Portfolio', _formatCurrency(data.disbursementMetrics!.activePortfolio)),
                  ])
                else if (!isDisb && data.repaymentMetrics != null)
                  _buildKpiRow4([
                    _KpiItem('Total Repayments Collected', _formatCurrency(data.repaymentMetrics!.totalRepaymentsCollected)),
                    _KpiItem('Repayment Count', data.repaymentMetrics!.repaymentCount.toString()),
                    _KpiItem('Average Repayment', _formatCurrency(data.repaymentMetrics!.averageRepayment)),
                    _KpiItem('Active Paying Clients', data.repaymentMetrics!.activePayingClients.toString()),
                  ]),
                const SizedBox(height: 16),

                if (records.isEmpty)
                  _buildEmptyState('No loan records found for the selected filters.')
                else ...[
                  _buildDynamicDataTable(
                    records,
                    isDisb
                        ? ['Disbursement Date', 'Loan Number', 'Client Code', 'Client Name', 'Product', 'Officer', 'Branch', 'Principal', 'Status']
                        : ['Repayment Date', 'Loan Number', 'Client Code', 'Client Name', 'Product', 'Amount Paid', 'Officer', 'Branch', 'Transaction Type', 'Status'],
                  ),
                  const SizedBox(height: 14),
                  _buildInspectorSection(
                    title: 'View Transaction Details',
                    records: records,
                    selectedIndex: _selectedLoanInspectIdx,
                    onIndexChanged: (idx) => setState(() => _selectedLoanInspectIdx = idx),
                    labelBuilder: (r) => isDisb
                        ? '${r['Loan Number']} — ${r['Client Name']} (${r['Principal']})'
                        : '${r['Loan Number']} — ${r['Client Name']} (${r['Amount Paid']})',
                    detailsBuilder: (sel) => isDisb
                        ? [
                            _DetailItem('Disbursement Date', sel['Disbursement Date']),
                            _DetailItem('Loan Number', sel['Loan Number']),
                            _DetailItem('Client', '${sel['Client Code']} (${sel['Client Name']})'),
                            _DetailItem('Principal', sel['Principal']),
                            _DetailItem('Product', sel['Product']),
                            _DetailItem('Officer', sel['Officer']),
                            _DetailItem('Branch', sel['Branch']),
                            _DetailItem('Status', sel['Status']),
                          ]
                        : [
                            _DetailItem('Repayment Date', sel['Repayment Date']),
                            _DetailItem('Loan Number', sel['Loan Number']),
                            _DetailItem('Client', '${sel['Client Code']} (${sel['Client Name']})'),
                            _DetailItem('Amount Paid', sel['Amount Paid']),
                            _DetailItem('Product', sel['Product']),
                            _DetailItem('Officer', sel['Officer']),
                            _DetailItem('Branch', sel['Branch']),
                            _DetailItem('Status', sel['Status']),
                          ],
                    showRawTech: _showRawLoanTech,
                    onToggleRawTech: (v) => setState(() => _showRawLoanTech = v),
                  ),
                  const SizedBox(height: 14),
                  _buildExportButton(
                    isDisb ? 'Export Loan Disbursements CSV' : 'Export Repayments CSV',
                    () => _exportCsvFromRecords(records, isDisb ? 'loan_disbursements' : 'loan_repayments'),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 6: COLLECTION PERFORMANCE
  // =========================================================================
  Widget _buildTab6Collections(String branchId, bool isOfficer, bool isBm, bool isAdmin) {
    final bOptions = _getBranchOptions(isAdmin);
    final oOptions = _getOfficerOptions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Collection Performance Audit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text('Meeting compliance matrix comparing expected collections against actual payments.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        // Responsive Filter Bar
        _buildFilterCard(
          onDateQuickSelect: (from, to) => setState(() {
            _collectionsFromDate = from;
            _globalToDate = to;
          }),
          child: Builder(
            builder: (context) {
              final isMobile = MediaQuery.of(context).size.width < 750;
              if (isMobile) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker('Date From', _collectionsFromDate, (d) => setState(() => _collectionsFromDate = d))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildDatePicker('Date To', _globalToDate, (d) => setState(() => _globalToDate = d))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            'Branch',
                            _selectedCpBranch,
                            bOptions,
                            (v) => setState(() => _selectedCpBranch = v),
                            enabled: isAdmin,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDropdown(
                            'Officer',
                            _selectedCpOfficer,
                            oOptions,
                            (v) => setState(() => _selectedCpOfficer = v),
                            enabled: !isOfficer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            'Compliance',
                            _selectedCpStatus,
                            ['ALL', 'PAID', 'PART_PAYMENT', 'NOT_PAID'],
                            (v) => setState(() => _selectedCpStatus = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSearchField('Search Client / Group', _cpSearchCtrl, () => setState(() {})),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: _buildDatePicker('Date From', _collectionsFromDate, (d) => setState(() => _collectionsFromDate = d))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _buildDatePicker('Date To', _globalToDate, (d) => setState(() => _globalToDate = d))),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Branch',
                      _selectedCpBranch,
                      bOptions,
                      (v) => setState(() => _selectedCpBranch = v),
                      enabled: isAdmin,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Officer',
                      _selectedCpOfficer,
                      oOptions,
                      (v) => setState(() => _selectedCpOfficer = v),
                      enabled: !isOfficer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdown(
                      'Compliance',
                      _selectedCpStatus,
                      ['ALL', 'PAID', 'PART_PAYMENT', 'NOT_PAID'],
                      (v) => setState(() => _selectedCpStatus = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildSearchField('Search Client / Group', _cpSearchCtrl, () => setState(() {})),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        FutureBuilder<CollectionPerformanceResponseModel>(
          future: ref.read(auditApiServiceProvider).getCollectionPerformance(
            dateFrom: _formatDate(_collectionsFromDate),
            dateTo: _formatDate(_globalToDate),
            branchId: _resolveTargetBranchId(_selectedCpBranch, branchId),
            officerId: _resolveTargetOfficerId(_selectedCpOfficer),
            complianceStatus: _selectedCpStatus,
            search: _cpSearchCtrl.text.trim(),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFFDC2626)));
            }

            final data = snapshot.data!;
            final m = data.metrics;
            final records = data.records;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKpiRow5([
                  _KpiItem('Expected Collections', _formatCurrency(m.expectedCollections)),
                  _KpiItem('Actual Collections', _formatCurrency(m.actualCollections)),
                  _KpiItem(
                    'Collection Variance',
                    _formatCurrency(m.collectionVariance),
                    delta: m.collectionVariance > 0 ? '-${_formatCurrency(m.collectionVariance)}' : '₦0.00',
                    isDeltaInverse: true,
                  ),
                  _KpiItem('Meeting Compliance', '${m.meetingComplianceRatio.toStringAsFixed(1)}%'),
                  _KpiItem('Meetings Audited', '${m.meetingsAudited} (${m.paidCount} Paid)'),
                ]),
                const SizedBox(height: 16),

                if (records.isEmpty)
                  _buildEmptyState('No collection performance records found for the selected filters.')
                else ...[
                  _buildDynamicDataTable(records, [
                    'Meeting Date', 'Client Code', 'Client Name', 'Group', 'Expected', 'Paid', 'Compliance %', 'Officer', 'Branch', 'Status'
                  ]),
                  const SizedBox(height: 14),
                  _buildInspectorSection(
                    title: 'View Meeting Collection Details',
                    records: records,
                    selectedIndex: _selectedCpInspectIdx,
                    onIndexChanged: (idx) => setState(() => _selectedCpInspectIdx = idx),
                    labelBuilder: (r) => '${r['Meeting Date']} — ${r['Client Name']} (Paid: ${r['Paid']} / Exp: ${r['Expected']})',
                    detailsBuilder: (sel) => [
                      _DetailItem('Meeting Date', sel['Meeting Date']),
                      _DetailItem('Client Code', sel['Client Code']),
                      _DetailItem('Client Name', sel['Client Name']),
                      _DetailItem('Group', sel['Group']),
                      _DetailItem('Expected Amount', sel['Expected']),
                      _DetailItem('Actual Paid', sel['Paid']),
                      _DetailItem('Compliance', sel['Compliance %']),
                      _DetailItem('Officer', sel['Officer']),
                      _DetailItem('Status', sel['Status']),
                    ],
                    showRawTech: _showRawCpTech,
                    onToggleRawTech: (v) => setState(() => _showRawCpTech = v),
                  ),
                  const SizedBox(height: 14),
                  _buildExportButton('Export Collection Performance CSV', () => _exportCsvFromRecords(records, 'collection_performance')),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 7: 15 EXCEPTION REPORTS
  // =========================================================================
  Widget _buildTab7Exceptions(String branchId) {
    return FutureBuilder<ExceptionReportsResponseModel>(
      future: ref.read(auditApiServiceProvider).getExceptionReports(branchId: branchId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFFDC2626)));
        }

        final data = snapshot.data!;
        final details = data.details;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('15 Automated Audit Exception Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Scans core database for compliance breaches, unposted transactions, or projection anomalies.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 16),

            Builder(
              builder: (context) {
                final isMobile = MediaQuery.of(context).size.width < 750;
                return _buildKpiCard(
                  'Total Exceptions Detected',
                  data.totalExceptions.toString(),
                  delta: '${data.exceptionRulesEvaluated} Rules Evaluated',
                  width: isMobile ? double.infinity : 280,
                );
              },
            ),
            const SizedBox(height: 20),

            ...details.entries.map((entry) {
              final ruleName = entry.key.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
              final issues = entry.value;
              final count = issues.length;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: count > 0 ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: count > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      count > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      color: count > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      size: 18,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ruleName,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: count > 0 ? const Color(0xFF991B1B) : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: count > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count issues',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: count > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: count == 0
                          ? const Row(
                              children: [
                                Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 16),
                                SizedBox(width: 8),
                                Text('Zero exceptions detected for this rule.', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            )
                          : _buildDynamicDataTable(issues, issues.first.keys.toList()),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // =========================================================================
  // TAB 8: 360° UNIVERSAL EXPLORER & TIMELINE
  // =========================================================================
  Widget _buildTab8Explorer(String branchId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('360° Universal Search & Audit Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text('Search across all sub-systems by Client Code, Customer Name, Officer, Loan Number, or Reference ID.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        // Search Box Container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (context) {
                  final isMobile = MediaQuery.of(context).size.width < 750;
                  if (isMobile) {
                    return Column(
                      children: [
                        TextField(
                          controller: _explorerSearchCtrl,
                          decoration: InputDecoration(
                            labelText: 'Enter Search Term',
                            hintText: 'e.g. OGI-12-005, Adewale, Ayomide, REF-00382',
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: _explorerSearchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _explorerSearchCtrl.clear();
                                      setState(() => _explorerResult = null);
                                    },
                                  )
                                : null,
                          ),
                          onSubmitted: (_) => _handleExplorerSearch(branchId),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: _explorerLoading ? null : () => _handleExplorerSearch(branchId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E86C1),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _explorerLoading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.search, size: 18, color: Colors.white),
                            label: const Text('Search Across Sub-Systems', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _explorerSearchCtrl,
                          decoration: InputDecoration(
                            labelText: 'Enter Search Term',
                            hintText: 'e.g. OGI-12-005, Adewale, Ayomide, REF-00382',
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: _explorerSearchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _explorerSearchCtrl.clear();
                                      setState(() => _explorerResult = null);
                                    },
                                  )
                                : null,
                          ),
                          onSubmitted: (_) => _handleExplorerSearch(branchId),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _explorerLoading ? null : () => _handleExplorerSearch(branchId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E86C1),
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: _explorerLoading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.search, size: 18, color: Colors.white),
                          label: const Text('Search', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              // Search Suggestions Row
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Suggestions:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                  _buildSearchSuggestionChip('OGI-', branchId),
                  _buildSearchSuggestionChip('LN-', branchId),
                  _buildSearchSuggestionChip('REF-', branchId),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (_explorerLoading)
          const IcareTableSkeleton(rowCount: 6, hasFilterBar: false)
        else if (_explorerResult != null)
          _buildExplorerResultsSection(branchId)
        else
          _buildEmptyState('Enter a search term above to inspect matching records across all sub-systems.'),
      ],
    );
  }

  Future<void> _handleExplorerSearch(String branchId) async {
    final term = _explorerSearchCtrl.text.trim();
    if (term.isEmpty) return;

    setState(() => _explorerLoading = true);
    try {
      final res = await ref.read(auditApiServiceProvider).searchUniversalExplorer(
        query: term,
        branchId: branchId,
      );
      if (mounted) {
        setState(() {
          _explorerResult = res;
          _explorerLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _explorerLoading = false);
    }
  }

  Widget _buildSearchSuggestionChip(String tag, String branchId) {
    return InkWell(
      onTap: () {
        _explorerSearchCtrl.text = tag;
        _handleExplorerSearch(branchId);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          tag,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2E86C1),
            fontFamily: 'JetBrains Mono',
          ),
        ),
      ),
    );
  }

  Widget _buildExplorerResultsSection(String branchId) {
    final res = _explorerResult!;
    if (!res.found) {
      return _buildEmptyState("No records found for '${res.query}'. Try changing the search criteria.");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFA7F3D0))),
          child: Text("Audit records matched '${res.query}' across sub-systems", style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
        ),
        const SizedBox(height: 16),

        if (res.loans.isNotEmpty) ...[
          const Text('Loans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          _buildDynamicDataTable(res.loans, ['Disbursement Date', 'Loan Number', 'Client Code', 'Client Name', 'Product', 'Officer', 'Branch', 'Principal', 'Status']),
          const SizedBox(height: 8),
          // Expandable Loan Lifecycle Timelines
          _buildLoanTimelineExpander(res.loans),
          const SizedBox(height: 20),
        ],

        if (res.repayments.isNotEmpty) ...[
          const Text('Repayments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          _buildDynamicDataTable(res.repayments, ['Repayment Date', 'Loan Number', 'Client Code', 'Client Name', 'Product', 'Amount Paid', 'Officer', 'Branch', 'Transaction Type', 'Status']),
          const SizedBox(height: 20),
        ],

        if (res.savings.isNotEmpty) ...[
          const Text('Savings Ledger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          _buildDynamicDataTable(res.savings, ['Date', 'Client Code', 'Client Name', 'Ledger', 'Deposit', 'Withdrawal', 'Available Balance', 'Officer', 'Branch', 'Remarks', 'Status']),
          const SizedBox(height: 20),
        ],

        if (res.fees.isNotEmpty) ...[
          const Text('Fee Ledger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          _buildDynamicDataTable(res.fees, ['Date', 'Client Code', 'Client Name', 'Fee Type', 'Amount', 'Officer', 'Branch', 'Reference', 'Status']),
          const SizedBox(height: 20),
        ],

        if (res.treasuryTransactions.isNotEmpty) ...[
          const Text('Treasury Ledger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          _buildDynamicDataTable(res.treasuryTransactions, ['Date', 'Category', 'Amount', 'Officer', 'Branch', 'Reference', 'Narration', 'Status']),
          const SizedBox(height: 20),
        ],

        if (res.ledgerTransactions.isNotEmpty) ...[
          const Text('General Ledger Journals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          _buildDynamicDataTable(res.ledgerTransactions, ['Posting Date', 'Journal Ref', 'Narration', 'Debit Account', 'Credit Account', 'Amount', 'Branch', 'Officer', 'Status']),
          const SizedBox(height: 8),
          _buildJournalLegsExpander(res.ledgerTransactions),
          const SizedBox(height: 20),
        ],

        if (res.auditLogs.isNotEmpty) ...[
          const Text('Audit Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          _buildDynamicDataTable(res.auditLogs, res.auditLogs.first.keys.toList()),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildLoanTimelineExpander(List<Map<String, dynamic>> loans) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: ExpansionTile(
        title: const Text('View Loan Lifecycle Audit Timelines', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        children: loans.take(5).map((l) {
          final raw = l['_raw_record'] as Map<String, dynamic>? ?? {};
          final lid = (raw['loan_id'] ?? raw['id'] ?? '').toString();
          final lNumber = l['Loan Number'] ?? 'Loan';
          final cName = l['Client Name'] ?? '';
          final princ = l['Principal'] ?? '';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Timeline for $lNumber — $cName ($princ)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    TextButton.icon(
                      icon: const Icon(Icons.timeline, size: 16),
                      label: const Text('Load Timeline', style: TextStyle(fontSize: 12)),
                      onPressed: () => _fetchLoanTimeline(lid),
                    ),
                  ],
                ),
                if (_expandedTimelineLoanId == lid) ...[
                  if (_loadingTimeline)
                    const Padding(padding: EdgeInsets.all(12), child: IcareTableSkeleton(rowCount: 3, hasFilterBar: false))
                  else if (_loanTimelineData != null && _loanTimelineData!.isNotEmpty)
                    _buildDynamicDataTable(_loanTimelineData!, _loanTimelineData!.first.keys.toList())
                  else
                    const Text('No timeline events recorded.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
                const Divider(),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _fetchLoanTimeline(String loanId) async {
    setState(() {
      _expandedTimelineLoanId = loanId;
      _loadingTimeline = true;
    });
    try {
      final res = await ref.read(auditApiServiceProvider).getLoanTimeline(loanId: loanId);
      if (mounted) {
        setState(() {
          _loanTimelineData = res.timeline;
          _loadingTimeline = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTimeline = false);
    }
  }

  Widget _buildJournalLegsExpander(List<Map<String, dynamic>> journals) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: ExpansionTile(
        title: const Text('Inspect Journal Double-Entry Legs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        children: journals.map((j) {
          final entries = (j['_entries'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
          if (entries.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Journal: ${j['Journal Ref']} — ${j['Narration']} (${j['Amount']})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                _buildDynamicDataTable(entries, ['Journal Ref', 'Account', 'Leg', 'Debit (₦)', 'Credit (₦)', 'Line Narration']),
                const Divider(),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // =========================================================================
  // TAB 9: PERFORMANCE INSIGHTS
  // =========================================================================
  Widget _buildTab9Insights(String branchId) {
    return FutureBuilder<RiskDistributionResponseModel>(
      future: ref.read(auditApiServiceProvider).getPerformanceInsights(branchId: branchId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false);
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFFDC2626)));
        }

        final dist = snapshot.data!.distribution;
        final total = dist['total_clients'] ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Executive Performance Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('System Performance & Portfolio Quality Insights based on loan repayment history and risk scores.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 16),

            _buildKpiRow5([
              _KpiItem('Total Borrowers Audited', total.toString()),
              _KpiItem('Excellent Tier', (dist['EXCELLENT'] ?? 0).toString()),
              _KpiItem('Good Tier', (dist['GOOD'] ?? 0).toString()),
              _KpiItem('Fair Tier', (dist['FAIR'] ?? 0).toString()),
              _KpiItem('High Risk Tier', (dist['HIGH_RISK'] ?? 0).toString(), isDeltaInverse: true),
            ]),
          ],
        );
      },
    );
  }

  // =========================================================================
  // TAB 10: RECONCILIATION WIZARD
  // =========================================================================
  Widget _buildTab10Wizard(String branchId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Guided Reconciliation Wizard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text('Interactive wizard to verify balance, locate discrepancies, and trigger automated projection repair.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 16),

        if (_wizardBanner != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFA7F3D0))),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_wizardBanner!, style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w600, fontSize: 13.5))),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        Builder(
          builder: (context) {
            final isMobile = MediaQuery.of(context).size.width < 750;
            if (isMobile) {
              return Column(
                children: [
                  _buildDatePicker('Select Reconciliation Date:', _rwDate, (d) => setState(() => _rwDate = d)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _repairing ? null : () => _handleExecuteRepair(branchId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4B4B),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: _repairing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.auto_fix_high, size: 18, color: Colors.white),
                      label: const Text('Start Guided Projection Repair', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _buildDatePicker('Select Reconciliation Date:', _rwDate, (d) => setState(() => _rwDate = d)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _repairing ? null : () => _handleExecuteRepair(branchId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4B4B),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: _repairing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.auto_fix_high, size: 18, color: Colors.white),
                      label: const Text('Start Guided Projection Repair', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        if (_repairResult != null) ...[
          const Text('Verification Results After Repair', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          _buildRepairVerificationSection(_repairResult!.verificationAfterRepair),
        ],
      ],
    );
  }

  Future<void> _handleExecuteRepair(String branchId) async {
    setState(() => _repairing = true);
    try {
      final res = await ref.read(auditApiServiceProvider).executeReconciliationRepair(
        branchId: branchId,
        reconciliationDate: _formatDate(_rwDate),
      );
      if (mounted) {
        setState(() {
          _repairResult = res;
          _wizardBanner = 'Reconciliation repair complete. Rebuilt ${res.rebuiltOfficerCount} officer cashbooks & Master Cashbook.';
          _repairing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _wizardBanner = 'Repair error: $e';
          _repairing = false;
        });
      }
    }
  }

  Widget _buildRepairVerificationSection(Integrity6WayModel verif) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(verif.isBalanced ? Icons.check_circle : Icons.error_outline, color: verif.isBalanced ? const Color(0xFF16A34A) : const Color(0xFFDC2626), size: 20),
              const SizedBox(width: 10),
              Text(verif.statusText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: verif.isBalanced ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildKpiCard('General Ledger', _formatCurrency(verif.ledgerTotal), width: 180),
              _buildKpiCard('Audit Views', _formatCurrency(verif.auditViewsTotal), width: 180),
              _buildKpiCard('CO Cashbooks', _formatCurrency(verif.coCashbooksTotal), width: 180),
              _buildKpiCard('Master Cashbook', _formatCurrency(verif.masterCashbookTotal), width: 180),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SHARED UI HELPERS & WIDGET BUILDERS
  // =========================================================================

  List<String> _getBranchOptions(bool isAdmin) {
    final authState = ref.read(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;

    if (!isAdmin) {
      final userBranch = user?.branch;
      if (userBranch != null && userBranch.isNotEmpty) {
        return [userBranch];
      }
      if (_meta != null && _meta!.branches.isNotEmpty) {
        return [_meta!.branches.first.name];
      }
      return ['Ogijo'];
    }

    if (_meta == null) return ['All Branches'];
    final bNames = _meta!.branches.map((b) => b.name).toList();
    return ['All Branches'] + bNames;
  }

  List<String> _getOfficerOptions() {
    if (_meta == null) return ['All Officers'];
    return ['All Officers'] + _meta!.officers.map((o) => o.displayName).toList();
  }

  String? _resolveTargetBranchId(String selectedName, String fallbackId) {
    if (selectedName == 'All Branches' || selectedName.isEmpty) return null;
    if (_meta != null) {
      for (final b in _meta!.branches) {
        if (b.name == selectedName) return b.branchId;
      }
    }
    return fallbackId.isNotEmpty ? fallbackId : null;
  }

  String? _resolveTargetOfficerId(String selectedDisplay) {
    if (selectedDisplay == 'All Officers' || selectedDisplay.isEmpty) return null;
    if (_meta != null) {
      for (final o in _meta!.officers) {
        if (o.displayName == selectedDisplay || o.username == selectedDisplay) return o.id;
      }
    }
    return null;
  }

  String? _resolveTargetProductId(String selectedName) {
    if (selectedName == 'All Products' || selectedName.isEmpty) return null;
    if (_meta != null) {
      for (final p in _meta!.products) {
        if (p.name == selectedName) return p.productId;
      }
    }
    return null;
  }

  Widget _buildDateQuickPresets(Function(DateTime from, DateTime to) onDateQuickSelect) {
    final now = DateTime.now();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDatePresetChip('This Month', () {
            onDateQuickSelect(DateTime(now.year, now.month, 1), now);
          }),
          const SizedBox(width: 6),
          _buildDatePresetChip('Last 30 Days', () {
            onDateQuickSelect(now.subtract(const Duration(days: 30)), now);
          }),
          const SizedBox(width: 6),
          _buildDatePresetChip('Today', () {
            onDateQuickSelect(DateTime(now.year, now.month, now.day), now);
          }),
        ],
      ),
    );
  }

  Widget _buildDatePresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flash_on, size: 10, color: Color(0xFF2E86C1)),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard({
    required Widget child,
    required Function(DateTime, DateTime) onDateQuickSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune, size: 15, color: Color(0xFF2E86C1)),
                  SizedBox(width: 6),
                  Text(
                    'Audit Filters',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              _buildDateQuickPresets(onDateQuickSelect),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime value, Function(DateTime) onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2024),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        child: Text(DateFormat('yyyy-MM-dd').format(value), style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String) onChanged, {bool enabled = true}) {
    final validValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : null);
    return DropdownButtonFormField<String>(
      value: validValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        enabled: enabled,
      ),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
      onChanged: enabled ? (v) => v != null ? onChanged(v) : null : null,
    );
  }

  Widget _buildSearchField(String hint, TextEditingController ctrl, VoidCallback onSubmitted) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: 'Search',
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 15, color: Color(0xFF64748B)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        suffixIcon: ctrl.text.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear, size: 14), onPressed: () { ctrl.clear(); onSubmitted(); })
            : null,
      ),
      style: const TextStyle(fontSize: 12),
      onSubmitted: (_) => onSubmitted(),
    );
  }

  Widget _buildKpiRow5(List<_KpiItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;
        final isMedium = constraints.maxWidth > 550;
        final cardW = isWide
            ? (constraints.maxWidth - 40) / 5
            : (isMedium ? (constraints.maxWidth - 10) / 3 : (constraints.maxWidth - 10) / 2);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((i) => _buildKpiCard(i.label, i.value, delta: i.delta, isDeltaInverse: i.isDeltaInverse, width: cardW)).toList(),
        );
      },
    );
  }

  Widget _buildKpiRow4(List<_KpiItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 750;
        final isMedium = constraints.maxWidth > 500;
        final cardW = isWide
            ? (constraints.maxWidth - 36) / 4
            : (isMedium ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((i) => _buildKpiCard(i.label, i.value, delta: i.delta, isDeltaInverse: i.isDeltaInverse, width: cardW)).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(String label, String value, {String? delta, bool isDeltaInverse = false, required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isDeltaInverse ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 11,
                  color: isDeltaInverse ? const Color(0xFFDC2626) : const Color(0xFF059669),
                ),
                const SizedBox(width: 2),
                Text(
                  delta,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isDeltaInverse ? const Color(0xFFDC2626) : const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDynamicDataTable(
    List<Map<String, dynamic>> records,
    List<String> columns, {
    String? title,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 750;
    final showCards = _useCardView ?? isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls Header Bar (Record count & View Mode Toggle)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${records.length} records',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  if (title != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ],
              ),
              // Segmented Toggle: Cards vs Table
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _useCardView = true),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: showCards ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: showCards
                              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.view_agenda_outlined,
                              size: 13,
                              color: showCards ? const Color(0xFF2E86C1) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Cards',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: showCards ? FontWeight.w700 : FontWeight.w500,
                                color: showCards ? const Color(0xFF2E86C1) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _useCardView = false),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: !showCards ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: !showCards
                              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.table_chart_outlined,
                              size: 13,
                              color: !showCards ? const Color(0xFF2E86C1) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Table',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: !showCards ? FontWeight.w700 : FontWeight.w500,
                                color: !showCards ? const Color(0xFF2E86C1) : const Color(0xFF64748B),
                              ),
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
        ),

        // Body: Card list OR Horizontal Data Table
        if (showCards)
          _buildRecordCardList(records, columns)
        else
          _buildTableView(records, columns),
      ],
    );
  }

  Widget _buildRecordCardList(List<Map<String, dynamic>> records, List<String> columns) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9).withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        border: const Border(
          left: BorderSide(color: Color(0xFFE2E8F0)),
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: records.asMap().entries.map((entry) {
          final idx = entry.key;
          final r = entry.value;
          return _buildSingleRecordCard(r, columns, idx);
        }).toList(),
      ),
    );
  }

  Widget _buildSingleRecordCard(Map<String, dynamic> r, List<String> columns, int idx) {
    final title = (r['Client Name'] ?? r['Category'] ?? r['Narration'] ?? r['Journal Ref'] ?? r['Loan Number'] ?? r['Source'] ?? '').toString();
    final displayTitle = title.isNotEmpty ? title : 'Record #${idx + 1}';
    final code = (r['Client Code'] ?? r['Loan Number'] ?? r['Reference'] ?? r['Journal Ref'] ?? '').toString();
    final date = (r['Date'] ?? r['Disbursement Date'] ?? r['Repayment Date'] ?? r['Meeting Date'] ?? r['Posting Date'] ?? '').toString();
    final amount = (r['Amount'] ?? r['Amount Paid'] ?? r['Principal'] ?? r['Deposit'] ?? r['Paid'] ?? r['Variance (₦)'] ?? '').toString();
    final withdrawal = r['Withdrawal']?.toString();
    final availBalance = (r['Available Balance'] ?? r['Balance'])?.toString();
    final status = (r['Status'] ?? r['Compliance %'])?.toString() ?? '';
    final officer = r['Officer']?.toString();
    final branch = r['Branch']?.toString();
    final typeTag = (r['Product'] ?? r['Fee Type'] ?? r['Ledger'] ?? r['Group'] ?? r['Transaction Type'])?.toString();

    final excludedKeys = {
      'Client Name', 'Category', 'Narration', 'Journal Ref', 'Loan Number',
      'Source', 'Client Code', 'Reference', 'Date', 'Disbursement Date',
      'Repayment Date', 'Meeting Date', 'Posting Date', 'Amount', 'Amount Paid',
      'Principal', 'Deposit', 'Paid', 'Variance (₦)', 'Withdrawal', 'Available Balance',
      'Balance', 'Status', 'Compliance %', 'Officer', 'Branch', 'Product',
      'Fee Type', 'Ledger', 'Group', 'Transaction Type', '_raw_record', '_entries'
    };

    final extraDetails = r.entries
        .where((e) => !excludedKeys.contains(e.key) && !e.key.startsWith('_') && !e.key.endsWith('_Raw') && e.value != null && e.value.toString().isNotEmpty)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title + Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (code.isNotEmpty && code != displayTitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          code,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            fontFamily: 'JetBrains Mono',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (status.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildCellWidget('Status', status),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Financial Metrics Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (amount.isNotEmpty && amount != '-' && amount != '₦0.00') ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                      Text(
                        amount,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ],
                  ),
                ],
                if (withdrawal != null && withdrawal.isNotEmpty && withdrawal != '-' && withdrawal != '₦0.00') ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Withdrawal',
                        style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                      Text(
                        withdrawal,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ],
                  ),
                ],
                if (availBalance != null && availBalance.isNotEmpty && availBalance != '-') ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Available Bal',
                        style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                      Text(
                        availBalance,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),

            // Metadata Chips (Date, Officer, Branch, Type)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (date.isNotEmpty)
                  _buildCardChip(Icons.calendar_today_outlined, date),
                if (typeTag != null && typeTag.isNotEmpty)
                  _buildCardChip(Icons.category_outlined, typeTag, color: const Color(0xFF6366F1)),
                if (officer != null && officer.isNotEmpty && officer != '-')
                  _buildCardChip(Icons.person_outline, officer),
                if (branch != null && branch.isNotEmpty && branch != '-')
                  _buildCardChip(Icons.location_on_outlined, branch),
              ],
            ),

            if (extraDetails.isNotEmpty) ...[
              const SizedBox(height: 4),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 4),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: const Text(
                    'More details',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2E86C1)),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: extraDetails.map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    e.key,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    e.value.toString(),
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF1E293B)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardChip(IconData icon, String label, {Color color = const Color(0xFF64748B)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableView(List<Map<String, dynamic>> records, List<String> columns) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
        border: Border(
          left: BorderSide(color: Color(0xFFE2E8F0)),
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12, top: 8, bottom: 4),
            child: Row(
              children: [
                Icon(Icons.swipe, size: 14, color: Color(0xFF94A3B8)),
                SizedBox(width: 6),
                Text('Scroll horizontally for complete table', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18.0,
              horizontalMargin: 12.0,
              headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
              columns: columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)))).toList(),
              rows: records.map((r) {
                return DataRow(
                  cells: columns.map((col) {
                    final val = r[col]?.toString() ?? '-';
                    return DataCell(_buildCellWidget(col, val));
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCellWidget(String col, String val) {
    if (col == 'Status') {
      Color bg = const Color(0xFFF1F5F9);
      Color txt = const Color(0xFF475569);
      final cleanVal = val.replaceAll(RegExp(r'[^\w\s]'), '').trim().toUpperCase();

      if (cleanVal.contains('PAID') || cleanVal.contains('APPROVED') || cleanVal.contains('BALANCED') || cleanVal.contains('DISBURSED') || cleanVal.contains('COMPLETED') || cleanVal.contains('ACTIVE')) {
        bg = const Color(0xFFDCFCE7);
        txt = const Color(0xFF15803D);
      } else if (cleanVal.contains('PART') || cleanVal.contains('PENDING')) {
        bg = const Color(0xFFFEF3C7);
        txt = const Color(0xFFB45309);
      } else if (cleanVal.contains('NOT') || cleanVal.contains('OVERDUE') || cleanVal.contains('REJECTED') || cleanVal.contains('UNBALANCED') || cleanVal.contains('MISMATCH')) {
        bg = const Color(0xFFFEE2E2);
        txt = const Color(0xFFB91C1C);
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(cleanVal, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: txt)),
      );
    }
    if (col == 'Remarks' || col == 'Narration' || col == 'Note / Type' || col == 'Cause' || col == 'Description') {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Tooltip(
          message: val,
          child: Text(
            val,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      );
    }
    return Text(val, style: const TextStyle(fontSize: 11));
  }

  Widget _buildInspectorSection({
    required String title,
    required List<Map<String, dynamic>> records,
    required int selectedIndex,
    required Function(int) onIndexChanged,
    required String Function(Map<String, dynamic>) labelBuilder,
    required List<_DetailItem> Function(Map<String, dynamic>) detailsBuilder,
    required bool showRawTech,
    required Function(bool) onToggleRawTech,
  }) {
    final validIdx = (selectedIndex >= 0 && selectedIndex < records.length) ? selectedIndex : 0;
    final sel = records[validIdx];
    final details = detailsBuilder(sel);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.fact_check_outlined, size: 20, color: Color(0xFF2E86C1)),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  value: validIdx,
                  decoration: InputDecoration(
                    labelText: 'Select Transaction to Inspect:',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: List.generate(records.length, (i) {
                    return DropdownMenuItem<int>(
                      value: i,
                      child: Text(labelBuilder(records[i]), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    );
                  }),
                  onChanged: (val) { if (val != null) onIndexChanged(val); },
                ),
                const SizedBox(height: 16),
                const Text('Transaction Details', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: details.map((d) {
                    return Container(
                      width: 180,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(
                            d.value,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Checkbox(value: showRawTech, onChanged: (v) => onToggleRawTech(v ?? false)),
                    const Text('Show Advanced Technical Details (JSON)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
                if (showRawTech) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        InkWell(
                          onTap: () {
                            final text = const JsonEncoder.withIndent('  ').convert(sel['_raw_record'] ?? sel);
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Raw JSON copied to clipboard'), duration: Duration(seconds: 2)),
                            );
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy, size: 12, color: Color(0xFF94A3B8)),
                              SizedBox(width: 4),
                              Text('Copy', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            const JsonEncoder.withIndent('  ').convert(sel['_raw_record'] ?? sel),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF38BDF8)),
                          ),
                        ),
                      ],
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

  Widget _buildExportButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: Colors.white,
        ),
        icon: const Icon(Icons.download, size: 16, color: Color(0xFF334155)),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF1E40AF), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiItem {
  final String label;
  final String value;
  final String? delta;
  final bool isDeltaInverse;
  _KpiItem(this.label, this.value, {this.delta, this.isDeltaInverse = false});
}

class _DetailItem {
  final String label;
  final String value;
  _DetailItem(this.label, this.value);
}
