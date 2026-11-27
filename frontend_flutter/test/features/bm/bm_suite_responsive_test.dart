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
import 'package:frontend_flutter/core/widgets/icare_data_table.dart';
import 'package:frontend_flutter/core/widgets/icare_metric_card.dart';
import 'package:frontend_flutter/core/widgets/icare_status_badge.dart';
import 'package:frontend_flutter/features/bm/data/datasources/bm_api_service.dart';
import 'package:frontend_flutter/features/bm/data/datasources/master_cashbook_api_service.dart';
import 'package:frontend_flutter/features/bm/data/models/bm_dashboard_models.dart';
import 'package:frontend_flutter/features/bm/data/models/master_cashbook_models.dart';
import 'package:frontend_flutter/features/bm/presentation/bm_dashboard_screen.dart';
import 'package:frontend_flutter/features/bm/presentation/master_cashbook_screen.dart';

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

BmDashboardDataModel _buildLiveBmDashboardData() {
  return BmDashboardDataModel(
    branchName: 'Ikeja Branch',
    businessDate: '2026-11-26',
    meetingDay: 'Thursday',
    isClosed: false,
    closureReason: '',
    branchSummary: BranchSummaryModel(
      activeClients: 185,
      activeLoans: 142,
      activeSavings: 4850000.0,
      collectionToday: 425000.0,
      par: '2.1%',
    ),
    branchCashPosition: BranchCashPositionModel(
      openingBalance: 320000.0,
      cashIn: 480000.0,
      cashOut: 190000.0,
      bankDeposit: 150000.0,
      bankWithdrawal: 0.0,
      closingBalance: 460000.0,
      status: 'Balanced',
      difference: 0.0,
    ),
    officerCollectionStatus: [
      OfficerCollectionStatusModel(
        officer: 'co_ada',
        officerName: 'Ada Obi',
        groupsScheduled: 4,
        scheduledGroups: 'Unity, Favour',
        expected: 250000.0,
        collected: 230000.0,
        outstanding: 20000.0,
        compliancePct: 92.0,
        closingBalance: 140000.0,
        status: 'Balanced',
      ),
      OfficerCollectionStatusModel(
        officer: 'co_tunde',
        officerName: 'Tunde Bello',
        groupsScheduled: 3,
        scheduledGroups: 'Success',
        expected: 210000.0,
        collected: 195000.0,
        outstanding: 15000.0,
        compliancePct: 92.9,
        closingBalance: 120000.0,
        status: 'Pending',
      ),
    ],
    pendingLoans: [
      PendingLoanApprovalModel(
        loanId: 'ln-1',
        clientName: 'Chinedu Okafor',
        clientCode: 'IKJ-01-004',
        officer: 'Ada Obi',
        loanProduct: '12-Week Cash',
        loanAmount: 150000.0,
        disbursementDate: '2026-11-26',
      ),
    ],
    pendingWithdrawals: [
      PendingWithdrawalApprovalModel(
        id: 'wd-1',
        clientName: 'Bisi Adebayo',
        groupName: 'Unity Group',
        savingsType: 'Individual',
        operationType: 'Cash Withdrawal',
        amount: 25000.0,
        requestedBy: 'Ada Obi',
        operationalDate: '2026-11-26',
      ),
    ],
    pendingCorrections: [
      PendingCorrectionApprovalModel(
        id: 'cor-1',
        recordId: 'rep-90',
        recordType: 'Repayment',
        reason: 'Duplicate receipt',
        requestedBy: 'Tunde Bello',
        amount: 12000.0,
        clientName: 'Kemi Ade',
        clientCode: 'IKJ-02-001',
      ),
    ],
  );
}

