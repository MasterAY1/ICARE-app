import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/datasources/admin_api_service.dart';
import 'widgets/admin_overview_tab.dart';
import 'widgets/admin_rankings_tab.dart';
import 'widgets/admin_responsive.dart';
import 'widgets/admin_risk_tab.dart';

// State Providers for Admin Dashboard
final adminActiveTabProvider = StateProvider.autoDispose<int>(
  (ref) => 0,
); // 0=Overview, 1=Branch & Officer Rankings, 2=Loan Health & Risk
final adminPerformanceYearProvider = StateProvider.autoDispose<int>(
  (ref) => DateTime.now().year,
);
final adminSelectedBranchFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final adminDateProvider = StateProvider.autoDispose<DateTime>(
  (ref) => DateTime.now(),
);
final adminCalendarMode7dProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
); // false = 5-day Mon-Fri, true = 7-day

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  String? _statusBannerText;
  bool _isSuccessBanner = true;

  /// Remembers each tab's scroll offset when embedded in an ancestor Scrollable
  /// or when using internal scroll controllers.
  final Map<int, double> _tabScrollOffsets = {0: 0.0, 1: 0.0, 2: 0.0};
  final List<ScrollController> _tabScrollControllers = [
    ScrollController(),
    ScrollController(),
    ScrollController(),
  ];

  late final AnimationController _tabAnimController;
  late final Animation<double> _tabFadeAnim;
  late final Animation<Offset> _tabSlideAnim;

  @override
  void initState() {
    super.initState();
    _tabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _tabFadeAnim = CurvedAnimation(
      parent: _tabAnimController,
      curve: Curves.easeOutCubic,
    );
    _tabSlideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.015),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _tabAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _tabAnimController.dispose();
    for (final c in _tabScrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _showFeedback(String message, {bool isSuccess = true}) {
    setState(() {
      _statusBannerText = message;
      _isSuccessBanner = isSuccess;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _statusBannerText = null);
    });
  }

  void _selectTab(BuildContext context, int newTab, int currentTab) {
    if (newTab == currentTab) return;

    // Save current scroll position from ancestor Scrollable (if embedded in CoAppScaffold)
    final ancestorScrollable = Scrollable.maybeOf(context);
    if (ancestorScrollable != null && ancestorScrollable.position.hasPixels) {
      _tabScrollOffsets[currentTab] = ancestorScrollable.position.pixels;
    }

    ref.read(adminActiveTabProvider.notifier).state = newTab;

    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!disableAnimations) {
      _tabAnimController.forward(from: 0.0);
    } else {
      _tabAnimController.value = 1.0;
    }

    if (ancestorScrollable != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final pos = ancestorScrollable.position;
        if (pos.hasPixels && pos.hasContentDimensions) {
          final target = (_tabScrollOffsets[newTab] ?? 0.0)
              .clamp(pos.minScrollExtent, pos.maxScrollExtent);
          pos.jumpTo(target);
        }
      });
    }
  }

  Future<void> _refreshActiveTab(int activeTab, String dateStr, int year) async {
    if (activeTab == 0) {
      ref.invalidate(adminOperationsProvider(dateStr));
      await ref.read(adminOperationsProvider(dateStr).future);
    } else if (activeTab == 1) {
      ref.invalidate(institutionPerformanceProvider(year));
      await ref.read(institutionPerformanceProvider(year).future);
    } else {
      ref.invalidate(adminRiskHealthProvider);
      ref.invalidate(institutionPerformanceProvider(year));
      await ref.read(adminRiskHealthProvider.future);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(adminActiveTabProvider);
    final selectedDate = ref.watch(adminDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final year = ref.watch(adminPerformanceYearProvider);

    // Pre-warm all 3 providers so tab switches don't flash loading skeletons
    final opsAsync = ref.watch(adminOperationsProvider(dateStr));
    ref.watch(institutionPerformanceProvider(year));
    ref.watch(adminRiskHealthProvider);

    final pendingApprovalsCount = opsAsync.maybeWhen(
      data: (d) => d.pendingReversalsCount + d.pendingHighLoansCount,
      orElse: () => 0,
    );

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final hasBoundedHeight = outerConstraints.hasBoundedHeight;

        if (hasBoundedHeight) {
          // Standalone / bounded viewport: sticky header + tab bar above per-tab RefreshIndicator + ScrollView
          return AdminResponsiveContainer(
            builder: (context, size, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInstitutionalHeader(
                    context,
                    selectedDate,
                    size,
                    activeTab: activeTab,
                    dateStr: dateStr,
                    year: year,
                  ),
                  const SizedBox(height: 12),
                  if (_statusBannerText != null) _buildStatusBanner(),
                  _buildWorkspaceSegmentedTabs(
                    context,
                    activeTab,
                    size,
                    pendingApprovalsCount: pendingApprovalsCount,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: FadeTransition(
                      opacity: _tabFadeAnim,
                      child: SlideTransition(
                        position: _tabSlideAnim,
                        child: IndexedStack(
                          index: activeTab,
                          children: [
                            RefreshIndicator(
                              color: const Color(0xFF0F766E),
                              onRefresh: () =>
                                  _refreshActiveTab(0, dateStr, year),
                              child: SingleChildScrollView(
                                controller: _tabScrollControllers[0],
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                child: AdminOverviewTab(
                                  dateStr: dateStr,
                                  size: size,
                                  onReversalDecision: _handleReversalApproval,
                                  onLoanDecision: _handleLoanApproval,
                                ),
                              ),
                            ),
                            RefreshIndicator(
                              color: const Color(0xFF0F766E),
                              onRefresh: () =>
                                  _refreshActiveTab(1, dateStr, year),
                              child: SingleChildScrollView(
                                controller: _tabScrollControllers[1],
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                child: AdminRankingsTab(size: size),
                              ),
                            ),
                            RefreshIndicator(
                              color: const Color(0xFF0F766E),
                              onRefresh: () =>
                                  _refreshActiveTab(2, dateStr, year),
                              child: SingleChildScrollView(
                                controller: _tabScrollControllers[2],
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                child: AdminRiskTab(size: size),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }

        // Embedded inside CoAppScaffold's outer SingleChildScrollView (unbounded vertical constraints)
        return AdminResponsiveContainer(
          padding: EdgeInsets.zero,
          builder: (context, size, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInstitutionalHeader(
                  context,
                  selectedDate,
                  size,
                  activeTab: activeTab,
                  dateStr: dateStr,
                  year: year,
                ),
                const SizedBox(height: 14),
                if (_statusBannerText != null) _buildStatusBanner(),
                _buildWorkspaceSegmentedTabs(
                  context,
                  activeTab,
                  size,
                  pendingApprovalsCount: pendingApprovalsCount,
                ),
                const SizedBox(height: 18),
                FadeTransition(
                  opacity: _tabFadeAnim,
                  child: SlideTransition(
                    position: _tabSlideAnim,
                    child: IndexedStack(
                      index: activeTab,
                      children: [
                        Visibility(
                          visible: activeTab == 0,
                          maintainState: true,
                          child: AdminOverviewTab(
                            dateStr: dateStr,
                            size: size,
                            onReversalDecision: _handleReversalApproval,
                            onLoanDecision: _handleLoanApproval,
                          ),
                        ),
                        Visibility(
                          visible: activeTab == 1,
                          maintainState: true,
                          child: AdminRankingsTab(size: size),
                        ),
                        Visibility(
                          visible: activeTab == 2,
                          maintainState: true,
                          child: AdminRiskTab(size: size),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _isSuccessBanner
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isSuccessBanner
              ? const Color(0xFF86EFAC)
              : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isSuccessBanner
                ? Icons.check_circle_outline
                : Icons.error_outline,
            color: _isSuccessBanner
                ? const Color(0xFF15803D)
                : const Color(0xFFDC2626),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusBannerText!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _isSuccessBanner
                    ? const Color(0xFF166534)
                    : const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. INSTITUTIONAL HEADER & BANNER
  // =========================================================================
  Widget _buildInstitutionalHeader(
    BuildContext context,
    DateTime selectedDate,
    AdminSize size, {
    required int activeTab,
    required String dateStr,
    required int year,
  }) {
    final formattedDate =
        DateFormat('EEEE, MMMM d, yyyy').format(selectedDate).toUpperCase();
    final isWeekend = selectedDate.weekday >= 6;
    final isCompact = size.isCompact;

    final tabTitle = activeTab == 0
        ? 'Overview'
        : activeTab == 1
            ? 'Branch & Officer Rankings'
            : 'Loan Health & Risk';
    final tabSubtitle = activeTab == 0
        ? 'See today’s numbers and how all branches are doing.'
        : activeTab == 1
            ? 'Compare branch and credit officer performance across the network.'
            : 'Monitor late repayments, recoveries, and early loan payoffs.';

    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      size: 18,
                      color: Color(0xFF0F172A),
                    ),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isWeekend)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Text(
                        'Weekend (Closed)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => _refreshActiveTab(activeTab, dateStr, year),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: Color(0xFF475569),
                    ),
                    tooltip: 'Refresh current tab',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    padding: const EdgeInsets.all(6),
                    splashRadius: 18,
                  ),
                  IconButton(
                    onPressed: () => _pickDate(context),
                    icon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: Color(0xFF475569),
                    ),
                    tooltip: 'Select operational date',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    padding: const EdgeInsets.all(6),
                    splashRadius: 18,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          Text(
            tabTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tabSubtitle,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. SEGMENTED WORKSPACE TABS (ALWAYS SHOWS ICON + LABEL AT EVERY WIDTH)
  // =========================================================================
  Widget _buildWorkspaceSegmentedTabs(
    BuildContext context,
    int activeTab,
    AdminSize size, {
    required int pendingApprovalsCount,
  }) {
    final isCompact = size.isCompact;
    final tabs = [
      (
        label: 'Overview',
        shortLabel: 'Overview',
        icon: Icons.dashboard_outlined,
        badgeCount: pendingApprovalsCount,
      ),
      (
        label: 'Branch & Officer Rankings',
        shortLabel: 'Rankings',
        icon: Icons.leaderboard_outlined,
        badgeCount: 0,
      ),
      (
        label: 'Loan Health & Risk',
        shortLabel: 'Loan Health',
        icon: Icons.shield_outlined,
        badgeCount: 0,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final isSelected = activeTab == idx;
          final tab = tabs[idx];
          final displayLabel = isCompact ? tab.shortLabel : tab.label;

          return Expanded(
            child: InkWell(
              key: ValueKey('admin_tab_$idx'),
              onTap: () => _selectTab(context, idx, activeTab),
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  vertical: 9,
                  horizontal: isCompact ? 6 : 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
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
                      size: isCompact ? 14 : 15,
                      color: isSelected
                          ? const Color(0xFF022C22)
                          : const Color(0xFF64748B),
                    ),
                    SizedBox(width: isCompact ? 4 : 6),
                    Flexible(
                      child: Text(
                        displayLabel,
                        style: TextStyle(
                          fontSize: isCompact ? 11.5 : 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFF022C22)
                              : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (tab.badgeCount > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${tab.badgeCount}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
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
    final success = approve
        ? await api.approveReversal(requestId)
        : await api.rejectReversal(requestId);
    if (success) {
      _showFeedback(
        approve
            ? 'Correction approved and ledger reversed.'
            : 'Correction request rejected.',
      );
      ref.invalidate(adminOperationsProvider);
    } else {
      _showFeedback('Action failed. Please retry.', isSuccess: false);
    }
  }

  Future<void> _handleLoanApproval(String loanId, bool approve) async {
    final api = ref.read(adminApiServiceProvider);
    final success = approve
        ? await api.approveLoan(loanId)
        : await api.rejectLoan(loanId);
    if (success) {
      _showFeedback(
        approve
            ? 'Loan application approved and disbursed.'
            : 'Loan application rejected.',
      );
      ref.invalidate(adminOperationsProvider);
    } else {
      _showFeedback('Action failed. Please retry.', isSuccess: false);
    }
  }
}
