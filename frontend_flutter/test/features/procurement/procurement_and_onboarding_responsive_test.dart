import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
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
import 'package:frontend_flutter/core/theme/icare_theme.dart';
import 'package:frontend_flutter/core/widgets/icare_card.dart';
import 'package:frontend_flutter/core/widgets/icare_metric_card.dart';
import 'package:frontend_flutter/core/widgets/icare_status_badge.dart';
import 'package:frontend_flutter/features/onboarding/data/onboarding_api_service.dart';
import 'package:frontend_flutter/features/onboarding/presentation/branch_onboarding_admin_screen.dart';
import 'package:frontend_flutter/features/onboarding/presentation/branch_onboarding_portal_screen.dart';
import 'package:frontend_flutter/features/onboarding/presentation/credit_officer_portal_screen.dart';
import 'package:frontend_flutter/features/procurement/data/datasources/procurement_api_service.dart';
import 'package:frontend_flutter/features/procurement/presentation/asset_procurement_screen.dart';

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

class _NoopHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      Uint8List.fromList(utf8.encode('{}')),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _QuietConn implements ConnectivityService {
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

class _StaticAuthController extends AuthController {
  _StaticAuthController(
    AuthUser user,
    ApiClient apiClient,
    OfflineDatabaseService db,
  ) : super(apiClient, db, _MemStorage(), false) {
    state = AuthStateAuthenticated(user: user, token: 'test-jwt-token');
  }
}

class _FakeProcurementApiService extends ProcurementApiService {
  final bool shouldFail;

  _FakeProcurementApiService(super.client, {this.shouldFail = false});

