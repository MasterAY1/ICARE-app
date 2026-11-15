import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Platform implementation for Android, iOS, Windows, macOS, and Linux.
/// Returns the verified saved file path on success, or null if saving failed.
Future<String?> downloadBlobFile(List<int> bytes, String fileName, String mimeType) async {
  final candidates = <Future<Directory?> Function()>[
    if (Platform.isAndroid) ...[
      getDownloadsDirectory,
      getExternalStorageDirectory,
      getApplicationDocumentsDirectory,
    ] else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) ...[
      getDownloadsDirectory,
      getApplicationDocumentsDirectory,
    ] else ...[
      getApplicationDocumentsDirectory,
    ],
  ];

  for (final resolveDir in candidates) {
    try {
      final dir = await resolveDir();
      if (dir == null) continue;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final filePath = p.join(dir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      if (await file.exists()) {
        debugPrint('File saved successfully: $filePath');
        return file.path;
      }
    } catch (e) {
      debugPrint('Storage candidate failed for $fileName: $e');
    }
  }
  return null;
}
