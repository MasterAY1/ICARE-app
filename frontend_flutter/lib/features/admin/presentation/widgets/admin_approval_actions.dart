import 'package:flutter/material.dart';

import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../../data/models/admin_dashboard_models.dart';
import 'admin_responsive.dart';

/// Shows a confirmation dialog before approving or declining a reversal or loan.
/// Returns `true` only when the administrator explicitly confirms.
Future<bool> showAdminApprovalConfirmDialog({
  required BuildContext context,
  required String title,
  required String branchName,
  required String summaryLine,
  required String consequenceText,
  required String confirmLabel,
  required bool isPositiveAction,
}) async {
  final result = await showIcareDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final tokens = IcareSurfaceTokens.of(ctx);
      final accentColor = isPositiveAction
          ? tokens.successDot
          : tokens.dangerDot;
      final solidActionBg = isPositiveAction
          ? const Color(0xFF059669)
          : const Color(0xFFDC2626);
      final bgTint = isPositiveAction
          ? tokens.successBg
          : tokens.dangerBg;
      final borderTint = isPositiveAction
          ? tokens.successBorder
          : tokens.dangerBorder;

      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: tokens.borderSubtle),
        ),
        backgroundColor: tokens.surface,
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgTint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderTint),
              ),
              child: Icon(
                isPositiveAction
                    ? Icons.verified_outlined
                    : Icons.warning_amber_rounded,
                size: 20,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branchName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summaryLine,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                consequenceText,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: tokens.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: solidActionBg,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              confirmLabel,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );
  return result == true;
}

/// Action center card for pending reversals and high-value loans (> ₦300,000),
/// with confirmation modal, in-flight button locks, and adaptive mobile/desktop layout.
class AdminApprovalsActionCenter extends StatefulWidget {
  final AdminOperationsSnapshotModel data;
  final AdminSize size;
  final Future<void> Function(String requestId, bool approve) onReversalDecision;
  final Future<void> Function(String loanId, bool approve) onLoanDecision;

  const AdminApprovalsActionCenter({
    super.key,
    required this.data,
    required this.size,
    required this.onReversalDecision,
    required this.onLoanDecision,
  });

  @override
  State<AdminApprovalsActionCenter> createState() =>
      _AdminApprovalsActionCenterState();
}

