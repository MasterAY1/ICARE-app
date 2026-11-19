// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

void configurePlatformHttpAdapter(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}

String? readWebCsrfCookie() {
  try {
    final cookies = html.document.cookie;
    if (cookies == null || cookies.isEmpty) return null;
    for (final rawPart in cookies.split(';')) {
      final part = rawPart.trim();
      final eqIdx = part.indexOf('=');
      if (eqIdx <= 0) continue;
      final key = part.substring(0, eqIdx).trim();
      if (key == 'icare_csrf') {
        final rawVal = part.substring(eqIdx + 1).trim();
        if (rawVal.isEmpty) return null;
        return Uri.decodeComponent(rawVal);
      }
    }
  } catch (_) {}
  return null;
}
