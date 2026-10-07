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
    int year = 2026,
    int month = 9,
  }) async {
    final params = <String, dynamic>{
      'year': year,
      'month': month,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }

    final response = await _apiClient.get(
      '/api/v1/reports/monthly-parity',
      queryParameters: params,
    );
    return MonthlyParityData.fromJson(response.data as Map<String, dynamic>);
  }

  /// 10. Get Official Executive Statements (Trial Balance & Receipts/Payments)
  Future<MonthlyExecutiveStatementsData> getOfficialStatements({
    String? branchName,
    int year = 2026,
    int month = 9,
  }) async {
    final params = <String, dynamic>{
      'year': year,
      'month': month,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }

    final response = await _apiClient.get(
      '/api/v1/reports/official-statements',
      queryParameters: params,
    );
    return MonthlyExecutiveStatementsData.fromJson(response.data as Map<String, dynamic>);
  }

  /// 11. Download Executive Monthly Excel Workbook
  Future<List<int>> downloadMonthlyParityExcel({
    String? branchName,
    int year = 2026,
    int month = 9,
  }) async {
    final params = <String, dynamic>{
      'year': year,
      'month': month,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }

    final response = await _apiClient.get(
      '/api/v1/reports/export/monthly-parity-excel',
      queryParameters: params,
      options: Options(responseType: ResponseType.bytes),
    );
    return List<int>.from(response.data as List);
  }

  /// 12. Download CO Monthly Summary CSV
  Future<List<int>> downloadMonthlyParityCsv({
    String? branchName,
    int year = 2026,
    int month = 9,
  }) async {
    final params = <String, dynamic>{
      'year': year,
      'month': month,
    };
    if (branchName != null && branchName.isNotEmpty && !branchName.startsWith('All')) {
      params['branch_name'] = branchName;
    }

    final response = await _apiClient.get(
      '/api/v1/reports/export/monthly-parity-csv',
      queryParameters: params,
      options: Options(responseType: ResponseType.bytes),
    );
    return List<int>.from(response.data as List);
  }
}

