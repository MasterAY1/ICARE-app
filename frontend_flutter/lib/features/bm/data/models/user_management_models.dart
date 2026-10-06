// Dart Data Models for Phase 10: User Management.
// Strongly typed, null-safe models matching api/schemas/users.py.

class UserListItemModel {
  final String id;
  final String username;
  final String fullName;
  final String role;
  final String? branchName;
  final String? branchId;
  final bool isActive;
  final String? createdAt;
  final String? lastLogin;
  final Map<String, dynamic>? extraFields;

  UserListItemModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.branchName,
    this.branchId,
    required this.isActive,
    this.createdAt,
    this.lastLogin,
    this.extraFields,
  });

  factory UserListItemModel.fromJson(Map<String, dynamic> json) {
    return UserListItemModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      branchName: json['branch_name']?.toString(),
      branchId: json['branch_id']?.toString(),
      isActive: json['is_active'] == true,
      createdAt: json['created_at']?.toString(),
      lastLogin: json['last_login']?.toString(),
      extraFields: json['extra_fields'] is Map<String, dynamic> ? json['extra_fields'] as Map<String, dynamic> : null,
    );
  }
}

class UserListResponseModel {
  final List<UserListItemModel> users;
  final int totalCount;

  UserListResponseModel({
    required this.users,
    required this.totalCount,
  });

