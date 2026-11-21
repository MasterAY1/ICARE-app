import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/icare_colors.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../../../core/theme/icare_typography.dart';
import '../../../core/theme/icare_spacing.dart';
import '../../../core/widgets/icare_card.dart';
import '../../../core/widgets/icare_metric_card.dart';
import '../../../core/widgets/icare_status_badge.dart';
import '../../../core/widgets/icare_section_header.dart';
import '../../../core/widgets/icare_data_table.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../../../core/errors/app_error_formatter.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_database_service.dart';
import '../../../core/offline/offline_sync_manager.dart';
import '../data/datasources/co_api_service.dart';
import '../data/models/co_dashboard_models.dart';
import '../../shared/presentation/co_app_scaffold.dart';

final coDashboardProvider = FutureProvider.autoDispose<CoDashboardData>((ref) async {
  final api = ref.watch(coApiServiceProvider);
  final isOnline = ref.watch(isOnlineProvider);
  final dbService = ref.watch(offlineDatabaseServiceProvider);
  final syncMgr = ref.watch(offlineSyncManagerProvider);

  // 1. If currently offline, attempt to load cached dashboard immediately
  if (!isOnline) {
    final cached = await dbService.getCachedDashboardData(role: 'co');
    if (cached != null) {
      return CoDashboardData.fromJson(cached);
    }
  }

  // 2. Attempt online network fetch
  try {
    final data = await api.getCoDashboardData();
    // Cache the fresh dashboard data
    dbService.cacheDashboardData(data.toJson(), role: 'co').ignore();

    // Opportunistically pre-cache active business date meeting collection sheets and single-client options
    final bizIso = data.welcome['date_iso']?.toString().trim();
    final todayStr = (bizIso != null && bizIso.isNotEmpty)
        ? bizIso
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
    final groupNames = <String>[];
    for (final meeting in data.meetingPortfolio) {
      final gName = (meeting['Group Name'] ?? meeting['group_name'])?.toString().trim();
      if (gName != null && gName.isNotEmpty && !groupNames.contains(gName)) {
        groupNames.add(gName);
      }
    }
    if (groupNames.isNotEmpty) {
      syncMgr.preCacheAllAvailableGroups(groupNames, todayStr).ignore();
    } else {
      syncMgr.preCacheSingleClients().ignore();
    }
    syncMgr.preCacheWithdrawalWorkspace(dateStr: todayStr).ignore();
    return data;
  } catch (err) {
    // 3. Fallback to cache on network drop / DioException
    final cached = await dbService.getCachedDashboardData(role: 'co');
    if (cached != null) {
      return CoDashboardData.fromJson(cached);
    }
    // If no cache exists, rethrow so the error UI displays a clean explanation
    rethrow;
  }
});

/// Selected tab in mobile operational segmented hub
/// 0: Meetings, 1: Performance, 2: Cash Position, 3: Attention
final coDashboardMobileTabProvider = StateProvider.autoDispose<int>((ref) => 0);

/// Search filter text for Mobile Attention List
final coDashboardAttentionSearchProvider = StateProvider.autoDispose<String>((ref) => '');

