// lib/features/am/data/models/am_dashboard_models.dart

class RegionalSummaryModel {
  final String areaName;
  final String businessDate;
  final int branchesCount;
  final int openBranchesCount;
  final int activeClients;
  final double activeCredit;
  final double outstandingPortfolio;
  final double totalSavings;
  final double todayExpected;
  final double todayCollected;
  final double compliancePct;
  final double vaultCashAcct1000;
  final String par;
  final int defaultersCount;
  final List<String> assignedBranches;

  RegionalSummaryModel({
    required this.areaName,
    required this.businessDate,
    required this.branchesCount,
    required this.openBranchesCount,
    required this.activeClients,
    required this.activeCredit,
    required this.outstandingPortfolio,
    required this.totalSavings,
    required this.todayExpected,
    required this.todayCollected,
    required this.compliancePct,
    required this.vaultCashAcct1000,
    required this.par,
    required this.defaultersCount,
    required this.assignedBranches,
  });

  factory RegionalSummaryModel.fromJson(Map<String, dynamic> json) {
    return RegionalSummaryModel(
      areaName: json['area_name'] ?? 'Area 1',
      businessDate: json['business_date'] ?? '',
      branchesCount: (json['branches_count'] as num?)?.toInt() ?? 0,
      openBranchesCount: (json['open_branches_count'] as num?)?.toInt() ?? 0,
      activeClients: (json['active_clients'] as num?)?.toInt() ?? 0,
      activeCredit: (json['active_credit'] as num?)?.toDouble() ?? 0.0,
      outstandingPortfolio: (json['outstanding_portfolio'] as num?)?.toDouble() ?? 0.0,
      totalSavings: (json['total_savings'] as num?)?.toDouble() ?? 0.0,
      todayExpected: (json['today_expected'] as num?)?.toDouble() ?? 0.0,
      todayCollected: (json['today_collected'] as num?)?.toDouble() ?? 0.0,
      compliancePct: (json['compliance_pct'] as num?)?.toDouble() ?? 0.0,
      vaultCashAcct1000: (json['vault_cash_acct_1000'] as num?)?.toDouble() ?? 0.0,
      par: json['par'] ?? '0.0%',
      defaultersCount: (json['defaulters_count'] as num?)?.toInt() ?? 0,
      assignedBranches: (json['assigned_branches'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'area_name': areaName,
    'business_date': businessDate,
    'branches_count': branchesCount,
    'open_branches_count': openBranchesCount,
    'active_clients': activeClients,
    'active_credit': activeCredit,
    'outstanding_portfolio': outstandingPortfolio,
    'total_savings': totalSavings,
    'today_expected': todayExpected,
    'today_collected': todayCollected,
    'compliance_pct': compliancePct,
    'vault_cash_acct_1000': vaultCashAcct1000,
    'par': par,
    'defaulters_count': defaultersCount,
    'assigned_branches': assignedBranches,
  };
}

class BranchPerformanceItemModel {
  final String branchId;
  final String branchName;
  final String bmName;
  final bool isClosed;
  final String? closureReason;
  final double expectedCollection;
  final double collected;
  final double outstandingToday;
  final double compliancePct;
  final double vaultCashAcct1000;
  final String par;
  final int defaultersCount;
  final double cashVariance;
  final String eodStatus;
  final String operationalStatus;

  BranchPerformanceItemModel({
    required this.branchId,
    required this.branchName,
    required this.bmName,
    required this.isClosed,
    this.closureReason,
    required this.expectedCollection,
    required this.collected,
    required this.outstandingToday,
    required this.compliancePct,
    required this.vaultCashAcct1000,
    required this.par,
    required this.defaultersCount,
    required this.cashVariance,
    required this.eodStatus,
    required this.operationalStatus,
  });

  factory BranchPerformanceItemModel.fromJson(Map<String, dynamic> json) {
    return BranchPerformanceItemModel(
      branchId: json['branch_id'] ?? '',
      branchName: json['branch_name'] ?? '',
      bmName: json['bm_name'] ?? 'Unassigned',
      isClosed: json['is_closed'] ?? false,
      closureReason: json['closure_reason'],
      expectedCollection: (json['expected_collection'] as num?)?.toDouble() ?? 0.0,
      collected: (json['collected'] as num?)?.toDouble() ?? 0.0,
      outstandingToday: (json['outstanding_today'] as num?)?.toDouble() ?? 0.0,
      compliancePct: (json['compliance_pct'] as num?)?.toDouble() ?? 100.0,
      vaultCashAcct1000: (json['vault_cash_acct_1000'] as num?)?.toDouble() ?? 0.0,
      par: json['par'] ?? '0.0%',
      defaultersCount: (json['defaulters_count'] as num?)?.toInt() ?? 0,
      cashVariance: (json['cash_variance'] as num?)?.toDouble() ?? 0.0,
      eodStatus: json['eod_status'] ?? 'PENDING',
      operationalStatus: json['operational_status'] ?? 'Normal',
    );
  }
}

class PendingHighValueLoanItemModel {
  final String loanId;
  final String branchId;
  final String branchName;
  final String clientId;
  final String clientName;
  final String clientCode;
  final String officer;
  final String loanProduct;
  final double loanAmount;
  final String applicationDate;
  final String escalationReason;

  PendingHighValueLoanItemModel({
    required this.loanId,
    required this.branchId,
    required this.branchName,
    required this.clientId,
    required this.clientName,
    required this.clientCode,
    required this.officer,
    required this.loanProduct,
    required this.loanAmount,
    required this.applicationDate,
    required this.escalationReason,
  });

  factory PendingHighValueLoanItemModel.fromJson(Map<String, dynamic> json) {
    return PendingHighValueLoanItemModel(
      loanId: json['loan_id'] ?? '',
      branchId: json['branch_id'] ?? '',
      branchName: json['branch_name'] ?? '',
      clientId: json['client_id'] ?? '',
      clientName: json['client_name'] ?? 'Unknown Client',
      clientCode: json['client_code'] ?? '',
      officer: json['officer'] ?? 'Officer',
      loanProduct: json['loan_product'] ?? 'Standard Loan',
      loanAmount: (json['loan_amount'] as num?)?.toDouble() ?? 0.0,
      applicationDate: json['application_date'] ?? '',
      escalationReason: json['escalation_reason'] ?? '',
    );
  }
}

class PendingBranchTransferItemModel {
  final String transferId;
  final String clientId;
  final String clientName;
  final String clientCode;
  final String sourceBranchId;
  final String sourceBranchName;
  final String destBranchId;
  final String destBranchName;
  final double outstandingBalance;
  final double savingsBalance;
  final String reason;
  final String requestedAt;

  PendingBranchTransferItemModel({
    required this.transferId,
    required this.clientId,
    required this.clientName,
    required this.clientCode,
    required this.sourceBranchId,
    required this.sourceBranchName,
    required this.destBranchId,
    required this.destBranchName,
    required this.outstandingBalance,
    required this.savingsBalance,
    required this.reason,
    required this.requestedAt,
  });

  factory PendingBranchTransferItemModel.fromJson(Map<String, dynamic> json) {
    return PendingBranchTransferItemModel(
      transferId: json['transfer_id'] ?? '',
      clientId: json['client_id'] ?? '',
      clientName: json['client_name'] ?? '',
      clientCode: json['client_code'] ?? '',
      sourceBranchId: json['source_branch_id'] ?? '',
      sourceBranchName: json['source_branch_name'] ?? '',
      destBranchId: json['dest_branch_id'] ?? '',
      destBranchName: json['dest_branch_name'] ?? '',
      outstandingBalance: (json['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
      savingsBalance: (json['savings_balance'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] ?? '',
      requestedAt: json['requested_at'] ?? '',
    );
  }
}

class PendingBranchEodItemModel {
  final String branchId;
  final String branchName;
  final String closureDate;
  final String masterCashbookStatus;
  final double cashVariance;
  final double vaultCash;
  final bool isConfirmed;
  final String status;
  final String? confirmedBy;
  final String? confirmedAt;
  final String? notes;

  PendingBranchEodItemModel({
    required this.branchId,
    required this.branchName,
    required this.closureDate,
    required this.masterCashbookStatus,
    required this.cashVariance,
    required this.vaultCash,
    required this.isConfirmed,
    required this.status,
    this.confirmedBy,
    this.confirmedAt,
    this.notes,
  });

  factory PendingBranchEodItemModel.fromJson(Map<String, dynamic> json) {
    return PendingBranchEodItemModel(
      branchId: json['branch_id'] ?? '',
      branchName: json['branch_name'] ?? '',
      closureDate: json['closure_date'] ?? '',
      masterCashbookStatus: json['master_cashbook_status'] ?? 'Open',
      cashVariance: (json['cash_variance'] as num?)?.toDouble() ?? 0.0,
      vaultCash: (json['vault_cash'] as num?)?.toDouble() ?? 0.0,
      isConfirmed: json['is_confirmed'] ?? false,
      status: json['status'] ?? 'PENDING',
      confirmedBy: json['confirmed_by'],
      confirmedAt: json['confirmed_at'],
      notes: json['notes'],
    );
  }
}

class AreaApprovalsHubModel {
  final List<PendingHighValueLoanItemModel> pendingHighValueLoans;
  final List<PendingBranchTransferItemModel> pendingBranchTransfers;
  final List<PendingBranchEodItemModel> pendingBranchEods;
  final bool canLockArea;

  AreaApprovalsHubModel({
    required this.pendingHighValueLoans,
    required this.pendingBranchTransfers,
    required this.pendingBranchEods,
    required this.canLockArea,
  });

  factory AreaApprovalsHubModel.fromJson(Map<String, dynamic> json) {
    return AreaApprovalsHubModel(
      pendingHighValueLoans: (json['pending_high_value_loans'] as List<dynamic>?)
              ?.map((e) => PendingHighValueLoanItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pendingBranchTransfers: (json['pending_branch_transfers'] as List<dynamic>?)
              ?.map((e) => PendingBranchTransferItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pendingBranchEods: (json['pending_branch_eods'] as List<dynamic>?)
              ?.map((e) => PendingBranchEodItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      canLockArea: json['can_lock_area'] ?? false,
    );
  }
}

class AvailableHandoverReportModel {
  final String title;
  final String format;
  final String reportType;
  final String description;
  final bool isReady;

  AvailableHandoverReportModel({
    required this.title,
    required this.format,
    required this.reportType,
    required this.description,
    required this.isReady,
  });

  factory AvailableHandoverReportModel.fromJson(Map<String, dynamic> json) {
    return AvailableHandoverReportModel(
      title: json['title'] ?? '',
      format: json['format'] ?? 'Excel (.xlsx)',
      reportType: json['report_type'] ?? '',
      description: json['description'] ?? '',
      isReady: json['is_ready'] ?? false,
    );
  }
}

class BranchHandoverSummaryModel {
  final String branchId;
  final String branchName;
  final String bmName;
  final String targetDate;
  final bool isCashbookClosed;
  final double cashVariance;
  final List<AvailableHandoverReportModel> availableReports;

  BranchHandoverSummaryModel({
    required this.branchId,
    required this.branchName,
    required this.bmName,
    required this.targetDate,
    required this.isCashbookClosed,
    required this.cashVariance,
    required this.availableReports,
  });

  factory BranchHandoverSummaryModel.fromJson(Map<String, dynamic> json) {
    return BranchHandoverSummaryModel(
      branchId: json['branch_id'] ?? '',
      branchName: json['branch_name'] ?? '',
      bmName: json['bm_name'] ?? 'Branch Manager',
      targetDate: json['target_date'] ?? '',
      isCashbookClosed: json['is_cashbook_closed'] ?? false,
      cashVariance: (json['cash_variance'] as num?)?.toDouble() ?? 0.0,
      availableReports: (json['available_reports'] as List<dynamic>?)
              ?.map((e) => AvailableHandoverReportModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class AmDashboardDataModel {
  final RegionalSummaryModel regionalSummary;
  final List<BranchPerformanceItemModel> branchPerformance;
  final AreaApprovalsHubModel approvalsHub;

  AmDashboardDataModel({
    required this.regionalSummary,
    required this.branchPerformance,
    required this.approvalsHub,
  });

  factory AmDashboardDataModel.fromJson(Map<String, dynamic> json) {
    return AmDashboardDataModel(
      regionalSummary: RegionalSummaryModel.fromJson(json['regional_summary'] as Map<String, dynamic>),
      branchPerformance: (json['branch_performance'] as List<dynamic>?)
              ?.map((e) => BranchPerformanceItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      approvalsHub: AreaApprovalsHubModel.fromJson(json['approvals_hub'] as Map<String, dynamic>),
    );
  }
}
