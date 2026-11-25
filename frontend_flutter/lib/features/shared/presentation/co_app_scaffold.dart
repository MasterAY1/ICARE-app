import 'dart:convert';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:motor/motor.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_sync_manager.dart';
import '../../../core/offline/offline_database_service.dart';
import '../../../core/theme/icare_motion.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../profile/presentation/settings_profile_screen.dart';
import 'widgets/user_avatar_circle.dart';
import '../../co/presentation/co_dashboard_screen.dart';
import '../../co/presentation/loan_origination_screen.dart';
import '../../co/presentation/daily_collections_screen.dart';
import '../../co/presentation/withdrawal_operations_screen.dart';
import '../../co/presentation/portfolio_overview_screen.dart';
import '../../co/presentation/daily_cashbook_screen.dart';
import '../../bm/presentation/bm_dashboard_screen.dart';
import '../../bm/presentation/master_cashbook_screen.dart';
import '../../bm/presentation/user_management_screen.dart';
import '../../am/presentation/am_dashboard_screen.dart';
import '../../am/presentation/am_portfolio_screen.dart';
import '../../audit/presentation/audit_ledger_screen.dart';
import '../../reports/presentation/reports_export_screen.dart';
import '../../onboarding/presentation/branch_onboarding_admin_screen.dart';
import '../../admin/data/datasources/admin_api_service.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';
import '../../admin/presentation/admin_portfolio_screen.dart';
import '../../procurement/data/datasources/procurement_api_service.dart';
import '../../procurement/presentation/asset_procurement_screen.dart';
import '../../procurement/presentation/procurement_dashboard_screen.dart';
import '../../auth/presentation/login_screen.dart';

/// Active page state provider for Streamlit-style radio navigation
/// Global signal provider to trigger refresh across all sub-views and future builders
final globalRefreshSignalProvider = StateProvider<int>((ref) => 0);

final activeCoPageProvider = StateProvider<String>((ref) => 'Dashboard');

/// Selected group provider when navigating from Dashboard quick action into Collections
final selectedCollectionGroupProvider = StateProvider<String?>((ref) => null);

/// Main Application Shell for Credit Officer (1:1 replica of app.py L1925-2000 & media_1788063430479.png)
class CoAppScaffold extends ConsumerWidget {
  const CoAppScaffold({super.key});

  void _selectPage(WidgetRef ref, String nextPage) {
    final current = ref.read(activeCoPageProvider);
    if (current == nextPage) return;
    final haptics = ref.read(themeControllerProvider).hapticsEnabled;
    IcareFluidMotion.selectionHaptic(haptics);
    ref.read(activeCoPageProvider.notifier).state = nextPage;
  }

  Widget _buildTransitionedActiveView(
    BuildContext context,
    WidgetRef ref,
    String activePage,
    bool isBm,
    bool isAm,
    bool isAdmin, {
    bool isProcurement = false,
  }) {
    return PageTransitionSwitcher(
      duration: IcareFluidMotion.resolveDuration(context, IcareFluidMotion.tabDuration),
      transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
        return FadeThroughTransition(
          animation: primaryAnimation,
          secondaryAnimation: secondaryAnimation,
          fillColor: Colors.transparent,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>(activePage),
        child: _buildActiveView(
          context,
          ref,
          activePage,
          isBm,
          isAm,
          isAdmin,
          isProcurement: isProcurement,
        ),
      ),
    );
  }

