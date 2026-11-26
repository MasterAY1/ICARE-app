import 'dart:async';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import '../../../core/widgets/icare_section_header.dart';

import '../../../core/widgets/icare_skeleton_loader.dart';

import '../../../core/theme/icare_theme_tokens.dart';

import '../../../core/utils/currency_formatter.dart';

import '../../../core/offline/connectivity_service.dart';

import '../../../core/offline/offline_database_service.dart';

import '../../../core/offline/offline_sync_manager.dart';
import '../../../core/errors/app_error_formatter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';

import '../data/datasources/co_api_service.dart';

import '../../shared/presentation/co_app_scaffold.dart';

import 'co_dashboard_screen.dart';

import 'daily_cashbook_screen.dart';

import 'portfolio_overview_screen.dart';

// ==========================================

// STATE PROVIDERS

// ==========================================

final collectionsTabProvider = StateProvider<int>((ref) => 0); // 0=Record, 1=History, 2=Reversals

final collectionsModeProvider = StateProvider<String>((ref) => 'Group Collection Sheet'); // or 'Single Client Quick Entry'

final collectionsSelectedGroupProvider = StateProvider<String?>((ref) => null);

final collectionsBusinessDateProvider = StateProvider<DateTime?>((ref) => null);

final collectionsDateProvider = StateProvider<DateTime?>((ref) => null);

final effectiveCollectionsDateProvider = Provider<DateTime>((ref) {
  return ref.watch(collectionsDateProvider) ??
      ref.watch(collectionsBusinessDateProvider) ??
      DateTime.now();
});

final collectionsLateEntryProvider = StateProvider<bool>((ref) => false);

bool _canAuthorizeLateEntry(AuthState authState) {
  if (authState is! AuthStateAuthenticated) return false;
  final normRole = authState.user.role.trim().toLowerCase();
  return normRole == 'admin' ||
      normRole == 'super admin' ||
      normRole == 'super_admin' ||
      normRole == 'superadmin' ||
      normRole == 'administrator' ||
      normRole == 'global_admin' ||
      normRole == 'global admin' ||
      normRole == 'system admin' ||
      normRole == 'system administrator';
}

// ==========================================

// ASYNC DATA PROVIDERS

// ==========================================

final collectionSheetFutureProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {

  final api = ref.watch(coApiServiceProvider);

  final grp = ref.watch(collectionsSelectedGroupProvider);

  final dt = ref.watch(collectionsDateProvider);

  final cachedBizDt = ref.read(collectionsBusinessDateProvider);

  final String? queryDateStr = dt != null ? DateFormat('yyyy-MM-dd').format(dt) : null;

  final String dateStr = queryDateStr ?? DateFormat('yyyy-MM-dd').format(cachedBizDt ?? DateTime.now());

  final isOnline = ref.watch(isOnlineProvider);

  final syncMgr = ref.watch(offlineSyncManagerProvider);

  final dbService = ref.watch(offlineDatabaseServiceProvider);

  Future<Map<String, dynamic>?> resolveOfflineSheet() async {
    final cachedGroups = await dbService.getCachedGroupNames();
    Map<String, dynamic>? cached;
    if (grp != null) {
      cached = await syncMgr.getOfflineSheet(grp, dateStr: dateStr);
    }
    if (cached == null && cachedGroups.isNotEmpty) {
      final fallbackGrp = cachedGroups.contains(grp) ? grp! : cachedGroups.first;
      cached = await syncMgr.getOfflineSheet(fallbackGrp, dateStr: dateStr);
    }
    if (cached != null) {
      final mutable = Map<String, dynamic>.from(cached);
      if (cachedGroups.isNotEmpty) {
        mutable['available_groups'] = cachedGroups;
      }
      return mutable;
    }
    return null;
  }

  if (!isOnline) {
    final offlineSheet = await resolveOfflineSheet();
    if (offlineSheet != null) {
      return offlineSheet;
    }
    throw DioException(
      requestOptions: RequestOptions(path: '/api/v1/co/collections/sheet'),
      error: 'Offline cache miss: No pre-cached group sheets found on this device. Connect to the internet once to sync your groups.',
      type: DioExceptionType.connectionError,
    );
  }

  try {
    final sheet = await api.getCollectionSheet(groupName: grp, date: queryDateStr);
    final serverDateStr = sheet['date']?.toString().trim();
    final effectiveDateStr = (serverDateStr != null && serverDateStr.isNotEmpty) ? serverDateStr : dateStr;
    if (serverDateStr != null && serverDateStr.isNotEmpty) {
      final parsedBizDate = DateTime.tryParse(serverDateStr);
      if (parsedBizDate != null) {
        Future.microtask(() {
          if (ref.read(collectionsBusinessDateProvider) != parsedBizDate) {
            ref.read(collectionsBusinessDateProvider.notifier).state = parsedBizDate;
          }
        });
      }
    }
    final effectiveGrp = (grp ?? sheet['group_name'])?.toString().trim();
    final hasMembers = sheet['members'] != null || sheet['clients'] != null;
    if (effectiveGrp != null && effectiveGrp.isNotEmpty && hasMembers) {
      await syncMgr.cacheLoadedGroupSheet(effectiveGrp, sheet, dateStr: effectiveDateStr);
    }
    final availGroups = (sheet['available_groups'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        <String>[];
    if (availGroups.isNotEmpty) {
      syncMgr.preCacheAllAvailableGroups(availGroups, effectiveDateStr, skipGroup: effectiveGrp).ignore();
    } else {
      syncMgr.preCacheSingleClients().ignore();
    }
    syncMgr.preCacheWithdrawalWorkspace(dateStr: effectiveDateStr).ignore();
    return sheet;
  } catch (e) {
    final offlineSheet = await resolveOfflineSheet();
    if (offlineSheet != null) {
      return offlineSheet;
    }
    rethrow;
  }

});

final singleClientOptionsProvider = FutureProvider<Map<String, dynamic>>((ref) async {

  final api = ref.watch(coApiServiceProvider);

  return api.getSingleClientOptions();

});

final collectionsHistoryProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, ({String dateStr, String search, String? officer})>((ref, args) async {

  final api = ref.watch(coApiServiceProvider);

  return api.getCollectionsHistory(date: args.dateStr, search: args.search, officer: args.officer);

});

final reversalOptionsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, ({String category, String dateStr, bool allRecent, String search})>((ref, args) async {

  final api = ref.watch(coApiServiceProvider);

  return api.getReversalOptions(

    category: args.category,

    date: args.dateStr,

    allRecent: args.allRecent,

    search: args.search,

  );

});

final reversalRequestsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {

  final api = ref.watch(coApiServiceProvider);

  return api.getReversalRequests();

});

// ==========================================

// MAIN SCREEN COMPONENT

// ==========================================

/// 1:1 Streamlit replica of Credit Officer Daily Collections (app.py L4840–7259)

/// Strict institutional styling, zero emojis (Rule 10), atomic Account 1000 posting.

class DailyCollectionsScreen extends ConsumerStatefulWidget {

  const DailyCollectionsScreen({super.key});

  @override

  ConsumerState<DailyCollectionsScreen> createState() => _DailyCollectionsScreenState();

}

class _DailyCollectionsScreenState extends ConsumerState<DailyCollectionsScreen> {

  // Receipt State

  Map<String, dynamic>? _receiptData;

  // Staging / Review State for Mode 1

  bool _isOpeningBatchModal = false;

  bool _isOpeningSingleClientModal = false;

  String _lastSheetCtrlScopeKey = '';

  List<Map<String, dynamic>> _stagedTransactions = [];

  // Group Form Controllers (keyed by client_id or client_code)

  final TextEditingController _grpSavingsCtrl = TextEditingController();

  final Map<String, TextEditingController> _memberRepaymentCtrls = {};

  final Map<String, TextEditingController> _memberSavingsCtrls = {};

  final Map<String, bool> _memberNotPaidFlags = {};

  bool _expandAllMembers = false;

  final Map<String, bool> _expandedMemberCards = {};

  // Single Client Form State (Mode 2)

  String? _scSelectedClientId;

  String? _scSelectedLoanId;

  String _scSelectedGroupFilter = 'All Groups';

  final TextEditingController _scSearchCtrl = TextEditingController();

  String _scSearchText = '';

  final TextEditingController _scPersonalSavCtrl = TextEditingController();

  final TextEditingController _scGroupSavCtrl = TextEditingController();

  final TextEditingController _scLoanRepCtrl = TextEditingController();

  final TextEditingController _scAppFeeCtrl = TextEditingController();

  final TextEditingController _scPbFeeCtrl = TextEditingController();

  final TextEditingController _scMiscFeeCtrl = TextEditingController();

  final TextEditingController _scNoteCtrl = TextEditingController(text: 'Single Client Collection');

  bool _scMarkNotPaid = false;

  // Tab 2 History State

  DateTime? _histDate;

  final TextEditingController _histSearchCtrl = TextEditingController();

  String _histOfficer = 'All Officers';

  List<String> _histAvailableOfficers = const ['All Officers'];

  int _histClientPage = 1;

  static const int _histPageSize = 10;

  String _histStatusFilter = 'ALL';

  // Tab 3 Reversal Hub State

  String _revCategory = 'Loan Repayments';

  DateTime? _revDate;

  final TextEditingController _revSearchCtrl = TextEditingController();

  bool _revAllRecent = false;

  String? _selectedReversalRefId;

  final TextEditingController _revReasonCtrl = TextEditingController();

  // Async submission state

  bool _isSubmitting = false;

  String? _statusBannerText;

  bool _isSuccessBanner = true;

  @override

  void initState() {

    super.initState();

    // Check if a preselected group was passed from Dashboard quick action

    WidgetsBinding.instance.addPostFrameCallback((_) {

      final preselected = ref.read(selectedCollectionGroupProvider);

      if (preselected != null && preselected.isNotEmpty) {

        ref.read(collectionsSelectedGroupProvider.notifier).state = preselected;

        ref.read(selectedCollectionGroupProvider.notifier).state = null;

      }

    });

  }

  @override

  void dispose() {

    _grpSavingsCtrl.dispose();

    for (var c in _memberRepaymentCtrls.values) {

      c.dispose();

    }

    for (var c in _memberSavingsCtrls.values) {

      c.dispose();

    }

    _scPersonalSavCtrl.dispose();

    _scGroupSavCtrl.dispose();

    _scLoanRepCtrl.dispose();

    _scAppFeeCtrl.dispose();

    _scPbFeeCtrl.dispose();

    _scMiscFeeCtrl.dispose();

    _scNoteCtrl.dispose();

    _scSearchCtrl.dispose();

    _histSearchCtrl.dispose();

    _revSearchCtrl.dispose();

    _revReasonCtrl.dispose();

    super.dispose();

  }

  void _showNotification(String message, {bool isSuccess = true}) {

    setState(() {

      _statusBannerText = message;

      _isSuccessBanner = isSuccess;

    });

  }

  /// Single-active accordion handler: Expands clicked member and auto-collapses others

  void _toggleMemberCard(String cid) {

    setState(() {

      final isCurrentlyExpanded = _expandedMemberCards[cid] == true;

      _expandAllMembers = false;

      _expandedMemberCards.clear();

      if (!isCurrentlyExpanded) {

        _expandedMemberCards[cid] = true;

      }

    });

  }

  // =========================================================================

  // SUBMISSION HANDLERS

  // =========================================================================

  /// Calculates staging totals and triggers Animated Collection Flow Modal

  void _calculateAndReviewGroup(

    List<dynamic> members,

    String groupName,

    String dateStr, [

    bool isOpen = true,

    String openReason = 'Open',

  ]) {

    final toInsert = <Map<String, dynamic>>[];

    final grpSavAmt = double.tryParse(_grpSavingsCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

    for (var m in members) {

      final cid = m['client_id']?.toString() ?? '';

      final cname = m['client_name']?.toString() ?? '';

      final code = m['client_code']?.toString() ?? cid;

      final rawLoanId = m['loan_id']?.toString().trim() ?? '';

      final hasActiveLoan = rawLoanId.isNotEmpty && rawLoanId.toLowerCase() != 'null';

      final expRep = hasActiveLoan ? ((m['expected_repayment'] as num?)?.toDouble() ?? 0.0) : 0.0;

      final isNotPaid = hasActiveLoan && (_memberNotPaidFlags[cid] == true);

      final repStr = _memberRepaymentCtrls[cid]?.text.replaceAll(',', '').trim() ?? '';

      final savStr = _memberSavingsCtrls[cid]?.text.replaceAll(',', '').trim() ?? '';

      final repAmt = hasActiveLoan
          ? (isNotPaid ? 0.0 : (repStr.isEmpty ? 0.0 : (double.tryParse(repStr) ?? 0.0)))
          : (repStr.isEmpty ? 0.0 : (double.tryParse(repStr) ?? 0.0));

      final savAmt = double.tryParse(savStr) ?? 0.0;

      if (!hasActiveLoan && (repAmt > 0 || _memberNotPaidFlags[cid] == true)) {

        _showNotification('$cname has no active loan and cannot receive a loan repayment or unpaid mark. Enter Savings only.', isSuccess: false);

        return;

      }

      if (repAmt > 0 || savAmt > 0 || isNotPaid) {

        String pStatus = 'PAID';

        double overdueVal = 0.0;

        if (hasActiveLoan) {

          if (isNotPaid) {

            pStatus = 'NOT_PAID';

            overdueVal = expRep;

          } else if (repAmt < expRep) {

            pStatus = 'PART_PAID';

            overdueVal = expRep - repAmt;

          } else if (repAmt > expRep && expRep > 0) {

            pStatus = 'EXCESS';

          }

        }

        toInsert.add({

          'client_id': cid,

          'client_name': cname,

          'client_code': code,

          'loan_id': hasActiveLoan ? rawLoanId : null,

          'loan_product': m['loan_product'] ?? 'Standard Loan',

          'loan_repayment_amount': hasActiveLoan ? repAmt : 0.0,

          'savings_deposit_amount': savAmt,

          'expected_amount': hasActiveLoan ? expRep : 0.0,

          'payment_status': pStatus,

          'overdue_amount': overdueVal,

          'mark_not_paid': isNotPaid,

        });

      }

    }

    if (toInsert.isEmpty && grpSavAmt == 0) {

      _showNotification('Please enter at least one repayment or savings deposit before reviewing.', isSuccess: false);

      return;

    }

    setState(() {

      _stagedTransactions = toInsert;

    });

    final isLateEntry = _canAuthorizeLateEntry(ref.read(authControllerProvider)) && ref.read(collectionsLateEntryProvider);

    _showAnimatedCollectionFlowModal(

      context: context,

      groupName: groupName,

      dateStr: dateStr,

      isOpen: isOpen,

      openReason: openReason,

      isLateEntry: isLateEntry,

    );

  }

  void _invalidateCollectionRelatedProviders() {
    ref.invalidate(collectionSheetFutureProvider);
    ref.invalidate(singleClientOptionsProvider);
    ref.invalidate(collectionsHistoryProvider);
    ref.invalidate(reversalOptionsProvider);
    ref.invalidate(coDashboardProvider);
    ref.invalidate(coCashbookDataProvider);
    ref.invalidate(portfolioDataProvider);
  }

  /// Displays the 4-phase animated collection confirmation, posting, and receipt modal

  void _showAnimatedCollectionFlowModal({

    required BuildContext context,

    required String groupName,

    required String dateStr,

    required bool isOpen,

    required String openReason,

    required bool isLateEntry,

  }) {

    if (_isOpeningBatchModal) return;

    _isOpeningBatchModal = true;

    final grpSavAmt = double.tryParse(_grpSavingsCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

    final isOnline = ref.read(isOnlineProvider);

    showGeneralDialog(

      context: context,

      barrierDismissible: false,

      barrierLabel: 'Collection Flow',

      barrierColor: const Color(0x8C000000),

      transitionDuration: const Duration(milliseconds: 320),

      pageBuilder: (dialogCtx, anim1, anim2) {

        return _CollectionFlowModal(

          groupName: groupName,

          dateStr: dateStr,

          isOpen: isOpen,

          openReason: openReason,

          isLateEntry: isLateEntry,

          stagedTransactions: List<Map<String, dynamic>>.from(_stagedTransactions),

          grpSavings: grpSavAmt,

          isOnline: isOnline,

          onConfirmPost: () => _executeBatchPost(groupName, dateStr),

          onDismissAndReset: () {

            Navigator.of(dialogCtx, rootNavigator: true).pop();

            setState(() {

              _stagedTransactions = [];

              _grpSavingsCtrl.clear();

              _memberRepaymentCtrls.clear();

              _memberSavingsCtrls.clear();

              _memberNotPaidFlags.clear();

              _expandedMemberCards.clear();

            });

            _invalidateCollectionRelatedProviders();

          },

          onViewHistory: () {

            Navigator.of(dialogCtx, rootNavigator: true).pop();

            setState(() {

              _stagedTransactions = [];

              ref.read(collectionsTabProvider.notifier).state = 1; // Tab 1: History

            });

            _invalidateCollectionRelatedProviders();

          },

        );

      },

      transitionBuilder: (dialogCtx, anim1, anim2, child) {

        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);

        return ScaleTransition(

          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),

          child: FadeTransition(

            opacity: anim1,

            child: child,

          ),

        );

      },

    ).then((_) {

      if (mounted) _isOpeningBatchModal = false;

    });

  }

  /// Internal batch submission worker executing backend posting or offline queuing

