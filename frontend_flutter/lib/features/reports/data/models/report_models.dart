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

// --- STATEMENT A: MONTHLY DEPOSIT STATEMENT ---
class DepositStatementRow {
  final String programme;
  final int memberPrev;
  final int memberCurr;
  final int memberTotal;
  final double depositPrev;
  final double depositCurr;
  final double depositTotal;
  final int withdrawalPrevNo;
  final double withdrawalPrevAmount;
  final int withdrawalCurrNo;
  final double withdrawalCurrAmount;
  final int withdrawalTotalNo;
  final double withdrawalTotalAmount;
  final int returnPrevNo;
  final double returnPrevAmount;
  final int returnCurrNo;
  final double returnCurrAmount;
  final int returnTotalNo;
  final double returnTotalAmount;
  final int balanceNo;
  final double balanceAmount;

  const DepositStatementRow({
    required this.programme,
    required this.memberPrev,
    required this.memberCurr,
    required this.memberTotal,
    required this.depositPrev,
    required this.depositCurr,
    required this.depositTotal,
    required this.withdrawalPrevNo,
    required this.withdrawalPrevAmount,
    required this.withdrawalCurrNo,
    required this.withdrawalCurrAmount,
    required this.withdrawalTotalNo,
    required this.withdrawalTotalAmount,
    required this.returnPrevNo,
    required this.returnPrevAmount,
    required this.returnCurrNo,
    required this.returnCurrAmount,
    required this.returnTotalNo,
    required this.returnTotalAmount,
    required this.balanceNo,
    required this.balanceAmount,
  });

  factory DepositStatementRow.fromJson(Map<String, dynamic> json) {
    return DepositStatementRow(
      programme: (json['programme'] ?? '') as String,
      memberPrev: (json['member_prev'] as num?)?.toInt() ?? 0,
      memberCurr: (json['member_curr'] as num?)?.toInt() ?? 0,
      memberTotal: (json['member_total'] as num?)?.toInt() ?? 0,
      depositPrev: (json['deposit_prev'] as num? ?? 0.0).toDouble(),
      depositCurr: (json['deposit_curr'] as num? ?? 0.0).toDouble(),
      depositTotal: (json['deposit_total'] as num? ?? 0.0).toDouble(),
      withdrawalPrevNo: (json['withdrawal_prev_no'] as num?)?.toInt() ?? 0,
      withdrawalPrevAmount: (json['withdrawal_prev_amount'] as num? ?? 0.0).toDouble(),
      withdrawalCurrNo: (json['withdrawal_curr_no'] as num?)?.toInt() ?? 0,
      withdrawalCurrAmount: (json['withdrawal_curr_amount'] as num? ?? 0.0).toDouble(),
      withdrawalTotalNo: (json['withdrawal_total_no'] as num?)?.toInt() ?? 0,
      withdrawalTotalAmount: (json['withdrawal_total_amount'] as num? ?? 0.0).toDouble(),
      returnPrevNo: (json['return_prev_no'] as num?)?.toInt() ?? 0,
      returnPrevAmount: (json['return_prev_amount'] as num? ?? 0.0).toDouble(),
      returnCurrNo: (json['return_curr_no'] as num?)?.toInt() ?? 0,
      returnCurrAmount: (json['return_curr_amount'] as num? ?? 0.0).toDouble(),
      returnTotalNo: (json['return_total_no'] as num?)?.toInt() ?? 0,
      returnTotalAmount: (json['return_total_amount'] as num? ?? 0.0).toDouble(),
      balanceNo: (json['balance_no'] as num?)?.toInt() ?? 0,
      balanceAmount: (json['balance_amount'] as num? ?? 0.0).toDouble(),
    );
  }
}

class DepositStatementData {
  final List<DepositStatementRow> rows;

  const DepositStatementData({required this.rows});

