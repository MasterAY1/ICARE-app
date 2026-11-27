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
import 'package:frontend_flutter/features/admin/data/datasources/admin_api_service.dart';
import 'package:frontend_flutter/features/admin/data/models/admin_dashboard_models.dart'
    as admin_models;
import 'package:frontend_flutter/features/admin/presentation/admin_branch_detail_sheet.dart';
import 'package:frontend_flutter/features/admin/presentation/admin_branch_reconciliation_sheet.dart';
import 'package:frontend_flutter/features/admin/presentation/admin_portfolio_screen.dart';
import 'package:frontend_flutter/features/am/data/datasources/am_api_service.dart';
import 'package:frontend_flutter/features/am/data/models/am_dashboard_models.dart';
import 'package:frontend_flutter/features/am/presentation/am_portfolio_screen.dart';
import 'package:frontend_flutter/features/am/presentation/branch_inspection_screen.dart';
import 'package:frontend_flutter/features/am/presentation/officer_productivity_sheet.dart';
import 'package:frontend_flutter/features/reports/data/datasources/reports_api_service.dart';
import 'package:frontend_flutter/features/reports/data/models/report_models.dart';

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

AmDashboardDataModel _buildMockAmData() {
  return AmDashboardDataModel(
    regionalSummary: RegionalSummaryModel(
      areaName: 'Area 2 North',
      businessDate: '2026-11-26',
      branchesCount: 2,
      openBranchesCount: 2,
      activeClients: 580,
      activeCredit: 32500000.0,
      outstandingPortfolio: 26400000.0,
      totalSavings: 11200000.0,
      todayExpected: 950000.0,
      todayCollected: 840000.0,
      compliancePct: 88.4,
      vaultCashAcct1000: 2150000.0,
      par: '2.4%',
      defaultersCount: 5,
      assignedBranches: const ['Ikeja Branch', 'Ogijo Branch'],
    ),
    branchPerformance: [
      BranchPerformanceItemModel(
        branchId: 'br-ikeja',
        branchName: 'Ikeja Branch',
        bmName: 'Adebayo T.',
        isClosed: false,
        closureReason: '',
        expectedCollection: 550000.0,
        collected: 500000.0,
        outstandingToday: 50000.0,
        compliancePct: 90.9,
        vaultCashAcct1000: 1350000.0,
        par: '1.8%',
        defaultersCount: 2,
        cashVariance: 0.0,
        eodStatus: 'PENDING',
        operationalStatus: 'Operational',
        reversalsCount: 0,
        loansDisbursedCount: 5,
        principalDisbursedAmount: 1000000.0,
        activeCreditDisbursedAmount: 1200000.0,
        fullPaymentsCount: 2,
        fullPaymentsActiveCredit: 300000.0,
        netLoanCount: 3,
        netActiveCreditVolume: 900000.0,
      ),
      BranchPerformanceItemModel(
        branchId: 'br-ogijo',
        branchName: 'Ogijo Branch',
        bmName: 'Ngozi K.',
        isClosed: false,
        closureReason: '',
        expectedCollection: 400000.0,
        collected: 340000.0,
        outstandingToday: 60000.0,
        compliancePct: 85.0,
        vaultCashAcct1000: 800000.0,
        par: '3.0%',
        defaultersCount: 3,
        cashVariance: 0.0,
        eodStatus: 'CLOSED',
        operationalStatus: 'Operational',
        reversalsCount: 1,
        loansDisbursedCount: 3,
        principalDisbursedAmount: 600000.0,
        activeCreditDisbursedAmount: 720000.0,
        fullPaymentsCount: 1,
        fullPaymentsActiveCredit: 180000.0,
        netLoanCount: 2,
        netActiveCreditVolume: 540000.0,
      ),
    ],
    approvalsHub: AreaApprovalsHubModel(
      pendingHighValueLoans: [],
      pendingBranchTransfers: [],
      pendingBranchEods: [],
      pendingBranchReversals: [],
      canLockArea: true,
    ),
  );
}