class _AdminApprovalsActionCenterState
    extends State<AdminApprovalsActionCenter> {
  final Set<String> _inFlightIds = <String>{};

  Future<void> _confirmAndRunReversal(
    PendingReversalItemModel item,
    bool approve,
  ) async {
    final key = 'rev_${item.requestId}';
    if (_inFlightIds.contains(key)) return;

    final confirmed = await showAdminApprovalConfirmDialog(
      context: context,
      title: approve ? 'Approve Correction Request?' : 'Reject Correction Request?',
      branchName: 'Branch: ${item.branchName}',
      summaryLine: '${item.recordType} • Reason: ${item.reason}',
      consequenceText: approve
          ? 'Approving this request will post an official reversing entry to the ledger. This action cannot be undone.'
          : 'Rejecting this request will leave the original entry unchanged and close the request.',
      confirmLabel: approve ? 'Yes, Approve Reversal' : 'Yes, Reject Request',
      isPositiveAction: approve,
    );

    if (!confirmed || !mounted) return;

    setState(() => _inFlightIds.add(key));
    try {
      await widget.onReversalDecision(item.requestId, approve);
    } finally {
      if (mounted) {
        setState(() => _inFlightIds.remove(key));
      }
    }
  }

  Future<void> _confirmAndRunLoan(
    PendingHighLoanItemModel item,
    bool approve,
  ) async {
    final key = 'loan_${item.loanId}';
    if (_inFlightIds.contains(key)) return;

    final formattedAmt = CurrencyFormatter.format(item.loanAmount);
    final confirmed = await showAdminApprovalConfirmDialog(
      context: context,
      title: approve ? 'Approve Large Loan?' : 'Decline Large Loan?',
      branchName: 'Branch: ${item.branchName}',
      summaryLine: 'Loan Amount: $formattedAmt',
      consequenceText: approve
          ? 'Approving this loan authorizes disbursement of $formattedAmt and updates the branch vault ledger.'
          : 'Declining this application will cancel the loan request.',
      confirmLabel: approve ? 'Yes, Approve Loan' : 'Yes, Decline Loan',
      isPositiveAction: approve,
    );

    if (!confirmed || !mounted) return;

    setState(() => _inFlightIds.add(key));
    try {
      await widget.onLoanDecision(item.loanId, approve);
    } finally {
      if (mounted) {
        setState(() => _inFlightIds.remove(key));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reversals = widget.data.pendingReversals;
    final highLoans = widget.data.pendingHighLoans;
    final totalWaiting = reversals.length + highLoans.length;
    final isCompact = widget.size.isCompact;
    final tokens = IcareSurfaceTokens.of(context);

    return IcareCard(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      border: Border.all(
        color: totalWaiting > 0 ? tokens.dangerBorder : tokens.borderSubtle,
      ),
      topAccentColor: totalWaiting > 0 ? tokens.dangerDot : tokens.successDot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Requests Waiting for Your Decision',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Review and decide on error corrections and large loans',
                      style: TextStyle(fontSize: 11, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IcareStatusBadge(
                label: '$totalWaiting Waiting',
                variant: totalWaiting > 0
                    ? IcareBadgeVariant.danger
                    : IcareBadgeVariant.neutral,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (reversals.isEmpty && highLoans.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 22,
                    color: tokens.successDot,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No pending requests. Everything is up to date.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (reversals.isNotEmpty) ...[
              Text(
                'Correction Requests Waiting for Approval',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              ...reversals.map((r) => _buildReversalRow(tokens, r, isCompact)),
              if (highLoans.isNotEmpty) const SizedBox(height: 12),
            ],
            if (highLoans.isNotEmpty) ...[
              Text(
                'Large Loan Requests (Over ₦300,000)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              ...highLoans.map((l) => _buildHighLoanRow(tokens, l, isCompact)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildReversalRow(
      IcareSurfaceTokens tokens, PendingReversalItemModel r, bool stackButtons) {
    final isBusy = _inFlightIds.contains('rev_${r.requestId}');

    final infoColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${r.branchName} • ${r.recordType}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Reason: ${r.reason}',
          style: TextStyle(fontSize: 11.5, color: tokens.textSecondary),
        ),
        Text(
          'Requested by: ${r.requestedBy}',
          style: TextStyle(fontSize: 10.5, color: tokens.textLight),
        ),
      ],
    );

    final approveBtn = ElevatedButton(
      onPressed: isBusy ? null : () => _confirmAndRunReversal(r, true),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        disabledBackgroundColor: tokens.borderStrong,
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size(stackButtons ? 0 : 72, stackButtons ? 38 : 32),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: isBusy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Approve',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
    );

    final rejectBtn = OutlinedButton(
      onPressed: isBusy ? null : () => _confirmAndRunReversal(r, false),
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.dangerText,
        side: BorderSide(color: tokens.dangerBorder),
        backgroundColor: tokens.dangerBg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size(stackButtons ? 0 : 68, stackButtons ? 38 : 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: const Text(
        'Reject',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: stackButtons
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoColumn,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: approveBtn),
                    const SizedBox(width: 8),
                    Expanded(child: rejectBtn),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: infoColumn),
                const SizedBox(width: 12),
                approveBtn,
                const SizedBox(width: 8),
                rejectBtn,
              ],
            ),
    );
  }

  Widget _buildHighLoanRow(
      IcareSurfaceTokens tokens, PendingHighLoanItemModel l, bool stackButtons) {
    final isBusy = _inFlightIds.contains('loan_${l.loanId}');

    final infoColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l.branchName} • ${CurrencyFormatter.format(l.loanAmount)}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Borrower current loan: ${CurrencyFormatter.format(l.activeCredit)}',
          style: TextStyle(fontSize: 11.5, color: tokens.textSecondary),
        ),
      ],
    );

    final approveBtn = ElevatedButton(
      onPressed: isBusy ? null : () => _confirmAndRunLoan(l, true),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        disabledBackgroundColor: tokens.borderStrong,
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size(stackButtons ? 0 : 84, stackButtons ? 38 : 32),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: isBusy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Approve Loan',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
    );

    final declineBtn = OutlinedButton(
      onPressed: isBusy ? null : () => _confirmAndRunLoan(l, false),
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.dangerText,
        side: BorderSide(color: tokens.dangerBorder),
        backgroundColor: tokens.dangerBg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size(stackButtons ? 0 : 68, stackButtons ? 38 : 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: const Text(
        'Decline',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: stackButtons
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoColumn,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: approveBtn),
                    const SizedBox(width: 8),
                    Expanded(child: declineBtn),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: infoColumn),
                const SizedBox(width: 12),
                approveBtn,
                const SizedBox(width: 8),
                declineBtn,
              ],
            ),
    );
  }
}
