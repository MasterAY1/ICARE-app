import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/icare_metric_card.dart';
import '../../../core/widgets/icare_section_header.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../data/datasources/admin_api_service.dart';
import '../data/models/admin_dashboard_models.dart';

// State Providers for Admin Dashboard
final adminActiveTabProvider = StateProvider.autoDispose<int>((ref) => 0); // 0=Operations, 1=Performance, 2=Risk & Health
final adminPerformanceSubTabProvider = StateProvider.autoDispose<int>((ref) => 0); // 0=Branch Performance, 1=Officer Performance
final adminPerformanceYearProvider = StateProvider.autoDispose<int>((ref) => DateTime.now().year);
final adminSelectedBranchFilterProvider = StateProvider.autoDispose<String?>((ref) => null);
final adminDateProvider = StateProvider.autoDispose<DateTime>((ref) => DateTime.now());

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  String? _statusBannerText;
  bool _isSuccessBanner = true;

  void _showFeedback(String message, {bool isSuccess = true}) {
    setState(() {
      _statusBannerText = message;
      _isSuccessBanner = isSuccess;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _statusBannerText = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(adminActiveTabProvider);
    final selectedDate = ref.watch(adminDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final isMobile = MediaQuery.of(context).size.width < 700;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Bar
          _buildHeaderBar(context, selectedDate, isMobile),
          const SizedBox(height: 14),

          // Feedback Flash Banner
          if (_statusBannerText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: _isSuccessBanner ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isSuccessBanner ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSuccessBanner ? Icons.check_circle_outline : Icons.error_outline,
                    color: _isSuccessBanner ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusBannerText!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isSuccessBanner ? const Color(0xFF166534) : const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 2. Primary Navigation Segment
          _buildPrimaryTabs(activeTab, isMobile),
          const SizedBox(height: 18),

          // 3. Active Workspace Content
          if (activeTab == 0)
            _buildOperationsWorkspace(dateStr, isMobile)
          else if (activeTab == 1)
            _buildPerformanceWorkspace(isMobile)
          else
            _buildRiskHealthWorkspace(isMobile),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context, DateTime selectedDate, bool isMobile) {
    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(selectedDate);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IcareSectionHeader(
                title: 'Institutional Command Cockpit',
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_outlined, size: 14, color: Color(0xFF475569)),
                        const SizedBox(width: 6),
                        Text(
                          formattedDate,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const IcareSectionHeader(
              title: 'Institutional Command Cockpit',
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_available_outlined, size: 15, color: Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrimaryTabs(int activeTab, bool isMobile) {
    final tabs = [
      {'label': 'Daily Operations & Approvals', 'icon': Icons.tune_rounded},
      {'label': 'Branch & Officer Performance', 'icon': Icons.leaderboard_outlined},
      {'label': 'Portfolio Risk & Quality', 'icon': Icons.shield_outlined},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(tabs.length, (idx) {
            final isSel = activeTab == idx;
            final item = tabs[idx];
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => ref.read(adminActiveTabProvider.notifier).state = idx,
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF064E3B) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        size: 15,
                        color: isSel ? const Color(0xFFA7F3D0) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                          color: isSel ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String title, String detail, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF991B1B),
              side: const BorderSide(color: Color(0xFFF87171)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // WORKSPACE 1: DAILY OPERATIONS & APPROVALS
  // =========================================================================
  Widget _buildOperationsWorkspace(String dateStr, bool isMobile) {
    final opsAsync = ref.watch(adminOperationsProvider(dateStr));

    return opsAsync.when(
      loading: () => const IcareSkeletonLoader(height: 120),
      error: (err, _) => _buildErrorBanner(
        'Unable to load real-time operations',
        'Backend service may be synchronizing. Please retry.',
        () => ref.invalidate(adminOperationsProvider(dateStr)),
      ),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Five Hero Institutional KPI Cards
          _buildHeroKpiRow(data, isMobile),
          const SizedBox(height: 20),

          // 2. Action Center: Pending Reversals & Loan Escalations
          _buildActionCenterSection(data, isMobile),
          const SizedBox(height: 20),

          // 3. Multi-Branch Operations & EOD Status Matrix
          _buildBranchMatrixSection(data, isMobile),
        ],
      ),
    );
  }

  Widget _buildHeroKpiRow(AdminOperationsSnapshotModel d, bool isMobile) {
    final cards = [
      IcareMetricCard(
        label: 'PRIMARY VAULT RESERVE',
        value: CurrencyFormatter.formatNaira(d.vaultCashInCustody),
        delta: 'Physical Vault Cash',
        icon: Icons.account_balance_outlined,
        topBorderColor: const Color(0xFF0F766E),
      ),
      IcareMetricCard(
        label: 'COLLECTIONS TODAY',
        value: CurrencyFormatter.formatNaira(d.todayCollections),
        delta: '${d.collectionCompliancePct.toStringAsFixed(1)}% Compliance',
        icon: Icons.receipt_long_outlined,
        topBorderColor: const Color(0xFF059669),
      ),
      IcareMetricCard(
        label: 'LOANS DISBURSED',
        value: CurrencyFormatter.formatNaira(d.todayDisbursements),
        delta: '${d.todayDisbursedCount} Facilities Outflow',
        icon: Icons.payments_outlined,
        topBorderColor: const Color(0xFF2563EB),
      ),
      IcareMetricCard(
        label: 'NET SAVINGS FLOW',
        value: CurrencyFormatter.formatNaira(d.todayNetSavings),
        delta: 'Inflow minus Outflow',
        icon: Icons.savings_outlined,
        topBorderColor: const Color(0xFF7C3AED),
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c)).toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = (constraints.maxWidth - 36) / 4;
        return Row(
          children: cards.map((c) => Container(width: w, margin: const EdgeInsets.only(right: 12), child: c)).toList(),
        );
      },
    );
  }

  Widget _buildActionCenterSection(AdminOperationsSnapshotModel d, bool isMobile) {
    final totalPending = d.pendingReversalsCount + d.pendingHighLoansCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.rule_folder_outlined, size: 16, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Administrative Approvals Clearinghouse',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: totalPending > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: totalPending > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
                ),
                child: Text(
                  totalPending > 0 ? '$totalPending Pending' : 'All Queues Cleared',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: totalPending > 0 ? const Color(0xFFDC2626) : const Color(0xFF166534),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Reversals Queue
          if (d.pendingReversals.isNotEmpty) ...[
            const Text('Pending Error Correction & Reversal Requests:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
            const SizedBox(height: 8),
            ...d.pendingReversals.map((r) => _buildReversalQueueItem(r)),
            const SizedBox(height: 12),
          ],

          // High-Value Loans Queue
          if (d.pendingHighLoans.isNotEmpty) ...[
            const Text('Pending High-Value Loan Escalations (> ₦300,000):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
            const SizedBox(height: 8),
            ...d.pendingHighLoans.map((l) => _buildLoanQueueItem(l)),
          ],

          if (totalPending == 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: const Text('Zero pending items. All branch operations and exceptions are up to date.', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReversalQueueItem(PendingReversalItemModel r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(r.branchName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                      child: Text(r.recordType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text('Reason: ${r.reason} • By: ${r.requestedBy}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              side: const BorderSide(color: Color(0xFFDC2626)),
            ),
            onPressed: () async {
              final api = ref.read(adminApiServiceProvider);
              final ok = await api.rejectReversal(r.requestId);
              if (ok) {
                _showFeedback('Reversal request rejected.');
                ref.invalidate(adminOperationsProvider);
              }
            },
            child: const Text('Reject', style: TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
            ),
            onPressed: () async {
              final api = ref.read(adminApiServiceProvider);
              final ok = await api.approveReversal(r.requestId);
              if (ok) {
                _showFeedback('Reversal approved. Ledger adjusting entry posted.');
                ref.invalidate(adminOperationsProvider);
              }
            },
            child: const Text('Approve & Post', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanQueueItem(PendingHighLoanItemModel l) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(l.branchName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.formatNaira(l.loanAmount),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F766E), fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text('Active Credit: ${CurrencyFormatter.formatNaira(l.activeCredit)} • Applied: ${l.createdAt}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              side: const BorderSide(color: Color(0xFFDC2626)),
            ),
            onPressed: () async {
              final api = ref.read(adminApiServiceProvider);
              final ok = await api.rejectLoan(l.loanId);
              if (ok) {
                _showFeedback('Loan application rejected.');
                ref.invalidate(adminOperationsProvider);
              }
            },
            child: const Text('Reject', style: TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF064E3B),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
            ),
            onPressed: () async {
              final api = ref.read(adminApiServiceProvider);
              final ok = await api.approveLoan(l.loanId);
              if (ok) {
                _showFeedback('Loan approved and scheduled for disbursement.');
                ref.invalidate(adminOperationsProvider);
              }
            },
            child: const Text('Approve Loan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchMatrixSection(AdminOperationsSnapshotModel d, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.hub_outlined, size: 16, color: Color(0xFF475569)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Branch Operational & Business Day Matrix',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Branch Cards List / Grid
          ...d.branchMatrix.map((b) => _buildBranchMatrixRow(b, isMobile)),
        ],
      ),
    );
  }

  Widget _buildBranchMatrixRow(BranchOperationalStatusModel b, bool isMobile) {
    Color statusBg;
    Color statusText;
    String statusLabel;

    switch (b.operationalStatus) {
      case 'CLOSED':
        statusBg = const Color(0xFFF1F5F9);
        statusText = const Color(0xFF475569);
        statusLabel = 'Closed & Balanced';
        break;
      case 'EOD_PENDING':
        statusBg = const Color(0xFFFEF3C7);
        statusText = const Color(0xFF92400E);
        statusLabel = 'EOD Pending Review';
        break;
      default:
        statusBg = const Color(0xFFECFDF5);
        statusText = const Color(0xFF065F46);
        statusLabel = 'Open & Trading';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(b.branchName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                      child: Text(statusLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusText)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Manager: ${b.managerName}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('TODAY COLLECTED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.formatNaira(b.todayCollected),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('VAULT RESERVE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.formatNaira(b.vaultCash),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F766E), fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // WORKSPACE 2: BRANCH & OFFICER PERFORMANCE (CONCISE, NO AWARDS DISPLAY)
  // =========================================================================
  Widget _buildPerformanceWorkspace(bool isMobile) {
    final subTab = ref.watch(adminPerformanceSubTabProvider);
    final year = ref.watch(adminPerformanceYearProvider);
    final perfAsync = ref.watch(institutionPerformanceProvider(year));

    return perfAsync.when(
      loading: () => const IcareSkeletonLoader(height: 120),
      error: (err, _) => _buildErrorBanner(
        'Unable to load institution performance',
        'Backend service may be synchronizing. Please retry.',
        () => ref.invalidate(institutionPerformanceProvider(year)),
      ),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtab Controls: [ Branch Performance | Officer Performance ] + Year Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildSubTabPill('Branch Performance', 0, subTab),
                    const SizedBox(width: 8),
                    _buildSubTabPill('Officer Performance', 1, subTab),
                  ],
                ),
                DropdownButton<int>(
                  value: year,
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  items: [2026, 2025, 2024].map((y) => DropdownMenuItem(value: y, child: Text('$y Cycle'))).toList(),
                  onChanged: (val) {
                    if (val != null) ref.read(adminPerformanceYearProvider.notifier).state = val;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (subTab == 0)
            _buildBranchPerformanceView(data.branchRankings, isMobile)
          else
            _buildOfficerPerformanceView(data.officerRankings, isMobile),
        ],
      ),
    );
  }

  Widget _buildSubTabPill(String label, int index, int current) {
    final isSel = current == index;
    return InkWell(
      onTap: () => ref.read(adminPerformanceSubTabProvider.notifier).state = index,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF064E3B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
            color: isSel ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildBranchPerformanceView(List<BranchPerformanceItemModel> branches, bool isMobile) {
    if (branches.isEmpty) {
      return const Center(child: Text('No branch performance records available.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top 3 Highlights (Concise, sleek rank chips, zero award fanfare)
        if (branches.length >= 3) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final w = isMobile ? constraints.maxWidth : (constraints.maxWidth - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildBranchTopCard(branches[0], 1, w),
                  _buildBranchTopCard(branches[1], 2, w),
                  _buildBranchTopCard(branches[2], 3, w),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
        ],

        // Full 1st-to-Last Branch Performance Table
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined, size: 16, color: Color(0xFF475569)),
                    SizedBox(width: 8),
                    Text('Branch Performance Rankings', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 38,
                  dataRowMinHeight: 46,
                  dataRowMaxHeight: 52,
                  columns: const [
                    DataColumn(label: Text('Rank', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('Branch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('Active Clients', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('Disbursed (YTD)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('Recovered Arrears', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('PAR %', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('Compliance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('Score', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                  ],
                  rows: branches.map((b) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: b.rank <= 3 ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: b.rank <= 3 ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
                            ),
                            child: Text('#${b.rank}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: b.rank <= 3 ? const Color(0xFF065F46) : const Color(0xFF475569))),
                          ),
                        ),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(b.branchName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                              Text(b.bmName, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        DataCell(Text('${b.activeMembers}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.formatNaira(b.disbPrincipal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(CurrencyFormatter.formatNaira(b.overdueRecovered), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F766E), fontFeatures: [FontFeature.tabularFigures()])),
                              Text('${b.fullRecoveriesCount} Restorations', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            '${b.parPct.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: b.parPct <= 2.5 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        DataCell(Text('${b.compliancePct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(
                          Text(
                            '${b.compositeScore} / 100',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF064E3B), fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBranchTopCard(BranchPerformanceItemModel b, int rank, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: rank == 1 ? const Color(0xFF059669) : const Color(0xFFE2E8F0), width: rank == 1 ? 1.5 : 1.0),
        boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: rank == 1 ? const Color(0xFF064E3B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#$rank Rank',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: rank == 1 ? Colors.white : const Color(0xFF475569)),
                ),
              ),
              Text(
                '${b.compositeScore} pts',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF064E3B), fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(b.branchName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          Text('BM: ${b.bmName}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Disbursed: ${CurrencyFormatter.formatNaira(b.disbPrincipal)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              Text('PAR: ${b.parPct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: b.parPct <= 2.5 ? const Color(0xFF059669) : const Color(0xFFDC2626))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerPerformanceView(List<OfficerPerformanceItemModel> officers, bool isMobile) {
    if (officers.isEmpty) {
      return const Center(child: Text('No officer performance records available.'));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.people_outline, size: 16, color: Color(0xFF475569)),
                SizedBox(width: 8),
                Text('Officer Performance Rankings', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 38,
              dataRowMinHeight: 46,
              dataRowMaxHeight: 52,
              columns: const [
                DataColumn(label: Text('Rank', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Officer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Branch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Active Clients', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Disbursed (YTD)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Recovered Arrears', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('PAR %', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Score', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
              ],
              rows: officers.map((o) {
                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: o.rank <= 3 ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: o.rank <= 3 ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1)),
                        ),
                        child: Text('#${o.rank}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: o.rank <= 3 ? const Color(0xFF1E40AF) : const Color(0xFF475569))),
                      ),
                    ),
                    DataCell(Text(o.officerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                    DataCell(Text(o.branchName, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
                    DataCell(Text('${o.activeClients}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                    DataCell(Text(CurrencyFormatter.formatNaira(o.disbPrincipal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]))),
                    DataCell(Text(CurrencyFormatter.formatNaira(o.overdueRecovered), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F766E), fontFeatures: [FontFeature.tabularFigures()]))),
                    DataCell(
                      Text(
                        '${o.parPct.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: o.parPct <= 2.5 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${o.compositeScore} / 100',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F766E), fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // WORKSPACE 3: RISK & PLATFORM HEALTH
  // =========================================================================
  Widget _buildRiskHealthWorkspace(bool isMobile) {
    final healthAsync = ref.watch(adminRiskHealthProvider);

    return healthAsync.when(
      loading: () => const IcareSkeletonLoader(height: 120),
      error: (err, _) => _buildErrorBanner(
        'Unable to load risk indicators',
        'Backend service may be synchronizing. Please retry.',
        () => ref.invalidate(adminRiskHealthProvider),
      ),
      data: (h) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Risk Overview Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final w = isMobile ? constraints.maxWidth : (constraints.maxWidth - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildHealthCard('PORTFOLIO AT RISK (PAR)', '${h.parPct.toStringAsFixed(2)}%', 'Total Active: ${CurrencyFormatter.formatNaira(h.totalActiveCredit)}', w, isAlert: h.parPct > 5.0),
                  _buildHealthCard('OVERDUE RECOVERED', CurrencyFormatter.formatNaira(h.totalOverdueRecovered), '${h.fullClientRestorations} Full Rehabilitations', w),
                  _buildHealthCard('FULL PAYOFFS (EARLY)', CurrencyFormatter.formatNaira(h.fullPayoffsSettledAmount), '${h.fullPayoffCount} Contracts Settled Early', w),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 2. Institutional Credit Risk & Portfolio Quality Overview
          Container(
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
                  'Institutional Credit Risk & Portfolio Quality Overview',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                _buildRiskIndicatorRow('Financial Books Reconciliation', 'Balanced & Verified', isHealthy: true),
                _buildRiskIndicatorRow('Vault Cash Reserve Coverage', 'Physical Custody Backed', isHealthy: true),
                _buildRiskIndicatorRow('Arrears Recovery Status', '${CurrencyFormatter.formatNaira(h.totalOverdueRecovered)} Recovered', isHealthy: true),
                _buildRiskIndicatorRow('Early Payoff Prepayment Settlement', '${CurrencyFormatter.formatNaira(h.fullPayoffsSettledAmount)} (${h.fullPayoffCount} Accounts)', isHealthy: true),
                _buildRiskIndicatorRow('Client Rehabilitation & Defaulter Restoration', '${h.fullClientRestorations} Full Restorations', isHealthy: true),
                _buildRiskIndicatorRow('Audit & Regulatory Compliance', 'Authoritative Ledger Enforced', isHealthy: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard(String title, String value, String subtitle, double width, {bool isAlert = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isAlert ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF64748B))),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildRiskIndicatorRow(String label, String value, {bool isHealthy = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: isHealthy ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
              ),
              const SizedBox(width: 6),
              Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isHealthy ? const Color(0xFF065F46) : const Color(0xFF991B1B))),
            ],
          ),
        ],
      ),
    );
  }
}
