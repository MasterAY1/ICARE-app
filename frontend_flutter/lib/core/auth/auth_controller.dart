import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../errors/app_error_formatter.dart';
import '../network/api_client.dart';
import '../offline/offline_database_service.dart';
import 'auth_state.dart';
import 'session_storage.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final offlineDb = ref.watch(offlineDatabaseServiceProvider);
  return AuthController(apiClient, offlineDb);
});

class AuthController extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final OfflineDatabaseService? _offlineDb;
  final SessionStorage _sessionStorage;
  final bool _useCookieAuth;

  AuthController(
    this._apiClient, [
    this._offlineDb,
    SessionStorage? storage,
    bool? useCookieAuth,
  ])  : _sessionStorage = storage ?? sessionStorage,
        _useCookieAuth = useCookieAuth ?? kIsWeb,
        super(const AuthStateInitial());

  void _bindOfflineScope(AuthUser user) {
    final branchScope = (user.branchId != null && user.branchId!.isNotEmpty)
        ? user.branchId!
        : user.branch;
    _offlineDb?.setSessionScope(userId: user.id, branchId: branchScope);
  }

  String _extractDioError(
    DioException e, {
    String unauthorizedMessage = 'Invalid username or password. Please verify your credentials.',
  }) {
    final data = e.response?.data;
    String? serverMsg;
    if (data is Map) {
      final raw = data['detail'] ?? data['message'];
      if (raw != null && raw.toString().trim().isNotEmpty) {
        serverMsg = raw.toString().trim();
      }
    }
    if (e.response?.statusCode == 401) {
      return serverMsg ?? unauthorizedMessage;
    } else if (e.response?.statusCode == 404) {
      return serverMsg ?? 'Authentication server endpoint not found (404). Please contact support.';
    } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      return 'Server connection timed out. The server may be waking up, please retry in 30 seconds.';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'Cannot connect to banking server. Please check your internet connection.';
    } else if (serverMsg != null) {
      return serverMsg;
    }
    return 'Connection error (${e.response?.statusCode ?? e.type.name}). Please retry.';
  }

  Future<bool> _completeAuthenticatedSession(
    Map<String, dynamic> data, {
    required String fallbackUsername,
  }) async {
    final rawCsrf = data['csrf_token']?.toString().trim() ?? '';
    if (rawCsrf.isNotEmpty && rawCsrf != 'null') {
      _apiClient.setCsrfToken(rawCsrf);
    }

    final rawToken = data['access_token']?.toString().trim() ?? '';
    final hasBearer = rawToken.isNotEmpty && rawToken != 'null';

    final rawUser = data['user'];
    final Map<String, dynamic> userMap;
    if (rawUser is Map<String, dynamic>) {
      userMap = rawUser;
    } else if (rawUser is Map) {
      userMap = Map<String, dynamic>.from(rawUser);
    } else {
      userMap = {'username': fallbackUsername};
    }
    final user = AuthUser.fromJson(userMap);

    if (_useCookieAuth) {
      if (rawUser is! Map && !hasBearer) {
        return false;
      }
      _apiClient.setAuthToken(null);
      _bindOfflineScope(user);
      try {
        await _sessionStorage.clearSession();
      } catch (_) {}
      state = AuthStateAuthenticated(user: user, token: '');
      return true;
    }

    if (!hasBearer) {
      return false;
    }

    _bindOfflineScope(user);
    _apiClient.setAuthToken(rawToken);
    await _sessionStorage.saveSession(rawToken, jsonEncode(user.toJson()));
    state = AuthStateAuthenticated(user: user, token: rawToken);
    return true;
  }

  Future<void> restoreSession() async {
    if (_useCookieAuth) {
      try {
        await _sessionStorage.clearSession();
      } catch (_) {}
      try {
        final response = await _apiClient.get(
          '/api/v1/auth/me',
          options: Options(extra: {'bypass_offline_cache': true}),
        );
        final data = response.data;
        if (response.statusCode == 200 &&
            data is Map &&
            data['authenticated'] == true &&
            data['user'] is Map) {
          final user = AuthUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
          final rawCsrf = data['csrf_token']?.toString().trim() ?? '';
          if (rawCsrf.isNotEmpty && rawCsrf != 'null') {
            _apiClient.setCsrfToken(rawCsrf);
          }
          _apiClient.setAuthToken(null);
          _bindOfflineScope(user);
          state = AuthStateAuthenticated(user: user, token: '');
        }
      } catch (_) {
        // Leave state unauthenticated when cookie session is absent or invalid
      }
      return;
    }

    try {
      final session = await _sessionStorage.getSession();
      if (session != null) {
        final token = session['token']!;
        final userJson = session['user']!;
        if (token.isNotEmpty && token != 'null' && userJson.isNotEmpty && userJson != 'null') {
          final userMap = jsonDecode(userJson) as Map<String, dynamic>;
          final user = AuthUser.fromJson(userMap);
          _bindOfflineScope(user);
          _apiClient.setAuthToken(token);
          state = AuthStateAuthenticated(user: user, token: token);
        } else {
          await _sessionStorage.clearSession();
        }
      }
    } catch (_) {}
  }

  Future<void> login({required String username, required String password}) async {
    state = const AuthStateLoading();
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/login',
        data: {'username': username, 'password': password},
      );

      final rawData = response.data;
      if (rawData is Map) {
        final data = Map<String, dynamic>.from(rawData);
        final isMfaRequired = data['mfa_required'] == true;
        final isPasswordChangeRequired = data['password_change_required'] == true;

        if (isPasswordChangeRequired) {
          final tempToken = data['temp_token']?.toString().trim() ?? '';
          if (tempToken.isEmpty || tempToken == 'null') {
            state = const AuthStateError('Password update is required, but no verification token was issued. Please retry.');
            return;
          }
          final rawUser = data['user'];
          final user = rawUser is Map
              ? AuthUser.fromJson(Map<String, dynamic>.from(rawUser))
              : null;
          final msg = data['message']?.toString().trim();
          state = AuthStatePasswordChangeRequired(
            tempToken: tempToken,
            username: username,
            user: user,
            message: (msg != null && msg.isNotEmpty)
                ? msg
                : 'First-time login detected. Set a new password before continuing.',
          );
          return;
        }

        if (isMfaRequired) {
          final mfaToken = data['mfa_token']?.toString().trim() ?? '';
          if (mfaToken.isEmpty || mfaToken == 'null') {
            state = const AuthStateError('Two-factor authentication is required, but no challenge token was issued. Please retry.');
            return;
          }
          final msg = data['message']?.toString().trim();
          state = AuthStateMfaRequired(
            mfaToken: mfaToken,
            username: username,
            message: (msg != null && msg.isNotEmpty)
                ? msg
                : 'Enter the 6-digit code from your authenticator app or a recovery backup code.',
          );
          return;
        }

        final completed = await _completeAuthenticatedSession(
          data,
          fallbackUsername: username,
        );
        if (completed) {
          return;
        }
      }
      state = const AuthStateError('Invalid username or password. Please verify your credentials.');
    } on DioException catch (e) {
      state = AuthStateError(_extractDioError(e));
    } catch (e) {
      state = AuthStateError('Unexpected authentication error: ${AppErrorDetails.from(e).message}');
    }
  }

  Future<void> submitMfaChallenge({required String code}) async {
    final current = state;
    if (current is! AuthStateMfaRequired) return;

    state = current.copyWith(isSubmitting: true, clearError: true);
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/mfa/challenge',
        data: {
          'mfa_token': current.mfaToken,
          'code': code.trim(),
        },
      );
      final rawData = response.data;
      if (rawData is Map) {
        final data = Map<String, dynamic>.from(rawData);
        final completed = await _completeAuthenticatedSession(
          data,
          fallbackUsername: current.username,
        );
        if (completed) {
          return;
        }
      }
      state = current.copyWith(
        isSubmitting: false,
        errorMessage: 'Verification could not be completed. Please try again.',
      );
    } on DioException catch (e) {
      final msg = _extractDioError(
        e,
        unauthorizedMessage: 'Invalid verification code. Check your authenticator app or backup code.',
      );
      final lower = msg.toLowerCase();
      if (e.response?.statusCode == 401 &&
          (lower.contains('challenge token') ||
              lower.contains('expired') ||
              lower.contains('log in again'))) {
        state = AuthStateError(msg);
      } else {
        state = current.copyWith(isSubmitting: false, errorMessage: msg);
      }
    } catch (e) {
      state = current.copyWith(
        isSubmitting: false,
        errorMessage: 'Unexpected verification error: ${AppErrorDetails.from(e).message}',
      );
    }
  }

  Future<void> submitInitialPasswordChange({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = state;
    if (current is! AuthStatePasswordChangeRequired) return;

    state = current.copyWith(isSubmitting: true, clearError: true);
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/change-initial-password',
        data: {
          'temp_token': current.tempToken,
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      final rawData = response.data;
      if (rawData is Map) {
        final data = Map<String, dynamic>.from(rawData);
        if (data['mfa_required'] == true) {
          final mfaToken = data['mfa_token']?.toString().trim() ?? '';
          if (mfaToken.isNotEmpty && mfaToken != 'null') {
            final msg = data['message']?.toString().trim();
            state = AuthStateMfaRequired(
              mfaToken: mfaToken,
              username: current.username,
              message: (msg != null && msg.isNotEmpty)
                  ? msg
                  : 'Password updated. Enter your authentication code to complete sign in.',
            );
            return;
          }
        }
        final completed = await _completeAuthenticatedSession(
          data,
          fallbackUsername: current.username,
        );
        if (completed) {
          return;
        }
      }
      state = current.copyWith(
        isSubmitting: false,
        errorMessage: 'Password update could not be completed. Please try again.',
      );
    } on DioException catch (e) {
      final msg = _extractDioError(
        e,
        unauthorizedMessage: 'Password update session expired. Please sign in again.',
      );
      final lower = msg.toLowerCase();
      if (e.response?.statusCode == 401 &&
          (lower.contains('password change token') ||
              lower.contains('expired') ||
              lower.contains('log in again'))) {
        state = AuthStateError(msg);
      } else {
        state = current.copyWith(isSubmitting: false, errorMessage: msg);
      }
    } catch (e) {
      state = current.copyWith(
        isSubmitting: false,
        errorMessage: 'Unexpected error updating password: ${AppErrorDetails.from(e).message}',
      );
    }
  }

  void cancelChallenge() {
    state = const AuthStateInitial();
  }

  /// Updates the in-memory authenticated user profile and persists it on mobile/desktop.
  Future<void> updateAuthenticatedUser(
    AuthUser updatedUser, {
    String? refreshedBearerToken,
    String? refreshedCsrfToken,
  }) async {
    if (refreshedCsrfToken != null && refreshedCsrfToken.trim().isNotEmpty) {
      _apiClient.setCsrfToken(refreshedCsrfToken);
    }

    final current = state;
    if (current is! AuthStateAuthenticated) return;

    final effectiveToken = (!_useCookieAuth &&
            refreshedBearerToken != null &&
            refreshedBearerToken.trim().isNotEmpty)
        ? refreshedBearerToken.trim()
        : current.token;

    if (!_useCookieAuth && effectiveToken.isNotEmpty) {
      _apiClient.setAuthToken(effectiveToken);
      try {
        await _sessionStorage.saveSession(effectiveToken, jsonEncode(updatedUser.toJson()));
      } catch (_) {}
    }

    state = AuthStateAuthenticated(user: updatedUser, token: effectiveToken);
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('/api/v1/auth/logout');
    } catch (_) {}
    _apiClient.setAuthToken(null);
    _apiClient.setCsrfToken(null);
    try {
      await _offlineDb?.clearSessionStorage(clearOutbox: false);
    } catch (_) {}
    try {
      await _sessionStorage.clearSession();
    } catch (_) {}
    state = const AuthStateInitial();
  }
}
