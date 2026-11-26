import 'package:flutter/material.dart';
import '../../../../core/auth/role_utils.dart';
import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../../data/models/user_management_models.dart';

typedef UmFlashCallback = void Function(String message, {bool isError});

Widget buildUmInfoCard(BuildContext context, String text) {
  final tokens = IcareSurfaceTokens.of(context);
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: tokens.infoBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: tokens.infoBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline, size: 16, color: tokens.infoDot),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, color: tokens.infoText),
          ),
        ),
      ],
    ),
  );
}

Widget buildUmErrorCard(
  BuildContext context,
  dynamic error, {
  VoidCallback? onRetry,
}) {
  final tokens = IcareSurfaceTokens.of(context);
  final details = error is AppErrorDetails ? error : AppErrorDetails.from(error);
  return IcareCard(
    topAccentColor: tokens.dangerDot,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 20, color: tokens.dangerDot),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                details.title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.dangerText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                details.message,
                style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
              ),
            ],
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('Retry'),
          ),
        ],
      ],
    ),
  );
}

InputDecoration umInputDecoration(BuildContext context, {String? hint, String? label, Widget? prefixIcon, Widget? suffixIcon}) {
  final tokens = IcareSurfaceTokens.of(context);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    hintStyle: TextStyle(fontSize: 13, color: tokens.textLight),
    filled: true,
    fillColor: tokens.surfaceSubtle,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: tokens.borderStrong),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: tokens.borderStrong),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: tokens.brandPrimary, width: 1.5),
    ),
  );
}

Color umRoleBadgeColor(String role, {required bool isDark}) {
  switch (IcareRoleUtils.normalizeKey(role)) {
    case 'admin':
      return isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9);
    case 'am':
      return isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E);
    case 'bm':
      return isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    case 'account_manager':
      return isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1);
    case 'procurement':
      return isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
    default:
      return isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);
  }
}

Widget umRoleBadge(BuildContext context, String role) {
  final tokens = IcareSurfaceTokens.of(context);
  final color = umRoleBadgeColor(role, isDark: tokens.isDark);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: tokens.isDark ? 0.16 : 0.1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      IcareRoleUtils.displayLabel(role),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

Widget umActiveStatusBadge(bool isActive) {
  return IcareStatusBadge(
    label: isActive ? 'Active' : 'Inactive',
    variant: isActive ? IcareBadgeVariant.success : IcareBadgeVariant.danger,
  );
}

String umInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

/// Filters users cleanly by caller scope, matching RBAC visibility rules.
List<UserListItemModel> filterScopedUsers(
  List<UserListItemModel> allUsers, {
  required bool isBm,
  required bool isAm,
  required String? currentUserId,
}) {
  return allUsers.where((u) {
    if ((isBm || isAm) && currentUserId != null && u.id == currentUserId) {
      return false;
    }
    if (isBm && !IcareRoleUtils.isCo(u.role)) {
      return false;
    }
    return true;
  }).toList();
}
