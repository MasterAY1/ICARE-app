// ignore_for_file: deprecated_member_use, unnecessary_const
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/datasources/master_cashbook_api_service.dart';
import '../data/models/master_cashbook_models.dart';
import '../../shared/utils/file_download_helper.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';

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

  final api = ref.watch(masterCashbookApiServiceProvider);
  return api.getCoAggregation(date: date, officer: officer);
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

  // Tab 1 state
  DateTime _selectedDateTab1 = DateTime.now();
  final TextEditingController _fundsHoCtrl = TextEditingController();
  final TextEditingController _fundsBranchCtrl = TextEditingController();
  final TextEditingController _fundsAreaCtrl = TextEditingController();
  final TextEditingController _xferBranchCtrl = TextEditingController();
  final TextEditingController _xferHoCtrl = TextEditingController();
  final TextEditingController _xferAreaCtrl = TextEditingController();
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
  Color _bannerColor = const Color(0xFF065F46);
  Color _bannerBg = const Color(0xFFECFDF5);
  IconData _bannerIcon = Icons.check_circle_outline;

  bool _isSubmittingManual = false;
  bool _isSubmittingReversal = false;
  bool _isExecutingEod = false;
  bool _isDownloadingExcel = false;
  String? _lastLoadedTab1Key;

  @override
  void initState() {
    super.initState();
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
    _salariesCtrl.dispose();
    _adjInCtrl.dispose();
    _adjOutCtrl.dispose();
    _adjReasonCtrl.dispose();
    _treasuryRevReasonCtrl.dispose();
    super.dispose();
  }

  void _showBanner(String message, Color color, Color bg, IconData icon) {
    if (!mounted) return;
    setState(() {
      _bannerMessage = message;
      _bannerColor = color;
      _bannerBg = bg;
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
      _showBanner('Downloaded $fileName successfully', const Color(0xFF065F46), const Color(0xFFECFDF5), Icons.check_circle_outline);
    } catch (e) {
      _showBanner('Failed to download Excel ledger: $e', const Color(0xFFDC2626), const Color(0xFFFEF2F2), Icons.error_outline);
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
        const Color(0xFFDC2626),
        const Color(0xFFFEF2F2),
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
        'staff_salaries': double.tryParse(_salariesCtrl.text.trim()) ?? 0.0,
        'adjustment_in': double.tryParse(_adjInCtrl.text.trim()) ?? 0.0,
        'adjustment_out': double.tryParse(_adjOutCtrl.text.trim()) ?? 0.0,
        'adjustment_reason': _adjReasonCtrl.text.trim(),
      };

      final res = await api.saveManualEntries(payload);
      _showBanner(
        res['message'] ?? 'Master Cashbook manual entries saved and projection rebuilt.',
        const Color(0xFF065F46),
        const Color(0xFFECFDF5),
        Icons.check_circle_outline,
      );
      ref.invalidate(masterDailyCashbookProvider('${_formatDate(_selectedDateTab1)}||'));
    } catch (e) {
      _showBanner(
        'Failed to save manual entries: $e',
        const Color(0xFFDC2626),
        const Color(0xFFFEF2F2),
        Icons.error_outline,
      );
    } finally {
      setState(() => _isSubmittingManual = false);
    }
  }

  Future<void> _handleApproveReversal(String requestId) async {
    try {
      final api = ref.read(masterCashbookApiServiceProvider);
      final res = await api.approveReversal(requestId);
      _showBanner(
        res['message'] ?? 'Reversal approved and executed atomically!',
        const Color(0xFF065F46),
        const Color(0xFFECFDF5),
        Icons.check_circle_outline,
      );
      ref.invalidate(masterDailyCashbookProvider('${_formatDate(_selectedDateTab1)}||'));
    } catch (e) {
      _showBanner(
        'Approval failed: $e',
        const Color(0xFFDC2626),
        const Color(0xFFFEF2F2),
        Icons.error_outline,
      );
    }
  }

  Future<void> _handleRejectReversal(String requestId) async {
    try {
      final api = ref.read(masterCashbookApiServiceProvider);
      final res = await api.rejectReversal(requestId);
      _showBanner(
        res['message'] ?? 'Reversal rejected.',
        const Color(0xFF1E40AF),
        const Color(0xFFEFF6FF),
        Icons.info_outline,
      );
      ref.invalidate(masterDailyCashbookProvider('${_formatDate(_selectedDateTab1)}||'));
    } catch (e) {
      _showBanner(
        'Rejection failed: $e',
        const Color(0xFFDC2626),
        const Color(0xFFFEF2F2),
        Icons.error_outline,
      );
    }
  }

  Future<void> _handleFlagTreasuryReversal() async {
    if (_selectedTreasuryTxId == null || _selectedTreasuryTxId!.isEmpty) {
      _showBanner('Please select a Treasury Entry to flag.', const Color(0xFFD97706), const Color(0xFFFEF3C7), Icons.warning_amber);
      return;
    }
    final reason = _treasuryRevReasonCtrl.text.trim();
    if (reason.isEmpty) {
      _showBanner('Please provide a reason for the reversal.', const Color(0xFFD97706), const Color(0xFFFEF3C7), Icons.warning_amber);
      return;
    }

    setState(() => _isSubmittingReversal = true);
    try {
      final api = ref.read(masterCashbookApiServiceProvider);
      final res = await api.flagTreasuryReversal(_selectedTreasuryTxId!, reason);
      _showBanner(
        res['message'] ?? 'Treasury reversal request submitted!',
        const Color(0xFF065F46),
        const Color(0xFFECFDF5),
        Icons.check_circle_outline,
      );
      _treasuryRevReasonCtrl.clear();
      setState(() => _selectedTreasuryTxId = null);
      ref.invalidate(masterDailyCashbookProvider('${_formatDate(_selectedDateTab1)}||'));
    } catch (e) {
      _showBanner(
        'Failed to submit request: $e',
        const Color(0xFFDC2626),
        const Color(0xFFFEF2F2),
        Icons.error_outline,
      );
    } finally {
      setState(() => _isSubmittingReversal = false);
    }
  }

  // ==========================================
  // TAB 2 ACTIONS
  // ==========================================

  Future<void> _handleExecuteEod(String dateStr) async {
    setState(() => _isExecutingEod = true);
    try {
      final api = ref.read(masterCashbookApiServiceProvider);
      final res = await api.executeEodClose(dateStr);
      _showBanner(
        res['message'] ?? 'Successfully executed Day Close! Operational date advanced.',
        const Color(0xFF065F46),
        const Color(0xFFECFDF5),
        Icons.check_circle_outline,
      );
      ref.invalidate(coAggregationProvider('${_formatDate(_selectedDateTab2)}||${_selectedOfficerTab2 ?? ""}'));
      ref.invalidate(masterDailyCashbookProvider('${_formatDate(_selectedDateTab1)}||'));
    } catch (e) {
      _showBanner(
        'EOD Day Close failed: $e',
        const Color(0xFFDC2626),
        const Color(0xFFFEF2F2),
        Icons.error_outline,
      );
    } finally {
      setState(() => _isExecutingEod = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    'Branch Manager Master Cashbook',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 25,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Branch Treasury & Vault Cashbook',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
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
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF059669)),
                    SizedBox(width: 5),
                    Text(
                      'Account 1000 Vault Truth',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bannerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bannerColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(_bannerIcon, size: 20, color: _bannerColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _bannerMessage!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _bannerColor,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: _bannerColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _bannerMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTabs() {
    final tabs = [
      (0, 'Daily Cashbook Entry', Icons.account_balance_wallet_outlined),
      (1, 'CO Cashbooks Aggregation', Icons.groups_outlined),
      (2, 'Monthly Ledger', Icons.calendar_month_outlined),
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
                  color: isSelected ? const Color(0xFF064E3B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF064E3B) : const Color(0xFFCBD5E1),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF064E3B).withValues(alpha: 0.22),
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
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF334155),
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
    final key = '${_formatDate(_selectedDateTab1)}||';
    final asyncDaily = ref.watch(masterDailyCashbookProvider(key));

    return asyncDaily.when(
      loading: () => const IcareTableSkeleton(rowCount: 8, hasFilterBar: false),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
        child: Text('Error loading Master Cashbook: $err', style: const TextStyle(color: Color(0xFFDC2626))),
      ),
      data: (data) {
        if (_lastLoadedTab1Key != key) {
          _lastLoadedTab1Key = key;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _populateManualControllers(data);
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTab1ControlBar(data, isMobile),
            const SizedBox(height: 16),
            if (isMobile) _buildTab1MobileSectionSelector(),
            if (!isMobile || _tab1MobileSection == 0 || _tab1MobileSection == 3) ...[
              if (data.tally != null) ...[
                _buildReconciliationTally(data.tally!, data.branch),
                const SizedBox(height: 20),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
              ],
              _buildDailyLedgerTAccount(data, isMobile),
              if (!isMobile || _tab1MobileSection == 3) ...[
                const SizedBox(height: 28),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 20),
              ],
            ],
            if (!isMobile || _tab1MobileSection == 1 || _tab1MobileSection == 3) ...[
              _buildBmManualInputsForm(data, isMobile),
              if (!isMobile || _tab1MobileSection == 3) ...[
                const SizedBox(height: 28),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 20),
              ],
            ],
            if (!isMobile || _tab1MobileSection == 2 || _tab1MobileSection == 3) ...[
              _buildErrorCorrectionHub(data, isMobile),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTab1ControlBar(MasterCashbookDailyData data, bool isMobile) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final curDate = DateTime(_selectedDateTab1.year, _selectedDateTab1.month, _selectedDateTab1.day);
    final isToday = curDate == today;
    final isYesterday = curDate == yesterday;

    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                icon: const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF0F172A)),
                label: Text(
                  DateFormat(isMobile ? 'EEE, dd MMM yyyy' : 'EEEE, dd MMMM yyyy').format(_selectedDateTab1),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
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
                    color: isToday ? const Color(0xFF064E3B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isToday ? const Color(0xFF064E3B) : const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                      color: isToday ? Colors.white : const Color(0xFF334155),
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
                    color: isYesterday ? const Color(0xFF064E3B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isYesterday ? const Color(0xFF064E3B) : const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    'Yesterday',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isYesterday ? FontWeight.w700 : FontWeight.w600,
                      color: isYesterday ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
              ),
              const Spacer(),

              // Operational Status Pill (Desktop/Tablet)
              if (!isMobile)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: data.isOpen ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: data.isOpen ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        data.isOpen ? Icons.lock_open_outlined : Icons.lock_outlined,
                        size: 13,
                        color: data.isOpen ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        data.isOpen ? 'Ledger Open' : 'Ledger Finalized',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: data.isOpen ? const Color(0xFF065F46) : const Color(0xFF92400E),
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
                color: data.openReason.toLowerCase().contains('closed') ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: data.openReason.toLowerCase().contains('closed') ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    data.openReason.toLowerCase().contains('closed') ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    size: 15,
                    color: data.openReason.toLowerCase().contains('closed') ? const Color(0xFF059669) : const Color(0xFFD97706),
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
                        color: data.openReason.toLowerCase().contains('closed') ? const Color(0xFF065F46) : const Color(0xFF92400E),
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
    final sections = [
      (0, 'Ledger', Icons.account_balance_wallet_outlined),
      (1, 'Manual', Icons.edit_note_outlined),
      (2, 'Reversals', Icons.assignment_return_outlined),
      (3, 'All', Icons.view_agenda_outlined),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      s.$3,
                      size: 14,
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
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
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Collection & Arrears Reconciliation Tally',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  '$branch Branch reconciliation',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                  iconColor: const Color(0xFF2563EB),
                  iconBg: const Color(0xFFEFF6FF),
                ),
                _buildMetricCard(
                  width: cardWidth,
                  label: 'Overdue Arrears',
                  value: _formatCurrency(tally.notPaidAmount),
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFDC2626),
                  iconBg: const Color(0xFFFEF2F2),
                  delta: tally.notPaidCount > 0 ? '${tally.notPaidCount} Not Paid' : '0 Arrears',
                  isDeltaInverse: true,
                ),
                _buildMetricCard(
                  width: cardWidth,
                  label: 'Physical Cash Collected',
                  value: _formatCurrency(tally.actualCashCollected),
                  icon: Icons.payments_outlined,
                  iconColor: const Color(0xFF059669),
                  iconBg: const Color(0xFFECFDF5),
                  delta: tally.excessAmount > 0 ? '+${_formatCurrency(tally.excessAmount)} Excess' : null,
                ),
                _buildMetricCard(
                  width: cardWidth,
                  label: 'Bank Deposited',
                  value: _formatCurrency(tally.bankDeposited),
                  icon: Icons.account_balance_outlined,
                  iconColor: const Color(0xFF0F766E),
                  iconBg: const Color(0xFFF0FDFA),
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
    final closing = tally.closingCashBalance;
    if (closing.abs() < 0.01) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reconciled: ₦0 net variance • Arrears: ${_formatCurrency(tally.notPaidAmount)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
              ),
            ),
          ],
        ),
      );
    } else if (closing > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Vault Cash: ${_formatCurrency(closing)} unbanked • Arrears: ${_formatCurrency(tally.notPaidAmount)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Excess Deposited: Surplus ${_formatCurrency(closing.abs())} banked',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildNonPayingClientsExpander(List<MasterNotPaidClientData> clients) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.people_outline, size: 16, color: Color(0xFFDC2626)),
        ),
        title: Text(
          'View Non-Paying Clients (${clients.length} Arrears Records)',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Client Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Expected Installment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Shortfall / Arrears', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              ],
              rows: clients.map((c) {
                return DataRow(cells: [
                  DataCell(Text(c.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  DataCell(Text(c.code, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                  DataCell(Text(_formatCurrency(c.expected), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                  DataCell(Text(_formatCurrency(c.shortfall), style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.isPartial ? const Color(0xFFFEF3C7) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        c.isPartial ? 'Partial Shortfall' : 'Marked NOT PAID (₦0)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.isPartial ? const Color(0xFF92400E) : const Color(0xFFDC2626)),
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
      ('Fund To Assets', out.fundToAssetProgram),
      ('Fund to Finance', out.fundToProductFinance),
      ('Product/Savings Withdrawal', out.productWithdrawal + out.savingsWithdrawal),
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
                  const Text(
                    'Daily Ledger (T-Account Sheet)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _tab1HideZeroRows ? '$totalActive active accounts' : 'All 42 accounts',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
                      color: const Color(0xFF334155),
                    ),
                    label: Text(
                      _tab1UseSpreadsheet ? 'T-Panels' : 'Spreadsheet',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () => setState(() => _tab1HideZeroRows = !_tab1HideZeroRows),
                  icon: Icon(
                    _tab1HideZeroRows ? Icons.visibility_outlined : Icons.filter_alt_outlined,
                    size: 14,
                    color: const Color(0xFF334155),
                  ),
                  label: Text(
                    _tab1HideZeroRows ? 'Show All' : 'Active Only',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    backgroundColor: Colors.white,
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
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        color: _tab1TAccountTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: _tab1TAccountTab == 0
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Both (T-Panels)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _tab1TAccountTab == 0 ? FontWeight.w700 : FontWeight.w500,
                          color: _tab1TAccountTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
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
                        color: _tab1TAccountTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: _tab1TAccountTab == 1
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Inflows (${_formatCurrency(data.totalInflows)})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _tab1TAccountTab == 1 ? FontWeight.w700 : FontWeight.w500,
                          color: _tab1TAccountTab == 1 ? const Color(0xFF059669) : const Color(0xFF64748B),
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
                        color: _tab1TAccountTab == 2 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: _tab1TAccountTab == 2
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Outflows (${_formatCurrency(data.totalOutflows)})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _tab1TAccountTab == 2 ? FontWeight.w700 : FontWeight.w500,
                          color: _tab1TAccountTab == 2 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
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
                  title: 'DEBIT (CASH INFLOWS)',
                  totalLabel: 'Total Inflows',
                  totalAmount: data.totalInflows,
                  headerColor: const Color(0xFF059669),
                  headerBg: const Color(0xFFECFDF5),
                  headerBorder: const Color(0xFFA7F3D0),
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
                  headerColor: const Color(0xFFDC2626),
                  headerBg: const Color(0xFFFFF1F2),
                  headerBorder: const Color(0xFFFECDD3),
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
            accentColor: const Color(0xFF059669),
            icon: Icons.south_west_rounded,
          )
        else if (isMobile && _tab1TAccountTab == 2)
          _buildSingleLedgerList(
            title: 'Daily Outflows (Credit)',
            items: displayedOutflows,
            totalLabel: 'Total Outflows',
            totalValue: data.totalOutflows,
            accentColor: const Color(0xFFDC2626),
            icon: Icons.north_east_rounded,
          )
        else if (isMobile && _tab1TAccountTab == 0) ...[
          _buildSingleLedgerList(
            title: 'Daily Inflows (Debit)',
            items: displayedInflows,
            totalLabel: 'Total Inflows',
            totalValue: data.totalInflows,
            accentColor: const Color(0xFF059669),
            icon: Icons.south_west_rounded,
          ),
          const SizedBox(height: 14),
          _buildSingleLedgerList(
            title: 'Daily Outflows (Credit)',
            items: displayedOutflows,
            totalLabel: 'Total Outflows',
            totalValue: data.totalOutflows,
            accentColor: const Color(0xFFDC2626),
            icon: Icons.north_east_rounded,
          ),
          const SizedBox(height: 14),
          _buildTAccountBalancingBar(data),
        ] else
          // Spreadsheet Data Table
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Inflows (Left / Debit)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Amount (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Outflows (Right / Credit)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Amount (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                ],
                rows: List.generate(maxLen, (idx) {
                  final infItem = idx < displayedInflows.length ? displayedInflows[idx] : ('', 0.0);
                  final outItem = idx < displayedOutflows.length ? displayedOutflows[idx] : ('', 0.0);

                  return DataRow(
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (idx.isOdd) return const Color(0xFFF8FAFC);
                      return Colors.white;
                    }),
                    cells: [
                      DataCell(Text(infItem.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                      DataCell(Text(infItem.$1.isNotEmpty ? _formatCurrency(infItem.$2) : '', style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
                      DataCell(Text(outItem.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                      DataCell(Text(outItem.$1.isNotEmpty ? _formatCurrency(outItem.$2) : '', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
                    ],
                  );
                }),
              ),
            ),
          ),
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
    return Container(
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
                    color: Colors.white,
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
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No active accounts recorded.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final item = items[idx];
                final isOpening = item.$1.contains('Opening');
                return Container(
                  color: isOpening ? const Color(0xFFF0FDF4) : (idx.isEven ? Colors.white : const Color(0xFFF8FAFC)),
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
                                decoration: BoxDecoration(color: const Color(0xFF065F46), borderRadius: BorderRadius.circular(3)),
                                child: const Text('OPEN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                item.$1,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isOpening ? FontWeight.w700 : FontWeight.w500,
                                  color: const Color(0xFF334155),
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
                          color: isCredit ? const Color(0xFFDC2626) : const Color(0xFF059669),
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
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(9), bottomRight: Radius.circular(9)),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
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
    final closing = data.closingBalance;
    final isPos = closing >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPos ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPos ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isPos ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                size: 20,
                color: isPos ? const Color(0xFF059669) : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPos ? 'VAULT POSITION BALANCED' : 'VAULT DEFICIT DETECTED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isPos ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    'Opening (${_formatCurrency(data.inflows.openingBalance)}) + Inflows (${_formatCurrency(data.totalInflows)}) - Outflows (${_formatCurrency(data.totalOutflows)})',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isPos ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Closing Balance', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              Text(
                _formatCurrency(closing),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isPos ? const Color(0xFF065F46) : const Color(0xFFDC2626),
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
  }) {
    return Container(
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(9), topRight: Radius.circular(9)),
              border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.2))),
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No active entries recorded.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
                            color: const Color(0xFF334155),
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
                          color: item.$2 > 0 ? (accentColor == const Color(0xFF059669) ? const Color(0xFF059669) : const Color(0xFFDC2626)) : const Color(0xFF94A3B8),
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
    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note_outlined, size: 20, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BM Manual Inputs & Transfers', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    Text('Head Office funding, inter-branch transfers, and expenses.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
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
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.south_west_rounded, size: 15, color: Color(0xFF059669)),
                    SizedBox(width: 6),
                    Text('Vault Funding Received (Inflows)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
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
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.north_east_rounded, size: 15, color: Color(0xFFDC2626)),
                    SizedBox(width: 6),
                    Text('Corporate Transfers & Outflows', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF9F1239))),
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
                  _buildNumberInputField('Staff Salaries', _salariesCtrl),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _buildNumberInputField('Fund Transferred to Branch Office', _xferBranchCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberInputField('Fund Transferred to H.O.', _xferHoCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberInputField('Fund Transferred to Other Areas', _xferAreaCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberInputField('Staff Salaries', _salariesCtrl)),
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
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: const Icon(Icons.tune_outlined, size: 18, color: Color(0xFF475569)),
              title: const Text(
                'Branch Treasury Adjustments & Debt Management',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              subtitle: const Text(
                'Record branch-level cash debts, borrowed vault floats, deficit settlements, or direct adjustments.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
          const Text('Daily Balancing Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
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
                    label: 'Opening Balance',
                    value: _formatCurrency(data.inflows.openingBalance),
                    icon: Icons.lock_clock_outlined,
                    iconColor: const Color(0xFF065F46),
                    iconBg: const Color(0xFFECFDF5),
                  ),
                  _buildMetricCard(
                    width: cardW,
                    label: 'Total Inflows (Debit)',
                    value: _formatCurrency(data.totalInflows),
                    icon: Icons.south_west_rounded,
                    iconColor: const Color(0xFF059669),
                    iconBg: const Color(0xFFECFDF5),
                  ),
                  _buildMetricCard(
                    width: cardW,
                    label: 'Total Outflows (Credit)',
                    value: _formatCurrency(data.totalOutflows),
                    icon: Icons.north_east_rounded,
                    iconColor: const Color(0xFFDC2626),
                    iconBg: const Color(0xFFFFF1F2),
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
                backgroundColor: const Color(0xFFFF4B4B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosingBalanceBanner(double closing) {
    final isPos = closing >= 0;
    final color = isPos ? const Color(0xFF065F46) : const Color(0xFFDC2626);
    final bg = isPos ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Branch Error Correction & Reversals Hub',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 2),
        const Text(
          'Pending reversal requests and branch corrections.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        const Text(
          'Pending Branch Reversal Requests',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 10),
        if (data.pendingReversals.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
            child: const Text('No pending reversal requests for this branch.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
          )
        else
          ...data.pendingReversals.map((r) => _buildPendingReversalCard(r, isMobile)),
        const SizedBox(height: 16),
        _buildFlagTreasuryExpander(data.treasuryTransactions),
      ],
    );
  }

  (IconData, Color, Color, Color, String) _getReversalTypeInfo(String recordType) {
    if (recordType.contains('Savings')) {
      return (Icons.savings_outlined, const Color(0xFF059669), const Color(0xFFECFDF5), const Color(0xFFA7F3D0), 'Savings Deposit');
    }
    if (recordType.contains('Fee')) {
      return (Icons.receipt_long_outlined, const Color(0xFFD97706), const Color(0xFFFEF3C7), const Color(0xFFFDE68A), 'EOD Fee');
    }
    if (recordType.contains('Expense')) {
      return (Icons.shopping_cart_outlined, const Color(0xFFE11D48), const Color(0xFFFFE4E6), const Color(0xFFFECDD3), 'Office Expense');
    }
    if (recordType.contains('Treasury')) {
      return (Icons.account_balance_outlined, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), const Color(0xFFDDD6FE), 'Treasury Transfer');
    }
    return (Icons.payments_outlined, const Color(0xFF2563EB), const Color(0xFFEFF6FF), const Color(0xFFBFDBFE), 'Loan Repayment');
  }

  Widget _buildPendingReversalCard(MasterPendingReversalData req, bool isMobile) {
    final typeInfo = _getReversalTypeInfo(req.recordType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        'Ref #${req.recordId.length > 8 ? req.recordId.substring(0, 8) : req.recordId}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_top_outlined, size: 11, color: Color(0xFF92400E)),
                    SizedBox(width: 4),
                    Text('Pending Approval', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'Requested by ${req.requestedByName}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              const SizedBox(width: 8),
              const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
              const SizedBox(width: 8),
              const Icon(Icons.access_time, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                req.createdAt.length > 16 ? req.createdAt.substring(0, 16).replaceAll('T', ' ') : req.createdAt,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_outlined, size: 15, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    req.reason,
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF334155)),
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
                onPressed: () => _handleRejectReversal(req.id),
                icon: const Icon(Icons.close, size: 14, color: Color(0xFF475569)),
                label: const Text('Reject', style: TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _handleApproveReversal(req.id),
                icon: const Icon(Icons.check, size: 14, color: Colors.white),
                label: const Text('Approve Reversal', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.flag_outlined, size: 16, color: Color(0xFFD97706)),
        ),
        title: const Text('Flag Branch Treasury Entry for Reversal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (transactions.isEmpty)
            const Text('No recent branch treasury transactions found.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
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
                  backgroundColor: const Color(0xFFFF4B4B),
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
    final key = '${_formatDate(_selectedDateTab2)}||${_selectedOfficerTab2 ?? ""}';
    final asyncCo = ref.watch(coAggregationProvider(key));

    return asyncCo.when(
      loading: () => const IcareTableSkeleton(rowCount: 8, hasFilterBar: false),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
        child: Text('Error loading CO Cashbook aggregation: $err', style: const TextStyle(color: Color(0xFFDC2626))),
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
                      iconColor: const Color(0xFF475569),
                      iconBg: const Color(0xFFF1F5F9),
                    ),
                    _buildMetricCard(
                      width: cardW,
                      label: 'Total Inflows',
                      value: _formatCurrency(data.totalInflows),
                      icon: Icons.south_west_rounded,
                      iconColor: const Color(0xFF059669),
                      iconBg: const Color(0xFFECFDF5),
                    ),
                    _buildMetricCard(
                      width: cardW,
                      label: 'Total Outflows',
                      value: _formatCurrency(data.totalOutflows),
                      icon: Icons.north_east_rounded,
                      iconColor: const Color(0xFFDC2626),
                      iconBg: const Color(0xFFFEF2F2),
                    ),
                    _buildMetricCard(
                      width: cardW,
                      label: 'Closing Balance',
                      value: _formatCurrency(data.closingBalance),
                      icon: Icons.savings_outlined,
                      iconColor: isPos ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      iconBg: isPos ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      valueColor: isPos ? const Color(0xFF065F46) : const Color(0xFFDC2626),
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
                      const Text(
                        'Credit Officer Daily Cashbook Ledger',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${data.officer.isNotEmpty ? data.officer : "All Officers"} • ${DateFormat("dd MMM yyyy").format(_selectedDateTab2)}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
                        color: const Color(0xFF334155),
                      ),
                      label: Text(
                        _tab2HideZeroRows ? 'Active Only' : 'Show All',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        backgroundColor: Colors.white,
                      ),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _tab2UseSpreadsheet = !_tab2UseSpreadsheet),
                        icon: Icon(
                          _tab2UseSpreadsheet ? Icons.view_agenda_outlined : Icons.table_chart_outlined,
                          size: 14,
                          color: const Color(0xFF334155),
                        ),
                        label: Text(
                          _tab2UseSpreadsheet ? 'T-Panels' : 'Spreadsheet',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          backgroundColor: Colors.white,
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
                  color: const Color(0xFFF1F5F9),
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
                            color: _tab2TAccountTab == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: _tab2TAccountTab == 0 ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)] : null,
                          ),
                          child: Text('Both', style: TextStyle(fontSize: 12, fontWeight: _tab2TAccountTab == 0 ? FontWeight.w700 : FontWeight.w500, color: _tab2TAccountTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B))),
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
                            color: _tab2TAccountTab == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: _tab2TAccountTab == 1 ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)] : null,
                          ),
                          child: Text('Inflows', style: TextStyle(fontSize: 12, fontWeight: _tab2TAccountTab == 1 ? FontWeight.w700 : FontWeight.w500, color: _tab2TAccountTab == 1 ? const Color(0xFF059669) : const Color(0xFF64748B))),
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
                            color: _tab2TAccountTab == 2 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: _tab2TAccountTab == 2 ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)] : null,
                          ),
                          child: Text('Outflows', style: TextStyle(fontSize: 12, fontWeight: _tab2TAccountTab == 2 ? FontWeight.w700 : FontWeight.w500, color: _tab2TAccountTab == 2 ? const Color(0xFFDC2626) : const Color(0xFF64748B))),
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
                  accentColor: const Color(0xFF059669),
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
                  accentColor: const Color(0xFFDC2626),
                  icon: Icons.north_east_rounded,
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
                      headerColor: const Color(0xFF065F46),
                      headerBg: const Color(0xFFF0FDF4),
                      headerBorder: const Color(0xFFA7F3D0),
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
                      headerColor: const Color(0xFF991B1B),
                      headerBg: const Color(0xFFFEF2F2),
                      headerBorder: const Color(0xFFFECACA),
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
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            _buildEodControls(data, isMobile),
          ],
        );
      },
    );
  }

  Widget _buildTab2ControlBar(CoAggregationData data, bool isMobile) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final curDate = DateTime(_selectedDateTab2.year, _selectedDateTab2.month, _selectedDateTab2.day);
    final isToday = curDate == today;
    final isYesterday = curDate == yesterday;
    final isClosed = !data.isOpen && data.openReason.toLowerCase().contains('closed');

    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  icon: const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF0F172A)),
                  label: Text(
                    DateFormat('EEE, dd MMM yyyy').format(_selectedDateTab2),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontSize: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
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
                      color: isToday ? const Color(0xFF064E3B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isToday ? const Color(0xFF064E3B) : const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                        color: isToday ? Colors.white : const Color(0xFF334155),
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
                      color: isYesterday ? const Color(0xFF064E3B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isYesterday ? const Color(0xFF064E3B) : const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      'Y\'day',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isYesterday ? FontWeight.w700 : FontWeight.w600,
                        color: isYesterday ? Colors.white : const Color(0xFF334155),
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedOfficerTab2 ?? (data.officers.isNotEmpty ? data.officers[0].username : null),
                          items: data.officers.map((o) {
                            return DropdownMenuItem<String>(
                              value: o.username,
                              child: Text(o.display, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
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
                        ? const Color(0xFFEFF6FF)
                        : (data.isOpen ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isClosed
                          ? const Color(0xFFBFDBFE)
                          : (data.isOpen ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
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
                            ? const Color(0xFF1E40AF)
                            : (data.isOpen ? const Color(0xFF059669) : const Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isClosed ? 'Day Closed' : (data.isOpen ? 'Ledger Open' : 'Ledger Frozen'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isClosed
                              ? const Color(0xFF1E40AF)
                              : (data.isOpen ? const Color(0xFF065F46) : const Color(0xFF92400E)),
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
                  icon: const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF0F172A)),
                  label: Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(_selectedDateTab2),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
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
                      color: isToday ? const Color(0xFF064E3B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isToday ? const Color(0xFF064E3B) : const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                        color: isToday ? Colors.white : const Color(0xFF334155),
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
                      color: isYesterday ? const Color(0xFF064E3B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isYesterday ? const Color(0xFF064E3B) : const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      'Yesterday',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isYesterday ? FontWeight.w700 : FontWeight.w600,
                        color: isYesterday ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
                if (data.officers.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  Container(
                    height: 24,
                    width: 1,
                    color: const Color(0xFFE2E8F0),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined, size: 15, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedOfficerTab2 ?? (data.officers.isNotEmpty ? data.officers[0].username : null),
                            items: data.officers.map((o) {
                              return DropdownMenuItem<String>(
                                value: o.username,
                                child: Text(o.display, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
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
                        ? const Color(0xFFEFF6FF)
                        : (data.isOpen ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isClosed
                          ? const Color(0xFFBFDBFE)
                          : (data.isOpen ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
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
                            ? const Color(0xFF1E40AF)
                            : (data.isOpen ? const Color(0xFF059669) : const Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isClosed ? 'Day Closed' : (data.isOpen ? 'Ledger Open' : 'Ledger Frozen'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isClosed
                              ? const Color(0xFF1E40AF)
                              : (data.isOpen ? const Color(0xFF065F46) : const Color(0xFF92400E)),
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
    final closing = data.closingBalance;
    final isPos = closing >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPos ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPos ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isPos ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                size: 20,
                color: isPos ? const Color(0xFF059669) : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPos ? 'CO LEDGER BALANCED' : 'CO DEFICIT DETECTED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isPos ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    'Opening (${_formatCurrency(data.openingBalance)}) + Inflows (${_formatCurrency(data.totalInflows)}) - Outflows (${_formatCurrency(data.totalOutflows)})',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isPos ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Closing Balance', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              Text(
                _formatCurrency(closing),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isPos ? const Color(0xFF065F46) : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoLedgerTable(CoAggregationData data, bool isMobile) {
    final inflowItems = data.inflows.entries.toList();
    final outflowItems = data.outflows.entries.toList();

    final activeInflows = inflowItems.where((e) => e.key.toLowerCase().contains('opening') || e.value.abs() > 0.001).toList();
    final activeOutflows = outflowItems.where((e) => e.value.abs() > 0.001).toList();

    final displayedInflows = _tab2HideZeroRows ? activeInflows : inflowItems;
    final displayedOutflows = _tab2HideZeroRows ? activeOutflows : outflowItems;
    final maxLen = displayedInflows.length > displayedOutflows.length ? displayedInflows.length : displayedOutflows.length;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz, size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 4),
                  Text('Scroll horizontally to view debit/credit columns', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          Scrollbar(
            thumbVisibility: isMobile,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Inflows (Left / Debit)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Amount (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Outflows (Right / Credit)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Amount (₦)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                ],
                rows: List.generate(maxLen, (idx) {
                  final inf = idx < displayedInflows.length ? displayedInflows[idx] : null;
                  final out = idx < displayedOutflows.length ? displayedOutflows[idx] : null;

                  return DataRow(
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (idx.isOdd) return const Color(0xFFF8FAFC);
                      return Colors.white;
                    }),
                    cells: [
                      DataCell(Text(inf?.key ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                      DataCell(Text(inf != null ? _formatCurrency(inf.value) : '', style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
                      DataCell(Text(out?.key ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                      DataCell(Text(out != null ? _formatCurrency(out.value) : '', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEodControls(CoAggregationData data, bool isMobile) {
    final dateStr = _formatDate(_selectedDateTab2);
    final isClosed = !data.isOpen && data.openReason.toLowerCase().contains('closed');

    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.security_outlined, size: 20, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Branch Manager End of Day (EOD) Operations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    Text('Daily ledger freeze & date rollover.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isClosed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF1E40AF), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Day Close Executed for $dateStr • Operational date advanced.',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
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
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outlined, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cannot execute Day Close (${data.openReason}).',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
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
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFF1E40AF)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Operational Date: $dateStr • Freezes daily entries and advances to Next Working Day.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isExecutingEod ? null : () => _confirmAndExecuteEod(dateStr),
                  icon: _isExecutingEod
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                  label: const Text('Execute EOD Day Close', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
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
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Color(0xFF1E40AF)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Operational Date: $dateStr • Freezes daily entries and advances to Next Working Day.',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isExecutingEod ? null : () => _confirmAndExecuteEod(dateStr),
                  icon: _isExecutingEod
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                  label: const Text('Execute EOD Day Close', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _confirmAndExecuteEod(String dateStr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text('Confirm EOD Day Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to execute End of Day (EOD) Close for operational date $dateStr?',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action is irreversible. All cashbook transactions for this date will be permanently sealed, and the operational date will advance to the next working day.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleExecuteEod(dateStr);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Confirm & Execute Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: MONTHLY LEDGER
  // ==========================================

  Widget _buildTab3MonthlyLedger(bool isMobile) {
    final key = '$_selectedMonth||$_selectedYear||${_selectedBranchTab3 ?? ""}';
    final asyncMonthly = ref.watch(monthlyLedgerProvider(key));

    return asyncMonthly.when(
      loading: () => const IcareTableSkeleton(rowCount: 8, hasFilterBar: false),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
        child: Text('Error loading Monthly Ledger: $err', style: const TextStyle(color: Color(0xFFDC2626))),
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF1E40AF), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Please select an operational branch to view the monthly ledger.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF1E40AF), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No ledger entries found for $currentBranch in ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth, 1))}.',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
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
                        iconColor: const Color(0xFF475569),
                        iconBg: const Color(0xFFF1F5F9),
                      ),
                      _buildMetricCard(
                        width: cardW,
                        label: 'Total Monthly Inflows',
                        value: _formatIntegerCurrency(data.totalMonthInflows),
                        icon: Icons.south_west_rounded,
                        iconColor: const Color(0xFF059669),
                        iconBg: const Color(0xFFECFDF5),
                      ),
                      _buildMetricCard(
                        width: cardW,
                        label: 'Total Monthly Outflows',
                        value: _formatIntegerCurrency(data.totalMonthOutflows),
                        icon: Icons.north_east_rounded,
                        iconColor: const Color(0xFFDC2626),
                        iconBg: const Color(0xFFFEF2F2),
                      ),
                      _buildMetricCard(
                        width: cardW,
                        label: 'Month-End Closing Balance',
                        value: _formatIntegerCurrency(data.monthClosing),
                        icon: Icons.account_balance_wallet_outlined,
                        iconColor: isPos ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        iconBg: isPos ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        valueColor: isPos ? const Color(0xFF065F46) : const Color(0xFFDC2626),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Icon(Icons.description_outlined, size: 20, color: Color(0xFF059669)),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Monthly Ledger Workbook Export',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Complete 42-column Account 1000 matrix (.xlsx)',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
                        backgroundColor: const Color(0xFF064E3B),
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
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _tab3DailyFeedView = !_tab3DailyFeedView),
                      icon: Icon(_tab3DailyFeedView ? Icons.table_chart_outlined : Icons.view_agenda_outlined, size: 14, color: const Color(0xFF334155)),
                      label: Text(
                        _tab3DailyFeedView ? 'Table View' : 'Card View',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        backgroundColor: Colors.white,
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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
    final monthSelector = DropdownButtonFormField<int>(
      value: _selectedMonth,
      decoration: InputDecoration(
        labelText: 'Month',
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        prefixIcon: const Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: List.generate(12, (index) {
        final m = index + 1;
        return DropdownMenuItem<int>(
          value: m,
          child: Text(DateFormat('MMMM').format(DateTime(2026, m, 1)), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        prefixIcon: const Icon(Icons.schedule_outlined, size: 18, color: Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
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
      decoration: InputDecoration(
        labelText: 'Operating Branch',
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        prefixIcon: const Icon(Icons.business_outlined, size: 18, color: Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabled: data.availableBranches.length > 1,
      ),
      items: data.availableBranches.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
      onChanged: data.availableBranches.length > 1
          ? (val) {
              if (val != null) setState(() => _selectedBranchTab3 = val);
            }
          : null,
    );

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_outlined, size: 18, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Ledger Parameters', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  Text('Historical Account 1000 cash flows review.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
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
    return Column(
      children: rows.map((r) {
        final netCash = r.totalInflows - r.totalOutflows;
        final isPos = netCash >= 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ExpansionTile(
            shape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                r.date.length >= 10 ? r.date.substring(5) : r.date,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155), fontFamily: 'monospace'),
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Close: ${_formatIntegerCurrency(r.closingBalance)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A), fontFamily: 'monospace'),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isPos ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isPos ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    '${isPos ? '+' : ''}${_formatIntegerCurrency(netCash)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: isPos ? const Color(0xFF065F46) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text('In: ${_formatIntegerCurrency(r.totalInflows)}', style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                  const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                  Text('Out: ${_formatIntegerCurrency(r.totalOutflows)}', style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                  const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                  Text('Open: ${_formatIntegerCurrency(r.openingBalance)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace')),
                ],
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            children: [
              const Divider(color: Color(0xFFF1F5F9)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Savings Deposits', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  Text(_formatIntegerCurrency(r.savingsDeposit), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Daily Collections (60d/120d)', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  Text(_formatIntegerCurrency(r.repDaily + r.rep120Days), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bank Deposits', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  Text(_formatIntegerCurrency(r.bankDeposit), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626), fontFamily: 'monospace')),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Active Loan Disbursements', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  Text(_formatIntegerCurrency(r.disb60d + r.disb120d + r.disb12w + r.disb24w + r.disbMth), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626), fontFamily: 'monospace')),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthlyLedgerTable(List<MonthlyLedgerRowData> rows, bool isMobile) {
    // Column Totals for Summary Row
    final totalSavings = rows.fold(0.0, (s, r) => s + r.savingsDeposit);
    final totalRepDaily = rows.fold(0.0, (s, r) => s + r.repDaily);
    final totalRep120 = rows.fold(0.0, (s, r) => s + r.rep120Days);
    final totalRep12w = rows.fold(0.0, (s, r) => s + r.rep12Weeks);
    final totalRep24w = rows.fold(0.0, (s, r) => s + r.rep24Weeks);
    final totalRepMth = rows.fold(0.0, (s, r) => s + r.repMonthly);
    final totalInflows = rows.fold(0.0, (s, r) => s + r.totalInflows);
    final totalDisb60d = rows.fold(0.0, (s, r) => s + r.disb60d);
    final totalDisb120d = rows.fold(0.0, (s, r) => s + r.disb120d);
    final totalDisb12w = rows.fold(0.0, (s, r) => s + r.disb12w);
    final totalDisb24w = rows.fold(0.0, (s, r) => s + r.disb24w);
    final totalDisbMth = rows.fold(0.0, (s, r) => s + r.disbMth);
    final totalBankDep = rows.fold(0.0, (s, r) => s + r.bankDeposit);
    final totalOutflows = rows.fold(0.0, (s, r) => s + r.totalOutflows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.swipe_outlined, size: 14, color: Color(0xFF64748B)),
                SizedBox(width: 4),
                Text('Scroll horizontally to view all columns', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        Container(
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columns: const [
                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Opening Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Savings Deposit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Repay (60d)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Repay (120d)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Repay (12w)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Repay (24w)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Repay (Mth)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Laps Reserve', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Funds from HO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Funds from Branch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Funds from Area', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Asset Credit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Cash & Carry', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Loan Finance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Daily 11%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Daily 20%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Weekly 11%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Weekly 20%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Risk Premium', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Contingency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Form Damage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Bonus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('App Fee', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Passbook', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Bank Withdr.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Adjustment In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Total Inflows', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Color(0xFF065F46)))),
                // Outflows
                DataColumn(label: Text('Disb 60d', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Disb 120d', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Disb 12w', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Disb 24w', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Disb Mth', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Xfer Branch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Xfer HO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Xfer Area', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('To Assets', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('To Finance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Prod/Sav Withdr.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Staff Salaries', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Office Expenses', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Laps Return', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Bank Deposit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Adjustment Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                DataColumn(label: Text('Total Outflows', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Color(0xFF991B1B)))),
                DataColumn(label: Text('Closing Balance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Color(0xFF0F172A)))),
              ],
              rows: [
                ...rows.map((r) {
                  return DataRow(
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      final idx = rows.indexOf(r);
                      if (idx.isOdd) return const Color(0xFFF8FAFC);
                      return Colors.white;
                    }),
                    cells: [
                      DataCell(Text(r.date, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.openingBalance), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.savingsDeposit), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.repDaily), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.rep120Days), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.rep12Weeks), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.rep24Weeks), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.repMonthly), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.lapsReserve), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.fundsReceivedHo), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.fundsReceivedOtherBranch), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.fundsReceivedOtherArea), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.assetCreditSales), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.cashAndCarry), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.loanReceivedFinance), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.daily11Pct), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.daily20Pct), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.weekly11Pct), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.weekly20Pct), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.riskPremiumReturns), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.contingency), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.creditFormDamage), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.bonus), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.appFee), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.passbook), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.bankWithdrawal), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.adjustmentIn), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.totalInflows), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669), fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.disb60d), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.disb120d), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.disb12w), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.disb24w), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.disbMth), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.fundTransferredOtherBranch), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.fundTransferredHo), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.fundToOtherArea), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.fundToAssetProgram), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.fundToProductFinance), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.productWithdrawal), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.staffSalaries), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.officeExpenses), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.lapsReturns), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.bankDeposit), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.adjustmentOut), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.totalOutflows), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626), fontFamily: 'monospace'))),
                      DataCell(Text(_formatLedgerCell(r.closingBalance), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontFamily: 'monospace'))),
                    ],
                  );
                }),
                // Total Summary Row
                DataRow(
                  color: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                  cells: [
                    const DataCell(Text('MONTH TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    DataCell(Text(_formatLedgerCell(totalSavings), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                    DataCell(Text(_formatLedgerCell(totalRepDaily), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                    DataCell(Text(_formatLedgerCell(totalRep120), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                    DataCell(Text(_formatLedgerCell(totalRep12w), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                    DataCell(Text(_formatLedgerCell(totalRep24w), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                    DataCell(Text(_formatLedgerCell(totalRepMth), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    DataCell(Text(_formatLedgerCell(totalInflows), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF059669), fontFamily: 'monospace'))),
                    DataCell(Text(_formatLedgerCell(totalDisb60d), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                    DataCell(Text(_formatLedgerCell(totalDisb120d), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                    DataCell(Text(_formatLedgerCell(totalDisb12w), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                    DataCell(Text(_formatLedgerCell(totalDisb24w), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                    DataCell(Text(_formatLedgerCell(totalDisbMth), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    DataCell(Text(_formatLedgerCell(totalBankDep), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                    DataCell(Text(_formatLedgerCell(totalOutflows), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFDC2626), fontFamily: 'monospace'))),
                    const DataCell(Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                  ],
                ),
              ],
            ),
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
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                          color: iconBg ?? const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(icon, size: 14, color: iconColor ?? const Color(0xFF475569)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
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
                    color: isDeltaInverse ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDeltaInverse ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    delta,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDeltaInverse ? const Color(0xFFDC2626) : const Color(0xFF059669),
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
                color: valueColor ?? const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInputField(String label, TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        prefixIcon: Container(
          padding: const EdgeInsets.only(left: 12, right: 8),
          alignment: Alignment.centerLeft,
          width: 32,
          child: const Text('₦', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 13)),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
    );
  }

  Widget _buildTextInputField(String label, TextEditingController ctrl, {String? placeholder}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        hintText: placeholder,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}