  factory UserListResponseModel.fromJson(Map<String, dynamic> json) {
    return UserListResponseModel(
      users: (json['users'] as List<dynamic>?)
              ?.map((e) => UserListItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CreateUserResponseModel {
  final bool success;
  final String message;
  final UserListItemModel? user;

  CreateUserResponseModel({
    required this.success,
    required this.message,
    this.user,
  });

  factory CreateUserResponseModel.fromJson(Map<String, dynamic> json) {
    return CreateUserResponseModel(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      user: json['user'] is Map<String, dynamic>
          ? UserListItemModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

class GenericActionResponseModel {
  final bool success;
  final String message;

  GenericActionResponseModel({
    required this.success,
    required this.message,
  });

  factory GenericActionResponseModel.fromJson(Map<String, dynamic> json) {
    return GenericActionResponseModel(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
    );
  }
}

// -----------------------------------------------------------------------------
// Product Assignment Models
// -----------------------------------------------------------------------------
class CreditOfficerProductMetaModel {
  final String id;
  final String username;
  final String fullName;
  final List<String> allowedProducts;

  CreditOfficerProductMetaModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.allowedProducts,
  });

  factory CreditOfficerProductMetaModel.fromJson(Map<String, dynamic> json) {
    return CreditOfficerProductMetaModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      allowedProducts: (json['allowed_products'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class ProductAssignmentMetaResponseModel {
  final List<String> availableProducts;
  final List<CreditOfficerProductMetaModel> creditOfficers;

  ProductAssignmentMetaResponseModel({
    required this.availableProducts,
    required this.creditOfficers,
  });

  factory ProductAssignmentMetaResponseModel.fromJson(Map<String, dynamic> json) {
    return ProductAssignmentMetaResponseModel(
      availableProducts: (json['available_products'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      creditOfficers: (json['credit_officers'] as List<dynamic>?)
              ?.map((e) => CreditOfficerProductMetaModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// -----------------------------------------------------------------------------
// Area Manager Assignment Models
// -----------------------------------------------------------------------------
class BranchOptionItemModel {
  final String branchId;
  final String name;

  BranchOptionItemModel({
    required this.branchId,
    required this.name,
  });

  factory BranchOptionItemModel.fromJson(Map<String, dynamic> json) {
    return BranchOptionItemModel(
      branchId: json['branch_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class AMAssignmentItemModel {
  final String userId;
  final String username;
  final String fullName;
  final List<String> assignedBranchIds;
  final List<String> assignedBranchNames;

  AMAssignmentItemModel({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.assignedBranchIds,
    required this.assignedBranchNames,
  });

  factory AMAssignmentItemModel.fromJson(Map<String, dynamic> json) {
    return AMAssignmentItemModel(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      assignedBranchIds: (json['assigned_branch_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      assignedBranchNames: (json['assigned_branch_names'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class AMAssignmentsResponseModel {
  final List<AMAssignmentItemModel> areaManagers;
  final List<BranchOptionItemModel> allBranches;

  AMAssignmentsResponseModel({
    required this.areaManagers,
    required this.allBranches,
  });

  factory AMAssignmentsResponseModel.fromJson(Map<String, dynamic> json) {
    return AMAssignmentsResponseModel(
      areaManagers: (json['area_managers'] as List<dynamic>?)
              ?.map((e) => AMAssignmentItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      allBranches: (json['all_branches'] as List<dynamic>?)
              ?.map((e) => BranchOptionItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// -----------------------------------------------------------------------------
// Branch Closure Models
// -----------------------------------------------------------------------------
class BranchClosureItemModel {
  final String id;
  final String startDate;
  final String endDate;
  final String reason;
  final String? branchId;
  final String? branchName;

  BranchClosureItemModel({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.branchId,
    this.branchName,
  });

  factory BranchClosureItemModel.fromJson(Map<String, dynamic> json) {
    return BranchClosureItemModel(
      id: json['id']?.toString() ?? '',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      branchId: json['branch_id']?.toString(),
      branchName: json['branch_name']?.toString(),
    );
  }
}

class BranchClosuresResponseModel {
  final List<BranchClosureItemModel> closures;

  BranchClosuresResponseModel({
    required this.closures,
  });

  factory BranchClosuresResponseModel.fromJson(Map<String, dynamic> json) {
    return BranchClosuresResponseModel(
      closures: (json['closures'] as List<dynamic>?)
              ?.map((e) => BranchClosureItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CreateBranchClosureResponseModel {
  final bool success;
  final String message;
  final int rescheduledLoans;

  CreateBranchClosureResponseModel({
    required this.success,
    required this.message,
    required this.rescheduledLoans,
  });

  factory CreateBranchClosureResponseModel.fromJson(Map<String, dynamic> json) {
    return CreateBranchClosureResponseModel(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      rescheduledLoans: (json['rescheduled_loans'] as num?)?.toInt() ?? 0,
    );
  }
}

// -----------------------------------------------------------------------------
// User Audit Logs & Login History Models
// -----------------------------------------------------------------------------
class UserAuditLogItemModel {
  final String? id;
  final String timestamp;
  final String username;
  final String? role;
  final String? branch;
  final String action;
  final String? module;
  final String? entityType;
  final String? displayName;
  final String? status;

  UserAuditLogItemModel({
    this.id,
    required this.timestamp,
    required this.username,
    this.role,
    this.branch,
    required this.action,
    this.module,
    this.entityType,
    this.displayName,
    this.status,
  });

  factory UserAuditLogItemModel.fromJson(Map<String, dynamic> json) {
    return UserAuditLogItemModel(
      id: json['id']?.toString(),
      timestamp: json['timestamp']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      role: json['role']?.toString(),
      branch: json['branch']?.toString(),
      action: json['action']?.toString() ?? '',
      module: json['module']?.toString(),
      entityType: json['entity_type']?.toString(),
      displayName: json['display_name']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class UserAuditLogsResponseModel {
  final List<UserAuditLogItemModel> logs;
  final int totalCount;

  UserAuditLogsResponseModel({
    required this.logs,
    required this.totalCount,
  });

  factory UserAuditLogsResponseModel.fromJson(Map<String, dynamic> json) {
    return UserAuditLogsResponseModel(
      logs: (json['logs'] as List<dynamic>?)
              ?.map((e) => UserAuditLogItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class LoginHistoryItemModel {
  final String? id;
  final String loginTime;
  final String username;
  final String status;
  final String? sessionId;
  final String? logoutTime;
  final int failedAttempts;

  LoginHistoryItemModel({
    this.id,
    required this.loginTime,
    required this.username,
    required this.status,
    this.sessionId,
    this.logoutTime,
    required this.failedAttempts,
  });

  factory LoginHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return LoginHistoryItemModel(
      id: json['id']?.toString(),
      loginTime: json['login_time']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SUCCESS',
      sessionId: json['session_id']?.toString(),
      logoutTime: json['logout_time']?.toString(),
      failedAttempts: (json['failed_attempts'] as num?)?.toInt() ?? 0,
    );
  }
}

class LoginHistoryResponseModel {
  final List<LoginHistoryItemModel> history;
  final int totalCount;

  LoginHistoryResponseModel({
    required this.history,
    required this.totalCount,
  });

  factory LoginHistoryResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginHistoryResponseModel(
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => LoginHistoryItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );
  }
}
