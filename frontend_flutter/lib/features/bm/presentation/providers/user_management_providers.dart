import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/user_management_api_service.dart';
import '../../data/models/user_management_models.dart';

/// Live Riverpod providers for User Management so tab switches preserve state
/// without FutureBuilder rebuild thrashing.
final userDirectoryProvider = FutureProvider.autoDispose<UserListResponseModel>((ref) {
  return ref.watch(userManagementApiServiceProvider).getUsers();
});

final productAssignmentMetaProvider =
    FutureProvider.autoDispose<ProductAssignmentMetaResponseModel>((ref) {
  return ref.watch(userManagementApiServiceProvider).getProductAssignmentMeta();
});

final amAssignmentsProvider =
    FutureProvider.autoDispose<AMAssignmentsResponseModel>((ref) {
  return ref.watch(userManagementApiServiceProvider).getAmAssignments();
});

final branchClosuresProvider =
    FutureProvider.autoDispose<BranchClosuresResponseModel>((ref) {
  return ref.watch(userManagementApiServiceProvider).getBranchClosures();
});

final userAuditLogsProvider =
    FutureProvider.autoDispose<UserAuditLogsResponseModel>((ref) {
  return ref.watch(userManagementApiServiceProvider).getUserAuditLogs(limit: 200);
});

final loginHistoryProvider =
    FutureProvider.autoDispose<LoginHistoryResponseModel>((ref) {
  return ref.watch(userManagementApiServiceProvider).getLoginHistory(limit: 200);
});

void invalidateAllUserManagementProviders(WidgetRef ref) {
  ref.invalidate(userDirectoryProvider);
  ref.invalidate(productAssignmentMetaProvider);
  ref.invalidate(amAssignmentsProvider);
  ref.invalidate(branchClosuresProvider);
  ref.invalidate(userAuditLogsProvider);
  ref.invalidate(loginHistoryProvider);
}
