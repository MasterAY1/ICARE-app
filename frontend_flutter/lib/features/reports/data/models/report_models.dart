/// Report and Export Data Models for 1:1 Streamlit Parity Migration (Phase 11)
library;

class BranchOption {
  final String? branchId;
  final String name;

  const BranchOption({this.branchId, required this.name});

  factory BranchOption.fromJson(Map<String, dynamic> json) {
    return BranchOption(
      branchId: json['branch_id'] as String?,
      name: (json['name'] ?? '') as String,
    );
  }
}

class OfficerOption {
  final String userId;
  final String username;
  final String fullName;
  final String? branchId;
  final String? branchName;

  const OfficerOption({
    required this.userId,
    required this.username,
    required this.fullName,
    this.branchId,
    this.branchName,
  });

  factory OfficerOption.fromJson(Map<String, dynamic> json) {
    return OfficerOption(
      userId: (json['user_id'] ?? '') as String,
      username: (json['username'] ?? '') as String,
      fullName: (json['full_name'] ?? json['username'] ?? '') as String,
      branchId: json['branch_id'] as String?,
      branchName: json['branch_name'] as String?,
    );
  }
}

class ReportsMeta {
  final List<BranchOption> branches;
  final List<String> products;
  final List<OfficerOption> officers;
  final String? defaultBranch;
  final String scopeLevel;

  const ReportsMeta({
    required this.branches,
    required this.products,
    required this.officers,
    this.defaultBranch,
    required this.scopeLevel,
  });

