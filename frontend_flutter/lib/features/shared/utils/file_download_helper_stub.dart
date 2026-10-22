import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Platform implementation for Android, iOS, Windows, macOS, and Linux
void downloadBlobFile(List<int> bytes, String fileName, String mimeType) async {
  try {
    Directory? targetDir;

    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        targetDir = downloadDir;
      } else {
        targetDir = await getExternalStorageDirectory();
      }
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      targetDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    } else {
      targetDir = await getApplicationDocumentsDirectory();
    }

    targetDir ??= await getApplicationDocumentsDirectory();

    final filePath = '${targetDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('File saved successfully: $filePath');
  } catch (e) {
    debugPrint('Error saving file on non-web platform: $e');
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final file = File('${docDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }
}
