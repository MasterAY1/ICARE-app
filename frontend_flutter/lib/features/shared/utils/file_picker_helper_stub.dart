import 'dart:typed_data';

class PickedFileData {
  final Uint8List bytes;
  final String fileName;
  PickedFileData({required this.bytes, required this.fileName});
}

Future<PickedFileData?> pickBrowserFile({String accept = 'image/*,application/pdf'}) async {
  return null;
}
