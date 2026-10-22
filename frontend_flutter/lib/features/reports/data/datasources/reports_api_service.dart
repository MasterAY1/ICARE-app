import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/report_models.dart';

final reportsApiServiceProvider = Provider<ReportsApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReportsApiService(apiClient);
});

class ReportsApiService {
  final ApiClient _apiClient;

  ReportsApiService(this._apiClient);

  /// 1. Dynamic metadata (branches, products, officers) scoped to role
  Future<ReportsMeta> getReportsMeta() async {
    final response = await _apiClient.get('/api/v1/reports/meta');
    return ReportsMeta.fromJson(response.data as Map<String, dynamic>);
  }

  /// 2. General Ledger Trial Balance
  Future<TrialBalanceData> getTrialBalance({
    String? branchName,
    String? asOfDate,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{};
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }
    if (asOfDate != null && asOfDate.isNotEmpty) params['as_of_date'] = asOfDate;
    if (startDate != null && startDate.isNotEmpty) params['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;

    final response = await _apiClient.get(
      '/api/v1/reports/trial-balance',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return TrialBalanceData.fromJson(response.data as Map<String, dynamic>);
  }

  /// 3. Savings Portfolio & Savers Breakdown
  Future<SavingsSummaryData> getSavingsSummary({
    String? branchName,
    String? productName,
    String? officerName,
    String? asOfDate,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{};
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }
    if (productName != null && productName.isNotEmpty && !productName.startsWith('All')) {
      params['product_name'] = productName;
    }
    if (officerName != null && officerName.isNotEmpty && !officerName.startsWith('All')) {
      params['officer_name'] = officerName;
    }
    if (asOfDate != null && asOfDate.isNotEmpty) params['as_of_date'] = asOfDate;
    if (startDate != null && startDate.isNotEmpty) params['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;

    final response = await _apiClient.get(
      '/api/v1/reports/savings-summary',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return SavingsSummaryData.fromJson(response.data as Map<String, dynamic>);
  }

  /// 4. Repayments & Collections Performance
  Future<RepaymentSummaryData> getRepaymentSummary({
    String? branchName,
    String? productName,
    String? officerName,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{};
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }
    if (productName != null && productName.isNotEmpty && !productName.startsWith('All')) {
      params['product_name'] = productName;
    }
    if (officerName != null && officerName.isNotEmpty && !officerName.startsWith('All')) {
      params['officer_name'] = officerName;
    }
    if (startDate != null && startDate.isNotEmpty) params['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;

    final response = await _apiClient.get(
      '/api/v1/reports/repayment-summary',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return RepaymentSummaryData.fromJson(response.data as Map<String, dynamic>);
  }

  /// 5. Portfolio Health, Officer Performance & Risk Rating
  Future<PortfolioPerformanceData> getPortfolioPerformance({
    String? branchName,
    String? productName,
    String? officerName,
    String? inspectOfficer,
  }) async {
    final params = <String, dynamic>{};
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }
    if (productName != null && productName.isNotEmpty && !productName.startsWith('All')) {
      params['product_name'] = productName;
    }
    if (officerName != null && officerName.isNotEmpty && !officerName.startsWith('All')) {
      params['officer_name'] = officerName;
    }
    if (inspectOfficer != null && inspectOfficer.isNotEmpty && !inspectOfficer.startsWith('All')) {
      params['inspect_officer'] = inspectOfficer;
    }

    final response = await _apiClient.get(
      '/api/v1/reports/portfolio-performance',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return PortfolioPerformanceData.fromJson(response.data as Map<String, dynamic>);
  }

  /// 6. Area Manager Branch Comparison (AM Exclusive)
  Future<AreaComparisonData> getAreaComparison({
    String? productName,
    String? asOfDate,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{};
    if (productName != null && productName.isNotEmpty && !productName.startsWith('All')) {
      params['product_name'] = productName;
    }
    if (asOfDate != null && asOfDate.isNotEmpty) params['as_of_date'] = asOfDate;
    if (startDate != null && startDate.isNotEmpty) params['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;

    final response = await _apiClient.get(
      '/api/v1/reports/area-comparison',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return AreaComparisonData.fromJson(response.data as Map<String, dynamic>);
  }

  /// 7. Download Consolidated Excel
  Future<List<int>> downloadExcel({
    String? branchName,
    String? productName,
    String? officerName,
    String? asOfDate,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{};
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }
    if (productName != null && productName.isNotEmpty && !productName.startsWith('All')) {
      params['product_name'] = productName;
    }
    if (officerName != null && officerName.isNotEmpty && !officerName.startsWith('All')) {
      params['officer_name'] = officerName;
    }
    if (asOfDate != null && asOfDate.isNotEmpty) params['as_of_date'] = asOfDate;
    if (startDate != null && startDate.isNotEmpty) params['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;

    final response = await _apiClient.get(
      '/api/v1/reports/export/excel',
      queryParameters: params.isNotEmpty ? params : null,
      options: Options(responseType: ResponseType.bytes),
    );
    return List<int>.from(response.data as List);
  }

  /// 8. Download Individual CSV
  Future<List<int>> downloadCsv({
    required String reportType,
    String? branchName,
    String? productName,
    String? officerName,
    String? asOfDate,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{'report_type': reportType};
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }
    if (productName != null && productName.isNotEmpty && !productName.startsWith('All')) {
      params['product_name'] = productName;
    }
    if (officerName != null && officerName.isNotEmpty && !officerName.startsWith('All')) {
      params['officer_name'] = officerName;
    }
    if (asOfDate != null && asOfDate.isNotEmpty) params['as_of_date'] = asOfDate;
    if (startDate != null && startDate.isNotEmpty) params['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;

    final response = await _apiClient.get(
      '/api/v1/reports/export/csv',
      queryParameters: params,
      options: Options(responseType: ResponseType.bytes),
    );
    return List<int>.from(response.data as List);
  }

  /// 9. Get Monthly Parity Matrix
  Future<MonthlyParityData> getMonthlyParity({
    String? branchName,
    int? year,
    int? month,
    String? officerName,
    String? productName,
  }) async {
    final params = <String, dynamic>{
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }
    if (officerName != null && officerName.isNotEmpty && !officerName.startsWith('All')) {
      params['officer_name'] = officerName;
    }
    if (productName != null && productName.isNotEmpty && !productName.startsWith('All')) {
      params['product_name'] = productName;
    }

    final response = await _apiClient.get(
      '/api/v1/reports/monthly-parity',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return MonthlyParityData.fromJson(response.data as Map<String, dynamic>);
  }

  /// 10. Get Official Executive Statements (Trial Balance & Receipts/Payments)
  Future<MonthlyExecutiveStatementsData> getOfficialStatements({
    String? branchName,
    int? year,
    int? month,
    String? officerName,
    String? productName,
  }) async {
    final params = <String, dynamic>{
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }
    if (officerName != null && officerName.isNotEmpty && !officerName.startsWith('All')) {
      params['officer_name'] = officerName;
    }
    if (productName != null && productName.isNotEmpty && !productName.startsWith('All')) {
      params['product_name'] = productName;
    }

    final response = await _apiClient.get(
      '/api/v1/reports/official-statements',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return MonthlyExecutiveStatementsData.fromJson(response.data as Map<String, dynamic>);
  }

  /// 11. Download Executive Monthly Excel Workbook
  Future<List<int>> downloadMonthlyParityExcel({
    String? branchName,
    int? year,
    int? month,
    String? officerName,
    String? productName,
  }) async {
    final params = <String, dynamic>{
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }
    if (officerName != null && officerName.isNotEmpty && !officerName.startsWith('All')) {
      params['officer_name'] = officerName;
    }
    if (productName != null && productName.isNotEmpty && !productName.startsWith('All')) {
      params['product_name'] = productName;
    }

    final response = await _apiClient.get(
      '/api/v1/reports/export/monthly-parity-excel',
      queryParameters: params.isNotEmpty ? params : null,
      options: Options(responseType: ResponseType.bytes),
    );
    return List<int>.from(response.data as List);
  }

  /// 12. Download CO Monthly Summary CSV
  Future<List<int>> downloadMonthlyParityCsv({
    String? branchName,
    int? year,
    int? month,
    String? officerName,
    String? productName,
  }) async {
    final params = <String, dynamic>{
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }
    if (officerName != null && officerName.isNotEmpty && !officerName.startsWith('All')) {
      params['officer_name'] = officerName;
    }
    if (productName != null && productName.isNotEmpty && !productName.startsWith('All')) {
      params['product_name'] = productName;
    }

    final response = await _apiClient.get(
      '/api/v1/reports/export/monthly-parity-csv',
      queryParameters: params.isNotEmpty ? params : null,
      options: Options(responseType: ResponseType.bytes),
    );
    return List<int>.from(response.data as List);
  }

  /// 12b. Download Executive Monthly Financial Statement PDF (Paper Grade)
  Future<List<int>> downloadMonthlyParityPdf({
    String? branchName,
    int? year,
    int? month,
    String? officerName,
    String? productName,
  }) async {
    final params = <String, dynamic>{
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }
    if (officerName != null && officerName.isNotEmpty && !officerName.startsWith('All')) {
      params['officer_name'] = officerName;
    }
    if (productName != null && productName.isNotEmpty && !productName.startsWith('All')) {
      params['product_name'] = productName;
    }

    final response = await _apiClient.get(
      '/api/v1/reports/export/monthly-parity-pdf',
      queryParameters: params.isNotEmpty ? params : null,
      options: Options(responseType: ResponseType.bytes),
    );
    return List<int>.from(response.data as List);
  }

  /// 13. Get Monthly Reconciliation Data
  Future<MonthlyReconciliationData> getMonthlyReconciliation({
    String? branchName,
    int? year,
    int? month,
  }) async {
    final params = <String, dynamic>{
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }

    final response = await _apiClient.get(
      '/api/v1/reports/monthly-reconciliation',
      queryParameters: params.isNotEmpty ? params : null,
    );
    final body = response.data as Map<String, dynamic>;
    final data = (body['data'] ?? {}) as Map<String, dynamic>;
    return MonthlyReconciliationData.fromJson(data);
  }

  /// 14. Save Monthly Reconciliation Data
  Future<Map<String, dynamic>> saveMonthlyReconciliation({
    String? branchName,
    int? year,
    int? month,
    required MonthlyReconciliationData data,
  }) async {
    final payload = <String, dynamic>{
      if (year != null) 'year': year,
      if (month != null) 'month': month,
      'data': data.toJson(),
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      payload['branch_name'] = branchName;
    }

    final response = await _apiClient.post(
      '/api/v1/reports/monthly-reconciliation',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  /// 15. Retrieve Annex-1 Sundry Accounts & OpEx Analysis
  Future<Annex1ReportData> getAnnex1Report({
    String? branchName,
    int? year,
    int? month,
  }) async {
    final params = <String, dynamic>{
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }

    final response = await _apiClient.get(
      '/api/v1/reports/annex-1',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return Annex1ReportData.fromJson(response.data as Map<String, dynamic>);
  }

  // ===========================================================================
  // MONTHLY REPORT THREE-TIER WORKFLOW ENDPOINTS (BM -> AM -> ADMIN)
  // ===========================================================================

  /// 16. Get current monthly workflow submission status for a branch
  Future<MonthlyWorkflowStatusModel> getMonthlyWorkflowStatus({
    String? branchName,
    int? year,
    int? month,
  }) async {
    final params = <String, dynamic>{
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }

    final response = await _apiClient.get(
      '/api/v1/reports/monthly-workflow/status',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return MonthlyWorkflowStatusModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 17. Tier 1: Branch Manager verifies and submits monthly report to Area Manager
  Future<Map<String, dynamic>> submitMonthlyWorkflow({
    String? branchName,
    int year = 2026,
    int month = 9,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'year': year,
      'month': month,
      if (notes != null) 'notes': notes,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      payload['branch_name'] = branchName;
    }

    final response = await _apiClient.post(
      '/api/v1/reports/monthly-workflow/submit',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  /// 18. Tier 2: Area Manager endorses and signs off on branch monthly report
  Future<Map<String, dynamic>> endorseMonthlyWorkflow({
    String? branchName,
    int year = 2026,
    int month = 9,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'year': year,
      'month': month,
      if (notes != null) 'notes': notes,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      payload['branch_name'] = branchName;
    }

    final response = await _apiClient.post(
      '/api/v1/reports/monthly-workflow/endorse',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  /// 19. Tier 2: Area Manager returns branch report for correction with query notes
  Future<Map<String, dynamic>> returnMonthlyWorkflow({
    String? branchName,
    int year = 2026,
    int month = 9,
    required String queryNotes,
  }) async {
    final payload = <String, dynamic>{
      'year': year,
      'month': month,
      'query_notes': queryNotes,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      payload['branch_name'] = branchName;
    }

    final response = await _apiClient.post(
      '/api/v1/reports/monthly-workflow/return',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  /// 20. Tier 2: Area Manager seals regional package once all supervised branches are endorsed
  Future<Map<String, dynamic>> sealAreaMonthlyWorkflow({
    String areaName = 'Area 1',
    int year = 2026,
    int month = 9,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'area_name': areaName,
      'year': year,
      'month': month,
      if (notes != null) 'notes': notes,
    };

    final response = await _apiClient.post(
      '/api/v1/reports/monthly-workflow/seal-area',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  /// 21. Tier 3: Executive Admin locks and permanently archives monthly reports
  Future<Map<String, dynamic>> lockMonthlyWorkflow({
    String? branchName,
    int year = 2026,
    int month = 9,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'year': year,
      'month': month,
      if (notes != null) 'notes': notes,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      payload['branch_name'] = branchName;
    }

    final response = await _apiClient.post(
      '/api/v1/reports/monthly-workflow/lock',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  /// 22. Area Manager Approvals Hub: List supervised branches monthly submission statuses
  Future<List<MonthlyWorkflowPendingBranchModel>> getPendingAmMonthlySubmissions({
    int? year,
    int? month,
  }) async {
    final params = <String, dynamic>{
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    };

    final response = await _apiClient.get(
      '/api/v1/reports/monthly-workflow/pending-am',
      queryParameters: params.isNotEmpty ? params : null,
    );
    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((e) => MonthlyWorkflowPendingBranchModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}



