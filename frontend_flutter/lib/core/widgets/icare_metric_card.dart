import 'package:flutter/material.dart';
import '../theme/icare_typography.dart';
import '../theme/icare_spacing.dart';
import '../theme/icare_theme_tokens.dart';
import 'icare_card.dart';

/// Standard Institutional Banking KPI / Metric Card
/// Guarantees that financial values never line-break or wrap.
class IcareMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final bool isInverseDelta;
  final Color? topBorderColor;
  final bool isFullEmerald;
  final Color? statusTextColor;
  final IconData? icon;
  final VoidCallback? onTap;

  const IcareMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.isInverseDelta = false,
    this.topBorderColor,
    this.isFullEmerald = false,
    this.statusTextColor,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = IcareSpacing.isMobile(context);
    final tokens = IcareSurfaceTokens.of(context);

    if (isFullEmerald) {
      return IcareCard(
        backgroundColor: tokens.isDark ? tokens.brandPrimaryDark : tokens.brandPrimary,
        border: Border.all(
          color: tokens.isDark ? tokens.brandSoftBorder : tokens.brandPrimaryDark,
          width: 1,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 12 : 14,
        ),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFA7F3D0), // Soft Mint
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 6),
                  Icon(icon, size: 16, color: const Color(0xFFA7F3D0)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
            if (delta != null) ...[
              const SizedBox(height: 4),
              Text(
                delta!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFD1FAE5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      );
    }

    final valueColor = statusTextColor ?? tokens.textPrimary;

    return IcareCard(
      topAccentColor: topBorderColor,
      topAccentHeight: topBorderColor != null ? 3.0 : 0.0,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 12 : 14,
      ),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: IcareTypography.cardLabel.copyWith(color: tokens.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Icon(icon, size: 15, color: tokens.textMuted),
              ],
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: IcareTypography.metricValue.copyWith(
                color: valueColor,
                fontSize: isMobile ? 17 : 18,
              ),
              maxLines: 1,
              softWrap: false,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 4),
            Text(
              delta!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isInverseDelta ? tokens.dangerText : tokens.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
