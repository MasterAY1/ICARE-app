// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'session_storage_base.dart';

/// Hardened Web session storage implementation.
/// Browser authentication relies exclusively on server-set HttpOnly cookies
/// paired with CSRF headers; raw tokens and user profiles are never written to
/// window.localStorage. Any legacy keys are actively purged.
class PlatformSessionStorage implements SessionStorage {
  static const _legacyTokenKey = 'icare_auth_token';
  static const _legacyUserKey = 'icare_auth_user';

  void _purgeLegacyLocalStorage() {
    try {
      html.window.localStorage.remove(_legacyTokenKey);
      html.window.localStorage.remove(_legacyUserKey);
    } catch (_) {}
  }

  @override
  Future<void> saveSession(String token, String userJson) async {
    _purgeLegacyLocalStorage();
  }

  @override
  Future<Map<String, String>?> getSession() async {
    _purgeLegacyLocalStorage();
    return null;
  }

  @override
  Future<void> clearSession() async {
    _purgeLegacyLocalStorage();
  }
}

SessionStorage getSessionStorage() => PlatformSessionStorage();
