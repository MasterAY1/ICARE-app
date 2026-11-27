import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/app_error_formatter.dart';
import '../../../core/theme/icare_motion.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/icare_card.dart';
import '../../../core/widgets/icare_metric_card.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../data/datasources/procurement_api_service.dart';
import 'widgets/procurement_analytics_charts.dart';

/// Shared navigation & filter coordination providers so quick actions on
/// ProcurementDashboardScreen can land directly on any Asset & Procurement tab.
final activeProcurementTabProvider = StateProvider<int>((ref) => 0);
final activeProcurementStockOpModeProvider = StateProvider<int>((ref) => 0);
final activeProcurementCostFilterProvider =
    StateProvider<String>((ref) => 'ALL');

/// Strict client-side write permission check: only Procurement Officer / Asset Manager.
bool isProcurementOperatorRole(AuthUser? user) {
  final role = (user?.role ?? '').trim().toLowerCase();
  return role == 'procurement officer' ||
      role == 'procurement_officer' ||
      role == 'asset manager' ||
      role == 'asset_manager' ||
      role == 'procurement' ||
      role == 'po';
}

/// Asset Catalog & Procurement Operations workspace.
/// - For Procurement Officers: full catalog/pricing management, multi-branch stock
///   transfers, supplier GRN receipts, and damage/loss write-offs.
/// - For Admin / Executive viewers: read-only institution directory, stock matrix,
///   branch valuation breakdown, and movement audit log.
class AssetProcurementScreen extends ConsumerStatefulWidget {
  final int? initialTabIndex;

  const AssetProcurementScreen({
    super.key,
    this.initialTabIndex,
  });

  @override
  ConsumerState<AssetProcurementScreen> createState() =>
      _AssetProcurementScreenState();
}