  Future<Map<String, dynamic>> _executeBatchPost(String groupName, String dateStr) async {

    final grpSavAmt = double.tryParse(_grpSavingsCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

    final isLateEntry = _canAuthorizeLateEntry(ref.read(authControllerProvider)) && ref.read(collectionsLateEntryProvider);
    final payload = {

      'group_name': groupName,

      'date': dateStr,

      'is_late_entry': isLateEntry,

      'group_savings_deposit': grpSavAmt,

      'group_savings_withdrawal': 0.0,

      'collections': _stagedTransactions,

    };

    final isOnline = ref.read(isOnlineProvider);
    final syncMgr = ref.read(offlineSyncManagerProvider);

    // Pre-generate stable idempotency key before transmission to ensure safe retry identity
    final batchKey = payload['idempotency_key']?.toString() ?? syncMgr.generateIdempotencyKey(groupName);
    payload['idempotency_key'] = batchKey;
    payload['batch_id'] = batchKey;

    if (!isOnline) {
      final offlineRes = await syncMgr.queueOfflineBatch(
        groupName: groupName,
        collectionDate: dateStr,
        payload: payload,
      );
      _invalidateCollectionRelatedProviders();
      return offlineRes;
    }

    try {
      final api = ref.read(coApiServiceProvider);
      final res = await api.submitBatchCollections(payload);
      _invalidateCollectionRelatedProviders();
      return res;
    } catch (e) {
      // Permanent errors (400, 401, 403, 422) must NEVER be queued or retried automatically
      if (ApiClient.isPermanentError(e)) {
        rethrow;
      }

      if (e is DioException) {
        // Network drop during response or timeout: Outcome is unknown. Attempt status recovery
        // unless it was an immediate connectionError where the request never reached the server.
        if (e.type != DioExceptionType.connectionError) {
          final client = ref.read(apiClientProvider);
          try {
            final statusCheck = await client.checkTransactionStatus(batchKey);
            if (statusCheck != null && statusCheck['status'] == 'Confirmed') {
              final body = statusCheck['response_body'] as Map<String, dynamic>? ?? {};
              _invalidateCollectionRelatedProviders();
              return body;
            }
          } catch (_) {}
        }

        // Enqueue into offline outbox preserving the EXACT original idempotency key
        final offlineRes = await syncMgr.queueOfflineBatch(
          groupName: groupName,
          collectionDate: dateStr,
          payload: payload,
        );
        _invalidateCollectionRelatedProviders();
        return offlineRes;
      }
      rethrow;
    }

  }

  /// Launches 4-phase animated confirmation flow modal for single client collection

  void _submitSingleClient(Map<String, dynamic> clientObj, String dateStr, [double expRep = 0.0]) {

    final savVal = double.tryParse(_scPersonalSavCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

    final grpSavVal = double.tryParse(_scGroupSavCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

    final repVal = _scMarkNotPaid ? 0.0 : (double.tryParse(_scLoanRepCtrl.text.replaceAll(',', '').trim()) ?? 0.0);

    final appVal = _scMarkNotPaid ? 0.0 : (double.tryParse(_scAppFeeCtrl.text.replaceAll(',', '').trim()) ?? 0.0);

    final pbVal = _scMarkNotPaid ? 0.0 : (double.tryParse(_scPbFeeCtrl.text.replaceAll(',', '').trim()) ?? 0.0);

    final miscVal = _scMarkNotPaid ? 0.0 : (double.tryParse(_scMiscFeeCtrl.text.replaceAll(',', '').trim()) ?? 0.0);

    final hasSelectedLoan = _scSelectedLoanId != null && _scSelectedLoanId!.trim().isNotEmpty;

    if (!hasSelectedLoan && (repVal > 0 || _scMarkNotPaid)) {

      _showNotification('This client has no active loan and cannot record a loan repayment or unpaid mark. Record Savings or Fees instead.', isSuccess: false);

      return;

    }

    if (!_scMarkNotPaid && savVal == 0 && grpSavVal == 0 && repVal == 0 && appVal == 0 && pbVal == 0 && miscVal == 0) {

      _showNotification('Please enter a Personal Savings Deposit, Group Savings Deposit, Loan Repayment, or Fee amount greater than ₦0.', isSuccess: false);

      return;

    }

    _showAnimatedSingleClientFlowModal(

      context: context,

      clientObj: clientObj,

      dateStr: dateStr,

      expRep: expRep,

      savVal: savVal,

      grpSavVal: grpSavVal,

      repVal: repVal,

      appVal: appVal,

      pbVal: pbVal,

      miscVal: miscVal,

      isNotPaid: _scMarkNotPaid,

      note: _scMarkNotPaid ? 'Marked NOT PAID (Single Client Collection)' : _scNoteCtrl.text.trim(),

    );

  }

  /// Displays the 4-phase animated single client collection confirmation modal

  void _showAnimatedSingleClientFlowModal({

    required BuildContext context,

    required Map<String, dynamic> clientObj,

    required String dateStr,

    required double expRep,

    required double savVal,

    required double grpSavVal,

    required double repVal,

    required double appVal,

    required double pbVal,

    required double miscVal,

    required bool isNotPaid,

    required String note,

  }) {

    if (_isOpeningSingleClientModal) return;

    _isOpeningSingleClientModal = true;

    final isOnline = ref.read(isOnlineProvider);

    final isLateEntry = _canAuthorizeLateEntry(ref.read(authControllerProvider)) && ref.read(collectionsLateEntryProvider);

    showGeneralDialog(

      context: context,

      barrierDismissible: false,

      barrierLabel: 'Single Client Collection Flow',

      barrierColor: const Color(0x8C000000),

      transitionDuration: const Duration(milliseconds: 320),

      pageBuilder: (dialogCtx, anim1, anim2) {

        return _SingleClientFlowModal(

          clientObj: clientObj,

          dateStr: dateStr,

          loanId: _scSelectedLoanId,

          expRep: expRep,

          savVal: savVal,

          grpSavVal: grpSavVal,

          repVal: repVal,

          appVal: appVal,

          pbVal: pbVal,

          miscVal: miscVal,

          isNotPaid: isNotPaid,

          note: note,

          isOnline: isOnline,

          onConfirmPost: () async {
            final isOnline = ref.read(isOnlineProvider);
            final syncMgr = ref.read(offlineSyncManagerProvider);
            final api = ref.read(coApiServiceProvider);
            final authorizedLateEntry = _canAuthorizeLateEntry(ref.read(authControllerProvider)) && isLateEntry;
            final payload = {
              'client_id': clientObj['client_id'],
              'client_name': clientObj['client_name'],
              'group_id': clientObj['group_id'],
              'group_name': clientObj['group_name'],
              'loan_id': _scSelectedLoanId,
              'date': dateStr,
              'is_late_entry': authorizedLateEntry,
              'savings_deposit': savVal,
              'group_savings_deposit': grpSavVal,
              'loan_repayment': repVal,
              'app_fee': appVal,
              'passbook_fee': pbVal,
              'misc_fee': miscVal,
              'note': note,
              'mark_not_paid': isNotPaid,
              'expected_amount': expRep,
            };

            final singleClientName = clientObj['client_name']?.toString() ?? 'Client';
            final singleKey = payload['idempotency_key']?.toString() ?? syncMgr.generateIdempotencyKey('SC_$singleClientName');
            payload['idempotency_key'] = singleKey;
            payload['batch_id'] = singleKey;

            if (!isOnline) {
              final offlineRes = await syncMgr.queueOfflineSingleCollection(
                clientName: singleClientName,
                collectionDate: dateStr,
                payload: payload,
              );
              _invalidateCollectionRelatedProviders();
              return offlineRes;
            }

            try {
              final res = await api.submitSingleCollection(payload);
              _invalidateCollectionRelatedProviders();
              return res;
            } catch (e) {
              // Permanent errors must NEVER be retried or queued
              if (ApiClient.isPermanentError(e)) {
                rethrow;
              }

              if (e is DioException) {
                if (e.type != DioExceptionType.connectionError) {
                  final client = ref.read(apiClientProvider);
                  try {
                    final statusCheck = await client.checkTransactionStatus(singleKey);
                    if (statusCheck != null && statusCheck['status'] == 'Confirmed') {
                      final body = statusCheck['response_body'] as Map<String, dynamic>? ?? {};
                      _invalidateCollectionRelatedProviders();
                      return body;
                    }
                  } catch (_) {}
                }

                final offlineRes = await syncMgr.queueOfflineSingleCollection(
                  clientName: singleClientName,
                  collectionDate: dateStr,
                  payload: payload,
                );
                _invalidateCollectionRelatedProviders();
                return offlineRes;
              }
              rethrow;
            }
          },
          onDismissAndReset: () {

            Navigator.of(dialogCtx, rootNavigator: true).pop();

            setState(() {

              _scPersonalSavCtrl.clear();

              _scGroupSavCtrl.clear();

              _scLoanRepCtrl.clear();

              _scAppFeeCtrl.clear();

              _scPbFeeCtrl.clear();

              _scMiscFeeCtrl.clear();

              _scNoteCtrl.clear();

              _scMarkNotPaid = false;

              _receiptData = null;

            });

            _invalidateCollectionRelatedProviders();

          },

          onViewHistory: () {

            Navigator.of(dialogCtx, rootNavigator: true).pop();

            setState(() {

              _scPersonalSavCtrl.clear();

              _scGroupSavCtrl.clear();

              _scLoanRepCtrl.clear();

              _scAppFeeCtrl.clear();

              _scPbFeeCtrl.clear();

              _scMiscFeeCtrl.clear();

              _scNoteCtrl.clear();

              _scMarkNotPaid = false;

              _receiptData = null;

              ref.read(collectionsTabProvider.notifier).state = 1;

            });

            _invalidateCollectionRelatedProviders();

          },

        );

      },

    ).then((_) {

      if (mounted) _isOpeningSingleClientModal = false;

    });

  }

  /// Submits reversal request to BM (app.py L7204)

  Future<void> _submitReversalRequest() async {

    final refId = _selectedReversalRefId;

    final reason = _revReasonCtrl.text.trim();

    if (refId == null || refId.isEmpty) {

      _showNotification('Please select a transaction to flag for reversal.', isSuccess: false);

      return;

    }

    if (reason.isEmpty) {

      _showNotification('Please provide a valid reason for the reversal.', isSuccess: false);

      return;

    }

    setState(() => _isSubmitting = true);

    try {

      final api = ref.read(coApiServiceProvider);

      final res = await api.requestRepaymentReversal({

        'record_id': refId,

        'record_type': _revCategory == 'Loan Repayments'
            ? 'Repayment'
            : (_revCategory == 'Savings Withdrawals' ? 'SavingsWithdrawal' : 'Savings Deposit'),

        'reason': reason,

      });

      final reqId = res['request_id']?.toString() ?? 'REQ';

      _showNotification('Reversal request submitted to Branch Manager for approval! (Ref: #${reqId.length > 8 ? reqId.substring(0, 8) : reqId})', isSuccess: true);

      _revReasonCtrl.clear();

      setState(() => _selectedReversalRefId = null);

      ref.invalidate(reversalRequestsProvider);

      ref.invalidate(reversalOptionsProvider);

    } catch (e) {

      _showNotification('Failed to submit reversal request: ${AppErrorDetails.from(e).message}', isSuccess: false);

    } finally {

      setState(() => _isSubmitting = false);

    }

  }

  // =========================================================================

  // MAIN BUILD

  // =========================================================================

  @override

  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final activeTab = ref.watch(collectionsTabProvider);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IcareSectionHeader(
              title: 'Daily Collections',
            ),
            const SizedBox(height: 12),

            // Notification / Flash Alert Banner
            if (_statusBannerText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: _isSuccessBanner ? tokens.successBg : tokens.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSuccessBanner ? tokens.successBorder : tokens.dangerBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccessBanner ? Icons.check_circle_outline : Icons.error_outline,
                      color: _isSuccessBanner ? tokens.successDot : tokens.dangerDot,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusBannerText!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isSuccessBanner ? tokens.successText : tokens.dangerText,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: tokens.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _statusBannerText = null),
                    ),
                  ],
                ),
              ),
            ],

            // 3. Primary Navigation Tabs
            _buildPrimaryTabs(activeTab),
            const SizedBox(height: 16),

            // 4. Tab Body Content
            if (activeTab == 0)
              _buildTab1RecordCollections()
            else if (activeTab == 1)
              _buildTab2HistoryAndAudit()
            else
              _buildTab3ErrorCorrection(),
          ],
        ),

        // Full Screen Posting Overlay with animated spinner & ledger commit status
        if (_isSubmitting)
          _buildFullScreenPostingOverlay(),
      ],
    );
  }

  /// Full-screen animated overlay shown when posting collections to General Ledger
  Widget _buildFullScreenPostingOverlay() {
    final tokens = IcareSurfaceTokens.of(context);
    return Positioned.fill(
      child: Container(
        color: const Color(0xD90F172A),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.borderSubtle),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: tokens.brandSoftBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: tokens.brandSoftBorder, width: 2),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(tokens.brandAccent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Posting Collections to Ledger',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Committing atomic journal entries to Primary Vault Cash and updating client balances...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: tokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 13, color: tokens.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Idempotency lock active • Do not close',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TOP CONTROL BAR & TABS
  // =========================================================================
  Widget _buildCompactOperationsBar({
    required String mode,
    required DateTime activeDate,
    required bool isLateEntry,
    required bool isMobile,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    final modes = ['Group Collection Sheet', 'Single Client Quick Entry'];

    // 1. Sleek Mode Segmented Pill
    final modeSegment = Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
        children: modes.map((m) {
          final isSel = mode == m;
          final isGroup = m == 'Group Collection Sheet';
          final btn = InkWell(
            onTap: () {
              ref.read(collectionsModeProvider.notifier).state = m;
            },
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 5),
              decoration: BoxDecoration(
                color: isSel ? tokens.brandPrimaryDark : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSel
                    ? const [
                        BoxShadow(
                          color: Color(0x140F172A),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isGroup ? Icons.groups_rounded : Icons.person_rounded,
                    size: 14,
                    color: isSel ? const Color(0xFFA7F3D0) : tokens.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isGroup ? 'Group Sheet' : (isMobile ? 'Single' : 'Single Entry'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                      color: isSel ? Colors.white : tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
          return isMobile ? Expanded(child: btn) : btn;
        }).toList(),
      ),
    );

    // 2. Ultra-Compact Unified Backdate / Date Pill
    Widget backdateWidget;
    if (isLateEntry) {
      backdateWidget = Container(
        height: 36,
        decoration: BoxDecoration(
          color: tokens.infoBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.infoBorder, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: activeDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  ref.read(collectionsDateProvider.notifier).state = picked;
                }
              },
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_calendar_rounded, size: 14, color: tokens.infoText),
                    const SizedBox(width: 5),
                    Text(
                      DateFormat('dd MMM yyyy').format(activeDate),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.infoText),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down, size: 15, color: tokens.infoText),
                  ],
                ),
              ),
            ),
            Container(width: 1, height: 20, color: tokens.infoBorder),
            InkWell(
              onTap: () {
                ref.read(collectionsLateEntryProvider.notifier).state = false;
                ref.read(collectionsDateProvider.notifier).state = null;
              },
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
              child: Tooltip(
                message: 'Reset backdated date to today',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Icon(Icons.close_rounded, size: 14, color: tokens.infoText),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      backdateWidget = InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now().subtract(const Duration(days: 1)),
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            ref.read(collectionsLateEntryProvider.notifier).state = true;
            ref.read(collectionsDateProvider.notifier).state = picked;
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 14, color: tokens.textMuted),
              const SizedBox(width: 5),
              Text(
                'Backdate Entry',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Row(
          children: [
            Expanded(child: modeSegment),
            if (_canAuthorizeLateEntry(ref.watch(authControllerProvider))) ...[
              const SizedBox(width: 8),
              backdateWidget,
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Collection Mode:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textPrimary),
              ),
              const SizedBox(width: 10),
              modeSegment,
            ],
          ),
          if (_canAuthorizeLateEntry(ref.watch(authControllerProvider))) backdateWidget,
        ],
      ),
    );
  }

  Widget _buildPrimaryTabs(int activeTab) {
    final tokens = IcareSurfaceTokens.of(context);
    final tabs = [
      {'label': 'Record Collections', 'icon': Icons.edit_note_rounded},
      {'label': 'Collection History & Audit', 'icon': Icons.receipt_long_outlined},
      {'label': 'Error Correction & Reversals', 'icon': Icons.rule_folder_outlined},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(tabs.length, (idx) {
            final isSel = activeTab == idx;
            final item = tabs[idx];
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => ref.read(collectionsTabProvider.notifier).state = idx,
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? tokens.brandPrimaryDark : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSel
                        ? const [
                            BoxShadow(
                              color: Color(0x140F172A),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        size: 15,
                        color: isSel ? const Color(0xFFA7F3D0) : tokens.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                          color: isSel ? Colors.white : tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1: RECORD COLLECTIONS
  // =========================================================================
  Widget _buildTab1RecordCollections() {
    final mode = ref.watch(collectionsModeProvider);
    final activeDate = ref.watch(effectiveCollectionsDateProvider);
    final isLateEntry = ref.watch(collectionsLateEntryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_receiptData != null) ...[
          _buildPersistentReceiptCard(),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 650;
            return _buildCompactOperationsBar(
              mode: mode,
              activeDate: activeDate,
              isLateEntry: isLateEntry,
              isMobile: isMobile,
            );
          },
        ),
        const SizedBox(height: 14),
        if (mode == 'Group Collection Sheet')
          _buildGroupCollectionSheetMode()
        else
          _buildSingleClientQuickEntryMode(),
      ],
    );
  }

  // =========================================================================
  // PERSISTENT RECEIPT CONFIRMATION CARD
  // =========================================================================
  Widget _buildPersistentReceiptCard() {
    final tokens = IcareSurfaceTokens.of(context);
    final r = _receiptData!;
    final batchId = r['batch_id']?.toString() ?? 'N/A';
    final groupName = r['group_name']?.toString() ?? 'N/A';
    final officer = r['officer']?.toString() ?? 'Credit Officer';
    final branch = r['branch']?.toString() ?? '';
    final recordedAt = r['timestamp']?.toString() ?? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final totalCash = (r['total_cash'] as num?)?.toDouble() ?? 0.0;
    final totalRep = (r['total_repayment'] as num?)?.toDouble() ?? 0.0;
    final totalSav = (r['total_savings'] as num?)?.toDouble() ?? 0.0;
    final totalRecs = r['total_submitted'] ?? 0;
    final alreadySaved = (r['already_saved'] as num?)?.toInt() ?? 0;
    final items = (r['items'] as List<dynamic>?) ?? [];
    final String dStr = r['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String ofcStr = '$officer ($branch)';
    final String totStr = CurrencyFormatter.formatNaira(totalCash, showDecimals: true);
    final String repStr = CurrencyFormatter.formatNaira(totalRep, showDecimals: true);
    final String savStr = CurrencyFormatter.formatNaira(totalSav, showDecimals: true);
    final isOfflineQueued = r['status'] == 'QUEUED_LOCAL' || r['watermark'] != null;

    final whatsappText = isOfflineQueued ? '''

ICARE FIELD COLLECTION RECEIPT (OFFLINE)

Batch ID: $batchId

Group: $groupName

Date: $dStr | Time: $recordedAt

Officer: $ofcStr

Total Collected: $totStr

- Loan Repayments: $repStr

- Savings Deposits: $savStr

Records: $totalRecs

Status: PENDING SERVER SYNCHRONIZATION (NOT YET POSTED TO LEDGER)''' : '''

ICARE COLLECTION RECEIPT

Batch ID: $batchId

Group: $groupName

Date: $dStr | Time: $recordedAt

Officer: $ofcStr

Total Collected: $totStr

- Loan Repayments: $repStr

- Savings Deposits: $savStr

Records: $totalRecs

Status: CONFIRMED & POSTED TO LEDGER''';

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOfflineQueued ? tokens.warningDot : tokens.brandAccent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOfflineQueued ? tokens.warningDot : tokens.brandAccent).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: EdgeInsets.all(isMobile ? 14 : 20),
            decoration: BoxDecoration(
              color: isOfflineQueued ? tokens.warningBg : tokens.successBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isOfflineQueued ? tokens.warningBg : tokens.successBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isOfflineQueued ? tokens.warningBorder : tokens.successBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isOfflineQueued ? Icons.cloud_upload_outlined : Icons.check_circle_outline,
                    color: isOfflineQueued ? tokens.warningDot : tokens.successDot,
                    size: isMobile ? 22 : 28,
                  ),
                ),
                SizedBox(width: isMobile ? 10 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOfflineQueued
                            ? 'COLLECTION QUEUED LOCALLY (PENDING SYNC)'
                            : 'COLLECTION POSTED & CONFIRMED IN GENERAL LEDGER',
                        style: TextStyle(
                          fontSize: isMobile ? 13.5 : 16,
                          fontWeight: FontWeight.w800,
                          color: isOfflineQueued ? tokens.warningText : tokens.successText,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isOfflineQueued
                            ? 'Batch stored in local outbox on device. Final ledger posting to Primary Vault Cash will occur upon network synchronization.'
                            : 'All member repayments and savings deposits have been committed to the ledger with physical cash recorded in Primary Vault Cash.',
                        style: TextStyle(
                          fontSize: isMobile ? 11.5 : 12.5,
                          color: isOfflineQueued ? tokens.warningText : tokens.successText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isOfflineQueued ? tokens.warningBorder : tokens.successBorder),

          // Metadata Grid
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final m1 = _buildReceiptMetaItem('Batch Reference', batchId, isCopyable: true);
                final m2 = _buildReceiptMetaItem('Group / Source', groupName);
                final m3 = _buildReceiptMetaItem('Officer / Branch', ofcStr);
                final m4 = _buildReceiptMetaItem('Recorded At', recordedAt);
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: m1),
                          const SizedBox(width: 10),
                          Expanded(child: m2),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: m3),
                          const SizedBox(width: 10),
                          Expanded(child: m4),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: m1),
                    const SizedBox(width: 12),
                    Expanded(child: m2),
                    const SizedBox(width: 12),
                    Expanded(child: m3),
                    const SizedBox(width: 12),
                    Expanded(child: m4),
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: tokens.borderSubtle),

          // 4 Executive KPI Summary Cards
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final c1 = _buildReceiptKpiCard('Total Cash Collected', CurrencyFormatter.formatNaira(totalCash, showDecimals: true), tokens.brandAccent, isHero: true);
                final c2 = _buildReceiptKpiCard('Loan Repayments', CurrencyFormatter.formatNaira(totalRep, showDecimals: true), tokens.infoDot);
                final c3 = _buildReceiptKpiCard('Savings Deposits', CurrencyFormatter.formatNaira(totalSav, showDecimals: true), tokens.brandPrimary);
                final c4 = _buildReceiptKpiCard('Members Accounted', '$totalRecs records', tokens.textSecondary);
                if (w < 600) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: c1),
                          const SizedBox(width: 8),
                          Expanded(child: c2),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: c3),
                          const SizedBox(width: 8),
                          Expanded(child: c4),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: c1),
                    const SizedBox(width: 12),
                    Expanded(child: c2),
                    const SizedBox(width: 12),
                    Expanded(child: c3),
                    const SizedBox(width: 12),
                    Expanded(child: c4),
                  ],
                );
              },
            ),
          ),
          if (alreadySaved > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.infoBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.infoBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: tokens.infoText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Idempotency Protection Active: $alreadySaved records were safely identified from an earlier network attempt and skipped to guarantee zero duplicate postings.',
                        style: TextStyle(fontSize: 12, color: tokens.infoText, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Itemized Expander Table

          if (items.isNotEmpty) ...[

            Theme(

              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),

              child: ExpansionTile(

                initiallyExpanded: true,

                title: Text(

                  'View Itemized Member Verification Breakdown',

                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.successText),

                ),

                children: [

                  Container(

                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),

                    decoration: BoxDecoration(

                      color: tokens.surfaceElevated,

                      borderRadius: BorderRadius.circular(10),

                      border: Border.all(color: tokens.borderSubtle),

                    ),

                    child: SingleChildScrollView(

                      scrollDirection: Axis.horizontal,

                      child: ConstrainedBox(

                        constraints: const BoxConstraints(minWidth: 550),

                        child: Table(

                          border: TableBorder.all(color: tokens.borderSubtle),

                          columnWidths: const {

                            0: FlexColumnWidth(2.2),

                            1: FlexColumnWidth(1.4),

                            2: FlexColumnWidth(1.4),

                            3: FlexColumnWidth(1.2),

                          },

                          children: [

                            TableRow(

                              decoration: BoxDecoration(color: tokens.surfaceSubtle),

                              children: [

                                Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Client / Member', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textSecondary))),

                                Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Repayment (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textSecondary))),

                                Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Savings (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textSecondary))),

                                Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Posting Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textSecondary))),

                              ],

                            ),

                            ...items.map((it) {

                              final cName = it['client']?.toString() ?? 'Member';

                              final rep = (it['repayment'] as num?)?.toDouble() ?? 0.0;

                              final sav = (it['savings'] as num?)?.toDouble() ?? 0.0;

                              final stat = it['status']?.toString() ?? 'UNRECORDED';

                              return TableRow(

                                children: [

                                  Padding(

                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                                    child: Text(cName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary), softWrap: true),

                                  ),

                                  Padding(

                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                                    child: Text(rep > 0 ? CurrencyFormatter.formatNaira(rep, showDecimals: true) : '—', style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFamily: 'monospace')),

                                  ),

                                  Padding(

                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                                    child: Text(sav > 0 ? CurrencyFormatter.formatNaira(sav, showDecimals: true) : '—', style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontFamily: 'monospace')),

                                  ),

                                  Padding(

                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                                    child: Container(

                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

                                      decoration: BoxDecoration(color: tokens.successBg, borderRadius: BorderRadius.circular(4), border: Border.all(color: tokens.successBorder)),

                                      child: Text(stat, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.successText), textAlign: TextAlign.center),

                                    ),

                                  ),

                                ],

                              );

                            }),

                          ],

                        ),

                      ),

                    ),

                  ),

                ],

              ),

            ),

          ],

          // Formatted WhatsApp Receipt Expander

          Theme(

            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),

            child: ExpansionTile(

              title: Text(

                'View / Copy WhatsApp Summary',

                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.successText),

              ),

              children: [

                Container(

                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),

                  padding: EdgeInsets.all(isMobile ? 12 : 14),

                  decoration: BoxDecoration(

                    color: const Color(0xFF0F172A),

                    borderRadius: BorderRadius.circular(10),

                    border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,

                  ),

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Row(

                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                        children: [

                          const Text('Official WhatsApp Digital Receipt', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),

                          TextButton.icon(

                            icon: const Icon(Icons.copy, size: 14, color: Color(0xFF10B981)),

                            label: const Text('Copy Receipt', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w700)),

                            style: TextButton.styleFrom(

                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                              minimumSize: Size.zero,

                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,

                            ),

                            onPressed: () {

                              Clipboard.setData(ClipboardData(text: whatsappText));

                              ScaffoldMessenger.of(context).showSnackBar(

                                const SnackBar(content: Text('WhatsApp receipt copied to clipboard!'), duration: Duration(seconds: 2)),

                              );

                            },

                          ),

                        ],

                      ),

                      const SizedBox(height: 8),

                      SelectableText(

                        whatsappText,

                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFF1F5F9), height: 1.4),

                      ),

                    ],

                  ),

                ),

              ],

            ),

          ),

          // Return / Record Next Group Actions

          Padding(

            padding: EdgeInsets.fromLTRB(16, 0, 16, isMobile ? 14 : 20),

            child: LayoutBuilder(

              builder: (context, constraints) {

                final isCompact = constraints.maxWidth < 500;

                final nextBtn = SizedBox(

                  height: 46,

                  child: ElevatedButton.icon(

                    onPressed: () {

                      setState(() {

                        _receiptData = null;

                        _grpSavingsCtrl.clear();

                        _memberRepaymentCtrls.clear();

                        _memberSavingsCtrls.clear();

                        _memberNotPaidFlags.clear();

                      });

                    },

                    icon: const Icon(Icons.refresh, size: 18),

                    label: const Text(

                      'Record Next Group / Return',

                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),

                    ),

                    style: ElevatedButton.styleFrom(

                      backgroundColor: tokens.isDark ? tokens.brandPrimaryDark : tokens.brandPrimary,

                      foregroundColor: Colors.white,

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

                      elevation: 1,

                    ),

                  ),

                );

                final historyBtn = SizedBox(

                  height: 46,

                  child: OutlinedButton.icon(

                    onPressed: () {

                      setState(() {

                        _receiptData = null;

                      });

                      ref.read(collectionsTabProvider.notifier).state = 1;

                    },

                    icon: const Icon(Icons.history, size: 18),

                    label: const Text(

                      'View in History & Audit',

                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),

                    ),

                    style: OutlinedButton.styleFrom(

                      foregroundColor: tokens.textSecondary,

                      side: BorderSide(color: tokens.borderStrong, width: 1.2),

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

                    ),

                  ),

                );

                if (isCompact) {

                  return Column(

                    crossAxisAlignment: CrossAxisAlignment.stretch,

                    children: [

                      nextBtn,

                      const SizedBox(height: 10),

                      historyBtn,

                    ],

                  );

                }

                return Row(

                  children: [

                    Expanded(child: nextBtn),

                    const SizedBox(width: 12),

                    Expanded(child: historyBtn),

                  ],

                );

              },

            ),

          ),

        ],

      ),

    );

  }

  Widget _buildReceiptMetaItem(String label, String value, {bool isCopyable = false}) {

    final tokens = IcareSurfaceTokens.of(context);

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

      decoration: BoxDecoration(

        color: tokens.surfaceSubtle,

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: tokens.borderSubtle),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            label,

            style: TextStyle(fontSize: 10.5, color: tokens.textMuted, fontWeight: FontWeight.w600),

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

          ),

          const SizedBox(height: 2),

          Row(

            children: [

              Expanded(

                child: Text(

                  value,

                  style: TextStyle(fontSize: 12.5, color: tokens.textPrimary, fontWeight: FontWeight.w700),

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                ),

              ),

              if (isCopyable) ...[

                const SizedBox(width: 4),

                InkWell(

                  onTap: () {

                    Clipboard.setData(ClipboardData(text: value));

                    ScaffoldMessenger.of(context).showSnackBar(

                      SnackBar(content: Text('$label copied to clipboard!'), duration: const Duration(seconds: 1)),

                    );

                  },

                  child: Icon(Icons.copy, size: 14, color: tokens.textMuted),

                ),

              ],

            ],

          ),

        ],

      ),

    );

  }

  Widget _buildReceiptKpiCard(String label, String value, Color valueColor, {bool isHero = false}) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          top: BorderSide(color: valueColor, width: 3),
          left: BorderSide(color: isHero ? tokens.brandSoftBorder : tokens.borderSubtle),
          right: BorderSide(color: isHero ? tokens.brandSoftBorder : tokens.borderSubtle),
          bottom: BorderSide(color: isHero ? tokens.brandSoftBorder : tokens.borderSubtle),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: tokens.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: valueColor,
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseKpiCard(
    String label,
    String value,
    String subtitle, {
    Color? accentColor,
    bool isAlert = false,
    IconData? icon,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    final effectiveColor = isAlert ? tokens.dangerText : (accentColor ?? tokens.infoDot);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isAlert ? tokens.dangerBg : tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlert ? tokens.dangerBorder : tokens.borderSubtle,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: isAlert ? tokens.dangerText : tokens.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(icon, size: 12, color: effectiveColor),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isAlert ? tokens.dangerText : tokens.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isAlert ? tokens.dangerText : tokens.textMuted,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MODE 1: GROUP COLLECTION SHEET
  // =========================================================================
  Widget _buildGroupCollectionSheetMode() {
    final tokens = IcareSurfaceTokens.of(context);
    final sheetAsync = ref.watch(collectionSheetFutureProvider);
    final selectedDate = ref.watch(effectiveCollectionsDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    return sheetAsync.when(
      loading: () => const IcareFormSkeleton(fieldCount: 5),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.dangerBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.dangerBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: tokens.dangerDot, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Error loading collection sheet: ${AppErrorDetails.from(err).message}',
                style: TextStyle(color: tokens.dangerText, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      data: (sheetData) {
        final availableGroups = (sheetData['available_groups'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['Ungrouped'];
        final currentGroup = sheetData['group_name']?.toString() ?? availableGroups.first;
        final meetingDay = sheetData['meeting_day']?.toString() ?? DateFormat('EEEE').format(selectedDate);
        final isOpen = sheetData['is_open'] == true;
        final openReason = sheetData['open_reason']?.toString() ?? 'Closed';
        final grpSavingsBal = (sheetData['group_savings_balance'] as num?)?.toDouble() ?? 0.0;
        final members = (sheetData['members'] as List<dynamic>?) ?? [];
        final nextScopeKey = '$currentGroup::$dateStr';

        if (_lastSheetCtrlScopeKey.isNotEmpty && _lastSheetCtrlScopeKey != nextScopeKey) {
          for (final c in _memberRepaymentCtrls.values) {
            c.dispose();
          }
          for (final c in _memberSavingsCtrls.values) {
            c.dispose();
          }
          _memberRepaymentCtrls.clear();
          _memberSavingsCtrls.clear();
          _memberNotPaidFlags.clear();
          _grpSavingsCtrl.clear();
          _stagedTransactions = [];
        }
        _lastSheetCtrlScopeKey = nextScopeKey;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Selection Card & Meeting Day
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Solidarity Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: availableGroups.contains(currentGroup) ? currentGroup : availableGroups.first,
                          dropdownColor: tokens.surfaceElevated,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: tokens.surfaceSubtle,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
                          ),
                          items: availableGroups.map((g) => DropdownMenuItem(value: g, child: Text(g, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(collectionsSelectedGroupProvider.notifier).state = val;
                              setState(() {
                                _expandedMemberCards.clear();
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Text('Meeting Day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: tokens.surfaceSubtle,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: tokens.borderStrong),
                          ),
                          child: Text(
                            '$meetingDay (${DateFormat('dd MMM').format(selectedDate)})',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Select Solidarity Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: availableGroups.contains(currentGroup) ? currentGroup : availableGroups.first,
                              dropdownColor: tokens.surfaceElevated,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: tokens.surfaceSubtle,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
                              ),
                              items: availableGroups.map((g) => DropdownMenuItem(value: g, child: Text(g, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  ref.read(collectionsSelectedGroupProvider.notifier).state = val;
                                  setState(() {
                                    _expandedMemberCards.clear();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Meeting Day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: tokens.surfaceSubtle,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: tokens.borderStrong),
                              ),
                              child: Text(
                                '$meetingDay (${DateFormat('dd MMM').format(selectedDate)})',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Communal Group Savings Row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.borderSubtle),
                boxShadow: const [
                  BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final headerSection = Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.brandSoftBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tokens.brandSoftBorder),
                        ),
                        child: Icon(Icons.account_balance_outlined, size: 18, color: tokens.brandSoftText),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Group Communal Savings',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tokens.brandSoftBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('Reserve', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tokens.brandSoftText)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Available Vault Reserve: ${CurrencyFormatter.formatNaira(grpSavingsBal)}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.brandAccent, fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final inputField = SizedBox(
                    width: isMobile ? double.infinity : 240,
                    child: TextField(
                      controller: _grpSavingsCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: tokens.textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: tokens.surfaceSubtle,
                        labelText: 'Group Savings (₦)',
                        hintText: '0',
                        prefixIcon: Icon(Icons.payments_outlined, size: 16, color: tokens.textMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.brandAccent, width: 1.5)),
                      ),
                    ),
                  );
                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        headerSection,
                        const SizedBox(height: 12),
                        inputField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: headerSection),
                      const SizedBox(width: 16),
                      inputField,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Group Meeting Pulse Bar
            Builder(
              builder: (context) {
                final totalExpRep = members.fold<double>(0.0, (acc, m) => acc + ((m['expected_repayment'] as num?)?.toDouble() ?? 0.0));
                final totalArrears = members.fold<double>(0.0, (acc, m) => acc + ((m['overdue_arrears'] as num?)?.toDouble() ?? 0.0));
                final payingCount = members.where((m) => ((m['expected_repayment'] as num?)?.toDouble() ?? 0.0) > 0).length;
                final p1 = _buildPulseKpiCard('Expected Repayment', CurrencyFormatter.formatNaira(totalExpRep), '$payingCount Members Due', accentColor: tokens.brandAccent, icon: Icons.event_note_outlined);
                final p2 = _buildPulseKpiCard('Overdue Arrears', CurrencyFormatter.formatNaira(totalArrears), totalArrears > 0 ? 'Action Needed' : 'None in Group', accentColor: tokens.dangerText, isAlert: totalArrears > 0, icon: Icons.warning_amber_rounded);
                final p3 = _buildPulseKpiCard('Communal Savings', CurrencyFormatter.formatNaira(grpSavingsBal), 'Group Reserve Fund', accentColor: tokens.infoDot, icon: Icons.savings_outlined);
                final p4 = _buildPulseKpiCard('Group Size', '${members.length} Members', 'Active in Meeting', accentColor: tokens.textSecondary, icon: Icons.groups_outlined);
                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 800) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: p1),
                            const SizedBox(width: 10),
                            Expanded(child: p2),
                            const SizedBox(width: 10),
                            Expanded(child: p3),
                            const SizedBox(width: 10),
                            Expanded(child: p4),
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: p1),
                              const SizedBox(width: 10),
                              Expanded(child: p2),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: p3),
                              const SizedBox(width: 10),
                              Expanded(child: p4),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Section Header & Expand Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Members in $currentGroup (${members.length})',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                ),

                Row(
                  children: [
                    Checkbox(
                      value: _expandAllMembers,
                      activeColor: tokens.brandAccent,
                      onChanged: (val) {
                        final nextVal = val == true;
                        setState(() {
                          _expandAllMembers = nextVal;
                          for (final m in members) {
                            final cid = m['client_id']?.toString() ?? '';
                            if (cid.isNotEmpty) {
                              _expandedMemberCards[cid] = nextVal;
                            }
                          }
                        });
                      },
                    ),
                    Text('Expand All Members', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Empty State Check
            if (members.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 36, color: tokens.textMuted),
                      const SizedBox(height: 8),
                      Text('No active members in this group.', style: TextStyle(color: tokens.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Live Collection Progress Dock
              Builder(
                builder: (context) {
                  double liveRep = 0.0;
                  double liveSav = double.tryParse(_grpSavingsCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                  int accountedCount = 0;
                  int alreadyRecordedCount = 0;
                  double alreadyRecordedTotal = 0.0;

                  for (final m in members) {
                    final tTot = (m['today_collected_total'] as num?)?.toDouble() ?? 0.0;
                    final tStat = m['today_status']?.toString();
                    if (tTot > 0 || tStat == 'PAID' || tStat == 'NOT_PAID') {
                      alreadyRecordedCount++;
                      alreadyRecordedTotal += tTot;
                    }

                    final cid = m['client_id']?.toString() ?? '';
                    final isNotPaid = _memberNotPaidFlags[cid] == true;
                    if (isNotPaid) {
                      accountedCount++;
                    } else {
                      final rep = double.tryParse(_memberRepaymentCtrls[cid]?.text.replaceAll(',', '').trim() ?? '') ?? 0.0;
                      final sav = double.tryParse(_memberSavingsCtrls[cid]?.text.replaceAll(',', '').trim() ?? '') ?? 0.0;
                      if (rep > 0 || sav > 0) accountedCount++;
                      liveRep += rep;
                      liveSav += sav;
                    }
                  }

                  final liveTotal = liveRep + liveSav;
                  final totalTarget = members.fold<double>(0.0, (acc, m) => acc + ((m['expected_repayment'] as num?)?.toDouble() ?? 0.0));
                  final progressPct = totalTarget > 0 ? (liveRep / totalTarget).clamp(0.0, 1.0) : 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: tokens.successBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.successBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: tokens.successDot,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Live Collection Progress',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.successText),
                                ),
                              ],
                            ),
                            Text(
                              '$accountedCount / ${members.length} Accounted',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.successText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressPct,
                            minHeight: 6,
                            backgroundColor: tokens.successBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(tokens.successDot),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Collected: ${CurrencyFormatter.formatNaira(liveTotal)}',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: tokens.successText),
                            ),
                            Text(
                              'Target: ${CurrencyFormatter.formatNaira(totalTarget)}',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textMuted),
                            ),
                          ],
                        ),
                        if (alreadyRecordedCount > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: tokens.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: tokens.successBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, size: 14, color: tokens.successText),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Already Recorded Today: $alreadyRecordedCount of ${members.length} Members (${CurrencyFormatter.formatNaira(alreadyRecordedTotal)})',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.successText),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              // Member Collection Cards
              ...members.map((m) => _buildMemberCollectionCard(m)),
              const SizedBox(height: 20),

              // Calculate Totals & Review Members Button
              Builder(
                builder: (context) {
                  double liveRep = 0.0;
                  double liveSav = double.tryParse(_grpSavingsCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                  for (final m in members) {
                    final cid = m['client_id']?.toString() ?? '';
                    final isNotPaid = _memberNotPaidFlags[cid] == true;
                    if (!isNotPaid) {
                      final rep = double.tryParse(_memberRepaymentCtrls[cid]?.text.replaceAll(',', '').trim() ?? '') ?? 0.0;
                      final sav = double.tryParse(_memberSavingsCtrls[cid]?.text.replaceAll(',', '').trim() ?? '') ?? 0.0;
                      liveRep += rep;
                      liveSav += sav;
                    }
                  }
                  final liveTotal = liveRep + liveSav;
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _calculateAndReviewGroup(members, currentGroup, dateStr, isOpen, openReason),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimaryDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        'Review & Post Collections (${CurrencyFormatter.formatNaira(liveTotal)})',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMemberCollectionCard(dynamic m) {
    final tokens = IcareSurfaceTokens.of(context);
    final cid = m['client_id']?.toString() ?? '';
    final code = m['client_code']?.toString() ?? cid;
    final name = m['client_name']?.toString() ?? 'Client';
    final rawLoanId = m['loan_id']?.toString().trim() ?? '';
    final hasActiveLoan = rawLoanId.isNotEmpty && rawLoanId.toLowerCase() != 'null';
    final actCred = (m['active_credit'] as num?)?.toDouble() ?? 0.0;
    final remBal = (m['remaining_balance'] as num?)?.toDouble() ?? 0.0;
    final expRep = hasActiveLoan ? ((m['expected_repayment'] as num?)?.toDouble() ?? 0.0) : 0.0;
    final savBal = (m['savings_balance'] as num?)?.toDouble() ?? 0.0;
    final hasOverdue = m['has_overdue'] == true;
    final overdueArrears = (m['overdue_arrears'] as num?)?.toDouble() ?? 0.0;
    final prodName = m['loan_product']?.toString() ?? 'Loan';
    final isFutureLoan = m['is_future_loan'] == true;
    final tRep = (m['today_repayment'] as num?)?.toDouble() ?? 0.0;
    final tSav = (m['today_savings'] as num?)?.toDouble() ?? 0.0;
    final tStat = m['today_status']?.toString() ?? 'UNRECORDED';
    final tTot = (m['today_collected_total'] as num?)?.toDouble() ?? (tRep + tSav);
    final isAlreadyRecorded = tTot > 0 || tStat == 'PAID' || tStat == 'NOT_PAID';

    // Initialize state controllers for member
    if (!hasActiveLoan) {
      _memberNotPaidFlags[cid] = false;
    }
    _memberRepaymentCtrls.putIfAbsent(cid, () => TextEditingController(text: (hasActiveLoan && expRep > 0) ? expRep.toStringAsFixed(0) : '0'));
    if (!hasActiveLoan && _memberRepaymentCtrls[cid]!.text != '0') {
      _memberRepaymentCtrls[cid]!.text = '0';
    }
    _memberSavingsCtrls.putIfAbsent(cid, () => TextEditingController());
    _memberNotPaidFlags.putIfAbsent(cid, () => false);

    final isNotPaid = hasActiveLoan && (_memberNotPaidFlags[cid] == true);
    final isExpanded = _expandedMemberCards[cid] == true;
    final repCtrl = _memberRepaymentCtrls[cid]!;
    final savCtrl = _memberSavingsCtrls[cid]!;
    final currentRep = isNotPaid ? 0.0 : (double.tryParse(repCtrl.text.replaceAll(',', '').trim()) ?? 0.0);
    final currentSav = double.tryParse(savCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final clientTotal = currentRep + currentSav;

    // Client Initials
    final nameParts = name.trim().split(RegExp(r'\s+'));
    final initials = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : (nameParts.isNotEmpty && nameParts[0].isNotEmpty ? nameParts[0][0].toUpperCase() : 'C');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? tokens.brandAccent
              : (isNotPaid
                  ? tokens.dangerBorder
                  : (isAlreadyRecorded
                      ? tokens.successBorder
                      : (hasOverdue ? tokens.warningBorder : (clientTotal > 0 ? tokens.successBorder : tokens.borderSubtle)))),
          width: isExpanded ? 1.8 : (isAlreadyRecorded || isNotPaid || hasOverdue || clientTotal > 0 ? 1.5 : 1),
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded ? tokens.brandAccent.withValues(alpha: 0.08) : const Color(0x080F172A),
            blurRadius: isExpanded ? 8 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isExpanded ? null : () => _toggleMemberCard(cid),
          child: Padding(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Client Avatar, Name, Code, Product, Status Pill & Expand Toggle
                InkWell(
                  onTap: () => _toggleMemberCard(cid),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        // Initials Circle
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isNotPaid
                                ? tokens.dangerBg
                                : (isAlreadyRecorded
                                    ? tokens.successBg
                                    : (hasOverdue ? tokens.warningBg : (isExpanded ? tokens.brandSoftBg : tokens.successBg))),
                            border: Border.all(
                              color: isNotPaid
                                  ? tokens.dangerBorder
                                  : (hasOverdue ? tokens.warningBorder : tokens.successBorder),
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isNotPaid
                                    ? tokens.dangerText
                                    : (hasOverdue ? tokens.warningText : tokens.successText),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Client Name & Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  text: name,
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: tokens.textPrimary),
                                  children: [
                                    TextSpan(
                                      text: ' ($code)',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textMuted),
                                    ),
                                  ],
                                ),
                                softWrap: true,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: tokens.surfaceSubtle, borderRadius: BorderRadius.circular(4)),
                                    child: Text(prodName, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
                                  ),
                                  if (expRep > 0)
                                    Text(
                                      'Exp: ${CurrencyFormatter.formatNaira(expRep)}',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.successText),
                                    ),
                                  if (isAlreadyRecorded) ...[
                                    if (tStat == 'NOT_PAID')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: tokens.warningBg,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: tokens.warningBorder),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.info_outline, size: 11, color: tokens.warningText),
                                            const SizedBox(width: 3),
                                            Text('Marked Unpaid Today', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tokens.warningText)),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: tokens.successBg,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: tokens.successBorder),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle_outline, size: 11, color: tokens.successText),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Recorded Today: ${tRep > 0 ? CurrencyFormatter.formatNaira(tRep) + " Rep" : ""}${tRep > 0 && tSav > 0 ? " · " : ""}${tSav > 0 ? CurrencyFormatter.formatNaira(tSav) + " Sav" : ""}',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tokens.successText),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Collapsed Status Pill
                        if (!isExpanded) ...[
                          if (isAlreadyRecorded && tTot > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: tokens.successBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: tokens.successBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 12, color: tokens.successText),
                                  const SizedBox(width: 4),
                                  Text(CurrencyFormatter.formatNaira(tTot), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tokens.successText)),
                                ],
                              ),
                            )
                          else if (isNotPaid)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: tokens.dangerBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: tokens.dangerBorder),
                              ),
                              child: Text('Unpaid (₦0)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.dangerText)),
                            )
                          else if (clientTotal > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: tokens.successBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: tokens.successBorder),
                              ),
                              child: Text(CurrencyFormatter.formatNaira(clientTotal), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tokens.successText)),
                            ),
                          const SizedBox(width: 6),
                        ],
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: tokens.textMuted,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),

                if (isExpanded) ...[
                  const SizedBox(height: 10),

                  // Financial Micro-Metrics Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ACTIVE CREDIT', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: tokens.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.formatNaira(actCred),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 22, color: tokens.borderSubtle),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('REMAINING', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: tokens.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.formatNaira(remBal),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 22, color: tokens.borderSubtle),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SAVINGS BAL', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: tokens.successText), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.formatNaira(savBal),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.successText, fontFeatures: const [FontFeature.tabularFigures()]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (hasOverdue && overdueArrears > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: tokens.warningBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tokens.warningBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 15, color: tokens.warningText),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Overdue Arrears: ${CurrencyFormatter.formatNaira(overdueArrears)}',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tokens.warningText),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (isFutureLoan) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: tokens.infoBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tokens.infoBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 15, color: tokens.infoText),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'First installment starts on ${m['start_date'] ?? 'next meeting'}',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.infoText),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Repayment Fast-Entry Shortcuts
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        hasActiveLoan ? 'Loan Repayment' : 'No Active Loan (Savings Only)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: hasActiveLoan ? tokens.textPrimary : tokens.textMuted,
                        ),
                      ),
                      if (hasActiveLoan)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (expRep > 0)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _memberNotPaidFlags[cid] = false;
                                    repCtrl.text = expRep.toStringAsFixed(0);
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: tokens.successBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: tokens.successBorder),
                                  ),
                                  child: Text(
                                    'Expected: ₦${expRep.toStringAsFixed(0)}',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.successText),
                                  ),
                                ),
                              ),
                            if (remBal > 0)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _memberNotPaidFlags[cid] = false;
                                    repCtrl.text = remBal.toStringAsFixed(0);
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: tokens.infoBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: tokens.infoBorder),
                                  ),
                                  child: Text(
                                    'Payoff: ₦${remBal.toStringAsFixed(0)}',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.infoText),
                                  ),
                                ),
                              ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  final nextVal = !isNotPaid;
                                  _memberNotPaidFlags[cid] = nextVal;
                                  if (nextVal) {
                                    repCtrl.text = '0';
                                  } else {
                                    repCtrl.text = expRep.toStringAsFixed(0);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isNotPaid ? tokens.dangerBg : tokens.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isNotPaid ? tokens.dangerBorder : tokens.borderStrong),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isNotPaid ? Icons.check_circle : Icons.circle_outlined,
                                      size: 11,
                                      color: isNotPaid ? tokens.dangerText : tokens.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Unpaid (₦0)',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: isNotPaid ? tokens.dangerText : tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Repayment Input
                  TextField(
                    controller: repCtrl,
                    enabled: hasActiveLoan && !isNotPaid,
                    readOnly: !hasActiveLoan,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: (hasActiveLoan && !isNotPaid) ? tokens.textPrimary : tokens.textMuted),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: (hasActiveLoan && !isNotPaid) ? tokens.surface : tokens.surfaceSubtle,
                      prefixText: '₦ ',
                      prefixStyle: TextStyle(fontWeight: FontWeight.w700, color: hasActiveLoan ? tokens.textPrimary : tokens.textMuted),
                      hintText: hasActiveLoan ? 'Expected: ${expRep.toStringAsFixed(0)}' : 'No active loan — record savings below',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderSubtle)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.brandAccent, width: 1.8)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Savings Fast-Add Shortcuts
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text('Savings Deposit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...[500, 1000, 2000].map((amt) {
                            return InkWell(
                              onTap: () {
                                final cur = double.tryParse(savCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                                final nextVal = cur + amt;
                                setState(() {
                                  savCtrl.text = nextVal.toStringAsFixed(0);
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: tokens.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: tokens.borderStrong),
                                ),
                                child: Text(
                                  '+₦$amt',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                                ),
                              ),
                            );
                          }),
                          if (currentSav > 0)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  savCtrl.text = '';
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: tokens.dangerBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: tokens.dangerBorder),
                                ),
                                child: Text(
                                  'Clear',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tokens.dangerText),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Savings Input
                  TextField(
                    controller: savCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: tokens.textPrimary),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: tokens.surface,
                      prefixText: '₦ ',
                      prefixStyle: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary),
                      hintText: '0',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.brandAccent, width: 1.8)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Member Card Footer Summary
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: clientTotal > 0 ? tokens.successBg : tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: clientTotal > 0 ? tokens.successBorder : tokens.borderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rep: ${CurrencyFormatter.formatNaira(currentRep)} · Sav: ${CurrencyFormatter.formatNaira(currentSav)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: clientTotal > 0 ? tokens.successText : tokens.textMuted,
                          ),
                        ),
                        Text(
                          'Total: ${CurrencyFormatter.formatNaira(clientTotal)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: clientTotal > 0 ? tokens.successText : tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // MODE 2: SINGLE CLIENT QUICK ENTRY
  // =========================================================================
  Widget _buildSingleClientQuickEntryMode() {
    final tokens = IcareSurfaceTokens.of(context);
    final optsAsync = ref.watch(singleClientOptionsProvider);
    final selectedDate = ref.watch(effectiveCollectionsDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    return optsAsync.when(
      loading: () => const IcareFormSkeleton(fieldCount: 4),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.dangerBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.dangerBorder),
        ),
        child: Text(
          'Error loading clients: ${AppErrorDetails.from(err).message}',
          style: TextStyle(color: tokens.dangerText),
        ),
      ),
      data: (data) {
        final clients = (data['clients'] as List<dynamic>?) ?? [];
        if (clients.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Center(
              child: Text('No registered active clients found.', style: TextStyle(color: tokens.textMuted)),
            ),
          );
        }

        final Set<String> groupNames = {'All Groups'};
        for (final c in clients) {
          final g = c['group_name']?.toString().trim();
          if (g != null && g.isNotEmpty) {
            groupNames.add(g);
          } else {
            groupNames.add('Ungrouped');
          }
        }
        final sortedGroups = groupNames.toList()..sort((a, b) {
          if (a == 'All Groups') return -1;
          if (b == 'All Groups') return 1;
          return a.compareTo(b);
        });

        final filteredClients = clients.where((c) {
          final cgName = c['group_name']?.toString().trim() ?? '';
          if (_scSelectedGroupFilter != 'All Groups') {
            if (_scSelectedGroupFilter == 'Ungrouped') {
              if (cgName.isNotEmpty) return false;
            } else {
              if (cgName.toLowerCase() != _scSelectedGroupFilter.toLowerCase()) return false;
            }
          }
          if (_scSearchText.trim().isNotEmpty) {
            final query = _scSearchText.trim().toLowerCase();
            final name = (c['client_name']?.toString() ?? '').toLowerCase();
            final code = (c['client_code']?.toString() ?? '').toLowerCase();
            if (!name.contains(query) && !code.contains(query)) return false;
          }
          return true;
        }).toList();

        final dynamic selClient = filteredClients.isNotEmpty
            ? filteredClients.firstWhere(
                (c) => c['client_id']?.toString() == _scSelectedClientId,
                orElse: () => filteredClients.first,
              )
            : null;
        if (selClient != null) {
          _scSelectedClientId = selClient['client_id']?.toString();
        } else {
          _scSelectedClientId = null;
        }

        final isInGroup = selClient != null && selClient['is_in_group'] == true;
        final grpName = selClient != null ? (selClient['group_name']?.toString() ?? 'Ungrouped') : 'Ungrouped';
        final pSav = selClient != null ? ((selClient['personal_savings_balance'] as num?)?.toDouble() ?? 0.0) : 0.0;
        final gSav = selClient != null ? ((selClient['group_savings_balance'] as num?)?.toDouble() ?? 0.0) : 0.0;
        final loans = selClient != null ? ((selClient['loans'] as List<dynamic>?) ?? []) : [];

        Map<String, dynamic>? activeLoan;
        if (loans.isNotEmpty) {
          final found = loans.firstWhere(
            (l) => l['loan_id']?.toString() == _scSelectedLoanId,
            orElse: () => loans.first,
          );
          if (found is Map) {
            activeLoan = Map<String, dynamic>.from(found);
            _scSelectedLoanId = activeLoan['loan_id']?.toString();
          } else {
            _scSelectedLoanId = null;
          }
        } else {
          _scSelectedLoanId = null;
        }

        final remBal = activeLoan != null ? (activeLoan['remaining_balance'] as num?)?.toDouble() ?? 0.0 : 0.0;
        final expRep = activeLoan != null ? (activeLoan['expected_repayment'] as num?)?.toDouble() ?? 0.0 : 0.0;
        final scOverdueArrears = activeLoan != null ? (activeLoan['overdue_arrears'] as num?)?.toDouble() ?? 0.0 : 0.0;
        final scHasOverdue = activeLoan != null && (activeLoan['has_overdue'] == true || scOverdueArrears > 0);
        final scCurrentInstallment = activeLoan != null ? (activeLoan['current_installment'] as num?)?.toDouble() ?? expRep : 0.0;
        final prodName = activeLoan != null ? activeLoan['product']?.toString() ?? 'Loan' : 'No Active Loan';
        final scTodayRep = selClient != null ? ((selClient['today_repayment'] as num?)?.toDouble() ?? 0.0) : 0.0;
        final scTodaySav = selClient != null ? ((selClient['today_savings'] as num?)?.toDouble() ?? 0.0) : 0.0;
        final scTodayTot = selClient != null ? ((selClient['today_collected_total'] as num?)?.toDouble() ?? (scTodayRep + scTodaySav)) : 0.0;
        final scTodayStat = selClient != null ? (selClient['today_status']?.toString() ?? 'UNRECORDED') : 'UNRECORDED';
        final scIsRecordedToday = selClient != null && (selClient['today_collected'] == true || scTodayTot > 0 || scTodayStat == 'PAID' || scTodayStat == 'NOT_PAID');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Single Client Quick Entry',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary),
            ),
            const SizedBox(height: 16),

            // Search & Group Filter Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filter & Search Clients', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: tokens.textPrimary)),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final groupDropdown = DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: sortedGroups.contains(_scSelectedGroupFilter) ? _scSelectedGroupFilter : 'All Groups',
                        dropdownColor: tokens.surfaceElevated,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Solidarity Group',
                          filled: true,
                          fillColor: tokens.surfaceSubtle,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
                        ),
                        items: sortedGroups.map((g) => DropdownMenuItem(value: g, child: Text(g, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _scSelectedGroupFilter = val ?? 'All Groups';
                            _scSelectedClientId = null;
                            _scSelectedLoanId = null;
                            _scLoanRepCtrl.clear();
                          });
                        },
                      );

                      final searchBox = TextField(
                        controller: _scSearchCtrl,
                        style: TextStyle(color: tokens.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Search Client Name / Code',
                          hintText: 'e.g. Adebayo or CL-010',
                          filled: true,
                          fillColor: tokens.surfaceSubtle,
                          prefixIcon: Icon(Icons.search, size: 20, color: tokens.textMuted),
                          suffixIcon: _scSearchText.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 18, color: tokens.textMuted),
                                  onPressed: () {
                                    setState(() {
                                      _scSearchCtrl.clear();
                                      _scSearchText = '';
                                    });
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _scSearchText = val;
                          });
                        },
                      );

                      if (constraints.maxWidth < 600) {
                        return Column(
                          children: [
                            groupDropdown,
                            const SizedBox(height: 10),
                            searchBox,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: groupDropdown),
                          const SizedBox(width: 12),
                          Expanded(child: searchBox),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Text('Select Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                  const SizedBox(height: 6),
                  if (filteredClients.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tokens.dangerBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tokens.dangerBorder),
                      ),
                      child: Text(
                        'No matching clients found. Select "All Groups" or clear search.',
                        style: TextStyle(fontSize: 12.5, color: tokens.dangerText),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      dropdownColor: tokens.surfaceElevated,
                      value: filteredClients.any((c) => c['client_id']?.toString() == _scSelectedClientId)
                          ? _scSelectedClientId
                          : (filteredClients.isNotEmpty ? filteredClients.first['client_id']?.toString() : null),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: tokens.surfaceSubtle,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
                      ),
                      selectedItemBuilder: (BuildContext context) {
                        return filteredClients.map((c) {
                          final cid = c['client_id']?.toString() ?? '';
                          final ccode = c['client_code']?.toString() ?? cid;
                          final cname = c['client_name']?.toString() ?? '';
                          final cgname = c['group_name']?.toString() ?? 'Ungrouped';
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$cname ($ccode) — $cgname',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList();
                      },
                      items: filteredClients.map((c) {
                        final cid = c['client_id']?.toString() ?? '';
                        final ccode = c['client_code']?.toString() ?? cid;
                        final cname = c['client_name']?.toString() ?? '';
                        final cgname = c['group_name']?.toString() ?? 'Ungrouped';
                        final isDone = c['today_collected'] == true ||
                            ((c['today_collected_total'] as num?)?.toDouble() ?? 0.0) > 0 ||
                            c['today_status'] == 'PAID' ||
                            c['today_status'] == 'NOT_PAID';
                        return DropdownMenuItem(
                          value: cid,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$cname ($ccode) — Group: $cgname',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (isDone)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tokens.successBg,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: tokens.successBorder),
                                  ),
                                  child: Text(
                                    'Recorded Today',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tokens.successText),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _scSelectedClientId = val;
                          _scSelectedLoanId = null;
                          _scLoanRepCtrl.clear();
                        });
                      },
                    ),
                ],
              ),
            ),

            if (selClient == null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Center(
                  child: Text('No client selected. Choose a group or search client.', style: TextStyle(color: tokens.textMuted, fontWeight: FontWeight.w600)),
                ),
              ),
            ] else ...[
            const SizedBox(height: 16),

            // Client Overview Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final kpis = isInGroup
                    ? [
                        _buildSingleClientKpiCard('Group Name', grpName),
                        _buildSingleClientKpiCard('Personal Savings', CurrencyFormatter.formatNaira(pSav)),
                        _buildSingleClientKpiCard('Group Savings Fund', CurrencyFormatter.formatNaira(gSav)),
                        _buildSingleClientKpiCard('Outstanding Loan', activeLoan != null ? CurrencyFormatter.formatNaira(remBal) : 'No Active Loan'),
                      ]
                    : [
                        _buildSingleClientKpiCard('Membership', 'Individual (Ungrouped)'),
                        _buildSingleClientKpiCard('Personal Savings', CurrencyFormatter.formatNaira(pSav)),
                        _buildSingleClientKpiCard('Outstanding Loan', activeLoan != null ? CurrencyFormatter.formatNaira(remBal) : 'No Active Loan'),
                      ];

                if (constraints.maxWidth < 900) {
                  if (kpis.length == 4) {
                    return Column(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: kpis[0]),
                              const SizedBox(width: 10),
                              Expanded(child: kpis[1]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: kpis[2]),
                              const SizedBox(width: 10),
                              Expanded(child: kpis[3]),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: kpis[0]),
                              const SizedBox(width: 10),
                              Expanded(child: kpis[1]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: kpis[2]),
                      ],
                    );
                  }
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < kpis.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: kpis[i]),
                      ],
                    ],
                  ),
                );
              },
            ),

            // Today's Collection Status Banner
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: scIsRecordedToday
                    ? (scTodayStat == 'NOT_PAID' ? tokens.warningBg : tokens.successBg)
                    : tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: scIsRecordedToday
                      ? (scTodayStat == 'NOT_PAID' ? tokens.warningBorder : tokens.successBorder)
                      : tokens.borderSubtle,
                  width: scIsRecordedToday ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scIsRecordedToday
                          ? (scTodayStat == 'NOT_PAID' ? tokens.warningBg : tokens.successBg)
                          : tokens.neutralBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scIsRecordedToday
                            ? (scTodayStat == 'NOT_PAID' ? tokens.warningBorder : tokens.successBorder)
                            : tokens.borderSubtle,
                      ),
                    ),
                    child: Icon(
                      scIsRecordedToday
                          ? (scTodayStat == 'NOT_PAID' ? Icons.info_outline : Icons.check_circle_outline)
                          : Icons.schedule,
                      size: 18,
                      color: scIsRecordedToday
                          ? (scTodayStat == 'NOT_PAID' ? tokens.warningDot : tokens.successDot)
                          : tokens.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              scIsRecordedToday
                                  ? (scTodayStat == 'NOT_PAID'
                                      ? 'MARKED UNPAID TODAY ($dateStr)'
                                      : 'RECORDED TODAY ($dateStr)')
                                  : 'NOT YET RECORDED TODAY ($dateStr)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: scIsRecordedToday
                                    ? (scTodayStat == 'NOT_PAID' ? tokens.warningText : tokens.successText)
                                    : tokens.textSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const Spacer(),
                            if (scIsRecordedToday && scTodayStat != 'NOT_PAID')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tokens.brandPrimaryDark,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  CurrencyFormatter.formatNaira(scTodayTot),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          scIsRecordedToday
                              ? (scTodayStat == 'NOT_PAID'
                                  ? 'Client attendance logged with ₦0 payment. Overdue tracked in arrears.'
                                  : 'Loan Repayment: ${CurrencyFormatter.formatNaira(scTodayRep)} · Personal Savings: ${CurrencyFormatter.formatNaira(scTodaySav)} · Confirmed to Primary Vault Cash.')
                              : (expRep > 0
                                  ? (scHasOverdue
                                      ? 'Total Due Today: ${CurrencyFormatter.formatNaira(expRep)} (Installment: ${CurrencyFormatter.formatNaira(scCurrentInstallment)} + Overdue Arrears: ${CurrencyFormatter.formatNaira(scOverdueArrears)}).'
                                      : 'Expected loan repayment for this meeting cycle: ${CurrencyFormatter.formatNaira(expRep)}.')
                                  : 'No scheduled installment due today. You may record savings deposit or custom repayment below.'),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scIsRecordedToday
                                ? (scTodayStat == 'NOT_PAID' ? tokens.warningText : tokens.successText)
                                : (scHasOverdue ? tokens.warningText : tokens.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Form Inputs Container (app.py L5347)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Loan Selector if multiple loans
                  if (loans.length > 1) ...[
                    Text('Select Active Loan to Repay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _scSelectedLoanId,
                      dropdownColor: tokens.surfaceElevated,
                      style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: tokens.surfaceSubtle,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
                      ),
                      items: loans.map((l) {
                        return DropdownMenuItem<String>(
                          value: l['loan_id']?.toString(),
                          child: Text(l['label']?.toString() ?? 'Loan', style: TextStyle(fontSize: 13, color: tokens.textPrimary), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _scSelectedLoanId = val),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Delinquency Toggle (Mark as NOT PAID)
                  if (activeLoan != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _scMarkNotPaid ? tokens.dangerBg : tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _scMarkNotPaid ? tokens.dangerBorder : tokens.borderSubtle,
                          width: _scMarkNotPaid ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _scMarkNotPaid,
                            activeColor: tokens.dangerDot,
                            onChanged: (val) {
                              setState(() {
                                _scMarkNotPaid = val ?? false;
                                if (_scMarkNotPaid) {
                                  _scLoanRepCtrl.text = '0';
                                } else {
                                  _scLoanRepCtrl.clear();
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mark as NOT PAID today (₦0 Collection)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _scMarkNotPaid ? tokens.dangerText : tokens.textPrimary,
                                  ),
                                ),
                                if (_scMarkNotPaid) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Recorded ₦0 delinquency • Overdue Arrears: ${CurrencyFormatter.formatNaira(expRep)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.dangerText,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Core Inputs: Personal Savings, Group Savings, Loan Repayment
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final personalSavDeco = InputDecoration(
                        filled: true,
                        fillColor: tokens.surfaceSubtle,
                        labelText: 'Personal Savings Deposit (₦)',
                        labelStyle: TextStyle(color: tokens.textMuted),
                        hintText: '0',
                        hintStyle: TextStyle(color: tokens.textMuted),
                        border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                      );
                      final groupSavDeco = InputDecoration(
                        filled: true,
                        fillColor: tokens.surfaceSubtle,
                        labelText: 'Group Savings Deposit (₦)',
                        labelStyle: TextStyle(color: tokens.textMuted),
                        hintText: '0',
                        hintStyle: TextStyle(color: tokens.textMuted),
                        border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                      );
                      final loanEnabled = activeLoan != null && !_scMarkNotPaid;
                      final loanRepDeco = InputDecoration(
                        filled: true,
                        fillColor: loanEnabled ? tokens.surfaceSubtle : tokens.surfaceElevated,
                        labelText: activeLoan != null ? 'Loan Repayment ($prodName) (₦)' : 'No Active Loan (₦0)',
                        labelStyle: TextStyle(color: tokens.textMuted),
                        hintText: activeLoan != null ? 'Expected: ${CurrencyFormatter.formatNaira(expRep)}' : '0',
                        hintStyle: TextStyle(color: tokens.textMuted),
                        border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                        disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderSubtle)),
                      );

                      if (constraints.maxWidth < 600) {
                        return Column(
                          children: [
                            TextField(
                              controller: _scPersonalSavCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: tokens.textPrimary),
                              decoration: personalSavDeco,
                            ),
                            if (isInGroup) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _scGroupSavCtrl,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: tokens.textPrimary),
                                decoration: groupSavDeco,
                              ),
                            ],
                            const SizedBox(height: 12),
                            _buildSingleClientFastEntryPills(expRep, remBal),
                            TextField(
                              controller: _scLoanRepCtrl,
                              enabled: loanEnabled,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: loanEnabled ? tokens.textPrimary : tokens.textMuted),
                              decoration: loanRepDeco,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _scPersonalSavCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: tokens.textPrimary),
                              decoration: personalSavDeco,
                            ),
                          ),
                          if (isInGroup) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _scGroupSavCtrl,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: tokens.textPrimary),
                                decoration: groupSavDeco,
                              ),
                            ),
                          ],
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSingleClientFastEntryPills(expRep, remBal),
                                TextField(
                                  controller: _scLoanRepCtrl,
                                  enabled: loanEnabled,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: loanEnabled ? tokens.textPrimary : tokens.textMuted),
                                  decoration: loanRepDeco,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Additional Fees Expander (app.py L5367)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      iconColor: tokens.textMuted,
                      collapsedIconColor: tokens.textMuted,
                      title: Text('Additional Fees (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            InputDecoration feeDeco(String label) => InputDecoration(
                                  filled: true,
                                  fillColor: tokens.surfaceSubtle,
                                  labelText: label,
                                  labelStyle: TextStyle(color: tokens.textMuted),
                                  prefixText: '₦ ',
                                  prefixStyle: TextStyle(color: tokens.textSecondary),
                                  hintText: '0',
                                  hintStyle: TextStyle(color: tokens.textMuted),
                                  border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                                );

                            if (constraints.maxWidth < 600) {
                              return Column(
                                children: [
                                  TextField(
                                    controller: _scAppFeeCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: tokens.textPrimary),
                                    decoration: feeDeco('App Fee (₦)'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _scPbFeeCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: tokens.textPrimary),
                                    decoration: feeDeco('Pass Book (₦)'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _scMiscFeeCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: tokens.textPrimary),
                                    decoration: feeDeco('Misc Fee (₦)'),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _scAppFeeCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: tokens.textPrimary),
                                    decoration: feeDeco('App Fee (₦)'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _scPbFeeCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: tokens.textPrimary),
                                    decoration: feeDeco('Pass Book (₦)'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _scMiscFeeCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: tokens.textPrimary),
                                    decoration: feeDeco('Misc Fee (₦)'),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                  // Transaction Note Input
                  TextField(
                    controller: _scNoteCtrl,
                    style: TextStyle(color: tokens.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: tokens.surfaceSubtle,
                      labelText: 'Transaction Note / Remarks',
                      labelStyle: TextStyle(color: tokens.textMuted),
                      border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Submit Button (app.py L5375)
                  SizedBox(
                    width: double.infinity,
                    height: 46,

                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : () => _submitSingleClient(selClient, dateStr, expRep),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimaryDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Post Client Transaction', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

  Widget _buildSingleClientKpiCard(String label, String value, {Color? accentColor}) {
    final tokens = IcareSurfaceTokens.of(context);
    IconData effectiveIcon = Icons.analytics_outlined;
    Color effectiveColor = accentColor ?? tokens.brandPrimary;
    if (label.contains('Group Name') || label.contains('Membership')) {
      effectiveIcon = Icons.groups_rounded;
      effectiveColor = tokens.brandAccent;
    } else if (label.contains('Personal Savings')) {
      effectiveIcon = Icons.account_balance_wallet_rounded;
      effectiveColor = tokens.brandPrimary;
    } else if (label.contains('Group Savings Fund')) {
      effectiveIcon = Icons.savings_rounded;
      effectiveColor = tokens.infoDot;
    } else if (label.contains('Outstanding Loan')) {
      effectiveIcon = Icons.pending_actions_rounded;
      effectiveColor = value.contains('No Active') ? tokens.textMuted : tokens.warningDot;
    }

    final isLoanOutstanding = label.contains('Outstanding Loan') && !value.contains('No Active');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: tokens.isDark
            ? null
            : const [
                BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: tokens.isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(effectiveIcon, size: 14, color: effectiveColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: tokens.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isLoanOutstanding ? tokens.dangerText : tokens.textPrimary,
                fontFamily: value.contains('₦') ? 'monospace' : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleClientFastEntryPills(double expRep, double remBal) {
    if (_scMarkNotPaid || (expRep <= 0 && remBal <= 0)) {
      return const SizedBox.shrink();
    }
    final tokens = IcareSurfaceTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (expRep > 0)
            InkWell(
              onTap: () {
                setState(() {
                  _scLoanRepCtrl.text = expRep.toStringAsFixed(0);
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: tokens.brandSoftBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.brandSoftBorder),
                ),
                child: Text(
                  'Expected: ₦${expRep.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.brandSoftText),
                ),
              ),
            ),
          if (expRep > 0)
            InkWell(
              onTap: () {
                setState(() {
                  _scLoanRepCtrl.text = (expRep / 2).toStringAsFixed(0);
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: tokens.successBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.successBorder),
                ),
                child: Text(
                  'Half: ₦${(expRep / 2).toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.successText),
                ),
              ),
            ),
          if (remBal > 0)
            InkWell(
              onTap: () {
                setState(() {
                  _scLoanRepCtrl.text = remBal.toStringAsFixed(0);
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: tokens.infoBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.infoBorder),
                ),
                child: Text(
                  'Payoff: ₦${remBal.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.infoText),
                ),
              ),
            ),
          InkWell(
            onTap: () {
              setState(() {
                _scLoanRepCtrl.clear();
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.borderStrong),
              ),
              child: Text(
                'Clear',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: COLLECTION HISTORY & AUDIT (app.py L6382–6978)
  // =========================================================================
  Widget _buildTab2HistoryAndAudit() {
    final tokens = IcareSurfaceTokens.of(context);
    final DateTime effHistDate = _histDate ?? ref.watch(effectiveCollectionsDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(effHistDate);
    final search = _histSearchCtrl.text.trim();
    final histAsync = ref.watch(collectionsHistoryProvider((dateStr: dateStr, search: search, officer: _histOfficer)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collection History & Audit',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tokens.textPrimary, letterSpacing: -0.3),
        ),
        const SizedBox(height: 3),
        Text(
          'Audit posted repayments and savings.',
          style: TextStyle(fontSize: 13, color: tokens.textMuted),
        ),
        const SizedBox(height: 16),

        // Filter Controls: Filter Date & Search (app.py L6387-6398)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.borderSubtle),
            boxShadow: tokens.isDark
                ? null
                : const [
                    BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
                  ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final datePicker = InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: effHistDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: effHistDate.isAfter(DateTime.now()) ? effHistDate : DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _histDate = picked;
                      _histClientPage = 1;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderStrong),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 15, color: tokens.textSecondary),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd MMM yyyy').format(effHistDate), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 16, color: tokens.textMuted),
                    ],
                  ),
                ),
              );

              final searchField = TextField(
                controller: _histSearchCtrl,
                style: TextStyle(color: tokens.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search Client Name / Code / Group / Ref...',
                  hintStyle: TextStyle(color: tokens.textMuted),
                  prefixIcon: Icon(Icons.search, size: 18, color: tokens.textMuted),
                  filled: true,
                  fillColor: tokens.surfaceSubtle,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.brandPrimary, width: 1.5)),
                ),
                onChanged: (_) => setState(() => _histClientPage = 1),
                onSubmitted: (_) => setState(() => _histClientPage = 1),
              );

              final officerFilter = SizedBox(
                width: isMobile ? double.infinity : 190,
                child: DropdownButtonFormField<String>(
                  value: _histAvailableOfficers.contains(_histOfficer) ? _histOfficer : 'All Officers',
                  isExpanded: true,
                  dropdownColor: tokens.surfaceElevated,
                  decoration: InputDecoration(
                    labelText: 'Officer',
                    labelStyle: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    filled: true,
                    fillColor: tokens.surfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                  items: _histAvailableOfficers
                      .map((o) => DropdownMenuItem<String>(
                            value: o,
                            child: Text(o, style: TextStyle(color: tokens.textPrimary), overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _histOfficer = val;
                        _histClientPage = 1;
                      });
                    }
                  },
                ),
              );

              final refreshBtn = Container(
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(Icons.refresh, color: tokens.textSecondary, size: 20),
                  tooltip: 'Refresh History',
                  onPressed: () => ref.invalidate(collectionsHistoryProvider),
                ),
              );

              if (isMobile) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: datePicker),
                        const SizedBox(width: 8),
                        refreshBtn,
                      ],
                    ),
                    const SizedBox(height: 10),
                    searchField,
                    if (_histAvailableOfficers.length > 1) ...[
                      const SizedBox(height: 10),
                      officerFilter,
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  datePicker,
                  const SizedBox(width: 12),
                  Expanded(child: searchField),
                  if (_histAvailableOfficers.length > 1) ...[
                    const SizedBox(width: 10),
                    officerFilter,
                  ],
                  const SizedBox(width: 10),
                  refreshBtn,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        histAsync.when(
          loading: () => const IcareTableSkeleton(rowCount: 6, hasFilterBar: false),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: tokens.dangerBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: tokens.dangerBorder)),
            child: Text('Error loading history: ${AppErrorDetails.from(err).message}', style: TextStyle(color: tokens.dangerText, fontWeight: FontWeight.w600)),
          ),
          data: (hData) {
            final rawOfficers = (hData['available_officers'] as List<dynamic>?)
                    ?.map((e) => e.toString().trim())
                    .where((e) => e.isNotEmpty)
                    .toList() ??
                <String>[];
            final nextOfficers = <String>[
              'All Officers',
              ...rawOfficers.where((o) => o != 'All Officers'),
            ];
            if (!nextOfficers.contains(_histOfficer)) {
              nextOfficers.add(_histOfficer);
            }
            if (nextOfficers.length != _histAvailableOfficers.length ||
                !List.generate(nextOfficers.length, (i) => nextOfficers[i] == _histAvailableOfficers[i]).every((e) => e)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _histAvailableOfficers = nextOfficers);
                }
              });
            }
            final totReps = (hData['total_repayments'] as num?)?.toDouble() ?? 0.0;
            final paidCnt = hData['paid_repayments_count'] ?? 0;
            final notPaidCnt = hData['not_paid_repayments_count'] ?? 0;
            final totSav = (hData['total_savings'] as num?)?.toDouble() ?? 0.0;
            final savCnt = hData['savings_deposits_count'] ?? 0;
            final grandTotal = (hData['grand_total_cash'] as num?)?.toDouble() ?? 0.0;
            final groups = (hData['groups'] as List<dynamic>?) ?? [];
            final repayments = (hData['repayments'] as List<dynamic>?) ?? [];
            final savings = (hData['savings'] as List<dynamic>?) ?? [];
            final reversals = (hData['reversed_records'] as List<dynamic>?) ?? [];
            final eodSummary = hData['eod_summary'] as Map<String, dynamic>? ?? {};
            final eodLog = (hData['eod_log'] as List<dynamic>?) ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top 4 Metric Summary Cards (Unified summary - eliminates duplicate metrics)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final k1 = _buildHistoryKpiCard('Total Repayments', CurrencyFormatter.formatNaira(totReps), '$paidCnt Paid • $notPaidCnt Arrears', accentColor: tokens.brandPrimary, icon: Icons.assignment_turned_in_outlined);
                    final k2 = _buildHistoryKpiCard('Total Savings', CurrencyFormatter.formatNaira(totSav), '$savCnt Deposits', accentColor: tokens.infoDot, icon: Icons.savings_outlined);
                    final k3 = _buildHistoryKpiCard('Grand Total Inflow', CurrencyFormatter.formatNaira(grandTotal), 'Total Cash Collected', isGrand: true, accentColor: tokens.brandPrimary, icon: Icons.payments_outlined);
                    final k4 = _buildHistoryKpiCard('Active Groups', '${groups.length} ${groups.length == 1 ? 'Group' : 'Groups'}', '${repayments.length + savings.length} Total Txns', accentColor: tokens.brandAccent, icon: Icons.groups_outlined);
                    if (constraints.maxWidth < 600) {
                      return Column(
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: k1),
                                const SizedBox(width: 10),
                                Expanded(child: k2),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: k3),
                                const SizedBox(width: 10),
                                Expanded(child: k4),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else if (constraints.maxWidth < 900) {
                      return Column(
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: k1),
                                const SizedBox(width: 12),
                                Expanded(child: k2),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: k3),
                                const SizedBox(width: 12),
                                Expanded(child: k4),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: k1),
                          const SizedBox(width: 12),
                          Expanded(child: k2),
                          const SizedBox(width: 12),
                          Expanded(child: k3),
                          const SizedBox(width: 12),
                          Expanded(child: k4),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Group Summary Section (if groups exist)
                if (groups.isNotEmpty) ...[
                  _buildGroupSummarySection(groups, repayments.length, savings.length),
                  const SizedBox(height: 20),
                ],

                // Unified Client Collections Ledger (repayment and savings in one row)
                _buildUnifiedClientCollectionsTable(repayments, savings, dateStr),
                const SizedBox(height: 20),

                // EOD Summary Section & Historical Log
                _buildEodSummarySection(eodSummary, eodLog, dateStr),

                // Audit Expander: Reversed Records on this Date (app.py L6947-6978)
                if (reversals.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: Container(
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tokens.dangerBorder),
                      ),
                      child: ExpansionTile(
                        iconColor: tokens.dangerText,
                        collapsedIconColor: tokens.dangerText,
                        title: Text(
                          'Reversed Records on this Date (Audit Trail: ${reversals.length})',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.dangerText),
                        ),
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 680),
                              child: Table(
                                border: TableBorder.all(color: tokens.borderSubtle),
                                columnWidths: const {
                                  0: FlexColumnWidth(1.2),
                                  1: FlexColumnWidth(2),
                                  2: FlexColumnWidth(1.2),
                                  3: FlexColumnWidth(1),
                                  4: FlexColumnWidth(1.2),
                                  5: FlexColumnWidth(2.5),
                                },
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(color: tokens.dangerBg),
                                    children: [
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.dangerText))),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text('Client', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.dangerText))),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.dangerText))),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.dangerText))),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text('Ref ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.dangerText))),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text('Note / Reason', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.dangerText))),
                                    ],
                                  ),
                                  ...reversals.map((rev) {
                                    return TableRow(
                                      children: [
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text(rev['type'] ?? '', style: TextStyle(fontSize: 11, color: tokens.textPrimary))),
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text(rev['client'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textPrimary))),
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text(CurrencyFormatter.formatNaira((rev['amount'] as num?)?.toDouble() ?? 0), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary))),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: tokens.dangerBg, borderRadius: BorderRadius.circular(4)),
                                            child: Text('Reversed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tokens.dangerText), textAlign: TextAlign.center),
                                          ),
                                        ),
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text((rev['ref_id'] ?? '').toString(), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textSecondary))),
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text(rev['reason'] ?? rev['note'] ?? '', style: TextStyle(fontSize: 11, color: tokens.textSecondary))),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoryKpiCard(String label, String value, String subtitle, {bool isGrand = false, Color? accentColor, IconData? icon}) {
    final tokens = IcareSurfaceTokens.of(context);
    final effectiveColor = accentColor ?? (isGrand ? tokens.brandPrimary : tokens.infoDot);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isGrand ? tokens.brandSoftBg : tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isGrand ? tokens.brandSoftBorder : tokens.borderSubtle,
          width: 1,
        ),
        boxShadow: tokens.isDark
            ? null
            : const [
                BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 1)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: isGrand ? tokens.brandSoftText : tokens.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: tokens.isDark ? 0.18 : 0.08),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(icon, size: 14, color: effectiveColor),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isGrand ? tokens.brandSoftText : tokens.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isGrand ? tokens.brandPrimary : tokens.textMuted,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSummarySection(List<dynamic> groups, int repCount, int savCount) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: tokens.isDark
            ? null
            : const [
                BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tokens.infoBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.workspaces_outlined, size: 16, color: tokens.infoDot),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Group Breakdown (${groups.length})',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${groups.fold<int>(0, (acc, g) => acc + ((g['paying_members_count'] as num?)?.toInt() ?? 0))} Paying Clients',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              if (isMobile) {
                return Column(
                  children: groups.map((g) {
                    final gName = g['group_name'] ?? 'Unnamed Group';
                    final totRep = (g['total_repayment'] as num?)?.toDouble() ?? 0.0;
                    final memSav = (g['member_savings'] as num?)?.toDouble() ?? 0.0;
                    final grpSav = (g['group_savings'] as num?)?.toDouble() ?? 0.0;
                    final totSav = (g['total_savings'] as num?)?.toDouble() ?? 0.0;
                    final grpTotal = (g['grand_total'] as num?)?.toDouble() ?? 0.0;
                    final payingCnt = g['paying_members_count'] ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  gName,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tokens.successBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$payingCnt Clients',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tokens.successText),
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 16, color: tokens.borderSubtle),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Loan Repayment', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.formatNaira(totRep),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: tokens.brandPrimary),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Savings', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.formatNaira(totSav),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: tokens.infoText),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Mem: ${CurrencyFormatter.formatNaira(memSav)} • Grp: ${CurrencyFormatter.formatNaira(grpSav)}',
                                style: TextStyle(fontSize: 10, color: tokens.textMuted),
                              ),
                              Text(
                                'Total: ${CurrencyFormatter.formatNaira(grpTotal)}',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: tokens.textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth > 780 ? constraints.maxWidth : 780),
                  child: Table(
                    border: TableBorder.all(color: tokens.borderSubtle),
                    columnWidths: const {
                      0: FlexColumnWidth(2.2),
                      1: FlexColumnWidth(1.6),
                      2: FlexColumnWidth(1.4),
                      3: FlexColumnWidth(1.4),
                      4: FlexColumnWidth(1.4),
                      5: FlexColumnWidth(1.8),
                      6: FlexColumnWidth(1.3),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: tokens.surfaceSubtle),
                        children: [
                          Padding(padding: const EdgeInsets.all(10), child: Text('Group Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                          Padding(padding: const EdgeInsets.all(10), child: Text('Total Repayment (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                          Padding(padding: const EdgeInsets.all(10), child: Text('Member Savings (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                          Padding(padding: const EdgeInsets.all(10), child: Text('Group Savings (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                          Padding(padding: const EdgeInsets.all(10), child: Text('Total Savings (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                          Padding(padding: const EdgeInsets.all(10), child: Text('Grand Total Collected (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                          Padding(padding: const EdgeInsets.all(10), child: Text('Paying Members', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                        ],
                      ),
                      ...groups.map((g) {
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(10), child: Text(g['group_name'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary))),
                            Padding(padding: const EdgeInsets.all(10), child: Text(CurrencyFormatter.formatNaira((g['total_repayment'] as num?)?.toDouble() ?? 0), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary))),
                            Padding(padding: const EdgeInsets.all(10), child: Text(CurrencyFormatter.formatNaira((g['member_savings'] as num?)?.toDouble() ?? 0), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary))),
                            Padding(padding: const EdgeInsets.all(10), child: Text(CurrencyFormatter.formatNaira((g['group_savings'] as num?)?.toDouble() ?? 0), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary))),
                            Padding(padding: const EdgeInsets.all(10), child: Text(CurrencyFormatter.formatNaira((g['total_savings'] as num?)?.toDouble() ?? 0), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary))),
                            Padding(padding: const EdgeInsets.all(10), child: Text(CurrencyFormatter.formatNaira((g['grand_total'] as num?)?.toDouble() ?? 0), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: tokens.textPrimary))),
                            Padding(padding: const EdgeInsets.all(10), child: Text('${g['paying_members_count'] ?? 0} Clients', style: TextStyle(fontSize: 11, color: tokens.textSecondary))),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedClientCollectionsTable(List<dynamic> repayments, List<dynamic> savings, String dateStr) {
    final tokens = IcareSurfaceTokens.of(context);
    final Map<String, Map<String, dynamic>> clientMap = {};

    for (final r in repayments) {
      final cid = (r['client_id'] ?? r['client_code'] ?? r['client_name'] ?? '').toString();
      if (cid.isEmpty) continue;
      final cname = r['client_name']?.toString() ?? 'Client';
      final ccode = r['client_code']?.toString() ?? cid;
      final gname = r['group_name']?.toString() ?? '-';
      final prod = r['product']?.toString() ?? '-';
      final exp = (r['expected_amount'] ?? r['expected'] as num?)?.toDouble() ?? 0.0;
      final paid = (r['amount_paid'] as num?)?.toDouble() ?? 0.0;
      final stat = (r['status'] ?? (paid > 0 ? 'PAID' : 'NOT PAID')).toString();
      final rawRepTime = r['time']?.toString() ?? '';
      final time = (rawRepTime == '00:00' || rawRepTime == '0:00' || rawRepTime == '—') ? '' : rawRepTime;
      final off = r['officer']?.toString() ?? '';
      final note = r['note']?.toString() ?? '';
      final refId = (r['ref_id'] ?? '').toString();
      if (!clientMap.containsKey(cid)) {
        clientMap[cid] = {
          'client_id': cid,
          'client_name': cname,
          'client_code': ccode,
          'group_name': gname,
          'product': prod,
          'expected_repayment': exp,
          'repayment_paid': paid,
          'repayment_status': stat,
          'savings_deposited': 0.0,
          'time': time,
          'officer': off,
          'note': note,
          'ref_id': refId,
        };
      } else {
        final entry = clientMap[cid]!;
        entry['expected_repayment'] = (entry['expected_repayment'] as double) + exp;
        entry['repayment_paid'] = (entry['repayment_paid'] as double) + paid;
        if (entry['product'] == '-' && prod != '-') entry['product'] = prod;
        if (entry['group_name'] == '-' && gname != '-') entry['group_name'] = gname;
        if (entry['repayment_status'] == 'NOT PAID' && paid > 0) entry['repayment_status'] = stat;
        final currTime = entry['time'] as String? ?? '';
        if (time.isNotEmpty && (currTime.isEmpty || currTime == '00:00' || currTime == '0:00' || currTime == '—')) {
          entry['time'] = time;
        }
        if (off.isNotEmpty && (entry['officer'] as String).isEmpty) entry['officer'] = off;
      }
    }

    for (final s in savings) {
      final cid = (s['client_id'] ?? s['client_code'] ?? s['client_name'] ?? '').toString();
      if (cid.isEmpty) continue;
      final cname = s['client_name']?.toString() ?? 'Client';
      final ccode = s['client_code']?.toString() ?? cid;
      final gname = s['group_name']?.toString() ?? '-';
      final savAmt = (s['deposit_amount'] as num?)?.toDouble() ?? 0.0;
      final rawSavTime = s['time']?.toString() ?? '';
      final time = (rawSavTime == '00:00' || rawSavTime == '0:00' || rawSavTime == '—') ? '' : rawSavTime;
      final off = s['officer']?.toString() ?? '';
      final note = s['remarks']?.toString() ?? '';
      final refId = (s['ref_id'] ?? '').toString();
      if (!clientMap.containsKey(cid)) {
        clientMap[cid] = {
          'client_id': cid,
          'client_name': cname,
          'client_code': ccode,
          'group_name': gname,
          'product': '-',
          'expected_repayment': 0.0,
          'repayment_paid': 0.0,
          'repayment_status': '-',
          'savings_deposited': savAmt,
          'time': time,
          'officer': off,
          'note': note,
          'ref_id': refId,
        };
      } else {
        final entry = clientMap[cid]!;
        entry['savings_deposited'] = (entry['savings_deposited'] as double) + savAmt;
        if (entry['group_name'] == '-' && gname != '-') entry['group_name'] = gname;
        final currTime = entry['time'] as String? ?? '';
        if (time.isNotEmpty && (currTime.isEmpty || currTime == '00:00' || currTime == '0:00' || currTime == '—')) {
          entry['time'] = time;
        }
        if (off.isNotEmpty && (entry['officer'] as String).isEmpty) entry['officer'] = off;
      }
    }

    final allList = clientMap.values.toList();
    final search = _histSearchCtrl.text.trim().toLowerCase();

    // Counts for filter chips
    final totalCount = allList.length;
    final paidCount = allList.where((c) {
      final rep = (c['repayment_paid'] as num?)?.toDouble() ?? 0.0;
      final stat = (c['repayment_status'] ?? '').toString().toUpperCase();
      return rep > 0 || stat == 'PAID';
    }).length;
    final arrearsCount = allList.where((c) {
      final stat = (c['repayment_status'] ?? '').toString().toUpperCase();
      final exp = (c['expected_repayment'] as num?)?.toDouble() ?? 0.0;
      final rep = (c['repayment_paid'] as num?)?.toDouble() ?? 0.0;
      return stat == 'NOT PAID' || (exp > 0 && rep < exp);
    }).length;
    final savingsCount = allList.where((c) {
      final sav = (c['savings_deposited'] as num?)?.toDouble() ?? 0.0;
      return sav > 0;
    }).length;

    // Filter by search text
    var filteredList = allList;
    if (search.isNotEmpty) {
      filteredList = filteredList.where((c) {
        final cname = (c['client_name'] ?? '').toString().toLowerCase();
        final ccode = (c['client_code'] ?? '').toString().toLowerCase();
        final gname = (c['group_name'] ?? '').toString().toLowerCase();
        final note = (c['note'] ?? '').toString().toLowerCase();
        final refId = (c['ref_id'] ?? '').toString().toLowerCase();
        return cname.contains(search) || ccode.contains(search) || gname.contains(search) || note.contains(search) || refId.contains(search);
      }).toList();
    }

    // Filter by status chip
    if (_histStatusFilter == 'PAID') {
      filteredList = filteredList.where((c) {
        final rep = (c['repayment_paid'] as num?)?.toDouble() ?? 0.0;
        final stat = (c['repayment_status'] ?? '').toString().toUpperCase();
        return rep > 0 || stat == 'PAID';
      }).toList();
    } else if (_histStatusFilter == 'ARREARS') {
      filteredList = filteredList.where((c) {
        final stat = (c['repayment_status'] ?? '').toString().toUpperCase();
        final exp = (c['expected_repayment'] as num?)?.toDouble() ?? 0.0;
        final rep = (c['repayment_paid'] as num?)?.toDouble() ?? 0.0;
        return stat == 'NOT PAID' || (exp > 0 && rep < exp);
      }).toList();
    } else if (_histStatusFilter == 'SAVINGS') {
      filteredList = filteredList.where((c) {
        final sav = (c['savings_deposited'] as num?)?.toDouble() ?? 0.0;
        return sav > 0;
      }).toList();
    }

    // Pagination calculations (limits long scrolling to 10 clients per page)
    final totalFiltered = filteredList.length;
    final totalPages = totalFiltered == 0 ? 1 : ((totalFiltered - 1) ~/ _histPageSize) + 1;
    if (_histClientPage > totalPages) _histClientPage = totalPages;
    if (_histClientPage < 1) _histClientPage = 1;
    final startIndex = (totalFiltered == 0) ? 0 : (_histClientPage - 1) * _histPageSize;
    final endIndex = (startIndex + _histPageSize).clamp(0, totalFiltered);
    final pageItems = (totalFiltered == 0) ? <Map<String, dynamic>>[] : filteredList.sublist(startIndex, endIndex);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: tokens.isDark
            ? null
            : const [
                BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Client Collection & Savings Ledger', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tokens.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Client Collections & Savings • $totalCount Records', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildHistFilterChip('ALL', 'All ($totalCount)'),
                const SizedBox(width: 8),
                _buildHistFilterChip('PAID', 'Paid ($paidCount)'),
                const SizedBox(width: 8),
                _buildHistFilterChip('ARREARS', 'Arrears ($arrearsCount)'),
                const SizedBox(width: 8),
                _buildHistFilterChip('SAVINGS', 'Savings ($savingsCount)'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Data Body: Empty vs Mobile Cards vs Desktop Table
          if (filteredList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: tokens.surfaceSubtle, borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: Text('No client repayments or savings deposits match this filter.', style: TextStyle(color: tokens.textMuted, fontSize: 13)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                if (isMobile) {
                  return Column(
                    children: pageItems.map((c) => _buildMobileClientHistoryCard(c)).toList(),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth > 920 ? constraints.maxWidth : 920),
                    child: Table(
                      border: TableBorder.all(color: tokens.borderSubtle),
                      columnWidths: const {
                        0: FlexColumnWidth(2.2), // Client
                        1: FlexColumnWidth(1.4), // Group
                        2: FlexColumnWidth(1.2), // Product
                        3: FlexColumnWidth(1.4), // Expected
                        4: FlexColumnWidth(1.4), // Rep Paid
                        5: FlexColumnWidth(1.1), // Status
                        6: FlexColumnWidth(1.4), // Savings
                        7: FlexColumnWidth(1.5), // Total
                        8: FlexColumnWidth(1.6), // Officer / Time
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: tokens.surfaceSubtle),
                          children: [
                            Padding(padding: const EdgeInsets.all(10), child: Text('Client Name (Code)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                            Padding(padding: const EdgeInsets.all(10), child: Text('Group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                            Padding(padding: const EdgeInsets.all(10), child: Text('Product', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                            Padding(padding: const EdgeInsets.all(10), child: Text('Expected Rep. (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                            Padding(padding: const EdgeInsets.all(10), child: Text('Loan Repayment (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                            Padding(padding: const EdgeInsets.all(10), child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                            Padding(padding: const EdgeInsets.all(10), child: Text('Savings Deposit (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                            Padding(padding: const EdgeInsets.all(10), child: Text('Total Cash (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                            Padding(padding: const EdgeInsets.all(10), child: Text('Officer / Time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                          ],
                        ),
                        ...pageItems.map((c) {
                          final cname = c['client_name']?.toString() ?? '';
                          final ccode = c['client_code']?.toString() ?? '';
                          final gname = c['group_name']?.toString() ?? '-';
                          final prod = c['product']?.toString() ?? '-';
                          final exp = (c['expected_repayment'] as num?)?.toDouble() ?? 0.0;
                          final repPaid = (c['repayment_paid'] as num?)?.toDouble() ?? 0.0;
                          final stat = c['repayment_status']?.toString() ?? '-';
                          final savPaid = (c['savings_deposited'] as num?)?.toDouble() ?? 0.0;
                          final totalCash = repPaid + savPaid;
                          final off = c['officer']?.toString() ?? '';
                          final time = c['time']?.toString() ?? '';

                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cname, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(ccode, style: TextStyle(fontSize: 10.5, color: tokens.textMuted)),
                                  ],
                                ),
                              ),
                              Padding(padding: const EdgeInsets.all(10), child: Text(gname, style: TextStyle(fontSize: 11, color: tokens.textSecondary))),
                              Padding(padding: const EdgeInsets.all(10), child: Text(prod, style: TextStyle(fontSize: 11, color: tokens.textSecondary))),
                              Padding(padding: const EdgeInsets.all(10), child: Text(exp > 0 ? CurrencyFormatter.formatNaira(exp) : '—', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary))),
                              Padding(padding: const EdgeInsets.all(10), child: Text(repPaid > 0 ? CurrencyFormatter.formatNaira(repPaid) : '—', style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: repPaid > 0 ? tokens.textPrimary : tokens.textMuted))),
                              Padding(padding: const EdgeInsets.all(10), child: _buildStatusBadge(stat)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(savPaid > 0 ? CurrencyFormatter.formatNaira(savPaid) : '—', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: savPaid > 0 ? tokens.brandPrimary : tokens.textMuted, fontWeight: FontWeight.w600))),
                              Padding(padding: const EdgeInsets.all(10), child: Text(totalCash > 0 ? CurrencyFormatter.formatNaira(totalCash) : '—', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: totalCash > 0 ? tokens.textPrimary : tokens.textMuted))),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (off.isNotEmpty) Text(off, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                                    if (time.isNotEmpty && time != '00:00' && time != '0:00')
                                      Text(time, style: TextStyle(fontSize: 10, color: tokens.textMuted))
                                    else
                                      Text('—', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Pagination Bar (Eliminates long scrolling)
          if (totalFiltered > 0)
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.borderSubtle, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${startIndex + 1}–$endIndex of $totalFiltered',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tokens.textMuted),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _histClientPage > 1
                            ? () => setState(() => _histClientPage--)
                            : null,
                        icon: const Icon(Icons.chevron_left, size: 16),
                        label: const Text('Prev', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.textSecondary,
                          side: BorderSide(color: tokens.borderStrong),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '$_histClientPage / $totalPages',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _histClientPage < totalPages
                            ? () => setState(() => _histClientPage++)
                            : null,
                        icon: const Icon(Icons.chevron_right, size: 16),
                        label: const Text('Next', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.textSecondary,
                          side: BorderSide(color: tokens.borderStrong),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistFilterChip(String filterKey, String label) {
    final tokens = IcareSurfaceTokens.of(context);
    final isSelected = _histStatusFilter == filterKey;
    return InkWell(
      onTap: () {
        setState(() {
          _histStatusFilter = filterKey;
          _histClientPage = 1;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? tokens.brandSoftBg : tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? tokens.brandPrimary : tokens.borderStrong,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? tokens.brandSoftText : tokens.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileClientHistoryCard(Map<String, dynamic> c) {
    final tokens = IcareSurfaceTokens.of(context);
    final cname = c['client_name']?.toString() ?? '';
    final ccode = c['client_code']?.toString() ?? '';
    final gname = c['group_name']?.toString() ?? '-';
    final prod = c['product']?.toString() ?? '-';
    final exp = (c['expected_repayment'] as num?)?.toDouble() ?? 0.0;
    final repPaid = (c['repayment_paid'] as num?)?.toDouble() ?? 0.0;
    final stat = c['repayment_status']?.toString() ?? '-';
    final savPaid = (c['savings_deposited'] as num?)?.toDouble() ?? 0.0;
    final totalCash = repPaid + savPaid;
    final off = c['officer']?.toString() ?? '';
    final time = c['time']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cname,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$ccode • $gname${prod != '-' ? ' • $prod' : ''}',
                      style: TextStyle(fontSize: 11, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(stat),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Loan Repaid', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
                    const SizedBox(height: 1),
                    Text(
                      repPaid > 0 ? CurrencyFormatter.formatNaira(repPaid) : '—',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: repPaid > 0 ? tokens.brandPrimary : tokens.textMuted,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Savings Deposit', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
                    const SizedBox(height: 1),
                    Text(
                      savPaid > 0 ? CurrencyFormatter.formatNaira(savPaid) : '—',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: savPaid > 0 ? tokens.infoText : tokens.textMuted,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total Cash', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                    const SizedBox(height: 1),
                    Text(
                      totalCash > 0 ? CurrencyFormatter.formatNaira(totalCash) : '—',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        color: totalCash > 0 ? tokens.textPrimary : tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (exp > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Expected Repayment: ${CurrencyFormatter.formatNaira(exp)}',
              style: TextStyle(fontSize: 10.5, color: tokens.textMuted),
            ),
          ],
          if (off.isNotEmpty || (time.isNotEmpty && time != '00:00' && time != '0:00')) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (off.isNotEmpty)
                  Text('Officer: $off', style: TextStyle(fontSize: 10.5, color: tokens.textMuted, fontWeight: FontWeight.w500))
                else
                  const SizedBox.shrink(),
                if (time.isNotEmpty && time != '00:00' && time != '0:00')
                  Text(time, style: TextStyle(fontSize: 10.5, color: tokens.textMuted, fontFamily: 'monospace'))
                else
                  const SizedBox.shrink(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEodSummarySection(Map<String, dynamic> eodSummary, List<dynamic> eodLog, String dateStr) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.borderSubtle)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('End of Day (EOD) Inputs & Fee Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tokens.textPrimary)),
          const SizedBox(height: 4),
          Text('Daily cash inputs & auxiliary fees for $dateStr', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final itemWidth = isMobile
                  ? ((constraints.maxWidth - 10) / 2).floorToDouble()
                  : (constraints.maxWidth >= 900
                      ? ((constraints.maxWidth - 36) / 4).floorToDouble()
                      : ((constraints.maxWidth - 24) / 3).floorToDouble());
              return Wrap(
                spacing: isMobile ? 10 : 12,
                runSpacing: 10,
                children: [
                  _buildEodMetricItem('B/F Opening Cash', eodSummary['opening_cash'], width: itemWidth),
                  _buildEodMetricItem('Bank Deposited', eodSummary['bank_deposit'], width: itemWidth),
                  _buildEodMetricItem('Office Expenses', eodSummary['office_expenses'], width: itemWidth),
                  _buildEodMetricItem('Credit Form / App Fee', eodSummary['app_fee'], width: itemWidth),
                  _buildEodMetricItem('Passbook Fees', eodSummary['passbook'], width: itemWidth),
                  _buildEodMetricItem('Misc Fees', eodSummary['misc_fees'], width: itemWidth),
                  _buildEodMetricItem('Credit Form Damage', eodSummary['form_damage'], width: itemWidth),
                  _buildEodMetricItem('Staff Bonus', eodSummary['bonus'], width: itemWidth),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Container(
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: ExpansionTile(
                iconColor: tokens.textMuted,
                collapsedIconColor: tokens.textMuted,
                title: Text('Daily EOD Inputs History Log', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                children: [
                  if (eodLog.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No historical EOD inputs found for this filter.', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 960),
                        child: Table(
                          border: TableBorder.all(color: tokens.borderSubtle),
                          columnWidths: const {
                            0: FlexColumnWidth(1.2),
                            1: FlexColumnWidth(1.8),
                            2: FlexColumnWidth(1.2),
                            3: FlexColumnWidth(1.2),
                            4: FlexColumnWidth(1.2),
                            5: FlexColumnWidth(1.1),
                            6: FlexColumnWidth(1.1),
                            7: FlexColumnWidth(1.1),
                            8: FlexColumnWidth(1.2),
                            9: FlexColumnWidth(1.1),
                            10: FlexColumnWidth(1.3),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: tokens.surfaceElevated),
                              children: [
                                Padding(padding: const EdgeInsets.all(8), child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                                Padding(padding: const EdgeInsets.all(8), child: Text('Officer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                                Padding(padding: const EdgeInsets.all(8), child: Text('B/F Cash', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                                Padding(padding: const EdgeInsets.all(8), child: Text('Bank Deposit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                                Padding(padding: const EdgeInsets.all(8), child: Text('Expenses', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                                Padding(padding: const EdgeInsets.all(8), child: Text('App Fee', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                                Padding(padding: const EdgeInsets.all(8), child: Text('Passbook', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                                Padding(padding: const EdgeInsets.all(8), child: Text('Misc Fees', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                                Padding(padding: const EdgeInsets.all(8), child: Text('Form Damage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                                Padding(padding: const EdgeInsets.all(8), child: Text('Bonus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                                Padding(padding: const EdgeInsets.all(8), child: Text('Closing Cash', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),
                              ],
                            ),
                            ...eodLog.map((log) {
                              final bf = (log['B/F Cash'] as num?)?.toDouble() ?? 0.0;
                              final bd = (log['Bank Deposit'] as num?)?.toDouble() ?? 0.0;
                              final exp = (log['Expenses'] as num?)?.toDouble() ?? 0.0;
                              final appF = (log['App Fee'] as num?)?.toDouble() ?? 0.0;
                              final pb = (log['Passbook'] as num?)?.toDouble() ?? 0.0;
                              final misc = (log['Misc Fees'] as num?)?.toDouble() ?? 0.0;
                              final fd = (log['Form Damage'] as num?)?.toDouble() ?? 0.0;
                              final bon = (log['Bonus'] as num?)?.toDouble() ?? 0.0;
                              final cc = (log['Closing Cash'] as num?)?.toDouble() ?? 0.0;
                              return TableRow(
                                children: [
                                  Padding(padding: const EdgeInsets.all(8), child: Text(log['Date']?.toString() ?? '', style: TextStyle(fontSize: 11, color: tokens.textPrimary))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(log['Officer']?.toString() ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textPrimary))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(bf), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(bd), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(exp), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(appF), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(pb), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(misc), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(fd), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(bon), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(cc), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: tokens.textPrimary))),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEodMetricItem(String label, dynamic val, {double? width}) {
    final tokens = IcareSurfaceTokens.of(context);
    final dVal = (val as num?)?.toDouble() ?? 0.0;
    return Container(
      width: width ?? 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: tokens.surfaceSubtle, borderRadius: BorderRadius.circular(6), border: Border.all(color: tokens.borderSubtle)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: tokens.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.formatNaira(dVal),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: tokens.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final tokens = IcareSurfaceTokens.of(context);
    final clean = status.replaceAll('_', ' ').trim().toUpperCase();
    Color bg = tokens.successBg;
    Color fg = tokens.successText;
    if (clean == 'NOT PAID') {
      bg = tokens.dangerBg;
      fg = tokens.dangerText;
    } else if (clean == 'PART PAID') {
      bg = tokens.warningBg;
      fg = tokens.warningText;
    } else if (clean == 'EXCESS') {
      bg = tokens.infoBg;
      fg = tokens.infoText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        clean.isEmpty ? 'PAID' : clean,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
        textAlign: TextAlign.center,
      ),
    );
  }

  // =========================================================================

  // TAB 3: ERROR CORRECTION & REVERSAL HUB (app.py L6980–7259)

  // =========================================================================

  Widget _buildTab3ErrorCorrection() {

    final tokens = IcareSurfaceTokens.of(context);

    final DateTime effRevDate = _revDate ?? ref.watch(effectiveCollectionsDateProvider);

    final dateStr = DateFormat('yyyy-MM-dd').format(effRevDate);

    final search = _revSearchCtrl.text.trim();

    final revOptsAsync = ref.watch(reversalOptionsProvider((category: _revCategory, dateStr: dateStr, allRecent: _revAllRecent, search: search)));

    final revReqsAsync = ref.watch(reversalRequestsProvider);

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        // Title & Description

        Text(

          'Error Correction & Reversal Hub',

          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tokens.textPrimary, letterSpacing: -0.3),

        ),

        const SizedBox(height: 3),

        Text(

          'Flag erroneous collections for review.',

          style: TextStyle(fontSize: 13, color: tokens.textMuted),

        ),

        const SizedBox(height: 16),

        // 1. Category & Date Filter Bar (app.py L6987-7000)

        Container(

          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(

            color: tokens.surfaceElevated,

            borderRadius: BorderRadius.circular(12),

            border: Border.all(color: tokens.borderSubtle),

            boxShadow: [

              BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.18 : 0.03), blurRadius: 6, offset: const Offset(0, 2)),

            ],

          ),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text('Transaction Category:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),

              const SizedBox(height: 8),

              Wrap(

                spacing: 10,

                runSpacing: 8,

                children: [

                  _buildReversalCategoryButton('Loan Repayments', Icons.assignment_return_outlined),

                  _buildReversalCategoryButton('Savings Deposits', Icons.savings_outlined),

                  _buildReversalCategoryButton('Savings Withdrawals', Icons.account_balance_wallet_outlined),

                ],

              ),

              const SizedBox(height: 16),

              Divider(height: 1, color: tokens.borderSubtle),

              const SizedBox(height: 14),

              LayoutBuilder(

                builder: (context, constraints) {

                  final isMobile = constraints.maxWidth < 650;

                  final datePicker = InkWell(

                    onTap: () async {

                      final picked = await showDatePicker(

                        context: context,

                        initialDate: effRevDate,

                        firstDate: DateTime.now().subtract(const Duration(days: 365)),

                        lastDate: effRevDate.isAfter(DateTime.now()) ? effRevDate : DateTime.now(),

                      );

                      if (picked != null) {

                        setState(() {

                          _revDate = picked;

                          _selectedReversalRefId = null;

                        });

                      }

                    },

                    borderRadius: BorderRadius.circular(8),

                    child: Container(

                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                      decoration: BoxDecoration(

                        color: tokens.surfaceSubtle,

                        borderRadius: BorderRadius.circular(8),

                        border: Border.all(color: tokens.borderStrong),

                      ),

                      child: Row(

                        mainAxisSize: MainAxisSize.min,

                        children: [

                          Icon(Icons.calendar_today_outlined, size: 15, color: tokens.textSecondary),

                          const SizedBox(width: 8),

                          Text(DateFormat('dd MMM yyyy').format(effRevDate), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary)),

                          const SizedBox(width: 4),

                          Icon(Icons.arrow_drop_down, size: 16, color: tokens.textMuted),

                        ],

                      ),

                    ),

                  );

                  final searchField = TextField(

                    controller: _revSearchCtrl,

                    style: TextStyle(color: tokens.textPrimary),

                    decoration: InputDecoration(

                      hintText: 'Filter by Client Name / Code / Ref...',

                      hintStyle: TextStyle(color: tokens.textMuted),

                      prefixIcon: Icon(Icons.search, size: 18, color: tokens.textMuted),

                      filled: true,

                      fillColor: tokens.surfaceSubtle,

                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),

                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),

                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.brandPrimary, width: 1.5)),

                    ),

                    onSubmitted: (_) => setState(() => _selectedReversalRefId = null),

                  );

                  final allRecentCheckbox = InkWell(

                    onTap: () {

                      setState(() {

                        _revAllRecent = !_revAllRecent;

                        _selectedReversalRefId = null;

                      });

                    },

                    borderRadius: BorderRadius.circular(6),

                    child: Container(

                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

                      decoration: BoxDecoration(

                        color: _revAllRecent ? tokens.successBg : tokens.surfaceSubtle,

                        borderRadius: BorderRadius.circular(8),

                        border: Border.all(color: _revAllRecent ? tokens.successBorder : tokens.borderSubtle),

                      ),

                      child: Row(

                        mainAxisSize: MainAxisSize.min,

                        children: [

                          Icon(

                            _revAllRecent ? Icons.check_box : Icons.check_box_outline_blank,

                            size: 18,

                            color: _revAllRecent ? tokens.successDot : tokens.textMuted,

                          ),

                          const SizedBox(width: 6),

                          Text(

                            'All Recent (14 Days)',

                            style: TextStyle(

                              fontSize: 12,

                              fontWeight: FontWeight.w600,

                              color: _revAllRecent ? tokens.successText : tokens.textSecondary,

                            ),

                          ),

                        ],

                      ),

                    ),

                  );

                  if (isMobile) {

                    return Column(

                      crossAxisAlignment: CrossAxisAlignment.stretch,

                      children: [

                        Row(

                          children: [

                            Expanded(child: datePicker),

                            const SizedBox(width: 8),

                            allRecentCheckbox,

                          ],

                        ),

                        const SizedBox(height: 10),

                        searchField,

                      ],

                    );

                  }

                  return Row(

                    children: [

                      datePicker,

                      const SizedBox(width: 12),

                      Expanded(child: searchField),

                      const SizedBox(width: 12),

                      allRecentCheckbox,

                    ],

                  );

                },

              ),

            ],

          ),

        ),

        const SizedBox(height: 16),

        // 2. Options Dropdown & Details Card (app.py L7187-7225)

        revOptsAsync.when(

          loading: () => const IcareTableSkeleton(rowCount: 4, hasFilterBar: false),

          error: (err, _) => Container(

            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              color: tokens.dangerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.dangerBorder),
            ),

            child: Text('Error loading options: ${AppErrorDetails.from(err).message}', style: TextStyle(color: tokens.dangerText)),

          ),

          data: (optData) {

            final items = (optData['items'] as List<dynamic>?) ?? [];

            if (items.isEmpty) {

              final dateLbl = _revAllRecent ? 'all recent dates (last 14 days)' : dateStr;

              return Container(

                width: double.infinity,

                padding: const EdgeInsets.all(28),

                decoration: BoxDecoration(

                  color: tokens.surfaceElevated,

                  borderRadius: BorderRadius.circular(12),

                  border: Border.all(color: tokens.borderSubtle),

                ),

                child: Center(

                  child: Column(

                    children: [

                      Icon(Icons.search_off_outlined, size: 36, color: tokens.textMuted),

                      const SizedBox(height: 8),

                      Text(

                        'No ${_revCategory.toLowerCase()} found for $dateLbl matching your criteria.',

                        textAlign: TextAlign.center,

                        style: TextStyle(color: tokens.textMuted, fontSize: 13, fontWeight: FontWeight.w600),

                      ),

                    ],

                  ),

                ),

              );

            }

            final selItem = items.firstWhere(

              (it) => it['ref_id']?.toString() == _selectedReversalRefId,

              orElse: () => items.first,

            );

            _selectedReversalRefId = selItem['ref_id']?.toString();

            return Container(

              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(

                color: tokens.surfaceElevated,

                borderRadius: BorderRadius.circular(12),

                border: Border.all(color: tokens.borderSubtle),

                boxShadow: [

                  BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.18 : 0.03), blurRadius: 6, offset: const Offset(0, 2)),

                ],

              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Row(

                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [

                      Text(

                        'Select Record to Flag (${items.length} Available)',

                        style: TextStyle(fontSize: 13, color: tokens.textPrimary, fontWeight: FontWeight.w700),

                      ),

                      Container(

                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),

                        decoration: BoxDecoration(color: tokens.dangerBg, borderRadius: BorderRadius.circular(4), border: Border.all(color: tokens.dangerBorder)),

                        child: Text('Reversal Request', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.dangerText)),

                      ),

                    ],

                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(

                    isExpanded: true,

                    initialValue: _selectedReversalRefId,

                    dropdownColor: tokens.surfaceElevated,

                    decoration: InputDecoration(

                      filled: true,

                      fillColor: tokens.surfaceSubtle,

                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),

                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),

                    ),

                    selectedItemBuilder: (BuildContext context) {

                      return items.map((it) {

                        return Align(

                          alignment: Alignment.centerLeft,

                          child: Text(

                            it['label']?.toString() ?? 'Tx',

                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),

                            overflow: TextOverflow.ellipsis,

                            maxLines: 1,

                          ),

                        );

                      }).toList();

                    },

                    items: items.map((it) {

                      return DropdownMenuItem<String>(

                        value: it['ref_id']?.toString(),

                        child: Text(

                          it['label']?.toString() ?? 'Tx',

                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),

                          overflow: TextOverflow.ellipsis,

                          maxLines: 1,

                        ),

                      );

                    }).toList(),

                    onChanged: (val) => setState(() => _selectedReversalRefId = val),

                  ),

                  const SizedBox(height: 16),

                  // Selected Transaction Details Card

                  Container(

                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(

                      color: tokens.surfaceSubtle,

                      borderRadius: BorderRadius.circular(10),

                      border: Border.all(color: tokens.borderSubtle),

                    ),

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Row(

                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [

                            Text('Selected Transaction Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: tokens.textPrimary)),

                            Container(

                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

                              decoration: BoxDecoration(color: tokens.neutralBg, borderRadius: BorderRadius.circular(4)),

                              child: Text(selItem['category'] ?? _revCategory, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.neutralText)),

                            ),

                          ],

                        ),

                        const SizedBox(height: 12),

                        LayoutBuilder(

                          builder: (context, constraints) {

                            final isMobile = constraints.maxWidth < 500;

                            final kpi1 = _buildReversalDetailKpi('Amount', CurrencyFormatter.formatNaira((selItem['amount'] as num?)?.toDouble() ?? 0), isAmount: true);

                            final kpi2 = _buildReversalDetailKpi('Client Code', selItem['client_code']?.toString() ?? '—');

                            final kpi3 = _buildReversalDetailKpi('Date', selItem['date']?.toString() ?? '—');

                            if (isMobile) {

                              return Column(

                                children: [

                                  Row(

                                    children: [

                                      Expanded(child: kpi1),

                                      const SizedBox(width: 8),

                                      Expanded(child: kpi2),

                                    ],

                                  ),

                                  const SizedBox(height: 8),

                                  kpi3,

                                ],

                              );

                            }

                            return Row(

                              children: [

                                Expanded(child: kpi1),

                                const SizedBox(width: 10),

                                Expanded(child: kpi2),

                                const SizedBox(width: 10),

                                Expanded(child: kpi3),

                              ],

                            );

                          },

                        ),

                        const SizedBox(height: 12),

                        Text(

                          'Client Name: ${selItem['client_name'] ?? 'Unknown'}',

                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textPrimary),

                        ),

                        const SizedBox(height: 4),

                        Row(

                          children: [

                            Expanded(

                              child: Text(

                                'Full Ref ID: ${selItem['ref_id']} • Note: ${selItem['note'] ?? '—'}',

                                style: TextStyle(fontSize: 11, color: tokens.textMuted, fontFamily: 'monospace'),

                                overflow: TextOverflow.ellipsis,

                              ),

                            ),

                            InkWell(

                              onTap: () {

                                final refId = selItem['ref_id']?.toString() ?? '';

                                if (refId.isNotEmpty) {

                                  Clipboard.setData(ClipboardData(text: refId));

                                  ScaffoldMessenger.of(context).showSnackBar(

                                    const SnackBar(content: Text('Reference ID copied!'), duration: Duration(seconds: 1)),

                                  );

                                }

                              },

                              child: Icon(Icons.copy, size: 14, color: tokens.textMuted),

                            ),

                          ],

                        ),

                      ],

                    ),

                  ),

                  const SizedBox(height: 16),

                  // Reason Input

                  TextField(

                    controller: _revReasonCtrl,

                    style: TextStyle(color: tokens.textPrimary),

                    decoration: InputDecoration(

                      filled: true,

                      fillColor: tokens.surfaceSubtle,

                      labelText: 'Reason for Reversal *',

                      labelStyle: TextStyle(color: tokens.textMuted),

                      hintText: 'e.g., Wrong payment entered. Entered 50,000 instead of 5,000.',

                      hintStyle: TextStyle(color: tokens.textMuted),

                      prefixIcon: Icon(Icons.edit_note, size: 20, color: tokens.textMuted),

                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),

                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),

                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.brandPrimary, width: 1.5)),

                    ),

                  ),

                  const SizedBox(height: 16),

                  // Submit Button

                  SizedBox(

                    width: double.infinity,

                    height: 46,

                    child: ElevatedButton.icon(

                      onPressed: _isSubmitting ? null : _submitReversalRequest,

                      icon: _isSubmitting

                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))

                          : const Icon(Icons.report_problem_outlined, size: 18),

                      style: ElevatedButton.styleFrom(

                        backgroundColor: const Color(0xFFDC2626),

                        foregroundColor: Colors.white,

                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

                        elevation: 1,

                      ),

                      label: Text(

                        _isSubmitting ? 'Submitting Request...' : 'Submit Reversal Request to BM',

                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),

                      ),

                    ),

                  ),

                ],

              ),

            );

          },

        ),

        const SizedBox(height: 24),

        // 3. Submitted Reversal Requests History Table (app.py L7229-7258)

        Row(

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            Text(

              'Submitted Reversal Requests',

              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary),

            ),

            IconButton(

              icon: Icon(Icons.refresh, size: 18, color: tokens.textMuted),

              tooltip: 'Refresh Reversals',

              onPressed: () => ref.invalidate(reversalRequestsProvider),

            ),

          ],

        ),

        const SizedBox(height: 10),

        revReqsAsync.when(

          loading: () => const IcareTableSkeleton(rowCount: 3, hasFilterBar: false),

          error: (err, _) => Container(

            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(color: tokens.dangerBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: tokens.dangerBorder)),

            child: Text('Error loading requests: ${AppErrorDetails.from(err).message}', style: TextStyle(color: tokens.dangerText)),

          ),

          data: (reqData) {

            final requests = (reqData['requests'] as List<dynamic>?) ?? [];

            if (requests.isEmpty) {

              return Container(

                width: double.infinity,

                padding: const EdgeInsets.all(28),

                decoration: BoxDecoration(color: tokens.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: tokens.borderSubtle)),

                child: Center(

                  child: Text('You have not submitted any reversal requests yet.', style: TextStyle(color: tokens.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),

                ),

              );

            }

            return Container(

              decoration: BoxDecoration(

                color: tokens.surfaceElevated,

                borderRadius: BorderRadius.circular(12),

                border: Border.all(color: tokens.borderSubtle),

                boxShadow: [

                  BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.18 : 0.03), blurRadius: 6, offset: const Offset(0, 2)),

                ],

              ),

              child: SingleChildScrollView(

                scrollDirection: Axis.horizontal,

                child: ConstrainedBox(

                  constraints: const BoxConstraints(minWidth: 700),

                  child: Table(

                    columnWidths: const {

                      0: FlexColumnWidth(1.4),

                      1: FlexColumnWidth(1.2),

                      2: FlexColumnWidth(1.2),

                      3: FlexColumnWidth(2.8),

                      4: FlexColumnWidth(1.2),

                      5: FlexColumnWidth(1.4),

                    },

                    children: [

                      TableRow(

                        decoration: BoxDecoration(color: tokens.surfaceSubtle),

                        children: [

                          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textSecondary))),

                          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textSecondary))),

                          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Text('Record Ref', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textSecondary))),

                          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Text('Reason', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textSecondary))),

                          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textSecondary))),

                          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Text('Reviewed By', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textSecondary))),

                        ],

                      ),

                      ...requests.map((r) {

                        final stat = r['status']?.toString() ?? 'Pending';

                        Color statBg = tokens.warningBg;

                        Color statFg = tokens.warningText;

                        Color statBorder = tokens.warningBorder;

                        if (stat == 'Approved') {

                          statBg = tokens.successBg;

                          statFg = tokens.successText;

                          statBorder = tokens.successBorder;

                        } else if (stat == 'Rejected') {

                          statBg = tokens.dangerBg;

                          statFg = tokens.dangerText;

                          statBorder = tokens.dangerBorder;

                        }

                        return TableRow(

                          decoration: BoxDecoration(

                            border: Border(top: BorderSide(color: tokens.borderSubtle)),

                          ),

                          children: [

                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(r['date'] ?? '', style: TextStyle(fontSize: 11.5, color: tokens.textPrimary))),

                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(r['record_type'] ?? '', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textSecondary))),

                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(r['record_ref'] ?? '', style: TextStyle(fontSize: 11.5, color: tokens.textPrimary, fontFamily: 'monospace'))),

                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(r['reason'] ?? '', style: TextStyle(fontSize: 11.5, color: tokens.textPrimary), softWrap: true)),

                            Padding(

                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                              child: Container(

                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

                                decoration: BoxDecoration(color: statBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: statBorder)),

                                child: Text(stat, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statFg), textAlign: TextAlign.center),

                              ),

                            ),

                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(r['approved_by'] ?? '—', style: TextStyle(fontSize: 11.5, color: tokens.textMuted))),

                          ],

                        );

                      }),

                    ],

                  ),

                ),

              ),

            );

          },

        ),

      ],

    );

  }

  Widget _buildReversalCategoryButton(String title, IconData icon) {

    final tokens = IcareSurfaceTokens.of(context);

    final isSel = _revCategory == title;

    final selectedBg = tokens.isDark ? tokens.brandPrimaryDark : tokens.brandPrimary;

    return InkWell(

      onTap: () => setState(() {

        _revCategory = title;

        _selectedReversalRefId = null;

      }),

      borderRadius: BorderRadius.circular(8),

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 150),

        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

        decoration: BoxDecoration(

          color: isSel ? selectedBg : tokens.surfaceSubtle,

          borderRadius: BorderRadius.circular(8),

          border: Border.all(

            color: isSel ? selectedBg : tokens.borderSubtle,

            width: 1.2,

          ),

        ),

        child: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            Icon(icon, size: 15, color: isSel ? Colors.white : tokens.textMuted),

            const SizedBox(width: 6),

            Text(

              title,

              style: TextStyle(

                fontSize: 12.5,

                fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,

                color: isSel ? Colors.white : tokens.textSecondary,

              ),

            ),

          ],

        ),

      ),

    );

  }

  Widget _buildReversalDetailKpi(String label, String val, {bool isAmount = false}) {

    final tokens = IcareSurfaceTokens.of(context);

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(

        color: tokens.surfaceElevated,

        borderRadius: BorderRadius.circular(8),

        border: Border(

          top: BorderSide(color: isAmount ? tokens.dangerDot : tokens.borderStrong, width: 2.5),

          left: BorderSide(color: tokens.borderSubtle),

          right: BorderSide(color: tokens.borderSubtle),

          bottom: BorderSide(color: tokens.borderSubtle),

        ),

        boxShadow: [

          BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.02), blurRadius: 3, offset: const Offset(0, 1)),

        ],

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(label, style: TextStyle(fontSize: 10, color: tokens.textMuted, fontWeight: FontWeight.w600)),

          const SizedBox(height: 2),

          FittedBox(

            fit: BoxFit.scaleDown,

            alignment: Alignment.centerLeft,

            child: Text(

              val,

              maxLines: 1,

              softWrap: false,

              style: TextStyle(

                fontSize: 13,

                fontWeight: FontWeight.w800,

                color: isAmount ? tokens.dangerText : tokens.textPrimary,

                fontFamily: 'monospace',

                fontFeatures: const [FontFeature.tabularFigures()],

              ),

            ),

          ),

        ],

      ),

    );

  }

}

