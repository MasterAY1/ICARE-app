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

  String _scopeUserId = 'anon';
  String _scopeBranchId = 'default';

  OfflineDatabaseService({
    this.useMemoryStore = false,
    String userId = 'anon',
    String branchId = 'default',
  })  : _scopeUserId = userId.trim().isEmpty ? 'anon' : userId.trim(),
        _scopeBranchId = branchId.trim().isEmpty ? 'default' : branchId.trim();

  String get activeUserId => _scopeUserId;
  String get activeBranchId => _scopeBranchId;
  String get activeScopeKey => '${_sanitizeScope(_scopeUserId)}::${_sanitizeScope(_scopeBranchId)}';

  static String _sanitizeScope(String? val) {
    final clean = (val ?? '').trim();
    return clean.isEmpty ? 'default' : clean.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  /// Binds all offline caches and outbox storage to the authenticated user & branch.
  /// Clears volatile in-memory caches whenever the identity or branch context changes.
  void setSessionScope({required String userId, required String branchId}) {
    final nextUser = userId.trim().isEmpty ? 'anon' : userId.trim();
    final nextBranch = branchId.trim().isEmpty ? 'default' : branchId.trim();
    if (_scopeUserId != nextUser || _scopeBranchId != nextBranch) {
      _webDashboardCache.clear();
      _webApiCache.clear();
      _webGroupsCache.clear();
      _webClientsCache.clear();
      _webOutbox.clear();
    }
    _scopeUserId = nextUser;
    _scopeBranchId = nextBranch;
  }

  /// Wipes all user/branch-scoped offline caches and queued storage on logout,
  /// sweeps any legacy unscoped keys, and resets scope to anonymous defaults.
  Future<void> clearSessionStorage({bool clearOutbox = true}) async {
    final currentScope = activeScopeKey;
    _webDashboardCache.clear();
    _webApiCache.clear();
    _webGroupsCache.clear();
    _webClientsCache.clear();
    if (clearOutbox) {
      _webOutbox.clear();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final dashKeys = prefs.getStringList('offline_dashboard_keys_$currentScope') ?? [];
      for (final k in dashKeys) {
        await prefs.remove('offline_dashboard_${currentScope}_$k');
        await prefs.remove('offline_dashboard_timestamp_${currentScope}_$k');
      }
      await prefs.remove('offline_dashboard_keys_$currentScope');

      final apiKeys = prefs.getStringList('offline_api_cache_keys_$currentScope') ?? [];
      for (final k in apiKeys) {
        await prefs.remove('offline_api_${currentScope}_$k');
      }
      await prefs.remove('offline_api_cache_keys_$currentScope');

      final grpKeys = prefs.getStringList('offline_cached_group_keys_$currentScope') ?? [];
      for (final k in grpKeys) {
        await prefs.remove('offline_sheet_${currentScope}_$k');
      }
      await prefs.remove('offline_cached_group_keys_$currentScope');
      await prefs.remove('offline_cached_groups_$currentScope');

      if (clearOutbox) {
        await prefs.remove('offline_persisted_outbox_$currentScope');
      }

      // Sweep legacy unscoped pre-isolation keys
      for (final legacyRole in ['co', 'bm', 'am', 'admin', 'director']) {
        await prefs.remove('offline_dashboard_$legacyRole');
        await prefs.remove('offline_dashboard_timestamp_$legacyRole');
      }
      final legacyApiKeys = prefs.getStringList('offline_api_cache_keys') ?? [];
      for (final k in legacyApiKeys) {
        await prefs.remove('offline_api_$k');
      }
      await prefs.remove('offline_api_cache_keys');
      final legacyGroups = prefs.getStringList('offline_cached_groups') ?? [];
      for (final g in legacyGroups) {
        await prefs.remove('offline_sheet_$g');
      }
      await prefs.remove('offline_cached_groups');
      await prefs.remove('offline_persisted_outbox');
    } catch (_) {}

    if (!kIsWeb && !useMemoryStore) {
      try {
        final db = await database;
        await db.delete('offline_groups_cache', where: 'scope_key = ? OR scope_key = ?', whereArgs: [currentScope, '']);
        await db.delete('offline_clients_cache', where: 'scope_key = ? OR scope_key = ?', whereArgs: [currentScope, '']);
        await db.delete('offline_dashboard_cache', where: 'scope_key = ? OR scope_key = ?', whereArgs: [currentScope, '']);
        if (clearOutbox) {
          await db.delete('offline_outbox', where: 'scope_key = ?', whereArgs: [currentScope]);
        }
      } catch (_) {}
    }

    _scopeUserId = 'anon';
    _scopeBranchId = 'default';
  }

  // Web / Test in-memory fallback stores (keyed by scopeKey)
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
      version: 3,
      onCreate: (db, version) async {
        // 1. Group & schedule cache (user/branch isolated)
        await db.execute('''
          CREATE TABLE offline_groups_cache (
            group_name TEXT PRIMARY KEY,
            scope_key TEXT NOT NULL DEFAULT '',
            user_id TEXT NOT NULL DEFAULT '',
            branch_id TEXT NOT NULL DEFAULT '',
            meeting_day TEXT,
            data_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        // 2. Client roster cache for quick search & validation (user/branch isolated)
        await db.execute('''
          CREATE TABLE offline_clients_cache (
            client_id TEXT PRIMARY KEY,
            scope_key TEXT NOT NULL DEFAULT '',
            user_id TEXT NOT NULL DEFAULT '',
            branch_id TEXT NOT NULL DEFAULT '',
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
            scope_key TEXT NOT NULL DEFAULT '',
            user_id TEXT NOT NULL DEFAULT '',
            branch_id TEXT NOT NULL DEFAULT '',
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

        // 4. Dashboard cache (user/branch isolated)
        await db.execute('''
          CREATE TABLE offline_dashboard_cache (
            id TEXT PRIMARY KEY,
            scope_key TEXT NOT NULL DEFAULT '',
            user_id TEXT NOT NULL DEFAULT '',
            branch_id TEXT NOT NULL DEFAULT '',
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
              scope_key TEXT NOT NULL DEFAULT '',
              user_id TEXT NOT NULL DEFAULT '',
              branch_id TEXT NOT NULL DEFAULT '',
              data_json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          for (final tbl in [
            'offline_groups_cache',
            'offline_clients_cache',
            'offline_outbox',
            'offline_dashboard_cache',
          ]) {
            for (final col in ['scope_key', 'user_id', 'branch_id']) {
              try {
                await db.execute("ALTER TABLE $tbl ADD COLUMN $col TEXT NOT NULL DEFAULT ''");
              } catch (_) {}
            }
          }
          // Purge pre-isolation shared read caches so cross-account/branch bleed cannot occur
          await db.delete('offline_groups_cache');
          await db.delete('offline_clients_cache');
          await db.delete('offline_dashboard_cache');
        }
      },
    );
  }

  // ==========================================
  // 0. DASHBOARD CACHE (OFFLINE FALLBACK)
  // ==========================================

  /// Caches dashboard JSON payload locally scoped by active user & branch
  Future<void> cacheDashboardData(Map<String, dynamic> data, {String role = 'co'}) async {
    final scope = activeScopeKey;
    final memKey = '$scope::$role';
    final nowIso = DateTime.now().toIso8601String();
    final jsonStr = jsonEncode(data);

    _webDashboardCache[memKey] = jsonStr;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_dashboard_${scope}_$role', jsonStr);
      await prefs.setString('offline_dashboard_timestamp_${scope}_$role', nowIso);
      final dashKeys = prefs.getStringList('offline_dashboard_keys_$scope') ?? [];
      if (!dashKeys.contains(role)) {
        dashKeys.add(role);
        await prefs.setStringList('offline_dashboard_keys_$scope', dashKeys);
      }
    } catch (_) {}

    if (!kIsWeb && !useMemoryStore) {
      try {
        final db = await database;
        await db.insert(
          'offline_dashboard_cache',
          {
            'id': memKey,
            'scope_key': scope,
            'user_id': _scopeUserId,
            'branch_id': _scopeBranchId,
            'data_json': jsonStr,
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}
    }
  }

  /// Retrieves cached dashboard JSON payload for active user & branch if present
  Future<Map<String, dynamic>?> getCachedDashboardData({String role = 'co'}) async {
    final scope = activeScopeKey;
    final memKey = '$scope::$role';

    if (_webDashboardCache.containsKey(memKey)) {
      final str = _webDashboardCache[memKey]!;
      return jsonDecode(str) as Map<String, dynamic>;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('offline_dashboard_${scope}_$role');
      if (str != null && str.isNotEmpty) {
        _webDashboardCache[memKey] = str;
        return jsonDecode(str) as Map<String, dynamic>;
      }
    } catch (_) {}

    if (!kIsWeb && !useMemoryStore) {
      try {
        final db = await database;
        final res = await db.query(
          'offline_dashboard_cache',
          where: 'id = ? AND scope_key = ?',
          whereArgs: [memKey, scope],
          limit: 1,
        );
        if (res.isNotEmpty) {
          final jsonStr = res.first['data_json'] as String;
          _webDashboardCache[memKey] = jsonStr;
          return jsonDecode(jsonStr) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    return null;
  }

  // ==========================================
  // 0.1 GENERIC GET API RESPONSE CACHE
  // ==========================================

  /// Caches an API GET response locally scoped to active user & branch
  Future<void> cacheApiResponse(String cacheKey, dynamic data) async {
    final scope = activeScopeKey;
    final memKey = '$scope::$cacheKey';
    _webApiCache[memKey] = data;

    try {
      final jsonStr = jsonEncode(data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_api_${scope}_$cacheKey', jsonStr);

      final keys = prefs.getStringList('offline_api_cache_keys_$scope') ?? [];
      if (!keys.contains(cacheKey)) {
        keys.add(cacheKey);
        await prefs.setStringList('offline_api_cache_keys_$scope', keys);
      }
    } catch (e) {
      debugPrint('Failed to persist API cache for $cacheKey: $e');
    }
  }

  /// Retrieves cached GET API response for active user & branch if available
  Future<dynamic> getCachedApiResponse(String cacheKey) async {
    final scope = activeScopeKey;
    final memKey = '$scope::$cacheKey';
    if (_webApiCache.containsKey(memKey)) {
      return _webApiCache[memKey];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('offline_api_${scope}_$cacheKey');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        _webApiCache[memKey] = decoded;
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

  String _groupSheetCacheKey(String groupName, [String? dateStr]) {
    final cleanGroup = groupName.trim();
    final cleanDate = (dateStr ?? '').trim();
    if (cleanDate.isEmpty) return cleanGroup;
    return '$cleanGroup::$cleanDate';
  }

  /// Caches a group collection sheet locally for offline access scoped by active user & branch.
  Future<void> cacheGroupSheet(String groupName, Map<String, dynamic> sheetData, {String? dateStr}) async {
    final scope = activeScopeKey;
    final nowIso = DateTime.now().toIso8601String();
    final jsonStr = jsonEncode(sheetData);
    final effectiveDate = (dateStr ?? sheetData['date']?.toString() ?? '').split('T').first.trim();
    final cacheKey = _groupSheetCacheKey(groupName, effectiveDate);
    final scopedCacheKey = '$scope::$cacheKey';
    final scopedBaseKey = '$scope::$groupName';

    // Persist to SharedPreferences across web and native (scoped by user & branch)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_sheet_${scope}_$cacheKey', jsonStr);
      await prefs.setString('offline_sheet_${scope}_$groupName', jsonStr);
      final sheetKeys = prefs.getStringList('offline_cached_group_keys_$scope') ?? [];
      var keysChanged = false;
      if (!sheetKeys.contains(cacheKey)) {
        sheetKeys.add(cacheKey);
        keysChanged = true;
      }
      if (!sheetKeys.contains(groupName)) {
        sheetKeys.add(groupName);
        keysChanged = true;
      }
      if (keysChanged) {
        await prefs.setStringList('offline_cached_group_keys_$scope', sheetKeys);
      }

      final groups = prefs.getStringList('offline_cached_groups_$scope') ?? [];
      if (!groups.contains(groupName)) {
        groups.add(groupName);
        await prefs.setStringList('offline_cached_groups_$scope', groups);
      }
    } catch (_) {}

    // Support both 'members' (authoritative FastAPI response) and 'clients'
    final rawClients = sheetData['members'] as List<dynamic>? ?? sheetData['clients'] as List<dynamic>? ?? [];

    if (kIsWeb || useMemoryStore) {
      final cacheEntry = {
        'group_name': groupName,
        'scope_key': scope,
        'meeting_day': sheetData['meeting_day'] ?? '',
        'data_json': jsonStr,
        'updated_at': nowIso,
      };
      _webGroupsCache[scopedCacheKey] = Map<String, dynamic>.from(cacheEntry);
      _webGroupsCache[scopedBaseKey] = Map<String, dynamic>.from(cacheEntry);

      for (final c in rawClients) {
        if (c is Map<String, dynamic>) {
          final cid = c['client_id']?.toString() ?? c['id']?.toString() ?? '';
          final lid = c['loan_id']?.toString() ?? '';
          final clientKey = lid.isNotEmpty ? '$scope::$cid::$lid' : '$scope::$cid';
          if (cid.isNotEmpty) {
            _webClientsCache[clientKey] = {
              'client_id': cid,
              'scope_key': scope,
              'user_id': _scopeUserId,
              'branch_id': _scopeBranchId,
              'client_code': c['client_code']?.toString() ?? '',
              'client_name': c['client_name']?.toString() ?? '',
              'group_name': groupName,
              'loan_id': lid,
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
      for (final gKey in <String>{scopedCacheKey, scopedBaseKey}) {
        await db.insert(
          'offline_groups_cache',
          {
            'group_name': gKey,
            'scope_key': scope,
            'user_id': _scopeUserId,
            'branch_id': _scopeBranchId,
            'meeting_day': sheetData['meeting_day'] ?? '',
            'data_json': jsonStr,
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final batch = db.batch();
      for (final c in rawClients) {
        if (c is Map<String, dynamic>) {
          final cid = c['client_id']?.toString() ?? c['id']?.toString() ?? '';
          if (cid.isNotEmpty) {
            batch.insert(
              'offline_clients_cache',
              {
                'client_id': '$scope::$cid',
                'scope_key': scope,
                'user_id': _scopeUserId,
                'branch_id': _scopeBranchId,
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
      return cacheGroupSheet(groupName, sheetData, dateStr: effectiveDate);
    }
  }

  /// Retrieves a cached group collection sheet for active user & branch (date-scoped when supplied).
  Future<Map<String, dynamic>?> getCachedGroupSheet(String groupName, {String? dateStr}) async {
    final scope = activeScopeKey;
    final candidates = <String>[
      if (dateStr != null && dateStr.trim().isNotEmpty) _groupSheetCacheKey(groupName, dateStr),
      groupName,
    ];

    for (final key in candidates) {
      final entry = _webGroupsCache['$scope::$key'];
      if (entry != null) {
        final jsonStr = entry['data_json'] as String;
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in candidates) {
        final str = prefs.getString('offline_sheet_${scope}_$key');
        if (str != null && str.isNotEmpty) {
          return jsonDecode(str) as Map<String, dynamic>;
        }
      }
    } catch (_) {}

    if (!kIsWeb && !useMemoryStore) {
      try {
        final db = await database;
        for (final key in candidates) {
          final res = await db.query(
            'offline_groups_cache',
            where: 'group_name = ? AND scope_key = ?',
            whereArgs: ['$scope::$key', scope],
            limit: 1,
          );
          if (res.isNotEmpty) {
            final jsonStr = res.first['data_json'] as String;
            return jsonDecode(jsonStr) as Map<String, dynamic>;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Retrieves all cached group names scoped to the active user & branch.
  Future<List<String>> getCachedGroupNames() async {
    final scope = activeScopeKey;
    final scopePrefix = '$scope::';
    final names = <String>{};
    for (final raw in _webGroupsCache.keys) {
      if (raw.startsWith(scopePrefix)) {
        final tail = raw.substring(scopePrefix.length);
        names.add(tail.split('::').first);
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('offline_cached_groups_$scope') ?? [];
      for (final raw in list) {
        names.add(raw.split('::').first);
      }
    } catch (_) {}

    if (!kIsWeb && !useMemoryStore) {
      try {
        final db = await database;
        final res = await db.query(
          'offline_groups_cache',
          columns: ['group_name'],
          where: 'scope_key = ?',
          whereArgs: [scope],
          orderBy: 'group_name ASC',
        );
        for (final r in res) {
          final gn = r['group_name'] as String?;
          if (gn != null && gn.startsWith(scopePrefix)) {
            names.add(gn.substring(scopePrefix.length).split('::').first);
          }
        }
      } catch (_) {}
    }

    final sorted = names.toList()..sort();
    return sorted;
  }

  // ==========================================
  // 2. OUTBOX MANAGEMENT (SYNC-UP)
  // ==========================================

  String get _scopedOutboxPrefsKey => 'offline_persisted_outbox_$activeScopeKey';

  Future<List<Map<String, dynamic>>> _readPrefsOutbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_scopedOutboxPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        return (jsonDecode(raw) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Future<void> _writePrefsOutbox(List<Map<String, dynamic>> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_scopedOutboxPrefsKey, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _hydrateWebOutboxFromPrefs() async {
    final scope = activeScopeKey;
    final persisted = await _readPrefsOutbox();
    if (persisted.isEmpty) {
      _webOutbox.removeWhere((item) => item['scope_key'] != scope);
      return;
    }

    // Merge persisted entries for the active scope without duplicating idempotency_key
    final Map<String, Map<String, dynamic>> byKey = {};
    for (final item in persisted) {
      if ((item['scope_key']?.toString() ?? scope) != scope) continue;
      final key = item['idempotency_key']?.toString() ?? '${item['id']}';
      byKey[key] = item;
    }
    for (final item in _webOutbox) {
      if ((item['scope_key']?.toString() ?? scope) != scope) continue;
      final key = item['idempotency_key']?.toString() ?? '${item['id']}';
      byKey[key] = item;
    }
    _webOutbox
      ..clear()
      ..addAll(byKey.values);
  }

  /// Optimistically updates cached group sheets and single-client options
  /// when a collection is queued into the offline outbox so members reflect
  /// today's recorded status and avoid duplicate submissions.
  Future<void> applyOptimisticOfflineCollectionToCachedSheet({
    required String groupName,
    required List<Map<String, dynamic>> collections,
    double groupSavingsDeposit = 0.0,
    String? collectionDate,
  }) async {
    final Map<String, Map<String, dynamic>> txByClient = {};
    final Map<String, Map<String, dynamic>> txByClientLoan = {};
    for (final tx in collections) {
      final cid = (tx['client_id'] ?? tx['Client ID'] ?? '').toString().trim();
      final lid = (tx['loan_id'] ?? '').toString().trim();
      if (cid.isNotEmpty) {
        txByClient[cid] = tx;
        if (lid.isNotEmpty) {
          txByClientLoan['$cid::$lid'] = tx;
        }
      }
    }

    Map<String, dynamic> applyToMemberMap(Map<String, dynamic> member) {
      final cid = (member['client_id'] ?? member['id'] ?? '').toString().trim();
      final lid = (member['loan_id'] ?? '').toString().trim();
      final tx = (lid.isNotEmpty ? txByClientLoan['$cid::$lid'] : null) ?? txByClient[cid];
      if (tx == null) return member;

      final repAmt = ((tx['loan_repayment_amount'] ??
                  tx['repayment_amount'] ??
                  tx['loan_repayment'] ??
                  0) as num)
              .toDouble();
      final savAmt = ((tx['savings_deposit_amount'] ??
                  tx['savings_amount'] ??
                  tx['savings_deposit'] ??
                  0) as num)
              .toDouble();
      final markNotPaid =
          tx['mark_not_paid'] == true || tx['payment_status'] == 'NOT_PAID';

      final prevRep = ((member['today_repayment'] ?? member['today_paid'] ?? 0) as num).toDouble();
      final prevSav = ((member['today_savings'] ?? 0) as num).toDouble();
      final nextRep = markNotPaid ? prevRep : (prevRep + repAmt);
      final nextSav = prevSav + savAmt;

      member['today_repayment'] = nextRep;
      member['today_savings'] = nextSav;
      member['today_collected_total'] = nextRep + nextSav;
      member['today_status'] = markNotPaid
          ? (prevRep > 0 ? 'PAID' : 'NOT_PAID')
          : ((nextRep > 0 || nextSav > 0) ? 'PAID' : (member['today_status'] ?? 'NOT_PAID'));
      member['today_collected'] = true;
      member['offline_queued'] = true;
      return member;
    }

    // 1. Update cached group sheet for `groupName` (date-scoped & base key)
    if (groupName.isNotEmpty && groupName != 'Ungrouped') {
      final sheet = await getCachedGroupSheet(groupName, dateStr: collectionDate);
      if (sheet != null) {
        final updatedSheet = Map<String, dynamic>.from(sheet);
        if (updatedSheet['members'] is List) {
          updatedSheet['members'] = (updatedSheet['members'] as List)
              .map((m) => m is Map ? applyToMemberMap(Map<String, dynamic>.from(m)) : m)
              .toList();
        }
        if (updatedSheet['clients'] is List) {
          updatedSheet['clients'] = (updatedSheet['clients'] as List)
              .map((m) => m is Map ? applyToMemberMap(Map<String, dynamic>.from(m)) : m)
              .toList();
        }
        if (groupSavingsDeposit > 0) {
          final prevGrpSav = ((updatedSheet['group_savings_balance'] ?? 0) as num).toDouble();
          updatedSheet['group_savings_balance'] = prevGrpSav + groupSavingsDeposit;
        }
        await cacheGroupSheet(groupName, updatedSheet, dateStr: collectionDate);
      }
    }

    // 2. Keep cached GET API responses (/single-client-options and /sheet) synchronized
    if (txByClient.isNotEmpty) {
      final scData = await getCachedApiResponse('/api/v1/co/collections/single-client-options');
      if (scData is Map && scData['clients'] is List) {
        final updatedSc = Map<String, dynamic>.from(scData);
        updatedSc['clients'] = (scData['clients'] as List)
            .map((c) => c is Map ? applyToMemberMap(Map<String, dynamic>.from(c)) : c)
            .toList();
        await cacheApiResponse('/api/v1/co/collections/single-client-options', updatedSc);
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final apiKeys = prefs.getStringList('offline_api_cache_keys_$activeScopeKey') ?? [];
        for (final key in apiKeys) {
          if (!key.startsWith('/api/v1/co/collections/sheet')) continue;
          final cachedSheet = await getCachedApiResponse(key);
          if (cachedSheet is! Map) continue;
          final cachedGroup = cachedSheet['group_name']?.toString() ?? '';
          if (groupName.isNotEmpty && cachedGroup == groupName) {
            final updatedApiSheet = Map<String, dynamic>.from(cachedSheet);
            if (updatedApiSheet['members'] is List) {
              updatedApiSheet['members'] = (updatedApiSheet['members'] as List)
                  .map((m) => m is Map ? applyToMemberMap(Map<String, dynamic>.from(m)) : m)
                  .toList();
            }
            if (groupSavingsDeposit > 0) {
              final prevGrpSav = ((updatedApiSheet['group_savings_balance'] ?? 0) as num).toDouble();
              updatedApiSheet['group_savings_balance'] = prevGrpSav + groupSavingsDeposit;
            }
            await cacheApiResponse(key, updatedApiSheet);
          }
        }
      } catch (_) {}
    }
  }

  /// Queues an ad-hoc single client collection into the local outbox when offline.
  Future<int> queueSingleCollection({
    required String idempotencyKey,
    required String clientName,
    required String collectionDate,
    required Map<String, dynamic> payload,
  }) async {
    final scope = activeScopeKey;
    final nowIso = DateTime.now().toIso8601String();
    final int recordId = idempotencyKey.hashCode.abs();
    final entry = <String, dynamic>{
      'id': recordId,
      'scope_key': scope,
      'user_id': _scopeUserId,
      'branch_id': _scopeBranchId,
      'idempotency_key': idempotencyKey,
      'operation_type': 'SINGLE_COLLECTION',
      'group_name': clientName,
      'collection_date': collectionDate,
      'payload_json': jsonEncode(payload),
      'status': 'pending',
      'retry_count': 0,
      'created_at': nowIso,
      'synced_at': null,
      'error_message': null,
    };

    // Persist to SharedPreferences with deduplication and matching id
    final list = await _readPrefsOutbox();
    list.removeWhere((item) => item['idempotency_key'] == idempotencyKey || item['id'] == recordId);
    list.add(Map<String, dynamic>.from(entry));
    await _writePrefsOutbox(list);

    if (kIsWeb || useMemoryStore) {
      _webOutbox.removeWhere((item) => item['idempotency_key'] == idempotencyKey || item['id'] == recordId);
      _webOutbox.add(entry);
      return recordId;
    }

    try {
      final db = await database;
      return await db.insert(
        'offline_outbox',
        {
          'id': recordId,
          'scope_key': scope,
          'user_id': _scopeUserId,
          'branch_id': _scopeBranchId,
          'idempotency_key': idempotencyKey,
          'operation_type': 'SINGLE_COLLECTION',
          'group_name': clientName,
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
      return queueSingleCollection(
        idempotencyKey: idempotencyKey,
        clientName: clientName,
        collectionDate: collectionDate,
        payload: payload,
      );
    }
  }

  /// Queues a collection batch into the local outbox when offline.
  Future<int> queueBatchCollection({
    required String idempotencyKey,
    required String groupName,
    required String collectionDate,
    required Map<String, dynamic> payload,
  }) async {
    final scope = activeScopeKey;
    final nowIso = DateTime.now().toIso8601String();
    final int recordId = idempotencyKey.hashCode.abs();
    final entry = <String, dynamic>{
      'id': recordId,
      'scope_key': scope,
      'user_id': _scopeUserId,
      'branch_id': _scopeBranchId,
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
    };

    // Persist to SharedPreferences with deduplication and matching id
    final list = await _readPrefsOutbox();
    list.removeWhere((item) => item['idempotency_key'] == idempotencyKey || item['id'] == recordId);
    list.add(Map<String, dynamic>.from(entry));
    await _writePrefsOutbox(list);

    if (kIsWeb || useMemoryStore) {
      _webOutbox.removeWhere((item) => item['idempotency_key'] == idempotencyKey || item['id'] == recordId);
      _webOutbox.add(entry);
      return recordId;
    }

    try {
      final db = await database;
      return await db.insert(
        'offline_outbox',
        {
          'id': recordId,
          'scope_key': scope,
          'user_id': _scopeUserId,
          'branch_id': _scopeBranchId,
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

  /// Retrieves all pending outbox batches ready for synchronization (strictly scoped by user & branch).
  Future<List<Map<String, dynamic>>> getPendingOutboxBatches() async {
    final scope = activeScopeKey;
    if (kIsWeb || useMemoryStore) {
      await _hydrateWebOutboxFromPrefs();
      return _webOutbox
          .where((item) =>
              (item['scope_key']?.toString() ?? scope) == scope &&
              (item['status'] == 'pending' || item['status'] == 'failed'))
          .toList();
    }

    try {
      final db = await database;
      return await db.query(
        'offline_outbox',
        where: "(status = 'pending' OR status = 'failed') AND scope_key = ?",
        whereArgs: [scope],
        orderBy: 'id ASC',
      );
    } catch (_) {
      useMemoryStore = true;
      return getPendingOutboxBatches();
    }
  }

  /// Retrieves count of pending transactions awaiting upload for the active user & branch.
  Future<int> getPendingOutboxCount() async {
    final scope = activeScopeKey;
    if (kIsWeb || useMemoryStore) {
      await _hydrateWebOutboxFromPrefs();
      return _webOutbox
          .where((item) =>
              (item['scope_key']?.toString() ?? scope) == scope &&
              (item['status'] == 'pending' || item['status'] == 'failed'))
          .length;
    }

    try {
      final db = await database;
      final res = await db.rawQuery(
        "SELECT COUNT(*) as count FROM offline_outbox WHERE (status = 'pending' OR status = 'failed') AND scope_key = ?",
        [scope],
      );
      if (res.isNotEmpty) {
        return (res.first['count'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (_) {
      useMemoryStore = true;
      return getPendingOutboxCount();
    }
  }

  String? _resolveIdempotencyKeyForId(int id, List<Map<String, dynamic>> prefsList) {
    for (final item in _webOutbox) {
      if (item['id'] == id) return item['idempotency_key']?.toString();
    }
    for (final item in prefsList) {
      if (item['id'] == id) return item['idempotency_key']?.toString();
    }
    return null;
  }

  /// Marks a queued batch as successfully synced to the central server.
  Future<void> markOutboxBatchSynced(int id, String serverBatchId) async {
    final nowIso = DateTime.now().toIso8601String();
    final prefsList = await _readPrefsOutbox();
    final targetKey = _resolveIdempotencyKeyForId(id, prefsList);
    bool matches(Map<String, dynamic> item) =>
        item['id'] == id || (targetKey != null && item['idempotency_key'] == targetKey);

    if (prefsList.isNotEmpty) {
      for (final item in prefsList) {
        if (matches(item)) {
          item['status'] = 'synced';
          item['synced_at'] = nowIso;
          item['error_message'] = null;
        }
      }
      await _writePrefsOutbox(prefsList);
    }

    if (kIsWeb || useMemoryStore) {
      for (final item in _webOutbox) {
        if (matches(item)) {
          item['status'] = 'synced';
          item['synced_at'] = nowIso;
          item['error_message'] = null;
        }
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
        where: targetKey != null ? '(id = ? OR idempotency_key = ?) AND scope_key = ?' : 'id = ? AND scope_key = ?',
        whereArgs: targetKey != null ? [id, targetKey, activeScopeKey] : [id, activeScopeKey],
      );
    } catch (_) {
      useMemoryStore = true;
      return markOutboxBatchSynced(id, serverBatchId);
    }
  }

  /// Marks a queued batch as failed with error details for retry, or quarantined on permanent rejection.
  Future<void> markOutboxBatchFailed(int id, String errorMessage, {bool isPermanent = false}) async {
    final targetStatus = isPermanent ? 'quarantined' : 'failed';
    final prefsList = await _readPrefsOutbox();
    final targetKey = _resolveIdempotencyKeyForId(id, prefsList);
    bool matches(Map<String, dynamic> item) =>
        item['id'] == id || (targetKey != null && item['idempotency_key'] == targetKey);

    if (prefsList.isNotEmpty) {
      for (final item in prefsList) {
        if (matches(item)) {
          item['status'] = targetStatus;
          item['retry_count'] = ((item['retry_count'] as int?) ?? 0) + 1;
          item['error_message'] = errorMessage;
        }
      }
      await _writePrefsOutbox(prefsList);
    }

    if (kIsWeb || useMemoryStore) {
      for (final item in _webOutbox) {
        if (matches(item)) {
          item['status'] = targetStatus;
          item['retry_count'] = ((item['retry_count'] as int?) ?? 0) + 1;
          item['error_message'] = errorMessage;
        }
      }
      return;
    }

    try {
      final db = await database;
      await db.rawUpdate(
        targetKey != null
            ? '''
              UPDATE offline_outbox 
              SET status = ?, 
                  retry_count = retry_count + 1, 
                  error_message = ? 
              WHERE (id = ? OR idempotency_key = ?) AND scope_key = ?
            '''
            : '''
              UPDATE offline_outbox 
              SET status = ?, 
                  retry_count = retry_count + 1, 
                  error_message = ? 
              WHERE id = ? AND scope_key = ?
            ''',
        targetKey != null
            ? [targetStatus, errorMessage, id, targetKey, activeScopeKey]
            : [targetStatus, errorMessage, id, activeScopeKey],
      );
    } catch (_) {
      useMemoryStore = true;
      return markOutboxBatchFailed(id, errorMessage, isPermanent: isPermanent);
    }
  }

  /// Retrieves recent synced outbox items for audit history (scoped by user & branch).
  Future<List<Map<String, dynamic>>> getRecentSyncedBatches({int limit = 20}) async {
    final scope = activeScopeKey;
    if (kIsWeb || useMemoryStore) {
      await _hydrateWebOutboxFromPrefs();
      final synced = _webOutbox
          .where((item) =>
              (item['scope_key']?.toString() ?? scope) == scope &&
              item['status'] == 'synced')
          .toList();
      return synced.reversed.take(limit).toList();
    }

    try {
      final db = await database;
      return await db.query(
        'offline_outbox',
        where: "status = 'synced' AND scope_key = ?",
        whereArgs: [scope],
        orderBy: 'synced_at DESC',
        limit: limit,
      );
    } catch (_) {
      useMemoryStore = true;
      return getRecentSyncedBatches(limit: limit);
    }
  }

  /// Permanently removes a specific queued or failed outbox batch by id.
  Future<void> deleteOutboxBatch(int id) async {
    final prefsList = await _readPrefsOutbox();
    final targetKey = _resolveIdempotencyKeyForId(id, prefsList);
    bool matches(Map<String, dynamic> item) =>
        item['id'] == id || (targetKey != null && item['idempotency_key'] == targetKey);

    if (prefsList.isNotEmpty) {
      prefsList.removeWhere(matches);
      await _writePrefsOutbox(prefsList);
    }

    if (kIsWeb || useMemoryStore) {
      _webOutbox.removeWhere(matches);
      return;
    }

    try {
      final db = await database;
      await db.delete(
        'offline_outbox',
        where: targetKey != null ? '(id = ? OR idempotency_key = ?) AND scope_key = ?' : 'id = ? AND scope_key = ?',
        whereArgs: targetKey != null ? [id, targetKey, activeScopeKey] : [id, activeScopeKey],
      );
    } catch (_) {
      useMemoryStore = true;
      _webOutbox.removeWhere(matches);
    }
  }

  /// Clears all failed outbox batches for the active user & branch from the device.
  Future<int> clearFailedOutboxBatches() async {
    int count = 0;
    final prefsList = await _readPrefsOutbox();
    if (prefsList.isNotEmpty) {
      final kept = prefsList.where((item) => item['status'] != 'failed').toList();
      count = prefsList.length - kept.length;
      await _writePrefsOutbox(kept);
    }

    if (kIsWeb || useMemoryStore) {
      final before = _webOutbox.length;
      _webOutbox.removeWhere((item) => item['status'] == 'failed');
      return count > 0 ? count : (before - _webOutbox.length);
    }

    try {
      final db = await database;
      final deleted = await db.delete(
        'offline_outbox',
        where: "status = 'failed' AND scope_key = ?",
        whereArgs: [activeScopeKey],
      );
      return deleted;
    } catch (_) {
      useMemoryStore = true;
      final before = _webOutbox.length;
      _webOutbox.removeWhere((item) => item['status'] == 'failed');
      return count > 0 ? count : (before - _webOutbox.length);
    }
  }
}
