// ignore_for_file: deprecated_member_use, prefer_const_constructors
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/errors/app_error_formatter.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_sync_manager.dart';
import '../data/datasources/co_api_service.dart';
import '../../../core/widgets/icare_card.dart';
import '../../../core/widgets/icare_data_table.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../../../core/widgets/icare_status_badge.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import 'widgets/co_shared_widgets.dart';
import 'widgets/co_withdrawal_charts.dart';
import 'co_dashboard_screen.dart';
import 'daily_cashbook_screen.dart';
import '../../bm/presentation/bm_dashboard_screen.dart';
import '../../bm/presentation/master_cashbook_screen.dart';

// ==========================================
// STATE PROVIDERS
// ==========================================

final withdrawalTabProvider = StateProvider<String>((ref) => 'Individual Savings');
final withdrawalBusinessDateProvider = FutureProvider<DateTime?>((ref) async {
  ref.watch(authControllerProvider);
  final api = ref.watch(coApiServiceProvider);
  try {
    final res = await api.getOriginationBusinessDate();
    final raw = res['business_date']?.toString().trim();
    if (raw != null && raw.length >= 10) {
      return DateTime.tryParse(raw.substring(0, 10));
    }
  } catch (_) {}
  return null;
});
final withdrawalManualOpDateProvider = StateProvider<DateTime?>((ref) => null);
final withdrawalOpDateProvider = Provider<DateTime>((ref) {
  return ref.watch(withdrawalManualOpDateProvider) ??
      ref.watch(withdrawalBusinessDateProvider).valueOrNull ??
      DateTime.now();
});
final dwShowAllProvider = StateProvider<bool>((ref) => false);
final dwCategoryProvider = StateProvider<String>((ref) => 'All Types');
final dwSearchProvider = StateProvider<String>((ref) => '');

// ==========================================
// ASYNC DATA PROVIDERS
// ==========================================

final individualOptionsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(authControllerProvider);
  final api = ref.watch(coApiServiceProvider);
  return api.getIndividualWithdrawalOptions();
});

final groupOptionsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(authControllerProvider);
  final api = ref.watch(coApiServiceProvider);
  return api.getGroupWithdrawalOptions();
});

final miscBalanceProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(authControllerProvider);
  final api = ref.watch(coApiServiceProvider);
  return api.getMiscWithdrawalBalance();
});

final lapsOptionsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(authControllerProvider);
  final api = ref.watch(coApiServiceProvider);
  return api.getLapsWithdrawalOptions();
});

final dailyWithdrawalsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(coApiServiceProvider);
  final opDate = ref.watch(withdrawalOpDateProvider);
  final showAll = ref.watch(dwShowAllProvider);
  final cat = ref.watch(dwCategoryProvider);
  final search = ref.watch(dwSearchProvider);

  final dateStr = DateFormat('yyyy-MM-dd').format(opDate);
  return api.getDailyWithdrawals(date: dateStr, showAll: showAll, category: cat, search: search);
});

final pendingApprovalsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(coApiServiceProvider);
  return api.getPendingApprovals();
});

/// 1:1 Streamlit replica of Withdrawal Operations (app.py L7260–8801)
/// Zero hardcoded data. Reuses live backend withdrawal options & request processing.
/// Zero-emoji governance strictly enforced.
class WithdrawalOperationsScreen extends ConsumerStatefulWidget {
  const WithdrawalOperationsScreen({super.key});

  @override
  ConsumerState<WithdrawalOperationsScreen> createState() => _WithdrawalOperationsScreenState();
}

class _WithdrawalOperationsScreenState extends ConsumerState<WithdrawalOperationsScreen> {
  // Tab 1: Individual State
  String _indGroupFilter = 'All Groups';
  String? _indSelectedClientId;
  String _indDestOp = 'Cash Withdrawal';
  String? _indSelectedLoanId;
  String _indFeeType = 'credit_form_damage';
  String _indTransferTargetCat = 'IndividualSavings';
  String? _indTransferRecipientId;
  final _indAmountCtrl = TextEditingController();
  final _indRemarksCtrl = TextEditingController();
  bool _indAutoExec = false;

  // Tab 2: Group State
  String? _grpSelectedGroupId;
  String _grpDestOp = 'Cash Withdrawal';
  String? _grpSelectedMemberId;
  String? _grpSelectedLoanId;
  String _grpFeeType = 'credit_form_damage';
  String _grpTransferTargetCat = 'IndividualSavings';
  String? _grpTransferRecipientId;
  String? _grpLapsBeneficiaryClientId;
  String? _grpLapsBeneficiaryClientName;
  final _grpAmountCtrl = TextEditingController();
  final _grpRemarksCtrl = TextEditingController();
  bool _grpAutoExec = false;

  // Tab 3: Misc State
  String _miscPayoutMethod = 'Cash';
  final _miscAmountCtrl = TextEditingController();
  final _miscRemarksCtrl = TextEditingController();
  bool _miscAutoExec = true;

  // Tab 4: LAPS State
  String? _selectedLapsClientId;
  String _lapsPayoutMethod = 'Cash';
  final _lapsAmountCtrl = TextEditingController();
  final _lapsRemarksCtrl = TextEditingController();
  bool _lapsAutoExec = false;

  // Tab 5: Pending Approvals Reject State
  String? _rejectingRequestId;
  final _rejectReasonCtrl = TextEditingController();

  // Subtabs for Daily Withdrawals
  int _dwSubtabIndex = 0;

  String? _flashMessage;
  bool _isSuccessFlash = true;
  bool _isSubmitting = false;
  final Map<String, String> _attemptIdemKeys = {};
  int _attemptSeq = 0;

  String _getAttemptIdemKey(String formTag) {
    return _attemptIdemKeys.putIfAbsent(
      formTag,
      () => '$formTag-${DateTime.now().microsecondsSinceEpoch}-${_attemptSeq++}',
    );
  }

  void _clearAttemptIdemKey(String formTag) {
    _attemptIdemKeys.remove(formTag);
  }

  String get _currentUsername {
    final authState = ref.read(authControllerProvider);
    return authState is AuthStateAuthenticated ? authState.user.username.trim() : '';
  }

  bool get _isManager {
    final authState = ref.read(authControllerProvider);
    final role = authState is AuthStateAuthenticated ? authState.user.role : 'Credit Officer';
    return const {'Branch Manager', 'BM'}.contains(role);
  }

  static final RegExp _internalTagPattern = RegExp(
    r'\[(?:DEST_ID|DEST_NAME|DEST_TYPE|FEE|LOAN_OFFSET|IDEMPOTENCY):[^\]]*\]\s*',
    caseSensitive: false,
  );

  String _cleanRemarks(dynamic raw) {
    return (raw ?? '').toString().replaceAll(_internalTagPattern, '').trim();
  }

  void _invalidateAfterWithdrawalMutation() {
    ref.invalidate(withdrawalBusinessDateProvider);
    ref.invalidate(individualOptionsProvider);
    ref.invalidate(groupOptionsProvider);
    ref.invalidate(miscBalanceProvider);
    ref.invalidate(lapsOptionsProvider);
    ref.invalidate(dailyWithdrawalsProvider);
    ref.invalidate(pendingApprovalsProvider);
    ref.invalidate(coDashboardProvider);
    ref.invalidate(bmDashboardDataProvider);
    ref.invalidate(masterDailyCashbookProvider);
    ref.invalidate(coCashbookDataProvider);
  }

  static const List<Map<String, dynamic>> _indDestOptions = [
    {
      'value': 'Cash Withdrawal',
      'title': 'Cash Withdrawal',
      'subtitle': 'Physical cash withdrawal paid from branch vault cash',
      'icon': Icons.payments_outlined,
    },
    {
      'value': 'Client Bank Account (Transfer)',
      'title': 'Client Bank Account (Transfer)',
      'subtitle': 'Direct electronic wire to client\'s registered bank account',
      'icon': Icons.account_balance_rounded,
    },
    {
      'value': 'Loan Repayment / Asset Debt Offset',
      'title': 'Loan Repayment / Debt Offset',
      'subtitle': 'Non-cash debt settlement directly reducing active loan balance',
      'icon': Icons.published_with_changes_rounded,
    },
    {
      'value': 'Fee Payment from Savings',
      'title': 'Fee Payment from Savings',
      'subtitle': 'Clear passbook, application, or damage fee shortfalls from savings',
      'icon': Icons.receipt_long_rounded,
    },
    {
      'value': 'Another Member or Group Savings',
      'title': 'Another Member or Group Savings',
      'subtitle': 'Internal non-cash transfer to another member or group account',
      'icon': Icons.sync_alt_rounded,
    },
    {
      'value': 'LAPS Reserve',
      'title': 'LAPS Protection Reserve',
      'subtitle': 'Sweep residual savings to Loan Asset Protection Scheme reserve',
      'icon': Icons.shield_outlined,
    },
  ];

  static const List<Map<String, dynamic>> _grpDestOptions = [
    {
      'value': 'Cash Withdrawal',
      'title': 'Cash Withdrawal',
      'subtitle': 'Physical cash withdrawal paid from branch vault cash',
      'icon': Icons.payments_outlined,
    },
    {
      'value': 'Group Bank Account (Transfer)',
      'title': 'Group Bank Account (Transfer)',
      'subtitle': 'Direct electronic payout to group\'s official bank account',
      'icon': Icons.account_balance_rounded,
    },
    {
      'value': 'Loan Repayment / Asset Debt Offset (Member Debt)',
      'title': 'Member Debt Offset',
      'subtitle': 'Offset a member\'s overdue or active loan from group savings',
      'icon': Icons.published_with_changes_rounded,
    },
    {
      'value': 'Fee Payment from Group Savings',
      'title': 'Fee Payment from Group Savings',
      'subtitle': 'Clear collective group administrative or passbook fees',
      'icon': Icons.receipt_long_rounded,
    },
    {
      'value': 'Another Member or Group Savings',
      'title': 'Reallocate to Another Member/Group',
      'subtitle': 'Internal non-cash transfer to another member or group account',
      'icon': Icons.sync_alt_rounded,
    },
    {
      'value': 'LAPS Reserve (Group Closed)',
      'title': 'LAPS Reserve (Group Closed)',
      'subtitle': 'Transfer residual group savings to LAPS reserve upon group dissolution',
      'icon': Icons.shield_outlined,
    },
  ];

  @override
  void dispose() {
    _indAmountCtrl.dispose();
    _indRemarksCtrl.dispose();
    _grpAmountCtrl.dispose();
    _grpRemarksCtrl.dispose();
    _miscAmountCtrl.dispose();
    _miscRemarksCtrl.dispose();
    _lapsAmountCtrl.dispose();
    _lapsRemarksCtrl.dispose();
    _rejectReasonCtrl.dispose();
    super.dispose();
  }

  void _showFlash(String msg, {bool isSuccess = true}) {
    setState(() {
      _flashMessage = msg;
      _isSuccessFlash = isSuccess;
    });
  }

