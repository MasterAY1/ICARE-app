import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

final isOnlineProvider = StateNotifierProvider<OnlineStatusNotifier, bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return OnlineStatusNotifier(service);
});

class OnlineStatusNotifier extends StateNotifier<bool> {
  final ConnectivityService _service;
  StreamSubscription<bool>? _sub;

  OnlineStatusNotifier(this._service) : super(_service.isOnline) {
    _init();
  }

  void _init() async {
    _sub = _service.statusStream.listen((online) {
      if (mounted) {
        state = online;
      }
    });
    final online = await _service.checkActualConnection(forceImmediateOffline: true);
    if (mounted) {
      state = online;
    }
  }

  Future<bool> refresh() async {
    final online = await _service.checkActualConnection(forceImmediateOffline: true);
    if (mounted) {
      state = online;
    }
    return online;
  }

  void setOffline() {
    _service.reportOffline();
    if (mounted) {
      state = false;
    }
  }

  void setOnline() {
    _service.reportOnline();
    if (mounted) {
      state = true;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Service that monitors physical connectivity and verifies internet health.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final Dio _healthClient = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _heartbeatTimer;
  bool _lastStatus = true;
  int _consecutiveFailures = 0;

  bool get isOnline => _lastStatus;

  ConnectivityService() {
    _init();
  }

  void _init() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) async {
      final hasInterface = results.any((r) => r != ConnectivityResult.none);
      if (!hasInterface) {
        _consecutiveFailures = 2;
        _updateStatus(false);
      } else {
        // Double-check with a lightweight ping to verify actual data throughput
        await checkActualConnection(forceImmediateOffline: true);
      }
    });

    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Steady heartbeat every 30 seconds with debouncing to prevent flapping
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await checkActualConnection();
    });
  }

  void reportOffline() {
    _consecutiveFailures = 2;
    _updateStatus(false);
  }

  void reportOnline() {
    _consecutiveFailures = 0;
    _updateStatus(true);
  }

  void _updateStatus(bool isOnline) {
    _lastStatus = isOnline;
    if (!_controller.isClosed) {
      _controller.add(isOnline);
    }
  }

  static String get _healthUrl {
    final cleanUrl = resolveDefaultApiUrl();
    return cleanUrl.endsWith('/') ? '${cleanUrl}api/health' : '$cleanUrl/api/health';
  }

  /// Pings backend health endpoint to check true connectivity.
  Future<bool> checkActualConnection({bool forceImmediateOffline = false}) async {
    try {
      final res = await _connectivity.checkConnectivity();
      if (res.every((r) => r == ConnectivityResult.none)) {
        _consecutiveFailures = 2;
        _updateStatus(false);
        return false;
      }

      final healthRes = await _healthClient.get(
        _healthUrl,
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final isHealthy = healthRes.statusCode == 200;
      if (isHealthy) {
        _consecutiveFailures = 0;
        _updateStatus(true);
        return true;
      } else {
        _consecutiveFailures++;
        if (forceImmediateOffline || _consecutiveFailures >= 2) {
          _consecutiveFailures = 2;
          _updateStatus(false);
          return false;
        }
        return _lastStatus;
      }
    } catch (_) {
      // Require 2 consecutive failures for background heartbeat, or immediate when forced
      _consecutiveFailures++;
      if (forceImmediateOffline || _consecutiveFailures >= 2) {
        _consecutiveFailures = 2;
        _updateStatus(false);
        return false;
      }
      return _lastStatus;
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _connectivitySub?.cancel();
    _controller.close();
    _healthClient.close();
  }
}
