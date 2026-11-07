import 'package:flutter/foundation.dart';

@immutable
class AdminOperationsSnapshotModel {
  final String businessDate;
  final BusinessDateStatusModel businessDateStatus;
  final InstitutionalOverviewModel overview;
  final double vaultCashInCustody;
  final double todayCollections;
  final double todayDisbursements;
  final int todayDisbursedCount;
  final double todaySavingsDeposit;
  final double todaySavingsWithdrawal;
  final double todayNetSavings;
  final double collectionCompliancePct;
  final List<FinancialActivityDayModel> financialActivityWeek;
  final List<BranchPerformanceRowModel> branchPerformanceSummary;
  final List<BranchOperationalStatusModel> branchMatrix;
  final int pendingReversalsCount;
  final List<PendingReversalItemModel> pendingReversals;
  final int pendingHighLoansCount;
  final List<PendingHighLoanItemModel> pendingHighLoans;

  const AdminOperationsSnapshotModel({
    required this.businessDate,
    required this.businessDateStatus,
    required this.overview,
    required this.vaultCashInCustody,
    required this.todayCollections,
    required this.todayDisbursements,
    required this.todayDisbursedCount,
    required this.todaySavingsDeposit,
    required this.todaySavingsWithdrawal,
    required this.todayNetSavings,
    required this.collectionCompliancePct,
    required this.financialActivityWeek,
    required this.branchPerformanceSummary,
    required this.branchMatrix,
    required this.pendingReversalsCount,
    required this.pendingReversals,
    required this.pendingHighLoansCount,
    required this.pendingHighLoans,
  });

