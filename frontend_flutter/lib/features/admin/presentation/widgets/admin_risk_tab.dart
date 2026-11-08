import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../data/datasources/admin_api_service.dart';
import '../../data/models/admin_dashboard_models.dart';
import '../admin_branch_detail_sheet.dart';
import '../admin_dashboard_screen.dart';
import 'admin_responsive.dart';

class AdminRiskTab extends ConsumerWidget {
  final AdminSize size;

  const AdminRiskTab({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riskAsync = ref.watch(adminRiskHealthProvider);
    final year = ref.watch(adminPerformanceYearProvider);
    final perfAsync = ref.watch(institutionPerformanceProvider(year));

    return riskAsync.when(
      loading: () => const Column(
        children: [
          IcareSkeletonLoader(height: 150),
          SizedBox(height: 16),
          IcareSkeletonLoader(height: 220),
        ],
      ),
      error: (err, _) {
        final errorDetails = AppErrorDetails.from(err);
        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFDC2626),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${errorDetails.title}: ${errorDetails.message}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF991B1B),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(adminRiskHealthProvider),
                child: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
      data: (risk) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroRiskCard(risk, size),
            const SizedBox(height: 16),
            _buildRiskMetricsGrid(risk, size),
            const SizedBox(height: 16),
            perfAsync.maybeWhen(
              data: (perf) => _buildBranchRiskBreakdown(
                context,
                perf.branchRankings,
                size,
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroRiskCard(AdminRiskHealthModel risk, AdminSize size) {
    final isElevated = risk.parPct > 10.0;
    final accentColor = isElevated
        ? const Color(0xFFDC2626)
        : const Color(0xFF059669);
    final badgeBg = isElevated
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFECFDF5);
    final badgeBorder = isElevated
        ? const Color(0xFFFECACA)
        : const Color(0xFFA7F3D0);
    final statusLabel = isElevated
        ? 'Needs Attention • Above 10% Limit'
        : 'Healthy • Within 10% Limit';

    return Container(
      padding: EdgeInsets.all(size.isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loan Health & Risk Indicators',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Share of active loans with late repayments across all branches',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${risk.parPct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'At-Risk Loans (Late Payments) • Active Loan Book: ${CurrencyFormatter.format(risk.totalActiveCredit)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (risk.parPct / 30.0).clamp(0.03, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskMetricsGrid(AdminRiskHealthModel risk, AdminSize size) {
    final columns = size.isCompact
        ? 1
        : size.isMedium
            ? 2
            : 4;

    final items = [
      _RiskMetricCardData(
        icon: Icons.restore_outlined,
        label: 'Late Repayments Recovered',
        value: CurrencyFormatter.format(risk.totalOverdueRecovered),
        subtitle: '${risk.recoveryEventsCount} recovery payments recorded',
        color: const Color(0xFF0284C7),
      ),
      _RiskMetricCardData(
        icon: Icons.task_alt_outlined,
        label: 'Early Full Payoffs',
        value: CurrencyFormatter.format(risk.fullPayoffsSettledAmount),
        subtitle: '${risk.fullPayoffCount} loans paid off early',
        color: const Color(0xFF047857),
      ),
      _RiskMetricCardData(
        icon: Icons.add_chart_outlined,
        label: 'Extra Cash Collected',
        value: CurrencyFormatter.format(risk.excessCashCollected),
        subtitle: 'Surplus paid above scheduled instalments',
        color: const Color(0xFF0F766E),
      ),
      _RiskMetricCardData(
        icon: Icons.verified_user_outlined,
        label: 'Clients Fully Cleared',
        value: '${risk.fullClientRestorations} Borrowers',
        subtitle: 'Moved from overdue back to good standing',
        color: const Color(0xFF334155),
      ),
    ];

    return AdminResponsiveGrid(
      columns: columns,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: items.map(_buildRiskMetricTile).toList(),
    );
  }

  Widget _buildRiskMetricTile(_RiskMetricCardData item) {
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
              Icon(item.icon, size: 16, color: item.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
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
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: item.color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            style: const TextStyle(
              fontSize: 11,
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

  Widget _buildBranchRiskBreakdown(
    BuildContext context,
    List<BranchPerformanceItemModel> branches,
    AdminSize size,
  ) {
    if (branches.isEmpty) return const SizedBox.shrink();

    final sorted = List<BranchPerformanceItemModel>.from(branches)
      ..sort((a, b) {
        final cmp = b.parPct.compareTo(a.parPct);
        if (cmp != 0) return cmp;
        return b.overdueAmount.compareTo(a.overdueAmount);
      });

    final columns = size.isExpanded ? 2 : 1;

    return Container(
      padding: EdgeInsets.all(size.isCompact ? 14 : 18),
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
                      'Which Branches Need Attention',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Branches ordered by late-payment percentage (highest first)',
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
          AdminResponsiveGrid(
            columns: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 10,
            children: sorted
                .map((b) => _buildBranchRiskRow(context, b))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchRiskRow(
    BuildContext context,
    BranchPerformanceItemModel b,
  ) {
    final isHighRisk = b.parPct > 10.0;
    final statusColor = isHighRisk
        ? const Color(0xFFDC2626)
        : const Color(0xFF059669);

    return InkWell(
      onTap: () => AdminBranchDetailSheet.show(
        context,
        branchId: b.branchId,
        branchName: b.branchName,
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isHighRisk
                ? const Color(0xFFFECACA)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.branchName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Manager: ${b.bmName} • ${b.defaultersCount} late borrowers',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHighRisk
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Late ${b.parPct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (b.parPct / 25.0).clamp(0.03, 1.0),
                minHeight: 4,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Overdue: ${CurrencyFormatter.format(b.overdueAmount)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'Active loans: ${CurrencyFormatter.format(b.activeCreditBook)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (b.overdueRecovered > 0)
                  Text(
                    'Recovered: ${CurrencyFormatter.format(b.overdueRecovered)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0284C7),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskMetricCardData {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _RiskMetricCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });
}
