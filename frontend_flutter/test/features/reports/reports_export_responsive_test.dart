import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/core/auth/auth_controller.dart';
import 'package:frontend_flutter/core/auth/auth_state.dart';
import 'package:frontend_flutter/core/network/api_client.dart';
import 'package:frontend_flutter/features/reports/data/datasources/reports_api_service.dart';
import 'package:frontend_flutter/features/reports/data/models/report_models.dart';
import 'package:frontend_flutter/features/reports/presentation/reports_export_screen.dart';
import 'package:frontend_flutter/features/reports/presentation/widgets/report_export_actions.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(AuthUser user) : super(ApiClient()) {
    state = AuthStateAuthenticated(user: user, token: 'test-jwt-token');
  }
}

class _FakeReportsApiService extends ReportsApiService {
  int metaCalls = 0;
  int parityCalls = 0;
  int officialStatementsCalls = 0;
  int areaComparisonCalls = 0;
  String? lastExcelBranchName;
  String? lastCsvBranchName;
  String workflowStatus;
  final String? amQueryNotes;
  final List<MonthlyWorkflowPendingBranchModel>? adminSignedOverride;
  final List<MonthlyWorkflowPendingBranchModel>? amPendingOverride;

  _FakeReportsApiService({
    this.workflowStatus = 'DRAFT',
    this.amQueryNotes,
    this.adminSignedOverride,
    this.amPendingOverride,
  }) : super(ApiClient());

  @override
  Future<ReportsMeta> getReportsMeta() async {
    metaCalls++;
    return const ReportsMeta(
      branches: [
        BranchOption(branchId: 'b-1', name: 'Ikeja Branch'),
        BranchOption(branchId: 'b-2', name: 'Surulere Branch'),
      ],
      products: ['Monthly Loan', 'Weekly Loan', 'Daily Loan'],
      officers: [
        OfficerOption(
          userId: 'u-1',
          username: 'co_ikeja',
          fullName: 'Chinedu Okafor',
          branchId: 'b-1',
          branchName: 'Ikeja Branch',
        ),
      ],
      defaultBranch: 'Ikeja Branch',
      scopeLevel: 'INSTITUTION',
    );
  }

  @override
  Future<MonthlyParityData> getMonthlyParity({
    String? branchName,
    int? year,
    int? month,
    String? officerName,
    String? productName,
  }) async {
    parityCalls++;
    return const MonthlyParityData(
      year: 2026,
      month: 9,
      monthLabel: 'September 2026',
      branchId: 'b-1',
      branchName: 'Ikeja Branch',
      totalColName: 'Branch Total',
      officers: [
        MonthlyParityOfficer(
          officerId: 'u-1',
          name: 'Chinedu Okafor',
          username: 'co_ikeja',
          fullName: 'Chinedu Okafor',
        ),
      ],
      rows: [
        MonthlyParityMetricRow(
          metric: 'Active Loans Count',
          values: {'u-1': 45, 'Branch Total': 45},
        ),
        MonthlyParityMetricRow(
          metric: 'Collections Received',
          values: {'u-1': 1250000.0, 'Branch Total': 1250000.0},
        ),
      ],
      summaryCards: MonthlyParitySummaryCards(
        disbursedPrincipal: 2500000.0,
        upfrontFees: 125000.0,
        netActiveCredit: 2875000.0,
        openingCredit: 5000000.0,
        collections: 1250000.0,
        closingCredit: 6625000.0,
        openingSavings: 1100000.0,
        savingsDeposits: 350000.0,
        savingsWithdrawals: 50000.0,
        closingSavings: 1400000.0,
        bankDeposits: 900000.0,
        officeExpenses: 45000.0,
        activeLoans: 45,
        activeSavers: 60,
        glDebits: 8500000.0,
        glCredits: 8500000.0,
        glDiff: 0.0,
        isGlBalanced: true,
      ),
    );
  }

