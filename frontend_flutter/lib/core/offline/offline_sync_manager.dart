import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import '../../features/co/data/datasources/co_api_service.dart';
import 'offline_database_service.dart';

final pendingOutboxCountProvider = StateNotifierProvider<PendingOutboxNotifier, int>((ref) {
  final dbService = ref.watch(offlineDatabaseServiceProvider);
  final notifier = PendingOutboxNotifier(dbService);
  ref.listen<AuthState>(authControllerProvider, (_, __) {
    notifier.refresh();
  });
  return notifier;
});

class PendingOutboxNotifier extends StateNotifier<int> {
  final OfflineDatabaseService _db;
  PendingOutboxNotifier(this._db) : super(0) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final count = await _db.getPendingOutboxCount();
      state = count;
    } catch (_) {
      // In case table not yet ready
    }
  }
}

final offlineSyncManagerProvider = Provider<OfflineSyncManager>((ref) {
  final dbService = ref.watch(offlineDatabaseServiceProvider);
  final coApi = ref.watch(coApiServiceProvider);
  final notifier = ref.watch(pendingOutboxCountProvider.notifier);
  return OfflineSyncManager(dbService, coApi, notifier);
});

/// High-level manager orchestrating synchronization between local SQLite storage
/// and the central Supabase Financial Ledger via the FastAPI backend.
class OfflineSyncManager {
  final OfflineDatabaseService _db;
  final CoApiService _api;
  final PendingOutboxNotifier _outboxNotifier;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  OfflineSyncManager(this._db, this._api, this._outboxNotifier);