  @override
  Future<Map<String, dynamic>> getOverview({String? branchId}) async {
    if (shouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/procurement/overview'),
        type: DioExceptionType.connectionTimeout,
        message: 'Timeout',
      );
    }
    return {
      'branches': [
        {'branch_id': 'br-1', 'name': 'Ikeja Branch'},
        {'branch_id': 'br-2', 'name': 'Ogijo Branch'},
      ],
      'branch_summaries': [
        {
          'branch_id': 'br-1',
          'branch_name': 'Ikeja Branch',
          'units_available': 14,
          'inventory_cash_value': 2800000.0,
          'inventory_cost_value': 2100000.0,
        },
        {
          'branch_id': 'br-2',
          'branch_name': 'Ogijo Branch',
          'units_available': 8,
          'inventory_cash_value': 1600000.0,
          'inventory_cost_value': 1250000.0,
        },
      ],
      'inventory_summary': {
        'units_available': 22,
        'units_reserved': 2,
        'inventory_cash_value': 4400000.0,
        'inventory_cost_value': 3350000.0,
      },
      'pnl_summary': {
        'units_sold': 6,
        'realized_package_revenue': 1200000.0,
        'net_realized_profit': 240000.0,
        'net_margin_pct': 20.0,
      },
      'catalog_readiness': {
        'cost_configured_skus': 2,
        'total_catalog_skus': 2,
      },
      'recent_movements': [
        {
          'id': 'mv-1',
          'movement_type': 'RESTOCK',
          'sku_code': 'FRZ-001',
          'item_name': 'Bruhm 100L Freezer',
          'branch_name': 'Ikeja Branch',
          'quantity': 5,
          'unit_cost': 165000.0,
          'recorded_at': '2026-11-26',
          'recorded_by': 'Procurement Admin',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getStockMatrix({
    String? category,
    String? search,
    bool inStockOnly = false,
  }) async {
    if (shouldFail) {
      throw Exception('Matrix error');
    }
    return {
      'branches': [
        {'branch_id': 'br-1', 'name': 'Ikeja Branch'},
        {'branch_id': 'br-2', 'name': 'Ogijo Branch'},
      ],
      'categories': ['FREEZER'],
      'summary': {'total_skus': 1, 'total_available': 22},
      'items': [
        {
          'item_id': 'ast-1',
          'sku_code': 'FRZ-001',
          'category': 'FREEZER',
          'item_name': 'Bruhm 100L Freezer',
          'has_cost_price': true,
          'cost_price': 165000.0,
          'cash_and_carry_price': 200000.0,
          'easy_buy_60d_price': 224000.0,
          'easy_buy_120d_price': 242000.0,
          'total_available': 22,
          'total_on_hand': 24,
          'total_reserved': 2,
          'branches': {
            'br-1': {'on_hand': 16, 'reserved': 2, 'available': 14},
            'br-2': {'on_hand': 8, 'reserved': 0, 'available': 8},
          },
        },
      ],
    };
  }
}

class _FakeOnboardingApiService extends OnboardingApiService {
  final bool shouldFail;

  _FakeOnboardingApiService(super.client, {this.shouldFail = false});

  @override
  Future<List<Map<String, dynamic>>> listAdminSessions({String? statusFilter}) async {
    if (shouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/onboarding/admin/sessions'),
        type: DioExceptionType.connectionTimeout,
        message: 'Timeout',
      );
    }
    return [
      {
        'id': 'ses-1',
        'branch_name': 'Ogijo Branch',
        'branch_code': 'OGI',
        'token': 'onb_branch_ogi',
        'status': 'submitted',
        'contact_person': 'Kemi Ade',
        'contact_phone': '08011122233',
        'total_groups': 4,
        'total_members': 32,
        'total_savings': 420000.0,
        'total_active_credit': 1850000.0,
        'total_current_balance': 920000.0,
        'expires_at': '2026-12-10T00:00:00Z',
      },
      {
        'id': 'ses-2',
        'branch_name': 'Mowe Branch',
        'branch_code': 'MOW',
        'token': 'onb_branch_mow',
        'status': 'draft',
        'contact_person': 'Seyi O.',
        'total_groups': 2,
        'total_members': 14,
        'total_savings': 160000.0,
        'total_active_credit': 750000.0,
        'total_current_balance': 480000.0,
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> getSession(String token, {String? officer}) async {
    if (shouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/onboarding/session/$token'),
        type: DioExceptionType.connectionTimeout,
        message: 'Timeout',
      );
    }
    return {
      'session': {
        'id': 'ses-1',
        'branch_name': 'Ogijo Branch',
        'branch_code': 'OGI',
        'status': 'draft',
        'payload': {
          'officers': [
            {
              'id': 'co-1',
              'name': 'Ada Obi',
              'phone': '08012345678',
              'role': 'Credit Officer',
              'is_misc_savings_manager': true,
              'status': 'drafting',
            },
          ],
          'groups': [
            {
              'group_reference': 'GRP-01',
              'group_name': 'Unity Traders',
              'meeting_day': 'Wednesday',
              'leader_name': 'Alhaja Risikat',
              'officer_name': 'Ada Obi',
              'group_savings': 45000.0,
            },
          ],
          'members': [
            {
              'member_reference': 'OGI-01-001',
              'group_reference': 'GRP-01',
              'full_name': 'Kehinde Afolabi',
              'phone_number': '08098765432',
              'savings_balance': 35000.0,
              'principal_loan': 120000.0,
              'active_credit': 144000.0,
              'current_credit_balance': 84000.0,
              'loan_type': '12-Week Standard',
            },
          ],
          'misc_savings': 15000.0,
          'laps_savings': 8000.0,
        },
      },
      'loan_products': [
        {'id': 'lp-1', 'name': '12-Week Standard'},
        {'id': 'lp-2', 'name': '60-Day Asset'},
      ],
      'meeting_days': ['Daily', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
    };
  }

  @override
  Future<Map<String, dynamic>> getOfficerWorkspace(String coToken) async {
    if (shouldFail) {
      throw Exception('Workspace expired or unreachable');
    }
    return {
      'officer': {
        'id': 'co-1',
        'name': 'Ada Obi',
        'status': 'drafting',
        'is_misc_savings_manager': true,
        'misc_savings': 12000.0,
      },
      'branch_name': 'Ogijo Branch',
      'branch_code': 'OGI',
      'session_status': 'draft',
      'is_locked': false,
      'groups': [
        {
          'group_reference': 'GRP-01',
          'group_name': 'Unity Traders',
          'meeting_day': 'Wednesday',
          'leader_name': 'Alhaja Risikat',
          'group_savings': 45000.0,
        },
      ],
      'members': [
        {
          'full_name': 'Kehinde Afolabi',
          'group_reference': 'GRP-01',
          'phone_number': '08098765432',
          'savings_balance': 35000.0,
          'principal_loan': 120000.0,
          'active_credit': 144000.0,
          'current_credit_balance': 84000.0,
          'loan_type': '12-Week Standard',
        },
      ],
      'aggregates': {
        'individual_member_savings': 35000.0,
        'group_savings_pool': 45000.0,
        'misc_savings': 12000.0,
        'total_portfolio_savings': 92000.0,
        'active_credit': 144000.0,
        'outstanding_balance': 84000.0,
      },
      'loan_products': [
        {'id': 'lp-1', 'name': '12-Week Standard'},
      ],
    };
  }
}

List<Override> _buildOverrides({bool shouldFail = false}) {
  SharedPreferences.setMockInitialValues({});
  final offlineDb = OfflineDatabaseService(
    useMemoryStore: true,
    userId: 'admin_1',
    branchId: 'br-ho',
  );
  final conn = _QuietConn();
  final apiClient = ApiClient(
    baseUrl: 'http://localhost',
    connectivityService: conn,
    offlineDb: offlineDb,
    adapter: _NoopHttpAdapter(),
  );
  final adminUser = AuthUser(
    id: 'adm-1',
    username: 'admin_ceo',
    fullName: 'Mrs. Shobande',
    role: 'Admin',
    branch: 'Head Office',
    branchId: 'br-ho',
  );

  return [
    connectivityServiceProvider.overrideWithValue(conn),
    offlineDatabaseServiceProvider.overrideWithValue(offlineDb),
    apiClientProvider.overrideWithValue(apiClient),
    authControllerProvider.overrideWith(
      (ref) => _StaticAuthController(adminUser, apiClient, offlineDb),
    ),
    procurementApiServiceProvider.overrideWithValue(
      _FakeProcurementApiService(apiClient, shouldFail: shouldFail),
    ),
    onboardingApiServiceProvider.overrideWithValue(
      _FakeOnboardingApiService(apiClient, shouldFail: shouldFail),
    ),
  ];
}

void _assertCleanGovernance(WidgetTester tester) {
  final emojiRegex = RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true);
  final internalCodeRegex = RegExp(r'\b(BR-[A-Z0-9-]+|FP-[0-9]+|Account 1000)\b');

  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final text = w.data ?? '';
    if (text.isEmpty) continue;
    expect(emojiRegex.hasMatch(text), isFalse, reason: 'Emoji found: $text');
    expect(internalCodeRegex.hasMatch(text), isFalse, reason: 'Internal code leaked: $text');
    expect(text.contains('DioException'), isFalse, reason: 'Raw exception leaked: $text');
    expect(text.contains('core database'), isFalse, reason: 'Internal phrase leaked: $text');
    expect(text.contains('Daily 60 Days'), isFalse, reason: 'Hardcoded fallback leaked: $text');
  }
}

void _expectNoException(WidgetTester tester) {
  final err = tester.takeException();
  expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : '$err');
}

void main() {
  group('Phase 4 Procurement & Onboarding Suite', () {
    for (final width in <double>[360, 1280]) {
      testWidgets(
        'AssetProcurementScreen renders analytics charts, metrics, and stock matrix without overflow at ${width.toInt()}px',
        (tester) async {
          tester.view.physicalSize = Size(width, 960);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            ProviderScope(
              overrides: _buildOverrides(),
              child: MaterialApp(
                theme: IcareTheme.lightTheme,
                darkTheme: IcareTheme.darkTheme,
                themeMode: width == 360 ? ThemeMode.dark : ThemeMode.light,
                home: const Scaffold(
                  body: SingleChildScrollView(child: AssetProcurementScreen()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          _expectNoException(tester);
          expect(find.byType(BarChart), findsAtLeastNWidgets(1));
          expect(find.byType(PieChart), findsAtLeastNWidgets(1));
          expect(find.byType(IcareMetricCard), findsAtLeastNWidgets(1));
          _assertCleanGovernance(tester);
        },
      );
    }

    for (final width in <double>[360, 1280]) {
      testWidgets(
        'BranchOnboardingAdminScreen renders overview charts, adaptive generate sheet, and zero FlowCards at ${width.toInt()}px',
        (tester) async {
          tester.view.physicalSize = Size(width, 960);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            ProviderScope(
              overrides: _buildOverrides(),
              child: MaterialApp(
                theme: IcareTheme.lightTheme,
                darkTheme: IcareTheme.darkTheme,
                themeMode: width == 360 ? ThemeMode.dark : ThemeMode.light,
                home: const Scaffold(
                  body: SingleChildScrollView(child: BranchOnboardingAdminScreen()),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          await tester.pump(const Duration(milliseconds: 250));

          _expectNoException(tester);
          expect(find.byType(BarChart), findsAtLeastNWidgets(1));
          expect(find.byType(PieChart), findsAtLeastNWidgets(1));
          expect(find.byType(IcareStatusBadge), findsAtLeastNWidgets(1));
          expect(find.byType(IcareCard), findsAtLeastNWidgets(1));
          expect(find.textContaining('Core Banking'), findsNothing);
          _assertCleanGovernance(tester);

          await tester.tap(find.text('Generate Branch Link'));
          await tester.pumpAndSettle();
          _expectNoException(tester);
          expect(find.text('Generate Secure Link'), findsOneWidget);

          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          _expectNoException(tester);
        },
      );
    }

    testWidgets(
      'BranchOnboardingAdminScreen error state renders Retry card without leaking exceptions',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _buildOverrides(shouldFail: true),
            child: MaterialApp(
              theme: IcareTheme.lightTheme,
              home: const Scaffold(
                body: SingleChildScrollView(child: BranchOnboardingAdminScreen()),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));

        final portalInitErr = tester.takeException();
        expect(portalInitErr, isNull, reason: portalInitErr is FlutterError ? portalInitErr.toStringDeep() : '$portalInitErr');
        expect(find.text('Retry'), findsOneWidget);
        _assertCleanGovernance(tester);
      },
    );

    testWidgets(
      'BranchOnboardingPortalScreen and CreditOfficerPortalScreen render review charts cleanly on 360px mobile',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _buildOverrides(),
            child: MaterialApp(
              theme: IcareTheme.lightTheme,
              home: const BranchOnboardingPortalScreen(token: 'onb_branch_ogi'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));

        _expectNoException(tester);
        expect(find.textContaining('ICARE Onboarding Portal'), findsOneWidget);
        expect(find.textContaining('ICARE Core Banking'), findsNothing);

        final reviewPortalTab = find.text('Review & Submit to AM');
        await tester.drag(find.byType(TabBar), const Offset(-600, 0));
        await tester.pumpAndSettle();
        await tester.ensureVisible(reviewPortalTab);
        await tester.pumpAndSettle();
        await tester.tap(reviewPortalTab);
        await tester.pumpAndSettle();

        _expectNoException(tester);
        expect(find.byType(BarChart), findsAtLeastNWidgets(1));
        expect(find.byType(PieChart), findsAtLeastNWidgets(1));
        _assertCleanGovernance(tester);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _buildOverrides(),
            child: MaterialApp(
              theme: IcareTheme.darkTheme,
              home: const CreditOfficerPortalScreen(coToken: 'onb_co_test'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));

        _expectNoException(tester);
        final reviewCoTab = find.text('Review');
        await tester.drag(find.byType(TabBar), const Offset(-500, 0));
        await tester.pumpAndSettle();
        await tester.ensureVisible(reviewCoTab);
        await tester.pumpAndSettle();
        await tester.tap(reviewCoTab);
        await tester.pumpAndSettle();

        _expectNoException(tester);
        expect(find.byType(BarChart), findsAtLeastNWidgets(1));
        expect(find.byType(PieChart), findsAtLeastNWidgets(1));
        _assertCleanGovernance(tester);
      },
    );
  });
}