  @override
  Future<MonthlyExecutiveStatementsData> getOfficialStatements({
    String? branchName,
    int? year,
    int? month,
    String? officerName,
    String? productName,
  }) async {
    officialStatementsCalls++;
    return const MonthlyExecutiveStatementsData(
      branchName: 'Ikeja Branch',
      areaName: 'Area 1',
      monthLabel: 'September 2026',
      year: 2026,
      month: 9,
      trialBalance: OfficialTrialBalanceData(
        rows: [
          OfficialTrialBalanceRow(
            section: 'Cash & Bank Balances',
            item: 'Cash at Hand (Account 1000)',
            debit: 450000.0,
            credit: 0.0,
          ),
          OfficialTrialBalanceRow(
            section: 'Portfolio & Client Balances',
            item: 'Loan Receivable',
            debit: 6625000.0,
            credit: 0.0,
          ),
        ],
        totalDebits: 7075000.0,
        totalCredits: 7075000.0,
        variance: 0.0,
        isBalanced: true,
      ),
      receiptsAndPayments: ReceiptsPaymentsData(
        receipts: [
          ReceiptsPaymentsItem(item: 'Loan Collection', amount: 1250000.0),
        ],
        payments: [
          ReceiptsPaymentsItem(item: 'Loan Disbursement', amount: 2500000.0),
        ],
        totalReceipts: 1250000.0,
        totalPayments: 1250000.0,
        variance: 0.0,
      ),
      depositStatement: DepositStatementData(
        rows: [
          DepositStatementRow(
            programme: 'Monthly Loan',
            memberPrev: 20,
            memberCurr: 5,
            memberTotal: 25,
            depositPrev: 500000.0,
            depositCurr: 150000.0,
            depositTotal: 650000.0,
            withdrawalPrevNo: 2,
            withdrawalPrevAmount: 20000.0,
            withdrawalCurrNo: 1,
            withdrawalCurrAmount: 10000.0,
            withdrawalTotalNo: 3,
            withdrawalTotalAmount: 30000.0,
            returnPrevNo: 0,
            returnPrevAmount: 0.0,
            returnCurrNo: 0,
            returnCurrAmount: 0.0,
            returnTotalNo: 0,
            returnTotalAmount: 0.0,
            balanceNo: 25,
            balanceAmount: 620000.0,
          ),
        ],
      ),
      creditStatement: CreditStatementData(
        rows: [
          CreditStatementRow(
            section: '1. Total Borrower',
            item: 'Opening Balance',
            monthly: 20,
            weekly: 15,
            daily: 10,
            total: 45,
          ),
        ],
      ),
    );
  }

  @override
  Future<MonthlyReconciliationData> getMonthlyReconciliation({
    String? branchName,
    int? year,
    int? month,
  }) async {
    return const MonthlyReconciliationData(
      banks: [
        BankStatementItem(
          bankName: 'First Bank',
          accountNumber: '2034567890',
          openingBalance: 1000000.0,
          bankCharges: 2500.0,
          bankInterest: 0.0,
          closingBalance: 1897500.0,
        ),
      ],
      cashInHandBf: 320000.0,
      overdueBf: 85000.0,
      overdueCf: 70000.0,
      salesProfitMarkup: 375000.0,
      salesCashAndCarry: 0.0,
      fundCashHoAssetReceipt: 0.0,
      fundCashHoMainReceipt: 0.0,
      fundCashOtherAreaReceipt: 0.0,
      fundCashBranchReceipt: 0.0,
      fundCashHoAssetPayment: 0.0,
      fundCashHoMainPayment: 0.0,
      fundCashBranchPayment: 0.0,
      depositWithdrawal: 50000.0,
      lapseDepositReturn: 0.0,
      paidToOtherSources: 0.0,
      receivedFromOtherSources: 0.0,
      retainedEarnings: 0.0,
      headOfficeAssetAllocation: 0.0,
    );
  }

  @override
  Future<Annex1ReportData> getAnnex1Report({
    String? branchName,
    int? year,
    int? month,
  }) async {
    return const Annex1ReportData(
      branchName: 'Ikeja Branch',
      year: 2026,
      month: 9,
      monthLabel: 'September 2026',
      sundryReceipts: [
        Annex1LineItem(code: 'PC1', name: 'Passbook Fee', amount: 15000.0),
      ],
      totalSundryReceipts: 15000.0,
      sundryPaymentsGroups: [
        Annex1CategoryGroup(
          categoryCode: 'PB',
          categoryName: 'Administrative Expenses',
          subtotal: 25000.0,
          items: [
            Annex1LineItem(
                code: 'PB3', name: 'Office Stationery', amount: 25000.0),
          ],
        ),
      ],
      totalSundryPayments: 25000.0,
    );
  }

