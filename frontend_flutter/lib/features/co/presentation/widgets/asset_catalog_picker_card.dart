import 'package:flutter/material.dart';
import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_status_badge.dart';

/// Displays an interactive Branch Asset Inventory & Master Asset Price List
/// selector on the Loan Application tab for Asset Loans and Cash & Carry sales.
class AssetCatalogPickerSection extends StatefulWidget {
  final String branchName;
  final String selectedProduct;
  final List<Map<String, dynamic>> catalogItems;
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> cartItems;
  final bool isLoading;
  final bool isOfflineCache;
  final String? errorMessage;
  final VoidCallback onRefresh;
  final VoidCallback onOpenFullCatalog;
  final void Function(Map<String, dynamic> item) onAddItem;
  final void Function(String itemId, int delta) onChangeQty;
  final void Function(String itemId) onRemoveItem;
  final VoidCallback onClearCart;

  const AssetCatalogPickerSection({
    super.key,
    required this.branchName,
    required this.selectedProduct,
    required this.catalogItems,
    required this.categories,
    required this.summary,
    required this.cartItems,
    required this.isLoading,
    required this.isOfflineCache,
    this.errorMessage,
    required this.onRefresh,
    required this.onOpenFullCatalog,
    required this.onAddItem,
    required this.onChangeQty,
    required this.onRemoveItem,
    required this.onClearCart,
  });

  @override
  State<AssetCatalogPickerSection> createState() =>
      _AssetCatalogPickerSectionState();
}

class _AssetCatalogPickerSectionState extends State<AssetCatalogPickerSection> {
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'ALL';
  bool _inStockOnly = true;
  String? _pickedItemId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _activeTierLabel {
    final p = widget.selectedProduct.toLowerCase();
    if (p.contains('cash and carry') || p.contains('cash & carry')) {
      return 'Cash & Carry';
    }
    if (p.contains('120') || p.contains('24w') || p.contains('6m')) {
      return 'Easy Buy (+21%)';
    }
    return 'Easy Buy (+12%)';
  }

  double _packagePriceForItem(Map<String, dynamic> item, {bool fromCart = false}) {
    final p = widget.selectedProduct.toLowerCase();
    final cash = (item[fromCart ? 'unit_cash_price' : 'cash_and_carry_price'] as num?)?.toDouble() ?? 0.0;
    final p60 = (item[fromCart ? 'unit_easy_buy_60d_price' : 'easy_buy_60d_price'] as num?)?.toDouble() ?? (cash * 1.12);
    final p120 = (item[fromCart ? 'unit_easy_buy_120d_price' : 'easy_buy_120d_price'] as num?)?.toDouble() ?? (cash * 1.21);
    if (p.contains('cash and carry') || p.contains('cash & carry')) return cash;
    if (p.contains('120') || p.contains('24w') || p.contains('6m')) return p120;
    return p60;
  }

