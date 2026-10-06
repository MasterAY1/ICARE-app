// ignore_for_file: deprecated_member_use, prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../data/datasources/co_api_service.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';

// ==========================================
// STATE PROVIDERS
// ==========================================

final withdrawalTabProvider = StateProvider<String>((ref) => 'Individual Savings');
final withdrawalOpDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final dwShowAllProvider = StateProvider<bool>((ref) => false);
final dwCategoryProvider = StateProvider<String>((ref) => 'All Types');
final dwSearchProvider = StateProvider<String>((ref) => '');

// ==========================================
// ASYNC DATA PROVIDERS
// ==========================================

final individualOptionsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(coApiServiceProvider);
  return api.getIndividualWithdrawalOptions();
});

final groupOptionsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(coApiServiceProvider);
  return api.getGroupWithdrawalOptions();
});

final miscBalanceProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(coApiServiceProvider);
  return api.getMiscWithdrawalBalance();
});

final lapsOptionsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
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
  String _indDestOp = 'Client Bank Account (Transfer)';
  String? _indSelectedLoanId;
  String _indFeeType = 'credit_form_damage';
  final String _indTransferTargetCat = 'Individual Member';
  String? _indTransferRecipientId;
  final _indAmountCtrl = TextEditingController();
  final _indRemarksCtrl = TextEditingController();
  bool _indAutoExec = false;

  // Tab 2: Group State
  String? _grpSelectedGroupId;
  String _grpDestOp = 'Group Bank Account (Transfer)';
  String? _grpSelectedMemberId;
  String? _grpSelectedLoanId;
  final String _grpFeeType = 'credit_form_damage';
  final String _grpTransferTargetCat = 'Group Member';
  String? _grpTransferRecipientId;
  final _grpAmountCtrl = TextEditingController();
  final _grpRemarksCtrl = TextEditingController();
  bool _grpAutoExec = false;

  // Tab 3: Misc State
  final _miscAmountCtrl = TextEditingController();
  final _miscRemarksCtrl = TextEditingController();

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

  static const List<Map<String, dynamic>> _indDestOptions = [
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

  // ==========================================================================
  // TAB 1: INDIVIDUAL SAVINGS SUBMISSION
  // ==========================================================================
  Future<void> _submitIndividualWithdrawal(Map<String, dynamic> clientData) async {
    final amt = double.tryParse(_indAmountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final bal = (clientData['savings_balance'] as num?)?.toDouble() ?? 0.0;
    final cId = clientData['client_id']?.toString() ?? '';
    final cName = clientData['name']?.toString() ?? 'Client';

    if (amt <= 0) {
      _showFlash('Amount must be greater than zero.', isSuccess: false);
      return;
    }
    if (amt > bal) {
      _showFlash('Insufficient balance. Available: ${CurrencyFormatter.formatNaira(bal)}', isSuccess: false);
      return;
    }
    if (_indDestOp == 'Loan Repayment / Asset Debt Offset' && (_indSelectedLoanId == null || _indSelectedLoanId!.isEmpty)) {
      _showFlash('Select an eligible loan for debt offset.', isSuccess: false);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final opDate = ref.read(withdrawalOpDateProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(opDate);

      String remFinal = _indRemarksCtrl.text.trim();
      if (_indDestOp == 'Loan Repayment / Asset Debt Offset') {
        remFinal = '[LOAN_OFFSET:$_indSelectedLoanId] $remFinal'.trim();
      } else if (_indDestOp == 'Fee Payment from Savings') {
        remFinal = '[FEE:$_indFeeType] $remFinal'.trim();
      } else if (_indDestOp == 'Another Member or Group Savings') {
        remFinal = '[DEST_ID:$_indTransferRecipientId][DEST_TYPE:$_indTransferTargetCat] $remFinal'.trim();
      }

      final payload = {
        'savings_type': 'Individual',
        'operation_type': _indDestOp,
        'client_id': cId,
        'client_name': cName,
        'loan_id': _indSelectedLoanId,
        'amount': amt,
        'operational_date': dateStr,
        'remarks': remFinal,
        'auto_execute': _indAutoExec,
      };

      final api = ref.read(coApiServiceProvider);
      final res = await api.submitWithdrawalRequest(payload);

      _showFlash(res['message']?.toString() ?? 'Withdrawal request submitted successfully!');
      _indAmountCtrl.clear();
      _indRemarksCtrl.clear();
      ref.invalidate(individualOptionsProvider);
      ref.invalidate(dailyWithdrawalsProvider);
    } catch (e) {
      _showFlash('Execution failed: $e', isSuccess: false);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ==========================================================================
  // TAB 2: GROUP SAVINGS SUBMISSION
  // ==========================================================================
  Future<void> _submitGroupWithdrawal(Map<String, dynamic> grpData) async {
    final amt = double.tryParse(_grpAmountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final bal = (grpData['savings_balance'] as num?)?.toDouble() ?? 0.0;
    final gId = grpData['group_id']?.toString() ?? '';
    final gName = grpData['name']?.toString() ?? 'Group';

    if (amt <= 0) {
      _showFlash('Amount must be greater than zero.', isSuccess: false);
      return;
    }
    if (amt > bal) {
      _showFlash('Insufficient group balance. Available: ${CurrencyFormatter.formatNaira(bal)}', isSuccess: false);
      return;
    }
    if (_grpDestOp.contains('Loan Repayment') && (_grpSelectedLoanId == null || _grpSelectedLoanId!.isEmpty)) {
      _showFlash('Select a member and loan for debt offset.', isSuccess: false);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final opDate = ref.read(withdrawalOpDateProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(opDate);

      String remFinal = _grpRemarksCtrl.text.trim();
      if (_grpDestOp.contains('Loan Repayment')) {
        remFinal = '[LOAN_OFFSET:$_grpSelectedLoanId] $remFinal'.trim();
      } else if (_grpDestOp.contains('Fee Payment')) {
        remFinal = '[FEE:$_grpFeeType] $remFinal'.trim();
      } else if (_grpDestOp.contains('Another Member')) {
        remFinal = '[DEST_ID:$_grpTransferRecipientId][DEST_TYPE:$_grpTransferTargetCat] $remFinal'.trim();
      }

      final payload = {
        'savings_type': 'Group',
        'operation_type': _grpDestOp,
        'client_id': _grpSelectedMemberId,
        'client_name': gName,
        'group_name': gId,
        'loan_id': _grpSelectedLoanId,
        'amount': amt,
        'operational_date': dateStr,
        'remarks': remFinal,
        'auto_execute': _grpAutoExec,
      };

      final api = ref.read(coApiServiceProvider);
      final res = await api.submitWithdrawalRequest(payload);

      _showFlash(res['message']?.toString() ?? 'Group withdrawal request submitted successfully!');
      _grpAmountCtrl.clear();
      _grpRemarksCtrl.clear();
      ref.invalidate(groupOptionsProvider);
      ref.invalidate(dailyWithdrawalsProvider);
    } catch (e) {
      _showFlash('Execution failed: $e', isSuccess: false);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ==========================================================================
  // TAB 4: LAPS PAYOUT SUBMISSION
  // ==========================================================================
  Future<void> _submitLapsPayout(Map<String, dynamic> lapsRec) async {
    final amt = double.tryParse(_lapsAmountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final bal = (lapsRec['balance'] as num?)?.toDouble() ?? 0.0;
    final cId = lapsRec['client_id']?.toString() ?? '';

    if (amt <= 0) {
      _showFlash('Payout amount must be greater than zero.', isSuccess: false);
      return;
    }
    if (amt > bal) {
      _showFlash('Insufficient LAPS balance. Available: ${CurrencyFormatter.formatNaira(bal)}', isSuccess: false);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final opDate = ref.read(withdrawalOpDateProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(opDate);

      final payload = {
        'savings_type': 'LAPS',
        'operation_type': 'LAPS Payout',
        'client_id': cId,
        'amount': amt,
        'operational_date': dateStr,
        'payout_method': _lapsPayoutMethod,
        'remarks': _lapsRemarksCtrl.text.trim(),
        'auto_execute': _lapsAutoExec,
      };

      final api = ref.read(coApiServiceProvider);
      final res = await api.submitWithdrawalRequest(payload);

      _showFlash(res['message']?.toString() ?? 'LAPS payout submitted successfully!');
      _lapsAmountCtrl.clear();
      _lapsRemarksCtrl.clear();
      ref.invalidate(lapsOptionsProvider);
      ref.invalidate(dailyWithdrawalsProvider);
    } catch (e) {
      _showFlash('Execution failed: $e', isSuccess: false);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ==========================================================================
  // TAB 5 (BM ONLY): APPROVE / REJECT ACTIONS
  // ==========================================================================
  Future<void> _approveRequest(String reqId) async {
    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final res = await api.approveWithdrawal(reqId);
      _showFlash(res['message']?.toString() ?? 'Withdrawal approved successfully!');
      ref.invalidate(pendingApprovalsProvider);
      ref.invalidate(dailyWithdrawalsProvider);
    } catch (e) {
      _showFlash('Approval failed: $e', isSuccess: false);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmRejectRequest(String reqId) async {
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
      ref.invalidate(pendingApprovalsProvider);
      ref.invalidate(dailyWithdrawalsProvider);
    } catch (e) {
      _showFlash('Rejection failed: $e', isSuccess: false);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final role = user?.role ?? 'Credit Officer';
    final isManager = role == 'Branch Manager' || role == 'BM' || role == 'Area Manager' || role == 'AM' || role == 'Admin' || role == 'Super Admin';

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
              ref.read(withdrawalOpDateProvider.notifier).state = picked;
            }
          },
        ),

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
    final indAsync = ref.watch(individualOptionsProvider);

    return indAsync.when(
      loading: () => const IcareFormSkeleton(fieldCount: 4),
      error: (err, _) => _buildErrorCard('Error loading individual options: $err', () => ref.refresh(individualOptionsProvider)),
      data: (data) {
        final groups = (data['groups'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['All Groups'];
        final allClients = (data['clients'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text('No active clients found for the selected group.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
        final loans = (selClient['eligible_loans'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

        // Selected loan
        if (loans.isNotEmpty && (_indSelectedLoanId == null || !loans.any((l) => l['loan_id'] == _indSelectedLoanId))) {
          _indSelectedLoanId = loans.first['loan_id']?.toString();
        }
        Map<String, dynamic>? selLoan = loans.isNotEmpty ? loans.firstWhere((l) => l['loan_id'] == _indSelectedLoanId, orElse: () => loans.first) : null;

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
                  decoration: const InputDecoration(
                    labelText: 'Group Filter',
                    isDense: true,
                    prefixIcon: Icon(Icons.groups_outlined, size: 18),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis, softWrap: true))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _indGroupFilter = val);
                  },
                );

                final clientField = DropdownButtonFormField<String>(
                  value: _indSelectedClientId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Member',
                    isDense: true,
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: filteredClients.map((c) {
                    final label = '${c['name']} (${c['client_code']})';
                    return DropdownMenuItem(value: c['client_id']?.toString(), child: Text(label, overflow: TextOverflow.ellipsis, softWrap: true));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _indSelectedClientId = val);
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
              decoration: const InputDecoration(
                labelText: 'Destination',
                isDense: true,
                prefixIcon: Icon(Icons.tune_rounded, size: 18),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _indDestOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt['value'] as String,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(opt['icon'] as IconData, size: 16, color: const Color(0xFF064E3B)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          opt['title'] as String,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
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
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text('No active loans found for this client to offset.', style: TextStyle(color: Color(0xFF92400E), fontSize: 12), softWrap: true),
                )
              else ...[
                DropdownButtonFormField<String>(
                  value: _indSelectedLoanId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Target Loan for Debt Offset',
                    isDense: true,
                    prefixIcon: Icon(Icons.request_quote_outlined, size: 18),
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
                          const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile(
                          'Active Credit',
                          CurrencyFormatter.formatNaira((selLoan['active_credit'] as num?)?.toDouble() ?? 0.0),
                          const Color(0xFF2563EB),
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
                decoration: const InputDecoration(
                  labelText: 'Fee Type',
                  isDense: true,
                  prefixIcon: Icon(Icons.receipt_long_outlined, size: 18),
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
                value: _indTransferRecipientId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Recipient Member',
                  isDense: true,
                  prefixIcon: Icon(Icons.swap_horiz_rounded, size: 18),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: allClients.where((c) => c['client_id'] != _indSelectedClientId).map((c) {
                  return DropdownMenuItem(
                    value: c['client_id']?.toString(),
                    child: Text('${c['name']} (${c['client_code']})', overflow: TextOverflow.ellipsis, softWrap: true),
                  );
                }).toList(),
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
              decoration: const InputDecoration(
                labelText: 'Withdrawal Amount (₦)',
                hintText: 'Enter amount...',
                isDense: true,
                prefixIcon: Icon(Icons.payments_outlined, size: 18),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // 6. Remarks
            TextField(
              controller: _indRemarksCtrl,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: 'Remarks & Authorization Notes',
                hintText: 'Reason or account details...',
                isDense: true,
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // 7. Manager Direct Posting Toggle
            if (isManager) ...[
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Direct BM Authorization & Immediate Ledger Posting', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                subtitle: const Text('Direct BM execution: Posts immediately to ledgers without pending queue.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                value: _indAutoExec,
                activeColor: const Color(0xFF15803D),
                onChanged: (v) => setState(() => _indAutoExec = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 10),
            ],

            // 8. Submit Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isManager && _indAutoExec) ? const Color(0xFF15803D) : const Color(0xFF064E3B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon((isManager && _indAutoExec) ? Icons.verified_rounded : Icons.send_rounded, size: 16),
                label: Text(
                  _isSubmitting
                      ? 'Processing...'
                      : (isManager && _indAutoExec)
                          ? 'Authorize & Post Withdrawal to Ledger'
                          : 'Submit for BM Approval',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  softWrap: true,
                ),
                onPressed: _isSubmitting ? null : () => _submitIndividualWithdrawal(selClient),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // TAB 2 BUILDER: GROUP SAVINGS (app.py L7647–7956)
  // ==========================================================================
  Widget _buildGroupTab(bool isManager) {
    final grpAsync = ref.watch(groupOptionsProvider);

    return grpAsync.when(
      loading: () => const IcareFormSkeleton(fieldCount: 4),
      error: (err, _) => _buildErrorCard('Error loading group options: $err', () => ref.refresh(groupOptionsProvider)),
      data: (data) {
        final groups = (data['groups'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

        if (groups.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text('No active groups found for the selected officer.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ),
          );
        }

        if (_grpSelectedGroupId == null || !groups.any((g) => g['group_id'] == _grpSelectedGroupId)) {
          _grpSelectedGroupId = groups.first['group_id']?.toString();
        }
        final selGrp = groups.firstWhere((g) => g['group_id'] == _grpSelectedGroupId, orElse: () => groups.first);

        final bal = (selGrp['savings_balance'] as num?)?.toDouble() ?? 0.0;

        return _buildFormCard(
          title: 'Group Savings Withdrawal',
          icon: Icons.groups_rounded,
          children: [
            // 1. Group Selector
            DropdownButtonFormField<String>(
              value: _grpSelectedGroupId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select Group',
                isDense: true,
                prefixIcon: Icon(Icons.groups_outlined, size: 18),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: groups.map((g) => DropdownMenuItem(value: g['group_id']?.toString(), child: Text(g['name']?.toString() ?? 'Group', overflow: TextOverflow.ellipsis, softWrap: true))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _grpSelectedGroupId = val);
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
              value: _grpDestOp,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Destination',
                isDense: true,
                prefixIcon: Icon(Icons.tune_rounded, size: 18),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _grpDestOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt['value'] as String,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(opt['icon'] as IconData, size: 16, color: const Color(0xFF064E3B)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          opt['title'] as String,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _grpDestOp = val);
              },
            ),
            const SizedBox(height: 10),

            // 4. Quick Amount Presets & Amount Input
            _buildAmountPresetChips(availableBalance: bal, controller: _grpAmountCtrl),
            const SizedBox(height: 8),

            TextField(
              controller: _grpAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₦)',
                hintText: 'Enter group withdrawal amount...',
                isDense: true,
                prefixIcon: Icon(Icons.payments_outlined, size: 18),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // 5. Remarks
            TextField(
              controller: _grpRemarksCtrl,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: 'Remarks & Group Resolution Notes',
                hintText: 'Resolution reference or details...',
                isDense: true,
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // 6. BM Direct Authorization Toggle
            if (isManager) ...[
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Direct BM Authorization & Immediate Ledger Posting', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                subtitle: const Text('Direct BM execution: Posts immediately to ledgers without pending queue.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                value: _grpAutoExec,
                activeColor: const Color(0xFF15803D),
                onChanged: (v) => setState(() => _grpAutoExec = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 10),
            ],

            // 7. Submit Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isManager && _grpAutoExec) ? const Color(0xFF15803D) : const Color(0xFF064E3B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon((isManager && _grpAutoExec) ? Icons.verified_rounded : Icons.send_rounded, size: 16),
                label: Text(
                  _isSubmitting
                      ? 'Processing...'
                      : (isManager && _grpAutoExec)
                          ? 'Authorize & Post Group Withdrawal to Ledger'
                          : 'Submit for BM Approval',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  softWrap: true,
                ),
                onPressed: _isSubmitting ? null : () => _submitGroupWithdrawal(selGrp),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // TAB 3 BUILDER: MISC SAVINGS (app.py L7958–8183)
  // ==========================================================================
  Widget _buildMiscTab(bool isManager) {
    final miscAsync = ref.watch(miscBalanceProvider);

    return miscAsync.when(
      loading: () => const IcareFormSkeleton(fieldCount: 2),
      error: (err, _) => _buildErrorCard('Error loading misc balance: $err', () => ref.refresh(miscBalanceProvider)),
      data: (data) {
        final bal = (data['misc_balance'] as num?)?.toDouble() ?? 0.0;
        final roleNotice = data['role_notice']?.toString() ?? 'Misc Savings is managed by the Branch Manager.';

        return _buildFormCard(
          title: 'Branch Miscellaneous Savings',
          icon: Icons.savings_rounded,
          children: [
            _buildInlineBalanceStrip(
              label: 'Branch Misc Pool',
              balance: bal,
              tag: 'MISC LEDGER FUND',
              subtitle: 'Account 1000 Protected Vault Fund',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Branch Manager Governance',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E40AF)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          roleNotice,
                          style: const TextStyle(color: Color(0xFF1E3A8A), fontSize: 11, height: 1.3),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // TAB 4 BUILDER: LAPS SAVINGS (app.py L8185–8319)
  // ==========================================================================
  Widget _buildLapsTab(bool isManager) {
    final lapsAsync = ref.watch(lapsOptionsProvider);

    return lapsAsync.when(
      loading: () => const IcareTableSkeleton(rowCount: 6, hasFilterBar: false),
      error: (err, _) => _buildErrorCard('Error loading LAPS records: $err', () => ref.refresh(lapsOptionsProvider)),
      data: (data) {
        final records = (data['records'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

        if (records.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No LAPS savings records found for payout. LAPS records are created for closed clients and groups.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
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
              decoration: const InputDecoration(
                labelText: 'Select LAPS Record',
                isDense: true,
                prefixIcon: Icon(Icons.person_search_outlined, size: 18),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: records.map((r) {
                final cid = r['client_id']?.toString() ?? '';
                final b = (r['balance'] as num?)?.toDouble() ?? 0.0;
                final shortId = cid.length > 12 ? cid.substring(0, 12) : cid;
                return DropdownMenuItem(
                  value: cid,
                  child: Text('$shortId... — ${CurrencyFormatter.formatNaira(b)}', overflow: TextOverflow.ellipsis, softWrap: true),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedLapsClientId = val);
              },
            ),
            const SizedBox(height: 10),

            // 2. Compact Inline Balance Strip
            _buildInlineBalanceStrip(
              label: 'LAPS Protection Balance',
              balance: bal,
              tag: 'CLOSED CLIENT RESERVE',
              subtitle: 'Protected Savings Liability',
            ),
            const SizedBox(height: 12),

            // 3. Compact Payout Method 2-Segment Toggle
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _lapsPayoutMethod = 'Cash'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _lapsPayoutMethod == 'Cash' ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _lapsPayoutMethod == 'Cash' ? const Color(0xFF15803D) : const Color(0xFFCBD5E1),
                          width: _lapsPayoutMethod == 'Cash' ? 1.5 : 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payments_rounded, size: 16, color: _lapsPayoutMethod == 'Cash' ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            'Cash Payout (Account 1000)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _lapsPayoutMethod == 'Cash' ? FontWeight.w700 : FontWeight.w600,
                              color: _lapsPayoutMethod == 'Cash' ? const Color(0xFF15803D) : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _lapsPayoutMethod = 'Bank Transfer'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _lapsPayoutMethod == 'Bank Transfer' ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _lapsPayoutMethod == 'Bank Transfer' ? const Color(0xFF15803D) : const Color(0xFFCBD5E1),
                          width: _lapsPayoutMethod == 'Bank Transfer' ? 1.5 : 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_rounded, size: 16, color: _lapsPayoutMethod == 'Bank Transfer' ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            'Bank Transfer (Bank 1020)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _lapsPayoutMethod == 'Bank Transfer' ? FontWeight.w700 : FontWeight.w600,
                              color: _lapsPayoutMethod == 'Bank Transfer' ? const Color(0xFF15803D) : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 4. Quick Amount Presets & Amount Input
            _buildAmountPresetChips(availableBalance: bal, controller: _lapsAmountCtrl),
            const SizedBox(height: 8),

            TextField(
              controller: _lapsAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Payout Amount (₦)',
                hintText: 'Enter amount...',
                isDense: true,
                prefixIcon: Icon(Icons.payments_outlined, size: 18),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // 5. Remarks
            TextField(
              controller: _lapsRemarksCtrl,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: 'Remarks & Client Verification',
                hintText: 'Identity notes or details...',
                isDense: true,
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // 6. BM Direct Authorization Toggle
            if (isManager) ...[
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Direct BM Authorization & Immediate Ledger Posting', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                subtitle: const Text('Direct BM execution: Posts immediately to ledgers without pending queue.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                value: _lapsAutoExec,
                activeColor: const Color(0xFF15803D),
                onChanged: (v) => setState(() => _lapsAutoExec = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 10),
            ],

            // 7. Submit Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isManager && _lapsAutoExec) ? const Color(0xFF15803D) : const Color(0xFF064E3B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon((isManager && _lapsAutoExec) ? Icons.verified_rounded : Icons.send_rounded, size: 16),
                label: Text(
                  _isSubmitting
                      ? 'Processing...'
                      : (isManager && _lapsAutoExec)
                          ? 'Authorize & Post LAPS Payout to Ledger'
                          : 'Submit LAPS Payout for BM Approval',
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
    final pendingAsync = ref.watch(pendingApprovalsProvider);

    return pendingAsync.when(
      loading: () => const IcareTableSkeleton(rowCount: 4, hasFilterBar: false),
      error: (err, _) => _buildErrorCard(
        'Error loading pending approvals: $err',
        () => ref.refresh(pendingApprovalsProvider),
      ),
      data: (data) {
        final pendingList = (data['pending_requests'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];

        if (pendingList.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 28,
                    color: Color(0xFF15803D),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'All Caught Up',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'There are no withdrawal requests pending Branch Manager review or ledger authorization.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
                    size: 16,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Authorizations (${pendingList.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        softWrap: true,
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Review officer-submitted withdrawal requests for ledger posting approval or rejection.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
              final opDate = req['operational_date']?.toString() ?? '';
              final remarks = req['remarks']?.toString() ?? '';
              final isRejecting = _rejectingRequestId == reqId;

              final initials = clientName.trim().isNotEmpty
                  ? clientName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                  : 'CL';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isRejecting ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                    width: isRejecting ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
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
                              backgroundColor: const Color(0xFF064E3B).withValues(alpha: 0.1),
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Color(0xFF064E3B),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
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
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            clientCode,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontFamily: 'JetBrains Mono',
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      if (groupName.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0FDF4),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            groupName,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF15803D),
                                            ),
                                            softWrap: true,
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '$savingsType - $opType',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2563EB),
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFDC2626),
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: const Text(
                                'Awaiting Approval',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
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
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Requested by $reqBy | Date: $opDate${remarks.isNotEmpty ? " | Notes: $remarks" : ""}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Actions or In-line Rejection Form
                    if (isRejecting) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Specify Rejection Reason',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _rejectReasonCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Enter reason for rejecting this request...',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                fillColor: Colors.white,
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
                                    foregroundColor: const Color(0xFF64748B),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _isSubmitting ? null : () => _confirmRejectRequest(reqId),
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
                            onPressed: _isSubmitting
                                ? null
                                : () => setState(() {
                                      _rejectingRequestId = reqId;
                                      _rejectReasonCtrl.clear();
                                    }),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.close_rounded, size: 14),
                            label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : () => _approveRequest(reqId),
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
                              'Approve & Post to Ledger',
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
  // TAB 6 BUILDER: DAILY WITHDRAWALS (app.py L8459–8800)
  // ==========================================================================
  Widget _buildDailyWithdrawalsTab(bool isManager) {
    final dwAsync = ref.watch(dailyWithdrawalsProvider);
    final showAll = ref.watch(dwShowAllProvider);
    final catFilter = ref.watch(dwCategoryProvider);

    return dwAsync.when(
      loading: () => const IcareTableSkeleton(rowCount: 8, hasFilterBar: false),
      error: (err, _) => _buildErrorCard('Error loading daily withdrawals: $err', () => ref.refresh(dailyWithdrawalsProvider)),
      data: (data) {
        final kpis = data['kpis'] as Map<String, dynamic>? ?? {};
        final totWithdrawn = (kpis['total_withdrawn'] as num?)?.toDouble() ?? 0.0;
        final feesDeducted = (kpis['loan_fees_deducted'] as num?)?.toDouble() ?? 0.0;
        final cashBankPaid = (kpis['cash_bank_paid'] as num?)?.toDouble() ?? 0.0;
        final debtOffsets = (kpis['debt_fee_offsets'] as num?)?.toDouble() ?? 0.0;
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
                  children: const [
                    Text('Daily Withdrawals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    SizedBox(height: 2),
                    Text('Review all savings withdrawals, upfront loan fee deductions, and request status for your clients.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), softWrap: true),
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
                    const Text('Show all dates', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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

            // Top 5 KPI Cards (app.py L8662-8668)
            LayoutBuilder(
              builder: (context, constraints) {
                final c1 = _buildMetricTile(showAll ? 'Total Withdrawn' : 'Total Today', CurrencyFormatter.formatNaira(totWithdrawn), const Color(0xFF0F172A));
                final c2 = _buildMetricTile('Loan Fees', CurrencyFormatter.formatNaira(feesDeducted), const Color(0xFF2563EB));
                final c3 = _buildMetricTile('Cash & Bank Paid', CurrencyFormatter.formatNaira(cashBankPaid), const Color(0xFF15803D));
                final c4 = _buildMetricTile('Debt/Fee Offsets', CurrencyFormatter.formatNaira(debtOffsets), const Color(0xFFD97706));
                final c5 = _buildMetricTile('Waiting Approval', '$waitCount req (${CurrencyFormatter.formatNaira(waitAmt)})', const Color(0xFFB91C1C));

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
                    ],
                  );
                } else if (constraints.maxWidth >= 500) {
                  return Column(
                    children: [
                      Row(children: [Expanded(child: c1), const SizedBox(width: 6), Expanded(child: c2), const SizedBox(width: 6), Expanded(child: c3)]),
                      const SizedBox(height: 6),
                      Row(children: [Expanded(child: c4), const SizedBox(width: 6), Expanded(child: c5)]),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Row(children: [Expanded(child: c1), const SizedBox(width: 6), Expanded(child: c2)]),
                      const SizedBox(height: 6),
                      Row(children: [Expanded(child: c3), const SizedBox(width: 6), Expanded(child: c4)]),
                      const SizedBox(height: 6),
                      c5,
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 12),

            // Filters Row (app.py L8671-8679)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                final dropdown = DropdownButtonFormField<String>(
                  value: catFilter,
                  isExpanded: true,
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
                  ],
                  onChanged: (val) {
                    if (val != null) ref.read(dwCategoryProvider.notifier).state = val;
                  },
                );
                final searchField = TextField(
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
    final isSel = _dwSubtabIndex == idx;
    return InkWell(
      onTap: () => setState(() => _dwSubtabIndex = idx),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFF1F5F9) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSel ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          title,
          style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
          softWrap: true,
        ),
      ),
    );
  }

  Widget _buildAllWithdrawalsTable(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: const Center(child: Text('No withdrawals found for the selected criteria.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13), softWrap: true)),
      );
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 48,
            horizontalMargin: 10,
            columnSpacing: 12,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Client Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Reference', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            ],
            rows: records.map((r) {
              final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
              return DataRow(cells: [
                DataCell(Text(r['date']?.toString() ?? '', style: const TextStyle(fontSize: 11))),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(r['client_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), softWrap: true),
                  ),
                ),
                DataCell(Text(r['client_code']?.toString() ?? '', style: const TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono'))),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(r['group']?.toString() ?? '', style: const TextStyle(fontSize: 11), softWrap: true),
                  ),
                ),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(r['category']?.toString() ?? '', style: const TextStyle(fontSize: 11), softWrap: true),
                  ),
                ),
                DataCell(Text(CurrencyFormatter.formatNaira(amt), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Text(r['details']?.toString() ?? '', style: const TextStyle(fontSize: 11), softWrap: true),
                  ),
                ),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(r['reference']?.toString() ?? '', style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10), softWrap: true),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoanFeeDeductionsTable(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: const Center(child: Text('No loan fee deductions found for the selected criteria.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13), softWrap: true)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("When a loan is disbursed, markup interest and gap fees are automatically deducted from the borrower's savings.", style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), softWrap: true),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 34,
                dataRowMaxHeight: 48,
                horizontalMargin: 10,
                columnSpacing: 12,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
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
                    DataCell(Text(r['date']?.toString() ?? '', style: const TextStyle(fontSize: 11))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(r['client_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), softWrap: true),
                      ),
                    ),
                    DataCell(Text(r['client_code']?.toString() ?? '', style: const TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono'))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Text(r['loan_ref']?.toString() ?? '', style: const TextStyle(fontSize: 11), softWrap: true),
                      ),
                    ),
                    DataCell(Text(uInt > 0 ? CurrencyFormatter.formatNaira(uInt) : '-', style: const TextStyle(fontSize: 11, fontFeatures: [FontFeature.tabularFigures()]))),
                    DataCell(Text(uGap > 0 ? CurrencyFormatter.formatNaira(uGap) : '-', style: const TextStyle(fontSize: 11, fontFeatures: [FontFeature.tabularFigures()]))),
                    DataCell(Text(CurrencyFormatter.formatNaira(tot), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                    DataCell(Text(r['status']?.toString() ?? 'Auto-deducted on Disbursement', style: const TextStyle(fontSize: 11, color: Color(0xFF047857)), softWrap: true)),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCashBankPayoutsTable(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: const Center(child: Text('No cash or bank payouts found for the selected criteria.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13), softWrap: true)),
      );
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 48,
            horizontalMargin: 10,
            columnSpacing: 12,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
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
                DataCell(Text(r['date']?.toString() ?? '', style: const TextStyle(fontSize: 11))),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(r['client_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), softWrap: true),
                  ),
                ),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(r['group']?.toString() ?? '', style: const TextStyle(fontSize: 11), softWrap: true),
                  ),
                ),
                DataCell(Text(r['payment_type']?.toString() ?? '', style: const TextStyle(fontSize: 11))),
                DataCell(Text(CurrencyFormatter.formatNaira(amt), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Text(r['approval_notes']?.toString() ?? '', style: const TextStyle(fontSize: 11), softWrap: true),
                  ),
                ),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(r['reference']?.toString() ?? '', style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10), softWrap: true),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMyRequestsList(List<Map<String, dynamic>> requests) {
    if (requests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: const Center(child: Text('No withdrawal requests found.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13), softWrap: true)),
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
        final remarks = req['remarks']?.toString() ?? '';
        final rejReason = req['rejection_reason']?.toString() ?? '';
        final appBy = req['approved_by']?.toString() ?? '';

        Color badgeColor;
        String badgeText;
        if (stStatus == 'APPROVED') {
          badgeColor = const Color(0xFF15803D);
          badgeText = '[Approved & Posted]';
        } else if (stStatus == 'REJECTED') {
          badgeColor = const Color(0xFFB91C1C);
          badgeText = '[Rejected]';
        } else {
          badgeColor = const Color(0xFFB45309);
          badgeText = '[Waiting for Approval]';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 550;
              final infoCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name | $stype — $op | Ref: $refCode',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    softWrap: true,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Requested by: ${req['requested_by']} | Date: $opDate',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    softWrap: true,
                  ),
                  if (remarks.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Notes: $remarks',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                      softWrap: true,
                    ),
                  ],
                  if (stStatus == 'REJECTED' && rejReason.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Reason from Manager: $rejReason',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C)),
                      softWrap: true,
                    ),
                  ] else if (stStatus == 'APPROVED' && appBy.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Authorized by $appBy',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                  color: const Color(0xFF064E3B),
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
                    const Text(
                      'Withdrawal Operations',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      softWrap: true,
                    ),
                    Text(
                      isManager ? 'BM Direct Authorization Mode' : 'Credit Officer Request Mode',
                      style: TextStyle(
                        fontSize: 11,
                        color: isManager ? const Color(0xFF15803D) : const Color(0xFF2563EB),
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
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF475569)),
                  const SizedBox(width: 5),
                  Text(
                    DateFormat('dd MMM yyyy').format(opDate),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                      fontFamily: 'JetBrains Mono',
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleRow,
                const SizedBox(height: 6),
                dateCapsule,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleRow),
              const SizedBox(width: 10),
              dateCapsule,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFlashBanner() {
    if (_flashMessage == null) return const SizedBox.shrink();
    final isSuccess = _isSuccessFlash;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSuccess ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withValues(alpha: 0.05),
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
              color: isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              size: 18,
              color: isSuccess ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _flashMessage!,
              style: TextStyle(
                color: isSuccess ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            color: isSuccess ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((t) {
            final isSel = activeTab == t || (t.startsWith('Pending Approvals') && activeTab.startsWith('Pending Approvals'));
            final isPending = t.startsWith('Pending Approvals');

            IconData iconData;
            if (t == 'Individual Savings') {
              iconData = Icons.person_rounded;
            } else if (t == 'Group Savings') {
              iconData = Icons.groups_rounded;
            } else if (t == 'Misc Savings') {
              iconData = Icons.savings_rounded;
            } else if (t == 'LAPS Savings') {
              iconData = Icons.shield_rounded;
            } else if (isPending) {
              iconData = Icons.pending_actions_rounded;
            } else {
              iconData = Icons.receipt_long_rounded;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => onSelectTab(t),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSel ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                    border: isSel
                        ? Border.all(color: const Color(0xFFCBD5E1))
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        iconData,
                        size: 16,
                        color: isSel
                            ? (isPending ? const Color(0xFFDC2626) : const Color(0xFF064E3B))
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                          color: isSel
                              ? (isPending ? const Color(0xFFDC2626) : const Color(0xFF0F172A))
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA7F3D0)),
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
                  color: const Color(0xFF064E3B),
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                    if (tag != null || subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        [if (tag != null) tag, if (subtitle != null) subtitle].join(' | '),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF047857), fontWeight: FontWeight.w600),
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
              const Text(
                'AVAILABLE BALANCE',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF047857), letterSpacing: 0.5),
              ),
              Text(
                CurrencyFormatter.formatNaira(balance),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF064E3B),
                  fontFamily: 'JetBrains Mono',
                  fontFeatures: [FontFeature.tabularFigures()],
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
            const Text(
              'QUICK PRESETS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Max: ${CurrencyFormatter.formatNaira(availableBalance)}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF047857),
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
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 15, color: const Color(0xFF064E3B)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      softWrap: true,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                        softWrap: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          top: BorderSide(color: color, width: 3),
          left: const BorderSide(color: Color(0xFFE2E8F0)),
          right: const BorderSide(color: Color(0xFFE2E8F0)),
          bottom: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
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
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
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
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
                fontFamily: 'JetBrains Mono',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          Text(error, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
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
