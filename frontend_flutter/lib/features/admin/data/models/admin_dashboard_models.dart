import 'package:flutter/foundation.dart';

@immutable
class AdminOperationsSnapshotModel {
  final String businessDate;
  final double vaultCashInCustody;
  final double todayCollections;
  final double todayDisbursements;
  final int todayDisbursedCount;
  final double todaySavingsDeposit;
  final double todaySavingsWithdrawal;
  final double todayNetSavings;
  final double collectionCompliancePct;
  final List<BranchOperationalStatusModel> branchMatrix;
  final int pendingReversalsCount;
  final List<PendingReversalItemModel> pendingReversals;
  final int pendingHighLoansCount;
  final List<PendingHighLoanItemModel> pendingHighLoans;

  const AdminOperationsSnapshotModel({
    required this.businessDate,
    required this.vaultCashInCustody,
    required this.todayCollections,
    required this.todayDisbursements,
    required this.todayDisbursedCount,
    required this.todaySavingsDeposit,
    required this.todaySavingsWithdrawal,
    required this.todayNetSavings,
    required this.collectionCompliancePct,
    required this.branchMatrix,
    required this.pendingReversalsCount,
    required this.pendingReversals,
    required this.pendingHighLoansCount,
    required this.pendingHighLoans,
  });

  factory AdminOperationsSnapshotModel.fromJson(Map<String, dynamic> json) {
    final liq = json['liquidity'] as Map<String, dynamic>? ?? {};
    final ac = json['action_center'] as Map<String, dynamic>? ?? {};

    final bList = (json['branch_matrix'] as List<dynamic>? ?? [])
        .map((e) => BranchOperationalStatusModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final rList = (ac['pending_reversals'] as List<dynamic>? ?? [])
        .map((e) => PendingReversalItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final hlList = (ac['pending_high_loans'] as List<dynamic>? ?? [])
        .map((e) => PendingHighLoanItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return AdminOperationsSnapshotModel(
      businessDate: json['business_date']?.toString() ?? '',
      vaultCashInCustody: (liq['vault_cash_in_custody'] as num?)?.toDouble() ?? 0.0,
      todayCollections: (liq['today_collections'] as num?)?.toDouble() ?? 0.0,
      todayDisbursements: (liq['today_disbursements'] as num?)?.toDouble() ?? 0.0,
      todayDisbursedCount: (liq['today_disbursed_count'] as num?)?.toInt() ?? 0,
      todaySavingsDeposit: (liq['today_savings_deposit'] as num?)?.toDouble() ?? 0.0,
      todaySavingsWithdrawal: (liq['today_savings_withdrawal'] as num?)?.toDouble() ?? 0.0,
      todayNetSavings: (liq['today_net_savings'] as num?)?.toDouble() ?? 0.0,
      collectionCompliancePct: (liq['collection_compliance_pct'] as num?)?.toDouble() ?? 95.0,
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

  const BranchOperationalStatusModel({
    required this.branchId,
    required this.branchName,
    required this.branchCode,
    required this.managerName,
    required this.operationalStatus,
    required this.vaultCash,
    required this.todayCollected,
  });

  factory BranchOperationalStatusModel.fromJson(Map<String, dynamic> json) {
    return BranchOperationalStatusModel(
      branchId: json['branch_id']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? 'Branch',
      branchCode: json['branch_code']?.toString() ?? '',
      managerName: json['manager_name']?.toString() ?? 'Manager',
      operationalStatus: json['operational_status']?.toString() ?? 'OPEN',
      vaultCash: (json['vault_cash'] as num?)?.toDouble() ?? 0.0,
      todayCollected: (json['today_collected'] as num?)?.toDouble() ?? 0.0,
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

  const InstitutionPerformanceModel({
    required this.year,
    required this.branchRankings,
    required this.officerRankings,
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

    return InstitutionPerformanceModel(
      year: (json['year'] as num?)?.toInt() ?? 2026,
      branchRankings: bList,
      officerRankings: oList,
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
