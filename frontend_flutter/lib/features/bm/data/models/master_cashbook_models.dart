// Master Cashbook Dart Models
// Mirrors api/schemas/master_cashbook.py for 1:1 parity with Streamlit app.py L11187-12191.

class MasterCashbookInflowsData {
  final double openingBalance;
  final double savingsDeposit;
  final double repDaily;
  final double rep120Days;
  final double rep12Weeks;
  final double rep24Weeks;
  final double repMonthly;
  final double lapsReserve;
  final double fundsReceivedHo;
  final double fundsReceivedOtherBranch;
  final double fundsReceivedOtherArea;
  final double assetCreditSales;
  final double cashAndCarry;
  final double loanReceivedFinance;
  final double daily11Pct;
  final double daily20Pct;
  final double weekly11Pct;
  final double weekly20Pct;
  final double riskPremiumReturns;
  final double contingency;
  final double creditFormDamage;
  final double bonus;
  final double appFee;
  final double passbook;
  final double bankWithdrawal;
  final double adjustmentIn;

  const MasterCashbookInflowsData({
    this.openingBalance = 0.0,
    this.savingsDeposit = 0.0,
    this.repDaily = 0.0,
    this.rep120Days = 0.0,
    this.rep12Weeks = 0.0,
    this.rep24Weeks = 0.0,
    this.repMonthly = 0.0,
    this.lapsReserve = 0.0,
    this.fundsReceivedHo = 0.0,
    this.fundsReceivedOtherBranch = 0.0,
    this.fundsReceivedOtherArea = 0.0,
    this.assetCreditSales = 0.0,
    this.cashAndCarry = 0.0,
    this.loanReceivedFinance = 0.0,
    this.daily11Pct = 0.0,
    this.daily20Pct = 0.0,
    this.weekly11Pct = 0.0,
    this.weekly20Pct = 0.0,
    this.riskPremiumReturns = 0.0,
    this.contingency = 0.0,
    this.creditFormDamage = 0.0,
    this.bonus = 0.0,
    this.appFee = 0.0,
    this.passbook = 0.0,
    this.bankWithdrawal = 0.0,
    this.adjustmentIn = 0.0,
  });

  factory MasterCashbookInflowsData.fromJson(Map<String, dynamic> json) {
    double toD(dynamic val) => val == null ? 0.0 : (val as num).toDouble();
    return MasterCashbookInflowsData(
      openingBalance: toD(json['opening_balance']),
      savingsDeposit: toD(json['savings_deposit']),
      repDaily: toD(json['rep_daily']),
      rep120Days: toD(json['rep_120_days']),
      rep12Weeks: toD(json['rep_12_weeks']),
      rep24Weeks: toD(json['rep_24_weeks']),
      repMonthly: toD(json['rep_monthly']),
      lapsReserve: toD(json['laps_reserve']),
      fundsReceivedHo: toD(json['funds_received_ho']),
      fundsReceivedOtherBranch: toD(json['funds_received_other_branch']),
      fundsReceivedOtherArea: toD(json['funds_received_other_area']),
      assetCreditSales: toD(json['asset_credit_sales']),
      cashAndCarry: toD(json['cash_and_carry']),
      loanReceivedFinance: toD(json['loan_received_finance']),
      daily11Pct: toD(json['daily_11_pct']),
      daily20Pct: toD(json['daily_20_pct']),
      weekly11Pct: toD(json['weekly_11_pct']),
      weekly20Pct: toD(json['weekly_20_pct']),
      riskPremiumReturns: toD(json['risk_premium_returns']),
      contingency: toD(json['contingency']),
      creditFormDamage: toD(json['credit_form_damage']),
      bonus: toD(json['bonus']),
      appFee: toD(json['app_fee']),
      passbook: toD(json['passbook']),
      bankWithdrawal: toD(json['bank_withdrawal']),
      adjustmentIn: toD(json['adjustment_in']),
    );
  }
}

class MasterCashbookOutflowsData {
  final double disb60d;
  final double disb120d;
  final double disb12w;
  final double disb24w;
  final double disbMth;
  final double fundTransferredOtherBranch;
  final double fundTransferredHo;
  final double fundToOtherArea;
  final double fundToAssetProgram;
  final double fundToProductFinance;
  final double productWithdrawal;
  final double savingsWithdrawal;
  final double staffSalaries;
  final double officeExpenses;
  final double lapsReturns;
  final double bankDeposit;
  final double adjustmentOut;

