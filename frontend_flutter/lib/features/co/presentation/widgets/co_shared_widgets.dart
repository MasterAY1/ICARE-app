import 'package:flutter/material.dart';
import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_section_header.dart';
import '../../../../core/widgets/icare_status_badge.dart';

/// Shared tabular numeric styling for Credit Officer screens.
/// Avoids unregistered font strings while enforcing aligned tabular figures.
TextStyle coTabularStyle({
  double fontSize = 12,
  FontWeight fontWeight = FontWeight.w600,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Controlled horizontal scroll wrapper ensuring every [Scrollbar] always holds
/// its own dedicated [ScrollController] to eliminate runtime assertions.
class CoControlledHorizontalScroll extends StatefulWidget {
  final Widget child;
  final bool thumbVisibility;

  const CoControlledHorizontalScroll({
    super.key,
    required this.child,
    this.thumbVisibility = true,
  });

  @override
  State<CoControlledHorizontalScroll> createState() =>
      _CoControlledHorizontalScrollState();
}

class _CoControlledHorizontalScrollState
    extends State<CoControlledHorizontalScroll> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: widget.thumbVisibility,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: widget.child,
      ),
    );
  }
}

/// Clean Fluid UI inline error card powered by [AppErrorDetails].
class CoInlineErrorCard extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final String? fallbackTitle;

  const CoInlineErrorCard({
    super.key,
    required this.error,
    this.onRetry,
    this.fallbackTitle,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final details = AppErrorDetails.from(error);
    return IcareCard(
      topAccentColor: tokens.dangerDot,
      backgroundColor: tokens.dangerBg,
      border: Border.all(color: tokens.dangerBorder),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: tokens.dangerDot, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fallbackTitle ?? details.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.dangerText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  details.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.dangerText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Clean document upload zone replacing legacy uploader UI.
class CoDocumentUploadCard extends StatelessWidget {
  final String label;
  final String? fileName;
  final String? uploadedUrl;
  final bool isUploading;
  final String allowedTypesText;
  final VoidCallback onPickFile;

  const CoDocumentUploadCard({
    super.key,
    required this.label,
    required this.fileName,
    this.uploadedUrl,
    required this.isUploading,
    required this.allowedTypesText,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final hasFile =
        (fileName ?? '').isNotEmpty || (uploadedUrl ?? '').isNotEmpty;
    return IcareCard(
      backgroundColor: hasFile ? tokens.successBg : tokens.surfaceSubtle,
      border: Border.all(
        color: hasFile ? tokens.successBorder : tokens.borderSubtle,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasFile
                    ? Icons.verified_outlined
                    : Icons.upload_file_outlined,
                size: 16,
                color: hasFile ? tokens.successDot : tokens.brandPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              if (hasFile)
                const IcareStatusBadge(
                  label: 'Uploaded',
                  variant: IcareBadgeVariant.success,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasFile
                ? (fileName?.isNotEmpty == true
                    ? fileName!
                    : 'Document attached')
                : allowedTypesText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: hasFile ? tokens.successText : tokens.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isUploading ? null : onPickFile,
              icon: isUploading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      hasFile ? Icons.swap_horiz_rounded : Icons.cloud_upload_outlined,
                      size: 15,
                    ),
              label: Text(
                isUploading
                    ? 'Uploading...'
                    : (hasFile ? 'Replace File' : 'Browse & Upload'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable empty/info notice banner honoring Fluid UI typography wrapping rules.
class CoEmptyStateCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  const CoEmptyStateCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return IcareCard(
      backgroundColor: tokens.surfaceSubtle,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tokens.infoBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: tokens.infoText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textMuted,
                    height: 1.35,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 10),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard section header wrapper with optional right badge/action.
Widget buildCoSectionHeading({
  required String title,
  String? subtitle,
  Widget? trailing,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: IcareSectionHeader(
      title: title,
      subtitle: subtitle,
      action: trailing,
    ),
  );
}
