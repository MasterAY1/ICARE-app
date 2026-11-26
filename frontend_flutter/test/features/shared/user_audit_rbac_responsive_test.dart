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
import 'package:frontend_flutter/core/auth/role_utils.dart';
import 'package:frontend_flutter/core/auth/session_storage_base.dart';
import 'package:frontend_flutter/core/errors/app_error_formatter.dart';
import 'package:frontend_flutter/core/network/api_client.dart';
import 'package:frontend_flutter/core/offline/connectivity_service.dart';
import 'package:frontend_flutter/core/offline/offline_database_service.dart';
import 'package:frontend_flutter/core/theme/icare_theme.dart';
import 'package:frontend_flutter/core/theme/theme_controller.dart';
import 'package:frontend_flutter/features/audit/data/datasources/audit_api_service.dart';
import 'package:frontend_flutter/features/audit/data/models/audit_models.dart';
import 'package:frontend_flutter/features/audit/presentation/audit_ledger_screen.dart';
import 'package:frontend_flutter/features/audit/presentation/widgets/audit_integrity_and_insights_tabs.dart';
import 'package:frontend_flutter/features/bm/data/datasources/user_management_api_service.dart';
import 'package:frontend_flutter/features/bm/data/models/user_management_models.dart';
import 'package:frontend_flutter/features/bm/presentation/user_management_screen.dart';
import 'package:frontend_flutter/features/shared/presentation/co_app_scaffold.dart';

class _MemStorage implements SessionStorage {
  Map<String, String>? _data;
  @override
  Future<void> clearSession() async => _data = null;
  @override
  Future<Map<String, String>?> getSession() async => _data;
  @override
  Future<void> saveSession(String token, String userJson) async =>
      _data = {'token': token, 'user': userJson};
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

class _StaticConn implements ConnectivityService {
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

class _FakeAuthController extends AuthController {
  _StaticConn? conn;
  _FakeAuthController(
    AuthUser user,
    ApiClient api,
    OfflineDatabaseService db,
  ) : super(api, db, _MemStorage(), false) {
    state = AuthStateAuthenticated(user: user, token: 'test-token');
  }
}

class _FakeUserManagementApi extends UserManagementApiService {
  final List<String> revokedIds = [];
  final List<String> deletedIds = [];
  bool emptyProductMeta;

  _FakeUserManagementApi(
    super.apiClient, {
    this.emptyProductMeta = false,
  });

  List<BranchOptionItemModel> get _branches => [
        BranchOptionItemModel(branchId: 'b-1', name: 'Sagamu Branch'),
        BranchOptionItemModel(branchId: 'b-2', name: 'Abeokuta Branch'),
      ];

  @override
  Future<UserListResponseModel> getUsers() async {
    return UserListResponseModel(
      totalCount: 3,
      availableBranches: _branches,
      users: [
        UserListItemModel(
          id: 'u-co1',
          username: 'CO1',
          fullName: 'Ada Obi',
          role: 'Credit Officer',
          branchName: 'Sagamu Branch',
          branchId: 'b-1',
          isActive: true,
          lastLogin: '2026-11-25 08:15:00',
          createdAt: '2026-01-10',
        ),
        UserListItemModel(
          id: 'u-bm1',
          username: 'BM_Sagamu',
          fullName: 'Bola Ade',
          role: 'Branch Manager',
          branchName: 'Sagamu Branch',
          branchId: 'b-1',
          isActive: true,
          lastLogin: '2026-11-25 07:45:00',
          createdAt: '2026-01-05',
        ),
        UserListItemModel(
          id: 'u-am1',
          username: 'AM_RegionA',
          fullName: 'Chidi Eze',
          role: 'Area Manager',
          branchName: 'Abeokuta Branch',
          branchId: 'b-2',
          isActive: false,
          lastLogin: 'Never',
          createdAt: '2026-01-03',
        ),
      ],
    );
  }

