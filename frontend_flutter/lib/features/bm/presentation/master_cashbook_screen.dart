// ignore_for_file: deprecated_member_use, unnecessary_const
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/datasources/master_cashbook_api_service.dart';
import '../data/models/master_cashbook_models.dart';
import '../../shared/utils/file_download_helper.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import 'package:frontend_flutter/core/theme/icare_motion.dart';

/// Target branch filter passed from external navigation (AM Dashboard, Handover modal, etc.)
final masterCashbookTargetBranchProvider = StateProvider<String?>((ref) => null);

/// Riverpod family providers using composite keys to eliminate infinite refetches
final masterDailyCashbookProvider = FutureProvider.family<MasterCashbookDailyData, String>((ref, key) async {
  final parts = key.split('||');
  final date = parts.isNotEmpty && parts[0] != 'null' && parts[0].isNotEmpty ? parts[0] : null;
  final branch = parts.length > 1 && parts[1] != 'null' && parts[1].isNotEmpty ? parts[1] : null;

  final api = ref.watch(masterCashbookApiServiceProvider);
  return api.getMasterCashbookDaily(date: date, branch: branch);
});

final coAggregationProvider = FutureProvider.family<CoAggregationData, String>((ref, key) async {
  final parts = key.split('||');
  final date = parts.isNotEmpty && parts[0] != 'null' && parts[0].isNotEmpty ? parts[0] : null;
  final officer = parts.length > 1 && parts[1] != 'null' && parts[1].isNotEmpty ? parts[1] : null;
  final branch = parts.length > 2 && parts[2] != 'null' && parts[2].isNotEmpty ? parts[2] : null;

  final api = ref.watch(masterCashbookApiServiceProvider);
  return api.getCoAggregation(date: date, officer: officer, branch: branch);
});

final monthlyLedgerProvider = FutureProvider.family<MonthlyLedgerData, String>((ref, key) async {
  final parts = key.split('||');
  final month = int.tryParse(parts[0]) ?? DateTime.now().month;
  final year = int.tryParse(parts[1]) ?? DateTime.now().year;
  final branch = parts.length > 2 && parts[2] != 'null' && parts[2].isNotEmpty ? parts[2] : null;

  final api = ref.watch(masterCashbookApiServiceProvider);
  return api.getMonthlyLedger(month: month, year: year, branch: branch);
});

/// 1:1 Streamlit Parity Replica of Branch Manager Master Cashbook (app.py L11187–12191)
/// Backed by Account 1000 Vault Cash and MasterCashbookProjectionBuilder.
/// Strict Zero-Emoji Governance (GEMINI Rule 10: Material/SVG Icons only).
class MasterCashbookScreen extends ConsumerStatefulWidget {
  const MasterCashbookScreen({super.key});

  @override
  ConsumerState<MasterCashbookScreen> createState() => _MasterCashbookScreenState();
}

