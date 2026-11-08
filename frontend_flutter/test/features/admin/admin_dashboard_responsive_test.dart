import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/features/admin/data/datasources/admin_api_service.dart';
import 'package:frontend_flutter/features/admin/data/models/admin_dashboard_models.dart';
import 'package:frontend_flutter/features/admin/presentation/admin_dashboard_screen.dart';

AdminOperationsSnapshotModel _buildMockOperations() {
  return AdminOperationsSnapshotModel(
    businessDate: '2026-11-08',
    businessDateStatus: const BusinessDateStatusModel(
      isWorkingDay: true,
      statusReason: 'Valid working day',
      nextWorkingDay: '2026-11-09',
    ),
    overview: const InstitutionalOverviewModel(
      totalClientsCount: 1420,
      totalClientsDisplay: '1,420',
      activeBranchesCount: 4,
      totalPortfolio: 48500000.0,
      todayCollections: 1850000.0,
    ),
    vaultCashInCustody: 3420000.0,
    todayCollections: 1850000.0,
    todayDisbursements: 600000.0,
    todayDisbursedCount: 4,
    todaySavingsDeposit: 320000.0,
    todaySavingsWithdrawal: 50000.0,
    todayNetSavings: 270000.0,
    collectionCompliancePct: 96.4,
    financialActivityWeek: const [
      FinancialActivityDayModel(
        day: 'Mon',
        date: '2026-11-02',
        isWorkingDay: true,
        statusReason: 'Working day',
        collections: 1500000,
        disbursements: 450000,
      ),
      FinancialActivityDayModel(
        day: 'Tue',
        date: '2026-11-03',
        isWorkingDay: true,
        statusReason: 'Working day',
        collections: 1850000,
        disbursements: 600000,
      ),
      FinancialActivityDayModel(
        day: 'Wed',
        date: '2026-11-04',
        isWorkingDay: true,
        statusReason: 'Working day',
        collections: 1620000,
        disbursements: 300000,
      ),
    ],
    branchPerformanceSummary: const [
      BranchPerformanceRowModel(
        branchId: 'b-1',
        branchName: 'Ikeja Branch',
        volume: 850000,
        relativePct: 100.0,
        vaultCash: 1200000,
        managerName: 'Adebayo T.',
        status: 'OPEN',
        isHeadOffice: false,
      ),
      BranchPerformanceRowModel(
        branchId: 'b-2',
        branchName: 'Surulere Branch',
        volume: 600000,
        relativePct: 70.5,
        vaultCash: 950000,
        managerName: 'Ngozi K.',
        status: 'OPEN',
        isHeadOffice: false,
      ),
      BranchPerformanceRowModel(
        branchId: 'b-3',
        branchName: 'Yaba Branch',
        volume: 400000,
        relativePct: 47.0,
        vaultCash: 720000,
        managerName: 'Ibrahim M.',
        status: 'OPEN',
        isHeadOffice: false,
      ),
      BranchPerformanceRowModel(
        branchId: 'b-ho',
        branchName: 'Head Office',
        volume: 0,
        relativePct: 0.0,
        vaultCash: 550000,
        managerName: 'Admin Treasury',
        status: 'OPEN',
        isHeadOffice: true,
      ),
    ],
    branchMatrix: const [],
    pendingReversalsCount: 1,
    pendingReversals: const [
      PendingReversalItemModel(
        requestId: 'rev-101',
        branchName: 'Ikeja Branch',
        recordType: 'Repayment',
        recordId: 'rep-889',
        reason: 'Duplicate teller entry on receipt',
        requestedBy: 'Chinedu O.',
        createdAt: '2026-11-08 09:30',
      ),
    ],
    pendingHighLoansCount: 1,
    pendingHighLoans: const [
      PendingHighLoanItemModel(
        loanId: 'loan-501',
        branchName: 'Surulere Branch',
        loanAmount: 500000.0,
        activeCredit: 600000.0,
        createdAt: '2026-11-08 10:15',
      ),
    ],
  );
}

