import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_controller.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/auth/role_utils.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import 'providers/user_management_providers.dart';
import 'widgets/um_directory_tab.dart';
import 'widgets/um_governance_tabs.dart';
import 'widgets/um_provisioning_tabs.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _activeTab = 'Users Directory';
  String? _flashMessage;
  bool _flashIsError = false;

  void _setFlash(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _flashMessage = message;
      _flashIsError = isError;
    });
  }

  IconData _tabIcon(String tabName) {
    switch (tabName) {
      case 'Users Directory':
      case 'Branch Staff':
        return Icons.people_alt_outlined;
      case 'Create User':
        return Icons.person_add_outlined;
      case 'Password Reset':
        return Icons.lock_reset_outlined;
      case 'Officer Turnover':
        return Icons.swap_horiz_rounded;
      case 'Product Assignment':
        return Icons.inventory_2_outlined;
      case 'AM Assignments':
        return Icons.account_tree_outlined;
      case 'Branch Closures':
        return Icons.event_busy_outlined;
      case 'Audit Logs':
      case 'Branch Activity Logs':
        return Icons.receipt_long_outlined;
      case 'Login History':
        return Icons.login_outlined;
      default:
        return Icons.tab_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;

    ref.listen<int>(globalRefreshSignalProvider, (prev, next) {
      if (next != prev) {
        invalidateAllUserManagementProviders(ref);
      }
    });

    if (user == null) {
      return Center(
        child: Text(
          'Session expired. Please sign in again.',
          style: TextStyle(color: tokens.textMuted),
        ),
      );
    }

    final isAdmin = IcareRoleUtils.isAdmin(user.role);
    final isBm = IcareRoleUtils.isBm(user.role);
    final isAm = IcareRoleUtils.isAm(user.role);

    if (!isAdmin && !isBm && !isAm) {
      return IcareCard(
        topAccentColor: tokens.dangerDot,
        child: Row(
          children: [
            Icon(Icons.gpp_bad_outlined, color: tokens.dangerDot, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You do not have permission to access User Management.',
                style: TextStyle(
                  color: tokens.dangerText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final List<String> tabs;
    if (isAdmin) {
      tabs = const [
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
    } else {
      tabs = const [
        'Branch Staff',
        'Create User',
        'Password Reset',
        'Product Assignment',
        'Branch Closures',
        'Branch Activity Logs',
      ];
    }

    if (!tabs.contains(_activeTab)) {
      _activeTab = tabs.first;
    }

    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 720;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isBm
              ? 'Branch User Management'
              : (isAm
                  ? 'Area Staff & Closures'
                  : 'Enterprise User & Security Control'),
          style: TextStyle(
            fontSize: isMobile ? 20 : 25,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isBm
              ? 'Manage Credit Officers, product access, and closure schedules for ${user.branch}.'
              : (isAm
                  ? 'Supervise branch personnel, product permissions, and custom closures across assigned branches.'
                  : 'Full institutional directory, role provisioning, supervisory branch spans, and authentication logs.'),
          style: TextStyle(fontSize: 13, color: tokens.textMuted),
        ),
        const SizedBox(height: 16),

        if (_flashMessage != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _flashIsError ? tokens.dangerBg : tokens.successBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _flashIsError ? tokens.dangerBorder : tokens.successBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _flashIsError
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  size: 18,
                  color: _flashIsError ? tokens.dangerDot : tokens.successDot,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _flashMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          _flashIsError ? tokens.dangerText : tokens.successText,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: _flashIsError ? tokens.dangerText : tokens.successText,
                  ),
                  onPressed: () => setState(() => _flashMessage = null),
                ),
              ],
            ),
          ),
        ],

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: tabs.map((tab) {
              final selected = _activeTab == tab;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _activeTab = tab),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color:
                          selected ? tokens.brandPrimaryDark : tokens.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? tokens.brandPrimaryDark
                            : tokens.borderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _tabIcon(tab),
                          size: 15,
                          color: selected ? Colors.white : tokens.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? Colors.white : tokens.textSecondary,
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
        const SizedBox(height: 18),

        _buildActiveTab(
          isAdmin: isAdmin,
          isBm: isBm,
          isAm: isAm,
          callerBranchName: user.branch,
        ),
      ],
    );
  }

  Widget _buildActiveTab({
    required bool isAdmin,
    required bool isBm,
    required bool isAm,
    required String callerBranchName,
  }) {
    switch (_activeTab) {
      case 'Users Directory':
      case 'Branch Staff':
        return UmDirectoryTab(
          isAdmin: isAdmin,
          isBm: isBm,
          isAm: isAm,
          onFlash: _setFlash,
        );
      case 'Create User':
        return UmCreateUserTab(
          isAdmin: isAdmin,
          isBm: isBm,
          isAm: isAm,
          callerBranchName: callerBranchName,
          onFlash: _setFlash,
        );
      case 'Password Reset':
        return UmPasswordResetTab(
          isBm: isBm,
          isAm: isAm,
          onFlash: _setFlash,
        );
      case 'Officer Turnover':
        return UmOfficerTurnoverTab(onFlash: _setFlash);
      case 'Product Assignment':
        return UmProductAssignmentTab(onFlash: _setFlash);
      case 'AM Assignments':
        return UmAmAssignmentsTab(onFlash: _setFlash);
      case 'Branch Closures':
        return UmBranchClosuresTab(
          isAdmin: isAdmin,
          isBm: isBm,
          isAm: isAm,
          callerBranchName: callerBranchName,
          onFlash: _setFlash,
        );
      case 'Audit Logs':
      case 'Branch Activity Logs':
        return UmAuditLogsTab(
          isBm: isBm,
          branchName: callerBranchName,
        );
      case 'Login History':
        return const UmLoginHistoryTab();
      default:
        return const SizedBox.shrink();
    }
  }
}