  @override
  Future<MonthlyWorkflowStatusModel> getMonthlyWorkflowStatus({
    String? branchName,
    int? year,
    int? month,
  }) async {
    return MonthlyWorkflowStatusModel(
      id: 'wf-1',
      branchId: 'b-1',
      areaName: 'Area 1',
      year: 2026,
      month: 9,
      status: workflowStatus,
      disbursedPrincipal: 2500000.0,
      upfrontFees: 125000.0,
      netActiveCredit: 2875000.0,
      collections: 1250000.0,
      closingCredit: 6625000.0,
      closingSavings: 1400000.0,
      vaultCashAcct1000: 450000.0,
      bankDepositsAcct1050: 900000.0,
      isGlBalanced: true,
      glVariance: 0.0,
      bmName: 'Adebayo T.',
      amQueryNotes: amQueryNotes,
    );
  }

  @override
  Future<List<MonthlyWorkflowPendingBranchModel>>
      getPendingAmMonthlySubmissions({
    int? year,
    int? month,
  }) async {
    if (amPendingOverride != null) {
      return amPendingOverride!;
    }
    return const [
      MonthlyWorkflowPendingBranchModel(
        branchId: 'b-1',
        branchName: 'Ikeja Branch',
        year: 2026,
        month: 9,
        status: 'BM_SUBMITTED',
        disbursedPrincipal: 2500000.0,
        collections: 1250000.0,
        closingCredit: 6625000.0,
        closingSavings: 1400000.0,
        vaultCash: 450000.0,
        isGlBalanced: true,
        bmName: 'Adebayo T.',
      ),
    ];
  }

  @override
  Future<List<MonthlyWorkflowPendingBranchModel>>
      getAdminSignedMonthlySubmissions({
    int? year,
    int? month,
  }) async {
    if (adminSignedOverride != null) {
      return adminSignedOverride!;
    }
    return const [
      MonthlyWorkflowPendingBranchModel(
        branchId: 'b-1',
        branchName: 'Ikeja Branch',
        areaName: 'Area 1',
        year: 2026,
        month: 9,
        status: 'AM_VERIFIED',
        disbursedPrincipal: 2500000.0,
        upfrontFees: 125000.0,
        netActiveCredit: 2875000.0,
        collections: 1250000.0,
        closingCredit: 6625000.0,
        closingSavings: 1400000.0,
        vaultCash: 450000.0,
        isGlBalanced: true,
        bmName: 'Adebayo T.',
        amName: 'Ngozi K.',
        amNotes: 'All Trial Balance & Vault Cash lines verified.',
        amEndorsedAt: '2026-09-30T15:20:00',
      ),
      MonthlyWorkflowPendingBranchModel(
        branchId: 'b-2',
        branchName: 'Surulere Branch',
        areaName: 'Area 1',
        year: 2026,
        month: 9,
        status: 'ADMIN_LOCKED',
        disbursedPrincipal: 1800000.0,
        collections: 1050000.0,
        closingCredit: 4200000.0,
        closingSavings: 950000.0,
        vaultCash: 300000.0,
        isGlBalanced: true,
        bmName: 'Yemi S.',
        amName: 'Ngozi K.',
        amNotes: 'Endorsed with zero variance.',
        amEndorsedAt: '2026-09-29T16:10:00',
        adminName: 'Head Admin',
        adminLockedAt: '2026-10-01T09:00:00',
      ),
      MonthlyWorkflowPendingBranchModel(
        branchId: 'b-draft',
        branchName: 'Unsigned Draft Branch',
        year: 2026,
        month: 9,
        status: 'BM_SUBMITTED',
        disbursedPrincipal: 999999.0,
        collections: 111111.0,
        closingCredit: 500000.0,
        closingSavings: 200000.0,
        vaultCash: 50000.0,
        isGlBalanced: true,
      ),
    ];
  }

