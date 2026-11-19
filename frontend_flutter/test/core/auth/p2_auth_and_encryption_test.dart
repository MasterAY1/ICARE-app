import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_flutter/core/auth/auth_controller.dart';
import 'package:frontend_flutter/core/auth/auth_state.dart';
import 'package:frontend_flutter/core/auth/session_storage_base.dart';
import 'package:frontend_flutter/core/network/api_client.dart';
import 'package:frontend_flutter/core/offline/offline_database_service.dart';
import 'package:frontend_flutter/core/security/local_encryption_service.dart';
import 'package:frontend_flutter/core/security/local_key_store_base.dart';

class _InMemorySessionStorage implements SessionStorage {
  Map<String, String>? _stored;
  bool saveCalled = false;
  bool clearCalled = false;

  @override
  Future<void> saveSession(String token, String userJson) async {
    saveCalled = true;
    _stored = {'token': token, 'user': userJson};
  }

  @override
  Future<Map<String, String>?> getSession() async => _stored;

  @override
  Future<void> clearSession() async {
    clearCalled = true;
    _stored = null;
  }
}

class _InMemoryKeyStore implements LocalKeyStore {
  final Map<String, String> _keys = {};

  @override
  Future<String?> readKey(String name) async => _keys[name];

  @override
  Future<void> writeKey(String name, String value) async {
    _keys[name] = value;
  }

  @override
  Future<void> deleteKey(String name) async {
    _keys.remove(name);
  }
}

