import 'package:flutter/material.dart';
import '../theme/icare_colors.dart';
import '../theme/icare_typography.dart';

/// Clean institutional section header with optional action button and accent line
class IcareSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool showAccentBar;

  const IcareSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.showAccentBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showAccentBar) ...[
            Container(
              width: 3.5,
              height: 16,
              decoration: BoxDecoration(
                color: IcareColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: IcareTypography.sectionHeader,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: IcareTypography.sectionSubtitle,
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 12),
            action!,
          ],
        ],
      ),
    );
  }
}
