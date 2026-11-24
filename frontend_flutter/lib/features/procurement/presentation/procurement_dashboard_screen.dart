import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/app_error_formatter.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import '../data/datasources/procurement_api_service.dart';
import 'asset_procurement_screen.dart';

/// Executive Dashboard dedicated to the Procurement Officer role.
/// Displays institution-wide physical asset portfolio, branch stock share,
/// supplier cost readiness, category breakdown, realized P&L, and movement ledger,
/// with direct workflow shortcuts into the Asset & Procurement workspace.
class ProcurementDashboardScreen extends ConsumerStatefulWidget {
  const ProcurementDashboardScreen({super.key});

  @override
  ConsumerState<ProcurementDashboardScreen> createState() =>
      _ProcurementDashboardScreenState();
}

class _ProcurementDashboardScreenState
    extends ConsumerState<ProcurementDashboardScreen> {
  bool _isLoading = true;
  String? _loadError;
  String _selectedBranchFilter = 'ALL';
  bool _showAllTopSkus = false;

  Map<String, dynamic> _overview = {};
  Map<String, dynamic> _matrix = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final api = ref.read(procurementApiServiceProvider);
      final results = await Future.wait([
        api.getOverview(
          branchId:
              _selectedBranchFilter == 'ALL' ? null : _selectedBranchFilter,
        ),
        api.getStockMatrix(),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = results[0];
        _matrix = results[1];
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = AppErrorDetails.from(e).message;
      });
    }
  }

  List<Map<String, dynamic>> get _branches {
    final raw =
        (_overview['branches'] ?? _matrix['branches']) as List<dynamic>?;
    return (raw ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> get _matrixItems {
    final raw = _matrix['items'] as List<dynamic>?;
    return (raw ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _openAssetHub({
    required int tabIndex,
    int? stockOpMode,
    String? costFilter,
  }) {
    if (stockOpMode != null) {
      ref.read(activeProcurementStockOpModeProvider.notifier).state =
          stockOpMode;
    }
    if (costFilter != null) {
      ref.read(activeProcurementCostFilterProvider.notifier).state = costFilter;
    }
    ref.read(activeProcurementTabProvider.notifier).state = tabIndex;
    ref.read(activeCoPageProvider.notifier).state = 'Asset & Procurement';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final canOperate = isProcurementOperatorRole(user);

    ref.listen<int>(procurementRefreshSignalProvider, (prev, next) {
      if (prev != next) {
        _loadData();
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 760;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderAndControls(
          tokens: tokens,
          canOperate: canOperate,
          isMobile: isMobile,
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const IcareTableSkeleton(rowCount: 6, hasFilterBar: true)
        else if (_loadError != null)
          _buildErrorBanner(_loadError!, tokens)
        else
          _buildDashboardBody(
            tokens: tokens,
            canOperate: canOperate,
            isMobile: isMobile,
            screenWidth: screenWidth,
          ),
      ],
    );
  }

  Widget _buildHeaderAndControls({
    required IcareSurfaceTokens tokens,
    required bool canOperate,
    required bool isMobile,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 680,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Procurement & Inventory Executive Dashboard',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Institution-wide physical asset portfolio, branch stock distribution, supplier cost readiness, and realized P&L',
                      style: TextStyle(fontSize: 13, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 250,
                    child: DropdownButtonFormField<String>(
                      value: _selectedBranchFilter,
                      isExpanded: true,
                      dropdownColor: tokens.surfaceElevated,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Scope Filter',
                        prefixIcon: Icon(Icons.business_outlined, size: 17),
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'ALL',
                          child: Text('All ICARE Branches'),
                        ),
                        ..._branches.map(
                          (b) => DropdownMenuItem(
                            value: b['branch_id']?.toString(),
                            child: Text(b['name']?.toString() ?? 'Branch'),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedBranchFilter = val);
                          _loadData();
                        }
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loadData,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.textPrimary,
                      side: BorderSide(color: tokens.borderStrong),
                      backgroundColor: tokens.surfaceSubtle,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (canOperate) ...[
            const SizedBox(height: 16),
            Divider(color: tokens.borderSubtle, height: 1),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Quick Actions:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.textMuted,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _openAssetHub(tabIndex: 2, stockOpMode: 0),
                  icon: const Icon(Icons.add_shopping_cart_outlined, size: 17),
                  label: const Text('Receive New Stock (GRN)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openAssetHub(tabIndex: 1),
                  icon: const Icon(Icons.swap_horiz, size: 17),
                  label: const Text('Transfer Branch Stock'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textPrimary,
                    side: BorderSide(color: tokens.borderStrong),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _openAssetHub(tabIndex: 0, costFilter: 'ALL'),
                  icon: const Icon(Icons.sell_outlined, size: 17),
                  label: const Text('Update Master Prices & Costs'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textPrimary,
                    side: BorderSide(color: tokens.borderStrong),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error, IcareSurfaceTokens tokens) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.dangerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.dangerBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: tokens.dangerDot, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Unable to load procurement dashboard: $error',
              style: TextStyle(
                color: tokens.dangerText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardBody({
    required IcareSurfaceTokens tokens,
    required bool canOperate,
    required bool isMobile,
    required double screenWidth,
  }) {
    final invSum = Map<String, dynamic>.from(
      (_overview['inventory_summary'] as Map?) ?? const {},
    );
    final pnlSum = Map<String, dynamic>.from(
      (_overview['pnl_summary'] as Map?) ?? const {},
    );
    final readiness = Map<String, dynamic>.from(
      (_overview['catalog_readiness'] as Map?) ?? const {},
    );
    final branchSummaries =
        (_overview['branch_summaries'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    final breakdown =
        (_overview['profit_breakdown_by_item'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    final movements =
        (_overview['recent_movements'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    final costConfiguredSkus =
        (readiness['cost_configured_skus'] as num?)?.toInt() ?? 0;
    final costPendingSkus =
        (readiness['cost_pending_skus'] as num?)?.toInt() ?? 0;
    final totalCatalogSkus =
        (readiness['total_catalog_skus'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Supplier Cost Readiness Progress Card
        _buildCostReadinessCard(
          tokens: tokens,
          configured: costConfiguredSkus,
          pending: costPendingSkus,
          total: totalCatalogSkus,
          canOperate: canOperate,
        ),
        const SizedBox(height: 16),

        // 2. Six Executive KPI Cards
        _buildKpiGrid(
          tokens: tokens,
          invSum: invSum,
          pnlSum: pnlSum,
          costConfiguredSkus: costConfiguredSkus,
          costPendingSkus: costPendingSkus,
          totalCatalogSkus: totalCatalogSkus,
        ),
        const SizedBox(height: 20),

        // 3. Full-Width Branch Stock Distribution & Valuation Breakdown
        _buildBranchDistributionSection(
          tokens: tokens,
          branchSummaries: branchSummaries,
        ),
        const SizedBox(height: 20),

        // 4. Category Inventory Breakdown & Top Active Assets
        _buildCategoryAndTopAssetsSection(
          tokens: tokens,
          breakdown: breakdown,
          isMobile: isMobile,
          isWide: screenWidth >= 1120,
        ),
        const SizedBox(height: 20),

        // 5. Recent Stock & Price Movement Ledger
        ProcurementMovementLedgerCard(
          tokens: tokens,
          movements: movements,
          branches: _branches,
          title: 'Recent Stock & Price Movement Ledger',
          subtitle:
              'Immutable ledger of supplier deliveries, inter-branch transfers, disbursements, write-offs, and price changes',
          showBranchFilter: false,
        ),
      ],
    );
  }

  Widget _buildCostReadinessCard({
    required IcareSurfaceTokens tokens,
    required int configured,
    required int pending,
    required int total,
    required bool canOperate,
  }) {
    final ratio = total > 0 ? (configured / total).clamp(0.0, 1.0) : 0.0;
    final pct = (ratio * 100.0).toStringAsFixed(1);
    final complete = total > 0 && pending == 0;
    final accent = complete ? tokens.successDot : tokens.warningDot;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: complete ? tokens.successBorder : tokens.warningBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: complete ? tokens.successBg : tokens.warningBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      complete
                          ? Icons.verified_outlined
                          : Icons.pending_actions_outlined,
                      size: 19,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supplier Cost Readiness ($configured / $total SKUs configured • $pct%)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        complete
                            ? 'All active catalog items have verified wholesale supplier costs for live P&L margin reporting.'
                            : '$pending SKUs currently awaiting wholesale supplier cost entry in Master Catalog & Pricing.',
                        style: TextStyle(fontSize: 12, color: tokens.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              if (canOperate)
                ElevatedButton.icon(
                  onPressed: () => _openAssetHub(
                    tabIndex: 0,
                    costFilter: pending > 0 ? 'PENDING' : 'ALL',
                  ),
                  icon: const Icon(Icons.price_change_outlined, size: 16),
                  label: Text(
                    pending > 0
                        ? 'Configure Cost Prices'
                        : 'Review Catalog Prices',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        complete ? tokens.brandPrimary : tokens.warningDot,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: tokens.surfaceSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid({
    required IcareSurfaceTokens tokens,
    required Map<String, dynamic> invSum,
    required Map<String, dynamic> pnlSum,
    required int costConfiguredSkus,
    required int costPendingSkus,
    required int totalCatalogSkus,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1020
            ? 3
            : (constraints.maxWidth >= 620 ? 2 : 1);
        const spacing = 12.0;
        final cardWidth = (constraints.maxWidth - (cols - 1) * spacing) / cols;

        final availUnits = (invSum['units_available'] as num?)?.toInt() ?? 0;
        final onHandUnits = (invSum['units_on_hand'] as num?)?.toInt() ?? 0;
        final reservedUnits =
            (invSum['units_reserved'] as num?)?.toInt() ?? 0;
        final stockedSkus = (invSum['stocked_skus'] as num?)?.toInt() ?? 0;
        final cashVal =
            (invSum['inventory_cash_value'] as num?)?.toDouble() ?? 0.0;
        final easy60Val =
            (invSum['inventory_60d_value'] as num?)?.toDouble() ?? 0.0;
        final costVal =
            (invSum['inventory_cost_value'] as num?)?.toDouble() ?? 0.0;

        final unitsSold = (pnlSum['units_sold'] as num?)?.toInt() ?? 0;
        final pkgRev =
            (pnlSum['realized_package_revenue'] as num?)?.toDouble() ?? 0.0;
        final grossProf =
            (pnlSum['gross_profit'] as num?)?.toDouble() ?? 0.0;
        final tradeProf =
            (pnlSum['realized_trading_profit'] as num?)?.toDouble() ?? 0.0;
        final finMarkup =
            (pnlSum['realized_financing_markup'] as num?)?.toDouble() ?? 0.0;
        final netProf =
            (pnlSum['net_realized_profit'] as num?)?.toDouble() ?? 0.0;
        final woUnits = (pnlSum['write_off_units'] as num?)?.toInt() ?? 0;
        final woLoss =
            (pnlSum['write_off_cost_loss'] as num?)?.toDouble() ?? 0.0;
        final netMarginPct =
            (pnlSum['net_margin_pct'] as num?)?.toDouble() ?? 0.0;

        final kpis = [
          _kpiCard(
            tokens: tokens,
            width: cardWidth,
            icon: Icons.inventory_2_outlined,
            accentColor: tokens.brandPrimary,
            title: 'Physical Stock Available',
            value: '$availUnits units',
            subtitle:
                '$onHandUnits on hand  •  $reservedUnits reserved  •  $stockedSkus stocked SKUs',
          ),
          _kpiCard(
            tokens: tokens,
            width: cardWidth,
            icon: Icons.account_balance_wallet_outlined,
            accentColor: tokens.infoDot,
            title: 'Inventory Valuation (Retail vs Cost)',
            value: CurrencyFormatter.formatNaira(cashVal),
            subtitle: costVal > 0
                ? 'Easy Buy 60D: ${CurrencyFormatter.formatNaira(easy60Val)}  •  Cost: ${CurrencyFormatter.formatNaira(costVal)} (Margin: ${CurrencyFormatter.formatNaira(cashVal - costVal)})'
                : 'Easy Buy 60D: ${CurrencyFormatter.formatNaira(easy60Val)}  •  Cost Valuation: Pending entry',
          ),
          _kpiCard(
            tokens: tokens,
            width: cardWidth,
            icon: Icons.price_check_outlined,
            accentColor:
                costConfiguredSkus > 0 ? tokens.successDot : tokens.warningDot,
            title: 'Supplier Cost Price Readiness',
            value: '$costConfiguredSkus / $totalCatalogSkus SKUs',
            subtitle: costPendingSkus > 0
                ? '$costPendingSkus SKUs currently awaiting supplier wholesale cost'
                : 'All catalog SKUs have supplier cost prices configured',
          ),
          _kpiCard(
            tokens: tokens,
            width: cardWidth,
            icon: Icons.point_of_sale_outlined,
            accentColor: tokens.brandPrimary,
            title: 'Realized Disbursed Revenue',
            value: CurrencyFormatter.formatNaira(pkgRev),
            subtitle:
                '$unitsSold units disbursed across Cash & Carry and Easy Buy plans',
          ),
          _kpiCard(
            tokens: tokens,
            width: cardWidth,
            icon: Icons.trending_up_outlined,
            accentColor: tokens.successDot,
            title: 'Realized Gross Profit',
            value: CurrencyFormatter.formatNaira(grossProf),
            subtitle:
                'Trading: ${CurrencyFormatter.formatNaira(tradeProf)}  •  Easy Buy Markup: ${CurrencyFormatter.formatNaira(finMarkup)}',
          ),
          _kpiCard(
            tokens: tokens,
            width: cardWidth,
            icon: netProf >= 0
                ? Icons.assessment_outlined
                : Icons.warning_amber_outlined,
            accentColor: netProf >= 0 ? tokens.successDot : tokens.dangerDot,
            title: 'Net Asset P&L (After Write-Offs)',
            value: CurrencyFormatter.formatNaira(netProf),
            subtitle:
                'Write-Off Loss: ${CurrencyFormatter.formatNaira(woLoss)} ($woUnits units)  •  Net Margin: ${netMarginPct.toStringAsFixed(1)}%',
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: kpis,
        );
      },
    );
  }

  Widget _buildBranchDistributionSection({
    required IcareSurfaceTokens tokens,
    required List<Map<String, dynamic>> branchSummaries,
  }) {
    final totalInstitutionUnits = branchSummaries.fold<int>(
      0,
      (s, b) => s + ((b['units_available'] as num?)?.toInt() ?? 0),
    );

    return ProcurementSectionCard(
      tokens: tokens,
      title: 'Branch Stock Distribution & Valuation Breakdown',
      subtitle:
          'Physical inventory share, reserved stock, wholesale cost, and retail value across every branch',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (branchSummaries.isNotEmpty) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 980
                    ? 3
                    : (constraints.maxWidth >= 600 ? 2 : 1);
                const spacing = 10.0;
                final cardWidth =
                    (constraints.maxWidth - (cols - 1) * spacing) / cols;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: branchSummaries.map((b) {
                    final avail = (b['units_available'] as num?)?.toInt() ?? 0;
                    final onHand = (b['units_on_hand'] as num?)?.toInt() ?? 0;
                    final reserved =
                        (b['units_reserved'] as num?)?.toInt() ?? 0;
                    final stockedSkus =
                        (b['stocked_skus'] as num?)?.toInt() ?? 0;
                    final cashVal =
                        (b['inventory_cash_value'] as num?)?.toDouble() ?? 0.0;
                    final share = totalInstitutionUnits > 0
                        ? (avail / totalInstitutionUnits).clamp(0.0, 1.0)
                        : 0.0;
                    final sharePct = (share * 100.0).toStringAsFixed(1);

                    return Container(
                      width: cardWidth,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: avail > 0
                              ? tokens.brandSoftBorder
                              : tokens.borderSubtle,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  b['branch_name']?.toString() ?? 'Branch',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ),
                              ProcurementStatusPill(
                                label: '$sharePct% share',
                                bg: avail > 0
                                    ? tokens.brandSoftBg
                                    : tokens.surface,
                                fg: avail > 0
                                    ? tokens.brandSoftText
                                    : tokens.textMuted,
                                border: avail > 0
                                    ? tokens.brandSoftBorder
                                    : tokens.borderSubtle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: share,
                              minHeight: 6,
                              backgroundColor: tokens.surface,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                avail > 0
                                    ? tokens.brandPrimary
                                    : tokens.borderStrong,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$avail avail ($onHand on hand • $reserved rsv)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: tokens.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '$stockedSkus SKUs',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: tokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Retail Value: ${CurrencyFormatter.formatNaira(cashVal)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          ProcurementBranchValuationTable(
            tokens: tokens,
            branchSummaries: branchSummaries,
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _computeCategoryAggregates() {
    final byCat = <String, Map<String, dynamic>>{};
    final targetBranchId =
        _selectedBranchFilter == 'ALL' ? null : _selectedBranchFilter;

    for (final it in _matrixItems) {
      final cat = it['category']?.toString() ?? 'UNCATEGORIZED';
      final cashPrice =
          (it['cash_and_carry_price'] as num?)?.toDouble() ?? 0.0;
      int avail = (it['total_available'] as num?)?.toInt() ?? 0;
      if (targetBranchId != null) {
        final bStocks = (it['branch_stocks'] as Map?) ?? const {};
        avail = ((bStocks[targetBranchId] as Map?)?['quantity_available']
                    as num?)
                ?.toInt() ??
            0;
      }

      final acc = byCat.putIfAbsent(
        cat,
        () => {
          'category': cat,
          'catalog_skus': 0,
          'stocked_skus': 0,
          'units_available': 0,
          'retail_value': 0.0,
        },
      );
      acc['catalog_skus'] = (acc['catalog_skus'] as int) + 1;
      if (avail > 0) {
        acc['stocked_skus'] = (acc['stocked_skus'] as int) + 1;
        acc['units_available'] = (acc['units_available'] as int) + avail;
        acc['retail_value'] =
            (acc['retail_value'] as double) + (avail * cashPrice);
      }
    }

    final list = byCat.values.toList();
    list.sort((a, b) {
      final uCmp = (b['units_available'] as int)
          .compareTo(a['units_available'] as int);
      if (uCmp != 0) return uCmp;
      final vCmp =
          (b['retail_value'] as double).compareTo(a['retail_value'] as double);
      if (vCmp != 0) return vCmp;
      return (a['category'] as String).compareTo(b['category'] as String);
    });
    return list;
  }

  Widget _buildCategoryAndTopAssetsSection({
    required IcareSurfaceTokens tokens,
    required List<Map<String, dynamic>> breakdown,
    required bool isMobile,
    required bool isWide,
  }) {
    final categoryAggs = _computeCategoryAggregates();
    final maxCatValue = categoryAggs.fold<double>(
      0.0,
      (m, e) {
        final rv = (e['retail_value'] as double);
        return rv > m ? rv : m;
      },
    );

    final visibleBreakdown =
        _showAllTopSkus ? breakdown : breakdown.take(20).toList();

    final leftCard = ProcurementSectionCard(
      tokens: tokens,
      title: 'Inventory by Asset Category (${categoryAggs.length})',
      subtitle:
          'Catalog coverage, active in-stock SKUs, and retail stock valuation per category',
      child: categoryAggs.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'No category inventory data loaded.',
                style: TextStyle(color: tokens.textMuted),
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460),
              child: SingleChildScrollView(
                child: Column(
                  children: categoryAggs.map((cat) {
                    final name = cat['category'] as String;
                    final totalSkus = cat['catalog_skus'] as int;
                    final stockedSkus = cat['stocked_skus'] as int;
                    final units = cat['units_available'] as int;
                    final retailVal = cat['retail_value'] as double;
                    final ratio = maxCatValue > 0
                        ? (retailVal / maxCatValue).clamp(0.0, 1.0)
                        : 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.formatNaira(retailVal),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: units > 0
                                      ? tokens.textPrimary
                                      : tokens.textMuted,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 5,
                              backgroundColor: tokens.surface,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                units > 0
                                    ? tokens.brandPrimary
                                    : tokens.borderStrong,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$units unit(s) available  •  $stockedSkus / $totalSkus SKUs in stock',
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
    );

    final rightCard = ProcurementSectionCard(
      tokens: tokens,
      title: 'Top Stocked & Disbursed SKUs (${breakdown.length})',
      subtitle:
          'Active physical stock paired with wholesale margin and realized net sales profit',
      trailing: breakdown.length > 20
          ? TextButton(
              onPressed: () =>
                  setState(() => _showAllTopSkus = !_showAllTopSkus),
              child: Text(
                _showAllTopSkus
                    ? 'Show Top 20'
                    : 'Show All (${breakdown.length})',
              ),
            )
          : null,
      child: breakdown.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No stocked or sold SKUs match the selected branch scope.',
                style: TextStyle(color: tokens.textMuted),
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460),
              child: SingleChildScrollView(
                child: ProcurementFullWidthTable(
                  tokens: tokens,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(tokens.surfaceSubtle),
                    columnSpacing: 16,
                    horizontalMargin: 12,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 54,
                    columns: const [
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('Item Name')),
                      DataColumn(label: Text('Avail'), numeric: true),
                      DataColumn(label: Text('Cash Price'), numeric: true),
                      DataColumn(label: Text('Retail Margin'), numeric: true),
                      DataColumn(label: Text('Sold'), numeric: true),
                      DataColumn(label: Text('Net Profit'), numeric: true),
                    ],
                    rows: visibleBreakdown.map((it) {
                      final hasCost = it['has_cost_price'] == true;
                      final cashP =
                          (it['cash_and_carry_price'] as num?)?.toDouble() ??
                              0.0;
                      final marginAmt =
                          (it['retail_margin_amount'] as num?)?.toDouble() ??
                              0.0;
                      final marginPct =
                          (it['retail_margin_pct'] as num?)?.toDouble() ?? 0.0;
                      final netProf =
                          (it['realized_net_profit'] as num?)?.toDouble() ??
                              0.0;

                      return DataRow(
                        cells: [
                          DataCell(Text(
                            it['sku_code']?.toString() ?? '',
                            style: const TextStyle(fontSize: 11.5),
                          )),
                          DataCell(
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: isMobile ? 140 : 170,
                                maxWidth: 220,
                              ),
                              child: Text(
                                it['item_name']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text('${it['available'] ?? 0}')),
                          DataCell(Text(
                            CurrencyFormatter.formatNaira(cashP),
                            style: const TextStyle(
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          )),
                          DataCell(Text(
                            hasCost
                                ? '${CurrencyFormatter.formatNaira(marginAmt)} (${marginPct.toStringAsFixed(1)}%)'
                                : 'Pending',
                            style: TextStyle(
                              color: hasCost
                                  ? tokens.successText
                                  : tokens.textMuted,
                            ),
                          )),
                          DataCell(Text('${it['units_sold'] ?? 0}')),
                          DataCell(Text(
                            CurrencyFormatter.formatNaira(netProf),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: netProf > 0
                                  ? tokens.successText
                                  : (netProf < 0
                                      ? tokens.dangerText
                                      : tokens.textMuted),
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: leftCard),
          const SizedBox(width: 16),
          Expanded(flex: 7, child: rightCard),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leftCard,
        const SizedBox(height: 16),
        rightCard,
      ],
    );
  }

  Widget _kpiCard({
    required IcareSurfaceTokens tokens,
    required double width,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5,
              color: tokens.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
