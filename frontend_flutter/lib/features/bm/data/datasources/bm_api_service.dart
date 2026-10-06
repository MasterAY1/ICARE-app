import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/bm_dashboard_models.dart';

final bmApiServiceProvider = Provider<BmApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return BmApiService(apiClient);
});

class BmApiService {
  final ApiClient _apiClient;

  BmApiService(this._apiClient);

  /// Fetch raw JSON map of BM dashboard data
  Future<Map<String, dynamic>> getBmDashboardDataRaw({String? date}) async {
    final queryParams = <String, dynamic>{};
    if (date != null && date.isNotEmpty) {
      queryParams['date'] = date;
    }

    final response = await _apiClient.get(
      '/api/v1/bm/dashboard',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    return response.data as Map<String, dynamic>;
  }

  /// Fetch presentation-ready BM dashboard data
  Future<BmDashboardDataModel> getBmDashboardData({String? date}) async {
    final raw = await getBmDashboardDataRaw(date: date);
    return BmDashboardDataModel.fromJson(raw);
  }

  // ==========================================
  // LOAN APPROVALS & REJECTIONS
  // ==========================================

  Future<Map<String, dynamic>> approveLoan({
    required String loanId,
    required String disbursementDate,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/bm/approve-loan',
      data: {
        'loan_id': loanId,
        'disbursement_date': disbursementDate,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectLoan({
    required String loanId,
    String? reason,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/bm/reject-loan',
      data: {
        'loan_id': loanId,
        'reason': reason ?? 'Rejected by BM',
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> batchApproveLoans({
    required List<String> loanIds,
    required String defaultDisbursementDate,
    Map<String, String>? loanDatesMap,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/bm/batch-approve-loans',
      data: {
        'loan_ids': loanIds,
        'default_disbursement_date': defaultDisbursementDate,
        'loan_dates_map': loanDatesMap,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ==========================================
  // WITHDRAWAL APPROVALS & REJECTIONS
  // ==========================================

  Future<Map<String, dynamic>> approveWithdrawal({
    required String withdrawalId,
    required String operationalDate,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/bm/approve-withdrawal',
      data: {
        'withdrawal_id': withdrawalId,
        'operational_date': operationalDate,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectWithdrawal({
    required String withdrawalId,
    String? reason,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/bm/reject-withdrawal',
      data: {
        'withdrawal_id': withdrawalId,
        'reason': reason ?? 'Rejected by BM',
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> batchApproveWithdrawals({
    required List<String> withdrawalIds,
    required String defaultOperationalDate,
    Map<String, String>? withdrawalDatesMap,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/bm/batch-approve-withdrawals',
      data: {
        'withdrawal_ids': withdrawalIds,
        'default_operational_date': defaultOperationalDate,
        'withdrawal_dates_map': withdrawalDatesMap,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ==========================================
  // ERROR CORRECTION APPROVALS & REJECTIONS
  // ==========================================

  Future<Map<String, dynamic>> approveCorrection({
    required String correctionId,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/bm/approve-correction',
      data: {
        'correction_id': correctionId,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectCorrection({
    required String correctionId,
    String? reason,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/bm/reject-correction',
      data: {
        'correction_id': correctionId,
        'reason': reason ?? 'Rejected by BM',
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> batchApproveCorrections({
    required List<String> correctionIds,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/bm/batch-approve-corrections',
      data: {
        'correction_ids': correctionIds,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
