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
    final envBaseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://icare-app.onrender.com');
    final effectiveUrl = baseUrl ?? (envBaseUrl.isNotEmpty ? envBaseUrl : 'https://icare-app.onrender.com');
    _dio = Dio(BaseOptions(
      baseUrl: effectiveUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
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
        if (_isConnectionError(err)) {
          // Immediately notify connectivity service of offline state
          _connectivityService?.reportOffline();

          // If this was a GET request, resolve with cached data
          if (err.requestOptions.method.toUpperCase() == 'GET') {
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
        }

        // For non-GET requests or cache misses, propagate the error
        return handler.next(err);
      },
    ));
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

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    return _dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path, {dynamic data}) async {
    return _dio.delete(path, data: data);
  }
}
