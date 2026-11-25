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
import 'package:frontend_flutter/core/theme/icare_theme.dart';
import 'package:frontend_flutter/core/theme/theme_controller.dart';
import 'package:frontend_flutter/features/am/data/models/am_dashboard_models.dart';
import 'package:frontend_flutter/features/am/presentation/am_dashboard_screen.dart';
import 'package:frontend_flutter/features/co/presentation/withdrawal_operations_screen.dart';
import 'package:frontend_flutter/features/onboarding/data/onboarding_api_service.dart';
import 'package:frontend_flutter/features/shared/presentation/co_app_scaffold.dart';

class _InMemorySessionStorage implements SessionStorage {
  Map<String, String>? _stored;

  @override
  Future<void> saveSession(String token, String userJson) async {
    _stored = {'token': token, 'user': userJson};
  }

  @override
  Future<Map<String, String>?> getSession() async => _stored;

  @override
  Future<void> clearSession() async {
    _stored = null;
  }
}

class _FakeHttpAdapter implements HttpClientAdapter {
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

class _QuietConnectivityService implements ConnectivityService {
  final StreamController<bool> _ctrl = StreamController<bool>.broadcast();
  bool _online;

  _QuietConnectivityService({bool isOnline = true}) : _online = isOnline;

  @override
  Stream<bool> get statusStream => _ctrl.stream;

  @override
  bool get isOnline => _online;

  @override
  void reportOffline() {
    _online = false;
    if (!_ctrl.isClosed) _ctrl.add(false);
  }

  @override
  void reportOnline() {
    _online = true;
    if (!_ctrl.isClosed) _ctrl.add(true);
  }

  @override
  Future<bool> checkActualConnection({bool forceImmediateOffline = false}) async {
    return _online;
  }

