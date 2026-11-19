import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'session_storage_base.dart';

/// Hardened native mobile/desktop session storage using platform secure storage
/// (Android Keystore / iOS Keychain) and purging any legacy plaintext session files.
class PlatformSessionStorage implements SessionStorage {
  static const _tokenKey = 'icare_secure_auth_token';
  static const _userKey = 'icare_secure_auth_user';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  Future<void> _purgeLegacyPlaintextFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final legacyFile = File('${dir.path}/icare_session.json');
      if (await legacyFile.exists()) {
        await legacyFile.delete();
      }
    } catch (_) {}
  }

  @override
  Future<void> saveSession(String token, String userJson) async {
    await _purgeLegacyPlaintextFile();
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
      await _secureStorage.write(key: _userKey, value: userJson);
    } catch (_) {}
  }

  @override
  Future<Map<String, String>?> getSession() async {
    await _purgeLegacyPlaintextFile();
    try {
      final token = (await _secureStorage.read(key: _tokenKey))?.trim();
      final userJson = (await _secureStorage.read(key: _userKey))?.trim();
      if (token != null && token.isNotEmpty && userJson != null && userJson.isNotEmpty) {
        return {'token': token, 'user': userJson};
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> clearSession() async {
    await _purgeLegacyPlaintextFile();
    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _userKey);
    } catch (_) {}
  }
}

SessionStorage getSessionStorage() => PlatformSessionStorage();
