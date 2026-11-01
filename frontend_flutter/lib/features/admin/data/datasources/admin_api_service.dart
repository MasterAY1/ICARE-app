import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/admin_dashboard_models.dart';

final adminApiServiceProvider = Provider<AdminApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdminApiService(apiClient);
});

final adminOperationsProvider = FutureProvider.family<AdminOperationsSnapshotModel, String>((ref, dateStr) async {
  final api = ref.watch(adminApiServiceProvider);
  return api.getOperations(dateStr.isNotEmpty ? dateStr : null);
});

final institutionPerformanceProvider = FutureProvider.family<InstitutionPerformanceModel, int>((ref, year) async {
  final api = ref.watch(adminApiServiceProvider);
  return api.getPerformance(year: year);
});

final adminRiskHealthProvider = FutureProvider<AdminRiskHealthModel>((ref) async {
  final api = ref.watch(adminApiServiceProvider);
  return api.getRiskHealth();
});

class AdminApiService {
  final ApiClient _apiClient;

  AdminApiService(this._apiClient);

  Future<AdminOperationsSnapshotModel> getOperations(String? businessDate) async {
    final queryParams = <String, dynamic>{};
    if (businessDate != null && businessDate.isNotEmpty) {
      queryParams['business_date'] = businessDate;
    }

    final response = await _apiClient.get(
      '/api/v1/admin/dashboard/operations',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    return AdminOperationsSnapshotModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<InstitutionPerformanceModel> getPerformance({int year = 2026, String? branchId}) async {
    final queryParams = <String, dynamic>{'year': year};
    if (branchId != null && branchId.isNotEmpty && branchId != 'all') {
      queryParams['branch_id'] = branchId;
    }

    final response = await _apiClient.get(
      '/api/v1/admin/dashboard/performance',
      queryParameters: queryParams,
    );

    return InstitutionPerformanceModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminRiskHealthModel> getRiskHealth() async {
    final response = await _apiClient.get('/api/v1/admin/dashboard/risk-health');
    return AdminRiskHealthModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<bool> approveReversal(String requestId, {String? notes}) async {
    final response = await _apiClient.post(
      '/api/v1/admin/dashboard/approvals/reversal',
      data: {
        'request_id': requestId,
        'action': 'APPROVE',
        'notes': notes,
      },
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    return data['success'] == true;
  }

  Future<bool> rejectReversal(String requestId, {String? notes}) async {
    final response = await _apiClient.post(
      '/api/v1/admin/dashboard/approvals/reversal',
      data: {
        'request_id': requestId,
        'action': 'REJECT',
        'notes': notes,
      },
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    return data['success'] == true;
  }

  Future<bool> approveLoan(String loanId, {String? disbursementDate, String? notes}) async {
    final response = await _apiClient.post(
      '/api/v1/admin/dashboard/approvals/loan',
      data: {
        'loan_id': loanId,
        'action': 'APPROVE',
        'disbursement_date': disbursementDate,
        'notes': notes,
      },
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    return data['success'] == true;
  }

  Future<bool> rejectLoan(String loanId, {String? notes}) async {
    final response = await _apiClient.post(
      '/api/v1/admin/dashboard/approvals/loan',
      data: {
        'loan_id': loanId,
        'action': 'REJECT',
        'notes': notes,
      },
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    return data['success'] == true;
  }
}
