// Dart Data Models for Phase 9: Audit Ledger & Audit Center.
// Matches api/schemas/audit.py schemas with null-safety and robust JSON parsing.

class BranchOptionModel {
  final String branchId;
  final String name;
  final String? code;

  BranchOptionModel({
    required this.branchId,
    required this.name,
    this.code,
  });

  factory BranchOptionModel.fromJson(Map<String, dynamic> json) {
    return BranchOptionModel(
      branchId: json['branch_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
    );
  }
}

class OfficerOptionModel {
  final String id;
  final String username;
  final String fullName;
  final String displayName;
  final String? role;

  OfficerOptionModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.displayName,
    this.role,
  });

  factory OfficerOptionModel.fromJson(Map<String, dynamic> json) {
    return OfficerOptionModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      role: json['role']?.toString(),
    );
  }
}

class ProductOptionModel {
  final String productId;
  final String name;
  final String? code;

  ProductOptionModel({
    required this.productId,
    required this.name,
    this.code,
  });

  factory ProductOptionModel.fromJson(Map<String, dynamic> json) {
    return ProductOptionModel(
      productId: json['product_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
    );
  }
}

class AuditMetaModel {
  final List<BranchOptionModel> branches;
  final List<OfficerOptionModel> officers;
  final List<ProductOptionModel> products;

  AuditMetaModel({
    required this.branches,
    required this.officers,
    required this.products,
  });

