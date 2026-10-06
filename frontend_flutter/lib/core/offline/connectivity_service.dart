import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  OnlineStatusNotifier(this._service) : super(true) {
    _init();
  }

  void _init() async {
    state = await _service.checkActualConnection();
    _sub = _service.statusStream.listen((online) {
      state = online;
    });
  }

  void refresh() async {
    state = await _service.checkActualConnection();
  }

  void setOffline() {
    state = false;
    _service.reportOffline();
  }

  void setOnline() {
    state = true;
    _service.reportOnline();
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
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
  ));

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _heartbeatTimer;
  bool _lastStatus = true;

  bool get isOnline => _lastStatus;

  ConnectivityService() {
    _init();
  }

  void _init() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) async {
      final hasInterface = results.any((r) => r != ConnectivityResult.none);
      if (!hasInterface) {
        _updateStatus(false);
      } else {
        // Double-check with a lightweight ping to verify actual data throughput
        final actuallyOnline = await checkActualConnection();
        _updateStatus(actuallyOnline);
      }
    });

    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Active heartbeat every 8 seconds to seamlessly catch online <-> offline transitions
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      await checkActualConnection();
    });
  }

  void reportOffline() {
    _updateStatus(false);
  }

  void reportOnline() {
    _updateStatus(true);
  }

  void _updateStatus(bool isOnline) {
    if (_lastStatus != isOnline) {
      _lastStatus = isOnline;
      _controller.add(isOnline);
    }
  }

  static String get _healthUrl {
    const apiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://icare-app.onrender.com');
    final cleanUrl = apiUrl.isNotEmpty ? apiUrl : 'https://icare-app.onrender.com';
    return cleanUrl.endsWith('/') ? '${cleanUrl}health' : '$cleanUrl/health';
  }

  /// Pings backend health endpoint or reliable DNS to check true connectivity.
  Future<bool> checkActualConnection() async {
    try {
      final res = await _connectivity.checkConnectivity();
      if (res.every((r) => r == ConnectivityResult.none)) {
        _updateStatus(false);
        return false;
      }
      
      final healthRes = await _healthClient.get(_healthUrl);
      final isHealthy = healthRes.statusCode == 200;
      _updateStatus(isHealthy);
      return isHealthy;
    } catch (_) {
      // If server doesn't respond or timed out, report offline
      _updateStatus(false);
      return false;
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _connectivitySub?.cancel();
    _controller.close();
    _healthClient.close();
  }
}
