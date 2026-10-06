// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class PickedFileData {
  final Uint8List bytes;
  final String fileName;
  PickedFileData({required this.bytes, required this.fileName});
}

Future<PickedFileData?> pickBrowserFile({String accept = 'image/*,application/pdf'}) async {
  final completer = Completer<PickedFileData?>();
  final input = html.FileUploadInputElement()..accept = accept;
  input.click();

  input.onChange.listen((e) {
    final files = input.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((e) {
        final res = reader.result;
        if (res is Uint8List) {
          completer.complete(PickedFileData(
            bytes: res,
            fileName: file.name,
          ));
        } else if (res is List<int>) {
          completer.complete(PickedFileData(
            bytes: Uint8List.fromList(res),
            fileName: file.name,
          ));
        } else if (res is ByteBuffer) {
          completer.complete(PickedFileData(
            bytes: res.asUint8List(),
            fileName: file.name,
          ));
        } else {
          completer.complete(null);
        }
      });
      reader.onError.listen((_) {
        completer.complete(null);
      });
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}