admin_models.InstitutionPerformanceModel _buildMockPortfolio(int year) {
  const scorecard = admin_models.ScorecardBreakdownModel(
    capitalDeploymentScore: 22.0,
    delinquencyControlScore: 23.0,
    overdueRecoveryScore: 14.0,
    borrowerOutreachScore: 13.0,
    repaymentComplianceScore: 9.0,
    vaultDisciplineScore: 9.0,
    compositeScore: 90.0,
  );

  return admin_models.InstitutionPerformanceModel(
    year: year,
    summary: const admin_models.PerformanceSummaryModel(
      totalDisbursedYtd: 48000000.0,
      totalDisbursedCount: 310,
      totalOverdueRecoveredYtd: 1950000.0,
      totalActiveBorrowers: 1120,
      totalActiveCredit: 38500000.0,
      totalNetSavings: 10800000.0,
      totalFullPayoffsCount: 29,
      totalFullPayoffsAmount: 4200000.0,
      totalOverdue: 920000.0,
      averagePar: 2.4,
    ),
    branchRankings: const [
      admin_models.BranchPerformanceItemModel(
        rank: 1,
        branchId: 'b-1',
        branchName: 'Ikeja Branch',
        branchCode: 'IKJ',
        bmName: 'Adebayo T.',
        disbPrincipal: 25000000.0,
        disbCount: 160,
        activeMembers: 620,
        activeCreditBook: 19500000.0,
        parPct: 1.9,
        overdueAmount: 370500.0,
        defaultersCount: 3,
        overdueRecovered: 1100000.0,
        recoveriesCount: 15,
        fullRecoveriesCount: 6,
        recoveryRatePct: 92.5,
        collectedAmount: 18400000.0,
        compliancePct: 96.8,
        vaultCash: 1350000.0,
        netSavingsBalance: 6200000.0,
        fullPayoffsCount: 16,
        fullPayoffsAmount: 2400000.0,
        topOfficerName: 'Ada Obi',
        compositeScore: 90.0,
        scorecard: scorecard,
      ),
      admin_models.BranchPerformanceItemModel(
        rank: 2,
        branchId: 'b-2',
        branchName: 'Ogijo Branch',
        branchCode: 'OGI',
        bmName: 'Ngozi K.',
        disbPrincipal: 23000000.0,
        disbCount: 150,
        activeMembers: 500,
        activeCreditBook: 19000000.0,
        parPct: 2.9,
        overdueAmount: 551000.0,
        defaultersCount: 5,
        overdueRecovered: 850000.0,
        recoveriesCount: 12,
        fullRecoveriesCount: 4,
        recoveryRatePct: 87.5,
        collectedAmount: 16200000.0,
        compliancePct: 91.5,
        vaultCash: 800000.0,
        netSavingsBalance: 4600000.0,
        fullPayoffsCount: 13,
        fullPayoffsAmount: 1800000.0,
        topOfficerName: 'Tunde B.',
        compositeScore: 84.0,
        scorecard: scorecard,
      ),
    ],
    officerRankings: const [
      admin_models.OfficerPerformanceItemModel(
        rank: 1,
        officerId: 'off-1',
        officerName: 'Ada Obi',
        officerUsername: 'co_ada',
        branchId: 'b-1',
        branchName: 'Ikeja Branch',
        activeClients: 140,
        activeCredit: 4800000.0,
        disbPrincipal: 6200000.0,
        disbCount: 42,
        overdueAmount: 45000.0,
        parPct: 0.9,
        defaultersCount: 1,
        overdueRecovered: 210000.0,
        fullRecoveriesCount: 2,
        collectedAmount: 5400000.0,
        compliancePct: 98.1,
        compositeScore: 95.0,
      ),
    ],
  );
}

class _FakeAmApiService extends AmApiService {
  final bool shouldFail;

  _FakeAmApiService(super.client, {this.shouldFail = false});

  @override
  Future<AmDashboardDataModel> getAmDashboardData({
    String? businessDate,
    String? startDate,
    String? endDate,
  }) async {
    if (shouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/am/dashboard'),
        type: DioExceptionType.connectionTimeout,
        message: 'Timeout',
      );
    }
    return _buildMockAmData();
  }

  @override
  Future<Map<String, dynamic>> getBranchInspection({
    required String branchId,
    String? businessDate,
  }) async {
    if (shouldFail) {
      throw Exception('Branch inspection unavailable');
    }
    return {
      'branch_summary': {
        'active_clients': 320,
        'active_loans': 260,
        'par': '1.8%',
      },
      'branch_cash_position': {
        'closing_balance': 1350000.0,
        'status': 'Balanced',
      },
      'officer_collection_status': [
        {
          'Officer Name': 'Ada Obi',
          'Officer': 'co_ada',
          'Expected': 280000.0,
          'Collected': 260000.0,
          'Compliance %': 92.9,
          'Status': 'Balanced',
        },
        {
          'Officer Name': 'Tunde Bello',
          'Officer': 'co_tunde',
          'Expected': 270000.0,
          'Collected': 240000.0,
          'Compliance %': 88.9,
          'Status': 'Pending',
        },
      ],
    };
  }

  @override
  Future<BranchOfficerProductivityResponseModel> getBranchOfficerProductivity({
    required String branchId,
    String? startDate,
    String? endDate,
  }) async {
    if (shouldFail) {
      throw Exception('Officer metrics failed');
    }
    return BranchOfficerProductivityResponseModel(
      branchId: branchId,
      branchName: 'Ikeja Branch',
      startDate: startDate ?? '2026-11-01',
      endDate: endDate ?? '2026-11-26',
      officers: [
        OfficerProductivityItemModel(
          officerId: 'off-1',
          username: 'co_ada',
          fullName: 'Ada Obi',
          activeClientsCount: 165,
          activePortfolio: 11200000.0,
          loansDisbursedCount: 4,
          principalDisbursedAmount: 750000.0,
          activeCreditDisbursedAmount: 900000.0,
          fullPaymentsCount: 2,
          fullPaymentsActiveCredit: 300000.0,
          netLoanCount: 2,
          netActiveCreditVolume: 600000.0,
          compliancePct: 95.5,
          parPct: '1.2%',
        ),
      ],
    );
  }
}

