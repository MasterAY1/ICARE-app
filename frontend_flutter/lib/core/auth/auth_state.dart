class AuthUser {
  final String id;
  final String username;
  final String fullName;
  final String role;
  final String branch;
  final String? branchId;
  final List<String> assignedBranches;
  final List<String> assignedBranchIds;
  final List<String> allowedProducts;
  final String phone;
  final String email;
  final String avatarUrl;
  final String bio;
  final bool mfaEnabled;
  final bool isMiscSavingsManager;
  final String? createdAt;
  final String? lastLogin;
  final Map<String, dynamic> preferences;

  AuthUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.branch,
    this.branchId,
    this.assignedBranches = const [],
    this.assignedBranchIds = const [],
    this.allowedProducts = const [],
    this.phone = '',
    this.email = '',
    this.avatarUrl = '',
    this.bio = '',
    this.mfaEnabled = false,
    this.isMiscSavingsManager = false,
    this.createdAt,
    this.lastLogin,
    this.preferences = const {},
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawPrefs = json['preferences'];
    final Map<String, dynamic> parsedPrefs = rawPrefs is Map
        ? Map<String, dynamic>.from(rawPrefs)
        : const <String, dynamic>{};

    return AuthUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Credit Officer',
      branch: json['branch']?.toString() ?? json['branch_name']?.toString() ?? '',
      branchId: json['branch_id']?.toString(),
      assignedBranches: (json['assigned_branches'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      assignedBranchIds: (json['assigned_branch_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      allowedProducts: (json['allowed_products'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      mfaEnabled: json['mfa_enabled'] == true,
      isMiscSavingsManager: json['is_misc_savings_manager'] == true,
      createdAt: json['created_at']?.toString(),
      lastLogin: json['last_login']?.toString(),
      preferences: parsedPrefs,
    );
  }

  AuthUser copyWith({
    String? fullName,
    String? phone,
    String? email,
    String? avatarUrl,
    String? bio,
    bool? mfaEnabled,
    Map<String, dynamic>? preferences,
  }) {
    return AuthUser(
      id: id,
      username: username,
      fullName: fullName ?? this.fullName,
      role: role,
      branch: branch,
      branchId: branchId,
      assignedBranches: assignedBranches,
      assignedBranchIds: assignedBranchIds,
      allowedProducts: allowedProducts,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      mfaEnabled: mfaEnabled ?? this.mfaEnabled,
      isMiscSavingsManager: isMiscSavingsManager,
      createdAt: createdAt,
      lastLogin: lastLogin,
      preferences: preferences ?? this.preferences,
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
      'allowed_products': allowedProducts,
      'phone': phone,
      'email': email,
      'avatar_url': avatarUrl,
      'bio': bio,
      'mfa_enabled': mfaEnabled,
      'is_misc_savings_manager': isMiscSavingsManager,
      'created_at': createdAt,
      'last_login': lastLogin,
      'preferences': preferences,
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

class AuthStateMfaRequired extends AuthState {
  final String mfaToken;
  final String username;
  final String message;
  final String? errorMessage;
  final bool isSubmitting;

  const AuthStateMfaRequired({
    required this.mfaToken,
    required this.username,
    this.message = 'Enter the 6-digit code from your authenticator app or a recovery backup code.',
    this.errorMessage,
    this.isSubmitting = false,
  });

  AuthStateMfaRequired copyWith({
    String? mfaToken,
    String? username,
    String? message,
    String? errorMessage,
    bool clearError = false,
    bool? isSubmitting,
  }) {
    return AuthStateMfaRequired(
      mfaToken: mfaToken ?? this.mfaToken,
      username: username ?? this.username,
      message: message ?? this.message,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class AuthStatePasswordChangeRequired extends AuthState {
  final String tempToken;
  final String username;
  final AuthUser? user;
  final String message;
  final String? errorMessage;
  final bool isSubmitting;

  const AuthStatePasswordChangeRequired({
    required this.tempToken,
    required this.username,
    this.user,
    this.message = 'First-time login detected. Set a new password before continuing.',
    this.errorMessage,
    this.isSubmitting = false,
  });

  AuthStatePasswordChangeRequired copyWith({
    String? tempToken,
    String? username,
    AuthUser? user,
    String? message,
    String? errorMessage,
    bool clearError = false,
    bool? isSubmitting,
  }) {
    return AuthStatePasswordChangeRequired(
      tempToken: tempToken ?? this.tempToken,
      username: username ?? this.username,
      user: user ?? this.user,
      message: message ?? this.message,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class AuthStateError extends AuthState {
  final String message;
  const AuthStateError(this.message);
}
