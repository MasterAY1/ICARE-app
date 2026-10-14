// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';
import 'platform_file_picker_stub.dart';

Future<PlatformPickedFile?> pickExcelFile() async {
  final completer = Completer<PlatformPickedFile?>();
  final uploadInput = html.FileUploadInputElement()..accept = '.xlsx, .xls';
  uploadInput.click();

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((e) {
        if (reader.result != null) {
          final bytes = Uint8List.fromList(reader.result as List<int>);
          completer.complete(PlatformPickedFile(name: file.name, bytes: bytes));
        } else {
          completer.complete(null);
        }
      });
      reader.onError.listen((_) => completer.complete(null));
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}
