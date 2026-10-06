import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/co/data/datasources/co_api_service.dart';
import 'offline_database_service.dart';

final pendingOutboxCountProvider = StateNotifierProvider<PendingOutboxNotifier, int>((ref) {
  final dbService = ref.watch(offlineDatabaseServiceProvider);
  return PendingOutboxNotifier(dbService);
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

  /// Pre-caches a group collection sheet from the server to local SQLite.
  Future<void> preCacheGroupSheet(String groupName, [String? dateStr]) async {
    try {
      final sheet = await _api.getCollectionSheet(groupName: groupName, date: dateStr);
      await _db.cacheGroupSheet(groupName, sheet);
    } catch (_) {
      // Non-critical background caching failure
    }
  }

  /// Retrieves group sheet from local cache (fallback when offline).
  Future<Map<String, dynamic>?> getOfflineSheet(String groupName) async {
    return await _db.getCachedGroupSheet(groupName);
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
    final key = generateIdempotencyKey(groupName);
    
    // Inject idempotency key and batch ID into payload
    final augmentedPayload = Map<String, dynamic>.from(payload);
    augmentedPayload['idempotency_key'] = key;
    augmentedPayload['batch_id'] = key;

    final outboxId = await _db.queueBatchCollection(
      idempotencyKey: key,
      groupName: groupName,
      collectionDate: collectionDate,
      payload: augmentedPayload,
    );

    await _outboxNotifier.refresh();

    // Generate local offline receipt conforming to institutional standards
    final collections = (payload['collections'] as List<dynamic>? ?? []);
    double totalRepayments = 0.0;
    double totalSavings = (payload['group_savings_deposit'] as num?)?.toDouble() ?? 0.0;

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
        'total_repayments': totalRepayments,
        'total_savings': totalSavings,
        'total_submitted': collections.length,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'QUEUED_LOCAL',
        'watermark': 'OFFLINE RECORDING - PENDING SYNC',
      }
    };
  }

  // ==========================================
  // 3. SYNC-UP (FLUSH PENDING OUTBOX TO SERVER)
  // ==========================================

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

    try {
      final pendingBatches = await _db.getPendingOutboxBatches();
      if (pendingBatches.isEmpty) {
        return SyncResult(success: true, message: 'All transactions are already synchronized', syncedCount: 0);
      }

      for (final item in pendingBatches) {
        final id = item['id'] as int;
        final payloadJson = item['payload_json'] as String;
        final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

        try {
          // Post to authoritative backend with deterministic idempotency_key
          final res = await _api.submitBatchCollections(payload);
          final receipt = res['receipt'] as Map<String, dynamic>?;
          final serverBatchId = receipt?['batch_id']?.toString() ?? res['batch_id']?.toString() ?? 'SYNCED-$id';
          
          await _db.markOutboxBatchSynced(id, serverBatchId);
          syncedCount++;
        } catch (e) {
          failedCount++;
          String err;
          if (e is DioException) {
            if (e.response?.statusCode == 401) {
              err = 'Session expired. Please log in again to sync.';
            } else if (e.response?.data is Map && (e.response!.data as Map).containsKey('detail')) {
              err = (e.response!.data as Map)['detail'].toString();
            } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
              err = 'Server connection timed out. Please retry.';
            } else if (e.type == DioExceptionType.connectionError) {
              err = 'Network connection failed (${e.type.name}).';
            } else {
              err = 'Server error (${e.response?.statusCode ?? e.type.name}): ${e.message ?? 'Unknown'}';
            }
          } else {
            err = e.toString();
          }

          errorMessages.add('Batch #$id (${item['group_name']}): $err');
          await _db.markOutboxBatchFailed(id, err);
          // If connection dropped or server error, stop attempting subsequent batches
          break;
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
