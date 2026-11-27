import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter/core/auth/auth_controller.dart';
import 'package:frontend_flutter/core/auth/auth_state.dart';
import 'package:frontend_flutter/core/auth/session_storage_base.dart';
import 'package:frontend_flutter/core/network/api_client.dart';
import 'package:frontend_flutter/core/offline/connectivity_service.dart';
import 'package:frontend_flutter/core/offline/offline_database_service.dart';
import 'package:frontend_flutter/core/offline/offline_sync_manager.dart';
import 'package:frontend_flutter/core/theme/icare_theme.dart';
import 'package:frontend_flutter/core/theme/theme_controller.dart';
import 'package:frontend_flutter/features/co/data/datasources/co_api_service.dart';
import 'package:frontend_flutter/features/co/presentation/daily_cashbook_screen.dart';
import 'package:frontend_flutter/features/co/presentation/daily_collections_screen.dart';
import 'package:frontend_flutter/features/shared/presentation/co_app_scaffold.dart';

class _MemStorage implements SessionStorage {
  Map<String, String>? _stored;
  @override
  Future<void> saveSession(String token, String userJson) async =>
      _stored = {'token': token, 'user': userJson};
  @override
  Future<Map<String, String>?> getSession() async => _stored;
  @override
  Future<void> clearSession() async => _stored = null;
}

class _AlwaysOnlineConn implements ConnectivityService {
  final _ctrl = StreamController<bool>.broadcast();
  @override
  Stream<bool> get statusStream => _ctrl.stream;
  @override
  bool get isOnline => true;
  @override
  void reportOffline() {}
  @override
  void reportOnline() {}
  @override
  Future<bool> checkActualConnection({bool forceImmediateOffline = false}) async =>
      true;
  @override
  void dispose() => _ctrl.close();
}

class _SequencedAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;
  _SequencedAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      onFetch(options);

  @override
  void close({bool force = false}) {}
}

class _StaticCoAuth extends AuthController {
  _StaticCoAuth(
    AuthUser user,
    ApiClient apiClient,
    OfflineDatabaseService db,
  ) : super(apiClient, db, _MemStorage(), false) {
    state = AuthStateAuthenticated(user: user, token: 'test-token');
  }
}

class _StubCoApi extends CoApiService {
  _StubCoApi(super.client);

  @override
  Future<Map<String, dynamic>> getCollectionSheet({
    String? groupName,
    String? date,
  }) async =>
      {
        'date': '2026-11-27',
        'is_open': true,
        'open_reason': 'Working Day',
        'groups': ['Favour'],
        'group_name': 'Favour',
        'clients': [],
      };

