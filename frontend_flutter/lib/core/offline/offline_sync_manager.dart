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

final quarantinedOutboxCountProvider = StateNotifierProvider<QuarantinedOutboxNotifier, int>((ref) {
  final dbService = ref.watch(offlineDatabaseServiceProvider);
  final notifier = QuarantinedOutboxNotifier(dbService);
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

class QuarantinedOutboxNotifier extends StateNotifier<int> {
  final OfflineDatabaseService _db;
  QuarantinedOutboxNotifier(this._db) : super(0) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final count = await _db.getQuarantinedOutboxCount();
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
  final quarantinedNotifier = ref.watch(quarantinedOutboxCountProvider.notifier);
  return OfflineSyncManager(
    dbService,
    coApi,
    notifier,
    quarantinedNotifier: quarantinedNotifier,
  );
});

/// High-level manager orchestrating synchronization between local SQLite storage
/// and the central Supabase Financial Ledger via the FastAPI backend.
class OfflineSyncManager {
  final OfflineDatabaseService _db;
  final CoApiService _api;
  final PendingOutboxNotifier _outboxNotifier;
  final QuarantinedOutboxNotifier? _quarantinedNotifier;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  OfflineSyncManager(
    this._db,
    this._api,
    this._outboxNotifier, {
    QuarantinedOutboxNotifier? quarantinedNotifier,
  }) : _quarantinedNotifier = quarantinedNotifier;

  Future<void> _refreshCounters() async {
    await _outboxNotifier.refresh();
    await _quarantinedNotifier?.refresh();
  }

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

  /// Pre-caches all available group collection sheets, single-client options, and daily collections history in background.
  Future<void> preCacheAllAvailableGroups(
    List<String> groupNames,
    String dateStr, {
    String? skipGroup,
  }) async {
    await preCacheSingleClients();
    try {
      await _api.getCollectionsHistory(date: dateStr);
    } catch (_) {
      // Non-critical background cache warm-up
    }
    for (final rawName in groupNames) {
      final name = rawName.trim();
      if (name.isEmpty || name == 'Ungrouped' || name == skipGroup) continue;
      final keepGoing = await _tryPreCacheGroup(name, dateStr);
      if (!keepGoing) break;
    }
  }

  /// Pre-caches withdrawal read snapshots and branch business date so Withdrawal Operations works read-only offline.
  Future<void> preCacheWithdrawalWorkspace({String? dateStr}) async {
    Future<void> safeCall(Future<dynamic> Function() fn) async {
      try {
        await fn();
      } catch (_) {
        // Non-critical background cache warm-up
      }
    }

    String? effectiveDate = dateStr?.trim();
    if (effectiveDate == null || effectiveDate.isEmpty) {
      try {
        final biz = await _api.getOriginationBusinessDate();
        final raw = biz['business_date']?.toString().trim();
        if (raw != null && raw.length >= 10) {
          effectiveDate = raw.substring(0, 10);
        }
      } catch (_) {}
    } else {
      await safeCall(_api.getOriginationBusinessDate);
    }

    await Future.wait([
      safeCall(_api.getIndividualWithdrawalOptions),
      safeCall(_api.getGroupWithdrawalOptions),
      safeCall(_api.getLapsWithdrawalOptions),
      safeCall(_api.getMiscWithdrawalBalance),
      safeCall(_api.getWithdrawalRequests),
      if (effectiveDate != null && effectiveDate.isNotEmpty)
        safeCall(() => _api.getDailyWithdrawals(
              date: effectiveDate,
              showAll: false,
              category: 'All Types',
              search: '',
            )),
    ]);
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

    await _refreshCounters();

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

    await _refreshCounters();

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

  /// Queues a Credit Officer withdrawal request (`auto_execute: false`) for online review & BM 4-Eyes approval.
  /// Enforces Option B governance: never queues direct manager executions or cash payouts offline.
  Future<Map<String, dynamic>> queueOfflineWithdrawalRequest({
    required String displayLabel,
    required String operationalDate,
    required Map<String, dynamic> payload,
  }) async {
    final existingKey = payload['idempotency_key']?.toString();
    final key = (existingKey != null && existingKey.isNotEmpty)
        ? existingKey
        : generateIdempotencyKey('WR_$displayLabel');

    final augmentedPayload = Map<String, dynamic>.from(payload);
    augmentedPayload['idempotency_key'] = key;
    augmentedPayload['auto_execute'] = false;

    final optimisticMeta = await _db.applyOptimisticWithdrawalReservation(augmentedPayload);
    final outboxId = await _db.queueWithdrawalRequest(
      idempotencyKey: key,
      displayLabel: displayLabel,
      operationalDate: operationalDate,
      payload: augmentedPayload,
      optimisticMeta: optimisticMeta,
    );

    await _refreshCounters();

    return {
      'success': true,
      'offline_queued': true,
      'outbox_id': outboxId,
      'idempotency_key': key,
      'status': 'QUEUED_LOCAL',
      'message':
          'Withdrawal request queued offline for Manager approval. Do not disburse cash until synced and approved.',
    };
  }

  // ==========================================
  // 3. SYNC-UP (FLUSH PENDING OUTBOX TO SERVER)
  // ==========================================

  /// Rolls back any un-reverted optimistic local cache changes, discards the outbox batch,
  /// and refreshes the outbox counters.
  Future<void> discardOutboxBatch(int id) async {
    await _db.rollbackOptimisticOfflineCollection(id);
    await _db.deleteOutboxBatch(id);
    await _refreshCounters();
  }

  /// Re-queues a quarantined batch for manual retry, preserving its idempotency key.
  /// If currently online, triggers immediate outbox synchronization.
  Future<SyncResult?> retryQuarantinedBatch(int id, {bool syncNow = true}) async {
    final requeued = await _db.requeueOutboxBatch(id);
    await _refreshCounters();
    if (!requeued || !syncNow) return null;
    return await syncOutbox();
  }

  /// Rolls back and clears all failed outbox batches and refreshes the outbox counters.
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
    await _refreshCounters();
    return count;
  }

  /// Rolls back (idempotently) and clears all quarantined outbox batches from the device.
  Future<int> clearAllQuarantinedBatches() async {
    final quarantined = await _db.getQuarantinedOutboxBatches();
    for (final item in quarantined) {
      final bId = item['id'];
      if (bId is int) {
        await _db.rollbackOptimisticOfflineCollection(bId);
      }
    }
    final count = await _db.clearQuarantinedOutboxBatches();
    await _refreshCounters();
    return count;
  }

  static bool _looksLikeDioBoilerplate(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('dioexception') ||
        lower.contains('requestoptions') ||
        lower.contains('status code of') ||
        lower.contains('developer.mozilla.org') ||
        lower.contains('validatestatus');
  }

  static Map<String, dynamic>? _parseErrorMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  static ({String message, bool isTransient}) _extractSyncError(dynamic error) {
    if (error is! DioException) {
      return (message: error.toString(), isTransient: true);
    }

    final statusCode = error.response?.statusCode;
    final dataMap = _parseErrorMap(error.response?.data);
    final errorCode = dataMap?['error_code']?.toString().trim() ?? '';
    final detailStr = dataMap?['detail']?.toString().trim();
    final msgStr = dataMap?['message']?.toString().trim();
    final titleStr = dataMap?['title']?.toString().trim();
    final serverText = (detailStr != null && detailStr.isNotEmpty)
        ? detailStr
        : ((msgStr != null && msgStr.isNotEmpty)
            ? msgStr
            : ((titleStr != null && titleStr.isNotEmpty) ? titleStr : null));

    if (statusCode == 401) {
      return (message: 'Session expired. Please sign in again to sync.', isTransient: true);
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return (message: 'Network connection failed (${error.type.name}).', isTransient: true);
    }

    final isTransientError = errorCode == 'DB_NETWORK_TIMEOUT' ||
        statusCode == 408 ||
        statusCode == 429 ||
        statusCode == null ||
        statusCode >= 500;

    if (serverText != null && !_looksLikeDioBoilerplate(serverText)) {
      return (message: serverText, isTransient: isTransientError);
    }

    final rawMsg = error.message?.trim();
    if (rawMsg != null && rawMsg.isNotEmpty && !_looksLikeDioBoilerplate(rawMsg)) {
      return (
        message: isTransientError ? 'Server error ($statusCode): $rawMsg' : 'Rejected ($statusCode): $rawMsg',
        isTransient: isTransientError,
      );
    }

    if (isTransientError) {
      return (
        message: 'Temporary server delay (${statusCode ?? error.type.name}). Your transaction remains safely queued.',
        isTransient: true,
      );
    }
    return (
      message: 'Rejected ($statusCode): Validation failed on the server.',
      isTransient: false,
    );
  }

  /// Flushes all queued collection & withdrawal request batches sequentially to the cloud backend.
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
    var touchedWithdrawals = false;

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
          if (opType == 'WITHDRAWAL_REQUEST') {
            final safePayload = Map<String, dynamic>.from(payload)..['auto_execute'] = false;
            final res = await _api.submitWithdrawalRequest(safePayload);
            serverBatchId = res['reference']?.toString() ?? res['request_id']?.toString() ?? 'SYNCED-$id';
          } else if (opType == 'SINGLE_COLLECTION') {
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
          if (opType == 'WITHDRAWAL_REQUEST') {
            touchedWithdrawals = true;
          } else {
            if (opType == 'SINGLE_COLLECTION') {
              touchedSingleClients = true;
            }
            if (targetGroup.isNotEmpty && targetGroup != 'Ungrouped') {
              touchedGroups.add(targetGroup);
              touchedGroupDates[targetGroup] = targetDate;
            }
          }
          syncedCount++;
        } catch (e) {
          failedCount++;
          final extracted = _extractSyncError(e);
          final err = extracted.message;
          final isTransient = extracted.isTransient;

          errorMessages.add('Batch #$id (${item['group_name']}): $err');
          await _db.markOutboxBatchFailed(id, err, isPermanent: !isTransient);
          if (!isTransient) {
            await _db.rollbackOptimisticOfflineCollection(id);
            if (opType == 'WITHDRAWAL_REQUEST') {
              touchedWithdrawals = true;
            } else {
              if (opType == 'SINGLE_COLLECTION') {
                touchedSingleClients = true;
              }
              if (targetGroup.isNotEmpty && targetGroup != 'Ungrouped') {
                touchedGroups.add(targetGroup);
                touchedGroupDates[targetGroup] = targetDate;
              }
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
      var hasRemainingWithdrawals = false;
      for (final rem in remainingActive) {
        try {
          final remPayload = jsonDecode(rem['payload_json'].toString()) as Map<String, dynamic>;
          final remOp = (rem['operation_type'] as String?) ?? 'BATCH_COLLECTION';
          if (remOp == 'SINGLE_COLLECTION') hasRemainingSingle = true;
          if (remOp == 'WITHDRAWAL_REQUEST') hasRemainingWithdrawals = true;
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
      if (touchedWithdrawals && !hasRemainingWithdrawals) {
        await preCacheWithdrawalWorkspace();
      }

      await _refreshCounters();

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
      await _refreshCounters();
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