// =========================================================================

// ANIMATED COLLECTION CONFIRMATION, LIVE POSTING & SUCCESS MODAL

// =========================================================================

enum _ModalStage { confirmation, posting, success, error }

class _CollectionFlowModal extends StatefulWidget {

  final String groupName;

  final String dateStr;

  final bool isOpen;

  final String openReason;

  final bool isLateEntry;

  final List<Map<String, dynamic>> stagedTransactions;

  final double grpSavings;

  final bool isOnline;

  final Future<Map<String, dynamic>> Function() onConfirmPost;

  final VoidCallback onDismissAndReset;

  final VoidCallback onViewHistory;

  const _CollectionFlowModal({

    required this.groupName,

    required this.dateStr,

    required this.isOpen,

    required this.openReason,

    required this.isLateEntry,

    required this.stagedTransactions,

    required this.grpSavings,

    required this.isOnline,

    required this.onConfirmPost,

    required this.onDismissAndReset,

    required this.onViewHistory,

  });

  @override

  State<_CollectionFlowModal> createState() => _CollectionFlowModalState();

}

class _CollectionFlowModalState extends State<_CollectionFlowModal> {

  _ModalStage _phase = _ModalStage.confirmation;

  Map<String, dynamic>? _receiptData;

  String? _errorMessage;