  @override
  void dispose() {
    _ctrl.close();
  }
}

class _StaticAuthController extends AuthController {
  _StaticAuthController(
    AuthUser user,
    ApiClient apiClient,
    OfflineDatabaseService offlineDb,
  ) : super(apiClient, offlineDb, _InMemorySessionStorage(), false) {
    state = AuthStateAuthenticated(user: user, token: 'test-jwt-token');
  }
}

AuthUser _buildUserForRole(String role, {String fullName = 'Test Staff'}) {
  return AuthUser(
    id: 'user-${role.toLowerCase().replaceAll(' ', '_')}',
    username: 'staff_${role.toLowerCase().replaceAll(' ', '_')}',
    fullName: fullName,
    role: role,
    branch: 'Ikeja Branch',
    branchId: 'br-ikeja',
    assignedBranches: const ['Ikeja Branch', 'Ogijo Branch'],
    assignedBranchIds: const ['br-ikeja', 'br-ogijo'],
  );
}

AmDashboardDataModel _buildLiveAmData() {
  return AmDashboardDataModel(
    regionalSummary: RegionalSummaryModel(
      areaName: 'Area 1',
      businessDate: '2026-11-25',
      branchesCount: 2,
      openBranchesCount: 2,
      activeClients: 640,
      activeCredit: 38500000.0,
      outstandingPortfolio: 32000000.0,
      totalSavings: 14200000.0,
      todayExpected: 1000000.0,
      todayCollected: 850000.0,
      compliancePct: 85.0,
      vaultCashAcct1000: 2750000.0,
      par: '2.8%',
      defaultersCount: 7,
      assignedBranches: const ['Ikeja Branch', 'Ogijo Branch'],
    ),
    branchPerformance: [
      BranchPerformanceItemModel(
        branchId: 'br-ikeja',
        branchName: 'Ikeja Branch',
        bmName: 'Adebayo T.',
        isClosed: false,
        closureReason: '',
        expectedCollection: 600000.0,
        collected: 540000.0,
        outstandingToday: 60000.0,
        compliancePct: 90.0,
        vaultCashAcct1000: 1650000.0,
        par: '1.9%',
        defaultersCount: 3,
        cashVariance: 0.0,
        eodStatus: 'PENDING',
        operationalStatus: 'Operational',
        reversalsCount: 1,
        loansDisbursedCount: 4,
        principalDisbursedAmount: 800000.0,
        activeCreditDisbursedAmount: 1080000.0,
        fullPaymentsCount: 2,
        fullPaymentsActiveCredit: 320000.0,
        netLoanCount: 2,
        netActiveCreditVolume: 760000.0,
      ),
      BranchPerformanceItemModel(
        branchId: 'br-ogijo',
        branchName: 'Ogijo Branch',
        bmName: 'Ngozi K.',
        isClosed: false,
        closureReason: '',
        expectedCollection: 400000.0,
        collected: 310000.0,
        outstandingToday: 90000.0,
        compliancePct: 77.5,
        vaultCashAcct1000: 1100000.0,
        par: '3.7%',
        defaultersCount: 4,
        cashVariance: 0.0,
        eodStatus: 'CLOSED',
        operationalStatus: 'Requires Attention',
        reversalsCount: 0,
        loansDisbursedCount: 2,
        principalDisbursedAmount: 450000.0,
        activeCreditDisbursedAmount: 607500.0,
        fullPaymentsCount: 1,
        fullPaymentsActiveCredit: 150000.0,
        netLoanCount: 1,
        netActiveCreditVolume: 457500.0,
      ),
    ],
    approvalsHub: AreaApprovalsHubModel(
      pendingHighValueLoans: [
        PendingHighValueLoanItemModel(
          loanId: 'ln-high-1',
          branchId: 'br-ikeja',
          branchName: 'Ikeja Branch',
          clientId: 'cl-1',
          clientName: 'Chinedu Okafor',
          clientCode: 'IKJ-0041',
          officer: 'Tunde B.',
          loanProduct: 'SME Capital Loan',
          loanAmount: 450000.0,
          applicationDate: '2026-11-25',
          escalationReason: 'Above Branch Limit (> ₦300k)',
        ),
      ],
      pendingBranchTransfers: const [],
      pendingBranchEods: const [],
      pendingBranchReversals: const [],
      canLockArea: false,
    ),
  );
}

AmDashboardDataModel _buildEmptyAmData() {
  return AmDashboardDataModel(
    regionalSummary: RegionalSummaryModel(
      areaName: 'Area 1',
      businessDate: '2026-11-25',
      branchesCount: 1,
      openBranchesCount: 1,
      activeClients: 0,
      activeCredit: 0.0,
      outstandingPortfolio: 0.0,
      totalSavings: 0.0,
      todayExpected: 0.0,
      todayCollected: 0.0,
      compliancePct: 0.0,
      vaultCashAcct1000: 0.0,
      par: '0.0%',
      defaultersCount: 0,
      assignedBranches: const ['Ikeja Branch'],
    ),
    branchPerformance: [
      BranchPerformanceItemModel(
        branchId: 'br-ikeja',
        branchName: 'Ikeja Branch',
        bmName: 'Adebayo T.',
        isClosed: false,
        closureReason: '',
        expectedCollection: 0.0,
        collected: 0.0,
        outstandingToday: 0.0,
        compliancePct: 0.0,
        vaultCashAcct1000: 0.0,
        par: '0.0%',
        defaultersCount: 0,
        cashVariance: 0.0,
        eodStatus: 'PENDING',
        operationalStatus: 'Operational',
      ),
    ],
    approvalsHub: AreaApprovalsHubModel(
      pendingHighValueLoans: const [],
      pendingBranchTransfers: const [],
      pendingBranchEods: const [],
      pendingBranchReversals: const [],
      canLockArea: false,
    ),
  );
}

void _expectNoEmojis(WidgetTester tester) {
  final emojiPattern = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
    unicode: true,
  );
  for (final widget in tester.allWidgets) {
    if (widget is Text && widget.data != null) {
      expect(
        emojiPattern.hasMatch(widget.data!),
        isFalse,
        reason: 'Forbidden emoji found in UI text: "${widget.data}"',
      );
    }
  }
}

void _expectNoInternalCodes(WidgetTester tester) {
  final internalPattern = RegExp(r'\b(BR-[A-Z]+-\d+|FP-\d+|Account 1000)\b');
  for (final widget in tester.allWidgets) {
    if (widget is Text && widget.data != null) {
      expect(
        internalPattern.hasMatch(widget.data!),
        isFalse,
        reason: 'Internal technical code leaked in UI text: "${widget.data}"',
      );
    }
  }
}

