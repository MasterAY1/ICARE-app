import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_metric_card.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../data/datasources/admin_api_service.dart';
import '../../data/models/admin_dashboard_models.dart';
import '../admin_branch_detail_sheet.dart';
import '../admin_branch_reconciliation_sheet.dart';
import 'admin_approval_actions.dart';
import 'admin_asset_portfolio_pulse_card.dart';
import 'admin_overview_charts.dart';
import 'admin_responsive.dart';

class AdminOverviewTab extends ConsumerWidget {
  final String dateStr;
  final AdminSize size;
  final Future<void> Function(String requestId, bool approve) onReversalDecision;
  final Future<void> Function(String loanId, bool approve) onLoanDecision;

  const AdminOverviewTab({
    super.key,
    required this.dateStr,
    required this.size,
    required this.onReversalDecision,
    required this.onLoanDecision,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opsAsync = ref.watch(adminOperationsProvider(dateStr));
    final tokens = IcareSurfaceTokens.of(context);

    return opsAsync.when(
      loading: () => const Column(
        children: [
          IcareSkeletonLoader(height: 110),
          SizedBox(height: 16),
          IcareSkeletonLoader(height: 180),
          SizedBox(height: 16),
          IcareSkeletonLoader(height: 200),
        ],
      ),
      error: (err, _) {
        final errorDetails = AppErrorDetails.from(err);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.dangerBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.dangerBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.error_outline,
                  color: tokens.dangerDot,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      errorDetails.title.isNotEmpty
                          ? errorDetails.title
                          : 'Unable to Load Institutional Operations',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.dangerText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      errorDetails.message,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: tokens.dangerText,
                      ),
                    ),
                    if (errorDetails.action.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        errorDetails.action,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: tokens.dangerText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => ref.invalidate(adminOperationsProvider(dateStr)),
                style: TextButton.styleFrom(
                  foregroundColor: tokens.dangerText,
                  backgroundColor: tokens.dangerBg,
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
      data: (data) {
        final hasPendingApprovals = data.pendingReversals.isNotEmpty ||
            data.pendingHighLoans.isNotEmpty;

        final chartCard = AdminWeeklyCashFlowChart(
          weekData: data.financialActivityWeek,
          size: size,
        );
        final branchLiquidityChart = AdminBranchLiquidityChart(
          branches: data.branchPerformanceSummary,
          size: size,
        );
        final assetPulseCard = AdminAssetPortfolioPulseCard(size: size);
        final approvalsCard = AdminApprovalsActionCenter(
          data: data,
          size: size,
          onReversalDecision: onReversalDecision,
          onLoanDecision: onLoanDecision,
        );
        final branchCollectionsCard = _buildBranchPerformanceCard(
          context,
          tokens,
          data.branchPerformanceSummary,
          size,
        );
        final reconciliationCard = _buildStatutoryReconciliationPortalCard(
          context,
          tokens,
          data.branchPerformanceSummary,
          size,
        );

        if (size.isExpanded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopKpiGrid(tokens, data, size),
              const SizedBox(height: 12),
              _buildLiquidityKpiStrip(tokens, data, size),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: chartCard),
                  const SizedBox(width: 18),
                  Expanded(flex: 5, child: approvalsCard),
                ],
              ),
              const SizedBox(height: 18),
              branchLiquidityChart,
              const SizedBox(height: 18),
              assetPulseCard,
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: branchCollectionsCard),
                  const SizedBox(width: 18),
                  Expanded(child: reconciliationCard),
                ],
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasPendingApprovals) ...[
              approvalsCard,
              const SizedBox(height: 16),
            ],
            _buildTopKpiGrid(tokens, data, size),
            const SizedBox(height: 12),
            _buildLiquidityKpiStrip(tokens, data, size),
            const SizedBox(height: 16),
            chartCard,
            const SizedBox(height: 16),
            branchLiquidityChart,
            const SizedBox(height: 16),
            assetPulseCard,
            const SizedBox(height: 16),
            branchCollectionsCard,
            const SizedBox(height: 16),
            reconciliationCard,
            if (!hasPendingApprovals) ...[
              const SizedBox(height: 16),
              approvalsCard,
            ],
          ],
        );
      },
    );
  }

  Widget _buildTopKpiGrid(
      IcareSurfaceTokens tokens, AdminOperationsSnapshotModel data, AdminSize size) {
    final ov = data.overview;
    final branches = data.branchPerformanceSummary;
    final hoCount = branches.where((b) => b.isHeadOffice).length;
    final fieldCount = branches.where((b) => !b.isHeadOffice).length;
    final branchSubtitle = branches.isNotEmpty
        ? '$fieldCount field ${fieldCount == 1 ? 'branch' : 'branches'}'
            '${hoCount > 0 ? ' • $hoCount head office' : ''}'
        : '${ov.activeBranchesCount} active across network';

    final cards = [
      _OverviewKpiItem(
        icon: Icons.groups_outlined,
        label: 'Total clients',
        value: ov.totalClientsDisplay,
        subtitle: '${ov.totalClientsCount} registered across branches',
      ),
      _OverviewKpiItem(
        icon: Icons.domain_outlined,
        label: 'Operating branches',
        value: '${ov.activeBranchesCount}',
        subtitle: branchSubtitle,
      ),
      _OverviewKpiItem(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Active loans',
        value: ov.totalPortfolio > 0
            ? CurrencyFormatter.format(ov.totalPortfolio)
            : '₦—',
        subtitle: 'Money out with borrowers',
      ),
      _OverviewKpiItem(
        icon: Icons.trending_up_outlined,
        label: "Today's collections",
        value: ov.todayCollections > 0
            ? CurrencyFormatter.format(ov.todayCollections)
            : '₦—',
        subtitle: 'Repayments received today',
      ),
    ];

    return AdminResponsiveGrid(
      columns: size.isCompact ? 2 : 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: cards.map((item) => _buildCompactKpiCard(tokens, item)).toList(),
    );
  }

  Widget _buildCompactKpiCard(IcareSurfaceTokens tokens, _OverviewKpiItem item) {
    return IcareCard(
      padding: const EdgeInsets.all(14),
      topAccentColor: tokens.brandPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 16, color: tokens.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            style: TextStyle(
              fontSize: 10.5,
              color: tokens.textLight,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLiquidityKpiStrip(
      IcareSurfaceTokens tokens, AdminOperationsSnapshotModel data, AdminSize size) {
    final compText = data.collectionCompliancePct > 0
        ? '${data.collectionCompliancePct.toStringAsFixed(1)}%'
        : '0.0%';
    final netSign = data.todayNetSavings < 0 ? '-' : '';
    final netFormatted =
        '$netSign${CurrencyFormatter.format(data.todayNetSavings.abs())}';

    return AdminResponsiveGrid(
      columns: size.isCompact ? 2 : 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        IcareMetricCard(
          icon: Icons.account_balance_outlined,
          label: 'Vault Cash Custody',
          value: CurrencyFormatter.format(data.vaultCashInCustody),
          delta: 'Consolidated physical branch cash reserves',
          isFullEmerald: true,
        ),
        IcareMetricCard(
          icon: Icons.outbound_outlined,
          label: "Today's Disbursements",
          value: data.todayDisbursements > 0
              ? CurrencyFormatter.format(data.todayDisbursements)
              : '₦0',
          delta: '${data.todayDisbursedCount} loans released today',
          topBorderColor: tokens.infoDot,
          statusTextColor: tokens.infoText,
        ),
        IcareMetricCard(
          icon: Icons.savings_outlined,
          label: "Today's Net Savings",
          value: netFormatted,
          delta:
              'Deposits ${CurrencyFormatter.format(data.todaySavingsDeposit)} • Withdrawals ${CurrencyFormatter.format(data.todaySavingsWithdrawal)}',
          topBorderColor: data.todayNetSavings >= 0
              ? tokens.successDot
              : tokens.warningDot,
          statusTextColor: data.todayNetSavings >= 0
              ? tokens.successText
              : tokens.warningText,
        ),
        IcareMetricCard(
          icon: Icons.fact_check_outlined,
          label: 'Schedule Compliance',
          value: compText,
          delta: data.collectionCompliancePct > 0
              ? 'Paid vs due across active schedules'
              : 'No due installments recorded up to date',
          topBorderColor: data.collectionCompliancePct >= 90
              ? tokens.successDot
              : (data.collectionCompliancePct > 0
                  ? tokens.warningDot
                  : tokens.borderStrong),
          statusTextColor: data.collectionCompliancePct >= 90
              ? tokens.successText
              : (data.collectionCompliancePct > 0
                  ? tokens.warningText
                  : tokens.textMuted),
        ),
      ],
    );
  }

  Widget _buildBranchPerformanceCard(
    BuildContext context,
    IcareSurfaceTokens tokens,
    List<BranchPerformanceRowModel> branches,
    AdminSize size,
  ) {
    final isCompact = size.isCompact;

    return IcareCard(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Branch Collections",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Money collected today by each branch',
                      style: TextStyle(fontSize: 11, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Tap branch for detail',
                style: TextStyle(fontSize: 11, color: tokens.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (branches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No branch collection records found for today.',
                  style: TextStyle(fontSize: 12, color: tokens.textLight),
                ),
              ),
            )
          else
            ...branches.asMap().entries.map((entry) {
              return _buildBranchPerformanceRow(
                context,
                tokens,
                entry.value,
                entry.key + 1,
              );
            }),
          const SizedBox(height: 14),
          Divider(height: 1, color: tokens.borderSubtle),
          const SizedBox(height: 10),
          Text(
            'Numbers update live as collections are recorded and approved.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: tokens.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchPerformanceRow(
    BuildContext context,
    IcareSurfaceTokens tokens,
    BranchPerformanceRowModel b,
    int rank,
  ) {
    if (b.isHeadOffice) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.borderStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tokens.brandPrimaryDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              b.branchName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.surfaceHover,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Head Office • Treasury',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Vault cash: ${CurrencyFormatter.format(b.vaultCash)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.successText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Treasury Hub',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: tokens.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => AdminBranchDetailSheet.show(
        context,
        branchId: b.branchId,
        branchName: b.branchName,
      ),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: rank <= 3
                              ? tokens.brandPrimaryDark
                              : tokens.surfaceHover,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            '#$rank',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: rank <= 3
                                  ? Colors.white
                                  : tokens.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          b.branchName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '(${b.managerName})',
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      b.volume > 0 ? CurrencyFormatter.format(b.volume) : '₦—',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: tokens.textLight,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: b.relativePct.clamp(0.04, 1.0),
                minHeight: 4,
                backgroundColor: tokens.surfaceHover,
                valueColor:
                    AlwaysStoppedAnimation<Color>(tokens.successDot),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatutoryReconciliationPortalCard(
    BuildContext context,
    IcareSurfaceTokens tokens,
    List<BranchPerformanceRowModel> branches,
    AdminSize size,
  ) {
    final isCompact = size.isCompact;

    return IcareCard(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        size: 18,
                        color: tokens.brandPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Branch Statutory Reconciliations & Opening Baselines (B/F)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Input and manage physical paper returns, bank balances, and brought-forward ledgers',
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isCompact) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => AdminBranchReconciliationSheet.show(context),
                  icon: const Icon(
                    Icons.tune_outlined,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Open B/F Portal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (isCompact) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => AdminBranchReconciliationSheet.show(context),
                icon: const Icon(
                  Icons.tune_outlined,
                  size: 15,
                  color: Colors.white,
                ),
                label: const Text(
                  'Open Statutory Reconciliation Portal',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.brandPrimaryDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (branches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No active branches found.',
                  style: TextStyle(fontSize: 12, color: tokens.textLight),
                ),
              ),
            )
          else
            ...branches.where((b) => !b.isHeadOffice).map((b) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: tokens.surfaceHover,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.domain_outlined,
                              size: 14,
                              color: tokens.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.branchName,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Manager: ${b.managerName}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: tokens.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        AdminBranchReconciliationSheet.show(
                          context,
                          branchId: b.branchId,
                          branchName: b.branchName,
                        );
                      },
                      icon: Icon(
                        Icons.edit_note_outlined,
                        size: 15,
                        color: tokens.brandPrimary,
                      ),
                      label: Text(
                        isCompact ? 'B/F' : 'Input / Manage B/F',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tokens.brandPrimary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: tokens.surface,
                        side: BorderSide(color: tokens.brandSoftBorder),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _OverviewKpiItem {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

  const _OverviewKpiItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });
}
