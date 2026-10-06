import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_sync_manager.dart';
import '../../co/presentation/co_dashboard_screen.dart';
import '../../co/presentation/loan_origination_screen.dart';
import '../../co/presentation/daily_collections_screen.dart';
import '../../co/presentation/withdrawal_operations_screen.dart';
import '../../co/presentation/portfolio_overview_screen.dart';
import '../../co/presentation/daily_cashbook_screen.dart';
import '../../bm/presentation/bm_dashboard_screen.dart';
import '../../bm/presentation/master_cashbook_screen.dart';
import '../../bm/presentation/user_management_screen.dart';
import '../../audit/presentation/audit_ledger_screen.dart';
import '../../reports/presentation/reports_export_screen.dart';
import '../../auth/presentation/login_screen.dart';

/// Active page state provider for Streamlit-style radio navigation
final activeCoPageProvider = StateProvider<String>((ref) => 'Dashboard');

/// Selected group provider when navigating from Dashboard quick action into Collections
final selectedCollectionGroupProvider = StateProvider<String?>((ref) => null);

/// Main Application Shell for Credit Officer (1:1 replica of app.py L1925-2000 & media_1788063430479.png)
class CoAppScaffold extends ConsumerWidget {
  const CoAppScaffold({super.key});

  void _handleSignOut(BuildContext context, WidgetRef ref) {
    ref.read(activeCoPageProvider.notifier).state = 'Dashboard';
    ref.read(authControllerProvider.notifier).logout();
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
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
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
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: Color(0xFFDC2626), size: 48),
                const SizedBox(height: 16),
                const Text(
                  'ACCESS RESTRICTED: MISSING AUTHENTICATED SCOPE',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                ),
                const SizedBox(height: 8),
                Text(
                  'No valid branch scope was detected for ${user.username}. The system fails closed per governance rule FP-001.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _handleSignOut(context, ref),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
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
    final isBm = role == 'Branch Manager' || role == 'BM';
    final isAdmin = role == 'Admin' || role == 'Super Admin' || role == 'ADMIN';
    final isAm = role == 'Area Manager' || role == 'AM';

    final roleBadge = isBm
        ? 'Branch Manager'
        : (isAdmin
            ? 'Admin'
            : (isAm
                ? 'Area Manager'
                : (role.isNotEmpty ? role : 'Credit Officer')));

    final badgeColor = isBm
        ? const Color(0xFF2563EB)
        : (isAdmin
            ? const Color(0xFF7C3AED)
            : (isAm
                ? const Color(0xFFD97706)
                : const Color(0xFF8CC63F)));

    List<String> navItems;
    if (isBm) {
      navItems = ['Dashboard', 'Portfolio', 'Master Cashbook', 'User Management', 'Audit Ledger', 'Reports & Export'];
    } else if (isAdmin) {
      navItems = ['Dashboard', 'Portfolio', 'Loan Origination', 'Collections', 'Withdrawal Operations', 'CO Cashbook', 'Master Cashbook', 'User Management', 'Audit Ledger', 'Reports & Export'];
    } else if (isAm) {
      navItems = ['Dashboard', 'Portfolio', 'Master Cashbook', 'CO Cashbook', 'User Management', 'Audit Ledger', 'Reports & Export'];
    } else {
      navItems = ['Dashboard', 'Loan Origination', 'Collections', 'Withdrawal Operations', 'Portfolio', 'CO Cashbook'];
    }


    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isMobile = screenWidth < 600;
    final contentPadding = screenWidth < 600
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 14)
        : (screenWidth < 900
            ? const EdgeInsets.all(20)
            : const EdgeInsets.all(28));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF064E3B),
              elevation: 0,
              scrolledUnderElevation: 0,
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
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ICARE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
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
              actions: [
                // 1. Online / Offline Pill
                Consumer(
                  builder: (context, ref, child) {
                    final isOnline = ref.watch(isOnlineProvider);
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                          const SizedBox(width: 4),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // 2. Outbox Pending Badge & Sync Action
                Consumer(
                  builder: (context, ref, child) {
                    final pendingCount = ref.watch(pendingOutboxCountProvider);
                    if (pendingCount == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 3),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          minimumSize: const Size(0, 28),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.sync, size: 13, color: Colors.white),
                        label: Text(
                          '$pendingCount',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _showSyncDialog(context, ref),
                      ),
                    );
                  },
                ),

                // 3. User Avatar Pill / Profile Drawer Trigger
                Builder(
                  builder: (ctx) => InkWell(
                    onTap: () => Scaffold.of(ctx).openDrawer(),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, right: 12),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF047857),
                          border: Border.all(color: const Color(0x80A7F3D0), width: 1.2),
                        ),
                        child: Center(
                          child: Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: Colors.white,
              child: _buildDrawerContent(
                context,
                ref,
                displayName,
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
            ),
      body: Column(
        children: [
          // 1. Top Accent Running Bar
          Container(
            height: 3.0,
            width: double.infinity,
            color: const Color(0xFF065F46),
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
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                        child: _buildSidebarContent(
                          context,
                          ref,
                          displayName,
                          roleBadge,
                          branchName,
                          badgeColor,
                          navItems,
                          activePage,
                        ),
                      ),

                      // ================= CONTENT AREA =================
                      Expanded(
                        child: SingleChildScrollView(
                          padding: contentPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Welcome Banner
                              _buildWelcomeBanner(displayName, branchName, roleBadge),
                              const SizedBox(height: 24),

                              // Active View Dispatcher
                              _buildActiveView(activePage, isBm),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    padding: contentPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Banner
                        if (!isMobile || activePage != 'Dashboard') ...[
                          _buildWelcomeBanner(displayName, branchName, roleBadge, isMobile: isMobile),
                          SizedBox(height: isMobile ? 12 : 20),
                        ],

                        // Active View Dispatcher
                        _buildActiveView(activePage, isBm),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Modern Mobile Bottom Navigation Bar (Cleaner 4-item layout for CO)
  Widget _buildBottomNavBar(
    BuildContext context,
    WidgetRef ref,
    List<String> navItems,
    String activePage,
    bool isBm,
  ) {
    final List<({String key, String shortLabel, IconData icon, IconData activeIcon})> destinations;
    if (isBm) {
      destinations = [
        (key: 'Dashboard', shortLabel: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
        (key: 'Portfolio', shortLabel: 'Portfolio', icon: Icons.folder_shared_outlined, activeIcon: Icons.folder_shared),
        (key: 'Master Cashbook', shortLabel: 'Cashbook', icon: Icons.account_balance_outlined, activeIcon: Icons.account_balance),
        (key: 'User Management', shortLabel: 'Users', icon: Icons.people_alt_outlined, activeIcon: Icons.people_alt),
        (key: 'Audit Ledger', shortLabel: 'Audit', icon: Icons.security_outlined, activeIcon: Icons.security),
      ];
    } else {
      destinations = [
        (key: 'Dashboard', shortLabel: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
        (key: 'Loan Origination', shortLabel: 'Origination', icon: Icons.person_add_alt_1_outlined, activeIcon: Icons.person_add_alt_1),
        (key: 'Withdrawal Operations', shortLabel: 'Withdrawals', icon: Icons.currency_exchange_outlined, activeIcon: Icons.currency_exchange),
        (key: 'Portfolio', shortLabel: 'Portfolio', icon: Icons.folder_shared_outlined, activeIcon: Icons.folder_shared),
      ];
    }

    final availableDests = destinations.where((d) => navItems.contains(d.key)).toList();
    if (availableDests.isEmpty) return const SizedBox.shrink();

    final activeThemeColor = isBm ? const Color(0xFF2563EB) : const Color(0xFF065F46);
    final activeBgColor = isBm ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 10,
            offset: Offset(0, -3),
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
                  onTap: () {
                    ref.read(activeCoPageProvider.notifier).state = dest.key;
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? activeBgColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? dest.activeIcon : dest.icon,
                          size: 22,
                          color: isSelected ? activeThemeColor : const Color(0xFF64748B),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dest.shortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? activeThemeColor : const Color(0xFF64748B),
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

  /// Modern Drawer Navigation
  Widget _buildDrawerContent(
    BuildContext context,
    WidgetRef ref,
    String displayName,
    String roleBadge,
    String branchName,
    Color badgeColor,
    List<String> navItems,
    String activePage,
  ) {
    return Column(
      children: [
        // Drawer Header with Deep Emerald Gradient
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF022C22),
                Color(0xFF064E3B),
                Color(0xFF047857),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF8CC63F), width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icare_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Text('IC', style: TextStyle(color: Color(0xFF064E3B), fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
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
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF8CC63F)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$branchName Branch',
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

        // Navigation Items List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  'OPERATIONS & MODULES',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
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
                    ref.read(activeCoPageProvider.notifier).state = item;
                    Navigator.of(context).pop();
                  },
                );
              }),
            ],
          ),
        ),

        // Drawer Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.logout, size: 16, color: Color(0xFFDC2626)),
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
              const Text(
                'CORE BANKING v3.0.0 (st v1.38.0)',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
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

  /// Modern Desktop Sidebar Content
  Widget _buildSidebarContent(
    BuildContext context,
    WidgetRef ref,
    String displayName,
    String roleBadge,
    String branchName,
    Color badgeColor,
    List<String> navItems,
    String activePage,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Top Sidebar Content
        Column(
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
                  border: Border.all(color: const Color(0xFF8CC63F), width: 2),
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
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text(
                        'IC',
                        style: TextStyle(
                          color: Color(0xFF8CC63F),
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
            const Center(
              child: Text(
                'CORE BANKING v3.0.0 (st v1.38.0)',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 14),

            // Officer Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(8),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$branchName Branch',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11.5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // OPERATIONS Label
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'OPERATIONS',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
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
                  onTap: () {
                    ref.read(activeCoPageProvider.notifier).state = item;
                  },
                );
              }).toList(),
            ),
          ],
        ),

        // Bottom Sign Out Button
        Column(
          children: [
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                icon: const Icon(Icons.logout, size: 15, color: Color(0xFF64748B)),
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
    final icon = _getNavIcon(label, active: isSelected);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFECFDF5) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: const Color(0xFFA7F3D0), width: 0.9)
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 3.5,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF065F46) : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? const Color(0xFF065F46) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF065F46) : const Color(0xFF1E293B),
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
      case 'Collections':
        return active ? Icons.payments : Icons.payments_outlined;
      case 'Loan Origination':
        return active ? Icons.person_add_alt_1 : Icons.person_add_alt_1_outlined;
      case 'Portfolio':
        return active ? Icons.folder_shared : Icons.folder_shared_outlined;
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
      default:
        return active ? Icons.circle : Icons.circle_outlined;
    }
  }

  /// Welcome Banner (app.py L1991-2000)
  Widget _buildWelcomeBanner(String displayName, String branchName, String roleBadge, {bool isMobile = false}) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

    if (isMobile) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF064E3B)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$branchName Branch · $formattedDate',
                style: const TextStyle(
                  color: Color(0xFF334155),
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
        color: const Color(0xFF064E3B),
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
                  text: '$branchName Branch',
                  style: const TextStyle(
                    color: Color(0xFF8CC63F),
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

  Widget _buildActiveView(String page, bool isBm) {
    switch (page) {
      case 'Dashboard':
        return isBm ? const BmDashboardScreen() : const CoDashboardScreen();
      case 'Loan Origination':
        return const LoanOriginationScreen();
      case 'Collections':
        return const DailyCollectionsScreen();
      case 'Withdrawal Operations':
        return const WithdrawalOperationsScreen();
      case 'Portfolio':
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
      default:
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            'Page: $page (Awaiting Page Parity Specification & Implementation)',
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        );
    }
  }

  void _showSyncDialog(BuildContext context, WidgetRef ref) {
    showDialog(
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

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(pendingOutboxCountProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final syncMgr = ref.read(offlineSyncManagerProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cloud_sync, color: Color(0xFFD97706), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OFFLINE OUTBOX SYNC',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                Text(
                  'Post queued collections to the central ledger',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOnline ? Icons.wifi : Icons.wifi_off,
                      size: 18,
                      color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOnline ? 'Network Connection: Verified Online' : 'Network Connection: Offline (Tap to Check)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOnline ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.refresh,
                      size: 16,
                      color: isOnline ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pending batches on device: $pendingCount',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Queued transactions will post atomically to Account 1000 and the double-entry financial ledger.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (_statusMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                  ),
                ),
                child: Text(
                  _statusMsg!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
            if (_isSyncing) ...[
              const SizedBox(height: 16),
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF064E3B)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSyncing ? null : () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
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
                  if (mounted) {
                    setState(() {
                      _isSyncing = false;
                      _isSuccess = res.success;
                      _statusMsg = res.message;
                    });
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF064E3B),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFCBD5E1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          icon: const Icon(Icons.cloud_upload_outlined, size: 16),
          label: const Text('Sync Now', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

