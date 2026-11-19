import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'local_key_store_base.dart';

class PlatformLocalKeyStore implements LocalKeyStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
  final Map<String, String> _memoryFallback = {};

  @override
  Future<String?> readKey(String name) async {
    try {
      final val = await _storage.read(key: name);
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
      await _storage.write(key: name, value: value);
    } catch (_) {}
  }

  @override
  Future<void> deleteKey(String name) async {
    _memoryFallback.remove(name);
    try {
      await _storage.delete(key: name);
    } catch (_) {}
  }
}

LocalKeyStore getLocalKeyStore() => PlatformLocalKeyStore();