class _MasterCashbookScreenState extends ConsumerState<MasterCashbookScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool get _isAm {
    final auth = ref.watch(authControllerProvider);
    final user = auth is AuthStateAuthenticated ? auth.user : null;
    final role = (user?.role ?? '').trim().toLowerCase();
    return role == 'area manager' || role == 'am';
  }

  void _changeActiveBranch(String newBranch) {
    setState(() {
      _selectedBranchTab1 = newBranch;
      _selectedBranchTab2 = newBranch;
      _selectedBranchTab3 = newBranch;
      _selectedOfficerTab2 = null;
    });
  }

  // Tab 1 state
  // Branch state for multi-branch roles (AM, Admin)
  String? _selectedBranchTab1;
  DateTime _selectedDateTab1 = DateTime.now();
  final TextEditingController _fundsHoCtrl = TextEditingController();
  final TextEditingController _fundsBranchCtrl = TextEditingController();
  final TextEditingController _fundsAreaCtrl = TextEditingController();
  final TextEditingController _xferBranchCtrl = TextEditingController();
  final TextEditingController _xferHoCtrl = TextEditingController();
  final TextEditingController _xferAreaCtrl = TextEditingController();
  final TextEditingController _fundToAssetCtrl = TextEditingController();
  final TextEditingController _salariesCtrl = TextEditingController();
  final TextEditingController _adjInCtrl = TextEditingController();
  final TextEditingController _adjOutCtrl = TextEditingController();
  final TextEditingController _adjReasonCtrl = TextEditingController();

  // Tab 1 Reversal Flagging
  String? _selectedTreasuryTxId;
  final TextEditingController _treasuryRevReasonCtrl = TextEditingController();

  // Tab 2 state
  DateTime _selectedDateTab2 = DateTime.now();
  String? _selectedOfficerTab2;
  String? _selectedBranchTab2;

  // Tab 3 state
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String? _selectedBranchTab3;

  // UI Modernization & Responsive View States
  int _tab1MobileSection = 0; // 0: Overview & Ledger, 1: Manual Inputs & Float, 2: Reversals Hub, 3: Full Stack
  bool _tab1HideZeroRows = true;
  int _tab1TAccountTab = 0; // 0: Dual Columns / Both, 1: Inflows Only, 2: Outflows Only
  bool _tab1UseSpreadsheet = false;
  bool _tab2HideZeroRows = true;
  bool _tab2UseSpreadsheet = false;
  int _tab2TAccountTab = 0; // 0: Dual Columns / Both, 1: Inflows Only, 2: Outflows Only
  bool _tab3DailyFeedView = true;

  // Banner & submitting states
  String? _bannerMessage;
  String _bannerSeverity = 'success';
  IconData _bannerIcon = Icons.check_circle_outline;

  bool _isSubmittingManual = false;
  bool _isSubmittingReversal = false;
  bool _isExecutingEod = false;
  bool _isDownloadingExcel = false;
  String? _lastLoadedTab1Key;
  MasterCashbookDailyData? _lastLoadedTab1Data;

  @override
  void initState() {
    super.initState();
    final targetBranch = ref.read(masterCashbookTargetBranchProvider);
    if (targetBranch != null) {
      _selectedBranchTab1 = targetBranch;
      _selectedBranchTab2 = targetBranch;
      _selectedBranchTab3 = targetBranch;
    }
    Future.microtask(() {
      if (mounted) {
        ref.read(masterCashbookTargetBranchProvider.notifier).state = null;
      }
    });
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fundsHoCtrl.dispose();
    _fundsBranchCtrl.dispose();
    _fundsAreaCtrl.dispose();
    _xferBranchCtrl.dispose();
    _xferHoCtrl.dispose();
    _xferAreaCtrl.dispose();
    _fundToAssetCtrl.dispose();
    _salariesCtrl.dispose();
    _adjInCtrl.dispose();
    _adjOutCtrl.dispose();
    _adjReasonCtrl.dispose();
    _treasuryRevReasonCtrl.dispose();
    super.dispose();
  }

  void _showBanner(String message, String severity, IconData icon) {
    if (!mounted) return;
    setState(() {
      _bannerMessage = message;
      _bannerSeverity = severity;
      _bannerIcon = icon;
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _bannerMessage == message) {
        setState(() => _bannerMessage = null);
      }
    });
  }

  String _formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);
  String _formatCurrency(double val) => CurrencyFormatter.format(val);

  String _formatLedgerCell(double val) {
    if (val == 0.0) return '0';
    return NumberFormat('#,##0').format(val);
  }

  String _formatIntegerCurrency(double val) {
    return '₦${NumberFormat('#,##0').format(val)}';
  }

  Future<void> _handleDownloadExcel(String branch) async {
    setState(() => _isDownloadingExcel = true);
    try {
      final bytes = await ref.read(masterCashbookApiServiceProvider).downloadMonthlyLedgerExcel(
        _selectedMonth,
        _selectedYear,
        branch,
      );
      final monthName = DateFormat('MMMM').format(DateTime(2026, _selectedMonth, 1));
      final fileName = 'ICARE_Master_Cashbook_${branch}_${monthName}_$_selectedYear.xlsx';
      downloadBlobFile(bytes, fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      _showBanner('Downloaded $fileName successfully', 'success', Icons.check_circle_outline);
    } catch (e) {
      _showBanner('Failed to download Excel ledger: $e', 'error', Icons.error_outline);
    } finally {
      setState(() => _isDownloadingExcel = false);
    }
  }

  void _populateManualControllers(MasterCashbookDailyData data) {
    final inf = data.inflows;
    final out = data.outflows;

    _fundsHoCtrl.text = inf.fundsReceivedHo > 0 ? inf.fundsReceivedHo.toStringAsFixed(0) : '';
    _fundsBranchCtrl.text = inf.fundsReceivedOtherBranch > 0 ? inf.fundsReceivedOtherBranch.toStringAsFixed(0) : '';
    _fundsAreaCtrl.text = inf.fundsReceivedOtherArea > 0 ? inf.fundsReceivedOtherArea.toStringAsFixed(0) : '';

    _xferBranchCtrl.text = out.fundTransferredOtherBranch > 0 ? out.fundTransferredOtherBranch.toStringAsFixed(0) : '';
    _xferHoCtrl.text = out.fundTransferredHo > 0 ? out.fundTransferredHo.toStringAsFixed(0) : '';
    _xferAreaCtrl.text = out.fundToOtherArea > 0 ? out.fundToOtherArea.toStringAsFixed(0) : '';
    _fundToAssetCtrl.text = out.fundToAssetProgram > 0 ? out.fundToAssetProgram.toStringAsFixed(0) : '';
    _salariesCtrl.text = out.staffSalaries > 0 ? out.staffSalaries.toStringAsFixed(0) : '';

    _adjInCtrl.text = inf.adjustmentIn > 0 ? inf.adjustmentIn.toStringAsFixed(0) : '';
    _adjOutCtrl.text = out.adjustmentOut > 0 ? out.adjustmentOut.toStringAsFixed(0) : '';
    _adjReasonCtrl.text = data.adjustmentReason;
  }

  // ==========================================
  // TAB 1 ACTIONS
  // ==========================================

  Future<void> _handleSaveManualEntries(bool isOpen, String openReason) async {
    if (!isOpen) {
      _showBanner(
        'Cannot save manual entries: Operational Activity Suspended ($openReason).',
        'error',
        Icons.error_outline,
      );
      return;
    }

    setState(() => _isSubmittingManual = true);
    try {
      final api = ref.read(masterCashbookApiServiceProvider);
      final payload = {
        'date': _formatDate(_selectedDateTab1),
        'funds_received_ho': double.tryParse(_fundsHoCtrl.text.trim()) ?? 0.0,
        'funds_received_other_branch': double.tryParse(_fundsBranchCtrl.text.trim()) ?? 0.0,
        'funds_received_other_area': double.tryParse(_fundsAreaCtrl.text.trim()) ?? 0.0,
        'fund_transferred_other_branch': double.tryParse(_xferBranchCtrl.text.trim()) ?? 0.0,
        'fund_transferred_ho': double.tryParse(_xferHoCtrl.text.trim()) ?? 0.0,
        'fund_to_other_area': double.tryParse(_xferAreaCtrl.text.trim()) ?? 0.0,
        'fund_to_asset_program': double.tryParse(_fundToAssetCtrl.text.trim()) ?? 0.0,
        'staff_salaries': double.tryParse(_salariesCtrl.text.trim()) ?? 0.0,
        'adjustment_in': double.tryParse(_adjInCtrl.text.trim()) ?? 0.0,
        'adjustment_out': double.tryParse(_adjOutCtrl.text.trim()) ?? 0.0,
        'adjustment_reason': _adjReasonCtrl.text.trim(),
      };

      final res = await api.saveManualEntries(payload);
      _showBanner(
        res['message'] ?? 'Master Cashbook manual entries saved and projection rebuilt.',
        'success',
        Icons.check_circle_outline,
      );
      _lastLoadedTab1Key = null;
      ref.invalidate(masterDailyCashbookProvider);
      ref.invalidate(coAggregationProvider);
      ref.invalidate(monthlyLedgerProvider);
    } catch (e) {
      _showBanner(
        'Failed to save manual entries: $e',
        'error',
        Icons.error_outline,
      );
    } finally {
      setState(() => _isSubmittingManual = false);
    }
  }

  Future<void> _handleApproveReversal(MasterPendingReversalData req) async {
    final amtStr = CurrencyFormatter.format(req.amount);
    final confirm = await showIcareDialog<bool>(
      context: context,
      builder: (ctx) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return AlertDialog(
          backgroundColor: tokens.surfaceElevated,
          title: Text('Confirm Reversal — [${req.recordType}]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: tokens.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (req.clientName != null && req.clientName!.isNotEmpty) ...[
                Text('Client / Entity: ${req.clientName!} ${req.clientCode != null && req.clientCode!.isNotEmpty ? "(${req.clientCode})" : ""}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                const SizedBox(height: 4),
              ],
              Text('Amount to Reverse: $amtStr', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.dangerText)),
              const SizedBox(height: 6),
              Text('Reason: ${req.reason}', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: tokens.textSecondary)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.warningBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.warningBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: tokens.warningDot),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Approving this reversal will deduct $amtStr from Vault Cash. Ensure physical cash has been counted and aligned.',
                        style: TextStyle(fontSize: 11.5, color: tokens.warningText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: tokens.brandPrimaryDark, foregroundColor: Colors.white),
              child: const Text('Approve Reversal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final api = ref.read(masterCashbookApiServiceProvider);
      final res = await api.approveReversal(req.id);
      _showBanner(
        res['message'] ?? 'Reversal approved and executed atomically!',
        'success',
        Icons.check_circle_outline,
      );
      ref.invalidate(masterDailyCashbookProvider);
    } catch (e) {
      _showBanner(
        'Approval failed: $e',
        'error',
        Icons.error_outline,
      );
    }
  }

  Future<void> _handleRejectReversal(MasterPendingReversalData req) async {
    final confirm = await showIcareDialog<bool>(
      context: context,
      builder: (ctx) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return AlertDialog(
          backgroundColor: tokens.surfaceElevated,
          title: Text('Reject Reversal Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: tokens.textPrimary)),
          content: Text('Are you sure you want to reject this reversal request for [${req.recordType}] (Ref: #${req.recordId.length > 8 ? req.recordId.substring(0, 8) : req.recordId})?',
              style: TextStyle(fontSize: 13, color: tokens.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              child: const Text('Reject Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final api = ref.read(masterCashbookApiServiceProvider);
      final res = await api.rejectReversal(req.id);
      _showBanner(
        res['message'] ?? 'Reversal rejected.',
        'info',
        Icons.info_outline,
      );
      ref.invalidate(masterDailyCashbookProvider);
    } catch (e) {
      _showBanner(
        'Rejection failed: $e',
        'error',
        Icons.error_outline,
      );
    }
  }

  Future<void> _handleFlagTreasuryReversal() async {
    if (_selectedTreasuryTxId == null || _selectedTreasuryTxId!.isEmpty) {
      _showBanner('Please select a Treasury Entry to flag.', 'warning', Icons.warning_amber);
      return;
    }
    final reason = _treasuryRevReasonCtrl.text.trim();
    if (reason.isEmpty) {
      _showBanner('Please provide a reason for the reversal.', 'warning', Icons.warning_amber);
      return;
    }

    setState(() => _isSubmittingReversal = true);
    try {
      final api = ref.read(masterCashbookApiServiceProvider);
      final res = await api.flagTreasuryReversal(_selectedTreasuryTxId!, reason);
      _showBanner(
        res['message'] ?? 'Treasury reversal request submitted!',
        'success',
        Icons.check_circle_outline,
      );
      _treasuryRevReasonCtrl.clear();
      setState(() => _selectedTreasuryTxId = null);
      ref.invalidate(masterDailyCashbookProvider);
    } catch (e) {
      _showBanner(
        'Failed to submit request: $e',
        'error',
        Icons.error_outline,
      );
    } finally {
      setState(() => _isSubmittingReversal = false);
    }
  }

  // ==========================================
  // TAB 2 ACTIONS
  // ==========================================

  Future<void> _handleExecuteEod(String dateStr, {String? reasonTag, String? notes}) async {
    setState(() => _isExecutingEod = true);
    try {
      final api = ref.read(masterCashbookApiServiceProvider);
      final res = await api.executeEodClose(dateStr, reasonTag: reasonTag, notes: notes);
      _showBanner(
        res['message'] ?? 'Successfully executed Day Close! Operational date advanced.',
        'success',
        Icons.check_circle_outline,
      );
      ref.invalidate(coAggregationProvider('${_formatDate(_selectedDateTab2)}||${_selectedOfficerTab2 ?? ""}'));
      ref.invalidate(masterDailyCashbookProvider);
    } catch (e) {
      _showBanner(
        'EOD Day Close failed: $e',
        'error',
        Icons.error_outline,
      );
    } finally {
      setState(() => _isExecutingEod = false);
    }
  }

  List<String> _getAvailableBranches() {
    final auth = ref.read(authControllerProvider);
    final user = auth is AuthStateAuthenticated ? auth.user : null;
    final role = (user?.role ?? '').trim().toLowerCase();
    final isAm = role == 'area manager' || role == 'am';
    if (isAm) {
      return user?.assignedBranches.isNotEmpty == true ? user!.assignedBranches : (user?.branch.isNotEmpty == true ? [user!.branch] : <String>[]);
    }
    return user?.branch.isNotEmpty == true ? [user!.branch] : <String>[];
  }

  @override
  Widget build(BuildContext context) {
    // Reactive listener for target branch when already mounted
    ref.listen<String?>(masterCashbookTargetBranchProvider, (prev, next) {
      if (next != null) {
        _changeActiveBranch(next);
        Future.microtask(() {
          if (mounted) ref.read(masterCashbookTargetBranchProvider.notifier).state = null;
        });
      }
    });

    ref.listen<int>(globalRefreshSignalProvider, (prev, next) {
      if (prev != next) {
        _lastLoadedTab1Key = null;
      }
    });

    final isMobile = MediaQuery.of(context).size.width < 650;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(isMobile),
        const SizedBox(height: 14),
        if (_bannerMessage != null) ...[
          _buildFeedbackBanner(),
          const SizedBox(height: 14),
        ],
        _buildPillTabs(),
        const SizedBox(height: 18),
        _buildTabContent(isMobile),
      ],
    );
  }

  Widget _buildHeader(bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final isAm = _isAm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAm ? 'Area Supervisory Master Cashbook' : 'Branch Manager Master Cashbook',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 25,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isAm
                        ? 'Regional Treasury & Supervised Branch Vault Audit'
                        : 'Branch Treasury & Vault Cashbook',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isAm ? tokens.brandSoftBg : tokens.successBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isAm ? tokens.brandSoftBorder : tokens.successBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAm ? Icons.visibility_outlined : Icons.verified_user_outlined,
                      size: 14,
                      color: isAm ? tokens.brandPrimary : tokens.successText,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isAm ? 'Supervisory Audit Mode • Read-Only' : 'Certified Vault Reserve',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isAm ? tokens.brandSoftText : tokens.successText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildFeedbackBanner() {
    final tokens = IcareSurfaceTokens.of(context);
    final (fg, bg, border) = switch (_bannerSeverity) {
      'error' => (tokens.dangerText, tokens.dangerBg, tokens.dangerBorder),
      'warning' => (tokens.warningText, tokens.warningBg, tokens.warningBorder),
      'info' => (tokens.infoText, tokens.infoBg, tokens.infoBorder),
      _ => (tokens.successText, tokens.successBg, tokens.successBorder),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(_bannerIcon, size: 20, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _bannerMessage!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: fg),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _bannerMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTabs() {
    final tokens = IcareSurfaceTokens.of(context);
    final isAm = _isAm;
    final activeTabColor = isAm ? tokens.brandPrimaryDark : const Color(0xFF1D4ED8);
    final tabs = [
      (0, isAm ? 'Daily Cashbook Audit' : 'Daily Cashbook Entry', Icons.account_balance_wallet_outlined),
      (1, isAm ? 'CO Cashbooks Inspection' : 'CO Cashbooks Aggregation', Icons.groups_outlined),
      (2, isAm ? 'Monthly Ledger Review' : 'Monthly Ledger', Icons.calendar_month_outlined),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final isSelected = _tabController.index == t.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _tabController.animateTo(t.$1);
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? activeTabColor : tokens.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? activeTabColor : tokens.borderStrong,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: tokens.isDark
                      ? null
                      : isSelected
                          ? [
                              BoxShadow(
                                color: activeTabColor.withValues(alpha: 0.22),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t.$3,
                      size: 16,
                      color: isSelected ? Colors.white : tokens.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(bool isMobile) {
    switch (_tabController.index) {
      case 0:
        return _buildTab1Daily(isMobile);
      case 1:
        return _buildTab2CoAggregation(isMobile);
      case 2:
        return _buildTab3MonthlyLedger(isMobile);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // TAB 1: DAILY CASHBOOK ENTRY
  // ==========================================

  Widget _buildTab1Daily(bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final branches = _getAvailableBranches();
    if (_selectedBranchTab1 == null && branches.isNotEmpty) {
      _selectedBranchTab1 = branches.first;
    }
    final activeBranch = _selectedBranchTab1;
    final key = '${_formatDate(_selectedDateTab1)}||${activeBranch ?? ""}';
    final asyncDaily = ref.watch(masterDailyCashbookProvider(key));

    return asyncDaily.when(
      loading: () => const IcareTableSkeleton(rowCount: 8, hasFilterBar: false),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: tokens.dangerBg, borderRadius: BorderRadius.circular(8)),
        child: Text('Error loading Master Cashbook: $err', style: TextStyle(color: tokens.dangerText)),
      ),
      data: (data) {
        final isAm = _isAm;
        if (_lastLoadedTab1Key != key || !identical(_lastLoadedTab1Data, data)) {
          _lastLoadedTab1Key = key;
          _lastLoadedTab1Data = data;
          if (!isAm) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _populateManualControllers(data);
            });
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTab1ControlBar(data, isMobile),
            const SizedBox(height: 16),
            if (isAm) ...[
              // Area Manager Supervisory Read-Only View: Purely Audit & Inspection
              if (data.tally != null) ...[
                _buildReconciliationTally(data.tally!, data.branch),
                const SizedBox(height: 20),
                Divider(color: tokens.borderSubtle),
                const SizedBox(height: 16),
              ],
              _buildDailyLedgerTAccount(data, isMobile),
            ] else ...[
              // Branch Manager Operational View: With Inputs, Float & Reversals Hub
              if (isMobile) _buildTab1MobileSectionSelector(),
              if (!isMobile || _tab1MobileSection == 0 || _tab1MobileSection == 3) ...[
                if (data.tally != null) ...[
                  _buildReconciliationTally(data.tally!, data.branch),
                  const SizedBox(height: 20),
                  Divider(color: tokens.borderSubtle),
                  const SizedBox(height: 16),
                ],
                _buildDailyLedgerTAccount(data, isMobile),
                if (!isMobile || _tab1MobileSection == 3) ...[
                  const SizedBox(height: 28),
                  Divider(color: tokens.borderSubtle),
                  const SizedBox(height: 20),
                ],
              ],
              if (!isMobile || _tab1MobileSection == 1 || _tab1MobileSection == 3) ...[
                _buildBmManualInputsForm(data, isMobile),
                if (!isMobile || _tab1MobileSection == 3) ...[
                  const SizedBox(height: 28),
                  Divider(color: tokens.borderSubtle),
                  const SizedBox(height: 20),
                ],
              ],
              if (!isMobile || _tab1MobileSection == 2 || _tab1MobileSection == 3) ...[
                _buildErrorCorrectionHub(data, isMobile),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _buildTab1ControlBar(MasterCashbookDailyData data, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final curDate = DateTime(_selectedDateTab1.year, _selectedDateTab1.month, _selectedDateTab1.day);
    final isToday = curDate == today;
    final isYesterday = curDate == yesterday;

    final branches = _getAvailableBranches();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: tokens.isDark
            ? null
            : [
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
          if (branches.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Icon(Icons.apartment, size: 16, color: tokens.brandPrimary),
                  const SizedBox(width: 8),
                  Text('Supervised Branch:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                  const SizedBox(width: 8),
                  for (final b in branches) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: Icon(Icons.storefront, size: 14, color: _selectedBranchTab1 == b ? Colors.white : tokens.brandPrimary),
                        label: Text(b, style: TextStyle(fontSize: 12, fontWeight: _selectedBranchTab1 == b ? FontWeight.w800 : FontWeight.w600, color: _selectedBranchTab1 == b ? Colors.white : tokens.textPrimary)),
                        selected: _selectedBranchTab1 == b,
                        selectedColor: tokens.brandPrimaryDark,
                        backgroundColor: tokens.surfaceSubtle,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: _selectedBranchTab1 == b ? tokens.brandPrimaryDark : tokens.borderStrong),
                        onSelected: (selected) {
                          if (selected && _selectedBranchTab1 != b) {
                            _changeActiveBranch(b);
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(height: 18, color: tokens.borderSubtle),
          ],
          Row(
            children: [
              // Calendar picker button
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDateTab1,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _selectedDateTab1 = picked);
                  }
                },
                icon: Icon(Icons.calendar_today_outlined, size: 15, color: tokens.textPrimary),
                label: Text(
                  DateFormat(isMobile ? 'EEE, dd MMM yyyy' : 'EEEE, dd MMMM yyyy').format(_selectedDateTab1),
                  style: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: tokens.surfaceSubtle,
                  side: BorderSide(color: tokens.borderStrong),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),

              // Quick chip: Today
              InkWell(
                onTap: () => setState(() => _selectedDateTab1 = today),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isToday ? tokens.brandPrimaryDark : tokens.surfaceHover,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isToday ? tokens.brandPrimaryDark : tokens.borderStrong),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                      color: isToday ? Colors.white : tokens.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Quick chip: Yesterday
              InkWell(
                onTap: () => setState(() => _selectedDateTab1 = yesterday),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isYesterday ? tokens.brandPrimaryDark : tokens.surfaceHover,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isYesterday ? tokens.brandPrimaryDark : tokens.borderStrong),
                  ),
                  child: Text(
                    'Yesterday',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isYesterday ? FontWeight.w700 : FontWeight.w600,
                      color: isYesterday ? Colors.white : tokens.textSecondary,
                    ),
                  ),
                ),
              ),
              const Spacer(),

              if (isMobile)
                IconButton(
                  icon: Icon(Icons.refresh, size: 19, color: tokens.textPrimary),
                  tooltip: 'Refresh Daily Cashbook',
                  onPressed: () {
                    _lastLoadedTab1Key = null;
                    ref.invalidate(masterDailyCashbookProvider);
                    ref.invalidate(coAggregationProvider);
                    ref.invalidate(monthlyLedgerProvider);
                  },
                )
              else ...[
                OutlinedButton.icon(
                  onPressed: () {
                    _lastLoadedTab1Key = null;
                    ref.invalidate(masterDailyCashbookProvider);
                    ref.invalidate(coAggregationProvider);
                    ref.invalidate(monthlyLedgerProvider);
                  },
                  icon: Icon(Icons.refresh, size: 15, color: tokens.textPrimary),
                  label: Text(
                    'Refresh',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    side: BorderSide(color: tokens.borderStrong),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Operational Status Pill (Desktop/Tablet)
              if (!isMobile)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: data.isOpen ? tokens.successBg : tokens.warningBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: data.isOpen ? tokens.successBorder : tokens.warningBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        data.isOpen ? Icons.lock_open_outlined : Icons.lock_outlined,
                        size: 13,
                        color: data.isOpen ? tokens.successDot : tokens.warningDot,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        data.isOpen ? 'Ledger Open' : 'Ledger Finalized',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: data.isOpen ? tokens.successText : tokens.warningText,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Operational Status Warning Banner if closed
          if (!data.isOpen) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: data.openReason.toLowerCase().contains('closed') ? tokens.successBg : tokens.warningBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: data.openReason.toLowerCase().contains('closed') ? tokens.successBorder : tokens.warningBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    data.openReason.toLowerCase().contains('closed') ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    size: 15,
                    color: data.openReason.toLowerCase().contains('closed') ? tokens.successDot : tokens.warningDot,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.openReason.toLowerCase().contains('closed')
                          ? 'Master Cashbook Closed & Verified for this date. Operational balance rolled forward.'
                          : 'Operational Activity Suspended (${data.openReason}): Read-only mode.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: data.openReason.toLowerCase().contains('closed') ? tokens.successText : tokens.warningText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTab1MobileSectionSelector() {
    final tokens = IcareSurfaceTokens.of(context);
    final sections = [
      (0, 'Ledger', Icons.account_balance_wallet_outlined),
      (1, 'Manual', Icons.edit_note_outlined),
      (2, 'Reversals', Icons.assignment_return_outlined),
      (3, 'All', Icons.view_agenda_outlined),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: tokens.surfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: sections.map((s) {
          final isSelected = _tab1MobileSection == s.$1;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _tab1MobileSection = s.$1),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? tokens.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: (isSelected && !tokens.isDark)
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      s.$3,
                      size: 14,
                      color: isSelected ? tokens.textPrimary : tokens.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        s.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? tokens.textPrimary : tokens.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReconciliationTally(MasterReconciliationTallyData tally, String branch) {
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Collection & Arrears Reconciliation Tally',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '$branch Branch reconciliation',
                  style: TextStyle(fontSize: 12, color: tokens.textMuted),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final cardWidth = isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildMetricCard(
                  width: cardWidth,
                  label: 'Scheduled Inflows',
                  value: _formatCurrency(tally.scheduledExpected),
                  icon: Icons.schedule_outlined,
                  iconColor: tokens.infoDot,
                  iconBg: tokens.infoBg,
                ),
                _buildMetricCard(
                  width: cardWidth,
                  label: 'Overdue Arrears',
                  value: _formatCurrency(tally.notPaidAmount),
                  icon: Icons.warning_amber_rounded,
                  iconColor: tokens.dangerDot,
                  iconBg: tokens.dangerBg,
                  delta: tally.notPaidCount > 0 ? '${tally.notPaidCount} Not Paid' : '0 Arrears',
                  isDeltaInverse: true,
                ),
                _buildMetricCard(
                  width: cardWidth,
                  label: 'Physical Cash Collected',
                  value: _formatCurrency(tally.actualCashCollected),
                  icon: Icons.payments_outlined,
                  iconColor: tokens.successDot,
                  iconBg: tokens.successBg,
                  delta: tally.excessAmount > 0 ? '+${_formatCurrency(tally.excessAmount)} Excess' : null,
                ),
                _buildMetricCard(
                  width: cardWidth,
                  label: 'Bank Deposited',
                  value: _formatCurrency(tally.bankDeposited),
                  icon: Icons.account_balance_outlined,
                  iconColor: tokens.brandPrimary,
                  iconBg: tokens.brandSoftBg,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _buildTallyCallout(tally),
        if (tally.notPaidClients.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildNonPayingClientsExpander(tally.notPaidClients),
        ],
      ],
    );
  }

  Widget _buildTallyCallout(MasterReconciliationTallyData tally) {
    final tokens = IcareSurfaceTokens.of(context);
    final closing = tally.closingCashBalance;
    if (closing.abs() < 0.01) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.successBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.successBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: tokens.successDot, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reconciled: ₦0 net variance • Arrears: ${_formatCurrency(tally.notPaidAmount)}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tokens.successText),
              ),
            ),
          ],
        ),
      );
    } else if (closing > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.infoBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.infoBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: tokens.infoDot, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Vault Cash: ${_formatCurrency(closing)} unbanked • Arrears: ${_formatCurrency(tally.notPaidAmount)}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tokens.infoText),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.warningBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.warningBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: tokens.warningDot, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Excess Deposited: Surplus ${_formatCurrency(closing.abs())} banked',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tokens.warningText),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildNonPayingClientsExpander(List<MasterNotPaidClientData> clients) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: tokens.dangerBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.people_outline, size: 16, color: tokens.dangerDot),
        ),
        title: Text(
          'View Non-Paying Clients (${clients.length} Arrears Records)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
        ),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
              columns: [
                DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                DataColumn(label: Text('Client Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                DataColumn(label: Text('Expected Installment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                DataColumn(label: Text('Shortfall / Arrears', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
              ],
              rows: clients.map((c) {
                return DataRow(cells: [
                  DataCell(Text(c.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary))),
                  DataCell(Text(c.code, style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: tokens.textSecondary))),
                  DataCell(Text(_formatCurrency(c.expected), style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: tokens.textPrimary))),
                  DataCell(Text(_formatCurrency(c.shortfall), style: TextStyle(fontSize: 12, color: tokens.dangerText, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.isPartial ? tokens.warningBg : tokens.dangerBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        c.isPartial ? 'Partial Shortfall' : 'Marked NOT PAID (₦0)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.isPartial ? tokens.warningText : tokens.dangerText),
                      ),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyLedgerTAccount(MasterCashbookDailyData data, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final inf = data.inflows;
    final out = data.outflows;

    final inflowRows = [
      ('Opening Balance', inf.openingBalance),
      ('Savings Deposit (Amount)', inf.savingsDeposit),
      ('Credit Repayment (60 days)', inf.repDaily),
      ('Credit Repayment (120 days)', inf.rep120Days),
      ('Credit Repayment (12 weeks)', inf.rep12Weeks),
      ('Credit Repayment (24 weeks)', inf.rep24Weeks),
      ('Credit Repayment (Monthly)', inf.repMonthly),
      ('Laps Reserve', inf.lapsReserve),
      ('Funds Received from Head Office', inf.fundsReceivedHo),
      ('Funds Received from Branch Office', inf.fundsReceivedOtherBranch),
      ('Funds Received from Other Areas', inf.fundsReceivedOtherArea),
      ('Asset Credit Sales', inf.assetCreditSales),
      ('Cash & Carry', inf.cashAndCarry),
      ('Funds Received from Asset', inf.loanReceivedAsset),
      ('Funds from Finance', inf.loanReceivedFinance),
      ('Daily 11%', inf.daily11Pct),
      ('Daily 20%', inf.daily20Pct),
      ('Weekly 11%', inf.weekly11Pct),
      ('Weekly 20%', inf.weekly20Pct),
      ('Monthly 11%/20%', inf.riskPremiumReturns),
      ('Contingency (1%)', inf.contingency),
      ('Credit Form Damage', inf.creditFormDamage),
      ('Bonus', inf.bonus),
      ('Credit Form / App Fee', inf.appFee),
      ('Pass Book', inf.passbook),
      ('Bank Withdrawal', inf.bankWithdrawal),
      ('Adjustment In', inf.adjustmentIn),
    ];

    final outflowRows = [
      ('Active Loan (60 Days)', out.disb60d),
      ('Active Loan (120 Days)', out.disb120d),
      ('Active Loan (12 Weeks)', out.disb12w),
      ('Active Loan (24 Weeks)', out.disb24w),
      ('Active Loan (Monthly)', out.disbMth),
      ('Fund Transferred to Branch Office', out.fundTransferredOtherBranch),
      ('Fund Transferred to Head Office', out.fundTransferredHo),
      ('Fund Transferred to Other Areas', out.fundToOtherArea),
      ('Fund to Asset Program', out.fundToAssetProgram),
      ('Fund to Finance', out.fundToProductFinance),
      ('Product/Savings Withdrawal', out.productWithdrawal),
      ('Staff Salaries', out.staffSalaries),
      ('Office Expenses', out.officeExpenses),
      ('Laps Return', out.lapsReturns),
      ('Bank Deposit', out.bankDeposit),
      ('Adjustment Out', out.adjustmentOut),
    ];

    final activeInflows = inflowRows.where((r) => r.$1 == 'Opening Balance' || r.$2.abs() > 0.001).toList();
    final activeOutflows = outflowRows.where((r) => r.$2.abs() > 0.001).toList();
    final totalActive = activeInflows.length + activeOutflows.length;

    final displayedInflows = _tab1HideZeroRows ? activeInflows : inflowRows;
    final displayedOutflows = _tab1HideZeroRows ? activeOutflows : outflowRows;
    final maxLen = displayedInflows.length > displayedOutflows.length ? displayedInflows.length : displayedOutflows.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Ledger (T-Account Sheet)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _tab1HideZeroRows ? '$totalActive active accounts' : 'All 42 accounts',
                    style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (!isMobile) ...[
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _tab1UseSpreadsheet = !_tab1UseSpreadsheet),
                    icon: Icon(
                      _tab1UseSpreadsheet ? Icons.dashboard_outlined : Icons.table_chart_outlined,
                      size: 14,
                      color: tokens.textSecondary,
                    ),
                    label: Text(
                      _tab1UseSpreadsheet ? 'T-Panels' : 'Spreadsheet',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: BorderSide(color: tokens.borderStrong),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      backgroundColor: tokens.surface,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () => setState(() => _tab1HideZeroRows = !_tab1HideZeroRows),
                  icon: Icon(
                    _tab1HideZeroRows ? Icons.visibility_outlined : Icons.filter_alt_outlined,
                    size: 14,
                    color: tokens.textSecondary,
                  ),
                  label: Text(
                    _tab1HideZeroRows ? 'Show All' : 'Active Only',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: BorderSide(color: tokens.borderStrong),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    backgroundColor: tokens.surface,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Mobile Segment Selector for Inflows / Outflows
        if (isMobile) ...[
          Container(
            decoration: BoxDecoration(
              color: tokens.surfaceHover,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.borderSubtle),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _tab1TAccountTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _tab1TAccountTab == 0 ? tokens.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: (_tab1TAccountTab == 0 && !tokens.isDark)
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Both (T-Panels)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _tab1TAccountTab == 0 ? FontWeight.w700 : FontWeight.w500,
                          color: _tab1TAccountTab == 0 ? tokens.textPrimary : tokens.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _tab1TAccountTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _tab1TAccountTab == 1 ? tokens.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: (_tab1TAccountTab == 1 && !tokens.isDark)
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Inflows (${_formatCurrency(data.totalInflows)})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _tab1TAccountTab == 1 ? FontWeight.w700 : FontWeight.w500,
                          color: _tab1TAccountTab == 1 ? tokens.successText : tokens.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _tab1TAccountTab = 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _tab1TAccountTab == 2 ? tokens.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: (_tab1TAccountTab == 2 && !tokens.isDark)
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Outflows (${_formatCurrency(data.totalOutflows)})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _tab1TAccountTab == 2 ? FontWeight.w700 : FontWeight.w500,
                          color: _tab1TAccountTab == 2 ? tokens.dangerText : tokens.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Views Content
        if (!isMobile && !_tab1UseSpreadsheet) ...[
          // Authentic Dual-Column T-Account Panel on Desktop/Tablet
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTAccountPanel(
                  title: 'DEBIT (INFLOWS & OPENING B/F)',
                  totalLabel: 'Total Debit (B/F + Inflows)',
                  totalAmount: data.totalInflows,
                  headerColor: tokens.successText,
                  headerBg: tokens.successBg,
                  headerBorder: tokens.successBorder,
                  items: displayedInflows,
                  icon: Icons.south_west_rounded,
                  isCredit: false,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildTAccountPanel(
                  title: 'CREDIT (CASH OUTFLOWS)',
                  totalLabel: 'Total Outflows',
                  totalAmount: data.totalOutflows,
                  headerColor: tokens.dangerText,
                  headerBg: tokens.dangerBg,
                  headerBorder: tokens.dangerBorder,
                  items: displayedOutflows,
                  icon: Icons.north_east_rounded,
                  isCredit: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildTAccountBalancingBar(data),
        ] else if (isMobile && _tab1TAccountTab == 1)
          _buildSingleLedgerList(
            title: 'Daily Inflows (Debit)',
            items: displayedInflows,
            totalLabel: 'Total Inflows',
            totalValue: data.totalInflows,
            accentColor: tokens.successText,
            icon: Icons.south_west_rounded,
          )
        else if (isMobile && _tab1TAccountTab == 2)
          _buildSingleLedgerList(
            title: 'Daily Outflows (Credit)',
            items: displayedOutflows,
            totalLabel: 'Total Outflows',
            totalValue: data.totalOutflows,
            accentColor: tokens.dangerText,
            icon: Icons.north_east_rounded,
            isCredit: true,
          )
        else if (isMobile && _tab1TAccountTab == 0) ...[
          _buildSingleLedgerList(
            title: 'Daily Inflows (Debit)',
            items: displayedInflows,
            totalLabel: 'Total Inflows',
            totalValue: data.totalInflows,
            accentColor: tokens.successText,
            icon: Icons.south_west_rounded,
          ),
          const SizedBox(height: 14),
          _buildSingleLedgerList(
            title: 'Daily Outflows (Credit)',
            items: displayedOutflows,
            totalLabel: 'Total Outflows',
            totalValue: data.totalOutflows,
            accentColor: tokens.dangerText,
            icon: Icons.north_east_rounded,
            isCredit: true,
          ),
          const SizedBox(height: 14),
          _buildTAccountBalancingBar(data),
        ] else ...[
          // Spreadsheet Data Table
          Container(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                columns: [
                  DataColumn(label: Text('Inflows (Left / Debit)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                  DataColumn(label: Text('Amount (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                  DataColumn(label: Text('Outflows (Right / Credit)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                  DataColumn(label: Text('Amount (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                ],
                rows: [
                  ...List.generate(maxLen, (idx) {
                    final infItem = idx < displayedInflows.length ? displayedInflows[idx] : ('', 0.0);
                    final outItem = idx < displayedOutflows.length ? displayedOutflows[idx] : ('', 0.0);

                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (idx.isOdd) return tokens.surfaceSubtle;
                        return tokens.surface;
                      }),
                      cells: [
                        DataCell(Text(infItem.$1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tokens.textPrimary))),
                        DataCell(Text(infItem.$1.isNotEmpty ? _formatCurrency(infItem.$2) : '', style: TextStyle(fontSize: 12, color: tokens.successText, fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
                        DataCell(Text(outItem.$1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tokens.textPrimary))),
                        DataCell(Text(outItem.$1.isNotEmpty ? _formatCurrency(outItem.$2) : '', style: TextStyle(fontSize: 12, color: tokens.dangerText, fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
                      ],
                    );
                  }),
                  DataRow(
                    color: WidgetStateProperty.all(tokens.surfaceHover),
                    cells: [
                      DataCell(Text('Total Debit (Opening + Receipts)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tokens.successText))),
                      DataCell(Text(_formatCurrency(data.totalInflows), style: TextStyle(fontSize: 12, color: tokens.successText, fontWeight: FontWeight.w800, fontFamily: 'monospace'))),
                      DataCell(Text('Total Credit (Outflows)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tokens.dangerText))),
                      DataCell(Text(_formatCurrency(data.totalOutflows), style: TextStyle(fontSize: 12, color: tokens.dangerText, fontWeight: FontWeight.w800, fontFamily: 'monospace'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildTAccountBalancingBar(data),
        ],
      ],
    );
  }

  Widget _buildTAccountPanel({
    required String title,
    required String totalLabel,
    required double totalAmount,
    required Color headerColor,
    required Color headerBg,
    required Color headerBorder,
    required List<(String, double)> items,
    required IconData icon,
    required bool isCredit,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: tokens.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(9), topRight: Radius.circular(9)),
              border: Border(bottom: BorderSide(color: headerBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: headerColor),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: headerColor, letterSpacing: 0.3),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: headerBorder),
                  ),
                  child: Text(
                    _formatCurrency(totalAmount),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: headerColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items list
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('No active accounts recorded.', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: tokens.borderSubtle),
              itemBuilder: (context, idx) {
                final item = items[idx];
                final isOpening = item.$1.contains('Opening');
                return Container(
                  color: isOpening ? tokens.successBg : (idx.isEven ? tokens.surface : tokens.surfaceSubtle),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (isOpening) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(color: tokens.brandPrimaryDark, borderRadius: BorderRadius.circular(3)),
                                child: const Text('OPEN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                item.$1,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isOpening ? FontWeight.w700 : FontWeight.w500,
                                  color: tokens.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatCurrency(item.$2),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isCredit ? tokens.dangerText : tokens.successText,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // Footer total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(9), bottomRight: Radius.circular(9)),
              border: Border(top: BorderSide(color: tokens.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalLabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary),
                ),
                Text(
                  _formatCurrency(totalAmount),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: headerColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTAccountBalancingBar(MasterCashbookDailyData data) {
    final tokens = IcareSurfaceTokens.of(context);
    final closing = data.closingBalance;
    final isPos = closing >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPos ? tokens.successBg : tokens.dangerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPos ? tokens.successBorder : tokens.dangerBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  isPos ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                  size: 20,
                  color: isPos ? tokens.successDot : tokens.dangerDot,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPos ? 'VAULT POSITION BALANCED' : 'VAULT DEFICIT DETECTED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPos ? tokens.successText : tokens.dangerText,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        'Opening (${_formatCurrency(data.inflows.openingBalance)}) + Receipts (${_formatCurrency(data.totalInflows - data.inflows.openingBalance)}) - Outflows (${_formatCurrency(data.totalOutflows)})',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isPos ? tokens.successText : tokens.dangerText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Closing Balance', style: TextStyle(fontSize: 11, color: tokens.textMuted, fontWeight: FontWeight.w500)),
              Text(
                _formatCurrency(closing),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isPos ? tokens.successText : tokens.dangerText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleLedgerList({
    required String title,
    required List<(String, double)> items,
    required String totalLabel,
    required double totalValue,
    required Color accentColor,
    required IconData icon,
    bool isCredit = false,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: tokens.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: tokens.isDark ? 0.14 : 0.07),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(9), topRight: Radius.circular(9)),
              border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.25))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: accentColor),
                    const SizedBox(width: 8),
                    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accentColor)),
                  ],
                ),
                Text(
                  _formatCurrency(totalValue),
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w800, color: accentColor),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No active entries recorded.', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: tokens.borderSubtle),
              itemBuilder: (context, idx) {
                final item = items[idx];
                final isOpening = item.$1.contains('Opening');
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.$1,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isOpening ? FontWeight.w700 : FontWeight.w500,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatCurrency(item.$2),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: item.$2 > 0 ? (isCredit ? tokens.dangerText : tokens.successText) : tokens.textLight,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBmManualInputsForm(MasterCashbookDailyData data, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: tokens.isDark
            ? null
            : [
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: tokens.surfaceHover,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit_note_outlined, size: 20, color: tokens.textPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BM Manual Inputs & Transfers', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                    Text('Head Office funding, inter-branch transfers, and expenses.', style: TextStyle(fontSize: 11.5, color: tokens.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Card 1: Vault Funding Received (Inflows)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.successBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.successBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.south_west_rounded, size: 15, color: tokens.successDot),
                    const SizedBox(width: 6),
                    Text('Vault Funding Received (Inflows)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.successText)),
                  ],
                ),
                const SizedBox(height: 12),
                if (isMobile) ...[
                  _buildNumberInputField('Funds Received from Head Office', _fundsHoCtrl),
                  const SizedBox(height: 10),
                  _buildNumberInputField('Funds Received from Branch Office', _fundsBranchCtrl),
                  const SizedBox(height: 10),
                  _buildNumberInputField('Funds Received from Other Areas', _fundsAreaCtrl),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _buildNumberInputField('Funds Received from Head Office', _fundsHoCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberInputField('Funds Received from Branch Office', _fundsBranchCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberInputField('Funds Received from Other Areas', _fundsAreaCtrl)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Card 2: Corporate Transfers & Salaries (Outflows)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.dangerBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.dangerBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.north_east_rounded, size: 15, color: tokens.dangerDot),
                    const SizedBox(width: 6),
                    Text('Corporate Transfers & Outflows', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.dangerText)),
                  ],
                ),
                const SizedBox(height: 12),
                if (isMobile) ...[
                  _buildNumberInputField('Fund Transferred to Branch Office', _xferBranchCtrl),
                  const SizedBox(height: 10),
                  _buildNumberInputField('Fund Transferred to H.O.', _xferHoCtrl),
                  const SizedBox(height: 10),
                  _buildNumberInputField('Fund Transferred to Other Areas', _xferAreaCtrl),
                  const SizedBox(height: 10),
                  _buildNumberInputField('Fund to Asset Program', _fundToAssetCtrl),
                  const SizedBox(height: 10),
                  _buildNumberInputField('Staff Salaries', _salariesCtrl),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _buildNumberInputField('Fund Transferred to Branch Office', _xferBranchCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberInputField('Fund Transferred to H.O.', _xferHoCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberInputField('Fund Transferred to Other Areas', _xferAreaCtrl)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildNumberInputField('Fund to Asset Program', _fundToAssetCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberInputField('Staff Salaries', _salariesCtrl)),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Card 3: Branch Treasury Adjustments & Debt Management
          Container(
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: Icon(Icons.tune_outlined, size: 18, color: tokens.textSecondary),
              title: Text(
                'Branch Treasury Adjustments & Debt Management',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
              ),
              subtitle: Text(
                'Record branch-level cash debts, borrowed vault floats, deficit settlements, or direct adjustments.',
                style: TextStyle(fontSize: 11, color: tokens.textMuted),
              ),
              childrenPadding: const EdgeInsets.all(14),
              children: [
                if (isMobile) ...[
                  _buildNumberInputField('Adjustment In (₦)', _adjInCtrl),
                  const SizedBox(height: 10),
                  _buildNumberInputField('Adjustment Out (₦)', _adjOutCtrl),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _buildNumberInputField('Adjustment In (₦)', _adjInCtrl)),
                      const SizedBox(width: 14),
                      Expanded(child: _buildNumberInputField('Adjustment Out (₦)', _adjOutCtrl)),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                _buildTextInputField('Adjustment Reason / Debt Narration', _adjReasonCtrl, placeholder: 'e.g., Short-term emergency cash float borrowed from Mr. X'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Card 4: Daily Balancing Summary & Action
          Text('Daily Balancing Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 650;
              final cardW = isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricCard(
                    width: cardW,
                    label: 'Opening Balance (B/F)',
                    value: _formatCurrency(data.inflows.openingBalance),
                    icon: Icons.lock_clock_outlined,
                    iconColor: tokens.brandPrimary,
                    iconBg: tokens.brandSoftBg,
                  ),
                  _buildMetricCard(
                    width: cardW,
                    label: 'Today Inflows (Receipts)',
                    value: _formatCurrency((data.totalInflows - data.inflows.openingBalance).clamp(0.0, double.infinity)),
                    icon: Icons.south_west_rounded,
                    iconColor: tokens.successDot,
                    iconBg: tokens.successBg,
                  ),
                  _buildMetricCard(
                    width: cardW,
                    label: 'Today Outflows (Credit)',
                    value: _formatCurrency(data.totalOutflows),
                    icon: Icons.north_east_rounded,
                    iconColor: tokens.dangerDot,
                    iconBg: tokens.dangerBg,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _buildClosingBalanceBanner(data.closingBalance),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isSubmittingManual ? null : () => _handleSaveManualEntries(data.isOpen, data.openReason),
              icon: _isSubmittingManual
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18, color: Colors.white),
              label: Text(
                _isSubmittingManual ? 'Saving Entries...' : 'Save Master Cashbook Entry',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.brandPrimaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosingBalanceBanner(double closing) {
    final tokens = IcareSurfaceTokens.of(context);
    final isPos = closing >= 0;
    final color = isPos ? tokens.successText : tokens.dangerText;
    final bg = isPos ? tokens.successBg : tokens.dangerBg;
    final border = isPos ? tokens.successBorder : tokens.dangerBorder;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isPos ? Icons.account_balance_wallet_outlined : Icons.warning_amber_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                'Closing Vault Balance',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
          Text(
            _formatCurrency(closing),
            style: TextStyle(fontFamily: 'monospace', fontSize: 17, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCorrectionHub(MasterCashbookDailyData data, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Branch Error Correction & Reversals Hub',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          'Pending reversal requests and branch corrections.',
          style: TextStyle(fontSize: 12, color: tokens.textMuted),
        ),
        const SizedBox(height: 16),
        Text(
          'Pending Branch Reversal Requests',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textSecondary),
        ),
        const SizedBox(height: 10),
        if (data.pendingReversals.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: tokens.successBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: tokens.successBorder)),
            child: Text('No pending reversal requests for this branch.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.successText)),
          )
        else
          ...data.pendingReversals.map((r) => _buildPendingReversalCard(r, isMobile)),
        const SizedBox(height: 16),
        _buildFlagTreasuryExpander(data.treasuryTransactions),
      ],
    );
  }

  (IconData, Color, Color, Color, String) _getReversalTypeInfo(String recordType, IcareSurfaceTokens tokens) {
    if (recordType.contains('Savings')) {
      return (Icons.savings_outlined, tokens.successText, tokens.successBg, tokens.successBorder, 'Savings Deposit');
    }
    if (recordType.contains('Fee')) {
      return (Icons.receipt_long_outlined, tokens.warningText, tokens.warningBg, tokens.warningBorder, 'EOD Fee');
    }
    if (recordType.contains('Expense')) {
      return (Icons.shopping_cart_outlined, tokens.dangerText, tokens.dangerBg, tokens.dangerBorder, 'Office Expense');
    }
    if (recordType.contains('Treasury')) {
      final purple = tokens.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
      return (Icons.account_balance_outlined, purple, purple.withValues(alpha: tokens.isDark ? 0.16 : 0.08), purple.withValues(alpha: 0.35), 'Treasury Transfer');
    }
    return (Icons.payments_outlined, tokens.infoText, tokens.infoBg, tokens.infoBorder, 'Loan Repayment');
  }

  Widget _buildPendingReversalCard(MasterPendingReversalData req, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final typeInfo = _getReversalTypeInfo(req.recordType, tokens);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: tokens.isDark
            ? null
            : [
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeInfo.$3,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: typeInfo.$4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeInfo.$1, size: 14, color: typeInfo.$2),
                          const SizedBox(width: 5),
                          Text(
                            typeInfo.$5,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: typeInfo.$2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: tokens.surfaceHover, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        'Ref #${req.recordId.length > 8 ? req.recordId.substring(0, 8) : req.recordId}',
                        style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: tokens.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.format(req.amount),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: tokens.dangerText, fontFamily: 'monospace'),
                    ),
                    if (req.clientName != null && req.clientName!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• ${req.clientName!} ${req.clientCode != null && req.clientCode!.isNotEmpty ? "(${req.clientCode})" : ""}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.warningBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tokens.warningBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_top_outlined, size: 11, color: tokens.warningText),
                    const SizedBox(width: 4),
                    Text('Pending Approval', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.warningText)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline, size: 13, color: tokens.textMuted),
              const SizedBox(width: 4),
              Text(
                'Requested by ${req.requestedByName}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary),
              ),
              const SizedBox(width: 8),
              Text('•', style: TextStyle(color: tokens.borderStrong)),
              const SizedBox(width: 8),
              Icon(Icons.access_time, size: 13, color: tokens.textMuted),
              const SizedBox(width: 4),
              Text(
                req.createdAt.length > 16 ? req.createdAt.substring(0, 16).replaceAll('T', ' ') : req.createdAt,
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_outlined, size: 15, color: tokens.textLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    req.reason,
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: tokens.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _handleRejectReversal(req),
                icon: Icon(Icons.close, size: 14, color: tokens.textSecondary),
                label: Text('Reject', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.borderStrong),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _handleApproveReversal(req),
                icon: const Icon(Icons.check, size: 14, color: Colors.white),
                label: const Text('Approve Reversal', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.brandPrimaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlagTreasuryExpander(List<MasterTreasuryTransactionData> transactions) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: tokens.warningBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.flag_outlined, size: 16, color: tokens.warningDot),
        ),
        title: Text('Flag Branch Treasury Entry for Reversal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (transactions.isEmpty)
            Text('No recent branch treasury transactions found.', style: TextStyle(fontSize: 12, color: tokens.textMuted))
          else ...[
            DropdownButtonFormField<String>(
              value: _selectedTreasuryTxId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select Treasury Entry to Flag',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: transactions.map((t) {
                return DropdownMenuItem<String>(
                  value: t.id,
                  child: Text(t.label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedTreasuryTxId = val),
            ),
            const SizedBox(height: 12),
            _buildTextInputField('Reason for Reversal', _treasuryRevReasonCtrl, placeholder: 'e.g., Wrong salary amount entered.'),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _isSubmittingReversal ? null : _handleFlagTreasuryReversal,
                icon: _isSubmittingReversal
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.flag_outlined, size: 18, color: Colors.white),
                label: Text(_isSubmittingReversal ? 'Submitting Request...' : 'Submit Treasury Reversal Request', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: CO CASHBOOKS AGGREGATION
  // ==========================================

  Widget _buildTab2CoAggregation(bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final branches = _getAvailableBranches();
    if (_selectedBranchTab2 == null && branches.isNotEmpty) {
      _selectedBranchTab2 = _selectedBranchTab1 ?? branches.first;
    }
    final activeBranch = _selectedBranchTab2 ?? _selectedBranchTab1;
    final key = '${_formatDate(_selectedDateTab2)}||${_selectedOfficerTab2 ?? ""}||${activeBranch ?? ""}';
    final asyncCo = ref.watch(coAggregationProvider(key));

    return asyncCo.when(
      loading: () => const IcareTableSkeleton(rowCount: 8, hasFilterBar: false),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: tokens.dangerBg, borderRadius: BorderRadius.circular(8)),
        child: Text('Error loading CO Cashbook aggregation: $err', style: TextStyle(color: tokens.dangerText)),
      ),
      data: (data) {
        if (_selectedOfficerTab2 == null && data.officers.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => _selectedOfficerTab2 = data.officers[0].username);
          });
        }

        final inflowEntries = data.inflows.entries.map((e) => (e.key, e.value)).toList();
        final outflowEntries = data.outflows.entries.map((e) => (e.key, e.value)).toList();

        final activeInflows = inflowEntries.where((e) => e.$1.toLowerCase().contains('opening') || e.$2.abs() > 0.001).toList();
        final activeOutflows = outflowEntries.where((e) => e.$2.abs() > 0.001).toList();

        final displayedInflows = _tab2HideZeroRows ? activeInflows : inflowEntries;
        final displayedOutflows = _tab2HideZeroRows ? activeOutflows : outflowEntries;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTab2ControlBar(data, isMobile),
            const SizedBox(height: 16),
            // High-priority KPI Summary Cards at the top of Tab 2
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final cardW = isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
                final isPos = data.closingBalance >= 0;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMetricCard(
                      width: cardW,
                      label: 'Opening Balance',
                      value: _formatCurrency(data.openingBalance),
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: tokens.textSecondary,
                      iconBg: tokens.surfaceHover,
                    ),
                    _buildMetricCard(
                      width: cardW,
                      label: 'Total Inflows',
                      value: _formatCurrency(data.totalInflows),
                      icon: Icons.south_west_rounded,
                      iconColor: tokens.successDot,
                      iconBg: tokens.successBg,
                    ),
                    _buildMetricCard(
                      width: cardW,
                      label: 'Total Outflows',
                      value: _formatCurrency(data.totalOutflows),
                      icon: Icons.north_east_rounded,
                      iconColor: tokens.dangerDot,
                      iconBg: tokens.dangerBg,
                    ),
                    _buildMetricCard(
                      width: cardW,
                      label: 'Closing Balance',
                      value: _formatCurrency(data.closingBalance),
                      icon: Icons.savings_outlined,
                      iconColor: isPos ? tokens.successDot : tokens.dangerDot,
                      iconBg: isPos ? tokens.successBg : tokens.dangerBg,
                      valueColor: isPos ? tokens.successText : tokens.dangerText,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAm ? 'Area Supervisory Credit Officer Inspection' : 'Credit Officer Daily Cashbook Ledger',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                      ),
                      Text(
                        '${data.officer.isNotEmpty ? data.officer : "All Officers"}${data.branch.isNotEmpty ? " • ${data.branch}" : (activeBranch != null && activeBranch.isNotEmpty ? " • $activeBranch" : "")} • ${DateFormat("dd MMM yyyy").format(_selectedDateTab2)}',
                        style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _tab2HideZeroRows = !_tab2HideZeroRows),
                      icon: Icon(
                        _tab2HideZeroRows ? Icons.visibility_outlined : Icons.filter_alt_outlined,
                        size: 14,
                        color: tokens.textSecondary,
                      ),
                      label: Text(
                        _tab2HideZeroRows ? 'Active Only' : 'Show All',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(color: tokens.borderStrong),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        backgroundColor: tokens.surface,
                      ),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _tab2UseSpreadsheet = !_tab2UseSpreadsheet),
                        icon: Icon(
                          _tab2UseSpreadsheet ? Icons.view_agenda_outlined : Icons.table_chart_outlined,
                          size: 14,
                          color: tokens.textSecondary,
                        ),
                        label: Text(
                          _tab2UseSpreadsheet ? 'T-Panels' : 'Spreadsheet',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: BorderSide(color: tokens.borderStrong),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          backgroundColor: tokens.surface,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isMobile) ...[
              // Mobile Segmented Selector for Inflows / Outflows / Both
              Container(
                decoration: BoxDecoration(
                  color: tokens.surfaceHover,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _tab2TAccountTab = 0),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _tab2TAccountTab == 0 ? tokens.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: (_tab2TAccountTab == 0 && !tokens.isDark) ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)] : null,
                          ),
                          child: Text('Both', style: TextStyle(fontSize: 12, fontWeight: _tab2TAccountTab == 0 ? FontWeight.w700 : FontWeight.w500, color: _tab2TAccountTab == 0 ? tokens.textPrimary : tokens.textMuted)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _tab2TAccountTab = 1),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _tab2TAccountTab == 1 ? tokens.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: (_tab2TAccountTab == 1 && !tokens.isDark) ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)] : null,
                          ),
                          child: Text('Inflows', style: TextStyle(fontSize: 12, fontWeight: _tab2TAccountTab == 1 ? FontWeight.w700 : FontWeight.w500, color: _tab2TAccountTab == 1 ? tokens.successText : tokens.textMuted)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _tab2TAccountTab = 2),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _tab2TAccountTab == 2 ? tokens.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: (_tab2TAccountTab == 2 && !tokens.isDark) ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)] : null,
                          ),
                          child: Text('Outflows', style: TextStyle(fontSize: 12, fontWeight: _tab2TAccountTab == 2 ? FontWeight.w700 : FontWeight.w500, color: _tab2TAccountTab == 2 ? tokens.dangerText : tokens.textMuted)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_tab2TAccountTab == 0 || _tab2TAccountTab == 1) ...[
                _buildSingleLedgerList(
                  title: 'DEBIT (Cash Inflows)',
                  items: displayedInflows,
                  totalLabel: 'Total Inflows',
                  totalValue: data.totalInflows,
                  accentColor: tokens.successText,
                  icon: Icons.south_west_rounded,
                ),
                const SizedBox(height: 12),
              ],
              if (_tab2TAccountTab == 0 || _tab2TAccountTab == 2) ...[
                _buildSingleLedgerList(
                  title: 'CREDIT (Cash Outflows)',
                  items: displayedOutflows,
                  totalLabel: 'Total Outflows',
                  totalValue: data.totalOutflows,
                  accentColor: tokens.dangerText,
                  icon: Icons.north_east_rounded,
                  isCredit: true,
                ),
                const SizedBox(height: 12),
              ],
              _buildCoTAccountBalancingBar(data),
            ] else if (!_tab2UseSpreadsheet) ...[
              // Desktop/Tablet Dual Column T-Account Panels
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTAccountPanel(
                      title: 'DEBIT (Cash Inflows)',
                      totalLabel: 'Total Inflows',
                      totalAmount: data.totalInflows,
                      headerColor: tokens.successText,
                      headerBg: tokens.successBg,
                      headerBorder: tokens.successBorder,
                      items: displayedInflows,
                      icon: Icons.south_west_rounded,
                      isCredit: false,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildTAccountPanel(
                      title: 'CREDIT (Cash Outflows)',
                      totalLabel: 'Total Outflows',
                      totalAmount: data.totalOutflows,
                      headerColor: tokens.dangerText,
                      headerBg: tokens.dangerBg,
                      headerBorder: tokens.dangerBorder,
                      items: displayedOutflows,
                      icon: Icons.north_east_rounded,
                      isCredit: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildCoTAccountBalancingBar(data),
            ] else ...[
              _buildCoLedgerTable(data, isMobile),
            ],
            const SizedBox(height: 24),
            Divider(color: tokens.borderSubtle),
            const SizedBox(height: 16),
            _buildEodControls(data, isMobile),
          ],
        );
      },
    );
  }

  Widget _buildTab2ControlBar(CoAggregationData data, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final curDate = DateTime(_selectedDateTab2.year, _selectedDateTab2.month, _selectedDateTab2.day);
    final isToday = curDate == today;
    final isYesterday = curDate == yesterday;
    final isClosed = !data.isOpen && data.openReason.toLowerCase().contains('closed');
    final branches = _getAvailableBranches();
    final activeBranch = _selectedBranchTab2 ?? _selectedBranchTab1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (branches.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Icon(Icons.apartment, size: 16, color: tokens.brandPrimary),
                  const SizedBox(width: 8),
                  Text('Supervised Branch:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                  const SizedBox(width: 8),
                  for (final b in branches) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: Icon(Icons.storefront, size: 14, color: activeBranch == b ? Colors.white : tokens.brandPrimary),
                        label: Text(b, style: TextStyle(fontSize: 12, fontWeight: activeBranch == b ? FontWeight.w800 : FontWeight.w600, color: activeBranch == b ? Colors.white : tokens.textPrimary)),
                        selected: activeBranch == b,
                        selectedColor: tokens.brandPrimaryDark,
                        backgroundColor: tokens.surfaceSubtle,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: activeBranch == b ? tokens.brandPrimaryDark : tokens.borderStrong),
                        onSelected: (selected) {
                          if (selected && activeBranch != b) {
                            _changeActiveBranch(b);
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(height: 18, color: tokens.borderSubtle),
          ],
          if (isMobile) ...[
            // Mobile: Date picker and chips row
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDateTab2,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _selectedDateTab2 = picked);
                    }
                  },
                  icon: Icon(Icons.calendar_today_outlined, size: 15, color: tokens.textPrimary),
                  label: Text(
                    DateFormat('EEE, dd MMM yyyy').format(_selectedDateTab2),
                    style: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary, fontSize: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: tokens.surfaceSubtle,
                    side: BorderSide(color: tokens.borderStrong),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => setState(() => _selectedDateTab2 = today),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      color: isToday ? tokens.brandPrimaryDark : tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isToday ? tokens.brandPrimaryDark : tokens.borderStrong),
                    ),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                        color: isToday ? Colors.white : tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => setState(() => _selectedDateTab2 = yesterday),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      color: isYesterday ? tokens.brandPrimaryDark : tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isYesterday ? tokens.brandPrimaryDark : tokens.borderStrong),
                    ),
                    child: Text(
                      'Y\'day',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isYesterday ? FontWeight.w700 : FontWeight.w600,
                        color: isYesterday ? Colors.white : tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (data.officers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderStrong),
                ),
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 16, color: tokens.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: tokens.surfaceElevated,
                          iconEnabledColor: tokens.textSecondary,
                          value: _selectedOfficerTab2 ?? (data.officers.isNotEmpty ? data.officers[0].username : null),
                          items: data.officers.map((o) {
                            return DropdownMenuItem<String>(
                              value: o.username,
                              child: Text(o.display, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedOfficerTab2 = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isClosed
                        ? tokens.infoBg
                        : (data.isOpen ? tokens.successBg : tokens.warningBg),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isClosed
                          ? tokens.infoBorder
                          : (data.isOpen ? tokens.successBorder : tokens.warningBorder),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isClosed
                            ? Icons.check_circle_outline
                            : (data.isOpen ? Icons.lock_open_outlined : Icons.lock_outlined),
                        size: 12,
                        color: isClosed
                            ? tokens.infoText
                            : (data.isOpen ? tokens.successDot : tokens.warningDot),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isClosed ? 'Day Closed' : (data.isOpen ? 'Ledger Open' : 'Ledger Frozen'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isClosed
                              ? tokens.infoText
                              : (data.isOpen ? tokens.successText : tokens.warningText),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            // Desktop/Tablet: Single row
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDateTab2,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _selectedDateTab2 = picked);
                    }
                  },
                  icon: Icon(Icons.calendar_today_outlined, size: 15, color: tokens.textPrimary),
                  label: Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(_selectedDateTab2),
                    style: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: tokens.surfaceSubtle,
                    side: BorderSide(color: tokens.borderStrong),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _selectedDateTab2 = today),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isToday ? tokens.brandPrimaryDark : tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isToday ? tokens.brandPrimaryDark : tokens.borderStrong),
                    ),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                        color: isToday ? Colors.white : tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => setState(() => _selectedDateTab2 = yesterday),
                  borderRadius: BorderRadius.circular(6),
                      child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isYesterday ? tokens.brandPrimaryDark : tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isYesterday ? tokens.brandPrimaryDark : tokens.borderStrong),
                    ),
                    child: Text(
                      'Yesterday',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isYesterday ? FontWeight.w700 : FontWeight.w600,
                        color: isYesterday ? Colors.white : tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
                if (data.officers.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  Container(
                    height: 24,
                    width: 1,
                    color: tokens.borderSubtle,
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.borderStrong),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.badge_outlined, size: 15, color: tokens.textMuted),
                        const SizedBox(width: 6),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: tokens.surfaceElevated,
                            iconEnabledColor: tokens.textSecondary,
                            value: _selectedOfficerTab2 ?? (data.officers.isNotEmpty ? data.officers[0].username : null),
                            items: data.officers.map((o) {
                              return DropdownMenuItem<String>(
                                value: o.username,
                                child: Text(o.display, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedOfficerTab2 = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isClosed
                        ? tokens.infoBg
                        : (data.isOpen ? tokens.successBg : tokens.warningBg),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isClosed
                          ? tokens.infoBorder
                          : (data.isOpen ? tokens.successBorder : tokens.warningBorder),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isClosed
                            ? Icons.check_circle_outline
                            : (data.isOpen ? Icons.lock_open_outlined : Icons.lock_outlined),
                        size: 13,
                        color: isClosed
                            ? tokens.infoText
                            : (data.isOpen ? tokens.successDot : tokens.warningDot),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isClosed ? 'Day Closed' : (data.isOpen ? 'Ledger Open' : 'Ledger Frozen'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isClosed
                              ? tokens.infoText
                              : (data.isOpen ? tokens.successText : tokens.warningText),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoTAccountBalancingBar(CoAggregationData data) {
    final tokens = IcareSurfaceTokens.of(context);
    final closing = data.closingBalance;
    final isPos = closing >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPos ? tokens.successBg : tokens.dangerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPos ? tokens.successBorder : tokens.dangerBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  isPos ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                  size: 20,
                  color: isPos ? tokens.successDot : tokens.dangerDot,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPos ? 'CO LEDGER BALANCED' : 'CO DEFICIT DETECTED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPos ? tokens.successText : tokens.dangerText,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        'Opening (${_formatCurrency(data.openingBalance)}) + Receipts (${_formatCurrency(data.totalInflows - data.openingBalance)}) - Outflows (${_formatCurrency(data.totalOutflows)})',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: (isPos ? tokens.successText : tokens.dangerText).withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Closing Balance', style: TextStyle(fontSize: 11, color: tokens.textMuted, fontWeight: FontWeight.w500)),
              Text(
                _formatCurrency(closing),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isPos ? tokens.successText : tokens.dangerText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoLedgerTable(CoAggregationData data, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final inflowItems = data.inflows.entries.toList();
    final outflowItems = data.outflows.entries.toList();

    final activeInflows = inflowItems.where((e) => e.key.toLowerCase().contains('opening') || e.value.abs() > 0.001).toList();
    final activeOutflows = outflowItems.where((e) => e.value.abs() > 0.001).toList();

    final displayedInflows = _tab2HideZeroRows ? activeInflows : inflowItems;
    final displayedOutflows = _tab2HideZeroRows ? activeOutflows : outflowItems;
    final maxLen = displayedInflows.length > displayedOutflows.length ? displayedInflows.length : displayedOutflows.length;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz, size: 14, color: tokens.textMuted),
                  const SizedBox(width: 4),
                  Text('Scroll horizontally to view debit/credit columns', style: TextStyle(fontSize: 11, color: tokens.textMuted, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          Scrollbar(
            thumbVisibility: isMobile,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                columns: [
                  DataColumn(label: Text('Inflows (Left / Debit)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                  DataColumn(label: Text('Amount (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                  DataColumn(label: Text('Outflows (Right / Credit)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                  DataColumn(label: Text('Amount (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary))),
                ],
                rows: [
                  ...List.generate(maxLen, (idx) {
                    final inf = idx < displayedInflows.length ? displayedInflows[idx] : null;
                    final out = idx < displayedOutflows.length ? displayedOutflows[idx] : null;

                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (idx.isOdd) return tokens.surfaceSubtle;
                        return tokens.surface;
                      }),
                      cells: [
                        DataCell(Text(inf?.key ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tokens.textPrimary))),
                        DataCell(Text(inf != null ? _formatCurrency(inf.value) : '', style: TextStyle(fontSize: 12, color: tokens.successText, fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
                        DataCell(Text(out?.key ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tokens.textPrimary))),
                        DataCell(Text(out != null ? _formatCurrency(out.value) : '', style: TextStyle(fontSize: 12, color: tokens.dangerText, fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
                      ],
                    );
                  }),
                  DataRow(
                    color: WidgetStateProperty.all(tokens.neutralBg),
                    cells: [
                      DataCell(Text('Total Debit (Opening + Receipts)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tokens.successText))),
                      DataCell(Text(_formatCurrency(data.totalInflows), style: TextStyle(fontSize: 12, color: tokens.successText, fontWeight: FontWeight.w800, fontFamily: 'monospace'))),
                      DataCell(Text('Total Credit (Outflows)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tokens.dangerText))),
                      DataCell(Text(_formatCurrency(data.totalOutflows), style: TextStyle(fontSize: 12, color: tokens.dangerText, fontWeight: FontWeight.w800, fontFamily: 'monospace'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEodControls(CoAggregationData data, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final dateStr = _formatDate(_selectedDateTab2);
    final isClosed = !data.isOpen && data.openReason.toLowerCase().contains('closed');
    final isAm = _isAm;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.02),
            blurRadius: 4,
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.security_outlined, size: 20, color: tokens.textPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAm ? 'Daily Vault Ledger Supervisory Status' : 'Branch Manager End of Day (EOD) Operations',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                    ),
                    Text(
                      isAm ? 'Certified operational status & vault freeze inspection.' : 'Daily ledger freeze & date rollover.',
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isAm) ...[
            if (isClosed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.successBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.successBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_outlined, color: tokens.successDot, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Certified Day Close for $dateStr • Vault balance locked and day closed by Branch Manager.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.successText),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.brandSoftBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.brandSoftBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: tokens.brandPrimary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Supervisory Inspection Mode • Operational Date: $dateStr. Vault Day Close is an operational control executed exclusively by the Branch Manager.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.brandSoftText),
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            if (isClosed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.infoBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.infoBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: tokens.infoText, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Day Close Executed for $dateStr • Operational date advanced.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.infoText),
                      ),
                    ),
                  ],
                ),
              )
            else if (!data.isOpen)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.warningBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.warningBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outlined, color: tokens.warningDot, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cannot execute Day Close (${data.openReason}).',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.warningText),
                      ),
                    ),
                  ],
                ),
              )
            else if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.infoBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.infoBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: tokens.infoText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Operational Date: $dateStr • Freezes daily entries and advances to Next Working Day.',
                            style: TextStyle(fontSize: 12, color: tokens.infoText, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isExecutingEod ? null : () => _confirmAndExecuteEod(dateStr, data.closingBalance),
                    icon: _isExecutingEod
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                    label: const Text('Execute EOD Day Close', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brandPrimaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.infoBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.infoBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: tokens.infoText),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Operational Date: $dateStr • Freezes daily entries and advances to Next Working Day.',
                              style: TextStyle(fontSize: 12, color: tokens.infoText, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isExecutingEod ? null : () => _confirmAndExecuteEod(dateStr, data.closingBalance),
                    icon: _isExecutingEod
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                    label: const Text('Execute EOD Day Close', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brandPrimaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  void _confirmAndExecuteEod(String dateStr, double closingBal) {
    String selectedTag = closingBal == 0
        ? 'Balanced'
        : (closingBal > 0
            ? 'Cash locked in office safe overnight'
            : 'Advance payments (loans & savings) banked ahead of schedule');
    final notesController = TextEditingController();

    final isZero = closingBal == 0;
    final isPos = closingBal > 0;
    final statusText = isZero
        ? 'Balanced (₦0.00)'
        : (isPos
            ? 'Cash in Safe / Office (+${_formatCurrency(closingBal)})'
            : 'Advance Money Banked Ahead (-${_formatCurrency(closingBal.abs())})');

    final options = isZero
        ? ['All collections banked today']
        : (isPos
            ? [
                'Cash locked in office safe overnight',
                'Advance client marked present on sheet',
                'Other reason'
              ]
            : [
                'Advance payments (loans & savings) banked ahead of schedule',
                'Savings withdrawals paid out to clients',
                'Other reason'
              ]);

    showIcareDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final tokens = IcareSurfaceTokens.of(ctx);
          final statusColor = isZero
              ? tokens.successText
              : (isPos ? tokens.infoText : tokens.warningText);
          final statusBg = isZero
              ? tokens.successBg
              : (isPos ? tokens.infoBg : tokens.warningBg);
          final statusBorder = isZero
              ? tokens.successBorder
              : (isPos ? tokens.infoBorder : tokens.warningBorder);

          return AlertDialog(
            backgroundColor: tokens.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Icon(Icons.shield_outlined, color: tokens.textPrimary, size: 22),
                const SizedBox(width: 8),
                Text('Confirm Day Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you ready to close business operations for $dateStr?',
                    style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: statusColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isZero
                              ? 'All collections were paid into the commercial bank today.'
                              : (isPos
                                  ? 'Cash remains in office custody overnight or advance credit logged.'
                                  : 'Cash was banked ahead for future meetings or client savings paid out.'),
                          style: TextStyle(fontSize: 11.5, color: statusColor.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                  if (!isZero) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Reason for Balance:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    ...options.map((opt) => RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: tokens.brandPrimary,
                      value: opt,
                      groupValue: selectedTag,
                      title: Text(opt, style: TextStyle(fontSize: 12.5, color: tokens.textPrimary)),
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedTag = val);
                      },
                    )),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Add Note for Area Manager (Optional)',
                      labelStyle: TextStyle(color: tokens.textMuted),
                      hintText: 'e.g. Mama Chinedu paid 4 weeks advance into bank.',
                      hintStyle: TextStyle(color: tokens.textMuted),
                      filled: true,
                      fillColor: tokens.surfaceSubtle,
                      border: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderSubtle)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.borderStrong)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: tokens.brandPrimary, width: 1.5)),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: tokens.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Closing balance rolls forward as tomorrow morning opening money.',
                            style: TextStyle(fontSize: 11, color: tokens.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.borderStrong),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text('Cancel', style: TextStyle(color: tokens.textSecondary, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _handleExecuteEod(
                    dateStr,
                    reasonTag: selectedTag,
                    notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.brandPrimaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Confirm & Close Day', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 3: MONTHLY LEDGER
  // ==========================================

  Widget _buildTab3MonthlyLedger(bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final key = '$_selectedMonth||$_selectedYear||${_selectedBranchTab3 ?? ""}';
    final asyncMonthly = ref.watch(monthlyLedgerProvider(key));

    return asyncMonthly.when(
      loading: () => const IcareTableSkeleton(rowCount: 8, hasFilterBar: false),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.dangerBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.dangerBorder),
        ),
        child: Text('Error loading Monthly Ledger: $err', style: TextStyle(color: tokens.dangerText)),
      ),
      data: (data) {
        if (_selectedBranchTab3 == null && data.availableBranches.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => _selectedBranchTab3 = data.branch);
          });
        }

        final currentBranch = _selectedBranchTab3 ?? data.branch;
        final isHeadOffice = currentBranch == 'Head Office';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTab3ControlCard(data, currentBranch, isMobile),
            const SizedBox(height: 18),
            if (isHeadOffice || currentBranch.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.infoBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.infoBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: tokens.infoText, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Please select an operational branch to view the monthly ledger.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.infoText),
                      ),
                    ),
                  ],
                ),
              )
            else if (data.rows.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.infoBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.infoBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: tokens.infoText, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No ledger entries found for $currentBranch in ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth, 1))}.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.infoText),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Top-level Month Summary Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  final cardW = isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
                  final isPos = data.monthClosing >= 0;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildMetricCard(
                        width: cardW,
                        label: 'Month Opening Balance',
                        value: _formatIntegerCurrency(data.monthOpening),
                        icon: Icons.account_balance_outlined,
                        iconColor: tokens.textSecondary,
                        iconBg: tokens.surfaceSubtle,
                      ),
                      _buildMetricCard(
                        width: cardW,
                        label: 'Total Monthly Inflows',
                        value: _formatIntegerCurrency(data.totalMonthInflows),
                        icon: Icons.south_west_rounded,
                        iconColor: tokens.successText,
                        iconBg: tokens.successBg,
                      ),
                      _buildMetricCard(
                        width: cardW,
                        label: 'Total Monthly Outflows',
                        value: _formatIntegerCurrency(data.totalMonthOutflows),
                        icon: Icons.north_east_rounded,
                        iconColor: tokens.dangerText,
                        iconBg: tokens.dangerBg,
                      ),
                      _buildMetricCard(
                        width: cardW,
                        label: 'Month-End Closing Balance',
                        value: _formatIntegerCurrency(data.monthClosing),
                        icon: Icons.account_balance_wallet_outlined,
                        iconColor: isPos ? tokens.successText : tokens.dangerText,
                        iconBg: isPos ? tokens.successBg : tokens.dangerBg,
                        valueColor: isPos ? tokens.successText : tokens.dangerText,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Export Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tokens.successBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: tokens.successBorder),
                            ),
                            child: Icon(Icons.description_outlined, size: 20, color: tokens.successText),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Monthly Ledger Workbook Export',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                                ),
                                Text(
                                  'Complete 42-column Vault Cash Ledger matrix (.xlsx)',
                                  style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isDownloadingExcel ? null : () => _handleDownloadExcel(currentBranch),
                      icon: _isDownloadingExcel
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.file_download_outlined, size: 16, color: Colors.white),
                      label: Text(
                        _isDownloadingExcel ? 'Generating...' : 'Export Excel',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimaryDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // View Header & Toggle
              if (isMobile) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _tab3DailyFeedView ? 'Daily Entries (${data.rows.length} days)' : 'Full Matrix Spreadsheet',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _tab3DailyFeedView = !_tab3DailyFeedView),
                      icon: Icon(_tab3DailyFeedView ? Icons.table_chart_outlined : Icons.view_agenda_outlined, size: 14, color: tokens.textSecondary),
                      label: Text(
                        _tab3DailyFeedView ? 'Table View' : 'Card View',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(color: tokens.borderStrong),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        backgroundColor: tokens.surface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_tab3DailyFeedView)
                  _buildMonthlyLedgerDailyFeed(data.rows)
                else
                  _buildMonthlyLedgerTable(data.rows, isMobile),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Ledger Details (${data.rows.length} Active Days)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMonthlyLedgerTable(data.rows, isMobile),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _buildTab3ControlCard(MonthlyLedgerData data, String currentBranch, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    final monthSelector = DropdownButtonFormField<int>(
      value: _selectedMonth,
      dropdownColor: tokens.surfaceElevated,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
      decoration: InputDecoration(
        labelText: 'Month',
        labelStyle: TextStyle(fontSize: 12, color: tokens.textMuted),
        prefixIcon: Icon(Icons.calendar_month_outlined, size: 18, color: tokens.textMuted),
        filled: true,
        fillColor: tokens.surfaceSubtle,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderSubtle)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.brandPrimary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: List.generate(12, (index) {
        final m = index + 1;
        return DropdownMenuItem<int>(
          value: m,
          child: Text(DateFormat('MMMM').format(DateTime(2026, m, 1)), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
        );
      }),
      onChanged: (val) {
        if (val != null) setState(() => _selectedMonth = val);
      },
    );

    final yearField = TextFormField(
      initialValue: _selectedYear.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Year',
        labelStyle: TextStyle(fontSize: 12, color: tokens.textMuted),
        prefixIcon: Icon(Icons.schedule_outlined, size: 18, color: tokens.textMuted),
        filled: true,
        fillColor: tokens.surfaceSubtle,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderSubtle)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.brandPrimary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: tokens.textPrimary),
      onChanged: (val) {
        final parsed = int.tryParse(val);
        if (parsed != null && parsed >= 2024 && parsed <= 2030) {
          setState(() => _selectedYear = parsed);
        }
      },
    );

    final branchSelector = DropdownButtonFormField<String>(
      value: currentBranch,
      isExpanded: true,
      dropdownColor: tokens.surfaceElevated,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
      decoration: InputDecoration(
        labelText: 'Operating Branch',
        labelStyle: TextStyle(fontSize: 12, color: tokens.textMuted),
        prefixIcon: Icon(Icons.business_outlined, size: 18, color: tokens.textMuted),
        filled: true,
        fillColor: tokens.surfaceSubtle,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderSubtle)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.brandPrimary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabled: data.availableBranches.length > 1,
      ),
      items: data.availableBranches.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary)))).toList(),
      onChanged: data.availableBranches.length > 1
          ? (val) {
              if (val != null) _changeActiveBranch(val);
            }
          : null,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.02),
            blurRadius: 4,
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.tune_outlined, size: 18, color: tokens.textPrimary),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Ledger Parameters', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                  Text('Historical Vault Cash Reserve review.', style: TextStyle(fontSize: 11.5, color: tokens.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isMobile) ...[
            Row(
              children: [
                Expanded(child: monthSelector),
                const SizedBox(width: 10),
                Expanded(child: yearField),
              ],
            ),
            const SizedBox(height: 10),
            branchSelector,
          ] else ...[
            Row(
              children: [
                Expanded(child: monthSelector),
                const SizedBox(width: 12),
                Expanded(child: yearField),
                const SizedBox(width: 12),
                Expanded(child: branchSelector),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlyLedgerDailyFeed(List<MonthlyLedgerRowData> rows) {
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      children: rows.map((r) {
        final netCash = r.totalInflows - r.totalOutflows;
        final isPos = netCash >= 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.02),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ExpansionTile(
            shape: const Border(),
            iconColor: tokens.textMuted,
            collapsedIconColor: tokens.textMuted,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Text(
                r.date.length >= 10 ? r.date.substring(5) : r.date,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textSecondary, fontFamily: 'monospace'),
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Close: ${_formatIntegerCurrency(r.closingBalance)}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tokens.textPrimary, fontFamily: 'monospace'),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isPos ? tokens.successBg : tokens.dangerBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isPos ? tokens.successBorder : tokens.dangerBorder),
                  ),
                  child: Text(
                    '${isPos ? '+' : ''}${_formatIntegerCurrency(netCash)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: isPos ? tokens.successText : tokens.dangerText,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text('In: ${_formatIntegerCurrency(r.totalInflows)}', style: TextStyle(fontSize: 11, color: tokens.successText, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                  Text(' • ', style: TextStyle(color: tokens.textMuted)),
                  Text('Out: ${_formatIntegerCurrency(r.totalOutflows)}', style: TextStyle(fontSize: 11, color: tokens.dangerText, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                  Text(' • ', style: TextStyle(color: tokens.textMuted)),
                  Text('Open: ${_formatIntegerCurrency(r.openingBalance)}', style: TextStyle(fontSize: 11, color: tokens.textMuted, fontFamily: 'monospace')),
                ],
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            children: [
              Divider(color: tokens.borderSubtle),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Savings Deposits', style: TextStyle(fontSize: 11.5, color: tokens.textMuted)),
                  Text(_formatIntegerCurrency(r.savingsDeposit), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: tokens.textPrimary)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Daily Collections (60d/120d)', style: TextStyle(fontSize: 11.5, color: tokens.textMuted)),
                  Text(_formatIntegerCurrency(r.repDaily + r.rep120Days), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: tokens.textPrimary)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bank Deposits', style: TextStyle(fontSize: 11.5, color: tokens.textMuted)),
                  Text(_formatIntegerCurrency(r.bankDeposit), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.dangerText, fontFamily: 'monospace')),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Active Loan Disbursements', style: TextStyle(fontSize: 11.5, color: tokens.textMuted)),
                  Text(_formatIntegerCurrency(r.disb60d + r.disb120d + r.disb12w + r.disb24w + r.disbMth), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.dangerText, fontFamily: 'monospace')),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthlyLedgerTable(List<MonthlyLedgerRowData> rows, bool isMobile) {
    final tokens = IcareSurfaceTokens.of(context);
    // Column Totals for Summary Row (every numeric column summed; Opening/Closing reflect Day-1 / Month-End)
    final monthOpening = rows.isNotEmpty ? rows.first.openingBalance : 0.0;
    final monthClosing = rows.isNotEmpty ? rows.last.closingBalance : 0.0;
    final totalSavings = rows.fold(0.0, (s, r) => s + r.savingsDeposit);
    final totalRepDaily = rows.fold(0.0, (s, r) => s + r.repDaily);
    final totalRep120 = rows.fold(0.0, (s, r) => s + r.rep120Days);
    final totalRep12w = rows.fold(0.0, (s, r) => s + r.rep12Weeks);
    final totalRep24w = rows.fold(0.0, (s, r) => s + r.rep24Weeks);
    final totalRepMth = rows.fold(0.0, (s, r) => s + r.repMonthly);
    final totalLapsReserve = rows.fold(0.0, (s, r) => s + r.lapsReserve);
    final totalFundsHo = rows.fold(0.0, (s, r) => s + r.fundsReceivedHo);
    final totalFundsBranch = rows.fold(0.0, (s, r) => s + r.fundsReceivedOtherBranch);
    final totalFundsArea = rows.fold(0.0, (s, r) => s + r.fundsReceivedOtherArea);
    final totalAssetCredit = rows.fold(0.0, (s, r) => s + r.assetCreditSales);
    final totalCashAndCarry = rows.fold(0.0, (s, r) => s + r.cashAndCarry);
    final totalLoanRecAsset = rows.fold(0.0, (s, r) => s + r.loanReceivedAsset);
    final totalLoanRecFinance = rows.fold(0.0, (s, r) => s + r.loanReceivedFinance);
    final totalDaily11 = rows.fold(0.0, (s, r) => s + r.daily11Pct);
    final totalDaily20 = rows.fold(0.0, (s, r) => s + r.daily20Pct);
    final totalWeekly11 = rows.fold(0.0, (s, r) => s + r.weekly11Pct);
    final totalWeekly20 = rows.fold(0.0, (s, r) => s + r.weekly20Pct);
    final totalRiskPremium = rows.fold(0.0, (s, r) => s + r.riskPremiumReturns);
    final totalContingency = rows.fold(0.0, (s, r) => s + r.contingency);
    final totalFormDamage = rows.fold(0.0, (s, r) => s + r.creditFormDamage);
    final totalBonus = rows.fold(0.0, (s, r) => s + r.bonus);
    final totalAppFee = rows.fold(0.0, (s, r) => s + r.appFee);
    final totalPassbook = rows.fold(0.0, (s, r) => s + r.passbook);
    final totalBankWithdr = rows.fold(0.0, (s, r) => s + r.bankWithdrawal);
    final totalAdjIn = rows.fold(0.0, (s, r) => s + r.adjustmentIn);
    final totalInflows = monthOpening + rows.fold(0.0, (s, r) => s + (r.totalInflows - r.openingBalance));
    final totalDisb60d = rows.fold(0.0, (s, r) => s + r.disb60d);
    final totalDisb120d = rows.fold(0.0, (s, r) => s + r.disb120d);
    final totalDisb12w = rows.fold(0.0, (s, r) => s + r.disb12w);
    final totalDisb24w = rows.fold(0.0, (s, r) => s + r.disb24w);
    final totalDisbMth = rows.fold(0.0, (s, r) => s + r.disbMth);
    final totalXferBranch = rows.fold(0.0, (s, r) => s + r.fundTransferredOtherBranch);
    final totalXferHo = rows.fold(0.0, (s, r) => s + r.fundTransferredHo);
    final totalXferArea = rows.fold(0.0, (s, r) => s + r.fundToOtherArea);
    final totalToAssets = rows.fold(0.0, (s, r) => s + r.fundToAssetProgram);
    final totalToFinance = rows.fold(0.0, (s, r) => s + r.fundToProductFinance);
    final totalProdWithdr = rows.fold(0.0, (s, r) => s + r.productWithdrawal);
    final totalSalaries = rows.fold(0.0, (s, r) => s + r.staffSalaries);
    final totalOfficeExp = rows.fold(0.0, (s, r) => s + r.officeExpenses);
    final totalLapsRet = rows.fold(0.0, (s, r) => s + r.lapsReturns);
    final totalBankDep = rows.fold(0.0, (s, r) => s + r.bankDeposit);
    final totalAdjOut = rows.fold(0.0, (s, r) => s + r.adjustmentOut);
    final totalOutflows = rows.fold(0.0, (s, r) => s + r.totalOutflows);

    final totalAssetReceipts = totalLoanRecAsset + totalCashAndCarry;
    final assetVariance = totalAssetReceipts - totalToAssets;
    final isAssetSettled = assetVariance.abs() < 0.01;
    final headerStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.textPrimary);
    final cellStyle = TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textPrimary);
    final totalStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: tokens.textPrimary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.swipe_outlined, size: 14, color: tokens.textMuted),
                const SizedBox(width: 4),
                Text('Scroll horizontally to view all columns', style: TextStyle(fontSize: 11, color: tokens.textMuted, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
              columns: [
                DataColumn(label: Text('Date', style: headerStyle)),
                DataColumn(label: Text('Opening Balance', style: headerStyle)),
                DataColumn(label: Text('Savings Deposit', style: headerStyle)),
                DataColumn(label: Text('Repay (60d)', style: headerStyle)),
                DataColumn(label: Text('Repay (120d)', style: headerStyle)),
                DataColumn(label: Text('Repay (12w)', style: headerStyle)),
                DataColumn(label: Text('Repay (24w)', style: headerStyle)),
                DataColumn(label: Text('Repay (Mth)', style: headerStyle)),
                DataColumn(label: Text('Laps Reserve', style: headerStyle)),
                DataColumn(label: Text('Funds from HO', style: headerStyle)),
                DataColumn(label: Text('Funds from Branch', style: headerStyle)),
                DataColumn(label: Text('Funds from Area', style: headerStyle)),
                DataColumn(label: Text('Asset Credit', style: headerStyle)),
                DataColumn(label: Text('Cash & Carry', style: headerStyle)),
                DataColumn(label: Text('Funds from Asset', style: headerStyle)),
                DataColumn(label: Text('Loan Finance', style: headerStyle)),
                DataColumn(label: Text('Daily 11%', style: headerStyle)),
                DataColumn(label: Text('Daily 20%', style: headerStyle)),
                DataColumn(label: Text('Weekly 11%', style: headerStyle)),
                DataColumn(label: Text('Weekly 20%', style: headerStyle)),
                DataColumn(label: Text('Risk Premium', style: headerStyle)),
                DataColumn(label: Text('Contingency', style: headerStyle)),
                DataColumn(label: Text('Form Damage', style: headerStyle)),
                DataColumn(label: Text('Bonus', style: headerStyle)),
                DataColumn(label: Text('App Fee', style: headerStyle)),
                DataColumn(label: Text('Passbook', style: headerStyle)),
                DataColumn(label: Text('Bank Withdr.', style: headerStyle)),
                DataColumn(label: Text('Adjustment In', style: headerStyle)),
                DataColumn(label: Text('Total Inflows', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: tokens.successText))),
                // Outflows
                DataColumn(label: Text('Disb 60d', style: headerStyle)),
                DataColumn(label: Text('Disb 120d', style: headerStyle)),
                DataColumn(label: Text('Disb 12w', style: headerStyle)),
                DataColumn(label: Text('Disb 24w', style: headerStyle)),
                DataColumn(label: Text('Disb Mth', style: headerStyle)),
                DataColumn(label: Text('Xfer Branch', style: headerStyle)),
                DataColumn(label: Text('Xfer HO', style: headerStyle)),
                DataColumn(label: Text('Xfer Area', style: headerStyle)),
                DataColumn(label: Text('To Assets', style: headerStyle)),
                DataColumn(label: Text('To Finance', style: headerStyle)),
                DataColumn(label: Text('Prod/Sav Withdr.', style: headerStyle)),
                DataColumn(label: Text('Staff Salaries', style: headerStyle)),
                DataColumn(label: Text('Office Expenses', style: headerStyle)),
                DataColumn(label: Text('Laps Return', style: headerStyle)),
                DataColumn(label: Text('Bank Deposit', style: headerStyle)),
                DataColumn(label: Text('Adjustment Out', style: headerStyle)),
                DataColumn(label: Text('Total Outflows', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: tokens.dangerText))),
                DataColumn(label: Text('Closing Balance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: tokens.textPrimary))),
              ],
              rows: [
                ...rows.map((r) {
                  return DataRow(
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      final idx = rows.indexOf(r);
                      if (idx.isOdd) return tokens.surfaceSubtle;
                      return tokens.surface;
                    }),
                    cells: [
                      DataCell(Text(r.date, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: tokens.textPrimary))),
                      DataCell(Text(_formatLedgerCell(r.openingBalance), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.savingsDeposit), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.repDaily), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.rep120Days), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.rep12Weeks), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.rep24Weeks), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.repMonthly), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.lapsReserve), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.fundsReceivedHo), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.fundsReceivedOtherBranch), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.fundsReceivedOtherArea), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.assetCreditSales), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.cashAndCarry), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.loanReceivedAsset), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.loanReceivedFinance), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.daily11Pct), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.daily20Pct), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.weekly11Pct), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.weekly20Pct), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.riskPremiumReturns), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.contingency), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.creditFormDamage), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.bonus), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.appFee), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.passbook), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.bankWithdrawal), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.adjustmentIn), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.totalInflows), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.successText, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.disb60d), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.disb120d), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.disb12w), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.disb24w), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.disbMth), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.fundTransferredOtherBranch), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.fundTransferredHo), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.fundToOtherArea), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.fundToAssetProgram), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.fundToProductFinance), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.productWithdrawal), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.staffSalaries), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.officeExpenses), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.lapsReturns), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.bankDeposit), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.adjustmentOut), style: cellStyle)),
                      DataCell(Text(_formatLedgerCell(r.totalOutflows), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.dangerText, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.closingBalance), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tokens.textPrimary, fontFamily: 'monospace'))),
                    ],
                  );
                }),
                // Total Summary Row
                DataRow(
                  color: WidgetStateProperty.all(tokens.neutralBg),
                  cells: [
                    DataCell(Text('MONTH TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tokens.textPrimary))),
                    DataCell(Text(_formatLedgerCell(monthOpening), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalSavings), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalRepDaily), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalRep120), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalRep12w), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalRep24w), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalRepMth), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalLapsReserve), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalFundsHo), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalFundsBranch), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalFundsArea), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalAssetCredit), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalCashAndCarry), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalLoanRecAsset), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalLoanRecFinance), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalDaily11), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalDaily20), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalWeekly11), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalWeekly20), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalRiskPremium), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalContingency), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalFormDamage), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalBonus), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalAppFee), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalPassbook), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalBankWithdr), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalAdjIn), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalInflows), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: tokens.successText, fontFamily: 'monospace'))),
                    DataCell(Text(_formatLedgerCell(totalDisb60d), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalDisb120d), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalDisb12w), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalDisb24w), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalDisbMth), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalXferBranch), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalXferHo), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalXferArea), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalToAssets), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalToFinance), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalProdWithdr), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalSalaries), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalOfficeExp), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalLapsRet), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalBankDep), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalAdjOut), style: totalStyle)),
                    DataCell(Text(_formatLedgerCell(totalOutflows), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: tokens.dangerText, fontFamily: 'monospace'))),
                    DataCell(Text(_formatLedgerCell(monthClosing), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: tokens.textPrimary, fontFamily: 'monospace'))),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isAssetSettled ? tokens.successBg : tokens.warningBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isAssetSettled ? tokens.successBorder : tokens.warningBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          isAssetSettled ? Icons.check_circle_outline : Icons.pending_actions_outlined,
                          size: 18,
                          color: isAssetSettled ? tokens.successDot : tokens.warningDot,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isAssetSettled
                                ? 'Month-End Asset Program Settled'
                                : 'Month-End Asset Program Settlement Variance',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isAssetSettled ? tokens.successText : tokens.warningText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tokens.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isAssetSettled ? tokens.successBorder : tokens.warningBorder),
                    ),
                    child: Text(
                      isAssetSettled
                          ? 'Balanced'
                          : 'Variance: ${_formatCurrency(assetVariance)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: isAssetSettled ? tokens.successText : tokens.warningText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  Text(
                    'Funds from Asset: ${_formatCurrency(totalLoanRecAsset)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                  ),
                  Text(
                    'Cash & Carry: ${_formatCurrency(totalCashAndCarry)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                  ),
                  Text(
                    'Total Asset Receipts: ${_formatCurrency(totalAssetReceipts)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.successText),
                  ),
                  Text(
                    'Fund to Asset Program: ${_formatCurrency(totalToAssets)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.dangerText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SHARED FORM / METRIC HELPERS
  // ==========================================

  Widget _buildMetricCard({
    required double width,
    required String label,
    required String value,
    IconData? icon,
    Color? iconColor,
    Color? iconBg,
    String? delta,
    bool isDeltaInverse = false,
    Color? valueColor,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.14 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
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
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: iconBg ?? tokens.surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(icon, size: 14, color: iconColor ?? tokens.textSecondary),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (delta != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDeltaInverse ? tokens.dangerBg : tokens.successBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDeltaInverse ? tokens.dangerBorder : tokens.successBorder),
                  ),
                  child: Text(
                    delta,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDeltaInverse ? tokens.dangerText : tokens.successText,
                    ),
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
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: valueColor ?? tokens.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInputField(String label, TextEditingController ctrl) {
    final tokens = IcareSurfaceTokens.of(context);
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: tokens.textMuted),
        prefixIcon: Container(
          padding: const EdgeInsets.only(left: 12, right: 8),
          alignment: Alignment.centerLeft,
          width: 32,
          child: Text('₦', style: TextStyle(fontWeight: FontWeight.w700, color: tokens.textSecondary, fontSize: 13)),
        ),
        filled: true,
        fillColor: tokens.surfaceSubtle,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderSubtle)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.brandPrimary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: tokens.textPrimary),
    );
  }

  Widget _buildTextInputField(String label, TextEditingController ctrl, {String? placeholder}) {
    final tokens = IcareSurfaceTokens.of(context);
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: tokens.textMuted),
        hintText: placeholder,
        hintStyle: TextStyle(fontSize: 12, color: tokens.textMuted),
        filled: true,
        fillColor: tokens.surfaceSubtle,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderSubtle)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.brandPrimary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: TextStyle(fontSize: 13, color: tokens.textPrimary),
    );
  }
}