  factory ReportsMeta.fromJson(Map<String, dynamic> json) {
    return ReportsMeta(
      branches: (json['branches'] as List<dynamic>? ?? [])
          .map((e) => BranchOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      officers: (json['officers'] as List<dynamic>? ?? [])
          .map((e) => OfficerOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      defaultBranch: json['default_branch'] as String?,
      scopeLevel: (json['scope_level'] ?? 'INSTITUTION') as String,
    );
  }
}

// --- TRIAL BALANCE ---

class TrialBalanceRow {
  final String accountCode;
  final String accountName;
  final String accountType;
  final String normalBalance;
  final double grossDebits;
  final double grossCredits;
  final double debitBalance;
  final double creditBalance;
  final double netPosition;

  const TrialBalanceRow({
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.normalBalance,
    required this.grossDebits,
    required this.grossCredits,
    required this.debitBalance,
    required this.creditBalance,
    required this.netPosition,
  });

  factory TrialBalanceRow.fromJson(Map<String, dynamic> json) {
    return TrialBalanceRow(
      accountCode: (json['account_code'] ?? '') as String,
      accountName: (json['account_name'] ?? '') as String,
      accountType: (json['account_type'] ?? '') as String,
      normalBalance: (json['normal_balance'] ?? 'Debit') as String,
      grossDebits: (json['gross_debits'] as num? ?? 0.0).toDouble(),
      grossCredits: (json['gross_credits'] as num? ?? 0.0).toDouble(),
      debitBalance: (json['debit_balance'] as num? ?? 0.0).toDouble(),
      creditBalance: (json['credit_balance'] as num? ?? 0.0).toDouble(),
      netPosition: (json['net_position'] as num? ?? 0.0).toDouble(),
    );
  }
}

class TrialBalanceData {
  final bool isBalanced;
  final String status;
  final double totalDebits;
  final double totalCredits;
  final double totalNetDebits;
  final double totalNetCredits;
  final double variance;
  final String? asOfDate;
  final String? startDate;
  final String? endDate;
  final List<TrialBalanceRow> rows;

  const TrialBalanceData({
    required this.isBalanced,
    required this.status,
    required this.totalDebits,
    required this.totalCredits,
    required this.totalNetDebits,
    required this.totalNetCredits,
    required this.variance,
    this.asOfDate,
    this.startDate,
    this.endDate,
    required this.rows,
  });

  factory TrialBalanceData.fromJson(Map<String, dynamic> json) {
    return TrialBalanceData(
      isBalanced: json['is_balanced'] as bool? ?? true,
      status: (json['status'] ?? 'BALANCED') as String,
      totalDebits: (json['total_debits'] as num? ?? 0.0).toDouble(),
      totalCredits: (json['total_credits'] as num? ?? 0.0).toDouble(),
      totalNetDebits: (json['total_net_debits'] as num? ?? 0.0).toDouble(),
      totalNetCredits: (json['total_net_credits'] as num? ?? 0.0).toDouble(),
      variance: (json['variance'] as num? ?? 0.0).toDouble(),
      asOfDate: json['as_of_date'] as String?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      rows: (json['rows'] as List<dynamic>? ?? [])
          .map((e) => TrialBalanceRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// --- SAVINGS SUMMARY ---

class SaverRow {
  final String clientId;
  final String clientName;
  final String group;
  final String branch;
  final String officer;
  final double totalDeposited;
  final double totalWithdrawn;
  final double netSavingsBalance;
  final String? lastTransactionDate;

  const SaverRow({
    required this.clientId,
    required this.clientName,
    required this.group,
    required this.branch,
    required this.officer,
    required this.totalDeposited,
    required this.totalWithdrawn,
    required this.netSavingsBalance,
    this.lastTransactionDate,
  });

  factory SaverRow.fromJson(Map<String, dynamic> json) {
    return SaverRow(
      clientId: (json['client_id'] ?? '') as String,
      clientName: (json['client_name'] ?? '') as String,
      group: (json['group'] ?? 'Independent') as String,
      branch: (json['branch'] ?? '') as String,
      officer: (json['officer'] ?? '') as String,
      totalDeposited: (json['total_deposited'] as num? ?? 0.0).toDouble(),
      totalWithdrawn: (json['total_withdrawn'] as num? ?? 0.0).toDouble(),
      netSavingsBalance: (json['net_savings_balance'] as num? ?? 0.0).toDouble(),
      lastTransactionDate: json['last_transaction_date'] as String?,
    );
  }
}

class SavingsSummaryData {
  final double totalIndividualDeposits;
  final double totalIndividualWithdrawals;
  final double netIndividualSavings;
  final double totalGroupDeposits;
  final double totalGroupWithdrawals;
  final double netGroupSavings;
  final double lapsReserve;
  final double totalConsolidatedSavings;
  final int activeSaversCount;
  final int totalSaversRecorded;
  final List<SaverRow> savers;

  const SavingsSummaryData({
    required this.totalIndividualDeposits,
    required this.totalIndividualWithdrawals,
    required this.netIndividualSavings,
    required this.totalGroupDeposits,
    required this.totalGroupWithdrawals,
    required this.netGroupSavings,
    required this.lapsReserve,
    required this.totalConsolidatedSavings,
    required this.activeSaversCount,
    required this.totalSaversRecorded,
    required this.savers,
  });

  factory SavingsSummaryData.fromJson(Map<String, dynamic> json) {
    return SavingsSummaryData(
      totalIndividualDeposits: (json['total_individual_deposits'] as num? ?? 0.0).toDouble(),
      totalIndividualWithdrawals: (json['total_individual_withdrawals'] as num? ?? 0.0).toDouble(),
      netIndividualSavings: (json['net_individual_savings'] as num? ?? 0.0).toDouble(),
      totalGroupDeposits: (json['total_group_deposits'] as num? ?? 0.0).toDouble(),
      totalGroupWithdrawals: (json['total_group_withdrawals'] as num? ?? 0.0).toDouble(),
      netGroupSavings: (json['net_group_savings'] as num? ?? 0.0).toDouble(),
      lapsReserve: (json['laps_reserve'] as num? ?? 0.0).toDouble(),
      totalConsolidatedSavings: (json['total_consolidated_savings'] as num? ?? 0.0).toDouble(),
      activeSaversCount: json['active_savers_count'] as int? ?? 0,
      totalSaversRecorded: json['total_savers_recorded'] as int? ?? 0,
      savers: (json['savers'] as List<dynamic>? ?? [])
          .map((e) => SaverRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// --- REPAYMENT SUMMARY ---

class ProductCollectionRow {
  final String loanProduct;
  final double collectionsNgn;
  final int transactions;
  final int uniqueClients;

  const ProductCollectionRow({
    required this.loanProduct,
    required this.collectionsNgn,
    required this.transactions,
    required this.uniqueClients,
  });

  factory ProductCollectionRow.fromJson(Map<String, dynamic> json) {
    return ProductCollectionRow(
      loanProduct: (json['loan_product'] ?? '') as String,
      collectionsNgn: (json['collections_ngn'] as num? ?? 0.0).toDouble(),
      transactions: json['transactions'] as int? ?? 0,
      uniqueClients: json['unique_clients'] as int? ?? 0,
    );
  }
}

class RepaymentLogRow {
  final String date;
  final String clientCode;
  final String clientName;
  final String loanProduct;
  final String officer;
  final String branch;
  final double amountPaid;
  final double expectedAmount;
  final String paymentStatus;
  final String transactionType;

  const RepaymentLogRow({
    required this.date,
    required this.clientCode,
    required this.clientName,
    required this.loanProduct,
    required this.officer,
    required this.branch,
    required this.amountPaid,
    required this.expectedAmount,
    required this.paymentStatus,
    required this.transactionType,
  });

  factory RepaymentLogRow.fromJson(Map<String, dynamic> json) {
    return RepaymentLogRow(
      date: (json['date'] ?? '') as String,
      clientCode: (json['client_code'] ?? '') as String,
      clientName: (json['client_name'] ?? '') as String,
      loanProduct: (json['loan_product'] ?? '') as String,
      officer: (json['officer'] ?? '') as String,
      branch: (json['branch'] ?? '') as String,
      amountPaid: (json['amount_paid'] as num? ?? 0.0).toDouble(),
      expectedAmount: (json['expected_amount'] as num? ?? 0.0).toDouble(),
      paymentStatus: (json['payment_status'] ?? 'PAID') as String,
      transactionType: (json['transaction_type'] ?? 'Collection') as String,
    );
  }
}

class RepaymentSummaryData {
  final double totalCollected;
  final double totalExpected;
  final double baseCollections;
  final double collectionEfficiency;
  final double totalOverdueCollected;
  final double fullPayoffAmount;
  final int fullPayoffCount;
  final double excessPaymentAmount;
  final int excessPaymentCount;
  final Map<String, int> statusCounts;
  final int totalTransactions;
  final List<ProductCollectionRow> products;
  final List<RepaymentLogRow> repayments;

  const RepaymentSummaryData({
    required this.totalCollected,
    required this.totalExpected,
    required this.baseCollections,
    required this.collectionEfficiency,
    required this.totalOverdueCollected,
    required this.fullPayoffAmount,
    required this.fullPayoffCount,
    required this.excessPaymentAmount,
    required this.excessPaymentCount,
    required this.statusCounts,
    required this.totalTransactions,
    required this.products,
    required this.repayments,
  });

  factory RepaymentSummaryData.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['status_counts'] as Map<String, dynamic>? ?? {};
    final counts = rawCounts.map((k, v) => MapEntry(k, (v as num).toInt()));

    return RepaymentSummaryData(
      totalCollected: (json['total_collected'] as num? ?? 0.0).toDouble(),
      totalExpected: (json['total_expected'] as num? ?? 0.0).toDouble(),
      baseCollections: (json['base_collections'] as num? ?? 0.0).toDouble(),
      collectionEfficiency: (json['collection_efficiency'] as num? ?? 0.0).toDouble(),
      totalOverdueCollected: (json['total_overdue_collected'] as num? ?? 0.0).toDouble(),
      fullPayoffAmount: (json['full_payoff_amount'] as num? ?? 0.0).toDouble(),
      fullPayoffCount: json['full_payoff_count'] as int? ?? 0,
      excessPaymentAmount: (json['excess_payment_amount'] as num? ?? 0.0).toDouble(),
      excessPaymentCount: json['excess_payment_count'] as int? ?? 0,
      statusCounts: counts,
      totalTransactions: json['total_transactions'] as int? ?? 0,
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => ProductCollectionRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      repayments: (json['repayments'] as List<dynamic>? ?? [])
          .map((e) => RepaymentLogRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// --- PORTFOLIO & OFFICER PERFORMANCE ---

class OfficerPerformanceRow {
  final String clientId;
  final String clientName;
  final String phone;
  final String group;
  final String product;
  final double activeCredit;
  final double loanRepay;
  final double paidToLoan;
  final double loanBalance;
  final double savings;
  final double overdue;
  final String status;

  const OfficerPerformanceRow({
    required this.clientId,
    required this.clientName,
    required this.phone,
    required this.group,
    required this.product,
    required this.activeCredit,
    required this.loanRepay,
    required this.paidToLoan,
    required this.loanBalance,
    required this.savings,
    required this.overdue,
    required this.status,
  });

  factory OfficerPerformanceRow.fromJson(Map<String, dynamic> json) {
    return OfficerPerformanceRow(
      clientId: (json['client_id'] ?? '') as String,
      clientName: (json['client_name'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      group: (json['group'] ?? '') as String,
      product: (json['product'] ?? '') as String,
      activeCredit: (json['active_credit'] as num? ?? 0.0).toDouble(),
      loanRepay: (json['loan_repay'] as num? ?? 0.0).toDouble(),
      paidToLoan: (json['paid_to_loan'] as num? ?? 0.0).toDouble(),
      loanBalance: (json['loan_balance'] as num? ?? 0.0).toDouble(),
      savings: (json['savings'] as num? ?? 0.0).toDouble(),
      overdue: (json['overdue'] as num? ?? 0.0).toDouble(),
      status: (json['status'] ?? 'Active') as String,
    );
  }
}

class PortfolioPerformanceData {
  final int activeLoans;
  final double totalPortfolio;
  final double parPercentage;
  final List<String> officersList;
  final List<OfficerPerformanceRow> officerRecords;
  final Map<String, int> riskDistribution;

  const PortfolioPerformanceData({
    required this.activeLoans,
    required this.totalPortfolio,
    required this.parPercentage,
    required this.officersList,
    required this.officerRecords,
    required this.riskDistribution,
  });

  factory PortfolioPerformanceData.fromJson(Map<String, dynamic> json) {
    final rawRisk = json['risk_distribution'] as Map<String, dynamic>? ?? {};
    final risk = rawRisk.map((k, v) => MapEntry(k, (v as num).toInt()));

    return PortfolioPerformanceData(
      activeLoans: json['active_loans'] as int? ?? 0,
      totalPortfolio: (json['total_portfolio'] as num? ?? 0.0).toDouble(),
      parPercentage: (json['par_percentage'] as num? ?? 0.0).toDouble(),
      officersList: (json['officers_list'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      officerRecords: (json['officer_records'] as List<dynamic>? ?? [])
          .map((e) => OfficerPerformanceRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      riskDistribution: risk,
    );
  }
}

// --- AREA COMPARISON (AM EXCLUSIVE) ---

class AreaBranchRow {
  final String branch;
  final int peopleOnLoan;
  final int activeLoans;
  final int activeSavers;
  final double totalSavings;
  final double collectionsReceived;
  final double expectedCollections;
  final double collectionEfficiency;
  final double outstandingPortfolio;
  final double parPercentage;
  final String status;

  const AreaBranchRow({
    required this.branch,
    required this.peopleOnLoan,
    required this.activeLoans,
    required this.activeSavers,
    required this.totalSavings,
    required this.collectionsReceived,
    required this.expectedCollections,
    required this.collectionEfficiency,
    required this.outstandingPortfolio,
    required this.parPercentage,
    required this.status,
  });

  factory AreaBranchRow.fromJson(Map<String, dynamic> json) {
    return AreaBranchRow(
      branch: (json['branch'] ?? '') as String,
      peopleOnLoan: json['people_on_loan'] as int? ?? 0,
      activeLoans: json['active_loans'] as int? ?? 0,
      activeSavers: json['active_savers'] as int? ?? 0,
      totalSavings: (json['total_savings'] as num? ?? 0.0).toDouble(),
      collectionsReceived: (json['collections_received'] as num? ?? 0.0).toDouble(),
      expectedCollections: (json['expected_collections'] as num? ?? 0.0).toDouble(),
      collectionEfficiency: (json['collection_efficiency'] as num? ?? 100.0).toDouble(),
      outstandingPortfolio: (json['outstanding_portfolio'] as num? ?? 0.0).toDouble(),
      parPercentage: (json['par_percentage'] as num? ?? 0.0).toDouble(),
      status: (json['status'] ?? 'HEALTHY') as String,
    );
  }
}

class AreaComparisonData {
  final int totalBranches;
  final int totalPeopleOnLoan;
  final int totalActiveLoans;
  final int totalActiveSavers;
  final double totalAreaCollections;
  final double totalAreaExpected;
  final double overallEfficiency;
  final double totalAreaSavings;
  final double totalAreaPortfolio;
  final double overallPar;
  final List<AreaBranchRow> rows;

  const AreaComparisonData({
    required this.totalBranches,
    required this.totalPeopleOnLoan,
    required this.totalActiveLoans,
    required this.totalActiveSavers,
    required this.totalAreaCollections,
    required this.totalAreaExpected,
    required this.overallEfficiency,
    required this.totalAreaSavings,
    required this.totalAreaPortfolio,
    required this.overallPar,
    required this.rows,
  });

  factory AreaComparisonData.fromJson(Map<String, dynamic> json) {
    return AreaComparisonData(
      totalBranches: json['total_branches'] as int? ?? 0,
      totalPeopleOnLoan: json['total_people_on_loan'] as int? ?? 0,
      totalActiveLoans: json['total_active_loans'] as int? ?? 0,
      totalActiveSavers: json['total_active_savers'] as int? ?? 0,
      totalAreaCollections: (json['total_area_collections'] as num? ?? 0.0).toDouble(),
      totalAreaExpected: (json['total_area_expected'] as num? ?? 0.0).toDouble(),
      overallEfficiency: (json['overall_efficiency'] as num? ?? 100.0).toDouble(),
      totalAreaSavings: (json['total_area_savings'] as num? ?? 0.0).toDouble(),
      totalAreaPortfolio: (json['total_area_portfolio'] as num? ?? 0.0).toDouble(),
      overallPar: (json['overall_par'] as num? ?? 0.0).toDouble(),
      rows: (json['rows'] as List<dynamic>? ?? [])
          .map((e) => AreaBranchRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// --- MONTHLY EXECUTIVE SUITE ---

class MonthlyParityOfficer {
  final String officerId;
  final String name;
  final String? username;
  final String? fullName;

  const MonthlyParityOfficer({
    required this.officerId,
    required this.name,
    this.username,
    this.fullName,
  });

  factory MonthlyParityOfficer.fromJson(Map<String, dynamic> json) {
    return MonthlyParityOfficer(
      officerId: (json['officer_id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
    );
  }
}

class MonthlyParityMetricRow {
  final String metric;
  final Map<String, dynamic> values;

  const MonthlyParityMetricRow({
    required this.metric,
    required this.values,
  });

  factory MonthlyParityMetricRow.fromJson(Map<String, dynamic> json) {
    return MonthlyParityMetricRow(
      metric: (json['metric'] ?? '') as String,
      values: (json['values'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class MonthlyParitySummaryCards {
  final double disbursedPrincipal;
  final double upfrontFees;
  final double netActiveCredit;
  final double openingCredit;
  final double collections;
  final double closingCredit;
  final double openingSavings;
  final double savingsDeposits;
  final double savingsWithdrawals;
  final double closingSavings;
  final double bankDeposits;
  final double officeExpenses;
  final int activeLoans;
  final int activeSavers;
  final double glDebits;
  final double glCredits;
  final double glDiff;
  final bool isGlBalanced;

  const MonthlyParitySummaryCards({
    required this.disbursedPrincipal,
    required this.upfrontFees,
    required this.netActiveCredit,
    required this.openingCredit,
    required this.collections,
    required this.closingCredit,
    required this.openingSavings,
    required this.savingsDeposits,
    required this.savingsWithdrawals,
    required this.closingSavings,
    required this.bankDeposits,
    required this.officeExpenses,
    required this.activeLoans,
    required this.activeSavers,
    required this.glDebits,
    required this.glCredits,
    required this.glDiff,
    required this.isGlBalanced,
  });

  factory MonthlyParitySummaryCards.fromJson(Map<String, dynamic> json) {
    return MonthlyParitySummaryCards(
      disbursedPrincipal: (json['disbursed_principal'] as num? ?? 0.0).toDouble(),
      upfrontFees: (json['upfront_fees'] as num? ?? 0.0).toDouble(),
      netActiveCredit: (json['net_active_credit'] as num? ?? 0.0).toDouble(),
      openingCredit: (json['opening_credit'] as num? ?? 0.0).toDouble(),
      collections: (json['collections'] as num? ?? 0.0).toDouble(),
      closingCredit: (json['closing_credit'] as num? ?? 0.0).toDouble(),
      openingSavings: (json['opening_savings'] as num? ?? 0.0).toDouble(),
      savingsDeposits: (json['savings_deposits'] as num? ?? 0.0).toDouble(),
      savingsWithdrawals: (json['savings_withdrawals'] as num? ?? 0.0).toDouble(),
      closingSavings: (json['closing_savings'] as num? ?? 0.0).toDouble(),
      bankDeposits: (json['bank_deposits'] as num? ?? 0.0).toDouble(),
      officeExpenses: (json['office_expenses'] as num? ?? 0.0).toDouble(),
      activeLoans: json['active_loans'] as int? ?? 0,
      activeSavers: json['active_savers'] as int? ?? 0,
      glDebits: (json['gl_debits'] as num? ?? 0.0).toDouble(),
      glCredits: (json['gl_credits'] as num? ?? 0.0).toDouble(),
      glDiff: (json['gl_diff'] as num? ?? 0.0).toDouble(),
      isGlBalanced: json['is_gl_balanced'] as bool? ?? false,
    );
  }
}

class MonthlyParityData {
  final int year;
  final int month;
  final String monthLabel;
  final String branchId;
  final String branchName;
  final String totalColName;
  final List<MonthlyParityOfficer> officers;
  final List<MonthlyParityMetricRow> rows;
  final MonthlyParitySummaryCards summaryCards;

  const MonthlyParityData({
    required this.year,
    required this.month,
    required this.monthLabel,
    required this.branchId,
    required this.branchName,
    required this.totalColName,
    required this.officers,
    required this.rows,
    required this.summaryCards,
  });

  factory MonthlyParityData.fromJson(Map<String, dynamic> json) {
    return MonthlyParityData(
      year: json['year'] as int? ?? 2026,
      month: json['month'] as int? ?? 9,
      monthLabel: (json['month_label'] ?? '') as String,
      branchId: (json['branch_id'] ?? '') as String,
      branchName: (json['branch_name'] ?? '') as String,
      totalColName: (json['total_col_name'] ?? 'Branch Total') as String,
      officers: (json['officers'] as List<dynamic>? ?? [])
          .map((e) => MonthlyParityOfficer.fromJson(e as Map<String, dynamic>))
          .toList(),
      rows: (json['rows'] as List<dynamic>? ?? [])
          .map((e) => MonthlyParityMetricRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      summaryCards: MonthlyParitySummaryCards.fromJson(json['summary_cards'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class OfficialTrialBalanceRow {
  final String section;
  final String item;
  final double debit;
  final double credit;

  const OfficialTrialBalanceRow({
    required this.section,
    required this.item,
    required this.debit,
    required this.credit,
  });

  factory OfficialTrialBalanceRow.fromJson(Map<String, dynamic> json) {
    return OfficialTrialBalanceRow(
      section: (json['section'] ?? '') as String,
      item: (json['item'] ?? '') as String,
      debit: (json['debit'] as num? ?? 0.0).toDouble(),
      credit: (json['credit'] as num? ?? 0.0).toDouble(),
    );
  }
}

class OfficialTrialBalanceData {
  final List<OfficialTrialBalanceRow> rows;
  final double totalDebits;
  final double totalCredits;
  final double variance;
  final bool isBalanced;

  const OfficialTrialBalanceData({
    required this.rows,
    required this.totalDebits,
    required this.totalCredits,
    required this.variance,
    required this.isBalanced,
  });

  factory OfficialTrialBalanceData.fromJson(Map<String, dynamic> json) {
    return OfficialTrialBalanceData(
      rows: (json['rows'] as List<dynamic>? ?? [])
          .map((e) => OfficialTrialBalanceRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalDebits: (json['total_debits'] as num? ?? 0.0).toDouble(),
      totalCredits: (json['total_credits'] as num? ?? 0.0).toDouble(),
      variance: (json['variance'] as num? ?? 0.0).toDouble(),
      isBalanced: json['is_balanced'] as bool? ?? false,
    );
  }
}

class ReceiptsPaymentsItem {
  final String item;
  final String? subDetail;
  final double amount;

  const ReceiptsPaymentsItem({
    required this.item,
    this.subDetail,
    required this.amount,
  });

  factory ReceiptsPaymentsItem.fromJson(Map<String, dynamic> json) {
    return ReceiptsPaymentsItem(
      item: (json['item'] ?? '') as String,
      subDetail: json['sub_detail'] as String?,
      amount: (json['amount'] as num? ?? 0.0).toDouble(),
    );
  }
}

class ReceiptsPaymentsData {
  final List<ReceiptsPaymentsItem> receipts;
  final List<ReceiptsPaymentsItem> payments;
  final double totalReceipts;
  final double totalPayments;
  final double variance;

  const ReceiptsPaymentsData({
    required this.receipts,
    required this.payments,
    required this.totalReceipts,
    required this.totalPayments,
    required this.variance,
  });

  factory ReceiptsPaymentsData.fromJson(Map<String, dynamic> json) {
    return ReceiptsPaymentsData(
      receipts: (json['receipts'] as List<dynamic>? ?? [])
          .map((e) => ReceiptsPaymentsItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      payments: (json['payments'] as List<dynamic>? ?? [])
          .map((e) => ReceiptsPaymentsItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalReceipts: (json['total_receipts'] as num? ?? 0.0).toDouble(),
      totalPayments: (json['total_payments'] as num? ?? 0.0).toDouble(),
      variance: (json['variance'] as num? ?? 0.0).toDouble(),
    );
  }
}

class MonthlyExecutiveStatementsData {
  final String branchName;
  final String areaName;
  final String monthLabel;
  final int year;
  final int month;
  final OfficialTrialBalanceData trialBalance;
  final ReceiptsPaymentsData receiptsAndPayments;

  const MonthlyExecutiveStatementsData({
    required this.branchName,
    required this.areaName,
    required this.monthLabel,
    required this.year,
    required this.month,
    required this.trialBalance,
    required this.receiptsAndPayments,
  });

  factory MonthlyExecutiveStatementsData.fromJson(Map<String, dynamic> json) {
    return MonthlyExecutiveStatementsData(
      branchName: (json['branch_name'] ?? '') as String,
      areaName: (json['area_name'] ?? '') as String,
      monthLabel: (json['month_label'] ?? '') as String,
      year: json['year'] as int? ?? 2026,
      month: json['month'] as int? ?? 9,
      trialBalance: OfficialTrialBalanceData.fromJson(json['trial_balance'] as Map<String, dynamic>? ?? {}),
      receiptsAndPayments: ReceiptsPaymentsData.fromJson(json['receipts_and_payments'] as Map<String, dynamic>? ?? {}),
    );
  }
}

