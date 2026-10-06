import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../data/datasources/user_management_api_service.dart';
import '../data/models/user_management_models.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';

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
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;

    if (user == null) {
      return const Center(child: Text('Session expired. Please re-login.'));
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
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.gpp_bad, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'You do not have permission to access User Management.',
                style: TextStyle(color: Color(0xFF991B1B), fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    // Role-adaptive tab list
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
    } else if (isBm) {
      tabs = [
        'Branch Staff',
        'Password Reset',
        'Product Assignment',
        'Branch Closures',
        'Branch Activity Logs',
      ];
    } else if (isAm) {
      tabs = ['Branch Staff (Read Only)'];
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
          'User Management',
          style: TextStyle(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage application users, reset passwords, and handle officer turnover.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
        _buildPillTabs(tabs),
        const SizedBox(height: 20),

        // Tab Content Area
        _buildActiveTabContent(tabs[_selectedTabIndex], isAdmin, isBm, isAm, user.branch, isMobile: isMobile),
      ],
    );
  }

  Widget _buildFlashBanner(String message, {required bool isError}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isError ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? const Color(0xFF991B1B) : const Color(0xFF166534),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: isError ? const Color(0xFF991B1B) : const Color(0xFF166534),
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

  Color _getRoleBadgeColor(String role) {
    final lower = role.toLowerCase();
    if (lower.contains('admin') || lower.contains('director')) {
      return const Color(0xFF7C3AED);
    } else if (lower.contains('branch manager') || lower.contains('bm')) {
      return const Color(0xFF1D4ED8);
    } else if (lower.contains('area manager') || lower.contains('am')) {
      return const Color(0xFFB45309);
    } else {
      return const Color(0xFF047857);
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'U';
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Widget _buildPillTabs(List<String> tabs) {
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
                  color: isSelected ? const Color(0xFF064E3B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? const Color(0xFF064E3B) : const Color(0xFFCBD5E1)),
                  boxShadow: isSelected
                      ? [BoxShadow(color: const Color(0xFF064E3B).withValues(alpha: 0.18), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

  Widget _buildActiveTabContent(String tabName, bool isAdmin, bool isBm, bool isAm, String branch, {required bool isMobile}) {
    switch (tabName) {
      case 'Users Directory':
      case 'Branch Staff':
      case 'Branch Staff (Read Only)':
        return _buildTabUsersDirectory(isAdmin: isAdmin, isBm: isBm, isAm: isAm, isMobile: isMobile);
      case 'Create User':
        return _buildTabCreateUser();
      case 'Password Reset':
        return _buildTabPasswordReset(isBm: isBm);
      case 'Officer Turnover':
        return _buildTabOfficerTurnover();
      case 'Product Assignment':
        return _buildTabProductAssignment();
      case 'AM Assignments':
        return _buildTabAMAssignments();
      case 'Branch Closures':
        return _buildTabBranchClosures(isAdmin: isAdmin, branchName: branch, isMobile: isMobile);
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

        // Apply Search & Filters
        final query = _userSearchController.text.trim().toLowerCase();
        final filteredUsers = allUsers.where((u) {
          if (query.isNotEmpty) {
            final matchName = u.fullName.toLowerCase().contains(query);
            final matchUser = u.username.toLowerCase().contains(query);
            final matchRole = u.role.toLowerCase().contains(query);
            final matchBranch = (u.branchName ?? '').toLowerCase().contains(query);
            if (!matchName && !matchUser && !matchRole && !matchBranch) return false;
          }
          if (_userRoleFilter == 'ACTIVE' && !u.isActive) return false;
          if (_userRoleFilter == 'INACTIVE' && u.isActive) return false;
          if (_userRoleFilter == 'CO' && !u.role.toLowerCase().contains('officer')) return false;
          if (_userRoleFilter == 'BM' && !u.role.toLowerCase().contains('branch manager')) return false;
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
                      'Users Directory (${allUsers.length})',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${allUsers.where((u) => u.isActive).length} Active • ${allUsers.where((u) => !u.isActive).length} Inactive',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (!isMobile) ...[
                      IconButton(
                        tooltip: showAsCards ? 'Switch to Table' : 'Switch to Cards',
                        icon: Icon(showAsCards ? Icons.table_chart_outlined : Icons.view_agenda_outlined, size: 18),
                        onPressed: () => setState(() => _useCardView = !_useCardView),
                      ),
                      const SizedBox(width: 4),
                    ],
                    OutlinedButton.icon(
                      onPressed: _refreshAll,
                      icon: const Icon(Icons.refresh, size: 15),
                      label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        backgroundColor: Colors.white,
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
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
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
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ('ALL', 'All (${allUsers.length})'),
                  ('ACTIVE', 'Active (${allUsers.where((u) => u.isActive).length})'),
                  ('INACTIVE', 'Inactive (${allUsers.where((u) => !u.isActive).length})'),
                  ('CO', 'Credit Officers (${allUsers.where((u) => u.role.toLowerCase().contains('officer')).length})'),
                  ('BM', 'Branch Managers (${allUsers.where((u) => u.role.toLowerCase().contains('branch manager')).length})'),
                ].map((f) {
                  final isSelected = _userRoleFilter == f.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _userRoleFilter = f.$1),
                      selectedColor: const Color(0xFF0F172A),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                alignment: Alignment.center,
                child: const Text('No users match the search filter.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              )
            else if (showAsCards)
              ...filteredUsers.map((u) => _buildUserCard(u, isAdmin, isBm))
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 13),
                    dataTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    columns: const [
                      DataColumn(label: Text('User')),
                      DataColumn(label: Text('Full Name')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Branch')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Last Login')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filteredUsers.map((u) {
                      final roleColor = _getRoleBadgeColor(u.role);
                      return DataRow(
                        cells: [
                          DataCell(Text('@${u.username}', style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(u.fullName)),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                              child: Text(u.role, style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          DataCell(Text(u.branchName ?? 'Head Office')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: u.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                u.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: u.isActive ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(u.lastLogin ?? 'Never')),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Reset Password',
                                  icon: const Icon(Icons.lock_reset, size: 18, color: Color(0xFF2563EB)),
                                  onPressed: () {
                                    setState(() {
                                      _resetUsername = u.username;
                                      _selectedTabIndex = isAdmin ? 2 : 1;
                                    });
                                  },
                                ),
                                IconButton(
                                  tooltip: u.isActive ? 'Deactivate' : 'Activate',
                                  icon: Icon(
                                    u.isActive ? Icons.block : Icons.check_circle_outline,
                                    size: 18,
                                    color: u.isActive ? const Color(0xFFD97706) : const Color(0xFF16A34A),
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

            // Status Management (Admin & BM)
            if (isAdmin || isBm) ...[
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),
              const Text('Manage User Status & Deletion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select User', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedToggleUsername,
                      isExpanded: true,
                      decoration: _inputDecoration(),
                      items: users.map((u) {
                        return DropdownMenuItem(value: u.username, child: Text('${u.username} — ${u.fullName} (${u.role})', overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedToggleUsername = val),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Text('Current Status: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          selectedUser.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selectedUser.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
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
                              backgroundColor: const Color(0xFF16A34A),
                              disabledBackgroundColor: const Color(0xFFCBD5E1),
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
                              backgroundColor: const Color(0xFFD97706),
                              disabledBackgroundColor: const Color(0xFFCBD5E1),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Deactivate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),

                    // Admin Danger Zone
                    if (isAdmin) ...[
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: ExpansionTile(
                          leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                          title: const Text('Danger Zone (Permanent Deletion)', style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w700, fontSize: 13.5)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Deleting a user permanently removes them from the database. If this user has logged transactions, clients, or loans, their reference will be preserved as empty/null in historical audit logs.',
                                    style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
                                  ),
                                  const SizedBox(height: 12),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    title: Text(
                                      "Confirm I want to permanently delete the user '${selectedUser.username}'",
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
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
                                        disabledBackgroundColor: const Color(0xFFCBD5E1),
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

  Widget _buildUserCard(UserListItemModel u, bool isAdmin, bool isBm) {
    final roleColor = _getRoleBadgeColor(u.role);
    final initials = _getInitials(u.fullName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                backgroundColor: roleColor.withValues(alpha: 0.12),
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
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: u.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
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
                                  color: u.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                u.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: u.isActive ? const Color(0xFF166534) : const Color(0xFF991B1B),
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
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.08),
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
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.business_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        u.branchName ?? 'Head Office',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 5),
                  Text(
                    'Last: ${u.lastLogin ?? 'Never'}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          if (isAdmin || isBm) ...[
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
                              _selectedTabIndex = isAdmin ? 2 : 1;
                            });
                          },
                    icon: const Icon(Icons.lock_reset, size: 14),
                    label: const Text('Reset Pass', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
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
                      backgroundColor: u.isActive ? const Color(0xFFD97706) : const Color(0xFF16A34A),
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
  Widget _buildTabCreateUser() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Form(
        key: _createFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            _buildInfoCard('Only Head Office administrators can create new users.'),
            const SizedBox(height: 20),

            // Username
            const Text('Username (e.g. CO5, BM_Ikeja)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            TextFormField(
              controller: _createUsernameController,
              decoration: _inputDecoration(hint: 'e.g. CO5'),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Username is required' : null,
            ),
            const SizedBox(height: 16),

            // Full Name
            const Text('Full Name (e.g. Mr. Ayomide)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            TextFormField(
              controller: _createFullNameController,
              decoration: _inputDecoration(hint: 'e.g. Mrs. Funmilayo Adeleke'),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Full Name is required' : null,
            ),
            const SizedBox(height: 16),

            // Role
            const Text('Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _createRole,
              decoration: _inputDecoration(),
              items: const [
                DropdownMenuItem(value: 'Credit Officer', child: Text('Credit Officer')),
                DropdownMenuItem(value: 'Branch Manager', child: Text('Branch Manager')),
                DropdownMenuItem(value: 'Area Manager', child: Text('Area Manager')),
                DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                DropdownMenuItem(value: 'Super Admin', child: Text('Super Admin')),
                DropdownMenuItem(value: 'Account Manager', child: Text('Account Manager')),
              ],
              onChanged: (val) => setState(() => _createRole = val ?? 'Credit Officer'),
            ),
            const SizedBox(height: 16),

            // Branch Name
            const Text('Branch Name (e.g. Ogijo)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _createBranch,
              decoration: _inputDecoration(),
              items: const [
                DropdownMenuItem(value: 'Ogijo', child: Text('Ogijo')),
                DropdownMenuItem(value: 'Ikorodu', child: Text('Ikorodu')),
                DropdownMenuItem(value: 'Kola', child: Text('Kola')),
                DropdownMenuItem(value: 'Ibadan', child: Text('Ibadan')),
                DropdownMenuItem(value: 'Head Office', child: Text('Head Office')),
              ],
              onChanged: (val) => setState(() => _createBranch = val ?? 'Ogijo'),
            ),
            const SizedBox(height: 16),

            // Password
            const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
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
                  backgroundColor: const Color(0xFF064E3B),
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
  Widget _buildTabPasswordReset({required bool isBm}) {
    return FutureBuilder<UserListResponseModel>(
      future: _usersFuture,
      builder: (context, snapshot) {
        final users = snapshot.data?.users ?? [];
        if (_resetUsername == null && users.isNotEmpty) {
          _resetUsername = users.first.username;
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              if (isBm)
                _buildInfoCard('You can only reset passwords for staff in your branch.')
              else
                _buildInfoCard('Admins can reset passwords for any active user account.'),
              const SizedBox(height: 20),

              const Text('Select User', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _resetUsername,
                decoration: _inputDecoration(),
                items: users.map((u) {
                  return DropdownMenuItem(value: u.username, child: Text('${u.username} — ${u.fullName} (${u.branchName ?? "HQ"})'));
                }).toList(),
                onChanged: (val) => setState(() => _resetUsername = val),
              ),
              const SizedBox(height: 16),

              const Text('New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
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
                    backgroundColor: const Color(0xFF064E3B),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Update Officer Name (Turnover)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              _buildInfoCard('When an officer leaves, update the Full Name tied to their generic username (e.g. CO2) so that historical data remains intact but the new officer\'s name is used going forward.'),
              const SizedBox(height: 20),

              const Text('Select Officer ID', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _turnoverUsername,
                decoration: _inputDecoration(),
                items: coUsers.map((u) {
                  return DropdownMenuItem(value: u.username, child: Text('${u.username} — ${u.fullName} (${u.branchName ?? "HQ"})'));
                }).toList(),
                onChanged: (val) => setState(() => _turnoverUsername = val),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Text('Current Name: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(selectedCO.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF064E3B))),
                ],
              ),
              const SizedBox(height: 16),

              const Text('New Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
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
                    backgroundColor: const Color(0xFF064E3B),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assign Products to Credit Officers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              _buildInfoCard('Assign specific loan products to a Credit Officer. If left completely blank, the officer will have access to ALL products.'),
              const SizedBox(height: 20),

              const Text('Select Credit Officer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedAssignCO,
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
                  const Text('Name: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(selectedOfficer.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF064E3B))),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Allowed Products (Multi-select)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableProducts.map((p) {
                  final isChecked = _currentAllowedProducts.contains(p);
                  return FilterChip(
                    label: Text(p),
                    selected: isChecked,
                    selectedColor: const Color(0xFFDCFCE7),
                    checkmarkColor: const Color(0xFF166534),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isChecked ? FontWeight.w700 : FontWeight.w400,
                      color: isChecked ? const Color(0xFF166534) : const Color(0xFF334155),
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
                    backgroundColor: const Color(0xFF064E3B),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Area Manager Branch Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              _buildInfoCard('Each Area Manager supervises 5-7 branches. Assign branches below.'),
              const SizedBox(height: 20),

              const Text('Select Area Manager', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedAMId,
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
                  const Text('Currently Assigned: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Expanded(
                    child: Text(
                      selectedAM.assignedBranchNames.isNotEmpty ? selectedAM.assignedBranchNames.join(', ') : 'None',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF064E3B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Text('Select Branches (5-7 required):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isValidCount ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Selected: $selectedCount',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isValidCount ? const Color(0xFF166534) : const Color(0xFF92400E),
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
                    selectedColor: const Color(0xFFDCFCE7),
                    checkmarkColor: const Color(0xFF166534),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isChecked ? FontWeight.w700 : FontWeight.w400,
                      color: isChecked ? const Color(0xFF166534) : const Color(0xFF334155),
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
                    backgroundColor: const Color(0xFF064E3B),
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
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
  Widget _buildTabBranchClosures({required bool isAdmin, required String branchName, required bool isMobile}) {
    return FutureBuilder<BranchClosuresResponseModel>(
      future: _closuresFuture,
      builder: (context, snapshot) {
        final closures = snapshot.data?.closures ?? [];

        final startDatePicker = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Start Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
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
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _closureStartDate != null ? DateFormat('yyyy-MM-dd').format(_closureStartDate!) : 'YYYY-MM-DD',
                      style: TextStyle(fontSize: 13, color: _closureStartDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                    ),
                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          ],
        );

        final endDatePicker = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('End Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
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
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _closureEndDate != null ? DateFormat('yyyy-MM-dd').format(_closureEndDate!) : 'YYYY-MM-DD',
                      style: TextStyle(fontSize: 13, color: _closureEndDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                    ),
                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          ],
        );

        final formCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add New Closure', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
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
              const Text('Reason (e.g. End of Year Break)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(height: 4),
              TextFormField(
                controller: _closureReasonController,
                decoration: _inputDecoration(hint: 'e.g. End of Year Operational Shutdown'),
              ),
              const SizedBox(height: 16),
              // Branch target
              if (isAdmin) ...[
                const Text('Target Branch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 4),
                DropdownButtonFormField<String?>(
                  value: _selectedClosureBranchId,
                  isExpanded: true,
                  decoration: _inputDecoration(),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Branches (Global)')),
                    DropdownMenuItem(value: '997d504e-7f5c-4772-887d-fdd5a4c1183b', child: Text('Ogijo')),
                    DropdownMenuItem(value: '4ab6e1c4-6783-4bb6-904f-9da51cfab505', child: Text('Ikorodu')),
                    DropdownMenuItem(value: 'dd09c735-3b1e-4eeb-89a8-d27a85e02156', child: Text('Kola')),
                    DropdownMenuItem(value: '7ca8250a-9077-4bef-8cf3-78cf26c30705', child: Text('Ibadan')),
                    DropdownMenuItem(value: '1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d', child: Text('Head Office')),
                  ],
                  onChanged: (val) => setState(() => _selectedClosureBranchId = val),
                ),
              ] else ...[
                Text('Target Branch: $branchName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF064E3B))),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isActionLoading ? null : _handleCreateClosure,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF064E3B),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Active Closures', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 16),
              if (closures.isEmpty)
                _buildInfoCard('No custom closures recorded.')
              else ...[
                if (isMobile)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.swipe, size: 14, color: Color(0xFF64748B)),
                        SizedBox(width: 4),
                        Text('Scroll horizontally to view closures', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 12.5),
                    dataTextStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
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
                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
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
            const Text('Branch Settings & Closures', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text(
              'Manage custom branch closures (e.g., operational shutdowns, end-of-year breaks). These dates will be strictly excluded when calculating loan repayment schedules.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                ),
                onChanged: (val) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),

            if (filtered.isEmpty)
              _buildInfoCard('No audit logs recorded yet.')
            else ...[
              if (isMobile)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.swipe, size: 14, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text('Scroll horizontally to view audit trail', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 12.5),
                    dataTextStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
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
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                l.status ?? 'Logged',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: (l.status ?? '').toUpperCase() == 'SUCCESS'
                                      ? const Color(0xFF166534)
                                      : const Color(0xFF475569),
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
            const Text('Login History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            _buildInfoCard('System-wide authentication access log including successful logins, failures, and session IDs.'),
            const SizedBox(height: 16),

            if (isMobile)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.swipe, size: 14, color: Color(0xFF64748B)),
                    SizedBox(width: 4),
                    Text('Scroll horizontally to view login history', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                  ],
                ),
              ),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 12.5),
                  dataTextStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
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
                              color: isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              h.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSuccess ? const Color(0xFF166534) : const Color(0xFF991B1B),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Closure', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to delete this custom branch closure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)))),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B)))),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.5),
      ),
    );
  }
}

extension _ConnectionStateExtension on AsyncSnapshot {
  bool get connectionUriWaiting => connectionState == ConnectionState.waiting;
}