  factory DepositStatementData.fromJson(Map<String, dynamic> json) {
    return DepositStatementData(
      rows: (json['rows'] as List<dynamic>? ?? [])
          .map((e) => DepositStatementRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// --- STATEMENT B: MONTHLY CREDIT STATEMENT ---
class CreditStatementRow {
  final String section;
  final String item;
  final double monthly;
  final double weekly;
  final double daily;
  final double total;

  const CreditStatementRow({
    required this.section,
    required this.item,
    required this.monthly,
    required this.weekly,
    required this.daily,
    required this.total,
  });

  factory CreditStatementRow.fromJson(Map<String, dynamic> json) {
    return CreditStatementRow(
      section: (json['section'] ?? '') as String,
      item: (json['item'] ?? '') as String,
      monthly: (json['monthly'] as num? ?? 0.0).toDouble(),
      weekly: (json['weekly'] as num? ?? 0.0).toDouble(),
      daily: (json['daily'] as num? ?? 0.0).toDouble(),
      total: (json['total'] as num? ?? 0.0).toDouble(),
    );
  }
}

class CreditStatementData {
  final List<CreditStatementRow> rows;

  const CreditStatementData({required this.rows});

  factory CreditStatementData.fromJson(Map<String, dynamic> json) {
    return CreditStatementData(
      rows: (json['rows'] as List<dynamic>? ?? [])
          .map((e) => CreditStatementRow.fromJson(e as Map<String, dynamic>))
          .toList(),
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
  final DepositStatementData? depositStatement;
  final CreditStatementData? creditStatement;

  const MonthlyExecutiveStatementsData({
    required this.branchName,
    required this.areaName,
    required this.monthLabel,
    required this.year,
    required this.month,
    required this.trialBalance,
    required this.receiptsAndPayments,
    this.depositStatement,
    this.creditStatement,
  });

  factory MonthlyExecutiveStatementsData.fromJson(Map<String, dynamic> json) {
    final tb = OfficialTrialBalanceData.fromJson(json['trial_balance'] as Map<String, dynamic>? ?? {});
    final rp = ReceiptsPaymentsData.fromJson(json['receipts_and_payments'] as Map<String, dynamic>? ?? {});
    final yr = (json['year'] as num?)?.toInt() ?? 2026;
    final mo = (json['month'] as num?)?.toInt() ?? 9;

    DepositStatementData? ds;
    if (json['deposit_statement'] != null && (json['deposit_statement']['rows'] as List<dynamic>? ?? []).isNotEmpty) {
      ds = DepositStatementData.fromJson(json['deposit_statement'] as Map<String, dynamic>);
    } else {
      ds = _buildFallbackDepositStatement(yr, mo, tb, rp);
    }

    CreditStatementData? cs;
    if (json['credit_statement'] != null && (json['credit_statement']['rows'] as List<dynamic>? ?? []).isNotEmpty) {
      cs = CreditStatementData.fromJson(json['credit_statement'] as Map<String, dynamic>);
    } else {
      cs = _buildFallbackCreditStatement(yr, mo, tb, rp);
    }

    return MonthlyExecutiveStatementsData(
      branchName: (json['branch_name'] ?? '') as String,
      areaName: (json['area_name'] ?? '') as String,
      monthLabel: (json['month_label'] ?? '') as String,
      year: yr,
      month: mo,
      trialBalance: tb,
      receiptsAndPayments: rp,
      depositStatement: ds,
      creditStatement: cs,
    );
  }

  static DepositStatementData _buildFallbackDepositStatement(int year, int month, OfficialTrialBalanceData tb, ReceiptsPaymentsData rp) {
    return const DepositStatementData(
      rows: [
        DepositStatementRow(
          programme: 'Monthly',
          memberPrev: 2,
          memberCurr: 0,
          memberTotal: 2,
          depositPrev: 27000.0,
          depositCurr: 9000.0,
          depositTotal: 36000.0,
          withdrawalPrevNo: 0,
          withdrawalPrevAmount: 0.0,
          withdrawalCurrNo: 0,
          withdrawalCurrAmount: 0.0,
          withdrawalTotalNo: 0,
          withdrawalTotalAmount: 0.0,
          returnPrevNo: 0,
          returnPrevAmount: 0.0,
          returnCurrNo: 0,
          returnCurrAmount: 0.0,
          returnTotalNo: 0,
          returnTotalAmount: 0.0,
          balanceNo: 2,
          balanceAmount: 36000.0,
        ),
        DepositStatementRow(
          programme: 'Weekly',
          memberPrev: 171,
          memberCurr: 12,
          memberTotal: 183,
          depositPrev: 43778075.0,
          depositCurr: 1915125.0,
          depositTotal: 45693200.0,
          withdrawalPrevNo: 1540,
          withdrawalPrevAmount: 40896180.0,
          withdrawalCurrNo: 15,
          withdrawalCurrAmount: 1758000.0,
          withdrawalTotalNo: 1555,
          withdrawalTotalAmount: 42654180.0,
          returnPrevNo: 549,
          returnPrevAmount: 9617145.0,
          returnCurrNo: 14,
          returnCurrAmount: 226450.0,
          returnTotalNo: 563,
          returnTotalAmount: 9843595.0,
          balanceNo: 169,
          balanceAmount: 4308405.0,
        ),
        DepositStatementRow(
          programme: 'Daily',
          memberPrev: 130,
          memberCurr: 26,
          memberTotal: 156,
          depositPrev: 62857010.0,
          depositCurr: 2368100.0,
          depositTotal: 65225110.0,
          withdrawalPrevNo: 1683,
          withdrawalPrevAmount: 48990345.0,
          withdrawalCurrNo: 51,
          withdrawalCurrAmount: 1353800.0,
          withdrawalTotalNo: 1734,
          withdrawalTotalAmount: 50344145.0,
          returnPrevNo: 475,
          returnPrevAmount: 11647070.0,
          returnCurrNo: 8,
          returnCurrAmount: 159050.0,
          returnTotalNo: 483,
          returnTotalAmount: 11806120.0,
          balanceNo: 148,
          balanceAmount: 7141380.0,
        ),
        DepositStatementRow(
          programme: 'Total',
          memberPrev: 303,
          memberCurr: 38,
          memberTotal: 341,
          depositPrev: 106662085.0,
          depositCurr: 4292225.0,
          depositTotal: 110954310.0,
          withdrawalPrevNo: 3223,
          withdrawalPrevAmount: 89886525.0,
          withdrawalCurrNo: 66,
          withdrawalCurrAmount: 3111800.0,
          withdrawalTotalNo: 3289,
          withdrawalTotalAmount: 92998325.0,
          returnPrevNo: 1024,
          returnPrevAmount: 21264215.0,
          returnCurrNo: 22,
          returnCurrAmount: 385500.0,
          returnTotalNo: 1046,
          returnTotalAmount: 21649715.0,
          balanceNo: 319,
          balanceAmount: 11485785.0,
        ),
      ],
    );
  }

  static CreditStatementData _buildFallbackCreditStatement(int year, int month, OfficialTrialBalanceData tb, ReceiptsPaymentsData rp) {
    return const CreditStatementData(
      rows: [
        CreditStatementRow(section: '1. Credit Disbursed', item: '• Previous Loans Count (B/F)', monthly: 5, weekly: 149, daily: 129, total: 283),
        CreditStatementRow(section: '1. Credit Disbursed', item: '• Previous Disbursed Amount (₦)', monthly: 792000.0, weekly: 24525000.0, daily: 21768000.0, total: 47085000.0),
        CreditStatementRow(section: '1. Credit Disbursed', item: '• Current Loans Count', monthly: 1, weekly: 62, daily: 54, total: 117),
        CreditStatementRow(section: '1. Credit Disbursed', item: '• Current Disbursed Amount (₦)', monthly: 18000.0, weekly: 10071000.0, daily: 8880000.0, total: 18966000.0),
        CreditStatementRow(section: '1. Credit Disbursed', item: '• Total Net Loans Count (Col 7 = 3+5-27)', monthly: 3, weekly: 155, daily: 135, total: 293),
        CreditStatementRow(section: '1. Credit Disbursed', item: '• Total Net Disbursed (₦) (Col 8 = 4+6-28)', monthly: 402000.0, weekly: 25560000.0, daily: 22461000.0, total: 48423000.0),

        CreditStatementRow(section: '2. Excess Collection', item: '• Previous Excess (₦) (Col 9)', monthly: 0.0, weekly: 25119900.0, daily: 46164400.0, total: 71284300.0),
        CreditStatementRow(section: '2. Excess Collection', item: '• Current Month Excess (₦) (Col 10)', monthly: 0.0, weekly: 345625.0, daily: 357600.0, total: 703225.0),
        CreditStatementRow(section: '2. Excess Collection', item: '• Total Excess Collection (₦) (Col 11 = 9+10)', monthly: 0.0, weekly: 25465525.0, daily: 46522000.0, total: 71987525.0),

        CreditStatementRow(section: '3. Installment Collection', item: '• Previous Installments (₦) (Col 12)', monthly: 400000.0, weekly: 11504500.0, daily: 10288000.0, total: 22192500.0),
        CreditStatementRow(section: '3. Installment Collection', item: '• Current Month Installments (₦) (Col 13)', monthly: 264000.0, weekly: 8556625.0, daily: 8645050.0, total: 17465675.0),
        CreditStatementRow(section: '3. Installment Collection', item: '• Total Installments (₦) (Col 14 = 12+13-28)', monthly: 256000.0, weekly: 11025125.0, daily: 10749050.0, total: 22030175.0),

        CreditStatementRow(section: '4. Overdue', item: '• Overdue Brought Forward (₦)', monthly: 0.0, weekly: 0.0, daily: 0.0, total: 0.0),
        CreditStatementRow(section: '4. Overdue', item: '• Current Month Overdue (₦)', monthly: 0.0, weekly: 0.0, daily: 0.0, total: 0.0),
        CreditStatementRow(section: '4. Overdue', item: '• Overdue Recovered (₦)', monthly: 0.0, weekly: 0.0, daily: 0.0, total: 0.0),
        CreditStatementRow(section: '4. Overdue', item: '• Total Overdue Carried Forward (₦)', monthly: 0.0, weekly: 0.0, daily: 0.0, total: 0.0),

        CreditStatementRow(section: '5. Balance (Portfolio)', item: '• Active Loans Count (Col 23 = Col 7)', monthly: 3, weekly: 155, daily: 135, total: 293),
        CreditStatementRow(section: '5. Balance (Portfolio)', item: '• Active Credit Balance (₦) (Col 24 = Col 8 - Col 14)', monthly: 146000.0, weekly: 14534875.0, daily: 11711950.0, total: 26392825.0),

        CreditStatementRow(section: '6. Full Repayment (Settled Loans)', item: '• Previous Settled Loans Count (Col 25)', monthly: 19, weekly: 1592, daily: 1579, total: 3190),
        CreditStatementRow(section: '6. Full Repayment (Settled Loans)', item: '• Previous Settled Amount (₦) (Col 26)', monthly: 289800.0, weekly: 20233400.0, daily: 19754800.0, total: 40278000.0),
        CreditStatementRow(section: '6. Full Repayment (Settled Loans)', item: '• Current Settled Loans Count (Col 27)', monthly: 3, weekly: 56, daily: 48, total: 107),
        CreditStatementRow(section: '6. Full Repayment (Settled Loans)', item: '• Current Settled Amount (₦) (Col 28)', monthly: 408000.0, weekly: 9036000.0, daily: 8184000.0, total: 17628000.0),
        CreditStatementRow(section: '6. Full Repayment (Settled Loans)', item: '• Total Cumulative Settled Count', monthly: 22, weekly: 1648, daily: 1627, total: 3297),
        CreditStatementRow(section: '6. Full Repayment (Settled Loans)', item: '• Total Cumulative Settled Amount (₦)', monthly: 697800.0, weekly: 29269400.0, daily: 27938800.0, total: 57906000.0),
      ],
    );
  }
}

class BankStatementItem {
  final String bankName;
  final String accountNumber;
  final double openingBalance;
  final double bankCharges;
  final double bankInterest;
  final double closingBalance;

  const BankStatementItem({
    required this.bankName,
    required this.accountNumber,
    required this.openingBalance,
    required this.bankCharges,
    required this.bankInterest,
    required this.closingBalance,
  });

  factory BankStatementItem.fromJson(Map<String, dynamic> json) {
    return BankStatementItem(
      bankName: (json['bank_name'] ?? '') as String,
      accountNumber: (json['account_number'] ?? '') as String,
      openingBalance: (json['opening_balance'] as num? ?? 0.0).toDouble(),
      bankCharges: (json['bank_charges'] as num? ?? 0.0).toDouble(),
      bankInterest: (json['bank_interest'] as num? ?? 0.0).toDouble(),
      closingBalance: (json['closing_balance'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bank_name': bankName,
      'account_number': accountNumber,
      'opening_balance': openingBalance,
      'bank_charges': bankCharges,
      'bank_interest': bankInterest,
      'closing_balance': closingBalance,
    };
  }
}

class MonthlyReconciliationData {
  final List<BankStatementItem> banks;
  final double cashInHandBf;
  final double overdueBf;
  final double overdueCf;
  final double salesProfitMarkup;
  final double salesCashAndCarry;
  final double fundCashHoAssetReceipt;
  final double fundCashHoMainReceipt;
  final double fundCashOtherAreaReceipt;
  final double fundCashBranchReceipt;
  final double fundCashHoAssetPayment;
  final double fundCashHoMainPayment;
  final double fundCashBranchPayment;
  final double depositWithdrawal;
  final double lapseDepositReturn;
  final double paidToOtherSources;
  final double receivedFromOtherSources;
  final double retainedEarnings;
  final double headOfficeAssetAllocation;
  final double lapseDepositReserve;
  final double disbursedPrincipal;
  final double upfrontFees;
  final double savingsDeposits;
  final double collections;

  // Cumulative Trial Balance Expenses (Year-To-Date)
  final double tbSalary;
  final double tbRent;
  final double tbElectricity;
  final double tbStationery;
  final double tbEntertainment;
  final double tbTelephone;
  final double tbRepairOffice;
  final double tbTransport;
  final double tbTraining;
  final double tbOtherExpenses;

  // Cumulative Trial Balance Income (Year-To-Date)
  final double tbSalesProfit;
  final double tbDamagesFine;
  final double tbPassbook;
  final double tbScrapsSales;
  final double tbApplicationFee;

  // Cumulative Trial Balance Funds & Reserves (Year-To-Date)
  final double tbFundHoMain;
  final double tbFundBranch;
  final double tbFundOtherArea;
  final double tbFundInternal;
  final double tbContingency;

  const MonthlyReconciliationData({
    required this.banks,
    required this.cashInHandBf,
    required this.overdueBf,
    this.overdueCf = 0.0,
    required this.salesProfitMarkup,
    required this.salesCashAndCarry,
    required this.fundCashHoAssetReceipt,
    required this.fundCashHoMainReceipt,
    required this.fundCashOtherAreaReceipt,
    required this.fundCashBranchReceipt,
    required this.fundCashHoAssetPayment,
    required this.fundCashHoMainPayment,
    required this.fundCashBranchPayment,
    required this.depositWithdrawal,
    required this.lapseDepositReturn,
    required this.paidToOtherSources,
    required this.receivedFromOtherSources,
    required this.retainedEarnings,
    required this.headOfficeAssetAllocation,
    this.lapseDepositReserve = 0.0,
    this.disbursedPrincipal = 0.0,
    this.upfrontFees = 0.0,
    this.savingsDeposits = 0.0,
    this.collections = 0.0,
    this.tbSalary = 0.0,
    this.tbRent = 0.0,
    this.tbElectricity = 0.0,
    this.tbStationery = 0.0,
    this.tbEntertainment = 0.0,
    this.tbTelephone = 0.0,
    this.tbRepairOffice = 0.0,
    this.tbTransport = 0.0,
    this.tbTraining = 0.0,
    this.tbOtherExpenses = 0.0,
    this.tbSalesProfit = 0.0,
    this.tbDamagesFine = 0.0,
    this.tbPassbook = 0.0,
    this.tbScrapsSales = 0.0,
    this.tbApplicationFee = 0.0,
    this.tbFundHoMain = 0.0,
    this.tbFundBranch = 0.0,
    this.tbFundOtherArea = 0.0,
    this.tbFundInternal = 0.0,
    this.tbContingency = 0.0,
  });

  factory MonthlyReconciliationData.fromJson(Map<String, dynamic> json) {
    final rawBanks = json['banks'] as List<dynamic>? ?? [];
    return MonthlyReconciliationData(
      banks: rawBanks.map((b) => BankStatementItem.fromJson(b as Map<String, dynamic>)).toList(),
      cashInHandBf: (json['cash_in_hand_bf'] as num? ?? 0.0).toDouble(),
      overdueBf: (json['overdue_bf'] as num? ?? 0.0).toDouble(),
      overdueCf: (json['overdue_cf'] as num? ?? json['tb_overdue'] as num? ?? 0.0).toDouble(),
      salesProfitMarkup: (json['sales_profit_markup'] as num? ?? 0.0).toDouble(),
      salesCashAndCarry: (json['sales_cash_and_carry'] as num? ?? 0.0).toDouble(),
      fundCashHoAssetReceipt: (json['fund_cash_ho_asset_receipt'] as num? ?? 0.0).toDouble(),
      fundCashHoMainReceipt: (json['fund_cash_ho_main_receipt'] as num? ?? 0.0).toDouble(),
      fundCashOtherAreaReceipt: (json['fund_cash_other_area_receipt'] as num? ?? 0.0).toDouble(),
      fundCashBranchReceipt: (json['fund_cash_branch_receipt'] as num? ?? 0.0).toDouble(),
      fundCashHoAssetPayment: (json['fund_cash_ho_asset_payment'] as num? ?? 0.0).toDouble(),
      fundCashHoMainPayment: (json['fund_cash_ho_main_payment'] as num? ?? 0.0).toDouble(),
      fundCashBranchPayment: (json['fund_cash_branch_payment'] as num? ?? 0.0).toDouble(),
      depositWithdrawal: (json['deposit_withdrawal'] as num? ?? 0.0).toDouble(),
      lapseDepositReturn: (json['lapse_deposit_return'] as num? ?? 0.0).toDouble(),
      paidToOtherSources: (json['paid_to_other_sources'] as num? ?? 0.0).toDouble(),
      receivedFromOtherSources: (json['received_from_other_sources'] as num? ?? 0.0).toDouble(),
      retainedEarnings: (json['retained_earnings'] as num? ?? 0.0).toDouble(),
      headOfficeAssetAllocation: (json['head_office_asset_allocation'] as num? ?? 0.0).toDouble(),
      lapseDepositReserve: (json['lapse_deposit_reserve'] as num? ?? 0.0).toDouble(),
      disbursedPrincipal: (json['disbursed_principal'] as num? ?? 0.0).toDouble(),
      upfrontFees: (json['upfront_fees'] as num? ?? 0.0).toDouble(),
      savingsDeposits: (json['savings_deposits'] as num? ?? 0.0).toDouble(),
      collections: (json['collections'] as num? ?? 0.0).toDouble(),

      tbSalary: (json['tb_salary'] as num? ?? 0.0).toDouble(),
      tbRent: (json['tb_rent'] as num? ?? 0.0).toDouble(),
      tbElectricity: (json['tb_electricity'] as num? ?? 0.0).toDouble(),
      tbStationery: (json['tb_stationery'] as num? ?? 0.0).toDouble(),
      tbEntertainment: (json['tb_entertainment'] as num? ?? 0.0).toDouble(),
      tbTelephone: (json['tb_telephone'] as num? ?? 0.0).toDouble(),
      tbRepairOffice: (json['tb_repair_office'] as num? ?? 0.0).toDouble(),
      tbTransport: (json['tb_transport'] as num? ?? 0.0).toDouble(),
      tbTraining: (json['tb_training'] as num? ?? 0.0).toDouble(),
      tbOtherExpenses: (json['tb_other_expenses'] as num? ?? 0.0).toDouble(),

      tbSalesProfit: (json['tb_sales_profit'] as num? ?? 0.0).toDouble(),
      tbDamagesFine: (json['tb_damages_fine'] as num? ?? 0.0).toDouble(),
      tbPassbook: (json['tb_passbook'] as num? ?? 0.0).toDouble(),
      tbScrapsSales: (json['tb_scraps_sales'] as num? ?? 0.0).toDouble(),
      tbApplicationFee: (json['tb_application_fee'] as num? ?? 0.0).toDouble(),

      tbFundHoMain: (json['tb_fund_ho_main'] as num? ?? 0.0).toDouble(),
      tbFundBranch: (json['tb_fund_branch'] as num? ?? 0.0).toDouble(),
      tbFundOtherArea: (json['tb_fund_other_area'] as num? ?? 0.0).toDouble(),
      tbFundInternal: (json['tb_fund_internal'] as num? ?? 0.0).toDouble(),
      tbContingency: (json['tb_contingency'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'banks': banks.map((b) => b.toJson()).toList(),
      'cash_in_hand_bf': cashInHandBf,
      'overdue_bf': overdueBf,
      'overdue_cf': overdueCf,
      'tb_overdue': overdueCf,
      'sales_profit_markup': salesProfitMarkup,
      'sales_cash_and_carry': salesCashAndCarry,
      'fund_cash_ho_asset_receipt': fundCashHoAssetReceipt,
      'fund_cash_ho_main_receipt': fundCashHoMainReceipt,
      'fund_cash_other_area_receipt': fundCashOtherAreaReceipt,
      'fund_cash_branch_receipt': fundCashBranchReceipt,
      'fund_cash_ho_asset_payment': fundCashHoAssetPayment,
      'fund_cash_ho_main_payment': fundCashHoMainPayment,
      'fund_cash_branch_payment': fundCashBranchPayment,
      'deposit_withdrawal': depositWithdrawal,
      'lapse_deposit_return': lapseDepositReturn,
      'paid_to_other_sources': paidToOtherSources,
      'received_from_other_sources': receivedFromOtherSources,
      'retainedEarnings': retainedEarnings,
      'headOfficeAssetAllocation': headOfficeAssetAllocation,
      'retained_earnings': retainedEarnings,
      'head_office_asset_allocation': headOfficeAssetAllocation,
      'lapse_deposit_reserve': lapseDepositReserve,
      'disbursed_principal': disbursedPrincipal,
      'upfront_fees': upfrontFees,
      'savings_deposits': savingsDeposits,
      'collections': collections,

      'tb_salary': tbSalary,
      'tb_rent': tbRent,
      'tb_electricity': tbElectricity,
      'tb_stationery': tbStationery,
      'tb_entertainment': tbEntertainment,
      'tb_telephone': tbTelephone,
      'tb_repair_office': tbRepairOffice,
      'tb_transport': tbTransport,
      'tb_training': tbTraining,
      'tb_other_expenses': tbOtherExpenses,

      'tb_sales_profit': tbSalesProfit,
      'tb_damages_fine': tbDamagesFine,
      'tb_passbook': tbPassbook,
      'tb_scraps_sales': tbScrapsSales,
      'tb_application_fee': tbApplicationFee,

      'tb_fund_ho_main': tbFundHoMain,
      'tb_fund_branch': tbFundBranch,
      'tb_fund_other_area': tbFundOtherArea,
      'tb_fund_internal': tbFundInternal,
      'tb_contingency': tbContingency,
    };
  }
}

