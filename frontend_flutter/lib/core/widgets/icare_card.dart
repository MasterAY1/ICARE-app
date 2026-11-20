import 'package:flutter/material.dart';
import '../theme/icare_spacing.dart';
import '../theme/icare_theme_tokens.dart';

/// Universal institutional banking card container
class IcareCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? topAccentColor;
  final double topAccentHeight;
  final VoidCallback? onTap;
  final Border? border;

  const IcareCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.topAccentColor,
    this.topAccentHeight = 3.0,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final effectivePadding = padding ?? IcareSpacing.cardPadding(context);

    Widget cardBody = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? tokens.surface,
        borderRadius: IcareSpacing.roundedMd,
        border: border ?? Border.all(color: tokens.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: tokens.isDark ? const Color(0x28000000) : const Color(0x0A0F172A),
            blurRadius: tokens.isDark ? 8 : 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: IcareSpacing.roundedMd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (topAccentColor != null)
              Container(
                height: topAccentHeight,
                color: topAccentColor,
              ),
            Padding(
              padding: effectivePadding,
              child: child,
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: IcareSpacing.roundedMd,
          child: cardBody,
        ),
      );
    }

    return cardBody;
  }
}
