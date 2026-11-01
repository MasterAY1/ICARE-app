import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../data/datasources/admin_api_service.dart';
import '../data/models/admin_dashboard_models.dart';
import 'admin_branch_detail_sheet.dart';

// State Providers for Admin Dashboard
final adminActiveTabProvider = StateProvider.autoDispose<int>((ref) => 0); // 0=Overview & Pulse, 1=Performance Rankings, 2=Risk & Quality
final adminPerformanceYearProvider = StateProvider.autoDispose<int>((ref) => DateTime.now().year);
final adminSelectedBranchFilterProvider = StateProvider.autoDispose<String?>((ref) => null);
final adminDateProvider = StateProvider.autoDispose<DateTime>((ref) => DateTime.now());
final adminCalendarMode7dProvider = StateProvider.autoDispose<bool>((ref) => false); // false = 5-day Mon-Fri, true = 7-day

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Executive Top Brand & Date Banner
          _buildInstitutionalHeader(context, selectedDate, isMobile),
          const SizedBox(height: 16),

          // Feedback Notification Banner
          if (_statusBannerText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
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

          // 2. Tab Navigation Selector
          _buildWorkspaceSegmentedTabs(activeTab, isMobile),
          const SizedBox(height: 20),

          // 3. Tab Workspace Views
          if (activeTab == 0)
            _buildInstitutionalOverviewWorkspace(dateStr, isMobile)
          else if (activeTab == 1)
            _buildPerformanceWorkspace(isMobile)
          else
            _buildRiskQualityWorkspace(isMobile),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. INSTITUTIONAL HEADER & BANNER
  // =========================================================================
  Widget _buildInstitutionalHeader(BuildContext context, DateTime selectedDate, bool isMobile) {
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(selectedDate).toUpperCase();
    final isWeekend = selectedDate.weekday >= 6;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Emblem & Administration Tagline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance, size: 18, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ICARE',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'ADMINISTRATION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  // Working Day Status Badge (BR-DATE-001, BR-DATE-004)
                  if (isWeekend)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Text(
                        'Weekend Freeze',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                      ),
                    ),
                  IconButton(
                    onPressed: () => _pickDate(context),
                    icon: const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF475569)),
                    tooltip: 'Select operational date',
                    splashRadius: 18,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Date Display (Mockup Header Style)
          Text(
            formattedDate,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),

          // Main Title & Subtitle
          const Text(
            'Institutional Overview',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Monitor operations across all branches.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. SEGMENTED WORKSPACE TABS
  // =========================================================================
  Widget _buildWorkspaceSegmentedTabs(int activeTab, bool isMobile) {
    final tabs = [
      (label: 'Command Overview', icon: Icons.dashboard_outlined),
      (label: 'Branch & Officer Rankings', icon: Icons.leaderboard_outlined),
      (label: 'Portfolio Risk & Quality', icon: Icons.shield_outlined),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return Row(
            children: List.generate(tabs.length, (idx) {
              final isSelected = activeTab == idx;
              final tab = tabs[idx];
              return Expanded(
                child: InkWell(
                  onTap: () => ref.read(adminActiveTabProvider.notifier).state = idx,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.icon,
                          size: 15,
                          color: isSelected ? const Color(0xFF022C22) : const Color(0xFF64748B),
                        ),
                        if (!isNarrow) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              tab.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? const Color(0xFF022C22) : const Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // =========================================================================
  // 3. WORKSPACE 1: INSTITUTIONAL OVERVIEW (THE MOCKUP LAYOUT)
  // =========================================================================
  Widget _buildInstitutionalOverviewWorkspace(String dateStr, bool isMobile) {
    final opsAsync = ref.watch(adminOperationsProvider(dateStr));

    return opsAsync.when(
      loading: () => const Column(
        children: [
          IcareSkeletonLoader(height: 120),
          SizedBox(height: 16),
          IcareSkeletonLoader(height: 180),
          SizedBox(height: 16),
          IcareSkeletonLoader(height: 200),
        ],
      ),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Unable to load institutional operations: $err',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B)),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(adminOperationsProvider(dateStr)),
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
      data: (data) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A. Top 4-Card Executive KPI Grid (Mockup Layout)
            _buildTopKpiGrid(data.overview, isMobile),
            const SizedBox(height: 18),

            // B. Financial Activity Card (Last 7 Days / Mon-Fri Working Week)
            _buildFinancialActivityCard(data.financialActivityWeek, isMobile),
            const SizedBox(height: 18),

            // C. Branch Performance Card (with Click-to-Drilldown)
            _buildBranchPerformanceCard(data.branchPerformanceSummary, isMobile),
            const SizedBox(height: 18),

            // D. System Operations & Approvals Clearinghouse
            _buildApprovalsActionCenter(data, isMobile),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // A. Top 4-Card Executive KPI Grid (Mockup Match)
  // -------------------------------------------------------------------------
  Widget _buildTopKpiGrid(InstitutionalOverviewModel ov, bool isMobile) {
    final cards = [
      _KpiItem(
        icon: Icons.groups_outlined,
        label: 'Total clients',
        value: ov.totalClientsDisplay,
        subtitle: '${ov.totalClientsCount} registered in system',
      ),
      _KpiItem(
        icon: Icons.domain_outlined,
        label: 'Active branches',
        value: '${ov.activeBranchesCount}',
        subtitle: 'Excludes Head Office',
      ),
      _KpiItem(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Total portfolio',
        value: ov.totalPortfolio > 0 ? CurrencyFormatter.format(ov.totalPortfolio) : '₦—',
        subtitle: 'Active credit deployed',
      ),
      _KpiItem(
        icon: Icons.trending_up_outlined,
        label: "Today's collections",
        value: ov.todayCollections > 0 ? CurrencyFormatter.format(ov.todayCollections) : '₦—',
        subtitle: 'Repayments received',
      ),
    ];

    if (isMobile) {
      // 2x2 grid on mobile
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.25,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cards.map((c) => _buildCompactKpiCard(c)).toList(),
      );
    } else {
      // 4-across on desktop/tablet
      return Row(
        children: cards.map((c) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _buildCompactKpiCard(c),
            ),
          );
        }).toList(),
      );
    }
  }

  Widget _buildCompactKpiCard(_KpiItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 16, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            item.subtitle,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // B. Financial Activity Card (Last 7 Days / Mon-Fri Working Week)
  // -------------------------------------------------------------------------
  Widget _buildFinancialActivityCard(List<FinancialActivityDayModel> weekData, bool isMobile) {
    final showFull7d = ref.watch(adminCalendarMode7dProvider);
    final displayedDays = showFull7d ? weekData : weekData.where((d) => d.day != 'Sat' && d.day != 'Sun').toList();

    // Determine max volume to scale bars
    double maxVol = 1.0;
    for (final d in displayedDays) {
      if (d.collections > maxVol) maxVol = d.collections;
      if (d.disbursements > maxVol) maxVol = d.disbursements;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Period Badge & 5-Day/7-Day Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financial activity',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Operational working days (Mon-Fri) • Non-working days excluded',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              InkWell(
                onTap: () => ref.read(adminCalendarMode7dProvider.notifier).state = !showFull7d,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    showFull7d ? '7-Day View' : 'Mon-Fri (5-Day)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Visual Bar Chart Series
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: displayedDays.map((d) {
                final isNonWorking = !d.isWorkingDay;
                final colRatio = (d.collections / maxVol).clamp(0.08, 1.0);
                final barHeight = 85.0 * colRatio;

                return Expanded(
                  child: Tooltip(
                    message: '${d.day} (${d.date})\nCollections: ${CurrencyFormatter.format(d.collections)}\nDisbursements: ${CurrencyFormatter.format(d.disbursements)}${isNonWorking ? '\n${d.statusReason}' : ''}',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // The Rounded Bar
                        Container(
                          width: isMobile ? 22 : 36,
                          height: isNonWorking ? 16 : barHeight,
                          decoration: BoxDecoration(
                            color: isNonWorking
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF60A5FA), // Restrained steel blue
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: isNonWorking
                              ? const Center(
                                  child: Icon(Icons.lock_outline, size: 10, color: Color(0xFF94A3B8)),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        // Day Label
                        Text(
                          d.day,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isNonWorking ? FontWeight.w500 : FontWeight.w700,
                            color: isNonWorking ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // C. Branch Performance Card (Mockup Layout with Progress Bars)
  // -------------------------------------------------------------------------
  Widget _buildBranchPerformanceCard(List<BranchPerformanceRowModel> branches, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Branch performance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Tap branch for detail',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (branches.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No operational branches found.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ),
            ),
          ] else ...[
            ...branches.map((b) => _buildBranchPerformanceRow(b)),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Footnote Matching Mockup
          const Text(
            'Illustrative layout only. Actual values must come from verified reports.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchPerformanceRow(BranchPerformanceRowModel b) {
    return InkWell(
      onTap: () => AdminBranchDetailSheet.show(context, branchId: b.branchId, branchName: b.branchName),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    b.branchName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                ),
                Text(
                  b.volume > 0 ? CurrencyFormatter.format(b.volume) : '—',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
              ],
            ),
            const SizedBox(height: 6),
            // Progress distribution bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: b.relativePct.clamp(0.04, 1.0),
                minHeight: 4,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // D. System Operations & Approvals Clearinghouse
  // -------------------------------------------------------------------------
  Widget _buildApprovalsActionCenter(AdminOperationsSnapshotModel data, bool isMobile) {
    final reversals = data.pendingReversals;
    final highLoans = data.pendingHighLoans;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Approvals & Escalation Clearinghouse',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (reversals.isNotEmpty || highLoans.isNotEmpty) ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${reversals.length + highLoans.length} Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: (reversals.isNotEmpty || highLoans.isNotEmpty) ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (reversals.isEmpty && highLoans.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No pending transaction reversals or high-value loan escalations.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          ] else ...[
            if (reversals.isNotEmpty) ...[
              const Text('Correction Reversals Awaiting Executive Approval', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              ...reversals.map((r) => _buildReversalRow(r)),
              const SizedBox(height: 12),
            ],
            if (highLoans.isNotEmpty) ...[
              const Text('High-Value Loan Applications (>₦300,000)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              ...highLoans.map((l) => _buildHighLoanRow(l)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildReversalRow(PendingReversalItemModel r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
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
                Text('${r.branchName} • ${r.recordType}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(r.reason, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _handleReversalApproval(r.requestId, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(60, 28),
            ),
            child: const Text('Approve', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () => _handleReversalApproval(r.requestId, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(60, 28),
            ),
            child: const Text('Reject', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
  }

  Widget _buildHighLoanRow(PendingHighLoanItemModel l) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
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
                Text('${l.branchName} • ${CurrencyFormatter.format(l.loanAmount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text('Active Credit: ${CurrencyFormatter.format(l.activeCredit)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _handleLoanApproval(l.loanId, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(60, 28),
            ),
            child: const Text('Sanction', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. WORKSPACE 2: BRANCH & OFFICER PERFORMANCE LEAGUE
  // =========================================================================
  Widget _buildPerformanceWorkspace(bool isMobile) {
    final year = ref.watch(adminPerformanceYearProvider);
    final perfAsync = ref.watch(institutionPerformanceProvider(year));

    return perfAsync.when(
      loading: () => const IcareSkeletonLoader(height: 240),
      error: (err, _) => Center(child: Text('Error loading performance: $err')),
      data: (data) {
        final branches = data.branchRankings;
        final officers = data.officerRankings;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Branch Rankings League Table
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Branch Performance League Table', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),
                  ...branches.map((b) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: b.rank <= 3 ? const Color(0xFF022C22) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${b.rank}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: b.rank <= 3 ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(b.branchName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Text(
                          CurrencyFormatter.format(b.disbPrincipal),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Top Officers
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Field Credit Officers Leaderboard', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),
                  ...officers.take(5).map((o) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text('#${o.rank}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('${o.officerName} (${o.branchName})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ),
                        Text('Score: ${o.compositeScore}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF047857))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // 5. WORKSPACE 3: PORTFOLIO RISK & QUALITY
  // =========================================================================
  Widget _buildRiskQualityWorkspace(bool isMobile) {
    final riskAsync = ref.watch(adminRiskHealthProvider);

    return riskAsync.when(
      loading: () => const IcareSkeletonLoader(height: 200),
      error: (err, _) => Center(child: Text('Error loading risk data: $err')),
      data: (risk) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Institutional Credit Risk & Quality Indicators', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildRiskItem('Portfolio at Risk (PAR)', '${risk.parPct.toStringAsFixed(1)}%', risk.parPct > 10 ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRiskItem('Overdue Recovered', CurrencyFormatter.format(risk.totalOverdueRecovered), const Color(0xFF0284C7)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildRiskItem('Early Full Payoffs Settled', CurrencyFormatter.format(risk.fullPayoffsSettledAmount), const Color(0xFF047857)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRiskItem('Full Rehabilitations', '${risk.fullClientRestorations} Borrowers', const Color(0xFF475569)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRiskItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color, fontFeatures: const [FontFeature.tabularFigures()]),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ACTIONS & HANDLERS
  // =========================================================================
  Future<void> _pickDate(BuildContext context) async {
    final current = ref.read(adminDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      ref.read(adminDateProvider.notifier).state = picked;
    }
  }

  Future<void> _handleReversalApproval(String requestId, bool approve) async {
    final api = ref.read(adminApiServiceProvider);
    final success = approve ? await api.approveReversal(requestId) : await api.rejectReversal(requestId);
    if (success) {
      _showFeedback(approve ? 'Reversal approved successfully.' : 'Reversal rejected.');
      ref.invalidate(adminOperationsProvider);
    } else {
      _showFeedback('Action failed. Please retry.', isSuccess: false);
    }
  }

  Future<void> _handleLoanApproval(String loanId, bool approve) async {
    final api = ref.read(adminApiServiceProvider);
    final success = await api.approveLoan(loanId);
    if (success) {
      _showFeedback('High-value loan application sanctioned.');
      ref.invalidate(adminOperationsProvider);
    } else {
      _showFeedback('Action failed. Please retry.', isSuccess: false);
    }
  }
}

class _KpiItem {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

  const _KpiItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });
}