  const MasterCashbookOutflowsData({
    this.disb60d = 0.0,
    this.disb120d = 0.0,
    this.disb12w = 0.0,
    this.disb24w = 0.0,
    this.disbMth = 0.0,
    this.fundTransferredOtherBranch = 0.0,
    this.fundTransferredHo = 0.0,
    this.fundToOtherArea = 0.0,
    this.fundToAssetProgram = 0.0,
    this.fundToProductFinance = 0.0,
    this.productWithdrawal = 0.0,
    this.savingsWithdrawal = 0.0,
    this.staffSalaries = 0.0,
    this.officeExpenses = 0.0,
    this.lapsReturns = 0.0,
    this.bankDeposit = 0.0,
    this.adjustmentOut = 0.0,
  });

  factory MasterCashbookOutflowsData.fromJson(Map<String, dynamic> json) {
    double toD(dynamic val) => val == null ? 0.0 : (val as num).toDouble();
    return MasterCashbookOutflowsData(
      disb60d: toD(json['disb_60d']),
      disb120d: toD(json['disb_120d']),
      disb12w: toD(json['disb_12w']),
      disb24w: toD(json['disb_24w']),
      disbMth: toD(json['disb_mth']),
      fundTransferredOtherBranch: toD(json['fund_transferred_other_branch']),
      fundTransferredHo: toD(json['fund_transferred_ho']),
      fundToOtherArea: toD(json['fund_to_other_area']),
      fundToAssetProgram: toD(json['fund_to_asset_program']),
      fundToProductFinance: toD(json['fund_to_product_finance']),
      productWithdrawal: toD(json['product_withdrawal']),
      savingsWithdrawal: toD(json['savings_withdrawal']),
      staffSalaries: toD(json['staff_salaries']),
      officeExpenses: toD(json['office_expenses']),
      lapsReturns: toD(json['laps_returns']),
      bankDeposit: toD(json['bank_deposit']),
      adjustmentOut: toD(json['adjustment_out']),
    );
  }
}

class MasterNotPaidClientData {
  final String name;
  final String code;
  final double expected;
  final double shortfall;
  final bool isPartial;

  const MasterNotPaidClientData({
    required this.name,
    required this.code,
    required this.expected,
    required this.shortfall,
    required this.isPartial,
  });

  factory MasterNotPaidClientData.fromJson(Map<String, dynamic> json) {
    return MasterNotPaidClientData(
      name: json['name'] ?? 'Unknown',
      code: json['code'] ?? '',
      expected: ((json['expected'] ?? 0.0) as num).toDouble(),
      shortfall: ((json['shortfall'] ?? 0.0) as num).toDouble(),
      isPartial: json['is_partial'] ?? false,
    );
  }
}

class MasterReconciliationTallyData {
  final double scheduledExpected;
  final double notPaidAmount;
  final int notPaidCount;
  final List<MasterNotPaidClientData> notPaidClients;
  final double excessAmount;
  final int excessCount;
  final double actualRepayments;
  final double actualSavings;
  final double actualCashCollected;
  final double bankDeposited;
  final double closingCashBalance;
  final bool isCashBalanced;
  final double arrearsFloat;
  final int totalRepsCount;

  const MasterReconciliationTallyData({
    this.scheduledExpected = 0.0,
    this.notPaidAmount = 0.0,
    this.notPaidCount = 0,
    this.notPaidClients = const [],
    this.excessAmount = 0.0,
    this.excessCount = 0,
    this.actualRepayments = 0.0,
    this.actualSavings = 0.0,
    this.actualCashCollected = 0.0,
    this.bankDeposited = 0.0,
    this.closingCashBalance = 0.0,
    this.isCashBalanced = true,
    this.arrearsFloat = 0.0,
    this.totalRepsCount = 0,
  });

  factory MasterReconciliationTallyData.fromJson(Map<String, dynamic> json) {
    double toD(dynamic val) => val == null ? 0.0 : (val as num).toDouble();
    final npList = (json['not_paid_clients'] as List<dynamic>?)
            ?.map((e) => MasterNotPaidClientData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return MasterReconciliationTallyData(
      scheduledExpected: toD(json['scheduled_expected']),
      notPaidAmount: toD(json['not_paid_amount']),
      notPaidCount: json['not_paid_count'] ?? 0,
      notPaidClients: npList,
      excessAmount: toD(json['excess_amount']),
      excessCount: json['excess_count'] ?? 0,
      actualRepayments: toD(json['actual_repayments']),
      actualSavings: toD(json['actual_savings']),
      actualCashCollected: toD(json['actual_cash_collected']),
      bankDeposited: toD(json['bank_deposited']),
      closingCashBalance: toD(json['closing_cash_balance']),
      isCashBalanced: json['is_cash_balanced'] ?? true,
      arrearsFloat: toD(json['arrears_float']),
      totalRepsCount: json['total_reps_count'] ?? 0,
    );
  }
}

class MasterPendingReversalData {
  final String id;
  final String recordId;
  final String recordType;
  final String reason;
  final String requestedBy;
  final String requestedByName;
  final String createdAt;
  final String status;