  Future<void> _submitOrQueueWithdrawalRequest({
    required Map<String, dynamic> payload,
    required String displayLabel,
    required String attemptKey,
    required bool autoExecuteRequested,
    required VoidCallback onCleared,
    required String onlineDefaultMessage,
  }) async {
    final isOnline = ref.read(isOnlineProvider);
    final syncMgr = ref.read(offlineSyncManagerProvider);
    final dateStr = payload['operational_date']?.toString() ??
        DateFormat('yyyy-MM-dd').format(ref.read(withdrawalOpDateProvider));

    if (!isOnline && autoExecuteRequested) {
      _showFlash(
        'Live server connection is required for immediate authorization and payout. Uncheck immediate authorization to queue a request for later review.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (!isOnline) {
        final offlineRes = await syncMgr.queueOfflineWithdrawalRequest(
          displayLabel: displayLabel,
          operationalDate: dateStr,
          payload: payload,
        );
        _showFlash(
          offlineRes['message']?.toString() ??
              'Withdrawal request queued offline for Manager approval. Do not disburse cash until synced and approved.',
        );
        onCleared();
        _clearAttemptIdemKey(attemptKey);
        _invalidateAfterWithdrawalMutation();
        return;
      }

      try {
        final api = ref.read(coApiServiceProvider);
        final res = await api.submitWithdrawalRequest(payload);
        _showFlash(res['message']?.toString() ?? onlineDefaultMessage);
        onCleared();
        _clearAttemptIdemKey(attemptKey);
        _invalidateAfterWithdrawalMutation();
      } catch (e) {
        if (!autoExecuteRequested &&
            e is DioException &&
            !ApiClient.isPermanentError(e)) {
          final offlineRes = await syncMgr.queueOfflineWithdrawalRequest(
            displayLabel: displayLabel,
            operationalDate: dateStr,
            payload: payload,
          );
          _showFlash(
            offlineRes['message']?.toString() ??
                'Network interrupted: Withdrawal request queued offline with the same reference for Manager approval.',
          );
          onCleared();
          _clearAttemptIdemKey(attemptKey);
          _invalidateAfterWithdrawalMutation();
          return;
        }
        _showFlash(AppErrorDetails.from(e).message, isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ==========================================================================
  // TAB 1: INDIVIDUAL SAVINGS SUBMISSION
  // ==========================================================================
  Future<void> _submitIndividualWithdrawal(
    Map<String, dynamic> clientData, {
    required List<Map<String, dynamic>> allClients,
    required List<Map<String, dynamic>> allGroups,
  }) async {
    final amt = double.tryParse(_indAmountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final bal = (clientData['savings_balance'] as num?)?.toDouble() ?? 0.0;
    final cId = clientData['client_id']?.toString() ?? '';
    final cName = clientData['name']?.toString() ?? 'Client';

    if (amt <= 0) {
      _showFlash('Amount must be greater than zero.', isSuccess: false);
      return;
    }
    if (amt > bal + 0.01) {
      _showFlash('Insufficient balance. Available: ${CurrencyFormatter.formatNaira(bal)}', isSuccess: false);
      return;
    }
    if (_indDestOp == 'Loan Repayment / Asset Debt Offset') {
      if (_indSelectedLoanId == null || _indSelectedLoanId!.isEmpty) {
        _showFlash('Select an eligible loan for debt offset.', isSuccess: false);
        return;
      }
      final loans = (clientData['eligible_loans'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final targetLoan = loans.firstWhere(
        (l) => l['loan_id']?.toString() == _indSelectedLoanId,
        orElse: () => <String, dynamic>{},
      );
      final loanBal = (targetLoan['balance'] as num?)?.toDouble();
      if (loanBal != null && amt > loanBal + 0.01) {
        _showFlash(
          'Offset amount exceeds remaining loan balance of ${CurrencyFormatter.formatNaira(loanBal)}.',
          isSuccess: false,
        );
        return;
      }
    }
    if (_indDestOp == 'Another Member or Group Savings' && (_indTransferRecipientId == null || _indTransferRecipientId!.isEmpty)) {
      _showFlash('Select a transfer recipient account.', isSuccess: false);
      return;
    }

    String? destId;
    String? destName;
    String? destType;
    if (_indDestOp == 'Loan Repayment / Asset Debt Offset') {
      destId = _indSelectedLoanId;
      destType = 'Loan';
    } else if (_indDestOp == 'Another Member or Group Savings') {
      destId = _indTransferRecipientId;
      destType = _indTransferTargetCat;
      if (_indTransferTargetCat == 'GroupSavings') {
        final grp = allGroups.firstWhere(
          (g) => g['group_id']?.toString() == destId,
          orElse: () => <String, dynamic>{},
        );
        destName = grp['name']?.toString() ?? grp['label']?.toString();
      } else {
        final cli = allClients.firstWhere(
          (c) => c['client_id']?.toString() == destId,
          orElse: () => <String, dynamic>{},
        );
        destName = cli['name']?.toString();
      }
    }

    final opDate = ref.read(withdrawalOpDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(opDate);
    final autoExec = (_isManager && ref.read(isOnlineProvider)) ? _indAutoExec : false;

    final payload = <String, dynamic>{
      'savings_type': 'Individual',
      'operation_type': _indDestOp,
      'client_id': cId,
      'client_name': cName,
      'loan_id': _indDestOp == 'Loan Repayment / Asset Debt Offset' ? _indSelectedLoanId : null,
      'destination_id': destId,
      'destination_name': destName,
      'destination_type': destType,
      'fee_type': _indDestOp == 'Fee Payment from Savings' ? _indFeeType : null,
      'amount': amt,
      'operational_date': dateStr,
      'payout_method': _indDestOp == 'Client Bank Account (Transfer)' ? 'Bank Transfer' : 'Cash',
      'remarks': _indRemarksCtrl.text.trim(),
      'auto_execute': autoExec,
      'idempotency_key': _getAttemptIdemKey('ind'),
    };

    await _submitOrQueueWithdrawalRequest(
      payload: payload,
      displayLabel: cName,
      attemptKey: 'ind',
      autoExecuteRequested: autoExec,
      onCleared: () {
        _indAmountCtrl.clear();
        _indRemarksCtrl.clear();
      },
      onlineDefaultMessage: 'Withdrawal request submitted successfully!',
    );
  }

  // ==========================================================================
  // TAB 2: GROUP SAVINGS SUBMISSION
  // ==========================================================================
  Future<void> _submitGroupWithdrawal(
    Map<String, dynamic> grpData, {
    required List<Map<String, dynamic>> allClients,
    required List<Map<String, dynamic>> allGroups,
  }) async {
    final amt = double.tryParse(_grpAmountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final bal = (grpData['savings_balance'] as num?)?.toDouble() ?? 0.0;
    final gId = grpData['group_id']?.toString() ?? '';
    final gName = grpData['name']?.toString() ?? 'Group';

    if (amt <= 0) {
      _showFlash('Amount must be greater than zero.', isSuccess: false);
      return;
    }
    if (amt > bal + 0.01) {
      _showFlash('Insufficient group balance. Available: ${CurrencyFormatter.formatNaira(bal)}', isSuccess: false);
      return;
    }
    final grpMembers = (grpData['members'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    if (_grpDestOp.contains('Loan Repayment')) {
      if (_grpSelectedMemberId == null || _grpSelectedLoanId == null || _grpSelectedLoanId!.isEmpty) {
        _showFlash('Select a member and eligible loan for debt offset.', isSuccess: false);
        return;
      }
      final selMem = grpMembers.firstWhere(
        (m) => m['client_id']?.toString() == _grpSelectedMemberId,
        orElse: () => <String, dynamic>{},
      );
      final mLoans = (selMem['eligible_loans'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((l) => Map<String, dynamic>.from(l))
          .toList();
      final targetLoan = mLoans.firstWhere(
        (l) => l['loan_id']?.toString() == _grpSelectedLoanId,
        orElse: () => <String, dynamic>{},
      );
      final loanBal = (targetLoan['balance'] as num?)?.toDouble();
      if (loanBal != null && amt > loanBal + 0.01) {
        _showFlash(
          'Offset amount exceeds member remaining loan balance of ${CurrencyFormatter.formatNaira(loanBal)}.',
          isSuccess: false,
        );
        return;
      }
    }
    if (_grpDestOp == 'Another Member or Group Savings' && (_grpTransferRecipientId == null || _grpTransferRecipientId!.isEmpty)) {
      _showFlash('Select a transfer destination.', isSuccess: false);
      return;
    }
    if (_grpDestOp.contains('LAPS Reserve') && (_grpLapsBeneficiaryClientId == null || _grpLapsBeneficiaryClientId!.isEmpty)) {
      _showFlash('Select a beneficiary group member for LAPS protection transfer.', isSuccess: false);
      return;
    }

    String? destId;
    String? destName;
    String? destType;
    String? reqClientId;
    String? reqClientName = gName;

    if (_grpDestOp.contains('Loan Repayment')) {
      destId = _grpSelectedLoanId;
      destType = 'Loan';
      reqClientId = _grpSelectedMemberId;
    } else if (_grpDestOp.contains('Fee Payment')) {
      if (_grpSelectedMemberId != null && _grpSelectedMemberId!.isNotEmpty) {
        final feeMem = grpMembers.firstWhere(
          (m) => m['client_id']?.toString() == _grpSelectedMemberId,
          orElse: () => <String, dynamic>{},
        );
        reqClientId = _grpSelectedMemberId;
        destId = _grpSelectedMemberId;
        destName = feeMem['name']?.toString();
        destType = 'Member';
      }
    } else if (_grpDestOp == 'Another Member or Group Savings') {
      destId = _grpTransferRecipientId;
      destType = _grpTransferTargetCat;
      if (_grpTransferTargetCat == 'GroupSavings') {
        final grp = allGroups.firstWhere(
          (g) => g['group_id']?.toString() == destId,
          orElse: () => <String, dynamic>{},
        );
        destName = grp['name']?.toString() ?? grp['label']?.toString();
      } else {
        final cli = allClients.firstWhere(
          (c) => c['client_id']?.toString() == destId,
          orElse: () => <String, dynamic>{},
        );
        destName = cli['name']?.toString();
      }
    } else if (_grpDestOp.contains('LAPS Reserve')) {
      reqClientId = _grpLapsBeneficiaryClientId;
      reqClientName = _grpLapsBeneficiaryClientName ?? gName;
      destId = _grpLapsBeneficiaryClientId;
      destName = _grpLapsBeneficiaryClientName;
      destType = 'LAPS';
    }

    final opDate = ref.read(withdrawalOpDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(opDate);
    final autoExec = (_isManager && ref.read(isOnlineProvider)) ? _grpAutoExec : false;

    final payload = <String, dynamic>{
      'savings_type': 'Group',
      'operation_type': _grpDestOp,
      'client_id': reqClientId,
      'client_name': reqClientName,
      'group_id': gId,
      'group_name': gName,
      'loan_id': _grpDestOp.contains('Loan Repayment') ? _grpSelectedLoanId : null,
      'destination_id': destId,
      'destination_name': destName,
      'destination_type': destType,
      'fee_type': _grpDestOp.contains('Fee Payment') ? _grpFeeType : null,
      'amount': amt,
      'operational_date': dateStr,
      'payout_method': _grpDestOp == 'Group Bank Account (Transfer)' ? 'Bank Transfer' : 'Cash',
      'remarks': _grpRemarksCtrl.text.trim(),
      'auto_execute': autoExec,
      'idempotency_key': _getAttemptIdemKey('grp'),
    };

    await _submitOrQueueWithdrawalRequest(
      payload: payload,
      displayLabel: gName,
      attemptKey: 'grp',
      autoExecuteRequested: autoExec,
      onCleared: () {
        _grpAmountCtrl.clear();
        _grpRemarksCtrl.clear();
      },
      onlineDefaultMessage: 'Group withdrawal request submitted successfully!',
    );
  }

  // ==========================================================================
  // TAB 3: MISC SAVINGS SUBMISSION (BRANCH MANAGER / DESIGNATED OFFICER)
  // ==========================================================================
  Future<void> _submitMiscWithdrawal(double bal) async {
    final amt = double.tryParse(_miscAmountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    if (amt <= 0) {
      _showFlash('Withdrawal amount must be greater than zero.', isSuccess: false);
      return;
    }
    if (amt > bal + 0.01) {
      _showFlash('Insufficient Misc pool balance. Available: ${CurrencyFormatter.formatNaira(bal)}', isSuccess: false);
      return;
    }

    final opDate = ref.read(withdrawalOpDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(opDate);
    final opType = _miscPayoutMethod == 'Bank Transfer' ? 'Bank Transfer' : 'Cash Withdrawal';
    final autoExec = (_isManager && ref.read(isOnlineProvider)) ? _miscAutoExec : false;

    final payload = <String, dynamic>{
      'savings_type': 'Misc',
      'operation_type': opType,
      'amount': amt,
      'operational_date': dateStr,
      'payout_method': _miscPayoutMethod,
      'remarks': _miscRemarksCtrl.text.trim(),
      'auto_execute': autoExec,
      'idempotency_key': _getAttemptIdemKey('misc'),
    };

    await _submitOrQueueWithdrawalRequest(
      payload: payload,
      displayLabel: 'Branch Misc Savings',
      attemptKey: 'misc',
      autoExecuteRequested: autoExec,
      onCleared: () {
        _miscAmountCtrl.clear();
        _miscRemarksCtrl.clear();
      },
      onlineDefaultMessage: 'Misc savings withdrawal processed successfully!',
    );
  }

  // ==========================================================================
  // TAB 4: LAPS PAYOUT SUBMISSION
  // ==========================================================================
  Future<void> _submitLapsPayout(Map<String, dynamic> lapsRec) async {
    final amt = double.tryParse(_lapsAmountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final bal = (lapsRec['balance'] as num?)?.toDouble() ?? 0.0;
    final cId = lapsRec['client_id']?.toString() ?? '';
    final cName = lapsRec['client_name']?.toString();

    if (amt <= 0) {
      _showFlash('Payout amount must be greater than zero.', isSuccess: false);
      return;
    }
    if (amt > bal + 0.01) {
      _showFlash('Insufficient LAPS balance. Available: ${CurrencyFormatter.formatNaira(bal)}', isSuccess: false);
      return;
    }

    final opDate = ref.read(withdrawalOpDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(opDate);
    final isReturn = _lapsPayoutMethod == 'Return to Savings';
    final autoExec = (_isManager && ref.read(isOnlineProvider)) ? _lapsAutoExec : false;

    final payload = <String, dynamic>{
      'savings_type': 'LAPS',
      'operation_type': isReturn ? 'LAPS Return to Customer Savings' : 'LAPS Payout',
      'client_id': cId,
      'client_name': cName,
      'amount': amt,
      'operational_date': dateStr,
      'payout_method': _lapsPayoutMethod,
      'remarks': _lapsRemarksCtrl.text.trim(),
      'auto_execute': autoExec,
      'idempotency_key': _getAttemptIdemKey('laps'),
    };

    await _submitOrQueueWithdrawalRequest(
      payload: payload,
      displayLabel: cName ?? 'LAPS Account',
      attemptKey: 'laps',
      autoExecuteRequested: autoExec,
      onCleared: () {
        _lapsAmountCtrl.clear();
        _lapsRemarksCtrl.clear();
      },
      onlineDefaultMessage: 'LAPS payout submitted successfully!',
    );
  }

  // ==========================================================================
  // TAB 5 (BM ONLY): APPROVE / REJECT ACTIONS
  // ==========================================================================
  Future<void> _approveRequest(String reqId) async {
    if (!ref.read(isOnlineProvider)) {
      _showFlash('Live server connection is required to approve withdrawals.', isSuccess: false);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final res = await api.approveWithdrawal(reqId);
      _showFlash(res['message']?.toString() ?? 'Withdrawal approved successfully!');
      _invalidateAfterWithdrawalMutation();
    } catch (e) {
      _showFlash(AppErrorDetails.from(e).message, isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmRejectRequest(String reqId) async {
    if (!ref.read(isOnlineProvider)) {
      _showFlash('Live server connection is required to reject withdrawal requests.', isSuccess: false);
      return;
    }
    final reason = _rejectReasonCtrl.text.trim();
    if (reason.isEmpty) {
      _showFlash('Please specify a rejection reason.', isSuccess: false);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final res = await api.rejectWithdrawal(reqId, reason);
      _showFlash(res['message']?.toString() ?? 'Withdrawal rejected successfully.');
      setState(() {
        _rejectingRequestId = null;
        _rejectReasonCtrl.clear();
      });
      _invalidateAfterWithdrawalMutation();
    } catch (e) {
      _showFlash(AppErrorDetails.from(e).message, isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildOfflineNoticeBanner(IcareSurfaceTokens tokens, {required bool isManager}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.warningBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: tokens.warningDot),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Mode · Cached Balances',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.warningText),
                ),
                const SizedBox(height: 2),
                Text(
                  isManager
                      ? 'Approvals, rejections, and immediate cash payouts require a live connection. Offline submissions are queued strictly as unapproved review requests.'
                      : 'Withdrawal requests entered offline will be queued safely on this device and sent for Manager approval once your connection returns. Do not disburse cash yet.',
                  style: TextStyle(fontSize: 11.5, color: tokens.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoExecCheckbox({
    required bool value,
    required bool isOnline,
    required IcareSurfaceTokens tokens,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        'Immediate Branch Manager Authorization',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isOnline ? tokens.textPrimary : tokens.textMuted,
        ),
      ),
      subtitle: Text(
        isOnline
            ? 'Authorize and settle immediately without queuing for review.'
            : 'Unavailable offline. Connect to internet to authorize immediate payout.',
        style: TextStyle(fontSize: 11, color: tokens.textMuted),
      ),
      value: isOnline && value,
      activeColor: tokens.brandPrimary,
      onChanged: isOnline ? onChanged : null,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final role = user?.role ?? 'Credit Officer';
    final isCo = role == 'Credit Officer' || role == 'CO' || role == 'Officer';
    final isBm = role == 'Branch Manager' || role == 'BM';
    if (!isCo && !isBm) {
      final tokens = IcareSurfaceTokens.of(context);
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.dangerBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline_rounded, size: 28, color: tokens.dangerText),
              ),
              const SizedBox(height: 16),
              Text(
                'Withdrawal Operations Restricted',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Withdrawal requests and approvals are restricted to Credit Officers and Branch Managers for branch vault control.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: tokens.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }
    final isManager = isBm;
    final isOnline = ref.watch(isOnlineProvider);

    final activeTab = ref.watch(withdrawalTabProvider);
    final opDate = ref.watch(withdrawalOpDateProvider);
    final pendingAsync = isManager ? ref.watch(pendingApprovalsProvider) : null;
    final pendingCount = pendingAsync?.value?['requests'] is List ? (pendingAsync!.value!['requests'] as List).length : 0;

    final tabs = isManager
        ? [
            'Individual Savings',
            'Group Savings',
            'Misc Savings',
            'LAPS Savings',
            'Pending Approvals ($pendingCount)',
            'Daily Withdrawals'
          ]
        : [
            'Individual Savings',
            'Group Savings',
            'Misc Savings',
            'LAPS Savings',
            'Daily Withdrawals'
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Executive Cockpit Header (Gradient & Date Capsule)
        _buildExecutiveWithdrawalCockpit(
          isManager: isManager,
          opDate: opDate,
          onChangeDate: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: opDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              ref.read(withdrawalManualOpDateProvider.notifier).state = picked;
            }
          },
        ),

        if (!isOnline) _buildOfflineNoticeBanner(IcareSurfaceTokens.of(context), isManager: isManager),
        const SizedBox(height: 8),

        // 2. Flash Banner
        if (_flashMessage != null) ...[
          _buildFlashBanner(),
          const SizedBox(height: 16),
        ],

        // 3. Tactile 6-Pill Segmented Navigation Bar
        _buildTactileTabsBar(
          tabs: tabs,
          activeTab: activeTab,
          onSelectTab: (t) => ref.read(withdrawalTabProvider.notifier).state = t,
        ),
        const SizedBox(height: 20),

        // 4. Active Tab View
        if (activeTab == 'Individual Savings')
          _buildIndividualTab(isManager)
        else if (activeTab == 'Group Savings')
          _buildGroupTab(isManager)
        else if (activeTab == 'Misc Savings')
          _buildMiscTab(isManager)
        else if (activeTab == 'LAPS Savings')
          _buildLapsTab(isManager)
        else if (activeTab.startsWith('Pending Approvals'))
          _buildPendingApprovalsTab()
        else
          _buildDailyWithdrawalsTab(isManager),
      ],
    );
  }

  // ==========================================================================
  // TAB 1 BUILDER: INDIVIDUAL SAVINGS (app.py L7324–7645)
  // ==========================================================================
  Widget _buildIndividualTab(bool isManager) {
    final tokens = IcareSurfaceTokens.of(context);
    final isOnline = ref.watch(isOnlineProvider);
    final indAsync = ref.watch(individualOptionsProvider);

    return indAsync.when(
      loading: () => const IcareFormSkeleton(fieldCount: 4),
      error: (err, _) => _buildErrorCard(AppErrorDetails.from(err).message, () => ref.refresh(individualOptionsProvider)),
      data: (data) {
        final groups = (data['groups'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['All Groups'];
        final allGroups = (data['all_groups'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        final allClients = (data['clients'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

        // Filter clients by group
        final filteredClients = allClients.where((c) {
          if (_indGroupFilter == 'All Groups') return true;
          final gName = c['group_name']?.toString() ?? 'Ungrouped';
          return gName == _indGroupFilter || _indGroupFilter.startsWith(gName);
        }).toList();

        if (filteredClients.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Center(
              child: Text('No active clients found for the selected group.', style: TextStyle(color: tokens.textMuted, fontSize: 13)),
            ),
          );
        }

        // Selected client
        if (_indSelectedClientId == null || !filteredClients.any((c) => c['client_id'] == _indSelectedClientId)) {
          _indSelectedClientId = filteredClients.first['client_id']?.toString();
        }
        final selClient = filteredClients.firstWhere(
          (c) => c['client_id'] == _indSelectedClientId,
          orElse: () => filteredClients.first,
        );

        final bal = (selClient['savings_balance'] as num?)?.toDouble() ?? 0.0;
        final loans = ((selClient['eligible_loans'] as List<dynamic>?)
                    ?.map((e) => Map<String, dynamic>.from(e as Map))
                    .toList() ??
                [])
            .where((l) => (l['status']?.toString().trim().toLowerCase() ?? '') != 'pending')
            .toList();

        // Selected loan
        if (loans.isNotEmpty) {
          if (_indSelectedLoanId == null || !loans.any((l) => l['loan_id'] == _indSelectedLoanId)) {
            _indSelectedLoanId = loans.first['loan_id']?.toString();
          }
        } else {
          _indSelectedLoanId = null;
        }
        Map<String, dynamic>? selLoan = loans.isNotEmpty ? loans.firstWhere((l) => l['loan_id'] == _indSelectedLoanId, orElse: () => loans.first) : null;

        final List<DropdownMenuItem<String>> validIndTransferItems =
            _indDestOp != 'Another Member or Group Savings'
                ? const []
                : (_indTransferTargetCat == 'GroupSavings'
                    ? allGroups
                        .map((g) => DropdownMenuItem<String>(
                              value: g['group_id']?.toString(),
                              child: Text(
                                (g['label'] ?? g['name'] ?? 'Group').toString(),
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ))
                        .toList()
                    : allClients
                        .where((c) => c['client_id']?.toString() != _indSelectedClientId)
                        .map((c) => DropdownMenuItem<String>(
                              value: c['client_id']?.toString(),
                              child: Text(
                                '${c['name']} (${c['client_code']})',
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ))
                        .toList());
        final safeIndTransferVal = validIndTransferItems.any((i) => i.value == _indTransferRecipientId)
            ? _indTransferRecipientId
            : null;

        return _buildFormCard(
          title: 'Individual Savings Withdrawal',
          icon: Icons.person_rounded,
          children: [
            // 1. Group & Client Selectors
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 550;
                final grpField = DropdownButtonFormField<String>(
                  value: _indGroupFilter,
                  isExpanded: true,
                  dropdownColor: tokens.surfaceElevated,
                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Group Filter',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis, softWrap: true))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _indGroupFilter = val;
                        _indSelectedClientId = null;
                        _indSelectedLoanId = null;
                        _clearAttemptIdemKey('ind');
                      });
                    }
                  },
                );

                final clientField = DropdownButtonFormField<String>(
                  value: _indSelectedClientId,
                  isExpanded: true,
                  dropdownColor: tokens.surfaceElevated,
                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Select Member',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: filteredClients.map((c) {
                    final label = '${c['name']} (${c['client_code']})';
                    return DropdownMenuItem(value: c['client_id']?.toString(), child: Text(label, overflow: TextOverflow.ellipsis, softWrap: true));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _indSelectedClientId = val;
                        _indSelectedLoanId = null;
                        _clearAttemptIdemKey('ind');
                      });
                    }
                  },
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      grpField,
                      const SizedBox(height: 8),
                      clientField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 2, child: grpField),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: clientField),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),

            // 2. Compact Inline Balance Strip
            _buildInlineBalanceStrip(
              label: selClient['name']?.toString() ?? 'Client',
              balance: bal,
              tag: selClient['client_code']?.toString(),
              subtitle: selClient['group_name']?.toString() ?? 'Ungrouped',
            ),
            const SizedBox(height: 12),

            // 3. Compact Destination Dropdown
            DropdownButtonFormField<String>(
              value: _indDestOp,
              isExpanded: true,
              dropdownColor: tokens.surfaceElevated,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Destination',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _indDestOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt['value'] as String,
                  child: Text(
                    opt['title'] as String,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _indDestOp = val);
              },
            ),
            const SizedBox(height: 10),

            // 4. Conditional Destination Fields
            if (_indDestOp == 'Loan Repayment / Asset Debt Offset') ...[
              if (loans.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.warningBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.warningBorder),
                  ),
                  child: Text('No active loans found for this client to offset.', style: TextStyle(color: tokens.warningText, fontSize: 12), softWrap: true),
                )
              else ...[
                DropdownButtonFormField<String>(
                  value: _indSelectedLoanId,
                  isExpanded: true,
                  dropdownColor: tokens.surfaceElevated,
                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Target Loan for Debt Offset',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: loans.map((l) {
                    final lbl = l['label']?.toString() ?? 'Loan ${l['loan_id']?.toString().substring(0, 8)}';
                    return DropdownMenuItem(value: l['loan_id']?.toString(), child: Text(lbl, overflow: TextOverflow.ellipsis, softWrap: true));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _indSelectedLoanId = val);
                  },
                ),
                if (selLoan != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          'Loan Balance',
                          CurrencyFormatter.formatNaira((selLoan['balance'] as num?)?.toDouble() ?? 0.0),
                          tokens.dangerText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile(
                          'Active Credit',
                          CurrencyFormatter.formatNaira((selLoan['active_credit'] as num?)?.toDouble() ?? 0.0),
                          tokens.infoText,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 10),
            ] else if (_indDestOp == 'Fee Payment from Savings') ...[
              DropdownButtonFormField<String>(
                value: _indFeeType,
                isExpanded: true,
                dropdownColor: tokens.surfaceElevated,
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Fee Type',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'credit_form_damage', child: Text('Credit Form Damage Fee', softWrap: true)),
                  DropdownMenuItem(value: 'passbook', child: Text('Passbook Fee', softWrap: true)),
                  DropdownMenuItem(value: 'app_fee', child: Text('Application Fee', softWrap: true)),
                  DropdownMenuItem(value: 'misc_fees', child: Text('Misc Fee / Penalty', softWrap: true)),
                  DropdownMenuItem(value: 'other', child: Text('Other Fee / Shortfall', softWrap: true)),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _indFeeType = val);
                },
              ),
              const SizedBox(height: 10),
            ] else if (_indDestOp == 'Another Member or Group Savings') ...[
              DropdownButtonFormField<String>(
                value: _indTransferTargetCat,
                isExpanded: true,
                dropdownColor: tokens.surfaceElevated,
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Transfer Destination Type',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'IndividualSavings', child: Text('Another Client Savings Account')),
                  DropdownMenuItem(value: 'GroupSavings', child: Text('Group Collective Savings Account')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _indTransferTargetCat = val;
                      _indTransferRecipientId = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: safeIndTransferVal,
                isExpanded: true,
                dropdownColor: tokens.surfaceElevated,
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                decoration: InputDecoration(
                  labelText: _indTransferTargetCat == 'GroupSavings' ? 'Recipient Group Account' : 'Recipient Member',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: validIndTransferItems,
                onChanged: (val) {
                  if (val != null) setState(() => _indTransferRecipientId = val);
                },
              ),
              const SizedBox(height: 10),
            ],

            // 5. Amount Input & Quick Presets
            _buildAmountPresetChips(availableBalance: bal, controller: _indAmountCtrl),
            const SizedBox(height: 8),

            TextField(
              controller: _indAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Withdrawal Amount (₦)',
                hintText: 'Enter amount...',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // 6. Remarks
            TextField(
              controller: _indRemarksCtrl,
              maxLines: 1,
              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Remarks & Authorization Notes',
                hintText: 'Reason or account details...',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // 7. Manager Direct Posting Toggle
            if (isManager) ...[
              _buildAutoExecCheckbox(
                value: _indAutoExec,
                isOnline: isOnline,
                tokens: tokens,
                onChanged: (v) => setState(() => _indAutoExec = v ?? false),
              ),
              const SizedBox(height: 10),
            ],

            // 8. Submit Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isOnline && isManager && _indAutoExec) ? const Color(0xFF15803D) : tokens.brandPrimaryDark,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: tokens.surfaceSubtle,
                  disabledForegroundColor: tokens.textMuted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon((isOnline && isManager && _indAutoExec) ? Icons.verified_rounded : Icons.send_rounded, size: 16),
                label: Text(
                  _isSubmitting
                      ? 'Processing...'
                      : !isOnline
                          ? 'Queue Request Offline'
                          : (isManager && _indAutoExec)
                              ? 'Authorize & Settle Withdrawal'
                              : 'Submit for BM Approval',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  softWrap: true,
                ),
                onPressed: _isSubmitting
                    ? null
                    : () => _submitIndividualWithdrawal(
                          selClient,
                          allClients: allClients,
                          allGroups: allGroups,
                        ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // TAB 2 BUILDER: GROUP SAVINGS
  // ==========================================================================
  Widget _buildGroupTab(bool isManager) {
    final tokens = IcareSurfaceTokens.of(context);
    final isOnline = ref.watch(isOnlineProvider);
    final grpAsync = ref.watch(groupOptionsProvider);
    final needsClientRecipients =
        _grpDestOp == 'Another Member or Group Savings' && _grpTransferTargetCat != 'GroupSavings';
    final indVal = needsClientRecipients ? ref.watch(individualOptionsProvider).valueOrNull : null;
    final allClients = (indVal?['clients'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    return grpAsync.when(
      loading: () => const IcareFormSkeleton(fieldCount: 4),
      error: (err, _) => _buildErrorCard(AppErrorDetails.from(err).message, () => ref.refresh(groupOptionsProvider)),
      data: (data) {
        final groups = (data['groups'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
        final allGroups = ((data['all_groups'] ?? data['groups']) as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];

        if (groups.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Center(
              child: Text('No active groups found for the selected officer.', style: TextStyle(color: tokens.textMuted, fontSize: 13)),
            ),
          );
        }

        if (_grpSelectedGroupId == null || !groups.any((g) => g['group_id'] == _grpSelectedGroupId)) {
          _grpSelectedGroupId = groups.first['group_id']?.toString();
        }
        final selGrp = groups.firstWhere((g) => g['group_id'] == _grpSelectedGroupId, orElse: () => groups.first);
        final gId = selGrp['group_id']?.toString() ?? '';
        final bal = (selGrp['savings_balance'] as num?)?.toDouble() ?? 0.0;
        final members = (selGrp['members'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];

        if (members.isNotEmpty) {
          if (_grpSelectedMemberId == null || !members.any((m) => m['client_id']?.toString() == _grpSelectedMemberId)) {
            _grpSelectedMemberId = members.first['client_id']?.toString();
          }
          if (_grpLapsBeneficiaryClientId == null || !members.any((m) => m['client_id']?.toString() == _grpLapsBeneficiaryClientId)) {
            _grpLapsBeneficiaryClientId = members.first['client_id']?.toString();
            _grpLapsBeneficiaryClientName = members.first['name']?.toString();
          }
        } else {
          _grpSelectedMemberId = null;
          _grpSelectedLoanId = null;
          _grpLapsBeneficiaryClientId = null;
          _grpLapsBeneficiaryClientName = null;
        }

        final Map<String, dynamic>? selMember = members.isNotEmpty
            ? members.firstWhere((m) => m['client_id']?.toString() == _grpSelectedMemberId, orElse: () => members.first)
            : null;
        final memberLoans = ((selMember?['eligible_loans'] as List<dynamic>?)
                    ?.map((e) => Map<String, dynamic>.from(e as Map))
                    .toList() ??
                [])
            .where((l) => (l['status']?.toString().trim().toLowerCase() ?? '') != 'pending')
            .toList();
        if (memberLoans.isNotEmpty) {
          if (_grpSelectedLoanId == null || !memberLoans.any((l) => l['loan_id']?.toString() == _grpSelectedLoanId)) {
            _grpSelectedLoanId = memberLoans.first['loan_id']?.toString();
          }
        } else {
          _grpSelectedLoanId = null;
        }
        final Map<String, dynamic>? selMemberLoan = memberLoans.isNotEmpty
            ? memberLoans.firstWhere((l) => l['loan_id']?.toString() == _grpSelectedLoanId, orElse: () => memberLoans.first)
            : null;

        final List<DropdownMenuItem<String>> validGrpTransferItems =
            _grpDestOp != 'Another Member or Group Savings'
                ? const []
                : (_grpTransferTargetCat == 'GroupSavings'
                    ? allGroups
                        .where((g) => g['group_id']?.toString() != gId)
                        .map((g) => DropdownMenuItem<String>(
                              value: g['group_id']?.toString(),
                              child: Text(
                                (g['label'] ?? g['name'] ?? 'Group').toString(),
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ))
                        .toList()
                    : allClients
                        .map((c) => DropdownMenuItem<String>(
                              value: c['client_id']?.toString(),
                              child: Text(
                                '${c['name']} (${c['client_code']})',
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ))
                        .toList());
        final safeGrpTransferVal = validGrpTransferItems.any((i) => i.value == _grpTransferRecipientId)
            ? _grpTransferRecipientId
            : null;
        final safeGrpDestOp = _grpDestOptions.any((o) => o['value'] == _grpDestOp)
            ? _grpDestOp
            : _grpDestOptions.first['value'] as String;

        return _buildFormCard(
          title: 'Group Savings Withdrawal',
          icon: Icons.groups_rounded,
          children: [
            // 1. Group Selector
            DropdownButtonFormField<String>(
              value: _grpSelectedGroupId,
              isExpanded: true,
              dropdownColor: tokens.surfaceElevated,
              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Select Group',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: groups.map((g) => DropdownMenuItem(value: g['group_id']?.toString(), child: Text(g['name']?.toString() ?? 'Group', overflow: TextOverflow.ellipsis, softWrap: true))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _grpSelectedGroupId = val;
                    _grpSelectedMemberId = null;
                    _grpSelectedLoanId = null;
                    _grpLapsBeneficiaryClientId = null;
                    _grpLapsBeneficiaryClientName = null;
                    _clearAttemptIdemKey('grp');
                  });
                }
              },
            ),
            const SizedBox(height: 10),

            // 2. Compact Inline Balance Strip
            _buildInlineBalanceStrip(
              label: selGrp['name']?.toString() ?? 'Group',
              balance: bal,
              tag: 'GROUP SAVINGS',
              subtitle: 'Joint Liability Account',
            ),
            const SizedBox(height: 12),

            // 3. Compact Destination Dropdown
            DropdownButtonFormField<String>(
              value: safeGrpDestOp,
              isExpanded: true,
              dropdownColor: tokens.surfaceElevated,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Destination',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _grpDestOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt['value'] as String,
                  child: Text(
                    opt['title'] as String,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _grpDestOp = val);
              },
            ),
            const SizedBox(height: 10),

            // 4. Conditional Destination Fields
            if (safeGrpDestOp.contains('Loan Repayment')) ...[
              if (members.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.warningBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.warningBorder),
                  ),
                  child: Text('No active members found in this group.', style: TextStyle(color: tokens.warningText, fontSize: 12)),
                )
              else ...[
                DropdownButtonFormField<String>(
                  value: members.any((m) => m['client_id']?.toString() == _grpSelectedMemberId) ? _grpSelectedMemberId : null,
                  isExpanded: true,
                  dropdownColor: tokens.surfaceElevated,
                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Select Group Member',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: members.map((m) {
                    return DropdownMenuItem<String>(
                      value: m['client_id']?.toString(),
                      child: Text('${m['name']} (${m['client_code']})', overflow: TextOverflow.ellipsis, softWrap: true),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _grpSelectedMemberId = val;
                        _grpSelectedLoanId = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                if (memberLoans.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: tokens.warningBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tokens.warningBorder),
                    ),
                    child: Text('No active loans found for the selected member to offset.', style: TextStyle(color: tokens.warningText, fontSize: 12)),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    value: memberLoans.any((l) => l['loan_id']?.toString() == _grpSelectedLoanId) ? _grpSelectedLoanId : null,
                    isExpanded: true,
                    dropdownColor: tokens.surfaceElevated,
                    style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Target Member Loan for Debt Offset',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: memberLoans.map((l) {
                      final lbl = l['label']?.toString() ?? 'Loan ${l['loan_id']?.toString().substring(0, 8)}';
                      return DropdownMenuItem<String>(value: l['loan_id']?.toString(), child: Text(lbl, overflow: TextOverflow.ellipsis, softWrap: true));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _grpSelectedLoanId = val);
                    },
                  ),
                  if (selMemberLoan != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            'Loan Balance',
                            CurrencyFormatter.formatNaira((selMemberLoan['balance'] as num?)?.toDouble() ?? 0.0),
                            tokens.dangerText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            'Active Credit',
                            CurrencyFormatter.formatNaira((selMemberLoan['active_credit'] as num?)?.toDouble() ?? 0.0),
                            tokens.infoText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
              const SizedBox(height: 10),
            ] else if (safeGrpDestOp.contains('Fee Payment')) ...[
              if (members.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: members.any((m) => m['client_id']?.toString() == _grpSelectedMemberId) ? _grpSelectedMemberId : null,
                  isExpanded: true,
                  dropdownColor: tokens.surfaceElevated,
                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Attribute Fee to Group Member (Optional)',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: members.map((m) {
                    return DropdownMenuItem<String>(
                      value: m['client_id']?.toString(),
                      child: Text('${m['name']} (${m['client_code']})', overflow: TextOverflow.ellipsis, softWrap: true),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _grpSelectedMemberId = val;
                      _clearAttemptIdemKey('grp');
                    });
                  },
                ),
                const SizedBox(height: 8),
              ],
              DropdownButtonFormField<String>(
                value: _grpFeeType,
                isExpanded: true,
                dropdownColor: tokens.surfaceElevated,
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Fee Type',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'credit_form_damage', child: Text('Credit Form Damage Fee')),
                  DropdownMenuItem(value: 'passbook', child: Text('Passbook Fee')),
                  DropdownMenuItem(value: 'app_fee', child: Text('Application Fee')),
                  DropdownMenuItem(value: 'misc_fees', child: Text('Misc Fee / Penalty')),
                  DropdownMenuItem(value: 'other', child: Text('Other Fee / Shortfall')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _grpFeeType = val);
                },
              ),
              const SizedBox(height: 10),
            ] else if (safeGrpDestOp == 'Another Member or Group Savings') ...[
              DropdownButtonFormField<String>(
                value: _grpTransferTargetCat,
                isExpanded: true,
                dropdownColor: tokens.surfaceElevated,
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Transfer Destination Type',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'IndividualSavings', child: Text('Individual Member Savings Account')),
                  DropdownMenuItem(value: 'GroupSavings', child: Text('Another Group Savings Account')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _grpTransferTargetCat = val;
                      _grpTransferRecipientId = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: safeGrpTransferVal,
                isExpanded: true,
                dropdownColor: tokens.surfaceElevated,
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                decoration: InputDecoration(
                  labelText: _grpTransferTargetCat == 'GroupSavings' ? 'Recipient Group Account' : 'Recipient Client',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: validGrpTransferItems,
                onChanged: (val) {
                  if (val != null) setState(() => _grpTransferRecipientId = val);
                },
              ),
              const SizedBox(height: 10),
            ] else if (safeGrpDestOp.contains('LAPS Reserve')) ...[
              DropdownButtonFormField<String>(
                value: members.any((m) => m['client_id']?.toString() == _grpLapsBeneficiaryClientId) ? _grpLapsBeneficiaryClientId : null,
                isExpanded: true,
                dropdownColor: tokens.surfaceElevated,
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Beneficiary Group Member (LAPS Record Holder)',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: members.map((m) {
                  return DropdownMenuItem<String>(
                    value: m['client_id']?.toString(),
                    child: Text('${m['name']} (${m['client_code']})', overflow: TextOverflow.ellipsis, softWrap: true),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final matched = members.firstWhere(
                      (m) => m['client_id']?.toString() == val,
                      orElse: () => <String, dynamic>{},
                    );
                    setState(() {
                      _grpLapsBeneficiaryClientId = val;
                      _grpLapsBeneficiaryClientName = matched['name']?.toString();
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
            ],

            // 5. Quick Amount Presets & Amount Input
            _buildAmountPresetChips(availableBalance: bal, controller: _grpAmountCtrl),
            const SizedBox(height: 8),

            TextField(
              controller: _grpAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Amount (₦)',
                hintText: 'Enter group withdrawal amount...',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // 6. Remarks
            TextField(
              controller: _grpRemarksCtrl,
              maxLines: 1,
              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Remarks & Group Resolution Notes',
                hintText: 'Resolution reference or details...',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // 7. BM Direct Authorization Toggle
            if (isManager) ...[
              _buildAutoExecCheckbox(
                value: _grpAutoExec,
                isOnline: isOnline,
                tokens: tokens,
                onChanged: (v) => setState(() => _grpAutoExec = v ?? false),
              ),
              const SizedBox(height: 10),
            ],

            // 8. Submit Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isOnline && isManager && _grpAutoExec) ? const Color(0xFF15803D) : tokens.brandPrimaryDark,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: tokens.surfaceSubtle,
                  disabledForegroundColor: tokens.textMuted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon((isOnline && isManager && _grpAutoExec) ? Icons.verified_rounded : Icons.send_rounded, size: 16),
                label: Text(
                  _isSubmitting
                      ? 'Processing...'
                      : !isOnline
                          ? 'Queue Request Offline'
                          : (isManager && _grpAutoExec)
                              ? 'Authorize & Settle Group Withdrawal'
                              : 'Submit for BM Approval',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  softWrap: true,
                ),
                onPressed: _isSubmitting
                    ? null
                    : () => _submitGroupWithdrawal(
                          selGrp,
                          allClients: allClients,
                          allGroups: allGroups,
                        ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // TAB 3 BUILDER: MISC SAVINGS
  // ==========================================================================
  Widget _buildMiscTab(bool isManager) {
    final tokens = IcareSurfaceTokens.of(context);
    final isOnline = ref.watch(isOnlineProvider);
    final miscAsync = ref.watch(miscBalanceProvider);

    return miscAsync.when(
      loading: () => const IcareFormSkeleton(fieldCount: 2),
      error: (err, _) => _buildErrorCard(AppErrorDetails.from(err).message, () => ref.refresh(miscBalanceProvider)),
      data: (data) {
        final bal = (data['misc_balance'] as num?)?.toDouble() ?? 0.0;
        final canWithdraw = (data['can_withdraw'] == true) || isManager;
        final roleNotice = data['role_notice']?.toString() ?? 'Misc Savings is managed by the Branch Manager.';

        return _buildFormCard(
          title: 'Branch Miscellaneous Savings',
          icon: Icons.savings_rounded,
          children: [
            _buildInlineBalanceStrip(
              label: 'Branch Misc Pool',
              balance: bal,
              tag: 'MISC POOL RESERVE',
              subtitle: data['branch']?.toString() ?? 'Protected Vault Cash Reserve',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: tokens.infoBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.infoBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: tokens.infoText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Branch Manager Governance',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.infoText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          roleNotice,
                          style: TextStyle(color: tokens.infoText.withValues(alpha: 0.9), fontSize: 11, height: 1.3),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (canWithdraw) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _miscPayoutMethod,
                isExpanded: true,
                dropdownColor: tokens.surfaceElevated,
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Payout Settlement Method',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Physical Vault Cash Payout')),
                  DropdownMenuItem(value: 'Bank Transfer', child: Text('Direct Bank Transfer Payout')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _miscPayoutMethod = val);
                },
              ),
              const SizedBox(height: 10),
              _buildAmountPresetChips(availableBalance: bal, controller: _miscAmountCtrl),
              const SizedBox(height: 8),
              TextField(
                controller: _miscAmountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Misc Withdrawal Amount (₦)',
                  hintText: 'Enter amount...',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _miscRemarksCtrl,
                maxLines: 1,
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Authorization Remarks',
                  hintText: 'Purpose or voucher reference...',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              if (isManager) ...[
                _buildAutoExecCheckbox(
                  value: _miscAutoExec,
                  isOnline: isOnline,
                  tokens: tokens,
                  onChanged: (v) => setState(() => _miscAutoExec = v ?? true),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (isOnline && isManager && _miscAutoExec) ? const Color(0xFF15803D) : tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: tokens.surfaceSubtle,
                    disabledForegroundColor: tokens.textMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon((isOnline && isManager && _miscAutoExec) ? Icons.verified_rounded : Icons.send_rounded, size: 16),
                  label: Text(
                    _isSubmitting
                        ? 'Processing...'
                        : !isOnline
                            ? 'Queue Request Offline'
                            : ((isManager && _miscAutoExec) ? 'Authorize & Settle Misc Withdrawal' : 'Submit Misc Withdrawal Request'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  onPressed: (_isSubmitting || bal <= 0) ? null : () => _submitMiscWithdrawal(bal),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ==========================================================================
  // TAB 4 BUILDER: LAPS SAVINGS
  // ==========================================================================
  Widget _buildLapsTab(bool isManager) {
    final tokens = IcareSurfaceTokens.of(context);
    final isOnline = ref.watch(isOnlineProvider);
    final lapsAsync = ref.watch(lapsOptionsProvider);

    return lapsAsync.when(
      loading: () => const IcareTableSkeleton(rowCount: 6, hasFilterBar: false),
      error: (err, _) => _buildErrorCard(AppErrorDetails.from(err).message, () => ref.refresh(lapsOptionsProvider)),
      data: (data) {
        final records = (data['records'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

        if (records.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Center(
              child: Text(
                'No LAPS savings records found for payout. LAPS records are created for closed clients and groups.',
                style: TextStyle(color: tokens.textMuted, fontSize: 13),
              ),
            ),
          );
        }

        if (_selectedLapsClientId == null || !records.any((r) => r['client_id'] == _selectedLapsClientId)) {
          _selectedLapsClientId = records.first['client_id']?.toString();
        }
        final selLaps = records.firstWhere((r) => r['client_id'] == _selectedLapsClientId, orElse: () => records.first);
        final bal = (selLaps['balance'] as num?)?.toDouble() ?? 0.0;

        return _buildFormCard(
          title: 'LAPS Savings Payout',
          icon: Icons.shield_rounded,
          children: [
            // 1. Record Selector
            DropdownButtonFormField<String>(
              value: _selectedLapsClientId,
              isExpanded: true,
              dropdownColor: tokens.surfaceElevated,
              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Select LAPS Record',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: records.map((r) {
                final cid = r['client_id']?.toString() ?? '';
                final b = (r['balance'] as num?)?.toDouble() ?? 0.0;
                final cName = r['client_name']?.toString();
                final cCode = r['client_code']?.toString();
                final fallbackShort = cid.length > 8 ? cid.substring(0, 8) : cid;
                final displayName = (cName != null && cName.isNotEmpty)
                    ? (cCode != null && cCode.isNotEmpty ? '$cName ($cCode)' : cName)
                    : 'Client $fallbackShort';
                return DropdownMenuItem(
                  value: cid,
                  child: Text('$displayName — ${CurrencyFormatter.formatNaira(b)}', overflow: TextOverflow.ellipsis, softWrap: true),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedLapsClientId = val);
              },
            ),
            const SizedBox(height: 10),

            // 2. Compact Inline Balance Strip
            _buildInlineBalanceStrip(
              label: (selLaps['client_name']?.toString().isNotEmpty ?? false)
                  ? selLaps['client_name'].toString()
                  : 'LAPS Protection Balance',
              balance: bal,
              tag: (selLaps['client_code']?.toString().isNotEmpty ?? false)
                  ? selLaps['client_code'].toString()
                  : 'CLOSED CLIENT RESERVE',
              subtitle: 'Protected Savings Liability',
            ),
            const SizedBox(height: 12),

            // 3. Modern 3-Option Payout / Restoration Selector (Rule 10 & 12 compliant)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 640;
                final options = [
                  {
                    'id': 'Cash',
                    'title': 'Cash Payout',
                    'subtitle': 'Physical cash disbursement from vault cash',
                  },
                  {
                    'id': 'Bank Transfer',
                    'title': 'Bank Wire',
                    'subtitle': 'Electronic transfer payout to client account',
                  },
                  {
                    'id': 'Return to Savings',
                    'title': 'Return to Customer Savings',
                    'subtitle': 'Restore balance to client savings & re-activate account (Zero cash impact)',
                  },
                ];

                final tiles = options.map((opt) {
                  final isSelected = _lapsPayoutMethod == opt['id'];
                  return InkWell(
                    onTap: () => setState(() => _lapsPayoutMethod = opt['id']!),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? tokens.successBg : tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? tokens.successBorder : tokens.borderStrong,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? tokens.brandPrimary : tokens.textMuted,
                                    width: isSelected ? 4 : 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  opt['title']!,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? tokens.successText : tokens.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            opt['subtitle']!,
                            style: TextStyle(fontSize: 10.5, color: tokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList();

                if (isNarrow) {
                  return Column(
                    children: tiles.map((t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: t)).toList(),
                  );
                }

                return Row(
                  children: tiles.map((t) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: t))).toList(),
                );
              },
            ),
            const SizedBox(height: 10),

            // 4. Quick Amount Presets & Amount Input
            _buildAmountPresetChips(availableBalance: bal, controller: _lapsAmountCtrl),
            const SizedBox(height: 8),

            TextField(
              controller: _lapsAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Payout Amount (₦)',
                hintText: 'Enter amount...',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // 5. Remarks
            TextField(
              controller: _lapsRemarksCtrl,
              maxLines: 1,
              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Remarks & Client Verification',
                hintText: 'Identity notes or details...',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // 6. BM Direct Authorization Toggle
            if (isManager) ...[
              _buildAutoExecCheckbox(
                value: _lapsAutoExec,
                isOnline: isOnline,
                tokens: tokens,
                onChanged: (v) => setState(() => _lapsAutoExec = v ?? false),
              ),
              const SizedBox(height: 10),
            ],

            // 7. Submit Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isOnline && isManager && _lapsAutoExec) ? const Color(0xFF15803D) : tokens.brandPrimaryDark,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: tokens.surfaceSubtle,
                  disabledForegroundColor: tokens.textMuted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon((isOnline && isManager && _lapsAutoExec) ? Icons.verified_rounded : Icons.send_rounded, size: 16),
                label: Text(
                  _isSubmitting
                      ? 'Processing...'
                      : !isOnline
                          ? 'Queue Request Offline'
                          : (_lapsPayoutMethod == 'Return to Savings')
                              ? ((isManager && _lapsAutoExec)
                                  ? 'Authorize & Restore Balance to Customer Savings'
                                  : 'Submit LAPS Restoration for BM Approval')
                              : ((isManager && _lapsAutoExec)
                                  ? 'Authorize & Settle LAPS Payout'
                                  : 'Submit LAPS Payout for BM Approval'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  softWrap: true,
                ),
                onPressed: _isSubmitting ? null : () => _submitLapsPayout(selLaps),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // TAB 5 BUILDER: PENDING APPROVALS (BM ONLY)
  // ==========================================================================
  Widget _buildPendingApprovalsTab() {
    final tokens = IcareSurfaceTokens.of(context);
    final isOnline = ref.watch(isOnlineProvider);
    final pendingAsync = ref.watch(pendingApprovalsProvider);

    return pendingAsync.when(
      loading: () => const IcareTableSkeleton(rowCount: 4, hasFilterBar: false),
      error: (err, _) => _buildErrorCard(
        AppErrorDetails.from(err).message,
        () => ref.refresh(pendingApprovalsProvider),
      ),
      data: (data) {
        final rawPending = (data['requests'] ?? data['pending_requests']) as List<dynamic>?;
        final pendingList = rawPending
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];

        if (pendingList.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: tokens.successBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: tokens.successBorder),
                  ),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 28,
                    color: tokens.successDot,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'All Caught Up',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'There are no withdrawal requests pending Branch Manager review or authorization.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: tokens.textMuted),
                ),
              ],
            ),
          );
        }

        final actorLow = _currentUsername.toLowerCase();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: tokens.dangerBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.dangerBorder),
                  ),
                  child: Icon(
                    Icons.gavel_rounded,
                    size: 16,
                    color: tokens.dangerDot,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Authorizations (${pendingList.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                        softWrap: true,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Review submitted withdrawal requests for approval or rejection.',
                        style: TextStyle(fontSize: 11, color: tokens.textMuted),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...pendingList.map((req) {
              final reqId = req['id']?.toString() ?? '';
              final clientName = req['client_name']?.toString() ?? 'Unknown Client';
              final clientCode = req['client_code']?.toString() ?? '';
              final groupName = req['group_name']?.toString() ?? '';
              final savingsType = req['savings_type']?.toString() ?? 'Savings';
              final opType = req['operation_type']?.toString() ?? 'Withdrawal';
              final amt = (req['amount'] as num?)?.toDouble() ?? 0.0;
              final reqBy = req['requested_by']?.toString() ?? 'Credit Officer';
              final isSelfRequested = actorLow.isNotEmpty && reqBy.trim().toLowerCase() == actorLow;
              final opDate = req['operational_date']?.toString() ?? '';
              final remarks = _cleanRemarks(req['remarks']);
              final isRejecting = _rejectingRequestId == reqId;

              final initials = clientName.trim().isNotEmpty
                  ? clientName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                  : 'CL';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isRejecting ? tokens.dangerBorder : tokens.borderSubtle,
                    width: isRejecting ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: tokens.isDark ? 0.18 : 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 600;
                        final headerLeft = Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: tokens.brandSoftBg,
                              child: Text(
                                initials,
                                style: TextStyle(
                                  color: tokens.brandSoftText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clientName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: tokens.textPrimary,
                                    ),
                                    softWrap: true,
                                  ),
                                  const SizedBox(height: 2),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 2,
                                    children: [
                                      if (clientCode.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: tokens.surfaceSubtle,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            clientCode,
                                            style: coTabularStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: tokens.textSecondary,
                                            ),
                                          ),
                                        ),
                                      if (groupName.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: tokens.successBg,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            groupName,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: tokens.successText,
                                            ),
                                            softWrap: true,
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: tokens.infoBg,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '$savingsType - $opType',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: tokens.infoText,
                                          ),
                                          softWrap: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );

                        final headerRight = Column(
                          crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatNaira(amt),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: tokens.dangerText,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.dangerBg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: tokens.dangerBorder),
                              ),
                              child: Text(
                                'Awaiting Approval',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.dangerText,
                                ),
                              ),
                            ),
                          ],
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              headerLeft,
                              const SizedBox(height: 8),
                              headerRight,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: headerLeft),
                            const SizedBox(width: 12),
                            headerRight,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14, color: tokens.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Requested by $reqBy | Date: $opDate${remarks.isNotEmpty ? " | Notes: $remarks" : ""}',
                              style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Actions or In-line Rejection Form
                    if (isSelfRequested) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: tokens.warningBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: tokens.warningBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified_user_outlined, size: 14, color: tokens.warningDot),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Maker-Checker: Awaiting peer manager review',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.warningText),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isRejecting) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: tokens.dangerBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tokens.dangerBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Specify Rejection Reason',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: tokens.dangerText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _rejectReasonCtrl,
                              style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Enter reason for rejecting this request...',
                                hintStyle: TextStyle(color: tokens.textMuted),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                fillColor: tokens.surface,
                                filled: true,
                                isDense: true,
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                OutlinedButton(
                                  onPressed: () => setState(() {
                                    _rejectingRequestId = null;
                                    _rejectReasonCtrl.clear();
                                  }),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: tokens.textSecondary,
                                    side: BorderSide(color: tokens.borderStrong),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                                ),
                                ElevatedButton.icon(
                                  onPressed: (_isSubmitting || !isOnline) ? null : () => _confirmRejectRequest(reqId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.close_rounded, size: 14),
                                  label: const Text('Confirm Rejection', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          OutlinedButton.icon(
                            onPressed: (_isSubmitting || !isOnline)
                                ? null
                                : () => setState(() {
                                      _rejectingRequestId = reqId;
                                      _rejectReasonCtrl.clear();
                                    }),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tokens.dangerText,
                              side: BorderSide(color: tokens.dangerBorder),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.close_rounded, size: 14),
                            label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          ElevatedButton.icon(
                            onPressed: (_isSubmitting || !isOnline) ? null : () => _approveRequest(reqId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF15803D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              elevation: 0,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                            label: const Text(
                              'Approve & Settle',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // TAB 6 BUILDER: DAILY WITHDRAWALS
  // ==========================================================================
  Widget _buildDailyWithdrawalsTab(bool isManager) {
    final tokens = IcareSurfaceTokens.of(context);
    final dwAsync = ref.watch(dailyWithdrawalsProvider);
    final showAll = ref.watch(dwShowAllProvider);
    final catFilter = ref.watch(dwCategoryProvider);

    return dwAsync.when(
      loading: () => const IcareTableSkeleton(rowCount: 8, hasFilterBar: false),
      error: (err, _) => _buildErrorCard(AppErrorDetails.from(err).message, () => ref.refresh(dailyWithdrawalsProvider)),
      data: (data) {
        final kpis = data['kpis'] as Map<String, dynamic>? ?? {};
        final totWithdrawn = (kpis['total_withdrawn'] as num?)?.toDouble() ?? 0.0;
        final feesDeducted = (kpis['loan_fees_deducted'] as num?)?.toDouble() ?? 0.0;
        final cashBankPaid = (kpis['cash_bank_paid'] as num?)?.toDouble() ?? 0.0;
        final debtOffsets = (kpis['debt_fee_offsets'] as num?)?.toDouble() ?? 0.0;
        final lapsReserved = (kpis['laps_reserved'] as num?)?.toDouble() ?? 0.0;
        final waitCount = (kpis['waiting_for_approval_count'] as num?)?.toInt() ?? 0;
        final waitAmt = (kpis['waiting_for_approval_amount'] as num?)?.toDouble() ?? 0.0;

        final allRecs = (data['all_records'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
        final upfrontRecs = (data['loan_fee_deductions'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
        final payoutRecs = (data['cash_bank_payouts'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
        final myReqs = (data['my_requests'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                final titleCol = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Withdrawals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Review all savings withdrawals, upfront loan fee deductions, and request status for your clients.', style: TextStyle(fontSize: 11, color: tokens.textMuted), softWrap: true),
                  ],
                );
                final checkboxRow = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: showAll,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => ref.read(dwShowAllProvider.notifier).state = v ?? false,
                    ),
                    Text('Show all dates', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                  ],
                );
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleCol,
                      const SizedBox(height: 4),
                      checkboxRow,
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleCol),
                    checkboxRow,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Top 6 KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final c1 = _buildMetricTile(showAll ? 'Total Withdrawn' : 'Total Today', CurrencyFormatter.formatNaira(totWithdrawn), tokens.textPrimary);
                final c2 = _buildMetricTile('Loan Fees', CurrencyFormatter.formatNaira(feesDeducted), tokens.infoText);
                final c3 = _buildMetricTile('Cash & Bank Paid', CurrencyFormatter.formatNaira(cashBankPaid), tokens.successText);
                final c4 = _buildMetricTile('Debt/Fee Offsets', CurrencyFormatter.formatNaira(debtOffsets), tokens.warningText);
                final c5 = _buildMetricTile('LAPS Reserve', CurrencyFormatter.formatNaira(lapsReserved), tokens.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED));
                final c6 = _buildMetricTile('Waiting Approval', '$waitCount req (${CurrencyFormatter.formatNaira(waitAmt)})', tokens.dangerText);

                if (constraints.maxWidth >= 900) {
                  return Row(
                    children: [
                      Expanded(child: c1),
                      const SizedBox(width: 8),
                      Expanded(child: c2),
                      const SizedBox(width: 8),
                      Expanded(child: c3),
                      const SizedBox(width: 8),
                      Expanded(child: c4),
                      const SizedBox(width: 8),
                      Expanded(child: c5),
                      const SizedBox(width: 8),
                      Expanded(child: c6),
                    ],
                  );
                } else if (constraints.maxWidth >= 500) {
                  return Column(
                    children: [
                      Row(children: [Expanded(child: c1), const SizedBox(width: 6), Expanded(child: c2), const SizedBox(width: 6), Expanded(child: c3)]),
                      const SizedBox(height: 6),
                      Row(children: [Expanded(child: c4), const SizedBox(width: 6), Expanded(child: c5), const SizedBox(width: 6), Expanded(child: c6)]),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Row(children: [Expanded(child: c1), const SizedBox(width: 6), Expanded(child: c2)]),
                      const SizedBox(height: 6),
                      Row(children: [Expanded(child: c3), const SizedBox(width: 6), Expanded(child: c4)]),
                      const SizedBox(height: 6),
                      Row(children: [Expanded(child: c5), const SizedBox(width: 6), Expanded(child: c6)]),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 12),

            CoWithdrawalAnalyticsSection(
              totalWithdrawn: totWithdrawn,
              loanFeesDeducted: feesDeducted,
              cashBankPaid: cashBankPaid,
              debtOffsets: debtOffsets,
              lapsReserved: lapsReserved,
              waitingAmount: waitAmt,
              waitingCount: waitCount,
              showAll: showAll,
            ),
            const SizedBox(height: 12),

            // Filters Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                final dropdown = DropdownButtonFormField<String>(
                  value: catFilter,
                  isExpanded: true,
                  dropdownColor: tokens.surfaceElevated,
                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Filter by Type',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All Types', child: Text('All Types', softWrap: true)),
                    DropdownMenuItem(value: 'Loan Fee Deductions', child: Text('Loan Fee Deductions', softWrap: true)),
                    DropdownMenuItem(value: 'Cash & Bank Payouts', child: Text('Cash & Bank Payouts', softWrap: true)),
                    DropdownMenuItem(value: 'Loan & Fee Offsets', child: Text('Loan & Fee Offsets', softWrap: true)),
                    DropdownMenuItem(value: 'Group Withdrawals', child: Text('Group Withdrawals', softWrap: true)),
                    DropdownMenuItem(value: 'Misc & LAPS', child: Text('Misc & LAPS', softWrap: true)),
                    DropdownMenuItem(value: 'LAPS Reserve', child: Text('LAPS Reserve', softWrap: true)),
                    DropdownMenuItem(value: 'Reversals', child: Text('Reversals', softWrap: true)),
                  ],
                  onChanged: (val) {
                    if (val != null) ref.read(dwCategoryProvider.notifier).state = val;
                  },
                );
                final searchField = TextField(
                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Search records',
                    hintText: 'Type client name, code, or loan ID...',
                    prefixIcon: Icon(Icons.search, size: 16),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (val) => ref.read(dwSearchProvider.notifier).state = val,
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      dropdown,
                      const SizedBox(height: 8),
                      searchField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 2, child: dropdown),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: searchField),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // 4 Subtabs (app.py L8697-8702)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSubtabButton(0, 'All Withdrawals (${allRecs.length})'),
                  const SizedBox(width: 6),
                  _buildSubtabButton(1, 'Loan Fee Deductions (${upfrontRecs.length})'),
                  const SizedBox(width: 6),
                  _buildSubtabButton(2, 'Cash & Bank Payouts (${payoutRecs.length})'),
                  const SizedBox(width: 6),
                  _buildSubtabButton(3, 'My Requests & Status (${myReqs.length})'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Subtab Table Content
            if (_dwSubtabIndex == 0)
              _buildAllWithdrawalsTable(allRecs)
            else if (_dwSubtabIndex == 1)
              _buildLoanFeeDeductionsTable(upfrontRecs)
            else if (_dwSubtabIndex == 2)
              _buildCashBankPayoutsTable(payoutRecs)
            else
              _buildMyRequestsList(myReqs),
          ],
        );
      },
    );
  }

  Widget _buildSubtabButton(int idx, String title) {
    final tokens = IcareSurfaceTokens.of(context);
    final isSel = _dwSubtabIndex == idx;
    return InkWell(
      onTap: () => setState(() => _dwSubtabIndex = idx),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? tokens.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSel ? tokens.borderStrong : tokens.borderSubtle),
        ),
        child: Text(
          title,
          style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? tokens.textPrimary : tokens.textMuted),
          softWrap: true,
        ),
      ),
    );
  }

  Widget _buildStatusPill(String rawStatus) {
    final s = rawStatus.toUpperCase().trim();
    final variant = (s == 'REVERSAL' || s == 'REJECTED')
        ? IcareBadgeVariant.danger
        : (s == 'REVERSED' || s == 'PENDING' || s == 'PROCESSING')
            ? IcareBadgeVariant.warning
            : IcareBadgeVariant.success;
    return IcareStatusBadge(
      label: s.isEmpty ? 'ACTIVE' : s,
      variant: variant,
    );
  }

  Widget _buildAllWithdrawalsTable(List<Map<String, dynamic>> records) {
    final tokens = IcareSurfaceTokens.of(context);
    if (records.isEmpty) {
      return const CoEmptyStateCard(
        title: 'No Withdrawals Found',
        message: 'No withdrawals found for the selected criteria.',
        icon: Icons.receipt_long_outlined,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: records.map((r) {
              final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
              final recStatus = (r['status']?.toString() ?? 'UNRECORDED').toUpperCase();
              final isNeg = amt < 0 || recStatus == 'REVERSAL';
              final formattedAmt = amt < 0
                  ? '-${CurrencyFormatter.formatNaira(amt.abs())}'
                  : CurrencyFormatter.formatNaira(amt);
              final details = _cleanRemarks(r['details']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: IcareCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r['client_name']?.toString() ?? 'Client',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: tokens.textPrimary),
                              softWrap: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusPill(recStatus),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if ((r['client_code']?.toString() ?? '').isNotEmpty)
                            Text(
                              r['client_code'].toString(),
                              style: coTabularStyle(fontSize: 11, color: tokens.textSecondary),
                            ),
                          if ((r['group']?.toString() ?? '').isNotEmpty)
                            Text(r['group'].toString(), style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
                          if ((r['date']?.toString() ?? '').isNotEmpty)
                            Text(r['date'].toString(), style: coTabularStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              r['category']?.toString() ?? 'Withdrawal',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                              softWrap: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedAmt,
                            style: coTabularStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isNeg ? tokens.dangerText : tokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (details.isNotEmpty || (r['reference']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          [
                            if (details.isNotEmpty) details,
                            if ((r['reference']?.toString() ?? '').isNotEmpty) 'Ref: ${r['reference']}',
                          ].join(' • '),
                          style: coTabularStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: tokens.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }

        return IcareDataTable(
          minWidth: 920,
          columns: const [
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataColumn(label: Text('Client Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataColumn(label: Text('Group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataColumn(label: Text('Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataColumn(label: Text('Reference', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          ],
          rows: records.map((r) {
            final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
            final recStatus = (r['status']?.toString() ?? 'UNRECORDED').toUpperCase();
            final isNeg = amt < 0 || recStatus == 'REVERSAL';
            final formattedAmt = amt < 0
                ? '-${CurrencyFormatter.formatNaira(amt.abs())}'
                : CurrencyFormatter.formatNaira(amt);
            return DataRow(cells: [
              DataCell(Text(r['date']?.toString() ?? '', style: coTabularStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textSecondary))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(r['client_name']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: tokens.textPrimary), softWrap: true),
                ),
              ),
              DataCell(Text(r['client_code']?.toString() ?? '', style: coTabularStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textSecondary))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(r['group']?.toString() ?? '', style: TextStyle(fontSize: 11, color: tokens.textSecondary), softWrap: true),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(r['category']?.toString() ?? '', style: TextStyle(fontSize: 11, color: tokens.textSecondary), softWrap: true),
                ),
              ),
              DataCell(
                Text(
                  formattedAmt,
                  style: coTabularStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isNeg ? tokens.dangerText : tokens.textPrimary,
                  ),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(_cleanRemarks(r['details']), style: TextStyle(fontSize: 11, color: tokens.textSecondary), softWrap: true),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(r['reference']?.toString() ?? '', style: coTabularStyle(fontSize: 10, fontWeight: FontWeight.w500, color: tokens.textMuted), softWrap: true),
                ),
              ),
              DataCell(_buildStatusPill(recStatus)),
            ]);
          }).toList(),
        );
      },
    );
  }

  Widget _buildLoanFeeDeductionsTable(List<Map<String, dynamic>> records) {
    final tokens = IcareSurfaceTokens.of(context);
    if (records.isEmpty) {
      return const CoEmptyStateCard(
        title: 'No Fee Deductions Found',
        message: 'No loan fee deductions found for the selected criteria.',
        icon: Icons.percent_rounded,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("When a loan is disbursed, markup interest and gap fees are automatically deducted from the borrower's savings.", style: TextStyle(fontSize: 11, color: tokens.textMuted), softWrap: true),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                children: records.map((r) {
                  final uInt = (r['interest_deducted'] as num?)?.toDouble() ?? 0.0;
                  final uGap = (r['gap_fee_deducted'] as num?)?.toDouble() ?? 0.0;
                  final tot = (r['total_deducted'] as num?)?.toDouble() ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: IcareCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r['client_name']?.toString() ?? 'Client',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: tokens.textPrimary),
                                ),
                              ),
                              _buildStatusPill(r['status']?.toString() ?? 'SETTLED'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${r['client_code'] ?? ''} • Loan ${r['loan_ref'] ?? '-'} • ${r['date'] ?? ''}',
                            style: coTabularStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textMuted),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Interest: ${CurrencyFormatter.formatNaira(uInt)}', style: coTabularStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textSecondary)),
                              Text('Gap: ${CurrencyFormatter.formatNaira(uGap)}', style: coTabularStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textSecondary)),
                              Text('Total: ${CurrencyFormatter.formatNaira(tot)}', style: coTabularStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: tokens.textPrimary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            }

            return IcareDataTable(
              minWidth: 820,
              columns: const [
                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Client Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Loan Reference', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Interest Deducted', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Gap Fee Deducted', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Total Deducted', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              ],
              rows: records.map((r) {
                final uInt = (r['interest_deducted'] as num?)?.toDouble() ?? 0.0;
                final uGap = (r['gap_fee_deducted'] as num?)?.toDouble() ?? 0.0;
                final tot = (r['total_deducted'] as num?)?.toDouble() ?? 0.0;
                return DataRow(cells: [
                  DataCell(Text(r['date']?.toString() ?? '', style: coTabularStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textSecondary))),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(r['client_name']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: tokens.textPrimary), softWrap: true),
                    ),
                  ),
                  DataCell(Text(r['client_code']?.toString() ?? '', style: coTabularStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textSecondary))),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(r['loan_ref']?.toString() ?? '', style: coTabularStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textSecondary), softWrap: true),
                    ),
                  ),
                  DataCell(Text(uInt > 0 ? CurrencyFormatter.formatNaira(uInt) : '-', style: coTabularStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textSecondary))),
                  DataCell(Text(uGap > 0 ? CurrencyFormatter.formatNaira(uGap) : '-', style: coTabularStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textSecondary))),
                  DataCell(Text(CurrencyFormatter.formatNaira(tot), style: coTabularStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                  DataCell(_buildStatusPill(r['status']?.toString() ?? 'ACTIVE')),
                ]);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCashBankPayoutsTable(List<Map<String, dynamic>> records) {
    final tokens = IcareSurfaceTokens.of(context);
    if (records.isEmpty) {
      return const CoEmptyStateCard(
        title: 'No Cash or Bank Payouts',
        message: 'No cash or bank payouts found for the selected criteria.',
        icon: Icons.account_balance_outlined,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: records.map((r) {
              final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
              final notes = _cleanRemarks(r['approval_notes']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: IcareCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              r['client_name']?.toString() ?? 'Client',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: tokens.textPrimary),
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatNaira(amt),
                            style: coTabularStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tokens.successText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${r['payment_type'] ?? 'Payout'} • ${r['group'] ?? '-'} • ${r['date'] ?? ''}',
                        style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                      ),
                      if (notes.isNotEmpty || (r['reference']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          [
                            if (notes.isNotEmpty) notes,
                            if ((r['reference']?.toString() ?? '').isNotEmpty) 'Ref: ${r['reference']}',
                          ].join(' • '),
                          style: coTabularStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: tokens.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }

        return IcareDataTable(
          minWidth: 820,
          columns: const [
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataColumn(label: Text('Client / Group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataColumn(label: Text('Group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataColumn(label: Text('Payment Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataColumn(label: Text('Approval Notes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataColumn(label: Text('Reference', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          ],
          rows: records.map((r) {
            final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
            return DataRow(cells: [
              DataCell(Text(r['date']?.toString() ?? '', style: coTabularStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textSecondary))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(r['client_name']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: tokens.textPrimary), softWrap: true),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(r['group']?.toString() ?? '', style: TextStyle(fontSize: 11, color: tokens.textSecondary), softWrap: true),
                ),
              ),
              DataCell(Text(r['payment_type']?.toString() ?? '', style: TextStyle(fontSize: 11, color: tokens.textSecondary))),
              DataCell(Text(CurrencyFormatter.formatNaira(amt), style: coTabularStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(_cleanRemarks(r['approval_notes']), style: TextStyle(fontSize: 11, color: tokens.textSecondary), softWrap: true),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(r['reference']?.toString() ?? '', style: coTabularStyle(fontSize: 10, fontWeight: FontWeight.w500, color: tokens.textMuted), softWrap: true),
                ),
              ),
            ]);
          }).toList(),
        );
      },
    );
  }

  Widget _buildMyRequestsList(List<Map<String, dynamic>> requests) {
    final tokens = IcareSurfaceTokens.of(context);
    if (requests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: tokens.surfaceSubtle, borderRadius: BorderRadius.circular(8), border: Border.all(color: tokens.borderSubtle)),
        child: Center(child: Text('No withdrawal requests found.', style: TextStyle(color: tokens.textMuted, fontSize: 13), softWrap: true)),
      );
    }

    return Column(
      children: requests.map((req) {
        final stStatus = req['status']?.toString() ?? 'PENDING';
        final amt = (req['amount'] as num?)?.toDouble() ?? 0.0;
        final name = req['client_name']?.toString() ?? 'Unknown';
        final stype = req['savings_type']?.toString() ?? 'Savings';
        final op = req['operation_type']?.toString() ?? 'Withdrawal';
        final refCode = req['reference']?.toString() ?? '-';
        final opDate = req['operational_date']?.toString() ?? '';
        final remarks = _cleanRemarks(req['remarks']);
        final rejReason = req['rejection_reason']?.toString() ?? '';
        final appBy = req['approved_by']?.toString() ?? '';

        Color badgeColor;
        String badgeText;
        if (stStatus == 'APPROVED') {
          badgeColor = tokens.successText;
          badgeText = '[Approved]';
        } else if (stStatus == 'REJECTED') {
          badgeColor = tokens.dangerText;
          badgeText = '[Rejected]';
        } else {
          badgeColor = tokens.warningText;
          badgeText = '[Waiting for Approval]';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 550;
              final infoCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name | $stype — $op | Ref: $refCode',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tokens.textPrimary),
                    softWrap: true,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Requested by: ${req['requested_by']} | Date: $opDate',
                    style: TextStyle(fontSize: 11, color: tokens.textMuted),
                    softWrap: true,
                  ),
                  if (remarks.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Notes: $remarks',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: tokens.textSecondary),
                      softWrap: true,
                    ),
                  ],
                  if (stStatus == 'REJECTED' && rejReason.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Reason from Manager: $rejReason',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.dangerText),
                      softWrap: true,
                    ),
                  ] else if (stStatus == 'APPROVED' && appBy.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Authorized by $appBy',
                      style: TextStyle(fontSize: 11, color: tokens.successText),
                      softWrap: true,
                    ),
                  ],
                ],
              );
              final amtCol = Column(
                crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatNaira(amt),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: badgeColor, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                  const SizedBox(height: 1),
                  Text(badgeText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor)),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoCol,
                    const SizedBox(height: 6),
                    amtCol,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: infoCol),
                  const SizedBox(width: 10),
                  amtCol,
                ],
              );
            },
          ),
        );
      }).toList(),
    );
  }

  // ==========================================================================
  // MODERN FINTECH WIDGET HELPERS
  // ==========================================================================

  Widget _buildExecutiveWithdrawalCockpit({
    required bool isManager,
    required DateTime opDate,
    required VoidCallback onChangeDate,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.16 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 520;
          final titleRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tokens.brandPrimaryDark,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Withdrawal Operations',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                      softWrap: true,
                    ),
                    Text(
                      isManager ? 'Branch Manager Mode' : 'Credit Officer Request Mode',
                      style: TextStyle(
                        fontSize: 11,
                        color: isManager ? tokens.successText : tokens.infoText,
                        fontWeight: FontWeight.w600,
                      ),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ],
          );

          final dateCapsule = InkWell(
            onTap: onChangeDate,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.borderStrong),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 12, color: tokens.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    DateFormat('dd MMM yyyy').format(opDate),
                    style: coTabularStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down_rounded, size: 16, color: tokens.textMuted),
                ],
              ),
            ),
          );

          final actionBar = Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              dateCapsule,
              InkWell(
                onTap: _invalidateAfterWithdrawalMutation,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.borderStrong),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 13, color: tokens.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Refresh',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleRow,
                const SizedBox(height: 6),
                actionBar,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleRow),
              const SizedBox(width: 10),
              actionBar,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFlashBanner() {
    if (_flashMessage == null) return const SizedBox.shrink();
    final tokens = IcareSurfaceTokens.of(context);
    final isSuccess = _isSuccessFlash;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSuccess ? tokens.successBg : tokens.dangerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSuccess ? tokens.successBorder : tokens.dangerBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isSuccess ? tokens.successDot : tokens.dangerDot).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isSuccess ? tokens.successBorder : tokens.dangerBorder).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              size: 18,
              color: isSuccess ? tokens.successText : tokens.dangerText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _flashMessage!,
              style: TextStyle(
                color: isSuccess ? tokens.successText : tokens.dangerText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            color: isSuccess ? tokens.successText : tokens.dangerText,
            onPressed: () => setState(() => _flashMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildTactileTabsBar({
    required List<String> tabs,
    required String activeTab,
    required ValueChanged<String> onSelectTab,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((t) {
            final isSel = activeTab == t || (t.startsWith('Pending Approvals') && activeTab.startsWith('Pending Approvals'));
            final isPending = t.startsWith('Pending Approvals');

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => onSelectTab(t),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? tokens.surfaceElevated : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: tokens.isDark ? 0.2 : 0.05),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                    border: isSel
                        ? Border.all(color: tokens.borderStrong)
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                      color: isSel
                          ? (isPending ? tokens.dangerText : tokens.textPrimary)
                          : tokens.textMuted,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInlineBalanceStrip({
    required String label,
    required double balance,
    String? tag,
    String? subtitle,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.successBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.successBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 460;
          final info = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: tokens.brandPrimaryDark,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                    if (tag != null || subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        [if (tag != null) tag, if (subtitle != null) subtitle].join(' | '),
                        style: TextStyle(fontSize: 10, color: tokens.successText, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          final balText = Column(
            crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AVAILABLE BALANCE',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: tokens.successText, letterSpacing: 0.5),
              ),
              Text(
                CurrencyFormatter.formatNaira(balance),
                style: coTabularStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: tokens.successText,
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                info,
                const SizedBox(height: 6),
                balText,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: info),
              const SizedBox(width: 8),
              balText,
            ],
          );
        },
      ),
    );
  }

  Widget _buildAmountPresetChips({
    required double availableBalance,
    required TextEditingController controller,
  }) {
    if (availableBalance <= 0) return const SizedBox.shrink();
    final tokens = IcareSurfaceTokens.of(context);

    final presets = [
      {'label': '25%', 'ratio': 0.25},
      {'label': '50%', 'ratio': 0.50},
      {'label': '75%', 'ratio': 0.75},
      {'label': '100% Full', 'ratio': 1.00},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'QUICK PRESETS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: tokens.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Max: ${CurrencyFormatter.formatNaira(availableBalance)}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: tokens.successText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: presets.map((p) {
            final label = p['label'] as String;
            final ratio = p['ratio'] as double;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () {
                    final target = (availableBalance * ratio).floorToDouble();
                    controller.text = target.toStringAsFixed(0);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tokens.borderStrong),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFormCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    String? subtitle,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return IcareCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                  letterSpacing: -0.2,
                ),
                softWrap: true,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.textMuted,
                  ),
                  softWrap: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: tokens.borderSubtle),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, {IconData? icon}) {
    final tokens = IcareSurfaceTokens.of(context);
    return IcareCard(
      topAccentColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, color: tokens.textMuted, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 12, color: color),
              ],
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: coTabularStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error, VoidCallback onRetry) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.dangerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.dangerBorder),
      ),
      child: Column(
        children: [
          Text(error, style: TextStyle(color: tokens.dangerText, fontSize: 13)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
