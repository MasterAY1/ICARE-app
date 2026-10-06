import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_database_service.dart';
import '../data/datasources/bm_api_service.dart';
import '../data/models/bm_dashboard_models.dart';
import '../../shared/presentation/co_app_scaffold.dart';

final bmDashboardDataProvider = FutureProvider.autoDispose<BmDashboardDataModel>((ref) async {
  final api = ref.watch(bmApiServiceProvider);
  final isOnline = ref.watch(isOnlineProvider);
  final dbService = ref.watch(offlineDatabaseServiceProvider);

  if (!isOnline) {
    final cached = await dbService.getCachedDashboardData(role: 'bm');
    if (cached != null) {
      return BmDashboardDataModel.fromJson(cached);
    }
  }

  try {
    final raw = await api.getBmDashboardDataRaw();
    dbService.cacheDashboardData(raw, role: 'bm').ignore();
    return BmDashboardDataModel.fromJson(raw);
  } catch (err) {
    final cached = await dbService.getCachedDashboardData(role: 'bm');
    if (cached != null) {
      return BmDashboardDataModel.fromJson(cached);
    }
    rethrow;
  }
});

class BmDashboardScreen extends ConsumerStatefulWidget {
  const BmDashboardScreen({super.key});

  @override
  ConsumerState<BmDashboardScreen> createState() => _BmDashboardScreenState();
}

class _BmDashboardScreenState extends ConsumerState<BmDashboardScreen> {
  String? _flashMessage;
  bool _isProcessing = false;

  // Approvals Hub Tab State
  String _activeApprovalTab = 'Withdrawals';

  // Mobile Dashboard Navigation ('Approvals', 'Overview', 'Officers', 'All')
  String _mobileSectionTab = 'Approvals';
  String? _expandedOfficer;

  // Approvals Pagination
  int _loanPage = 1;
  int _wrPage = 1;
  int _corrPage = 1;
  static const int _approvalPageSize = 5;
  int _getPageSize(bool isMobile) => isMobile ? 3 : _approvalPageSize;

  // Filters for Loan Disbursements
  String _loanOfficerFilter = 'All Officers';
  String _loanProductFilter = 'All Products';
  final _loanSearchCtrl = TextEditingController();
  DateTime _batchLoanDate = DateTime.now();
  final Set<String> _selectedLoanIds = {};
  final Map<String, DateTime> _loanDatesMap = {};

  // Filters for Withdrawals
  String _wrOfficerFilter = 'All Officers';
  String _wrTypeFilter = 'All Types';
  final _wrSearchCtrl = TextEditingController();
  DateTime _batchWrDate = DateTime.now();
  final Set<String> _selectedWrIds = {};
  final Map<String, DateTime> _wrDatesMap = {};

  // Filters for Error Corrections
  String _corrOfficerFilter = 'All Officers';
  String _corrTypeFilter = 'All Types';
  final _corrSearchCtrl = TextEditingController();
  final Set<String> _selectedCorrIds = {};

  @override
  void dispose() {
    _loanSearchCtrl.dispose();
    _wrSearchCtrl.dispose();
    _corrSearchCtrl.dispose();
    super.dispose();
  }

  void _showFlash(String msg) {
    setState(() {
      _flashMessage = msg;
    });
  }