InstitutionPerformanceModel _buildMockPerformance(int year) {
  const scorecard = ScorecardBreakdownModel(
    capitalDeploymentScore: 22.0,
    delinquencyControlScore: 23.5,
    overdueRecoveryScore: 14.0,
    borrowerOutreachScore: 13.5,
    repaymentComplianceScore: 9.5,
    vaultDisciplineScore: 9.5,
    compositeScore: 92.0,
  );

  return InstitutionPerformanceModel(
    year: year,
    summary: const PerformanceSummaryModel(
      totalDisbursedYtd: 65000000.0,
      totalDisbursedCount: 420,
      totalOverdueRecoveredYtd: 2450000.0,
      totalActiveBorrowers: 1420,
      totalActiveCredit: 48500000.0,
      totalNetSavings: 12400000.0,
      totalFullPayoffsCount: 38,
      totalFullPayoffsAmount: 5700000.0,
      totalOverdue: 1200000.0,
      averagePar: 2.5,
    ),
    branchRankings: const [
      BranchPerformanceItemModel(
        rank: 1,
        branchId: 'b-1',
        branchName: 'Ikeja Branch',
        branchCode: 'IKJ',
        bmName: 'Adebayo T.',
        disbPrincipal: 28000000.0,
        disbCount: 180,
        activeMembers: 610,
        activeCreditBook: 21000000.0,
        parPct: 1.8,
        overdueAmount: 378000.0,
        defaultersCount: 4,
        overdueRecovered: 1200000.0,
        recoveriesCount: 19,
        fullRecoveriesCount: 7,
        recoveryRatePct: 94.0,
        collectedAmount: 19500000.0,
        compliancePct: 98.2,
        vaultCash: 1200000.0,
        topOfficerName: 'Funke A.',
        compositeScore: 92.0,
        scorecard: scorecard,
      ),
      BranchPerformanceItemModel(
        rank: 2,
        branchId: 'b-2',
        branchName: 'Surulere Branch',
        branchCode: 'SRL',
        bmName: 'Ngozi K.',
        disbPrincipal: 21000000.0,
        disbCount: 140,
        activeMembers: 480,
        activeCreditBook: 16500000.0,
        parPct: 11.4,
        overdueAmount: 1881000.0,
        defaultersCount: 12,
        overdueRecovered: 850000.0,
        recoveriesCount: 11,
        fullRecoveriesCount: 3,
        recoveryRatePct: 81.0,
        collectedAmount: 14200000.0,
        compliancePct: 91.0,
        vaultCash: 950000.0,
        topOfficerName: 'Tunde B.',
        compositeScore: 79.5,
        scorecard: scorecard,
      ),
    ],
    officerRankings: List.generate(
      12,
      (idx) => OfficerPerformanceItemModel(
        rank: idx + 1,
        officerId: 'off-${idx + 1}',
        officerName: 'Officer ${idx + 1}',
        officerUsername: 'co_${idx + 1}',
        branchId: idx.isEven ? 'b-1' : 'b-2',
        branchName: idx.isEven ? 'Ikeja Branch' : 'Surulere Branch',
        activeClients: 120 - (idx * 5),
        activeCredit: 4500000.0 - (idx * 200000),
        disbPrincipal: 6200000.0 - (idx * 300000),
        disbCount: 45 - idx,
        overdueAmount: 50000.0 * idx,
        parPct: 1.2 + idx,
        defaultersCount: idx,
        overdueRecovered: 250000.0,
        fullRecoveriesCount: 2,
        collectedAmount: 5100000.0,
        compliancePct: 97.5 - idx,
        compositeScore: 94.0 - (idx * 2.0),
      ),
    ),
  );
}

AdminRiskHealthModel _buildMockRiskHealth() {
  return const AdminRiskHealthModel(
    parPct: 3.4,
    totalActiveCredit: 48500000.0,
    totalOverdueRecovered: 2450000.0,
    recoveryEventsCount: 42,
    fullClientRestorations: 15,
    fullPayoffsSettledAmount: 5700000.0,
    fullPayoffCount: 38,
    excessCashCollected: 1890000.0,
    projectionEngineStatus: 'Synchronized',
    pendingEventBacklog: 0,
    offlineDeviceSyncStatus: 'Active',
    databaseCluster: 'Supabase Managed',
    immutableAuditState: 'Enforced',
  );
}