  @override
  Future<TrialBalanceData> getTrialBalance({
    String? branchName,
    String? asOfDate,
    String? startDate,
    String? endDate,
  }) async {
    return const TrialBalanceData(
      isBalanced: true,
      status: 'BALANCED',
      totalDebits: 7075000.0,
      totalCredits: 7075000.0,
      totalNetDebits: 7075000.0,
      totalNetCredits: 7075000.0,
      variance: 0.0,
      rows: [],
    );
  }

  @override
  Future<SavingsSummaryData> getSavingsSummary({
    String? branchName,
    String? productName,
    String? officerName,
    String? asOfDate,
    String? startDate,
    String? endDate,
  }) async {
    return const SavingsSummaryData(
      totalIndividualDeposits: 1200000.0,
      totalIndividualWithdrawals: 100000.0,
      netIndividualSavings: 1100000.0,
      totalGroupDeposits: 350000.0,
      totalGroupWithdrawals: 50000.0,
      netGroupSavings: 300000.0,
      lapsReserve: 45000.0,
      totalConsolidatedSavings: 1400000.0,
      activeSaversCount: 60,
      totalSaversRecorded: 65,
      savers: [],
    );
  }

  @override
  Future<RepaymentSummaryData> getRepaymentSummary({
    String? branchName,
    String? productName,
    String? officerName,
    String? startDate,
    String? endDate,
  }) async {
    return const RepaymentSummaryData(
      totalCollected: 1250000.0,
      totalExpected: 1300000.0,
      baseCollections: 1100000.0,
      collectionEfficiency: 96.2,
      totalOverdueCollected: 35000.0,
      fullPayoffAmount: 300000.0,
      fullPayoffCount: 2,
      excessPaymentAmount: 150000.0,
      excessPaymentCount: 3,
      statusCounts: {'PAID': 40},
      totalTransactions: 40,
      products: [],
      repayments: [],
    );
  }

  @override
  Future<PortfolioPerformanceData> getPortfolioPerformance({
    String? branchName,
    String? productName,
    String? officerName,
    String? inspectOfficer,
  }) async {
    return const PortfolioPerformanceData(
      activeLoans: 45,
      totalPortfolio: 6625000.0,
      parPercentage: 1.8,
      officersList: ['Chinedu Okafor'],
      officerRecords: [],
      riskDistribution: {'Current (0 Days)': 44, '1-30 Days': 1},
    );
  }

  @override
  Future<AreaComparisonData> getAreaComparison({
    String? productName,
    String? asOfDate,
    String? startDate,
    String? endDate,
    int? year,
    int? month,
  }) async {
    areaComparisonCalls++;
    return const AreaComparisonData(
      totalBranches: 2,
      totalPeopleOnLoan: 90,
      totalActiveLoans: 90,
      totalActiveSavers: 115,
      totalAreaCollections: 2400000.0,
      totalAreaExpected: 2500000.0,
      overallEfficiency: 96.0,
      totalAreaSavings: 2750000.0,
      totalAreaPortfolio: 12800000.0,
      overallPar: 1.5,
      rows: [
        AreaBranchRow(
          branch: 'Ikeja Branch',
          peopleOnLoan: 45,
          activeLoans: 45,
          activeSavers: 60,
          totalSavings: 1400000.0,
          collectionsReceived: 1250000.0,
          expectedCollections: 1300000.0,
          collectionEfficiency: 96.2,
          outstandingPortfolio: 6625000.0,
          parPercentage: 1.8,
          status: 'HEALTHY',
        ),
      ],
    );
  }

  @override
  Future<List<int>> downloadMonthlyParityPdf({
    String? branchName,
    int? year,
    int? month,
    String? officerName,
    String? productName,
  }) async {
    return [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34];
  }

  @override
  Future<List<int>> downloadExcel({
    String? branchName,
    String? productName,
    String? officerName,
    String? asOfDate,
    String? startDate,
    String? endDate,
    int? year,
    int? month,
  }) async {
    lastExcelBranchName = branchName;
    return [1, 2, 3, 4];
  }
}

Widget _buildHarness({
  required AuthUser user,
  required _FakeReportsApiService fakeApi,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith((ref) => _FakeAuthController(user)),
      reportsApiServiceProvider.overrideWithValue(fakeApi),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: ReportsExportScreen(),
        ),
      ),
    ),
  );
}