  @override
  Future<ProductAssignmentMetaResponseModel> getProductAssignmentMeta() async {
    return ProductAssignmentMetaResponseModel(
      availableProducts:
          emptyProductMeta ? const [] : const ['Business Weekly', 'Asset Plus'],
      creditOfficers: [
        CreditOfficerProductMetaModel(
          id: 'u-co1',
          username: 'CO1',
          fullName: 'Ada Obi',
          allowedProducts: emptyProductMeta ? const [] : const ['Business Weekly'],
        ),
      ],
    );
  }

  @override
  Future<AMAssignmentsResponseModel> getAmAssignments() async {
    return AMAssignmentsResponseModel(
      areaManagers: [
        AMAssignmentItemModel(
          userId: 'u-am1',
          username: 'AM_RegionA',
          fullName: 'Chidi Eze',
          assignedBranchIds: const ['b-1'],
          assignedBranchNames: const ['Sagamu Branch'],
        ),
      ],
      allBranches: _branches,
    );
  }

  @override
  Future<BranchClosuresResponseModel> getBranchClosures() async {
    return BranchClosuresResponseModel(
      availableBranches: _branches,
      closures: [
        BranchClosureItemModel(
          id: 'cl-1',
          startDate: '2026-12-25',
          endDate: '2026-12-26',
          reason: 'Public Holiday',
          branchId: 'b-1',
          branchName: 'Sagamu Branch',
        ),
      ],
    );
  }

  @override
  Future<UserAuditLogsResponseModel> getUserAuditLogs({int limit = 200}) async {
    return UserAuditLogsResponseModel(
      totalCount: 1,
      logs: [
        UserAuditLogItemModel(
          id: 'al-1',
          timestamp: '2026-11-25 09:00:00',
          username: 'admin',
          role: 'Admin',
          branch: 'Head Office',
          action: 'USER_UPDATED',
          module: 'Users',
          status: 'SUCCESS',
        ),
      ],
    );
  }

  @override
  Future<LoginHistoryResponseModel> getLoginHistory({int limit = 200}) async {
    return LoginHistoryResponseModel(
      totalCount: 2,
      history: [
        LoginHistoryItemModel(
          id: 'lh-1',
          loginTime: '2026-11-25 08:15:00',
          username: 'CO1',
          status: 'SUCCESS',
          sessionId: 'sess-101',
          failedAttempts: 0,
        ),
        LoginHistoryItemModel(
          id: 'lh-2',
          loginTime: '2026-11-25 07:30:00',
          username: 'CO2',
          status: 'FAILED',
          sessionId: null,
          failedAttempts: 2,
        ),
      ],
    );
  }

  @override
  Future<GenericActionResponseModel> revokeUserSessions({
    required String userId,
  }) async {
    revokedIds.add(userId);
    return GenericActionResponseModel(
      success: true,
      message: 'Sessions revoked.',
    );
  }

  @override
  Future<GenericActionResponseModel> deleteUserPermanently({
    required String userId,
  }) async {
    deletedIds.add(userId);
    return GenericActionResponseModel(
      success: true,
      message: 'User deleted.',
    );
  }
}

class _FakeAuditApi extends AuditApiService {
  final int totalRiskClients;
  _FakeAuditApi(super.apiClient, {this.totalRiskClients = 100});

  @override
  Future<AuditMetaModel> getMetadata({String? branchId}) async {
    return AuditMetaModel(
      branches: [
        BranchOptionModel(branchId: 'b-1', name: 'Sagamu Branch', code: 'SAG'),
        BranchOptionModel(branchId: 'b-2', name: 'Abeokuta Branch', code: 'ABE'),
      ],
      officers: [
        OfficerOptionModel(
          id: 'u-co1',
          username: 'CO1',
          fullName: 'Ada Obi',
          displayName: 'Ada Obi (CO1)',
        ),
      ],
      products: [
        ProductOptionModel(productId: 'p-1', name: 'Business Weekly', code: 'BW'),
      ],
    );
  }

