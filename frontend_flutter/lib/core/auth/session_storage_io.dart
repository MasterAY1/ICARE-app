import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'session_storage_base.dart';

class PlatformSessionStorage implements SessionStorage {
  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/icare_session.json');
  }

  @override
  Future<void> saveSession(String token, String userJson) async {
    try {
      final file = await _getFile();
      await file.writeAsString('$token\n$userJson');
    } catch (_) {}
  }

  @override
  Future<Map<String, String>?> getSession() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final lines = content.split('\n');
        if (lines.length >= 2) {
          final token = lines[0].trim();
          final userJson = lines.sublist(1).join('\n').trim();
          if (token.isNotEmpty && userJson.isNotEmpty) {
            return {'token': token, 'user': userJson};
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> clearSession() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

SessionStorage getSessionStorage() => PlatformSessionStorage();
