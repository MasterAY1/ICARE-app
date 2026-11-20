import 'package:flutter/material.dart';
import '../theme/icare_typography.dart';
import '../theme/icare_spacing.dart';
import '../theme/icare_theme_tokens.dart';

enum IcareBadgeVariant {
  success,
  warning,
  danger,
  info,
  neutral,
}

/// Zero-Emoji Canonical Status Badge with Dot Indicator
class IcareStatusBadge extends StatelessWidget {
  final String label;
  final IcareBadgeVariant? variant;
  final bool showDot;

  const IcareStatusBadge({
    super.key,
    required this.label,
    this.variant,
    this.showDot = true,
  });

  factory IcareStatusBadge.fromStatus(String status, {bool showDot = true}) {
    final s = status.toLowerCase().trim();
    IcareBadgeVariant v;

    if (s.contains('complet') || s.contains('balanc') && !s.contains('unbal') || s.contains('approv') || s.contains('active') || s.contains('paid') && !s.contains('not') && !s.contains('part')) {
      v = IcareBadgeVariant.success;
    } else if (s.contains('unbal') || s.contains('overdue') || s.contains('danger') || s.contains('reject') || s.contains('defaulter') || s.contains('not paid')) {
      v = IcareBadgeVariant.danger;
    } else if (s.contains('part') || s.contains('pend') || s.contains('warn') || s.contains('register')) {
      v = IcareBadgeVariant.warning;
    } else if (s.contains('on loan') || s.contains('excess') || s.contains('info')) {
      v = IcareBadgeVariant.info;
    } else {
      v = IcareBadgeVariant.neutral;
    }

    return IcareStatusBadge(
      label: status,
      variant: v,
      showDot: showDot,
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = variant ?? IcareBadgeVariant.neutral;
    final tokens = IcareSurfaceTokens.of(context);

    Color bg;
    Color text;
    Color border;
    Color dot;

    switch (v) {
      case IcareBadgeVariant.success:
        bg = tokens.successBg;
        text = tokens.successText;
        border = tokens.successBorder;
        dot = tokens.successDot;
        break;
      case IcareBadgeVariant.warning:
        bg = tokens.warningBg;
        text = tokens.warningText;
        border = tokens.warningBorder;
        dot = tokens.warningDot;
        break;
      case IcareBadgeVariant.danger:
        bg = tokens.dangerBg;
        text = tokens.dangerText;
        border = tokens.dangerBorder;
        dot = tokens.dangerDot;
        break;
      case IcareBadgeVariant.info:
        bg = tokens.infoBg;
        text = tokens.infoText;
        border = tokens.infoBorder;
        dot = tokens.infoDot;
        break;
      case IcareBadgeVariant.neutral:
        bg = tokens.neutralBg;
        text = tokens.neutralText;
        border = tokens.neutralBorder;
        dot = tokens.neutralDot;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: IcareSpacing.roundedPill,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: IcareTypography.statusBadge.copyWith(
              color: text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