class _FakeReportsApiService extends ReportsApiService {
  final bool shouldFail;
  _FakeReportsApiService(super.client, {this.shouldFail = false});

  @override
  Future<ReportsMeta> getReportsMeta() async {
    if (shouldFail) {
      throw Exception('Metadata failed');
    }
    return const ReportsMeta(
      branches: [
        BranchOption(branchId: 'b-1', name: 'Ikeja Branch'),
        BranchOption(branchId: 'b-2', name: 'Ogijo Branch'),
      ],
      products: ['12-Week Cash'],
      officers: [],
      defaultBranch: 'Ikeja Branch',
      scopeLevel: 'INSTITUTION',
    );
  }

  @override
  Future<MonthlyReconciliationData> getMonthlyReconciliation({
    String? branchName,
    int? year,
    int? month,
  }) async {
    if (shouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/reports/monthly-reconciliation'),
        type: DioExceptionType.badResponse,
        message: 'Server 500 error',
      );
    }
    return MonthlyReconciliationData.fromJson({
      'cash_in_hand_bf': 350000.0,
      'overdue_bf': 120000.0,
      'overdue_cf': 95000.0,
      'disbursed_principal': 2400000.0,
      'collections': 2100000.0,
      'savings_deposits': 640000.0,
      'banks': [
        {
          'bank_name': 'Zenith Bank',
          'account_number': '1012345678',
          'opening_balance': 850000.0,
          'bank_charges': 2500.0,
          'bank_interest': 0.0,
          'closing_balance': 1450000.0,
        },
      ],
    });
  }
}

List<Override> _buildOverrides({bool shouldFail = false}) {
  SharedPreferences.setMockInitialValues({});
  final offlineDb = OfflineDatabaseService(
    useMemoryStore: true,
    userId: 'admin_1',
    branchId: 'br-ikeja',
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
    assignedBranches: const ['Ikeja Branch', 'Ogijo Branch'],
    assignedBranchIds: const ['br-ikeja', 'br-ogijo'],
  );

  return [
    connectivityServiceProvider.overrideWithValue(conn),
    offlineDatabaseServiceProvider.overrideWithValue(offlineDb),
    apiClientProvider.overrideWithValue(apiClient),
    authControllerProvider.overrideWith(
      (ref) => _StaticAuthController(adminUser, apiClient, offlineDb),
    ),
    amApiServiceProvider.overrideWithValue(
      _FakeAmApiService(apiClient, shouldFail: shouldFail),
    ),
    reportsApiServiceProvider.overrideWithValue(
      _FakeReportsApiService(apiClient, shouldFail: shouldFail),
    ),
    institutionPerformanceProvider.overrideWith((ref, year) async {
      if (shouldFail) {
        throw Exception('Portfolio fetch timeout');
      }
      return _buildMockPortfolio(year);
    }),
    adminBranchDetailProvider.overrideWith((ref, branchId) async {
      if (shouldFail) {
        throw Exception('Branch detail fetch error');
      }
      return const admin_models.AdminBranchDetailModel(
        branchId: 'b-1',
        branchName: 'Ikeja Branch',
        managerName: 'Adebayo T.',
        operationalStatus: 'Operational',
        vaultCashInCustody: 1350000.0,
        activeCreditBook: 19500000.0,
        activeBorrowersCount: 620,
        todayCollections: 500000.0,
        overdueAmount: 370500.0,
        parPct: 1.9,
        defaultersCount: 3,
        overdueRecovered: 1100000.0,
        fullRecoveriesCount: 6,
        totalDisbursedYtd: 25000000.0,
        totalDisbursedCount: 160,
        officersCount: 1,
        officers: [
          admin_models.BranchOfficerSummaryModel(
            officerId: 'off-1',
            name: 'Ada Obi',
            username: 'co_ada',
          ),
        ],
      );
    }),
  ];
}

