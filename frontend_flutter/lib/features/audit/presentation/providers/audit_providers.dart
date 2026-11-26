import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/audit_api_service.dart';
import '../../data/models/audit_models.dart';

@immutable
class Audit6WayQuery {
  final String? branchId;
  final String postingDate;
  const Audit6WayQuery({this.branchId, required this.postingDate});

  @override
  bool operator ==(Object other) =>
      other is Audit6WayQuery &&
      other.branchId == branchId &&
      other.postingDate == postingDate;

  @override
  int get hashCode => Object.hash(branchId, postingDate);
}

@immutable
class AuditLedgerFilterQuery {
  final String dateFrom;
  final String dateTo;
  final String filterType;
  final String? branchId;
  final String? officerId;
  final String? productId;
  final String search;

  const AuditLedgerFilterQuery({
    required this.dateFrom,
    required this.dateTo,
    this.filterType = 'ALL',
    this.branchId,
    this.officerId,
    this.productId,
    this.search = '',
  });

  @override
  bool operator ==(Object other) =>
      other is AuditLedgerFilterQuery &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo &&
      other.filterType == filterType &&
      other.branchId == branchId &&
      other.officerId == officerId &&
      other.productId == productId &&
      other.search == search;

  @override
  int get hashCode => Object.hash(
        dateFrom,
        dateTo,
        filterType,
        branchId,
        officerId,
        productId,
        search,
      );
}

final auditMetaProvider =
    FutureProvider.autoDispose.family<AuditMetaModel, String?>((ref, branchId) {
  return ref.watch(auditApiServiceProvider).getMetadata(branchId: branchId);
});

final integrity6WayProvider =
    FutureProvider.autoDispose.family<Integrity6WayModel, Audit6WayQuery>(
        (ref, query) {
  return ref.watch(auditApiServiceProvider).get6WayIntegrity(
        branchId: query.branchId,
        postingDate: query.postingDate,
      );
});

final feeLedgerProvider = FutureProvider.autoDispose
    .family<FeeLedgerResponseModel, AuditLedgerFilterQuery>((ref, q) {
  return ref.watch(auditApiServiceProvider).getFeeLedger(
        dateFrom: q.dateFrom,
        dateTo: q.dateTo,
        feeType: q.filterType,
        branchId: q.branchId,
        officerId: q.officerId,
        search: q.search.isEmpty ? null : q.search,
      );
});

final treasuryLedgerProvider = FutureProvider.autoDispose
    .family<TreasuryLedgerResponseModel, AuditLedgerFilterQuery>((ref, q) {
  return ref.watch(auditApiServiceProvider).getTreasuryLedger(
        dateFrom: q.dateFrom,
        dateTo: q.dateTo,
        category: q.filterType,
        branchId: q.branchId,
        officerId: q.officerId,
        search: q.search.isEmpty ? null : q.search,
      );
});

final savingsLedgerProvider = FutureProvider.autoDispose
    .family<SavingsLedgerResponseModel, AuditLedgerFilterQuery>((ref, q) {
  return ref.watch(auditApiServiceProvider).getSavingsLedger(
        dateFrom: q.dateFrom,
        dateTo: q.dateTo,
        savingsLedger: q.filterType,
        branchId: q.branchId,
        officerId: q.officerId,
        search: q.search.isEmpty ? null : q.search,
      );
});

final loanLedgerProvider = FutureProvider.autoDispose
    .family<LoanLedgerResponseModel, AuditLedgerFilterQuery>((ref, q) {
  return ref.watch(auditApiServiceProvider).getLoanLedger(
        viewType: q.filterType,
        dateFrom: q.dateFrom,
        dateTo: q.dateTo,
        productId: q.productId,
        branchId: q.branchId,
        officerId: q.officerId,
        search: q.search.isEmpty ? null : q.search,
      );
});

final collectionPerformanceProvider = FutureProvider.autoDispose
    .family<CollectionPerformanceResponseModel, AuditLedgerFilterQuery>(
        (ref, q) {
  return ref.watch(auditApiServiceProvider).getCollectionPerformance(
        dateFrom: q.dateFrom,
        dateTo: q.dateTo,
        branchId: q.branchId,
        officerId: q.officerId,
        complianceStatus: q.filterType,
        search: q.search.isEmpty ? null : q.search,
      );
});

final withdrawalAuditProvider = FutureProvider.autoDispose
    .family<WithdrawalAuditResponseModel, AuditLedgerFilterQuery>((ref, q) {
  return ref.watch(auditApiServiceProvider).getWithdrawalAudit(
        dateFrom: q.dateFrom,
        dateTo: q.dateTo,
        statusFilter: q.filterType,
        branchId: q.branchId,
        search: q.search.isEmpty ? null : q.search,
      );
});

final exceptionReportsProvider = FutureProvider.autoDispose
    .family<ExceptionReportsResponseModel, String?>((ref, branchId) {
  return ref.watch(auditApiServiceProvider).getExceptionReports(
        branchId: (branchId == null || branchId.isEmpty) ? null : branchId,
      );
});

final performanceInsightsProvider = FutureProvider.autoDispose
    .family<RiskDistributionResponseModel, String?>((ref, branchId) {
  return ref.watch(auditApiServiceProvider).getPerformanceInsights(
        branchId: (branchId == null || branchId.isEmpty) ? null : branchId,
      );
});

void invalidateAllAuditProviders(WidgetRef ref) {
  ref.invalidate(auditMetaProvider);
  ref.invalidate(integrity6WayProvider);
  ref.invalidate(feeLedgerProvider);
  ref.invalidate(treasuryLedgerProvider);
  ref.invalidate(savingsLedgerProvider);
  ref.invalidate(loanLedgerProvider);
  ref.invalidate(collectionPerformanceProvider);
  ref.invalidate(withdrawalAuditProvider);
  ref.invalidate(exceptionReportsProvider);
  ref.invalidate(performanceInsightsProvider);
}
