import 'package:flutter/material.dart';
import '../theme/icare_colors.dart';
import '../theme/icare_spacing.dart';

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
    final effectivePadding = padding ?? IcareSpacing.cardPadding(context);

    Widget cardBody = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? IcareColors.surface,
        borderRadius: IcareSpacing.roundedMd,
        border: border ?? Border.all(color: IcareColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
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
