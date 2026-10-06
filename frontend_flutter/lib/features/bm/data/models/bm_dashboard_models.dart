/// BM Dashboard data models.
/// Mirrors `api/schemas/bm_dashboard.py` and Streamlit app.py L2560–3138.
class BranchSummaryModel {
  final int activeClients;
  final int activeLoans;
  final double activeSavings;
  final double collectionToday;
  final String par;

  BranchSummaryModel({
    required this.activeClients,
    required this.activeLoans,
    required this.activeSavings,
    required this.collectionToday,
    required this.par,
  });

  factory BranchSummaryModel.fromJson(Map<String, dynamic> json) {
    return BranchSummaryModel(
      activeClients: (json['active_clients'] as num?)?.toInt() ?? 0,
      activeLoans: (json['active_loans'] as num?)?.toInt() ?? 0,
      activeSavings: (json['active_savings'] as num?)?.toDouble() ?? 0.0,
      collectionToday: (json['collection_today'] as num?)?.toDouble() ?? 0.0,
      par: json['par']?.toString() ?? '0.0%',
    );
  }
}

class BranchCashPositionModel {
  final double openingBalance;
  final double cashIn;
  final double cashOut;
  final double bankDeposit;
  final double bankWithdrawal;
  final double closingBalance;
  final String status;
  final double difference;

  BranchCashPositionModel({
    required this.openingBalance,
    required this.cashIn,
    required this.cashOut,
    required this.bankDeposit,
    required this.bankWithdrawal,
    required this.closingBalance,
    required this.status,
    required this.difference,
  });

