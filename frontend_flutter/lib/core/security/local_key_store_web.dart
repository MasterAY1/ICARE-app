// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'local_key_store_base.dart';

/// Web key store using tab-scoped sessionStorage (never localStorage),
/// with an in-memory fallback when browser storage is unavailable.
class PlatformLocalKeyStore implements LocalKeyStore {
  final Map<String, String> _memoryFallback = {};

  @override
  Future<String?> readKey(String name) async {
    try {
      final val = html.window.sessionStorage[name];
      if (val != null && val.isNotEmpty) {
        _memoryFallback[name] = val;
        return val;
      }
    } catch (_) {}
    return _memoryFallback[name];
  }

  @override
  Future<void> writeKey(String name, String value) async {
    _memoryFallback[name] = value;
    try {
      html.window.sessionStorage[name] = value;
    } catch (_) {}
  }

  @override
  Future<void> deleteKey(String name) async {
    _memoryFallback.remove(name);
    try {
      html.window.sessionStorage.remove(name);
    } catch (_) {}
  }
}

LocalKeyStore getLocalKeyStore() => PlatformLocalKeyStore();
