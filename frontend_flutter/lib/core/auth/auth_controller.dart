import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import 'auth_state.dart';
import 'session_storage.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthController(apiClient);
});

class AuthController extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthController(this._apiClient) : super(const AuthStateInitial());

  Future<void> restoreSession() async {
    try {
      final session = await sessionStorage.getSession();
      if (session != null) {
        final token = session['token']!;
        final userJson = session['user']!;
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        final user = AuthUser.fromJson(userMap);
        _apiClient.setAuthToken(token);
        state = AuthStateAuthenticated(user: user, token: token);
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
      if (data is Map<String, dynamic> && data.containsKey('access_token')) {
        final token = data['access_token'].toString();
        final userMap = data['user'] is Map<String, dynamic> ? data['user'] as Map<String, dynamic> : {'username': username};
        final user = AuthUser.fromJson(userMap);

        _apiClient.setAuthToken(token);
        await sessionStorage.saveSession(token, jsonEncode(user.toJson()));
        state = AuthStateAuthenticated(user: user, token: token);
      } else {
        state = const AuthStateError('Invalid credentials. Please verify your username and password.');
      }
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
      await sessionStorage.clearSession();
    } catch (_) {}
    state = const AuthStateInitial();
  }
}