  void _clearFlash() {
    setState(() {
      _flashMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(bmDashboardDataProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return dashboardAsync.when(
      loading: () => const IcareDashboardSkeleton(),
      error: (err, stack) {
        final isConnectionError = !isOnline ||
            (err is DioException &&
                (err.type == DioExceptionType.connectionError ||
                    err.type == DioExceptionType.connectionTimeout ||
                    err.type == DioExceptionType.sendTimeout ||
                    err.type == DioExceptionType.receiveTimeout ||
                    err.type == DioExceptionType.unknown));

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isConnectionError ? const Color(0xFFFCD34D) : const Color(0xFFFCA5A5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConnectionError ? Icons.cloud_off : Icons.error_outline,
                  color: isConnectionError ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  isConnectionError
                      ? 'Offline Mode — No Local Cache Available'
                      : 'Failed to Load Branch Manager Dashboard',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isConnectionError ? const Color(0xFF92400E) : const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isConnectionError
                      ? 'You are currently working offline, but no cached BM dashboard was found on this device. Please connect to the internet once to load current branch operations.'
                      : err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(bmDashboardDataProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnectionError ? const Color(0xFFD97706) : const Color(0xFF064E3B),
                  ),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
      data: (data) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        return Column(
          children: [
            if (!isOnline)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_off, size: 16, color: Color(0xFF92400E)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Offline Mode Active — Displaying locally cached branch overview and approvals queue. New financial authorizations require an active server connection.',
                        style: TextStyle(color: Color(0xFF92400E), fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            _buildDashboardContent(data, isMobile),
          ],
        );
      },
    );
  }

  Widget _buildDashboardContent(BmDashboardDataModel data, bool isMobile) {
    final hasLoans = data.pendingLoans.isNotEmpty;
    final hasWrs = data.pendingWithdrawals.isNotEmpty;
    final hasCorrs = data.pendingCorrections.isNotEmpty;
    final hasApprovals = hasLoans || hasWrs || hasCorrs;

    // Auto-select valid tab if current active tab has 0 items
    if (hasApprovals) {
      if (_activeApprovalTab == 'Loan Disbursements' && !hasLoans) {
        if (hasWrs) {
          _activeApprovalTab = 'Withdrawals';
        } else if (hasCorrs) {
          _activeApprovalTab = 'Error Corrections';
        }
      } else if (_activeApprovalTab == 'Withdrawals' && !hasWrs) {
        if (hasLoans) {
          _activeApprovalTab = 'Loan Disbursements';
        } else if (hasCorrs) {
          _activeApprovalTab = 'Error Corrections';
        }
      } else if (_activeApprovalTab == 'Error Corrections' && !hasCorrs) {
        if (hasLoans) {
          _activeApprovalTab = 'Loan Disbursements';
        } else if (hasWrs) {
          _activeApprovalTab = 'Withdrawals';
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // 1. Header: Title & Audit Center
          if (isMobile)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Performance & Risk',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF334155)),
                  tooltip: 'Refresh Dashboard',
                  onPressed: () => ref.refresh(bmDashboardDataProvider),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(activeCoPageProvider.notifier).state = 'Audit Ledger';
                  },
                  icon: const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF334155)),
                  label: const Text('Audit', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Performance & Risk Dashboard',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF334155)),
                      tooltip: 'Refresh Dashboard',
                      onPressed: () => ref.refresh(bmDashboardDataProvider),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.read(activeCoPageProvider.notifier).state = 'Audit Ledger';
                      },
                      icon: const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF334155)),
                      label: const Text('Audit Center', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 8),

          // Subtitle & Caption (app.py L2561-2562)
          Text(
            'Branch Manager Dashboard — ${data.branchName} Branch',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Branch Daily Operations, Officer Status, & Approvals',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Flash Message Banner
          if (_flashMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _flashMessage!,
                      style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Color(0xFF059669)),
                    onPressed: _clearFlash,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Branch Closure Banner
          if (data.isClosed) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Branch Closed / Holiday (${data.closureReason}): All field collections and group meetings are suspended for ${data.branchName} Branch today.',
                      style: const TextStyle(color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Section Rendering: Mobile Tabs vs Desktop Full View
          if (isMobile) ...[
            _buildMobileSectionSwitcher(
              totalApprovals: (data.pendingLoans.length + data.pendingWithdrawals.length + data.pendingCorrections.length),
              totalOfficers: data.officerCollectionStatus.length,
              hasApprovals: hasApprovals,
            ),
            if ((_mobileSectionTab == 'Approvals' || _mobileSectionTab == 'All') && hasApprovals) ...[
              _buildApprovalsHub(data, hasLoans, hasWrs, hasCorrs, isMobile),
              const SizedBox(height: 16),
            ] else if (_mobileSectionTab == 'Approvals' && !hasApprovals) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 36, color: Color(0xFF10B981)),
                    SizedBox(height: 8),
                    Text('No Pending Approvals', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    SizedBox(height: 4),
                    Text('All loan disbursements, withdrawals, and error corrections are settled.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_mobileSectionTab == 'Overview' || _mobileSectionTab == 'All') ...[
              _buildBranchSummary(data.branchSummary),
              const SizedBox(height: 14),
              _buildBranchCashPosition(data.branchCashPosition),
              const SizedBox(height: 16),
            ],
            if (_mobileSectionTab == 'Officers' || _mobileSectionTab == 'All') ...[
              _buildOfficerCollectionStatus(data.officerCollectionStatus, isMobile),
              const SizedBox(height: 16),
            ],
          ] else ...[
            // 2. Branch Approvals Hub (app.py L2580-3105)
            if (hasApprovals) ...[
              _buildApprovalsHub(data, hasLoans, hasWrs, hasCorrs, isMobile),
              const SizedBox(height: 24),
            ],

            // 3. Section A: Branch Summary (app.py L3108-3114)
            _buildBranchSummary(data.branchSummary),
            const SizedBox(height: 24),

            // 4. Section B: Officer Collection Status Grid (app.py L3116-3126)
            _buildOfficerCollectionStatus(data.officerCollectionStatus, isMobile),
            const SizedBox(height: 24),

            // 5. Section C: Branch Cash Position (Master Cashbook) (app.py L3128-3138)
            _buildBranchCashPosition(data.branchCashPosition),
            const SizedBox(height: 32),
          ],
        ],
      );
  }

  // ==========================================
  // MOBILE SECTION SWITCHER
  // ==========================================
  Widget _buildMobileSectionSwitcher({
    required int totalApprovals,
    required int totalOfficers,
    required bool hasApprovals,
  }) {
    final sections = [
      {'key': 'Approvals', 'label': 'Approvals', 'count': totalApprovals, 'icon': Icons.approval_outlined},
      {'key': 'Overview', 'label': 'KPI & Vault', 'count': null, 'icon': Icons.account_balance_wallet_outlined},
      {'key': 'Officers', 'label': 'Officers', 'count': totalOfficers, 'icon': Icons.badge_outlined},
      {'key': 'All', 'label': 'All Feed', 'count': null, 'icon': Icons.view_agenda_outlined},
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: sections.map((s) {
          final isSel = _mobileSectionTab == s['key'];
          final count = s['count'] as int?;
          final icon = s['icon'] as IconData;

          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _mobileSectionTab = s['key'] as String),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSel
                      ? const [BoxShadow(color: Color(0x0C000000), blurRadius: 4, offset: Offset(0, 1))]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 14,
                          color: isSel ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        ),
                        if (count != null && count > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isSel ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      s['label'] as String,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
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

  // ==========================================
  // BRANCH APPROVALS HUB
  // ==========================================
  Widget _buildApprovalsHub(BmDashboardDataModel data, bool hasLoans, bool hasWrs, bool hasCorrs, bool isMobile) {
    final tabs = <String>[];
    if (hasLoans) tabs.add('Loan Disbursements');
    if (hasWrs) tabs.add('Withdrawals');
    if (hasCorrs) tabs.add('Error Corrections');

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
          const Text(
            'Branch Approvals Hub',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Filter by officer, configure operational disbursement dates, and process batch or individual approvals.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Modern Pill Tabs
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tabs.map((t) {
              final count = t == 'Loan Disbursements'
                  ? data.pendingLoans.length
                  : (t == 'Withdrawals' ? data.pendingWithdrawals.length : data.pendingCorrections.length);
              final isSel = _activeApprovalTab == t;

              return InkWell(
                onTap: () => setState(() => _activeApprovalTab = t),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSel ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '$t ($count)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                      color: isSel ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 16),

          if (_activeApprovalTab == 'Loan Disbursements' && hasLoans)
            _buildLoanApprovalsTab(data.pendingLoans, isMobile)
          else if (_activeApprovalTab == 'Withdrawals' && hasWrs)
            _buildWithdrawalApprovalsTab(data.pendingWithdrawals, isMobile)
          else if (_activeApprovalTab == 'Error Corrections' && hasCorrs)
            _buildCorrectionApprovalsTab(data.pendingCorrections, isMobile),
        ],
      ),
    );
  }

  // ==========================================
  // APPROVALS PAGINATION BAR
  // ==========================================
  Widget _buildApprovalPaginationBar({
    required int currentPage,
    required int totalCount,
    required int pageSize,
    required ValueChanged<int> onPageChanged,
  }) {
    if (totalCount <= pageSize) return const SizedBox.shrink();
    final totalPages = (totalCount / pageSize).ceil();
    final startItem = (currentPage - 1) * pageSize + 1;
    final endItem = (currentPage * pageSize).clamp(1, totalCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem-$endItem of $totalCount items',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(32, 32),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                child: const Icon(Icons.chevron_left, size: 18, color: Color(0xFF475569)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(32, 32),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                child: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF475569)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: LOAN DISBURSEMENTS
  // ==========================================
  Widget _buildLoanApprovalsTab(List<PendingLoanApprovalModel> loans, bool isMobile) {
    final officers = ['All Officers', ...loans.map((l) => l.officer).toSet().toList()..sort()];
    final products = ['All Products', ...loans.map((l) => l.loanProduct).toSet().toList()..sort()];

    final search = _loanSearchCtrl.text.trim().toLowerCase();
    final filtered = loans.where((l) {
      if (_loanOfficerFilter != 'All Officers' && l.officer != _loanOfficerFilter) return false;
      if (_loanProductFilter != 'All Products' && l.loanProduct != _loanProductFilter) return false;
      if (search.isNotEmpty) {
        final match = l.clientName.toLowerCase().contains(search) || l.clientCode.toLowerCase().contains(search);
        if (!match) return false;
      }
      return true;
    }).toList();

    final pSize = _getPageSize(isMobile);
    final totalPages = (filtered.length / pSize).ceil();
    if (_loanPage > totalPages && totalPages > 0) {
      _loanPage = totalPages;
    }
    final startIndex = (_loanPage - 1) * pSize;
    final pagedLoans = filtered.skip(startIndex).take(pSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter row
        if (isMobile)
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: officers.contains(_loanOfficerFilter) ? _loanOfficerFilter : 'All Officers',
                      decoration: const InputDecoration(labelText: 'Filter Officer', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: officers.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() {
                        _loanOfficerFilter = v ?? 'All Officers';
                        _loanPage = 1;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: products.contains(_loanProductFilter) ? _loanProductFilter : 'All Products',
                      decoration: const InputDecoration(labelText: 'Filter Product', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: products.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() {
                        _loanProductFilter = v ?? 'All Products';
                        _loanPage = 1;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _loanSearchCtrl,
                decoration: InputDecoration(
                  labelText: 'Search Client Name / Code',
                  hintText: 'Type name or code...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  suffixIcon: _loanSearchCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() {
                          _loanSearchCtrl.clear();
                          _loanPage = 1;
                        }))
                      : null,
                ),
                onChanged: (_) => setState(() => _loanPage = 1),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: officers.contains(_loanOfficerFilter) ? _loanOfficerFilter : 'All Officers',
                  decoration: const InputDecoration(labelText: 'Filter Officer', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: officers.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() {
                    _loanOfficerFilter = v ?? 'All Officers';
                    _loanPage = 1;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: products.contains(_loanProductFilter) ? _loanProductFilter : 'All Products',
                  decoration: const InputDecoration(labelText: 'Filter Product', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: products.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() {
                    _loanProductFilter = v ?? 'All Products';
                    _loanPage = 1;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _loanSearchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Search Client Name / Code',
                    hintText: 'Type name or code...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: _loanSearchCtrl.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() {
                            _loanSearchCtrl.clear();
                            _loanPage = 1;
                          }))
                        : null,
                  ),
                  onChanged: (_) => setState(() => _loanPage = 1),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        const Divider(color: Color(0xFFE2E8F0), height: 1),
        const SizedBox(height: 10),

        // Batch controls
        if (isMobile)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: filtered.isNotEmpty && _selectedLoanIds.containsAll(filtered.map((l) => l.loanId)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedLoanIds.addAll(filtered.map((l) => l.loanId));
                      } else {
                        _selectedLoanIds.removeAll(filtered.map((l) => l.loanId));
                      }
                    });
                  },
                ),
                const SizedBox(width: 4),
                Text('All (${filtered.length})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                const Spacer(),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _batchLoanDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _batchLoanDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFCBD5E1))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF2563EB)),
                        const SizedBox(width: 4),
                        Text(DateFormat('MM/dd').format(_batchLoanDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_selectedLoanIds.isEmpty || _isProcessing)
                      ? null
                      : () => _executeBatchApproveLoans(filtered),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 30),
                  ),
                  child: Text(
                    _isProcessing ? '...' : 'Approve (${_selectedLoanIds.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _batchLoanDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _batchLoanDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Batch Operational Disbursement Date', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    child: Text(DateFormat('yyyy-MM-dd').format(_batchLoanDate), style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Checkbox(
                value: filtered.isNotEmpty && _selectedLoanIds.containsAll(filtered.map((l) => l.loanId)),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedLoanIds.addAll(filtered.map((l) => l.loanId));
                    } else {
                      _selectedLoanIds.removeAll(filtered.map((l) => l.loanId));
                    }
                  });
                },
              ),
              Text('Select All (${filtered.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              ElevatedButton(
                onPressed: (_selectedLoanIds.isEmpty || _isProcessing)
                    ? null
                    : () => _executeBatchApproveLoans(filtered),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  _isProcessing ? 'Processing...' : 'Approve Selected Loans',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),

        // Cards list
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
            child: const Center(
              child: Text('No pending loan applications matching the selected filters.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pagedLoans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final pl = pagedLoans[idx];
              final isChecked = _selectedLoanIds.contains(pl.loanId);
              final cardDate = _loanDatesMap[pl.loanId] ?? _batchLoanDate;

              if (isMobile) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header line: Checkbox + Client Name & Product + Amount
                      Row(
                        children: [
                          Checkbox(
                            value: isChecked,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedLoanIds.add(pl.loanId);
                                } else {
                                  _selectedLoanIds.remove(pl.loanId);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pl.clientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis),
                                Text('${pl.clientCode} • ${pl.loanProduct}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(pl.loanAmount),
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Compact action line: Officer tag + Date Chip + Reject + Approve in ONE row!
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                            child: Text(pl.officer, style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569))),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: cardDate,
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() => _loanDatesMap[pl.loanId] = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 10, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 3),
                                  Text(
                                    DateFormat('MM/dd').format(cardDate),
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton(
                            onPressed: _isProcessing ? null : () => _rejectSingleLoan(pl.loanId, pl.clientName),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(0, 28),
                            ),
                            child: const Text('Reject', style: TextStyle(color: Color(0xFF475569), fontSize: 11)),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: _isProcessing ? null : () => _approveSingleLoan(pl.loanId, pl.clientName, cardDate),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 28),
                            ),
                            child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isChecked,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedLoanIds.add(pl.loanId);
                          } else {
                            _selectedLoanIds.remove(pl.loanId);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(pl.clientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                child: Text(pl.clientCode, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF475569))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Product: ${pl.loanProduct} | Officer: ${pl.officer}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(CurrencyFormatter.format(pl.loanAmount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          const Text('Requested Principal', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: cardDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _loanDatesMap[pl.loanId] = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Disbursement Date', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                          child: Text(DateFormat('yyyy-MM-dd').format(cardDate), style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : () => _approveSingleLoan(pl.loanId, pl.clientName, cardDate),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _isProcessing ? null : () => _rejectSingleLoan(pl.loanId, pl.clientName),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: const Text('Reject', style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
                    ),
                  ],
                ),
              );
            },
          ),
        _buildApprovalPaginationBar(
          currentPage: _loanPage,
          totalCount: filtered.length,
          pageSize: pSize,
          onPageChanged: (newPage) => setState(() => _loanPage = newPage),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: WITHDRAWALS
  // ==========================================
  Widget _buildWithdrawalApprovalsTab(List<PendingWithdrawalApprovalModel> wrs, bool isMobile) {
    final officers = ['All Officers', ...wrs.map((w) => w.requestedBy).toSet().toList()..sort()];
    final types = ['All Types', ...wrs.map((w) => w.savingsType).toSet().toList()..sort()];

    final search = _wrSearchCtrl.text.trim().toLowerCase();
    final filtered = wrs.where((w) {
      if (_wrOfficerFilter != 'All Officers' && w.requestedBy != _wrOfficerFilter) return false;
      if (_wrTypeFilter != 'All Types' && w.savingsType != _wrTypeFilter) return false;
      if (search.isNotEmpty) {
        final match = w.clientName.toLowerCase().contains(search) || (w.reference != null && w.reference!.toLowerCase().contains(search));
        if (!match) return false;
      }
      return true;
    }).toList();

    final pSize = _getPageSize(isMobile);
    final totalPages = (filtered.length / pSize).ceil();
    if (_wrPage > totalPages && totalPages > 0) {
      _wrPage = totalPages;
    }
    final startIndex = (_wrPage - 1) * pSize;
    final pagedWrs = filtered.skip(startIndex).take(pSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter row
        if (isMobile)
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: officers.contains(_wrOfficerFilter) ? _wrOfficerFilter : 'All Officers',
                      decoration: const InputDecoration(labelText: 'Officer', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      items: officers.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() {
                        _wrOfficerFilter = v ?? 'All Officers';
                        _wrPage = 1;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: types.contains(_wrTypeFilter) ? _wrTypeFilter : 'All Types',
                      decoration: const InputDecoration(labelText: 'Type', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      items: types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() {
                        _wrTypeFilter = v ?? 'All Types';
                        _wrPage = 1;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _wrSearchCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search client or reference...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  suffixIcon: _wrSearchCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 14), onPressed: () => setState(() {
                          _wrSearchCtrl.clear();
                          _wrPage = 1;
                        }))
                      : null,
                ),
                onChanged: (_) => setState(() => _wrPage = 1),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: officers.contains(_wrOfficerFilter) ? _wrOfficerFilter : 'All Officers',
                  decoration: const InputDecoration(labelText: 'Filter Officer', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: officers.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() {
                    _wrOfficerFilter = v ?? 'All Officers';
                    _wrPage = 1;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: types.contains(_wrTypeFilter) ? _wrTypeFilter : 'All Types',
                  decoration: const InputDecoration(labelText: 'Filter Savings Type', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() {
                    _wrTypeFilter = v ?? 'All Types';
                    _wrPage = 1;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _wrSearchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Search Client / Reference',
                    hintText: 'Type name or ref...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: _wrSearchCtrl.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() {
                            _wrSearchCtrl.clear();
                            _wrPage = 1;
                          }))
                        : null,
                  ),
                  onChanged: (_) => setState(() => _wrPage = 1),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        const Divider(color: Color(0xFFE2E8F0), height: 1),
        const SizedBox(height: 12),

        // Batch controls
        if (isMobile)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: filtered.isNotEmpty && _selectedWrIds.containsAll(filtered.map((w) => w.id)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedWrIds.addAll(filtered.map((w) => w.id));
                      } else {
                        _selectedWrIds.removeAll(filtered.map((w) => w.id));
                      }
                    });
                  },
                ),
                const SizedBox(width: 4),
                Text('All (${filtered.length})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                const Spacer(),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _batchWrDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _batchWrDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFCBD5E1))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF2563EB)),
                        const SizedBox(width: 4),
                        Text(DateFormat('MM/dd').format(_batchWrDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_selectedWrIds.isEmpty || _isProcessing)
                      ? null
                      : () => _executeBatchApproveWithdrawals(filtered),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 30),
                  ),
                  child: Text(
                    _isProcessing ? '...' : 'Approve (${_selectedWrIds.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _batchWrDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _batchWrDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Batch Operational Withdrawal Date', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    child: Text(DateFormat('yyyy-MM-dd').format(_batchWrDate), style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Checkbox(
                value: filtered.isNotEmpty && _selectedWrIds.containsAll(filtered.map((w) => w.id)),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedWrIds.addAll(filtered.map((w) => w.id));
                    } else {
                      _selectedWrIds.removeAll(filtered.map((w) => w.id));
                    }
                  });
                },
              ),
              Text('Select All (${filtered.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              ElevatedButton(
                onPressed: (_selectedWrIds.isEmpty || _isProcessing)
                    ? null
                    : () => _executeBatchApproveWithdrawals(filtered),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  _isProcessing ? 'Processing...' : 'Approve Selected Withdrawals',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),

        // Cards list
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
            child: const Center(
              child: Text('No pending withdrawal requests matching the selected filters.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pagedWrs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final wr = pagedWrs[idx];
              final isChecked = _selectedWrIds.contains(wr.id);
              DateTime cardDate = _batchWrDate;
              if (wr.operationalDate != null && wr.operationalDate!.isNotEmpty) {
                try {
                  cardDate = DateTime.parse(wr.operationalDate!);
                } catch (_) {}
              }
              if (_wrDatesMap.containsKey(wr.id)) {
                cardDate = _wrDatesMap[wr.id]!;
              }

              if (isMobile) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: isChecked,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedWrIds.add(wr.id);
                                } else {
                                  _selectedWrIds.remove(wr.id);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(wr.clientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis),
                                Text(
                                  '${wr.savingsType} • ${wr.operationType}',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(wr.amount),
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFFB91C1C), fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('Req: ${wr.requestedBy}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                          const Spacer(),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: cardDate,
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() => _wrDatesMap[wr.id] = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 10, color: Color(0xFF475569)),
                                  const SizedBox(width: 4),
                                  Text(DateFormat('MM/dd').format(cardDate), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _isProcessing ? null : () => _promptRejectWithdrawal(wr.id, wr.clientName),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(0, 28),
                            ),
                            child: const Text('Reject', style: TextStyle(color: Color(0xFF475569), fontSize: 11)),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: _isProcessing ? null : () => _approveSingleWithdrawal(wr.id, wr.clientName, wr.amount, cardDate),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 28),
                            ),
                            child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isChecked,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedWrIds.add(wr.id);
                          } else {
                            _selectedWrIds.remove(wr.id);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(wr.clientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                child: Text(wr.savingsType, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Op: ${wr.operationType} | Requested by: ${wr.requestedBy}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          if (wr.remarks != null && wr.remarks!.isNotEmpty)
                            Text(wr.remarks!, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(CurrencyFormatter.format(wr.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFB91C1C))),
                          const Text('Withdrawal Amount', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: cardDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _wrDatesMap[wr.id] = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Operational Date', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                          child: Text(DateFormat('yyyy-MM-dd').format(cardDate), style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : () => _approveSingleWithdrawal(wr.id, wr.clientName, wr.amount, cardDate),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _isProcessing ? null : () => _promptRejectWithdrawal(wr.id, wr.clientName),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: const Text('Reject', style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
                    ),
                  ],
                ),
              );
            },
          ),
        _buildApprovalPaginationBar(
          currentPage: _wrPage,
          totalCount: filtered.length,
          pageSize: pSize,
          onPageChanged: (newPage) => setState(() => _wrPage = newPage),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: ERROR CORRECTIONS
  // ==========================================
  Widget _buildCorrectionApprovalsTab(List<PendingCorrectionApprovalModel> corrs, bool isMobile) {
    final officers = ['All Officers', ...corrs.map((c) => c.requestedBy).toSet().toList()..sort()];
    final types = ['All Types', ...corrs.map((c) => c.recordType).toSet().toList()..sort()];

    final search = _corrSearchCtrl.text.trim().toLowerCase();
    final filtered = corrs.where((c) {
      if (_corrOfficerFilter != 'All Officers' && c.requestedBy != _corrOfficerFilter) return false;
      if (_corrTypeFilter != 'All Types' && c.recordType != _corrTypeFilter) return false;
      if (search.isNotEmpty) {
        final match = c.reason.toLowerCase().contains(search) || c.recordId.toLowerCase().contains(search);
        if (!match) return false;
      }
      return true;
    }).toList();

    final pSize = _getPageSize(isMobile);
    final totalPages = (filtered.length / pSize).ceil();
    if (_corrPage > totalPages && totalPages > 0) {
      _corrPage = totalPages;
    }
    final startIndex = (_corrPage - 1) * pSize;
    final pagedCorrs = filtered.skip(startIndex).take(pSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter row
        if (isMobile)
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: officers.contains(_corrOfficerFilter) ? _corrOfficerFilter : 'All Officers',
                      decoration: const InputDecoration(labelText: 'Requester', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      items: officers.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() {
                        _corrOfficerFilter = v ?? 'All Officers';
                        _corrPage = 1;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: types.contains(_corrTypeFilter) ? _corrTypeFilter : 'All Types',
                      decoration: const InputDecoration(labelText: 'Type', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      items: types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() {
                        _corrTypeFilter = v ?? 'All Types';
                        _corrPage = 1;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _corrSearchCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search ref or note...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  suffixIcon: _corrSearchCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 14), onPressed: () => setState(() {
                          _corrSearchCtrl.clear();
                          _corrPage = 1;
                        }))
                      : null,
                ),
                onChanged: (_) => setState(() => _corrPage = 1),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: officers.contains(_corrOfficerFilter) ? _corrOfficerFilter : 'All Officers',
                  decoration: const InputDecoration(labelText: 'Filter Requester', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: officers.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() {
                    _corrOfficerFilter = v ?? 'All Officers';
                    _corrPage = 1;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: types.contains(_corrTypeFilter) ? _corrTypeFilter : 'All Types',
                  decoration: const InputDecoration(labelText: 'Filter Transaction Type', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() {
                    _corrTypeFilter = v ?? 'All Types';
                    _corrPage = 1;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _corrSearchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Search Ref / Reason',
                    hintText: 'Type reference or note...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: _corrSearchCtrl.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() {
                            _corrSearchCtrl.clear();
                            _corrPage = 1;
                          }))
                        : null,
                  ),
                  onChanged: (_) => setState(() => _corrPage = 1),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        const Divider(color: Color(0xFFE2E8F0), height: 1),
        const SizedBox(height: 12),

        // Batch controls
        if (isMobile)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: filtered.isNotEmpty && _selectedCorrIds.containsAll(filtered.map((c) => c.id)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedCorrIds.addAll(filtered.map((c) => c.id));
                      } else {
                        _selectedCorrIds.removeAll(filtered.map((c) => c.id));
                      }
                    });
                  },
                ),
                const SizedBox(width: 4),
                Text('All (${filtered.length})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                const Spacer(),
                ElevatedButton(
                  onPressed: (_selectedCorrIds.isEmpty || _isProcessing)
                      ? null
                      : () => _executeBatchApproveCorrections(filtered),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 30),
                  ),
                  child: Text(
                    _isProcessing ? '...' : 'Approve (${_selectedCorrIds.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Checkbox(
                value: filtered.isNotEmpty && _selectedCorrIds.containsAll(filtered.map((c) => c.id)),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedCorrIds.addAll(filtered.map((c) => c.id));
                    } else {
                      _selectedCorrIds.removeAll(filtered.map((c) => c.id));
                    }
                  });
                },
              ),
              Text('Select All (${filtered.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              ElevatedButton(
                onPressed: (_selectedCorrIds.isEmpty || _isProcessing)
                    ? null
                    : () => _executeBatchApproveCorrections(filtered),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  _isProcessing ? 'Processing...' : 'Approve Selected Reversals',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),

        // Cards list
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
            child: const Center(
              child: Text('No pending error correction requests matching the selected filters.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pagedCorrs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final corr = pagedCorrs[idx];
              final isChecked = _selectedCorrIds.contains(corr.id);
              final rRef = corr.recordId.length >= 8 ? corr.recordId.substring(0, 8) : corr.recordId;

              if (isMobile) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: isChecked,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedCorrIds.add(corr.id);
                                } else {
                                  _selectedCorrIds.remove(corr.id);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('[${corr.recordType}] #$rRef', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5), overflow: TextOverflow.ellipsis),
                                Text(
                                  corr.reason,
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                            child: const Text('Pending', style: TextStyle(color: Color(0xFF92400E), fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('By: ${corr.requestedBy}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                          const Spacer(),
                          OutlinedButton(
                            onPressed: _isProcessing ? null : () => _rejectSingleCorrection(corr.id),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(0, 28),
                            ),
                            child: const Text('Reject', style: TextStyle(color: Color(0xFF475569), fontSize: 11)),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: _isProcessing ? null : () => _approveSingleCorrection(corr.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 28),
                            ),
                            child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isChecked,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedCorrIds.add(corr.id);
                          } else {
                            _selectedCorrIds.remove(corr.id);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('[${corr.recordType}]', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                child: Text('Ref: #$rRef', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF475569))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Requested by: ${corr.requestedBy} • Submitted: ${corr.createdAt ?? ""}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text('Reason: ${corr.reason}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF334155))),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(9999)),
                        child: const Text(
                          'Pending Approval',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : () => _approveSingleCorrection(corr.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _isProcessing ? null : () => _rejectSingleCorrection(corr.id),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: const Text('Reject', style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
                    ),
                  ],
                ),
              );
            },
          ),
        _buildApprovalPaginationBar(
          currentPage: _corrPage,
          totalCount: filtered.length,
          pageSize: pSize,
          onPageChanged: (newPage) => setState(() => _corrPage = newPage),
        ),
      ],
    );
  }

  // ==========================================
  // SECTION A: BRANCH SUMMARY (4 KPI CARDS)
  // ==========================================
  Widget _buildBranchSummary(BranchSummaryModel bs) {
    final c1 = _buildMetricCard(
      'Active Clients',
      '${bs.activeClients}',
      icon: Icons.people_alt_outlined,
      accentColor: const Color(0xFF2563EB),
      subtitle: 'Registered Borrowers',
    );
    final c2 = _buildMetricCard(
      'Active Savings',
      CurrencyFormatter.format(bs.activeSavings),
      icon: Icons.savings_outlined,
      accentColor: const Color(0xFF065F46),
      subtitle: 'Client Vault Savings',
    );
    final c3 = _buildMetricCard(
      'Collection Today',
      CurrencyFormatter.format(bs.collectionToday),
      icon: Icons.payments_outlined,
      accentColor: const Color(0xFF10B981),
      isGrand: true,
      subtitle: 'Daily Cash Inflow',
    );
    final parVal = double.tryParse(bs.par.replaceAll('%', '').trim()) ?? 0.0;
    final isParHealthy = parVal <= 5.0;
    final c4 = _buildMetricCard(
      'Portfolio at Risk (PAR)',
      bs.par,
      icon: isParHealthy ? Icons.verified_user_outlined : Icons.warning_amber_rounded,
      accentColor: isParHealthy ? const Color(0xFF059669) : const Color(0xFFDC2626),
      deltaColor: isParHealthy ? const Color(0xFF15803D) : const Color(0xFFDC2626),
      subtitle: isParHealthy ? 'Within 5% Target' : 'Exceeds 5% Target',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w < 600) {
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
        } else if (w < 900) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: c1), const SizedBox(width: 12), Expanded(child: c2)],
                ),
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: c3), const SizedBox(width: 12), Expanded(child: c4)],
                ),
              ),
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: c1),
              const SizedBox(width: 14),
              Expanded(child: c2),
              const SizedBox(width: 14),
              Expanded(child: c3),
              const SizedBox(width: 14),
              Expanded(child: c4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    String label,
    String value, {
    Color? deltaColor,
    Color? accentColor,
    IconData? icon,
    String? subtitle,
    bool isGrand = false,
  }) {
    final topBorderColor = accentColor ?? (isGrand ? const Color(0xFF10B981) : const Color(0xFF2563EB));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: BorderSide(color: topBorderColor, width: 3),
          left: BorderSide(color: isGrand ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
          right: BorderSide(color: isGrand ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
          bottom: BorderSide(color: isGrand ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: const [
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
                  label,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 16, color: topBorderColor),
              ],
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: deltaColor ?? (isGrand ? const Color(0xFF15803D) : const Color(0xFF0F172A)),
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // SECTION B: OFFICER COLLECTION STATUS
  // ==========================================
  Widget _buildOfficerCollectionStatus(List<OfficerCollectionStatusModel> officers, bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.badge_outlined, size: 16, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Officer Collection Status',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${officers.length} Officers',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          if (officers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: Text('No officer collection activity recorded for today.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))),
            )
          else if (isMobile)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: officers.map((o) => _buildMobileOfficerStatusCard(o)).toList(),
              ),
            )
          else
            Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 64,
                  columns: const [
                    DataColumn(label: Text('Officer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    DataColumn(label: Text('Scheduled Groups', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    DataColumn(label: Text('Expected', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    DataColumn(label: Text('Collected', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    DataColumn(label: Text('Outstanding', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    DataColumn(label: Text('Compliance %', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    DataColumn(label: Text('Closing Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  ],
                  rows: officers.map((o) {
                    final isAttention = o.status == 'Requires Attention';
                    final isNormal = o.status == 'Normal';

                    return DataRow(
                      cells: [
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(o.officer, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              Text(o.officerName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              o.scheduledGroups,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),
                        DataCell(Text(CurrencyFormatter.format(o.expected), style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.format(o.collected), style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: Color(0xFF16A34A), fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.format(o.outstanding), style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: Color(0xFFDC2626), fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(
                          Text(
                            '${o.compliancePct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: o.compliancePct >= 80 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        DataCell(Text(CurrencyFormatter.format(o.closingBalance), style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isNormal ? const Color(0xFFDCFCE7) : (isAttention ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Text(
                              o.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isNormal ? const Color(0xFF15803D) : (isAttention ? const Color(0xFFB45309) : const Color(0xFF475569)),
                              ),
                            ),
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

  Widget _buildMobileOfficerStatusCard(OfficerCollectionStatusModel o) {
    final isNormal = o.status == 'Normal';
    final isAttention = o.status == 'Requires Attention';
    final isHighCompliance = o.compliancePct >= 80.0;
    final isExpanded = _expandedOfficer == o.officer;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isExpanded ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
        boxShadow: isExpanded
            ? const [BoxShadow(color: Color(0x0C2563EB), blurRadius: 6, offset: Offset(0, 2))]
            : null,
      ),
      child: InkWell(
        onTap: () => setState(() => _expandedOfficer = isExpanded ? null : o.officer),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Collapsed Header Row (Always Visible)
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isHighCompliance ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    child: Text(
                      o.officer.length >= 2 ? o.officer.substring(0, 2).toUpperCase() : o.officer.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isHighCompliance ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.officerName.isNotEmpty ? o.officerName : o.officer,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Text(o.officer, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontFamily: 'monospace')),
                            const Text(' • ', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10)),
                            Text(
                              '${CurrencyFormatter.format(o.collected)} / ${CurrencyFormatter.format(o.expected)}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isHighCompliance ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${o.compliancePct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isHighCompliance ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),

              // Expandable Detail Body
              if (isExpanded) ...[
                const SizedBox(height: 10),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 10),

                // Scheduled Groups
                if (o.scheduledGroups.isNotEmpty && o.scheduledGroups != '—') ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.groups_outlined, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Groups: ${o.scheduledGroups}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // 3-Metric Summary
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Expected', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                            const SizedBox(height: 1),
                            Text(
                              CurrencyFormatter.format(o.expected),
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Collected', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                            const SizedBox(height: 1),
                            Text(
                              CurrencyFormatter.format(o.collected),
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: Color(0xFF16A34A)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Outstanding', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                            const SizedBox(height: 1),
                            Text(
                              CurrencyFormatter.format(o.outstanding),
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Footer Row: Status & Closing Balance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isNormal ? const Color(0xFFDCFCE7) : (isAttention ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        o.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isNormal ? const Color(0xFF15803D) : (isAttention ? const Color(0xFFB45309) : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Text('Closing: ', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                        Text(
                          CurrencyFormatter.format(o.closingBalance),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SECTION C: BRANCH CASH POSITION (MASTER CASHBOOK)
  // ==========================================
  Widget _buildBranchCashPosition(BranchCashPositionModel cp) {
    final isBalanced = cp.status == 'Balanced';

    final c1 = _buildMetricCard(
      'Opening Balance (B/F)',
      CurrencyFormatter.format(cp.openingBalance),
      icon: Icons.history_toggle_off_outlined,
      accentColor: const Color(0xFF64748B),
      subtitle: 'Vault B/F Balance',
    );
    final c2 = _buildMetricCard(
      'Total Inflows',
      CurrencyFormatter.format(cp.cashIn),
      icon: Icons.south_west_outlined,
      accentColor: const Color(0xFF10B981),
      subtitle: 'Collections & Deposits',
    );
    final c3 = _buildMetricCard(
      'Total Outflows',
      CurrencyFormatter.format(cp.cashOut),
      icon: Icons.north_east_outlined,
      accentColor: const Color(0xFFEF4444),
      subtitle: 'Disbursements & Costs',
    );
    final c4 = _buildMetricCard(
      'Closing Cash Balance',
      CurrencyFormatter.format(cp.closingBalance),
      icon: Icons.account_balance_wallet_outlined,
      accentColor: const Color(0xFF2563EB),
      isGrand: true,
      subtitle: 'Physical Vault Position',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.account_balance_outlined, size: 16, color: Color(0xFF065F46)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Branch Cash Position (Master Cashbook)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isBalanced ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isBalanced ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBalanced ? Icons.check_circle_outline : Icons.error_outline,
                      size: 13,
                      color: isBalanced ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cp.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isBalanced ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Core Financial Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              if (w < 600) {
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
              } else if (w < 900) {
                return Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [Expanded(child: c1), const SizedBox(width: 12), Expanded(child: c2)],
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [Expanded(child: c3), const SizedBox(width: 12), Expanded(child: c4)],
                      ),
                    ),
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: c1),
                    const SizedBox(width: 14),
                    Expanded(child: c2),
                    const SizedBox(width: 14),
                    Expanded(child: c3),
                    const SizedBox(width: 14),
                    Expanded(child: c4),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Reconciliation Verification Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isBalanced ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isBalanced ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isBalanced ? Icons.verified_outlined : Icons.warning_amber_rounded,
                  size: 18,
                  color: isBalanced ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isBalanced
                        ? 'Vault Cash is fully reconciled and balanced with Account 1000. Variance: ${CurrencyFormatter.format(cp.difference)}'
                        : 'Reconciliation Variance Detected: Difference of ${CurrencyFormatter.format(cp.difference)}. Requires physical vault audit.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isBalanced ? const Color(0xFF166534) : const Color(0xFF991B1B),
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

  // ==========================================
  // ACTION HANDLERS
  // ==========================================

  Future<void> _approveSingleLoan(String loanId, String clientName, DateTime date) async {
    setState(() => _isProcessing = true);
    try {
      final api = ref.read(bmApiServiceProvider);
      final res = await api.approveLoan(loanId: loanId, disbursementDate: DateFormat('yyyy-MM-dd').format(date));
      _showFlash(res['message']?.toString() ?? 'Loan approved & disbursed for $clientName!');
      ref.invalidate(bmDashboardDataProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approval failed: $e'), backgroundColor: const Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectSingleLoan(String loanId, String clientName) async {
    setState(() => _isProcessing = true);
    try {
      final api = ref.read(bmApiServiceProvider);
      final res = await api.rejectLoan(loanId: loanId, reason: 'Rejected by BM');
      _showFlash(res['message']?.toString() ?? 'Loan rejected for $clientName.');
      ref.invalidate(bmDashboardDataProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rejection failed: $e'), backgroundColor: const Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _executeBatchApproveLoans(List<PendingLoanApprovalModel> loans) async {
    setState(() => _isProcessing = true);
    try {
      final api = ref.read(bmApiServiceProvider);
      final dateMap = <String, String>{};
      for (final id in _selectedLoanIds) {
        final d = _loanDatesMap[id] ?? _batchLoanDate;
        dateMap[id] = DateFormat('yyyy-MM-dd').format(d);
      }
      final res = await api.batchApproveLoans(
        loanIds: _selectedLoanIds.toList(),
        defaultDisbursementDate: DateFormat('yyyy-MM-dd').format(_batchLoanDate),
        loanDatesMap: dateMap,
      );
      _showFlash(res['message']?.toString() ?? 'Batch approved loans successfully.');
      _selectedLoanIds.clear();
      ref.invalidate(bmDashboardDataProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Batch approval failed: $e'), backgroundColor: const Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _approveSingleWithdrawal(String id, String clientName, double amount, DateTime date) async {
    setState(() => _isProcessing = true);
    try {
      final api = ref.read(bmApiServiceProvider);
      final res = await api.approveWithdrawal(withdrawalId: id, operationalDate: DateFormat('yyyy-MM-dd').format(date));
      _showFlash(res['message']?.toString() ?? 'Withdrawal of ${CurrencyFormatter.format(amount)} for $clientName approved!');
      ref.invalidate(bmDashboardDataProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approval failed: $e'), backgroundColor: const Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _promptRejectWithdrawal(String id, String clientName) async {
    final reasonCtrl = TextEditingController();
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Withdrawal for $clientName'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Rejection Reason', hintText: 'Why is this being rejected?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldReject == true) {
      setState(() => _isProcessing = true);
      try {
        final api = ref.read(bmApiServiceProvider);
        final res = await api.rejectWithdrawal(withdrawalId: id, reason: reasonCtrl.text.trim().isEmpty ? 'Rejected by BM' : reasonCtrl.text.trim());
        _showFlash(res['message']?.toString() ?? 'Withdrawal request rejected.');
        ref.invalidate(bmDashboardDataProvider);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rejection failed: $e'), backgroundColor: const Color(0xFFDC2626)));
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _executeBatchApproveWithdrawals(List<PendingWithdrawalApprovalModel> wrs) async {
    setState(() => _isProcessing = true);
    try {
      final api = ref.read(bmApiServiceProvider);
      final dateMap = <String, String>{};
      for (final id in _selectedWrIds) {
        final d = _wrDatesMap[id] ?? _batchWrDate;
        dateMap[id] = DateFormat('yyyy-MM-dd').format(d);
      }
      final res = await api.batchApproveWithdrawals(
        withdrawalIds: _selectedWrIds.toList(),
        defaultOperationalDate: DateFormat('yyyy-MM-dd').format(_batchWrDate),
        withdrawalDatesMap: dateMap,
      );
      _showFlash(res['message']?.toString() ?? 'Batch approved withdrawals successfully.');
      _selectedWrIds.clear();
      ref.invalidate(bmDashboardDataProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Batch approval failed: $e'), backgroundColor: const Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _approveSingleCorrection(String id) async {
    setState(() => _isProcessing = true);
    try {
      final api = ref.read(bmApiServiceProvider);
      final res = await api.approveCorrection(correctionId: id);
      _showFlash(res['message']?.toString() ?? 'Reversal approved and executed atomically!');
      ref.invalidate(bmDashboardDataProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approval failed: $e'), backgroundColor: const Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectSingleCorrection(String id) async {
    setState(() => _isProcessing = true);
    try {
      final api = ref.read(bmApiServiceProvider);
      final res = await api.rejectCorrection(correctionId: id);
      _showFlash(res['message']?.toString() ?? 'Reversal rejected.');
      ref.invalidate(bmDashboardDataProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rejection failed: $e'), backgroundColor: const Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _executeBatchApproveCorrections(List<PendingCorrectionApprovalModel> corrs) async {
    setState(() => _isProcessing = true);
    try {
      final api = ref.read(bmApiServiceProvider);
      final res = await api.batchApproveCorrections(correctionIds: _selectedCorrIds.toList());
      _showFlash(res['message']?.toString() ?? 'Batch approved reversals successfully.');
      _selectedCorrIds.clear();
      ref.invalidate(bmDashboardDataProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Batch approval failed: $e'), backgroundColor: const Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
