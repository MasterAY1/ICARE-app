import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../offline/connectivity_service.dart';
import '../offline/offline_database_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  final offlineDb = ref.watch(offlineDatabaseServiceProvider);
  return ApiClient(
    connectivityService: connectivity,
    offlineDb: offlineDb,
  );
});

/// Authoritatively resolves the default backend API base URL with environment isolation.
///
/// Security & Isolation Invariants:
/// 1. Compile-time explicit `API_BASE_URL` (e.g. `--dart-define=API_BASE_URL=...`)
///    always takes top priority across all platforms.
/// 2. Local debug builds (`!kReleaseMode`) NEVER default to live production:
///    - Web debug (`kIsWeb` on localhost / 127.0.0.1 or `!kReleaseMode`): defaults to `http://localhost:8000`.
///    - Android emulator debug (`TargetPlatform.android`): defaults to `http://10.0.2.2:8000`.
///    - iOS / Desktop debug: defaults to `http://localhost:8000`.
/// 3. Release builds (`kReleaseMode`):
///    - Web: defaults to hosting origin (`Uri.base.origin`), or fallback if empty.
///    - Mobile APK / App: defaults to production cloud backend (`https://icare-app.onrender.com`).
String resolveDefaultApiUrl({
  String? baseUrl,
  bool? isWebOverride,
  bool? isReleaseOverride,
  TargetPlatform? platformOverride,
  String? webOriginOverride,
  String? webHostOverride,
}) {
  if (baseUrl != null && baseUrl.isNotEmpty) {
    return baseUrl;
  }

  const envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (envBaseUrl.isNotEmpty) {
    return envBaseUrl;
  }

  final isWeb = isWebOverride ?? kIsWeb;
  final isRelease = isReleaseOverride ?? kReleaseMode;
  final platform = platformOverride ?? defaultTargetPlatform;

  if (isWeb) {
    String origin = webOriginOverride ?? '';
    if (origin.isEmpty) {
      try {
        if (Uri.base.hasScheme && (Uri.base.scheme == 'http' || Uri.base.scheme == 'https')) {
          origin = Uri.base.origin;
        }
      } catch (_) {
        origin = '';
      }
    }
    String host = webHostOverride ?? '';
    if (host.isEmpty) {
      try {
        host = Uri.base.host.toLowerCase();
      } catch (_) {
        host = '';
      }
    } else {
      host = host.toLowerCase();
    }
    final isLocalHost = host == 'localhost' || host == '127.0.0.1';

    if (!isRelease || isLocalHost) {
      // Local development web session: target local FastAPI backend
      return 'http://localhost:8000';
    }

    if (origin.isNotEmpty && !origin.startsWith('file://')) {
      return origin;
    }
    return 'https://icare-app.onrender.com';
  }

  // Non-web platforms (Android, iOS, Desktop)
  if (!isRelease) {
    // Debug / local testing mode
    if (platform == TargetPlatform.android) {
      // Android emulator loopback alias to host machine
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  // Authoritative production release cloud backend
  return 'https://icare-app.onrender.com';
}

class ApiClient {
  late final Dio _dio;
  String? _authToken;
  final ConnectivityService? _connectivityService;
  final OfflineDatabaseService? _offlineDb;

  String get baseUrl => _dio.options.baseUrl;

  ApiClient({
    String? baseUrl,
    ConnectivityService? connectivityService,
    OfflineDatabaseService? offlineDb,
    HttpClientAdapter? adapter,
  })  : _connectivityService = connectivityService,
        _offlineDb = offlineDb {
    final effectiveUrl = resolveDefaultApiUrl(baseUrl: baseUrl);
    _dio = Dio(BaseOptions(
      baseUrl: effectiveUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 45),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    if (adapter != null) {
      _dio.httpClientAdapter = adapter;
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }

        final bypassCache = options.extra['bypass_offline_cache'] == true;

        // If offline and request is GET, instantly serve cached response if present
        if (!bypassCache &&
            options.method.toUpperCase() == 'GET' &&
            _connectivityService?.isOnline == false) {
          final cacheKey = _getCacheKey(options.path, options.queryParameters);
          final cached = await _offlineDb?.getCachedApiResponse(cacheKey);
          if (cached != null) {
            return handler.resolve(Response(
              requestOptions: options,
              data: cached,
              statusCode: 200,
              statusMessage: 'OK (Offline Cache)',
            ));
          }
        }

        return handler.next(options);
      },
      onResponse: (response, handler) async {
        // Any successful response confirms network connectivity
        _connectivityService?.reportOnline();

        // Transparently cache successful GET responses
        if (response.requestOptions.method.toUpperCase() == 'GET' &&
            response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300 &&
            response.data != null) {
          final cacheKey = _getCacheKey(
            response.requestOptions.path,
            response.requestOptions.queryParameters,
          );
          _offlineDb?.cacheApiResponse(cacheKey, response.data);
        }

        return handler.next(response);
      },
      onError: (err, handler) async {
        final isPhysOffline = _isPhysicalDisconnect(err);
        if (isPhysOffline) {
          // Immediately notify connectivity service of true physical offline state
          _connectivityService?.reportOffline();
        }

        // If this was a GET request and network dropped or timed out, resolve with cached data
        if (_isConnectionError(err) && err.requestOptions.method.toUpperCase() == 'GET') {
          final cacheKey = _getCacheKey(
            err.requestOptions.path,
            err.requestOptions.queryParameters,
          );
          final cached = await _offlineDb?.getCachedApiResponse(cacheKey);
          if (cached != null) {
            return handler.resolve(Response(
              requestOptions: err.requestOptions,
              data: cached,
              statusCode: 200,
              statusMessage: 'OK (Offline Cache Fallback)',
            ));
          }
        }

        // For non-GET requests or cache misses, propagate the error
        return handler.next(err);
      },
    ));
  }

  static bool _isPhysicalDisconnect(DioException err) {
    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout) {
      return true;
    }
    final msg = (err.message ?? '').toLowerCase();
    final errStr = err.error?.toString().toLowerCase() ?? '';
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        errStr.contains('socketexception') ||
        errStr.contains('failed host lookup')) {
      return true;
    }
    return false;
  }

  static bool _isConnectionError(DioException err) {
    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return true;
    }
    final msg = (err.message ?? '').toLowerCase();
    final errStr = err.error?.toString().toLowerCase() ?? '';
    if (msg.contains('xmlhttprequest') ||
        msg.contains('connection errored') ||
        msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        errStr.contains('xmlhttprequest') ||
        errStr.contains('connection errored') ||
        errStr.contains('socketexception') ||
        errStr.contains('failed host lookup')) {
      return true;
    }
    if (err.response?.statusCode != null && err.response!.statusCode! >= 502) {
      return true;
    }
    return false;
  }

  static String _getCacheKey(String path, [Map<String, dynamic>? queryParameters]) {
    final uri = Uri.parse(path);
    final allParams = <String, String>{};
    uri.queryParameters.forEach((k, v) => allParams[k] = v);
    if (queryParameters != null) {
      queryParameters.forEach((k, v) => allParams[k] = v?.toString() ?? '');
    }
    if (allParams.isEmpty) {
      return uri.path;
    }
    final sortedKeys = allParams.keys.toList()..sort();
    final qs = sortedKeys.map((k) => '$k=${allParams[k]}').join('&');
    return '${uri.path}?$qs';
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Queries backend to recover authoritative status of an in-flight or interrupted transaction.
  /// Prevents duplicate financial transactions after network dropouts.
  Future<Map<String, dynamic>?> checkTransactionStatus(String idempotencyKey) async {
    if (idempotencyKey.isEmpty) return null;
    try {
      final res = await _dio.get('/api/v1/transactions/status/$idempotencyKey');
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Backend has no record of this transaction key
        return {'status': 'NotFound', 'response_code': 404};
      }
      rethrow;
    }
  }

  /// Evaluates whether an error represents a permanent validation or business rule failure
  /// that must never be retried or queued for offline retry.
  static bool isPermanentError(dynamic error) {
    if (error is DioException && error.response != null) {
      final code = error.response!.statusCode;
      return code == 400 || code == 401 || code == 403 || code == 422;
    }
    return false;
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken}) async {
    return _dio.get(path, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken}) async {
    return _dio.post(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken}) async {
    return _dio.put(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken}) async {
    return _dio.delete(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }
}