  factory AuditMetaModel.fromJson(Map<String, dynamic> json) {
    return AuditMetaModel(
      branches: (json['branches'] as List<dynamic>?)
              ?.map((e) => BranchOptionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      officers: (json['officers'] as List<dynamic>?)
              ?.map((e) => OfficerOptionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      products: (json['products'] as List<dynamic>?)
              ?.map((e) => ProductOptionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class VarianceItemModel {
  final String source;
  final double expected;
  final double actual;
  final double variance;
  final String cause;

  VarianceItemModel({
    required this.source,
    required this.expected,
    required this.actual,
    required this.variance,
    required this.cause,
  });

  factory VarianceItemModel.fromJson(Map<String, dynamic> json) {
    return VarianceItemModel(
      source: json['source']?.toString() ?? '',
      expected: (json['expected'] as num?)?.toDouble() ?? 0.0,
      actual: (json['actual'] as num?)?.toDouble() ?? 0.0,
      variance: (json['variance'] as num?)?.toDouble() ?? 0.0,
      cause: json['cause']?.toString() ?? '',
    );
  }
}

class Integrity6WayModel {
  final String branchId;
  final String postingDate;
  final bool isBalanced;
  final String statusText;
  final String statusBadge;
  final double ledgerTotal;
  final double auditViewsTotal;
  final double coCashbooksTotal;
  final double masterCashbookTotal;
  final double dashboardTotal;
  final double reportsTotal;
  final List<VarianceItemModel> variances;

  Integrity6WayModel({
    required this.branchId,
    required this.postingDate,
    required this.isBalanced,
    required this.statusText,
    required this.statusBadge,
    required this.ledgerTotal,
    required this.auditViewsTotal,
    required this.coCashbooksTotal,
    required this.masterCashbookTotal,
    required this.dashboardTotal,
    required this.reportsTotal,
    required this.variances,
  });

  factory Integrity6WayModel.fromJson(Map<String, dynamic> json) {
    return Integrity6WayModel(
      branchId: json['branch_id']?.toString() ?? '',
      postingDate: json['posting_date']?.toString() ?? '',
      isBalanced: json['is_balanced'] == true,
      statusText: json['status_text']?.toString() ?? '',
      statusBadge: json['status_badge']?.toString() ?? 'MISMATCH',
      ledgerTotal: (json['ledger_total'] as num?)?.toDouble() ?? 0.0,
      auditViewsTotal: (json['audit_views_total'] as num?)?.toDouble() ?? 0.0,
      coCashbooksTotal: (json['co_cashbooks_total'] as num?)?.toDouble() ?? 0.0,
      masterCashbookTotal: (json['master_cashbook_total'] as num?)?.toDouble() ?? 0.0,
      dashboardTotal: (json['dashboard_total'] as num?)?.toDouble() ?? 0.0,
      reportsTotal: (json['reports_total'] as num?)?.toDouble() ?? 0.0,
      variances: (json['variances'] as List<dynamic>?)
              ?.map((e) => VarianceItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class AuditSummaryMetricsModel {
  final double totalAmount;
  final int totalCount;
  final double averageAmount;
  final String lastTransactionDate;
  final double highestAmount;

  AuditSummaryMetricsModel({
    required this.totalAmount,
    required this.totalCount,
    required this.averageAmount,
    required this.lastTransactionDate,
    required this.highestAmount,
  });

  factory AuditSummaryMetricsModel.fromJson(Map<String, dynamic> json) {
    return AuditSummaryMetricsModel(
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      averageAmount: (json['average_amount'] as num?)?.toDouble() ?? 0.0,
      lastTransactionDate: json['last_transaction_date']?.toString() ?? 'N/A',
      highestAmount: (json['highest_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FeeLedgerResponseModel {
  final AuditSummaryMetricsModel metrics;
  final List<Map<String, dynamic>> records;

  FeeLedgerResponseModel({
    required this.metrics,
    required this.records,
  });

  factory FeeLedgerResponseModel.fromJson(Map<String, dynamic> json) {
    return FeeLedgerResponseModel(
      metrics: AuditSummaryMetricsModel.fromJson(json['metrics'] as Map<String, dynamic>? ?? {}),
      records: (json['records'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class TreasuryLedgerResponseModel {
  final AuditSummaryMetricsModel metrics;
  final List<Map<String, dynamic>> records;

  TreasuryLedgerResponseModel({
    required this.metrics,
    required this.records,
  });

  factory TreasuryLedgerResponseModel.fromJson(Map<String, dynamic> json) {
    return TreasuryLedgerResponseModel(
      metrics: AuditSummaryMetricsModel.fromJson(json['metrics'] as Map<String, dynamic>? ?? {}),
      records: (json['records'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class SavingsSummaryMetricsModel {
  final double totalDeposits;
  final double totalWithdrawals;
  final double netSavingsMovement;
  final int transactionsCount;
  final int activeAccountsCount;

  SavingsSummaryMetricsModel({
    required this.totalDeposits,
    required this.totalWithdrawals,
    required this.netSavingsMovement,
    required this.transactionsCount,
    required this.activeAccountsCount,
  });

  factory SavingsSummaryMetricsModel.fromJson(Map<String, dynamic> json) {
    return SavingsSummaryMetricsModel(
      totalDeposits: (json['total_deposits'] as num?)?.toDouble() ?? 0.0,
      totalWithdrawals: (json['total_withdrawals'] as num?)?.toDouble() ?? 0.0,
      netSavingsMovement: (json['net_savings_movement'] as num?)?.toDouble() ?? 0.0,
      transactionsCount: (json['transactions_count'] as num?)?.toInt() ?? 0,
      activeAccountsCount: (json['active_accounts_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class SavingsLedgerResponseModel {
  final SavingsSummaryMetricsModel metrics;
  final List<Map<String, dynamic>> records;

  SavingsLedgerResponseModel({
    required this.metrics,
    required this.records,
  });

  factory SavingsLedgerResponseModel.fromJson(Map<String, dynamic> json) {
    return SavingsLedgerResponseModel(
      metrics: SavingsSummaryMetricsModel.fromJson(json['metrics'] as Map<String, dynamic>? ?? {}),
      records: (json['records'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class LoanDisbursementMetricsModel {
  final double totalPrincipalDisbursed;
  final int loansDisbursed;
  final double averagePrincipal;
  final int borrowersCount;
  final double activePortfolio;

  LoanDisbursementMetricsModel({
    required this.totalPrincipalDisbursed,
    required this.loansDisbursed,
    required this.averagePrincipal,
    required this.borrowersCount,
    required this.activePortfolio,
  });

  factory LoanDisbursementMetricsModel.fromJson(Map<String, dynamic> json) {
    return LoanDisbursementMetricsModel(
      totalPrincipalDisbursed: (json['total_principal_disbursed'] as num?)?.toDouble() ?? 0.0,
      loansDisbursed: (json['loans_disbursed'] as num?)?.toInt() ?? 0,
      averagePrincipal: (json['average_principal'] as num?)?.toDouble() ?? 0.0,
      borrowersCount: (json['borrowers_count'] as num?)?.toInt() ?? 0,
      activePortfolio: (json['active_portfolio'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LoanRepaymentMetricsModel {
  final double totalRepaymentsCollected;
  final int repaymentCount;
  final double averageRepayment;
  final int activePayingClients;

  LoanRepaymentMetricsModel({
    required this.totalRepaymentsCollected,
    required this.repaymentCount,
    required this.averageRepayment,
    required this.activePayingClients,
  });

  factory LoanRepaymentMetricsModel.fromJson(Map<String, dynamic> json) {
    return LoanRepaymentMetricsModel(
      totalRepaymentsCollected: (json['total_repayments_collected'] as num?)?.toDouble() ?? 0.0,
      repaymentCount: (json['repayment_count'] as num?)?.toInt() ?? 0,
      averageRepayment: (json['average_repayment'] as num?)?.toDouble() ?? 0.0,
      activePayingClients: (json['active_paying_clients'] as num?)?.toInt() ?? 0,
    );
  }
}

class LoanLedgerResponseModel {
  final String viewType;
  final LoanDisbursementMetricsModel? disbursementMetrics;
  final LoanRepaymentMetricsModel? repaymentMetrics;
  final List<Map<String, dynamic>> records;

  LoanLedgerResponseModel({
    required this.viewType,
    this.disbursementMetrics,
    this.repaymentMetrics,
    required this.records,
  });

  factory LoanLedgerResponseModel.fromJson(Map<String, dynamic> json) {
    return LoanLedgerResponseModel(
      viewType: json['view_type']?.toString() ?? 'Loan Disbursements',
      disbursementMetrics: json['disbursement_metrics'] != null
          ? LoanDisbursementMetricsModel.fromJson(json['disbursement_metrics'] as Map<String, dynamic>)
          : null,
      repaymentMetrics: json['repayment_metrics'] != null
          ? LoanRepaymentMetricsModel.fromJson(json['repayment_metrics'] as Map<String, dynamic>)
          : null,
      records: (json['records'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class CollectionPerformanceMetricsModel {
  final double expectedCollections;
  final double actualCollections;
  final double collectionVariance;
  final double meetingComplianceRatio;
  final int meetingsAudited;
  final int paidCount;

  CollectionPerformanceMetricsModel({
    required this.expectedCollections,
    required this.actualCollections,
    required this.collectionVariance,
    required this.meetingComplianceRatio,
    required this.meetingsAudited,
    required this.paidCount,
  });

  factory CollectionPerformanceMetricsModel.fromJson(Map<String, dynamic> json) {
    return CollectionPerformanceMetricsModel(
      expectedCollections: (json['expected_collections'] as num?)?.toDouble() ?? 0.0,
      actualCollections: (json['actual_collections'] as num?)?.toDouble() ?? 0.0,
      collectionVariance: (json['collection_variance'] as num?)?.toDouble() ?? 0.0,
      meetingComplianceRatio: (json['meeting_compliance_ratio'] as num?)?.toDouble() ?? 0.0,
      meetingsAudited: (json['meetings_audited'] as num?)?.toInt() ?? 0,
      paidCount: (json['paid_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CollectionPerformanceResponseModel {
  final CollectionPerformanceMetricsModel metrics;
  final List<Map<String, dynamic>> records;

  CollectionPerformanceResponseModel({
    required this.metrics,
    required this.records,
  });

  factory CollectionPerformanceResponseModel.fromJson(Map<String, dynamic> json) {
    return CollectionPerformanceResponseModel(
      metrics: CollectionPerformanceMetricsModel.fromJson(json['metrics'] as Map<String, dynamic>? ?? {}),
      records: (json['records'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class ExceptionReportsResponseModel {
  final int totalExceptions;
  final int exceptionRulesEvaluated;
  final Map<String, List<Map<String, dynamic>>> details;

  ExceptionReportsResponseModel({
    required this.totalExceptions,
    required this.exceptionRulesEvaluated,
    required this.details,
  });

  factory ExceptionReportsResponseModel.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'] as Map<String, dynamic>? ?? {};
    final parsedDetails = <String, List<Map<String, dynamic>>>{};
    rawDetails.forEach((key, value) {
      if (value is List) {
        parsedDetails[key] = value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        parsedDetails[key] = [];
      }
    });

    return ExceptionReportsResponseModel(
      totalExceptions: (json['total_exceptions'] as num?)?.toInt() ?? 0,
      exceptionRulesEvaluated: (json['exception_rules_evaluated'] as num?)?.toInt() ?? 15,
      details: parsedDetails,
    );
  }
}

class UniversalExplorerResponseModel {
  final String query;
  final bool found;
  final List<Map<String, dynamic>> loans;
  final List<Map<String, dynamic>> repayments;
  final List<Map<String, dynamic>> savings;
  final List<Map<String, dynamic>> fees;
  final List<Map<String, dynamic>> treasuryTransactions;
  final List<Map<String, dynamic>> ledgerTransactions;
  final List<Map<String, dynamic>> auditLogs;

  UniversalExplorerResponseModel({
    required this.query,
    required this.found,
    required this.loans,
    required this.repayments,
    required this.savings,
    required this.fees,
    required this.treasuryTransactions,
    required this.ledgerTransactions,
    required this.auditLogs,
  });

  factory UniversalExplorerResponseModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    }

    return UniversalExplorerResponseModel(
      query: json['query']?.toString() ?? '',
      found: json['found'] == true,
      loans: parseList(json['loans']),
      repayments: parseList(json['repayments']),
      savings: parseList(json['savings']),
      fees: parseList(json['fees']),
      treasuryTransactions: parseList(json['treasury_transactions']),
      ledgerTransactions: parseList(json['ledger_transactions']),
      auditLogs: parseList(json['audit_logs']),
    );
  }
}

class LoanTimelineResponseModel {
  final String loanId;
  final List<Map<String, dynamic>> timeline;

  LoanTimelineResponseModel({
    required this.loanId,
    required this.timeline,
  });

  factory LoanTimelineResponseModel.fromJson(Map<String, dynamic> json) {
    return LoanTimelineResponseModel(
      loanId: json['loan_id']?.toString() ?? '',
      timeline: (json['timeline'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class RiskDistributionResponseModel {
  final String branchId;
  final Map<String, int> distribution;

  RiskDistributionResponseModel({
    required this.branchId,
    required this.distribution,
  });

  factory RiskDistributionResponseModel.fromJson(Map<String, dynamic> json) {
    final rawDist = json['distribution'] as Map<String, dynamic>? ?? {};
    final dist = <String, int>{};
    rawDist.forEach((key, val) {
      dist[key] = (val as num?)?.toInt() ?? 0;
    });
    return RiskDistributionResponseModel(
      branchId: json['branch_id']?.toString() ?? '',
      distribution: dist,
    );
  }
}

class ReconciliationRepairResponseModel {
  final int rebuiltOfficerCount;
  final bool masterCashbookRebuilt;
  final Integrity6WayModel verificationAfterRepair;

  ReconciliationRepairResponseModel({
    required this.rebuiltOfficerCount,
    required this.masterCashbookRebuilt,
    required this.verificationAfterRepair,
  });

  factory ReconciliationRepairResponseModel.fromJson(Map<String, dynamic> json) {
    return ReconciliationRepairResponseModel(
      rebuiltOfficerCount: (json['rebuilt_officer_count'] as num?)?.toInt() ?? 0,
      masterCashbookRebuilt: json['master_cashbook_rebuilt'] == true,
      verificationAfterRepair: Integrity6WayModel.fromJson(
        json['verification_after_repair'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
