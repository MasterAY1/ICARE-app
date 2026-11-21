import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/app_error_formatter.dart';
import '../../../core/theme/icare_motion.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../data/datasources/procurement_api_service.dart';

/// Enterprise Asset & Procurement Command Hub (`BIA-ASSET-PROC-001`).
/// Provides multi-branch physical inventory control, supplier GRN receiving,
/// inter-branch stock transfers, damaged/lost write-offs, master cost & retail
/// price governance, and Profit & Loss reporting across all ICARE branches.
class AssetProcurementScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const AssetProcurementScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<AssetProcurementScreen> createState() =>
      _AssetProcurementScreenState();
}

class _AssetProcurementScreenState
    extends ConsumerState<AssetProcurementScreen> {
  late int _activeTab;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  String? _flashSuccess;
  String? _flashError;

  String _selectedBranchFilter = 'ALL';
  Map<String, dynamic> _overview = {};
  Map<String, dynamic> _matrix = {};

  // Tab 1 (Multi-Branch Matrix) filters
  final _matrixSearchCtrl = TextEditingController();
  String _matrixCategory = 'ALL';
  bool _matrixInStockOnly = false;

  // Tab 2 (Receive Stock GRN vs Write-Off) state
  int _stockOpMode = 0; // 0 = Receive GRN, 1 = Write-Off
  String? _grnBranchId;
  final _grnSupplierCtrl = TextEditingController();
  final _grnReferenceCtrl = TextEditingController();
  final _grnRemarksCtrl = TextEditingController();
  final List<Map<String, dynamic>> _grnLines = [];
  String? _grnPickItemId;

  String? _woBranchId;
  String? _woItemId;
  final _woQtyCtrl = TextEditingController(text: '1');
  final _woRefCtrl = TextEditingController();
  final _woReasonCtrl = TextEditingController();

  // Tab 3 (Price & Cost Manager) filters
  final _priceSearchCtrl = TextEditingController();
  String _priceCategory = 'ALL';
  String _costStatusFilter = 'ALL'; // ALL, PENDING, CONFIGURED, IN_STOCK

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTabIndex.clamp(0, 3);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void didUpdateWidget(covariant AssetProcurementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      setState(() {
        _activeTab = widget.initialTabIndex.clamp(0, 3);
      });
    }
  }

  @override
  void dispose() {
    _matrixSearchCtrl.dispose();
    _grnSupplierCtrl.dispose();
    _grnReferenceCtrl.dispose();
    _grnRemarksCtrl.dispose();
    _woQtyCtrl.dispose();
    _woRefCtrl.dispose();
    _woReasonCtrl.dispose();
    _priceSearchCtrl.dispose();
    super.dispose();
  }

  bool _canEditProcurement(AuthUser? user) {
    final role = (user?.role ?? '').trim().toLowerCase();
    return role == 'procurement officer' ||
        role == 'procurement_officer' ||
        role == 'asset manager' ||
        role == 'asset_manager' ||
        role == 'admin' ||
        role == 'super admin';
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final api = ref.read(procurementApiServiceProvider);
      final results = await Future.wait([
        api.getOverview(
          branchId: _selectedBranchFilter == 'ALL' ? null : _selectedBranchFilter,
        ),
        api.getStockMatrix(),
      ]);
      if (!mounted) return;
      final ov = results[0];
      final mx = results[1];
      final branches = (ov['branches'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      setState(() {
        _overview = ov;
        _matrix = mx;
        _isLoading = false;
        _loadError = null;
        if (_grnBranchId == null && branches.isNotEmpty) {
          _grnBranchId = branches.first['branch_id']?.toString();
        }
        if (_woBranchId == null && branches.isNotEmpty) {
          _woBranchId = branches.first['branch_id']?.toString();
        }
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
    final raw = (_matrix['branches'] ?? _overview['branches']) as List<dynamic>?;
    return (raw ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<String> get _categories {
    final raw = (_matrix['categories'] ?? _overview['categories']) as List<dynamic>?;
    return (raw ?? const []).map((e) => e.toString()).toList();
  }

  List<Map<String, dynamic>> get _matrixItems {
    final raw = _matrix['items'] as List<dynamic>?;
    return (raw ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _setFlash({String? success, String? error}) {
    if (!mounted) return;
    setState(() {
      _flashSuccess = success;
      _flashError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final canEdit = _canEditProcurement(user);

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
        // Header bar
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asset & Procurement Control Hub',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cross-branch asset inventory, supplier receiving (GRN), stock transfers, cost/selling governance, and Asset P&L.',
                    style: TextStyle(fontSize: 13, color: tokens.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : () => _loadData(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.textPrimary,
                side: BorderSide(color: tokens.borderStrong),
                backgroundColor: tokens.surface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_flashSuccess != null) ...[
          _buildBanner(_flashSuccess!, isError: false, tokens: tokens),
          const SizedBox(height: 10),
        ],
        if (_flashError != null) ...[
          _buildBanner(_flashError!, isError: true, tokens: tokens),
          const SizedBox(height: 10),
        ],

        // 4 Pill Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              (0, 'Stock & P&L Overview', Icons.analytics_outlined),
              (1, 'Multi-Branch Matrix & Transfers', Icons.swap_horiz_outlined),
              (2, 'Receive Stock (GRN) & Write-Offs', Icons.inventory_2_outlined),
              (3, 'Master Price & Cost List', Icons.sell_outlined),
            ].map((tab) {
              final selected = _activeTab == tab.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _activeTab = tab.$1),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? tokens.brandPrimary : tokens.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? tokens.brandPrimary : tokens.borderStrong,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.$3,
                          size: 16,
                          color: selected ? Colors.white : tokens.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab.$2,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            color: selected ? Colors.white : tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),

        if (_isLoading)
          const IcareTableSkeleton(rowCount: 6, hasFilterBar: true)
        else if (_loadError != null)
          _buildBanner('Unable to load procurement data: $_loadError',
              isError: true, tokens: tokens)
        else
          _buildTabBody(tokens, canEdit: canEdit, isMobile: isMobile),
      ],
    );
  }

  Widget _buildBanner(
    String msg, {
    required bool isError,
    required IcareSurfaceTokens tokens,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isError ? tokens.dangerBg : tokens.successBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? tokens.dangerBorder : tokens.successBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: isError ? tokens.dangerDot : tokens.successDot,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isError ? tokens.dangerText : tokens.successText,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: isError ? tokens.dangerText : tokens.successText,
            onPressed: () => setState(() {
              _flashSuccess = null;
              _flashError = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody(
    IcareSurfaceTokens tokens, {
    required bool canEdit,
    required bool isMobile,
  }) {
    switch (_activeTab) {
      case 0:
        return _buildOverviewTab(tokens, isMobile: isMobile);
      case 1:
        return _buildMatrixTab(tokens, canEdit: canEdit);
      case 2:
        return _buildReceiveAndWriteOffTab(tokens, canEdit: canEdit);
      case 3:
        return _buildPriceCatalogTab(tokens, canEdit: canEdit);
      default:
        return const SizedBox.shrink();
    }
  }

  // ===========================================================================
  // TAB 0: STOCK & PROFIT/LOSS OVERVIEW
  // ===========================================================================
  Widget _buildOverviewTab(
    IcareSurfaceTokens tokens, {
    required bool isMobile,
  }) {
    final invSum = Map<String, dynamic>.from(
        (_overview['inventory_summary'] as Map?) ?? const {});
    final pnlSum = Map<String, dynamic>.from(
        (_overview['pnl_summary'] as Map?) ?? const {});
    final readiness = Map<String, dynamic>.from(
        (_overview['catalog_readiness'] as Map?) ?? const {});
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

    final costPendingSkus =
        (readiness['cost_pending_skus'] as num?)?.toInt() ?? 0;
    final costConfiguredSkus =
        (readiness['cost_configured_skus'] as num?)?.toInt() ?? 0;
    final totalCatalogSkus =
        (readiness['total_catalog_skus'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Branch Scope Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business_outlined, size: 17, color: tokens.brandPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'Scope Filter:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  value: _selectedBranchFilter,
                  isExpanded: true,
                  dropdownColor: tokens.surfaceElevated,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'ALL',
                      child: Text('All ICARE Branches (Institution)'),
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
              if (costPendingSkus > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.warningBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.warningBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 15, color: tokens.warningDot),
                      const SizedBox(width: 6),
                      Text(
                        'Cost Pending on $costPendingSkus/$totalCatalogSkus SKUs — enter wholesale cost prices in Master Price & Cost List when ready.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.warningText,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 6 KPI Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 1020
                ? 3
                : (constraints.maxWidth >= 620 ? 2 : 1);
            const spacing = 12.0;
            final cardWidth =
                (constraints.maxWidth - (cols - 1) * spacing) / cols;

            final availUnits = (invSum['units_available'] as num?)?.toInt() ?? 0;
            final onHandUnits = (invSum['units_on_hand'] as num?)?.toInt() ?? 0;
            final reservedUnits =
                (invSum['units_reserved'] as num?)?.toInt() ?? 0;
            final stockedSkus = (invSum['stocked_skus'] as num?)?.toInt() ?? 0;
            final cashVal =
                (invSum['inventory_cash_value'] as num?)?.toDouble() ?? 0.0;
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
                    ? 'Cost Valuation: ${CurrencyFormatter.formatNaira(costVal)} (Projected Retail Margin: ${CurrencyFormatter.formatNaira(cashVal - costVal)})'
                    : 'Cost Valuation: Pending supplier cost entry',
              ),
              _kpiCard(
                tokens: tokens,
                width: cardWidth,
                icon: Icons.price_check_outlined,
                accentColor: costConfiguredSkus > 0
                    ? tokens.successDot
                    : tokens.warningDot,
                title: 'Supplier Cost Price Readiness',
                value: '$costConfiguredSkus / $totalCatalogSkus SKUs',
                subtitle: costPendingSkus > 0
                    ? '$costPendingSkus SKUs currently flagged Cost Pending'
                    : 'All catalog SKUs have supplier cost prices',
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
                accentColor:
                    netProf >= 0 ? tokens.successDot : tokens.dangerDot,
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
        ),
        const SizedBox(height: 20),

        // Per-Branch Valuation Table
        _sectionCard(
          tokens: tokens,
          title: 'Branch Stock & Valuation Breakdown',
          subtitle:
              'Physical units and valuation at cost vs Cash & Carry selling price across all branches',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
              columns: const [
                DataColumn(label: Text('Branch')),
                DataColumn(label: Text('Stocked SKUs'), numeric: true),
                DataColumn(label: Text('On Hand'), numeric: true),
                DataColumn(label: Text('Reserved'), numeric: true),
                DataColumn(label: Text('Available'), numeric: true),
                DataColumn(label: Text('Cost Value'), numeric: true),
                DataColumn(label: Text('Retail Cash Value'), numeric: true),
                DataColumn(label: Text('Projected Margin'), numeric: true),
              ],
              rows: branchSummaries.map((b) {
                final costV =
                    (b['inventory_cost_value'] as num?)?.toDouble() ?? 0.0;
                final cashV =
                    (b['inventory_cash_value'] as num?)?.toDouble() ?? 0.0;
                final projMargin =
                    (b['projected_retail_profit'] as num?)?.toDouble() ?? 0.0;
                return DataRow(
                  cells: [
                    DataCell(Text(
                      b['branch_name']?.toString() ?? 'Branch',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )),
                    DataCell(Text('${b['stocked_skus'] ?? 0}')),
                    DataCell(Text('${b['units_on_hand'] ?? 0}')),
                    DataCell(Text('${b['units_reserved'] ?? 0}')),
                    DataCell(Text(
                      '${b['units_available'] ?? 0}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ((b['units_available'] as num?)?.toInt() ?? 0) > 0
                            ? tokens.successText
                            : tokens.textMuted,
                      ),
                    )),
                    DataCell(Text(costV > 0
                        ? CurrencyFormatter.formatNaira(costV)
                        : 'Pending')),
                    DataCell(Text(CurrencyFormatter.formatNaira(cashV))),
                    DataCell(Text(costV > 0
                        ? CurrencyFormatter.formatNaira(projMargin)
                        : 'Pending')),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Itemized Profit & Margin Breakdown
        _sectionCard(
          tokens: tokens,
          title: 'Itemized Cost, Margin & Sales P&L (${breakdown.length} active/stocked SKUs)',
          subtitle:
              'Tracks stocked or sold assets with live cost-to-retail margins and realized net profit',
          child: breakdown.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No stocked or sold SKUs match the selected scope.',
                    style: TextStyle(color: tokens.textMuted),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(tokens.surfaceSubtle),
                    columns: const [
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('Item Name')),
                      DataColumn(label: Text('Avail'), numeric: true),
                      DataColumn(label: Text('Unit Cost'), numeric: true),
                      DataColumn(label: Text('Cash Price'), numeric: true),
                      DataColumn(label: Text('Retail Margin'), numeric: true),
                      DataColumn(label: Text('Sold'), numeric: true),
                      DataColumn(label: Text('Revenue'), numeric: true),
                      DataColumn(label: Text('Net Profit'), numeric: true),
                    ],
                    rows: breakdown.take(100).map((it) {
                      final hasCost = it['has_cost_price'] == true;
                      final costP =
                          (it['unit_cost_price'] as num?)?.toDouble() ?? 0.0;
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
                          DataCell(Text(it['sku_code']?.toString() ?? '')),
                          DataCell(
                            SizedBox(
                              width: isMobile ? 160 : 230,
                              child: Text(
                                it['item_name']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          DataCell(Text('${it['available'] ?? 0}')),
                          DataCell(
                            hasCost
                                ? Text(CurrencyFormatter.formatNaira(costP))
                                : _statusPill(
                                    tokens,
                                    'Cost Pending',
                                    tokens.warningBg,
                                    tokens.warningText,
                                    tokens.warningBorder,
                                  ),
                          ),
                          DataCell(Text(CurrencyFormatter.formatNaira(cashP))),
                          DataCell(Text(hasCost
                              ? '${CurrencyFormatter.formatNaira(marginAmt)} (${marginPct.toStringAsFixed(1)}%)'
                              : 'Pending')),
                          DataCell(Text('${it['units_sold'] ?? 0}')),
                          DataCell(Text(CurrencyFormatter.formatNaira(
                              (it['realized_package_revenue'] as num?)
                                      ?.toDouble() ??
                                  0.0))),
                          DataCell(Text(
                            CurrencyFormatter.formatNaira(netProf),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: netProf > 0
                                  ? tokens.successText
                                  : (netProf < 0
                                      ? tokens.dangerText
                                      : tokens.textMuted),
                            ),
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
        const SizedBox(height: 18),

        // Recent Movements Audit Log
        _sectionCard(
          tokens: tokens,
          title: 'Recent Stock & Price Movement Ledger (${movements.length})',
          subtitle:
              'Immutable movement log of stock receipts, transfers, disbursements, write-offs, and price updates',
          child: movements.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No asset stock or price movements logged yet.',
                    style: TextStyle(color: tokens.textMuted),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(tokens.surfaceSubtle),
                    columns: const [
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Branch')),
                      DataColumn(label: Text('Item')),
                      DataColumn(label: Text('Qty Delta'), numeric: true),
                      DataColumn(label: Text('Balance'), numeric: true),
                      DataColumn(label: Text('Unit Cost'), numeric: true),
                      DataColumn(label: Text('Selling Price'), numeric: true),
                      DataColumn(label: Text('Ref / By')),
                      DataColumn(label: Text('Remarks')),
                    ],
                    rows: movements.map((m) {
                      final mType = m['movement_type']?.toString() ?? '';
                      final qDelta = (m['quantity_delta'] as num?)?.toInt() ?? 0;
                      final cp = m['counterparty_branch_name']?.toString();
                      final bLabel = cp != null && cp.isNotEmpty
                          ? '${m['branch_name']} (${mType == 'TRANSFER_OUT' ? 'to' : 'from'} $cp)'
                          : (m['branch_name']?.toString() ?? '');
                      return DataRow(
                        cells: [
                          DataCell(_movementBadge(tokens, mType)),
                          DataCell(Text(bLabel)),
                          DataCell(Text('${m['item_name']} (${m['sku_code']})')),
                          DataCell(Text(
                            qDelta > 0 ? '+$qDelta' : '$qDelta',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: qDelta > 0
                                  ? tokens.successText
                                  : (qDelta < 0
                                      ? tokens.dangerText
                                      : tokens.textMuted),
                            ),
                          )),
                          DataCell(Text('${m['balance_after'] ?? 0}')),
                          DataCell(Text(
                            ((m['unit_cost_price'] as num?)?.toDouble() ?? 0) > 0
                                ? CurrencyFormatter.formatNaira(
                                    (m['unit_cost_price'] as num).toDouble())
                                : '-',
                          )),
                          DataCell(Text(CurrencyFormatter.formatNaira(
                              (m['unit_selling_price'] as num?)?.toDouble() ??
                                  0.0))),
                          DataCell(Text(
                              '${m['reference_code'] ?? '-'} • ${m['performed_by']}')),
                          DataCell(
                            SizedBox(
                              width: 220,
                              child: Text(
                                m['remarks']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 1: MULTI-BRANCH STOCK MATRIX & INTER-BRANCH TRANSFERS
  // ===========================================================================
  Widget _buildMatrixTab(
    IcareSurfaceTokens tokens, {
    required bool canEdit,
  }) {
    final branches = _branches;
    final q = _matrixSearchCtrl.text.trim().toLowerCase();
    final filtered = _matrixItems.where((it) {
      if (_matrixCategory != 'ALL' &&
          (it['category']?.toString().toUpperCase() ?? '') != _matrixCategory) {
        return false;
      }
      final totAvail = (it['total_available'] as num?)?.toInt() ?? 0;
      if (_matrixInStockOnly && totAvail <= 0) return false;
      if (q.isNotEmpty) {
        final hay =
            '${it['item_name']} ${it['sku_code']} ${it['category']} ${it['supplier_name'] ?? ''}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _matrixSearchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Search SKU or asset name...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  value: _matrixCategory,
                  isExpanded: true,
                  dropdownColor: tokens.surfaceElevated,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: 'ALL', child: Text('All Categories')),
                    ..._categories.map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _matrixCategory = v);
                  },
                ),
              ),
              FilterChip(
                selected: _matrixInStockOnly,
                label: const Text('In Stock Anywhere'),
                onSelected: (v) => setState(() => _matrixInStockOnly = v),
              ),
              if (canEdit)
                ElevatedButton.icon(
                  onPressed: branches.length < 2
                      ? null
                      : () => _openTransferDialog(tokens),
                  icon: const Icon(Icons.swap_horiz, size: 17),
                  label: const Text('Transfer Stock Between Branches'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimary,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          tokens: tokens,
          title:
              'Cross-Branch Physical Inventory Matrix (${filtered.length} SKUs shown)',
          subtitle:
              'Displays available / on-hand units side-by-side across all active branches',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
              columns: [
                const DataColumn(label: Text('SKU')),
                const DataColumn(label: Text('Item Name')),
                const DataColumn(label: Text('Cash Price'), numeric: true),
                const DataColumn(label: Text('Total Avail'), numeric: true),
                ...branches.map(
                  (b) => DataColumn(
                    label: Text(b['name']?.toString() ?? 'Branch'),
                    numeric: true,
                  ),
                ),
                if (canEdit) const DataColumn(label: Text('Action')),
              ],
              rows: filtered.take(150).map((it) {
                final bStocks = (it['branch_stocks'] as Map?) ?? const {};
                final totAvail = (it['total_available'] as num?)?.toInt() ?? 0;
                return DataRow(
                  cells: [
                    DataCell(Text(it['sku_code']?.toString() ?? '')),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              it['item_name']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              it['category']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text(CurrencyFormatter.formatNaira(
                        (it['cash_and_carry_price'] as num?)?.toDouble() ??
                            0.0))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: totAvail > 0
                              ? tokens.successBg
                              : tokens.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: totAvail > 0
                                ? tokens.successBorder
                                : tokens.borderSubtle,
                          ),
                        ),
                        child: Text(
                          '$totAvail',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: totAvail > 0
                                ? tokens.successText
                                : tokens.textMuted,
                          ),
                        ),
                      ),
                    ),
                    ...branches.map((b) {
                      final bid = b['branch_id']?.toString() ?? '';
                      final st =
                          (bStocks[bid] as Map?) ?? const <String, dynamic>{};
                      final av = (st['quantity_available'] as num?)?.toInt() ?? 0;
                      final rsv =
                          (st['quantity_reserved'] as num?)?.toInt() ?? 0;
                      return DataCell(
                        Text(
                          rsv > 0 ? '$av ($rsv rsv)' : '$av',
                          style: TextStyle(
                            fontWeight:
                                av > 0 ? FontWeight.w700 : FontWeight.w400,
                            color:
                                av > 0 ? tokens.successText : tokens.textMuted,
                          ),
                        ),
                      );
                    }),
                    if (canEdit)
                      DataCell(
                        TextButton.icon(
                          onPressed: totAvail <= 0 || branches.length < 2
                              ? null
                              : () => _openTransferDialog(
                                    tokens,
                                    preselectedItem: it,
                                  ),
                          icon: const Icon(Icons.swap_horiz, size: 16),
                          label: const Text('Transfer'),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openTransferDialog(
    IcareSurfaceTokens tokens, {
    Map<String, dynamic>? preselectedItem,
  }) async {
    final branches = _branches;
    if (branches.length < 2) return;

    Map<String, dynamic>? pickedItem = preselectedItem ??
        _matrixItems.cast<Map<String, dynamic>?>().firstWhere(
              (x) => ((x?['total_available'] as num?)?.toInt() ?? 0) > 0,
              orElse: () => _matrixItems.isNotEmpty ? _matrixItems.first : null,
            );
    if (pickedItem == null) {
      _setFlash(error: 'No catalog items available to transfer.');
      return;
    }

    String bestSourceBranch(Map<String, dynamic> item) {
      final bStocks = (item['branch_stocks'] as Map?) ?? const {};
      String bestId = branches.first['branch_id'].toString();
      int bestQty = -1;
      for (final b in branches) {
        final bid = b['branch_id'].toString();
        final av =
            ((bStocks[bid] as Map?)?['quantity_available'] as num?)?.toInt() ??
                0;
        if (av > bestQty) {
          bestQty = av;
          bestId = bid;
        }
      }
      return bestId;
    }

    String fromId = bestSourceBranch(pickedItem);
    String toId = branches
        .firstWhere((b) => b['branch_id'].toString() != fromId)['branch_id']
        .toString();
    final qtyCtrl = TextEditingController(text: '1');
    final refCtrl = TextEditingController();
    final remCtrl = TextEditingController();
    bool saving = false;
    String? modalErr;

    await showIcareDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final dTokens = IcareSurfaceTokens.of(ctx);
          final bStocks = (pickedItem!['branch_stocks'] as Map?) ?? const {};
          final srcAvail = ((bStocks[fromId] as Map?)?['quantity_available']
                      as num?)
                  ?.toInt() ??
              0;

          final stockedOptions = _matrixItems
              .where((x) => ((x['total_available'] as num?)?.toInt() ?? 0) > 0)
              .toList();
          if (stockedOptions.isNotEmpty &&
              !stockedOptions.any((x) => x['item_id'] == pickedItem!['item_id'])) {
            stockedOptions.insert(0, pickedItem!);
          }

          return AlertDialog(
            backgroundColor: dTokens.surfaceElevated,
            title: Text(
              'Transfer Stock Between Branches',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: dTokens.textPrimary,
              ),
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (modalErr != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: dTokens.dangerBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: dTokens.dangerBorder),
                        ),
                        child: Text(modalErr!,
                            style: TextStyle(
                                color: dTokens.dangerText, fontSize: 12)),
                      ),
                    ],
                    DropdownButtonFormField<String>(
                      value: pickedItem!['item_id']?.toString(),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Asset SKU',
                        border: OutlineInputBorder(),
                      ),
                      items: (stockedOptions.isEmpty
                              ? _matrixItems
                              : stockedOptions)
                          .map((it) => DropdownMenuItem(
                                value: it['item_id'].toString(),
                                child: Text(
                                  '${it['item_name']} (${it['sku_code']}) — ${it['total_available']} avail',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final match = _matrixItems
                            .firstWhere((e) => e['item_id'].toString() == v);
                        setModal(() {
                          pickedItem = match;
                          fromId = bestSourceBranch(match);
                          if (toId == fromId) {
                            toId = branches
                                .firstWhere(
                                    (b) => b['branch_id'].toString() != fromId)['branch_id']
                                .toString();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: fromId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Source Branch',
                        border: OutlineInputBorder(),
                      ),
                      items: branches.map((b) {
                        final bid = b['branch_id'].toString();
                        final av = ((bStocks[bid] as Map?)?['quantity_available']
                                    as num?)
                                ?.toInt() ??
                            0;
                        return DropdownMenuItem(
                          value: bid,
                          child: Text('${b['name']} ($av available)'),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setModal(() {
                          fromId = v;
                          if (toId == fromId) {
                            toId = branches
                                .firstWhere(
                                    (b) => b['branch_id'].toString() != fromId)['branch_id']
                                .toString();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: toId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Destination Branch',
                        border: OutlineInputBorder(),
                      ),
                      items: branches
                          .where((b) => b['branch_id'].toString() != fromId)
                          .map((b) {
                        final bid = b['branch_id'].toString();
                        final av = ((bStocks[bid] as Map?)?['quantity_available']
                                    as num?)
                                ?.toInt() ??
                            0;
                        return DropdownMenuItem(
                          value: bid,
                          child: Text('${b['name']} ($av currently available)'),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setModal(() => toId = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity to Transfer (Max: $srcAvail)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: refCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Waybill / Dispatch Reference (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: remCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Remarks',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                        if (qty <= 0 || qty > srcAvail) {
                          setModal(() => modalErr =
                              'Enter a valid quantity between 1 and $srcAvail.');
                          return;
                        }
                        setModal(() {
                          saving = true;
                          modalErr = null;
                        });
                        try {
                          final api = ref.read(procurementApiServiceProvider);
                          final res = await api.transferStock({
                            'from_branch_id': fromId,
                            'to_branch_id': toId,
                            'item_id': pickedItem!['item_id'].toString(),
                            'quantity': qty,
                            'reference_code': refCtrl.text.trim(),
                            'remarks': remCtrl.text.trim(),
                          });
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          _setFlash(
                            success:
                                'Transferred ${res['quantity']}x ${res['item_name']} from ${res['from_branch_name']} to ${res['to_branch_name']} (Ref: ${res['reference_code']}).',
                          );
                          await _loadData(silent: true);
                        } catch (e) {
                          setModal(() {
                            saving = false;
                            modalErr = AppErrorDetails.from(e).message;
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm Transfer'),
              ),
            ],
          );
        },
      ),
    );
    qtyCtrl.dispose();
    refCtrl.dispose();
    remCtrl.dispose();
  }

  // ===========================================================================
  // TAB 2: RECEIVE NEW STOCK (GRN) & DAMAGE WRITE-OFFS
  // ===========================================================================
  Widget _buildReceiveAndWriteOffTab(
    IcareSurfaceTokens tokens, {
    required bool canEdit,
  }) {
    if (!canEdit) {
      return _buildBanner(
        'Read-only access: only the Procurement Officer or Admin can post new stock receipts or write-offs.',
        isError: false,
        tokens: tokens,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              selected: _stockOpMode == 0,
              label: const Text('Receive New Stock (GRN)'),
              onSelected: (_) => setState(() => _stockOpMode = 0),
            ),
            ChoiceChip(
              selected: _stockOpMode == 1,
              label: const Text('Record Damaged / Lost Write-Off'),
              onSelected: (_) => setState(() => _stockOpMode = 1),
            ),
            OutlinedButton.icon(
              onPressed: () => _openCatalogItemModal(tokens),
              icon: const Icon(Icons.add_box_outlined, size: 17),
              label: const Text('Create New Catalog SKU'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_stockOpMode == 0)
          _buildGrnForm(tokens)
        else
          _buildWriteOffForm(tokens),
      ],
    );
  }

  Widget _buildGrnForm(IcareSurfaceTokens tokens) {
    final branches = _branches;
    final allSkus = _matrixItems;
    final totalUnits = _grnLines.fold<int>(
        0, (s, l) => s + ((l['quantity_received'] as num?)?.toInt() ?? 0));
    final totalCost = _grnLines.fold<double>(0.0, (s, l) {
      final qty = (l['quantity_received'] as num?)?.toInt() ?? 0;
      final cost = (l['unit_cost_price'] as num?)?.toDouble() ?? 0.0;
      return s + (qty * cost);
    });

    return _sectionCard(
      tokens: tokens,
      title: 'Goods Received Note (New Stock Entry)',
      subtitle:
          'Log supplier deliveries to any branch. Enter supplier unit cost when known, or leave blank until cost sheet is ready.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  value: _grnBranchId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Destination Branch',
                    border: OutlineInputBorder(),
                  ),
                  items: branches
                      .map((b) => DropdownMenuItem(
                            value: b['branch_id'].toString(),
                            child: Text(b['name'].toString()),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _grnBranchId = v),
                ),
              ),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _grnSupplierCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Supplier / Vendor Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _grnReferenceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Invoice / Waybill Ref',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _grnRemarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Remarks',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: tokens.borderSubtle),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _grnPickItemId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Asset SKU to Add to Delivery',
                    border: OutlineInputBorder(),
                  ),
                  items: allSkus
                      .map((it) => DropdownMenuItem(
                            value: it['item_id'].toString(),
                            child: Text(
                              '${it['item_name']} (${it['sku_code']}) — Cash ${CurrencyFormatter.formatNaira((it['cash_and_carry_price'] as num?)?.toDouble() ?? 0.0)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _grnPickItemId = v),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _grnPickItemId == null
                    ? null
                    : () {
                        final item = allSkus.firstWhere(
                            (e) => e['item_id'].toString() == _grnPickItemId);
                        if (_grnLines
                            .any((l) => l['item_id'] == item['item_id'])) {
                          return;
                        }
                        setState(() {
                          _grnLines.add({
                            'item_id': item['item_id'].toString(),
                            'sku_code': item['sku_code'],
                            'item_name': item['item_name'],
                            'quantity_received': 1,
                            'unit_cost_price':
                                (item['unit_cost_price'] as num?)?.toDouble() ??
                                    0.0,
                            'new_cash_price':
                                (item['cash_and_carry_price'] as num?)
                                        ?.toDouble() ??
                                    0.0,
                          });
                        });
                      },
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Add Line'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.brandPrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_grnLines.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Text(
                'No delivery lines added yet. Select an SKU above and click Add Line.',
                style: TextStyle(color: tokens.textMuted),
              ),
            )
          else
            ..._grnLines.asMap().entries.map((entry) {
              final idx = entry.key;
              final line = entry.value;
              final costV = (line['unit_cost_price'] as num?)?.toDouble() ?? 0.0;
              final cashV = (line['new_cash_price'] as num?)?.toDouble() ?? 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
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
                            '${line['item_name']} (${line['sku_code']})',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: tokens.dangerText),
                          onPressed: () =>
                              setState(() => _grnLines.removeAt(idx)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            initialValue: '${line['quantity_received']}',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Qty Received',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              setState(() {
                                line['quantity_received'] =
                                    int.tryParse(v.trim()) ?? 0;
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 210,
                          child: TextFormField(
                            initialValue:
                                costV > 0 ? costV.toStringAsFixed(0) : '',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Unit Cost Price (₦ — optional)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              final clean = v.replaceAll(',', '').trim();
                              setState(() {
                                line['unit_cost_price'] = clean.isEmpty
                                    ? 0.0
                                    : (double.tryParse(clean) ?? 0.0);
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 210,
                          child: TextFormField(
                            initialValue:
                                cashV > 0 ? cashV.toStringAsFixed(0) : '',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Cash & Carry Price (₦)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              final clean = v.replaceAll(',', '').trim();
                              setState(() {
                                line['new_cash_price'] = clean.isEmpty
                                    ? 0.0
                                    : (double.tryParse(clean) ?? 0.0);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Summary: ${_grnLines.length} SKU line(s)  •  $totalUnits unit(s)'
                  '${totalCost > 0 ? '  •  Receipt Cost: ${CurrencyFormatter.formatNaira(totalCost)}' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: (_isSubmitting || _grnLines.isEmpty || _grnBranchId == null)
                    ? null
                    : () async {
                        final invalid = _grnLines.any((l) =>
                            ((l['quantity_received'] as num?)?.toInt() ?? 0) <=
                            0);
                        if (invalid) {
                          _setFlash(
                            error:
                                'All delivery lines must have Quantity Received greater than 0.',
                          );
                          return;
                        }
                        setState(() => _isSubmitting = true);
                        try {
                          final api = ref.read(procurementApiServiceProvider);
                          final payload = {
                            'branch_id': _grnBranchId,
                            'supplier_name': _grnSupplierCtrl.text.trim(),
                            'reference_code': _grnReferenceCtrl.text.trim(),
                            'remarks': _grnRemarksCtrl.text.trim(),
                            'items': _grnLines.map((l) {
                              final c =
                                  (l['unit_cost_price'] as num?)?.toDouble() ??
                                      0.0;
                              final p =
                                  (l['new_cash_price'] as num?)?.toDouble() ??
                                      0.0;
                              return {
                                'item_id': l['item_id'],
                                'quantity_received': l['quantity_received'],
                                if (c > 0) 'unit_cost_price': c,
                                if (p > 0) 'new_cash_price': p,
                              };
                            }).toList(),
                          };
                          final res = await api.receiveStockBatch(payload);
                          setState(() {
                            _isSubmitting = false;
                            _grnLines.clear();
                            _grnReferenceCtrl.clear();
                            _grnRemarksCtrl.clear();
                          });
                          _setFlash(
                            success:
                                'Stock receipt posted at ${res['branch_name']}: ${res['total_units_received']} unit(s) received across ${res['total_lines']} SKU(s).',
                          );
                          await _loadData(silent: true);
                        } catch (e) {
                          setState(() => _isSubmitting = false);
                          _setFlash(error: AppErrorDetails.from(e).message);
                        }
                      },
                icon: const Icon(Icons.check_circle_outline, size: 17),
                label: Text(_isSubmitting ? 'Posting GRN...' : 'Post Stock Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWriteOffForm(IcareSurfaceTokens tokens) {
    final branches = _branches;
    final stockedAtBranch = _matrixItems.where((it) {
      final bStocks = (it['branch_stocks'] as Map?) ?? const {};
      final av = ((bStocks[_woBranchId] as Map?)?['quantity_available'] as num?)
              ?.toInt() ??
          0;
      return av > 0;
    }).toList();

    if (_woItemId != null &&
        !stockedAtBranch.any((x) => x['item_id'].toString() == _woItemId)) {
      _woItemId = null;
    }

    return _sectionCard(
      tokens: tokens,
      title: 'Record Damaged / Lost Asset Write-Off',
      subtitle:
          'Deducts unserviceable units from branch stock and records the loss in Asset P&L',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  value: _woBranchId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Branch',
                    border: OutlineInputBorder(),
                  ),
                  items: branches
                      .map((b) => DropdownMenuItem(
                            value: b['branch_id'].toString(),
                            child: Text(b['name'].toString()),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _woBranchId = v;
                    _woItemId = null;
                  }),
                ),
              ),
              SizedBox(
                width: 340,
                child: DropdownButtonFormField<String>(
                  value: _woItemId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Stocked SKU at Branch',
                    border: OutlineInputBorder(),
                  ),
                  items: stockedAtBranch.map((it) {
                    final bStocks = (it['branch_stocks'] as Map?) ?? const {};
                    final av =
                        ((bStocks[_woBranchId] as Map?)?['quantity_available']
                                    as num?)
                                ?.toInt() ??
                            0;
                    return DropdownMenuItem(
                      value: it['item_id'].toString(),
                      child: Text(
                        '${it['item_name']} (${it['sku_code']}) — $av avail',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _woItemId = v),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _woQtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Qty Lost/Damaged',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _woRefCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Incident Reference',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _woReasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Write-Off Reason / Audit Explanation (Required)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: (_isSubmitting || _woBranchId == null || _woItemId == null)
                ? null
                : () async {
                    final qty = int.tryParse(_woQtyCtrl.text.trim()) ?? 0;
                    final reason = _woReasonCtrl.text.trim();
                    if (qty <= 0 || reason.length < 2) {
                      _setFlash(
                        error:
                            'Enter a positive quantity and detailed reason for the write-off.',
                      );
                      return;
                    }
                    setState(() => _isSubmitting = true);
                    try {
                      final api = ref.read(procurementApiServiceProvider);
                      final res = await api.recordWriteOff({
                        'branch_id': _woBranchId,
                        'item_id': _woItemId,
                        'quantity': qty,
                        'reason': reason,
                        'reference_code': _woRefCtrl.text.trim(),
                      });
                      setState(() {
                        _isSubmitting = false;
                        _woItemId = null;
                        _woQtyCtrl.text = '1';
                        _woRefCtrl.clear();
                        _woReasonCtrl.clear();
                      });
                      _setFlash(
                        success:
                            'Write-off recorded for ${res['quantity_written_off']}x ${res['item_name']} at ${res['branch_name']} (Ref: ${res['reference_code']}).',
                      );
                      await _loadData(silent: true);
                    } catch (e) {
                      setState(() => _isSubmitting = false);
                      _setFlash(error: AppErrorDetails.from(e).message);
                    }
                  },
            icon: const Icon(Icons.report_problem_outlined, size: 17),
            label: Text(_isSubmitting ? 'Recording...' : 'Record Write-Off'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: MASTER PRICE LIST & SUPPLIER COST MANAGER
  // ===========================================================================
  Widget _buildPriceCatalogTab(
    IcareSurfaceTokens tokens, {
    required bool canEdit,
  }) {
    final q = _priceSearchCtrl.text.trim().toLowerCase();
    final filtered = _matrixItems.where((it) {
      if (_priceCategory != 'ALL' &&
          (it['category']?.toString().toUpperCase() ?? '') != _priceCategory) {
        return false;
      }
      final hasCost = it['has_cost_price'] == true;
      final totAvail = (it['total_available'] as num?)?.toInt() ?? 0;
      if (_costStatusFilter == 'PENDING' && hasCost) return false;
      if (_costStatusFilter == 'CONFIGURED' && !hasCost) return false;
      if (_costStatusFilter == 'IN_STOCK' && totAvail <= 0) return false;
      if (q.isNotEmpty) {
        final hay =
            '${it['item_name']} ${it['sku_code']} ${it['category']} ${it['supplier_name'] ?? ''}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _priceSearchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 18),
                        hintText: 'Search SKU, item, supplier...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<String>(
                      value: _priceCategory,
                      isExpanded: true,
                      dropdownColor: tokens.surfaceElevated,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: 'ALL', child: Text('All Categories')),
                        ..._categories.map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _priceCategory = v);
                      },
                    ),
                  ),
                  if (canEdit)
                    ElevatedButton.icon(
                      onPressed: () => _openCatalogItemModal(tokens),
                      icon: const Icon(Icons.add, size: 17),
                      label: const Text('Add New SKU'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ('ALL', 'All SKUs (${_matrixItems.length})'),
                    (
                      'PENDING',
                      'Cost Pending (${_matrixItems.where((x) => x['has_cost_price'] != true).length})'
                    ),
                    (
                      'CONFIGURED',
                      'Cost Configured (${_matrixItems.where((x) => x['has_cost_price'] == true).length})'
                    ),
                    (
                      'IN_STOCK',
                      'In Stock (${_matrixItems.where((x) => ((x['total_available'] as num?)?.toInt() ?? 0) > 0).length})'
                    ),
                  ].map((f) {
                    final selected = _costStatusFilter == f.$1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        selected: selected,
                        label: Text(f.$2),
                        onSelected: (_) =>
                            setState(() => _costStatusFilter = f.$1),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          tokens: tokens,
          title: 'Master Price & Supplier Cost Catalog (${filtered.length} SKUs)',
          subtitle:
              'Prices are strictly locked to Procurement Officer and Admin roles',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
              columns: [
                const DataColumn(label: Text('SKU')),
                const DataColumn(label: Text('Item Name')),
                const DataColumn(label: Text('Unit Cost Price'), numeric: true),
                const DataColumn(label: Text('Cash & Carry'), numeric: true),
                const DataColumn(label: Text('Easy Buy 60D'), numeric: true),
                const DataColumn(label: Text('Easy Buy 120D'), numeric: true),
                const DataColumn(label: Text('Retail Margin'), numeric: true),
                const DataColumn(label: Text('Total Stock'), numeric: true),
                if (canEdit) const DataColumn(label: Text('Edit')),
              ],
              rows: filtered.take(150).map((it) {
                final hasCost = it['has_cost_price'] == true;
                final costP = (it['unit_cost_price'] as num?)?.toDouble() ?? 0.0;
                final cashP =
                    (it['cash_and_carry_price'] as num?)?.toDouble() ?? 0.0;
                final p60 =
                    (it['easy_buy_60d_price'] as num?)?.toDouble() ?? 0.0;
                final p120 =
                    (it['easy_buy_120d_price'] as num?)?.toDouble() ?? 0.0;
                final marginAmt =
                    (it['retail_margin_amount'] as num?)?.toDouble() ?? 0.0;
                final marginPct =
                    (it['retail_margin_pct'] as num?)?.toDouble() ?? 0.0;

                return DataRow(
                  cells: [
                    DataCell(Text(it['sku_code']?.toString() ?? '')),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              it['item_name']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${it['category']}${it['supplier_name'] != null ? ' • ${it['supplier_name']}' : ''}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10.5, color: tokens.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      hasCost
                          ? Text(CurrencyFormatter.formatNaira(costP))
                          : _statusPill(
                              tokens,
                              'Cost Pending',
                              tokens.warningBg,
                              tokens.warningText,
                              tokens.warningBorder,
                            ),
                    ),
                    DataCell(Text(CurrencyFormatter.formatNaira(cashP))),
                    DataCell(Text(CurrencyFormatter.formatNaira(p60))),
                    DataCell(Text(CurrencyFormatter.formatNaira(p120))),
                    DataCell(Text(hasCost
                        ? '${CurrencyFormatter.formatNaira(marginAmt)} (${marginPct.toStringAsFixed(1)}%)'
                        : 'Pending')),
                    DataCell(Text('${it['total_available'] ?? 0}')),
                    if (canEdit)
                      DataCell(
                        IconButton(
                          tooltip: 'Edit Cost & Selling Prices',
                          icon: Icon(Icons.edit_outlined,
                              size: 18, color: tokens.brandPrimary),
                          onPressed: () =>
                              _openCatalogItemModal(tokens, existingItem: it),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCatalogItemModal(
    IcareSurfaceTokens tokens, {
    Map<String, dynamic>? existingItem,
  }) async {
    final isEdit = existingItem != null;
    final skuCtrl =
        TextEditingController(text: existingItem?['sku_code']?.toString() ?? '');
    final nameCtrl = TextEditingController(
        text: existingItem?['item_name']?.toString() ?? '');
    final supplierCtrl = TextEditingController(
        text: existingItem?['supplier_name']?.toString() ?? '');
    final existingCost =
        (existingItem?['unit_cost_price'] as num?)?.toDouble() ?? 0.0;
    final costCtrl = TextEditingController(
      text: existingCost > 0 ? existingCost.toStringAsFixed(0) : '',
    );
    final existingCash =
        (existingItem?['cash_and_carry_price'] as num?)?.toDouble() ?? 0.0;
    final cashCtrl = TextEditingController(
      text: existingCash > 0 ? existingCash.toStringAsFixed(0) : '',
    );
    final initQtyCtrl = TextEditingController(text: '0');

    final cats = _categories.isNotEmpty
        ? _categories
        : ['TELEVISION', 'FREEZER', 'PHONE', 'SOLAR SYSTEM', 'KITCHEN'];
    String catValue = existingItem?['category']?.toString() ?? cats.first;
    if (!cats.contains(catValue)) {
      cats.insert(0, catValue);
    }
    String? initBranchId = _branches.isNotEmpty
        ? _branches.first['branch_id'].toString()
        : null;
    bool saving = false;
    String? modalErr;

    await showIcareDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final dTokens = IcareSurfaceTokens.of(ctx);
          final parsedCost =
              double.tryParse(costCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
          final parsedCash =
              double.tryParse(cashCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
          final p60 = parsedCash * 1.12;
          final p120 = parsedCash * 1.21;
          final hasCost = parsedCost > 0;
          final margin = hasCost ? (parsedCash - parsedCost) : 0.0;
          final marginPct =
              hasCost && parsedCost > 0 ? (margin / parsedCost) * 100.0 : 0.0;

          return AlertDialog(
            backgroundColor: dTokens.surfaceElevated,
            title: Text(
              isEdit ? 'Edit Cost & Selling Prices' : 'Create New Catalog SKU',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: dTokens.textPrimary,
              ),
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (modalErr != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: dTokens.dangerBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: dTokens.dangerBorder),
                        ),
                        child: Text(modalErr!,
                            style: TextStyle(
                                color: dTokens.dangerText, fontSize: 12)),
                      ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: skuCtrl,
                            readOnly: isEdit,
                            decoration: InputDecoration(
                              labelText: isEdit
                                  ? 'SKU Code'
                                  : 'SKU Code (auto if blank)',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: catValue,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: cats
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c,
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setModal(() => catValue = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Asset Item Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: supplierCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Primary Supplier / Vendor (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setModal(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Supplier Cost Price (₦)',
                              helperText: 'Leave blank if Cost Pending',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: cashCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setModal(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Cash & Carry Price (₦)',
                              helperText: 'Auto-computes 60D & 120D',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: dTokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: dTokens.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live Pricing & Profit Preview',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: dTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Easy Buy 60D (+12%): ${CurrencyFormatter.formatNaira(p60)}  •  Easy Buy 120D (+21%): ${CurrencyFormatter.formatNaira(p120)}',
                            style: TextStyle(
                                fontSize: 11.5, color: dTokens.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasCost
                                ? 'Retail Profit / Unit: ${CurrencyFormatter.formatNaira(margin)} (${marginPct.toStringAsFixed(1)}%)  •  60D Total Profit: ${CurrencyFormatter.formatNaira(p60 - parsedCost)}'
                                : 'Retail Margin: Cost Pending  •  Financing Markup: ${CurrencyFormatter.formatNaira(p60 - parsedCash)} (60D) / ${CurrencyFormatter.formatNaira(p120 - parsedCash)} (120D)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: hasCost
                                  ? (margin >= 0
                                      ? dTokens.successText
                                      : dTokens.dangerText)
                                  : dTokens.infoText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isEdit && _branches.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: initBranchId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Initial Stock Branch',
                                border: OutlineInputBorder(),
                              ),
                              items: _branches
                                  .map((b) => DropdownMenuItem(
                                        value: b['branch_id'].toString(),
                                        child: Text(b['name'].toString()),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setModal(() => initBranchId = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: initQtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Opening Qty',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          setModal(() => modalErr = 'Item name is required.');
                          return;
                        }
                        setModal(() {
                          saving = true;
                          modalErr = null;
                        });
                        try {
                          final api = ref.read(procurementApiServiceProvider);
                          await api.upsertCatalogItem({
                            if (isEdit)
                              'item_id': existingItem['item_id'].toString(),
                            if (skuCtrl.text.trim().isNotEmpty)
                              'sku_code': skuCtrl.text.trim(),
                            'category': catValue,
                            'item_name': nameCtrl.text.trim(),
                            'unit_cost_price': parsedCost,
                            'cash_and_carry_price': parsedCash,
                            if (supplierCtrl.text.trim().isNotEmpty)
                              'supplier_name': supplierCtrl.text.trim(),
                            if (!isEdit && initBranchId != null)
                              'initial_branch_id': initBranchId,
                            if (!isEdit)
                              'initial_quantity':
                                  int.tryParse(initQtyCtrl.text.trim()) ?? 0,
                          });
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          _setFlash(
                            success: isEdit
                                ? 'Updated pricing for ${nameCtrl.text.trim()}.'
                                : 'Created new catalog SKU: ${nameCtrl.text.trim()}.',
                          );
                          await _loadData(silent: true);
                        } catch (e) {
                          setModal(() {
                            saving = false;
                            modalErr = AppErrorDetails.from(e).message;
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEdit ? 'Save Pricing' : 'Create SKU'),
              ),
            ],
          );
        },
      ),
    );

    skuCtrl.dispose();
    nameCtrl.dispose();
    supplierCtrl.dispose();
    costCtrl.dispose();
    cashCtrl.dispose();
    initQtyCtrl.dispose();
  }

  // ===========================================================================
  // UI BUILDING BLOCKS
  // ===========================================================================
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5,
              color: tokens.textMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IcareSurfaceTokens tokens,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: tokens.textMuted),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _statusPill(
    IcareSurfaceTokens tokens,
    String label,
    Color bg,
    Color fg,
    Color border,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _movementBadge(IcareSurfaceTokens tokens, String mType) {
    Color bg = tokens.surfaceSubtle;
    Color fg = tokens.textSecondary;
    Color bd = tokens.borderSubtle;
    if (mType == 'RESTOCK' || mType == 'TRANSFER_IN') {
      bg = tokens.successBg;
      fg = tokens.successText;
      bd = tokens.successBorder;
    } else if (mType == 'DAMAGE_WRITE_OFF') {
      bg = tokens.dangerBg;
      fg = tokens.dangerText;
      bd = tokens.dangerBorder;
    } else if (mType == 'DEDUCT_ON_DISBURSE' ||
        mType == 'TRANSFER_OUT' ||
        mType == 'PRICE_UPDATE') {
      bg = tokens.infoBg;
      fg = tokens.infoText;
      bd = tokens.infoBorder;
    } else if (mType == 'RESERVE_ON_APPLY') {
      bg = tokens.warningBg;
      fg = tokens.warningText;
      bd = tokens.warningBorder;
    }
    return _statusPill(tokens, mType, bg, fg, bd);
  }
}
