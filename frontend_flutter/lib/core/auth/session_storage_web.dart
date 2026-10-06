// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'session_storage_base.dart';

class PlatformSessionStorage implements SessionStorage {
  static const _tokenKey = 'icare_auth_token';
  static const _userKey = 'icare_auth_user';

  @override
  Future<void> saveSession(String token, String userJson) async {
    try {
      html.window.localStorage[_tokenKey] = token;
      html.window.localStorage[_userKey] = userJson;
    } catch (_) {}
  }

  @override
  Future<Map<String, String>?> getSession() async {
    try {
      final token = html.window.localStorage[_tokenKey];
      final userJson = html.window.localStorage[_userKey];
      if (token != null && token.isNotEmpty && userJson != null && userJson.isNotEmpty) {
        return {'token': token, 'user': userJson};
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> clearSession() async {
    try {
      html.window.localStorage.remove(_tokenKey);
      html.window.localStorage.remove(_userKey);
    } catch (_) {}
  }
}

SessionStorage getSessionStorage() => PlatformSessionStorage();
