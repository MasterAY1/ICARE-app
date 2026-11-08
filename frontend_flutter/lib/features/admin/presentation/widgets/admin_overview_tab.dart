import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../data/datasources/admin_api_service.dart';
import '../../data/models/admin_dashboard_models.dart';
import '../admin_branch_detail_sheet.dart';
import '../admin_branch_reconciliation_sheet.dart';
import '../admin_dashboard_screen.dart';
import 'admin_approval_actions.dart';
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
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.error_outline,
                  color: Color(0xFFDC2626),
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      errorDetails.message,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                    if (errorDetails.action.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        errorDetails.action,
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF7F1D1D),
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
                  foregroundColor: const Color(0xFF991B1B),
                  backgroundColor: const Color(0xFFFEE2E2),
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

        final chartCard = _buildFinancialActivityCard(
          context,
          ref,
          data.financialActivityWeek,
          size,
        );
        final approvalsCard = AdminApprovalsActionCenter(
          data: data,
          size: size,
          onReversalDecision: onReversalDecision,
          onLoanDecision: onLoanDecision,
        );
        final branchCollectionsCard = _buildBranchPerformanceCard(
          context,
          data.branchPerformanceSummary,
          size,
        );
        final reconciliationCard = _buildStatutoryReconciliationPortalCard(
          context,
          data.branchPerformanceSummary,
          size,
        );

        if (size.isExpanded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopKpiGrid(data, size),
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
            _buildTopKpiGrid(data, size),
            const SizedBox(height: 16),
            chartCard,
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

  Widget _buildTopKpiGrid(AdminOperationsSnapshotModel data, AdminSize size) {
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
      children: cards.map(_buildCompactKpiCard).toList(),
    );
  }

  Widget _buildCompactKpiCard(_OverviewKpiItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 16, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF94A3B8),
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialActivityCard(
    BuildContext context,
    WidgetRef ref,
    List<FinancialActivityDayModel> weekData,
    AdminSize size,
  ) {
    final showFull7d = ref.watch(adminCalendarMode7dProvider);
    final displayedDays = showFull7d
        ? weekData
        : weekData.where((d) => d.day != 'Sat' && d.day != 'Sun').toList();

    double maxVol = 1.0;
    for (final d in displayedDays) {
      if (d.collections > maxVol) maxVol = d.collections;
      if (d.disbursements > maxVol) maxVol = d.disbursements;
    }

    final isCompact = size.isCompact;

    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Cash Flow',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Money collected vs loans given out Monday to Friday',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => ref
                    .read(adminCalendarMode7dProvider.notifier)
                    .state = !showFull7d,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    showFull7d ? 'All 7 Days' : 'Work Days Only (Mon–Fri)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _buildLegendItem('Money Collected', const Color(0xFF059669)),
              _buildLegendItem('Loans Given Out', const Color(0xFF3B82F6)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: displayedDays.map((d) {
                final isNonWorking = !d.isWorkingDay;
                final colRatio = (d.collections / maxVol).clamp(0.04, 1.0);
                final disbRatio = (d.disbursements / maxVol).clamp(0.04, 1.0);
                final colHeight = d.collections > 0 ? (90.0 * colRatio) : 4.0;
                final disbHeight =
                    d.disbursements > 0 ? (90.0 * disbRatio) : 4.0;

                final netChange = d.collections - d.disbursements;
                final netFormatted = CurrencyFormatter.format(netChange.abs());
                final netSign =
                    netChange >= 0 ? '+$netFormatted' : '-$netFormatted';

                return Expanded(
                  child: Tooltip(
                    message: '${d.day} (${d.date})\n'
                        'Collected: ${CurrencyFormatter.format(d.collections)}\n'
                        'Loans given out: ${CurrencyFormatter.format(d.disbursements)}\n'
                        'Difference: $netSign'
                        '${isNonWorking ? '\n(${d.statusReason})' : ''}',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isNonWorking)
                          Container(
                            height: 28,
                            width: isCompact ? 32 : 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Closed',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: isCompact ? 12 : 18,
                                height: colHeight,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF059669),
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Container(
                                width: isCompact ? 12 : 18,
                                height: disbHeight,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF3B82F6),
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        Text(
                          d.day,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isNonWorking
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: isNonWorking
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildBranchPerformanceCard(
    BuildContext context,
    List<BranchPerformanceRowModel> branches,
    AdminSize size,
  ) {
    final isCompact = size.isCompact;

    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
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
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Money collected today by each branch',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Tap branch for detail',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (branches.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No branch collection records found for today.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...branches.asMap().entries.map((entry) {
              return _buildBranchPerformanceRow(
                context,
                entry.value,
                entry.key + 1,
              );
            }),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          const Text(
            'Numbers update live as collections are recorded and approved.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchPerformanceRow(
    BuildContext context,
    BranchPerformanceRowModel b,
    int rank,
  ) {
    if (b.isHeadOffice) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
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
                      color: const Color(0xFF0F172A),
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
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Head Office • Treasury',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Vault cash: ${CurrencyFormatter.format(b.vaultCash)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Treasury Hub',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Color(0xFF64748B),
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
                              ? const Color(0xFF022C22)
                              : const Color(0xFFF1F5F9),
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
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          b.branchName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '(${b.managerName})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFF94A3B8),
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
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatutoryReconciliationPortalCard(
    BuildContext context,
    List<BranchPerformanceRowModel> branches,
    AdminSize size,
  ) {
    final isCompact = size.isCompact;

    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
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
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCCFBF1)),
                      ),
                      child: const Icon(
                        Icons.account_balance_outlined,
                        size: 18,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Branch Statutory Reconciliations & Opening Baselines (B/F)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Input and manage physical paper returns, bank balances, and brought-forward ledgers',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
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
                    backgroundColor: const Color(0xFF0F766E),
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
                  backgroundColor: const Color(0xFF0F766E),
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No active branches found.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.domain_outlined,
                              size: 14,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.branchName,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Manager: ${b.managerName}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
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
                      icon: const Icon(
                        Icons.edit_note_outlined,
                        size: 15,
                        color: Color(0xFF0F766E),
                      ),
                      label: Text(
                        isCompact ? 'B/F' : 'Input / Manage B/F',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF99F6E4)),
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