MasterCashbookDailyData _buildLiveDailyCashbook() {
  return const MasterCashbookDailyData(
    date: '2026-11-26',
    branch: 'Ikeja Branch',
    isOpen: true,
    openReason: 'Working Day',
    inflows: MasterCashbookInflowsData(
      openingBalance: 320000.0,
      savingsDeposit: 85000.0,
      rep12Weeks: 290000.0,
      repDaily: 95000.0,
      appFee: 10000.0,
    ),
    outflows: MasterCashbookOutflowsData(
      disb12w: 150000.0,
      savingsWithdrawal: 25000.0,
      officeExpenses: 15000.0,
      bankDeposit: 150000.0,
    ),
    totalInflows: 800000.0,
    totalOutflows: 340000.0,
    closingBalance: 460000.0,
    tally: MasterReconciliationTallyData(
      scheduledExpected: 460000.0,
      notPaidAmount: 35000.0,
      notPaidCount: 2,
      notPaidClients: [
        MasterNotPaidClientData(
          name: 'Folake Sanni',
          code: 'IKJ-01-011',
          expected: 20000.0,
          shortfall: 20000.0,
          isPartial: false,
        ),
      ],
      excessAmount: 5000.0,
      excessCount: 1,
      actualRepayments: 385000.0,
      actualSavings: 85000.0,
      actualCashCollected: 470000.0,
      bankDeposited: 150000.0,
      closingCashBalance: 460000.0,
      isCashBalanced: true,
      arrearsFloat: 0.0,
      totalRepsCount: 28,
    ),
    pendingReversals: [
      MasterPendingReversalData(
        id: 'rev-1',
        recordId: 'rep-90',
        recordType: 'Repayment',
        reason: 'Incorrect amount posted',
        requestedBy: 'co_ada',
        requestedByName: 'Ada Obi',
        amount: 12000.0,
        clientName: 'Kemi Ade',
        clientCode: 'IKJ-02-001',
        createdAt: '2026-11-26 09:15',
        status: 'Pending',
      ),
    ],
    treasuryTransactions: [
      MasterTreasuryTransactionData(
        id: 'tr-1',
        transactionType: 'BANK_DEPOSIT',
        amount: 150000.0,
        postingDate: '2026-11-26',
        remarks: 'Zenith Bank sweep',
        label: 'Bank Deposit',
      ),
    ],
  );
}

CoAggregationData _buildLiveCoAggregation() {
  return const CoAggregationData(
    date: '2026-11-26',
    branch: 'Ikeja Branch',
    officer: 'co_ada',
    officers: [
      OfficerOptionData(
        username: 'co_ada',
        fullName: 'Ada Obi',
        display: 'Ada Obi (co_ada)',
      ),
    ],
    openingBalance: 0.0,
    inflows: {'12-Week Repayment': 195000.0, 'Member Savings': 55000.0},
    outflows: {'Loan Disbursement': 100000.0},
    totalInflows: 250000.0,
    totalOutflows: 100000.0,
    closingBalance: 150000.0,
    isOpen: true,
    openReason: 'Working Day',
    canCloseDay: true,
  );
}

MonthlyLedgerData _buildLiveMonthlyLedger() {
  return const MonthlyLedgerData(
    month: 11,
    year: 2026,
    branch: 'Ikeja Branch',
    monthOpening: 250000.0,
    totalMonthInflows: 4250000.0,
    totalMonthOutflows: 3120000.0,
    monthClosing: 1380000.0,
    availableBranches: ['Ikeja Branch', 'Ogijo Branch'],
    rows: [
      MonthlyLedgerRowData(
        date: '2026-11-25',
        openingBalance: 250000.0,
        rep12Weeks: 410000.0,
        savingsDeposit: 95000.0,
        totalInflows: 505000.0,
        disb12w: 200000.0,
        bankDeposit: 120000.0,
        totalOutflows: 320000.0,
        closingBalance: 435000.0,
      ),
      MonthlyLedgerRowData(
        date: '2026-11-26',
        openingBalance: 435000.0,
        rep12Weeks: 290000.0,
        savingsDeposit: 85000.0,
        totalInflows: 375000.0,
        disb12w: 150000.0,
        bankDeposit: 150000.0,
        totalOutflows: 300000.0,
        closingBalance: 510000.0,
      ),
    ],
  );
}

class _FakeBmApiService extends BmApiService {
  final bool shouldFail;