  int _postingStep = 0;

  Timer? _stepTimer;

  bool _itemizedExpanded = true;

  bool _whatsappExpanded = false;

  @override

  void dispose() {

    _stepTimer?.cancel();

    super.dispose();

  }

  Future<void> _startPosting() async {

    HapticFeedback.mediumImpact();

    setState(() {

      _phase = _ModalStage.posting;

      _postingStep = 0;

      _errorMessage = null;

    });

    _stepTimer?.cancel();

    _stepTimer = Timer.periodic(const Duration(milliseconds: 750), (t) {

      if (mounted && _phase == _ModalStage.posting) {

        setState(() {

          _postingStep = (_postingStep + 1) % 3;

        });

      }

    });

    try {

      final res = await widget.onConfirmPost();

      _stepTimer?.cancel();

      if (mounted) {

        setState(() {

          _receiptData = res['receipt'] as Map<String, dynamic>?;

          _phase = _ModalStage.success;

        });

        HapticFeedback.heavyImpact();

      }

    } catch (e) {

      _stepTimer?.cancel();

      if (mounted) {

        String cleanMessage = 'An error occurred while posting collections to the ledger.';
        if (e is DioException) {
          final resData = e.response?.data;
          if (resData is Map) {
            if (resData['message'] != null && resData['message'].toString().trim().isNotEmpty) {
              cleanMessage = resData['message'].toString();
            } else if (resData['detail'] != null && resData['detail'].toString().trim().isNotEmpty) {
              cleanMessage = resData['detail'].toString();
            }
          } else if (e.response?.statusCode == 403) {
            cleanMessage = 'Operational Restriction: Branch collections are closed for this date. Enable Late Entry or select an open working day.';
          } else if (e.response?.statusCode == 409) {
            cleanMessage = 'Lock Conflict: A transaction with this reference is currently being processed. Please wait a moment and check history.';
          } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
            cleanMessage = 'Network Connection Interrupted: The batch could not reach the server. You can queue this transaction offline.';
          }
        } else {
          cleanMessage = AppErrorDetails.from(e).message;
        }

        setState(() {

          _errorMessage = cleanMessage;

          _phase = _ModalStage.error;

        });

        HapticFeedback.vibrate();

      }

    }

  }

  @override

  Widget build(BuildContext context) {

    final tokens = IcareSurfaceTokens.of(context);

    final media = MediaQuery.of(context);

    final isMobile = media.size.width < 600;

    final maxDialogWidth = isMobile ? double.infinity : 720.0;

    final maxDialogHeight = media.size.height * (isMobile ? 0.94 : 0.88);

    return Dialog(

      backgroundColor: Colors.transparent,

      elevation: 0,

      insetPadding: EdgeInsets.symmetric(

        horizontal: isMobile ? 12 : 24,

        vertical: isMobile ? 12 : 24,

      ),

      child: Center(

        child: ConstrainedBox(

          constraints: BoxConstraints(

            maxWidth: maxDialogWidth,

            maxHeight: maxDialogHeight,

          ),

          child: Container(

            decoration: BoxDecoration(

              color: tokens.surface,

              borderRadius: BorderRadius.circular(isMobile ? 16 : 18),

              border: Border.all(color: tokens.borderSubtle),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withValues(alpha: tokens.isDark ? 0.45 : 0.15),

                  blurRadius: 28,

                  offset: const Offset(0, 10),

                ),

              ],

            ),

            child: ClipRRect(

              borderRadius: BorderRadius.circular(isMobile ? 16 : 18),

              child: Column(

                children: [

                  _buildHeader(context, isMobile),

                  Divider(height: 1, color: tokens.borderSubtle),

                  Expanded(

                    child: AnimatedSwitcher(

                      duration: const Duration(milliseconds: 320),

                      switchInCurve: Curves.easeOutCubic,

                      switchOutCurve: Curves.easeInCubic,

                      transitionBuilder: (child, anim) {

                        return FadeTransition(

                          opacity: anim,

                          child: ScaleTransition(

                            scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim),

                            child: child,

                          ),

                        );

                      },

                      child: switch (_phase) {

                        _ModalStage.confirmation => _buildConfirmationView(isMobile),

                        _ModalStage.posting => _buildPostingView(isMobile),

                        _ModalStage.success => _buildSuccessView(isMobile),

                        _ModalStage.error => _buildErrorView(isMobile),

                      },

                    ),

                  ),

                ],

              ),

            ),

          ),

        ),

      ),

    );

  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final isOfflineQueued = _receiptData?['is_offline_queued'] == true ||
        _receiptData?['offline_queued'] == true ||
        _receiptData?['status'] == 'QUEUED_LOCAL' ||
        _receiptData?['watermark'] != null;

    final title = switch (_phase) {

      _ModalStage.confirmation => 'Review Group Collections',

      _ModalStage.posting => 'Posting Collections to Ledger',

      _ModalStage.success => isOfflineQueued ? 'Collection Queued Offline' : 'Collection Confirmed',

      _ModalStage.error => 'Posting Interrupted',

    };

    final subtitle = switch (_phase) {

      _ModalStage.confirmation => 'Verify all collection entries for ${widget.groupName} before final ledger commitment.',

      _ModalStage.posting => 'Atomic double-entry transactions committing in real time.',

      _ModalStage.success => isOfflineQueued
          ? 'Saved to device outbox for automatic synchronization when back online.'
          : 'All entries successfully committed to Primary Vault Cash.',

      _ModalStage.error => 'Ledger communication encountered an issue.',

    };

    final iconData = switch (_phase) {

      _ModalStage.confirmation => Icons.fact_check_outlined,

      _ModalStage.posting => Icons.sync,

      _ModalStage.success => isOfflineQueued ? Icons.cloud_upload_outlined : Icons.check_circle_outline,

      _ModalStage.error => Icons.error_outline,

    };

    final iconBg = switch (_phase) {

      _ModalStage.confirmation => tokens.infoBg,

      _ModalStage.posting => tokens.successBg,

      _ModalStage.success => isOfflineQueued ? tokens.warningBg : tokens.successBg,

      _ModalStage.error => tokens.dangerBg,

    };

    final iconColor = switch (_phase) {

      _ModalStage.confirmation => tokens.infoText,

      _ModalStage.posting => tokens.successDot,

      _ModalStage.success => isOfflineQueued ? tokens.warningDot : tokens.successDot,

      _ModalStage.error => tokens.dangerDot,

    };

    return Container(

      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 14),

      color: tokens.surface,

      child: Row(

        children: [

          Container(

            padding: const EdgeInsets.all(8),

            decoration: BoxDecoration(

              color: iconBg,

              borderRadius: BorderRadius.circular(10),

            ),

            child: Icon(iconData, size: 20, color: iconColor),

          ),

          const SizedBox(width: 12),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  title,

                  style: TextStyle(

                    fontSize: isMobile ? 15 : 17,

                    fontWeight: FontWeight.w800,

                    color: tokens.textPrimary,

                    letterSpacing: -0.2,

                  ),

                ),

                const SizedBox(height: 2),

                Text(

                  subtitle,

                  style: TextStyle(

                    fontSize: isMobile ? 11.5 : 12.5,

                    color: tokens.textMuted,

                  ),

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                ),

              ],

            ),

          ),

          if (_phase != _ModalStage.posting)

            IconButton(

              icon: Icon(Icons.close, size: 20, color: tokens.textMuted),

              tooltip: 'Close Modal',

              onPressed: () => Navigator.of(context).pop(),

            ),

        ],

      ),

    );

  }

  // -------------------------------------------------------------------------

  // STAGE 1: CONFIRMATION VIEW

  // -------------------------------------------------------------------------

  Widget _buildConfirmationView(bool isMobile) {

    final tokens = IcareSurfaceTokens.of(context);

    double totalRep = 0.0;

    double totalSav = widget.grpSavings;

    int paidCount = 0;

    int notPaidCount = 0;

    for (var tx in widget.stagedTransactions) {

      final rep = (tx['loan_repayment_amount'] as num?)?.toDouble() ?? 0.0;

      final sav = (tx['savings_deposit_amount'] as num?)?.toDouble() ?? 0.0;

      totalRep += rep;

      totalSav += sav;

      if (rep > 0) {

        paidCount++;

      } else if (tx['payment_status'] == 'NOT_PAID') {

        notPaidCount++;

      }

    }

    final netCash = totalRep + totalSav;

    final canSubmit = widget.isOpen || widget.isLateEntry;

    return Column(

      children: [

        Expanded(

          child: SingleChildScrollView(

            padding: EdgeInsets.all(isMobile ? 14 : 20),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                // 3 Executive Summary Tiles

                LayoutBuilder(

                  builder: (context, constraints) {

                    final w = constraints.maxWidth;

                    final card1 = _buildSummaryTile(

                      title: 'Net Cash Expected From Group',

                      value: CurrencyFormatter.formatNaira(netCash, showDecimals: true),

                      subtitle: 'Gross physical cash payable to vault',

                      icon: Icons.payments_outlined,

                      accentColor: tokens.brandPrimary,

                      bgColor: tokens.brandSoftBg,

                      isHero: true,

                    );

                    final card2 = _buildSummaryTile(

                      title: 'Total Loan Repayments',

                      value: CurrencyFormatter.formatNaira(totalRep, showDecimals: true),

                      subtitle: '$paidCount paying member(s)${notPaidCount > 0 ? ' • $notPaidCount arrears' : ''}',

                      icon: Icons.assignment_turned_in_outlined,

                      accentColor: tokens.infoText,

                      bgColor: tokens.infoBg,

                    );

                    final card3 = _buildSummaryTile(

                      title: 'Total Net Savings',

                      value: CurrencyFormatter.formatNaira(totalSav, showDecimals: true),

                      subtitle: widget.grpSavings > 0

                          ? 'Includes ${CurrencyFormatter.formatNaira(widget.grpSavings)} communal savings'

                          : 'Individual member savings',

                      icon: Icons.savings_outlined,

                      accentColor: tokens.successText,

                      bgColor: tokens.successBg,

                    );

                    if (w < 650) {

                      return Column(

                        children: [

                          card1,

                          const SizedBox(height: 10),

                          Row(

                            children: [

                              Expanded(child: card2),

                              const SizedBox(width: 10),

                              Expanded(child: card3),

                            ],

                          ),

                        ],

                      );

                    }

                    return Row(

                      children: [

                        Expanded(flex: 4, child: card1),

                        const SizedBox(width: 12),

                        Expanded(flex: 3, child: card2),

                        const SizedBox(width: 12),

                        Expanded(flex: 3, child: card3),

                      ],

                    );

                  },

                ),

                const SizedBox(height: 14),

                // Optional Group Communal Savings Callout Banner

                if (widget.grpSavings > 0) ...[

                  Container(

                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

                    decoration: BoxDecoration(

                      color: tokens.infoBg,

                      borderRadius: BorderRadius.circular(10),

                      border: Border.all(color: tokens.infoBorder),

                    ),

                    child: Row(

                      children: [

                        Container(

                          padding: const EdgeInsets.all(6),

                          decoration: BoxDecoration(

                            color: tokens.surfaceElevated,

                            borderRadius: BorderRadius.circular(6),

                          ),

                          child: Icon(Icons.account_balance, size: 16, color: tokens.infoText),

                        ),

                        const SizedBox(width: 10),

                        Expanded(

                          child: Text(

                            'Group Communal Savings: ${CurrencyFormatter.formatNaira(widget.grpSavings)} entered for ${widget.groupName} will be committed alongside individual collections.',

                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.infoText),

                            softWrap: true,

                          ),

                        ),

                      ],

                    ),

                  ),

                  const SizedBox(height: 14),

                ],

                // Staged Collections Member Checklist Table

                Container(

                  decoration: BoxDecoration(

                    color: tokens.surfaceElevated,

                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(color: tokens.borderSubtle),

                  ),

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Padding(

                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),

                        child: Row(

                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [

                            Flexible(

                              child: Text(

                                'Staged Collections Checklist (${widget.stagedTransactions.length} Members)',

                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: tokens.textPrimary),

                                overflow: TextOverflow.ellipsis,

                              ),

                            ),

                            const SizedBox(width: 8),

                            Container(

                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

                              decoration: BoxDecoration(

                                color: tokens.successBg,

                                borderRadius: BorderRadius.circular(6),

                                border: Border.all(color: tokens.successBorder),

                              ),

                              child: Text(

                                'Primary Vault',

                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.successText),

                              ),

                            ),

                          ],

                        ),

                      ),

                      Divider(height: 1, color: tokens.borderSubtle),

                      if (isMobile) ...[

                        Padding(

                          padding: const EdgeInsets.all(12),

                          child: Column(

                            children: [

                              if (widget.grpSavings > 0)

                                Container(

                                  margin: const EdgeInsets.only(bottom: 8),

                                  padding: const EdgeInsets.all(10),

                                  decoration: BoxDecoration(

                                    color: tokens.infoBg,

                                    borderRadius: BorderRadius.circular(8),

                                    border: Border.all(color: tokens.infoBorder),

                                  ),

                                  child: Row(

                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                                    children: [

                                      Expanded(

                                        child: Text(

                                          '${widget.groupName} (Communal)',

                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.infoText),

                                          overflow: TextOverflow.ellipsis,

                                        ),

                                      ),

                                      Text(

                                        CurrencyFormatter.formatNaira(widget.grpSavings),

                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tokens.infoText, fontFamily: 'monospace'),

                                      ),

                                    ],

                                  ),

                                ),

                              ...widget.stagedTransactions.map((tx) {

                                final cName = tx['client_name']?.toString() ?? 'Client';

                                final cCode = tx['client_code']?.toString() ?? '';

                                final sDep = (tx['savings_deposit_amount'] as num?)?.toDouble() ?? 0.0;

                                final lRep = (tx['loan_repayment_amount'] as num?)?.toDouble() ?? 0.0;

                                final expAmt = (tx['expected_amount'] as num?)?.toDouble() ?? 0.0;

                                final ovAmt = (tx['overdue_amount'] as num?)?.toDouble() ?? 0.0;

                                final pStat = tx['payment_status']?.toString() ?? 'UNRECORDED';

                                String badgeText = 'FULL PAID';

                                Color badgeBg = tokens.successBg;

                                Color badgeFg = tokens.successText;

                                Color badgeBorder = tokens.successBorder;

                                if (pStat == 'NOT_PAID' || (lRep == 0 && tx['mark_not_paid'] == true)) {

                                  badgeText = 'NOT PAID';

                                  badgeBg = tokens.dangerBg;

                                  badgeFg = tokens.dangerText;

                                  badgeBorder = tokens.dangerBorder;

                                } else if (pStat == 'PART_PAID') {

                                  badgeText = 'PART PAID (₦${ovAmt.toStringAsFixed(0)} Arr)';

                                  badgeBg = tokens.warningBg;

                                  badgeFg = tokens.warningText;

                                  badgeBorder = tokens.warningBorder;

                                } else if (pStat == 'EXCESS') {

                                  badgeText = 'EXCESS (+₦${(lRep - expAmt).toStringAsFixed(0)})';

                                  badgeBg = tokens.infoBg;

                                  badgeFg = tokens.infoText;

                                  badgeBorder = tokens.infoBorder;

                                }

                                final repDisplay = (pStat == 'NOT_PAID' || lRep == 0)

                                    ? '₦0.00'

                                    : CurrencyFormatter.formatNaira(lRep);

                                return Container(

                                  margin: const EdgeInsets.only(bottom: 8),

                                  padding: const EdgeInsets.all(10),

                                  decoration: BoxDecoration(

                                    color: tokens.surfaceSubtle,

                                    borderRadius: BorderRadius.circular(8),

                                    border: Border.all(color: tokens.borderSubtle),

                                  ),

                                  child: Column(

                                    crossAxisAlignment: CrossAxisAlignment.start,

                                    children: [

                                      Row(

                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                                        children: [

                                          Expanded(

                                            child: Column(

                                              crossAxisAlignment: CrossAxisAlignment.start,

                                              children: [

                                                Text(cName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: tokens.textPrimary), overflow: TextOverflow.ellipsis),

                                                Text(cCode, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tokens.textMuted)),

                                              ],

                                            ),

                                          ),

                                          Container(

                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),

                                            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4), border: Border.all(color: badgeBorder)),

                                            child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeFg)),

                                          ),

                                        ],

                                      ),

                                      const SizedBox(height: 8),

                                      Row(

                                        children: [

                                          Expanded(

                                            child: Column(

                                              crossAxisAlignment: CrossAxisAlignment.start,

                                              children: [

                                                Text('Repayment', style: TextStyle(fontSize: 10, color: tokens.textMuted, fontWeight: FontWeight.w600)),

                                                const SizedBox(height: 1),

                                                Text(repDisplay, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: pStat == 'NOT_PAID' ? tokens.dangerText : tokens.textPrimary, fontFamily: 'monospace')),

                                              ],

                                            ),

                                          ),

                                          Expanded(

                                            child: Column(

                                              crossAxisAlignment: CrossAxisAlignment.start,

                                              children: [

                                                Text('Savings Deposit', style: TextStyle(fontSize: 10, color: tokens.textMuted, fontWeight: FontWeight.w600)),

                                                const SizedBox(height: 1),

                                                Text(sDep > 0 ? CurrencyFormatter.formatNaira(sDep) : '₦0.00', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sDep > 0 ? tokens.successText : tokens.textMuted, fontFamily: 'monospace')),

                                              ],

                                            ),

                                          ),

                                        ],

                                      ),

                                    ],

                                  ),

                                );

                              }),

                            ],

                          ),

                        ),

                      ] else ...[

                      SingleChildScrollView(

                        scrollDirection: Axis.horizontal,

                        child: ConstrainedBox(

                          constraints: const BoxConstraints(minWidth: 580),

                          child: Table(

                            columnWidths: const {

                              0: FlexColumnWidth(2.6),

                              1: FlexColumnWidth(1.4),

                              2: FlexColumnWidth(1.8),

                              3: FlexColumnWidth(1.8),

                            },

                            children: [

                              TableRow(

                                decoration: BoxDecoration(color: tokens.surfaceSubtle),

                                children: [

                                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Client / Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textSecondary))),

                                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Savings (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textSecondary))),

                                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Repayment (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textSecondary))),

                                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Payment Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textSecondary))),

                                ],

                              ),

                              if (widget.grpSavings > 0)

                                TableRow(

                                  decoration: BoxDecoration(border: Border(top: BorderSide(color: tokens.borderSubtle))),

                                  children: [

                                    Padding(

                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                                      child: Text('${widget.groupName} (Communal)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.infoText)),

                                    ),

                                    Padding(

                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                                      child: Text(CurrencyFormatter.formatNaira(widget.grpSavings), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary, fontFamily: 'monospace', fontFeatures: const [FontFeature.tabularFigures()])),

                                    ),

                                    Padding(

                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                                      child: Text('—', style: TextStyle(fontSize: 12, color: tokens.textMuted)),

                                    ),

                                    Padding(

                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                                      child: Container(

                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),

                                        decoration: BoxDecoration(color: tokens.infoBg, borderRadius: BorderRadius.circular(4), border: Border.all(color: tokens.infoBorder)),

                                        child: Text('GROUP SAVINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tokens.infoText), textAlign: TextAlign.center),

                                      ),

                                    ),

                                  ],

                                ),

                              ...widget.stagedTransactions.map((tx) {

                                final cName = tx['client_name']?.toString() ?? '';

                                final cCode = tx['client_code']?.toString() ?? '';

                                final sDep = (tx['savings_deposit_amount'] as num?)?.toDouble() ?? 0.0;

                                final lRep = (tx['loan_repayment_amount'] as num?)?.toDouble() ?? 0.0;

                                final expAmt = (tx['expected_amount'] as num?)?.toDouble() ?? 0.0;

                                final pStat = tx['payment_status']?.toString() ?? 'UNRECORDED';

                                final ovAmt = (tx['overdue_amount'] as num?)?.toDouble() ?? 0.0;

                                String badgeText = 'UNRECORDED';

                                Color badgeBg = tokens.neutralBg;

                                Color badgeFg = tokens.neutralText;

                                Color badgeBorder = tokens.neutralBorder;

                                String repDisplay = CurrencyFormatter.formatNaira(lRep);

                                if (pStat == 'PAID' || pStat == 'FULL' || pStat == 'FULL PAID') {

                                  badgeText = 'FULL PAID';

                                  badgeBg = tokens.successBg;

                                  badgeFg = tokens.successText;

                                  badgeBorder = tokens.successBorder;

                                } else if (pStat == 'NOT_PAID') {

                                  badgeText = 'NOT PAID (₦${ovAmt.toStringAsFixed(0)} Arrears)';

                                  badgeBg = tokens.dangerBg;

                                  badgeFg = tokens.dangerText;

                                  badgeBorder = tokens.dangerBorder;

                                  repDisplay = '₦0 (Exp ₦${expAmt.toStringAsFixed(0)})';

                                } else if (pStat == 'PART_PAID') {

                                  badgeText = 'PART PAID (₦${ovAmt.toStringAsFixed(0)} Arrears)';

                                  badgeBg = tokens.warningBg;

                                  badgeFg = tokens.warningText;

                                  badgeBorder = tokens.warningBorder;

                                } else if (pStat == 'EXCESS') {

                                  badgeText = 'EXCESS (+₦${(lRep - expAmt).toStringAsFixed(0)})';

                                  badgeBg = tokens.infoBg;

                                  badgeFg = tokens.infoText;

                                  badgeBorder = tokens.infoBorder;

                                }

                                return TableRow(

                                  decoration: BoxDecoration(border: Border(top: BorderSide(color: tokens.borderSubtle))),

                                  children: [

                                    Padding(

                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                                      child: Column(

                                        crossAxisAlignment: CrossAxisAlignment.start,

                                        children: [

                                          Text(cName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary), softWrap: true),

                                          Text(cCode, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tokens.textMuted)),

                                        ],

                                      ),

                                    ),

                                    Padding(

                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                                      child: Text(

                                        sDep > 0 ? CurrencyFormatter.formatNaira(sDep) : '—',

                                        style: TextStyle(

                                          fontSize: 12,

                                          fontWeight: sDep > 0 ? FontWeight.w700 : FontWeight.w500,

                                          color: sDep > 0 ? tokens.textPrimary : tokens.textMuted,

                                          fontFamily: 'monospace',

                                          fontFeatures: const [FontFeature.tabularFigures()],

                                        ),

                                      ),

                                    ),

                                    Padding(

                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                                      child: Text(

                                        repDisplay,

                                        style: TextStyle(

                                          fontSize: 12,

                                          fontWeight: lRep > 0 ? FontWeight.w700 : FontWeight.w500,

                                          color: pStat == 'NOT_PAID' ? tokens.dangerText : tokens.textPrimary,

                                          fontFamily: 'monospace',

                                          fontFeatures: const [FontFeature.tabularFigures()],

                                        ),

                                      ),

                                    ),

                                    Padding(

                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                                      child: Container(

                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),

                                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4), border: Border.all(color: badgeBorder)),

                                        child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeFg), textAlign: TextAlign.center),

                                      ),

                                    ),

                                  ],

                                );

                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

        Divider(height: 1, color: tokens.borderSubtle),

        // Bottom Action Bar

        Padding(

          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 12),

          child: Row(

            children: [

              Expanded(

                flex: 1,

                child: SizedBox(

                  height: 48,

                  child: OutlinedButton.icon(

                    onPressed: () => Navigator.of(context).pop(),

                    icon: const Icon(Icons.arrow_back, size: 16),

                    label: Text(isMobile ? 'Edit' : 'Edit / Go Back', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),

                    style: OutlinedButton.styleFrom(

                      foregroundColor: tokens.textSecondary,

                      side: BorderSide(color: tokens.borderStrong, width: 1.2),

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

                    ),

                  ),

                ),

              ),

              const SizedBox(width: 10),

              Expanded(

                flex: 2,

                child: SizedBox(

                  height: 48,

                  child: ElevatedButton.icon(

                    onPressed: canSubmit ? _startPosting : null,

                    icon: const Icon(Icons.check_circle_outline, size: 18),

                    label: Text(

                      canSubmit

                          ? (isMobile ? 'Confirm (${CurrencyFormatter.formatNaira(netCash)})' : 'Confirm & Save (${CurrencyFormatter.formatNaira(netCash)})')

                          : 'Suspended (${widget.openReason})',

                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: isMobile ? 12.5 : 14),

                      overflow: TextOverflow.ellipsis,

                    ),

                    style: ElevatedButton.styleFrom(

                      backgroundColor: tokens.isDark ? tokens.brandPrimaryDark : tokens.brandPrimary,

                      foregroundColor: Colors.white,

                      disabledBackgroundColor: tokens.textLight,

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

                      elevation: 1,

                    ),

                  ),

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }

  // -------------------------------------------------------------------------

  // STAGE 2: LIVE IN-MODAL POSTING VIEW

  // -------------------------------------------------------------------------

  Widget _buildPostingView(bool isMobile) {

    final tokens = IcareSurfaceTokens.of(context);

    double totalRep = 0.0;

    double totalSav = widget.grpSavings;

    for (var tx in widget.stagedTransactions) {

      totalRep += (tx['loan_repayment_amount'] as num?)?.toDouble() ?? 0.0;

      totalSav += (tx['savings_deposit_amount'] as num?)?.toDouble() ?? 0.0;

    }

    final netCash = totalRep + totalSav;

    return Center(

      child: Padding(

        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            const _AnimatedPulsingVaultIcon(),

            const SizedBox(height: 24),

            Text(

              'Posting Collections to Ledger',

              textAlign: TextAlign.center,

              style: TextStyle(

                fontSize: 18,

                fontWeight: FontWeight.w800,

                color: tokens.textPrimary,

                letterSpacing: -0.3,

              ),

            ),

            const SizedBox(height: 8),

            AnimatedSwitcher(

              duration: const Duration(milliseconds: 250),

              child: Text(

                switch (_postingStep) {

                  0 => 'Connecting to Core Banking Engine...',

                  1 => 'Committing atomic journal entries to Primary Vault Cash...',

                  _ => 'Securing double-entry ledger lock and client balances...',

                },

                key: ValueKey<int>(_postingStep),

                textAlign: TextAlign.center,

                style: TextStyle(

                  fontSize: 13,

                  color: tokens.textSecondary,

                  fontWeight: FontWeight.w500,

                ),

              ),

            ),

            const SizedBox(height: 18),

            Container(

              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

              decoration: BoxDecoration(

                color: tokens.surfaceSubtle,

                borderRadius: BorderRadius.circular(8),

                border: Border.all(color: tokens.borderStrong),

              ),

              child: Row(

                mainAxisSize: MainAxisSize.min,

                children: [

                  Icon(Icons.group_outlined, size: 14, color: tokens.textSecondary),

                  const SizedBox(width: 6),

                  Text(

                    '${widget.groupName} • ${widget.stagedTransactions.length} Member(s) • ${CurrencyFormatter.formatNaira(netCash)}',

                    style: TextStyle(

                      fontSize: 12,

                      fontWeight: FontWeight.w700,

                      color: tokens.textPrimary,

                      fontFeatures: const [FontFeature.tabularFigures()],

                    ),

                  ),

                ],

              ),

            ),

            const SizedBox(height: 16),

            Row(

              mainAxisSize: MainAxisSize.min,

              children: [

                Icon(Icons.lock_outline, size: 13, color: tokens.textMuted),

                const SizedBox(width: 6),

                Text(

                  'Idempotency lock active • Please do not close or navigate away',

                  style: TextStyle(fontSize: 11.5, color: tokens.textMuted, fontWeight: FontWeight.w500),

                ),

              ],

            ),

          ],

        ),

      ),

    );

  }

  // -------------------------------------------------------------------------

  // STAGE 3: SUCCESS CONFIRMED RECEIPT VIEW

  // -------------------------------------------------------------------------

  Widget _buildSuccessView(bool isMobile) {

    final tokens = IcareSurfaceTokens.of(context);

    final r = _receiptData ?? {};

    final batchId = r['batch_id']?.toString() ?? 'COL-OK';

    final groupName = r['group_name']?.toString() ?? widget.groupName;

    final totalCash = (r['total_cash'] as num?)?.toDouble() ?? 0.0;

    final totalRep = (r['total_repayment'] ?? r['total_repayments'] as num?)?.toDouble() ?? 0.0;

    final totalSav = (r['total_savings'] as num?)?.toDouble() ?? 0.0;

    final totalRecs = r['total_submitted'] ?? r['items_processed'] ?? widget.stagedTransactions.length;

    final ofcStr = r['officer_name']?.toString() ?? 'Field Credit Officer';

    final recordedAt = r['timestamp']?.toString() ?? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    final isOfflineQueued = r['is_offline_queued'] == true ||
        r['offline_queued'] == true ||
        r['status'] == 'QUEUED_LOCAL' ||
        r['watermark'] != null;

    final items = (r['items'] as List<dynamic>?) ?? widget.stagedTransactions;

    final String totStr = CurrencyFormatter.formatNaira(totalCash, showDecimals: true);

    final String repStr = CurrencyFormatter.formatNaira(totalRep, showDecimals: true);

    final String savStr = CurrencyFormatter.formatNaira(totalSav, showDecimals: true);

    final whatsappText = 'ICARE COLLECTION RECEIPT\\n'

        'Batch ID: $batchId\\n'

        'Group: $groupName\\n'

        'Recorded: $recordedAt\\n'

        'Officer: $ofcStr\\n'

        'Total Collected: $totStr\\n'

        '- Loan Repayments: $repStr\\n'

        '- Savings Deposits: $savStr\\n'

        'Records Accounted: $totalRecs\\n'

        'Status: ${isOfflineQueued ? 'QUEUED LOCALLY (PENDING NETWORK SYNC)' : 'CONFIRMED & COMMITTED TO PRIMARY VAULT CASH'}';

    return Column(

      children: [

        Expanded(

          child: SingleChildScrollView(

            padding: EdgeInsets.all(isMobile ? 14 : 20),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                // Celebratory Checkmark & Status Header Banner

                Center(

                  child: Column(

                    children: [

                      const _AnimatedSuccessCheckmark(),

                      const SizedBox(height: 12),

                      Text(

                        isOfflineQueued

                            ? 'COLLECTION QUEUED LOCALLY (PENDING SYNC)'

                            : 'COLLECTION POSTED & CONFIRMED IN GENERAL LEDGER',

                        textAlign: TextAlign.center,

                        style: TextStyle(

                          fontSize: isMobile ? 13.5 : 15,

                          fontWeight: FontWeight.w800,

                          color: isOfflineQueued ? tokens.warningText : tokens.successText,

                          letterSpacing: 0.1,

                        ),

                      ),

                      const SizedBox(height: 4),

                      Text(

                        isOfflineQueued

                            ? 'Batch stored in local outbox on device. Final ledger posting to Primary Vault Cash will occur upon network synchronization.'

                            : 'All member repayments and savings deposits have been committed to the ledger with physical cash recorded in Primary Vault Cash.',

                        textAlign: TextAlign.center,

                        style: TextStyle(

                          fontSize: isMobile ? 11.5 : 12.5,

                          color: isOfflineQueued ? tokens.warningDot : tokens.successText,

                          height: 1.35,

                        ),

                      ),

                    ],

                  ),

                ),

                const SizedBox(height: 16),

                // 4 Metadata Capsules

                Container(

                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(

                    color: tokens.surfaceSubtle,

                    borderRadius: BorderRadius.circular(10),

                    border: Border.all(color: tokens.borderSubtle),

                  ),

                  child: LayoutBuilder(

                    builder: (context, constraints) {

                      final m1 = _buildMetaCapsule('Batch Reference', batchId, isCopyable: true);

                      final m2 = _buildMetaCapsule('Group / Source', groupName);

                      final m3 = _buildMetaCapsule('Officer / Branch', ofcStr);

                      final m4 = _buildMetaCapsule('Recorded At', recordedAt);

                      if (constraints.maxWidth < 600) {

                        return Column(

                          children: [

                            Row(children: [Expanded(child: m1), const SizedBox(width: 8), Expanded(child: m2)]),

                            const SizedBox(height: 8),

                            Row(children: [Expanded(child: m3), const SizedBox(width: 8), Expanded(child: m4)]),

                          ],

                        );

                      }

                      return Row(

                        children: [

                          Expanded(child: m1),

                          const SizedBox(width: 8),

                          Expanded(child: m2),

                          const SizedBox(width: 8),

                          Expanded(child: m3),

                          const SizedBox(width: 8),

                          Expanded(child: m4),

                        ],

                      );

                    },

                  ),

                ),

                const SizedBox(height: 14),

                // 4 Executive KPI Summary Cards

                LayoutBuilder(

                  builder: (context, constraints) {

                    final w = constraints.maxWidth;

                    final c1 = _buildSummaryTile(title: 'Total Cash Collected', value: totStr, subtitle: 'Physical Vault Inflow', icon: Icons.payments_outlined, accentColor: tokens.brandPrimary, bgColor: tokens.brandSoftBg, isHero: true);

                    final c2 = _buildSummaryTile(title: 'Loan Repayments', value: repStr, subtitle: 'Active credit settlements', icon: Icons.assignment_turned_in_outlined, accentColor: tokens.infoText, bgColor: tokens.infoBg);

                    final c3 = _buildSummaryTile(title: 'Savings Deposits', value: savStr, subtitle: 'Individual & Group Savings', icon: Icons.savings_outlined, accentColor: tokens.successText, bgColor: tokens.successBg);

                    final c4 = _buildSummaryTile(title: 'Members Accounted', value: '$totalRecs records', subtitle: 'Processed entries', icon: Icons.group_outlined, accentColor: tokens.neutralText, bgColor: tokens.neutralBg);

                    if (w < 600) {

                      return Column(

                        children: [

                          Row(children: [Expanded(child: c1), const SizedBox(width: 8), Expanded(child: c2)]),

                          const SizedBox(height: 8),

                          Row(children: [Expanded(child: c3), const SizedBox(width: 8), Expanded(child: c4)]),

                        ],

                      );

                    }

                    return Row(

                      children: [

                        Expanded(child: c1),

                        const SizedBox(width: 10),

                        Expanded(child: c2),

                        const SizedBox(width: 10),

                        Expanded(child: c3),

                        const SizedBox(width: 10),

                        Expanded(child: c4),

                      ],

                    );

                  },

                ),

                const SizedBox(height: 14),

                // Collapsible Itemized Member Verification Breakdown

                Container(

                  decoration: BoxDecoration(

                    color: tokens.surfaceElevated,

                    borderRadius: BorderRadius.circular(10),

                    border: Border.all(color: tokens.borderSubtle),

                  ),

                  child: Column(

                    children: [

                      InkWell(

                        onTap: () => setState(() => _itemizedExpanded = !_itemizedExpanded),

                        borderRadius: BorderRadius.circular(10),

                        child: Padding(

                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

                          child: Row(

                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [

                              Row(

                                children: [

                                  Icon(Icons.list_alt, size: 16, color: tokens.successText),

                                  const SizedBox(width: 8),

                                  Text(

                                    'View Itemized Member Verification Breakdown',

                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.successText),

                                  ),

                                ],

                              ),

                              Icon(_itemizedExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: tokens.successText),

                            ],

                          ),

                        ),

                      ),

                      if (_itemizedExpanded) ...[

                        Divider(height: 1, color: tokens.borderSubtle),

                        SingleChildScrollView(

                          scrollDirection: Axis.horizontal,

                          child: ConstrainedBox(

                            constraints: const BoxConstraints(minWidth: 500),

                            child: Table(

                              columnWidths: const {

                                0: FlexColumnWidth(2.4),

                                1: FlexColumnWidth(1.4),

                                2: FlexColumnWidth(1.4),

                                3: FlexColumnWidth(1.2),

                              },

                              children: [

                                TableRow(

                                  decoration: BoxDecoration(color: tokens.surfaceSubtle),

                                  children: [

                                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('Client / Member', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),

                                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('Repayment (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),

                                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('Savings (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),

                                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('Posting Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textSecondary))),

                                  ],

                                ),

                                ...items.map((it) {

                                  final cName = it['client_name'] ?? it['client'] ?? 'Member';

                                  final rep = (it['loan_repayment_amount'] ?? it['repayment'] as num?)?.toDouble() ?? 0.0;

                                  final sav = (it['savings_deposit_amount'] ?? it['savings'] as num?)?.toDouble() ?? 0.0;

                                  final stat = it['status']?.toString() ?? 'UNRECORDED';

                                  return TableRow(

                                    children: [

                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text(cName.toString(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textPrimary))),

                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text(rep > 0 ? CurrencyFormatter.formatNaira(rep, showDecimals: true) : '—', style: TextStyle(fontSize: 11.5, color: tokens.textPrimary, fontFamily: 'monospace', fontFeatures: const [FontFeature.tabularFigures()]))),

                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text(sav > 0 ? CurrencyFormatter.formatNaira(sav, showDecimals: true) : '—', style: TextStyle(fontSize: 11.5, color: tokens.textPrimary, fontFamily: 'monospace', fontFeatures: const [FontFeature.tabularFigures()]))),

                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: tokens.successBg, borderRadius: BorderRadius.circular(4), border: Border.all(color: tokens.successBorder)), child: Text(stat, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: tokens.successText), textAlign: TextAlign.center))),

                                    ],

                                  );

                                }),

                              ],

                            ),

                          ),

                        ),

                      ],

                    ],

                  ),

                ),

                const SizedBox(height: 12),

                // Collapsible Official WhatsApp Receipt Card

                Container(

                  decoration: BoxDecoration(

                    color: const Color(0xFF0F172A),

                    borderRadius: BorderRadius.circular(10),

                    border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,

                  ),

                  child: Column(

                    children: [

                      InkWell(

                        onTap: () => setState(() => _whatsappExpanded = !_whatsappExpanded),

                        borderRadius: BorderRadius.circular(10),

                        child: Padding(

                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

                          child: Row(

                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [

                              const Row(

                                children: [

                                  Icon(Icons.share, size: 16, color: Color(0xFF10B981)),

                                  SizedBox(width: 8),

                                  Text(

                                    'View / Copy WhatsApp Summary',

                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),

                                  ),

                                ],

                              ),

                              Row(

                                children: [

                                  TextButton.icon(

                                    icon: const Icon(Icons.copy, size: 13, color: Color(0xFF10B981)),

                                    label: const Text('Copy', style: TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.w700)),

                                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), minimumSize: Size.zero),

                                    onPressed: () {

                                      Clipboard.setData(ClipboardData(text: whatsappText));

                                      ScaffoldMessenger.of(context).showSnackBar(

                                        const SnackBar(content: Text('WhatsApp receipt copied to clipboard!'), duration: Duration(seconds: 2)),

                                      );

                                    },

                                  ),

                                  Icon(_whatsappExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: const Color(0xFF94A3B8)),

                                ],

                              ),

                            ],

                          ),

                        ),

                      ),

                      if (_whatsappExpanded) ...[

                        const Divider(height: 1, color: Color(0xFF334155)),

                        Padding(

                          padding: const EdgeInsets.all(14),

                          child: SelectableText(

                            whatsappText,

                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Color(0xFFF1F5F9), height: 1.4),

                          ),

                        ),

                      ],

                    ],

                  ),

                ),

              ],

            ),

          ),

        ),

        Divider(height: 1, color: tokens.borderSubtle),

        // Bottom Actions Bar

        Padding(

          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 12),

          child: Row(

            children: [

              Expanded(

                child: SizedBox(

                  height: 48,

                  child: ElevatedButton.icon(

                    onPressed: widget.onDismissAndReset,

                    icon: const Icon(Icons.refresh, size: 18),

                    label: const Text('Record Next Group / Return', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),

                    style: ElevatedButton.styleFrom(

                      backgroundColor: tokens.isDark ? tokens.brandPrimaryDark : tokens.brandPrimary,

                      foregroundColor: Colors.white,

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

                      elevation: 1,

                    ),

                  ),

                ),

              ),

              const SizedBox(width: 12),

              Expanded(

                child: SizedBox(

                  height: 48,

                  child: OutlinedButton.icon(

                    onPressed: widget.onViewHistory,

                    icon: const Icon(Icons.history, size: 18),

                    label: const Text('View in History & Audit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),

                    style: OutlinedButton.styleFrom(

                      foregroundColor: tokens.textSecondary,

                      side: BorderSide(color: tokens.borderStrong, width: 1.2),

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

                    ),

                  ),

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }

  // -------------------------------------------------------------------------

  // STAGE 4: ERROR VIEW

  // -------------------------------------------------------------------------

  Widget _buildErrorView(bool isMobile) {

    final tokens = IcareSurfaceTokens.of(context);

    return Center(

      child: SingleChildScrollView(

        padding: EdgeInsets.all(isMobile ? 16 : 24),

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Container(

              width: 56,

              height: 56,

              decoration: BoxDecoration(color: tokens.dangerBg, shape: BoxShape.circle),

              child: Icon(Icons.error_outline, size: 32, color: tokens.dangerDot),

            ),

            const SizedBox(height: 14),

            Text(

              'Posting Interrupted',

              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tokens.textPrimary),

            ),

            const SizedBox(height: 8),

            Container(

              constraints: const BoxConstraints(maxWidth: 480),

              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

              decoration: BoxDecoration(

                color: tokens.dangerBg,

                borderRadius: BorderRadius.circular(10),

                border: Border.all(color: tokens.dangerBorder),

              ),

              child: Text(

                _errorMessage ?? 'An error occurred while posting collections to the ledger. Staged data has been preserved.',

                textAlign: TextAlign.center,

                style: TextStyle(fontSize: 12.5, color: tokens.dangerText, height: 1.4, fontWeight: FontWeight.w500),

              ),

            ),

            const SizedBox(height: 20),

            Row(

              mainAxisAlignment: MainAxisAlignment.center,

              children: [

                OutlinedButton.icon(

                  onPressed: () => setState(() => _phase = _ModalStage.confirmation),

                  icon: const Icon(Icons.arrow_back, size: 16),

                  label: const Text('Edit Collections', style: TextStyle(fontWeight: FontWeight.w700)),

                  style: OutlinedButton.styleFrom(

                    foregroundColor: tokens.textSecondary,

                    side: BorderSide(color: tokens.borderStrong),

                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12),

                  ),

                ),

                const SizedBox(width: 12),

                ElevatedButton.icon(

                  onPressed: _startPosting,

                  icon: const Icon(Icons.refresh, size: 16),

                  label: const Text('Retry Submission', style: TextStyle(fontWeight: FontWeight.w700)),

                  style: ElevatedButton.styleFrom(

                    backgroundColor: tokens.isDark ? tokens.brandPrimaryDark : tokens.brandPrimary,

                    foregroundColor: Colors.white,

                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12),

                  ),

                ),

              ],

            ),

          ],

        ),

      ),

    );

  }

  Widget _buildSummaryTile({

    required String title,

    required String value,

    required String subtitle,

    required IconData icon,

    required Color accentColor,

    required Color bgColor,

    bool isHero = false,

  }) {

    final tokens = IcareSurfaceTokens.of(context);

    return Container(

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(

        color: tokens.surfaceElevated,

        borderRadius: BorderRadius.circular(10),

        border: Border(

          top: BorderSide(color: accentColor, width: 2.5),

          left: BorderSide(color: isHero ? accentColor.withValues(alpha: 0.3) : tokens.borderSubtle),

          right: BorderSide(color: isHero ? accentColor.withValues(alpha: 0.3) : tokens.borderSubtle),

          bottom: BorderSide(color: isHero ? accentColor.withValues(alpha: 0.3) : tokens.borderSubtle),

        ),

        boxShadow: [

          BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.16 : 0.03), blurRadius: 4, offset: const Offset(0, 1)),

        ],

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              Expanded(

                child: Text(

                  title,

                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textMuted),

                  softWrap: true,

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,

                ),

              ),

              Container(

                padding: const EdgeInsets.all(4),

                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),

                child: Icon(icon, size: 14, color: accentColor),

              ),

            ],

          ),

          const SizedBox(height: 5),

          FittedBox(

            fit: BoxFit.scaleDown,

            alignment: Alignment.centerLeft,

            child: Text(

              value,

              maxLines: 1,

              softWrap: false,

              style: TextStyle(

                fontSize: 16,

                fontWeight: FontWeight.w800,

                color: isHero ? accentColor : tokens.textPrimary,

                fontFamily: 'monospace',

                fontFeatures: const [FontFeature.tabularFigures()],

              ),

            ),

          ),

          const SizedBox(height: 3),

          Text(

            subtitle,

            style: TextStyle(fontSize: 10.5, color: tokens.textMuted, fontWeight: FontWeight.w500),

            softWrap: true,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

          ),

        ],

      ),

    );

  }

  Widget _buildMetaCapsule(String label, String value, {bool isCopyable = false}) {

    final tokens = IcareSurfaceTokens.of(context);

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

      decoration: BoxDecoration(

        color: tokens.surfaceElevated,

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: tokens.borderSubtle),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(label, style: TextStyle(fontSize: 10, color: tokens.textMuted, fontWeight: FontWeight.w600)),

          const SizedBox(height: 2),

          Row(

            children: [

              Expanded(

                child: Text(

                  value,

                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary),

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                ),

              ),

              if (isCopyable) ...[

                const SizedBox(width: 4),

                InkWell(

                  onTap: () {

                    Clipboard.setData(ClipboardData(text: value));

                    ScaffoldMessenger.of(context).showSnackBar(

                      const SnackBar(content: Text('Copied reference!'), duration: Duration(seconds: 1)),

                    );

                  },

                  child: Icon(Icons.copy, size: 13, color: tokens.textMuted),

                ),

              ],

            ],

          ),

        ],

      ),

    );

  }

}

