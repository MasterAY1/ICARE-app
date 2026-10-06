import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/master_cashbook_models.dart';

final masterCashbookApiServiceProvider = Provider<MasterCashbookApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MasterCashbookApiService(apiClient);
});

class MasterCashbookApiService {
  final ApiClient _apiClient;

  MasterCashbookApiService(this._apiClient);

  /// Fetch Master Cashbook daily projection, tally and pending reversals
  Future<MasterCashbookDailyData> getMasterCashbookDaily({String? date, String? branch}) async {
    final queryParams = <String, dynamic>{};
    if (date != null && date.isNotEmpty) queryParams['date'] = date;
    if (branch != null && branch.isNotEmpty) queryParams['branch'] = branch;

    final response = await _apiClient.get(
      '/api/v1/bm/cashbook/daily',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    return MasterCashbookDailyData.fromJson(response.data as Map<String, dynamic>);
  }

  /// Save BM manual entries (Treasury movements, staff salaries, debt/adjustments)
  Future<Map<String, dynamic>> saveManualEntries(Map<String, dynamic> payload) async {
    final response = await _apiClient.post(
      '/api/v1/bm/cashbook/daily/manual-entries',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Fetch individual Credit Officer Daily Cashbook Ledger
  Future<CoAggregationData> getCoAggregation({String? date, String? officer}) async {
    final queryParams = <String, dynamic>{};
    if (date != null && date.isNotEmpty) queryParams['date'] = date;
    if (officer != null && officer.isNotEmpty) queryParams['officer'] = officer;

    final response = await _apiClient.get(
      '/api/v1/bm/cashbook/co-aggregation',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    return CoAggregationData.fromJson(response.data as Map<String, dynamic>);
  }

  /// Execute EOD Day Close to advance operational date
  Future<Map<String, dynamic>> executeEodClose(String date) async {
    final response = await _apiClient.post(
      '/api/v1/bm/cashbook/eod-close',
      data: {'date': date},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Fetch Monthly Ledger with columns A-AS and monthly KPIs
  Future<MonthlyLedgerData> getMonthlyLedger({required int month, required int year, String? branch}) async {
    final queryParams = <String, dynamic>{
      'month': month,
      'year': year,
    };
    if (branch != null && branch.isNotEmpty) queryParams['branch'] = branch;

    final response = await _apiClient.get(
      '/api/v1/bm/cashbook/monthly',
      queryParameters: queryParams,
    );
    return MonthlyLedgerData.fromJson(response.data as Map<String, dynamic>);
  }

  /// Approve pending reversal request
  Future<Map<String, dynamic>> approveReversal(String requestId) async {
    final response = await _apiClient.post(
      '/api/v1/bm/cashbook/reversals/approve',
      data: {'request_id': requestId},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Reject pending reversal request
  Future<Map<String, dynamic>> rejectReversal(String requestId) async {
    final response = await _apiClient.post(
      '/api/v1/bm/cashbook/reversals/reject',
      data: {'request_id': requestId},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Submit branch treasury reversal request
  Future<Map<String, dynamic>> flagTreasuryReversal(String transactionId, String reason) async {
    final response = await _apiClient.post(
      '/api/v1/bm/cashbook/reversals/flag-treasury',
      data: {
        'transaction_id': transactionId,
        'reason': reason,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Download Monthly Ledger as Excel (.xlsx) file bytes
  Future<List<int>> downloadMonthlyLedgerExcel(int month, int year, String? branch) async {
    final queryParams = <String, dynamic>{
      'month': month,
      'year': year,
    };
    if (branch != null && branch.isNotEmpty) queryParams['branch'] = branch;

    final response = await _apiClient.get(
      '/api/v1/bm/cashbook/monthly/export-excel',
      queryParameters: queryParams,
      options: Options(responseType: ResponseType.bytes),
    );
    return List<int>.from(response.data as List);
  }
}
