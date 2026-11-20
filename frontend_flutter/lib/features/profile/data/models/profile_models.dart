import '../../../../core/auth/auth_state.dart';

class LoginActivityItemModel {
  final String loginTime;
  final String status;
  final String? deviceName;
  final String? browser;
  final String? operatingSystem;

  const LoginActivityItemModel({
    required this.loginTime,
    required this.status,
    this.deviceName,
    this.browser,
    this.operatingSystem,
  });

  factory LoginActivityItemModel.fromJson(Map<String, dynamic> json) {
    return LoginActivityItemModel(
      loginTime: json['login_time']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SUCCESS',
      deviceName: json['device_name']?.toString(),
      browser: json['browser']?.toString(),
      operatingSystem: json['operating_system']?.toString(),
    );
  }
}

class StaffProfileSnapshot {
  final AuthUser user;
  final String emergencyContact;
  final bool canSelfChangePassword;
  final int remainingBackupCodes;
  final String? mfaEnrolledAt;
  final List<LoginActivityItemModel> recentActivity;

  const StaffProfileSnapshot({
    required this.user,
    this.emergencyContact = '',
    this.canSelfChangePassword = false,
    this.remainingBackupCodes = 0,
    this.mfaEnrolledAt,
    this.recentActivity = const [],
  });

  factory StaffProfileSnapshot.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final userMap = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : <String, dynamic>{};

    final rawActivity = json['recent_activity'] as List<dynamic>? ?? const [];
    final activities = rawActivity
        .whereType<Map>()
        .map((m) => LoginActivityItemModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    return StaffProfileSnapshot(
      user: AuthUser.fromJson(userMap),
      emergencyContact: json['emergency_contact']?.toString() ?? '',
      canSelfChangePassword: json['can_self_change_password'] == true,
      remainingBackupCodes: (json['remaining_backup_codes'] as num?)?.toInt() ?? 0,
      mfaEnrolledAt: json['mfa_enrolled_at']?.toString(),
      recentActivity: activities,
    );
  }
}

class MfaSetupBundle {
  final String secret;
  final String otpauthUri;
  final List<String> backupCodes;

  const MfaSetupBundle({
    required this.secret,
    required this.otpauthUri,
    required this.backupCodes,
  });

  factory MfaSetupBundle.fromJson(Map<String, dynamic> json) {
    return MfaSetupBundle(
      secret: json['secret']?.toString() ?? '',
      otpauthUri: json['otpauth_uri']?.toString() ?? '',
      backupCodes: (json['backup_codes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