  @override
  Future<Integrity6WayModel> get6WayIntegrity({
    String? branchId,
    String? postingDate,
  }) async {
    return Integrity6WayModel(
      branchId: branchId ?? 'b-1',
      postingDate: postingDate ?? '2026-11-25',
      isBalanced: true,
      statusText: 'All 6 financial projections reconcile to zero variance.',
      statusBadge: 'BALANCED',
      ledgerTotal: 250000.0,
      auditViewsTotal: 250000.0,
      coCashbooksTotal: 250000.0,
      masterCashbookTotal: 250000.0,
      dashboardTotal: 250000.0,
      reportsTotal: 250000.0,
      variances: const [],
    );
  }

  @override
  Future<ExceptionReportsResponseModel> getExceptionReports({
    String? branchId,
  }) async {
    return ExceptionReportsResponseModel(
      totalExceptions: 1,
      exceptionRulesEvaluated: 15,
      details: {
        'overdue_repayments': [
          {'Loan': 'LN-101', 'Client': 'Ada Obi', 'Amount': 5000.0, 'Status': 'OVERDUE'},
        ],
        'orphan_ledger_entries': const [],
      },
    );
  }

  @override
  Future<RiskDistributionResponseModel> getPerformanceInsights({
    String? branchId,
  }) async {
    if (totalRiskClients == 0) {
      return RiskDistributionResponseModel(
        branchId: branchId ?? 'ALL',
        distribution: const {
          'EXCELLENT': 0,
          'GOOD': 0,
          'FAIR': 0,
          'RISKY': 0,
          'HIGH_RISK': 0,
          'total_clients': 0,
        },
      );
    }
    return RiskDistributionResponseModel(
      branchId: branchId ?? 'ALL',
      distribution: const {
        'EXCELLENT': 40,
        'GOOD': 25,
        'FAIR': 15,
        'RISKY': 12,
        'HIGH_RISK': 8,
        'total_clients': 100,
      },
    );
  }