  @override
  Future<Map<String, dynamic>> getSingleClientOptions() async => {
        'date': '2026-11-27',
        'is_open': true,
        'open_reason': 'Working Day',
        'clients': [
          {
            'client_id': 'cli-1',
            'client_code': 'OGI-20-008',
            'client_name': 'Orija Temitope Adenike',
            'group_id': 'grp-1',
            'group_name': 'Success',
            'eligible_loans': [],
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> getCollectionsHistory({
    String? date,
    String? search,
    String? officer,
  }) async =>
      {
        'date': '2026-11-27',
        'total_repayments': 0.0,
        'paid_repayments_count': 0,
        'not_paid_repayments_count': 0,
        'total_savings': 3000.0,
        'savings_deposits_count': 1,
        'total_fees': 1500.0,
        'grand_total_cash': 4500.0,
        'groups': [],
        'repayments': [],
        'savings': [],
        'fees': [
          {
            'id': 'fee-1',
            'fee_type': 'MISC_FEE',
            'fee_label': 'Misc Fee (Misc Savings)',
            'amount': 1000.0,
            'client_name': 'Orija Temitope Adenike',
            'client_code': 'OGI-20-008',
            'collecting_officer': 'OGI_CO2',
            'managing_officer': 'OGI_CO3',
            'reference': 'SC-ALL-FEES-001',
            'remarks': 'Misc fee custody routed cleanly',
          },
          {
            'id': 'fee-2',
            'fee_type': 'CREDIT_FORM_DAMAGE',
            'fee_label': 'Credit Form Damage',
            'amount': 500.0,
            'client_name': 'Orija Temitope Adenike',
            'client_code': 'OGI-20-008',
            'collecting_officer': 'OGI_CO2',
            'managing_officer': '',
            'reference': 'SC-ALL-FEES-001',
            'remarks': 'Damaged form replacement',
          },
        ],
        'reversed_records': [],
        'eod_summary': <String, dynamic>{},
        'eod_log': [],
      };

  @override
  Future<Map<String, dynamic>> getReversalOptions({
    String? category,
    String? date,
    bool allRecent = false,
    String? search,
  }) async =>
      {'options': []};

  @override
  Future<Map<String, dynamic>> getReversalRequests() async => {'requests': []};

  @override
  Future<Map<String, dynamic>> getCoCashbook({
    String? dateStr,
    String? officer,
  }) async =>
      {
        'is_open': true,
        'open_reason': 'Working Day',
        'can_select_officer': false,
        'officers': [],
        'officer': 'OGI_CO2',
        'branch': 'Ogijo',
        'date': '2026-11-27',
        'inflows': {
          'opening_balance': 5000.0,
          'savings_deposit': 3000.0,
        },
        'outflows': {
          'office_expenses': 1000.0,
          'bank_deposit': 2000.0,
        },
        'total_inflows': 8000.0,
        'total_outflows': 3000.0,
        'closing_balance': 5000.0,
        'tally': {'not_paid_count': 0, 'not_paid_list': []},
        'reversal_options': [],
        'submitted_reversals': [],
      };

  @override
  Future<List<dynamic>> getClientFees({
    String? dateStr,
    String? officer,
  }) async =>
      [
        {
          'fee_type': 'Credit Form Damage',
          'client_code': 'OGI-20-008',
          'client_name': 'Orija Temitope Adenike',
          'amount': 500.0,
        },
      ];
}

List<Override> _testOverrides({
  String activePage = 'Collections',
  int initialTab = 0,
  String initialMode = 'Single Client Quick Entry',
}) {
  final conn = _AlwaysOnlineConn();
  final db = OfflineDatabaseService(useMemoryStore: true);
  final client = ApiClient(
    connectivityService: conn,
    offlineDb: db,
    adapter: _SequencedAdapter(
      (_) async => ResponseBody.fromBytes(
        Uint8List.fromList(utf8.encode('{}')),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ),
    isWebOverride: false,
  );
  final api = _StubCoApi(client);
  final user = AuthUser(
    id: 'co-ogi-2',
    username: 'OGI_CO2',
    fullName: 'Mr. Ayomide',
    role: 'Credit Officer',
    branch: 'Ogijo',
    branchId: 'br-ogijo',
    assignedBranches: ['Ogijo'],
    assignedBranchIds: ['br-ogijo'],
  );

  return [
    connectivityServiceProvider.overrideWithValue(conn),
    offlineDatabaseServiceProvider.overrideWithValue(db),
    apiClientProvider.overrideWithValue(client),
    coApiServiceProvider.overrideWithValue(api),
    authControllerProvider.overrideWith((_) => _StaticCoAuth(user, client, db)),
    themeControllerProvider.overrideWith((_) => ThemeController(autoLoad: false)),
    activeCoPageProvider.overrideWith((_) => activePage),
    collectionsTabProvider.overrideWith((_) => initialTab),
    collectionsModeProvider.overrideWith((_) => initialMode),
    selectedCollectionGroupProvider.overrideWith((_) => null),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('OfflineSyncManager.syncOutbox joins concurrent callers without returning already-in-progress error', () async {
    final conn = _AlwaysOnlineConn();
    final db = OfflineDatabaseService(useMemoryStore: true);
    db.setSessionScope(userId: 'co-1', branchId: 'br-ogijo');
    final notifier = PendingOutboxNotifier(db);
    final gate = Completer<void>();
    final postRequests = <String>[];

    final adapter = _SequencedAdapter((options) async {
      if (options.method.toUpperCase() == 'POST') {
        postRequests.add(options.path);
        await gate.future;
      }
      return ResponseBody.fromBytes(
        Uint8List.fromList(utf8.encode(jsonEncode({
          'success': true,
          'receipt': {'batch_id': 'SC-SYNCED-1'},
        }))),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final client = ApiClient(
      connectivityService: conn,
      offlineDb: db,
      adapter: adapter,
      isWebOverride: false,
    );
    final syncMgr = OfflineSyncManager(db, CoApiService(client), notifier);

    await syncMgr.queueOfflineSingleCollection(
      clientName: 'Orija Temitope',
      collectionDate: '2026-11-27',
      payload: {
        'client_id': 'cli-1',
        'client_name': 'Orija Temitope',
        'group_name': 'Success',
        'savings_deposit': 0.0,
        'group_savings_deposit': 0.0,
        'loan_repayment': 0.0,
        'app_fee': 500.0,
        'passbook_fee': 500.0,
        'misc_fee': 1000.0,
        'credit_form_damage': 200.0,
        'bonus': 300.0,
      },
    );

    final f1 = syncMgr.syncOutbox();
    final f2 = syncMgr.syncOutbox();
    await Future<void>.delayed(Duration.zero);
    gate.complete();

    final results = await Future.wait([f1, f2]);
    expect(postRequests, ['/api/v1/co/collections/single-submit']);
    expect(results[0].success, isTrue);
    expect(results[1].success, isTrue);
    expect(results[0].message, isNot('Synchronization already in progress'));
    expect(results[1].message, isNot('Synchronization already in progress'));
    expect(await db.getPendingOutboxCount(), 0);
  });

  testWidgets('showSingleClientCollectionFlowSheet itemizes and totals all 5 fee types', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: IcareTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showSingleClientCollectionFlowSheet(
                    context: context,
                    clientObj: const {
                      'client_id': 'cli-1',
                      'client_name': 'Orija Temitope Adenike',
                      'client_code': 'OGI-20-008',
                      'group_name': 'Success',
                    },
                    dateStr: '2026-11-27',
                    loanId: null,
                    expRep: 0.0,
                    savVal: 0.0,
                    grpSavVal: 0.0,
                    repVal: 0.0,
                    appVal: 500.0,
                    pbVal: 500.0,
                    miscVal: 1000.0,
                    cfdVal: 200.0,
                    bonVal: 300.0,
                    isNotPaid: false,
                    note: 'All 5 fees test',
                    isOnline: true,
                    onConfirmPost: () async => {
                      'receipt': {
                        'batch_id': 'SC-FEE-ONLY-1',
                        'total_cash': 2500.0,
                        'timestamp': '27 Nov 2026, 09:00 AM',
                      },
                    },
                    onDismissAndReset: (ctx) => Navigator.of(ctx).pop(),
                    onViewHistory: (ctx) => Navigator.of(ctx).pop(),
                  );
                },
                child: const Text('Open 5-Fee Confirmation'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open 5-Fee Confirmation'));
    await tester.pumpAndSettle();

    expect(find.text('Application Fee'), findsOneWidget);
    expect(find.text('Pass Book Fee'), findsOneWidget);
    expect(find.text('Misc Fee (Misc Savings)'), findsOneWidget);
    expect(find.text('Credit Form Damage'), findsOneWidget);
    expect(find.text('Bonus Fee'), findsOneWidget);
    expect(find.text('Confirm (₦2,500)'), findsOneWidget);

    await tester.tap(find.text('Confirm (₦2,500)'));
    await tester.pumpAndSettle();

    expect(find.text('Client Collection Confirmed'), findsOneWidget);
    expect(find.text('₦2,500.00'), findsWidgets);
  });

  testWidgets('DailyCollectionsScreen shows all 5 visible client fees on Single Client and itemized Fees Audit on History', (tester) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: _testOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: IcareTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: DailyCollectionsScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // All 5 fee inputs are directly visible (not collapsed inside an ExpansionTile)
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('Client Fees (Optional — Attributed & Audited)'), findsOneWidget);
    expect(find.text('Credit Form / App Fee (₦)'), findsOneWidget);
    expect(find.text('Pass Book (₦)'), findsOneWidget);
    expect(find.text('Misc Fee (₦)'), findsOneWidget);
    expect(find.text('Credit Form Damage (₦)'), findsOneWidget);
    expect(find.text('Bonus (₦)'), findsOneWidget);

    // Switch to Tab 1 (Collection History & Audit)
    container.read(collectionsTabProvider.notifier).state = 1;
    await tester.pumpAndSettle();

    expect(find.text('TOTAL CLIENT FEES'), findsOneWidget);
    expect(find.text('Recorded Client Fees & Charges'), findsOneWidget);
    expect(find.text('Custodian: OGI_CO3'), findsOneWidget);
    expect(find.text('Credit Form Damage'), findsWidgets);
  });

  testWidgets('DailyCashbookScreen removes EOD fee inputs and routes Record Client Fee to Single Client Quick Entry', (tester) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: _testOverrides(
        activePage: 'Daily Cashbook',
        initialTab: 1,
        initialMode: 'Group Collection Sheet',
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: IcareTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: DailyCashbookScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('EOD Inputs'));
    await tester.pumpAndSettle();

    expect(find.text('Opening Balance (B/F Cash)'), findsOneWidget);
    expect(find.text('Office Expenses'), findsOneWidget);
    expect(find.text('Bank Deposited'), findsOneWidget);
    expect(find.text('Cr Form Dmg'), findsNothing);
    expect(find.text('Save Opening Balance & Outflows'), findsOneWidget);

    final recordFeeBtn = find.text('Record Client Fee');
    expect(recordFeeBtn, findsOneWidget);
    await tester.ensureVisible(recordFeeBtn);
    await tester.tap(recordFeeBtn);
    await tester.pumpAndSettle();

    expect(container.read(activeCoPageProvider), 'Collections');
    expect(container.read(collectionsTabProvider), 0);
    expect(container.read(collectionsModeProvider), 'Single Client Quick Entry');
  });
}
