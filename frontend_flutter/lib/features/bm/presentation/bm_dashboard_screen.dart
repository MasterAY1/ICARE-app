import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_database_service.dart';
import '../data/datasources/bm_api_service.dart';
import '../data/models/bm_dashboard_models.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import 'master_cashbook_screen.dart';
import '../../co/presentation/withdrawal_operations_screen.dart';
import 'package:frontend_flutter/core/theme/icare_motion.dart';
import '../../../core/widgets/icare_card.dart';
import '../../../core/widgets/icare_data_table.dart';
import '../../../core/widgets/icare_metric_card.dart';
import '../../../core/widgets/icare_status_badge.dart';
import 'widgets/bm_analytics_charts.dart';

final bmDashboardDataProvider = FutureProvider.autoDispose<BmDashboardDataModel>((ref) async {
  // Retain data in memory for 60 seconds after unmount to prevent tab-switching refetches
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), () {
    link.close();
  });
  ref.onDispose(() => timer.cancel());

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

  void _invalidateAllCashbookAndDashboardProviders() {
    ref.invalidate(bmDashboardDataProvider);
    ref.invalidate(masterDailyCashbookProvider);
    ref.invalidate(coAggregationProvider);
    ref.invalidate(monthlyLedgerProvider);
    ref.invalidate(dailyWithdrawalsProvider);
    ref.invalidate(pendingApprovalsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(bmDashboardDataProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final tokens = IcareSurfaceTokens.of(context);

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
        final errDetails = AppErrorDetails.from(err);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: IcareCard(
                padding: const EdgeInsets.all(24),
                topAccentColor: isConnectionError ? tokens.warningDot : tokens.dangerDot,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnectionError ? Icons.cloud_off : Icons.error_outline,
                      color: isConnectionError ? tokens.warningDot : tokens.dangerDot,
                      size: 44,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isConnectionError
                          ? 'Offline Mode — No Local Cache Available'
                          : errDetails.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isConnectionError ? tokens.warningText : tokens.dangerText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isConnectionError
                          ? 'You are currently working offline, but no cached BM dashboard was found on this device. Please connect to the internet once to load current branch operations.'
                          : errDetails.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                    ),
                    if (!isConnectionError && errDetails.action.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        errDetails.action,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: tokens.textMuted),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _invalidateAllCashbookAndDashboardProviders,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConnectionError ? tokens.warningText : tokens.brandPrimaryDark,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      data: (data) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 680;
            return Column(
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
                            'Offline Mode Active — Displaying locally cached branch overview and approvals queue. New financial authorizations require an active server connection.',
                            style: TextStyle(color: tokens.warningText, fontSize: 11.5, fontWeight: FontWeight.w600),
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
      },
    );
  }

  Widget _buildDashboardContent(BmDashboardDataModel data, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
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
                Expanded(
                  child: Text(
                    'Performance & Risk',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, size: 20, color: tokens.textSecondary),
                  tooltip: 'Refresh Dashboard',
                  onPressed: _invalidateAllCashbookAndDashboardProviders,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(activeCoPageProvider.notifier).state = 'Audit Ledger';
                  },
                  icon: Icon(Icons.shield_outlined, size: 14, color: tokens.textSecondary),
                  label: Text('Audit', style: TextStyle(color: tokens.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: tokens.borderStrong),
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
                Expanded(
                  child: Text(
                    'Performance & Risk Dashboard',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.refresh, size: 20, color: tokens.textSecondary),
                      tooltip: 'Refresh Dashboard',
                      onPressed: _invalidateAllCashbookAndDashboardProviders,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.read(activeCoPageProvider.notifier).state = 'Audit Ledger';
                      },
                      icon: Icon(Icons.shield_outlined, size: 16, color: tokens.textSecondary),
                      label: Text('Audit Center', style: TextStyle(color: tokens.textSecondary, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: tokens.borderStrong),
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.textPrimary),
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                'Branch Daily Operations, Officer Status, & Approvals',
                style: TextStyle(fontSize: 13, color: tokens.textMuted),
              ),
              if (data.businessDate.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tokens.surfaceHover,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.borderStrong),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_outlined, size: 12, color: tokens.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Operations Date: ${data.meetingDay}, ${data.businessDate}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Flash Message Banner
          if (_flashMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: tokens.successBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.successBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: tokens.successDot, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _flashMessage!,
                      style: TextStyle(color: tokens.successText, fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: tokens.successDot),
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
                color: tokens.warningBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.warningBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: tokens.warningDot, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Branch Closed / Holiday (${data.closureReason}): All field collections and group meetings are suspended for ${data.branchName} Branch today.',
                      style: TextStyle(color: tokens.warningText, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 1.5 Hero Vault & Operations Command Card
          _buildHeroCard(data, isMobile),
          const SizedBox(height: 18),

          // Section Rendering: Mobile Tabs vs Desktop Full View
          if (isMobile) ...[
            _buildMobileSectionSwitcher(
              totalApprovals: (data.pendingLoans.length + data.pendingWithdrawals.length + data.pendingCorrections.length),
              totalOfficers: data.officerCollectionStatus.length,
              hasApprovals: hasApprovals,
            ),
            if (_mobileSectionTab == 'Approvals' || _mobileSectionTab == 'All') ...[
              _buildApprovalsHub(data, hasLoans, hasWrs, hasCorrs, isMobile),
              const SizedBox(height: 16),
            ],
            if (_mobileSectionTab == 'Overview' || _mobileSectionTab == 'All') ...[
              _buildBranchSummary(data.branchSummary),
              const SizedBox(height: 14),
              BmDashboardAnalyticsSection(data: data),
              const SizedBox(height: 14),
              _buildBranchCashPosition(data.branchCashPosition),
              const SizedBox(height: 16),
            ],
            if (_mobileSectionTab == 'Officers' || _mobileSectionTab == 'All') ...[
              _buildOfficerCollectionStatus(data.officerCollectionStatus, isMobile),
              const SizedBox(height: 16),
            ],
          ] else ...[
            // 2. Branch Approvals Hub (Always visible with live tabs)
            _buildApprovalsHub(data, hasLoans, hasWrs, hasCorrs, isMobile),
            const SizedBox(height: 24),

            // 3. Section A: Branch Summary
            _buildBranchSummary(data.branchSummary),
            const SizedBox(height: 20),

            // 3.5 Live BM Comparative Analytics
            BmDashboardAnalyticsSection(data: data),
            const SizedBox(height: 24),

            // 4. Section B: Officer Collection Status Grid
            _buildOfficerCollectionStatus(data.officerCollectionStatus, isMobile),
            const SizedBox(height: 24),

            // 5. Section C: Branch Cash Position (Master Cashbook)
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
    final tokens = IcareSurfaceTokens.of(context);
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
        color: tokens.surfaceHover,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
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
                  color: isSel ? tokens.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: (isSel && !tokens.isDark)
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
                          color: isSel ? tokens.brandPrimary : tokens.textMuted,
                        ),
                        if (count != null && count > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSel ? tokens.brandPrimaryDark : tokens.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isSel ? Colors.white : tokens.textSecondary,
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
                        color: isSel ? tokens.textPrimary : tokens.textMuted,
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
  // HERO VAULT & OPERATIONS COMMAND CARD
  // ==========================================
  Widget _buildHeroCard(BmDashboardDataModel data, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final closingCash = data.branchCashPosition.closingBalance;
    final isBalanced = data.branchCashPosition.status == 'Balanced';
    final collectionToday = data.branchSummary.collectionToday;
    final activeSavings = data.branchSummary.activeSavings;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tokens.brandPrimaryDark, tokens.brandPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.brandPrimaryLight.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: tokens.brandPrimaryDark.withValues(alpha: tokens.isDark ? 0.35 : 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isBalanced ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isBalanced ? const Color(0xFF34D399) : const Color(0xFFFBBF24)).withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${data.branchName.toUpperCase()} BRANCH · VAULT POSITION',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isBalanced ? const Color(0x2E10B981) : const Color(0x2EEF4444),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isBalanced ? const Color(0xFF34D399) : const Color(0xFFF87171),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBalanced ? Icons.verified_user : Icons.warning_amber_rounded,
                      size: 11,
                      color: isBalanced ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBalanced ? 'Vault Balanced' : 'Variance Detected',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isBalanced ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(closingCash),
              style: bmTabularStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.payments_outlined, size: 14, color: Colors.white.withValues(alpha: 0.82)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Today: ${CurrencyFormatter.format(collectionToday)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: bmTabularStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 14, color: Colors.white.withValues(alpha: 0.22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.savings_outlined, size: 14, color: Colors.white.withValues(alpha: 0.82)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Savings: ${CurrencyFormatter.format(activeSavings)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: bmTabularStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
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

  // ==========================================
  // BRANCH APPROVALS HUB
  // ==========================================
  Widget _buildApprovalsHub(BmDashboardDataModel data, bool hasLoans, bool hasWrs, bool hasCorrs, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final tabs = ['Loan Disbursements', 'Withdrawals', 'Error Corrections'];

    return IcareCard(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      topAccentColor: tokens.brandPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Branch Approvals Hub',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Disbursement authorization, withdrawals, and error corrections.',
                      style: TextStyle(fontSize: 12.5, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: 18, color: tokens.textMuted),
                tooltip: 'Refresh Approvals',
                onPressed: _invalidateAllCashbookAndDashboardProviders,
              ),
            ],
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
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? tokens.brandPrimaryDark : tokens.surfaceHover,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSel ? tokens.brandPrimaryDark : tokens.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                          color: isSel ? Colors.white : tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSel ? Colors.black.withValues(alpha: 0.25) : (count > 0 ? tokens.infoBg : tokens.borderSubtle),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isSel ? Colors.white : (count > 0 ? tokens.infoText : tokens.textMuted),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Divider(color: tokens.borderSubtle, height: 1),
          const SizedBox(height: 16),

          if (_activeApprovalTab == 'Loan Disbursements')
            hasLoans
                ? _buildLoanApprovalsTab(data.pendingLoans, isMobile)
                : _buildEmptyQueueCard('Loan Disbursements', Icons.payments_outlined)
          else if (_activeApprovalTab == 'Withdrawals')
            hasWrs
                ? _buildWithdrawalApprovalsTab(data.pendingWithdrawals, isMobile)
                : _buildEmptyQueueCard('Withdrawals', Icons.savings_outlined)
          else if (_activeApprovalTab == 'Error Corrections')
            hasCorrs
                ? _buildCorrectionApprovalsTab(data.pendingCorrections, isMobile)
                : _buildEmptyQueueCard('Error Corrections', Icons.build_circle_outlined),
        ],
      ),
    );
  }

  Widget _buildEmptyQueueCard(String queueName, IconData icon) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.infoBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: tokens.infoText),
          ),
          const SizedBox(height: 12),
          Text(
            'No Pending $queueName',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'All operational requests for $queueName in this branch have been reviewed and processed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: tokens.textMuted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _invalidateAllCashbookAndDashboardProviders,
                icon: Icon(Icons.refresh, size: 14, color: tokens.infoText),
                label: Text('Refresh Queue', style: TextStyle(color: tokens.infoText, fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.infoBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(activeCoPageProvider.notifier).state = 'Audit Ledger';
                },
                icon: Icon(Icons.shield_outlined, size: 14, color: tokens.textSecondary),
                label: Text('Inspect Audit Ledger', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.borderStrong),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
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
    final tokens = IcareSurfaceTokens.of(context);
    final totalPages = (totalCount / pageSize).ceil();
    final startItem = (currentPage - 1) * pageSize + 1;
    final endItem = (currentPage * pageSize).clamp(1, totalCount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Showing $startItem-$endItem of $totalCount items',
            style: bmTabularStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tokens.textMuted),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(32, 32),
                  side: BorderSide(color: tokens.borderStrong),
                ),
                child: const Icon(Icons.chevron_left, size: 18),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: bmTabularStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(32, 32),
                  side: BorderSide(color: tokens.borderStrong),
                ),
                child: const Icon(Icons.chevron_right, size: 18),
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
    final tokens = IcareSurfaceTokens.of(context);
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
    final loanBatchDisabled = _selectedLoanIds.isEmpty || _isProcessing;

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
        Divider(color: tokens.borderSubtle, height: 1),
        const SizedBox(height: 10),

        // Batch controls
        if (isMobile)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.borderSubtle),
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
                Flexible(
                  child: Text(
                    'All (${filtered.length})',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
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
                    decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: tokens.borderStrong)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 11, color: tokens.infoText),
                        const SizedBox(width: 4),
                        Text(DateFormat('MM/dd').format(_batchLoanDate), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: loanBatchDisabled ? null : () => _executeBatchApproveLoans(filtered),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: tokens.surfaceHover,
                    disabledForegroundColor: tokens.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 30),
                  ),
                  child: Text(
                    _isProcessing ? '...' : 'Approve (${_selectedLoanIds.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
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
                    child: Text(DateFormat('yyyy-MM-dd').format(_batchLoanDate), style: TextStyle(fontSize: 13, color: tokens.textPrimary)),
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
              Text('Select All (${filtered.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: tokens.textPrimary)),
              const Spacer(),
              ElevatedButton(
                onPressed: loanBatchDisabled ? null : () => _executeBatchApproveLoans(filtered),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.brandPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: tokens.surfaceHover,
                  disabledForegroundColor: tokens.textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  _isProcessing ? 'Processing...' : 'Approve Selected Loans',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),

        // Cards list
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: tokens.surfaceSubtle, borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Text('No pending loan applications matching the selected filters.', style: TextStyle(color: tokens.textMuted, fontSize: 13)),
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
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
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
                                Text(pl.clientName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tokens.textPrimary), overflow: TextOverflow.ellipsis),
                                Text('${pl.clientCode} • ${pl.loanProduct}', style: TextStyle(fontSize: 10.5, color: tokens.textMuted)),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(pl.loanAmount),
                            style: bmTabularStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: tokens.surfaceHover, borderRadius: BorderRadius.circular(4)),
                                    child: Text(pl.officer, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: tokens.textSecondary)),
                                  ),
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
                                      color: tokens.infoBg,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: tokens.infoBorder),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.calendar_today_outlined, size: 10, color: tokens.infoDot),
                                        const SizedBox(width: 3),
                                        Text(
                                          DateFormat('MM/dd').format(cardDate),
                                          style: bmTabularStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tokens.infoText),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton(
                            onPressed: _isProcessing ? null : () => _rejectSingleLoan(pl.loanId, pl.clientName),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: tokens.borderStrong),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(0, 28),
                            ),
                            child: Text('Reject', style: TextStyle(color: tokens.textSecondary, fontSize: 11)),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: _isProcessing ? null : () => _approveSingleLoan(pl.loanId, pl.clientName, cardDate),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tokens.brandPrimary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: tokens.surfaceHover,
                              disabledForegroundColor: tokens.textMuted,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 28),
                            ),
                            child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
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
                              Flexible(
                                child: Text(pl.clientName, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tokens.textPrimary)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: tokens.surfaceHover, borderRadius: BorderRadius.circular(4)),
                                child: Text(pl.clientCode, style: bmTabularStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Product: ${pl.loanProduct} | Officer: ${pl.officer}', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(CurrencyFormatter.format(pl.loanAmount), style: bmTabularStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tokens.textPrimary)),
                          Text('Requested Principal', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
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
                          child: Text(DateFormat('yyyy-MM-dd').format(cardDate), style: TextStyle(fontSize: 12, color: tokens.textPrimary)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : () => _approveSingleLoan(pl.loanId, pl.clientName, cardDate),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: tokens.surfaceHover,
                        disabledForegroundColor: tokens.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _isProcessing ? null : () => _rejectSingleLoan(pl.loanId, pl.clientName),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: tokens.borderStrong),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: Text('Reject', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
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
    final tokens = IcareSurfaceTokens.of(context);
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
    final wrBatchDisabled = _selectedWrIds.isEmpty || _isProcessing;

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
        Divider(color: tokens.borderSubtle, height: 1),
        const SizedBox(height: 12),

        // Batch controls
        if (isMobile)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.borderSubtle),
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
                Flexible(
                  child: Text(
                    'All (${filtered.length})',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
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
                    decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: tokens.borderStrong)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 11, color: tokens.infoText),
                        const SizedBox(width: 4),
                        Text(DateFormat('MM/dd').format(_batchWrDate), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: wrBatchDisabled ? null : () => _executeBatchApproveWithdrawals(filtered),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: tokens.surfaceHover,
                    disabledForegroundColor: tokens.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 30),
                  ),
                  child: Text(
                    _isProcessing ? '...' : 'Approve (${_selectedWrIds.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
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
                    child: Text(DateFormat('yyyy-MM-dd').format(_batchWrDate), style: TextStyle(fontSize: 13, color: tokens.textPrimary)),
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
              Text('Select All (${filtered.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: tokens.textPrimary)),
              const Spacer(),
              ElevatedButton(
                onPressed: wrBatchDisabled ? null : () => _executeBatchApproveWithdrawals(filtered),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.brandPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: tokens.surfaceHover,
                  disabledForegroundColor: tokens.textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  _isProcessing ? 'Processing...' : 'Approve Selected Withdrawals',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),

        // Cards list
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: tokens.surfaceSubtle, borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Text('No pending withdrawal requests matching the selected filters.', style: TextStyle(color: tokens.textMuted, fontSize: 13)),
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
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
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
                                Text(wr.clientName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tokens.textPrimary), overflow: TextOverflow.ellipsis),
                                Text(
                                  '${wr.savingsType} • ${wr.operationType}',
                                  style: TextStyle(fontSize: 10.5, color: tokens.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(wr.amount),
                            style: bmTabularStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: tokens.dangerText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Req: ${wr.requestedBy}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10.5, color: tokens.textLight),
                            ),
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
                                setState(() => _wrDatesMap[wr.id] = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: tokens.surfaceHover,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: tokens.borderStrong),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 10, color: tokens.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(DateFormat('MM/dd').format(cardDate), style: bmTabularStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton(
                            onPressed: _isProcessing ? null : () => _promptRejectWithdrawal(wr.id, wr.clientName),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: tokens.borderStrong),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(0, 28),
                            ),
                            child: Text('Reject', style: TextStyle(color: tokens.textSecondary, fontSize: 11)),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: _isProcessing ? null : () => _approveSingleWithdrawal(wr.id, wr.clientName, wr.amount, cardDate),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tokens.brandPrimary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: tokens.surfaceHover,
                              disabledForegroundColor: tokens.textMuted,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 28),
                            ),
                            child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
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
                              Flexible(
                                child: Text(
                                  wr.clientName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tokens.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: tokens.surfaceHover, borderRadius: BorderRadius.circular(4)),
                                child: Text(wr.savingsType, style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Op: ${wr.operationType} | Requested by: ${wr.requestedBy}', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                          if (wr.remarks != null && wr.remarks!.isNotEmpty)
                            Text(
                              wr.remarks!.replaceAll(RegExp(r'\[(?:DEST_ID|DEST_NAME|DEST_TYPE|FEE|LOAN_OFFSET|IDEMPOTENCY):[^\]]*\]\s*', caseSensitive: false), '').trim(),
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: tokens.textLight),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(CurrencyFormatter.format(wr.amount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tokens.dangerText)),
                          Text('Withdrawal Amount', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
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
                          child: Text(DateFormat('yyyy-MM-dd').format(cardDate), style: TextStyle(fontSize: 12, color: tokens.textPrimary)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : () => _approveSingleWithdrawal(wr.id, wr.clientName, wr.amount, cardDate),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: tokens.surfaceHover,
                        disabledForegroundColor: tokens.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _isProcessing ? null : () => _promptRejectWithdrawal(wr.id, wr.clientName),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: tokens.borderStrong),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: Text('Reject', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
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
    final tokens = IcareSurfaceTokens.of(context);
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
    final corrBatchDisabled = _selectedCorrIds.isEmpty || _isProcessing;

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
        Divider(color: tokens.borderSubtle, height: 1),
        const SizedBox(height: 12),

        // Batch controls
        if (isMobile)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.borderSubtle),
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
                Expanded(
                  child: Text(
                    'All (${filtered.length})',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: corrBatchDisabled ? null : () => _executeBatchApproveCorrections(filtered),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: tokens.surfaceHover,
                    disabledForegroundColor: tokens.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 30),
                  ),
                  child: Text(
                    _isProcessing ? '...' : 'Approve (${_selectedCorrIds.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
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
              Text('Select All (${filtered.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: tokens.textPrimary)),
              const Spacer(),
              ElevatedButton(
                onPressed: corrBatchDisabled ? null : () => _executeBatchApproveCorrections(filtered),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.brandPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: tokens.surfaceHover,
                  disabledForegroundColor: tokens.textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  _isProcessing ? 'Processing...' : 'Approve Selected Reversals',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),

        // Cards list
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: tokens.surfaceSubtle, borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Text('No pending error correction requests matching the selected filters.', style: TextStyle(color: tokens.textMuted, fontSize: 13)),
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
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '[${corr.recordType}] #$rRef',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: tokens.textPrimary),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      CurrencyFormatter.format(corr.amount),
                                      style: bmTabularStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: tokens.dangerText),
                                    ),
                                  ],
                                ),
                                if (corr.clientName != null && corr.clientName!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${corr.clientName!} ${corr.clientCode != null && corr.clientCode!.isNotEmpty ? "(${corr.clientCode})" : ""}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  corr.reason,
                                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: tokens.textSecondary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const IcareStatusBadge(label: 'Pending', variant: IcareBadgeVariant.warning, showDot: false),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'By: ${corr.requestedBy}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10.5, color: tokens.textLight),
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton(
                            onPressed: _isProcessing ? null : () => _rejectSingleCorrection(corr),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: tokens.borderStrong),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(0, 28),
                            ),
                            child: Text('Reject', style: TextStyle(color: tokens.textSecondary, fontSize: 11)),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: _isProcessing ? null : () => _approveSingleCorrection(corr),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tokens.brandPrimary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: tokens.surfaceHover,
                              disabledForegroundColor: tokens.textMuted,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 28),
                            ),
                            child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('[${corr.recordType}]', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tokens.textPrimary)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: tokens.surfaceHover, borderRadius: BorderRadius.circular(4)),
                                child: Text('Ref: #$rRef', style: bmTabularStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
                              ),
                              Text(
                                CurrencyFormatter.format(corr.amount),
                                style: bmTabularStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: tokens.dangerText),
                              ),
                              if (corr.clientName != null && corr.clientName!.isNotEmpty)
                                Text(
                                  '• ${corr.clientName!} ${corr.clientCode != null && corr.clientCode!.isNotEmpty ? "(${corr.clientCode})" : ""}',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Requested by: ${corr.requestedBy} • Submitted: ${corr.createdAt ?? ""}', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                          const SizedBox(height: 2),
                          Text('Reason: ${corr.reason}', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: tokens.textSecondary)),
                        ],
                      ),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IcareStatusBadge(
                          label: 'Pending Approval',
                          variant: IcareBadgeVariant.warning,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : () => _approveSingleCorrection(corr),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: tokens.surfaceHover,
                        disabledForegroundColor: tokens.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _isProcessing ? null : () => _rejectSingleCorrection(corr),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: tokens.borderStrong),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: Text('Reject', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
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
    final tokens = IcareSurfaceTokens.of(context);
    final c1 = _buildMetricCard(
      'Active Clients',
      '${bs.activeClients}',
      icon: Icons.people_alt_outlined,
      accentColor: tokens.infoDot,
      subtitle: 'Registered Borrowers',
    );
    final c2 = _buildMetricCard(
      'Active Savings',
      CurrencyFormatter.format(bs.activeSavings),
      icon: Icons.savings_outlined,
      accentColor: tokens.brandPrimary,
      subtitle: 'Client Vault Savings',
    );
    final c3 = _buildMetricCard(
      'Collection Today',
      CurrencyFormatter.format(bs.collectionToday),
      icon: Icons.payments_outlined,
      accentColor: tokens.successDot,
      isGrand: true,
      subtitle: 'Daily Cash Inflow',
    );
    final parVal = double.tryParse(bs.par.replaceAll('%', '').trim()) ?? 0.0;
    final isParHealthy = parVal <= 5.0;
    final c4 = _buildMetricCard(
      'Portfolio at Risk (PAR)',
      bs.par,
      icon: isParHealthy ? Icons.verified_user_outlined : Icons.warning_amber_rounded,
      accentColor: isParHealthy ? tokens.successDot : tokens.dangerDot,
      deltaColor: isParHealthy ? tokens.successText : tokens.dangerText,
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
    final tokens = IcareSurfaceTokens.of(context);
    final cardAccent = accentColor ?? (isGrand ? tokens.successDot : tokens.infoDot);
    return IcareMetricCard(
      label: label,
      value: value,
      delta: subtitle,
      icon: icon,
      topBorderColor: cardAccent,
      isFullEmerald: isGrand,
      statusTextColor: isGrand ? null : deltaColor,
    );
  }

  // ==========================================
  // SECTION B: OFFICER COLLECTION STATUS
  // ==========================================
  Widget _buildOfficerCollectionStatus(List<OfficerCollectionStatusModel> officers, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    return IcareCard(
      padding: EdgeInsets.zero,
      topAccentColor: tokens.infoDot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: tokens.infoBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.badge_outlined, size: 16, color: tokens.infoDot),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Officer Collection Status',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IcareStatusBadge(
                  label: '${officers.length} Officers',
                  variant: IcareBadgeVariant.neutral,
                  showDot: false,
                ),
              ],
            ),
          ),
          Divider(color: tokens.borderSubtle, height: 1),
          if (officers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Center(child: Text('No officer collection activity recorded for today.', style: TextStyle(color: tokens.textMuted, fontSize: 13))),
            )
          else if (isMobile)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: officers.map((o) => _buildMobileOfficerStatusCard(o)).toList(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: IcareDataTable(
                minWidth: 780,
                columns: [
                  DataColumn(label: Text('Officer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                  DataColumn(label: Text('Scheduled Groups', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                  DataColumn(label: Text('Expected', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                  DataColumn(label: Text('Collected', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                  DataColumn(label: Text('Outstanding', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                  DataColumn(label: Text('Compliance %', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                  DataColumn(label: Text('Closing Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                ],
                rows: officers.map((o) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(o.officer, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tokens.textPrimary)),
                            Text(o.officerName, style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                          ],
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Text(
                            o.scheduledGroups,
                            style: TextStyle(fontSize: 11.5, color: tokens.textSecondary),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                      DataCell(Text(CurrencyFormatter.format(o.expected), style: bmTabularStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: tokens.textPrimary))),
                      DataCell(Text(CurrencyFormatter.format(o.collected), style: bmTabularStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tokens.successText))),
                      DataCell(Text(CurrencyFormatter.format(o.outstanding), style: bmTabularStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: tokens.dangerText))),
                      DataCell(
                        Text(
                          '${o.compliancePct.toStringAsFixed(1)}%',
                          style: bmTabularStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: o.compliancePct >= 80 ? tokens.successText : tokens.dangerText,
                          ),
                        ),
                      ),
                      DataCell(Text(CurrencyFormatter.format(o.closingBalance), style: bmTabularStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textPrimary))),
                      DataCell(IcareStatusBadge.fromStatus(o.status)),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileOfficerStatusCard(OfficerCollectionStatusModel o) {
    final tokens = IcareSurfaceTokens.of(context);
    final isHighCompliance = o.compliancePct >= 80.0;
    final isExpanded = _expandedOfficer == o.officer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IcareCard(
        padding: EdgeInsets.zero,
        border: Border.all(color: isExpanded ? tokens.brandPrimary : tokens.borderSubtle),
        onTap: () => setState(() => _expandedOfficer = isExpanded ? null : o.officer),
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
                    backgroundColor: isHighCompliance ? tokens.successBg : tokens.warningBg,
                    child: Text(
                      o.officer.length >= 2 ? o.officer.substring(0, 2).toUpperCase() : o.officer.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isHighCompliance ? tokens.successText : tokens.warningText,
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
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                o.officer,
                                overflow: TextOverflow.ellipsis,
                                style: bmTabularStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: tokens.textMuted),
                              ),
                            ),
                            Text(' • ', style: TextStyle(color: tokens.borderStrong, fontSize: 10)),
                            Flexible(
                              child: Text(
                                '${CurrencyFormatter.format(o.collected)} / ${CurrencyFormatter.format(o.expected)}',
                                overflow: TextOverflow.ellipsis,
                                style: bmTabularStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isHighCompliance ? tokens.successBg : tokens.dangerBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${o.compliancePct.toStringAsFixed(0)}%',
                      style: bmTabularStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isHighCompliance ? tokens.successText : tokens.dangerText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: tokens.textMuted,
                  ),
                ],
              ),

              // Expandable Detail Body
              if (isExpanded) ...[
                const SizedBox(height: 10),
                Divider(color: tokens.borderSubtle, height: 1),
                const SizedBox(height: 10),

                // Scheduled Groups
                if (o.scheduledGroups.isNotEmpty && o.scheduledGroups != '—') ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.groups_outlined, size: 13, color: tokens.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Groups: ${o.scheduledGroups}',
                          style: TextStyle(fontSize: 11, color: tokens.textSecondary),
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
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Expected', style: TextStyle(fontSize: 9.5, color: tokens.textMuted)),
                            const SizedBox(height: 1),
                            Text(
                              CurrencyFormatter.format(o.expected),
                              style: bmTabularStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Collected', style: TextStyle(fontSize: 9.5, color: tokens.textMuted)),
                            const SizedBox(height: 1),
                            Text(
                              CurrencyFormatter.format(o.collected),
                              style: bmTabularStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tokens.successText),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Outstanding', style: TextStyle(fontSize: 9.5, color: tokens.textMuted)),
                            const SizedBox(height: 1),
                            Text(
                              CurrencyFormatter.format(o.outstanding),
                              style: bmTabularStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tokens.dangerText),
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
                    Flexible(child: IcareStatusBadge.fromStatus(o.status)),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Closing: ', style: TextStyle(fontSize: 10.5, color: tokens.textMuted)),
                        Text(
                          CurrencyFormatter.format(o.closingBalance),
                          style: bmTabularStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: tokens.textPrimary),
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
    final tokens = IcareSurfaceTokens.of(context);
    final isBalanced = cp.status == 'Balanced';

    final c1 = _buildMetricCard(
      'Opening Balance (B/F)',
      CurrencyFormatter.format(cp.openingBalance),
      icon: Icons.history_toggle_off_outlined,
      accentColor: tokens.textMuted,
      subtitle: 'Vault B/F Balance',
    );
    final c2 = _buildMetricCard(
      'Total Inflows',
      CurrencyFormatter.format(cp.cashIn),
      icon: Icons.south_west_outlined,
      accentColor: tokens.successDot,
      subtitle: 'Collections & Deposits',
    );
    final c3 = _buildMetricCard(
      'Total Outflows',
      CurrencyFormatter.format(cp.cashOut),
      icon: Icons.north_east_outlined,
      accentColor: tokens.dangerDot,
      subtitle: 'Disbursements & Costs',
    );
    final c4 = _buildMetricCard(
      'Closing Cash Balance',
      CurrencyFormatter.format(cp.closingBalance),
      icon: Icons.account_balance_wallet_outlined,
      accentColor: tokens.infoDot,
      isGrand: true,
      subtitle: 'Physical Vault Position',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: tokens.isDark
            ? null
            : const [
                BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
              ],
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
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: tokens.brandSoftBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.account_balance_outlined, size: 16, color: tokens.brandPrimary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Branch Cash Position (Master Cashbook)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IcareStatusBadge(
                label: cp.status,
                variant: isBalanced ? IcareBadgeVariant.success : IcareBadgeVariant.danger,
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
              color: isBalanced ? tokens.successBg : tokens.dangerBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isBalanced ? tokens.successBorder : tokens.dangerBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isBalanced ? Icons.verified_outlined : Icons.warning_amber_rounded,
                  size: 18,
                  color: isBalanced ? tokens.successDot : tokens.dangerDot,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isBalanced
                        ? 'Vault Cash is fully reconciled and balanced with the primary vault ledger. Variance: ${CurrencyFormatter.format(cp.difference)}'
                        : 'Reconciliation Variance Detected: Difference of ${CurrencyFormatter.format(cp.difference)}. Requires physical vault audit.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isBalanced ? tokens.successText : tokens.dangerText,
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

  void _showErrorSnackBar(dynamic error, {String prefix = ''}) {
    if (!mounted) return;
    final tokens = IcareSurfaceTokens.of(context);
    final msg = AppErrorDetails.from(error).message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$prefix$msg',
          style: TextStyle(color: tokens.dangerText, fontWeight: FontWeight.w600),
        ),
        backgroundColor: tokens.dangerBg,
      ),
    );
  }

  Future<void> _approveSingleLoan(String loanId, String clientName, DateTime date) async {
    setState(() => _isProcessing = true);
    try {
      final api = ref.read(bmApiServiceProvider);
      final res = await api.approveLoan(loanId: loanId, disbursementDate: DateFormat('yyyy-MM-dd').format(date));
      _showFlash(res['message']?.toString() ?? 'Loan approved & disbursed for $clientName!');
      _invalidateAllCashbookAndDashboardProviders();
    } catch (e) {
      _showErrorSnackBar(e, prefix: 'Approval failed: ');
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
      _invalidateAllCashbookAndDashboardProviders();
    } catch (e) {
      _showErrorSnackBar(e, prefix: 'Rejection failed: ');
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
      _invalidateAllCashbookAndDashboardProviders();
    } catch (e) {
      _showErrorSnackBar(e, prefix: 'Batch approval failed: ');
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
      _invalidateAllCashbookAndDashboardProviders();
    } catch (e) {
      _showErrorSnackBar(e, prefix: 'Approval failed: ');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _promptRejectWithdrawal(String id, String clientName) async {
    final reasonCtrl = TextEditingController();
    final shouldReject = await showIcareAdaptiveSheet<bool>(
      context: context,
      fitContent: true,
      desktopConstraints: const BoxConstraints(maxWidth: 440, maxHeight: 420),
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        final dangerFill = tokens.isDark ? tokens.dangerBorder : tokens.dangerText;
        return Material(
          color: tokens.surfaceElevated,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              isDialog ? 20 : 12,
              20,
              20 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isDialog)
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: tokens.borderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Text(
                  'Reject Withdrawal for $clientName',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Rejection Reason', hintText: 'Why is this being rejected?'),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: dangerFill, foregroundColor: Colors.white),
                      child: const Text('Confirm Rejection'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    final rejectionText = reasonCtrl.text.trim();
    reasonCtrl.dispose();

    if (shouldReject == true) {
      setState(() => _isProcessing = true);
      try {
        final api = ref.read(bmApiServiceProvider);
        final res = await api.rejectWithdrawal(withdrawalId: id, reason: rejectionText.isEmpty ? 'Rejected by BM' : rejectionText);
        _showFlash(res['message']?.toString() ?? 'Withdrawal request rejected.');
        _invalidateAllCashbookAndDashboardProviders();
      } catch (e) {
        _showErrorSnackBar(e, prefix: 'Rejection failed: ');
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
      _invalidateAllCashbookAndDashboardProviders();
    } catch (e) {
      _showErrorSnackBar(e, prefix: 'Batch approval failed: ');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _approveSingleCorrection(PendingCorrectionApprovalModel corr) async {
    final amtStr = CurrencyFormatter.format(corr.amount);
    final confirm = await showIcareAdaptiveSheet<bool>(
      context: context,
      fitContent: true,
      desktopConstraints: const BoxConstraints(maxWidth: 460, maxHeight: 540),
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return Material(
          color: tokens.surfaceElevated,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isDialog)
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: tokens.borderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Text('Confirm Reversal — [${corr.recordType}]', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: tokens.textPrimary)),
                const SizedBox(height: 12),
                if (corr.clientName != null && corr.clientName!.isNotEmpty) ...[
                  Text(
                    'Client: ${corr.clientName!} ${corr.clientCode != null && corr.clientCode!.isNotEmpty ? "(${corr.clientCode})" : ""}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 4),
                ],
                Text('Amount to Reverse: $amtStr', style: bmTabularStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tokens.dangerText)),
                const SizedBox(height: 6),
                Text('Reason: ${corr.reason}', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: tokens.textSecondary)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tokens.warningBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.warningBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: tokens.warningDot),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Approving this reversal will adjust $amtStr from Vault Cash. Ensure physical cash has been counted and aligned.',
                          style: TextStyle(fontSize: 11.5, color: tokens.warningText),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: tokens.brandPrimaryDark, foregroundColor: Colors.white),
                      child: const Text('Approve Reversal', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final api = ref.read(bmApiServiceProvider);
      final res = await api.approveCorrection(correctionId: corr.id);
      _showFlash(res['message']?.toString() ?? 'Reversal approved and posted cleanly!');
      _invalidateAllCashbookAndDashboardProviders();
    } catch (e) {
      _showErrorSnackBar(e, prefix: 'Approval failed: ');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectSingleCorrection(PendingCorrectionApprovalModel corr) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showIcareAdaptiveSheet<bool>(
      context: context,
      fitContent: true,
      desktopConstraints: const BoxConstraints(maxWidth: 460, maxHeight: 460),
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        final dangerFill = tokens.isDark ? tokens.dangerBorder : tokens.dangerText;
        return Material(
          color: tokens.surfaceElevated,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              isDialog ? 20 : 12,
              20,
              20 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isDialog)
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: tokens.borderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Text('Reject Reversal Request', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: tokens.textPrimary)),
                const SizedBox(height: 10),
                Text(
                  'Are you sure you want to reject this reversal request for [${corr.recordType}] (#${corr.recordId.length >= 8 ? corr.recordId.substring(0, 8) : corr.recordId})?',
                  style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason (Optional)',
                    hintText: 'e.g. Transaction verified as valid.',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: dangerFill, foregroundColor: Colors.white),
                      child: const Text('Reject Request', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    final rejectionText = reasonCtrl.text.trim();
    reasonCtrl.dispose();

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final api = ref.read(bmApiServiceProvider);
      final res = await api.rejectCorrection(
        correctionId: corr.id,
        reason: rejectionText.isNotEmpty ? rejectionText : 'Rejected by BM',
      );
      _showFlash(res['message']?.toString() ?? 'Reversal rejected.');
      _invalidateAllCashbookAndDashboardProviders();
    } catch (e) {
      _showErrorSnackBar(e, prefix: 'Rejection failed: ');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _executeBatchApproveCorrections(List<PendingCorrectionApprovalModel> corrs) async {
    final selectedCorrs = corrs.where((c) => _selectedCorrIds.contains(c.id)).toList();
    final totalAmount = selectedCorrs.fold<double>(0.0, (sum, c) => sum + c.amount);
    final amtStr = CurrencyFormatter.format(totalAmount);

    final confirm = await showIcareAdaptiveSheet<bool>(
      context: context,
      fitContent: true,
      desktopConstraints: const BoxConstraints(maxWidth: 460, maxHeight: 460),
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return Material(
          color: tokens.surfaceElevated,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isDialog)
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: tokens.borderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Text('Approve ${selectedCorrs.length} Reversals', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: tokens.textPrimary)),
                const SizedBox(height: 12),
                Text(
                  'You are about to batch approve ${selectedCorrs.length} reversal requests totaling $amtStr.',
                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tokens.warningBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.warningBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: tokens.warningDot),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Batch approval will adjust $amtStr from Vault Cash. Please verify all physical cash receipts before proceeding.',
                          style: TextStyle(fontSize: 11.5, color: tokens.warningText),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: tokens.brandPrimaryDark, foregroundColor: Colors.white),
                      child: const Text('Confirm Batch Approval', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final api = ref.read(bmApiServiceProvider);
      final res = await api.batchApproveCorrections(correctionIds: _selectedCorrIds.toList());
      _showFlash(res['message']?.toString() ?? 'Batch approved reversals successfully.');
      _selectedCorrIds.clear();
      _invalidateAllCashbookAndDashboardProviders();
    } catch (e) {
      _showErrorSnackBar(e, prefix: 'Batch approval failed: ');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