  const MasterPendingReversalData({
    required this.id,
    required this.recordId,
    required this.recordType,
    required this.reason,
    required this.requestedBy,
    required this.requestedByName,
    required this.createdAt,
    required this.status,
  });

  factory MasterPendingReversalData.fromJson(Map<String, dynamic> json) {
    return MasterPendingReversalData(
      id: json['id']?.toString() ?? '',
      recordId: json['record_id']?.toString() ?? '',
      recordType: json['record_type']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      requestedBy: json['requested_by']?.toString() ?? '',
      requestedByName: json['requested_by_name']?.toString() ?? 'Officer',
      createdAt: json['created_at']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
    );
  }
}

class MasterTreasuryTransactionData {
  final String id;
  final String transactionType;
  final double amount;
  final String postingDate;
  final String remarks;
  final String label;

  const MasterTreasuryTransactionData({
    required this.id,
    required this.transactionType,
    required this.amount,
    required this.postingDate,
    required this.remarks,
    required this.label,
  });

  factory MasterTreasuryTransactionData.fromJson(Map<String, dynamic> json) {
    return MasterTreasuryTransactionData(
      id: json['id']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? '',
      amount: ((json['amount'] ?? 0.0) as num).toDouble(),
      postingDate: json['posting_date']?.toString() ?? '',
      remarks: json['remarks']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

class MasterCashbookDailyData {
  final String date;
  final String branch;
  final bool isOpen;
  final String openReason;
  final MasterCashbookInflowsData inflows;
  final MasterCashbookOutflowsData outflows;
  final double totalInflows;
  final double totalOutflows;
  final double closingBalance;
  final MasterReconciliationTallyData? tally;
  final List<MasterPendingReversalData> pendingReversals;
  final List<MasterTreasuryTransactionData> treasuryTransactions;
  final String adjustmentReason;

  const MasterCashbookDailyData({
    required this.date,
    required this.branch,
    required this.isOpen,
    required this.openReason,
    required this.inflows,
    required this.outflows,
    required this.totalInflows,
    required this.totalOutflows,
    required this.closingBalance,
    this.tally,
    this.pendingReversals = const [],
    this.treasuryTransactions = const [],
    this.adjustmentReason = '',
  });

  factory MasterCashbookDailyData.fromJson(Map<String, dynamic> json) {
    double toD(dynamic val) => val == null ? 0.0 : (val as num).toDouble();
    return MasterCashbookDailyData(
      date: json['date'] ?? '',
      branch: json['branch'] ?? '',
      isOpen: json['is_open'] ?? true,
      openReason: json['open_reason'] ?? 'Working Day',
      inflows: MasterCashbookInflowsData.fromJson(json['inflows'] ?? {}),
      outflows: MasterCashbookOutflowsData.fromJson(json['outflows'] ?? {}),
      totalInflows: toD(json['total_inflows']),
      totalOutflows: toD(json['total_outflows']),
      closingBalance: toD(json['closing_balance']),
      tally: json['tally'] != null ? MasterReconciliationTallyData.fromJson(json['tally']) : null,
      pendingReversals: (json['pending_reversals'] as List<dynamic>?)
              ?.map((e) => MasterPendingReversalData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      treasuryTransactions: (json['treasury_transactions'] as List<dynamic>?)
              ?.map((e) => MasterTreasuryTransactionData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      adjustmentReason: json['adjustment_reason']?.toString() ?? '',
    );
  }
}

class OfficerOptionData {
  final String username;
  final String fullName;
  final String display;

  const OfficerOptionData({
    required this.username,
    required this.fullName,
    required this.display,
  });

  factory OfficerOptionData.fromJson(Map<String, dynamic> json) {
    return OfficerOptionData(
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? '',
      display: json['display'] ?? json['username'] ?? '',
    );
  }
}

class CoAggregationData {
  final String date;
  final String branch;
  final String officer;
  final List<OfficerOptionData> officers;
  final double openingBalance;
  final Map<String, double> inflows;
  final Map<String, double> outflows;
  final double totalInflows;
  final double totalOutflows;
  final double closingBalance;
  final bool isOpen;
  final String openReason;
  final bool canCloseDay;

  const CoAggregationData({
    required this.date,
    required this.branch,
    required this.officer,
    this.officers = const [],
    this.openingBalance = 0.0,
    this.inflows = const {},
    this.outflows = const {},
    this.totalInflows = 0.0,
    this.totalOutflows = 0.0,
    this.closingBalance = 0.0,
    this.isOpen = true,
    this.openReason = 'Working Day',
    this.canCloseDay = true,
  });

  factory CoAggregationData.fromJson(Map<String, dynamic> json) {
    double toD(dynamic val) => val == null ? 0.0 : (val as num).toDouble();
    final infMap = <String, double>{};
    if (json['inflows'] != null && json['inflows'] is Map) {
      (json['inflows'] as Map).forEach((k, v) {
        infMap[k.toString()] = toD(v);
      });
    }
    final outMap = <String, double>{};
    if (json['outflows'] != null && json['outflows'] is Map) {
      (json['outflows'] as Map).forEach((k, v) {
        outMap[k.toString()] = toD(v);
      });
    }

    return CoAggregationData(
      date: json['date'] ?? '',
      branch: json['branch'] ?? '',
      officer: json['officer'] ?? '',
      officers: (json['officers'] as List<dynamic>?)
              ?.map((e) => OfficerOptionData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      openingBalance: toD(json['opening_balance']),
      inflows: infMap,
      outflows: outMap,
      totalInflows: toD(json['total_inflows']),
      totalOutflows: toD(json['total_outflows']),
      closingBalance: toD(json['closing_balance']),
      isOpen: json['is_open'] ?? true,
      openReason: json['open_reason'] ?? 'Working Day',
      canCloseDay: json['can_close_day'] ?? true,
    );
  }
}

class MonthlyLedgerRowData {
  final String date;
  final double openingBalance;
  final double savingsDeposit;
  final double repDaily;
  final double rep120Days;
  final double rep12Weeks;
  final double rep24Weeks;
  final double repMonthly;
  final double lapsReserve;
  final double fundsReceivedHo;
  final double fundsReceivedOtherBranch;
  final double fundsReceivedOtherArea;
  final double assetCreditSales;
  final double cashAndCarry;
  final double loanReceivedFinance;
  final double daily11Pct;
  final double daily20Pct;
  final double weekly11Pct;
  final double weekly20Pct;
  final double riskPremiumReturns;
  final double contingency;
  final double creditFormDamage;
  final double bonus;
  final double appFee;
  final double passbook;
  final double bankWithdrawal;
  final double adjustmentIn;
  final double totalInflows;
  final double disb60d;
  final double disb120d;
  final double disb12w;
  final double disb24w;
  final double disbMth;
  final double fundTransferredOtherBranch;
  final double fundTransferredHo;
  final double fundToOtherArea;
  final double fundToAssetProgram;
  final double fundToProductFinance;
  final double productWithdrawal;
  final double staffSalaries;
  final double officeExpenses;
  final double lapsReturns;
  final double bankDeposit;
  final double adjustmentOut;
  final double totalOutflows;
  final double closingBalance;

  const MonthlyLedgerRowData({
    required this.date,
    this.openingBalance = 0.0,
    this.savingsDeposit = 0.0,
    this.repDaily = 0.0,
    this.rep120Days = 0.0,
    this.rep12Weeks = 0.0,
    this.rep24Weeks = 0.0,
    this.repMonthly = 0.0,
    this.lapsReserve = 0.0,
    this.fundsReceivedHo = 0.0,
    this.fundsReceivedOtherBranch = 0.0,
    this.fundsReceivedOtherArea = 0.0,
    this.assetCreditSales = 0.0,
    this.cashAndCarry = 0.0,
    this.loanReceivedFinance = 0.0,
    this.daily11Pct = 0.0,
    this.daily20Pct = 0.0,
    this.weekly11Pct = 0.0,
    this.weekly20Pct = 0.0,
    this.riskPremiumReturns = 0.0,
    this.contingency = 0.0,
    this.creditFormDamage = 0.0,
    this.bonus = 0.0,
    this.appFee = 0.0,
    this.passbook = 0.0,
    this.bankWithdrawal = 0.0,
    this.adjustmentIn = 0.0,
    this.totalInflows = 0.0,
    this.disb60d = 0.0,
    this.disb120d = 0.0,
    this.disb12w = 0.0,
    this.disb24w = 0.0,
    this.disbMth = 0.0,
    this.fundTransferredOtherBranch = 0.0,
    this.fundTransferredHo = 0.0,
    this.fundToOtherArea = 0.0,
    this.fundToAssetProgram = 0.0,
    this.fundToProductFinance = 0.0,
    this.productWithdrawal = 0.0,
    this.staffSalaries = 0.0,
    this.officeExpenses = 0.0,
    this.lapsReturns = 0.0,
    this.bankDeposit = 0.0,
    this.adjustmentOut = 0.0,
    this.totalOutflows = 0.0,
    this.closingBalance = 0.0,
  });

  factory MonthlyLedgerRowData.fromJson(Map<String, dynamic> json) {
    double toD(dynamic val) => val == null ? 0.0 : (val as num).toDouble();
    return MonthlyLedgerRowData(
      date: json['date'] ?? '',
      openingBalance: toD(json['opening_balance']),
      savingsDeposit: toD(json['savings_deposit']),
      repDaily: toD(json['rep_daily']),
      rep120Days: toD(json['rep_120_days']),
      rep12Weeks: toD(json['rep_12_weeks']),
      rep24Weeks: toD(json['rep_24_weeks']),
      repMonthly: toD(json['rep_monthly']),
      lapsReserve: toD(json['laps_reserve']),
      fundsReceivedHo: toD(json['funds_received_ho']),
      fundsReceivedOtherBranch: toD(json['funds_received_other_branch']),
      fundsReceivedOtherArea: toD(json['funds_received_other_area']),
      assetCreditSales: toD(json['asset_credit_sales']),
      cashAndCarry: toD(json['cash_and_carry']),
      loanReceivedFinance: toD(json['loan_received_finance']),
      daily11Pct: toD(json['daily_11_pct']),
      daily20Pct: toD(json['daily_20_pct']),
      weekly11Pct: toD(json['weekly_11_pct']),
      weekly20Pct: toD(json['weekly_20_pct']),
      riskPremiumReturns: toD(json['risk_premium_returns']),
      contingency: toD(json['contingency']),
      creditFormDamage: toD(json['credit_form_damage']),
      bonus: toD(json['bonus']),
      appFee: toD(json['app_fee']),
      passbook: toD(json['passbook']),
      bankWithdrawal: toD(json['bank_withdrawal']),
      adjustmentIn: toD(json['adjustment_in']),
      totalInflows: toD(json['total_inflows']),
      disb60d: toD(json['disb_60d']),
      disb120d: toD(json['disb_120d']),
      disb12w: toD(json['disb_12w']),
      disb24w: toD(json['disb_24w']),
      disbMth: toD(json['disb_mth']),
      fundTransferredOtherBranch: toD(json['fund_transferred_other_branch']),
      fundTransferredHo: toD(json['fund_transferred_ho']),
      fundToOtherArea: toD(json['fund_to_other_area']),
      fundToAssetProgram: toD(json['fund_to_asset_program']),
      fundToProductFinance: toD(json['fund_to_product_finance']),
      productWithdrawal: toD(json['product_withdrawal']),
      staffSalaries: toD(json['staff_salaries']),
      officeExpenses: toD(json['office_expenses']),
      lapsReturns: toD(json['laps_returns']),
      bankDeposit: toD(json['bank_deposit']),
      adjustmentOut: toD(json['adjustment_out']),
      totalOutflows: toD(json['total_outflows']),
      closingBalance: toD(json['closing_balance']),
    );
  }
}

class MonthlyLedgerData {
  final int month;
  final int year;
  final String branch;
  final List<MonthlyLedgerRowData> rows;
  final double monthOpening;
  final double totalMonthInflows;
  final double totalMonthOutflows;
  final double monthClosing;
  final List<String> availableBranches;

  const MonthlyLedgerData({
    required this.month,
    required this.year,
    required this.branch,
    this.rows = const [],
    this.monthOpening = 0.0,
    this.totalMonthInflows = 0.0,
    this.totalMonthOutflows = 0.0,
    this.monthClosing = 0.0,
    this.availableBranches = const [],
  });

  factory MonthlyLedgerData.fromJson(Map<String, dynamic> json) {
    double toD(dynamic val) => val == null ? 0.0 : (val as num).toDouble();
    return MonthlyLedgerData(
      month: json['month'] ?? 1,
      year: json['year'] ?? 2026,
      branch: json['branch'] ?? '',
      rows: (json['rows'] as List<dynamic>?)
              ?.map((e) => MonthlyLedgerRowData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      monthOpening: toD(json['month_opening']),
      totalMonthInflows: toD(json['total_month_inflows']),
      totalMonthOutflows: toD(json['total_month_outflows']),
      monthClosing: toD(json['month_closing']),
      availableBranches: (json['available_branches'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