  List<Map<String, dynamic>> get _filteredItems {
    final q = _searchCtrl.text.trim().toLowerCase();
    return widget.catalogItems.where((it) {
      final avail = (it['quantity_available'] as num?)?.toInt() ?? 0;
      if (_inStockOnly && avail <= 0) return false;
      if (_selectedCategory != 'ALL' &&
          (it['category']?.toString().toUpperCase() ?? '') != _selectedCategory) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay = [
          it['item_name']?.toString() ?? '',
          it['sku_code']?.toString() ?? '',
          it['category']?.toString() ?? '',
          it['branch_item_alias']?.toString() ?? '',
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final filtered = _filteredItems;
    final totalUnitsAvail =
        (widget.summary['total_units_available'] as num?)?.toInt() ?? 0;
    final stockedSkus =
        (widget.summary['branch_stocked_skus'] as num?)?.toInt() ?? 0;

    if (_pickedItemId != null &&
        !filtered.any((e) => e['item_id']?.toString() == _pickedItemId)) {
      _pickedItemId = filtered.isNotEmpty ? filtered.first['item_id']?.toString() : null;
    } else if (_pickedItemId == null && filtered.isNotEmpty) {
      _pickedItemId = filtered.first['item_id']?.toString();
    }

    final selectedPreviewItem = _pickedItemId == null
        ? null
        : filtered.cast<Map<String, dynamic>?>().firstWhere(
              (e) => e?['item_id']?.toString() == _pickedItemId,
              orElse: () => null,
            );

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.infoBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 18, color: tokens.infoText),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Branch Asset Stock & Price List',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: tokens.textPrimary,
                        ),
                      ),
                      Text(
                        '${widget.branchName.isNotEmpty ? widget.branchName : 'Branch'}: $totalUnitsAvail unit(s) across $stockedSkus in-stock SKUs${widget.isOfflineCache ? ' • Offline Copy' : ''}',
                        style: TextStyle(fontSize: 11, color: tokens.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Refresh Branch Inventory',
                    onPressed: widget.isLoading ? null : widget.onRefresh,
                    icon: widget.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.refresh, size: 18, color: tokens.infoText),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenFullCatalog,
                    icon: const Icon(Icons.menu_book_outlined, size: 15),
                    label: Text(
                      isMobile ? 'Catalog' : 'Full Catalog & Stock',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.infoText,
                      side: BorderSide(color: tokens.infoBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (widget.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.errorMessage!,
              style: TextStyle(fontSize: 11.5, color: tokens.warningText),
            ),
          ],

          const SizedBox(height: 10),

          // Filter Controls: Search, Category, In-Stock Chip
          LayoutBuilder(
            builder: (context, constraints) {
              final searchField = TextField(
                controller: _searchCtrl,
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: tokens.surface,
                  prefixIcon: Icon(Icons.search, size: 18, color: tokens.textMuted),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() => _searchCtrl.clear()),
                        )
                      : null,
                  hintText: 'Search freezer, phone, pot, solar...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                onChanged: (_) => setState(() {}),
              );

              final catDropdown = DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedCategory,
                dropdownColor: tokens.surfaceElevated,
                style: TextStyle(fontSize: 12.5, color: tokens.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: tokens.surface,
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'ALL',
                    child: Text('All Categories', overflow: TextOverflow.ellipsis),
                  ),
                  ...widget.categories.map((c) {
                    final cname = c['category']?.toString() ?? '';
                    final units = (c['units_available'] as num?)?.toInt() ?? 0;
                    final label = units > 0 ? '$cname ($units)' : cname;
                    return DropdownMenuItem(
                      value: cname,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              );

              if (constraints.maxWidth < 600) {
                return Column(
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    catDropdown,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: searchField),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: catDropdown),
                ],
              );
            },
          ),

          const SizedBox(height: 8),
          Row(
            children: [
              FilterChip(
                selected: _inStockOnly,
                label: Text(
                  'In-Stock at Branch Only ($stockedSkus)',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                onSelected: (v) => setState(() => _inStockOnly = v),
              ),
              const Spacer(),
              Text(
                '${filtered.length} matching SKU(s)',
                style: TextStyle(fontSize: 11, color: tokens.textMuted),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Dropdown Selector + Add Button
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Text(
                _inStockOnly
                    ? 'No in-stock items match your filter. Turn off "In-Stock at Branch Only" to view the full Master Price List.'
                    : 'No matching catalog items found.',
                style: TextStyle(fontSize: 12, color: tokens.textMuted),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final dropdown = DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _pickedItemId,
                      dropdownColor: tokens.surfaceElevated,
                      style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: tokens.surface,
                        labelText: 'Select Branch Asset Item',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      items: filtered.take(150).map((it) {
                        final id = it['item_id']?.toString() ?? '';
                        final name = it['item_name']?.toString() ?? '';
                        final avail = (it['quantity_available'] as num?)?.toInt() ?? 0;
                        final cash = (it['cash_and_carry_price'] as num?)?.toDouble() ?? 0.0;
                        final priceStr = cash > 0
                            ? CurrencyFormatter.formatNaira(cash)
                            : 'Custom Price';
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            '$name ($avail avail) — $priceStr',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _pickedItemId = val),
                    );

                    final selectedAvail =
                        (selectedPreviewItem?['quantity_available'] as num?)?.toInt() ?? 0;
                    final addButton = ElevatedButton.icon(
                      onPressed: (selectedPreviewItem == null || selectedAvail <= 0)
                          ? null
                          : () => widget.onAddItem(selectedPreviewItem),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_shopping_cart_outlined, size: 16),
                      label: const Text(
                        'Add Item',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                    );

                    if (constraints.maxWidth < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          dropdown,
                          const SizedBox(height: 8),
                          addButton,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: dropdown),
                        const SizedBox(width: 8),
                        addButton,
                      ],
                    );
                  },
                ),

                if (selectedPreviewItem != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _pricePill(
                        tokens,
                        'Cash & Carry',
                        CurrencyFormatter.formatNaira(
                          (selectedPreviewItem['cash_and_carry_price'] as num?)?.toDouble() ?? 0.0,
                        ),
                      ),
                      _pricePill(
                        tokens,
                        'Easy Buy 60D/12W/3M',
                        CurrencyFormatter.formatNaira(
                          (selectedPreviewItem['easy_buy_60d_price'] as num?)?.toDouble() ?? 0.0,
                        ),
                      ),
                      _pricePill(
                        tokens,
                        'Easy Buy 120D/24W/6M',
                        CurrencyFormatter.formatNaira(
                          (selectedPreviewItem['easy_buy_120d_price'] as num?)?.toDouble() ?? 0.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

          // Selected Asset Order Cart
          if (widget.cartItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: tokens.borderSubtle),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected Asset Items (${widget.cartItems.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: tokens.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: widget.onClearCart,
                  child: const Text('Clear Selection', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...widget.cartItems.map((line) {
              final iid = line['item_id'].toString();
              final qty = (line['quantity'] as num?)?.toInt() ?? 1;
              final avail = (line['quantity_available'] as num?)?.toInt() ?? qty;
              final unitCash = (line['unit_cash_price'] as num?)?.toDouble() ?? 0.0;
              final unitPkg = _packagePriceForItem(line, fromCart: true);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: tokens.surface,
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
                            line['item_name']?.toString() ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.close, size: 16, color: tokens.dangerText),
                          onPressed: () => widget.onRemoveItem(iid),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${line['sku_code']} • Max avail: $avail',
                          style: TextStyle(fontSize: 11, color: tokens.textMuted),
                        ),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_circle_outline, size: 18),
                          onPressed: qty > 1 ? () => widget.onChangeQty(iid, -1) : null,
                        ),
                        Text(
                          '$qty',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: tokens.textPrimary,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          onPressed: qty < avail ? () => widget.onChangeQty(iid, 1) : null,
                        ),
                      ],
                    ),
                    Text(
                      'Base Cash Cost: ${CurrencyFormatter.formatNaira(unitCash * qty)}   •   $_activeTierLabel Total: ${CurrencyFormatter.formatNaira(unitPkg * qty)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.infoText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            Text(
              'Asset Cost below is automatically locked to the Cash & Carry catalog price of selected branch stock.',
              style: TextStyle(fontSize: 11, color: tokens.successText, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pricePill(IcareSurfaceTokens tokens, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: tokens.textSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Interactive Adaptive Sheet to inspect the Master Asset Price List,
/// monitor live branch physical stock, and allow Procurement Officers/Admins to restock or set prices.
Future<void> showBranchAssetCatalogDialog({
  required BuildContext context,
  required String branchName,
  required bool canManageInventory,
  required List<Map<String, dynamic>> initialItems,
  required List<Map<String, dynamic>> categories,
  required Map<String, dynamic> summary,
  required Future<Map<String, dynamic>> Function(String itemId, int qtyDelta, double? newPrice, double? newCostPrice, String remarks) onAdjustItem,
  VoidCallback? onChanged,
}) async {
  var items = List<Map<String, dynamic>>.from(initialItems);
  var currSummary = Map<String, dynamic>.from(summary);
  String catFilter = 'ALL';
  bool inStockOnly = true;
  final searchCtrl = TextEditingController();

  await showIcareAdaptiveSheet(
    context: context,
    mobileBreakpoint: 700,
    desktopConstraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
    builder: (ctx, isDialog) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final tokens = IcareSurfaceTokens.of(ctx);
          final q = searchCtrl.text.trim().toLowerCase();
          final visible = items.where((it) {
            final avail = (it['quantity_available'] as num?)?.toInt() ?? 0;
            if (inStockOnly && avail <= 0) return false;
            if (catFilter != 'ALL' &&
                (it['category']?.toString().toUpperCase() ?? '') != catFilter) {
              return false;
            }
            if (q.isNotEmpty) {
              final hay = [
                it['item_name']?.toString() ?? '',
                it['sku_code']?.toString() ?? '',
                it['category']?.toString() ?? '',
              ].join(' ').toLowerCase();
              if (!hay.contains(q)) return false;
            }
            return true;
          }).toList();

          Future<void> openAdjustDialog(Map<String, dynamic> it) async {
            final deltaCtrl = TextEditingController(text: '0');
            final existingCost = (it['unit_cost_price'] as num?)?.toDouble() ?? 0.0;
            final costCtrl = TextEditingController(
              text: existingCost > 0 ? existingCost.toStringAsFixed(0) : '',
            );
            final priceCtrl = TextEditingController(
              text: ((it['cash_and_carry_price'] as num?)?.toDouble() ?? 0.0)
                  .toStringAsFixed(0),
            );
            final remarksCtrl = TextEditingController();
            bool saving = false;
            await showIcareDialog(
              context: ctx,
              builder: (adjCtx) => StatefulBuilder(
                builder: (adjCtx, setAdjState) {
                  final adjTokens = IcareSurfaceTokens.of(adjCtx);
                  return AlertDialog(
                    backgroundColor: adjTokens.surfaceElevated,
                    title: Text(
                      'Adjust Stock / Price',
                      style: TextStyle(fontWeight: FontWeight.w800, color: adjTokens.textPrimary),
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${it['item_name']} (${it['sku_code']})',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: adjTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Current On Hand: ${it['quantity_on_hand']} • Reserved: ${it['quantity_reserved']} • Available: ${it['quantity_available']}',
                            style: TextStyle(fontSize: 11.5, color: adjTokens.textMuted),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: deltaCtrl,
                            keyboardType: const TextInputType.numberWithOptions(signed: true),
                            decoration: const InputDecoration(
                              labelText: 'Quantity Change (+ restock / - remove)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Unit Cost Price (₦ — optional if pending)',
                              helperText: 'Leave blank if supplier cost is not yet available',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cash & Carry Price (₦)',
                              helperText: 'Easy Buy 60D (+12%) & 120D (+21%) auto-update',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: remarksCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Reason / Delivery Note',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: saving ? null : () => Navigator.of(adjCtx).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setAdjState(() => saving = true);
                                try {
                                  final delta = int.tryParse(deltaCtrl.text.trim()) ?? 0;
                                  final rawCost = costCtrl.text.replaceAll(',', '').trim();
                                  final newCost = rawCost.isNotEmpty ? double.tryParse(rawCost) : null;
                                  final newPrice = double.tryParse(priceCtrl.text.replaceAll(',', '').trim());
                                  final res = await onAdjustItem(
                                    it['item_id'].toString(),
                                    delta,
                                    newPrice,
                                    newCost,
                                    remarksCtrl.text.trim(),
                                  );
                                  final updated = res['item'] as Map<String, dynamic>?;
                                  if (updated != null) {
                                    setModalState(() {
                                      final idx = items.indexWhere((x) => x['item_id'] == updated['item_id']);
                                      if (idx >= 0) items[idx] = updated;
                                      currSummary['total_units_available'] = items.fold<int>(
                                        0,
                                        (s, e) => s + ((e['quantity_available'] as num?)?.toInt() ?? 0),
                                      );
                                      currSummary['branch_stocked_skus'] = items
                                          .where((e) => ((e['quantity_available'] as num?)?.toInt() ?? 0) > 0)
                                          .length;
                                    });
                                    onChanged?.call();
                                  }
                                  if (adjCtx.mounted) Navigator.of(adjCtx).pop();
                                } catch (e) {
                                  setAdjState(() => saving = false);
                                  if (adjCtx.mounted) {
                                    ScaffoldMessenger.of(adjCtx).showSnackBar(
                                      SnackBar(
                                        content: Text(AppErrorDetails.from(e).message),
                                        backgroundColor: const Color(0xFFDC2626),
                                      ),
                                    );
                                  }
                                }
                              },
                        child: saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save Changes'),
                      ),
                    ],
                  );
                },
              ),
            );
            deltaCtrl.dispose();
            costCtrl.dispose();
            priceCtrl.dispose();
            remarksCtrl.dispose();
          }

          return Material(
            color: tokens.surfaceElevated,
            borderRadius: isDialog ? BorderRadius.circular(14) : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storefront_outlined, color: tokens.brandPrimary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Master Asset Price List & Branch Stock',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                            ),
                            Text(
                              '$branchName • ${currSummary['total_units_available'] ?? 0} units available across ${currSummary['branch_stocked_skus'] ?? 0} stocked items (${items.length} total SKUs)',
                              style: TextStyle(fontSize: 12, color: tokens.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 540;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: narrow ? constraints.maxWidth : 260,
                            child: TextField(
                              controller: searchCtrl,
                              decoration: const InputDecoration(
                                isDense: true,
                                prefixIcon: Icon(Icons.search, size: 18),
                                hintText: 'Search catalog or SKU...',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                          SizedBox(
                            width: narrow ? constraints.maxWidth : 240,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: catFilter,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
                                ...categories.map((c) {
                                  final cn = c['category']?.toString() ?? '';
                                  return DropdownMenuItem(value: cn, child: Text(cn, overflow: TextOverflow.ellipsis));
                                }),
                              ],
                              onChanged: (v) {
                                if (v != null) setModalState(() => catFilter = v);
                              },
                            ),
                          ),
                          FilterChip(
                            selected: inStockOnly,
                            label: const Text('In Stock Only'),
                            onSelected: (v) => setModalState(() => inStockOnly = v),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: tokens.borderSubtle),
                      itemBuilder: (_, idx) {
                        final it = visible[idx];
                        final avail = (it['quantity_available'] as num?)?.toInt() ?? 0;
                        final resv = (it['quantity_reserved'] as num?)?.toInt() ?? 0;
                        final cash = (it['cash_and_carry_price'] as num?)?.toDouble() ?? 0.0;
                        final p60 = (it['easy_buy_60d_price'] as num?)?.toDouble() ?? 0.0;
                        final p120 = (it['easy_buy_120d_price'] as num?)?.toDouble() ?? 0.0;

                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${it['item_name']} (${it['sku_code']})',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tokens.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IcareStatusBadge(
                                label: avail > 0 ? '$avail in stock${resv > 0 ? ' ($resv rsv)' : ''}' : 'Out of stock',
                                variant: avail > 0 ? IcareBadgeVariant.success : IcareBadgeVariant.neutral,
                                showDot: false,
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text('${it['category']}', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                                Text(
                                  cash > 0
                                      ? 'Cash: ${CurrencyFormatter.formatNaira(cash)}  |  60D/12W: ${CurrencyFormatter.formatNaira(p60)}  |  120D/24W: ${CurrencyFormatter.formatNaira(p120)}'
                                      : 'Custom / Branch Legacy Price',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textSecondary,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: canManageInventory
                              ? IconButton(
                                  tooltip: 'Adjust Stock or Price',
                                  icon: Icon(Icons.edit_outlined, size: 18, color: tokens.brandPrimary),
                                  onPressed: () => openAdjustDialog(it),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  searchCtrl.dispose();
}
