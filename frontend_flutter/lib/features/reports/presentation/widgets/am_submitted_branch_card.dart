import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../../data/models/report_models.dart';

/// Card representing one supervised branch's monthly return inside the Area
/// Manager's Review & Sign-Off Queue, highlighting Branch Manager submission
/// status, General Ledger integrity, key figures, and Tier-2 actions.
class AmSubmittedBranchCard extends StatelessWidget {
  final MonthlyWorkflowPendingBranchModel submission;
  final bool isSelected;
  final bool isBusyWorkflow;
  final VoidCallback onInspectStatements;
  final VoidCallback onPreviewPdf;
  final VoidCallback onShareExcel;
  final VoidCallback? onEndorse;
  final VoidCallback? onReturn;

  const AmSubmittedBranchCard({
    super.key,
    required this.submission,
    this.isSelected = false,
    this.isBusyWorkflow = false,
    required this.onInspectStatements,
    required this.onPreviewPdf,
    required this.onShareExcel,
    this.onEndorse,
    this.onReturn,
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
    final String status = submission.status;
    final bool isSubmitted = status == 'BM_SUBMITTED';
    final bool isReturned = status == 'RETURNED_FOR_CORRECTION';
    final bool isDraft = status == 'DRAFT';
    final bool isEndorsed = status == 'AM_VERIFIED';
    final bool isSealed = status == 'AREA_SEALED';
    final bool isLocked = status == 'ADMIN_LOCKED';

    late final String statusLabel;
    late final IcareBadgeVariant statusVariant;
    late final Color topAccent;
    late final Color calloutBg;
    late final Color calloutBorder;
    late final Color calloutText;
    late final IconData calloutIcon;
    late final String attributionLine;
    late final String noteLine;

    final String bmSigner = (submission.bmName?.trim().isNotEmpty ?? false)
        ? submission.bmName!.trim()
        : 'Branch Manager';

    if (isSubmitted) {
      statusLabel = 'AWAITING AM SIGN-OFF';
      statusVariant = IcareBadgeVariant.warning;
      topAccent = tokens.warningDot;
      calloutBg = tokens.warningBg;
      calloutBorder = tokens.warningBorder;
      calloutText = tokens.warningText;
      calloutIcon = Icons.pending_actions_rounded;
      attributionLine =
          'Certified by $bmSigner • ${_formatDate(submission.submittedAt)}';
      noteLine = (submission.bmNotes?.trim().isNotEmpty ?? false)
          ? submission.bmNotes!.trim()
          : 'Submitted by Branch Manager and ready for Area Manager review.';
    } else if (isReturned) {
      statusLabel = 'RETURNED TO BM';
      statusVariant = IcareBadgeVariant.danger;
      topAccent = tokens.dangerDot;
      calloutBg = tokens.dangerBg;
      calloutBorder = tokens.dangerBorder;
      calloutText = tokens.dangerText;
      calloutIcon = Icons.assignment_return_outlined;
      attributionLine = 'Queried by Area Manager';
      noteLine = (submission.amQueryNotes?.trim().isNotEmpty ?? false)
          ? 'Query: ${submission.amQueryNotes!.trim()}'
          : 'Returned for reconciliation adjustments prior to endorsement.';
    } else if (isLocked) {
      statusLabel = 'LOCKED & ARCHIVED';
      statusVariant = IcareBadgeVariant.neutral;
      topAccent = tokens.textPrimary;
      calloutBg = tokens.surfaceSubtle;
      calloutBorder = tokens.borderStrong;
      calloutText = tokens.textPrimary;
      calloutIcon = Icons.lock_outline_rounded;
      attributionLine =
          'Archived by ${submission.adminName ?? 'Admin'} • ${_formatDate(submission.adminLockedAt)}';
      noteLine = (submission.amNotes?.trim().isNotEmpty ?? false)
          ? submission.amNotes!.trim()
          : 'Permanently archived institutional monthly return.';
    } else if (isSealed) {
      statusLabel = 'REGIONALLY SEALED';
      statusVariant = IcareBadgeVariant.info;
      topAccent = tokens.infoDot;
      calloutBg = tokens.infoBg;
      calloutBorder = tokens.infoBorder;
      calloutText = tokens.infoText;
      calloutIcon = Icons.folder_special_outlined;
      attributionLine =
          'Endorsed by ${submission.amName ?? 'Area Manager'} • ${_formatDate(submission.amEndorsedAt ?? submission.submittedAt)}';
      noteLine = (submission.amNotes?.trim().isNotEmpty ?? false)
          ? submission.amNotes!.trim()
          : 'Included in sealed regional package awaiting Admin archival.';
    } else if (isEndorsed) {
      statusLabel = 'AM ENDORSED';
      statusVariant = IcareBadgeVariant.success;
      topAccent = tokens.successDot;
      calloutBg = tokens.successBg;
      calloutBorder = tokens.successBorder;
      calloutText = tokens.successText;
      calloutIcon = Icons.verified_outlined;
      attributionLine =
          'Signed by ${submission.amName ?? 'Area Manager'} • ${_formatDate(submission.amEndorsedAt ?? submission.submittedAt)}';
      noteLine = (submission.amNotes?.trim().isNotEmpty ?? false)
          ? submission.amNotes!.trim()
          : 'Supervisory endorsement complete.';
    } else {
      // DRAFT
      statusLabel = 'PENDING BM';
      statusVariant = IcareBadgeVariant.neutral;
      topAccent = tokens.borderStrong;
      calloutBg = tokens.surfaceSubtle;
      calloutBorder = tokens.borderSubtle;
      calloutText = tokens.textSecondary;
      calloutIcon = Icons.edit_note_rounded;
      attributionLine = 'Books still open with $bmSigner';
      noteLine =
          'Branch Manager has not yet certified and submitted this period return.';
    }

    return IcareCard(
      topAccentColor: topAccent,
      border: isSelected
          ? Border.all(color: tokens.brandPrimary, width: 1.8)
          : Border.all(color: tokens.borderSubtle, width: 1.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      Icons.storefront_outlined,
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
                        Text(
                          '${(submission.areaName?.trim().isNotEmpty ?? false) ? '${submission.areaName!} • ' : ''}BM: $bmSigner',
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
                  if (!isDraft)
                    IcareStatusBadge(
                      label: submission.isGlBalanced
                          ? 'GL BALANCED'
                          : 'GL VARIANCE',
                      variant: submission.isGlBalanced
                          ? IcareBadgeVariant.success
                          : IcareBadgeVariant.danger,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Submission / Review Attribution Callout
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: calloutBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: calloutBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(calloutIcon, size: 15, color: calloutText),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        attributionLine,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: calloutText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  noteLine,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Key Financial Snapshot Strip
          LayoutBuilder(
            builder: (context, constraints) {
              final int cols = constraints.maxWidth >= 420 ? 2 : 2;
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
                    label: 'Physical Vault Cash',
                    value: '₦${_ngnFmt.format(submission.vaultCash)}',
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
                icon: Icon(
                  isSubmitted
                      ? Icons.rate_review_outlined
                      : Icons.fact_check_outlined,
                  size: 15,
                ),
                label: Text(
                  isSubmitted ? 'Review & Endorse' : 'Inspect Statements',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSubmitted
                      ? const Color(0xFFB45309)
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
                  'Preview PDF',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.dangerText,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.dangerBorder),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
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
                    horizontal: 11,
                    vertical: 9,
                  ),
                ),
              ),
              if (isSubmitted && onReturn != null)
                OutlinedButton.icon(
                  onPressed: isBusyWorkflow ? null : onReturn,
                  icon: Icon(
                    Icons.assignment_return_outlined,
                    size: 14,
                    color: tokens.dangerText,
                  ),
                  label: Text(
                    'Return',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.dangerText,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: tokens.dangerBorder),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                  ),
                ),
              if (isSubmitted && onEndorse != null)
                ElevatedButton.icon(
                  onPressed: isBusyWorkflow ? null : onEndorse,
                  icon: const Icon(Icons.check_circle_outline, size: 15),
                  label: const Text(
                    'Endorse',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
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
                fontSize: 12.5,
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