  _FakeBmApiService(super.apiClient, {this.shouldFail = false});

  @override
  Future<BmDashboardDataModel> getBmDashboardData({String? date}) async {
    if (shouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/bm/dashboard'),
        type: DioExceptionType.connectionTimeout,
        message: 'SocketException timeout',
      );
    }
    return _buildLiveBmDashboardData();
  }

  @override
  Future<List<dynamic>> getPendingClientUpdates({String? branchId}) async => [];
}

class _FakeMasterCashbookApiService extends MasterCashbookApiService {
  final bool shouldFail;

  _FakeMasterCashbookApiService(super.apiClient, {this.shouldFail = false});

  @override
  Future<MasterCashbookDailyData> getMasterCashbookDaily({
    String? date,
    String? branch,
  }) async {
    if (shouldFail) {
      throw Exception('Cashbook ledger offline');
    }
    return _buildLiveDailyCashbook();
  }

  @override
  Future<CoAggregationData> getCoAggregation({
    String? date,
    String? officer,
    String? branch,
  }) async =>
      _buildLiveCoAggregation();

  @override
  Future<MonthlyLedgerData> getMonthlyLedger({
    required int month,
    required int year,
    String? branch,
  }) async =>
      _buildLiveMonthlyLedger();
}

List<Override> _buildBmOverrides({bool failDashboard = false, bool failCashbook = false}) {
  SharedPreferences.setMockInitialValues({});
  final offlineDb = OfflineDatabaseService(
    useMemoryStore: true,
    userId: 'bm_ikeja',
    branchId: 'br-ikeja',
  );
  final conn = _QuietConn();
  final apiClient = ApiClient(
    baseUrl: 'http://localhost',
    connectivityService: conn,
    offlineDb: offlineDb,
    adapter: _NoopHttpAdapter(),
  );
  final bmUser = AuthUser(
    id: 'bm-1',
    username: 'bm_ikeja',
    fullName: 'Adebayo T.',
    role: 'Branch Manager',
    branch: 'Ikeja Branch',
    branchId: 'br-ikeja',
  );

  return [
    connectivityServiceProvider.overrideWithValue(conn),
    offlineDatabaseServiceProvider.overrideWithValue(offlineDb),
    apiClientProvider.overrideWithValue(apiClient),
    authControllerProvider.overrideWith(
      (ref) => _StaticAuthController(bmUser, apiClient, offlineDb),
    ),
    bmApiServiceProvider.overrideWithValue(
      _FakeBmApiService(apiClient, shouldFail: failDashboard),
    ),
    bmDashboardDataProvider.overrideWith((ref) async {
      if (failDashboard) {
        throw DioException(
          requestOptions: RequestOptions(path: '/api/v1/bm/dashboard'),
          type: DioExceptionType.connectionError,
          message: 'Failed to reach server',
        );
      }
      return _buildLiveBmDashboardData();
    }),
    masterCashbookApiServiceProvider.overrideWithValue(
      _FakeMasterCashbookApiService(apiClient, shouldFail: failCashbook),
    ),
  ];
}

void _assertCleanUiGovernance(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text));
  final emojiRegex = RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true);
  final internalCodeRegex = RegExp(r'\b(BR-[A-Z0-9-]+|FP-[0-9]+|Account 1000)\b');

  for (final widget in texts) {
    final text = widget.data ?? '';
    if (text.isEmpty) continue;
    expect(emojiRegex.hasMatch(text), isFalse, reason: 'Emoji found: $text');
    expect(internalCodeRegex.hasMatch(text), isFalse, reason: 'Internal ID leaked: $text');
    expect(text.contains('DioException'), isFalse, reason: 'Raw exception leaked: $text');
    expect(text.contains('atomically'), isFalse, reason: 'Technical jargon leaked: $text');
  }
}

