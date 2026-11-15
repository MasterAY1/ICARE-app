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

    test('Outbox IDs match across SharedPreferences and memory so synced/discarded batches do not resurrect', () async {
      final batchPayload1 = {
        'group_name': 'Unity Group',
        'date': '2026-11-14',
        'group_savings_deposit': 0.0,
        'collections': [
          {'client_id': 'c-10', 'loan_repayment_amount': 2000.0, 'savings_deposit_amount': 0.0},
        ],
      };
      final batchPayload2 = {
        'group_name': 'Hope Group',
        'date': '2026-11-14',
        'group_savings_deposit': 0.0,
        'collections': [
          {'client_id': 'c-11', 'loan_repayment_amount': 3000.0, 'savings_deposit_amount': 0.0},
        ],
      };

      final res1 = await syncManager.queueOfflineBatch(
        groupName: 'Unity Group',
        collectionDate: '2026-11-14',
        payload: batchPayload1,
      );
      final res2 = await syncManager.queueOfflineBatch(
        groupName: 'Hope Group',
        collectionDate: '2026-11-14',
        payload: batchPayload2,
      );

      final id1 = res1['outbox_id'] as int;
      final id2 = res2['outbox_id'] as int;

      await dbService.markOutboxBatchSynced(id1, 'SRV-001');
      await syncManager.discardOutboxBatch(id2);

      // Simulate full app restart / browser reload by instantiating a fresh OfflineDatabaseService
      final reloadedDb = OfflineDatabaseService(useMemoryStore: true);
      final remainingPending = await reloadedDb.getPendingOutboxBatches();
      final remainingCount = await reloadedDb.getPendingOutboxCount();

      expect(remainingPending, isEmpty);
      expect(remainingCount, 0);
    });

    test('queueOfflineBatch and queueOfflineSingleCollection optimistically update cached group sheet and single-client options', () async {
      await dbService.cacheGroupSheet('Alpha Women', {
        'group_name': 'Alpha Women',
        'available_groups': ['Alpha Women'],
        'group_savings_balance': 10000.0,
        'members': [
          {
            'client_id': 'c-201',
            'client_name': 'Kemi Ade',
            'expected_repayment': 5000.0,
            'today_repayment': 0.0,
            'today_savings': 0.0,
            'today_collected_total': 0.0,
            'today_status': 'UNRECORDED',
          },
          {
            'client_id': 'c-202',
            'client_name': 'Bola Musa',
            'expected_repayment': 4000.0,
            'today_repayment': 0.0,
            'today_savings': 0.0,
            'today_collected_total': 0.0,
            'today_status': 'UNRECORDED',
          },
        ],
      });
      await dbService.cacheApiResponse('/api/v1/co/collections/single-client-options', {
        'clients': [
          {
            'client_id': 'c-202',
            'client_name': 'Bola Musa',
            'group_name': 'Alpha Women',
            'today_repayment': 0.0,
            'today_savings': 0.0,
            'today_collected_total': 0.0,
            'today_status': 'UNRECORDED',
            'today_collected': false,
          },
        ],
      });

      await syncManager.queueOfflineBatch(
        groupName: 'Alpha Women',
        collectionDate: '2026-11-14',
        payload: {
          'group_name': 'Alpha Women',
          'date': '2026-11-14',
          'group_savings_deposit': 1500.0,
          'collections': [
            {
              'client_id': 'c-201',
              'client_name': 'Kemi Ade',
              'loan_repayment_amount': 5000.0,
              'savings_deposit_amount': 500.0,
              'payment_status': 'PAID',
            },
          ],
        },
      );

      await syncManager.queueOfflineSingleCollection(
        clientName: 'Bola Musa',
        collectionDate: '2026-11-14',
        payload: {
          'client_id': 'c-202',
          'client_name': 'Bola Musa',
          'group_name': 'Alpha Women',
          'date': '2026-11-14',
          'loan_repayment': 0.0,
          'savings_deposit': 0.0,
          'mark_not_paid': true,
        },
      );

      final updatedSheet = await dbService.getCachedGroupSheet('Alpha Women');
      expect(updatedSheet, isNotNull);
      expect(updatedSheet!['group_savings_balance'], 11500.0);

      final members = (updatedSheet['members'] as List).cast<Map<String, dynamic>>();
      final m1 = members.firstWhere((m) => m['client_id'] == 'c-201');
      expect(m1['today_status'], 'PAID');
      expect(m1['today_repayment'], 5000.0);
      expect(m1['today_savings'], 500.0);
      expect(m1['today_collected_total'], 5500.0);
      expect(m1['offline_queued'], isTrue);

      final m2 = members.firstWhere((m) => m['client_id'] == 'c-202');
      expect(m2['today_status'], 'NOT_PAID');
      expect(m2['today_collected'], isTrue);
      expect(m2['offline_queued'], isTrue);

      final scCached = await dbService.getCachedApiResponse('/api/v1/co/collections/single-client-options') as Map<String, dynamic>;
      final scClient = (scCached['clients'] as List).first as Map<String, dynamic>;
      expect(scClient['today_status'], 'NOT_PAID');
      expect(scClient['today_collected'], isTrue);
    });

    test('ConnectivityService emits stream updates cleanly on reportOffline -> reportOnline recovery', () async {
      final connectivity = ConnectivityService();
      final emissions = <bool>[];
      final sub = connectivity.statusStream.listen(emissions.add);

      connectivity.reportOffline();
      connectivity.reportOnline();
      await Future<void>.delayed(Duration.zero);

      expect(connectivity.isOnline, isTrue);
      expect(emissions, [false, true]);

      await sub.cancel();
      connectivity.dispose();
    });

    test('setSessionScope strictly isolates caches and outbox batches across users and branches', () async {
      dbService.setSessionScope(userId: 'co-user-1', branchId: 'branch-ogijo');
      await dbService.cacheDashboardData({
        'welcome': {'officer_name': 'Officer One', 'branch_name': 'Ogijo'},
      }, role: 'co');
      await dbService.cacheApiResponse('/api/v1/co/portfolio', {
        'summary': {'active_loans': 11},
      });
      await dbService.cacheGroupSheet('Ogijo Alpha', {
        'group_name': 'Ogijo Alpha',
        'available_groups': ['Ogijo Alpha'],
        'members': [],
      });
      await syncManager.queueOfflineBatch(
        groupName: 'Ogijo Alpha',
        collectionDate: '2026-11-15',
        payload: {
          'group_name': 'Ogijo Alpha',
          'date': '2026-11-15',
          'collections': [
            {'client_id': 'c-1', 'loan_repayment_amount': 1000.0, 'savings_deposit_amount': 200.0},
          ],
        },
      );

      expect(await dbService.getPendingOutboxCount(), 1);
      expect((await dbService.getCachedDashboardData(role: 'co'))?['welcome']['branch_name'], 'Ogijo');

      // Switch to different user & branch: nothing from user-1 / ogijo may leak.
      dbService.setSessionScope(userId: 'co-user-2', branchId: 'branch-ikorodu');
      expect(await dbService.getCachedDashboardData(role: 'co'), isNull);
      expect(await dbService.getCachedApiResponse('/api/v1/co/portfolio'), isNull);
      expect(await dbService.getCachedGroupSheet('Ogijo Alpha'), isNull);
      expect(await dbService.getPendingOutboxBatches(), isEmpty);
      expect(await dbService.getPendingOutboxCount(), 0);

      // Switch same user to a different branch: still isolated by branch.
      dbService.setSessionScope(userId: 'co-user-1', branchId: 'branch-ikorodu');
      expect(await dbService.getCachedDashboardData(role: 'co'), isNull);
      expect(await dbService.getPendingOutboxCount(), 0);

      // Switch back to user-1 / ogijo: original scoped data remains intact.
      dbService.setSessionScope(userId: 'co-user-1', branchId: 'branch-ogijo');
      expect((await dbService.getCachedDashboardData(role: 'co'))?['welcome']['officer_name'], 'Officer One');
      expect((await dbService.getCachedApiResponse('/api/v1/co/portfolio'))['summary']['active_loans'], 11);
      expect((await dbService.getCachedGroupSheet('Ogijo Alpha'))?['group_name'], 'Ogijo Alpha');
      expect(await dbService.getPendingOutboxCount(), 1);
    });

    test('clearSessionStorage wipes active scope caches and outbox without wiping other users', () async {
      dbService.setSessionScope(userId: 'co-user-b', branchId: 'branch-2');
      await dbService.cacheDashboardData({'welcome': {'officer_name': 'User B'}}, role: 'co');
      await syncManager.queueOfflineBatch(
        groupName: 'Group B',
        collectionDate: '2026-11-15',
        payload: {
          'group_name': 'Group B',
          'date': '2026-11-15',
          'collections': [
            {'client_id': 'c-b', 'loan_repayment_amount': 2000.0, 'savings_deposit_amount': 0.0},
          ],
        },
      );

      dbService.setSessionScope(userId: 'co-user-a', branchId: 'branch-1');
      await dbService.cacheDashboardData({'welcome': {'officer_name': 'User A'}}, role: 'co');
      await dbService.cacheApiResponse('/api/v1/co/cashbook', {'closing_balance': 5000.0});
      await dbService.cacheGroupSheet('Group A', {'group_name': 'Group A', 'members': []});
      await syncManager.queueOfflineBatch(
        groupName: 'Group A',
        collectionDate: '2026-11-15',
        payload: {
          'group_name': 'Group A',
          'date': '2026-11-15',
          'collections': [
            {'client_id': 'c-a', 'loan_repayment_amount': 1500.0, 'savings_deposit_amount': 500.0},
          ],
        },
      );

      await dbService.clearSessionStorage();

      expect(dbService.activeUserId, 'anon');
      expect(dbService.activeBranchId, 'default');
      expect(dbService.activeScopeKey, 'anon::default');

      dbService.setSessionScope(userId: 'co-user-a', branchId: 'branch-1');
      expect(await dbService.getCachedDashboardData(role: 'co'), isNull);
      expect(await dbService.getCachedApiResponse('/api/v1/co/cashbook'), isNull);
      expect(await dbService.getCachedGroupSheet('Group A'), isNull);
      expect(await dbService.getPendingOutboxBatches(), isEmpty);
      expect(await dbService.getPendingOutboxCount(), 0);

      // User B's isolated scope remains intact.
      dbService.setSessionScope(userId: 'co-user-b', branchId: 'branch-2');
      expect((await dbService.getCachedDashboardData(role: 'co'))?['welcome']['officer_name'], 'User B');
      expect(await dbService.getPendingOutboxCount(), 1);
    });
  });
}