void _assertNoGovernanceLeaks(WidgetTester tester) {
  final emojiRegex = RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true);
  final internalCodeRegex = RegExp(r'\b(BR-[A-Z0-9-]+|FP-[0-9]+|Account 1000)\b');

  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final text = w.data ?? '';
    if (text.isEmpty) continue;
    expect(emojiRegex.hasMatch(text), isFalse, reason: 'Emoji found: $text');
    expect(internalCodeRegex.hasMatch(text), isFalse, reason: 'Internal rule leaked: $text');
    expect(text.contains('DioException'), isFalse, reason: 'Raw exception leaked: $text');
  }
}

void main() {
  group('Phase 4 AM Sub-Pages & Admin Portfolio Suite', () {
    for (final width in <double>[360, 1280]) {
      testWidgets(
        'AmPortfolioScreen renders area name, live allocation charts, and zero FlowCards at ${width.toInt()}px',
        (tester) async {
          tester.view.physicalSize = Size(width, 920);
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
                  body: SingleChildScrollView(child: AmPortfolioScreen()),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          await tester.pump(const Duration(milliseconds: 350));

          final err = tester.takeException();
          expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : '$err');
          expect(find.textContaining('AREA 2 NORTH'), findsAtLeastNWidgets(1));
          expect(find.text('AREA 1'), findsNothing);
          expect(find.byType(PieChart), findsAtLeastNWidgets(1));
          expect(find.byType(BarChart), findsAtLeastNWidgets(1));
          expect(find.byType(IcareMetricCard), findsAtLeastNWidgets(1));
          expect(find.byType(IcareStatusBadge), findsAtLeastNWidgets(1));

          _assertNoGovernanceLeaks(tester);
        },
      );
    }

    testWidgets(
      'BranchInspectionScreen and OfficerProductivityModalSheet render charts cleanly on mobile & error state',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _buildOverrides(),
            child: MaterialApp(
              theme: IcareTheme.lightTheme,
              home: const BranchInspectionScreen(
                branchId: 'br-ikeja',
                branchName: 'Ikeja Branch',
                businessDate: '2026-11-26',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(BarChart), findsAtLeastNWidgets(1));
        expect(find.byType(IcareCard), findsAtLeastNWidgets(1));
        _assertNoGovernanceLeaks(tester);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _buildOverrides(),
            child: MaterialApp(
              theme: IcareTheme.darkTheme,
              home: const Scaffold(
                body: OfficerProductivityModalSheet(
                  branchId: 'br-ikeja',
                  branchName: 'Ikeja Branch',
                  period: 'This Month',
                  dates: ('2026-11-01', '2026-11-26'),
                  isDialog: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Ada Obi'), findsAtLeastNWidgets(1));
        _assertNoGovernanceLeaks(tester);
      },
    );

    for (final width in <double>[360, 1280]) {
      testWidgets(
        'AdminPortfolioScreen renders charts, IcareDataTable, and league KPIs cleanly at ${width.toInt()}px',
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
                  body: SingleChildScrollView(child: AdminPortfolioScreen()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final err = tester.takeException();
          expect(err, isNull, reason: err is FlutterError ? err.toStringDeep() : '$err');
          expect(find.byType(BarChart), findsAtLeastNWidgets(1));
          expect(find.byType(PieChart), findsAtLeastNWidgets(1));
          expect(find.byType(IcareMetricCard), findsAtLeastNWidgets(1));
          expect(find.byType(IcareDataTable), findsAtLeastNWidgets(1));
          _assertNoGovernanceLeaks(tester);
        },
      );
    }

    testWidgets(
      'AdminBranchDetailSheet and AdminBranchReconciliationSheet render live data and clean error Retry cards',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _buildOverrides(),
            child: MaterialApp(
              theme: IcareTheme.lightTheme,
              home: const Scaffold(
                body: AdminBranchDetailSheet(
                  branchId: 'b-1',
                  initialBranchName: 'Ikeja Branch',
                  isDialog: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Ikeja Branch'), findsAtLeastNWidgets(1));
        expect(find.byType(IcareStatusBadge), findsAtLeastNWidgets(1));

        await tester.pumpWidget(
          ProviderScope(
            overrides: _buildOverrides(shouldFail: true),
            child: MaterialApp(
              theme: IcareTheme.lightTheme,
              home: const Scaffold(
                body: AdminBranchReconciliationSheet(
                  initialBranchName: 'Ikeja Branch',
                  initialYear: 2026,
                  initialMonth: 11,
                  isDialog: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Retry'), findsAtLeastNWidgets(1));
        _assertNoGovernanceLeaks(tester);
      },
    );
  });
}
