import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  AuthController(this._apiClient, [this._offlineDb]) : super(const AuthStateInitial());

  void _bindOfflineScope(AuthUser user) {
    final branchScope = (user.branchId != null && user.branchId!.isNotEmpty)
        ? user.branchId!
        : user.branch;
    _offlineDb?.setSessionScope(userId: user.id, branchId: branchScope);
  }

  Future<void> restoreSession() async {
    try {
      final session = await sessionStorage.getSession();
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
          await sessionStorage.clearSession();
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

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final rawToken = data['access_token'];
        final isMfaRequired = data['mfa_required'] == true;
        final isPasswordChangeRequired = data['password_change_required'] == true;

        if (isMfaRequired) {
          state = const AuthStateError('Two-factor security code required. Please enter your authenticator app code or contact an administrator.');
          return;
        }

        if (isPasswordChangeRequired) {
          state = const AuthStateError('First-time sign in detected. Please update your temporary password before proceeding, or contact your administrator.');
          return;
        }

        if (rawToken != null && rawToken.toString().trim().isNotEmpty && rawToken.toString() != 'null') {
          final token = rawToken.toString();
          final userMap = data['user'] is Map<String, dynamic> ? data['user'] as Map<String, dynamic> : {'username': username};
          final user = AuthUser.fromJson(userMap);

          _bindOfflineScope(user);
          _apiClient.setAuthToken(token);
          await sessionStorage.saveSession(token, jsonEncode(user.toJson()));
          state = AuthStateAuthenticated(user: user, token: token);
          return;
        }
      }
      state = const AuthStateError('Invalid username or password. Please verify your credentials.');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        state = const AuthStateError('Invalid username or password. Please verify your credentials.');
      } else if (e.response?.statusCode == 404) {
        state = const AuthStateError('Authentication server endpoint not found (404). Please contact support.');
      } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        state = const AuthStateError('Server connection timed out. The server may be waking up, please retry in 30 seconds.');
      } else if (e.type == DioExceptionType.connectionError) {
        state = const AuthStateError('Cannot connect to banking server. Please check your internet connection.');
      } else if (e.response?.data is Map && (e.response!.data as Map).containsKey('detail')) {
        state = AuthStateError(e.response!.data['detail'].toString());
      } else {
        state = AuthStateError('Connection error (${e.response?.statusCode ?? e.type.name}). Please retry.');
      }
    } catch (e) {
      state = AuthStateError('Unexpected authentication error: $e');
    }
  }

  Future<void> logout() async {
    _apiClient.setAuthToken(null);
    try {
      await _offlineDb?.clearSessionStorage();
    } catch (_) {}
    try {
      await sessionStorage.clearSession();
    } catch (_) {}
    state = const AuthStateInitial();
  }
}