  Future<void> _triggerPageRefresh(WidgetRef ref, String activePage, bool isBm, bool isAm, {bool isAdmin = false, bool isProcurement = false}) async {
    try {
      await ref.read(isOnlineProvider.notifier).refresh();
    } catch (_) {}

    ref.read(globalRefreshSignalProvider.notifier).state++;

    switch (activePage) {
      case 'Dashboard':
        if (isProcurement) {
          ref.read(procurementRefreshSignalProvider.notifier).state++;
        } else if (isAdmin) {
          ref.invalidate(adminOperationsProvider);
          ref.invalidate(institutionPerformanceProvider);
          ref.invalidate(adminRiskHealthProvider);
        } else if (isAm) {
          ref.invalidate(amDashboardDataProvider);
          ref.invalidate(amMonthlyWorkflowSubmissionsProvider);
        } else if (isBm) {
          ref.invalidate(bmDashboardDataProvider);
          ref.invalidate(masterDailyCashbookProvider);
          ref.invalidate(coAggregationProvider);
          ref.invalidate(monthlyLedgerProvider);
        } else {
          ref.invalidate(coDashboardProvider);
        }
        break;
      case 'Asset & Procurement':
        ref.read(procurementRefreshSignalProvider.notifier).state++;
        break;
      case 'Loan Origination':
        ref.invalidate(originationGroupsProvider);
        ref.invalidate(pendingDisbursementsProvider);
        break;
      case 'Collections':
        ref.invalidate(collectionSheetFutureProvider);
        ref.invalidate(collectionsHistoryProvider);
        ref.invalidate(reversalOptionsProvider);
        ref.invalidate(reversalRequestsProvider);
        break;
      case 'Withdrawal Operations':
        ref.invalidate(dailyWithdrawalsProvider);
        ref.invalidate(pendingApprovalsProvider);
        ref.invalidate(miscBalanceProvider);
        ref.invalidate(individualOptionsProvider);
        ref.invalidate(groupOptionsProvider);
        ref.invalidate(lapsOptionsProvider);
        break;
      case 'Portfolio':
        ref.invalidate(portfolioDataProvider);
        break;
      case 'CO Cashbook':
        ref.invalidate(coCashbookDataProvider);
        ref.invalidate(clientFeesProvider);
        break;
      case 'Master Cashbook':
        ref.invalidate(masterDailyCashbookProvider);
        ref.invalidate(coAggregationProvider);
        ref.invalidate(monthlyLedgerProvider);
        break;
      default:
        break;
    }
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final offlineDb = ref.read(offlineDatabaseServiceProvider);
    final pendingCount = await offlineDb.getPendingOutboxCount();
    final quarantinedCount = await offlineDb.getQuarantinedOutboxCount();
    await ref.read(pendingOutboxCountProvider.notifier).refresh();
    await ref.read(quarantinedOutboxCountProvider.notifier).refresh();
    final totalUnsynced = pendingCount + quarantinedCount;

    if (totalUnsynced > 0 && context.mounted) {
      final isOnline = ref.read(isOnlineProvider);
      final choice = await showIcareDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (dialogCtx) => AlertDialog(
          title: const Text(
            'Unsynchronized Offline Records',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          content: Text(
            quarantinedCount > 0
                ? 'You have $pendingCount pending and $quarantinedCount attention-needed offline transaction(s) stored on this device. Signing out will preserve them safely for your account until resolved.'
                : 'You have $pendingCount unsynchronized offline transaction(s) queued on this device. Signing out will keep them safely saved for your account, and they will not be posted to the central ledger until you sign back in and sync.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop('cancel'),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            if (isOnline)
              OutlinedButton(
                onPressed: () => Navigator.of(dialogCtx).pop('sync'),
                child: const Text('Sync Now', style: TextStyle(color: Color(0xFF064E3B), fontWeight: FontWeight.w700)),
              ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop('sign_out'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              child: const Text('Sign Out Anyway', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

      if (choice == 'sync') {
        final res = await ref.read(offlineSyncManagerProvider).syncOutbox();
        if (res.syncedCount > 0 || res.failedCount > 0) {
          ref.invalidate(collectionSheetFutureProvider);
          ref.invalidate(singleClientOptionsProvider);
          ref.invalidate(collectionsHistoryProvider);
          ref.invalidate(coDashboardProvider);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              backgroundColor: res.success ? const Color(0xFF065F46) : const Color(0xFFD97706),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (choice != 'sign_out') {
        return;
      }
    }

    ref.read(activeCoPageProvider.notifier).state = 'Dashboard';
    ref.read(activeProcurementTabProvider.notifier).state = 0;
    ref.read(activeProcurementStockOpModeProvider.notifier).state = 0;
    ref.read(activeProcurementCostFilterProvider.notifier).state = 'ALL';
    await ref.read(authControllerProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is! AuthStateAuthenticated) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    });

    final authState = ref.watch(authControllerProvider);
    final tokens = IcareSurfaceTokens.of(context);

    // If user is simply logged out or session initial, immediately forward to login
    if (authState is! AuthStateAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      });
      return Scaffold(
        backgroundColor: tokens.canvas,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final user = authState.user;
    final activePage = ref.watch(activeCoPageProvider);

    // Fail closed: No silent fallbacks to 'Ikeja' or fake user identity
    // If the authenticated user has no branch scope assigned
    if (user.branch.trim().isEmpty) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.dangerBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, color: tokens.dangerDot, size: 48),
                const SizedBox(height: 16),
                Text(
                  'ACCESS RESTRICTED: MISSING AUTHENTICATED SCOPE',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.dangerText),
                ),
                const SizedBox(height: 8),
                Text(
                  'No valid branch scope was detected for ${user.username}. Access is restricted per system security protocols.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: tokens.textMuted),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _handleSignOut(context, ref),
                  style: ElevatedButton.styleFrom(backgroundColor: tokens.dangerDot),
                  child: const Text('Return to Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final displayName = user.fullName.isNotEmpty ? user.fullName : user.username;
    final branchName = user.branch;
    final role = user.role.trim();
    final roleLower = role.toLowerCase();
    final isBm = role == 'Branch Manager' || role == 'BM';
    final isDirector = role == 'Director' || role == 'DIRECTOR' || role == 'Executive Director';
    final isProcurement = roleLower == 'procurement officer' ||
        roleLower == 'procurement_officer' ||
        roleLower == 'asset manager' ||
        roleLower == 'asset_manager' ||
        roleLower == 'procurement' ||
        roleLower == 'po';
    final isAdmin = role == 'Admin' || role == 'Super Admin' || role == 'ADMIN' || isDirector;
    final isAm = role == 'Area Manager' || role == 'AM';

    ref.listen<bool>(isOnlineProvider, (previous, next) async {
      if (previous == false && next == true) {
        _triggerPageRefresh(ref, activePage, isBm, isAm, isAdmin: isAdmin, isProcurement: isProcurement);
        final pendingCount = ref.read(pendingOutboxCountProvider);
        if (pendingCount > 0) {
          final syncMgr = ref.read(offlineSyncManagerProvider);
          final res = await syncMgr.syncOutbox();
          if (res.syncedCount > 0 || res.failedCount > 0) {
            ref.invalidate(collectionSheetFutureProvider);
            ref.invalidate(singleClientOptionsProvider);
            ref.invalidate(collectionsHistoryProvider);
            ref.invalidate(coDashboardProvider);
            ref.invalidate(individualOptionsProvider);
            ref.invalidate(groupOptionsProvider);
            ref.invalidate(lapsOptionsProvider);
            ref.invalidate(miscBalanceProvider);
            ref.invalidate(dailyWithdrawalsProvider);
            ref.invalidate(pendingApprovalsProvider);
            _triggerPageRefresh(ref, activePage, isBm, isAm, isAdmin: isAdmin, isProcurement: isProcurement);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(res.success ? Icons.cloud_done : Icons.warning_amber_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        res.success
                            ? 'Connection restored: Automatically synchronized ${res.syncedCount} queued transaction(s) to ledger.'
                            : 'Connection restored: ${res.message}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: res.success ? const Color(0xFF065F46) : const Color(0xFFB45309),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: res.success ? 4 : 8),
                action: res.success
                    ? null
                    : SnackBarAction(
                        label: 'Review',
                        textColor: Colors.white,
                        onPressed: () => _showSyncDialog(context, ref),
                      ),
              ),
            );
          }
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Connection restored. Live sync active.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              backgroundColor: Color(0xFF065F46),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });

    final roleBadge = isBm
        ? 'Branch Manager'
        : (isDirector
            ? 'Director'
            : (isProcurement
                ? 'Procurement Officer'
                : (isAdmin
                    ? 'Admin'
                    : (isAm
                        ? 'Area Manager'
                        : (role.isNotEmpty ? role : 'Credit Officer')))));

    final badgeColor = isBm
        ? const Color(0xFF2563EB)
        : (isProcurement
            ? const Color(0xFF0D9488)
            : (isAdmin
                ? const Color(0xFF7C3AED)
                : (isAm
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF8CC63F))));

    List<String> navItems;
    if (isBm) {
      navItems = ['Dashboard', 'Withdrawal Operations', 'Portfolio', 'Master Cashbook', 'User Management', 'Audit Ledger', 'Reports & Export'];
    } else if (isDirector) {
      navItems = [
        'Dashboard',
        'Portfolio',
        'Audit Ledger',
        'Reports & Export',
      ];
    } else if (isProcurement) {
      navItems = [
        'Dashboard',
        'Asset & Procurement',
      ];
    } else if (isAdmin) {
      navItems = [
        'Dashboard',
        'Asset & Procurement',
        'Portfolio',
        'User Management',
        'Reports & Export',
      ];
    } else if (isAm) {
      navItems = ['Dashboard', 'Portfolio', 'Master Cashbook', 'Branch Onboarding', 'User Management', 'Audit Ledger', 'Reports & Export'];
    } else {
      navItems = ['Dashboard', 'Loan Origination', 'Collections', 'Withdrawal Operations', 'Portfolio', 'CO Cashbook'];
    }


    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isMobile = screenWidth < 600;
    final compact = ref.watch(themeControllerProvider).compactDensity;
    final contentPadding = screenWidth < 600
        ? EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 10 : 14)
        : (screenWidth < 900
            ? EdgeInsets.all(compact ? 14 : 20)
            : EdgeInsets.all(compact ? 20 : 28));

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: tokens.isDark ? tokens.brandPrimaryDark : tokens.brandPrimary,
              elevation: 0,
              scrolledUnderElevation: 0,
              leadingWidth: 44,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  tooltip: 'Open Menu',
                ),
              ),
              titleSpacing: 0,
              title: Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/icare_logo.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ICARE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        roleBadge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                // 1. Online / Offline Pill (Interactive Tap-to-Check)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
                  child: _buildOnlineStatusPill(
                    context: context,
                    ref: ref,
                    activePage: activePage,
                    isBm: isBm,
                    isAm: isAm,
                    isAdmin: isAdmin,
                    isProcurement: isProcurement,
                  ),
                ),

                // 2. Explicit Refresh Action Button
                IconButton(
                  icon: const Icon(Icons.refresh, size: 19, color: Colors.white),
                  tooltip: 'Refresh Page',
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(32, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  onPressed: () async {
                    IcareFluidMotion.lightImpactHaptic(
                      ref.read(themeControllerProvider).hapticsEnabled,
                    );
                    await _triggerPageRefresh(ref, activePage, isBm, isAm, isAdmin: isAdmin, isProcurement: isProcurement);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text('Page data refreshed.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          backgroundColor: Color(0xFF065F46),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),

                // 2. Outbox Pending Badge & Sync Action
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
                  child: _buildOutboxSyncBadge(context, ref),
                ),

                // 3. User Avatar Pill / Direct Profile & Settings Trigger
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 10),
                  child: Tooltip(
                    message: 'Profile & Settings',
                    child: UserAvatarCircle(
                      fullName: displayName,
                      avatarUrl: user.avatarUrl,
                      size: 32,
                      backgroundColor: tokens.brandPrimaryLight,
                      borderColor: tokens.brandAccent.withValues(alpha: 0.75),
                      borderWidth: 1.4,
                      onTap: () {
                        ref.read(activeCoPageProvider.notifier).state = 'Settings & Profile';
                      },
                    ),
                  ),
                ),
              ],
            ),
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: tokens.surface,
              child: _buildDrawerContent(
                context,
                ref,
                displayName,
                user.avatarUrl,
                roleBadge,
                branchName,
                badgeColor,
                navItems,
                activePage,
              ),
            ),
      bottomNavigationBar: isDesktop
          ? null
          : _buildBottomNavBar(
              context,
              ref,
              navItems,
              activePage,
              isBm,
              isAm,
              isAdmin,
              isProcurement: isProcurement,
            ),
      body: Column(
        children: [
          // 1. Top Accent Running Bar
          Container(
            height: 3.0,
            width: double.infinity,
            color: tokens.brandPrimary,
          ),

          // 2. Main Body (Sidebar + Content Area)
          Expanded(
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ================= SIDEBAR =================
                      Container(
                        width: 270,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: tokens.surface,
                          border: Border(right: BorderSide(color: tokens.borderSubtle)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                        child: _buildSidebarContent(
                          context,
                          ref,
                          displayName,
                          user.avatarUrl,
                          roleBadge,
                          branchName,
                          badgeColor,
                          navItems,
                          activePage,
                          isBm: isBm,
                          isAm: isAm,
                          isAdmin: isAdmin,
                          isProcurement: isProcurement,
                        ),
                      ),

                      // ================= CONTENT AREA =================
                      Expanded(
                        child: RefreshIndicator(
                          color: tokens.brandPrimary,
                          backgroundColor: tokens.surfaceElevated,
                          displacement: 30,
                          onRefresh: () async {
                            IcareFluidMotion.lightImpactHaptic(
                              ref.read(themeControllerProvider).hapticsEnabled,
                            );
                            await _triggerPageRefresh(ref, activePage, isBm, isAm, isAdmin: isAdmin, isProcurement: isProcurement);
                          },
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: contentPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (activePage != 'Settings & Profile') ...[
                                  _buildWelcomeBanner(context, displayName, branchName, roleBadge),
                                  const SizedBox(height: 24),
                                ],

                                // Active View Dispatcher
                                _buildTransitionedActiveView(context, ref, activePage, isBm, isAm, isAdmin, isProcurement: isProcurement),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : RefreshIndicator(
                    color: tokens.brandPrimary,
                    backgroundColor: tokens.surfaceElevated,
                    displacement: 30,
                    onRefresh: () async {
                      IcareFluidMotion.lightImpactHaptic(
                        ref.read(themeControllerProvider).hapticsEnabled,
                      );
                      await _triggerPageRefresh(ref, activePage, isBm, isAm, isAdmin: isAdmin, isProcurement: isProcurement);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: contentPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Welcome Banner
                          if (activePage != 'Settings & Profile' && (!isMobile || activePage != 'Dashboard')) ...[
                            _buildWelcomeBanner(context, displayName, branchName, roleBadge, isMobile: isMobile),
                            SizedBox(height: isMobile ? 12 : 20),
                          ],

                          // Active View Dispatcher
                          _buildTransitionedActiveView(context, ref, activePage, isBm, isAm, isAdmin, isProcurement: isProcurement),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Modern Mobile Bottom Navigation Bar
  Widget _buildBottomNavBar(
    BuildContext context,
    WidgetRef ref,
    List<String> navItems,
    String activePage,
    bool isBm,
    bool isAm,
    bool isAdmin, {
    bool isProcurement = false,
  }) {
    final List<({String key, String shortLabel, IconData icon, IconData activeIcon})> destinations;
    if (isProcurement) {
      destinations = [
        (key: 'Dashboard', shortLabel: 'Overview', icon: Icons.analytics_outlined, activeIcon: Icons.analytics),
        (key: 'Asset & Procurement', shortLabel: 'Asset Hub', icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2),
      ];
    } else if (isAdmin) {
      destinations = [
        (key: 'Dashboard', shortLabel: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
        (key: 'Portfolio', shortLabel: 'Branches', icon: Icons.domain_outlined, activeIcon: Icons.domain),
        (key: 'Audit Ledger', shortLabel: 'Audit', icon: Icons.security_outlined, activeIcon: Icons.security),
        (key: 'Reports & Export', shortLabel: 'Reports', icon: Icons.analytics_outlined, activeIcon: Icons.analytics),
        (key: 'User Management', shortLabel: 'Users', icon: Icons.people_alt_outlined, activeIcon: Icons.people_alt),
      ];
    } else if (isBm) {
      destinations = [
        (key: 'Dashboard', shortLabel: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
        (key: 'Portfolio', shortLabel: 'Portfolio', icon: Icons.folder_shared_outlined, activeIcon: Icons.folder_shared),
        (key: 'Master Cashbook', shortLabel: 'Cashbook', icon: Icons.account_balance_outlined, activeIcon: Icons.account_balance),
        (key: 'User Management', shortLabel: 'Users', icon: Icons.people_alt_outlined, activeIcon: Icons.people_alt),
        (key: 'Reports & Export', shortLabel: 'Reports', icon: Icons.analytics_outlined, activeIcon: Icons.analytics),
      ];
    } else if (isAm) {
      destinations = [
        (key: 'Dashboard', shortLabel: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
        (key: 'Portfolio', shortLabel: 'Portfolio', icon: Icons.pie_chart_outline, activeIcon: Icons.pie_chart),
        (key: 'Master Cashbook', shortLabel: 'Cashbook', icon: Icons.account_balance_outlined, activeIcon: Icons.account_balance),
        (key: 'User Management', shortLabel: 'Staff', icon: Icons.people_alt_outlined, activeIcon: Icons.people_alt),
        (key: 'Reports & Export', shortLabel: 'Reports', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart),
      ];
    } else {
      destinations = [
        (key: 'Dashboard', shortLabel: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
        (key: 'Loan Origination', shortLabel: 'Origination', icon: Icons.person_add_alt_1_outlined, activeIcon: Icons.person_add_alt_1),
        (key: 'Collections', shortLabel: 'Collections', icon: Icons.payments_outlined, activeIcon: Icons.payments),
        (key: 'Withdrawal Operations', shortLabel: 'Withdrawals', icon: Icons.currency_exchange_outlined, activeIcon: Icons.currency_exchange),
        (key: 'Portfolio', shortLabel: 'Portfolio', icon: Icons.folder_shared_outlined, activeIcon: Icons.folder_shared),
      ];
    }

    final tokens = IcareSurfaceTokens.of(context);
    final availableDests = destinations.where((d) => navItems.contains(d.key)).toList();
    if (availableDests.isEmpty) return const SizedBox.shrink();

    final activeThemeColor = tokens.brandPrimary;
    final activeBgColor = tokens.brandSoftBg;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.borderSubtle, width: 1)),
        boxShadow: [
          BoxShadow(
            color: tokens.isDark ? const Color(0x30000000) : const Color(0x0C0F172A),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: availableDests.map((dest) {
              final isSelected = activePage == dest.key;
              return Expanded(
                child: InkWell(
                  onTap: () => _selectPage(ref, dest.key),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: IcareFluidMotion.resolveDuration(context, IcareFluidMotion.microDuration),
                    curve: IcareFluidMotion.standardCurve,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? activeBgColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SingleMotionBuilder(
                          value: isSelected ? 1.0 : 0.94,
                          motion: IcareFluidMotion.resolve(context, IcareFluidMotion.snappySpring),
                          builder: (_, scale, iconChild) => Transform.scale(
                            scale: scale,
                            child: iconChild,
                          ),
                          child: Icon(
                            isSelected ? dest.activeIcon : dest.icon,
                            size: 22,
                            color: isSelected ? activeThemeColor : tokens.textMuted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dest.shortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? activeThemeColor : tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  static String _formatBranchLocation(String branchName, {bool isAdmin = false}) {
    final clean = branchName.trim();
    if (isAdmin || clean.toLowerCase() == 'head office' || clean.toLowerCase() == 'headquarters' || clean.isEmpty) {
      return 'Head Office';
    }
    return '$clean Branch';
  }

  /// Modern Drawer Navigation
  Widget _buildDrawerContent(
    BuildContext context,
    WidgetRef ref,
    String displayName,
    String? avatarUrl,
    String roleBadge,
    String branchName,
    Color badgeColor,
    List<String> navItems,
    String activePage,
  ) {
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      children: [
        // Drawer Header with Brand Gradient & User Avatar (Tappable to open Settings)
        InkWell(
          onTap: () {
            ref.read(activeCoPageProvider.notifier).state = 'Settings & Profile';
            Navigator.of(context).pop();
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tokens.brandPrimaryDark,
                  tokens.brandPrimary,
                  tokens.brandPrimaryLight,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatarCircle(
                      fullName: displayName,
                      avatarUrl: avatarUrl,
                      size: 48,
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      borderColor: tokens.brandAccent,
                      borderWidth: 2,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              roleBadge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: Colors.white.withValues(alpha: 0.7)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: tokens.brandAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatBranchLocation(branchName, isAdmin: roleBadge == 'Admin'),
                        style: const TextStyle(
                          color: Color(0xE2FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Navigation Items List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  'OPERATIONS & MODULES',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ...navItems.map((item) {
                final isSelected = activePage == item;
                return _buildModernNavItem(
                  context: context,
                  label: item,
                  isSelected: isSelected,
                  onTap: () {
                    _selectPage(ref, item);
                    Navigator.of(context).pop();
                  },
                );
              }),
              const SizedBox(height: 12),
              Divider(color: tokens.borderSubtle, height: 1),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  'PERSONAL ACCOUNT',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _buildModernNavItem(
                context: context,
                label: 'Settings & Profile',
                isSelected: activePage == 'Settings & Profile',
                onTap: () {
                  _selectPage(ref, 'Settings & Profile');
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),

        // Drawer Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            border: Border(top: BorderSide(color: tokens.borderSubtle)),
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: tokens.surface,
                    foregroundColor: tokens.dangerText,
                    side: BorderSide(color: tokens.dangerBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: Icon(Icons.logout, size: 16, color: tokens.dangerText),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleSignOut(context, ref);
                  },
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'CORE BANKING v3.0.0',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineStatusPill({
    required BuildContext context,
    required WidgetRef ref,
    required String activePage,
    required bool isBm,
    required bool isAm,
    required bool isAdmin,
    bool isProcurement = false,
  }) {
    return Consumer(
      builder: (context, ref, child) {
        final isOnline = ref.watch(isOnlineProvider);
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            IcareFluidMotion.lightImpactHaptic(
              ref.read(themeControllerProvider).hapticsEnabled,
            );
            final connected = await ref.read(isOnlineProvider.notifier).refresh();
            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        connected ? Icons.wifi : Icons.wifi_off,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        connected ? 'Connection verified online. Synchronizing...' : 'No internet detected. Working in offline mode.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  backgroundColor: connected ? const Color(0xFF065F46) : const Color(0xFF92400E),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            }
            if (connected) {
              _triggerPageRefresh(ref, activePage, isBm, isAm, isAdmin: isAdmin, isProcurement: isProcurement);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFF065F46) : const Color(0xFF92400E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOutboxSyncBadge(BuildContext context, WidgetRef ref, {bool expandedLabel = false}) {
    return Consumer(
      builder: (context, ref, child) {
        final pendingCount = ref.watch(pendingOutboxCountProvider);
        final quarantinedCount = ref.watch(quarantinedOutboxCountProvider);
        final totalCount = pendingCount + quarantinedCount;
        if (totalCount == 0) return const SizedBox.shrink();
        final hasAttention = quarantinedCount > 0;
        final badgeBg = hasAttention ? const Color(0xFFDC2626) : const Color(0xFFD97706);
        final badgeText = expandedLabel
            ? (pendingCount > 0 ? 'Sync ($totalCount)' : 'Review ($quarantinedCount)')
            : '$totalCount';
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: badgeBg,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            minimumSize: const Size(0, 28),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          icon: Icon(hasAttention ? Icons.warning_amber_rounded : Icons.sync, size: 13, color: Colors.white),
          label: Text(
            badgeText,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _showSyncDialog(context, ref),
        );
      },
    );
  }

  /// Modern Desktop Sidebar Content
  Widget _buildSidebarContent(
    BuildContext context,
    WidgetRef ref,
    String displayName,
    String? avatarUrl,
    String roleBadge,
    String branchName,
    Color badgeColor,
    List<String> navItems,
    String activePage, {
    required bool isBm,
    required bool isAm,
    required bool isAdmin,
    bool isProcurement = false,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      children: [
        // Top Sidebar Content
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Circular Logo
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F2744),
                  border: Border.all(color: tokens.brandAccent, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icare_logo.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        'IC',
                        style: TextStyle(
                          color: tokens.brandAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // App Version Label
            const SizedBox(height: 6),
            Center(
              child: Text(
                'CORE BANKING v3.0.0',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: tokens.borderSubtle, height: 1),
            const SizedBox(height: 14),

            // Officer Profile Card (Tappable to open Settings & Profile)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  ref.read(activeCoPageProvider.notifier).state = 'Settings & Profile';
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: activePage == 'Settings & Profile' ? tokens.brandSoftBg : tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: activePage == 'Settings & Profile' ? tokens.brandSoftBorder : tokens.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      UserAvatarCircle(
                        fullName: displayName,
                        avatarUrl: avatarUrl,
                        size: 38,
                        backgroundColor: tokens.brandPrimary,
                        borderColor: tokens.brandAccent.withValues(alpha: 0.7),
                        borderWidth: 1.5,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    roleBadge,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _formatBranchLocation(branchName, isAdmin: roleBadge == 'Admin'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tokens.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Network Connectivity & Outbox Sync Bar (Desktop Visibility)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Row(
                children: [
                  _buildOnlineStatusPill(
                    context: context,
                    ref: ref,
                    activePage: activePage,
                    isBm: isBm,
                    isAm: isAm,
                    isAdmin: isAdmin,
                    isProcurement: isProcurement,
                  ),
                  const Spacer(),
                  _buildOutboxSyncBadge(context, ref, expandedLabel: true),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _triggerPageRefresh(ref, activePage, isBm, isAm, isAdmin: isAdmin, isProcurement: isProcurement),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.refresh, size: 16, color: tokens.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // OPERATIONS Label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'OPERATIONS',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Modern Navigation Items
            Column(
              children: navItems.map((item) {
                final isSelected = activePage == item;
                return _buildModernNavItem(
                  context: context,
                  label: item,
                  isSelected: isSelected,
                  onTap: () => _selectPage(ref, item),
                );
              }).toList(),
            ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Bottom Account Settings & Sign Out Actions
        Column(
          children: [
            Divider(color: tokens.borderSubtle, height: 1),
            const SizedBox(height: 10),
            _buildModernNavItem(
              context: context,
              label: 'Settings & Profile',
              isSelected: activePage == 'Settings & Profile',
              onTap: () => _selectPage(ref, 'Settings & Profile'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: tokens.surface,
                  foregroundColor: tokens.textSecondary,
                  side: BorderSide(color: tokens.borderStrong),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                icon: Icon(Icons.logout, size: 15, color: tokens.textMuted),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  _handleSignOut(context, ref);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Modern Navigation Item Tile with Left Active Bar & Icon
  Widget _buildModernNavItem({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    final icon = _getNavIcon(label, active: isSelected);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: IcareFluidMotion.resolveDuration(context, IcareFluidMotion.microDuration),
            curve: IcareFluidMotion.standardCurve,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? tokens.brandSoftBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? tokens.brandSoftBorder : Colors.transparent,
                width: 0.9,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: IcareFluidMotion.resolveDuration(context, IcareFluidMotion.microDuration),
                  curve: IcareFluidMotion.standardCurve,
                  width: 3.5,
                  height: isSelected ? 16 : 0,
                  decoration: BoxDecoration(
                    color: isSelected ? tokens.brandPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? tokens.brandSoftText : tokens.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? tokens.brandSoftText : tokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNavIcon(String item, {bool active = false}) {
    switch (item) {
      case 'Dashboard':
        return active ? Icons.dashboard : Icons.dashboard_outlined;
      case 'Asset & Procurement':
        return active ? Icons.inventory_2 : Icons.inventory_2_outlined;
      case 'Collections':
        return active ? Icons.payments : Icons.payments_outlined;
      case 'Loan Origination':
        return active ? Icons.person_add_alt_1 : Icons.person_add_alt_1_outlined;
      case 'Portfolio':
        return active ? Icons.folder_shared : Icons.folder_shared_outlined;
      case 'Branch Onboarding':
        return active ? Icons.domain_add : Icons.domain_add_outlined;
      case 'CO Cashbook':
        return active ? Icons.account_balance_wallet : Icons.account_balance_wallet_outlined;
      case 'Master Cashbook':
        return active ? Icons.account_balance : Icons.account_balance_outlined;
      case 'Withdrawal Operations':
        return active ? Icons.currency_exchange : Icons.currency_exchange_outlined;
      case 'User Management':
        return active ? Icons.people_alt : Icons.people_alt_outlined;
      case 'Audit Ledger':
      case 'Audit Center':
        return active ? Icons.security : Icons.security_outlined;
      case 'Reports & Export':
      case 'Reports':
        return active ? Icons.analytics : Icons.analytics_outlined;
      case 'Settings & Profile':
        return active ? Icons.manage_accounts : Icons.manage_accounts_outlined;
      default:
        return active ? Icons.circle : Icons.circle_outlined;
    }
  }

  /// Welcome Banner (app.py L1991-2000)
  Widget _buildWelcomeBanner(BuildContext context, String displayName, String branchName, String roleBadge, {bool isMobile = false}) {
    final tokens = IcareSurfaceTokens.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    final isAm = roleBadge == 'Area Manager' || roleBadge == 'AM';
    final isBm = roleBadge == 'Branch Manager' || roleBadge == 'BM';

    if (isMobile) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: tokens.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isAm ? Icons.hub_outlined : (isBm ? Icons.shield_outlined : Icons.location_on_outlined),
              size: 14,
              color: tokens.brandPrimary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                roleBadge == 'Admin'
                    ? 'Head Office · $formattedDate'
                    : (isAm
                        ? 'Regional Supervisory Command · $formattedDate'
                        : (isBm
                            ? '$branchName Branch Command · $formattedDate'
                            : '${_formatBranchLocation(branchName)} · $formattedDate')),
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isAm
            ? const Color(0xFF0F766E)
            : (isBm
                ? const Color(0xFF1E3A8A)
                : (tokens.isDark ? tokens.brandPrimaryDark : tokens.brandPrimary)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, $displayName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
              children: [
                TextSpan(text: '$roleBadge — '),
                TextSpan(
                  text: roleBadge == 'Admin'
                      ? 'Head Office'
                      : (isAm
                          ? 'Regional Command Center'
                          : (isBm
                              ? '$branchName Branch Command'
                              : _formatBranchLocation(branchName))),
                  style: TextStyle(
                    color: roleBadge == 'Admin'
                        ? const Color(0xFFDDD6FE)
                        : (isAm ? const Color(0xFF99F6E4) : (isBm ? const Color(0xFF93C5FD) : const Color(0xFF8CC63F))),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: ' · $formattedDate'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView(BuildContext context, WidgetRef ref, String page, bool isBm, bool isAm, bool isAdmin, {bool isProcurement = false}) {
    final tokens = IcareSurfaceTokens.of(context);
    switch (page) {
      case 'Dashboard':
        if (isProcurement) return const ProcurementDashboardScreen();
        if (isAdmin) return const AdminDashboardScreen();
        if (isAm) return const AmDashboardScreen();
        return isBm ? const BmDashboardScreen() : const CoDashboardScreen();
      case 'Asset & Procurement':
        return const AssetProcurementScreen();
      case 'Loan Origination':
        return const LoanOriginationScreen();
      case 'Collections':
        return const DailyCollectionsScreen();
      case 'Withdrawal Operations':
        return const WithdrawalOperationsScreen();
      case 'Portfolio':
        if (isAdmin) return const AdminPortfolioScreen();
        if (isAm) return const AmPortfolioScreen();
        return const PortfolioOverviewScreen();
      case 'CO Cashbook':
        return const DailyCashbookScreen();
      case 'Master Cashbook':
        return const MasterCashbookScreen();
      case 'Audit Ledger':
      case 'Audit Center':
        return const AuditLedgerScreen();
      case 'User Management':
        return const UserManagementScreen();
      case 'Reports & Export':
      case 'Reports':
        return const ReportsExportScreen();
      case 'Branch Onboarding':
        return const BranchOnboardingAdminScreen();
      case 'Settings & Profile':
        return SettingsProfileScreen(
          onRequestSignOut: () => _handleSignOut(context, ref),
          onOpenOutboxSync: () => _showSyncDialog(context, ref),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Text(
            'Page: $page (Awaiting Page Parity Specification & Implementation)',
            style: TextStyle(fontSize: 14, color: tokens.textMuted),
          ),
        );
    }
  }

  void _showSyncDialog(BuildContext context, WidgetRef ref) {
    showIcareDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _SyncDialog(),
    );
  }
}

class _SyncDialog extends ConsumerStatefulWidget {
  const _SyncDialog();

  @override
  ConsumerState<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends ConsumerState<_SyncDialog> {
  bool _isSyncing = false;
  String? _statusMsg;
  bool _isSuccess = false;

  void _invalidateAfterOutboxChange() {
    ref.invalidate(collectionSheetFutureProvider);
    ref.invalidate(singleClientOptionsProvider);
    ref.invalidate(collectionsHistoryProvider);
    ref.invalidate(coDashboardProvider);
    ref.invalidate(individualOptionsProvider);
    ref.invalidate(groupOptionsProvider);
    ref.invalidate(lapsOptionsProvider);
    ref.invalidate(miscBalanceProvider);
    ref.invalidate(dailyWithdrawalsProvider);
    ref.invalidate(pendingApprovalsProvider);
  }

  ({String typeLabel, double totalAmount, String amountDetail}) _summarizePayload(Map<String, dynamic> item) {
    final opType = item['operation_type']?.toString() ?? 'BATCH_COLLECTION';
    try {
      final payload = jsonDecode(item['payload_json']?.toString() ?? '{}') as Map<String, dynamic>;
      if (opType == 'WITHDRAWAL_REQUEST') {
        final amt = (payload['amount'] as num?)?.toDouble() ?? 0.0;
        final sType = payload['savings_type']?.toString() ?? 'Savings';
        final opName = payload['operation_type']?.toString() ?? 'Request';
        return (
          typeLabel: '$sType Withdrawal Request ($opName)',
          totalAmount: amt,
          amountDetail: CurrencyFormatter.formatNaira(amt),
        );
      }
      if (opType == 'SINGLE_COLLECTION') {
        final rep = (payload['loan_repayment'] as num?)?.toDouble() ?? 0.0;
        final sav = (payload['savings_deposit'] as num?)?.toDouble() ?? 0.0;
        final grp = (payload['group_savings_deposit'] as num?)?.toDouble() ?? 0.0;
        final fees = ((payload['app_fee'] as num?)?.toDouble() ?? 0.0) +
            ((payload['passbook_fee'] as num?)?.toDouble() ?? 0.0) +
            ((payload['misc_fee'] as num?)?.toDouble() ?? 0.0);
        final tot = rep + sav + grp + fees;
        return (
          typeLabel: 'Single Client Collection',
          totalAmount: tot,
          amountDetail: CurrencyFormatter.formatNaira(tot),
        );
      }
      final cols = (payload['collections'] as List?)?.whereType<Map>() ?? const Iterable.empty();
      double tot = (payload['group_savings_deposit'] as num?)?.toDouble() ?? 0.0;
      for (final c in cols) {
        tot += ((c['loan_repayment_amount'] as num?)?.toDouble() ?? 0.0) +
            ((c['savings_deposit_amount'] as num?)?.toDouble() ?? 0.0) +
            ((c['app_fee'] as num?)?.toDouble() ?? 0.0) +
            ((c['passbook_bonus'] as num?)?.toDouble() ?? 0.0) +
            ((c['misc_fees'] as num?)?.toDouble() ?? 0.0);
      }
      return (
        typeLabel: 'Group Collection (${cols.length} member${cols.length == 1 ? '' : 's'})',
        totalAmount: tot,
        amountDetail: CurrencyFormatter.formatNaira(tot),
      );
    } catch (_) {
      return (
        typeLabel: opType == 'WITHDRAWAL_REQUEST'
            ? 'Withdrawal Request'
            : (opType == 'SINGLE_COLLECTION' ? 'Single Client' : 'Group Batch'),
        totalAmount: 0.0,
        amountDetail: '',
      );
    }
  }

  Future<bool> _confirmDiscard(BuildContext context, String label, bool isQuarantined) async {
    final res = await showIcareDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Remove Offline Record', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(
          isQuarantined
              ? 'Removing "$label" deletes its local unposted offline copy from this device permanently. Confirm only if these figures have already been recorded separately.'
              : 'Remove queued batch "$label" from this device?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return res == true;
  }

  Widget _buildOutboxListSection({
    required Future<List<Map<String, dynamic>>> future,
    required bool isQuarantinedSection,
    required bool isOnline,
    required OfflineSyncManager syncMgr,
    required IcareSurfaceTokens tokens,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        if (items.isEmpty) return const SizedBox.shrink();

        return Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: isQuarantinedSection ? tokens.dangerBg.withValues(alpha: 0.35) : tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isQuarantinedSection ? tokens.dangerBorder : tokens.borderSubtle),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: tokens.borderSubtle),
            itemBuilder: (context, idx) {
              final item = items[idx];
              final opType = item['operation_type']?.toString() ?? 'BATCH_COLLECTION';
              final groupOrClient = item['group_name']?.toString() ?? 'Transaction';
              final colDate = item['collection_date']?.toString() ?? '';
              final statusStr = item['status']?.toString() ?? 'pending';
              final isFailed = statusStr == 'failed' || statusStr == 'quarantined';
              final isQuarantined = statusStr == 'quarantined';
              final errMsg = item['error_message']?.toString();
              final summary = _summarizePayload(item);
              final badgeColor = isQuarantined
                  ? tokens.dangerBg
                  : (isFailed ? tokens.warningBg : tokens.warningBg);
              final badgeTextColor = isQuarantined
                  ? tokens.dangerText
                  : (isFailed ? tokens.dangerText : tokens.warningText);
              final badgeLabel = isQuarantined ? 'Needs Review' : (isFailed ? 'Retrying' : 'Pending');

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: opType == 'WITHDRAWAL_REQUEST'
                                ? tokens.warningBg
                                : (opType == 'SINGLE_COLLECTION' ? tokens.infoBg : tokens.successBg),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            opType == 'WITHDRAWAL_REQUEST'
                                ? Icons.account_balance_wallet_outlined
                                : (opType == 'SINGLE_COLLECTION' ? Icons.person_outline : Icons.groups_outlined),
                            size: 16,
                            color: opType == 'WITHDRAWAL_REQUEST'
                                ? tokens.warningDot
                                : (opType == 'SINGLE_COLLECTION' ? tokens.infoDot : tokens.successDot),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                groupOrClient,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$colDate · ${summary.typeLabel}${summary.amountDetail.isNotEmpty ? ' · ${summary.amountDetail}' : ''}',
                                style: TextStyle(fontSize: 10.5, color: tokens.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeTextColor),
                          ),
                        ),
                      ],
                    ),
                    if (isFailed && errMsg != null && errMsg.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: tokens.dangerBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: tokens.dangerBorder),
                        ),
                        child: Text(
                          errMsg,
                          style: TextStyle(fontSize: 10.5, color: tokens.dangerText, height: 1.3),
                        ),
                      ),
                    ],
                    if (isFailed) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isQuarantined)
                            TextButton.icon(
                              onPressed: _isSyncing
                                  ? null
                                  : () async {
                                      final bId = item['id'] as int?;
                                      if (bId == null) return;
                                      setState(() {
                                        _isSyncing = true;
                                        _statusMsg = 'Retrying batch #$bId...';
                                      });
                                      final res = await syncMgr.retryQuarantinedBatch(bId, syncNow: isOnline);
                                      _invalidateAfterOutboxChange();
                                      if (mounted) {
                                        setState(() {
                                          _isSyncing = false;
                                          if (res != null) {
                                            _isSuccess = res.success;
                                            _statusMsg = res.message;
                                          } else {
                                            _isSuccess = true;
                                            _statusMsg = 'Batch #$bId returned to pending sync queue.';
                                          }
                                        });
                                      }
                                    },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                minimumSize: const Size(0, 26),
                              ),
                              icon: Icon(Icons.refresh, size: 14, color: tokens.brandPrimary),
                              label: Text(
                                isOnline ? 'Retry Now' : 'Queue Retry',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.brandPrimary),
                              ),
                            ),
                          const SizedBox(width: 6),
                          TextButton.icon(
                            onPressed: _isSyncing
                                ? null
                                : () async {
                                    final bId = item['id'] as int?;
                                    if (bId == null) return;
                                    final confirmed = await _confirmDiscard(context, groupOrClient, isQuarantined);
                                    if (!confirmed) return;
                                    await syncMgr.discardOutboxBatch(bId);
                                    _invalidateAfterOutboxChange();
                                    if (mounted) {
                                      setState(() {
                                        _statusMsg = 'Batch #$bId discarded from outbox.';
                                        _isSuccess = true;
                                      });
                                    }
                                  },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: const Size(0, 26),
                            ),
                            icon: Icon(Icons.delete_outline, size: 14, color: tokens.dangerText),
                            label: Text(
                              'Discard',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.dangerText),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(pendingOutboxCountProvider);
    final quarantinedCount = ref.watch(quarantinedOutboxCountProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final syncMgr = ref.read(offlineSyncManagerProvider);
    final tokens = IcareSurfaceTokens.of(context);

    return AlertDialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: tokens.borderSubtle),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tokens.warningBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.warningBorder),
            ),
            child: Icon(Icons.cloud_sync, color: tokens.warningDot, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OFFLINE OUTBOX SYNC',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                ),
                Text(
                  'Post queued collections to the central ledger',
                  style: TextStyle(fontSize: 11, color: tokens.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            InkWell(
              onTap: () {
                ref.read(isOnlineProvider.notifier).refresh();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOnline ? Icons.wifi : Icons.wifi_off,
                      size: 18,
                      color: isOnline ? tokens.successDot : tokens.dangerDot,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOnline ? 'Network Connection: Verified Online' : 'Network Connection: Offline (Tap to Check)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOnline ? tokens.successText : tokens.dangerText,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.refresh,
                      size: 16,
                      color: isOnline ? tokens.successText : tokens.dangerText,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pending transactions on device: $pendingCount',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Queued transactions will post atomically to primary vault cash and the double-entry financial ledger.',
              style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
            ),
            if (pendingCount > 0) ...[
              const SizedBox(height: 10),
              _buildOutboxListSection(
                future: ref.read(offlineDatabaseServiceProvider).getPendingOutboxBatches(),
                isQuarantinedSection: false,
                isOnline: isOnline,
                syncMgr: syncMgr,
                tokens: tokens,
              ),
            ],
            if (quarantinedCount > 0) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: tokens.dangerText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rejected / Needs Review: $quarantinedCount item(s)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.dangerText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'These records were rejected by the server and were preserved on this device so no field entry is lost. Review the rejection reason before retrying or discarding.',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 8),
              _buildOutboxListSection(
                future: ref.read(offlineDatabaseServiceProvider).getQuarantinedOutboxBatches(),
                isQuarantinedSection: true,
                isOnline: isOnline,
                syncMgr: syncMgr,
                tokens: tokens,
              ),
            ],
            if (_statusMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isSuccess ? tokens.successBg : tokens.dangerBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isSuccess ? tokens.successBorder : tokens.dangerBorder,
                  ),
                ),
                child: Text(
                  _statusMsg!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isSuccess ? tokens.successText : tokens.dangerText,
                  ),
                ),
              ),
            ],
            if (_isSyncing) ...[
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: tokens.brandPrimary),
                ),
              ),
            ],
          ],
          ),
        ),
      ),
      actions: [
        if (pendingCount > 0)
          TextButton.icon(
            onPressed: _isSyncing
                ? null
                : () async {
                    final cleared = await syncMgr.clearAllFailedBatches();
                    if (cleared > 0) _invalidateAfterOutboxChange();
                    if (mounted) {
                      setState(() {
                        _statusMsg = cleared > 0 ? 'Cleared $cleared failed transaction(s).' : 'No failed transactions to clear.';
                        _isSuccess = true;
                      });
                    }
                  },
            icon: Icon(Icons.delete_sweep_outlined, size: 16, color: tokens.dangerText),
            label: Text('Clear Failed', style: TextStyle(color: tokens.dangerText, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        if (quarantinedCount > 0)
          TextButton.icon(
            onPressed: _isSyncing
                ? null
                : () async {
                    final confirmed = await _confirmDiscard(context, '$quarantinedCount rejected item(s)', true);
                    if (!confirmed) return;
                    final cleared = await syncMgr.clearAllQuarantinedBatches();
                    if (cleared > 0) _invalidateAfterOutboxChange();
                    if (mounted) {
                      setState(() {
                        _statusMsg = cleared > 0 ? 'Cleared $cleared rejected transaction(s).' : 'No rejected items to clear.';
                        _isSuccess = true;
                      });
                    }
                  },
            icon: Icon(Icons.delete_forever_outlined, size: 16, color: tokens.dangerText),
            label: Text('Clear Review', style: TextStyle(color: tokens.dangerText, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        TextButton(
          onPressed: _isSyncing ? null : () => Navigator.of(context).pop(),
          child: Text('Close', style: TextStyle(color: tokens.textMuted, fontWeight: FontWeight.w600)),
        ),
        ElevatedButton.icon(
          onPressed: (!isOnline || _isSyncing || pendingCount == 0)
              ? null
              : () async {
                  setState(() {
                    _isSyncing = true;
                    _statusMsg = 'Syncing batches to central ledger...';
                  });
                  final res = await syncMgr.syncOutbox();
                  if (res.syncedCount > 0 || res.failedCount > 0) {
                    _invalidateAfterOutboxChange();
                  }
                  if (mounted) {
                    setState(() {
                      _isSyncing = false;
                      _isSuccess = res.success;
                      _statusMsg = res.message;
                    });
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: tokens.brandPrimary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: tokens.borderStrong,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          icon: const Icon(Icons.cloud_upload_outlined, size: 16),
          label: const Text('Sync Now', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