  factory AdminOperationsSnapshotModel.fromJson(Map<String, dynamic> json) {
    final liq = json['liquidity'] as Map<String, dynamic>? ?? {};
    final ac = json['action_center'] as Map<String, dynamic>? ?? {};
    final bds = json['business_date_status'] as Map<String, dynamic>? ?? {};
    final ov = json['overview'] as Map<String, dynamic>? ?? {};

    final bList = (json['branch_matrix'] as List<dynamic>? ?? [])
        .map((e) => BranchOperationalStatusModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final rList = (ac['pending_reversals'] as List<dynamic>? ?? [])
        .map((e) => PendingReversalItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final hlList = (ac['pending_high_loans'] as List<dynamic>? ?? [])
        .map((e) => PendingHighLoanItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final fawList = (json['financial_activity_week'] as List<dynamic>? ?? [])
        .map((e) => FinancialActivityDayModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final bpsList = (json['branch_performance_summary'] as List<dynamic>? ?? [])
        .map((e) => BranchPerformanceRowModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return AdminOperationsSnapshotModel(
      businessDate: json['business_date']?.toString() ?? '',
      businessDateStatus: BusinessDateStatusModel.fromJson(bds),
      overview: InstitutionalOverviewModel.fromJson(ov),
      vaultCashInCustody: (liq['vault_cash_in_custody'] as num?)?.toDouble() ?? 0.0,
      todayCollections: (liq['today_collections'] as num?)?.toDouble() ?? 0.0,
      todayDisbursements: (liq['today_disbursements'] as num?)?.toDouble() ?? 0.0,
      todayDisbursedCount: (liq['today_disbursed_count'] as num?)?.toInt() ?? 0,
      todaySavingsDeposit: (liq['today_savings_deposit'] as num?)?.toDouble() ?? 0.0,
      todaySavingsWithdrawal: (liq['today_savings_withdrawal'] as num?)?.toDouble() ?? 0.0,
      todayNetSavings: (liq['today_net_savings'] as num?)?.toDouble() ?? 0.0,
      collectionCompliancePct: (liq['collection_compliance_pct'] as num?)?.toDouble() ?? 95.0,
      financialActivityWeek: fawList,
      branchPerformanceSummary: bpsList,
      branchMatrix: bList,
      pendingReversalsCount: (ac['pending_reversals_count'] as num?)?.toInt() ?? rList.length,
      pendingReversals: rList,
      pendingHighLoansCount: (ac['pending_high_loans_count'] as num?)?.toInt() ?? hlList.length,
      pendingHighLoans: hlList,
    );
  }
}

@immutable
class BranchOperationalStatusModel {
  final String branchId;
  final String branchName;
  final String branchCode;
  final String managerName;
  final String operationalStatus;
  final double vaultCash;
  final double todayCollected;
  final bool isHeadOffice;

  const BranchOperationalStatusModel({
    required this.branchId,
    required this.branchName,
    required this.branchCode,
    required this.managerName,
    required this.operationalStatus,
    required this.vaultCash,
    required this.todayCollected,
    this.isHeadOffice = false,
  });

  factory BranchOperationalStatusModel.fromJson(Map<String, dynamic> json) {
    final name = json['branch_name']?.toString() ?? 'Branch';
    final isHo = json['is_head_office'] as bool? ??
        (name.trim().toLowerCase().contains('head office') || name.trim().toLowerCase().contains('headquarters'));
    return BranchOperationalStatusModel(
      branchId: json['branch_id']?.toString() ?? '',
      branchName: name,
      branchCode: json['branch_code']?.toString() ?? '',
      managerName: json['manager_name']?.toString() ?? 'Manager',
      operationalStatus: json['operational_status']?.toString() ?? 'OPEN',
      vaultCash: (json['vault_cash'] as num?)?.toDouble() ?? 0.0,
      todayCollected: (json['today_collected'] as num?)?.toDouble() ?? 0.0,
      isHeadOffice: isHo,
    );
  }
}

@immutable
class PendingReversalItemModel {
  final String requestId;
  final String branchName;
  final String recordType;
  final String recordId;
  final String reason;
  final String requestedBy;
  final String createdAt;

  const PendingReversalItemModel({
    required this.requestId,
    required this.branchName,
    required this.recordType,
    required this.recordId,
    required this.reason,
    required this.requestedBy,
    required this.createdAt,
  });

  factory PendingReversalItemModel.fromJson(Map<String, dynamic> json) {
    return PendingReversalItemModel(
      requestId: json['request_id']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? 'Branch',
      recordType: json['record_type']?.toString() ?? 'Transaction',
      recordId: json['record_id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? 'Correction needed',
      requestedBy: json['requested_by']?.toString() ?? 'Officer',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

@immutable
class PendingHighLoanItemModel {
  final String loanId;
  final String branchName;
  final double loanAmount;
  final double activeCredit;
  final String createdAt;

  const PendingHighLoanItemModel({
    required this.loanId,
    required this.branchName,
    required this.loanAmount,
    required this.activeCredit,
    required this.createdAt,
  });

  factory PendingHighLoanItemModel.fromJson(Map<String, dynamic> json) {
    return PendingHighLoanItemModel(
      loanId: json['loan_id']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? 'Branch',
      loanAmount: (json['loan_amount'] as num?)?.toDouble() ?? 0.0,
      activeCredit: (json['active_credit'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

@immutable
class InstitutionPerformanceModel {
  final int year;
  final List<BranchPerformanceItemModel> branchRankings;
  final List<OfficerPerformanceItemModel> officerRankings;
  final PerformanceSummaryModel summary;

  const InstitutionPerformanceModel({
    required this.year,
    required this.branchRankings,
    required this.officerRankings,
    required this.summary,
  });

  factory InstitutionPerformanceModel.fromJson(Map<String, dynamic> json) {
    final bp = json['branch_performance'] as Map<String, dynamic>? ?? {};
    final op = json['officer_performance'] as Map<String, dynamic>? ?? {};

    final bList = (bp['rankings'] as List<dynamic>? ?? [])
        .map((e) => BranchPerformanceItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final oList = (op['rankings'] as List<dynamic>? ?? [])
        .map((e) => OfficerPerformanceItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final sumMap = bp['summary'] as Map<String, dynamic>? ?? json['summary'] as Map<String, dynamic>? ?? {};

    return InstitutionPerformanceModel(
      year: (json['year'] as num?)?.toInt() ?? 2026,
      branchRankings: bList,
      officerRankings: oList,
      summary: PerformanceSummaryModel.fromJson(sumMap),
    );
  }
}

@immutable
class PerformanceSummaryModel {
  final double totalDisbursedYtd;
  final int totalDisbursedCount;
  final double totalOverdueRecoveredYtd;
  final int totalActiveBorrowers;
  final double totalActiveCredit;
  final double totalNetSavings;
  final int totalFullPayoffsCount;
  final double totalFullPayoffsAmount;
  final double totalOverdue;
  final double averagePar;

  const PerformanceSummaryModel({
    this.totalDisbursedYtd = 0.0,
    this.totalDisbursedCount = 0,
    this.totalOverdueRecoveredYtd = 0.0,
    this.totalActiveBorrowers = 0,
    this.totalActiveCredit = 0.0,
    this.totalNetSavings = 0.0,
    this.totalFullPayoffsCount = 0,
    this.totalFullPayoffsAmount = 0.0,
    this.totalOverdue = 0.0,
    this.averagePar = 0.0,
  });

  factory PerformanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return PerformanceSummaryModel(
      totalDisbursedYtd: (json['total_disbursed_ytd'] as num?)?.toDouble() ?? 0.0,
      totalDisbursedCount: (json['total_disbursed_count'] as num?)?.toInt() ?? 0,
      totalOverdueRecoveredYtd: (json['total_overdue_recovered_ytd'] as num?)?.toDouble() ?? 0.0,
      totalActiveBorrowers: (json['total_active_borrowers'] as num?)?.toInt() ?? 0,
      totalActiveCredit: (json['total_active_credit'] as num?)?.toDouble() ?? 0.0,
      totalNetSavings: (json['total_net_savings'] as num?)?.toDouble() ?? 0.0,
      totalFullPayoffsCount: (json['total_full_payoffs_count'] as num?)?.toInt() ?? 0,
      totalFullPayoffsAmount: (json['total_full_payoffs_amount'] as num?)?.toDouble() ?? 0.0,
      totalOverdue: (json['total_overdue'] as num?)?.toDouble() ?? 0.0,
      averagePar: (json['average_par'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

@immutable
class BranchPerformanceItemModel {
  final int rank;
  final String branchId;
  final String branchName;
  final String branchCode;
  final String bmName;
  final double disbPrincipal;
  final int disbCount;
  final int activeMembers;
  final double activeCreditBook;
  final double parPct;
  final double overdueAmount;
  final int defaultersCount;
  final double overdueRecovered;
  final int recoveriesCount;
  final int fullRecoveriesCount;
  final double recoveryRatePct;
  final double collectedAmount;
  final double compliancePct;
  final double vaultCash;
  final double netSavingsBalance;
  final int fullPayoffsCount;
  final double fullPayoffsAmount;
  final String topOfficerName;
  final double compositeScore;
  final ScorecardBreakdownModel scorecard;

  const BranchPerformanceItemModel({
    required this.rank,
    required this.branchId,
    required this.branchName,
    required this.branchCode,
    required this.bmName,
    required this.disbPrincipal,
    required this.disbCount,
    required this.activeMembers,
    required this.activeCreditBook,
    required this.parPct,
    required this.overdueAmount,
    required this.defaultersCount,
    required this.overdueRecovered,
    required this.recoveriesCount,
    required this.fullRecoveriesCount,
    required this.recoveryRatePct,
    required this.collectedAmount,
    required this.compliancePct,
    required this.vaultCash,
    this.netSavingsBalance = 0.0,
    this.fullPayoffsCount = 0,
    this.fullPayoffsAmount = 0.0,
    this.topOfficerName = 'Lead Officer',
    required this.compositeScore,
    required this.scorecard,
  });

  factory BranchPerformanceItemModel.fromJson(Map<String, dynamic> json) {
    return BranchPerformanceItemModel(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      branchId: json['branch_id']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? 'Branch',
      branchCode: json['branch_code']?.toString() ?? '',
      bmName: json['bm_name']?.toString() ?? 'Manager',
      disbPrincipal: (json['disb_principal'] as num?)?.toDouble() ?? 0.0,
      disbCount: (json['disb_count'] as num?)?.toInt() ?? 0,
      activeMembers: (json['active_members'] as num?)?.toInt() ?? 0,
      activeCreditBook: (json['active_credit_book'] as num?)?.toDouble() ?? 0.0,
      parPct: (json['par_pct'] as num?)?.toDouble() ?? 0.0,
      overdueAmount: (json['overdue_amount'] as num?)?.toDouble() ?? 0.0,
      defaultersCount: (json['defaulters_count'] as num?)?.toInt() ?? 0,
      overdueRecovered: (json['overdue_recovered'] as num?)?.toDouble() ?? 0.0,
      recoveriesCount: (json['recoveries_count'] as num?)?.toInt() ?? 0,
      fullRecoveriesCount: (json['full_recoveries_count'] as num?)?.toInt() ?? 0,
      recoveryRatePct: (json['recovery_rate_pct'] as num?)?.toDouble() ?? 100.0,
      collectedAmount: (json['collected_amount'] as num?)?.toDouble() ?? 0.0,
      compliancePct: (json['compliance_pct'] as num?)?.toDouble() ?? 95.0,
      vaultCash: (json['vault_cash'] as num?)?.toDouble() ?? 0.0,
      netSavingsBalance: (json['net_savings_balance'] as num?)?.toDouble() ?? 0.0,
      fullPayoffsCount: (json['full_payoffs_count'] as num?)?.toInt() ?? 0,
      fullPayoffsAmount: (json['full_payoffs_amount'] as num?)?.toDouble() ?? 0.0,
      topOfficerName: json['top_officer_name']?.toString() ?? 'Lead Officer',
      compositeScore: (json['composite_score'] as num?)?.toDouble() ?? 0.0,
      scorecard: ScorecardBreakdownModel.fromJson(json['scorecard'] as Map<String, dynamic>? ?? {}),
    );
  }
}

@immutable
class ScorecardBreakdownModel {
  final double capitalDeploymentScore;
  final double delinquencyControlScore;
  final double overdueRecoveryScore;
  final double borrowerOutreachScore;
  final double repaymentComplianceScore;
  final double vaultDisciplineScore;
  final double compositeScore;

  const ScorecardBreakdownModel({
    required this.capitalDeploymentScore,
    required this.delinquencyControlScore,
    required this.overdueRecoveryScore,
    required this.borrowerOutreachScore,
    required this.repaymentComplianceScore,
    required this.vaultDisciplineScore,
    required this.compositeScore,
  });

  factory ScorecardBreakdownModel.fromJson(Map<String, dynamic> json) {
    return ScorecardBreakdownModel(
      capitalDeploymentScore: (json['capital_deployment_score'] as num?)?.toDouble() ?? 0.0,
      delinquencyControlScore: (json['delinquency_control_score'] as num?)?.toDouble() ?? 0.0,
      overdueRecoveryScore: (json['overdue_recovery_score'] as num?)?.toDouble() ?? 0.0,
      borrowerOutreachScore: (json['borrower_outreach_score'] as num?)?.toDouble() ?? 0.0,
      repaymentComplianceScore: (json['repayment_compliance_score'] as num?)?.toDouble() ?? 0.0,
      vaultDisciplineScore: (json['vault_discipline_score'] as num?)?.toDouble() ?? 0.0,
      compositeScore: (json['composite_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

@immutable
class OfficerPerformanceItemModel {
  final int rank;
  final String officerId;
  final String officerName;
  final String officerUsername;
  final String branchId;
  final String branchName;
  final int activeClients;
  final double activeCredit;
  final double disbPrincipal;
  final int disbCount;
  final double overdueAmount;
  final double parPct;
  final int defaultersCount;
  final double overdueRecovered;
  final int fullRecoveriesCount;
  final double collectedAmount;
  final double compliancePct;
  final double compositeScore;

  const OfficerPerformanceItemModel({
    required this.rank,
    required this.officerId,
    required this.officerName,
    required this.officerUsername,
    required this.branchId,
    required this.branchName,
    required this.activeClients,
    required this.activeCredit,
    required this.disbPrincipal,
    required this.disbCount,
    required this.overdueAmount,
    required this.parPct,
    required this.defaultersCount,
    required this.overdueRecovered,
    required this.fullRecoveriesCount,
    required this.collectedAmount,
    required this.compliancePct,
    required this.compositeScore,
  });

  factory OfficerPerformanceItemModel.fromJson(Map<String, dynamic> json) {
    return OfficerPerformanceItemModel(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      officerId: json['officer_id']?.toString() ?? '',
      officerName: json['officer_name']?.toString() ?? 'Officer',
      officerUsername: json['officer_username']?.toString() ?? 'CO',
      branchId: json['branch_id']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? 'Branch',
      activeClients: (json['active_clients'] as num?)?.toInt() ?? 0,
      activeCredit: (json['active_credit'] as num?)?.toDouble() ?? 0.0,
      disbPrincipal: (json['disb_principal'] as num?)?.toDouble() ?? 0.0,
      disbCount: (json['disb_count'] as num?)?.toInt() ?? 0,
      overdueAmount: (json['overdue_amount'] as num?)?.toDouble() ?? 0.0,
      parPct: (json['par_pct'] as num?)?.toDouble() ?? 0.0,
      defaultersCount: (json['defaulters_count'] as num?)?.toInt() ?? 0,
      overdueRecovered: (json['overdue_recovered'] as num?)?.toDouble() ?? 0.0,
      fullRecoveriesCount: (json['full_recoveries_count'] as num?)?.toInt() ?? 0,
      collectedAmount: (json['collected_amount'] as num?)?.toDouble() ?? 0.0,
      compliancePct: (json['compliance_pct'] as num?)?.toDouble() ?? 95.0,
      compositeScore: (json['composite_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

@immutable
class AdminRiskHealthModel {
  final double parPct;
  final double totalActiveCredit;
  final double totalOverdueRecovered;
  final int recoveryEventsCount;
  final int fullClientRestorations;
  final double fullPayoffsSettledAmount;
  final int fullPayoffCount;
  final double excessCashCollected;
  final String projectionEngineStatus;
  final int pendingEventBacklog;
  final String offlineDeviceSyncStatus;
  final String databaseCluster;
  final String immutableAuditState;

  const AdminRiskHealthModel({
    required this.parPct,
    required this.totalActiveCredit,
    required this.totalOverdueRecovered,
    required this.recoveryEventsCount,
    required this.fullClientRestorations,
    required this.fullPayoffsSettledAmount,
    required this.fullPayoffCount,
    required this.excessCashCollected,
    required this.projectionEngineStatus,
    required this.pendingEventBacklog,
    required this.offlineDeviceSyncStatus,
    required this.databaseCluster,
    required this.immutableAuditState,
  });

  factory AdminRiskHealthModel.fromJson(Map<String, dynamic> json) {
    final ri = json['risk_indicators'] as Map<String, dynamic>? ?? {};
    final rec = ri['recovery_overview'] as Map<String, dynamic>? ?? {};
    final set = ri['settlement_overview'] as Map<String, dynamic>? ?? {};
    final eng = json['engine_health'] as Map<String, dynamic>? ?? {};

    return AdminRiskHealthModel(
      parPct: (ri['par_pct'] as num?)?.toDouble() ?? 0.0,
      totalActiveCredit: (ri['total_active_credit'] as num?)?.toDouble() ?? 0.0,
      totalOverdueRecovered: (rec['total_overdue_recovered'] as num?)?.toDouble() ?? 0.0,
      recoveryEventsCount: (rec['recovery_events_count'] as num?)?.toInt() ?? 0,
      fullClientRestorations: (rec['full_client_restorations'] as num?)?.toInt() ?? 0,
      fullPayoffsSettledAmount: (set['full_payoffs_settled_amount'] as num?)?.toDouble() ?? 0.0,
      fullPayoffCount: (set['full_payoff_count'] as num?)?.toInt() ?? 0,
      excessCashCollected: (set['excess_cash_collected'] as num?)?.toDouble() ?? 0.0,
      projectionEngineStatus: eng['projection_engine_status']?.toString() ?? 'Synchronized',
      pendingEventBacklog: (eng['pending_event_backlog'] as num?)?.toInt() ?? 0,
      offlineDeviceSyncStatus: eng['offline_device_sync_status']?.toString() ?? 'Active',
      databaseCluster: eng['database_cluster']?.toString() ?? 'Supabase Managed',
      immutableAuditState: eng['immutable_audit_state']?.toString() ?? 'Enforced',
    );
  }
}

@immutable
class BusinessDateStatusModel {
  final bool isWorkingDay;
  final String statusReason;
  final String nextWorkingDay;

  const BusinessDateStatusModel({
    required this.isWorkingDay,
    required this.statusReason,
    required this.nextWorkingDay,
  });

  factory BusinessDateStatusModel.fromJson(Map<String, dynamic> json) {
    return BusinessDateStatusModel(
      isWorkingDay: json['is_working_day'] as bool? ?? true,
      statusReason: json['status_reason']?.toString() ?? 'Valid working day',
      nextWorkingDay: json['next_working_day']?.toString() ?? '',
    );
  }
}

@immutable
class InstitutionalOverviewModel {
  final int totalClientsCount;
  final String totalClientsDisplay;
  final int activeBranchesCount;
  final double totalPortfolio;
  final double todayCollections;

  const InstitutionalOverviewModel({
    required this.totalClientsCount,
    required this.totalClientsDisplay,
    required this.activeBranchesCount,
    required this.totalPortfolio,
    required this.todayCollections,
  });

  factory InstitutionalOverviewModel.fromJson(Map<String, dynamic> json) {
    return InstitutionalOverviewModel(
      totalClientsCount: (json['total_clients_count'] as num?)?.toInt() ?? 0,
      totalClientsDisplay: json['total_clients_display']?.toString() ?? '10,000+',
      activeBranchesCount: (json['active_branches_count'] as num?)?.toInt() ?? 0,
      totalPortfolio: (json['total_portfolio'] as num?)?.toDouble() ?? 0.0,
      todayCollections: (json['today_collections'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

@immutable
class FinancialActivityDayModel {
  final String day;
  final String date;
  final bool isWorkingDay;
  final String statusReason;
  final double collections;
  final double disbursements;

  const FinancialActivityDayModel({
    required this.day,
    required this.date,
    required this.isWorkingDay,
    required this.statusReason,
    required this.collections,
    required this.disbursements,
  });

  factory FinancialActivityDayModel.fromJson(Map<String, dynamic> json) {
    return FinancialActivityDayModel(
      day: json['day']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      isWorkingDay: json['is_working_day'] as bool? ?? true,
      statusReason: json['status_reason']?.toString() ?? '',
      collections: (json['collections'] as num?)?.toDouble() ?? 0.0,
      disbursements: (json['disbursements'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

@immutable
class BranchPerformanceRowModel {
  final String branchId;
  final String branchName;
  final double volume;
  final double relativePct;
  final double vaultCash;
  final String managerName;
  final String status;
  final bool isHeadOffice;

  const BranchPerformanceRowModel({
    required this.branchId,
    required this.branchName,
    required this.volume,
    required this.relativePct,
    required this.vaultCash,
    required this.managerName,
    required this.status,
    this.isHeadOffice = false,
  });

  factory BranchPerformanceRowModel.fromJson(Map<String, dynamic> json) {
    final name = json['branch_name']?.toString() ?? 'Branch';
    final isHo = json['is_head_office'] as bool? ??
        (name.trim().toLowerCase().contains('head office') || name.trim().toLowerCase().contains('headquarters'));
    return BranchPerformanceRowModel(
      branchId: json['branch_id']?.toString() ?? '',
      branchName: name,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
      relativePct: (json['relative_pct'] as num?)?.toDouble() ?? 0.0,
      vaultCash: (json['vault_cash'] as num?)?.toDouble() ?? 0.0,
      managerName: json['manager_name']?.toString() ?? 'Branch Manager',
      status: json['status']?.toString() ?? 'OPEN',
      isHeadOffice: isHo,
    );
  }
}

@immutable
class BranchOfficerSummaryModel {
  final String officerId;
  final String name;
  final String username;

  const BranchOfficerSummaryModel({
    required this.officerId,
    required this.name,
    required this.username,
  });

  factory BranchOfficerSummaryModel.fromJson(Map<String, dynamic> json) {
    return BranchOfficerSummaryModel(
      officerId: json['officer_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Officer',
      username: json['username']?.toString() ?? '',
    );
  }
}

@immutable
class AdminBranchDetailModel {
  final String branchId;
  final String branchName;
  final String managerName;
  final String operationalStatus;
  final double vaultCashInCustody;
  final double activeCreditBook;
  final int activeBorrowersCount;
  final double todayCollections;
  final double overdueAmount;
  final double parPct;
  final int defaultersCount;
  final double overdueRecovered;
  final int fullRecoveriesCount;
  final double totalDisbursedYtd;
  final int totalDisbursedCount;
  final int officersCount;
  final List<BranchOfficerSummaryModel> officers;

  const AdminBranchDetailModel({
    required this.branchId,
    required this.branchName,
    required this.managerName,
    required this.operationalStatus,
    required this.vaultCashInCustody,
    required this.activeCreditBook,
    required this.activeBorrowersCount,
    required this.todayCollections,
    required this.overdueAmount,
    required this.parPct,
    required this.defaultersCount,
    required this.overdueRecovered,
    required this.fullRecoveriesCount,
    required this.totalDisbursedYtd,
    required this.totalDisbursedCount,
    required this.officersCount,
    required this.officers,
  });

  factory AdminBranchDetailModel.fromJson(Map<String, dynamic> json) {
    final offList = (json['officers'] as List<dynamic>? ?? [])
        .map((e) => BranchOfficerSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return AdminBranchDetailModel(
      branchId: json['branch_id']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? 'Branch',
      managerName: json['manager_name']?.toString() ?? 'Branch Manager',
      operationalStatus: json['operational_status']?.toString() ?? 'OPEN',
      vaultCashInCustody: (json['vault_cash_in_custody'] as num?)?.toDouble() ?? 0.0,
      activeCreditBook: (json['active_credit_book'] as num?)?.toDouble() ?? 0.0,
      activeBorrowersCount: (json['active_borrowers_count'] as num?)?.toInt() ?? 0,
      todayCollections: (json['today_collections'] as num?)?.toDouble() ?? 0.0,
      overdueAmount: (json['overdue_amount'] as num?)?.toDouble() ?? 0.0,
      parPct: (json['par_pct'] as num?)?.toDouble() ?? 0.0,
      defaultersCount: (json['defaulters_count'] as num?)?.toInt() ?? 0,
      overdueRecovered: (json['overdue_recovered'] as num?)?.toDouble() ?? 0.0,
      fullRecoveriesCount: (json['full_recoveries_count'] as num?)?.toInt() ?? 0,
      totalDisbursedYtd: (json['total_disbursed_ytd'] as num?)?.toDouble() ?? 0.0,
      totalDisbursedCount: (json['total_disbursed_count'] as num?)?.toInt() ?? 0,
      officersCount: (json['officers_count'] as num?)?.toInt() ?? offList.length,
      officers: offList,
    );
  }
}
