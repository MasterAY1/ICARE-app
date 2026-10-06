import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

final offlineDatabaseServiceProvider = Provider<OfflineDatabaseService>((ref) {
  return OfflineDatabaseService();
});

/// Authoritative Local SQLite & Persistent Storage Database Service for ICARE Core Banking.
/// Enables offline field collections, roster pre-caching, dashboard caching, and resilient outbox queuing.
/// Includes web-safe and test-safe fallback using SharedPreferences to guarantee persistence across browser refreshes and device restarts.
class OfflineDatabaseService {
  static Database? _database;
  bool useMemoryStore;

  OfflineDatabaseService({this.useMemoryStore = false});

  // Web / Test in-memory fallback stores
  int _webIdCounter = 1;
  final Map<String, Map<String, dynamic>> _webGroupsCache = {};
  final Map<String, Map<String, dynamic>> _webClientsCache = {};
  final Map<String, String> _webDashboardCache = {};
  final Map<String, dynamic> _webApiCache = {};
  final List<Map<String, dynamic>> _webOutbox = [];

  Future<Database> get database async {
    if (kIsWeb || useMemoryStore) {
      throw UnsupportedError('Native database not active (in-memory mode enabled).');
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'icare_offline.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        // 1. Group & schedule cache
        await db.execute('''
          CREATE TABLE offline_groups_cache (
            group_name TEXT PRIMARY KEY,
            meeting_day TEXT,
            data_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        // 2. Client roster cache for quick search & validation
        await db.execute('''
          CREATE TABLE offline_clients_cache (
            client_id TEXT PRIMARY KEY,
            client_code TEXT,
            client_name TEXT,
            group_name TEXT,
            loan_id TEXT,
            expected_installment REAL,
            loan_balance REAL,
            savings_balance REAL,
            data_json TEXT NOT NULL
          )
        ''');

        // 3. Outbox queue for offline transactions awaiting server synchronization
        await db.execute('''
          CREATE TABLE offline_outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            idempotency_key TEXT UNIQUE NOT NULL,
            operation_type TEXT NOT NULL,
            group_name TEXT,
            collection_date TEXT,
            payload_json TEXT NOT NULL,
            status TEXT NOT NULL,
            retry_count INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            synced_at TEXT,
            error_message TEXT
          )
        ''');

        // 4. Dashboard cache
        await db.execute('''
          CREATE TABLE offline_dashboard_cache (
            id TEXT PRIMARY KEY,
            data_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS offline_dashboard_cache (
              id TEXT PRIMARY KEY,
              data_json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  // ==========================================
  // 0. DASHBOARD CACHE (OFFLINE FALLBACK)
  // ==========================================

  /// Caches dashboard JSON payload locally (persisted across restarts & reloads)
  Future<void> cacheDashboardData(Map<String, dynamic> data, {String role = 'co'}) async {
    final nowIso = DateTime.now().toIso8601String();
    final jsonStr = jsonEncode(data);

    _webDashboardCache[role] = jsonStr;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_dashboard_$role', jsonStr);
      await prefs.setString('offline_dashboard_timestamp_$role', nowIso);
    } catch (_) {}

    if (!kIsWeb && !useMemoryStore) {
      try {
        final db = await database;
        await db.insert(
          'offline_dashboard_cache',
          {
            'id': role,
            'data_json': jsonStr,
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}
    }
  }

  /// Retrieves cached dashboard JSON payload if present
  Future<Map<String, dynamic>?> getCachedDashboardData({String role = 'co'}) async {
    if (_webDashboardCache.containsKey(role)) {
      final str = _webDashboardCache[role]!;
      return jsonDecode(str) as Map<String, dynamic>;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('offline_dashboard_$role');
      if (str != null && str.isNotEmpty) {
        _webDashboardCache[role] = str;
        return jsonDecode(str) as Map<String, dynamic>;
      }
    } catch (_) {}

    if (!kIsWeb && !useMemoryStore) {
      try {
        final db = await database;
        final res = await db.query(
          'offline_dashboard_cache',
          where: 'id = ?',
          whereArgs: [role],
          limit: 1,
        );
        if (res.isNotEmpty) {
          final jsonStr = res.first['data_json'] as String;
          _webDashboardCache[role] = jsonStr;
          return jsonDecode(jsonStr) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    return null;
  }

  // ==========================================
  // 0.1 GENERIC GET API RESPONSE CACHE
  // ==========================================

  /// Caches an API GET response locally in memory and persistent storage
  Future<void> cacheApiResponse(String cacheKey, dynamic data) async {
    _webApiCache[cacheKey] = data;

    try {
      final jsonStr = jsonEncode(data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_api_$cacheKey', jsonStr);

      final keys = prefs.getStringList('offline_api_cache_keys') ?? [];
      if (!keys.contains(cacheKey)) {
        keys.add(cacheKey);
        await prefs.setStringList('offline_api_cache_keys', keys);
      }
    } catch (e) {
      debugPrint('Failed to persist API cache for $cacheKey: $e');
    }
  }

  /// Retrieves cached GET API response if available
  Future<dynamic> getCachedApiResponse(String cacheKey) async {
    if (_webApiCache.containsKey(cacheKey)) {
      return _webApiCache[cacheKey];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('offline_api_$cacheKey');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        _webApiCache[cacheKey] = decoded;
        return decoded;
      }
    } catch (e) {
      debugPrint('Failed to read API cache for $cacheKey: $e');
    }

    return null;
  }

  // ==========================================
  // 1. CACHE MANAGEMENT (SYNC-DOWN)
  // ==========================================

  /// Caches a group collection sheet locally for offline access in the field.
  Future<void> cacheGroupSheet(String groupName, Map<String, dynamic> sheetData) async {
    final nowIso = DateTime.now().toIso8601String();
    final jsonStr = jsonEncode(sheetData);

    // Persist to SharedPreferences across web and native
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_sheet_$groupName', jsonStr);
      final groups = prefs.getStringList('offline_cached_groups') ?? [];
      if (!groups.contains(groupName)) {
        groups.add(groupName);
        await prefs.setStringList('offline_cached_groups', groups);
      }
    } catch (_) {}

    // Support both 'members' (authoritative FastAPI response) and 'clients'
    final rawClients = sheetData['members'] as List<dynamic>? ?? sheetData['clients'] as List<dynamic>? ?? [];

    if (kIsWeb || useMemoryStore) {
      _webGroupsCache[groupName] = {
        'group_name': groupName,
        'meeting_day': sheetData['meeting_day'] ?? '',
        'data_json': jsonStr,
        'updated_at': nowIso,
      };

      for (final c in rawClients) {
        if (c is Map<String, dynamic>) {
          final cid = c['client_id']?.toString() ?? c['id']?.toString() ?? '';
          if (cid.isNotEmpty) {
            _webClientsCache[cid] = {
              'client_id': cid,
              'client_code': c['client_code']?.toString() ?? '',
              'client_name': c['client_name']?.toString() ?? '',
              'group_name': groupName,
              'loan_id': c['loan_id']?.toString() ?? '',
              'expected_installment': (c['expected_installment'] as num?)?.toDouble() ?? (c['expected_repayment'] as num?)?.toDouble() ?? 0.0,
              'loan_balance': (c['loan_balance'] as num?)?.toDouble() ?? (c['remaining_balance'] as num?)?.toDouble() ?? 0.0,
              'savings_balance': (c['savings_balance'] as num?)?.toDouble() ?? 0.0,
              'data_json': jsonEncode(c),
            };
          }
        }
      }
      return;
    }

    try {
      final db = await database;
      await db.insert(
        'offline_groups_cache',
        {
          'group_name': groupName,
          'meeting_day': sheetData['meeting_day'] ?? '',
          'data_json': jsonStr,
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final batch = db.batch();
      for (final c in rawClients) {
        if (c is Map<String, dynamic>) {
          final cid = c['client_id']?.toString() ?? c['id']?.toString() ?? '';
          if (cid.isNotEmpty) {
            batch.insert(
              'offline_clients_cache',
              {
                'client_id': cid,
                'client_code': c['client_code']?.toString() ?? '',
                'client_name': c['client_name']?.toString() ?? '',
                'group_name': groupName,
                'loan_id': c['loan_id']?.toString() ?? '',
                'expected_installment': (c['expected_installment'] as num?)?.toDouble() ?? (c['expected_repayment'] as num?)?.toDouble() ?? 0.0,
                'loan_balance': (c['loan_balance'] as num?)?.toDouble() ?? (c['remaining_balance'] as num?)?.toDouble() ?? 0.0,
                'savings_balance': (c['savings_balance'] as num?)?.toDouble() ?? 0.0,
                'data_json': jsonEncode(c),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
      await batch.commit(noResult: true);
    } catch (_) {
      useMemoryStore = true;
      return cacheGroupSheet(groupName, sheetData);
    }
  }

  /// Retrieves a cached group collection sheet.
  Future<Map<String, dynamic>?> getCachedGroupSheet(String groupName) async {
    final entry = _webGroupsCache[groupName];
    if (entry != null) {
      final jsonStr = entry['data_json'] as String;
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('offline_sheet_$groupName');
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as Map<String, dynamic>;
      }
    } catch (_) {}

    if (!kIsWeb && !useMemoryStore) {
      try {
        final db = await database;
        final res = await db.query(
          'offline_groups_cache',
          where: 'group_name = ?',
          whereArgs: [groupName],
          limit: 1,
        );
        if (res.isNotEmpty) {
          final jsonStr = res.first['data_json'] as String;
          return jsonDecode(jsonStr) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    return null;
  }

  /// Retrieves all cached group names.
  Future<List<String>> getCachedGroupNames() async {
    final names = <String>{};
    names.addAll(_webGroupsCache.keys);

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('offline_cached_groups') ?? [];
      names.addAll(list);
    } catch (_) {}

    if (!kIsWeb && !useMemoryStore) {
      try {
        final db = await database;
        final res = await db.query('offline_groups_cache', columns: ['group_name'], orderBy: 'group_name ASC');
        for (final r in res) {
          final gn = r['group_name'] as String?;
          if (gn != null) names.add(gn);
        }
      } catch (_) {}
    }

    final sorted = names.toList()..sort();
    return sorted;
  }

  // ==========================================
  // 2. OUTBOX MANAGEMENT (SYNC-UP)
  // ==========================================

  /// Queues a collection batch into the local outbox when offline.
  Future<int> queueBatchCollection({
    required String idempotencyKey,
    required String groupName,
    required String collectionDate,
    required Map<String, dynamic> payload,
  }) async {
    final nowIso = DateTime.now().toIso8601String();

    // Persist to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawOutboxStr = prefs.getString('offline_persisted_outbox');
      final list = rawOutboxStr != null
          ? (jsonDecode(rawOutboxStr) as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];
      list.add({
        'id': idempotencyKey.hashCode.abs(),
        'idempotency_key': idempotencyKey,
        'operation_type': 'BATCH_COLLECTION',
        'group_name': groupName,
        'collection_date': collectionDate,
        'payload_json': jsonEncode(payload),
        'status': 'pending',
        'retry_count': 0,
        'created_at': nowIso,
        'synced_at': null,
        'error_message': null,
      });
      await prefs.setString('offline_persisted_outbox', jsonEncode(list));
    } catch (_) {}

    if (kIsWeb || useMemoryStore) {
      final id = _webIdCounter++;
      _webOutbox.add({
        'id': id,
        'idempotency_key': idempotencyKey,
        'operation_type': 'BATCH_COLLECTION',
        'group_name': groupName,
        'collection_date': collectionDate,
        'payload_json': jsonEncode(payload),
        'status': 'pending',
        'retry_count': 0,
        'created_at': nowIso,
        'synced_at': null,
        'error_message': null,
      });
      return id;
    }

    try {
      final db = await database;
      return await db.insert(
        'offline_outbox',
        {
          'idempotency_key': idempotencyKey,
          'operation_type': 'BATCH_COLLECTION',
          'group_name': groupName,
          'collection_date': collectionDate,
          'payload_json': jsonEncode(payload),
          'status': 'pending',
          'retry_count': 0,
          'created_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      useMemoryStore = true;
      return queueBatchCollection(
        idempotencyKey: idempotencyKey,
        groupName: groupName,
        collectionDate: collectionDate,
        payload: payload,
      );
    }
  }

  /// Retrieves all pending outbox batches ready for synchronization.
  Future<List<Map<String, dynamic>>> getPendingOutboxBatches() async {
    if (kIsWeb || useMemoryStore) {
      if (_webOutbox.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final raw = prefs.getString('offline_persisted_outbox');
          if (raw != null) {
            final list = (jsonDecode(raw) as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _webOutbox.addAll(list);
          }
        } catch (_) {}
      }
      return _webOutbox
          .where((item) => item['status'] == 'pending' || item['status'] == 'failed')
          .toList();
    }

    try {
      final db = await database;
      return await db.query(
        'offline_outbox',
        where: "status = 'pending' OR status = 'failed'",
        orderBy: 'id ASC',
      );
    } catch (_) {
      useMemoryStore = true;
      return getPendingOutboxBatches();
    }
  }

  /// Retrieves count of pending transactions awaiting upload.
  Future<int> getPendingOutboxCount() async {
    if (kIsWeb || useMemoryStore) {
      if (_webOutbox.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final raw = prefs.getString('offline_persisted_outbox');
          if (raw != null) {
            final list = (jsonDecode(raw) as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _webOutbox.addAll(list);
          }
        } catch (_) {}
      }
      return _webOutbox
          .where((item) => item['status'] == 'pending' || item['status'] == 'failed')
          .length;
    }

    try {
      final db = await database;
      final res = await db.rawQuery("SELECT COUNT(*) as count FROM offline_outbox WHERE status = 'pending' OR status = 'failed'");
      if (res.isNotEmpty) {
        return (res.first['count'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (_) {
      useMemoryStore = true;
      return getPendingOutboxCount();
    }
  }

  /// Marks a queued batch as successfully synced to the central server.
  Future<void> markOutboxBatchSynced(int id, String serverBatchId) async {
    final nowIso = DateTime.now().toIso8601String();

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('offline_persisted_outbox');
      if (raw != null) {
        final list = (jsonDecode(raw) as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        for (final item in list) {
          if (item['id'] == id) {
            item['status'] = 'synced';
            item['synced_at'] = nowIso;
            item['error_message'] = null;
          }
        }
        await prefs.setString('offline_persisted_outbox', jsonEncode(list));
      }
    } catch (_) {}

    if (kIsWeb || useMemoryStore) {
      final idx = _webOutbox.indexWhere((item) => item['id'] == id);
      if (idx != -1) {
        _webOutbox[idx]['status'] = 'synced';
        _webOutbox[idx]['synced_at'] = nowIso;
        _webOutbox[idx]['error_message'] = null;
      }
      return;
    }

    try {
      final db = await database;
      await db.update(
        'offline_outbox',
        {
          'status': 'synced',
          'synced_at': nowIso,
          'error_message': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (_) {
      useMemoryStore = true;
      return markOutboxBatchSynced(id, serverBatchId);
    }
  }

  /// Marks a queued batch as failed with error details for retry.
  Future<void> markOutboxBatchFailed(int id, String errorMessage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('offline_persisted_outbox');
      if (raw != null) {
        final list = (jsonDecode(raw) as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        for (final item in list) {
          if (item['id'] == id) {
            item['status'] = 'failed';
            item['retry_count'] = ((item['retry_count'] as int?) ?? 0) + 1;
            item['error_message'] = errorMessage;
          }
        }
        await prefs.setString('offline_persisted_outbox', jsonEncode(list));
      }
    } catch (_) {}

    if (kIsWeb || useMemoryStore) {
      final idx = _webOutbox.indexWhere((item) => item['id'] == id);
      if (idx != -1) {
        _webOutbox[idx]['status'] = 'failed';
        _webOutbox[idx]['retry_count'] = ((_webOutbox[idx]['retry_count'] as int?) ?? 0) + 1;
        _webOutbox[idx]['error_message'] = errorMessage;
      }
      return;
    }

    try {
      final db = await database;
      await db.rawUpdate('''
        UPDATE offline_outbox 
        SET status = 'failed', 
            retry_count = retry_count + 1, 
            error_message = ? 
        WHERE id = ?
      ''', [errorMessage, id]);
    } catch (_) {
      useMemoryStore = true;
      return markOutboxBatchFailed(id, errorMessage);
    }
  }

  /// Retrieves recent synced outbox items for audit history.
  Future<List<Map<String, dynamic>>> getRecentSyncedBatches({int limit = 20}) async {
    if (kIsWeb || useMemoryStore) {
      final synced = _webOutbox.where((item) => item['status'] == 'synced').toList();
      return synced.reversed.take(limit).toList();
    }

    try {
      final db = await database;
      return await db.query(
        'offline_outbox',
        where: "status = 'synced'",
        orderBy: 'synced_at DESC',
        limit: limit,
      );
    } catch (_) {
      useMemoryStore = true;
      return getRecentSyncedBatches(limit: limit);
    }
  }
}
