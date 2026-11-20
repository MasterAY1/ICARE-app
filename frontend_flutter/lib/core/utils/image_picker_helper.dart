import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/icare_theme_tokens.dart';

class PickedAvatarImage {
  final Uint8List bytes;
  final String fileName;

  const PickedAvatarImage({
    required this.bytes,
    required this.fileName,
  });
}

/// Cross-platform profile photo selector using official `image_picker`
/// (supports Android gallery/camera intents and Web browser selection).
class IcareAvatarPicker {
  IcareAvatarPicker._();

  static final ImagePicker _picker = ImagePicker();

  static Future<PickedAvatarImage?> pickProfilePhoto(BuildContext context) async {
    ImageSource source = ImageSource.gallery;

    if (!kIsWeb) {
      final chosenSource = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheetCtx) {
          final tokens = IcareSurfaceTokens.of(sheetCtx);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.borderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Profile Photograph',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose an image source for your staff profile avatar.',
                    style: TextStyle(fontSize: 12.5, color: tokens.textMuted),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: tokens.brandSoftBg,
                      child: Icon(
                        Icons.photo_library_outlined,
                        color: tokens.brandPrimary,
                      ),
                    ),
                    title: Text(
                      'Choose from Gallery',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Select a JPG, PNG, or WEBP photo',
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: tokens.borderSubtle),
                    ),
                    onTap: () => Navigator.of(sheetCtx).pop(ImageSource.gallery),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: tokens.infoBg,
                      child: Icon(
                        Icons.photo_camera_outlined,
                        color: tokens.infoText,
                      ),
                    ),
                    title: Text(
                      'Take Photo with Camera',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Capture a clear headshot right now',
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: tokens.borderSubtle),
                    ),
                    onTap: () => Navigator.of(sheetCtx).pop(ImageSource.camera),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (chosenSource == null) return null;
      source = chosenSource;
    }

    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final safeName = picked.name.isNotEmpty ? picked.name : 'avatar.jpg';
    return PickedAvatarImage(bytes: bytes, fileName: safeName);
  }
}
