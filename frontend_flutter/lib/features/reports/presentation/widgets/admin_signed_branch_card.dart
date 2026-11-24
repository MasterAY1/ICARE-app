import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../../data/models/report_models.dart';

/// Card presenting one Area Manager-signed and reviewed branch monthly report
/// in Admin's Executive Queue, highlighting AM signature, review notes, and archival controls.
class AdminSignedBranchCard extends StatelessWidget {
  final MonthlyWorkflowPendingBranchModel submission;
  final bool isSelected;
  final bool isDirectorReadOnly;
  final bool isBusyLocking;
  final VoidCallback onInspectStatements;
  final VoidCallback onPreviewPdf;
  final VoidCallback onShareExcel;
  final VoidCallback? onLockArchive;

  const AdminSignedBranchCard({
    super.key,
    required this.submission,
    this.isSelected = false,
    this.isDirectorReadOnly = false,
    this.isBusyLocking = false,
    required this.onInspectStatements,
    required this.onPreviewPdf,
    required this.onShareExcel,
    this.onLockArchive,
  });

  static final NumberFormat _ngnFmt = NumberFormat('#,##0.00');

  String _formatDate(String? rawIso) {
    if (rawIso == null || rawIso.trim().isEmpty) return 'Timestamp recorded';
    try {
      final dt = DateTime.parse(rawIso).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return rawIso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final bool isLocked = submission.status == 'ADMIN_LOCKED';
    final bool isSealed = submission.status == 'AREA_SEALED';

    final String statusLabel = isLocked
        ? 'LOCKED & ARCHIVED'
        : (isSealed ? 'REGIONALLY SEALED' : 'AM SIGNED & REVIEWED');
    final IcareBadgeVariant statusVariant = isLocked
        ? IcareBadgeVariant.neutral
        : (isSealed ? IcareBadgeVariant.info : IcareBadgeVariant.success);

    final Color topAccent = isLocked
        ? tokens.textPrimary
        : (isSealed ? tokens.infoDot : tokens.successDot);

    final String signerName = (submission.amName?.trim().isNotEmpty ?? false)
        ? submission.amName!.trim()
        : 'Area Manager';
    final String reviewNote = (submission.amNotes?.trim().isNotEmpty ?? false)
        ? submission.amNotes!.trim()
        : 'Reviewed and signed by Area Manager with verified Trial Balance and Vault Cash.';

    return IcareCard(
      topAccentColor: topAccent,
      border: isSelected
          ? Border.all(color: tokens.brandPrimary, width: 1.8)
          : Border.all(color: tokens.borderSubtle, width: 1.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Branch, Area & Status Badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: tokens.brandSoftBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.brandSoftBorder),
                    ),
                    child: Icon(
                      Icons.account_balance_outlined,
                      size: 16,
                      color: tokens.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission.branchName,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        if (submission.areaName != null &&
                            submission.areaName!.trim().isNotEmpty)
                          Text(
                            '${submission.areaName!} • BM: ${submission.bmName ?? 'Branch Manager'}',
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: tokens.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  IcareStatusBadge(label: statusLabel, variant: statusVariant),
                  IcareStatusBadge(
                    label:
                        submission.isGlBalanced ? 'GL BALANCED' : 'GL VARIANCE',
                    variant: submission.isGlBalanced
                        ? IcareBadgeVariant.success
                        : IcareBadgeVariant.danger,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // AM Review & Signature Attribution Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: isLocked ? tokens.surfaceSubtle : tokens.successBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isLocked ? tokens.borderSubtle : tokens.successBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isLocked ? Icons.verified_outlined : Icons.draw_outlined,
                      size: 15,
                      color:
                          isLocked ? tokens.brandPrimary : tokens.successText,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Signed by $signerName • ${_formatDate(submission.amEndorsedAt ?? submission.submittedAt)}',
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isLocked
                              ? tokens.textPrimary
                              : tokens.successText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reviewNote,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.textSecondary,
                    height: 1.35,
                  ),
                ),
                if (isLocked && submission.adminName != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: tokens.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Archived by ${submission.adminName!} on ${_formatDate(submission.adminLockedAt)}',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tokens.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Key Financial Snapshot Strip
          LayoutBuilder(
            builder: (context, constraints) {
              final int cols = constraints.maxWidth >= 520 ? 3 : 2;
              final double tileWidth =
                  (constraints.maxWidth - ((cols - 1) * 8)) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniMetricTile(
                    width: tileWidth,
                    label: 'Disbursed Principal',
                    value: '₦${_ngnFmt.format(submission.disbursedPrincipal)}',
                    tokens: tokens,
                  ),
                  _MiniMetricTile(
                    width: tileWidth,
                    label: 'Period Collections',
                    value: '₦${_ngnFmt.format(submission.collections)}',
                    tokens: tokens,
                  ),
                  _MiniMetricTile(
                    width: tileWidth,
                    label: 'Closing Credit',
                    value: '₦${_ngnFmt.format(submission.closingCredit)}',
                    tokens: tokens,
                  ),
                  _MiniMetricTile(
                    width: tileWidth,
                    label: 'Closing Savings',
                    value: '₦${_ngnFmt.format(submission.closingSavings)}',
                    tokens: tokens,
                  ),
                  _MiniMetricTile(
                    width: tileWidth,
                    label: 'Physical Vault Cash',
                    value: '₦${_ngnFmt.format(submission.vaultCash)}',
                    tokens: tokens,
                  ),
                  _MiniMetricTile(
                    width: tileWidth,
                    label: 'Net Active Credit',
                    value: '₦${_ngnFmt.format(submission.netActiveCredit)}',
                    tokens: tokens,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Action Controls
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: onInspectStatements,
                icon: const Icon(Icons.fact_check_outlined, size: 15),
                label: Text(
                  isSelected ? 'Inspecting Statements' : 'Inspect Statements',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected
                      ? tokens.brandPrimary
                      : tokens.brandPrimaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onPreviewPdf,
                icon: Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 15,
                  color: tokens.dangerText,
                ),
                label: Text(
                  'Preview & Print PDF',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.dangerText,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.dangerBorder),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onShareExcel,
                icon: Icon(
                  Icons.ios_share_outlined,
                  size: 15,
                  color: tokens.brandPrimary,
                ),
                label: Text(
                  'Share Excel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.brandPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.brandPrimary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                ),
              ),
              if (!isLocked && !isDirectorReadOnly && onLockArchive != null)
                ElevatedButton.icon(
                  onPressed: isBusyLocking ? null : onLockArchive,
                  icon: const Icon(Icons.lock_outline_rounded, size: 15),
                  label: Text(
                    isBusyLocking ? 'Locking...' : 'Lock & Archive',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetricTile extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IcareSurfaceTokens tokens;

  const _MiniMetricTile({
    required this.width,
    required this.label,
    required this.value,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: tokens.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
