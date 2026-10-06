import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/co_dashboard_models.dart';

final coApiServiceProvider = Provider<CoApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return CoApiService(client);
});

/// Authoritative API client service for all Credit Officer backend communications.
/// Connects Flutter UI to the FastAPI adapter running at http://127.0.0.1:8000.
class CoApiService {
  final ApiClient _client;
  CoApiService(this._client);

  // ==========================================
  // 1. DASHBOARD & PORTFOLIO
  // ==========================================

  /// GET /api/v1/co/dashboard
  Future<CoDashboardData> getCoDashboardData([String? dateStr]) async {
    final path = dateStr != null ? '/api/v1/co/dashboard?date=$dateStr' : '/api/v1/co/dashboard';
    final response = await _client.get(path);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return CoDashboardData.fromJson(data);
    }
    throw Exception('Invalid response format from CO dashboard API');
  }

  /// GET /api/v1/co/portfolio
  Future<Map<String, dynamic>> getPortfolioData({
    String? branch,
    String? officer,
    String? group,
    String? product,
    String? timePeriod,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, dynamic>{};
    if (branch != null && branch.isNotEmpty && branch != 'All') queryParams['branch'] = branch;
    if (officer != null && officer.isNotEmpty && officer != 'All') queryParams['officer'] = officer;
    if (group != null && group.isNotEmpty && group != 'All') queryParams['group'] = group;
    if (product != null && product.isNotEmpty && product != 'All') queryParams['product'] = product;
    if (timePeriod != null && timePeriod.isNotEmpty) queryParams['time_period'] = timePeriod;
    if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;

    final response = await _client.get('/api/v1/co/portfolio', queryParameters: queryParams);
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/v1/co/portfolio/dossier
  Future<Map<String, dynamic>> getClientDossier(String clientCode) async {
    final response = await _client.get('/api/v1/co/portfolio/dossier', queryParameters: {'client_code': clientCode});
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/portfolio/status-change
  Future<Map<String, dynamic>> changeClientStatus({
    required String clientId,
    required String targetStatus,
    required String reason,
  }) async {
    final response = await _client.post('/api/v1/co/portfolio/status-change', data: {
      'client_id': clientId,
      'target_status': targetStatus,
      'reason': reason,
    });
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/portfolio/reversal-request
  Future<Map<String, dynamic>> submitDossierReversal({
    required String recordId,
    required String reason,
  }) async {
    final response = await _client.post('/api/v1/co/portfolio/reversal-request', data: {
      'record_id': recordId,
      'reason': reason,
    });
    return response.data as Map<String, dynamic>;
  }

  // ==========================================
  // 2. FIELD COLLECTIONS
  // ==========================================

  /// GET /api/v1/co/collections/sheet
  Future<Map<String, dynamic>> getCollectionSheet({String? groupName, String? date}) async {
    final queryParams = <String, dynamic>{};
    if (groupName != null) queryParams['group_name'] = groupName;
    if (date != null) queryParams['date'] = date;

    final response = await _client.get('/api/v1/co/collections/sheet', queryParameters: queryParams);
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/collections/batch-submit
  Future<Map<String, dynamic>> submitBatchCollections(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/v1/co/collections/batch-submit', data: payload);
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/v1/co/collections/single-client-options
  Future<Map<String, dynamic>> getSingleClientOptions() async {
    final response = await _client.get('/api/v1/co/collections/single-client-options');
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/collections/single-submit
  Future<Map<String, dynamic>> submitSingleCollection(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/v1/co/collections/single-submit', data: payload);
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/v1/co/collections/history
  Future<Map<String, dynamic>> getCollectionsHistory({String? date, String? search, String? officer}) async {
    final queryParams = <String, dynamic>{};
    if (date != null) queryParams['date'] = date;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (officer != null && officer.isNotEmpty && officer != 'All Officers') queryParams['officer'] = officer;

    final response = await _client.get('/api/v1/co/collections/history', queryParameters: queryParams);
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/v1/co/collections/reversal-options
  Future<Map<String, dynamic>> getReversalOptions({
    String category = 'Loan Repayments',
    String? date,
    bool allRecent = false,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'category': category,
      'all_recent': allRecent,
    };
    if (date != null) queryParams['date'] = date;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _client.get('/api/v1/co/collections/reversal-options', queryParameters: queryParams);
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/v1/co/collections/reversal-requests
  Future<Map<String, dynamic>> getReversalRequests() async {
    final response = await _client.get('/api/v1/co/collections/reversal-requests');
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/collections/reversal-request
  Future<Map<String, dynamic>> requestRepaymentReversal(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/v1/co/collections/reversal-request', data: payload);
    return response.data as Map<String, dynamic>;
  }

  // ==========================================
  // 3. DAILY CASHBOOK (ACCOUNT 1000)
  // ==========================================

  /// GET /api/v1/co/cashbook
  Future<Map<String, dynamic>> getCoCashbook({String? dateStr, String? officer}) async {
    final queryParams = <String, dynamic>{};
    if (dateStr != null && dateStr.isNotEmpty) queryParams['date'] = dateStr;
    if (officer != null && officer.isNotEmpty) queryParams['officer'] = officer;
    final response = await _client.get('/api/v1/co/cashbook', queryParameters: queryParams);
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/cashbook/eod-adjustments
  Future<Map<String, dynamic>> submitEodAdjustments(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/v1/co/cashbook/eod-adjustments', data: payload);
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/cashbook/reversal-request
  Future<Map<String, dynamic>> requestCashbookReversal(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/v1/co/cashbook/reversal-request', data: payload);
    return response.data as Map<String, dynamic>;
  }

  // ==========================================
  // 4. LOAN ORIGINATION & REGISTRATION
  // ==========================================

  /// GET /api/v1/co/origination/groups
  Future<List<dynamic>> getOriginationGroups() async {
    final response = await _client.get('/api/v1/co/origination/groups');
    return response.data as List<dynamic>;
  }

  /// GET /api/v1/co/origination/search-clients
  Future<List<dynamic>> searchClientsForOrigination(String query) async {
    final response = await _client.get(
      '/api/v1/co/origination/search-clients',
      queryParameters: {'q': query},
    );
    return response.data as List<dynamic>;
  }

  /// GET /api/v1/co/origination/client-details/{clientId}
  Future<Map<String, dynamic>> getClientOriginationDetails(String clientId) async {
    final response = await _client.get('/api/v1/co/origination/client-details/$clientId');
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/origination/check-eligibility
  Future<Map<String, dynamic>> checkLoanEligibility(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/v1/co/origination/check-eligibility', data: payload);
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/origination/register-client
  Future<Map<String, dynamic>> registerClient(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/v1/co/origination/register-client', data: payload);
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/origination/apply
  Future<Map<String, dynamic>> applyForLoan(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/v1/co/origination/apply', data: payload);
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/v1/co/origination/pending
  Future<Map<String, dynamic>> getPendingDisbursements() async {
    final response = await _client.get('/api/v1/co/origination/pending');
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/origination/disburse
  Future<Map<String, dynamic>> disburseLoan(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/v1/co/origination/disburse', data: payload);
    return response.data as Map<String, dynamic>;
  }

  /// PUT /api/v1/co/origination/update-client/{clientId}
  Future<Map<String, dynamic>> updateClientAndGuarantor(String clientId, Map<String, dynamic> payload) async {
    final response = await _client.put('/api/v1/co/origination/update-client/$clientId', data: payload);
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/origination/upload-document
  Future<Map<String, dynamic>> uploadDocument({
    required List<int> bytes,
    required String fileName,
    String category = 'passport',
    String? clientId,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'category': category,
      if (clientId != null && clientId.isNotEmpty) 'client_id': clientId,
    });
    final response = await _client.post('/api/v1/co/origination/upload-document', data: formData);
    return response.data as Map<String, dynamic>;
  }


  // ==========================================
  // 5. WITHDRAWAL OPERATIONS
  // ==========================================

  /// GET /api/v1/co/withdrawals/individual-options
  Future<Map<String, dynamic>> getIndividualWithdrawalOptions() async {
    final response = await _client.get('/api/v1/co/withdrawals/individual-options');
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/v1/co/withdrawals/group-options
  Future<Map<String, dynamic>> getGroupWithdrawalOptions() async {
    final response = await _client.get('/api/v1/co/withdrawals/group-options');
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/v1/co/withdrawals/misc-balance
  Future<Map<String, dynamic>> getMiscWithdrawalBalance() async {
    final response = await _client.get('/api/v1/co/withdrawals/misc-balance');
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/v1/co/withdrawals/laps-options
  Future<Map<String, dynamic>> getLapsWithdrawalOptions() async {
    final response = await _client.get('/api/v1/co/withdrawals/laps-options');
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/v1/co/withdrawals/requests
  Future<Map<String, dynamic>> getWithdrawalRequests() async {
    final response = await _client.get('/api/v1/co/withdrawals/requests');
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/withdrawals/request
  Future<Map<String, dynamic>> submitWithdrawalRequest(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/v1/co/withdrawals/request', data: payload);
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/v1/co/withdrawals/daily-withdrawals
  Future<Map<String, dynamic>> getDailyWithdrawals({
    String? date,
    bool showAll = false,
    String? category,
    String? search,
  }) async {
    final q = <String, dynamic>{
      'show_all': showAll,
    };
    if (date != null && !showAll) q['date'] = date;
    if (category != null && category != 'All Types') q['category'] = category;
    if (search != null && search.isNotEmpty) q['search'] = search;

    final response = await _client.get('/api/v1/co/withdrawals/daily-withdrawals', queryParameters: q);
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/v1/co/withdrawals/pending-approvals
  Future<Map<String, dynamic>> getPendingApprovals() async {
    final response = await _client.get('/api/v1/co/withdrawals/pending-approvals');
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/withdrawals/approve
  Future<Map<String, dynamic>> approveWithdrawal(String requestId, {String? operationalDate}) async {
    final response = await _client.post('/api/v1/co/withdrawals/approve', data: {
      'request_id': requestId,
      if (operationalDate != null) 'operational_date': operationalDate,
    });
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/co/withdrawals/reject
  Future<Map<String, dynamic>> rejectWithdrawal(String requestId, String reason) async {
    final response = await _client.post('/api/v1/co/withdrawals/reject', data: {
      'request_id': requestId,
      'rejection_reason': reason,
    });
    return response.data as Map<String, dynamic>;
  }
}