  factory BranchCashPositionModel.fromJson(Map<String, dynamic> json) {
    return BranchCashPositionModel(
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0.0,
      cashIn: (json['cash_in'] as num?)?.toDouble() ?? 0.0,
      cashOut: (json['cash_out'] as num?)?.toDouble() ?? 0.0,
      bankDeposit: (json['bank_deposit'] as num?)?.toDouble() ?? 0.0,
      bankWithdrawal: (json['bank_withdrawal'] as num?)?.toDouble() ?? 0.0,
      closingBalance: (json['closing_balance'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Balanced',
      difference: (json['difference'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OfficerCollectionStatusModel {
  final String officer;
  final String officerName;
  final int groupsScheduled;
  final String scheduledGroups;
  final double expected;
  final double collected;
  final double outstanding;
  final double compliancePct;
  final double closingBalance;
  final String status;

  OfficerCollectionStatusModel({
    required this.officer,
    required this.officerName,
    required this.groupsScheduled,
    required this.scheduledGroups,
    required this.expected,
    required this.collected,
    required this.outstanding,
    required this.compliancePct,
    required this.closingBalance,
    required this.status,
  });

  factory OfficerCollectionStatusModel.fromJson(Map<String, dynamic> json) {
    return OfficerCollectionStatusModel(
      officer: json['officer']?.toString() ?? '',
      officerName: json['officer_name']?.toString() ?? '',
      groupsScheduled: (json['groups_scheduled'] as num?)?.toInt() ?? 0,
      scheduledGroups: json['scheduled_groups']?.toString() ?? 'None Scheduled',
      expected: (json['expected'] as num?)?.toDouble() ?? 0.0,
      collected: (json['collected'] as num?)?.toDouble() ?? 0.0,
      outstanding: (json['outstanding'] as num?)?.toDouble() ?? 0.0,
      compliancePct: (json['compliance_pct'] as num?)?.toDouble() ?? 0.0,
      closingBalance: (json['closing_balance'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Normal',
    );
  }
}

class PendingLoanApprovalModel {
  final String loanId;
  final String clientName;
  final String clientCode;
  final String officer;
  final String loanProduct;
  final double loanAmount;
  final String? disbursementDate;

  PendingLoanApprovalModel({
    required this.loanId,
    required this.clientName,
    required this.clientCode,
    required this.officer,
    required this.loanProduct,
    required this.loanAmount,
    this.disbursementDate,
  });

  factory PendingLoanApprovalModel.fromJson(Map<String, dynamic> json) {
    return PendingLoanApprovalModel(
      loanId: json['loan_id']?.toString() ?? '',
      clientName: json['client_name']?.toString() ?? '',
      clientCode: json['client_code']?.toString() ?? '',
      officer: json['officer']?.toString() ?? '',
      loanProduct: json['loan_product']?.toString() ?? '',
      loanAmount: (json['loan_amount'] as num?)?.toDouble() ?? 0.0,
      disbursementDate: json['disbursement_date']?.toString(),
    );
  }
}

class PendingWithdrawalApprovalModel {
  final String id;
  final String? clientId;
  final String clientName;
  final String? groupName;
  final String savingsType;
  final String operationType;
  final double amount;
  final String requestedBy;
  final String? reference;
  final String? remarks;
  final String? operationalDate;
  final String? createdAt;

  PendingWithdrawalApprovalModel({
    required this.id,
    this.clientId,
    required this.clientName,
    this.groupName,
    required this.savingsType,
    required this.operationType,
    required this.amount,
    required this.requestedBy,
    this.reference,
    this.remarks,
    this.operationalDate,
    this.createdAt,
  });

  factory PendingWithdrawalApprovalModel.fromJson(Map<String, dynamic> json) {
    return PendingWithdrawalApprovalModel(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString(),
      clientName: json['client_name']?.toString() ?? '',
      groupName: json['group_name']?.toString(),
      savingsType: json['savings_type']?.toString() ?? 'Individual',
      operationType: json['operation_type']?.toString() ?? 'Cash Withdrawal',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      requestedBy: json['requested_by']?.toString() ?? 'Officer',
      reference: json['reference']?.toString(),
      remarks: json['remarks']?.toString(),
      operationalDate: json['operational_date']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class PendingCorrectionApprovalModel {
  final String id;
  final String recordId;
  final String recordType;
  final String reason;
  final String requestedBy;
  final String? createdAt;

  PendingCorrectionApprovalModel({
    required this.id,
    required this.recordId,
    required this.recordType,
    required this.reason,
    required this.requestedBy,
    this.createdAt,
  });

  factory PendingCorrectionApprovalModel.fromJson(Map<String, dynamic> json) {
    return PendingCorrectionApprovalModel(
      id: json['id']?.toString() ?? '',
      recordId: json['record_id']?.toString() ?? '',
      recordType: json['record_type']?.toString() ?? 'Transaction',
      reason: json['reason']?.toString() ?? '',
      requestedBy: json['requested_by']?.toString() ?? 'Officer',
      createdAt: json['created_at']?.toString(),
    );
  }
}

class BmDashboardDataModel {
  final String branchName;
  final String businessDate;
  final String meetingDay;
  final bool isClosed;
  final String closureReason;
  final BranchSummaryModel branchSummary;
  final BranchCashPositionModel branchCashPosition;
  final List<OfficerCollectionStatusModel> officerCollectionStatus;
  final List<PendingLoanApprovalModel> pendingLoans;
  final List<PendingWithdrawalApprovalModel> pendingWithdrawals;
  final List<PendingCorrectionApprovalModel> pendingCorrections;

  BmDashboardDataModel({
    required this.branchName,
    required this.businessDate,
    required this.meetingDay,
    required this.isClosed,
    required this.closureReason,
    required this.branchSummary,
    required this.branchCashPosition,
    required this.officerCollectionStatus,
    required this.pendingLoans,
    required this.pendingWithdrawals,
    required this.pendingCorrections,
  });

  factory BmDashboardDataModel.fromJson(Map<String, dynamic> json) {
    return BmDashboardDataModel(
      branchName: json['branch_name']?.toString() ?? '',
      businessDate: json['business_date']?.toString() ?? '',
      meetingDay: json['meeting_day']?.toString() ?? '',
      isClosed: json['is_closed'] == true,
      closureReason: json['closure_reason']?.toString() ?? '',
      branchSummary: BranchSummaryModel.fromJson(json['branch_summary'] as Map<String, dynamic>? ?? {}),
      branchCashPosition: BranchCashPositionModel.fromJson(json['branch_cash_position'] as Map<String, dynamic>? ?? {}),
      officerCollectionStatus: (json['officer_collection_status'] as List<dynamic>? ?? [])
          .map((e) => OfficerCollectionStatusModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingLoans: (json['pending_loans'] as List<dynamic>? ?? [])
          .map((e) => PendingLoanApprovalModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingWithdrawals: (json['pending_withdrawals'] as List<dynamic>? ?? [])
          .map((e) => PendingWithdrawalApprovalModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingCorrections: (json['pending_corrections'] as List<dynamic>? ?? [])
          .map((e) => PendingCorrectionApprovalModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
