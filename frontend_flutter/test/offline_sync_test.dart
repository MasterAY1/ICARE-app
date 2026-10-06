import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/core/offline/offline_sync_manager.dart';
import 'package:frontend_flutter/core/offline/offline_database_service.dart';
import 'package:frontend_flutter/features/co/data/datasources/co_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_flutter/core/offline/connectivity_service.dart';
import 'package:frontend_flutter/core/network/api_client.dart';

class _FailingNetworkAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'The XMLHttpRequest onError callback was called',
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MockResponseAdapter implements HttpClientAdapter {
  final int statusCode;
  final Map<String, dynamic> responseData;

  _MockResponseAdapter({required this.statusCode, required this.responseData});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final responseBytes = Uint8List.fromList(jsonEncode(responseData).codeUnits);
    return ResponseBody.fromBytes(
      responseBytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineSyncManager Unit Tests', () {
    late OfflineSyncManager syncManager;
    late PendingOutboxNotifier notifier;
    late OfflineDatabaseService dbService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dbService = OfflineDatabaseService();
      notifier = PendingOutboxNotifier(dbService);
      final apiClient = ApiClient();
      final api = CoApiService(apiClient);
      syncManager = OfflineSyncManager(dbService, api, notifier);
    });

    test('generateIdempotencyKey produces unique, sanitized keys', () {
      final key1 = syncManager.generateIdempotencyKey('Peace & Unity Group #1');
      final key2 = syncManager.generateIdempotencyKey('Peace & Unity Group #1');

      expect(key1.startsWith('IDEM-Peace___Unity_Group__1-'), isTrue);
      expect(key2.startsWith('IDEM-Peace___Unity_Group__1-'), isTrue);
      expect(key1 != key2, isTrue, reason: 'Consecutive keys must be strictly unique');
    });

    test('Idempotency key sanitizes special characters properly', () {
      final key = syncManager.generateIdempotencyKey('Branch / Ibadan - Grp (A)');
      expect(key.contains('/'), isFalse);
      expect(key.contains('('), isFalse);
      expect(key.contains(')'), isFalse);
    });

    test('queueOfflineBatch generates valid offline receipt with watermark', () async {
      final payload = {
        'group_name': 'Test Solidarity Group',
        'date': '2026-10-02',
        'group_savings_deposit': 5000.0,
        'group_savings_withdrawal': 0.0,
        'collections': [
          {
            'client_id': 'c-001',
            'client_name': 'Amina Bello',
            'loan_repayment_amount': 2500.0,
            'savings_deposit_amount': 500.0,
          },
          {
            'client_id': 'c-002',
            'client_name': 'Chidi Okafor',
            'loan_repayment_amount': 3000.0,
            'savings_deposit_amount': 1000.0,
          },
        ],
      };

      final res = await syncManager.queueOfflineBatch(
        groupName: 'Test Solidarity Group',
        collectionDate: '2026-10-02',
        payload: payload,
      );

      expect(res['offline_queued'], isTrue);
      final receipt = res['receipt'] as Map<String, dynamic>;
      expect(receipt['status'], 'QUEUED_LOCAL');
      expect(receipt['watermark'], 'OFFLINE RECORDING - PENDING SYNC');
      expect(receipt['total_repayments'], 5500.0);
      expect(receipt['total_savings'], 6500.0); // 500 + 1000 + 5000
      expect(receipt['total_cash'], 12000.0);
      expect(receipt['total_submitted'], 2);
    });

    test('cacheDashboardData stores and getCachedDashboardData retrieves dashboard offline', () async {
      final sampleDashboard = {
        'welcome': {'officer_name': 'Test Officer', 'branch_name': 'Ibadan'},
        'branch_closure': {'is_closed': false},
        'repayment_summary': {'expected': 50000.0, 'collected': 25000.0},
        'meeting_portfolio': [
          {'group_name': 'Ibadan Group A', 'expected_collection': 20000.0}
        ],
        'savings': {},
        'repayment_status': {},
        'cash_position': {},
        'attention_list': [],
      };

      await dbService.cacheDashboardData(sampleDashboard, role: 'co');
      final retrieved = await dbService.getCachedDashboardData(role: 'co');

      expect(retrieved, isNotNull);
      expect(retrieved!['welcome']['officer_name'], 'Test Officer');
      expect(retrieved['meeting_portfolio'].length, 1);
    });

    test('cacheApiResponse and getCachedApiResponse store and retrieve arbitrary API JSON', () async {
      final portfolioData = {
        'summary': {'active_loans': 42, 'portfolio_value': 2500000.0},
        'client_table': [
          {'client_name': 'Test Client', 'balance': 50000.0}
        ],
      };

      const cacheKey = '/api/v1/co/portfolio?branch=Ibadan';
      await dbService.cacheApiResponse(cacheKey, portfolioData);
      final cached = await dbService.getCachedApiResponse(cacheKey);

      expect(cached, isNotNull);
      expect(cached['summary']['active_loans'], 42);
      expect(cached['client_table'].length, 1);
    });

    test('ApiClient serves cached GET response when offline', () async {
      final connectivity = ConnectivityService();
      connectivity.reportOffline();

      final client = ApiClient(
        connectivityService: connectivity,
        offlineDb: dbService,
      );

      final sampleCashbook = {
        'opening_balance': 15000.0,
        'closing_balance': 45000.0,
        'status': 'verified',
      };

      await dbService.cacheApiResponse('/api/v1/co/cashbook', sampleCashbook);

      // Fast-path resolution from cache when offline
      final response = await client.get('/api/v1/co/cashbook');
      expect(response.statusCode, 200);
      expect(response.data['status'], 'verified');
      expect(response.data['closing_balance'], 45000.0);

      connectivity.dispose();
    });

    test('ApiClient catches connection error, marks connectivity offline, and falls back to cache', () async {
      final connectivity = ConnectivityService();
      // App starts online
      connectivity.reportOnline();
      expect(connectivity.isOnline, isTrue);

      // Pre-seed cache (as if user previously loaded portfolio while online)
      final samplePortfolio = {
        'summary': {'active_loans': 100},
      };
      await dbService.cacheApiResponse('/api/v1/co/portfolio', samplePortfolio);

      // Simulate network dropping with failing network adapter
      final client = ApiClient(
        connectivityService: connectivity,
        offlineDb: dbService,
        adapter: _FailingNetworkAdapter(),
      );

      // GET request should NOT throw DioException [connection error]
      // Instead, it should catch the connection error, report offline, and resolve from cache
      final response = await client.get('/api/v1/co/portfolio');

      expect(response.statusCode, 200);
      expect(response.data['summary']['active_loans'], 100);
      expect(connectivity.isOnline, isFalse, reason: 'ConnectivityService must immediately switch to offline');

      connectivity.dispose();
    });

    test('syncOutbox unmasks and surfaces specific server error details rather than generic network error', () async {
      final payload = {
        'group_name': 'Test Error Group',
        'date': '2026-10-04',
        'group_savings_deposit': 1000.0,
        'group_savings_withdrawal': 0.0,
        'collections': [
          {
            'client_id': 'c-999',
            'client_name': 'Test Client',
            'loan_repayment_amount': 1500.0,
            'savings_deposit_amount': 200.0,
          },
        ],
      };

      await syncManager.queueOfflineBatch(
        groupName: 'Test Error Group',
        collectionDate: '2026-10-04',
        payload: payload,
      );

      final errorAdapter = _MockResponseAdapter(
        statusCode: 403,
        responseData: {'detail': 'Operations are closed for today (Sunday).'},
      );
      final client = ApiClient(adapter: errorAdapter);
      final api = CoApiService(client);
      final failingSyncManager = OfflineSyncManager(dbService, api, notifier);

      final result = await failingSyncManager.syncOutbox();

      expect(result.success, isFalse);
      expect(result.failedCount, 1);
      expect(result.syncedCount, 0);
      expect(result.message.contains('Operations are closed for today (Sunday).'), isTrue,
          reason: 'Error message must preserve the server detail instead of masking as network error');
    });
  });
}