List<Override> _baseInfraOverrides({
  required AuthUser user,
  String activePage = 'Dashboard',
}) {
  final conn = _QuietConnectivityService(isOnline: true);
  final offlineDb = OfflineDatabaseService(useMemoryStore: true);
  final apiClient = ApiClient(
    connectivityService: conn,
    offlineDb: offlineDb,
    adapter: _FakeHttpAdapter(),
    isWebOverride: false,
  );
  return [
    connectivityServiceProvider.overrideWithValue(conn),
    offlineDatabaseServiceProvider.overrideWithValue(offlineDb),
    apiClientProvider.overrideWithValue(apiClient),
    authControllerProvider.overrideWith(
      (_) => _StaticAuthController(user, apiClient, offlineDb),
    ),
    themeControllerProvider.overrideWith((_) => ThemeController(autoLoad: false)),
    activeCoPageProvider.overrideWith((_) => activePage),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AM Dashboard Redesign & Zero-Hardcode Verification', () {
    for (final width in <double>[360, 800, 1280]) {
      testWidgets(
        'renders AmDashboardScreen cleanly with charts & flow pipeline at ${width.toInt()}px width',
        (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final amUser = _buildUserForRole(
            'Area Manager',
            fullName: 'Mrs. Shobande',
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ..._baseInfraOverrides(user: amUser),
                amDashboardDataProvider.overrideWith(
                  (ref) async => _buildLiveAmData(),
                ),
                amMonthlyWorkflowSubmissionsProvider.overrideWith(
                  (ref) async => const [],
                ),
                adminOnboardingSessionsProvider.overrideWith(
                  (ref) async => const [],
                ),
              ],
              child: MaterialApp(
                theme: IcareTheme.lightTheme,
                home: const Scaffold(
                  body: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: AmDashboardScreen(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            find.text('Regional Supervision & EOD Governance Flow'),
            findsOneWidget,
          );
          expect(
            find.text('Branch Comparative Performance Analytics'),
            findsOneWidget,
          );
          expect(find.text('Collection & Risk Mix'), findsOneWidget);
          expect(find.text('85.0% Compliance'), findsOneWidget);

          // Toggle Bar Chart modes
          await tester.ensureVisible(find.text('Disbursed vs Payoffs'));
          await tester.tap(find.text('Disbursed vs Payoffs'));
          await tester.pumpAndSettle();
          expect(find.text('Principal Disbursed'), findsOneWidget);

          await tester.ensureVisible(find.text('Vault Reserve'));
          await tester.tap(find.text('Vault Reserve'));
          await tester.pumpAndSettle();
          expect(find.text('Physical Vault Cash'), findsOneWidget);

          // Tap Governance Stage 02 to select High-Value Loans Approval Tab
          await tester.ensureVisible(find.text('Credit > ₦300k'));
          await tester.tap(find.text('Credit > ₦300k'));
          await tester.pumpAndSettle();
          expect(find.text('Chinedu Okafor'), findsWidgets);

          expect(tester.takeException(), isNull);

          if (width < 600) {
            await tester.ensureVisible(find.text('Branches'));
            await tester.tap(find.text('Branches'));
            await tester.pumpAndSettle();
            expect(find.text('Ikeja Branch'), findsWidgets);
            expect(tester.takeException(), isNull);
          }

          _expectNoEmojis(tester);
          _expectNoInternalCodes(tester);
        },
      );
    }

    testWidgets(
      'displays honest zero empty states and dark theme cleanly with zero hardcoded 96.5% or 100.0%',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final amUser = _buildUserForRole('Area Manager');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._baseInfraOverrides(user: amUser),
              amDashboardDataProvider.overrideWith(
                (ref) async => _buildEmptyAmData(),
              ),
              amMonthlyWorkflowSubmissionsProvider.overrideWith(
                (ref) async => const [],
              ),
              adminOnboardingSessionsProvider.overrideWith(
                (ref) async => const [],
              ),
            ],
            child: MaterialApp(
              themeMode: ThemeMode.dark,
              darkTheme: IcareTheme.darkTheme,
              home: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: AmDashboardScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('0.0% Compliance'), findsOneWidget);
        expect(
          find.text('No recorded activity for this metric on the selected date'),
          findsOneWidget,
        );
        expect(find.textContaining('96.5%'), findsNothing);
        expect(find.textContaining('100.0%'), findsNothing);
        _expectNoEmojis(tester);
        _expectNoInternalCodes(tester);
      },
    );

    testWidgets(
      'formats HTTP 500 DioException through corporate AppErrorDetails banner without raw stack dump',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final amUser = _buildUserForRole('Area Manager');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._baseInfraOverrides(user: amUser),
              amDashboardDataProvider.overrideWith((ref) async {
                throw DioException(
                  requestOptions: RequestOptions(path: '/api/v1/am/dashboard'),
                  response: Response(
                    requestOptions: RequestOptions(path: '/api/v1/am/dashboard'),
                    statusCode: 500,
                    data: {'detail': 'Server error validating branch metrics'},
                  ),
                  type: DioExceptionType.badResponse,
                );
              }),
            ],
            child: MaterialApp(
              theme: IcareTheme.darkTheme,
              home: const Scaffold(body: AmDashboardScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Server Connection Delay'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.textContaining('DioException'), findsNothing);
        expect(find.textContaining('developer.mozilla.org'), findsNothing);
      },
    );
  });

  group('Withdrawal Operations Role Isolation (CO & BM Only)', () {
    testWidgets(
      'CoAppScaffold removes Withdrawal Operations for Admin and AM while preserving Dashboard & Portfolio',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        for (final roleName in const ['Admin', 'Area Manager']) {
          final user = _buildUserForRole(roleName);
          await tester.pumpWidget(
            ProviderScope(
              key: ValueKey('scaffold-$roleName'),
              overrides: _baseInfraOverrides(
                user: user,
                activePage: 'Placeholder',
              ),
              child: MaterialApp(
                theme: IcareTheme.lightTheme,
                home: const CoAppScaffold(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Dashboard'), findsOneWidget);
          expect(find.text('Portfolio'), findsOneWidget);
          expect(
            find.text('Withdrawal Operations'),
            findsNothing,
            reason: '$roleName should NOT see Withdrawal Operations in navigation',
          );
          expect(tester.takeException(), isNull);
        }

        for (final allowedRole in const ['Credit Officer', 'Branch Manager']) {
          final user = _buildUserForRole(allowedRole);
          await tester.pumpWidget(
            ProviderScope(
              key: ValueKey('scaffold-$allowedRole'),
              overrides: _baseInfraOverrides(
                user: user,
                activePage: 'Placeholder',
              ),
              child: MaterialApp(
                theme: IcareTheme.lightTheme,
                home: const CoAppScaffold(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Withdrawal Operations'),
            findsOneWidget,
            reason: '$allowedRole MUST retain Withdrawal Operations in navigation',
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'WithdrawalOperationsScreen blocks Admin and Area Manager roles',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        for (final blockedRole in const ['Admin', 'Area Manager']) {
          final user = _buildUserForRole(blockedRole);
          await tester.pumpWidget(
            ProviderScope(
              key: ValueKey('wr-blocked-$blockedRole'),
              overrides: _baseInfraOverrides(user: user),
              child: MaterialApp(
                theme: IcareTheme.lightTheme,
                home: const Scaffold(body: WithdrawalOperationsScreen()),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Withdrawal Operations Restricted'),
            findsOneWidget,
            reason: '$blockedRole must see access restriction screen',
          );
          expect(find.text('Individual Savings'), findsNothing);
        }
      },
    );

    testWidgets(
      'WithdrawalOperationsScreen serves Credit Officer in request-only mode',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final coUser = _buildUserForRole('Credit Officer');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._baseInfraOverrides(user: coUser),
              withdrawalBusinessDateProvider.overrideWith((_) async => DateTime(2026, 11, 25)),
              individualOptionsProvider.overrideWith(
                (_) async => const {
                  'groups': ['All Groups'],
                  'clients': [],
                  'all_groups': [],
                },
              ),
              dailyWithdrawalsProvider.overrideWith(
                (_) async => const {'records': [], 'summary': {}},
              ),
            ],
            child: MaterialApp(
              theme: IcareTheme.lightTheme,
              home: const Scaffold(
                body: SingleChildScrollView(child: WithdrawalOperationsScreen()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Individual Savings'), findsOneWidget);
        expect(find.text('Credit Officer Request Mode'), findsOneWidget);
        expect(find.textContaining('Pending Approvals'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'WithdrawalOperationsScreen serves Branch Manager with approval queue',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final bmUser = _buildUserForRole('Branch Manager');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._baseInfraOverrides(user: bmUser),
              withdrawalBusinessDateProvider.overrideWith((_) async => DateTime(2026, 11, 25)),
              individualOptionsProvider.overrideWith(
                (_) async => const {
                  'groups': ['All Groups'],
                  'clients': [],
                  'all_groups': [],
                },
              ),
              dailyWithdrawalsProvider.overrideWith(
                (_) async => const {'records': [], 'summary': {}},
              ),
              pendingApprovalsProvider.overrideWith(
                (_) async => const {'requests': []},
              ),
            ],
            child: MaterialApp(
              theme: IcareTheme.lightTheme,
              home: const Scaffold(
                body: SingleChildScrollView(child: WithdrawalOperationsScreen()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Branch Manager Mode'), findsOneWidget);
        expect(find.text('Pending Approvals (0)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
