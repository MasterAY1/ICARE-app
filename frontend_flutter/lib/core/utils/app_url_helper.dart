// lib/core/utils/app_url_helper.dart
import 'package:flutter/foundation.dart';

/// Returns the authoritative public base URL origin for sharing onboarding links,
/// invitations, and portal shortcuts across Web and Mobile Native APKs.
String getAppPublicOrigin() {
  const envUrl = String.fromEnvironment('PUBLIC_WEB_URL', defaultValue: '');
  if (envUrl.isNotEmpty) return envUrl;

  if (kIsWeb) {
    final origin = Uri.base.origin;
    if (origin.isNotEmpty && !origin.startsWith('file://')) {
      return origin;
    }
  }

  if (kDebugMode) {
    return 'http://localhost:3000';
  }

  // Authoritative production web application host for native mobile platforms
  return 'https://icare-app.onrender.com';
}