List<Override> _buildOverrides() {
  return [
    adminOperationsProvider.overrideWith(
      (ref, dateStr) async => _buildMockOperations(),
    ),
    institutionPerformanceProvider.overrideWith(
      (ref, year) async => _buildMockPerformance(year),
    ),
    adminRiskHealthProvider.overrideWith(
      (ref) async => _buildMockRiskHealth(),
    ),
  ];
}

void main() {
  group('AdminDashboardScreen Responsive Redesign (BIA-ADMIN-DASH-003)', () {
    for (final viewportWidth in <double>[360, 800, 1440]) {
      testWidgets(
        'renders all 3 tabs cleanly without overflow at ${viewportWidth.toInt()}px width',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(viewportWidth, 960));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            ProviderScope(
              overrides: _buildOverrides(),
              child: const MaterialApp(
                home: Scaffold(
                  body: AdminDashboardScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Tab 0: Overview
          expect(find.text('Overview'), findsWidgets);
          expect(
            find.text('3 field branches • 1 head office'),
            findsOneWidget,
          );
          expect(find.text('Total clients'), findsOneWidget);
          expect(find.text('Active loans'), findsOneWidget);
          expect(
            find.text('Requests Waiting for Your Decision'),
            findsOneWidget,
          );

          // Switch to Tab 1: Rankings
          final rankingsTabFinder = viewportWidth < 600
              ? find.text('Rankings')
              : find.text('Branch & Officer Rankings');
          expect(rankingsTabFinder, findsOneWidget);
          await tester.tap(rankingsTabFinder);
          await tester.pumpAndSettle();

          expect(find.text('Ikeja Branch'), findsWidgets);
          expect(find.text('Surulere Branch'), findsWidgets);

          // Switch to Tab 2: Loan Health & Risk
          final riskTabFinder = viewportWidth < 600
              ? find.text('Loan Health')
              : find.text('Loan Health & Risk');
          expect(riskTabFinder, findsOneWidget);
          await tester.tap(riskTabFinder);
          await tester.pumpAndSettle();

          expect(find.text('Loan Health & Risk Indicators'), findsOneWidget);
          expect(find.text('Healthy • Within 10% Limit'), findsOneWidget);
          expect(find.text('Extra Cash Collected'), findsOneWidget);
          expect(find.text('Which Branches Need Attention'), findsOneWidget);
        },
      );
    }

    testWidgets(
      'works seamlessly inside an unbounded SingleChildScrollView (CoAppScaffold mode)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: _buildOverrides(),
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AdminDashboardScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Total clients'), findsOneWidget);

        // Switch tabs inside unbounded parent scroll view
        await tester.tap(find.text('Rankings'));
        await tester.pumpAndSettle();
        expect(find.text('Ikeja Branch'), findsWidgets);

        await tester.tap(find.text('Loan Health'));
        await tester.pumpAndSettle();
        expect(find.text('Extra Cash Collected'), findsOneWidget);
      },
    );

    testWidgets(
      'Rankings tab supports Year Picker and Show All officers toggle',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: _buildOverrides(),
            child: const MaterialApp(
              home: Scaffold(
                body: AdminDashboardScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Branch & Officer Rankings'));
        await tester.pumpAndSettle();

        // At 1280px (expanded), initialLimit is 10 out of 12 officers
        expect(find.text('Officer 1'), findsOneWidget);
        expect(find.text('Officer 10'), findsOneWidget);
        expect(find.text('Officer 12'), findsNothing);

        final showAllBtn = find.text('Show All (12)');
        expect(showAllBtn, findsOneWidget);
        await tester.ensureVisible(showAllBtn);
        await tester.tap(showAllBtn);
        await tester.pumpAndSettle();

        expect(find.text('Officer 12'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping Approve on a pending reversal opens confirmation dialog before executing',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: _buildOverrides(),
            child: const MaterialApp(
              home: Scaffold(
                body: AdminDashboardScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final approveBtn = find.text('Approve').first;
        await tester.ensureVisible(approveBtn);
        await tester.pumpAndSettle();
        await tester.tap(approveBtn);
        await tester.pumpAndSettle();

        expect(find.text('Approve Correction Request?'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Approve Correction Request?'), findsNothing);
      },
    );
  });
}