class _AssetProcurementScreenState
    extends ConsumerState<AssetProcurementScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  String? _flashSuccess;
  String? _flashError;

  Map<String, dynamic> _overview = {};
  Map<String, dynamic> _matrix = {};

  // Tab 0 (Master Catalog & Pricing) state
  final _priceSearchCtrl = TextEditingController();
  String _priceCategory = 'ALL';
  int _pricePage = 0;
  int _pricePageSize = 50;

  // Tab 1 (Multi-Branch Stock Matrix) state
  final _matrixSearchCtrl = TextEditingController();
  String _matrixCategory = 'ALL';
  bool _matrixInStockOnly = false;
  int _matrixPage = 0;
  int _matrixPageSize = 50;

  // Tab 2 (Procurement Officer: GRN vs Write-Off) state
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

  @override
  void initState() {
    super.initState();
    if (widget.initialTabIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(activeProcurementTabProvider.notifier).state =
            widget.initialTabIndex!.clamp(0, 2);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void didUpdateWidget(covariant AssetProcurementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != null &&
        oldWidget.initialTabIndex != widget.initialTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(activeProcurementTabProvider.notifier).state =
            widget.initialTabIndex!.clamp(0, 2);
      });
    }
  }

  @override
  void dispose() {
    _priceSearchCtrl.dispose();
    _matrixSearchCtrl.dispose();
    _grnSupplierCtrl.dispose();
    _grnReferenceCtrl.dispose();
    _grnRemarksCtrl.dispose();
    _woQtyCtrl.dispose();
    _woRefCtrl.dispose();
    _woReasonCtrl.dispose();
    super.dispose();
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
        api.getOverview(),
        api.getStockMatrix(),
      ]);
      if (!mounted) return;
      final ov = results[0];
      final mx = results[1];
      final branches = (ov['branches'] as List<dynamic>? ?? const [])
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
    final raw =
        (_matrix['categories'] ?? _overview['categories']) as List<dynamic>?;
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
    final canEdit = isProcurementOperatorRole(user);
    final activeTab = ref.watch(activeProcurementTabProvider).clamp(0, 2);

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
        _buildWorkspaceHeader(
          tokens: tokens,
          canEdit: canEdit,
          isMobile: isMobile,
        ),
        const SizedBox(height: 14),

        if (!canEdit) ...[
          _buildReadOnlyGovernanceBanner(tokens),
          const SizedBox(height: 14),
        ],

        if (_flashSuccess != null) ...[
          _buildBanner(_flashSuccess!, isError: false, tokens: tokens),
          const SizedBox(height: 12),
        ],
        if (_flashError != null) ...[
          _buildBanner(_flashError!, isError: true, tokens: tokens),
          const SizedBox(height: 12),
        ],

        if (!_isLoading && _loadError == null) ...[
          _buildSummaryStrip(tokens),
          const SizedBox(height: 16),
          ProcurementAnalyticsSection(
            branchSummaries: (_overview['branch_summaries'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
            matrixItems: _matrixItems,
          ),
          const SizedBox(height: 16),
        ],

        _buildWorkspaceTabs(tokens, activeTab: activeTab, canEdit: canEdit),
        const SizedBox(height: 16),

        if (_isLoading)
          const IcareTableSkeleton(rowCount: 7, hasFilterBar: true)
        else if (_loadError != null)
          IcareCard(
            padding: const EdgeInsets.all(20),
            topAccentColor: tokens.dangerDot,
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: tokens.dangerDot, size: 22),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Unable to load asset inventory data: $_loadError',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.dangerText),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.refresh, size: 15),
                  label: const Text('Retry'),
                ),
              ],
            ),
          )
        else
          _buildTabBody(
            tokens,
            activeTab: activeTab,
            canEdit: canEdit,
            isMobile: isMobile,
          ),
      ],
    );
  }

  Widget _buildWorkspaceHeader({
    required IcareSurfaceTokens tokens,
    required bool canEdit,
    required bool isMobile,
  }) {
    final eyebrow = canEdit
        ? 'PROCUREMENT OPERATIONS WORKSPACE'
        : 'EXECUTIVE READ-ONLY OVERSIGHT';
    final title = canEdit
        ? 'Asset Catalog & Procurement Operations'
        : 'Institution Asset & Inventory Directory';
    final subtitle = canEdit
        ? 'Manage master asset pricing, supplier cost prices, multi-branch stock transfers, GRN stock receiving, and write-offs.'
        : 'Executive read-only oversight of all master catalog assets, branch stock levels, pricing tiers, and movement logs.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 760,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: canEdit ? tokens.brandSoftBg : tokens.infoBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: canEdit
                          ? tokens.brandSoftBorder
                          : tokens.infoBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        canEdit
                            ? Icons.inventory_2_outlined
                            : Icons.visibility_outlined,
                        size: 13,
                        color:
                            canEdit ? tokens.brandSoftText : tokens.infoText,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          eyebrow,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                            color:
                                canEdit ? tokens.brandSoftText : tokens.infoText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 23,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: tokens.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canEdit) ...[
                ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _openCatalogItemModal(tokens),
                  icon: const Icon(Icons.add_box_outlined, size: 17),
                  label: const Text('Add New SKU'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _loadData(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.textPrimary,
                  side: BorderSide(color: tokens.borderStrong),
                  backgroundColor: tokens.surfaceSubtle,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyGovernanceBanner(IcareSurfaceTokens tokens) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: tokens.infoBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.infoBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: tokens.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.infoBorder),
            ),
            child: Icon(Icons.shield_outlined, size: 18, color: tokens.infoDot),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Executive Read-Only View',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: tokens.infoText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'You can inspect all asset catalog prices, multi-branch stock levels, valuations, and movement history. Stock adjustments, transfers, GRN receiving, and price edits are restricted exclusively to the Procurement Officer.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: tokens.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip(IcareSurfaceTokens tokens) {
    final items = _matrixItems;
    final totalSkus = items.length;
    final inStockSkus = items
        .where((x) => ((x['total_available'] as num?)?.toInt() ?? 0) > 0)
        .length;
    final costConfigured =
        items.where((x) => x['has_cost_price'] == true).length;
    final costPending = totalSkus - costConfigured;

    final totalAvail = items.fold<int>(
      0,
      (s, x) => s + ((x['total_available'] as num?)?.toInt() ?? 0),
    );
    final totalOnHand = items.fold<int>(
      0,
      (s, x) => s + ((x['total_on_hand'] as num?)?.toInt() ?? 0),
    );
    final totalReserved = items.fold<int>(
      0,
      (s, x) => s + ((x['total_reserved'] as num?)?.toInt() ?? 0),
    );

    final invSum = Map<String, dynamic>.from(
      (_overview['inventory_summary'] as Map?) ?? const {},
    );
    final retailValue =
        (invSum['inventory_cash_value'] as num?)?.toDouble() ??
            items.fold<double>(0.0, (s, x) {
              final oh = (x['total_on_hand'] as num?)?.toInt() ?? 0;
              final cash = (x['cash_and_carry_price'] as num?)?.toDouble() ?? 0.0;
              return s + (oh * cash);
            });
    final costValue =
        (invSum['inventory_cost_value'] as num?)?.toDouble() ?? 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 980
            ? 4
            : (constraints.maxWidth >= 560 ? 2 : 1);
        const spacing = 12.0;
        final tileWidth =
            (constraints.maxWidth - (cols - 1) * spacing) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _summaryMetricTile(
              tokens: tokens,
              width: tileWidth,
              icon: Icons.category_outlined,
              accent: tokens.brandPrimary,
              label: 'Total Catalog SKUs',
              value: '$totalSkus SKUs',
              detail: '$costConfigured costed  •  $costPending pending cost',
            ),
            _summaryMetricTile(
              tokens: tokens,
              width: tileWidth,
              icon: Icons.check_circle_outline,
              accent: tokens.successDot,
              label: 'In-Stock SKUs',
              value: '$inStockSkus SKUs',
              detail: 'Across ${_categories.length} active asset categories',
            ),
            _summaryMetricTile(
              tokens: tokens,
              width: tileWidth,
              icon: Icons.inventory_2_outlined,
              accent: tokens.infoDot,
              label: 'Total Available Units',
              value: '$totalAvail units',
              detail: '$totalOnHand on hand  •  $totalReserved reserved',
            ),
            _summaryMetricTile(
              tokens: tokens,
              width: tileWidth,
              icon: Icons.account_balance_wallet_outlined,
              accent: tokens.brandPrimaryLight,
              label: 'Total Retail Stock Value',
              value: CurrencyFormatter.formatNaira(retailValue),
              detail: costValue > 0
                  ? 'Wholesale Cost: ${CurrencyFormatter.formatNaira(costValue)}'
                  : 'Wholesale Cost Valuation: Pending',
            ),
          ],
        );
      },
    );
  }

  Widget _summaryMetricTile({
    required IcareSurfaceTokens tokens,
    required double width,
    required IconData icon,
    required Color accent,
    required String label,
    required String value,
    required String detail,
  }) {
    return SizedBox(
      width: width,
      child: IcareMetricCard(
        label: label,
        value: value,
        delta: detail,
        icon: icon,
        topBorderColor: accent,
      ),
    );
  }

  Widget _buildWorkspaceTabs(
    IcareSurfaceTokens tokens, {
    required int activeTab,
    required bool canEdit,
  }) {
    final tabs = [
      (0, 'Master Catalog & Pricing', Icons.sell_outlined),
      (1, 'Multi-Branch Stock Matrix', Icons.swap_horiz_outlined),
      if (canEdit)
        (2, 'Receive Stock (GRN) & Write-Offs', Icons.inventory_2_outlined)
      else
        (2, 'Branch Valuation & Movement Log', Icons.history_edu_outlined),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final selected = activeTab == tab.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () {
                  ref.read(activeProcurementTabProvider.notifier).state =
                      tab.$1;
                },
                borderRadius: BorderRadius.circular(9),
                child: AnimatedContainer(
                  duration: IcareFluidMotion.resolveDuration(
                    context,
                    IcareFluidMotion.microDuration,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? tokens.brandPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: selected
                          ? tokens.brandPrimary
                          : Colors.transparent,
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
                      const SizedBox(width: 8),
                      Text(
                        tab.$2,
                        style: TextStyle(
                          fontSize: 13,
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
    required int activeTab,
    required bool canEdit,
    required bool isMobile,
  }) {
    switch (activeTab) {
      case 0:
        return _buildPriceCatalogTab(tokens, canEdit: canEdit);
      case 1:
        return _buildMatrixTab(tokens, canEdit: canEdit);
      case 2:
        if (canEdit) {
          return _buildReceiveAndWriteOffTab(tokens);
        }
        return _buildAdminAuditAndValuationTab(tokens, isMobile: isMobile);
      default:
        return const SizedBox.shrink();
    }
  }

  // ===========================================================================
  // TAB 0: MASTER CATALOG & PRICING
  // ===========================================================================
  Widget _buildPriceCatalogTab(
    IcareSurfaceTokens tokens, {
    required bool canEdit,
  }) {
    final costStatusFilter = ref.watch(activeProcurementCostFilterProvider);
    final q = _priceSearchCtrl.text.trim().toLowerCase();

    final filtered = _matrixItems.where((it) {
      if (_priceCategory != 'ALL' &&
          (it['category']?.toString().toUpperCase() ?? '') != _priceCategory) {
        return false;
      }
      final hasCost = it['has_cost_price'] == true;
      final totAvail = (it['total_available'] as num?)?.toInt() ?? 0;
      if (costStatusFilter == 'PENDING' && hasCost) return false;
      if (costStatusFilter == 'CONFIGURED' && !hasCost) return false;
      if (costStatusFilter == 'IN_STOCK' && totAvail <= 0) return false;
      if (costStatusFilter == 'OUT_OF_STOCK' && totAvail > 0) return false;
      if (q.isNotEmpty) {
        final hay =
            '${it['item_name']} ${it['sku_code']} ${it['category']} ${it['supplier_name'] ?? ''}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    final totalCount = filtered.length;
    final totalPages = totalCount == 0 ? 1 : (totalCount / _pricePageSize).ceil();
    final safePage = _pricePage.clamp(0, totalPages - 1);
    final startIdx = safePage * _pricePageSize;
    final endIdx = (startIdx + _pricePageSize).clamp(0, totalCount);
    final pageRows = filtered.sublist(startIdx, endIdx);

    final inStockCount = _matrixItems
        .where((x) => ((x['total_available'] as num?)?.toInt() ?? 0) > 0)
        .length;
    final outStockCount = _matrixItems.length - inStockCount;
    final costConfiguredCount =
        _matrixItems.where((x) => x['has_cost_price'] == true).length;
    final costPendingCount = _matrixItems.length - costConfiguredCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
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
                    width: 270,
                    child: TextField(
                      controller: _priceSearchCtrl,
                      onChanged: (_) => setState(() => _pricePage = 0),
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 18),
                        hintText: 'Search SKU, item, supplier...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 240,
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
                        if (v != null) {
                          setState(() {
                            _priceCategory = v;
                            _pricePage = 0;
                          });
                        }
                      },
                    ),
                  ),
                  if (canEdit)
                    ElevatedButton.icon(
                      onPressed: () => _openCatalogItemModal(tokens),
                      icon: const Icon(Icons.add, size: 17),
                      label: const Text('Add New Asset SKU'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ('ALL', 'All SKUs (${_matrixItems.length})'),
                    ('IN_STOCK', 'In Stock ($inStockCount)'),
                    ('OUT_OF_STOCK', 'Out of Stock ($outStockCount)'),
                    ('PENDING', 'Cost Pending ($costPendingCount)'),
                    ('CONFIGURED', 'Cost Configured ($costConfiguredCount)'),
                  ].map((f) {
                    final selected = costStatusFilter == f.$1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        selected: selected,
                        label: Text(f.$2),
                        onSelected: (_) {
                          ref
                              .read(activeProcurementCostFilterProvider.notifier)
                              .state = f.$1;
                          setState(() => _pricePage = 0);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ProcurementSectionCard(
          tokens: tokens,
          title: 'Master Asset Catalog & Pricing ($totalCount matching SKUs)',
          subtitle: canEdit
              ? 'Edit wholesale cost prices and approved Cash & Carry retail tiers across all catalog SKUs'
              : 'Read-only directory of approved wholesale cost prices, retail tiers, and available stock',
          trailing: _paginationSummaryPill(tokens, startIdx, endIdx, totalCount),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pageRows.isEmpty)
                _emptyTableState(
                  tokens,
                  'No catalog SKUs match your current search or filter criteria.',
                )
              else
                ProcurementFullWidthTable(
                  tokens: tokens,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(tokens.surfaceSubtle),
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    dataRowMinHeight: 50,
                    dataRowMaxHeight: 62,
                    columns: [
                      const DataColumn(label: Text('SKU')),
                      const DataColumn(label: Text('Asset Item & Category')),
                      const DataColumn(
                          label: Text('Unit Cost Price'), numeric: true),
                      const DataColumn(
                          label: Text('Cash & Carry'), numeric: true),
                      const DataColumn(
                          label: Text('Easy Buy 60D (+12%)'), numeric: true),
                      const DataColumn(
                          label: Text('Easy Buy 120D (+21%)'), numeric: true),
                      const DataColumn(
                          label: Text('Retail Margin'), numeric: true),
                      const DataColumn(
                          label: Text('Available Stock'), numeric: true),
                      if (canEdit) const DataColumn(label: Text('Actions')),
                    ],
                    rows: pageRows.map((it) {
                      final hasCost = it['has_cost_price'] == true;
                      final costP =
                          (it['unit_cost_price'] as num?)?.toDouble() ?? 0.0;
                      final cashP =
                          (it['cash_and_carry_price'] as num?)?.toDouble() ??
                              0.0;
                      final p60 =
                          (it['easy_buy_60d_price'] as num?)?.toDouble() ?? 0.0;
                      final p120 =
                          (it['easy_buy_120d_price'] as num?)?.toDouble() ??
                              0.0;
                      final marginAmt =
                          (it['retail_margin_amount'] as num?)?.toDouble() ??
                              0.0;
                      final marginPct =
                          (it['retail_margin_pct'] as num?)?.toDouble() ?? 0.0;
                      final avail =
                          (it['total_available'] as num?)?.toInt() ?? 0;

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              it['sku_code']?.toString() ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                  minWidth: 180, maxWidth: 260),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    it['item_name']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${it['category']}${it['supplier_name'] != null ? ' • ${it['supplier_name']}' : ''}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: tokens.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            hasCost
                                ? Text(
                                    CurrencyFormatter.formatNaira(costP),
                                    style: const TextStyle(
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  )
                                : ProcurementStatusPill(
                                    label: 'Cost Pending',
                                    bg: tokens.warningBg,
                                    fg: tokens.warningText,
                                    border: tokens.warningBorder,
                                  ),
                          ),
                          DataCell(Text(
                            CurrencyFormatter.formatNaira(cashP),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          )),
                          DataCell(Text(
                            CurrencyFormatter.formatNaira(p60),
                            style: const TextStyle(
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          )),
                          DataCell(Text(
                            CurrencyFormatter.formatNaira(p120),
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
                                  ? (marginAmt >= 0
                                      ? tokens.successText
                                      : tokens.dangerText)
                                  : tokens.textMuted,
                              fontWeight: hasCost
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          )),
                          DataCell(
                            ProcurementStatusPill(
                              label: avail > 0 ? '$avail in stock' : '0 units',
                              bg: avail > 0
                                  ? tokens.successBg
                                  : tokens.surfaceSubtle,
                              fg: avail > 0
                                  ? tokens.successText
                                  : tokens.textMuted,
                              border: avail > 0
                                  ? tokens.successBorder
                                  : tokens.borderSubtle,
                            ),
                          ),
                          if (canEdit)
                            DataCell(
                              OutlinedButton.icon(
                                onPressed: () => _openCatalogItemModal(
                                  tokens,
                                  existingItem: it,
                                ),
                                icon: Icon(Icons.edit_outlined,
                                    size: 15, color: tokens.brandPrimary),
                                label: Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.brandPrimary,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side:
                                      BorderSide(color: tokens.borderStrong),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                ),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 12),
              _buildPaginationBar(
                tokens: tokens,
                page: safePage,
                totalPages: totalPages,
                pageSize: _pricePageSize,
                totalCount: totalCount,
                onPageChanged: (p) => setState(() => _pricePage = p),
                onPageSizeChanged: (sz) => setState(() {
                  _pricePageSize = sz;
                  _pricePage = 0;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 1: MULTI-BRANCH STOCK MATRIX
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

    final totalCount = filtered.length;
    final totalPages =
        totalCount == 0 ? 1 : (totalCount / _matrixPageSize).ceil();
    final safePage = _matrixPage.clamp(0, totalPages - 1);
    final startIdx = safePage * _matrixPageSize;
    final endIdx = (startIdx + _matrixPageSize).clamp(0, totalCount);
    final pageRows = filtered.sublist(startIdx, endIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
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
                width: 270,
                child: TextField(
                  controller: _matrixSearchCtrl,
                  onChanged: (_) => setState(() => _matrixPage = 0),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Search SKU or asset name...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 240,
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
                    if (v != null) {
                      setState(() {
                        _matrixCategory = v;
                        _matrixPage = 0;
                      });
                    }
                  },
                ),
              ),
              FilterChip(
                selected: _matrixInStockOnly,
                label: const Text('In Stock Anywhere'),
                onSelected: (v) => setState(() {
                  _matrixInStockOnly = v;
                  _matrixPage = 0;
                }),
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
        ProcurementSectionCard(
          tokens: tokens,
          title:
              'Cross-Branch Physical Inventory Matrix ($totalCount matching SKUs)',
          subtitle: canEdit
              ? 'Available physical units across all active ICARE branches with inter-branch dispatch controls'
              : 'Read-only view of available and reserved physical units across all active branches',
          trailing: _paginationSummaryPill(tokens, startIdx, endIdx, totalCount),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pageRows.isEmpty)
                _emptyTableState(
                  tokens,
                  'No branch inventory items match the active filters.',
                )
              else
                ProcurementFullWidthTable(
                  tokens: tokens,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(tokens.surfaceSubtle),
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    dataRowMinHeight: 50,
                    dataRowMaxHeight: 62,
                    columns: [
                      const DataColumn(label: Text('SKU')),
                      const DataColumn(label: Text('Item Name & Category')),
                      const DataColumn(
                          label: Text('Cash Price'), numeric: true),
                      const DataColumn(
                          label: Text('Total Avail'), numeric: true),
                      ...branches.map(
                        (b) => DataColumn(
                          label: Text(b['name']?.toString() ?? 'Branch'),
                          numeric: true,
                        ),
                      ),
                      if (canEdit) const DataColumn(label: Text('Action')),
                    ],
                    rows: pageRows.map((it) {
                      final bStocks = (it['branch_stocks'] as Map?) ?? const {};
                      final totAvail =
                          (it['total_available'] as num?)?.toInt() ?? 0;
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              it['sku_code']?.toString() ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                  minWidth: 180, maxWidth: 250),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    it['item_name']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    it['category']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: tokens.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(Text(
                            CurrencyFormatter.formatNaira(
                              (it['cash_and_carry_price'] as num?)
                                      ?.toDouble() ??
                                  0.0,
                            ),
                            style: const TextStyle(
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          )),
                          DataCell(
                            ProcurementStatusPill(
                              label: '$totAvail',
                              bg: totAvail > 0
                                  ? tokens.successBg
                                  : tokens.surfaceSubtle,
                              fg: totAvail > 0
                                  ? tokens.successText
                                  : tokens.textMuted,
                              border: totAvail > 0
                                  ? tokens.successBorder
                                  : tokens.borderSubtle,
                            ),
                          ),
                          ...branches.map((b) {
                            final bid = b['branch_id']?.toString() ?? '';
                            final st = (bStocks[bid] as Map?) ??
                                const <String, dynamic>{};
                            final av =
                                (st['quantity_available'] as num?)?.toInt() ??
                                    0;
                            final rsv =
                                (st['quantity_reserved'] as num?)?.toInt() ?? 0;
                            return DataCell(
                              Text(
                                rsv > 0 ? '$av ($rsv rsv)' : '$av',
                                style: TextStyle(
                                  fontWeight: av > 0
                                      ? FontWeight.w800
                                      : FontWeight.w400,
                                  color: av > 0
                                      ? tokens.successText
                                      : tokens.textMuted,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            );
                          }),
                          if (canEdit)
                            DataCell(
                              OutlinedButton.icon(
                                onPressed:
                                    totAvail <= 0 || branches.length < 2
                                        ? null
                                        : () => _openTransferDialog(
                                              tokens,
                                              preselectedItem: it,
                                            ),
                                icon: const Icon(Icons.swap_horiz, size: 15),
                                label: const Text('Transfer'),
                                style: OutlinedButton.styleFrom(
                                  side:
                                      BorderSide(color: tokens.borderStrong),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                ),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 12),
              _buildPaginationBar(
                tokens: tokens,
                page: safePage,
                totalPages: totalPages,
                pageSize: _matrixPageSize,
                totalCount: totalCount,
                onPageChanged: (p) => setState(() => _matrixPage = p),
                onPageSizeChanged: (sz) => setState(() {
                  _matrixPageSize = sz;
                  _matrixPage = 0;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2 (PROCUREMENT OFFICER): RECEIVE STOCK (GRN) & WRITE-OFFS
  // ===========================================================================
  Widget _buildReceiveAndWriteOffTab(IcareSurfaceTokens tokens) {
    final stockOpMode = ref.watch(activeProcurementStockOpModeProvider);
    final movements =
        (_overview['recent_movements'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
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
              ChoiceChip(
                selected: stockOpMode == 0,
                label: const Text('Receive Supplier Stock (GRN)'),
                onSelected: (_) {
                  ref
                      .read(activeProcurementStockOpModeProvider.notifier)
                      .state = 0;
                },
              ),
              ChoiceChip(
                selected: stockOpMode == 1,
                label: const Text('Record Damaged / Lost Write-Off'),
                onSelected: (_) {
                  ref
                      .read(activeProcurementStockOpModeProvider.notifier)
                      .state = 1;
                },
              ),
              OutlinedButton.icon(
                onPressed: () => _openCatalogItemModal(tokens),
                icon: const Icon(Icons.add_box_outlined, size: 17),
                label: const Text('Create New Catalog SKU'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (stockOpMode == 0)
          _buildGrnForm(tokens)
        else
          _buildWriteOffForm(tokens),
        const SizedBox(height: 18),
        ProcurementMovementLedgerCard(
          tokens: tokens,
          movements: movements,
          branches: _branches,
          title: 'Recent Stock Receipts & Write-Off Ledger',
          subtitle:
              'Latest posted deliveries, transfers, disbursements, write-offs, and price updates',
          showBranchFilter: true,
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2 (ADMIN READ-ONLY): BRANCH VALUATION & MOVEMENT LOG
  // ===========================================================================
  Widget _buildAdminAuditAndValuationTab(
    IcareSurfaceTokens tokens, {
    required bool isMobile,
  }) {
    final branchSummaries =
        (_overview['branch_summaries'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    final movements =
        (_overview['recent_movements'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProcurementSectionCard(
          tokens: tokens,
          title: 'Branch Stock & Valuation Breakdown',
          subtitle:
              'Physical units and valuation at wholesale cost vs Cash & Carry selling price across all branches',
          child: ProcurementBranchValuationTable(
            tokens: tokens,
            branchSummaries: branchSummaries,
          ),
        ),
        const SizedBox(height: 18),
        ProcurementMovementLedgerCard(
          tokens: tokens,
          movements: movements,
          branches: _branches,
          title: 'Stock & Price Movement Audit Trail',
          subtitle:
              'Read-only ledger of all stock receipts, transfers, disbursements, write-offs, and approved price updates',
          showBranchFilter: true,
        ),
      ],
    );
  }

  // ===========================================================================
  // TRANSFER DIALOG & GRN / WRITE-OFF / CATALOG MODALS
  // ===========================================================================
  Future<void> _openTransferDialog(
    IcareSurfaceTokens tokens, {
    Map<String, dynamic>? preselectedItem,
  }) async {
    final authState = ref.read(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    if (!isProcurementOperatorRole(user)) return;

    final branches = _branches;
    if (branches.length < 2) return;

    Map<String, dynamic>? pickedItem = preselectedItem ??
        _matrixItems.cast<Map<String, dynamic>?>().firstWhere(
              (x) => ((x?['total_available'] as num?)?.toInt() ?? 0) > 0,
              orElse: () =>
                  _matrixItems.isNotEmpty ? _matrixItems.first : null,
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

    await showIcareAdaptiveSheet<void>(
      context: context,
      fitContent: true,
      desktopConstraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
      builder: (ctx, isDialog) => StatefulBuilder(
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
              !stockedOptions
                  .any((x) => x['item_id'] == pickedItem!['item_id'])) {
            stockedOptions.insert(0, pickedItem!);
          }

          return Material(
            color: dTokens.surfaceElevated,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                isDialog ? 20 : 12,
                20,
                20 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isDialog)
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: dTokens.borderStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  Text(
                    'Transfer Stock Between Branches',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: dTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
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
                    dropdownColor: dTokens.surfaceElevated,
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
                              .firstWhere((b) =>
                                  b['branch_id'].toString() !=
                                  fromId)['branch_id']
                              .toString();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: fromId,
                    isExpanded: true,
                    dropdownColor: dTokens.surfaceElevated,
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
                              .firstWhere((b) =>
                                  b['branch_id'].toString() !=
                                  fromId)['branch_id']
                              .toString();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: toId,
                    isExpanded: true,
                    dropdownColor: dTokens.surfaceElevated,
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
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dTokens.brandPrimaryDark,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: dTokens.surfaceHover,
                          disabledForegroundColor: dTokens.textMuted,
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Confirm Transfer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        qtyCtrl.dispose();
        refCtrl.dispose();
        remCtrl.dispose();
      });
    });
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

    return ProcurementSectionCard(
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
                  dropdownColor: tokens.surfaceElevated,
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
                  dropdownColor: tokens.surfaceElevated,
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
                onPressed: (_isSubmitting ||
                        _grnLines.isEmpty ||
                        _grnBranchId == null)
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
                              final c = (l['unit_cost_price'] as num?)
                                      ?.toDouble() ??
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

    return ProcurementSectionCard(
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
                  dropdownColor: tokens.surfaceElevated,
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
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
                child: DropdownButtonFormField<String>(
                  value: _woItemId,
                  isExpanded: true,
                  dropdownColor: tokens.surfaceElevated,
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
            onPressed:
                (_isSubmitting || _woBranchId == null || _woItemId == null)
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
              backgroundColor: tokens.isDark ? tokens.dangerBorder : tokens.dangerText,
              foregroundColor: Colors.white,
              disabledBackgroundColor: tokens.surfaceHover,
              disabledForegroundColor: tokens.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCatalogItemModal(
    IcareSurfaceTokens tokens, {
    Map<String, dynamic>? existingItem,
  }) async {
    final authState = ref.read(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    if (!isProcurementOperatorRole(user)) return;

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

    await showIcareAdaptiveSheet<void>(
      context: context,
      fitContent: true,
      desktopConstraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
      builder: (ctx, isDialog) => StatefulBuilder(
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

          return Material(
            color: dTokens.surfaceElevated,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                isDialog ? 20 : 12,
                20,
                20 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isDialog)
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: dTokens.borderStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  Text(
                    isEdit ? 'Edit Cost & Selling Prices' : 'Create New Catalog SKU',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: dTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
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
                          dropdownColor: dTokens.surfaceElevated,
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
                            dropdownColor: dTokens.surfaceElevated,
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
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dTokens.brandPrimaryDark,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: dTokens.surfaceHover,
                          disabledForegroundColor: dTokens.textMuted,
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(isEdit ? 'Save Pricing' : 'Create SKU'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        skuCtrl.dispose();
        nameCtrl.dispose();
        supplierCtrl.dispose();
        costCtrl.dispose();
        cashCtrl.dispose();
        initQtyCtrl.dispose();
      });
    });
  }

  Widget _paginationSummaryPill(
    IcareSurfaceTokens tokens,
    int startIdx,
    int endIdx,
    int totalCount,
  ) {
    final text = totalCount == 0
        ? '0 SKUs'
        : 'Showing ${startIdx + 1}-$endIdx of $totalCount';
    return ProcurementStatusPill(
      label: text,
      bg: tokens.surfaceSubtle,
      fg: tokens.textSecondary,
      border: tokens.borderSubtle,
    );
  }

  Widget _emptyTableState(IcareSurfaceTokens tokens, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontSize: 13, color: tokens.textMuted),
        ),
      ),
    );
  }

  Widget _buildPaginationBar({
    required IcareSurfaceTokens tokens,
    required int page,
    required int totalPages,
    required int pageSize,
    required int totalCount,
    required ValueChanged<int> onPageChanged,
    required ValueChanged<int> onPageSizeChanged,
  }) {
    if (totalCount == 0) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rows per page:',
              style: TextStyle(fontSize: 12, color: tokens.textMuted),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: DropdownButtonFormField<int>(
                value: pageSize,
                isExpanded: true,
                isDense: true,
                dropdownColor: tokens.surfaceElevated,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                items: const [
                  DropdownMenuItem(value: 50, child: Text('50')),
                  DropdownMenuItem(value: 100, child: Text('100')),
                  DropdownMenuItem(value: 200, child: Text('200')),
                ],
                onChanged: (v) {
                  if (v != null) onPageSizeChanged(v);
                },
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Page ${page + 1} of $totalPages',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
            OutlinedButton.icon(
              onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
              icon: const Icon(Icons.chevron_left, size: 17),
              label: const Text('Prev'),
            ),
            OutlinedButton.icon(
              onPressed:
                  page + 1 < totalPages ? () => onPageChanged(page + 1) : null,
              icon: const Icon(Icons.chevron_right, size: 17),
              label: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// SHARED ENTERPRISE PROCUREMENT UI PRIMITIVES (REUSED BY DASHBOARD & HUB)
// =============================================================================

/// Wraps a DataTable so it stretches cleanly to 100% of its card width on wide
/// viewports and scrolls horizontally only when needed on narrower viewports.
class ProcurementFullWidthTable extends StatefulWidget {
  final IcareSurfaceTokens tokens;
  final Widget child;

  const ProcurementFullWidthTable({
    super.key,
    required this.tokens,
    required this.child,
  });

  @override
  State<ProcurementFullWidthTable> createState() =>
      _ProcurementFullWidthTableState();
}

class _ProcurementFullWidthTableState extends State<ProcurementFullWidthTable> {
  final ScrollController _horizontalCtrl = ScrollController();

  @override
  void dispose() {
    _horizontalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.tokens.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            controller: _horizontalCtrl,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalCtrl,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProcurementSectionCard extends StatelessWidget {
  final IcareSurfaceTokens tokens;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const ProcurementSectionCard({
    super.key,
    required this.tokens,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return IcareCard(
      padding: const EdgeInsets.all(18),
      topAccentColor: tokens.brandPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: tokens.textMuted),
                  ),
                ],
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class ProcurementStatusPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final Color border;

  const ProcurementStatusPill({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class ProcurementMovementBadge extends StatelessWidget {
  final IcareSurfaceTokens tokens;
  final String movementType;

  const ProcurementMovementBadge({
    super.key,
    required this.tokens,
    required this.movementType,
  });

  static String displayLabel(String mType) {
    switch (mType) {
      case 'RESTOCK':
        return 'Stock Receipt';
      case 'INITIAL_SEED':
        return 'Opening Stock';
      case 'TRANSFER_IN':
        return 'Transfer In';
      case 'TRANSFER_OUT':
        return 'Transfer Out';
      case 'DEDUCT_ON_DISBURSE':
        return 'Disbursed';
      case 'RESERVE_ON_APPLY':
        return 'Reserved';
      case 'RELEASE_ON_REJECT':
        return 'Released';
      case 'DAMAGE_WRITE_OFF':
        return 'Write-Off';
      case 'PRICE_UPDATE':
        return 'Price Update';
      case 'ADJUSTMENT':
        return 'Adjustment';
      default:
        return mType.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bg = tokens.surfaceSubtle;
    Color fg = tokens.textSecondary;
    Color bd = tokens.borderSubtle;
    if (movementType == 'RESTOCK' ||
        movementType == 'TRANSFER_IN' ||
        movementType == 'INITIAL_SEED') {
      bg = tokens.successBg;
      fg = tokens.successText;
      bd = tokens.successBorder;
    } else if (movementType == 'DAMAGE_WRITE_OFF') {
      bg = tokens.dangerBg;
      fg = tokens.dangerText;
      bd = tokens.dangerBorder;
    } else if (movementType == 'DEDUCT_ON_DISBURSE' ||
        movementType == 'TRANSFER_OUT' ||
        movementType == 'PRICE_UPDATE') {
      bg = tokens.infoBg;
      fg = tokens.infoText;
      bd = tokens.infoBorder;
    } else if (movementType == 'RESERVE_ON_APPLY' ||
        movementType == 'ADJUSTMENT') {
      bg = tokens.warningBg;
      fg = tokens.warningText;
      bd = tokens.warningBorder;
    }
    return ProcurementStatusPill(
      label: displayLabel(movementType),
      bg: bg,
      fg: fg,
      border: bd,
    );
  }
}

class ProcurementBranchValuationTable extends StatelessWidget {
  final IcareSurfaceTokens tokens;
  final List<Map<String, dynamic>> branchSummaries;

  const ProcurementBranchValuationTable({
    super.key,
    required this.tokens,
    required this.branchSummaries,
  });

  @override
  Widget build(BuildContext context) {
    if (branchSummaries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No active branches available.',
          style: TextStyle(color: tokens.textMuted),
        ),
      );
    }

    return ProcurementFullWidthTable(
      tokens: tokens,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
        columnSpacing: 22,
        horizontalMargin: 16,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 54,
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
          final costV = (b['inventory_cost_value'] as num?)?.toDouble() ?? 0.0;
          final cashV = (b['inventory_cash_value'] as num?)?.toDouble() ?? 0.0;
          final projMargin =
              (b['projected_retail_profit'] as num?)?.toDouble() ?? 0.0;
          final avail = (b['units_available'] as num?)?.toInt() ?? 0;

          return DataRow(
            cells: [
              DataCell(
                Text(
                  b['branch_name']?.toString() ?? 'Branch',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              DataCell(Text('${b['stocked_skus'] ?? 0}')),
              DataCell(Text('${b['units_on_hand'] ?? 0}')),
              DataCell(Text('${b['units_reserved'] ?? 0}')),
              DataCell(
                ProcurementStatusPill(
                  label: '$avail',
                  bg: avail > 0 ? tokens.successBg : tokens.surfaceSubtle,
                  fg: avail > 0 ? tokens.successText : tokens.textMuted,
                  border:
                      avail > 0 ? tokens.successBorder : tokens.borderSubtle,
                ),
              ),
              DataCell(Text(
                costV > 0 ? CurrencyFormatter.formatNaira(costV) : 'Pending',
                style: TextStyle(
                  color: costV > 0 ? tokens.textPrimary : tokens.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )),
              DataCell(Text(
                CurrencyFormatter.formatNaira(cashV),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )),
              DataCell(Text(
                costV > 0
                    ? CurrencyFormatter.formatNaira(projMargin)
                    : 'Pending',
                style: TextStyle(
                  color: costV > 0 ? tokens.successText : tokens.textMuted,
                  fontWeight: costV > 0 ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class ProcurementMovementLedgerCard extends StatefulWidget {
  final IcareSurfaceTokens tokens;
  final List<Map<String, dynamic>> movements;
  final List<Map<String, dynamic>> branches;
  final String title;
  final String subtitle;
  final bool showBranchFilter;

  const ProcurementMovementLedgerCard({
    super.key,
    required this.tokens,
    required this.movements,
    this.branches = const [],
    required this.title,
    required this.subtitle,
    this.showBranchFilter = false,
  });

  @override
  State<ProcurementMovementLedgerCard> createState() =>
      _ProcurementMovementLedgerCardState();
}

class _ProcurementMovementLedgerCardState
    extends State<ProcurementMovementLedgerCard> {
  String _typeFilter = 'ALL';
  String _branchFilter = 'ALL';

  bool _matchesType(String mType) {
    switch (_typeFilter) {
      case 'RECEIPTS':
        return mType == 'RESTOCK' || mType == 'INITIAL_SEED';
      case 'TRANSFERS':
        return mType == 'TRANSFER_IN' || mType == 'TRANSFER_OUT';
      case 'DISBURSEMENTS':
        return mType == 'DEDUCT_ON_DISBURSE' ||
            mType == 'RESERVE_ON_APPLY' ||
            mType == 'RELEASE_ON_REJECT';
      case 'WRITEOFFS':
        return mType == 'DAMAGE_WRITE_OFF' || mType == 'ADJUSTMENT';
      case 'PRICES':
        return mType == 'PRICE_UPDATE';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final filtered = widget.movements.where((m) {
      final mType = m['movement_type']?.toString() ?? '';
      if (!_matchesType(mType)) return false;
      if (_branchFilter != 'ALL' &&
          (m['branch_id']?.toString() ?? '') != _branchFilter) {
        return false;
      }
      return true;
    }).toList();

    return ProcurementSectionCard(
      tokens: tokens,
      title: '${widget.title} (${filtered.length})',
      subtitle: widget.subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.showBranchFilter && widget.branches.isNotEmpty)
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: _branchFilter,
                    isExpanded: true,
                    dropdownColor: tokens.surfaceElevated,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Branch',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'ALL',
                        child: Text('All Branches'),
                      ),
                      ...widget.branches.map(
                        (b) => DropdownMenuItem(
                          value: b['branch_id'].toString(),
                          child: Text(b['name'].toString()),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _branchFilter = v);
                    },
                  ),
                ),
              ...[
                ('ALL', 'All Movements'),
                ('RECEIPTS', 'Stock Receipts'),
                ('TRANSFERS', 'Transfers'),
                ('DISBURSEMENTS', 'Disbursements'),
                ('WRITEOFFS', 'Write-Offs'),
                ('PRICES', 'Price Updates'),
              ].map((f) {
                return ChoiceChip(
                  selected: _typeFilter == f.$1,
                  label: Text(f.$2),
                  onSelected: (_) => setState(() => _typeFilter = f.$1),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Text(
                'No stock or price movements match the selected filters.',
                style: TextStyle(color: tokens.textMuted),
              ),
            )
          else
            ProcurementFullWidthTable(
              tokens: tokens,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                columnSpacing: 18,
                horizontalMargin: 14,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 58,
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
                rows: filtered.map((m) {
                  final mType = m['movement_type']?.toString() ?? '';
                  final qDelta = (m['quantity_delta'] as num?)?.toInt() ?? 0;
                  final cp = m['counterparty_branch_name']?.toString();
                  final bLabel = cp != null && cp.isNotEmpty
                      ? '${m['branch_name']} (${mType == 'TRANSFER_OUT' ? 'to' : 'from'} $cp)'
                      : (m['branch_name']?.toString() ?? '');
                  final costVal =
                      (m['unit_cost_price'] as num?)?.toDouble() ?? 0.0;

                  return DataRow(
                    cells: [
                      DataCell(ProcurementMovementBadge(
                        tokens: tokens,
                        movementType: mType,
                      )),
                      DataCell(Text(bLabel)),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                              minWidth: 160, maxWidth: 230),
                          child: Text(
                            '${m['item_name']} (${m['sku_code']})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(
                        qDelta > 0 ? '+$qDelta' : '$qDelta',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: qDelta > 0
                              ? tokens.successText
                              : (qDelta < 0
                                  ? tokens.dangerText
                                  : tokens.textMuted),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      )),
                      DataCell(Text(
                        '${m['balance_after'] ?? 0}',
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      )),
                      DataCell(Text(
                        costVal > 0
                            ? CurrencyFormatter.formatNaira(costVal)
                            : '-',
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      )),
                      DataCell(Text(
                        CurrencyFormatter.formatNaira(
                          (m['unit_selling_price'] as num?)?.toDouble() ?? 0.0,
                        ),
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      )),
                      DataCell(Text(
                          '${m['reference_code'] ?? '-'} • ${m['performed_by']}')),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                              minWidth: 150, maxWidth: 220),
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
        ],
      ),
    );
  }
}
