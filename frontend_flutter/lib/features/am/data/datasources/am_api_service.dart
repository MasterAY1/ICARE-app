// lib/features/am/data/datasources/am_api_service.dart
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/am_dashboard_models.dart';

final amApiServiceProvider = Provider<AmApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AmApiService(apiClient);
});

class AmApiService {
  final ApiClient _apiClient;

  AmApiService(this._apiClient);

  /// Fetch raw JSON map of AM dashboard data
  Future<Map<String, dynamic>> getAmDashboardDataRaw({String? businessDate}) async {
    final queryParams = <String, dynamic>{};
    if (businessDate != null && businessDate.isNotEmpty) {
      queryParams['business_date'] = businessDate;
    }

    final response = await _apiClient.get(
      '/api/v1/am/dashboard',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    return response.data as Map<String, dynamic>;
  }

  /// Fetch presentation-ready AM dashboard data
  Future<AmDashboardDataModel> getAmDashboardData({String? businessDate}) async {
    final raw = await getAmDashboardDataRaw(businessDate: businessDate);
    return AmDashboardDataModel.fromJson(raw);
  }

  /// Fetch Area Approvals Hub
  Future<AreaApprovalsHubModel> getAmApprovals({String? businessDate}) async {
    final queryParams = <String, dynamic>{};
    if (businessDate != null && businessDate.isNotEmpty) {
      queryParams['business_date'] = businessDate;
    }

    final response = await _apiClient.get(
      '/api/v1/am/approvals',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    return AreaApprovalsHubModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Confirm individual branch EOD
  Future<Map<String, dynamic>> confirmBranchEod({
    required String branchId,
    required String closureDate,
    String? notes,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/am/confirm-branch-eod',
      data: {
        'branch_id': branchId,
        'closure_date': closureDate,
        'notes': notes,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Master Area 1 daily closure lock
  Future<Map<String, dynamic>> confirmAreaClosure({
    required String areaName,
    required String closureDate,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/am/confirm-area-closure',
      data: {
        'area_name': areaName,
        'closure_date': closureDate,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Approve high-value loan (> ₦300k)
  Future<Map<String, dynamic>> approveHighValueLoan({
    required String loanId,
    required String disbursementDate,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/am/approve-loan',
      data: {
        'loan_id': loanId,
        'disbursement_date': disbursementDate,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Reject high-value loan
  Future<Map<String, dynamic>> rejectHighValueLoan({
    required String loanId,
    String? reason,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/am/reject-loan',
      data: {
        'loan_id': loanId,
        'reason': reason ?? 'Rejected by Area Manager',
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Sign off inter-branch client transfer
  Future<Map<String, dynamic>> signOffTransfer({
    required String transferId,
    String? notes,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/am/sign-off-transfer',
      data: {
        'transfer_id': transferId,
        'notes': notes,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Reject inter-branch client transfer
  Future<Map<String, dynamic>> rejectTransfer({
    required String transferId,
    required String reason,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/am/reject-transfer',
      data: {
        'transfer_id': transferId,
        'reason': reason,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Fetch Branch Handover Summary for read-only inspection & downloads
  Future<BranchHandoverSummaryModel> getBranchHandover({
    required String branchId,
    String? businessDate,
  }) async {
    final queryParams = <String, dynamic>{};
    if (businessDate != null && businessDate.isNotEmpty) {
      queryParams['business_date'] = businessDate;
    }

    final response = await _apiClient.get(
      '/api/v1/am/branch-handover/$branchId',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    return BranchHandoverSummaryModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fetch Branch Supervisory Inspection Data
  Future<Map<String, dynamic>> getBranchInspection({
    required String branchId,
    String? businessDate,
  }) async {
    final queryParams = <String, dynamic>{};
    if (businessDate != null && businessDate.isNotEmpty) {
      queryParams['business_date'] = businessDate;
    }

    final response = await _apiClient.get(
      '/api/v1/am/branch-inspection/$branchId',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    return response.data as Map<String, dynamic>;
  }

  /// Download Area Excel Report as Bytes
  Future<Uint8List> downloadAreaExcel({String? businessDate}) async {
    final queryParams = <String, dynamic>{};
    if (businessDate != null && businessDate.isNotEmpty) {
      queryParams['business_date'] = businessDate;
    }

    final response = await _apiClient.get(
      '/api/v1/am/reports/excel',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
      options: Options(responseType: ResponseType.bytes),
    );

    return Uint8List.fromList(response.data as List<int>);
  }
}
