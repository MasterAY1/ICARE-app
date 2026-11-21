import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_flutter/core/offline/offline_database_service.dart';
import 'package:frontend_flutter/features/co/presentation/widgets/asset_catalog_picker_card.dart';

void main() {
  test('OfflineDatabaseService caches and retrieves branch asset catalog per branch scope', () async {
    SharedPreferences.setMockInitialValues({});
    final db = OfflineDatabaseService(
      useMemoryStore: true,
      userId: 'co_ogijo',
      branchId: 'ogijo-branch-uuid',
    );
    await db.cacheBranchAssetCatalog('ogijo-branch-uuid', {
      'branch_name': 'Ogijo',
      'summary': {'total_units_available': 205, 'branch_stocked_skus': 127},
      'items': [
        {
          'item_id': 'item-1',
          'sku_code': 'GAS-003',
          'category': 'GAS COOKER AND CYLINDER',
          'item_name': '6KG CYLINDER',
          'cash_and_carry_price': 26000.0,
          'easy_buy_60d_price': 29120.0,
          'easy_buy_120d_price': 31460.0,
          'quantity_available': 5,
        },
      ],
    });

    final loaded = await db.getCachedBranchAssetCatalog('ogijo-branch-uuid');
    expect(loaded, isNotNull);
    expect(loaded!['branch_name'], equals('Ogijo'));
    expect((loaded['items'] as List).first['item_name'], equals('6KG CYLINDER'));
  });

  testWidgets('AssetCatalogPickerSection renders branch stock, filters, and updates cart quantities', (WidgetTester tester) async {
    final items = [
      {
        'item_id': 'item-1',
        'sku_code': 'GAS-003',
        'category': 'GAS COOKER AND CYLINDER',
        'item_name': '6KG CYLINDER',
        'cash_and_carry_price': 26000.0,
        'easy_buy_60d_price': 29120.0,
        'easy_buy_120d_price': 31460.0,
        'quantity_on_hand': 5,
        'quantity_reserved': 0,
        'quantity_available': 5,
      },
      {
        'item_id': 'item-2',
        'sku_code': 'FRZ-002',
        'category': 'FREEZER',
        'item_name': 'BRUHM 100L FREEZER SILVER',
        'cash_and_carry_price': 230000.0,
        'easy_buy_60d_price': 257600.0,
        'easy_buy_120d_price': 278300.0,
        'quantity_on_hand': 0,
        'quantity_reserved': 0,
        'quantity_available': 0,
      },
    ];
    final categories = [
      {'category': 'GAS COOKER AND CYLINDER', 'catalog_skus': 1, 'in_stock_skus': 1, 'units_available': 5},
      {'category': 'FREEZER', 'catalog_skus': 1, 'in_stock_skus': 0, 'units_available': 0},
    ];
    final summary = {
      'total_catalog_skus': 2,
      'branch_stocked_skus': 1,
      'total_units_available': 5,
    };

    final cart = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                return AssetCatalogPickerSection(
                  branchName: 'Ogijo',
                  selectedProduct: '60-Day Asset',
                  catalogItems: items,
                  categories: categories,
                  summary: summary,
                  cartItems: cart,
                  isLoading: false,
                  isOfflineCache: false,
                  onRefresh: () {},
                  onOpenFullCatalog: () {},
                  onAddItem: (it) {
                    setState(() {
                      cart.add({
                        'item_id': it['item_id'],
                        'sku_code': it['sku_code'],
                        'category': it['category'],
                        'item_name': it['item_name'],
                        'quantity': 1,
                        'quantity_available': it['quantity_available'],
                        'unit_cash_price': it['cash_and_carry_price'],
                        'unit_easy_buy_60d_price': it['easy_buy_60d_price'],
                        'unit_easy_buy_120d_price': it['easy_buy_120d_price'],
                      });
                    });
                  },
                  onChangeQty: (id, delta) {
                    setState(() {
                      final idx = cart.indexWhere((e) => e['item_id'] == id);
                      if (idx >= 0) {
                        cart[idx]['quantity'] = (cart[idx]['quantity'] as int) + delta;
                      }
                    });
                  },
                  onRemoveItem: (id) {
                    setState(() => cart.removeWhere((e) => e['item_id'] == id));
                  },
                  onClearCart: () {
                    setState(() => cart.clear());
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Ogijo: 5 unit(s) across 1 in-stock SKUs'), findsOneWidget);
    expect(find.text('1 matching SKU(s)'), findsOneWidget);

    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();

    expect(cart.length, equals(1));
    expect(find.text('Selected Asset Items (1)'), findsOneWidget);
    expect(find.textContaining('Easy Buy (+12%) Total:'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(cart.first['quantity'], equals(2));
  });
}
