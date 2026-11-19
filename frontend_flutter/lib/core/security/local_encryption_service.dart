import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'local_key_store.dart';

/// Application-level AES-256-GCM encryption helper for protecting sensitive
/// local offline caches and queued collection payloads at rest.
class LocalEncryptionService {
  static const String prefix = 'ENC:v1:';
  static const String _keyName = 'icare_local_data_key_v1';

  final AesGcm _cipher = AesGcm.with256bits();
  final LocalKeyStore? _keyStore;
  final bool memoryOnly;
  SecretKey? _cachedKey;

  LocalEncryptionService({
    LocalKeyStore? keyStore,
    this.memoryOnly = false,
  }) : _keyStore = memoryOnly ? null : (keyStore ?? getLocalKeyStore());

  Future<SecretKey> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;

    final store = _keyStore;
    if (!memoryOnly && store != null) {
      final stored = await store.readKey(_keyName);
      if (stored != null && stored.isNotEmpty) {
        try {
          final rawBytes = base64Decode(stored);
          if (rawBytes.length == 32) {
            _cachedKey = SecretKey(rawBytes);
            return _cachedKey!;
          }
        } catch (_) {}
      }
    }

    final rng = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => rng.nextInt(256));
    if (!memoryOnly && store != null) {
      await store.writeKey(_keyName, base64Encode(keyBytes));
    }
    _cachedKey = SecretKey(keyBytes);
    return _cachedKey!;
  }

  /// Encrypts UTF-8 plaintext using AES-256-GCM with a fresh random 96-bit nonce.
  Future<String> encryptString(String plaintext) async {
    final key = await _getOrCreateKey();
    final nonce = _cipher.newNonce();
    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    return '$prefix${base64Encode(secretBox.concatenation())}';
  }

  /// Decrypts an `ENC:v1:` envelope, failing closed with `null` on tampering or corruption.
  /// Legacy unencrypted strings are accepted only when `allowLegacyPlaintext` is `true`
  /// (used strictly to preserve pre-upgrade queued offline outbox batches).
  Future<String?> decryptString(
    String stored, {
    bool allowLegacyPlaintext = false,
  }) async {
    if (!stored.startsWith(prefix)) {
      return allowLegacyPlaintext ? stored : null;
    }

    try {
      final encoded = stored.substring(prefix.length);
      final bytes = base64Decode(encoded);
      final minLen = _cipher.nonceLength + _cipher.macAlgorithm.macLength;
      if (bytes.length < minLen) {
        return null;
      }

      final box = SecretBox.fromConcatenation(
        bytes,
        nonceLength: _cipher.nonceLength,
        macLength: _cipher.macAlgorithm.macLength,
      );
      final key = await _getOrCreateKey();
      final clearBytes = await _cipher.decrypt(box, secretKey: key);
      return utf8.decode(clearBytes);
    } catch (_) {
      return null;
    }
  }
}