// =========================================================================

// SINGLE CLIENT 4-PHASE ANIMATED CONFIRMATION & RECEIPT MODAL

// =========================================================================

class _SingleClientFlowModal extends StatefulWidget {
  final Map<String, dynamic> clientObj;
  final String dateStr;
  final String? loanId;
  final double expRep;
  final double savVal;
  final double grpSavVal;
  final double repVal;
  final double appVal;
  final double pbVal;
  final double miscVal;
  final bool isNotPaid;
  final String note;
  final bool isOnline;
  final Future<Map<String, dynamic>> Function() onConfirmPost;
  final VoidCallback onDismissAndReset;
  final VoidCallback onViewHistory;

  const _SingleClientFlowModal({
    required this.clientObj,
    required this.dateStr,
    required this.loanId,
    required this.expRep,
    required this.savVal,
    required this.grpSavVal,
    required this.repVal,
    required this.appVal,
    required this.pbVal,
    required this.miscVal,
    required this.isNotPaid,
    required this.note,
    required this.isOnline,
    required this.onConfirmPost,
    required this.onDismissAndReset,
    required this.onViewHistory,
  });

  @override
  State<_SingleClientFlowModal> createState() => _SingleClientFlowModalState();
}

class _SingleClientFlowModalState extends State<_SingleClientFlowModal> {
  _ModalStage _phase = _ModalStage.confirmation;
  Map<String, dynamic>? _receiptData;
  String? _errorMessage;
  int _postingStep = 0;
  Timer? _stepTimer;

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  Future<void> _startPosting() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _ModalStage.posting;
      _postingStep = 0;
      _errorMessage = null;
    });

    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 750), (t) {
      if (mounted && _phase == _ModalStage.posting) {
        setState(() {
          _postingStep = (_postingStep + 1) % 3;
        });
      }
    });

    try {
      final res = await widget.onConfirmPost();
      _stepTimer?.cancel();
      if (mounted) {
        setState(() {
          _receiptData = res['receipt'] as Map<String, dynamic>? ?? res;
          _phase = _ModalStage.success;
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      _stepTimer?.cancel();
      if (mounted) {
        setState(() {
          _errorMessage = AppErrorDetails.from(e).message;
          _phase = _ModalStage.error;
        });
        HapticFeedback.vibrate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 600;
    final maxDialogWidth = isMobile ? double.infinity : 680.0;
    final maxDialogHeight = media.size.height * (isMobile ? 0.94 : 0.88);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxDialogWidth,
            maxHeight: maxDialogHeight,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(isMobile ? 16 : 18),
              border: Border.all(color: tokens.borderSubtle),
              boxShadow: tokens.isDark
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x260F172A),
                        blurRadius: 28,
                        offset: Offset(0, 10),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isMobile ? 16 : 18),
              child: Column(
                children: [
                  _buildHeader(context, isMobile),
                  Divider(height: 1, color: tokens.borderSubtle),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: switch (_phase) {
                        _ModalStage.confirmation => _buildConfirmationView(isMobile),
                        _ModalStage.posting => _buildPostingView(isMobile),
                        _ModalStage.success => _buildSuccessView(isMobile),
                        _ModalStage.error => _buildErrorView(isMobile),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final clientName = widget.clientObj['client_name']?.toString() ?? 'Client';
    final isOfflineQueued = _receiptData?['is_offline_queued'] == true ||
        _receiptData?['offline_queued'] == true ||
        _receiptData?['status'] == 'QUEUED_LOCAL' ||
        _receiptData?['watermark'] != null;

    final title = switch (_phase) {
      _ModalStage.confirmation => 'Review Client Collection',
      _ModalStage.posting => 'Posting Collection to Vault',
      _ModalStage.success => isOfflineQueued ? 'Client Collection Queued Offline' : 'Client Collection Confirmed',
      _ModalStage.error => 'Posting Interrupted',
    };

    final subtitle = switch (_phase) {
      _ModalStage.confirmation => 'Verify collection entries for $clientName before ledger commitment.',
      _ModalStage.posting => 'Double-entry journal committing to Primary Vault Cash in real time.',
      _ModalStage.success => isOfflineQueued
          ? 'Saved to device outbox for automatic synchronization when back online.'
          : 'Successfully committed to Vault Cash with complete client audit trail.',
      _ModalStage.error => 'Ledger communication encountered an issue.',
    };

    final iconData = switch (_phase) {
      _ModalStage.confirmation => Icons.person_outline,
      _ModalStage.posting => Icons.sync,
      _ModalStage.success => isOfflineQueued ? Icons.cloud_upload_outlined : Icons.check_circle_outline,
      _ModalStage.error => Icons.error_outline,
    };

    final iconBg = switch (_phase) {
      _ModalStage.confirmation => tokens.infoBg,
      _ModalStage.posting => tokens.brandSoftBg,
      _ModalStage.success => isOfflineQueued ? tokens.warningBg : tokens.successBg,
      _ModalStage.error => tokens.dangerBg,
    };

    final iconColor = switch (_phase) {
      _ModalStage.confirmation => tokens.infoText,
      _ModalStage.posting => tokens.brandPrimary,
      _ModalStage.success => isOfflineQueued ? tokens.warningDot : tokens.successDot,
      _ModalStage.error => tokens.dangerDot,
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 14),
      color: tokens.surface,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 17,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isMobile ? 11.5 : 12.5,
                    color: tokens.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_phase == _ModalStage.confirmation || _phase == _ModalStage.error)
            IconButton(
              icon: Icon(Icons.close, size: 20, color: tokens.textMuted),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Close',
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmationView(bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final clientName = widget.clientObj['client_name']?.toString() ?? 'Client';
    final clientCode = widget.clientObj['client_code']?.toString() ?? 'CLI-N/A';
    final groupName = widget.clientObj['group_name']?.toString() ?? 'Ungrouped';
    final totalFees = widget.appVal + widget.pbVal + widget.miscVal;
    final totalSavings = widget.savVal + widget.grpSavVal;
    final totalCash = widget.repVal + totalSavings + totalFees;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 14 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client Card Header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: tokens.brandSoftBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.badge_outlined, size: 22, color: tokens.brandPrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clientName,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Code: $clientCode • Group: $groupName',
                              style: TextStyle(fontSize: 12, color: tokens.textMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Hero Cash Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.brandSoftBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.brandSoftBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: tokens.successBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.payments_outlined, size: 24, color: tokens.brandPrimary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Cash Collection',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.brandSoftText),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.formatNaira(totalCash, showDecimals: true),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: tokens.brandSoftText,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Itemized Breakdown Table
                Text(
                  'Transaction Breakdown',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: tokens.textSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: tokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      if (widget.isNotPaid)
                        _buildLineItem(
                          'Loan Repayment',
                          'Marked NOT PAID (₦${widget.expRep.toStringAsFixed(0)} Arrears)',
                          tokens.dangerText,
                          isAlert: true,
                        )
                      else if (widget.repVal > 0)
                        _buildLineItem(
                          'Loan Repayment',
                          CurrencyFormatter.formatNaira(widget.repVal, showDecimals: true),
                          tokens.infoText,
                        ),
                      if (widget.savVal > 0)
                        _buildLineItem(
                          'Personal Savings Deposit',
                          CurrencyFormatter.formatNaira(widget.savVal, showDecimals: true),
                          tokens.brandAccent,
                        ),
                      if (widget.grpSavVal > 0)
                        _buildLineItem(
                          'Group Savings Deposit',
                          CurrencyFormatter.formatNaira(widget.grpSavVal, showDecimals: true),
                          tokens.brandAccent,
                        ),
                      if (widget.appVal > 0)
                        _buildLineItem(
                          'Application / Credit Form Fee',
                          CurrencyFormatter.formatNaira(widget.appVal, showDecimals: true),
                          tokens.warningText,
                        ),
                      if (widget.pbVal > 0)
                        _buildLineItem(
                          'Pass Book Fee',
                          CurrencyFormatter.formatNaira(widget.pbVal, showDecimals: true),
                          tokens.warningText,
                        ),
                      if (widget.miscVal > 0)
                        _buildLineItem(
                          'Misc Fee (Routed to Misc Savings)',
                          CurrencyFormatter.formatNaira(widget.miscVal, showDecimals: true),
                          tokens.textSecondary,
                        ),
                      if (widget.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Remarks:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textMuted)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(widget.note, style: TextStyle(fontSize: 12, color: tokens.textPrimary)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: tokens.borderSubtle),

        // Bottom Action Bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: isMobile ? 2 : 1,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Edit Entry', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.textSecondary,
                      side: BorderSide(color: tokens.borderStrong, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: isMobile ? 3 : 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _startPosting,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      'Confirm & Post (${CurrencyFormatter.formatNaira(totalCash)})',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brandPrimaryDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineItem(String label, String value, Color valueColor, {bool isAlert = false}) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostingView(bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final clientName = widget.clientObj['client_name']?.toString() ?? 'Client';
    final totalCash = widget.repVal + widget.savVal + widget.grpSavVal + widget.appVal + widget.pbVal + widget.miscVal;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _AnimatedPulsingVaultIcon(),
            const SizedBox(height: 24),
            Text(
              'Posting Collection to Vault',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                switch (_postingStep) {
                  0 => 'Verifying client portfolio & account balances...',
                  1 => 'Committing atomic journal entries to Primary Vault Cash...',
                  _ => 'Securing double-entry ledger lock and fee audit trail...',
                },
                key: ValueKey<int>(_postingStep),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderStrong),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline, size: 14, color: tokens.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '$clientName • ${CurrencyFormatter.formatNaira(totalCash)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 13, color: tokens.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Idempotency lock active • Please do not close or navigate away',
                  style: TextStyle(fontSize: 11.5, color: tokens.textMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final r = _receiptData ?? {};
    final batchId = r['batch_id']?.toString() ?? 'COL-SC-OK';
    final clientName = widget.clientObj['client_name']?.toString() ?? 'Client';
    final clientCode = widget.clientObj['client_code']?.toString() ?? 'CLI-N/A';
    final groupName = widget.clientObj['group_name']?.toString() ?? 'Ungrouped';
    final totalCash = (r['total_cash'] as num?)?.toDouble() ?? (widget.repVal + widget.savVal + widget.grpSavVal + widget.appVal + widget.pbVal + widget.miscVal);
    final recordedAt = r['timestamp']?.toString() ?? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final isOfflineQueued = r['offline_queued'] == true || r['status'] == 'QUEUED_LOCAL' || r['watermark'] != null;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 14 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      if (isOfflineQueued)
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: tokens.warningBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: tokens.warningBorder, width: 2),
                          ),
                          child: Icon(Icons.cloud_upload_outlined, color: tokens.warningDot, size: 28),
                        )
                      else
                        const _AnimatedSuccessCheckmark(),
                      const SizedBox(height: 12),
                      Text(
                        isOfflineQueued
                            ? 'COLLECTION QUEUED LOCALLY (PENDING SYNC)'
                            : 'COLLECTION POSTED & COMMITTED TO PRIMARY VAULT CASH',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isOfflineQueued ? tokens.warningText : tokens.brandPrimary,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOfflineQueued
                            ? 'Single client collection stored in local outbox on device. Final ledger posting to Primary Vault Cash will occur upon network synchronization.'
                            : 'Transaction recorded with client attribution in fee register and double-entry ledger.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isOfflineQueued ? tokens.warningText : tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Digital Receipt Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isOfflineQueued ? tokens.warningBg : tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOfflineQueued ? tokens.warningBorder : tokens.borderStrong,
                      width: isOfflineQueued ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isOfflineQueued) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: tokens.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: tokens.warningBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_filled, size: 14, color: tokens.warningText),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'OFFLINE RECEIPT · PENDING RECONCILIATION TO VAULT CASH',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: tokens.warningText,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Receipt Reference:', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                          Text(batchId, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: tokens.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Client:', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                          Text('$clientName ($clientCode)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Group:', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                          Text(groupName, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recorded At:', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                          Text(recordedAt, style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
                        ],
                      ),
                      Divider(height: 18, color: tokens.borderSubtle),
                      if (widget.isNotPaid)
                        _buildReceiptRow('Loan Repayment', 'Marked NOT PAID')
                      else if (widget.repVal > 0)
                        _buildReceiptRow('Loan Repayment', CurrencyFormatter.formatNaira(widget.repVal, showDecimals: true)),
                      if (widget.savVal > 0)
                        _buildReceiptRow('Personal Savings', CurrencyFormatter.formatNaira(widget.savVal, showDecimals: true)),
                      if (widget.grpSavVal > 0)
                        _buildReceiptRow('Group Savings', CurrencyFormatter.formatNaira(widget.grpSavVal, showDecimals: true)),
                      if (widget.appVal > 0)
                        _buildReceiptRow('Application Fee', CurrencyFormatter.formatNaira(widget.appVal, showDecimals: true)),
                      if (widget.pbVal > 0)
                        _buildReceiptRow('Pass Book Fee', CurrencyFormatter.formatNaira(widget.pbVal, showDecimals: true)),
                      if (widget.miscVal > 0)
                        _buildReceiptRow('Misc Fee', CurrencyFormatter.formatNaira(widget.miscVal, showDecimals: true)),
                      Divider(height: 18, color: tokens.borderStrong),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TOTAL CASH COLLECTED', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: tokens.textPrimary)),
                          Text(CurrencyFormatter.formatNaira(totalCash, showDecimals: true), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: tokens.brandPrimary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: tokens.borderSubtle),

        // Bottom Actions
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: widget.onViewHistory,
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('View History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.textSecondary,
                      side: BorderSide(color: tokens.borderStrong),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: widget.onDismissAndReset,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Record Next Client', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brandPrimaryDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    final tokens = IcareSurfaceTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: tokens.textMuted)),
          Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildErrorView(bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: tokens.dangerBg, shape: BoxShape.circle),
              child: Icon(Icons.error_outline, size: 36, color: tokens.dangerDot),
            ),
            const SizedBox(height: 16),
            Text('Posting Failed', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tokens.textPrimary)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'An unknown error occurred.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: tokens.textMuted)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                    side: BorderSide(color: tokens.borderStrong),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _startPosting,
                  style: ElevatedButton.styleFrom(backgroundColor: tokens.brandPrimaryDark, foregroundColor: Colors.white),
                  child: const Text('Retry Posting'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// CELEBRATORY CHECKMARK & PULSING VAULT ANIMATION WIDGETS
// =========================================================================
class _AnimatedSuccessCheckmark extends StatefulWidget {
  const _AnimatedSuccessCheckmark();

  @override
  State<_AnimatedSuccessCheckmark> createState() => _AnimatedSuccessCheckmarkState();
}

class _AnimatedSuccessCheckmarkState extends State<_AnimatedSuccessCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: tokens.successBg,
          shape: BoxShape.circle,
          border: Border.all(color: tokens.successBorder, width: 2),
          boxShadow: tokens.isDark
              ? null
              : const [
                  BoxShadow(color: Color(0x1F059669), blurRadius: 14, offset: Offset(0, 4)),
                ],
        ),
        child: Icon(Icons.check, color: tokens.successDot, size: 34),
      ),
    );
  }
}

class _AnimatedPulsingVaultIcon extends StatefulWidget {
  const _AnimatedPulsingVaultIcon();

  @override
  State<_AnimatedPulsingVaultIcon> createState() => _AnimatedPulsingVaultIconState();
}

class _AnimatedPulsingVaultIconState extends State<_AnimatedPulsingVaultIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return ScaleTransition(
      scale: _pulseAnim,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: tokens.brandSoftBg,
          shape: BoxShape.circle,
          border: Border.all(color: tokens.brandSoftBorder, width: 2),
          boxShadow: tokens.isDark
              ? null
              : const [
                  BoxShadow(color: Color(0x1F059669), blurRadius: 18, offset: Offset(0, 6)),
                ],
        ),
        child: Center(
          child: SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(tokens.brandPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

