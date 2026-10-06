import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/user_management_models.dart';

final userManagementApiServiceProvider = Provider<UserManagementApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UserManagementApiService(apiClient);
});

class UserManagementApiService {
  final ApiClient _apiClient;

  UserManagementApiService(this._apiClient);

  /// 1. Fetch users scoped to role
  Future<UserListResponseModel> getUsers() async {
    final response = await _apiClient.get('/api/v1/users');
    return UserListResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 2. Create a new user (Admin Only)
  Future<CreateUserResponseModel> createUser({
    required String username,
    required String fullName,
    required String password,
    required String role,
    String? branchName,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/users',
      data: {
        'username': username,
        'full_name': fullName,
        'password': password,
        'role': role,
        if (branchName != null && branchName.isNotEmpty) 'branch_name': branchName,
      },
    );
    return CreateUserResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 3. Toggle user active/inactive status
  Future<GenericActionResponseModel> toggleUserStatus({
    required String userId,
    required bool activate,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/users/$userId/status',
      data: {'activate': activate},
    );
    return GenericActionResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 4. Permanently delete user (Admin Only)
  Future<GenericActionResponseModel> deleteUserPermanently({
    required String userId,
  }) async {
    final response = await _apiClient.delete('/api/v1/users/$userId');
    return GenericActionResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 5. Reset password
  Future<GenericActionResponseModel> resetPassword({
    required String username,
    required String newPassword,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/users/password-reset',
      data: {
        'username': username,
        'new_password': newPassword,
      },
    );
    return GenericActionResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 6. Officer turnover (Admin Only)
  Future<GenericActionResponseModel> updateOfficerTurnover({
    required String username,
    required String newName,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/users/officer-turnover',
      data: {
        'username': username,
        'new_name': newName,
      },
    );
    return GenericActionResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 7. Product assignment metadata
  Future<ProductAssignmentMetaResponseModel> getProductAssignmentMeta() async {
    final response = await _apiClient.get('/api/v1/users/products/meta');
    return ProductAssignmentMetaResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 8. Save product assignments for Credit Officer
  Future<GenericActionResponseModel> assignProducts({
    required String username,
    required List<String> allowedProducts,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/users/products/assign',
      data: {
        'username': username,
        'allowed_products': allowedProducts,
      },
    );
    return GenericActionResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 9. AM assignments metadata (Admin Only)
  Future<AMAssignmentsResponseModel> getAmAssignments() async {
    final response = await _apiClient.get('/api/v1/users/am-assignments');
    return AMAssignmentsResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 10. Save AM branch assignments (Admin Only)
  Future<GenericActionResponseModel> saveAmAssignments({
    required String amId,
    required List<String> branchIds,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/users/am-assignments',
      data: {
        'am_id': amId,
        'branch_ids': branchIds,
      },
    );
    return GenericActionResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 11. Branch closures list
  Future<BranchClosuresResponseModel> getBranchClosures() async {
    final response = await _apiClient.get('/api/v1/users/closures');
    return BranchClosuresResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 12. Create branch closure
  Future<CreateBranchClosureResponseModel> createBranchClosure({
    required String startDate,
    required String endDate,
    required String reason,
    String? branchId,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/users/closures',
      data: {
        'start_date': startDate,
        'end_date': endDate,
        'reason': reason,
        if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
      },
    );
    return CreateBranchClosureResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 13. Delete branch closure
  Future<GenericActionResponseModel> deleteBranchClosure({
    required String closureId,
  }) async {
    final response = await _apiClient.delete('/api/v1/users/closures/$closureId');
    return GenericActionResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 14. User audit logs
  Future<UserAuditLogsResponseModel> getUserAuditLogs({int limit = 200}) async {
    final response = await _apiClient.get(
      '/api/v1/users/audit-logs',
      queryParameters: {'limit': limit},
    );
    return UserAuditLogsResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 15. Login history (Admin Only)
  Future<LoginHistoryResponseModel> getLoginHistory({int limit = 200}) async {
    final response = await _apiClient.get(
      '/api/v1/users/login-history',
      queryParameters: {'limit': limit},
    );
    return LoginHistoryResponseModel.fromJson(response.data as Map<String, dynamic>);
  }
}
