import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error_formatter.dart';
import '../../../core/theme/icare_motion.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../data/datasources/admin_api_service.dart';
import '../data/models/admin_dashboard_models.dart';
import 'admin_branch_reconciliation_sheet.dart';

class AdminBranchDetailSheet extends ConsumerWidget {
  final String branchId;
  final String? initialBranchName;

  const AdminBranchDetailSheet({
    super.key,
    required this.branchId,
    this.initialBranchName,
  });

  static Future<void> show(BuildContext context, {required String branchId, String? branchName}) {
    return showIcareAdaptiveSheet<void>(
      context: context,
      mobileHeightFactor: 0.88,
      peekHeightFactor: 0.56,
      desktopConstraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
      builder: (_, __) => AdminBranchDetailSheet(
        branchId: branchId,
        initialBranchName: branchName,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(adminBranchDetailProvider(branchId));
    final tokens = IcareSurfaceTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle on mobile
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.surfaceHover,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.domain_outlined, size: 20, color: tokens.textPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        initialBranchName ?? 'Operational Branch Detail',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                        softWrap: true,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Operational pulse, vault liquidity & credit quality',
                        style: TextStyle(fontSize: 12, color: tokens.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: tokens.textMuted, size: 20),
                  splashRadius: 20,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.borderSubtle),

          // Body Content
          Expanded(
            child: detailAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    IcareSkeletonLoader(height: 80),
                    SizedBox(height: 12),
                    IcareSkeletonLoader(height: 140),
                    SizedBox(height: 12),
                    IcareSkeletonLoader(height: 120),
                  ],
                ),
              ),
              error: (err, _) {
                final errorDetails = AppErrorDetails.from(err);
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 36, color: tokens.dangerDot),
                        const SizedBox(height: 12),
                        Text(
                          errorDetails.title.isNotEmpty ? errorDetails.title : 'Unable to load branch details',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tokens.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          errorDetails.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: tokens.textMuted),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(adminBranchDetailProvider(branchId)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.brandPrimaryDark,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              data: (data) => _buildDetailContent(context, tokens, data),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailContent(
      BuildContext context, IcareSurfaceTokens tokens, AdminBranchDetailModel data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Branch Manager & Operational State Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: tokens.surfaceHover,
                  child: Icon(Icons.person_outline, color: tokens.textSecondary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.managerName,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Branch Manager • ${data.branchName}',
                        style: TextStyle(fontSize: 12, color: tokens.textMuted),
                      ),
                    ],
                  ),
                ),
                _buildStatusPill(tokens, data.operationalStatus),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Primary Vault Cash & Liquidity Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Primary Vault Reserve',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textMuted),
                    ),
                    Icon(Icons.account_balance_wallet_outlined, size: 16, color: tokens.textMuted),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.format(data.vaultCashInCustody),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: tokens.brandPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: tokens.borderSubtle),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSubMetric(tokens, 'Collections Today', CurrencyFormatter.format(data.todayCollections)),
                    _buildSubMetric(tokens, 'Disbursed YTD', CurrencyFormatter.format(data.totalDisbursedYtd)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Button: Statutory Reconciliation & Opening B/F
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                AdminBranchReconciliationSheet.show(
                  context,
                  branchId: branchId,
                  branchName: data.branchName,
                );
              },
              icon: Icon(Icons.account_balance_outlined, size: 16, color: tokens.brandSoftText),
              label: Text(
                'Branch Statutory Reconciliation & Opening B/F',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.brandSoftText),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: tokens.brandSoftBg,
                side: BorderSide(color: tokens.brandSoftBorder),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Active Portfolio & Risk Health
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Portfolio & Credit Risk Overview',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildRiskTile(
                        tokens,
                        'Active Credit Book',
                        CurrencyFormatter.format(data.activeCreditBook),
                        '${data.activeBorrowersCount} active borrowers',
                        tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildRiskTile(
                        tokens,
                        'Portfolio at Risk (PAR)',
                        '${data.parPct.toStringAsFixed(1)}%',
                        '${data.defaultersCount} overdue contracts',
                        data.parPct > 10.0 ? tokens.dangerText : tokens.successText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildRiskTile(
                        tokens,
                        'Overdue Arrears Pool',
                        CurrencyFormatter.format(data.overdueAmount),
                        'Past contractual maturity',
                        tokens.warningText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildRiskTile(
                        tokens,
                        'Overdue Recovered',
                        CurrencyFormatter.format(data.overdueRecovered),
                        '${data.fullRecoveriesCount} full rehabilitations',
                        tokens.infoText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Stationed Credit Officers
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Field Credit Officers',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                    ),
                    Text(
                      '${data.officersCount} assigned',
                      style: TextStyle(fontSize: 12, color: tokens.textMuted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (data.officers.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'No field officers currently stationed.',
                        style: TextStyle(fontSize: 12, color: tokens.textLight),
                      ),
                    ),
                  ),
                ] else ...[
                  ...data.officers.map((co) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: tokens.surfaceHover,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person_pin, size: 16, color: tokens.textSecondary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            co.name,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                          ),
                        ),
                        Text(
                          '@${co.username}',
                          style: TextStyle(fontSize: 11.5, color: tokens.textLight),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(IcareSurfaceTokens tokens, String status) {
    Color bg = tokens.neutralBg;
    Color fg = tokens.neutralText;
    String label = 'Open';

    final st = status.toUpperCase();
    if (st == 'OPEN') {
      bg = tokens.successBg;
      fg = tokens.successText;
      label = 'Active Open';
    } else if (st == 'EOD_PENDING') {
      bg = tokens.warningBg;
      fg = tokens.warningText;
      label = 'EOD Pending';
    } else if (st == 'CLOSED') {
      bg = tokens.neutralBg;
      fg = tokens.neutralText;
      label = 'Day Closed';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildSubMetric(IcareSurfaceTokens tokens, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: tokens.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildRiskTile(
      IcareSurfaceTokens tokens, String label, String value, String subtext, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: tokens.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(subtext, style: TextStyle(fontSize: 10.5, color: tokens.textLight)),
        ],
      ),
    );
  }
}
