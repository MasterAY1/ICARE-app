import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';

class TelemetryService {
  static final TelemetryService instance = TelemetryService._();
  TelemetryService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  String _resolveBaseUrl() => resolveDefaultApiUrl();

  /// Fire-and-forget report of unhandled exceptions to backend APM
  void reportError({
    required dynamic error,
    StackTrace? stackTrace,
    String? route,
    Map<String, dynamic>? context,
  }) {
    final platformStr = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
    final baseUrl = _resolveBaseUrl();
    final endpoint = '$baseUrl/api/v1/telemetry/client-error';

    _dio.post(
      endpoint,
      data: {
        'error': error.toString(),
        'stack_trace': stackTrace?.toString(),
        'platform': platformStr,
        'route': route,
        'context': context ?? {},
      },
    ).catchError((err) {
      // Graceful fail-open: avoid recursive errors if network is unavailable
      debugPrint('[Telemetry] Failed to deliver error report: $err');
      return Response(requestOptions: RequestOptions(path: endpoint), statusCode: 500);
    });
  }
}
