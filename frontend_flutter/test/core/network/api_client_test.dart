import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/core/network/api_client.dart';

void main() {
  group('resolveDefaultApiUrl - Production Environment Isolation', () {
    test('explicit baseUrl parameter always takes top priority', () {
      final url = resolveDefaultApiUrl(
        baseUrl: 'http://custom-proxy:9999',
        isWebOverride: true,
        isReleaseOverride: false,
      );
      expect(url, equals('http://custom-proxy:9999'));
    });

    test('web local development on localhost defaults to local backend', () {
      final url = resolveDefaultApiUrl(
        isWebOverride: true,
        isReleaseOverride: false,
        webHostOverride: 'localhost',
        webOriginOverride: 'http://localhost:3000',
      );
      expect(url, equals('http://localhost:8000'));
    });

    test('web local development on 127.0.0.1 defaults to local backend', () {
      final url = resolveDefaultApiUrl(
        isWebOverride: true,
        isReleaseOverride: false,
        webHostOverride: '127.0.0.1',
        webOriginOverride: 'http://127.0.0.1:52134',
      );
      expect(url, equals('http://localhost:8000'));
    });

    test('web debug build never silently falls back to cloud production', () {
      // Even if host is not localhost, debug mode forces localhost backend
      final url = resolveDefaultApiUrl(
        isWebOverride: true,
        isReleaseOverride: false,
        webHostOverride: 'dev-machine.local',
      );
      expect(url, equals('http://localhost:8000'));
    });

    test('web release build defaults to hosting origin', () {
      final url = resolveDefaultApiUrl(
        isWebOverride: true,
        isReleaseOverride: true,
        webHostOverride: 'icare-banking.vercel.app',
        webOriginOverride: 'https://icare-banking.vercel.app',
      );
      expect(url, equals('https://icare-banking.vercel.app'));
    });

    test('android debug build routes to host machine via emulator loopback alias', () {
      final url = resolveDefaultApiUrl(
        isWebOverride: false,
        isReleaseOverride: false,
        platformOverride: TargetPlatform.android,
      );
      expect(url, equals('http://10.0.2.2:8000'));
    });

    test('iOS debug build routes to localhost', () {
      final url = resolveDefaultApiUrl(
        isWebOverride: false,
        isReleaseOverride: false,
        platformOverride: TargetPlatform.iOS,
      );
      expect(url, equals('http://localhost:8000'));
    });

    test('desktop debug build routes to localhost', () {
      final url = resolveDefaultApiUrl(
        isWebOverride: false,
        isReleaseOverride: false,
        platformOverride: TargetPlatform.windows,
      );
      expect(url, equals('http://localhost:8000'));
    });

    test('mobile native release build targets authoritative cloud backend', () {
      final url = resolveDefaultApiUrl(
        isWebOverride: false,
        isReleaseOverride: true,
        platformOverride: TargetPlatform.android,
      );
      expect(url, equals('https://icare-app.onrender.com'));
    });
  });

  group('ApiClient Base URL Verification', () {
    test('instantiates with custom baseUrl and exposes it correctly', () {
      final client = ApiClient(baseUrl: 'http://test-server:8000');
      expect(client.baseUrl, equals('http://test-server:8000'));
    });
  });
}
