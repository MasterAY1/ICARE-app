class AuthUser {
  final String id;
  final String username;
  final String fullName;
  final String role;
  final String branch;
  final String? branchId;
  final List<String> assignedBranches;
  final List<String> assignedBranchIds;

  AuthUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.branch,
    this.branchId,
    this.assignedBranches = const [],
    this.assignedBranchIds = const [],
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Credit Officer',
      branch: json['branch']?.toString() ?? json['branch_name']?.toString() ?? '',
      branchId: json['branch_id']?.toString(),
      assignedBranches: (json['assigned_branches'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      assignedBranchIds: (json['assigned_branch_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'role': role,
      'branch': branch,
      'branch_id': branchId,
      'assigned_branches': assignedBranches,
      'assigned_branch_ids': assignedBranchIds,
    };
  }
}

abstract class AuthState {
  const AuthState();
}

class AuthStateInitial extends AuthState {
  const AuthStateInitial();
}

class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}

class AuthStateAuthenticated extends AuthState {
  final AuthUser user;
  final String token;
  const AuthStateAuthenticated({required this.user, required this.token});
}

class AuthStateError extends AuthState {
  final String message;
  const AuthStateError(this.message);
}
