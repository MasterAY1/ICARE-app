import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../../../shared/presentation/co_app_scaffold.dart';
import '../../data/datasources/admin_api_service.dart';
import '../../data/models/admin_dashboard_models.dart';
import '../admin_branch_reconciliation_sheet.dart';
import '../admin_dashboard_screen.dart';
import 'admin_responsive.dart';

/// Interactive Dual-Track Operational & Governance Flow Visualizer.
/// Connects every stage to live API telemetry (zero static metrics):
/// - Track 0: Credit & Vault Cash Cycle (Origination -> Admin Gate -> Collections -> Vault/EOD -> AM Sign-Off)
/// - Track 1: Asset Financing & Inventory Cycle (Master Catalog -> Branch Stock -> Financing Plans -> Net Asset P&L)
class AdminOperationalFlowCard extends ConsumerStatefulWidget {
  final AdminOperationsSnapshotModel operations;
  final AdminSize size;

  const AdminOperationalFlowCard({
    super.key,
    required this.operations,
    required this.size,
  });

  @override
  ConsumerState<AdminOperationalFlowCard> createState() =>
      _AdminOperationalFlowCardState();
}

class _AdminOperationalFlowCardState
    extends ConsumerState<AdminOperationalFlowCard> {
  int _selectedTrack = 0;

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final riskAsync = ref.watch(adminRiskHealthProvider);
    final procAsync = ref.watch(adminProcurementPulseProvider);
    final ops = widget.operations;

    final fieldBranches =
        ops.branchMatrix.where((b) => !b.isHeadOffice).toList();
    final closedBranchesCount = fieldBranches
        .where((b) => b.operationalStatus.toUpperCase() == 'CLOSED')
        .length;
    final totalPendingDecisions =
        ops.pendingReversalsCount + ops.pendingHighLoansCount;

    final risk = riskAsync.valueOrNull;
    final proc = procAsync.valueOrNull;

    final stages = _selectedTrack == 0
        ? _buildLendingFlowStages(
            context: context,
            tokens: tokens,
            ops: ops,
            risk: risk,
            fieldBranchesCount: fieldBranches.length,
            closedBranchesCount: closedBranchesCount,
            totalPendingDecisions: totalPendingDecisions,
          )
        : _buildAssetFlowStages(
            context: context,
            tokens: tokens,
            proc: proc,
          );

    return IcareCard(
      padding: EdgeInsets.all(widget.size.isCompact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 18,
                    color: tokens.brandPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Institution Capital & Governance Flow',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Live end-to-end money, stock, and executive sign-off stages (tap a node to inspect)',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _trackChip(tokens, 0, 'Credit & Vault Cycle'),
                    _trackChip(tokens, 1, 'Asset & SKU Flow'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.size.isExpanded)
            _buildHorizontalFlow(tokens, stages)
          else
            _buildVerticalFlow(tokens, stages),
        ],
      ),
    );
  }

  Widget _trackChip(IcareSurfaceTokens tokens, int idx, String label) {
    final active = _selectedTrack == idx;
    return InkWell(
      onTap: () => setState(() => _selectedTrack = idx),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: IcareFluidMotion.microDuration,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? tokens.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? tokens.brandPrimary : tokens.textMuted,
          ),
        ),
      ),
    );
  }

  List<_FlowStageData> _buildLendingFlowStages({
    required BuildContext context,
    required IcareSurfaceTokens tokens,
    required AdminOperationsSnapshotModel ops,
    required AdminRiskHealthModel? risk,
    required int fieldBranchesCount,
    required int closedBranchesCount,
    required int totalPendingDecisions,
  }) {
    final parLabel =
        risk != null ? 'PAR ${risk.parPct.toStringAsFixed(1)}%' : 'Risk check';
    final eodLabel = fieldBranchesCount > 0
        ? '$closedBranchesCount/$fieldBranchesCount EOD Closed'
        : '${ops.overview.activeBranchesCount} Branches';

    return [
      _FlowStageData(
        step: '01',
        title: 'Field Origination',
        metric: CurrencyFormatter.format(ops.todayDisbursements),
        caption: '${ops.todayDisbursedCount} disbursed • ${ops.overview.totalClientsDisplay} clients',
        status: ops.todayDisbursedCount > 0 ? 'Active' : 'Idle Today',
        badgeVariant: ops.todayDisbursedCount > 0
            ? IcareBadgeVariant.info
            : IcareBadgeVariant.neutral,
        icon: Icons.real_estate_agent_outlined,
        accent: tokens.infoDot,
        onTap: () =>
            ref.read(activeCoPageProvider.notifier).state = 'Portfolio',
      ),
      _FlowStageData(
        step: '02',
        title: 'Admin Decision Gate',
        metric: '$totalPendingDecisions Pending',
        caption:
            '${ops.pendingHighLoansCount} loans > ₦300k • ${ops.pendingReversalsCount} reversals',
        status: totalPendingDecisions > 0 ? 'Action Needed' : 'Clear',
        badgeVariant: totalPendingDecisions > 0
            ? IcareBadgeVariant.warning
            : IcareBadgeVariant.success,
        icon: Icons.gavel_outlined,
        accent: totalPendingDecisions > 0
            ? tokens.warningDot
            : tokens.successDot,
        onTap: null,
      ),
      _FlowStageData(
        step: '03',
        title: 'Repayments & Compliance',
        metric: CurrencyFormatter.format(ops.todayCollections),
        caption:
            'Schedule compliance ${ops.collectionCompliancePct.toStringAsFixed(1)}% • $parLabel',
        status: ops.collectionCompliancePct >= 90.0
            ? 'On Schedule'
            : (ops.collectionCompliancePct > 0 ? 'Monitor' : 'No Due Items'),
        badgeVariant: ops.collectionCompliancePct >= 90.0
            ? IcareBadgeVariant.success
            : (ops.collectionCompliancePct > 0
                ? IcareBadgeVariant.warning
                : IcareBadgeVariant.neutral),
        icon: Icons.payments_outlined,
        accent: tokens.successDot,
        onTap: () => ref.read(adminActiveTabProvider.notifier).state = 2,
      ),
      _FlowStageData(
        step: '04',
        title: 'Primary Vault & EOD',
        metric: CurrencyFormatter.format(ops.vaultCashInCustody),
        caption:
            'Net savings ${CurrencyFormatter.format(ops.todayNetSavings)} • $eodLabel',
        status: fieldBranchesCount > 0 && closedBranchesCount == fieldBranchesCount
            ? 'EOD Closed'
            : 'Open',
        badgeVariant: fieldBranchesCount > 0 &&
                closedBranchesCount == fieldBranchesCount
            ? IcareBadgeVariant.success
            : IcareBadgeVariant.info,
        icon: Icons.account_balance_outlined,
        accent: tokens.brandPrimary,
        onTap: () => AdminBranchReconciliationSheet.show(context),
      ),
      _FlowStageData(
        step: '05',
        title: 'AM Sign-Off & Archive',
        metric: risk != null ? '${risk.pendingEventBacklog} Queued' : 'Audit Ready',
        caption: 'Only AM-verified monthly packages unlock Executive Seal',
        status: 'Executive Gate',
        badgeVariant: IcareBadgeVariant.info,
        icon: Icons.verified_user_outlined,
        accent: tokens.brandPrimaryDark,
        onTap: () =>
            ref.read(activeCoPageProvider.notifier).state = 'Reports & Export',
      ),
    ];
  }

  List<_FlowStageData> _buildAssetFlowStages({
    required BuildContext context,
    required IcareSurfaceTokens tokens,
    required Map<String, dynamic>? proc,
  }) {
    final inv = Map<String, dynamic>.from(
      (proc?['inventory_summary'] as Map?) ?? const {},
    );
    final pnl = Map<String, dynamic>.from(
      (proc?['pnl_summary'] as Map?) ?? const {},
    );
    final readiness = Map<String, dynamic>.from(
      (proc?['catalog_readiness'] as Map?) ?? const {},
    );

    final totalSkus = (readiness['total_catalog_skus'] as num?)?.toInt() ?? 0;
    final costedSkus =
        (readiness['cost_configured_skus'] as num?)?.toInt() ?? 0;
    final availUnits = (inv['units_available'] as num?)?.toInt() ?? 0;
    final reservedUnits = (inv['units_reserved'] as num?)?.toInt() ?? 0;
    final retailVal =
        (inv['inventory_cash_value'] as num?)?.toDouble() ?? 0.0;
    final unitsSold = (pnl['units_sold'] as num?)?.toInt() ?? 0;
    final pkgRev =
        (pnl['realized_package_revenue'] as num?)?.toDouble() ?? 0.0;
    final netProfit =
        (pnl['net_realized_profit'] as num?)?.toDouble() ?? 0.0;
    final netMargin = (pnl['net_margin_pct'] as num?)?.toDouble() ?? 0.0;

    final bool hasProcData = proc != null;

    return [
      _FlowStageData(
        step: '01',
        title: 'Master SKU Catalog',
        metric: hasProcData ? '$totalSkus SKUs' : 'Read-Only Hub',
        caption: hasProcData
            ? '$costedSkus cost-configured across catalog categories'
            : 'Tap to inspect Master Catalog & wholesale supplier costs',
        status: hasProcData ? 'Synchronized' : 'Inspect',
        badgeVariant:
            hasProcData ? IcareBadgeVariant.success : IcareBadgeVariant.info,
        icon: Icons.sell_outlined,
        accent: tokens.brandPrimary,
        onTap: () => ref.read(activeCoPageProvider.notifier).state =
            'Asset & Procurement',
      ),
      _FlowStageData(
        step: '02',
        title: 'Branch Stock Matrix',
        metric: hasProcData ? '$availUnits Available' : 'Multi-Branch',
        caption: hasProcData
            ? '$reservedUnits reserved • Retail ${CurrencyFormatter.format(retailVal)}'
            : 'Real-time On Hand, Reserved & Available stock tracking',
        status: reservedUnits > 0 ? '$reservedUnits Reserved' : 'Live Matrix',
        badgeVariant: reservedUnits > 0
            ? IcareBadgeVariant.warning
            : IcareBadgeVariant.info,
        icon: Icons.inventory_2_outlined,
        accent: tokens.infoDot,
        onTap: () => ref.read(activeCoPageProvider.notifier).state =
            'Asset & Procurement',
      ),
      _FlowStageData(
        step: '03',
        title: 'Asset Plans & Disburse',
        metric: hasProcData ? '$unitsSold Units Sold' : 'Cash / 60D / 120D',
        caption: hasProcData
            ? 'Package Revenue ${CurrencyFormatter.format(pkgRev)}'
            : 'Cash & Carry (0%) • Easy Buy 60D (+12%) & 120D (+21%)',
        status: unitsSold > 0 ? 'Disbursed' : 'Ready',
        badgeVariant: IcareBadgeVariant.info,
        icon: Icons.shopping_bag_outlined,
        accent: tokens.brandPrimaryLight,
        onTap: () => ref.read(activeCoPageProvider.notifier).state =
            'Asset & Procurement',
      ),
      _FlowStageData(
        step: '04',
        title: 'Realized Asset P&L',
        metric: hasProcData
            ? CurrencyFormatter.format(netProfit)
            : 'Audit View',
        caption: hasProcData
            ? 'Net Margin ${netMargin.toStringAsFixed(1)}% after write-offs'
            : 'Trading margin + Easy Buy markup less damage write-offs',
        status: netProfit >= 0 ? 'Positive Margin' : 'Loss Alert',
        badgeVariant: netProfit >= 0
            ? IcareBadgeVariant.success
            : IcareBadgeVariant.danger,
        icon: Icons.assessment_outlined,
        accent: netProfit >= 0 ? tokens.successDot : tokens.dangerDot,
        onTap: () => ref.read(activeCoPageProvider.notifier).state =
            'Asset & Procurement',
      ),
    ];
  }

  Widget _buildHorizontalFlow(
    IcareSurfaceTokens tokens,
    List<_FlowStageData> stages,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < stages.length; i++) ...[
          Expanded(child: _FlowStageCard(tokens: tokens, stage: stages[i])),
          if (i < stages.length - 1)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: SizedBox(
                width: 22,
                height: 18,
                child: CustomPaint(
                  painter: _HorizontalArrowPainter(
                    color: tokens.brandPrimary.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildVerticalFlow(
    IcareSurfaceTokens tokens,
    List<_FlowStageData> stages,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < stages.length; i++) ...[
          _FlowStageCard(tokens: tokens, stage: stages[i]),
          if (i < stages.length - 1)
            SizedBox(
              height: 22,
              child: CustomPaint(
                painter: _VerticalArrowPainter(
                  color: tokens.brandPrimary.withValues(alpha: 0.45),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Executive Read-Only Asset & Procurement Snapshot Card on Admin Overview.
/// Renders strictly when live `/api/v1/procurement/overview` data is available.
class AdminAssetPortfolioPulseCard extends ConsumerWidget {
  final AdminSize size;

  const AdminAssetPortfolioPulseCard({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final procAsync = ref.watch(adminProcurementPulseProvider);
    final tokens = IcareSurfaceTokens.of(context);

    final proc = procAsync.valueOrNull;
    if (proc == null) {
      return const SizedBox.shrink();
    }

    final inv = Map<String, dynamic>.from(
      (proc['inventory_summary'] as Map?) ?? const {},
    );
    final pnl = Map<String, dynamic>.from(
      (proc['pnl_summary'] as Map?) ?? const {},
    );
    final readiness = Map<String, dynamic>.from(
      (proc['catalog_readiness'] as Map?) ?? const {},
    );

    final availUnits = (inv['units_available'] as num?)?.toInt() ?? 0;
    final reservedUnits = (inv['units_reserved'] as num?)?.toInt() ?? 0;
    final cashVal = (inv['inventory_cash_value'] as num?)?.toDouble() ?? 0.0;
    final costVal = (inv['inventory_cost_value'] as num?)?.toDouble() ?? 0.0;
    final netProfit = (pnl['net_realized_profit'] as num?)?.toDouble() ?? 0.0;
    final unitsSold = (pnl['units_sold'] as num?)?.toInt() ?? 0;
    final configured =
        (readiness['cost_configured_skus'] as num?)?.toInt() ?? 0;
    final totalSkus = (readiness['total_catalog_skus'] as num?)?.toInt() ?? 0;

    return IcareCard(
      padding: EdgeInsets.all(size.isCompact ? 14 : 18),
      topAccentColor: tokens.brandPrimaryLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tokens.brandSoftBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.brandSoftBorder),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
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
                          'Asset Financing & Stock Pulse (Read-Only)',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          '$configured / $totalSkus catalog SKUs cost-configured across branches',
                          style:
                              TextStyle(fontSize: 11.5, color: tokens.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => ref.read(activeCoPageProvider.notifier).state =
                    'Asset & Procurement',
                icon: const Icon(Icons.visibility_outlined, size: 15),
                label: const Text('Inspect Asset Hub'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.brandPrimary,
                  side: BorderSide(color: tokens.brandSoftBorder),
                  backgroundColor: tokens.brandSoftBg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AdminResponsiveGrid(
            columns: size.isCompact ? 2 : 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _MiniAssetStat(
                tokens: tokens,
                label: 'Available Units',
                value: '$availUnits',
                sub: '$reservedUnits reserved on pending loans',
              ),
              _MiniAssetStat(
                tokens: tokens,
                label: 'Retail Stock Value',
                value: CurrencyFormatter.format(cashVal),
                sub: costVal > 0
                    ? 'Wholesale Cost: ${CurrencyFormatter.format(costVal)}'
                    : 'Wholesale cost pending',
              ),
              _MiniAssetStat(
                tokens: tokens,
                label: 'Units Financed / Sold',
                value: '$unitsSold',
                sub: 'Cash & Carry + Easy Buy 60D/120D',
              ),
              _MiniAssetStat(
                tokens: tokens,
                label: 'Net Realized Asset P&L',
                value: CurrencyFormatter.format(netProfit),
                sub: 'After markup & write-off deductions',
                accent: netProfit >= 0 ? tokens.successText : tokens.dangerText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowStageData {
  final String step;
  final String title;
  final String metric;
  final String caption;
  final String status;
  final IcareBadgeVariant badgeVariant;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const _FlowStageData({
    required this.step,
    required this.title,
    required this.metric,
    required this.caption,
    required this.status,
    required this.badgeVariant,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
}

class _FlowStageCard extends StatelessWidget {
  final IcareSurfaceTokens tokens;
  final _FlowStageData stage;

  const _FlowStageCard({required this.tokens, required this.stage});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: stage.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(stage.icon, size: 15, color: stage.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${stage.step} • ${stage.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
              if (stage.onTap != null)
                Icon(
                  Icons.open_in_new,
                  size: 13,
                  color: tokens.textLight,
                ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              stage.metric,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stage.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: tokens.textMuted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          IcareStatusBadge(
            label: stage.status,
            variant: stage.badgeVariant,
          ),
        ],
      ),
    );

    if (stage.onTap == null) return content;

    return IcareTactileScale(
      child: InkWell(
        onTap: stage.onTap,
        borderRadius: BorderRadius.circular(10),
        child: content,
      ),
    );
  }
}

class _MiniAssetStat extends StatelessWidget {
  final IcareSurfaceTokens tokens;
  final String label;
  final String value;
  final String sub;
  final Color? accent;

  const _MiniAssetStat({
    required this.tokens,
    required this.label,
    required this.value,
    required this.sub,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tokens.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: accent ?? tokens.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: tokens.textLight),
          ),
        ],
      ),
    );
  }
}

class _HorizontalArrowPainter extends CustomPainter {
  final Color color;
  _HorizontalArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final y = size.height * 0.5;
    canvas.drawLine(Offset(2, y), Offset(size.width - 4, y), paint);

    final head = Path()
      ..moveTo(size.width - 9, y - 4)
      ..lineTo(size.width - 3, y)
      ..lineTo(size.width - 9, y + 4);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant _HorizontalArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _VerticalArrowPainter extends CustomPainter {
  final Color color;
  _VerticalArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const x = 22.0;
    canvas.drawLine(const Offset(x, 2), Offset(x, size.height - 3), paint);

    final head = Path()
      ..moveTo(x - 4, size.height - 8)
      ..lineTo(x, size.height - 2)
      ..lineTo(x + 4, size.height - 8);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant _VerticalArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