Future<void> _tapLabel(WidgetTester tester, String label) async {
  final finder = find.text(label).first;
  await Scrollable.ensureVisible(tester.element(finder));
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Credit Officer sees Access Denied and fires zero report API requests',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeApi = _FakeReportsApiService();
      final coUser = AuthUser(
        id: 'u-co',
        username: 'co_user',
        fullName: 'Chinedu Okafor',
        role: 'Credit Officer',
        branch: 'Ikeja Branch',
        branchId: 'b-1',
      );

      await tester.pumpWidget(_buildHarness(user: coUser, fakeApi: fakeApi));
      await tester.pumpAndSettle();

      expect(find.textContaining('Access Denied'), findsOneWidget);
      expect(fakeApi.metaCalls, 0);
      expect(fakeApi.parityCalls, 0);
      expect(fakeApi.officialStatementsCalls, 0);
      expect(fakeApi.areaComparisonCalls, 0);
    },
  );

  for (final size in const [Size(360, 800), Size(800, 1024), Size(1440, 900)]) {
    testWidgets(
      'Branch Manager renders cleanly at ${size.width.toInt()}x${size.height.toInt()} without calling areaComparison and keeps statement filters independent',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final fakeApi = _FakeReportsApiService(workflowStatus: 'BM_SUBMITTED');
        final bmUser = AuthUser(
          id: 'u-bm',
          username: 'bm_ikeja',
          fullName: 'Adebayo T.',
          role: 'Branch Manager',
          branch: 'Ikeja Branch',
          branchId: 'b-1',
        );

        await tester.pumpWidget(_buildHarness(user: bmUser, fakeApi: fakeApi));
        await tester.pumpAndSettle();

        expect(fakeApi.areaComparisonCalls, 0);
        expect(
            find.textContaining('SUBMITTED FOR AM SIGN-OFF'), findsOneWidget);

        // Verify Sub-Tab 0 (A. Deposit Statement) and Sub-Tab 1 (B. Credit Statement) independent filter states
        await _tapLabel(tester, 'A. Deposit Statement');
        expect(find.textContaining('Monthly Loan'), findsWidgets);

        await _tapLabel(tester, 'B. Credit Statement');
        expect(find.text('Consolidated Total'), findsWidgets);

        // Verify Sub-Tab 6 is read-only when BM_SUBMITTED
        await _tapLabel(tester, 'Bank & Treasury Reconciliation');
        expect(
            find.textContaining(
                'Read-Only Mode: Statements and treasury reconciliations are locked'),
            findsOneWidget);
      },
    );
  }

  testWidgets(
    'Area Manager sees Seal Regional Package when AM_VERIFIED, can open Regional Comparison, and sees zero internal codes in Trial Balance or Annex-1',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeApi = _FakeReportsApiService(workflowStatus: 'AM_VERIFIED');
      final amUser = AuthUser(
        id: 'u-am',
        username: 'am_lagos',
        fullName: 'Ngozi K.',
        role: 'Area Manager',
        branch: 'Ikeja Branch',
        branchId: 'b-1',
        assignedBranches: const ['Ikeja Branch', 'Surulere Branch'],
        assignedBranchIds: const ['b-1', 'b-2'],
      );

      await tester.pumpWidget(_buildHarness(user: amUser, fakeApi: fakeApi));
      await tester.pumpAndSettle();

      // AM starts on Regional Comparison tab
      expect(fakeApi.areaComparisonCalls, greaterThanOrEqualTo(1));
      expect(find.text('Ikeja Branch'), findsWidgets);

      // Switch to Branch Statements & Sign-Off tab
      await _tapLabel(tester, 'Branch Statements & Sign-Off');
      expect(find.text('Seal Regional Package'), findsOneWidget);

      // Switch to Official Trial Balance Sub-Tab and verify Rule 12 strips "(Account 1000)"
      await _tapLabel(tester, 'Official Trial Balance');
      expect(find.textContaining('Account 1000'), findsNothing);
      expect(find.text('Cash at Hand'), findsOneWidget);

      // Switch to Annex-1 Sundry Sub-Tab and verify Rule 12 strips PC1 / PB3 voucher codes
      await _tapLabel(tester, 'Annex-1 Sundry');
      expect(find.text('PC1'), findsNothing);
      expect(find.text('PB3'), findsNothing);
      expect(find.text('Passbook Fee'), findsOneWidget);
      expect(find.text('Office Stationery'), findsOneWidget);
    },
  );

  testWidgets(
    'Director role sees read-only status badges and can inspect Bank & Treasury Reconciliation in read-only mode',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeApi = _FakeReportsApiService(workflowStatus: 'BM_SUBMITTED');
      final directorUser = AuthUser(
        id: 'u-dir',
        username: 'exec_director',
        fullName: 'Executive Director',
        role: 'Director',
        branch: 'Head Office',
      );

      await tester
          .pumpWidget(_buildHarness(user: directorUser, fakeApi: fakeApi));
      await tester.pumpAndSettle();

      // Director should never see mutating buttons ("Endorse", "Return", "Lock & Archive")
      expect(find.text('Endorse & Sign Off'), findsNothing);
      expect(find.text('Lock & Archive'), findsNothing);
      expect(find.text('Awaiting Supervisory Endorsement'), findsOneWidget);

      // Director can open Sub-Tab 6 in read-only mode
      await _tapLabel(tester, 'Bank & Treasury Reconciliation');
      expect(
          find.textContaining(
              'Read-Only Mode: Statements and treasury reconciliations are locked'),
          findsOneWidget);
    },
  );

  for (final size in const [Size(390, 844), Size(800, 1024), Size(1440, 900)]) {
    testWidgets(
      'Redesigned Admin Reports & Export only shows AM-signed reports at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final fakeApi = _FakeReportsApiService();
        final adminUser = AuthUser(
          id: 'u-admin',
          username: 'admin',
          fullName: 'Head Admin',
          role: 'Admin',
          branch: 'Head Office',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider
                  .overrideWith((ref) => _FakeAuthController(adminUser)),
              reportsApiServiceProvider.overrideWithValue(fakeApi),
            ],
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: size.width < 600
                    ? const TextScaler.linear(1.2)
                    : TextScaler.noScaling,
              ),
              child: const MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: ReportsExportScreen(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Governance header & AM-signed cards appear
        expect(find.text('AM-SIGNED REPORTS ONLY'), findsOneWidget);
        expect(find.text('Ikeja Branch'), findsWidgets);
        expect(find.text('Surulere Branch'), findsWidgets);
        expect(find.textContaining('Signed by Ngozi K.'), findsWidgets);

        // Unreviewed BM_SUBMITTED report MUST NOT appear anywhere in Admin UI
        expect(find.text('Unsigned Draft Branch'), findsNothing);
        expect(find.text('Verify & Submit to Area Manager'), findsNothing);
        expect(find.text('Endorse & Sign Off'), findsNothing);

        // Zero emojis anywhere
        final emojiRe =
            RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          expect(emojiRe.hasMatch(t.data ?? ''), isFalse);
        }
      },
    );
  }

  testWidgets(
    'Admin shows honest empty state and blocks unreviewed statement fetches when zero reports are AM-signed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeApi = _FakeReportsApiService(
        adminSignedOverride: const [
          MonthlyWorkflowPendingBranchModel(
            branchId: 'b-bm',
            branchName: 'Draft Only Branch',
            year: 2026,
            month: 11,
            status: 'BM_SUBMITTED',
            disbursedPrincipal: 500000.0,
            collections: 250000.0,
            closingCredit: 900000.0,
            closingSavings: 300000.0,
            vaultCash: 100000.0,
            isGlBalanced: true,
          ),
        ],
      );
      final adminUser = AuthUser(
        id: 'u-admin',
        username: 'admin',
        fullName: 'Head Admin',
        role: 'Admin',
        branch: 'Head Office',
      );

      await tester.pumpWidget(_buildHarness(user: adminUser, fakeApi: fakeApi));
      await tester.pumpAndSettle();

      expect(find.textContaining('No Area Manager-Signed Reports Ready'),
          findsOneWidget);
      expect(find.text('Draft Only Branch'), findsNothing);
      expect(fakeApi.parityCalls, 0);
      expect(fakeApi.officialStatementsCalls, 0);
    },
  );

  testWidgets(
    'Admin navigates between AM-Signed Queue, Audited Statements, and Verified Export Vault cleanly',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeApi = _FakeReportsApiService();
      final adminUser = AuthUser(
        id: 'u-admin',
        username: 'admin',
        fullName: 'Head Admin',
        role: 'Admin',
        branch: 'Head Office',
      );

      await tester.pumpWidget(_buildHarness(user: adminUser, fakeApi: fakeApi));
      await tester.pumpAndSettle();

      // Switch to Audited Statements
      await _tapLabel(tester, 'Audited Statements');
      expect(
          find.textContaining('Signed & Reviewed by Ngozi K.'), findsOneWidget);
      expect(find.text('A. Deposit Statement'), findsOneWidget);
      expect(find.text('Preview & Print PDF'), findsOneWidget);

      // Verify Rule 12 still strips Account 1000 in Trial Balance
      await _tapLabel(tester, 'Official Trial Balance');
      expect(find.textContaining('Account 1000'), findsNothing);
      expect(find.text('Cash at Hand'), findsOneWidget);

      // Switch to Verified Export Vault
      await _tapLabel(tester, 'Verified Export Vault');
      expect(find.text('AM-Signed Consolidated Enterprise Package'),
          findsOneWidget);
      expect(find.text('Download Master Workbook (.xlsx)'), findsOneWidget);
      expect(find.text('Share PDF'), findsOneWidget);
      expect(find.text('Preview & Print PDF'), findsOneWidget);
    },
  );

  testWidgets(
    'Redesigned BM Fluid UI renders charts, export sheet actions, and certification states at 390x844 with 1.2x text scale',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeApi = _FakeReportsApiService(
        workflowStatus: 'RETURNED_FOR_CORRECTION',
        amQueryNotes: 'Verify vault physical count against bank slip.',
      );
      final bmUser = AuthUser(
        id: 'u-bm',
        username: 'bm_ikeja',
        fullName: 'Adebayo T.',
        role: 'Branch Manager',
        branch: 'Ikeja Branch',
        branchId: 'b-1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider
                .overrideWith((ref) => _FakeAuthController(bmUser)),
            reportsApiServiceProvider.overrideWithValue(fakeApi),
          ],
          child: const MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              textScaler: TextScaler.linear(1.2),
            ),
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: ReportsExportScreen(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeApi.areaComparisonCalls, 0);
      expect(find.text('SINGLE BRANCH • TIER-1 CERTIFICATION'), findsOneWidget);
      expect(find.text('RETURNED FOR CORRECTION'), findsOneWidget);
      expect(
          find.textContaining('Verify vault physical count'), findsOneWidget);
      expect(find.text('Re-verify & Resubmit'), findsOneWidget);
      expect(find.text('Preview & Print PDF'), findsOneWidget);
      expect(find.text('Share Workbook'), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);

      // Zero emojis & zero leaked internal account codes
      final emojiRe =
          RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        final str = t.data ?? '';
        expect(emojiRe.hasMatch(str), isFalse);
        expect(str.contains('Acct 1000'), isFalse);
      }

      // Switch to Data Exports & Downloads tab and verify Share / PDF controls
      await _tapLabel(tester, 'Data Exports & Downloads');
      expect(find.text('Official Monthly Statements & Print Pack'),
          findsOneWidget);
      expect(find.text('Share PDF'), findsOneWidget);
      expect(find.text('Preview & Print PDF'), findsOneWidget);
    },
  );

  for (final size in const [Size(390, 844), Size(800, 1024), Size(1440, 900)]) {
    testWidgets(
      'Redesigned AM Fluid UI prioritizes BM-submitted queue over drafts and connects statements/exports at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final fakeApi = _FakeReportsApiService(
          workflowStatus: 'BM_SUBMITTED',
          amPendingOverride: const [
            MonthlyWorkflowPendingBranchModel(
              branchId: 'b-1',
              branchName: 'Ikeja Branch',
              areaName: 'Area 1',
              year: 2026,
              month: 9,
              status: 'BM_SUBMITTED',
              disbursedPrincipal: 2500000.0,
              collections: 1250000.0,
              closingCredit: 6625000.0,
              closingSavings: 1400000.0,
              vaultCash: 450000.0,
              isGlBalanced: true,
              bmName: 'Adebayo T.',
              submittedAt: '2026-09-30T14:00:00',
            ),
            MonthlyWorkflowPendingBranchModel(
              branchId: 'b-2',
              branchName: 'Surulere Branch',
              areaName: 'Area 1',
              year: 2026,
              month: 9,
              status: 'AM_VERIFIED',
              disbursedPrincipal: 1800000.0,
              collections: 1050000.0,
              closingCredit: 4200000.0,
              closingSavings: 950000.0,
              vaultCash: 300000.0,
              isGlBalanced: true,
              bmName: 'Yemi S.',
              amName: 'Ngozi K.',
              amEndorsedAt: '2026-09-30T16:15:00',
            ),
            MonthlyWorkflowPendingBranchModel(
              branchId: 'b-draft',
              branchName: 'Alimosho Draft Branch',
              areaName: 'Area 1',
              year: 2026,
              month: 9,
              status: 'DRAFT',
              disbursedPrincipal: 400000.0,
              collections: 200000.0,
              closingCredit: 800000.0,
              closingSavings: 250000.0,
              vaultCash: 100000.0,
              isGlBalanced: true,
              bmName: 'Tunde K.',
            ),
          ],
        );

        final amUser = AuthUser(
          id: 'u-am',
          username: 'am_lagos',
          fullName: 'Ngozi K.',
          role: 'Area Manager',
          branch: 'Ikeja Branch',
          branchId: 'b-1',
          assignedBranches: const ['Ikeja Branch', 'Surulere Branch'],
          assignedBranchIds: const ['b-1', 'b-2'],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider
                  .overrideWith((ref) => _FakeAuthController(amUser)),
              reportsApiServiceProvider.overrideWithValue(fakeApi),
            ],
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: size.width < 600
                    ? const TextScaler.linear(1.2)
                    : TextScaler.noScaling,
              ),
              child: const MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: ReportsExportScreen(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Regional header & charts
        expect(
            find.text('BM-SUBMITTED REVIEW & DISTRICT SCOPE'), findsOneWidget);
        expect(find.byType(BarChart), findsOneWidget);
        expect(find.byType(PieChart), findsOneWidget);

        // Submitted Queue shows BM_SUBMITTED + AM_VERIFIED, and hides DRAFT by default
        expect(find.text('Submitted Queue (2)'), findsOneWidget);
        expect(find.text('Surulere Branch'), findsWidgets);
        expect(find.text('Alimosho Draft Branch'), findsNothing);
        expect(
          find.textContaining(
              '1 supervised branch is still in Branch Manager preparation'),
          findsOneWidget,
        );

        // Zero emojis
        final emojiRe =
            RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          expect(emojiRe.hasMatch(t.data ?? ''), isFalse);
        }

        // Review & Endorse transitions to Tab 1 with Endorse / Return controls
        await _tapLabel(tester, 'Review & Endorse');
        expect(find.text('Endorse & Sign Off'), findsOneWidget);
        expect(find.text('Query / Return'), findsOneWidget);

        // Data Exports tab has Share & Preview controls
        await _tapLabel(tester, 'Data Exports & Downloads');
        expect(find.text('Regional Consolidated Supervisory Package'),
            findsOneWidget);
        expect(find.text('Share Regional Workbook'), findsOneWidget);
        expect(find.text('Preview & Print PDF'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'BM DRAFT status displays Verify & Submit to Area Manager and opens ReportPdfPreviewSheet',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeApi = _FakeReportsApiService(workflowStatus: 'DRAFT');
      final bmUser = AuthUser(
        id: 'u-bm',
        username: 'bm_ikeja',
        fullName: 'Adebayo T.',
        role: 'Branch Manager',
        branch: 'Ikeja Branch',
        branchId: 'b-1',
      );

      await tester.pumpWidget(_buildHarness(user: bmUser, fakeApi: fakeApi));
      await tester.pumpAndSettle();

      expect(find.text('Verify & Submit to Area Manager'), findsOneWidget);
      final pdfBtn = find.text('Preview & Print PDF').first;
      await Scrollable.ensureVisible(tester.element(pdfBtn));
      await tester.pump();
      await tester.tap(pdfBtn);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(ReportPdfPreviewSheet), findsOneWidget);
    },
  );
}