/// Whether to show all attention items or limit to top 10 on mobile
final coDashboardAttentionShowAllProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Credit Officer Dashboard Screen
/// Modernized Mobile Fintech UX with 100% Zero Business Logic Regression
/// Incorporates Emerald Hero Vault Card (Account 1000), Quick Action Shortcuts,
/// 2x2 Portfolio Health Grid, and Mobile Native Meeting Cards.
/// Strict Zero-Emoji Governance (Rule 10) & Institutional Ledger Parity.
class CoDashboardScreen extends ConsumerWidget {
  const CoDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = IcareSurfaceTokens.of(context);
    final dashboardAsync = ref.watch(coDashboardProvider);
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

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isConnectionError ? tokens.warningBg : tokens.dangerBg,
            borderRadius: IcareSpacing.roundedMd,
            border: Border.all(
              color: isConnectionError ? tokens.warningBorder : tokens.dangerBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isConnectionError ? Icons.cloud_off : Icons.error_outline,
                color: isConnectionError ? tokens.warningDot : tokens.dangerDot,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnectionError ? 'Offline Mode — No Local Cache Available' : 'Could not load dashboard data',
                      style: TextStyle(
                        color: isConnectionError ? tokens.warningText : tokens.dangerText,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isConnectionError
                          ? 'You are currently working offline, but no cached dashboard data was found on this device. Please connect to the internet once to load and pre-cache your portfolio.'
                          : AppErrorDetails.from(err).message,
                      style: TextStyle(
                        color: (isConnectionError ? tokens.warningText : tokens.dangerText).withValues(alpha: 0.9),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => ref.refresh(coDashboardProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnectionError ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        );
      },
      data: (data) => Column(
        children: [
          if (!isOnline)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.warningBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.warningBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 16, color: tokens.warningDot),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline Mode Active — Displaying locally cached dashboard. Field collections and meeting sheets are available offline and will queue automatically for synchronization.',
                      style: TextStyle(color: tokens.warningText, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          _buildDashboardContent(context, ref, data),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, WidgetRef ref, CoDashboardData data) {
    final tokens = IcareSurfaceTokens.of(context);
    final wel = data.welcome;
    final officerName = wel['officer_name'] ?? 'Officer';
    final branchName = wel['branch_name'] ?? 'Branch';
    final dateStr = wel['date_str'] ?? '';
    final meetingDay = wel['meeting_day'] ?? '';
    final timeStr = wel['time_str'] ?? '';

    final isClosed = data.branchClosure['is_closed'] == true;
    final closureReason = data.branchClosure['reason'] ?? '';

    final repS = data.repaymentSummary;
    final mPort = data.meetingPortfolio;
    final sav = data.savings;
    final stCards = data.repaymentStatus;
    final cp = data.cashPosition;
    final attList = data.attentionList;

    final isMobile = IcareSpacing.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------------------------------------------------------------------
        // LEVEL 1: Officer Identity & Branch Context Bar
        // ---------------------------------------------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMobile ? 'Field Operations' : 'Credit Officer Dashboard',
                    style: IcareTypography.pageTitle.copyWith(
                      fontSize: isMobile ? 18 : 22,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$officerName · $branchName Branch',
                    style: IcareTypography.pageSubtitle.copyWith(
                      fontSize: isMobile ? 12 : 13,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Welcome / Business Date Institutional Badge
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: tokens.infoBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.infoBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today_outlined, color: tokens.infoText, size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: tokens.infoText,
                      fontSize: isMobile ? 12 : 13,
                      height: 1.35,
                    ),
                    children: [
                      const TextSpan(text: 'Operational Date: '),
                      TextSpan(
                        text: dateStr,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' ($meetingDay)'),
                      if (!isMobile && timeStr.isNotEmpty)
                        TextSpan(text: ' · System Time: $timeStr'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---------------------------------------------------------------------
        // LEVEL 2: Operational Status / Closure Alert (Conditional)
        // ---------------------------------------------------------------------
        if (isClosed) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: tokens.warningBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.warningBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.warning_amber_rounded, color: tokens.warningDot, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: tokens.warningText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: 'Branch Closed / Holiday ($closureReason): ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: 'All field collections, group meetings, and loan repayments are suspended for $branchName Branch today.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ---------------------------------------------------------------------
        // LEVEL 3: Hero Vault Cash Card (Account 1000 & Target Progress)
        // ---------------------------------------------------------------------
        _buildHeroVaultCard(
          cp: cp,
          repS: repS,
          mPort: mPort,
          isMobile: isMobile,
        ),
        const SizedBox(height: 14),

        // ---------------------------------------------------------------------
        // LEVEL 4: Tactile Quick Action Shortcuts
        // ---------------------------------------------------------------------
        _buildQuickActionShortcuts(
          context,
          ref,
          isClosed: isClosed,
          closureReason: closureReason,
        ),
        const SizedBox(height: 20),

        // ---------------------------------------------------------------------
        // LEVEL 5: Portfolio Health Grid (2x2 on Mobile, 4 across on Desktop)
        // ---------------------------------------------------------------------
        _buildPortfolioHealthGrid(context, data),
        const SizedBox(height: 24),

        if (isMobile) ...[
          _buildMobileSegmentedHub(context, ref, data),
        ] else ...[
          // ---------------------------------------------------------------------
          // LEVEL 6: Today's Solidarity Meeting Portfolio (Desktop & Tablet)
          // ---------------------------------------------------------------------
          const IcareSectionHeader(
            title: "Today's Meeting Portfolio",
          ),
          const SizedBox(height: 10),
          if (mPort.isNotEmpty) ...[
            _buildMeetingPortfolioTable(mPort),
            const SizedBox(height: 14),
            Text(
              'Quick Action: Start Collection',
              style: IcareTypography.bodyBold.copyWith(fontSize: 13, color: tokens.textPrimary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: mPort.asMap().entries.map((entry) {
                final idx = entry.key;
                final row = entry.value;
                final gName = (row['Group Name'] ?? row['group_name'] ?? '').toString();
                final rawStatus = (row['Status'] ?? row['status'] ?? 'Completed').toString();
                final cleanStatus = _cleanStatusText(rawStatus);

                return ElevatedButton.icon(
                  key: Key('start_grp_$idx'),
                  icon: Icon(isClosed ? Icons.lock_clock_outlined : Icons.play_circle_outline, size: 15),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isClosed ? tokens.surfaceSubtle : tokens.brandPrimaryDark,
                    foregroundColor: isClosed ? tokens.textMuted : Colors.white,
                    disabledBackgroundColor: tokens.surfaceSubtle,
                    disabledForegroundColor: tokens.textMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: isClosed
                      ? null
                      : () {
                          ref.read(selectedCollectionGroupProvider.notifier).state = gName;
                          ref.read(activeCoPageProvider.notifier).state = 'Collections';
                        },
                  label: Text(
                    isClosed ? '$gName (Closed)' : 'Start $gName ($cleanStatus)',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            _buildInfoBox('No active groups scheduled for today.'),
          ],
          const SizedBox(height: 24),

          // ---------------------------------------------------------------------
          // LEVEL 7: Today's Repayment Summary (Desktop & Tablet)
          // ---------------------------------------------------------------------
          const IcareSectionHeader(
            title: "Today's Repayment Summary",
          ),
          const SizedBox(height: 8),
          _buildResponsiveCardRow([
            IcareMetricCard(
              label: 'Daily (60D)',
              value: CurrencyFormatter.formatNaira((repS['rep_daily_amt'] as num?)?.toDouble() ?? 0.0),
              delta: '${repS['rep_daily_clients'] ?? 0} Clients Paid',
              icon: Icons.today_outlined,
            ),
            IcareMetricCard(
              label: '12 Weeks (Weekly)',
              value: CurrencyFormatter.formatNaira((repS['rep_12_weeks_amt'] as num?)?.toDouble() ?? 0.0),
              delta: '${repS['rep_12_weeks_clients'] ?? 0} Clients Paid',
              icon: Icons.payments_outlined,
            ),
            IcareMetricCard(
              label: '24 Weeks (Weekly)',
              value: CurrencyFormatter.formatNaira((repS['rep_24_weeks_amt'] as num?)?.toDouble() ?? 0.0),
              delta: '${repS['rep_24_weeks_clients'] ?? 0} Clients Paid',
              icon: Icons.payments_outlined,
            ),
          ], spacing: 12),
          const SizedBox(height: 12),
          _buildResponsiveCardRow([
            IcareMetricCard(
              label: 'Daily (120D)',
              value: CurrencyFormatter.formatNaira((repS['rep_120_days_amt'] as num?)?.toDouble() ?? 0.0),
              delta: '${repS['rep_120_days_clients'] ?? 0} Clients Paid',
              icon: Icons.calendar_view_month_outlined,
            ),
            IcareMetricCard(
              label: 'Monthly (3M / 6M)',
              value: CurrencyFormatter.formatNaira((repS['rep_monthly_amt'] as num?)?.toDouble() ?? 0.0),
              delta: '${repS['rep_monthly_clients'] ?? 0} Clients Paid',
              icon: Icons.event_repeat_outlined,
            ),
            IcareMetricCard(
              label: 'Total Repayment Today',
              value: CurrencyFormatter.formatNaira((repS['total_collected_today'] as num?)?.toDouble() ?? 0.0),
              delta: null,
              isFullEmerald: true,
              icon: Icons.account_balance_wallet_outlined,
            ),
          ], spacing: 12),
          const SizedBox(height: 18),

          // ---------------------------------------------------------------------
          // LEVEL 8: Today's Savings (Desktop & Tablet)
          // ---------------------------------------------------------------------
          const IcareSectionHeader(
            title: "Today's Savings",
          ),
          const SizedBox(height: 8),
          _buildResponsiveCardRow([
            IcareMetricCard(
              label: 'Savings Deposited',
              value: CurrencyFormatter.formatNaira((sav['deposited_amt'] as num?)?.toDouble() ?? 0.0),
              delta: '${sav['deposited_clients'] ?? 0} Clients',
              icon: Icons.arrow_downward_outlined,
            ),
            IcareMetricCard(
              label: 'Savings Withdrawn',
              value: CurrencyFormatter.formatNaira((sav['withdrawn_amt'] as num?)?.toDouble() ?? 0.0),
              delta: '${sav['withdrawn_clients'] ?? 0} Clients',
              isInverseDelta: true,
              icon: Icons.arrow_upward_outlined,
            ),
            IcareMetricCard(
              label: 'Net Savings',
              value: CurrencyFormatter.formatNaira((sav['net_savings'] as num?)?.toDouble() ?? 0.0),
              delta: null,
              icon: Icons.savings_outlined,
            ),
          ], spacing: 12),
          const SizedBox(height: 24),

          // ---------------------------------------------------------------------
          // LEVEL 9: Today's Repayment Status & Overdue Arrears (Desktop & Tablet)
          // ---------------------------------------------------------------------
          const IcareSectionHeader(
            title: "Today's Repayment Status & Overdue Arrears",
          ),
          const SizedBox(height: 8),
          _buildResponsiveCardRow([
            IcareMetricCard(
              label: 'Full Payoff',
              value: CurrencyFormatter.formatNaira((stCards['full_payment']?['amount'] as num?)?.toDouble() ?? 0.0),
              delta: '${stCards['full_payment']?['count'] ?? 0} Loans Settled',
              topBorderColor: IcareColors.metricPayoff,
            ),
            if (stCards['normal_payment'] != null)
              IcareMetricCard(
                label: 'Normal Payment',
                value: CurrencyFormatter.formatNaira((stCards['normal_payment']?['amount'] as num?)?.toDouble() ?? 0.0),
                delta: '${stCards['normal_payment']?['count'] ?? 0} On-Schedule',
                topBorderColor: tokens.brandPrimary,
              ),
            IcareMetricCard(
              label: 'Excess Payment',
              value: CurrencyFormatter.formatNaira((stCards['excess_payment']?['amount'] as num?)?.toDouble() ?? 0.0),
              delta: '${stCards['excess_payment']?['count'] ?? 0} Surplus Payers',
              topBorderColor: IcareColors.metricExcess,
            ),
            IcareMetricCard(
              label: 'Part Payment',
              value: CurrencyFormatter.formatNaira((stCards['part_payment']?['amount'] as num?)?.toDouble() ?? 0.0),
              delta: '${stCards['part_payment']?['count'] ?? 0} Underpayers',
              topBorderColor: IcareColors.metricPart,
            ),
            IcareMetricCard(
              label: 'Not Paid (Today)',
              value: CurrencyFormatter.formatNaira((stCards['not_paid']?['amount'] as num?)?.toDouble() ?? 0.0),
              delta: '${stCards['not_paid']?['count'] ?? 0} Non-Payers',
              isInverseDelta: true,
              topBorderColor: IcareColors.metricNotPaid,
            ),
            if (stCards['overdue_arrears'] != null)
              IcareMetricCard(
                label: 'Overdue Arrears',
                value: CurrencyFormatter.formatNaira((stCards['overdue_arrears']?['amount'] as num?)?.toDouble() ?? 0.0),
                delta: '${stCards['overdue_arrears']?['count'] ?? 0} Clients · ${data.overduePortfolio['overdue_groups_count'] ?? 0} Groups',
                isInverseDelta: true,
                topBorderColor: IcareColors.metricArrears,
              ),
          ], spacing: 12),
          const SizedBox(height: 24),

          // ---------------------------------------------------------------------
          // LEVEL 10: Cash Position (CO Cashbook - Desktop & Tablet)
          // ---------------------------------------------------------------------
          const IcareSectionHeader(
            title: "Cash Position (CO Cashbook)",
          ),
          const SizedBox(height: 8),
          _buildResponsiveCardRow([
            IcareMetricCard(
              label: 'Opening Vault',
              value: CurrencyFormatter.formatNaira((cp['opening_balance'] as num?)?.toDouble() ?? 0.0),
              icon: Icons.lock_clock_outlined,
            ),
            IcareMetricCard(
              label: 'Cash Inflow',
              value: CurrencyFormatter.formatNaira((cp['cash_in'] as num?)?.toDouble() ?? 0.0),
              icon: Icons.file_download_outlined,
            ),
            IcareMetricCard(
              label: 'Cash Outflow',
              value: CurrencyFormatter.formatNaira((cp['cash_out'] as num?)?.toDouble() ?? 0.0),
              icon: Icons.file_upload_outlined,
            ),
            IcareMetricCard(
              label: 'Closing Balance',
              value: CurrencyFormatter.formatNaira((cp['closing_balance'] as num?)?.toDouble() ?? 0.0),
              icon: Icons.account_balance_outlined,
            ),
          ], spacing: 12),
          const SizedBox(height: 12),
          _buildResponsiveCardRow([
            IcareCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CASHBOOK SETTLEMENT STATUS',
                        style: IcareTypography.cardLabel.copyWith(color: tokens.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _cleanStatusText(cp['status']?.toString() ?? 'Balanced'),
                        style: IcareTypography.metricValueCompact.copyWith(
                          color: (cp['status']?.toString().toLowerCase().contains('unbal') ?? false)
                              ? tokens.dangerText
                              : tokens.successText,
                        ),
                      ),
                    ],
                  ),
                  IcareStatusBadge.fromStatus(cp['status']?.toString() ?? 'Balanced'),
                ],
              ),
            ),
            IcareMetricCard(
              label: 'Cashbook Difference',
              value: CurrencyFormatter.formatNaira((cp['difference'] as num?)?.toDouble() ?? 0.0),
              statusTextColor: ((cp['difference'] as num?)?.toDouble() ?? 0.0) != 0.0
                  ? tokens.dangerText
                  : tokens.successText,
              icon: Icons.compare_arrows_outlined,
            ),
          ], spacing: 12),
          const SizedBox(height: 24),

          // ---------------------------------------------------------------------
          // LEVEL 11: Today's Attention List (Desktop & Tablet)
          // ---------------------------------------------------------------------
          const IcareSectionHeader(
            title: "Today's Attention List",
          ),
          const SizedBox(height: 8),
          if (attList.isNotEmpty) ...[
            _buildAttentionListTable(attList),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: tokens.successBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.successBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: tokens.successDot, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All scheduled clients have completed full repayments for today.',
                      style: TextStyle(
                        color: tokens.successText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  // ===========================================================================
  // MOBILE SEGMENTED OPERATIONAL HUB
  // Eliminates mobile long scrolling by organizing operations into 4 tabs:
  // 0: Meetings, 1: Performance, 2: Cashbook, 3: Attention
  // ===========================================================================

  Widget _buildMobileSegmentedHub(BuildContext context, WidgetRef ref, CoDashboardData data) {
    final tokens = IcareSurfaceTokens.of(context);
    final currentTab = ref.watch(coDashboardMobileTabProvider);
    final mPort = data.meetingPortfolio;
    final attList = data.attentionList;

    Widget tabContent;
    switch (currentTab) {
      case 0:
        tabContent = _buildMobileTabMeetings(context, ref, data);
        break;
      case 1:
        tabContent = _buildMobileTabPerformance(context, ref, data);
        break;
      case 2:
        tabContent = _buildMobileTabCashPosition(context, ref, data);
        break;
      case 3:
      default:
        tabContent = _buildMobileTabAttention(context, ref, data);
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'OPERATIONAL HUB',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              'Tap tab to switch',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: tokens.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // High-contrast tactile segmented tab bar
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
            child: Row(
              children: [
                _buildSegmentPill(
                  tokens: tokens,
                  ref: ref,
                  index: 0,
                  currentIndex: currentTab,
                  label: 'Meetings',
                  icon: Icons.groups_outlined,
                  badgeCount: mPort.length,
                ),
                const SizedBox(width: 4),
                _buildSegmentPill(
                  tokens: tokens,
                  ref: ref,
                  index: 1,
                  currentIndex: currentTab,
                  label: 'Performance',
                  icon: Icons.insights_outlined,
                ),
                const SizedBox(width: 4),
                _buildSegmentPill(
                  tokens: tokens,
                  ref: ref,
                  index: 2,
                  currentIndex: currentTab,
                  label: 'Cashbook',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(width: 4),
                _buildSegmentPill(
                  tokens: tokens,
                  ref: ref,
                  index: 3,
                  currentIndex: currentTab,
                  label: 'Attention',
                  icon: Icons.notification_important_outlined,
                  badgeCount: attList.length,
                  isAlertBadge: attList.isNotEmpty,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Active Tab Body
        tabContent,
      ],
    );
  }

  Widget _buildSegmentPill({
    required IcareSurfaceTokens tokens,
    required WidgetRef ref,
    required int index,
    required int currentIndex,
    required String label,
    required IconData icon,
    int? badgeCount,
    bool isAlertBadge = false,
  }) {
    final isSelected = index == currentIndex;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(coDashboardMobileTabProvider.notifier).state = index;
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? tokens.surfaceElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: tokens.borderSubtle) : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: tokens.isDark ? 0.18 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? tokens.brandPrimary : tokens.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? tokens.textPrimary : tokens.textMuted,
                ),
              ),
              if (badgeCount != null && badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAlertBadge
                        ? tokens.dangerBg
                        : (isSelected ? tokens.brandSoftBg : tokens.neutralBg),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isAlertBadge
                          ? tokens.dangerText
                          : (isSelected ? tokens.brandSoftText : tokens.textSecondary),
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

  Widget _buildMobileTabMeetings(BuildContext context, WidgetRef ref, CoDashboardData data) {
    final tokens = IcareSurfaceTokens.of(context);
    final mPort = data.meetingPortfolio;
    final isClosed = data.branchClosure['is_closed'] == true;
    if (mPort.isEmpty) {
      return _buildInfoBox('No active groups scheduled for today.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMobileMeetingCards(mPort, ref, isClosed: isClosed),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: Icon(isClosed ? Icons.lock_clock_outlined : Icons.payments_outlined, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.brandPrimaryDark,
              foregroundColor: Colors.white,
              disabledBackgroundColor: tokens.surfaceSubtle,
              disabledForegroundColor: tokens.textMuted,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: isClosed
                ? null
                : () {
                    ref.read(activeCoPageProvider.notifier).state = 'Collections';
                  },
            label: Text(
              isClosed ? 'Branch Closed — Collections Locked' : 'Go to Collections Batch',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTabPerformance(BuildContext context, WidgetRef ref, CoDashboardData data) {
    final tokens = IcareSurfaceTokens.of(context);
    final repS = data.repaymentSummary;
    final sav = data.savings;
    final stCards = data.repaymentStatus;

    final totalCollected = (repS['total_collected_today'] as num?)?.toDouble() ?? 0.0;
    final rep12Amt = (repS['rep_12_weeks_amt'] as num?)?.toDouble() ?? 0.0;
    final rep12Clients = (repS['rep_12_weeks_clients'] as num?)?.toInt() ?? 0;
    final rep24Amt = (repS['rep_24_weeks_amt'] as num?)?.toDouble() ?? 0.0;
    final rep24Clients = (repS['rep_24_weeks_clients'] as num?)?.toInt() ?? 0;
    final rep120dAmt = (repS['rep_120_days_amt'] as num?)?.toDouble() ?? 0.0;
    final rep120dClients = (repS['rep_120_days_clients'] as num?)?.toInt() ?? 0;
    final repDailyAmt = (repS['rep_daily_amt'] as num?)?.toDouble() ?? 0.0;
    final repDailyClients = (repS['rep_daily_clients'] as num?)?.toInt() ?? 0;
    final repMonthlyAmt = (repS['rep_monthly_amt'] as num?)?.toDouble() ?? 0.0;
    final repMonthlyClients = (repS['rep_monthly_clients'] as num?)?.toInt() ?? 0;
    final totalPayingClients = rep12Clients + rep24Clients + rep120dClients + repDailyClients + repMonthlyClients;

    final depAmt = (sav['deposited_amt'] as num?)?.toDouble() ?? 0.0;
    final depClients = (sav['deposited_clients'] as num?)?.toInt() ?? 0;
    final wdAmt = (sav['withdrawn_amt'] as num?)?.toDouble() ?? 0.0;
    final wdClients = (sav['withdrawn_clients'] as num?)?.toInt() ?? 0;
    final netSav = (sav['net_savings'] as num?)?.toDouble() ?? 0.0;

    final fullPay = stCards['full_payment'];
    final normalPay = stCards['normal_payment'];
    final excessPay = stCards['excess_payment'];
    final partPay = stCards['part_payment'];
    final notPaid = stCards['not_paid'];
    final arrears = stCards['overdue_arrears'];
    final overdueGroupsCount = (data.overduePortfolio['overdue_groups_count'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Repayment Summary
        Text(
          'REPAYMENT SUMMARY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.brandPrimaryDark,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL REPAYMENT TODAY',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.formatNaira(totalCollected),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalPayingClients Clients',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                tokens: tokens,
                label: 'Daily (60D)',
                value: CurrencyFormatter.formatNaira(repDailyAmt),
                subtext: '$repDailyClients Paid',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniStatCard(
                tokens: tokens,
                label: '12 Weeks (Weekly)',
                value: CurrencyFormatter.formatNaira(rep12Amt),
                subtext: '$rep12Clients Paid',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                tokens: tokens,
                label: '24 Weeks (Weekly)',
                value: CurrencyFormatter.formatNaira(rep24Amt),
                subtext: '$rep24Clients Paid',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniStatCard(
                tokens: tokens,
                label: 'Daily (120D)',
                value: CurrencyFormatter.formatNaira(rep120dAmt),
                subtext: '$rep120dClients Paid',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildMiniStatCard(
          tokens: tokens,
          label: 'Monthly (3M / 6M)',
          value: CurrencyFormatter.formatNaira(repMonthlyAmt),
          subtext: '$repMonthlyClients Paid',
        ),
        const SizedBox(height: 16),

        // Savings Breakdown
        Text(
          'SAVINGS BREAKDOWN',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                tokens: tokens,
                label: 'Deposited',
                value: CurrencyFormatter.formatNaira(depAmt),
                subtext: '$depClients Clients',
                valueColor: tokens.brandPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniStatCard(
                tokens: tokens,
                label: 'Withdrawn',
                value: CurrencyFormatter.formatNaira(wdAmt),
                subtext: '$wdClients Clients',
                valueColor: tokens.dangerText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildMiniStatCard(
          tokens: tokens,
          label: 'Net Savings Today',
          value: CurrencyFormatter.formatNaira(netSav),
          subtext: 'Inflow minus outflow',
          valueColor: tokens.successText,
        ),
        const SizedBox(height: 16),

        // Repayment Status & Arrears
        Text(
          'STATUS & OVERDUE BREAKDOWN',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                tokens: tokens,
                label: 'Full Payoff',
                value: CurrencyFormatter.formatNaira((fullPay?['amount'] as num?)?.toDouble() ?? 0.0),
                subtext: '${fullPay?['count'] ?? 0} Settled',
                topAccent: IcareColors.metricPayoff,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniStatCard(
                tokens: tokens,
                label: 'Normal Payment',
                value: CurrencyFormatter.formatNaira((normalPay?['amount'] as num?)?.toDouble() ?? 0.0),
                subtext: '${normalPay?['count'] ?? 0} On-Schedule',
                topAccent: tokens.brandPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                tokens: tokens,
                label: 'Excess Payment',
                value: CurrencyFormatter.formatNaira((excessPay?['amount'] as num?)?.toDouble() ?? 0.0),
                subtext: '${excessPay?['count'] ?? 0} Surplus',
                topAccent: IcareColors.metricExcess,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniStatCard(
                tokens: tokens,
                label: 'Part Payment',
                value: CurrencyFormatter.formatNaira((partPay?['amount'] as num?)?.toDouble() ?? 0.0),
                subtext: '${partPay?['count'] ?? 0} Underpaid',
                topAccent: IcareColors.metricPart,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildMiniStatCard(
          tokens: tokens,
          label: 'Not Paid',
          value: CurrencyFormatter.formatNaira((notPaid?['amount'] as num?)?.toDouble() ?? 0.0),
          subtext: '${notPaid?['count'] ?? 0} Clients',
          topAccent: IcareColors.metricNotPaid,
        ),
        if (arrears != null) ...[
          const SizedBox(height: 8),
          _buildMiniStatCard(
            tokens: tokens,
            label: 'Overdue Arrears',
            value: CurrencyFormatter.formatNaira((arrears['amount'] as num?)?.toDouble() ?? 0.0),
            subtext: '${arrears['count'] ?? 0} Past Due Clients · $overdueGroupsCount Groups',
            topAccent: IcareColors.metricArrears,
            valueColor: tokens.dangerText,
          ),
        ],
      ],
    );
  }

  Widget _buildMobileTabCashPosition(BuildContext context, WidgetRef ref, CoDashboardData data) {
    final tokens = IcareSurfaceTokens.of(context);
    final cp = data.cashPosition;
    final opening = (cp['opening_balance'] as num?)?.toDouble() ?? 0.0;
    final cashIn = (cp['cash_in'] as num?)?.toDouble() ?? 0.0;
    final cashOut = (cp['cash_out'] as num?)?.toDouble() ?? 0.0;
    final closing = (cp['closing_balance'] as num?)?.toDouble() ?? 0.0;
    final diff = (cp['difference'] as num?)?.toDouble() ?? 0.0;
    final status = cp['status']?.toString() ?? 'Balanced';
    final isUnbalanced = status.toLowerCase().contains('unbal');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                tokens: tokens,
                label: 'Opening Vault',
                value: CurrencyFormatter.formatNaira(opening),
                subtext: 'B/F Balance',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniStatCard(
                tokens: tokens,
                label: 'Cash Inflow',
                value: CurrencyFormatter.formatNaira(cashIn),
                subtext: 'Collections & Fees',
                valueColor: tokens.brandPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                tokens: tokens,
                label: 'Cash Outflow',
                value: CurrencyFormatter.formatNaira(cashOut),
                subtext: 'Disbursements & W/D',
                valueColor: tokens.dangerText,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniStatCard(
                tokens: tokens,
                label: 'Closing Balance',
                value: CurrencyFormatter.formatNaira(closing),
                subtext: 'Primary Vault Ledger',
                valueColor: tokens.infoText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Settlement Status Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SETTLEMENT STATUS',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _cleanStatusText(status),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isUnbalanced ? tokens.dangerText : tokens.successText,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'DIFFERENCE',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.formatNaira(diff),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: diff != 0.0 ? tokens.dangerText : tokens.successText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              ref.read(activeCoPageProvider.notifier).state = 'CO Cashbook';
            },
            label: const Text(
              'Open Full CO Cashbook',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTabAttention(BuildContext context, WidgetRef ref, CoDashboardData data) {
    final tokens = IcareSurfaceTokens.of(context);
    final attList = data.attentionList;
    if (attList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tokens.successBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.successBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: tokens.successDot, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'All scheduled clients have completed full repayments for today.',
                style: TextStyle(
                  color: tokens.successText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final searchQuery = ref.watch(coDashboardAttentionSearchProvider).toLowerCase().trim();
    final showAll = ref.watch(coDashboardAttentionShowAllProvider);

    final filtered = attList.where((r) {
      if (searchQuery.isEmpty) return true;
      final cName = (r['Client Name'] ?? r['client_name'] ?? '').toString().toLowerCase();
      final gName = (r['Group'] ?? r['group_name'] ?? '').toString().toLowerCase();
      return cName.contains(searchQuery) || gName.contains(searchQuery);
    }).toList();

    final displayList = showAll ? filtered : filtered.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        const _AttentionSearchBar(),
        const SizedBox(height: 10),

        // Count strip
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Flagged Clients: ${filtered.length}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            if (filtered.length > 10)
              Text(
                showAll ? 'Showing all' : 'Showing top 10',
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (displayList.isEmpty)
          _buildInfoBox('No flagged clients match "$searchQuery".')
        else
          ...displayList.map((r) => _buildMobileAttentionCard(tokens, r, ref)),

        if (filtered.length > 10) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: tokens.borderStrong),
              ),
              onPressed: () {
                ref.read(coDashboardAttentionShowAllProvider.notifier).state = !showAll;
              },
              child: Text(
                showAll ? 'Show Top 10 Only' : 'View All ${filtered.length} Flagged Clients',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMobileAttentionCard(IcareSurfaceTokens tokens, Map<String, dynamic> r, WidgetRef ref) {
    final clientName = (r['Client Name'] ?? r['client_name'] ?? '').toString();
    final group = (r['Group'] ?? r['group_name'] ?? '').toString();
    final expected = (r['Expected (₦)'] ??
            r['Expected'] ??
            r['expected_amount'] as num?)
        ?.toDouble() ??
        0.0;
    final paid = (r['Paid (₦)'] ?? r['Paid'] ?? r['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final shortfall =
        (r['Shortfall (₦)'] ?? r['Shortfall'] ?? r['shortfall'] as num?)?.toDouble() ?? 0.0;
    final status =
        (r['Status'] ?? r['Issue Type'] ?? r['issue_type'] ?? r['status'] ?? 'Shortfall').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group,
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IcareStatusBadge.fromStatus(status),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMicroStat(tokens, 'Expected', CurrencyFormatter.formatNaira(expected), tokens.textSecondary),
                _buildMicroStat(tokens, 'Paid', CurrencyFormatter.formatNaira(paid), tokens.brandPrimary),
                _buildMicroStat(tokens, 'Shortfall', CurrencyFormatter.formatNaira(shortfall), tokens.dangerText),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroStat(IcareSurfaceTokens tokens, String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: tokens.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required IcareSurfaceTokens tokens,
    required String label,
    required String value,
    required String subtext,
    Color? valueColor,
    Color? topAccent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topAccent != null) ...[
            Container(
              width: 24,
              height: 3,
              decoration: BoxDecoration(
                color: topAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: tokens.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: valueColor ?? tokens.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: tokens.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODERNIZED PRESENTATION WIDGETS
  // ===========================================================================

  /// Hero Vault Cash Card (Account 1000 & Collections Target)
  Widget _buildHeroVaultCard({
    required Map<String, dynamic> cp,
    required Map<String, dynamic> repS,
    required List<Map<String, dynamic>> mPort,
    required bool isMobile,
  }) {
    final closingBalance = (cp['closing_balance'] as num?)?.toDouble() ?? 0.0;
    final totalCollected = (repS['total_collected_today'] as num?)?.toDouble() ?? 0.0;

    double totalExpected = 0.0;
    for (final m in mPort) {
      totalExpected += (m['Expected (₦)'] ??
              m['Expected Collection'] ??
              m['expected_repayment'] ??
              m['Expected'] as num?)
          ?.toDouble() ??
          0.0;
    }

    final progress = totalExpected > 0
        ? (totalCollected / totalExpected).clamp(0.0, 1.0)
        : (totalCollected > 0 ? 1.0 : 0.0);
    final remaining = totalExpected > totalCollected ? totalExpected - totalCollected : 0.0;

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
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33064E3B),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle ambient decorative circle
          Positioned(
            right: -24,
            bottom: -24,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x0AFFFFFF),
              ),
            ),
          ),
          Positioned(
            left: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x0F8CC63F),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 18 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header tag: Account 1000 + Live Ledger
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF8CC63F),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'PRIMARY VAULT CASH',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFA7F3D0),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0x1FFFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x26FFFFFF)),
                      ),
                      child: const Text(
                        'Live Ledger',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD1FAE5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Hero Value
                const Text(
                  'Physical Cash in Custody',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6EE7B7),
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: '₦ ',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8CC63F),
                        ),
                      ),
                      TextSpan(
                        text: CurrencyFormatter.formatNaira(closingBalance, showDecimals: true)
                            .replaceAll('₦', '')
                            .trim(),
                        style: TextStyle(
                          fontSize: isMobile ? 30 : 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Circular Target Progress Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x38000000),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x1FFFFFFF)),
                  ),
                  child: Row(
                    children: [
                      // Circular Progress
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 4,
                              backgroundColor: const Color(0x26FFFFFF),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8CC63F)),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF8CC63F),
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
                              'Daily Collections Target',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFA7F3D0),
                              ),
                            ),
                            const SizedBox(height: 2),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: CurrencyFormatter.formatNaira(totalCollected),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' / ${CurrencyFormatter.formatNaira(totalExpected)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF6EE7B7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: progress >= 1.0 && totalExpected > 0
                              ? const Color(0x338CC63F)
                              : const Color(0x1FFFFFFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: progress >= 1.0 && totalExpected > 0
                                ? const Color(0x668CC63F)
                                : const Color(0x26FFFFFF),
                          ),
                        ),
                        child: Text(
                          progress >= 1.0 && totalExpected > 0
                              ? 'Target Met'
                              : '${CurrencyFormatter.formatNaira(remaining)} Left',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8CC63F),
                          ),
                        ),
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

  /// Tactile Quick Action Navigation Shortcuts
  Widget _buildQuickActionShortcuts(
    BuildContext context,
    WidgetRef ref, {
    bool isClosed = false,
    String closureReason = '',
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    final isMobile = IcareSpacing.isMobile(context);

    if (isMobile) {
      return Row(
        children: [
          Expanded(
            child: _buildActionShortcutIconButton(
              tokens: tokens,
              icon: isClosed ? Icons.lock_clock_outlined : Icons.payments_outlined,
              iconBg: isClosed ? tokens.surfaceSubtle : tokens.successBg,
              iconColor: isClosed ? tokens.textMuted : tokens.successText,
              tooltip: isClosed
                  ? 'Collections locked ($closureReason)'
                  : 'Collections (Post batch)',
              onTap: isClosed
                  ? null
                  : () {
                      ref.read(activeCoPageProvider.notifier).state = 'Collections';
                    },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildActionShortcutIconButton(
              tokens: tokens,
              icon: Icons.person_add_alt_1_outlined,
              iconBg: tokens.infoBg,
              iconColor: tokens.infoText,
              tooltip: 'Onboarding (Register client)',
              onTap: () {
                ref.read(activeCoPageProvider.notifier).state = 'Loan Origination';
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildActionShortcutIconButton(
              tokens: tokens,
              icon: Icons.account_balance_wallet_outlined,
              iconBg: tokens.warningBg,
              iconColor: tokens.warningText,
              tooltip: 'Cashbook (EOD Balance)',
              onTap: () {
                ref.read(activeCoPageProvider.notifier).state = 'CO Cashbook';
              },
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildActionShortcutCard(
            tokens: tokens,
            icon: isClosed ? Icons.lock_clock_outlined : Icons.payments_outlined,
            iconBg: isClosed ? tokens.surfaceSubtle : tokens.successBg,
            iconColor: isClosed ? tokens.textMuted : tokens.successText,
            title: 'Collections',
            subtitle: isClosed ? 'Closed today' : 'Post batch',
            onTap: isClosed
                ? null
                : () {
                    ref.read(activeCoPageProvider.notifier).state = 'Collections';
                  },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionShortcutCard(
            tokens: tokens,
            icon: Icons.person_add_alt_1_outlined,
            iconBg: tokens.infoBg,
            iconColor: tokens.infoText,
            title: 'Onboarding',
            subtitle: 'Register client',
            onTap: () {
              ref.read(activeCoPageProvider.notifier).state = 'Loan Origination';
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionShortcutCard(
            tokens: tokens,
            icon: Icons.account_balance_wallet_outlined,
            iconBg: tokens.warningBg,
            iconColor: tokens.warningText,
            title: 'Cashbook',
            subtitle: 'EOD Balance',
            onTap: () {
              ref.read(activeCoPageProvider.notifier).state = 'CO Cashbook';
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionShortcutIconButton({
    required IcareSurfaceTokens tokens,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: disabled ? 0.65 : 1.0,
        child: Material(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tokens.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 19),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionShortcutCard({
    required IcareSurfaceTokens tokens,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.65 : 1.0,
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: tokens.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 2x2 Responsive Portfolio Health Grid
  Widget _buildPortfolioHealthGrid(BuildContext context, CoDashboardData data) {
    final tokens = IcareSurfaceTokens.of(context);
    final repS = data.repaymentSummary;
    final sav = data.savings;
    final stCards = data.repaymentStatus;
    final cp = data.cashPosition;
    final mPort = data.meetingPortfolio;

    final totalCollected = (repS['total_collected_today'] as num?)?.toDouble() ?? 0.0;
    final clientsPaid = ((repS['rep_12_weeks_clients'] as num?)?.toInt() ?? 0) +
        ((repS['rep_24_weeks_clients'] as num?)?.toInt() ?? 0) +
        ((repS['rep_120_days_clients'] as num?)?.toInt() ?? 0) +
        ((repS['rep_daily_clients'] as num?)?.toInt() ?? 0) +
        ((repS['rep_monthly_clients'] as num?)?.toInt() ?? 0);

    final netSavings = (sav['net_savings'] as num?)?.toDouble() ?? 0.0;
    final depClients = (sav['deposited_clients'] as num?)?.toInt() ?? 0;
    final wdClients = (sav['withdrawn_clients'] as num?)?.toInt() ?? 0;

    final closingVault = (cp['closing_balance'] as num?)?.toDouble() ?? 0.0;
    final cpStatus = _cleanStatusText(cp['status']?.toString() ?? 'Balanced');

    final arrearsAmt = (stCards['overdue_arrears']?['amount'] as num?)?.toDouble() ?? 0.0;
    final arrearsCount = (stCards['overdue_arrears']?['count'] as num?)?.toInt() ?? 0;
    final overdueGroupsCount = (data.overduePortfolio['overdue_groups_count'] as num?)?.toInt() ?? 0;

    int totalClientsExpected = 0;
    for (final m in mPort) {
      final rawExp = m['Clients Expected'] ?? m['clients_expected'];
      if (rawExp is num) {
        totalClientsExpected += rawExp.toInt();
      }
    }

    final isMobile = IcareSpacing.isMobile(context);

    final cardRepayments = _buildPortfolioHealthCard(
      tokens: tokens,
      label: 'Repayments Today',
      value: CurrencyFormatter.formatNaira(totalCollected),
      subtext: '$clientsPaid clients paid',
      accentColor: tokens.brandPrimary,
    );

    final cardSavings = _buildPortfolioHealthCard(
      tokens: tokens,
      label: 'Net Savings Today',
      value: CurrencyFormatter.formatNaira(netSavings),
      subtext: '$depClients dep · $wdClients w/d',
      accentColor: const Color(0xFF8CC63F),
    );

    final cardVault = _buildPortfolioHealthCard(
      tokens: tokens,
      label: 'Vault Balance',
      value: CurrencyFormatter.formatNaira(closingVault),
      subtext: 'Status: $cpStatus',
      accentColor: tokens.infoText,
    );

    final cardArrears = _buildPortfolioHealthCard(
      tokens: tokens,
      label: 'Overdue Arrears',
      value: CurrencyFormatter.formatNaira(arrearsAmt),
      subtext: overdueGroupsCount > 0
          ? '$arrearsCount clients · $overdueGroupsCount groups'
          : '$arrearsCount clients flagged',
      accentColor: tokens.dangerDot,
      isAlert: arrearsAmt > 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PORTFOLIO HEALTH',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                letterSpacing: 0.6,
              ),
            ),
            if (totalClientsExpected > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.successBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.successBorder),
                ),
                child: Text(
                  '$totalClientsExpected Clients Scheduled',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tokens.successText,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (isMobile)
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: cardRepayments),
                  const SizedBox(width: 10),
                  Expanded(child: cardSavings),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: cardVault),
                  const SizedBox(width: 10),
                  Expanded(child: cardArrears),
                ],
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(child: cardRepayments),
              const SizedBox(width: 12),
              Expanded(child: cardSavings),
              const SizedBox(width: 12),
              Expanded(child: cardVault),
              const SizedBox(width: 12),
              Expanded(child: cardArrears),
            ],
          ),
      ],
    );
  }

  Widget _buildPortfolioHealthCard({
    required IcareSurfaceTokens tokens,
    required String label,
    required String value,
    required String subtext,
    required Color accentColor,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isAlert ? tokens.dangerBg : tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert ? tokens.dangerBorder : tokens.borderSubtle,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isAlert ? tokens.dangerText : tokens.textMuted,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isAlert ? tokens.dangerText : tokens.textPrimary,
              letterSpacing: -0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isAlert ? tokens.dangerText.withValues(alpha: 0.9) : tokens.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Mobile Native Meeting Cards (eliminating wide spreadsheets on small screens)
  Widget _buildMobileMeetingCards(
    List<Map<String, dynamic>> rows,
    WidgetRef ref, {
    bool isClosed = false,
  }) {
    return Builder(
      builder: (context) {
        final tokens = IcareSurfaceTokens.of(context);
        return Column(
          children: rows.asMap().entries.map((entry) {
            final idx = entry.key;
            final r = entry.value;
            final gName = (r['Group Name'] ?? r['group_name'] ?? '').toString();
            final expected = (r['Expected (₦)'] ??
                    r['Expected Collection'] ??
                    r['expected_repayment'] ??
                    r['Expected'] as num?)
                ?.toDouble() ??
                0.0;
            final collected = (r['Collected (₦)'] ??
                    r['Collected'] ??
                    r['collected_repayment'] as num?)
                ?.toDouble() ??
                0.0;
            final rawStatus = (r['Status'] ?? r['status'] ?? 'Scheduled').toString();
            final cleanStatus = _cleanStatusText(rawStatus);
            final meetingDay = (r['Meeting Day'] ?? r['meeting_day'] ?? 'Today').toString();
            final clientsExpected = (r['Clients Expected'] ?? r['clients_expected'] as num?)?.toInt() ?? 0;
            final isCompleted = cleanStatus.toLowerCase() == 'completed' || (expected > 0 && collected >= expected);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Accent Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                      border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCompleted ? tokens.successDot : tokens.infoText,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      gName,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Schedule: $meetingDay',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: tokens.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCompleted ? tokens.successBg : tokens.infoBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCompleted ? tokens.successBorder : tokens.infoBorder,
                            ),
                          ),
                          child: Text(
                            clientsExpected > 0 ? '$clientsExpected Members' : cleanStatus,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isCompleted ? tokens.successText : tokens.infoText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Body stats
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: tokens.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: tokens.borderSubtle),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Expected Target',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.formatNaira(expected),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: tokens.successBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: tokens.successBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Collected So Far',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.successText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.formatNaira(collected),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.successText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // One-tap launch button
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton.icon(
                            key: Key('mobile_start_grp_$idx'),
                            onPressed: isClosed
                                ? null
                                : () {
                                    ref.read(selectedCollectionGroupProvider.notifier).state = gName;
                                    ref.read(activeCoPageProvider.notifier).state = 'Collections';
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tokens.brandPrimaryDark,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: tokens.surfaceSubtle,
                              disabledForegroundColor: tokens.textMuted,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(isClosed ? Icons.lock_clock_outlined : Icons.play_circle_outline, size: 16),
                            label: Text(
                              isClosed ? 'Branch Closed Today' : 'Open Collection Sheet ($cleanStatus)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Responsive card row layout:
  /// - Desktop (>= 900px): 1 row with Expanded children & IntrinsicHeight
  /// - Tablet (600px - 899px): 2-card row or 2x2 grid
  /// - Mobile (< 600px): Balanced 2-column grid with IntrinsicHeight
  Widget _buildResponsiveCardRow(List<Widget> cards, {double spacing = 12}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        if (availableWidth >= 900) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) SizedBox(width: spacing),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
          );
        } else if (availableWidth >= 600) {
          if (cards.length == 2) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[0]),
                  SizedBox(width: spacing),
                  Expanded(child: cards[1]),
                ],
              ),
            );
          } else if (cards.length == 3 && availableWidth >= 720) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[0]),
                  SizedBox(width: spacing),
                  Expanded(child: cards[1]),
                  SizedBox(width: spacing),
                  Expanded(child: cards[2]),
                ],
              ),
            );
          } else if (cards.length == 4) {
            return Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[0]),
                      SizedBox(width: spacing),
                      Expanded(child: cards[1]),
                    ],
                  ),
                ),
                SizedBox(height: spacing),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[2]),
                      SizedBox(width: spacing),
                      Expanded(child: cards[3]),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) SizedBox(height: spacing),
                  SizedBox(width: double.infinity, child: cards[i]),
                ],
              ],
            );
          }
        } else {
          // Mobile (< 600px): Balanced 2-column grid
          if (cards.length == 2) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[0]),
                  SizedBox(width: spacing),
                  Expanded(child: cards[1]),
                ],
              ),
            );
          } else if (cards.length == 3) {
            return Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[0]),
                      SizedBox(width: spacing),
                      Expanded(child: cards[1]),
                    ],
                  ),
                ),
                SizedBox(height: spacing),
                SizedBox(width: double.infinity, child: cards[2]),
              ],
            );
          } else if (cards.length == 4) {
            return Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[0]),
                      SizedBox(width: spacing),
                      Expanded(child: cards[1]),
                    ],
                  ),
                ),
                SizedBox(height: spacing),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[2]),
                      SizedBox(width: spacing),
                      Expanded(child: cards[3]),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) SizedBox(height: spacing),
                  SizedBox(width: double.infinity, child: cards[i]),
                ],
              ],
            );
          }
        }
      },
    );
  }

  /// Meeting Portfolio Institutional Data Table (Desktop & Tablet)
  Widget _buildMeetingPortfolioTable(List<Map<String, dynamic>> rows) {
    return Builder(
      builder: (context) {
        final tokens = IcareSurfaceTokens.of(context);
        return IcareDataTable(
          minWidth: 580,
          columns: const [
            DataColumn(label: Text('Group Name')),
            DataColumn(label: Text('Expected (₦)'), numeric: true),
            DataColumn(label: Text('Collected (₦)'), numeric: true),
            DataColumn(label: Text('Outstanding (₦)'), numeric: true),
            DataColumn(label: Text('Compliance')),
            DataColumn(label: Text('Status')),
          ],
          rows: rows.map((r) {
            final groupName = (r['Group Name'] ?? r['group_name'] ?? '').toString();
            final expected = (r['Expected (₦)'] ??
                    r['Expected Collection'] ??
                    r['expected_repayment'] ??
                    r['Expected'] as num?)
                ?.toDouble() ??
                0.0;
            final collected = (r['Collected (₦)'] ??
                    r['Collected'] ??
                    r['collected_repayment'] as num?)
                ?.toDouble() ??
                0.0;
            final outstanding = (r['Outstanding (₦)'] ??
                    r['Outstanding'] ??
                    r['outstanding_repayment'] as num?)
                ?.toDouble() ??
                0.0;
            final complianceVal = r['Compliance'] ?? r['Compliance %'] ?? r['repayment_rate_pct'];
            final complianceStr = complianceVal is num
                ? '${complianceVal.toStringAsFixed(1)}%'
                : complianceVal?.toString() ?? '100.0%';
            final status = (r['Status'] ?? r['status'] ?? 'Completed').toString();

            return DataRow(cells: [
              DataCell(Text(groupName, style: IcareTypography.bodyBold.copyWith(color: tokens.textPrimary))),
              DataCell(Text(CurrencyFormatter.formatNaira(expected), style: IcareTypography.tableFinancialNumber.copyWith(color: tokens.textPrimary))),
              DataCell(Text(
                CurrencyFormatter.formatNaira(collected),
                style: IcareTypography.tableFinancialNumber.copyWith(color: tokens.brandPrimary),
              )),
              DataCell(Text(CurrencyFormatter.formatNaira(outstanding), style: IcareTypography.tableFinancialNumber.copyWith(color: tokens.textPrimary))),
              DataCell(Text(complianceStr, style: IcareTypography.bodyBold.copyWith(color: tokens.textPrimary))),
              DataCell(IcareStatusBadge.fromStatus(status)),
            ]);
          }).toList(),
        );
      },
    );
  }

  /// Attention List Institutional Data Table
  Widget _buildAttentionListTable(List<Map<String, dynamic>> rows) {
    return Builder(
      builder: (context) {
        final tokens = IcareSurfaceTokens.of(context);
        return IcareDataTable(
          minWidth: 740,
          columns: const [
            DataColumn(label: Text('Client Name')),
            DataColumn(label: Text('Client Code')),
            DataColumn(label: Text('Group')),
            DataColumn(label: Text('Expected (₦)'), numeric: true),
            DataColumn(label: Text('Paid (₦)'), numeric: true),
            DataColumn(label: Text('Shortfall (₦)'), numeric: true),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Action')),
          ],
          rows: rows.map((r) {
            final clientName = (r['Client Name'] ?? r['client_name'] ?? '').toString();
            final clientCode = (r['Client Code'] ?? r['client_code'] ?? '').toString();
            final group = (r['Group'] ?? r['group_name'] ?? '').toString();
            final expected = (r['Expected (₦)'] ??
                    r['Expected'] ??
                    r['expected_amount'] as num?)
                ?.toDouble() ??
                0.0;
            final paid = (r['Paid (₦)'] ?? r['Paid'] ?? r['paid_amount'] as num?)?.toDouble() ?? 0.0;
            final shortfall =
                (r['Shortfall (₦)'] ?? r['Shortfall'] ?? r['shortfall'] as num?)?.toDouble() ?? 0.0;
            final status =
                (r['Status'] ?? r['Issue Type'] ?? r['issue_type'] ?? r['status'] ?? 'Shortfall').toString();
            final actionMsg = (r['Action'] ?? r['action'] ?? '').toString();

            return DataRow(cells: [
              DataCell(Text(clientName, style: IcareTypography.bodyBold.copyWith(color: tokens.textPrimary))),
              DataCell(Text(clientCode.isNotEmpty ? clientCode : 'N/A', style: IcareTypography.body.copyWith(color: tokens.textSecondary))),
              DataCell(Text(group, style: IcareTypography.body.copyWith(color: tokens.textSecondary))),
              DataCell(Text(CurrencyFormatter.formatNaira(expected), style: IcareTypography.tableFinancialNumber.copyWith(color: tokens.textPrimary))),
              DataCell(Text(CurrencyFormatter.formatNaira(paid), style: IcareTypography.tableFinancialNumber.copyWith(color: tokens.textPrimary))),
              DataCell(Text(
                CurrencyFormatter.formatNaira(shortfall),
                style: IcareTypography.tableFinancialNumber.copyWith(color: tokens.dangerText),
              )),
              DataCell(IcareStatusBadge.fromStatus(status)),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    actionMsg.isNotEmpty ? actionMsg : 'Follow Up',
                    style: IcareTypography.body.copyWith(fontSize: 12, color: tokens.textSecondary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ),
            ]);
          }).toList(),
        );
      },
    );
  }

  /// Cleans status text of any legacy non-corporate pictographs cleanly
  static String _cleanStatusText(String status) {
    return status
        .replaceAll(
          RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\uFE0F\u200D]', unicode: true),
          '',
        )
        .trim();
  }

  Widget _buildInfoBox(String text) {
    return Builder(
      builder: (context) {
        final tokens = IcareSurfaceTokens.of(context);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: tokens.infoBg,
            borderRadius: IcareSpacing.roundedMd,
            border: Border.all(color: tokens.infoBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: tokens.infoText, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: TextStyle(color: tokens.infoText, fontSize: 13)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AttentionSearchBar extends ConsumerStatefulWidget {
  const _AttentionSearchBar();

  @override
  ConsumerState<_AttentionSearchBar> createState() => _AttentionSearchBarState();
}

class _AttentionSearchBarState extends ConsumerState<_AttentionSearchBar> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(coDashboardAttentionSearchProvider));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final searchQuery = ref.watch(coDashboardAttentionSearchProvider);
    if (_ctrl.text != searchQuery && searchQuery.isEmpty) {
      _ctrl.clear();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderStrong),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: tokens.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Search client or group name...',
                hintStyle: TextStyle(fontSize: 12.5, color: tokens.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
              onChanged: (val) {
                ref.read(coDashboardAttentionSearchProvider.notifier).state = val;
              },
            ),
          ),
          if (searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _ctrl.clear();
                ref.read(coDashboardAttentionSearchProvider.notifier).state = '';
              },
              child: Icon(Icons.close, size: 16, color: tokens.textMuted),
            ),
        ],
      ),
    );
  }
}