class _FakeHttpAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  _FakeHttpAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Map<String, dynamic> body, [int statusCode = 200]) {
  return ResponseBody.fromBytes(
    Uint8List.fromList(utf8.encode(jsonEncode(body))),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Priority 2 Auth Continuation, Web Cookie/CSRF & Encryption Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('MFA continuation keeps challenge state on bad code and authenticates on valid code', () async {
      final adapter = _FakeHttpAdapter((options) async {
        if (options.path == '/api/v1/auth/login') {
          return _jsonResponse({
            'access_token': null,
            'mfa_required': true,
            'mfa_token': 'mfa-temp-123',
            'password_change_required': false,
          });
        }
        if (options.path == '/api/v1/auth/mfa/challenge') {
          final body = options.data as Map<String, dynamic>;
          if (body['code'] == '000000') {
            return _jsonResponse({'detail': 'Invalid MFA verification code.'}, 401);
          }
          return _jsonResponse({
            'access_token': 'session-jwt-mfa-ok',
            'mfa_required': false,
            'user': {
              'id': 'usr-co-1',
              'username': 'co_mfa',
              'full_name': 'MFA Officer',
              'role': 'Credit Officer',
              'branch': 'Ikeja',
              'branch_id': 'b-ikeja',
            },
          });
        }
        return _jsonResponse({}, 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://localhost:8000', adapter: adapter, isWebOverride: false);
      final storage = _InMemorySessionStorage();
      final db = OfflineDatabaseService(useMemoryStore: true);
      final controller = AuthController(apiClient, db, storage, false);

      await controller.login(username: 'co_mfa', password: 'secret');
      expect(controller.state, isA<AuthStateMfaRequired>());
      final mfaState = controller.state as AuthStateMfaRequired;
      expect(mfaState.mfaToken, 'mfa-temp-123');

      await controller.submitMfaChallenge(code: '000000');
      expect(controller.state, isA<AuthStateMfaRequired>());
      expect((controller.state as AuthStateMfaRequired).errorMessage, contains('Invalid MFA'));
      expect((controller.state as AuthStateMfaRequired).isSubmitting, isFalse);

      await controller.submitMfaChallenge(code: '123456');
      expect(controller.state, isA<AuthStateAuthenticated>());
      final authState = controller.state as AuthStateAuthenticated;
      expect(authState.user.username, 'co_mfa');
      expect(authState.token, 'session-jwt-mfa-ok');
      expect(storage.saveCalled, isTrue);
    });

    test('Forced password rotation chains smoothly into MFA challenge and authenticates', () async {
      final adapter = _FakeHttpAdapter((options) async {
        if (options.path == '/api/v1/auth/login') {
          return _jsonResponse({
            'access_token': null,
            'password_change_required': true,
            'temp_token': 'pwd-temp-999',
            'mfa_required': false,
            'message': 'First-time login detected.',
            'user': {
              'id': 'usr-bm-1',
              'username': 'bm_new',
              'full_name': 'New BM',
              'role': 'Branch Manager',
              'branch': 'Ogijo',
              'branch_id': 'b-ogijo',
            },
          });
        }
        if (options.path == '/api/v1/auth/change-initial-password') {
          return _jsonResponse({
            'access_token': null,
            'password_change_required': false,
            'mfa_required': true,
            'mfa_token': 'mfa-after-pwd-888',
            'message': 'Password updated. Enter your authentication code.',
          });
        }
        if (options.path == '/api/v1/auth/mfa/challenge') {
          return _jsonResponse({
            'access_token': 'bm-final-token',
            'mfa_required': false,
            'user': {
              'id': 'usr-bm-1',
              'username': 'bm_new',
              'full_name': 'New BM',
              'role': 'Branch Manager',
              'branch': 'Ogijo',
              'branch_id': 'b-ogijo',
            },
          });
        }
        return _jsonResponse({}, 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://localhost:8000', adapter: adapter, isWebOverride: false);
      final storage = _InMemorySessionStorage();
      final db = OfflineDatabaseService(useMemoryStore: true);
      final controller = AuthController(apiClient, db, storage, false);

      await controller.login(username: 'bm_new', password: 'DefaultPass123!');
      expect(controller.state, isA<AuthStatePasswordChangeRequired>());

      await controller.submitInitialPasswordChange(
        currentPassword: 'DefaultPass123!',
        newPassword: 'MyStrongPassword2026!',
      );
      expect(controller.state, isA<AuthStateMfaRequired>());
      expect((controller.state as AuthStateMfaRequired).mfaToken, 'mfa-after-pwd-888');

      await controller.submitMfaChallenge(code: '654321');
      expect(controller.state, isA<AuthStateAuthenticated>());
      expect((controller.state as AuthStateAuthenticated).token, 'bm-final-token');
    });

    test('Web cookie mode avoids saving tokens in local storage, attaches CSRF headers, and restores via /auth/me', () async {
      final adapter = _FakeHttpAdapter((options) async {
        if (options.path == '/api/v1/auth/login') {
          return _jsonResponse({
            'access_token': null,
            'csrf_token': 'csrf-token-web-abc',
            'mfa_required': false,
            'user': {
              'id': 'usr-web-1',
              'username': 'web_officer',
              'full_name': 'Web Officer',
              'role': 'Credit Officer',
              'branch': 'Ikeja',
              'branch_id': 'b-ikeja',
            },
          });
        }
        if (options.path == '/api/v1/auth/me') {
          return _jsonResponse({
            'authenticated': true,
            'csrf_token': 'csrf-token-web-refreshed',
            'user': {
              'id': 'usr-web-1',
              'username': 'web_officer',
              'full_name': 'Web Officer',
              'role': 'Credit Officer',
              'branch': 'Ikeja',
              'branch_id': 'b-ikeja',
            },
          });
        }
        return _jsonResponse({'success': true});
      });

      final apiClient = ApiClient(baseUrl: 'http://localhost:8000', adapter: adapter, isWebOverride: true);
      final storage = _InMemorySessionStorage();
      await storage.saveSession('stale-legacy-token', '{}');
      storage.saveCalled = false;

      final db = OfflineDatabaseService(useMemoryStore: true);
      final controller = AuthController(apiClient, db, storage, true);

      // 1. Login in Web cookie mode
      await controller.login(username: 'web_officer', password: 'password123');
      expect(controller.state, isA<AuthStateAuthenticated>());
      expect((controller.state as AuthStateAuthenticated).token, isEmpty);
      expect(storage.saveCalled, isFalse);
      expect(await storage.getSession(), isNull);
      expect(apiClient.csrfToken, 'csrf-token-web-abc');
      expect(adapter.requests.first.headers['X-Auth-Mode'], 'cookie');
      expect(adapter.requests.first.headers.containsKey('Authorization'), isFalse);

      // 2. Mutating request automatically carries X-CSRF-Token
      await apiClient.post('/api/v1/co/collections/batch-submit', data: {'group_name': 'Unity'});
      final mutReq = adapter.requests.last;
      expect(mutReq.headers['X-CSRF-Token'], 'csrf-token-web-abc');

      // 3. Reload / restoreSession calls GET /api/v1/auth/me without Bearer token
      final restoredController = AuthController(
        ApiClient(baseUrl: 'http://localhost:8000', adapter: adapter, isWebOverride: true),
        db,
        storage,
        true,
      );
      await restoredController.restoreSession();
      expect(restoredController.state, isA<AuthStateAuthenticated>());
      expect((restoredController.state as AuthStateAuthenticated).user.username, 'web_officer');

      // 4. Logout sends X-CSRF-Token and clears CSRF state
      await controller.logout();
      expect(controller.state, isA<AuthStateInitial>());
      expect(apiClient.csrfToken, isNull);
      expect(adapter.requests.last.path, '/api/v1/auth/logout');
      expect(adapter.requests.last.headers['X-CSRF-Token'], 'csrf-token-web-abc');
    });

    test('LocalEncryptionService and OfflineDatabaseService encrypt sensitive caches & outbox at rest', () async {
      final keyStore = _InMemoryKeyStore();
      final encService = LocalEncryptionService(keyStore: keyStore);
      final db = OfflineDatabaseService(
        useMemoryStore: true,
        userId: 'usr-sec-1',
        branchId: 'b-sec',
        encryptionService: encService,
      );

      const sensitiveName = 'Adesewa Ogunleye';
      const sensitiveLoanId = 'LN-SECRET-9988';

      await db.cacheDashboardData({
        'client_name': sensitiveName,
        'today_collection': 45000,
      });
      await db.cacheApiResponse('/api/v1/co/portfolio/clients', {
        'clients': [
          {'client_name': sensitiveName, 'loan_id': sensitiveLoanId, 'balance': 125000}
        ],
      });
      await db.cacheGroupSheet(
        'Unity Women',
        {
          'group_name': 'Unity Women',
          'members': [
            {'client_id': 'c-1', 'client_name': sensitiveName, 'loan_balance': 50000}
          ],
        },
        dateStr: '2026-11-19',
      );
      await db.queueBatchCollection(
        idempotencyKey: 'idem-enc-1',
        groupName: 'Unity Women',
        collectionDate: '2026-11-19',
        payload: {
          'group_name': 'Unity Women',
          'collections': [
            {'client_id': 'c-1', 'client_name': sensitiveName, 'loan_id': sensitiveLoanId, 'amount': 5000}
          ],
        },
        optimisticMeta: {'group_name': 'Unity Women', 'clients': {}},
      );

      // Verify raw SharedPreferences values are all encrypted ciphertext containing ZERO plaintext PII
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      expect(allKeys.isNotEmpty, isTrue);
      for (final k in allKeys) {
        final v = prefs.get(k);
        if (v is String && !k.contains('timestamp')) {
          expect(v.startsWith(LocalEncryptionService.prefix), isTrue, reason: 'Key $k was not encrypted');
          expect(v.contains(sensitiveName), isFalse, reason: 'Plaintext name leaked in $k');
          expect(v.contains(sensitiveLoanId), isFalse, reason: 'Plaintext loan ID leaked in $k');
        }
      }

      // Verify decryption roundtrip through service getters
      final dbAfterRestart = OfflineDatabaseService(
        useMemoryStore: true,
        userId: 'usr-sec-1',
        branchId: 'b-sec',
        encryptionService: LocalEncryptionService(keyStore: keyStore),
      );
      final dash = await dbAfterRestart.getCachedDashboardData();
      expect(dash?['client_name'], sensitiveName);

      final apiCached = await dbAfterRestart.getCachedApiResponse('/api/v1/co/portfolio/clients');
      expect((apiCached['clients'] as List).first['loan_id'], sensitiveLoanId);

      final sheet = await dbAfterRestart.getCachedGroupSheet('Unity Women', dateStr: '2026-11-19');
      expect((sheet?['members'] as List).first['client_name'], sensitiveName);

      final outbox = await dbAfterRestart.getPendingOutboxBatches();
      expect(outbox.length, 1);
      final decodedPayload = jsonDecode(outbox.first['payload_json'].toString()) as Map<String, dynamic>;
      expect((decodedPayload['collections'] as List).first['client_name'], sensitiveName);

      // Verify tampered ciphertext fails closed
      final tampered = await encService.encryptString('{"secret": 1}');
      final badCipher = '${tampered.substring(0, tampered.length - 4)}AAAA';
      expect(await encService.decryptString(badCipher), isNull);

      // Verify legacy unencrypted outbox payloads remain readable for offline data safety
      SharedPreferences.setMockInitialValues({
        'offline_persisted_outbox_usr-legacy::b-leg': jsonEncode([
          {
            'id': 77,
            'scope_key': 'usr-legacy::b-leg',
            'idempotency_key': 'legacy-key-1',
            'operation_type': 'BATCH_COLLECTION',
            'group_name': 'Legacy Group',
            'collection_date': '2026-11-18',
            'payload_json': jsonEncode({'group_name': 'Legacy Group', 'collections': []}),
            'status': 'pending',
            'retry_count': 0,
            'created_at': '2026-11-18T10:00:00',
          }
        ]),
      });
      final legacyDb = OfflineDatabaseService(
        useMemoryStore: true,
        userId: 'usr-legacy',
        branchId: 'b-leg',
        encryptionService: LocalEncryptionService(keyStore: keyStore),
      );
      final legacyOutbox = await legacyDb.getPendingOutboxBatches();
      expect(legacyOutbox.length, 1);
      expect(legacyOutbox.first['idempotency_key'], 'legacy-key-1');
    });
  });
}
