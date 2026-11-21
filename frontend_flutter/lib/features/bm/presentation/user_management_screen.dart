import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../data/datasources/user_management_api_service.dart';
import '../data/models/user_management_models.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import 'package:frontend_flutter/core/theme/icare_motion.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  int _selectedTabIndex = 0;
  String? _flashSuccess;
  String? _flashError;

  // Tab 1: User Directory & Status
  late Future<UserListResponseModel> _usersFuture;
  String? _selectedToggleUsername;
  bool _confirmPermanentDelete = false;
  bool _isActionLoading = false;
  final _userSearchController = TextEditingController();
  String _userRoleFilter = 'ALL'; // ALL, ACTIVE, INACTIVE, CO, BM, AM, ADMIN
  String _selectedBranchFilter = 'ALL';
  bool _useCardView = true;

  // Tab 2: Create User
  final _createFormKey = GlobalKey<FormState>();
  final _createUsernameController = TextEditingController();
  final _createFullNameController = TextEditingController();
  final _createPasswordController = TextEditingController();
  String _createRole = 'Credit Officer';
  String _createBranch = 'Ogijo';
  bool _obscureCreatePassword = true;

  // Tab 3: Password Reset
  String? _resetUsername;
  final _resetPasswordController = TextEditingController();
  bool _obscureResetPassword = true;

  // Tab 4: Officer Turnover
  String? _turnoverUsername;
  final _turnoverNewNameController = TextEditingController();

  // Tab 5: Product Assignment
  late Future<ProductAssignmentMetaResponseModel> _productMetaFuture;
  String? _selectedAssignCO;
  List<String> _currentAllowedProducts = [];

  // Tab 6: AM Branch Assignments
  late Future<AMAssignmentsResponseModel> _amAssignmentsFuture;
  String? _selectedAMId;
  List<String> _selectedAMBranchIds = [];

  // Tab 7: Branch Closures
  late Future<BranchClosuresResponseModel> _closuresFuture;
  final _closureReasonController = TextEditingController();
  DateTime? _closureStartDate;
  DateTime? _closureEndDate;
  String? _selectedClosureBranchId;

  // Tab 8: Audit Logs
  late Future<UserAuditLogsResponseModel> _auditLogsFuture;
  final _auditSearchController = TextEditingController();

  // Tab 9: Login History
  late Future<LoginHistoryResponseModel> _loginHistoryFuture;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  void _refreshAll() {
    final api = ref.read(userManagementApiServiceProvider);
    setState(() {
      _usersFuture = api.getUsers();
      _productMetaFuture = api.getProductAssignmentMeta();
      _amAssignmentsFuture = api.getAmAssignments();
      _closuresFuture = api.getBranchClosures();
      _auditLogsFuture = api.getUserAuditLogs();
      _loginHistoryFuture = api.getLoginHistory();
    });
  }

  @override
  void dispose() {
    _createUsernameController.dispose();
    _createFullNameController.dispose();
    _createPasswordController.dispose();
    _resetPasswordController.dispose();
    _turnoverNewNameController.dispose();
    _closureReasonController.dispose();
    _auditSearchController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;

    if (user == null) {
      return Center(child: Text('Session expired. Please re-login.', style: TextStyle(color: tokens.textMuted)));
    }

    final role = user.role.trim();
    final isCo = role == 'Credit Officer' || role == 'CO' || role == 'Officer';
    final isAdmin = role == 'Admin' || role == 'Super Admin' || role == 'ADMIN';
    final isBm = role == 'Branch Manager' || role == 'BM';
    final isAm = role == 'Area Manager' || role == 'AM';

    // Access check: CO has NO access
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
                'You do not have permission to access User Management.',
                style: TextStyle(color: tokens.dangerText, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    // Role-adaptive tab list (Admin, AM, and BM)
    List<String> tabs;
    if (isAdmin) {
      tabs = [
        'Users Directory',
        'Create User',
        'Password Reset',
        'Officer Turnover',
        'Product Assignment',
        'AM Assignments',
        'Branch Closures',
        'Audit Logs',
        'Login History',
      ];
    } else if (isAm) {
      tabs = [
        'Branch Staff',
        'Create User',
        'Password Reset',
        'Product Assignment',
        'Branch Closures',
        'Branch Activity Logs',
      ];
    } else if (isBm) {
      tabs = [
        'Branch Staff',
        'Create User',
        'Password Reset',
        'Product Assignment',
        'Branch Closures',
        'Branch Activity Logs',
      ];
    } else {
      tabs = ['Users Directory'];
    }

    if (_selectedTabIndex >= tabs.length) {
      _selectedTabIndex = 0;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 750;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          isAm ? 'Supervised Staff Directory' : (isBm ? 'Branch Personnel & Staff Management' : 'User Management'),
          style: TextStyle(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isAm
              ? 'Supervisory personnel directory across all assigned branches in your region.'
              : (isBm
                  ? 'Manage branch personnel, configure product assignments, and handle password resets for ${user.branch} Branch.'
                  : 'Manage application users, reset passwords, and handle officer turnover.'),
          style: TextStyle(fontSize: 13, color: tokens.textMuted),
        ),
        const SizedBox(height: 16),

        // Flash Messages
        if (_flashSuccess != null) ...[
          _buildFlashBanner(_flashSuccess!, isError: false),
          const SizedBox(height: 12),
        ],
        if (_flashError != null) ...[
          _buildFlashBanner(_flashError!, isError: true),
          const SizedBox(height: 12),
        ],

        // Pill Tabs Navigation
        _buildPillTabs(tabs, _getActiveThemeColor(isAdmin, isBm, isAm, tokens)),
        const SizedBox(height: 20),

        // Tab Content Area
        _buildActiveTabContent(tabs[_selectedTabIndex], isAdmin, isBm, isAm, user.branch, isMobile: isMobile),
      ],
    );
  }

  Widget _buildFlashBanner(String message, {required bool isError}) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? tokens.dangerBg : tokens.successBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isError ? tokens.dangerBorder : tokens.successBorder),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: isError ? tokens.dangerDot : tokens.successDot, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? tokens.dangerText : tokens.successText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: isError ? tokens.dangerText : tokens.successText,
            onPressed: () => setState(() {
              _flashSuccess = null;
              _flashError = null;
            }),
          ),
        ],
      ),
    );
  }

  IconData _getTabIcon(String tab) {
    switch (tab) {
      case 'Users Directory':
      case 'Branch Staff':
      case 'Branch Staff (Read Only)':
        return Icons.groups_outlined;
      case 'Create User':
        return Icons.person_add_alt_outlined;
      case 'Password Reset':
        return Icons.lock_reset_outlined;
      case 'Officer Turnover':
        return Icons.swap_horiz_outlined;
      case 'Product Assignment':
        return Icons.assignment_ind_outlined;
      case 'AM Assignments':
        return Icons.account_tree_outlined;
      case 'Branch Closures':
        return Icons.domain_disabled_outlined;
      case 'Audit Logs':
      case 'Branch Activity Logs':
        return Icons.receipt_long_outlined;
      case 'Login History':
        return Icons.history_outlined;
      default:
        return Icons.grid_view_outlined;
    }
  }

  Color _getRoleBadgeColor(String role, {bool isDark = false}) {
    final lower = role.toLowerCase();
    if (lower.contains('admin') || lower.contains('director')) {
      return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
    } else if (lower.contains('procurement') || lower.contains('asset')) {
      return isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
    } else if (lower.contains('branch manager') || lower.contains('bm')) {
      return isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
    } else if (lower.contains('area manager') || lower.contains('am')) {
      return isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
    } else {
      return isDark ? const Color(0xFF34D399) : const Color(0xFF047857);
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'U';
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Color _getActiveThemeColor(bool isAdmin, bool isBm, bool isAm, IcareSurfaceTokens tokens) {
    if (isAdmin) return tokens.isDark ? const Color(0xFF6D28D9) : const Color(0xFF7C3AED);
    if (isBm) return tokens.isDark ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB);
    if (isAm) return tokens.brandPrimaryDark;
    return tokens.brandPrimaryDark;
  }

  Widget _buildPillTabs(List<String> tabs, Color activeThemeColor) {
    final tokens = IcareSurfaceTokens.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final title = entry.value;
          final isSelected = _selectedTabIndex == idx;
          final icon = _getTabIcon(title);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedTabIndex = idx),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? activeThemeColor : tokens.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? activeThemeColor : tokens.borderStrong),
                  boxShadow: isSelected
                      ? [BoxShadow(color: activeThemeColor.withValues(alpha: 0.22), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: isSelected ? Colors.white : tokens.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : tokens.textSecondary,
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

  Widget _buildActiveTabContent(String tabName, bool isAdmin, bool isBm, bool isAm, String branch, {required bool isMobile}) {
    switch (tabName) {
      case 'Users Directory':
      case 'Branch Staff':
      case 'Branch Staff (Read Only)':
        return _buildTabUsersDirectory(isAdmin: isAdmin, isBm: isBm, isAm: isAm, isMobile: isMobile);
      case 'Create User':
        return _buildTabCreateUser(isAdmin: isAdmin, isBm: isBm, isAm: isAm, branchName: branch);
      case 'Password Reset':
        return _buildTabPasswordReset(isAdmin: isAdmin, isBm: isBm, isAm: isAm);
      case 'Officer Turnover':
        return _buildTabOfficerTurnover();
      case 'Product Assignment':
        return _buildTabProductAssignment();
      case 'AM Assignments':
        return _buildTabAMAssignments();
      case 'Branch Closures':
        return _buildTabBranchClosures(isAdmin: isAdmin, isBm: isBm, isAm: isAm, branchName: branch, isMobile: isMobile);
      case 'Audit Logs':
      case 'Branch Activity Logs':
        return _buildTabAuditLogs(isBm: isBm, branch: branch, isMobile: isMobile);
      case 'Login History':
        return _buildTabLoginHistory(isMobile: isMobile);
      default:
        return const SizedBox.shrink();
    }
  }

  // =========================================================================
  // TAB 1: USERS DIRECTORY & STATUS MANAGEMENT
  // =========================================================================
  Widget _buildTabUsersDirectory({required bool isAdmin, required bool isBm, required bool isAm, required bool isMobile}) {
    final tokens = IcareSurfaceTokens.of(context);
    return FutureBuilder<UserListResponseModel>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }
        if (snapshot.hasError) {
          return _buildErrorCard('Failed to load users: ${snapshot.error}');
        }

        final allUsers = snapshot.data?.users ?? [];
        if (allUsers.isEmpty) {
          return _buildInfoCard('No users found.');
        }

        final branchesSet = allUsers
            .map((u) => u.branchName)
            .where((b) => b != null && b.trim().isNotEmpty)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();

        final authUser = ref.watch(authControllerProvider);
        final currentUid = authUser is AuthStateAuthenticated ? authUser.user.id : null;

        // Apply Search & Filters
        final query = _userSearchController.text.trim().toLowerCase();
        final filteredUsers = allUsers.where((u) {
          // BMs and AMs cannot view their own account in the directory
          if ((isBm || isAm) && u.id == currentUid) return false;

          // BMs only see Credit Officers in their branch
          if (isBm && !u.role.toLowerCase().contains('officer')) return false;

          if (_selectedBranchFilter != 'ALL' &&
              (u.branchName ?? '').trim().toLowerCase() != _selectedBranchFilter.trim().toLowerCase()) {
            return false;
          }
          if (query.isNotEmpty) {
            final matchName = u.fullName.toLowerCase().contains(query);
            final matchUser = u.username.toLowerCase().contains(query);
            final matchRole = u.role.toLowerCase().contains(query);
            final matchBranch = (u.branchName ?? '').toLowerCase().contains(query);
            if (!matchName && !matchUser && !matchRole && !matchBranch) return false;
          }
          if (_userRoleFilter == 'ACTIVE' && !u.isActive) return false;
          if (_userRoleFilter == 'INACTIVE' && u.isActive) return false;
          if (_userRoleFilter == 'CO' && (!u.role.toLowerCase().contains('officer') || u.role.toLowerCase().contains('procurement'))) {
            return false;
          }
          if (_userRoleFilter == 'BM' && !u.role.toLowerCase().contains('branch manager')) {
            return false;
          }
          if (_userRoleFilter == 'PROC' &&
              !u.role.toLowerCase().contains('procurement') &&
              !u.role.toLowerCase().contains('asset')) {
            return false;
          }
          if (_userRoleFilter == 'ADMIN' && !u.role.toLowerCase().contains('admin') && !u.role.toLowerCase().contains('director')) return false;
          return true;
        }).toList();

        final users = allUsers;
        if (_selectedToggleUsername == null && allUsers.isNotEmpty) {
          _selectedToggleUsername = allUsers.first.username;
        }

        final selectedUser = allUsers.firstWhere(
          (u) => u.username == _selectedToggleUsername,
          orElse: () => allUsers.first,
        );

        final showAsCards = isMobile || _useCardView;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAm ? 'Supervised Staff Directory (${filteredUsers.length})' : 'Users Directory (${allUsers.length})',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${allUsers.where((u) => u.isActive).length} Active • ${allUsers.where((u) => !u.isActive).length} Inactive',
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (!isMobile) ...[
                      IconButton(
                        tooltip: showAsCards ? 'Switch to Table' : 'Switch to Cards',
                        icon: Icon(showAsCards ? Icons.table_chart_outlined : Icons.view_agenda_outlined, size: 18, color: tokens.textSecondary),
                        onPressed: () => setState(() => _useCardView = !_useCardView),
                      ),
                      const SizedBox(width: 4),
                    ],
                    OutlinedButton.icon(
                      onPressed: _refreshAll,
                      icon: const Icon(Icons.refresh, size: 15),
                      label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(color: tokens.borderStrong),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        backgroundColor: tokens.surface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar
            TextField(
              controller: _userSearchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by name, @username, role, or branch...',
                hintStyle: TextStyle(fontSize: 12.5, color: tokens.textLight),
                prefixIcon: Icon(Icons.search, size: 18, color: tokens.textMuted),
                suffixIcon: _userSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _userSearchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: tokens.surface,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderSubtle)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.brandPrimary, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // Branch Scope Filter for AM
            if (isAm && branchesSet.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderStrong),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.apartment, size: 16, color: tokens.brandPrimary),
                    const SizedBox(width: 8),
                    Text('Branch Scope:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textMuted)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _selectedBranchFilter,
                      underline: const SizedBox.shrink(),
                      isDense: true,
                      dropdownColor: tokens.surfaceElevated,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('All Supervised Branches')),
                        ...branchesSet.map((b) => DropdownMenuItem(value: b, child: Text('$b Branch'))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedBranchFilter = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ('ALL', 'All (${allUsers.length})'),
                  ('ACTIVE', 'Active (${allUsers.where((u) => u.isActive).length})'),
                  ('INACTIVE', 'Inactive (${allUsers.where((u) => !u.isActive).length})'),
                  ('CO', 'Credit Officers (${allUsers.where((u) => u.role.toLowerCase().contains('officer') && !u.role.toLowerCase().contains('procurement')).length})'),
                  ('BM', 'Branch Managers (${allUsers.where((u) => u.role.toLowerCase().contains('branch manager')).length})'),
                  ('PROC', 'Procurement (${allUsers.where((u) => u.role.toLowerCase().contains('procurement') || u.role.toLowerCase().contains('asset')).length})'),
                ].map((f) {
                  final isSelected = _userRoleFilter == f.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _userRoleFilter = f.$1),
                      selectedColor: tokens.brandPrimaryDark,
                      backgroundColor: tokens.surface,
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : tokens.textSecondary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isSelected ? tokens.brandPrimaryDark : tokens.borderStrong),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Display Users: Cards vs Table
            if (filteredUsers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                alignment: Alignment.center,
                child: Text('No users match the search filter.', style: TextStyle(color: tokens.textMuted, fontSize: 13)),
              )
            else if (showAsCards)
              ...filteredUsers.map((u) => _buildUserCard(u, isAdmin, isBm, isAm))
            else
              Container(
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                    headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary, fontSize: 13),
                    dataTextStyle: TextStyle(fontSize: 13, color: tokens.textPrimary),
                    columns: [
                      const DataColumn(label: Text('User')),
                      const DataColumn(label: Text('Full Name')),
                      const DataColumn(label: Text('Role')),
                      const DataColumn(label: Text('Branch')),
                      const DataColumn(label: Text('Status')),
                      const DataColumn(label: Text('Last Login')),
                      if (isAdmin || isBm || isAm) const DataColumn(label: Text('Actions')),
                    ],
                    rows: filteredUsers.map((u) {
                      final roleColor = _getRoleBadgeColor(u.role, isDark: tokens.isDark);
                      return DataRow(
                        cells: [
                          DataCell(Text('@${u.username}', style: TextStyle(fontWeight: FontWeight.w600, color: tokens.textPrimary))),
                          DataCell(Text(u.fullName)),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: roleColor.withValues(alpha: tokens.isDark ? 0.16 : 0.08), borderRadius: BorderRadius.circular(4)),
                              child: Text(u.role, style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          DataCell(Text(u.branchName ?? 'Head Office')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: u.isActive ? tokens.successBg : tokens.dangerBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                u.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: u.isActive ? tokens.successText : tokens.dangerText,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(u.lastLogin ?? 'Never')),
                          if (isAdmin || isBm || isAm)
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Reset Password',
                                    icon: Icon(Icons.lock_reset, size: 18, color: tokens.infoDot),
                                    onPressed: () {
                                      setState(() {
                                        _resetUsername = u.username;
                                        _selectedTabIndex = 2;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    tooltip: u.isActive ? 'Deactivate' : 'Activate',
                                    icon: Icon(
                                      u.isActive ? Icons.block : Icons.check_circle_outline,
                                      size: 18,
                                      color: u.isActive ? tokens.warningDot : tokens.successDot,
                                    ),
                                    onPressed: _isActionLoading ? null : () => _handleToggleStatus(u.id, !u.isActive),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),

            // Status Management (Admin, AM & BM)
            if (isAdmin || isAm || isBm) ...[
              const SizedBox(height: 24),
              Divider(color: tokens.borderSubtle),
              const SizedBox(height: 16),
              Text('Manage User Status & Deletion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select User', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedToggleUsername,
                      isExpanded: true,
                      dropdownColor: tokens.surfaceElevated,
                      decoration: _inputDecoration(),
                      items: users.map((u) {
                        return DropdownMenuItem(value: u.username, child: Text('${u.username} — ${u.fullName} (${u.role})', overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedToggleUsername = val),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Text('Current Status: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                        Text(
                          selectedUser.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selectedUser.isActive ? tokens.successText : tokens.dangerText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (selectedUser.isActive || _isActionLoading)
                                ? null
                                : () => _handleToggleStatus(selectedUser.id, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF15803D),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: tokens.borderStrong,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Activate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (!selectedUser.isActive || _isActionLoading)
                                ? null
                                : () => _handleToggleStatus(selectedUser.id, false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB45309),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: tokens.borderStrong,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Deactivate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),

                    // Danger Zone (Admin, AM & BM)
                    if (isAdmin || isAm || isBm) ...[
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: tokens.dangerBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: tokens.dangerBorder),
                        ),
                        child: ExpansionTile(
                          leading: Icon(Icons.warning_amber_rounded, color: tokens.dangerDot),
                          title: Text('Danger Zone (Permanent Deletion)', style: TextStyle(color: tokens.dangerText, fontWeight: FontWeight.w700, fontSize: 13.5)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Deleting a user permanently removes them from the database. If this user has logged transactions, clients, or loans, their reference will be preserved as empty/null in historical audit logs.',
                                    style: TextStyle(fontSize: 12.5, color: tokens.textSecondary, height: 1.4),
                                  ),
                                  const SizedBox(height: 12),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    title: Text(
                                      "Confirm I want to permanently delete the user '${selectedUser.username}'",
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                                    ),
                                    value: _confirmPermanentDelete,
                                    onChanged: (val) => setState(() => _confirmPermanentDelete = val == true),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: (!_confirmPermanentDelete || _isActionLoading)
                                          ? null
                                          : () => _handleDeleteUser(selectedUser.id, selectedUser.username),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFDC2626),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: tokens.borderStrong,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      child: const Text('Permanently Delete User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ],
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
          ],
        );
      },
    );
  }

  Widget _buildUserCard(UserListItemModel u, bool isAdmin, bool isBm, bool isAm) {
    final tokens = IcareSurfaceTokens.of(context);
    final roleColor = _getRoleBadgeColor(u.role, isDark: tokens.isDark);
    final initials = _getInitials(u.fullName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.16 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: roleColor.withValues(alpha: tokens.isDark ? 0.18 : 0.12),
                child: Text(
                  initials,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: roleColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            u.fullName,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tokens.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: u.isActive ? tokens.successBg : tokens.dangerBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: u.isActive ? tokens.successDot : tokens.dangerDot,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                u.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: u.isActive ? tokens.successText : tokens.dangerText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '@${u.username}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tokens.textMuted),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: tokens.isDark ? 0.16 : 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            u.role,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: roleColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: tokens.borderSubtle),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.business_outlined, size: 14, color: tokens.textMuted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        u.branchName ?? 'Head Office',
                        style: TextStyle(fontSize: 12, color: tokens.textSecondary, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: tokens.textMuted),
                  const SizedBox(width: 5),
                  Text(
                    'Last: ${u.lastLogin ?? 'Never'}',
                    style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                  ),
                ],
              ),
            ],
          ),
          if (isAdmin || isBm || isAm) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isActionLoading
                        ? null
                        : () {
                            setState(() {
                              _resetUsername = u.username;
                              _selectedTabIndex = 2;
                            });
                          },
                    icon: const Icon(Icons.lock_reset, size: 14),
                    label: const Text('Reset Pass', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: tokens.borderStrong),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isActionLoading
                        ? null
                        : () => _handleToggleStatus(u.id, !u.isActive),
                    icon: Icon(
                      u.isActive ? Icons.block : Icons.check_circle_outline,
                      size: 14,
                      color: Colors.white,
                    ),
                    label: Text(
                      u.isActive ? 'Deactivate' : 'Activate',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: u.isActive ? const Color(0xFFB45309) : const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: CREATE USER (Admin Only)
  // =========================================================================
  Widget _buildTabCreateUser({
    required bool isAdmin,
    required bool isBm,
    required bool isAm,
    required String branchName,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    List<String> roleOptions;
    List<String> branchOptions;

    if (isBm) {
      roleOptions = const ['Credit Officer'];
      branchOptions = [branchName];
      if (_createRole != 'Credit Officer') _createRole = 'Credit Officer';
      if (_createBranch != branchName) _createBranch = branchName;
    } else if (isAm) {
      roleOptions = const ['Credit Officer', 'Branch Manager'];
      branchOptions = const ['Ogijo', 'Ikorodu', 'Kola', 'Ibadan'];
      if (!roleOptions.contains(_createRole)) _createRole = 'Credit Officer';
      if (!branchOptions.contains(_createBranch)) _createBranch = branchOptions.first;
    } else {
      roleOptions = const [
        'Credit Officer',
        'Branch Manager',
        'Area Manager',
        'Procurement Officer',
        'Admin',
        'Super Admin',
        'Account Manager',
      ];
      branchOptions = const ['Ogijo', 'Ikorodu', 'Kola', 'Ibadan', 'Head Office'];
    }

    final infoMsg = isBm
        ? 'Register a new Credit Officer for $branchName branch.'
        : (isAm
            ? 'Create a Branch Manager or Credit Officer for your supervised branches.'
            : 'Head Office administrators can create user accounts across all roles.');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Form(
        key: _createFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add New User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
            const SizedBox(height: 4),
            _buildInfoCard(infoMsg),
            const SizedBox(height: 20),

            // Username
            Text('Username (e.g. CO5, BM_Ikeja)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _createUsernameController,
              decoration: _inputDecoration(hint: 'e.g. CO5'),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Username is required' : null,
            ),
            const SizedBox(height: 16),

            // Full Name
            Text('Full Name (e.g. Mr. Ayomide)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _createFullNameController,
              decoration: _inputDecoration(hint: 'e.g. Mrs. Funmilayo Adeleke'),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Full Name is required' : null,
            ),
            const SizedBox(height: 16),

            // Role
            Text('Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: roleOptions.contains(_createRole) ? _createRole : roleOptions.first,
              dropdownColor: tokens.surfaceElevated,
              decoration: _inputDecoration(),
              items: roleOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: isBm ? null : (val) => setState(() => _createRole = val ?? roleOptions.first),
            ),
            const SizedBox(height: 16),

            // Branch Name
            Text('Branch Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: branchOptions.contains(_createBranch) ? _createBranch : branchOptions.first,
              dropdownColor: tokens.surfaceElevated,
              decoration: _inputDecoration(),
              items: branchOptions.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: isBm ? null : (val) => setState(() => _createBranch = val ?? branchOptions.first),
            ),
            const SizedBox(height: 16),

            // Password
            Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _createPasswordController,
              obscureText: _obscureCreatePassword,
              decoration: _inputDecoration().copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscureCreatePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                  onPressed: () => setState(() => _obscureCreatePassword = !_obscureCreatePassword),
                ),
              ),
              validator: (val) => (val == null || val.length < 4) ? 'Password must be at least 4 characters' : null,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isActionLoading ? null : _handleCreateUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.brandPrimaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Create User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 3: PASSWORD RESET
  // =========================================================================
  Widget _buildTabPasswordReset({required bool isAdmin, required bool isBm, required bool isAm}) {
    final tokens = IcareSurfaceTokens.of(context);
    return FutureBuilder<UserListResponseModel>(
      future: _usersFuture,
      builder: (context, snapshot) {
        final all = snapshot.data?.users ?? [];
        final authUser = ref.watch(authControllerProvider);
        final currentUid = authUser is AuthStateAuthenticated ? authUser.user.id : null;

        final users = all.where((u) {
          if (u.id == currentUid) return false; // Cannot reset own password here
          if (isBm) {
            return u.role.toLowerCase().contains('officer');
          }
          if (isAm) {
            return u.role.toLowerCase().contains('officer') || u.role.toLowerCase().contains('branch manager');
          }
          return true;
        }).toList();

        if ((_resetUsername == null || !users.any((u) => u.username == _resetUsername)) && users.isNotEmpty) {
          _resetUsername = users.first.username;
        }

        final infoMsg = isBm
            ? 'You can only reset passwords for Credit Officers in your branch.'
            : (isAm
                ? 'You can reset passwords for Branch Managers and Credit Officers in your supervised branches.'
                : 'Admins can reset passwords for any active user account.');

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
              const SizedBox(height: 4),
              _buildInfoCard(infoMsg),
              const SizedBox(height: 20),

              Text('Select User', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: users.any((u) => u.username == _resetUsername) ? _resetUsername : (users.isNotEmpty ? users.first.username : null),
                dropdownColor: tokens.surfaceElevated,
                decoration: _inputDecoration(),
                items: users.map((u) {
                  return DropdownMenuItem(value: u.username, child: Text('${u.username} — ${u.fullName} (${u.role})'));
                }).toList(),
                onChanged: (val) => setState(() => _resetUsername = val),
              ),
              const SizedBox(height: 16),

              Text('New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _resetPasswordController,
                obscureText: _obscureResetPassword,
                decoration: _inputDecoration().copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscureResetPassword ? Icons.visibility_off : Icons.visibility, size: 18),
                    onPressed: () => setState(() => _obscureResetPassword = !_obscureResetPassword),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isActionLoading ? null : _handleResetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Reset Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // TAB 4: OFFICER TURNOVER (Admin Only)
  // =========================================================================
  Widget _buildTabOfficerTurnover() {
    final tokens = IcareSurfaceTokens.of(context);
    return FutureBuilder<UserListResponseModel>(
      future: _usersFuture,
      builder: (context, snapshot) {
        final users = snapshot.data?.users ?? [];
        final coUsers = users.where((u) => u.role == 'Credit Officer' || u.role == 'CO' || u.username.startsWith('CO')).toList();

        if (_turnoverUsername == null && coUsers.isNotEmpty) {
          _turnoverUsername = coUsers.first.username;
        }

        final selectedCO = coUsers.firstWhere(
          (u) => u.username == _turnoverUsername,
          orElse: () => coUsers.isNotEmpty ? coUsers.first : users.first,
        );

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Update Officer Name (Turnover)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
              const SizedBox(height: 4),
              _buildInfoCard('When an officer leaves, update the Full Name tied to their generic username (e.g. CO2) so that historical data remains intact but the new officer\'s name is used going forward.'),
              const SizedBox(height: 20),

              Text('Select Officer ID', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _turnoverUsername,
                dropdownColor: tokens.surfaceElevated,
                decoration: _inputDecoration(),
                items: coUsers.map((u) {
                  return DropdownMenuItem(value: u.username, child: Text('${u.username} — ${u.fullName} (${u.branchName ?? "HQ"})'));
                }).toList(),
                onChanged: (val) => setState(() => _turnoverUsername = val),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Text('Current Name: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                  Text(selectedCO.fullName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.brandPrimary)),
                ],
              ),
              const SizedBox(height: 16),

              Text('New Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _turnoverNewNameController,
                decoration: _inputDecoration(hint: 'e.g. Mr. Emmanuel Ojo'),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isActionLoading ? null : _handleOfficerTurnover,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Update Officer Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // TAB 5: PRODUCT ASSIGNMENT
  // =========================================================================
  Widget _buildTabProductAssignment() {
    final tokens = IcareSurfaceTokens.of(context);
    return FutureBuilder<ProductAssignmentMetaResponseModel>(
      future: _productMetaFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionUriWaiting) {
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }
        if (snapshot.hasError) {
          return _buildErrorCard('Failed to load product metadata: ${snapshot.error}');
        }

        final data = snapshot.data;
        final availableProducts = data?.availableProducts ?? [];
        final officers = data?.creditOfficers ?? [];

        if (officers.isEmpty) {
          return _buildInfoCard('No Credit Officers found for product assignment.');
        }

        if (_selectedAssignCO == null && officers.isNotEmpty) {
          _selectedAssignCO = officers.first.username;
          _currentAllowedProducts = List.from(officers.first.allowedProducts);
        }

        final selectedOfficer = officers.firstWhere(
          (o) => o.username == _selectedAssignCO,
          orElse: () => officers.first,
        );

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign Products to Credit Officers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
              const SizedBox(height: 4),
              _buildInfoCard('Assign specific loan products to a Credit Officer. If left completely blank, the officer will have access to ALL products.'),
              const SizedBox(height: 20),

              Text('Select Credit Officer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedAssignCO,
                dropdownColor: tokens.surfaceElevated,
                decoration: _inputDecoration(),
                items: officers.map((o) {
                  return DropdownMenuItem(value: o.username, child: Text('${o.username} — ${o.fullName}'));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final off = officers.firstWhere((o) => o.username == val);
                    setState(() {
                      _selectedAssignCO = val;
                      _currentAllowedProducts = List.from(off.allowedProducts);
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Text('Name: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                  Text(selectedOfficer.fullName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.brandPrimary)),
                ],
              ),
              const SizedBox(height: 16),

              Text('Allowed Products (Multi-select)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableProducts.map((p) {
                  final isChecked = _currentAllowedProducts.contains(p);
                  return FilterChip(
                    label: Text(p),
                    selected: isChecked,
                    backgroundColor: tokens.surfaceHover,
                    selectedColor: tokens.successBg,
                    checkmarkColor: tokens.successText,
                    side: BorderSide(color: isChecked ? tokens.successBorder : tokens.borderSubtle),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isChecked ? FontWeight.w700 : FontWeight.w400,
                      color: isChecked ? tokens.successText : tokens.textSecondary,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _currentAllowedProducts.add(p);
                        } else {
                          _currentAllowedProducts.remove(p);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isActionLoading ? null : _handleAssignProducts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save Assignments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // TAB 6: AM BRANCH ASSIGNMENTS (Admin Only)
  // =========================================================================
  Widget _buildTabAMAssignments() {
    final tokens = IcareSurfaceTokens.of(context);
    return FutureBuilder<AMAssignmentsResponseModel>(
      future: _amAssignmentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionUriWaiting) {
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }
        if (snapshot.hasError) {
          return _buildErrorCard('Failed to load AM assignments: ${snapshot.error}');
        }

        final data = snapshot.data;
        final ams = data?.areaManagers ?? [];
        final branches = data?.allBranches ?? [];

        if (ams.isEmpty) {
          return _buildInfoCard('No Area Managers found. Create one first using the "Create User" tab.');
        }

        if (_selectedAMId == null && ams.isNotEmpty) {
          _selectedAMId = ams.first.userId;
          _selectedAMBranchIds = List.from(ams.first.assignedBranchIds);
        }

        final selectedAM = ams.firstWhere(
          (a) => a.userId == _selectedAMId,
          orElse: () => ams.first,
        );

        final selectedCount = _selectedAMBranchIds.length;
        final isValidCount = selectedCount >= 5 && selectedCount <= 7;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Area Manager Branch Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
              const SizedBox(height: 4),
              _buildInfoCard('Each Area Manager supervises 5-7 branches. Assign branches below.'),
              const SizedBox(height: 20),

              Text('Select Area Manager', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedAMId,
                dropdownColor: tokens.surfaceElevated,
                decoration: _inputDecoration(),
                items: ams.map((a) {
                  return DropdownMenuItem(value: a.userId, child: Text('${a.username} — ${a.fullName}'));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final target = ams.firstWhere((a) => a.userId == val);
                    setState(() {
                      _selectedAMId = val;
                      _selectedAMBranchIds = List.from(target.assignedBranchIds);
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Text('Currently Assigned: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                  Expanded(
                    child: Text(
                      selectedAM.assignedBranchNames.isNotEmpty ? selectedAM.assignedBranchNames.join(', ') : 'None',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.brandPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Text('Select Branches (5-7 required):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isValidCount ? tokens.successBg : tokens.warningBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Selected: $selectedCount',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isValidCount ? tokens.successText : tokens.warningText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: branches.map((b) {
                  final isChecked = _selectedAMBranchIds.contains(b.branchId);
                  return FilterChip(
                    label: Text(b.name),
                    selected: isChecked,
                    backgroundColor: tokens.surfaceHover,
                    selectedColor: tokens.successBg,
                    checkmarkColor: tokens.successText,
                    side: BorderSide(color: isChecked ? tokens.successBorder : tokens.borderSubtle),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isChecked ? FontWeight.w700 : FontWeight.w400,
                      color: isChecked ? tokens.successText : tokens.textSecondary,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedAMBranchIds.add(b.branchId);
                        } else {
                          _selectedAMBranchIds.remove(b.branchId);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isActionLoading || !isValidCount) ? null : _handleSaveAMAssignments,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: tokens.borderStrong,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save Assignments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // TAB 7: BRANCH CLOSURES & SETTINGS
  // =========================================================================
  Widget _buildTabBranchClosures({required bool isAdmin, required bool isBm, required bool isAm, required String branchName, required bool isMobile}) {
    final tokens = IcareSurfaceTokens.of(context);
    return FutureBuilder<BranchClosuresResponseModel>(
      future: _closuresFuture,
      builder: (context, snapshot) {
        final closures = snapshot.data?.closures ?? [];

        final startDatePicker = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _closureStartDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _closureStartDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  border: Border.all(color: tokens.borderStrong),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _closureStartDate != null ? DateFormat('yyyy-MM-dd').format(_closureStartDate!) : 'YYYY-MM-DD',
                      style: TextStyle(fontSize: 13, color: _closureStartDate != null ? tokens.textPrimary : tokens.textLight),
                    ),
                    Icon(Icons.calendar_today, size: 16, color: tokens.textMuted),
                  ],
                ),
              ),
            ),
          ],
        );

        final endDatePicker = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('End Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _closureEndDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _closureEndDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  border: Border.all(color: tokens.borderStrong),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _closureEndDate != null ? DateFormat('yyyy-MM-dd').format(_closureEndDate!) : 'YYYY-MM-DD',
                      style: TextStyle(fontSize: 13, color: _closureEndDate != null ? tokens.textPrimary : tokens.textLight),
                    ),
                    Icon(Icons.calendar_today, size: 16, color: tokens.textMuted),
                  ],
                ),
              ),
            ),
          ],
        );

        final formCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add New Closure', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
              const SizedBox(height: 16),
              if (isMobile) ...[
                startDatePicker,
                const SizedBox(height: 12),
                endDatePicker,
              ] else ...[
                Row(
                  children: [
                    Expanded(child: startDatePicker),
                    const SizedBox(width: 12),
                    Expanded(child: endDatePicker),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              // Reason
              Text('Reason (e.g. End of Year Break)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
              const SizedBox(height: 4),
              TextFormField(
                controller: _closureReasonController,
                decoration: _inputDecoration(hint: 'e.g. End of Year Operational Shutdown'),
              ),
              const SizedBox(height: 16),
              // Branch target (Admin and AM choose; BM locked to own branch)
              if (isAdmin || isAm) ...[
                Text(
                  isAm ? 'Target Branch (Supervised Area)' : 'Target Branch',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String?>(
                  value: _selectedClosureBranchId,
                  isExpanded: true,
                  dropdownColor: tokens.surfaceElevated,
                  decoration: _inputDecoration(),
                  items: [
                    if (isAdmin) const DropdownMenuItem(value: null, child: Text('All Branches (Global)')),
                    const DropdownMenuItem(value: '997d504e-7f5c-4772-887d-fdd5a4c1183b', child: Text('Ogijo')),
                    const DropdownMenuItem(value: '4ab6e1c4-6783-4bb6-904f-9da51cfab505', child: Text('Ikorodu')),
                    const DropdownMenuItem(value: 'dd09c735-3b1e-4eeb-89a8-d27a85e02156', child: Text('Kola')),
                    const DropdownMenuItem(value: '7ca8250a-9077-4bef-8cf3-78cf26c30705', child: Text('Ibadan')),
                    if (isAdmin) const DropdownMenuItem(value: '1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d', child: Text('Head Office')),
                  ],
                  onChanged: (val) => setState(() => _selectedClosureBranchId = val),
                ),
              ] else ...[
                Text('Target Branch: $branchName', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.brandPrimary)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isActionLoading ? null : _handleCreateClosure,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save Closure', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );

        final tableCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active Closures', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
              const SizedBox(height: 16),
              if (closures.isEmpty)
                _buildInfoCard('No custom closures recorded.')
              else ...[
                if (isMobile)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.swipe, size: 14, color: tokens.textMuted),
                        const SizedBox(width: 4),
                        Text('Scroll horizontally to view closures', style: TextStyle(fontSize: 11, color: tokens.textMuted, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                    headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary, fontSize: 12.5),
                    dataTextStyle: TextStyle(fontSize: 12.5, color: tokens.textPrimary),
                    columns: const [
                      DataColumn(label: Text('Start Date')),
                      DataColumn(label: Text('End Date')),
                      DataColumn(label: Text('Reason')),
                      DataColumn(label: Text('Branch')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: closures.map((c) {
                      return DataRow(
                        cells: [
                          DataCell(Text(c.startDate)),
                          DataCell(Text(c.endDate)),
                          DataCell(Text(c.reason)),
                          DataCell(Text(c.branchName ?? 'Global')),
                          DataCell(
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: tokens.dangerDot),
                              onPressed: () => _handleDeleteClosure(c.id),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Branch Settings & Closures', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
            const SizedBox(height: 4),
            Text(
              'Manage custom branch closures (e.g., operational shutdowns, end-of-year breaks). These dates will be strictly excluded when calculating loan repayment schedules.',
              style: TextStyle(fontSize: 13, color: tokens.textMuted),
            ),
            const SizedBox(height: 20),
            if (isMobile) ...[
              formCard,
              const SizedBox(height: 20),
              tableCard,
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: formCard),
                  const SizedBox(width: 20),
                  Expanded(child: tableCard),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  // =========================================================================
  // TAB 8: AUDIT LOGS / BRANCH ACTIVITY LOGS
  // =========================================================================
  Widget _buildTabAuditLogs({required bool isBm, required String branch, required bool isMobile}) {
    final tokens = IcareSurfaceTokens.of(context);
    return FutureBuilder<UserAuditLogsResponseModel>(
      future: _auditLogsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionUriWaiting) {
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }

        final logs = snapshot.data?.logs ?? [];
        final query = _auditSearchController.text.toLowerCase().trim();

        final filtered = query.isEmpty
            ? logs
            : logs.where((l) {
                return l.username.toLowerCase().contains(query) ||
                    l.action.toLowerCase().contains(query) ||
                    (l.branch ?? '').toLowerCase().contains(query) ||
                    (l.module ?? '').toLowerCase().contains(query);
              }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBm ? 'Branch Activity Logs ($branch)' : 'System Audit Logs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.textPrimary),
            ),
            const SizedBox(height: 4),
            _buildInfoCard(
              isBm
                  ? 'Immutable audit trail for operational activities within $branch branch.'
                  : 'Immutable audit trail. Logs cannot be modified or deleted.',
            ),
            const SizedBox(height: 16),

            // Search Bar
            SizedBox(
              width: isMobile ? double.infinity : 320,
              child: TextField(
                controller: _auditSearchController,
                decoration: _inputDecoration(hint: 'Filter by user, action, module...').copyWith(
                  prefixIcon: Icon(Icons.search, size: 18, color: tokens.textMuted),
                ),
                onChanged: (val) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),

            if (filtered.isEmpty)
              _buildInfoCard('No audit logs recorded yet.')
            else ...[
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.swipe, size: 14, color: tokens.textMuted),
                      const SizedBox(width: 4),
                      Text('Scroll horizontally to view audit trail', style: TextStyle(fontSize: 11, color: tokens.textMuted, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                    headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary, fontSize: 12.5),
                    dataTextStyle: TextStyle(fontSize: 12.5, color: tokens.textPrimary),
                    columns: const [
                      DataColumn(label: Text('Timestamp')),
                      DataColumn(label: Text('Username')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Branch')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('Module')),
                      DataColumn(label: Text('Display Name')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: filtered.map((l) {
                      return DataRow(
                        cells: [
                          DataCell(Text(l.timestamp)),
                          DataCell(Text(l.username, style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(l.role ?? '—')),
                          DataCell(Text(l.branch ?? '—')),
                          DataCell(Text(l.action)),
                          DataCell(Text(l.module ?? '—')),
                          DataCell(Text(l.displayName ?? '—')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (l.status ?? '').toUpperCase() == 'SUCCESS'
                                    ? tokens.successBg
                                    : tokens.surfaceHover,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                l.status ?? 'Logged',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: (l.status ?? '').toUpperCase() == 'SUCCESS'
                                      ? tokens.successText
                                      : tokens.textSecondary,
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
          ],
        );
      },
    );
  }

  // =========================================================================
  // TAB 9: LOGIN HISTORY (Admin Only)
  // =========================================================================
  Widget _buildTabLoginHistory({bool isMobile = false}) {
    final tokens = IcareSurfaceTokens.of(context);
    return FutureBuilder<LoginHistoryResponseModel>(
      future: _loginHistoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionUriWaiting) {
          return const IcareTableSkeleton(rowCount: 6, hasFilterBar: false);
        }

        final history = snapshot.data?.history ?? [];
        if (history.isEmpty) {
          return _buildInfoCard('No login history recorded yet.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Login History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
            const SizedBox(height: 4),
            _buildInfoCard('System-wide authentication access log including successful logins, failures, and session IDs.'),
            const SizedBox(height: 16),

            if (isMobile)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.swipe, size: 14, color: tokens.textMuted),
                    const SizedBox(width: 4),
                    Text('Scroll horizontally to view login history', style: TextStyle(fontSize: 11, color: tokens.textMuted, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),

            Container(
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                  headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary, fontSize: 12.5),
                  dataTextStyle: TextStyle(fontSize: 12.5, color: tokens.textPrimary),
                  columns: const [
                    DataColumn(label: Text('Login Time')),
                    DataColumn(label: Text('Username')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Session ID')),
                    DataColumn(label: Text('Logout Time')),
                    DataColumn(label: Text('Failed Attempts')),
                  ],
                  rows: history.map((h) {
                    final isSuccess = h.status.toUpperCase() == 'SUCCESS';
                    return DataRow(
                      cells: [
                        DataCell(Text(h.loginTime)),
                        DataCell(Text(h.username, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSuccess ? tokens.successBg : tokens.dangerBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              h.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSuccess ? tokens.successText : tokens.dangerText,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(h.sessionId ?? '—')),
                        DataCell(Text(h.logoutTime ?? 'Active Session')),
                        DataCell(Text(h.failedAttempts.toString())),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // ACTIONS / HANDLERS
  // =========================================================================
  Future<void> _handleToggleStatus(String userId, bool activate) async {
    setState(() => _isActionLoading = true);
    try {
      final api = ref.read(userManagementApiServiceProvider);
      final res = await api.toggleUserStatus(userId: userId, activate: activate);
      setState(() {
        _flashSuccess = res.message;
        _flashError = null;
      });
      _refreshAll();
    } catch (e) {
      setState(() {
        _flashError = 'Failed to update status: $e';
        _flashSuccess = null;
      });
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleDeleteUser(String userId, String username) async {
    setState(() => _isActionLoading = true);
    try {
      final api = ref.read(userManagementApiServiceProvider);
      final res = await api.deleteUserPermanently(userId: userId);
      setState(() {
        _flashSuccess = res.message;
        _flashError = null;
        _confirmPermanentDelete = false;
        _selectedToggleUsername = null;
      });
      _refreshAll();
    } catch (e) {
      setState(() {
        _flashError = 'Failed to delete user: $e';
        _flashSuccess = null;
      });
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleCreateUser() async {
    if (!_createFormKey.currentState!.validate()) return;
    setState(() => _isActionLoading = true);

    try {
      final api = ref.read(userManagementApiServiceProvider);
      final res = await api.createUser(
        username: _createUsernameController.text.trim(),
        fullName: _createFullNameController.text.trim(),
        password: _createPasswordController.text,
        role: _createRole,
        branchName: _createBranch,
      );

      setState(() {
        _flashSuccess = res.message;
        _flashError = null;
        _createUsernameController.clear();
        _createFullNameController.clear();
        _createPasswordController.clear();
      });
      _refreshAll();
    } catch (e) {
      setState(() {
        _flashError = 'Failed to create user: $e';
        _flashSuccess = null;
      });
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final uname = _resetUsername;
    final newPw = _resetPasswordController.text;
    if (uname == null || newPw.length < 4) {
      setState(() => _flashError = 'Please select a user and provide a password (minimum 4 characters).');
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      final api = ref.read(userManagementApiServiceProvider);
      final res = await api.resetPassword(username: uname, newPassword: newPw);
      setState(() {
        _flashSuccess = res.message;
        _flashError = null;
        _resetPasswordController.clear();
      });
    } catch (e) {
      setState(() {
        _flashError = 'Failed to reset password: $e';
        _flashSuccess = null;
      });
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleOfficerTurnover() async {
    final uname = _turnoverUsername;
    final newName = _turnoverNewNameController.text.trim();
    if (uname == null || newName.isEmpty) {
      setState(() => _flashError = 'Please select an officer and enter a new full name.');
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      final api = ref.read(userManagementApiServiceProvider);
      final res = await api.updateOfficerTurnover(username: uname, newName: newName);
      setState(() {
        _flashSuccess = res.message;
        _flashError = null;
        _turnoverNewNameController.clear();
      });
      _refreshAll();
    } catch (e) {
      setState(() {
        _flashError = 'Failed to update officer name: $e';
        _flashSuccess = null;
      });
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleAssignProducts() async {
    final uname = _selectedAssignCO;
    if (uname == null) return;

    setState(() => _isActionLoading = true);
    try {
      final api = ref.read(userManagementApiServiceProvider);
      final res = await api.assignProducts(username: uname, allowedProducts: _currentAllowedProducts);
      setState(() {
        _flashSuccess = res.message;
        _flashError = null;
      });
      _refreshAll();
    } catch (e) {
      setState(() {
        _flashError = 'Failed to assign products: $e';
        _flashSuccess = null;
      });
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleSaveAMAssignments() async {
    final amId = _selectedAMId;
    if (amId == null) return;

    setState(() => _isActionLoading = true);
    try {
      final api = ref.read(userManagementApiServiceProvider);
      final res = await api.saveAmAssignments(amId: amId, branchIds: _selectedAMBranchIds);
      setState(() {
        _flashSuccess = res.message;
        _flashError = null;
      });
      _refreshAll();
    } catch (e) {
      setState(() {
        _flashError = 'Failed to save AM branch assignments: $e';
        _flashSuccess = null;
      });
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleCreateClosure() async {
    final sDate = _closureStartDate;
    final eDate = _closureEndDate;
    final reason = _closureReasonController.text.trim();

    if (sDate == null || eDate == null || reason.isEmpty) {
      setState(() => _flashError = 'Please select start/end dates and enter a reason.');
      return;
    }

    final authState = ref.read(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final isAm = user != null && (user.role == 'Area Manager' || user.role == 'AM');
    if (isAm && _selectedClosureBranchId == null) {
      setState(() => _flashError = 'Please select a target branch in your supervised area.');
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      final api = ref.read(userManagementApiServiceProvider);
      final res = await api.createBranchClosure(
        startDate: DateFormat('yyyy-MM-dd').format(sDate),
        endDate: DateFormat('yyyy-MM-dd').format(eDate),
        reason: reason,
        branchId: _selectedClosureBranchId,
      );

      setState(() {
        _flashSuccess = '${res.message} (${res.rescheduledLoans} loan installments rescheduled).';
        _flashError = null;
        _closureReasonController.clear();
        _closureStartDate = null;
        _closureEndDate = null;
      });
      _refreshAll();
    } catch (e) {
      setState(() {
        _flashError = 'Failed to create closure: $e';
        _flashSuccess = null;
      });
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleDeleteClosure(String closureId) async {
    final confirm = await showIcareDialog<bool>(
      context: context,
      builder: (ctx) {
        final dTokens = IcareSurfaceTokens.of(ctx);
        return AlertDialog(
          backgroundColor: dTokens.surfaceElevated,
          title: Text('Delete Closure', style: TextStyle(fontWeight: FontWeight.w700, color: dTokens.textPrimary)),
          content: Text('Are you sure you want to delete this custom branch closure?', style: TextStyle(color: dTokens.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      final api = ref.read(userManagementApiServiceProvider);
      final res = await api.deleteBranchClosure(closureId: closureId);
      setState(() {
        _flashSuccess = res.message;
        _flashError = null;
      });
      _refreshAll();
    } catch (e) {
      setState(() {
        _flashError = 'Failed to delete closure: $e';
        _flashSuccess = null;
      });
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  // =========================================================================
  // UI HELPERS
  // =========================================================================
  Widget _buildInfoCard(String text) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: tokens.infoDot),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: tokens.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String text) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.dangerBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.dangerBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: tokens.dangerDot),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: tokens.dangerText))),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    final tokens = IcareSurfaceTokens.of(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: tokens.textLight),
      filled: true,
      fillColor: tokens.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: tokens.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: tokens.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: tokens.brandPrimary, width: 1.5),
      ),
    );
  }
}

extension _ConnectionStateExtension on AsyncSnapshot {
  bool get connectionUriWaiting => connectionState == ConnectionState.waiting;
}