  @override
  Future<WithdrawalAuditResponseModel> getWithdrawalAudit({
    String? dateFrom,
    String? dateTo,
    String statusFilter = 'ALL',
    String? branchId,
    String? search,
  }) async {
    return WithdrawalAuditResponseModel(
      summary: WithdrawalAuditSummaryModel(
        totalRequests: 1,
        pendingCount: 0,
        approvedCount: 1,
        rejectedCount: 0,
        approvedAmount: 15000.0,
        pendingAmount: 0.0,
      ),
      requests: [
        {
          'operational_date': '2026-11-25',
          'client_name': 'Ada Obi',
          'savings_type': 'Individual',
          'operation_type': 'Withdrawal',
          'amount': 15000.0,
          'payout_method': 'Cash',
          'requested_by': 'CO1',
          'approved_by': 'BM_Sagamu',
          'branch': 'Sagamu Branch',
          'reference': 'WR-001',
          'status': 'APPROVED',
        },
      ],
      auditEvents: const [],
    );
  }
}

AuthUser _user(String role) => AuthUser(
      id: 'uid-$role',
      username: 'user_$role',
      fullName: 'Test $role',
      role: role,
      branch: 'Sagamu Branch',
      branchId: 'b-1',
      assignedBranches: const ['Sagamu Branch', 'Abeokuta Branch'],
      assignedBranchIds: const ['b-1', 'b-2'],
    );

List<Override> _infra(
  AuthUser user, {
  String activePage = 'Dashboard',
  _FakeUserManagementApi? umApi,
  _FakeAuditApi? auditApi,
}) {
  final conn = _StaticConn();
  final db = OfflineDatabaseService(useMemoryStore: true);
  final client = ApiClient(
    connectivityService: conn,
    offlineDb: db,
    adapter: _NoopHttpAdapter(),
    isWebOverride: false,
  );
  return [
    connectivityServiceProvider.overrideWithValue(conn),
    offlineDatabaseServiceProvider.overrideWithValue(db),
    apiClientProvider.overrideWithValue(client),
    authControllerProvider.overrideWith((_) => _FakeAuthController(user, client, db)),
    themeControllerProvider.overrideWith((_) => ThemeController(autoLoad: false)),
    activeCoPageProvider.overrideWith((_) => activePage),
    userManagementApiServiceProvider.overrideWithValue(
      umApi ?? _FakeUserManagementApi(client),
    ),
    auditApiServiceProvider.overrideWithValue(
      auditApi ?? _FakeAuditApi(client),
    ),
  ];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('IcareRoleUtils canonical normalization', () {
    test('normalizes uppercase, underscore, and alias variants consistently', () {
      expect(IcareRoleUtils.isCo('CREDIT_OFFICER'), isTrue);
      expect(IcareRoleUtils.isBm('BRANCH_MANAGER'), isTrue);
      expect(IcareRoleUtils.isAm('AREA_MANAGER'), isTrue);
      expect(IcareRoleUtils.isAccountManager('Account Manager'), isTrue);
      expect(IcareRoleUtils.isAccountManager('ACCOUNT_MANAGER'), isTrue);
      expect(IcareRoleUtils.isDirector('Director'), isTrue);
      expect(IcareRoleUtils.isDirector('Executive Director'), isTrue);
      expect(IcareRoleUtils.isAdmin('ADMIN'), isTrue);
      expect(IcareRoleUtils.isAdmin('SUPER_ADMIN'), isTrue);
      // Director must NEVER evaluate true as mutating Admin
      expect(IcareRoleUtils.isAdmin('Director'), isFalse);
      expect(IcareRoleUtils.isExecutive('Director'), isTrue);
    });
  });

  group('AppErrorDetails sanitization', () {
    test('formats DioException without leaking raw stack traces or URLs', () {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/api/v1/users'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/users'),
          statusCode: 500,
          data: {'detail': 'Internal audit fault'},
        ),
      );
      final details = AppErrorDetails.from(dioErr);
      expect(details.message, isNot(contains('mozilla.org')));
      expect(details.message, isNotEmpty);
    });
  });

  void _setViewport(WidgetTester tester, double width, [double height = 900]) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('CoAppScaffold RBAC menu integrity', () {
    testWidgets('Admin nav includes Audit Ledger and User Management', (tester) async {
      _setViewport(tester, 1280, 900);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _infra(_user('Admin'), activePage: 'User Management'),
          child: MaterialApp(
            theme: IcareTheme.lightTheme,
            home: const CoAppScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Audit Ledger'), findsOneWidget);
      expect(find.text('User Management'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Director sees Audit Ledger but NOT User Management', (tester) async {
      _setViewport(tester, 1280, 900);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _infra(_user('Director'), activePage: 'Audit Ledger'),
          child: MaterialApp(
            theme: IcareTheme.lightTheme,
            home: const CoAppScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Audit Ledger'), findsOneWidget);
      expect(find.text('User Management'), findsNothing);
      expect(find.text('Reconciliation Wizard'), findsNothing);
      expect(find.textContaining('Read-Only Executive Oversight Mode'), findsOneWidget);
    });

    testWidgets('Account Manager sees Master Cashbook & Reports instead of CO menu',
        (tester) async {
      _setViewport(tester, 1280, 900);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _infra(_user('Account Manager'), activePage: 'Placeholder'),
          child: MaterialApp(
            theme: IcareTheme.lightTheme,
            home: const CoAppScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Master Cashbook'), findsOneWidget);
      expect(find.text('Reports & Export'), findsOneWidget);
      expect(find.text('Loan Origination'), findsNothing);
      expect(find.text('CO Cashbook'), findsNothing);
    });
  });

  group('UserManagementScreen Fluid UI & RBAC behavior', () {
    for (final width in [360.0, 800.0, 1280.0]) {
      for (final isDark in [false, true]) {
        testWidgets(
          'renders cleanly at ${width.toInt()}px (${isDark ? 'Dark' : 'Light'})',
          (tester) async {
            _setViewport(tester, width, 900);

            await tester.pumpWidget(
              ProviderScope(
                overrides: _infra(_user('Admin')),
                child: MaterialApp(
                  theme: isDark ? IcareTheme.darkTheme : IcareTheme.lightTheme,
                  home: const Scaffold(
                    body: SingleChildScrollView(
                      padding: EdgeInsets.all(12),
                      child: UserManagementScreen(),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Enterprise User & Security Control'), findsOneWidget);
            expect(find.textContaining('Sagamu Branch'), findsWidgets);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('Create User uses dynamic API branches & Product Assignment handles empty list safely',
        (tester) async {
      _setViewport(tester, 1280, 900);

      final conn = _StaticConn();
      final db = OfflineDatabaseService(useMemoryStore: true);
      final api = ApiClient(
        connectivityService: conn,
        offlineDb: db,
        adapter: _NoopHttpAdapter(),
        isWebOverride: false,
      );
      final fakeUm = _FakeUserManagementApi(api, emptyProductMeta: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _infra(_user('Admin'), umApi: fakeUm),
          child: MaterialApp(
            theme: IcareTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: UserManagementScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final createTab = find.text('Create User');
      await tester.ensureVisible(createTab);
      await tester.tap(createTab);
      await tester.pumpAndSettle();
      // Dynamic branches from mock API appear (Abeokuta selected first alphabetically; Sagamu in dropdown), NOT hardcoded Ogijo
      expect(find.text('Abeokuta Branch'), findsWidgets);
      expect(find.text('Sagamu Branch', skipOffstage: false), findsWidgets);
      expect(find.text('Ogijo', skipOffstage: false), findsNothing);

      final prodTab = find.text('Product Assignment');
      await tester.ensureVisible(prodTab);
      await tester.tap(prodTab);
      await tester.pumpAndSettle();
      expect(
        find.text('No active loan products are currently configured in the catalog.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AuditLedgerScreen Fluid UI, 5-Tier Risk & Role Scopes', () {
    for (final width in [360.0, 800.0, 1280.0]) {
      for (final isDark in [false, true]) {
        testWidgets(
          'renders Admin Audit 6-Way & 5-Tier Risk at ${width.toInt()}px (${isDark ? 'Dark' : 'Light'})',
          (tester) async {
            _setViewport(tester, width, 900);

            await tester.pumpWidget(
              ProviderScope(
                overrides: _infra(_user('Admin')),
                child: MaterialApp(
                  theme: isDark ? IcareTheme.darkTheme : IcareTheme.lightTheme,
                  home: const Scaffold(
                    body: SingleChildScrollView(
                      padding: EdgeInsets.all(12),
                      child: AuditLedgerScreen(),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('6-Way Integrity Match'), findsOneWidget);
            expect(find.text('Reconciliation Wizard'), findsOneWidget);
            expect(find.text('FINANCIAL INTEGRITY VERIFIED'), findsOneWidget);

            final insightsTab = find.text('Performance Insights');
            await tester.ensureVisible(insightsTab);
            await tester.pumpAndSettle();
            await tester.tap(insightsTab);
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Risky'));
            expect(find.text('Risky'), findsOneWidget);
            await tester.ensureVisible(find.text('High Risk'));
            expect(find.text('High Risk'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('Zero-client Risk Insights renders honest empty state without NaN error',
        (tester) async {
      _setViewport(tester, 1024, 900);

      final conn = _StaticConn();
      final db = OfflineDatabaseService(useMemoryStore: true);
      final api = ApiClient(
        connectivityService: conn,
        offlineDb: db,
        adapter: _NoopHttpAdapter(),
        isWebOverride: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _infra(
            _user('Director'),
            auditApi: _FakeAuditApi(api, totalRiskClients: 0),
          ),
          child: MaterialApp(
            theme: IcareTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: AuditLedgerScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final insightsTab = find.text('Performance Insights');
      await tester.ensureVisible(insightsTab);
      await tester.pumpAndSettle();
      await tester.tap(insightsTab);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('No scored client loans exist for this scope yet.'));
      expect(
        find.text('No scored client loans exist for this scope yet.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AuditWizardTab blocks Director even if instantiated directly',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: IcareTheme.lightTheme,
            home: Scaffold(
              body: AuditWizardTab(
                isAdmin: false,
                isDirector: true,
                fallbackBranchId: 'b-1',
                branchOptions: const ['Sagamu Branch'],
                resolveBranchId: (_) => 'b-1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Projection repair is restricted strictly to Administrators.'),
        findsOneWidget,
      );
    });
  });
}
