import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exceptionAsString()}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      color: const Color(0xFFF8FAFC),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24.0),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
          ),
          SizedBox(height: 12),
          Text(
            'Initializing interface...',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569), decoration: TextDecoration.none),
          ),
        ],
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Async Error: $error');
    return true; // Prevents process crash
  };

  runApp(
    const ProviderScope(
      child: IcareApp(),
    ),
  );
}