void main() {
  group('Phase 4 BM Dashboard & Master Cashbook Responsive Suite', () {
    for (final width in <double>[360, 800, 1280]) {
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        testWidgets(
          'BmDashboardScreen renders KPIs, live analytics charts, and zero FlowCards at ${width.toInt()}px (${mode.name})',
          (tester) async {
            tester.view.physicalSize = Size(width, 920);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              ProviderScope(
                overrides: _buildBmOverrides(),
                child: MaterialApp(
                  theme: IcareTheme.lightTheme,
                  darkTheme: IcareTheme.darkTheme,
                  themeMode: mode,
                  home: const Scaffold(
                    body: SingleChildScrollView(child: BmDashboardScreen()),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.byType(IcareCard), findsAtLeastNWidgets(1));

            if (width < 768) {
              await tester.tap(find.text('KPI & Vault'));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }

            expect(find.byType(IcareMetricCard), findsAtLeastNWidgets(1));
            expect(find.byType(BarChart), findsAtLeastNWidgets(1));
            expect(find.byType(PieChart), findsAtLeastNWidgets(1));

            if (width < 768) {
              await tester.tap(find.text('Officers'));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            } else {
              expect(find.byType(IcareDataTable), findsAtLeastNWidgets(1));
            }

            expect(find.byType(IcareStatusBadge), findsAtLeastNWidgets(1));
            expect(find.textContaining('Pipeline Flow'), findsNothing);

            _assertCleanUiGovernance(tester);
          },
        );
      }
    }

    testWidgets(
      'BmDashboardScreen error state renders AppErrorDetails Retry card without raw exceptions',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _buildBmOverrides(failDashboard: true),
            child: MaterialApp(
              theme: IcareTheme.lightTheme,
              home: const Scaffold(
                body: SingleChildScrollView(child: BmDashboardScreen()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(IcareCard), findsAtLeastNWidgets(1));
        expect(find.textContaining('Retry'), findsAtLeastNWidgets(1));
        _assertCleanUiGovernance(tester);
      },
    );

    for (final width in <double>[360, 1280]) {
      testWidgets(
        'MasterCashbookScreen renders Daily, CO Aggregation, and Monthly Matrix tabs cleanly at ${width.toInt()}px',
        (tester) async {
          tester.view.physicalSize = Size(width, 920);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            ProviderScope(
              overrides: _buildBmOverrides(),
              child: MaterialApp(
                theme: IcareTheme.lightTheme,
                darkTheme: IcareTheme.darkTheme,
                themeMode: width == 360 ? ThemeMode.dark : ThemeMode.light,
                home: const Scaffold(
                  body: SingleChildScrollView(child: MasterCashbookScreen()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(BarChart), findsAtLeastNWidgets(1));
          expect(find.byType(PieChart), findsAtLeastNWidgets(1));

          // Switch to Tab 2 (CO Cashbooks)
          final coTab = find.text('CO Cashbooks Aggregation');
          expect(coTab, findsOneWidget);
          await tester.ensureVisible(coTab);
          await tester.tap(coTab);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.textContaining('Ada Obi'), findsAtLeastNWidgets(1));
          expect(find.textContaining('12-Week Repayment'), findsAtLeastNWidgets(1));

          // Switch to Tab 3 (Monthly Matrix)
          final monthlyTab = find.text('Monthly Ledger');
          expect(monthlyTab, findsOneWidget);
          await tester.ensureVisible(monthlyTab);
          await tester.tap(monthlyTab);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(BarChart), findsAtLeastNWidgets(1));
          if (width >= 680) {
            expect(find.byType(IcareDataTable), findsAtLeastNWidgets(1));
          } else {
            expect(find.textContaining('Monthly Ledger Parameters'), findsOneWidget);
          }

          _assertCleanUiGovernance(tester);
        },
      );
    }

    testWidgets(
      'MasterCashbookScreen renders clean error recovery card when daily cashbook fails',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _buildBmOverrides(failCashbook: true),
            child: MaterialApp(
              theme: IcareTheme.lightTheme,
              home: const Scaffold(
                body: SingleChildScrollView(child: MasterCashbookScreen()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Retry'), findsAtLeastNWidgets(1));
        _assertCleanUiGovernance(tester);
      },
    );
  });
}
