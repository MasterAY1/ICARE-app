import 'package:flutter/material.dart';
import '../../../../core/theme/icare_theme_tokens.dart';

/// Crisp cross-platform user avatar supporting network profile photos
/// with instant high-contrast monogram fallback and optional upload badge.
class UserAvatarCircle extends StatelessWidget {
  final String fullName;
  final String? avatarUrl;
  final double size;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final bool showOnlineDot;
  final bool isOnline;
  final bool isUploading;
  final VoidCallback? onTap;

  const UserAvatarCircle({
    super.key,
    required this.fullName,
    this.avatarUrl,
    this.size = 44,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.5,
    this.showOnlineDot = false,
    this.isOnline = true,
    this.isUploading = false,
    this.onTap,
  });

  String get _initials {
    final cleaned = fullName.trim();
    if (cleaned.isEmpty) return 'U';
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final hasPhoto = avatarUrl != null &&
        avatarUrl!.trim().isNotEmpty &&
        (avatarUrl!.startsWith('http://') || avatarUrl!.startsWith('https://'));
    final bg = backgroundColor ?? tokens.brandPrimary;
    final border = borderColor ?? tokens.brandSoftBorder;

    final Widget monogram = Container(
      width: size,
      height: size,
      color: bg,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );

    final Widget avatarContent = ClipOval(
      child: hasPhoto
          ? Image.network(
              avatarUrl!.trim(),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => monogram,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return monogram;
              },
            )
          : monogram,
    );

    Widget circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: borderWidth),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          avatarContent,
          if (isUploading)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.45),
              ),
              child: Center(
                child: SizedBox(
                  width: size * 0.34,
                  height: size * 0.34,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (showOnlineDot) {
      final dotSize = (size * 0.24).clamp(9.0, 14.0);
      circle = Stack(
        clipBehavior: Clip.none,
        children: [
          circle,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? tokens.successDot : tokens.warningDot,
                border: Border.all(color: tokens.surface, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return Semantics(
        button: true,
        label: 'Profile avatar for $fullName',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: circle,
          ),
        ),
      );
    }

    return circle;
  }
}
