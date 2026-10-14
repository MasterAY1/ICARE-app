import 'dart:typed_data';

class PlatformPickedFile {
  final String name;
  final Uint8List bytes;

  PlatformPickedFile({required this.name, required this.bytes});
}

Future<PlatformPickedFile?> pickExcelFile() async {
  // Mobile / Desktop fallback stub
  return null;
}
