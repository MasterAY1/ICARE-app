import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/icare_colors.dart';
import '../../../core/widgets/icare_card.dart';
import '../../../core/widgets/icare_section_header.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_database_service.dart';
import '../../../core/offline/offline_sync_manager.dart';
import '../data/datasources/co_api_service.dart';
import '../../shared/presentation/co_app_scaffold.dart';

// ==========================================
// STATE PROVIDERS
// ==========================================

final collectionsTabProvider = StateProvider<int>((ref) => 0); // 0=Record, 1=History, 2=Reversals
final collectionsModeProvider = StateProvider<String>((ref) => 'Group Collection Sheet'); // or 'Single Client Quick Entry'
final collectionsSelectedGroupProvider = StateProvider<String?>((ref) => null);
final collectionsDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final collectionsLateEntryProvider = StateProvider<bool>((ref) => false);

// ==========================================
// ASYNC DATA PROVIDERS
// ==========================================

final collectionSheetFutureProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(coApiServiceProvider);
  final grp = ref.watch(collectionsSelectedGroupProvider);
  final dt = ref.watch(collectionsDateProvider);
  final dateStr = DateFormat('yyyy-MM-dd').format(dt);
  final isOnline = ref.watch(isOnlineProvider);
  final syncMgr = ref.watch(offlineSyncManagerProvider);
  final dbService = ref.watch(offlineDatabaseServiceProvider);

  if (!isOnline) {
    if (grp != null) {
      final cached = await syncMgr.getOfflineSheet(grp);
      if (cached != null) return cached;
    }
    final cachedGroups = await dbService.getCachedGroupNames();
    if (cachedGroups.isNotEmpty) {
      final targetGrp = grp ?? cachedGroups.first;
      final cached = await syncMgr.getOfflineSheet(targetGrp);
      if (cached != null) {
        final mutable = Map<String, dynamic>.from(cached);
        mutable['available_groups'] = cachedGroups;
        return mutable;
      }
    }
  }

  try {
    final sheet = await api.getCollectionSheet(groupName: grp, date: dateStr);
    final hasMembers = sheet['members'] != null || sheet['clients'] != null;
    if (grp != null && hasMembers) {
      syncMgr.preCacheGroupSheet(grp, dateStr).ignore();
    }
    return sheet;
  } catch (e) {
    if (grp != null) {
      final cached = await syncMgr.getOfflineSheet(grp);
      if (cached != null) return cached;
    }
    final cachedGroups = await dbService.getCachedGroupNames();
    if (cachedGroups.isNotEmpty) {
      final targetGrp = grp ?? cachedGroups.first;
      final cached = await syncMgr.getOfflineSheet(targetGrp);
      if (cached != null) {
        final mutable = Map<String, dynamic>.from(cached);
        mutable['available_groups'] = cachedGroups;
        return mutable;
      }
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
  bool _isReviewingGroup = false;
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

  // Tab 2 History State
  DateTime _histDate = DateTime.now();
  final TextEditingController _histSearchCtrl = TextEditingController();
  final String _histOfficer = 'All Officers';
  int _histClientPage = 1;
  static const int _histPageSize = 10;
  String _histStatusFilter = 'ALL';

  // Tab 3 Reversal Hub State
  String _revCategory = 'Loan Repayments';
  DateTime _revDate = DateTime.now();
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

  /// Calculates staging totals and switches to Review Screen (Mode 1)
  void _calculateAndReviewGroup(List<dynamic> members, String groupName, String dateStr) {
    final toInsert = <Map<String, dynamic>>[];
    final grpSavAmt = double.tryParse(_grpSavingsCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

    for (var m in members) {
      final cid = m['client_id']?.toString() ?? '';
      final cname = m['client_name']?.toString() ?? '';
      final code = m['client_code']?.toString() ?? cid;
      final expRep = (m['expected_repayment'] as num?)?.toDouble() ?? 0.0;
      final isNotPaid = _memberNotPaidFlags[cid] == true;

      final repStr = _memberRepaymentCtrls[cid]?.text.replaceAll(',', '').trim() ?? '';
      final savStr = _memberSavingsCtrls[cid]?.text.replaceAll(',', '').trim() ?? '';

      final repAmt = isNotPaid ? 0.0 : (double.tryParse(repStr) ?? expRep);
      final savAmt = double.tryParse(savStr) ?? 0.0;

      if (repAmt > 0 || savAmt > 0 || isNotPaid) {
        String pStatus = 'PAID';
        double overdueVal = 0.0;
        if (isNotPaid) {
          pStatus = 'NOT_PAID';
          overdueVal = expRep;
        } else if (repAmt < expRep) {
          pStatus = 'PART_PAID';
          overdueVal = expRep - repAmt;
        } else if (repAmt > expRep && expRep > 0) {
          pStatus = 'EXCESS';
        }

        toInsert.add({
          'client_id': cid,
          'client_name': cname,
          'client_code': code,
          'loan_id': m['loan_id'],
          'loan_product': m['loan_product'] ?? 'Standard Loan',
          'loan_repayment_amount': repAmt,
          'savings_deposit_amount': savAmt,
          'expected_amount': expRep,
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
      _isReviewingGroup = true;
    });
  }

  /// Atomically confirms & posts batch group collections to ledger (app.py L6081)
  /// Features offline-first fallback with local SQLite outbox queuing when disconnected.
  Future<void> _confirmAndSaveBatch(String groupName, String dateStr) async {
    setState(() => _isSubmitting = true);
    final grpSavAmt = double.tryParse(_grpSavingsCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

    final payload = {
      'group_name': groupName,
      'date': dateStr,
      'group_savings_deposit': grpSavAmt,
      'group_savings_withdrawal': 0.0,
      'collections': _stagedTransactions,
    };

    try {
      final isOnline = ref.read(isOnlineProvider);
      final syncMgr = ref.read(offlineSyncManagerProvider);

      if (!isOnline) {
        // Direct offline queuing
        final offlineRes = await syncMgr.queueOfflineBatch(
          groupName: groupName,
          collectionDate: dateStr,
          payload: payload,
        );
        setState(() {
          _isReviewingGroup = false;
          _stagedTransactions = [];
          _receiptData = offlineRes['receipt'] as Map<String, dynamic>?;
          _statusBannerText = 'COLLECTION QUEUED LOCALLY (OFFLINE). Transferred to Outbox for synchronization.';
        });
        _showNotification('Offline mode: Collection saved locally on device!', isSuccess: true);
        return;
      }

      final api = ref.read(coApiServiceProvider);
      final res = await api.submitBatchCollections(payload);
      final receipt = res['receipt'] as Map<String, dynamic>?;

      setState(() {
        _isReviewingGroup = false;
        _stagedTransactions = [];
        _receiptData = receipt ?? {
          'batch_id': 'COL-$dateStr-OK',
          'group_name': groupName,
          'total_cash': res['total_cash_in'] ?? 0.0,
          'total_repayments': res['total_repayments'] ?? 0.0,
          'total_savings': res['total_savings'] ?? 0.0,
          'total_submitted': res['items_processed'] ?? 0,
          'timestamp': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
        };
        _statusBannerText = null;
      });

      ref.invalidate(collectionSheetFutureProvider);
      ref.invalidate(singleClientOptionsProvider);
    } catch (e) {
      if (e is DioException) {
        try {
          final syncMgr = ref.read(offlineSyncManagerProvider);
          final offlineRes = await syncMgr.queueOfflineBatch(
            groupName: groupName,
            collectionDate: dateStr,
            payload: payload,
          );
          setState(() {
            _isReviewingGroup = false;
            _stagedTransactions = [];
            _receiptData = offlineRes['receipt'] as Map<String, dynamic>?;
            _statusBannerText = 'NETWORK INTERRUPTED: Collection saved locally in offline outbox.';
          });
          _showNotification('Network unavailable. Collection safely stored locally on device!', isSuccess: true);
          return;
        } catch (_) {
          // If local queue fails, surface error
        }
      }
      _showNotification('Failed to post batch collections: $e', isSuccess: false);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  /// Posts single client quick entry (app.py L5377)
  Future<void> _submitSingleClient(Map<String, dynamic> clientObj, String dateStr) async {
    final savVal = double.tryParse(_scPersonalSavCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final grpSavVal = double.tryParse(_scGroupSavCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final repVal = double.tryParse(_scLoanRepCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final appVal = double.tryParse(_scAppFeeCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final pbVal = double.tryParse(_scPbFeeCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final miscVal = double.tryParse(_scMiscFeeCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

    if (savVal == 0 && grpSavVal == 0 && repVal == 0 && appVal == 0 && pbVal == 0 && miscVal == 0) {
      _showNotification('Please enter a Personal Savings Deposit, Group Savings Deposit, Loan Repayment, or Fee amount greater than ₦0.', isSuccess: false);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(coApiServiceProvider);
      final payload = {
        'client_id': clientObj['client_id'],
        'client_name': clientObj['client_name'],
        'group_id': clientObj['group_id'],
        'group_name': clientObj['group_name'],
        'loan_id': _scSelectedLoanId,
        'date': dateStr,
        'savings_deposit': savVal,
        'group_savings_deposit': grpSavVal,
        'loan_repayment': repVal,
        'app_fee': appVal,
        'passbook_fee': pbVal,
        'misc_fee': miscVal,
        'note': _scNoteCtrl.text.trim(),
      };

      final res = await api.submitSingleCollection(payload);
      final receipt = res['receipt'] as Map<String, dynamic>?;

      setState(() {
        _receiptData = receipt ?? {
          'batch_id': res['batch_id'] ?? 'COL-SC-OK',
          'group_name': clientObj['group_name'] ?? 'Single Client',
          'total_cash': res['total_cash'] ?? (savVal + grpSavVal + repVal + appVal + pbVal + miscVal),
          'total_repayment': repVal,
          'total_savings': savVal + grpSavVal,
          'total_submitted': 1,
          'timestamp': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
        };
        _scPersonalSavCtrl.clear();
        _scGroupSavCtrl.clear();
        _scLoanRepCtrl.clear();
        _scAppFeeCtrl.clear();
        _scPbFeeCtrl.clear();
        _scMiscFeeCtrl.clear();
        _statusBannerText = null;
      });

      ref.invalidate(singleClientOptionsProvider);
      ref.invalidate(collectionSheetFutureProvider);
    } catch (e) {
      _showNotification('Failed to submit single client collection: $e', isSuccess: false);
    } finally {
      setState(() => _isSubmitting = false);
    }
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
        'record_type': _revCategory == 'Loan Repayments' ? 'Repayment' : 'Savings Deposit',
        'reason': reason,
      });

      final reqId = res['request_id']?.toString() ?? 'REQ';
      _showNotification('Reversal request submitted to Branch Manager for approval! (Ref: #${reqId.length > 8 ? reqId.substring(0, 8) : reqId})', isSuccess: true);
      _revReasonCtrl.clear();
      setState(() => _selectedReversalRefId = null);

      ref.invalidate(reversalRequestsProvider);
      ref.invalidate(reversalOptionsProvider);
    } catch (e) {
      _showNotification('Failed to submit reversal request: $e', isSuccess: false);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // =========================================================================
  // MAIN BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(collectionsTabProvider);
    final activeDate = ref.watch(collectionsDateProvider);
    final isLateEntry = ref.watch(collectionsLateEntryProvider);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Page Title & Caption (app.py L4841-4842)
            const IcareSectionHeader(
              title: 'Daily Collections',
              subtitle: 'Record daily repayments and savings.',
            ),
            const SizedBox(height: 12),

            // 2. Top Control Bar (Late Entry toggle & Business Date Display, app.py L4848-4853)
            _buildTopControlBar(activeDate, isLateEntry),
            const SizedBox(height: 14),

            // Notification / Flash Alert Banner
            if (_statusBannerText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: _isSuccessBanner ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSuccessBanner ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccessBanner ? Icons.check_circle_outline : Icons.error_outline,
                      color: _isSuccessBanner ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusBannerText!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isSuccessBanner ? const Color(0xFF166534) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _statusBannerText = null),
                    ),
                  ],
                ),
              ),
            ],

            // 3. Primary Navigation Tabs (Zero Emojis, app.py L4976)
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
    return Positioned.fill(
      child: Container(
        color: const Color(0xD90F172A), // Dark slate translucent backdrop
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                    color: const Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Posting Collections to Ledger',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Committing atomic journal entries to Account 1000 and updating client balances...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 13, color: Color(0xFF475569)),
                      SizedBox(width: 6),
                      Text(
                        'Idempotency lock active • Do not close',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
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

  Widget _buildTopControlBar(DateTime activeDate, bool isLateEntry) {
    return IcareCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final lateEntryToggle = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: isLateEntry,
                activeColor: IcareColors.primary,
                onChanged: (val) {
                  ref.read(collectionsLateEntryProvider.notifier).state = val;
                  if (!val) {
                    ref.read(collectionsDateProvider.notifier).state = DateTime.now();
                  }
                },
              ),
              const SizedBox(width: 8),
              const Text(
                'Late Entry / Backdated Entry',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ],
          );

          final dateDisplay = isLateEntry
              ? InkWell(
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
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Text(
                          'Select Date: ${DateFormat('dd MMMM yyyy').format(activeDate)}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF1D4ED8)),
                      ],
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Color(0xFF475569)),
                      const SizedBox(width: 8),
                      Text(
                        'Operational Date: ${DateFormat('dd MMMM yyyy').format(activeDate)} (${DateFormat('EEEE').format(activeDate)})',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                );

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                lateEntryToggle,
                const SizedBox(height: 10),
                dateDisplay,
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              lateEntryToggle,
              dateDisplay,
            ],
          );
        },
      ),
    );
  }

  Widget _buildPrimaryTabs(int activeTab) {
    final tabLabels = [
      'Record Collections',
      'Collection History & Audit',
      'Error Correction & Reversals',
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(tabLabels.length, (idx) {
            final isSel = activeTab == idx;
            return InkWell(
              onTap: () => ref.read(collectionsTabProvider.notifier).state = idx,
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: isSel ? Colors.white : Colors.transparent,
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
                child: Text(
                  tabLabels[idx],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                    color: isSel ? const Color(0xFF065F46) : const Color(0xFF64748B),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A. Persistent Collection Receipt Confirmation Card (app.py L4889-4975)
        if (_receiptData != null) ...[
          _buildPersistentReceiptCard(),
          const SizedBox(height: 20),
        ],

        // B. Mode Selector Card (app.py L4992)
        IcareCard(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final modes = ['Group Collection Sheet', 'Single Client Quick Entry'];

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COLLECTION MODE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: modes.map((m) {
                        final isSel = mode == m;
                        final isGroup = m == 'Group Collection Sheet';
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: isGroup ? 8.0 : 0),
                            child: InkWell(
                              onTap: () {
                                setState(() => _isReviewingGroup = false);
                                ref.read(collectionsModeProvider.notifier).state = m;
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSel ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isGroup ? Icons.groups_outlined : Icons.person_outline,
                                      size: 16,
                                      color: isSel ? const Color(0xFF065F46) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        isGroup ? 'Group Sheet' : 'Single Client',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                                          color: isSel ? const Color(0xFF065F46) : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
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

              return Row(
                children: [
                  const Text(
                    'Collection Mode:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const SizedBox(width: 16),
                  _buildModeRadioButton('Group Collection Sheet', mode),
                  const SizedBox(width: 16),
                  _buildModeRadioButton('Single Client Quick Entry', mode),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // C. Render Selected Mode View
        if (mode == 'Group Collection Sheet')
          _buildGroupCollectionSheetMode()
        else
          _buildSingleClientQuickEntryMode(),
      ],
    );
  }

  Widget _buildModeRadioButton(String title, String currentMode) {
    final isSel = currentMode == title;
    return InkWell(
      onTap: () {
        setState(() {
          _isReviewingGroup = false;
        });
        ref.read(collectionsModeProvider.notifier).state = title;
      },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSel ? const Color(0xFF065F46) : const Color(0xFF94A3B8),
                  width: 2,
                ),
              ),
              child: isSel
                  ? Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                color: isSel ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // PERSISTENT RECEIPT CONFIRMATION CARD (app.py L4889–4975)
  // =========================================================================

  Widget _buildPersistentReceiptCard() {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOfflineQueued ? const Color(0xFFD97706) : const Color(0xFF059669),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isOfflineQueued ? const Color(0x10D97706) : const Color(0x10059669),
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
              color: isOfflineQueued ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
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
                    color: isOfflineQueued ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isOfflineQueued ? const Color(0xFFFDE68A) : const Color(0xFF86EFAC),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isOfflineQueued ? Icons.cloud_upload_outlined : Icons.check_circle_outline,
                    color: isOfflineQueued ? const Color(0xFFD97706) : const Color(0xFF059669),
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
                          color: isOfflineQueued ? const Color(0xFF92400E) : const Color(0xFF064E3B),
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isOfflineQueued
                            ? 'Batch stored in local outbox on device. Final ledger posting to Account 1000 will occur upon network synchronization.'
                            : 'All member repayments and savings deposits have been committed to the ledger with physical cash recorded in Account 1000.',
                        style: TextStyle(
                          fontSize: isMobile ? 11.5 : 12.5,
                          color: isOfflineQueued ? const Color(0xFFB45309) : const Color(0xFF047857),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isOfflineQueued ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0)),

          // Metadata Grid (4-pillar metadata capsules)
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
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 4 Executive KPI Summary Cards
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final c1 = _buildReceiptKpiCard('Total Cash Collected', CurrencyFormatter.formatNaira(totalCash, showDecimals: true), const Color(0xFF059669), isHero: true);
                final c2 = _buildReceiptKpiCard('Loan Repayments', CurrencyFormatter.formatNaira(totalRep, showDecimals: true), const Color(0xFF2563EB));
                final c3 = _buildReceiptKpiCard('Savings Deposits', CurrencyFormatter.formatNaira(totalSav, showDecimals: true), const Color(0xFF0D9488));
                final c4 = _buildReceiptKpiCard('Members Accounted', '$totalRecs records', const Color(0xFF475569));

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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF1E40AF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Idempotency Protection Active: $alreadySaved records were safely identified from an earlier network attempt and skipped to guarantee zero duplicate postings.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
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
                title: const Text(
                  'View Itemized Member Verification Breakdown',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                ),
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 550),
                        child: Table(
                          border: TableBorder.all(color: const Color(0xFFF1F5F9)),
                          columnWidths: const {
                            0: FlexColumnWidth(2.2),
                            1: FlexColumnWidth(1.4),
                            2: FlexColumnWidth(1.4),
                            3: FlexColumnWidth(1.2),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                              children: const [
                                Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Client / Member', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF475569)))),
                                Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Repayment (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF475569)))),
                                Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Savings (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF475569)))),
                                Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Posting Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF475569)))),
                              ],
                            ),
                            ...items.map((it) {
                              final cName = it['client']?.toString() ?? 'Member';
                              final rep = (it['repayment'] as num?)?.toDouble() ?? 0.0;
                              final sav = (it['savings'] as num?)?.toDouble() ?? 0.0;
                              final stat = it['status']?.toString() ?? 'POSTED';
                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Text(cName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)), softWrap: true),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Text(rep > 0 ? CurrencyFormatter.formatNaira(rep, showDecimals: true) : '—', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Text(sav > 0 ? CurrencyFormatter.formatNaira(sav, showDecimals: true) : '—', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF86EFAC))),
                                      child: Text(stat, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF15803D)), textAlign: TextAlign.center),
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
              title: const Text(
                'View / Copy WhatsApp Summary',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
              ),
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: EdgeInsets.all(isMobile ? 12 : 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
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
                      backgroundColor: const Color(0xFF064E3B),
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
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
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
                  child: const Icon(Icons.copy, size: 14, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptKpiCard(String label, String value, Color valueColor, {bool isHero = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          top: BorderSide(color: valueColor, width: 3),
          left: BorderSide(color: isHero ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
          right: BorderSide(color: isHero ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
          bottom: BorderSide(color: isHero ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
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

  Widget _buildPulseKpiCard(String label, String value, String subtitle, {Color accentColor = const Color(0xFF2563EB), bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          top: BorderSide(color: isAlert ? const Color(0xFFDC2626) : accentColor, width: 3),
          left: BorderSide(color: isAlert ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
          right: BorderSide(color: isAlert ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
          bottom: BorderSide(color: isAlert ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
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
                color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // =========================================================================
  // MODE 1: GROUP COLLECTION SHEET (app.py L5523–6250)
  // =========================================================================

  Widget _buildGroupCollectionSheetMode() {
    final sheetAsync = ref.watch(collectionSheetFutureProvider);
    final selectedDate = ref.watch(collectionsDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    return sheetAsync.when(
      loading: () => const IcareFormSkeleton(fieldCount: 5),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFCA5A5))),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('Error loading collection sheet: $err', style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13))),
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

        // If in Staging / Review Mode, render Review Screen (app.py L6012)
        if (_isReviewingGroup) {
          return _buildReviewGroupCollectionsView(currentGroup, dateStr, isOpen, openReason);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Selection Card & Meeting Day
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Solidarity Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: availableGroups.contains(currentGroup) ? currentGroup : availableGroups.first,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          items: availableGroups.map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))).toList(),
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
                        const Text('Meeting Day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            '$meetingDay (${DateFormat('dd MMM').format(selectedDate)})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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
                            const Text('Select Solidarity Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: availableGroups.contains(currentGroup) ? currentGroup : availableGroups.first,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                              items: availableGroups.map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))).toList(),
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
                            const Text('Meeting Day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                '$meetingDay (${DateFormat('dd MMM').format(selectedDate)})',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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

            // Communal Group Savings Row (app.py L5767-5781)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Group Communal Savings · Available: ${CurrencyFormatter.formatNaira(grpSavingsBal)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                        ),
                        const SizedBox(height: 2),
                        const Text('Communal group contribution', style: TextStyle(fontSize: 12, color: Color(0xFF15803D))),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _grpSavingsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Group Savings (₦)',
                            hintText: '0',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF86EFAC))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF86EFAC))),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Group Communal Savings · Available: ${CurrencyFormatter.formatNaira(grpSavingsBal)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                            ),
                            const SizedBox(height: 2),
                            const Text('Communal group contribution', style: TextStyle(fontSize: 12, color: Color(0xFF15803D))),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _grpSavingsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Group Savings (₦)',
                            hintText: '0',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF86EFAC))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF86EFAC))),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Group Meeting Pulse Bar (app.py L5650-5750 parity)
            Builder(
              builder: (context) {
                final totalExpRep = members.fold<double>(0.0, (acc, m) => acc + ((m['expected_repayment'] as num?)?.toDouble() ?? 0.0));
                final totalArrears = members.fold<double>(0.0, (acc, m) => acc + ((m['overdue_arrears'] as num?)?.toDouble() ?? 0.0));
                final payingCount = members.where((m) => ((m['expected_repayment'] as num?)?.toDouble() ?? 0.0) > 0).length;

                final p1 = _buildPulseKpiCard('Expected Repayment', CurrencyFormatter.formatNaira(totalExpRep), '$payingCount Members Due', accentColor: const Color(0xFF065F46));
                final p2 = _buildPulseKpiCard('Overdue Arrears', CurrencyFormatter.formatNaira(totalArrears), totalArrears > 0 ? 'Action Needed' : 'None in Group', accentColor: const Color(0xFFDC2626), isAlert: totalArrears > 0);
                final p3 = _buildPulseKpiCard('Communal Savings', CurrencyFormatter.formatNaira(grpSavingsBal), 'Group Reserve Fund', accentColor: const Color(0xFF2563EB));
                final p4 = _buildPulseKpiCard('Group Size', '${members.length} Members', 'Active in Meeting', accentColor: const Color(0xFF475569));

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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                Row(
                  children: [
                    Checkbox(
                      value: _expandAllMembers,
                      activeColor: const Color(0xFF065F46),
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
                    const Text('Expand All Members', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Empty State Check (app.py L5565)
            if (members.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(Icons.people_outline, size: 36, color: Color(0xFF94A3B8)),
                      SizedBox(height: 8),
                      Text('No active members in this group.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w600)),
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
                  for (final m in members) {
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
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
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
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Live Collection Progress',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                                ),
                              ],
                            ),
                            Text(
                              '$accountedCount / ${members.length} Accounted',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressPct,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFDCFCE7),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Collected: ${CurrencyFormatter.formatNaira(liveTotal)}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                            ),
                            Text(
                              'Target: ${CurrencyFormatter.formatNaira(totalTarget)}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Member Collection Cards
              ...members.map((m) => _buildMemberCollectionCard(m)),
              const SizedBox(height: 20),

              // Calculate Totals & Review Members Button (app.py L6243)
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
                      onPressed: () => _calculateAndReviewGroup(members, currentGroup, dateStr),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF064E3B),
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
    final cid = m['client_id']?.toString() ?? '';
    final code = m['client_code']?.toString() ?? cid;
    final name = m['client_name']?.toString() ?? 'Client';
    final actCred = (m['active_credit'] as num?)?.toDouble() ?? 0.0;
    final remBal = (m['remaining_balance'] as num?)?.toDouble() ?? 0.0;
    final expRep = (m['expected_repayment'] as num?)?.toDouble() ?? 0.0;
    final savBal = (m['savings_balance'] as num?)?.toDouble() ?? 0.0;
    final hasOverdue = m['has_overdue'] == true;
    final overdueArrears = (m['overdue_arrears'] as num?)?.toDouble() ?? 0.0;
    final prodName = m['loan_product']?.toString() ?? 'Loan';
    final isFutureLoan = m['is_future_loan'] == true;

    // Initialize state controllers for member
    _memberRepaymentCtrls.putIfAbsent(cid, () => TextEditingController(text: expRep > 0 ? expRep.toStringAsFixed(0) : '0'));
    _memberSavingsCtrls.putIfAbsent(cid, () => TextEditingController());
    _memberNotPaidFlags.putIfAbsent(cid, () => false);
    final isNotPaid = _memberNotPaidFlags[cid] == true;
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? const Color(0xFF059669)
              : (isNotPaid
                  ? const Color(0xFFFCA5A5)
                  : (hasOverdue ? const Color(0xFFFCD34D) : (clientTotal > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)))),
          width: isExpanded ? 1.8 : (isNotPaid || hasOverdue || clientTotal > 0 ? 1.5 : 1),
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded ? const Color(0x14059669) : const Color(0x080F172A),
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
                                ? const Color(0xFFFEE2E2)
                                : (hasOverdue ? const Color(0xFFFEF3C7) : (isExpanded ? const Color(0xFFECFDF5) : const Color(0xFFF0FDF4))),
                            border: Border.all(
                              color: isNotPaid
                                  ? const Color(0xFFFCA5A5)
                                  : (hasOverdue ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0)),
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
                                    ? const Color(0xFFDC2626)
                                    : (hasOverdue ? const Color(0xFFB45309) : const Color(0xFF065F46)),
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
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                              children: [
                                TextSpan(
                                  text: ' ($code)',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
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
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                child: Text(prodName, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                              ),
                              if (expRep > 0)
                                Text(
                                  'Exp: ${CurrencyFormatter.formatNaira(expRep)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Collapsed Status Pill
                    if (!isExpanded) ...[
                      if (isNotPaid)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFECACA))),
                          child: const Text('₦0 Arrears', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                        )
                      else if (clientTotal > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFA7F3D0))),
                          child: Text(CurrencyFormatter.formatNaira(clientTotal), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
                        ),
                      const SizedBox(width: 6),
                    ],
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: const Color(0xFF64748B),
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ACTIVE CREDIT', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.formatNaira(actCred),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontFeatures: [FontFeature.tabularFigures()]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 22, color: const Color(0xFFE2E8F0)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('REMAINING', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.formatNaira(remBal),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontFeatures: [FontFeature.tabularFigures()]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 22, color: const Color(0xFFE2E8F0)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SAVINGS BAL', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF065F46)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.formatNaira(savBal),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46), fontFeatures: [FontFeature.tabularFigures()]),
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
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFDE68A))),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFB45309)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Overdue Arrears: ${CurrencyFormatter.formatNaira(overdueArrears)}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
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
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFBFDBFE))),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 15, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'First installment starts on ${m['start_date'] ?? 'next meeting'}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
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
                  const Text('Loan Repayment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Expected Pill
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
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Text(
                              'Expected: ₦${expRep.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                            ),
                          ),
                        ),
                      // Payoff Pill
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
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              'Payoff: ₦${remBal.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                            ),
                          ),
                        ),
                      // ₦0 Arrears Pill
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
                            color: isNotPaid ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isNotPaid ? const Color(0xFFF87171) : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isNotPaid ? Icons.check_circle : Icons.circle_outlined,
                                size: 11,
                                color: isNotPaid ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '₦0 Arrears',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isNotPaid ? const Color(0xFFDC2626) : const Color(0xFF475569),
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
                enabled: !isNotPaid,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isNotPaid ? const Color(0xFFF1F5F9) : Colors.white,
                  prefixText: '₦ ',
                  prefixStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  hintText: 'Expected: ${expRep.toStringAsFixed(0)}',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF065F46), width: 1.8)),
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
                  const Text('Savings Deposit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
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
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              '+₦$amt',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
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
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: const Text(
                              'Clear',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
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
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  prefixText: '₦ ',
                  prefixStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  hintText: '0',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF065F46), width: 1.8)),
                ),
              ),
              const SizedBox(height: 10),

              // Member Card Footer Summary
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: clientTotal > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: clientTotal > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
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
                        color: clientTotal > 0 ? const Color(0xFF065F46) : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'Total: ${CurrencyFormatter.formatNaira(clientTotal)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: clientTotal > 0 ? const Color(0xFF065F46) : const Color(0xFF0F172A),
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
  // REVIEW GROUP COLLECTIONS STAGING SCREEN (app.py L6012–6090)
  // =========================================================================

  Widget _buildReviewGroupCollectionsView(String groupName, String dateStr, bool isOpen, String openReason) {
    final grpSavAmt = double.tryParse(_grpSavingsCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

    double totalRep = 0.0;
    double totalSav = grpSavAmt;
    int paidCount = 0;
    int notPaidCount = 0;
    for (var tx in _stagedTransactions) {
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
    final totalIn = totalRep + totalSav;
    final netCash = totalIn; // Total Cash Inflow

    final isLateEntry = ref.watch(collectionsLateEntryProvider);
    final canSubmit = isOpen || isLateEntry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Navigation pill
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Review Group Collections',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Verify all collection entries for $groupName before final ledger commitment.',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _isReviewingGroup = false),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to Edit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Modern 3-Tile Executive Summary Grid (Total Money Given Out removed)
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final card1 = _buildReviewMetricCard(
              title: 'Net Cash Expected From Group',
              value: CurrencyFormatter.formatNaira(netCash, showDecimals: true),
              subtitle: 'Gross physical cash payable to vault',
              icon: Icons.payments_outlined,
              accentColor: const Color(0xFF059669),
              bgColor: const Color(0xFFF0FDF4),
              isHero: true,
            );
            final card2 = _buildReviewMetricCard(
              title: 'Total Loan Repayments',
              value: CurrencyFormatter.formatNaira(totalRep, showDecimals: true),
              subtitle: '$paidCount paying member(s)${notPaidCount > 0 ? ' • $notPaidCount arrears' : ''}',
              icon: Icons.assignment_turned_in_outlined,
              accentColor: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
            );
            final card3 = _buildReviewMetricCard(
              title: 'Total Net Savings',
              value: CurrencyFormatter.formatNaira(totalSav, showDecimals: true),
              subtitle: grpSavAmt > 0
                  ? 'Includes ${CurrencyFormatter.formatNaira(grpSavAmt)} communal savings'
                  : 'Individual member savings',
              icon: Icons.savings_outlined,
              accentColor: const Color(0xFF0D9488),
              bgColor: const Color(0xFFF0FDFA),
            );

            if (w < 700) {
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
        const SizedBox(height: 16),

        // Optional Group Communal Savings Callout Banner
        if (grpSavAmt > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.account_balance, size: 16, color: Color(0xFF0284C7)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Group Communal Savings: ${CurrencyFormatter.formatNaira(grpSavAmt)} entered for $groupName will be posted alongside individual collections.',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Review Items Card Table
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Staged Collections Checklist (${_stagedTransactions.length} Members)',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const Text(
                      'Account 1000 Physical Inflow',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 680),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.6),
                      1: FlexColumnWidth(1.4),
                      2: FlexColumnWidth(1.8),
                      3: FlexColumnWidth(1.8),
                    },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                        children: const [
                          Padding(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11), child: Text('Client / Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF475569)))),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11), child: Text('Savings (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF475569)))),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11), child: Text('Repayment (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF475569)))),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11), child: Text('Payment Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF475569)))),
                        ],
                      ),
                      if (grpSavAmt > 0)
                        TableRow(
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              child: Text('$groupName (Communal)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0369A1))),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              child: Text(CurrencyFormatter.formatNaira(grpSavAmt), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: Color(0xFF0F172A))),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              child: Text('—', style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFBAE6FD))),
                                child: const Text('GROUP SAVINGS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)), textAlign: TextAlign.center),
                              ),
                            ),
                          ],
                        ),
                      ..._stagedTransactions.map((tx) {
                        final cName = tx['client_name']?.toString() ?? '';
                        final cCode = tx['client_code']?.toString() ?? '';
                        final sDep = (tx['savings_deposit_amount'] as num?)?.toDouble() ?? 0.0;
                        final lRep = (tx['loan_repayment_amount'] as num?)?.toDouble() ?? 0.0;
                        final expAmt = (tx['expected_amount'] as num?)?.toDouble() ?? 0.0;
                        final pStat = tx['payment_status']?.toString() ?? 'PAID';
                        final ovAmt = (tx['overdue_amount'] as num?)?.toDouble() ?? 0.0;

                        String badgeText = 'FULL PAID';
                        Color badgeBg = const Color(0xFFECFDF5);
                        Color badgeFg = const Color(0xFF065F46);
                        Color badgeBorder = const Color(0xFFA7F3D0);
                        String repDisplay = CurrencyFormatter.formatNaira(lRep);

                        if (pStat == 'NOT_PAID') {
                          badgeText = 'NOT PAID (₦${ovAmt.toStringAsFixed(0)} Arrears)';
                          badgeBg = const Color(0xFFFEF2F2);
                          badgeFg = const Color(0xFFDC2626);
                          badgeBorder = const Color(0xFFFECACA);
                          repDisplay = '₦0 (Exp ₦${expAmt.toStringAsFixed(0)})';
                        } else if (pStat == 'PART_PAID') {
                          badgeText = 'PART PAID (₦${ovAmt.toStringAsFixed(0)} Arrears)';
                          badgeBg = const Color(0xFFFFFBEB);
                          badgeFg = const Color(0xFFB45309);
                          badgeBorder = const Color(0xFFFDE68A);
                        } else if (pStat == 'EXCESS') {
                          badgeText = 'EXCESS (+₦${(lRep - expAmt).toStringAsFixed(0)})';
                          badgeBg = const Color(0xFFEFF6FF);
                          badgeFg = const Color(0xFF1D4ED8);
                          badgeBorder = const Color(0xFFBFDBFE);
                        }

                        return TableRow(
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A)), softWrap: true),
                                  Text(cCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Text(
                                sDep > 0 ? CurrencyFormatter.formatNaira(sDep) : '—',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: sDep > 0 ? FontWeight.w700 : FontWeight.w500,
                                  color: sDep > 0 ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Text(
                                repDisplay,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: lRep > 0 ? FontWeight.w700 : FontWeight.w500,
                                  color: pStat == 'NOT_PAID' ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: badgeBorder),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: badgeFg),
                                  textAlign: TextAlign.center,
                                ),
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
          ),
        ),
        const SizedBox(height: 20),

        // Action Buttons: Edit / Go Back and Confirm & Commit Collections
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            final backBtn = SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _isReviewingGroup = false),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Edit / Go Back', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            );

            final isOnline = ref.watch(isOnlineProvider);
            final submitBtn = SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (!canSubmit || _isSubmitting) ? null : () => _confirmAndSaveBatch(groupName, dateStr),
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(isOnline ? Icons.check_circle_outline : Icons.cloud_upload_outlined, size: 18),
                label: Text(
                  _isSubmitting
                      ? (isOnline ? 'Posting to Ledger...' : 'Queueing in Outbox...')
                      : (canSubmit
                          ? (isOnline
                              ? 'Confirm & Save Collections (${CurrencyFormatter.formatNaira(netCash)})'
                              : 'Queue Offline Batch (${CurrencyFormatter.formatNaira(netCash)})')
                          : 'Operational Suspended ($openReason)'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOnline ? const Color(0xFF064E3B) : const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF94A3B8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                ),
              ),
            );

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  submitBtn,
                  const SizedBox(height: 10),
                  backBtn,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 2, child: backBtn),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: submitBtn),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildReviewMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    bool isHero = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: BorderSide(color: accentColor, width: 3),
          left: BorderSide(color: isHero ? accentColor.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
          right: BorderSide(color: isHero ? accentColor.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
          bottom: BorderSide(color: isHero ? accentColor.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 16, color: accentColor),
              ),
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
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isHero ? accentColor : const Color(0xFF0F172A),
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MODE 2: SINGLE CLIENT QUICK ENTRY (app.py L5249–5380)
  // =========================================================================

  Widget _buildSingleClientQuickEntryMode() {
    final optsAsync = ref.watch(singleClientOptionsProvider);
    final selectedDate = ref.watch(collectionsDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    return optsAsync.when(
      loading: () => const IcareFormSkeleton(fieldCount: 4),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
        child: Text('Error loading clients: $err', style: const TextStyle(color: Colors.red)),
      ),
      data: (data) {
        final clients = (data['clients'] as List<dynamic>?) ?? [];
        if (clients.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('No registered active clients found.', style: TextStyle(color: Color(0xFF64748B)))),
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

        // Filter clients by group and search query
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

        // Selected client
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
        final prodName = activeLoan != null ? activeLoan['product']?.toString() ?? 'Loan' : 'No Active Loan';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Single Client Collection / Savings Deposit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            const Text(
              'Record an ad-hoc savings deposit, loan repayment, or fee for an individual member without affecting other group records.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            // Search & Group Filter Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filter & Search Clients', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final groupDropdown = DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: sortedGroups.contains(_scSelectedGroupFilter) ? _scSelectedGroupFilter : 'All Groups',
                        decoration: InputDecoration(
                          labelText: 'Solidarity Group',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                        items: sortedGroups.map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))).toList(),
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
                        decoration: InputDecoration(
                          labelText: 'Search Client Name / Code',
                          hintText: 'e.g. Adebayo or CL-010',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                          suffixIcon: _scSearchText.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _scSearchCtrl.clear();
                                      _scSearchText = '';
                                    });
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
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
                  const Text('Select Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  if (filteredClients.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFECACA))),
                      child: const Text(
                        'No clients match the selected group or search filter. Select "All Groups" or clear search.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF991B1B)),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: filteredClients.any((c) => c['client_id']?.toString() == _scSelectedClientId)
                          ? _scSelectedClientId
                          : (filteredClients.isNotEmpty ? filteredClients.first['client_id']?.toString() : null),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
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
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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
                        return DropdownMenuItem(
                          value: cid,
                          child: Text(
                            '$cname ($ccode) — Group: $cgname',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Center(
                  child: Text('No client selected. Please choose a solidarity group or adjust search filters above.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
              ),
            ] else ...[
            const SizedBox(height: 16),

            // Client Overview Cards (app.py L5335-5345)
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
            const SizedBox(height: 16),

            // Form Inputs Container (app.py L5347)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Loan Selector if multiple loans
                  if (loans.length > 1) ...[
                    const Text('Select Active Loan to Repay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _scSelectedLoanId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      items: loans.map((l) {
                        return DropdownMenuItem<String>(
                          value: l['loan_id']?.toString(),
                          child: Text(l['label']?.toString() ?? 'Loan', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _scSelectedLoanId = val),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Core Inputs: Personal Savings, Group Savings, Loan Repayment
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 600) {
                        return Column(
                          children: [
                            TextField(
                              controller: _scPersonalSavCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                filled: true,
                                fillColor: Color(0xFFF8FAFC),
                                labelText: 'Personal Savings Deposit (₦)',
                                hintText: '0',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            if (isInGroup) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _scGroupSavCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  filled: true,
                                  fillColor: Color(0xFFF8FAFC),
                                  labelText: 'Group Savings Deposit (₦)',
                                  hintText: '0',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextField(
                              controller: _scLoanRepCtrl,
                              enabled: activeLoan != null,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: activeLoan != null ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
                                labelText: activeLoan != null ? 'Loan Repayment ($prodName) (₦)' : 'No Active Loan (₦0)',
                                hintText: activeLoan != null ? 'Expected: ${CurrencyFormatter.formatNaira(expRep)}' : '0',
                                border: const OutlineInputBorder(),
                              ),
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
                              decoration: const InputDecoration(
                                filled: true,
                                fillColor: Color(0xFFF8FAFC),
                                labelText: 'Personal Savings Deposit (₦)',
                                hintText: '0',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          if (isInGroup) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _scGroupSavCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  filled: true,
                                  fillColor: Color(0xFFF8FAFC),
                                  labelText: 'Group Savings Deposit (₦)',
                                  hintText: '0',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _scLoanRepCtrl,
                              enabled: activeLoan != null,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: activeLoan != null ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
                                labelText: activeLoan != null ? 'Loan Repayment ($prodName) (₦)' : 'No Active Loan (₦0)',
                                hintText: activeLoan != null ? 'Expected: ${CurrencyFormatter.formatNaira(expRep)}' : '0',
                                border: const OutlineInputBorder(),
                              ),
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
                      title: const Text('Additional Fees (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 600) {
                              return Column(
                                children: [
                                  TextField(
                                    controller: _scAppFeeCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      filled: true,
                                      fillColor: Color(0xFFF8FAFC),
                                      labelText: 'App Fee (₦)',
                                      prefixText: '₦ ',
                                      hintText: '0',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _scPbFeeCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      filled: true,
                                      fillColor: Color(0xFFF8FAFC),
                                      labelText: 'Pass Book (₦)',
                                      prefixText: '₦ ',
                                      hintText: '0',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _scMiscFeeCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      filled: true,
                                      fillColor: Color(0xFFF8FAFC),
                                      labelText: 'Misc Fee (₦)',
                                      prefixText: '₦ ',
                                      hintText: '0',
                                      border: OutlineInputBorder(),
                                    ),
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
                                    decoration: const InputDecoration(
                                      filled: true,
                                      fillColor: Color(0xFFF8FAFC),
                                      labelText: 'App Fee (₦)',
                                      prefixText: '₦ ',
                                      hintText: '0',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _scPbFeeCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      filled: true,
                                      fillColor: Color(0xFFF8FAFC),
                                      labelText: 'Pass Book (₦)',
                                      prefixText: '₦ ',
                                      hintText: '0',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _scMiscFeeCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      filled: true,
                                      fillColor: Color(0xFFF8FAFC),
                                      labelText: 'Misc Fee (₦)',
                                      prefixText: '₦ ',
                                      hintText: '0',
                                      border: OutlineInputBorder(),
                                    ),
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
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFFF8FAFC),
                      labelText: 'Transaction Note / Remarks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button (app.py L5375)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : () => _submitSingleClient(selClient, dateStr),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF065F46),
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

  Widget _buildSingleClientKpiCard(String label, String value, {Color accentColor = const Color(0xFF059669)}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          top: BorderSide(color: accentColor, width: 3),
          left: const BorderSide(color: Color(0xFFE2E8F0)),
          right: const BorderSide(color: Color(0xFFE2E8F0)),
          bottom: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600), softWrap: true, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                fontFamily: 'monospace',
                fontFeatures: [FontFeature.tabularFigures()],
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
    final dateStr = DateFormat('yyyy-MM-dd').format(_histDate);
    final search = _histSearchCtrl.text.trim();
    final histAsync = ref.watch(collectionsHistoryProvider((dateStr: dateStr, search: search, officer: _histOfficer)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Collection History & Audit',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
        ),
        const SizedBox(height: 3),
        const Text(
          'Inspect all daily repayments and savings deposits posted by Credit Officers.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),

        // Filter Controls: Filter Date & Search (app.py L6387-6398)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
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
                    initialDate: _histDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
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
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF475569)),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd MMM yyyy').format(_histDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              );

              final searchField = TextField(
                controller: _histSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search Client Name / Code / Group / Ref...',
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.5)),
                ),
                onChanged: (_) => setState(() => _histClientPage = 1),
                onSubmitted: (_) => setState(() => _histClientPage = 1),
              );

              final refreshBtn = Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF334155), size: 20),
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
                  ],
                );
              }
              return Row(
                children: [
                  datePicker,
                  const SizedBox(width: 12),
                  Expanded(child: searchField),
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
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
            child: Text('Error loading history: $err', style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
          ),
          data: (hData) {
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
                    final k1 = _buildHistoryKpiCard('Total Repayments', CurrencyFormatter.formatNaira(totReps), '$paidCnt Paid • $notPaidCnt Arrears', accentColor: const Color(0xFF065F46), icon: Icons.assignment_turned_in_outlined);
                    final k2 = _buildHistoryKpiCard('Total Savings', CurrencyFormatter.formatNaira(totSav), '$savCnt Deposits', accentColor: const Color(0xFF2563EB), icon: Icons.savings_outlined);
                    final k3 = _buildHistoryKpiCard('Grand Total Inflow', CurrencyFormatter.formatNaira(grandTotal), 'Total Cash Collected', isGrand: true, accentColor: const Color(0xFF10B981), icon: Icons.payments_outlined);
                    final k4 = _buildHistoryKpiCard('Active Groups', '${groups.length} ${groups.length == 1 ? 'Group' : 'Groups'}', '${repayments.length + savings.length} Total Txns', accentColor: const Color(0xFF6366F1), icon: Icons.groups_outlined);

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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: ExpansionTile(
                        title: Text(
                          'Reversed Records on this Date (Audit Trail: ${reversals.length})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                        ),
                        subtitle: const Text(
                          'These transactions were reversed and are omitted from active collections and daily totals.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 680),
                              child: Table(
                                border: TableBorder.all(color: const Color(0xFFF1F5F9)),
                                columnWidths: const {
                                  0: FlexColumnWidth(1.2),
                                  1: FlexColumnWidth(2),
                                  2: FlexColumnWidth(1.2),
                                  3: FlexColumnWidth(1),
                                  4: FlexColumnWidth(1.2),
                                  5: FlexColumnWidth(2.5),
                                },
                                children: [
                                  const TableRow(
                                    decoration: BoxDecoration(color: Color(0xFFFEF2F2)),
                                    children: [
                                      Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF991B1B)))),
                                      Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text('Client', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF991B1B)))),
                                      Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF991B1B)))),
                                      Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF991B1B)))),
                                      Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text('Ref ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF991B1B)))),
                                      Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text('Note / Reason', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF991B1B)))),
                                    ],
                                  ),
                                  ...reversals.map((rev) {
                                    return TableRow(
                                      children: [
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text(rev['type'] ?? '', style: const TextStyle(fontSize: 11))),
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text(rev['client'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text(CurrencyFormatter.formatNaira((rev['amount'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                                            child: const Text('Reversed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)), textAlign: TextAlign.center),
                                          ),
                                        ),
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text((rev['ref_id'] ?? '').toString(), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text(rev['reason'] ?? rev['note'] ?? '', style: const TextStyle(fontSize: 11))),
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
    final topBorderColor = accentColor ?? (isGrand ? const Color(0xFF10B981) : const Color(0xFF059669));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: BorderSide(color: topBorderColor, width: 3),
          left: BorderSide(color: isGrand ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
          right: BorderSide(color: isGrand ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
          bottom: BorderSide(color: isGrand ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: const [
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
                  label,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 16, color: topBorderColor),
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
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isGrand ? const Color(0xFF15803D) : const Color(0xFF0F172A),
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildGroupSummarySection(List<dynamic> groups, int repCount, int savCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
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
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.workspaces_outlined, size: 16, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Group Breakdown (${groups.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${groups.fold<int>(0, (acc, g) => acc + ((g['paying_members_count'] as num?)?.toInt() ?? 0))} Paying Clients',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
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
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$payingCnt Clients',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16, color: Color(0xFFE2E8F0)),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Loan Repayment', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.formatNaira(totRep),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: Color(0xFF065F46)),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Total Savings', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.formatNaira(totSav),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: Color(0xFF2563EB)),
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
                                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                              ),
                              Text(
                                'Total: ${CurrencyFormatter.formatNaira(grpTotal)}',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: Color(0xFF0F172A)),
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
                    border: TableBorder.all(color: const Color(0xFFE2E8F0)),
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
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                        children: [
                          Padding(padding: EdgeInsets.all(10), child: Text('Group Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(10), child: Text('Total Repayment (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(10), child: Text('Member Savings (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(10), child: Text('Group Savings (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(10), child: Text('Total Savings (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(10), child: Text('Grand Total Collected (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(10), child: Text('Paying Members', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                        ],
                      ),
                      ...groups.map((g) {
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(10), child: Text(g['group_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            Padding(padding: const EdgeInsets.all(10), child: Text(CurrencyFormatter.formatNaira((g['total_repayment'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                            Padding(padding: const EdgeInsets.all(10), child: Text(CurrencyFormatter.formatNaira((g['member_savings'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                            Padding(padding: const EdgeInsets.all(10), child: Text(CurrencyFormatter.formatNaira((g['group_savings'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                            Padding(padding: const EdgeInsets.all(10), child: Text(CurrencyFormatter.formatNaira((g['total_savings'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                            Padding(padding: const EdgeInsets.all(10), child: Text(CurrencyFormatter.formatNaira((g['grand_total'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                            Padding(padding: const EdgeInsets.all(10), child: Text('${g['paying_members_count'] ?? 0} Clients', style: const TextStyle(fontSize: 11))),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
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
                    const Text('Client Collection & Savings Ledger', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text('Itemized loan repayments and savings deposits on $dateStr ($totalCount Clients Recorded)', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
              child: const Center(
                child: Text('No client repayments or savings deposits match this filter.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
                      border: TableBorder.all(color: const Color(0xFFE2E8F0)),
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
                        const TableRow(
                          decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                          children: [
                            Padding(padding: EdgeInsets.all(10), child: Text('Client Name (Code)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Product', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Expected Rep. (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Loan Repayment (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Savings Deposit (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Total Cash (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Officer / Time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
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
                                    Text(cname, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                    const SizedBox(height: 2),
                                    Text(ccode, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Padding(padding: const EdgeInsets.all(10), child: Text(gname, style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(10), child: Text(prod, style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(10), child: Text(exp > 0 ? CurrencyFormatter.formatNaira(exp) : '-', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                              Padding(padding: const EdgeInsets.all(10), child: Text(CurrencyFormatter.formatNaira(repPaid), style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600))),
                              Padding(padding: const EdgeInsets.all(10), child: _buildStatusBadge(stat)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(savPaid > 0 ? CurrencyFormatter.formatNaira(savPaid) : '-', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF065F46), fontWeight: FontWeight.w600))),
                              Padding(padding: const EdgeInsets.all(10), child: Text(CurrencyFormatter.formatNaira(totalCash), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: Color(0xFF0F172A)))),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (off.isNotEmpty) Text(off, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    if (time.isNotEmpty && time != '00:00' && time != '0:00')
                                      Text(time, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)))
                                    else
                                      const Text('—', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
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
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${startIndex + 1}–$endIndex of $totalFiltered',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '$_histClientPage / $totalPages',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _histClientPage < totalPages
                            ? () => setState(() => _histClientPage++)
                            : null,
                        icon: const Icon(Icons.chevron_right, size: 16),
                        label: const Text('Next', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
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
          color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF065F46) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF065F46) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileClientHistoryCard(Map<String, dynamic> c) {
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$ccode • $gname${prod != '-' ? ' • $prod' : ''}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Loan Repaid', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    const SizedBox(height: 1),
                    Text(
                      CurrencyFormatter.formatNaira(repPaid),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: repPaid > 0 ? const Color(0xFF065F46) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Savings Deposit', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    const SizedBox(height: 1),
                    Text(
                      CurrencyFormatter.formatNaira(savPaid),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: savPaid > 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total Cash', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    const SizedBox(height: 1),
                    Text(
                      CurrencyFormatter.formatNaira(totalCash),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        color: Color(0xFF0F172A),
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
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
            ),
          ],
          if (off.isNotEmpty || (time.isNotEmpty && time != '00:00' && time != '0:00')) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (off.isNotEmpty)
                  Text('Officer: $off', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500))
                else
                  const SizedBox.shrink(),
                if (time.isNotEmpty && time != '00:00' && time != '0:00')
                  Text(time, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontFamily: 'monospace'))
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('End of Day (EOD) Inputs & Fee Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text('Operational EOD cashbook inputs & auxiliary fees recorded for $dateStr', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ExpansionTile(
                title: const Text('Daily EOD Inputs History Log', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                subtitle: const Text('Historical log of daily EOD cashbook inputs and reconciliation submissions.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                children: [
                  if (eodLog.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No historical EOD inputs found for this filter.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 960),
                        child: Table(
                          border: TableBorder.all(color: const Color(0xFFE2E8F0)),
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
                              decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                              children: const [
                                Padding(padding: EdgeInsets.all(8), child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(8), child: Text('Officer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(8), child: Text('B/F Cash', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(8), child: Text('Bank Deposit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(8), child: Text('Expenses', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(8), child: Text('App Fee', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(8), child: Text('Passbook', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(8), child: Text('Misc Fees', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(8), child: Text('Form Damage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(8), child: Text('Bonus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(8), child: Text('Closing Cash', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
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
                                  Padding(padding: const EdgeInsets.all(8), child: Text(log['Date']?.toString() ?? '', style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(log['Officer']?.toString() ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(bf), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(bd), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(exp), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(appF), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(pb), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(misc), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(fd), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(bon), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(CurrencyFormatter.formatNaira(cc), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
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
    final dVal = (val as num?)?.toDouble() ?? 0.0;
    return Container(
      width: width ?? 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.formatNaira(dVal),
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final clean = status.replaceAll('_', ' ').trim().toUpperCase();
    Color bg = const Color(0xFFDCFCE7);
    Color fg = const Color(0xFF15803D);

    if (clean == 'NOT PAID') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
    } else if (clean == 'PART PAID') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else if (clean == 'EXCESS') {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1E40AF);
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
    final dateStr = DateFormat('yyyy-MM-dd').format(_revDate);
    final search = _revSearchCtrl.text.trim();
    final revOptsAsync = ref.watch(reversalOptionsProvider((category: _revCategory, dateStr: dateStr, allRecent: _revAllRecent, search: search)));
    final revReqsAsync = ref.watch(reversalRequestsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Description
        const Text(
          'Error Correction & Reversal Hub',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
        ),
        const SizedBox(height: 3),
        const Text(
          'Flag an erroneous collection (loan repayment or savings deposit) for Branch Manager review and approval.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),

        // 1. Category & Date Filter Bar (app.py L6987-7000)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Transaction Category to Reverse:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _buildReversalCategoryButton('Loan Repayments', Icons.assignment_return_outlined),
                  _buildReversalCategoryButton('Savings Deposits', Icons.savings_outlined),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 14),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 650;

                  final datePicker = InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _revDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
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
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF475569)),
                          const SizedBox(width: 8),
                          Text(DateFormat('dd MMM yyyy').format(_revDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  );

                  final searchField = TextField(
                    controller: _revSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Filter by Client Name / Code / Ref...',
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF065F46), width: 1.5)),
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
                        color: _revAllRecent ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _revAllRecent ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _revAllRecent ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 18,
                            color: _revAllRecent ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'All Recent (14 Days)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _revAllRecent ? const Color(0xFF065F46) : const Color(0xFF475569),
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
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
            child: Text('Error loading options: $err', style: const TextStyle(color: Color(0xFFDC2626))),
          ),
          data: (optData) {
            final items = (optData['items'] as List<dynamic>?) ?? [];
            if (items.isEmpty) {
              final dateLbl = _revAllRecent ? 'all recent dates (last 14 days)' : dateStr;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_outlined, size: 36, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text(
                        'No ${_revCategory.toLowerCase()} found for $dateLbl matching your criteria.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
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
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Reversal Request', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedReversalRefId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return items.map((it) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            it['label']?.toString() ?? 'Tx',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Selected Transaction Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                              child: Text(selItem['category'] ?? _revCategory, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
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
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Full Ref ID: ${selItem['ref_id']} • Note: ${selItem['note'] ?? '—'}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
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
                              child: const Icon(Icons.copy, size: 14, color: Color(0xFF94A3B8)),
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
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      labelText: 'Reason for Reversal *',
                      hintText: 'e.g., Wrong payment entered. Entered 50,000 instead of 5,000.',
                      prefixIcon: const Icon(Icons.edit_note, size: 20, color: Color(0xFF94A3B8)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
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
            const Text(
              'Submitted Reversal Requests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF64748B)),
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
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
            child: Text('Error loading requests: $err', style: const TextStyle(color: Color(0xFFDC2626))),
          ),
          data: (reqData) {
            final requests = (reqData['requests'] as List<dynamic>?) ?? [];
            if (requests.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Center(
                  child: Text('You have not submitted any reversal requests yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
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
                        decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                        children: const [
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF475569)))),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF475569)))),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Text('Record Ref', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF475569)))),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Text('Reason', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF475569)))),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF475569)))),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Text('Reviewed By', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF475569)))),
                        ],
                      ),
                      ...requests.map((r) {
                        final stat = r['status']?.toString() ?? 'Pending';
                        Color statBg = const Color(0xFFFFFBEB);
                        Color statFg = const Color(0xFFB45309);
                        Color statBorder = const Color(0xFFFDE68A);
                        if (stat == 'Approved') {
                          statBg = const Color(0xFFDCFCE7);
                          statFg = const Color(0xFF15803D);
                          statBorder = const Color(0xFF86EFAC);
                        } else if (stat == 'Rejected') {
                          statBg = const Color(0xFFFEF2F2);
                          statFg = const Color(0xFFDC2626);
                          statBorder = const Color(0xFFFECACA);
                        }

                        return TableRow(
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                          ),
                          children: [
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(r['date'] ?? '', style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)))),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(r['record_type'] ?? '', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(r['record_ref'] ?? '', style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'))),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(r['reason'] ?? '', style: const TextStyle(fontSize: 11.5), softWrap: true)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: statBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: statBorder)),
                                child: Text(stat, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statFg), textAlign: TextAlign.center),
                              ),
                            ),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(r['approved_by'] ?? '—', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)))),
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
    final isSel = _revCategory == title;
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
          color: isSel ? const Color(0xFF064E3B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSel ? const Color(0xFF064E3B) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSel ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                color: isSel ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReversalDetailKpi(String label, String val, {bool isAmount = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          top: BorderSide(color: isAmount ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1), width: 2.5),
          left: const BorderSide(color: Color(0xFFE2E8F0)),
          right: const BorderSide(color: Color(0xFFE2E8F0)),
          bottom: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
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
                color: isAmount ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
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