  /// Generates a globally unique client transaction key for idempotent execution.
  String generateIdempotencyKey(String groupName) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(999999).toString().padLeft(6, '0');
    final sanitizedGroup = groupName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return 'IDEM-$sanitizedGroup-$now-$rand';
  }

  // ==========================================
  // 1. SYNC-DOWN (PRE-CACHING FOR FIELD USE)
  // ==========================================

  /// Saves an already-fetched group collection sheet directly into local storage.
  Future<void> cacheLoadedGroupSheet(String groupName, Map<String, dynamic> sheet, {String? dateStr}) async {
    if (groupName.trim().isEmpty) return;
    await _db.cacheGroupSheet(groupName, sheet, dateStr: dateStr);
  }

  Future<bool> _tryPreCacheGroup(String groupName, [String? dateStr]) async {
    try {
      final sheet = await _api.getCollectionSheet(groupName: groupName, date: dateStr);
      await _db.cacheGroupSheet(groupName, sheet, dateStr: dateStr);
      return true;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Pre-caches a group collection sheet from the server to local storage.
  Future<void> preCacheGroupSheet(String groupName, [String? dateStr]) async {
    await _tryPreCacheGroup(groupName, dateStr);
  }

  /// Pre-caches single-client quick-entry options for offline use.
  Future<void> preCacheSingleClients() async {
    try {
      await _api.getSingleClientOptions();
    } catch (_) {
      // Non-critical background caching failure
    }
  }

  /// Pre-caches all available group collection sheets and single-client options in background.
  Future<void> preCacheAllAvailableGroups(
    List<String> groupNames,
    String dateStr, {
    String? skipGroup,
  }) async {
    await preCacheSingleClients();
    for (final rawName in groupNames) {
      final name = rawName.trim();
      if (name.isEmpty || name == 'Ungrouped' || name == skipGroup) continue;
      final keepGoing = await _tryPreCacheGroup(name, dateStr);
      if (!keepGoing) break;
    }
  }

  /// Retrieves group sheet from local cache (fallback when offline).
  Future<Map<String, dynamic>?> getOfflineSheet(String groupName, {String? dateStr}) async {
    return await _db.getCachedGroupSheet(groupName, dateStr: dateStr);
  }

  // ==========================================
  // 2. QUEUE LOCAL COLLECTION (OFFLINE OUTBOX)
  // ==========================================

  /// Enqueues a collection batch into the local outbox when offline or network fails.
  /// Generates an offline electronic receipt for the Credit Officer.
  Future<Map<String, dynamic>> queueOfflineBatch({
    required String groupName,
    required String collectionDate,
    required Map<String, dynamic> payload,
  }) async {
    // Preserve existing idempotency key if pre-assigned to prevent duplicate posting
    final existingKey = payload['idempotency_key']?.toString();
    final key = (existingKey != null && existingKey.isNotEmpty)
        ? existingKey
        : generateIdempotencyKey(groupName);
    
    // Inject idempotency key, batch ID, and explicit offline sync flag into payload
    final augmentedPayload = Map<String, dynamic>.from(payload);
    augmentedPayload['idempotency_key'] = key;
    augmentedPayload['batch_id'] = key;
    augmentedPayload['is_offline_sync'] = true;

    final rawCols = (payload['collections'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        <Map<String, dynamic>>[];
    final grpSav = (payload['group_savings_deposit'] as num?)?.toDouble() ?? 0.0;
    final optimisticMeta = await _db.applyOptimisticOfflineCollectionToCachedSheet(
      groupName: groupName,
      collections: rawCols,
      groupSavingsDeposit: grpSav,
      collectionDate: collectionDate,
    );

    final outboxId = await _db.queueBatchCollection(
      idempotencyKey: key,
      groupName: groupName,
      collectionDate: collectionDate,
      payload: augmentedPayload,
      optimisticMeta: optimisticMeta,
    );

    await _outboxNotifier.refresh();

    // Generate local offline receipt conforming to institutional standards
    final collections = (payload['collections'] as List<dynamic>? ?? []);
    double totalRepayments = 0.0;
    double totalSavings = grpSav;

    for (final c in collections) {
      if (c is Map<String, dynamic>) {
        totalRepayments += (c['loan_repayment_amount'] as num?)?.toDouble() ?? (c['repayment_amount'] as num?)?.toDouble() ?? 0.0;
        totalSavings += (c['savings_deposit_amount'] as num?)?.toDouble() ?? (c['personal_savings'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return {
      'offline_queued': true,
      'outbox_id': outboxId,
      'receipt': {
        'batch_id': 'OFFLINE-QUEUE-$outboxId',
        'idempotency_key': key,
        'group_name': groupName,
        'total_cash': totalRepayments + totalSavings,
        'total_repayment': totalRepayments,
        'total_repayments': totalRepayments,
        'total_savings': totalSavings,
        'total_submitted': collections.length,
        'timestamp': DateTime.now().toIso8601String(),
        'is_offline_queued': true,
        'offline_queued': true,
        'status': 'QUEUED_LOCAL',
        'watermark': 'OFFLINE RECORDING - PENDING SYNC',
      }
    };
  }

  /// Enqueues an ad-hoc single client collection into the local outbox when offline or network fails.
  /// Generates an offline electronic cashier receipt for the client.
  Future<Map<String, dynamic>> queueOfflineSingleCollection({
    required String clientName,
    required String collectionDate,
    required Map<String, dynamic> payload,
  }) async {
    // Preserve existing idempotency key if pre-assigned to prevent duplicate posting
    final existingKey = payload['idempotency_key']?.toString();
    final key = (existingKey != null && existingKey.isNotEmpty)
        ? existingKey
        : generateIdempotencyKey('SC_$clientName');

    // Inject idempotency key, batch ID, and explicit offline sync flag into payload
    final augmentedPayload = Map<String, dynamic>.from(payload);
    augmentedPayload['idempotency_key'] = key;
    augmentedPayload['batch_id'] = key;
    augmentedPayload['is_offline_sync'] = true;

    final grpName = payload['group_name']?.toString().trim() ?? '';
    final grpSavAmt = (payload['group_savings_deposit'] as num?)?.toDouble() ?? 0.0;
    final optimisticMeta = await _db.applyOptimisticOfflineCollectionToCachedSheet(
      groupName: grpName,
      collections: [Map<String, dynamic>.from(payload)],
      groupSavingsDeposit: grpSavAmt,
      collectionDate: collectionDate,
    );

    final outboxId = await _db.queueSingleCollection(
      idempotencyKey: key,
      clientName: clientName,
      collectionDate: collectionDate,
      payload: augmentedPayload,
      optimisticMeta: optimisticMeta,
    );

    await _outboxNotifier.refresh();

    final repAmt = (payload['loan_repayment'] as num?)?.toDouble() ?? 0.0;
    final savAmt = (payload['savings_deposit'] as num?)?.toDouble() ?? 0.0;
    final fees = ((payload['app_fee'] as num?)?.toDouble() ?? 0.0) +
                 ((payload['passbook_fee'] as num?)?.toDouble() ?? 0.0) +
                 ((payload['misc_fee'] as num?)?.toDouble() ?? 0.0);
    final totCash = repAmt + savAmt + grpSavAmt + fees;

    return {
      'success': true,
      'offline_queued': true,
      'outbox_id': outboxId,
      'receipt': {
        'batch_id': 'OFFLINE-QUEUE-$outboxId',
        'idempotency_key': key,
        'group_name': 'Single Client: $clientName',
        'total_cash': totCash,
        'total_repayment': repAmt,
        'total_savings': savAmt + grpSavAmt,
        'total_submitted': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'is_offline_queued': true,
        'offline_queued': true,
        'status': 'QUEUED_LOCAL',
        'watermark': 'OFFLINE RECORDING - PENDING SYNC',
        'officer': 'Field Credit Officer',
        'date': collectionDate,
      }
    };
  }

  // ==========================================
  // 3. SYNC-UP (FLUSH PENDING OUTBOX TO SERVER)
  // ==========================================

  /// Rolls back any un-reverted optimistic local cache changes, discards the outbox batch,
  /// and refreshes the pending counter.
  Future<void> discardOutboxBatch(int id) async {
    await _db.rollbackOptimisticOfflineCollection(id);
    await _db.deleteOutboxBatch(id);
    await _outboxNotifier.refresh();
  }

  /// Rolls back and clears all failed outbox batches and refreshes the pending counter.
  Future<int> clearAllFailedBatches() async {
    final pendingAndFailed = await _db.getPendingOutboxBatches();
    for (final item in pendingAndFailed) {
      if (item['status'] == 'failed') {
        final bId = item['id'];
        if (bId is int) {
          await _db.rollbackOptimisticOfflineCollection(bId);
        }
      }
    }
    final count = await _db.clearFailedOutboxBatches();
    await _outboxNotifier.refresh();
    return count;
  }

  /// Flushes all queued collection batches sequentially to the cloud backend.
  /// Ensures strict double-entry ledger atomicity via atomic_execute_operations.
  Future<SyncResult> syncOutbox() async {
    if (_isSyncing) {
      return SyncResult(success: false, message: 'Synchronization already in progress');
    }

    _isSyncing = true;
    int syncedCount = 0;
    int failedCount = 0;
    final List<String> errorMessages = [];
    final Set<String> touchedGroups = {};
    final Map<String, String?> touchedGroupDates = {};
    var touchedSingleClients = false;

    try {
      final pendingBatches = await _db.getPendingOutboxBatches();
      if (pendingBatches.isEmpty) {
        return SyncResult(success: true, message: 'All transactions are already synchronized', syncedCount: 0);
      }

      for (final item in pendingBatches) {
        final id = item['id'] as int;
        final payloadJson = item['payload_json'] as String;
        final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
        final opType = (item['operation_type'] as String?) ?? 'BATCH_COLLECTION';
        final targetGroup = (opType == 'SINGLE_COLLECTION'
                ? payload['group_name']
                : (payload['group_name'] ?? item['group_name']))
            ?.toString()
            .trim() ?? '';
        final targetDate = (item['collection_date'] ?? payload['date'])?.toString();

        try {
          String serverBatchId;
          if (opType == 'SINGLE_COLLECTION') {
            final res = await _api.submitSingleCollection(payload);
            final receipt = res['receipt'] as Map<String, dynamic>?;
            serverBatchId = receipt?['batch_id']?.toString() ?? res['batch_id']?.toString() ?? 'SYNCED-$id';
          } else {
            final res = await _api.submitBatchCollections(payload);
            final receipt = res['receipt'] as Map<String, dynamic>?;
            serverBatchId = receipt?['batch_id']?.toString() ?? res['batch_id']?.toString() ?? 'SYNCED-$id';
          }

          await _db.markOutboxBatchSynced(id, serverBatchId);
          await _db.clearOptimisticFlagOnSyncedBatch(id);
          if (opType == 'SINGLE_COLLECTION') {
            touchedSingleClients = true;
          }
          if (targetGroup.isNotEmpty && targetGroup != 'Ungrouped') {
            touchedGroups.add(targetGroup);
            touchedGroupDates[targetGroup] = targetDate;
          }
          syncedCount++;
        } catch (e) {
          failedCount++;
          String err;
          bool isTransient = true;
          if (e is DioException) {
            final statusCode = e.response?.statusCode;
            if (statusCode == 401) {
              err = 'Session expired. Please log in again to sync.';
              isTransient = true;
            } else if (e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.sendTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.connectionError) {
              err = 'Network connection failed (${e.type.name}).';
              isTransient = true;
            } else if (statusCode != null && statusCode >= 400 && statusCode < 500) {
              isTransient = false;
              if (e.response?.data is Map && (e.response!.data as Map).containsKey('detail')) {
                err = (e.response!.data as Map)['detail'].toString();
              } else {
                err = 'Rejected ($statusCode): ${e.message ?? 'Validation error'}';
              }
            } else if (e.response?.data is Map && (e.response!.data as Map).containsKey('detail')) {
              err = (e.response!.data as Map)['detail'].toString();
            } else {
              err = 'Server error (${statusCode ?? e.type.name}): ${e.message ?? 'Unknown'}';
            }
          } else {
            err = e.toString();
          }

          errorMessages.add('Batch #$id (${item['group_name']}): $err');
          await _db.markOutboxBatchFailed(id, err, isPermanent: !isTransient);
          if (!isTransient) {
            await _db.rollbackOptimisticOfflineCollection(id);
            if (opType == 'SINGLE_COLLECTION') {
              touchedSingleClients = true;
            }
            if (targetGroup.isNotEmpty && targetGroup != 'Ungrouped') {
              touchedGroups.add(targetGroup);
              touchedGroupDates[targetGroup] = targetDate;
            }
          }
          // Halt only on transient network, auth expiry, or 5xx outages; skip permanent 4xx poison items
          if (isTransient) {
            break;
          }
          continue;
        }
      }

      // Only refresh from server for scopes that have zero remaining pending/failed batches,
      // so still-pending optimistic offline state is never clobbered.
      final remainingActive = await _db.getPendingOutboxBatches();
      final remainingGroups = <String>{};
      var hasRemainingSingle = false;
      for (final rem in remainingActive) {
        try {
          final remPayload = jsonDecode(rem['payload_json'].toString()) as Map<String, dynamic>;
          final remOp = (rem['operation_type'] as String?) ?? 'BATCH_COLLECTION';
          if (remOp == 'SINGLE_COLLECTION') hasRemainingSingle = true;
          final remGrp = (remPayload['group_name'] ?? rem['group_name'])?.toString().trim() ?? '';
          if (remGrp.isNotEmpty && remGrp != 'Ungrouped') remainingGroups.add(remGrp);
        } catch (_) {}
      }
      if (touchedSingleClients && !hasRemainingSingle && remainingActive.isEmpty) {
        await preCacheSingleClients();
      }
      for (final grp in touchedGroups) {
        if (!remainingGroups.contains(grp)) {
          await _tryPreCacheGroup(grp, touchedGroupDates[grp]);
        }
      }

      await _outboxNotifier.refresh();

      if (failedCount > 0) {
        final summaryMsg = errorMessages.isNotEmpty
            ? errorMessages.first
            : 'Synced $syncedCount batches. $failedCount batch(es) failed.';
        return SyncResult(
          success: false,
          syncedCount: syncedCount,
          failedCount: failedCount,
          message: summaryMsg,
          errors: errorMessages,
        );
      }

      return SyncResult(
        success: true,
        syncedCount: syncedCount,
        failedCount: 0,
        message: 'Successfully synchronized $syncedCount batch(es) to the central ledger.',
      );
    } finally {
      _isSyncing = false;
      await _outboxNotifier.refresh();
    }
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;
  final List<String> errors;

  SyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.errors = const [],
  });
}
