import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/audit_models.dart';

final auditApiServiceProvider = Provider<AuditApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuditApiService(apiClient);
});

class AuditApiService {
  final ApiClient _apiClient;

  AuditApiService(this._apiClient);

  /// Fetch dropdown metadata (branches, officers, loan products)
  Future<AuditMetaModel> getMetadata({String? branchId}) async {
    final params = <String, dynamic>{};
    if (branchId != null && branchId.isNotEmpty) params['branch_id'] = branchId;

    final response = await _apiClient.get(
      '/api/v1/audit/meta',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return AuditMetaModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 6-Way Financial Integrity Verification
  Future<Integrity6WayModel> get6WayIntegrity({
    String? branchId,
    String? postingDate,
  }) async {
    final params = <String, dynamic>{};
    if (branchId != null && branchId.isNotEmpty) params['branch_id'] = branchId;
    if (postingDate != null && postingDate.isNotEmpty) params['posting_date'] = postingDate;

    final response = await _apiClient.get(
      '/api/v1/audit/integrity-6way',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return Integrity6WayModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fees Audit Ledger
  Future<FeeLedgerResponseModel> getFeeLedger({
    String? dateFrom,
    String? dateTo,
    String feeType = 'ALL',
    String? branchId,
    String? officerId,
    String? search,
  }) async {
    final params = <String, dynamic>{'fee_type': feeType};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (branchId != null && branchId.isNotEmpty) params['branch_id'] = branchId;
    if (officerId != null && officerId.isNotEmpty) params['officer_id'] = officerId;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _apiClient.get(
      '/api/v1/audit/fees',
      queryParameters: params,
    );
    return FeeLedgerResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Treasury Audit Ledger
  Future<TreasuryLedgerResponseModel> getTreasuryLedger({
    String? dateFrom,
    String? dateTo,
    String category = 'ALL',
    String? branchId,
    String? officerId,
    String? search,
  }) async {
    final params = <String, dynamic>{'category': category};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (branchId != null && branchId.isNotEmpty) params['branch_id'] = branchId;
    if (officerId != null && officerId.isNotEmpty) params['officer_id'] = officerId;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _apiClient.get(
      '/api/v1/audit/treasury',
      queryParameters: params,
    );
    return TreasuryLedgerResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Savings Audit Ledger
  Future<SavingsLedgerResponseModel> getSavingsLedger({
    String? dateFrom,
    String? dateTo,
    String savingsLedger = 'ALL',
    String? branchId,
    String? officerId,
    String? search,
  }) async {
    final params = <String, dynamic>{'savings_ledger': savingsLedger};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (branchId != null && branchId.isNotEmpty) params['branch_id'] = branchId;
    if (officerId != null && officerId.isNotEmpty) params['officer_id'] = officerId;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _apiClient.get(
      '/api/v1/audit/savings',
      queryParameters: params,
    );
    return SavingsLedgerResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Loan Audit Ledger (Disbursements or Repayments)
  Future<LoanLedgerResponseModel> getLoanLedger({
    required String viewType,
    String? dateFrom,
    String? dateTo,
    String? productId,
    String? branchId,
    String? officerId,
    String? search,
  }) async {
    final params = <String, dynamic>{'view_type': viewType};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (productId != null && productId.isNotEmpty) params['product_id'] = productId;
    if (branchId != null && branchId.isNotEmpty) params['branch_id'] = branchId;
    if (officerId != null && officerId.isNotEmpty) params['officer_id'] = officerId;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _apiClient.get(
      '/api/v1/audit/loans',
      queryParameters: params,
    );
    return LoanLedgerResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Collection Performance Audit
  Future<CollectionPerformanceResponseModel> getCollectionPerformance({
    String? dateFrom,
    String? dateTo,
    String? branchId,
    String? officerId,
    String complianceStatus = 'ALL',
    String? search,
  }) async {
    final params = <String, dynamic>{'compliance_status': complianceStatus};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (branchId != null && branchId.isNotEmpty) params['branch_id'] = branchId;
    if (officerId != null && officerId.isNotEmpty) params['officer_id'] = officerId;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _apiClient.get(
      '/api/v1/audit/collections',
      queryParameters: params,
    );
    return CollectionPerformanceResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 15 Exception Reports
  Future<ExceptionReportsResponseModel> getExceptionReports({String? branchId}) async {
    final params = <String, dynamic>{};
    if (branchId != null && branchId.isNotEmpty) params['branch_id'] = branchId;

    final response = await _apiClient.get(
      '/api/v1/audit/exceptions',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return ExceptionReportsResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// 360° Universal Explorer Search
  Future<UniversalExplorerResponseModel> searchUniversalExplorer({
    required String query,
    String? branchId,
  }) async {
    final params = <String, dynamic>{'query': query};
    if (branchId != null && branchId.isNotEmpty) params['branch_id'] = branchId;

    final response = await _apiClient.get(
      '/api/v1/audit/explorer',
      queryParameters: params,
    );
    return UniversalExplorerResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Loan Timeline for Explorer
  Future<LoanTimelineResponseModel> getLoanTimeline({required String loanId}) async {
    final response = await _apiClient.get(
      '/api/v1/audit/explorer/loan-timeline',
      queryParameters: {'loan_id': loanId},
    );
    return LoanTimelineResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Executive Performance Insights
  Future<RiskDistributionResponseModel> getPerformanceInsights({String? branchId}) async {
    final params = <String, dynamic>{};
    if (branchId != null && branchId.isNotEmpty) params['branch_id'] = branchId;

    final response = await _apiClient.get(
      '/api/v1/audit/performance-insights',
      queryParameters: params.isNotEmpty ? params : null,
    );
    return RiskDistributionResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Reconciliation Wizard Repair Execution
  Future<ReconciliationRepairResponseModel> executeReconciliationRepair({
    required String branchId,
    required String reconciliationDate,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/audit/reconciliation-wizard/repair',
      data: {
        'branch_id': branchId,
        'reconciliation_date': reconciliationDate,
      },
    );
    return ReconciliationRepairResponseModel.fromJson(response.data as Map<String, dynamic>);
  }
}
