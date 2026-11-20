import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/network/api_client.dart';
import 'models/profile_models.dart';

final profileApiServiceProvider = Provider<ProfileApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return ProfileApiService(client);
});

class ProfileApiService {
  final ApiClient _client;

  ProfileApiService(this._client);

  /// GET /api/v1/auth/profile
  Future<StaffProfileSnapshot> fetchProfile() async {
    final res = await _client.get(
      '/api/v1/auth/profile',
      options: Options(extra: {'bypass_offline_cache': true}),
    );
    return StaffProfileSnapshot.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  /// PATCH /api/v1/auth/profile
  Future<({AuthUser user, String emergencyContact, String message})> updateProfile({
    String? phone,
    String? email,
    String? bio,
    String? emergencyContact,
    Map<String, dynamic>? preferences,
  }) async {
    final payload = <String, dynamic>{
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (bio != null) 'bio': bio,
      if (emergencyContact != null) 'emergency_contact': emergencyContact,
      if (preferences != null) 'preferences': preferences,
    };
    final res = await _client.patch('/api/v1/auth/profile', data: payload);
    final data = Map<String, dynamic>.from(res.data as Map);
    final rawUser = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : <String, dynamic>{};
    return (
      user: AuthUser.fromJson(rawUser),
      emergencyContact: data['emergency_contact']?.toString() ?? '',
      message: data['message']?.toString() ?? 'Profile updated.',
    );
  }

  /// POST /api/v1/auth/profile/avatar
  Future<({String avatarUrl, double sizeKb, String message})> uploadAvatar({
    required List<int> bytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final res = await _client.post('/api/v1/auth/profile/avatar', data: formData);
    final data = Map<String, dynamic>.from(res.data as Map);
    return (
      avatarUrl: data['avatar_url']?.toString() ?? '',
      sizeKb: (data['size_kb'] as num?)?.toDouble() ?? 0.0,
      message: data['message']?.toString() ?? 'Profile photograph updated.',
    );
  }

  /// DELETE /api/v1/auth/profile/avatar
  Future<AuthUser> removeAvatar() async {
    final res = await _client.delete('/api/v1/auth/profile/avatar');
    final data = Map<String, dynamic>.from(res.data as Map);
    final rawUser = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : <String, dynamic>{};
    return AuthUser.fromJson(rawUser);
  }

  /// POST /api/v1/auth/mfa/setup
  Future<MfaSetupBundle> initiateMfaSetup() async {
    final res = await _client.post('/api/v1/auth/mfa/setup');
    return MfaSetupBundle.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// POST /api/v1/auth/mfa/activate
  Future<String> activateMfa(String code) async {
    final res = await _client.post(
      '/api/v1/auth/mfa/activate',
      data: {'code': code.trim()},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['message']?.toString() ?? 'Two-factor authentication enabled.';
  }

  /// POST /api/v1/auth/mfa/disable
  Future<String> disableMfa(String password) async {
    final res = await _client.post(
      '/api/v1/auth/mfa/disable',
      data: {'password': password},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['message']?.toString() ?? 'Two-factor authentication disabled.';
  }

  /// POST /api/v1/auth/change-password
  Future<({String message, String? accessToken, String? csrfToken})> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await _client.post(
      '/api/v1/auth/change-password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    return (
      message: data['message']?.toString() ?? 'Password updated.',
      accessToken: data['access_token']?.toString(),
      csrfToken: data['csrf_token']?.toString(),
    );
  }
}
