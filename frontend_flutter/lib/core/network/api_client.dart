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

class ApiClient {
  late final Dio _dio;
  String? _authToken;
  final ConnectivityService? _connectivityService;
  final OfflineDatabaseService? _offlineDb;

  ApiClient({
    String? baseUrl,
    ConnectivityService? connectivityService,
    OfflineDatabaseService? offlineDb,
    HttpClientAdapter? adapter,
  })  : _connectivityService = connectivityService,
        _offlineDb = offlineDb {
    String defaultUrl = 'https://icare-app.onrender.com';
    if (kIsWeb) {
      final origin = Uri.base.origin;
      final host = Uri.base.host.toLowerCase();
      final isLocalDev = host == 'localhost' || host == '127.0.0.1';
      // When running in a local Flutter dev server (not port 8000), target cloud backend
      // Otherwise, when hosted on Vercel/Production or local reverse proxy, use origin
      if (origin.isNotEmpty && !origin.startsWith('file://') && (!isLocalDev || Uri.base.port == 8000)) {
        defaultUrl = origin;
      }
    }
    const envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final effectiveUrl = baseUrl ?? (envBaseUrl.isNotEmpty ? envBaseUrl : defaultUrl);
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
