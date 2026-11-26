/// Canonical client-side role normalization and RBAC helpers.
/// Mirrors backend `services/rbac_scope_service.py` so uppercase, underscore,
/// and alias strings resolve identically across navigation, User Management,
/// and Audit Ledger.
class IcareRoleUtils {
  IcareRoleUtils._();

  static String normalizeKey(String? rawRole) {
    final clean = (rawRole ?? '')
        .trim()
        .toUpperCase()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    switch (clean) {
      case 'CO':
      case 'CREDIT OFFICER':
      case 'OFFICER':
      case 'FIELD OFFICER':
        return 'co';
      case 'BM':
      case 'BRANCH MANAGER':
      case 'MANAGER':
        return 'bm';
      case 'AM':
      case 'AREA MANAGER':
      case 'REGIONAL MANAGER':
        return 'am';
      case 'ACCOUNT MANAGER':
      case 'ACCOUNTANT':
        return 'account_manager';
      case 'PROCUREMENT OFFICER':
      case 'PROCUREMENT':
      case 'ASSET MANAGER':
      case 'PO':
        return 'procurement';
      case 'DIRECTOR':
      case 'EXECUTIVE DIRECTOR':
      case 'BOARD DIRECTOR':
      case 'EXECUTIVE':
        return 'director';
      case 'ADMIN':
      case 'ADMINISTRATOR':
      case 'SUPER ADMIN':
      case 'SUPERADMIN':
      case 'GLOBAL ADMIN':
      case 'SYSTEM ADMIN':
      case 'SYSTEM ADMINISTRATOR':
        return 'admin';
      default:
        return 'unknown';
    }
  }

  static bool isCo(String? role) => normalizeKey(role) == 'co';
  static bool isBm(String? role) => normalizeKey(role) == 'bm';
  static bool isAm(String? role) => normalizeKey(role) == 'am';
  static bool isAccountManager(String? role) =>
      normalizeKey(role) == 'account_manager';
  static bool isProcurement(String? role) =>
      normalizeKey(role) == 'procurement';
  static bool isDirector(String? role) => normalizeKey(role) == 'director';
  static bool isAdmin(String? role) => normalizeKey(role) == 'admin';

  /// Executive read-only or administrative oversight (Admin, Super Admin, Director).
  static bool isExecutive(String? role) {
    final key = normalizeKey(role);
    return key == 'admin' || key == 'director';
  }

  static String displayLabel(String? rawRole) {
    final clean = (rawRole ?? '').trim();
    switch (normalizeKey(clean)) {
      case 'co':
        return 'Credit Officer';
      case 'bm':
        return 'Branch Manager';
      case 'am':
        return 'Area Manager';
      case 'account_manager':
        return 'Account Manager';
      case 'procurement':
        return 'Procurement Officer';
      case 'director':
        return 'Director';
      case 'admin':
        return clean.toUpperCase().contains('SUPER')
            ? 'Super Admin'
            : 'Admin';
      default:
        return clean.isNotEmpty ? clean : 'Credit Officer';
    }
  }
}
