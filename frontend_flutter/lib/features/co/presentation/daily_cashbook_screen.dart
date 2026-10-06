import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/icare_card.dart';
import '../../../core/widgets/icare_section_header.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/datasources/co_api_service.dart';

/// Riverpod family provider using composite String key "$dateStr||$officer" to guarantee value equality and eliminate infinite refetches
final coCashbookDataProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, key) async {
  final parts = key.split('||');
  final dateStr = parts.isNotEmpty && parts[0] != 'null' && parts[0].isNotEmpty ? parts[0] : null;
  final officer = parts.length > 1 && parts[1] != 'null' && parts[1].isNotEmpty ? parts[1] : null;

  final api = ref.watch(coApiServiceProvider);
  return api.getCoCashbook(dateStr: dateStr, officer: officer);
});

/// 1:1 Streamlit Parity Replica of Credit Officer Daily Cashbook & Reconciliation (app.py L10748–11186)
/// Double-entry physical cashbook verified against Account 1000 Vault Cash.
/// Strict Zero-Emoji Governance (GEMINI Rule 10: SVG / Material Icons only).
class DailyCashbookScreen extends ConsumerStatefulWidget {
  const DailyCashbookScreen({super.key});

  @override
  ConsumerState<DailyCashbookScreen> createState() => _DailyCashbookScreenState();
}

class _DailyCashbookScreenState extends ConsumerState<DailyCashbookScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedOfficer;

  // Mobile Operational Hub Navigation
  int _mobileCashbookTab = 0; // 0: T-Ledger, 1: EOD Outflows & Fees, 2: Field Tally, 3: Reversals
  int _mobileNotPaidLimit = 10;
  int _mobileLedgerSubTab = 0; // 0: Inflows (Debit), 1: Outflows (Credit)
  bool _mobileShowAllLedgerItems = false;

  // EOD Form Controllers
  final TextEditingController _openingCtrl = TextEditingController();
  final TextEditingController _expensesCtrl = TextEditingController();
  final TextEditingController _bankDepCtrl = TextEditingController();
  final TextEditingController _appFeeCtrl = TextEditingController();
  final TextEditingController _passbookCtrl = TextEditingController();
  final TextEditingController _miscFeeCtrl = TextEditingController();
  final TextEditingController _cfdCtrl = TextEditingController();
  final TextEditingController _bonusCtrl = TextEditingController();

  // Reversal Hub Controllers
  String? _selectedRevOptionId;
  String? _selectedRevOptionType;
  final TextEditingController _revReasonCtrl = TextEditingController();

  // Feedback states
  String? _statusBannerText;
  Color _statusBannerColor = const Color(0xFF065F46);
  Color _statusBannerBg = const Color(0xFFECFDF5);
  IconData _statusBannerIcon = Icons.check_circle_outline;

  bool _isSubmittingEod = false;
  bool _isSubmittingReversal = false;
  String? _lastLoadedKey;

  @override
  void dispose() {
    _openingCtrl.dispose();
    _expensesCtrl.dispose();
    _bankDepCtrl.dispose();
    _appFeeCtrl.dispose();
    _passbookCtrl.dispose();
    _miscFeeCtrl.dispose();
    _cfdCtrl.dispose();
    _bonusCtrl.dispose();
    _revReasonCtrl.dispose();
    super.dispose();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _currentKey => '$_dateStr||${_selectedOfficer ?? ""}';

  void _populateEodControllers(Map<String, dynamic> data) {
    final inflows = (data['inflows'] as Map<String, dynamic>?) ?? {};
    final outflows = (data['outflows'] as Map<String, dynamic>?) ?? {};

    final op = (inflows['opening_balance'] ?? 0.0) as num;
    final exp = (outflows['office_expenses'] ?? 0.0) as num;
    final bdep = (outflows['bank_deposit'] ?? 0.0) as num;
    final app = (inflows['app_fee'] ?? 0.0) as num;
    final pb = (inflows['passbook'] ?? 0.0) as num;
    final misc = (inflows['risk_premium_returns'] ?? 0.0) as num;
    final cfd = (inflows['credit_form_damage'] ?? 0.0) as num;
    final bon = (inflows['bonus'] ?? 0.0) as num;

    _openingCtrl.text = op > 0 ? op.toStringAsFixed(0) : '';
    _expensesCtrl.text = exp > 0 ? exp.toStringAsFixed(0) : '';
    _bankDepCtrl.text = bdep > 0 ? bdep.toStringAsFixed(0) : '';
    _appFeeCtrl.text = app > 0 ? app.toStringAsFixed(0) : '';
    _passbookCtrl.text = pb > 0 ? pb.toStringAsFixed(0) : '';
    _miscFeeCtrl.text = misc > 0 ? misc.toStringAsFixed(0) : '';
    _cfdCtrl.text = cfd > 0 ? cfd.toStringAsFixed(0) : '';
    _bonusCtrl.text = bon > 0 ? bon.toStringAsFixed(0) : '';
  }

  Future<void> _handleSaveEod(bool isOpen, String openReason) async {
    if (!isOpen) {
      _showBanner(
        'Cannot update End of Day inputs today ($openReason).',
        const Color(0xFFDC2626),
        const Color(0xFFFEF2F2),
        Icons.error_outline,
      );
      return;
    }

    setState(() => _isSubmittingEod = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final payload = <String, dynamic>{
        'date': _dateStr,
        if (_selectedOfficer != null && _selectedOfficer!.isNotEmpty) 'officer': _selectedOfficer,
        if (_openingCtrl.text.trim().isNotEmpty) 'opening_balance': double.tryParse(_openingCtrl.text.trim()),
        if (_expensesCtrl.text.trim().isNotEmpty) 'office_expenses': double.tryParse(_expensesCtrl.text.trim()),
        if (_bankDepCtrl.text.trim().isNotEmpty) 'bank_deposit': double.tryParse(_bankDepCtrl.text.trim()),
        if (_appFeeCtrl.text.trim().isNotEmpty) 'app_fee': double.tryParse(_appFeeCtrl.text.trim()),
        if (_passbookCtrl.text.trim().isNotEmpty) 'passbook': double.tryParse(_passbookCtrl.text.trim()),
        if (_miscFeeCtrl.text.trim().isNotEmpty) 'misc_fee': double.tryParse(_miscFeeCtrl.text.trim()),
        if (_cfdCtrl.text.trim().isNotEmpty) 'credit_form_damage': double.tryParse(_cfdCtrl.text.trim()),
        if (_bonusCtrl.text.trim().isNotEmpty) 'bonus': double.tryParse(_bonusCtrl.text.trim()),
      };

      final res = await api.submitEodAdjustments(payload);
      _showBanner(
        res['message'] ?? 'End of Day Outflows & Fees Updated Successfully.',
        const Color(0xFF065F46),
        const Color(0xFFECFDF5),
        Icons.check_circle_outline,
      );
      ref.invalidate(coCashbookDataProvider(_currentKey));
    } catch (e) {
      _showBanner(
        'Error updating End of Day inputs: $e',
        const Color(0xFFDC2626),
        const Color(0xFFFEF2F2),
        Icons.error_outline,
      );
    } finally {
      setState(() => _isSubmittingEod = false);
    }
  }

  Future<void> _handleReversalRequest() async {
    final reason = _revReasonCtrl.text.trim();
    if (_selectedRevOptionId == null || _selectedRevOptionId!.isEmpty) {
      _showBanner(
        'Please select an EOD transaction to flag for reversal.',
        const Color(0xFFD97706),
        const Color(0xFFFFFBEB),
        Icons.warning_amber_rounded,
      );
      return;
    }
    if (reason.isEmpty) {
      _showBanner(
        'Please provide a valid reason for the reversal.',
        const Color(0xFFD97706),
        const Color(0xFFFFFBEB),
        Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() => _isSubmittingReversal = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final res = await api.requestCashbookReversal({
        'record_id': _selectedRevOptionId!,
        'record_type': _selectedRevOptionType ?? 'Cashbook',
        'reason': reason,
      });

      _showBanner(
        res['message'] ?? 'Cashbook reversal request submitted to BM.',
        const Color(0xFF065F46),
        const Color(0xFFECFDF5),
        Icons.check_circle_outline,
      );
      _revReasonCtrl.clear();
      setState(() {
        _selectedRevOptionId = null;
        _selectedRevOptionType = null;
      });
      ref.invalidate(coCashbookDataProvider(_currentKey));
    } catch (e) {
      _showBanner(
        'Failed to submit reversal request: $e',
        const Color(0xFFDC2626),
        const Color(0xFFFEF2F2),
        Icons.error_outline,
      );
    } finally {
      setState(() => _isSubmittingReversal = false);
    }
  }

  void _showBanner(String msg, Color textCol, Color bgCol, IconData icon) {
    setState(() {
      _statusBannerText = msg;
      _statusBannerColor = textCol;
      _statusBannerBg = bgCol;
      _statusBannerIcon = icon;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final cashbookAsync = ref.watch(coCashbookDataProvider(_currentKey));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Title & Subtitle (app.py L10749-10750)
        const IcareSectionHeader(
          title: 'Daily Cashbook',
          subtitle: 'Vault Cash Ledger (Account 1000)',
        ),
        const SizedBox(height: 14),

        // Status Notification Banner (if any feedback)
        if (_statusBannerText != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _statusBannerBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _statusBannerColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(_statusBannerIcon, color: _statusBannerColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusBannerText!,
                    style: TextStyle(
                      color: _statusBannerColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: _statusBannerColor),
                  onPressed: () => setState(() => _statusBannerText = null),
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],

        // Operational Header Controls (Date & Officer Selector, app.py L10756-10785)
        cashbookAsync.when(
          loading: () => const _LoadingSkeleton(),
          error: (err, _) => _buildErrorCard(err.toString()),
          data: (data) {
            // Check if key changed to pre-populate inputs
            if (_lastLoadedKey != _currentKey) {
              _lastLoadedKey = _currentKey;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _populateEodControllers(data);
              });
            }
            return _buildContent(context, data, user);
          },
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data, dynamic user) {
    final isOpen = data['is_open'] == true;
    final openReason = (data['open_reason'] ?? 'Working Day').toString();
    final canSelectOfficer = data['can_select_officer'] == true;
    final officers = (data['officers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final currentOfficer = (data['officer'] ?? user?.username ?? '').toString();
    final branchName = (data['branch'] ?? user?.branch ?? '').toString();

    final tally = data['tally'] as Map<String, dynamic>?;
    final inflows = (data['inflows'] as Map<String, dynamic>?) ?? {};
    final outflows = (data['outflows'] as Map<String, dynamic>?) ?? {};

    final totalInflows = (data['total_inflows'] ?? 0.0) as num;
    final totalOutflows = (data['total_outflows'] ?? 0.0) as num;
    final closingBalance = (data['closing_balance'] ?? 0.0) as num;
    final openingBalance = (inflows['opening_balance'] ?? 0.0) as num;

    final reversalOptions = (data['reversal_options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final submittedReversals = (data['submitted_reversals'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final isMobile = MediaQuery.of(context).size.width < 900;
    final notPaidCnt = (tally?['not_paid_count'] ?? 0) as int;

    final controlsBar = _buildControlsBar(
      context: context,
      isMobile: isMobile,
      canSelectOfficer: canSelectOfficer,
      officers: officers,
      currentOfficer: currentOfficer,
      branchName: branchName,
    );

    if (isMobile) {
      Widget mobileTabContent;
      switch (_mobileCashbookTab) {
        case 0:
          mobileTabContent = _buildMobileTAccountLedger(
            inflows,
            outflows,
            totalInflows,
            totalOutflows,
          );
          break;
        case 1:
          mobileTabContent = _buildEodForm(isOpen, openReason, isMobile: true);
          break;
        case 2:
          mobileTabContent = tally != null
              ? _buildArrearsTallySection(tally, currentOfficer, isMobile: true)
              : _buildInfoCard('No field tally data available for this date.');
          break;
        case 3:
        default:
          mobileTabContent = _buildCorrectionHub(
            reversalOptions,
            submittedReversals,
            isMobile: true,
          );
          break;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Mobile Controls Bar: Date Picker + Officer Selector
          controlsBar,
          const SizedBox(height: 12),

          // Operational Status Banner if Day is Closed or Suspended (app.py L10764-10766)
          if (!isOpen) ...[
            _buildSuspendedBanner(openReason),
            const SizedBox(height: 12),
          ],

          // 2. Executive Hero Card (Account 1000 Vault Cash in Custody)
          _buildMobileExecutiveCashbookHero(
            openingBalance: openingBalance,
            totalInflows: totalInflows,
            totalOutflows: totalOutflows,
            closingBalance: closingBalance,
            officerName: currentOfficer,
            branchName: branchName,
          ),
          const SizedBox(height: 14),

          // 3. Tactile 4-Pill Segmented Operational Hub Bar
          _buildMobileCashbookPills(
            selectedTab: _mobileCashbookTab,
            onSelect: (idx) => setState(() => _mobileCashbookTab = idx),
            arrearsCount: notPaidCnt,
            reversalsCount: submittedReversals.length,
          ),
          const SizedBox(height: 14),

          // 4. Active Tab Content
          mobileTabContent,
          const SizedBox(height: 28),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Controls Bar: Date Picker + Officer Selector
        controlsBar,
        const SizedBox(height: 14),

        // Operational Status Banner if Day is Closed or Suspended (app.py L10764-10766)
        if (!isOpen) ...[
          _buildSuspendedBanner(openReason),
          const SizedBox(height: 14),
        ],

        // 1. Summary KPI Metric Cards (Immediate Cash Position on Mobile)
        _buildSummaryKpiCards(openingBalance, totalInflows, totalOutflows, closingBalance),
        const SizedBox(height: 16),

        // 2. Balanced 2-Column T-Account Ledger Display (app.py L11020-11076)
        _buildTAccountLedger(inflows, outflows),
        const SizedBox(height: 20),

        // 2. Daily Field Collection & Arrears Reconciliation Tally (app.py L11005-11019)
        if (tally != null) ...[
          _buildArrearsTallySection(tally, currentOfficer, isMobile: false),
          const SizedBox(height: 20),
        ],

        // 3. End of Day / Global Outflows & Additional Collections Form (app.py L10874-11000)
        _buildEodForm(isOpen, openReason, isMobile: false),
        const SizedBox(height: 20),

        // 4. Cashbook Error Correction & Reversal Hub (app.py L11078-11185)
        _buildCorrectionHub(reversalOptions, submittedReversals, isMobile: false),
        const SizedBox(height: 32),
      ],
    );
  }

  // ==========================================
  // SHARED HEADER CONTROLS & BANNERS
  // ==========================================
  Widget _buildControlsBar({
    required BuildContext context,
    required bool isMobile,
    required bool canSelectOfficer,
    required List<Map<String, dynamic>> officers,
    required String currentOfficer,
    required String branchName,
  }) {
    final dateCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Date',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              setState(() => _selectedDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ],
    );

    final officerCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          canSelectOfficer ? 'Select Credit Officer' : 'Assigned Officer',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 6),
        if (canSelectOfficer && officers.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: officers.any((o) => o['username'] == (_selectedOfficer ?? currentOfficer))
                    ? (_selectedOfficer ?? currentOfficer)
                    : (officers.first['username'] as String),
                icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                items: officers.map((o) {
                  final u = o['username'] as String;
                  final disp = (o['display'] ?? u).toString();
                  return DropdownMenuItem<String>(
                    value: u,
                    child: Text(
                      disp,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedOfficer = val);
                  }
                },
              ),
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 15, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$currentOfficer • $branchName Branch',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return IcareCard(
      padding: const EdgeInsets.all(14),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dateCol,
                const SizedBox(height: 12),
                officerCol,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: dateCol),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: officerCol),
              ],
            ),
    );
  }

  Widget _buildSuspendedBanner(String openReason) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Operations Suspended ($openReason) — Read-Only mode.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MOBILE EXECUTIVE CASHBOOK HERO & TABS
  // ==========================================

  Widget _buildMobileExecutiveCashbookHero({
    required num openingBalance,
    required num totalInflows,
    required num totalOutflows,
    required num closingBalance,
    required String officerName,
    required String branchName,
  }) {
    final isReconciled = closingBalance.abs() < 0.01;
    final isPositive = closingBalance > 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF022C22),
            Color(0xFF064E3B),
            Color(0xFF065F46),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33064E3B),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ambient decorative circles
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x0AFFFFFF),
              ),
            ),
          ),
          Positioned(
            left: -15,
            top: -15,
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x0F8CC63F),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Account 1000 badge + Reconciliation status badge
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
                            color: Color(0xFF8CC63F),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'ACCOUNT 1000 · VAULT CASH',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFA7F3D0),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isReconciled
                            ? const Color(0x2610B981)
                            : (isPositive ? const Color(0x2638BDF8) : const Color(0x26F59E0B)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isReconciled
                              ? const Color(0x4010B981)
                              : (isPositive ? const Color(0x4038BDF8) : const Color(0x40F59E0B)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isReconciled
                                ? Icons.check_circle_outline
                                : (isPositive ? Icons.account_balance_wallet_outlined : Icons.warning_amber_rounded),
                            size: 12,
                            color: isReconciled
                                ? const Color(0xFFD1FAE5)
                                : (isPositive ? const Color(0xFFBAE6FD) : const Color(0xFFFDE68A)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isReconciled ? 'Reconciled (₦0)' : (isPositive ? 'Cash in Hand' : 'Over-Deposited'),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isReconciled
                                  ? const Color(0xFFD1FAE5)
                                  : (isPositive ? const Color(0xFFBAE6FD) : const Color(0xFFFDE68A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Cash in Custody Hero Number
                const Text(
                  'Physical Cash in Custody (Closing)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6EE7B7),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.formatNaira(closingBalance),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('dd MMM yyyy').format(_selectedDate)} · $officerName ($branchName)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFD1FAE5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // 3-Metric Bottom Bar: Opening, Inflows, Outflows
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x1A000000),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x1AFFFFFF)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildHeroMiniMetric(
                          label: 'OPENING',
                          value: CurrencyFormatter.formatNaira(openingBalance),
                          valueColor: const Color(0xFFBAE6FD),
                        ),
                      ),
                      Container(width: 1, height: 28, color: const Color(0x26FFFFFF)),
                      Expanded(
                        child: _buildHeroMiniMetric(
                          label: 'INFLOWS',
                          value: CurrencyFormatter.formatNaira(totalInflows),
                          valueColor: const Color(0xFF6EE7B7),
                        ),
                      ),
                      Container(width: 1, height: 28, color: const Color(0x26FFFFFF)),
                      Expanded(
                        child: _buildHeroMiniMetric(
                          label: 'OUTFLOWS',
                          value: CurrencyFormatter.formatNaira(totalOutflows),
                          valueColor: const Color(0xFFFCA5A5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMiniMetric({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFFA7F3D0),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCashbookPills({
    required int selectedTab,
    required Function(int) onSelect,
    int? arrearsCount,
    int? reversalsCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildCashbookPill(
              index: 0,
              currentIndex: selectedTab,
              label: 'T-Ledger',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => onSelect(0),
            ),
            const SizedBox(width: 4),
            _buildCashbookPill(
              index: 1,
              currentIndex: selectedTab,
              label: 'EOD Inputs',
              icon: Icons.tune_outlined,
              onTap: () => onSelect(1),
            ),
            const SizedBox(width: 4),
            _buildCashbookPill(
              index: 2,
              currentIndex: selectedTab,
              label: 'Field Tally',
              icon: Icons.summarize_outlined,
              badgeCount: arrearsCount,
              isAlertBadge: arrearsCount != null && arrearsCount > 0,
              onTap: () => onSelect(2),
            ),
            const SizedBox(width: 4),
            _buildCashbookPill(
              index: 3,
              currentIndex: selectedTab,
              label: 'Reversals',
              icon: Icons.history_outlined,
              badgeCount: reversalsCount,
              onTap: () => onSelect(3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashbookPill({
    required int index,
    required int currentIndex,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    int? badgeCount,
    bool isAlertBadge = false,
  }) {
    final isSelected = index == currentIndex;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFF065F46) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
              if (badgeCount != null && badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAlertBadge
                        ? const Color(0xFFFEE2E2)
                        : (isSelected ? const Color(0xFFECFDF5) : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isAlertBadge
                          ? const Color(0xFF991B1B)
                          : (isSelected ? const Color(0xFF065F46) : const Color(0xFF475569)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTAccountLedger(
    Map<String, dynamic> inflows,
    Map<String, dynamic> outflows,
    num totalInflows,
    num totalOutflows,
  ) {
    final inflowItems = [
      ('Opening Balance', (inflows['opening_balance'] ?? 0.0) as num),
      ('Savings Deposit', (inflows['savings_deposit'] ?? 0.0) as num),
      ('Credit Rep (Daily)', (inflows['rep_daily'] ?? 0.0) as num),
      ('Credit Rep (12 Weeks)', (inflows['rep_12_weeks'] ?? 0.0) as num),
      ('Credit Rep (24 Weeks)', (inflows['rep_24_weeks'] ?? 0.0) as num),
      ('Credit Rep (Monthly)', (inflows['rep_monthly'] ?? 0.0) as num),
      ('Laps Reserve', (inflows['laps_reserve'] ?? 0.0) as num),
      ('Asset Credit Sales', (inflows['asset_credit_sales'] ?? 0.0) as num),
      ('Cash & Carry', (inflows['cash_and_carry'] ?? 0.0) as num),
      ('Daily 11% Markup', (inflows['daily_11_pct'] ?? 0.0) as num),
      ('Weekly 11% Markup', (inflows['weekly_11_pct'] ?? 0.0) as num),
      ('Weekly 20% Markup', (inflows['weekly_20_pct'] ?? 0.0) as num),
      ('Monthly / 20% Markup', (inflows['risk_premium_returns'] ?? 0.0) as num),
      ('Contingency (1%)', (inflows['contingency'] ?? 0.0) as num),
      ('Credit Form / App Fee', (inflows['app_fee'] ?? 0.0) as num),
      ('Credit Form Damage', (inflows['credit_form_damage'] ?? 0.0) as num),
      ('Pass Book', (inflows['passbook'] ?? 0.0) as num),
      ('Bonus', (inflows['bonus'] ?? 0.0) as num),
      ('Bank Withdrawal', (inflows['bank_withdrawal'] ?? 0.0) as num),
    ];

    final outflowItems = [
      ('Active Loan (Daily)', (outflows['active_loan_daily'] ?? 0.0) as num),
      ('Active Loan (12 Weeks)', (outflows['active_loan_12w'] ?? 0.0) as num),
      ('Active Loan (24 Weeks)', (outflows['active_loan_24w'] ?? 0.0) as num),
      ('Active Loan (Monthly)', (outflows['active_loan_monthly'] ?? 0.0) as num),
      ('Product / Savings Withdrawal', (outflows['product_withdrawal'] ?? 0.0) as num),
      ('Office Expenses', (outflows['office_expenses'] ?? 0.0) as num),
      ('LAPS Returns / Payouts', (outflows['laps_returns'] ?? 0.0) as num),
      ('Bank Deposit', (outflows['bank_deposit'] ?? 0.0) as num),
    ];

    final isInflow = _mobileLedgerSubTab == 0;
    final activeInflows = inflowItems.where((i) => i.$2 > 0).length;
    final activeOutflows = outflowItems.where((i) => i.$2 > 0).length;
    final currentItems = isInflow ? inflowItems : outflowItems;
    final displayedItems = _mobileShowAllLedgerItems
        ? currentItems
        : currentItems.where((i) => i.$2 > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-tab switcher: Inflows (Debit) vs Outflows (Credit)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _mobileLedgerSubTab = 0),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isInflow ? const Color(0xFFECFDF5) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isInflow ? Border.all(color: const Color(0xFFA7F3D0)) : null,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Inflows (Debit)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isInflow ? FontWeight.w700 : FontWeight.w500,
                                color: isInflow ? const Color(0xFF065F46) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatNaira(totalInflows),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isInflow ? const Color(0xFF065F46) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _mobileLedgerSubTab = 1),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !isInflow ? const Color(0xFFFEF2F2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: !isInflow ? Border.all(color: const Color(0xFFFECACA)) : null,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Outflows (Credit)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: !isInflow ? FontWeight.w700 : FontWeight.w500,
                                color: !isInflow ? const Color(0xFF991B1B) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatNaira(totalOutflows),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: !isInflow ? const Color(0xFF991B1B) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Filter toggle row: Active non-zero vs All items
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isInflow ? 'Inflow Accounts' : 'Outflow Accounts',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
            InkWell(
              onTap: () => setState(() => _mobileShowAllLedgerItems = !_mobileShowAllLedgerItems),
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
                    Icon(
                      _mobileShowAllLedgerItems ? Icons.filter_list_off : Icons.filter_list,
                      size: 13,
                      color: const Color(0xFF475569),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _mobileShowAllLedgerItems
                          ? 'Showing All (${currentItems.length})'
                          : 'Active Only (${isInflow ? activeInflows : activeOutflows})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Items List Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: displayedItems.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.inbox_outlined, size: 28, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text(
                          'No ${isInflow ? "inflows" : "outflows"} recorded today.',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => setState(() => _mobileShowAllLedgerItems = true),
                          child: const Text('Show all accounts', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < displayedItems.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      _buildMobileLedgerItemRow(
                        displayedItems[i].$1,
                        displayedItems[i].$2,
                        isInflow: isInflow,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMobileLedgerItemRow(String name, num amount, {required bool isInflow}) {
    final isNonZero = amount > 0;
    final color = isNonZero
        ? (isInflow ? const Color(0xFF065F46) : const Color(0xFF991B1B))
        : const Color(0xFF94A3B8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isNonZero
            ? (isInflow ? const Color(0xFFF0FDF4).withValues(alpha: 0.3) : const Color(0xFFFEF2F2).withValues(alpha: 0.3))
            : Colors.transparent,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (isNonZero) ...[
                  Container(
                    width: 4,
                    height: 16,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isInflow ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isNonZero ? FontWeight.w600 : FontWeight.w400,
                      color: isNonZero ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatLedgerAmount(amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: isNonZero ? FontWeight.w800 : FontWeight.w500,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEodForm(bool isOpen, String openReason, {bool isMobile = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isMobile,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          title: const Row(
            children: [
              Icon(Icons.tune_outlined, size: 18, color: Color(0xFF0F172A)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'End of Day Outflows & Fees',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Record branch expenses, bank deposits, and fee collections.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Color(0xFFE2E8F0), height: 24),

                  // Responsive EOD Form Inputs
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 650;
                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildNumberField('Opening Balance (B/F Cash)', _openingCtrl, step: 500),
                            const SizedBox(height: 12),
                            _buildNumberField('Office Expenses', _expensesCtrl, step: 500),
                            const SizedBox(height: 12),
                            _buildNumberField('Bank Deposited', _bankDepCtrl, step: 500),
                            const SizedBox(height: 16),
                            const Text(
                              'Additional Collections & Fees',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 10),
                            _buildNumberField(
                              'Credit Form / App Fee',
                              _appFeeCtrl,
                              help: 'Unified Processing Fee and Credit Form fee',
                              step: 500,
                            ),
                            const SizedBox(height: 12),
                            _buildNumberField('Pass Book', _passbookCtrl, step: 500),
                            const SizedBox(height: 12),
                            _buildNumberField(
                              'Misc Fee',
                              _miscFeeCtrl,
                              help: 'Routed directly to Misc Savings pool',
                              step: 500,
                            ),
                            const SizedBox(height: 12),
                            _buildNumberField(
                              'Cr Form Dmg',
                              _cfdCtrl,
                              help: 'Fee for damaged credit forms',
                              step: 100,
                            ),
                            const SizedBox(height: 12),
                            _buildNumberField('Bonus', _bonusCtrl, step: 500),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Opening Balance, Expenses, Bank Deposited
                          Row(
                            children: [
                              Expanded(
                                child: _buildNumberField('Opening Balance (B/F Cash)', _openingCtrl, step: 500),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildNumberField('Office Expenses', _expensesCtrl, step: 500),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildNumberField('Bank Deposited', _bankDepCtrl, step: 500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Additional Collections Subheading (app.py L10887)
                          const Text(
                            'Additional Collections & Fees',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 10),

                          // Row 2: Credit Form / App Fee, Pass Book, Misc Fee
                          Row(
                            children: [
                              Expanded(
                                child: _buildNumberField(
                                  'Credit Form / App Fee',
                                  _appFeeCtrl,
                                  help: 'Unified Processing Fee and Credit Form fee',
                                  step: 500,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildNumberField('Pass Book', _passbookCtrl, step: 500),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildNumberField(
                                  'Misc Fee',
                                  _miscFeeCtrl,
                                  help: 'Routed directly to Misc Savings pool',
                                  step: 500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row 3: Cr Form Dmg, Bonus
                          Row(
                            children: [
                              Expanded(
                                child: _buildNumberField(
                                  'Cr Form Dmg',
                                  _cfdCtrl,
                                  help: 'Fee for damaged credit forms',
                                  step: 100,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildNumberField('Bonus', _bonusCtrl, step: 500),
                              ),
                              const Expanded(child: SizedBox()), // spacer to match 3 columns
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // Submit Action Button (app.py L10898)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: (_isSubmittingEod || !isOpen) ? null : () => _handleSaveEod(isOpen, openReason),
                      icon: _isSubmittingEod
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        _isSubmittingEod ? 'Saving & Posting to Ledger...' : 'Save End of Day Outflows & Fees',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF064E3B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        disabledBackgroundColor: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField(
    String label,
    TextEditingController ctrl, {
    String? help,
    double step = 500.0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            if (help != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: help,
                child: const Icon(Icons.help_outline, size: 13, color: Color(0xFF94A3B8)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: InputBorder.none,
              prefixText: '₦ ',
              prefixStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
              hintText: '0',
              hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ARREARS RECONCILIATION TALLY
  // ==========================================
  Widget _buildArrearsTallySection(Map<String, dynamic> tally, String officerName, {bool isMobile = false}) {
    final exp = (tally['scheduled_expected'] ?? 0.0) as num;
    final notPaid = (tally['not_paid_amount'] ?? 0.0) as num;
    final notPaidCnt = (tally['not_paid_count'] ?? 0) as int;
    final cashCol = (tally['actual_cash_collected'] ?? 0.0) as num;
    final excess = (tally['excess_amount'] ?? 0.0) as num;
    final bankDep = (tally['bank_deposited'] ?? 0.0) as num;
    final closing = (tally['closing_cash_balance'] ?? 0.0) as num;
    final notPaidList = (tally['not_paid_clients'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Subtitle (app.py L1088-1090)
          const Text(
            'Collections & Arrears Reconciliation',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          const Text(
            'Field collections vs bank deposits & arrears',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          // 4 Tally Metric Cards (app.py L1091-1104)
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              if (w < 600) {
                return Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildTallyKpi('Scheduled Inflows', CurrencyFormatter.formatNaira(exp), null, null),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTallyKpi(
                              'Overdue Arrears',
                              CurrencyFormatter.formatNaira(notPaid),
                              notPaidCnt > 0 ? '$notPaidCnt Not Paid' : '0 Arrears',
                              const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildTallyKpi(
                              'Physical Cash Collected',
                              CurrencyFormatter.formatNaira(cashCol),
                              excess > 0 ? '+${CurrencyFormatter.formatNaira(excess)} Excess' : null,
                              const Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTallyKpi('Bank Deposited', CurrencyFormatter.formatNaira(bankDep), null, null),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else if (w < 900) {
                return Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildTallyKpi('Scheduled Inflows', CurrencyFormatter.formatNaira(exp), null, null),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTallyKpi(
                              'Overdue Arrears',
                              CurrencyFormatter.formatNaira(notPaid),
                              notPaidCnt > 0 ? '$notPaidCnt Not Paid' : '0 Arrears',
                              const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildTallyKpi(
                              'Physical Cash Collected',
                              CurrencyFormatter.formatNaira(cashCol),
                              excess > 0 ? '+${CurrencyFormatter.formatNaira(excess)} Excess' : null,
                              const Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTallyKpi('Bank Deposited', CurrencyFormatter.formatNaira(bankDep), null, null),
                          ),
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
                    Expanded(
                      child: _buildTallyKpi('Scheduled Inflows', CurrencyFormatter.formatNaira(exp), null, null),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTallyKpi(
                        'Overdue Arrears',
                        CurrencyFormatter.formatNaira(notPaid),
                        notPaidCnt > 0 ? '$notPaidCnt Not Paid' : '0 Arrears',
                        const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTallyKpi(
                        'Physical Cash Collected',
                        CurrencyFormatter.formatNaira(cashCol),
                        excess > 0 ? '+${CurrencyFormatter.formatNaira(excess)} Excess' : null,
                        const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTallyKpi('Bank Deposited', CurrencyFormatter.formatNaira(bankDep), null, null),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Physical Cash Reconciliation Status Banner (app.py L1105-1111)
          if (closing.abs() < 0.01) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF065F46), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF065F46)),
                        children: [
                          const TextSpan(text: 'Physical Cash Reconciled: ', style: TextStyle(fontWeight: FontWeight.w700)),
                          const TextSpan(text: 'Balanced (₦0.00). '),
                          TextSpan(text: 'Arrears: ${CurrencyFormatter.formatNaira(notPaid)}.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (closing > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF0369A1), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF0369A1)),
                        children: [
                          const TextSpan(text: 'Cash in Vault: ', style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: '${CurrencyFormatter.formatNaira(closing)} remaining. '),
                          TextSpan(text: 'Arrears: ${CurrencyFormatter.formatNaira(notPaid)}.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
                        children: [
                          const TextSpan(text: 'Extra Cash Deposited: ', style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: 'Surplus deposit of ${CurrencyFormatter.formatNaira(closing.abs())}.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Non-Paying Clients Collapsible Table (app.py L1113-1126)
          if (notPaidList.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Theme(
                data: ThemeData(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: isMobile,
                  title: Text(
                    'Non-Paying Clients (${notPaidList.length})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 600),
                                child: Table(
                                  border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 1),
                                  columnWidths: const {
                                    0: FlexColumnWidth(2.5),
                                    1: FlexColumnWidth(1.5),
                                    2: FlexColumnWidth(1.8),
                                    3: FlexColumnWidth(1.8),
                                    4: FlexColumnWidth(2.2),
                                  },
                                  children: [
                                    const TableRow(
                                      decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                                      children: [
                                        _TableHeaderCell('Client Name'),
                                        _TableHeaderCell('Client Code'),
                                        _TableHeaderCell('Expected'),
                                        _TableHeaderCell('Shortfall'),
                                        _TableHeaderCell('Type'),
                                      ],
                                    ),
                                    ...(isMobile ? notPaidList.take(_mobileNotPaidLimit) : notPaidList).map((c) {
                                      final name = (c['name'] ?? '').toString();
                                      final code = (c['code'] ?? '').toString();
                                      final expVal = (c['expected'] ?? 0.0) as num;
                                      final shortVal = (c['shortfall'] ?? 0.0) as num;
                                      final isPart = c['is_partial'] == true;
                                      return TableRow(
                                        children: [
                                          _TableCell(name, fontWeight: FontWeight.w600),
                                          _TableCell(code),
                                          _TableCell(CurrencyFormatter.formatNaira(expVal)),
                                          _TableCell(CurrencyFormatter.formatNaira(shortVal), textColor: const Color(0xFFDC2626), fontWeight: FontWeight.w700),
                                          _TableCell(isPart ? 'Partial Shortfall' : 'NOT PAID (₦0)', textColor: isPart ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (isMobile && notPaidList.length > 10) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _mobileNotPaidLimit = (_mobileNotPaidLimit == 10) ? notPaidList.length : 10;
                                  });
                                },
                                child: Text(
                                  _mobileNotPaidLimit == 10
                                      ? 'View All ${notPaidList.length} Arrears Records'
                                      : 'Show Top 10 Only',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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
          ],
        ],
      ),
    );
  }

  Widget _buildTallyKpi(String label, String value, String? delta, Color? deltaColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 2),
            Text(
              delta,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: deltaColor ?? const Color(0xFF64748B)),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TOP SUMMARY KPI METRIC CARDS
  // ==========================================
  Widget _buildSummaryKpiCards(
    num openingBalance,
    num totalInflows,
    num totalOutflows,
    num closingBalance,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final c1 = _buildSummaryKpiCard('Opening Balance', CurrencyFormatter.formatNaira(openingBalance), const Color(0xFF0284C7));
        final c2 = _buildSummaryKpiCard('Total Inflows', CurrencyFormatter.formatNaira(totalInflows), const Color(0xFF059669));
        final c3 = _buildSummaryKpiCard('Total Outflows', CurrencyFormatter.formatNaira(totalOutflows), const Color(0xFFDC2626));
        final c4 = _buildClosingCard(closingBalance);

        if (w < 600) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: c1),
                    const SizedBox(width: 10),
                    Expanded(child: c2),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: c3),
                    const SizedBox(width: 10),
                    Expanded(child: c4),
                  ],
                ),
              ),
            ],
          );
        } else if (w < 900) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: c1),
                    const SizedBox(width: 12),
                    Expanded(child: c2),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: c3),
                    const SizedBox(width: 12),
                    Expanded(child: c4),
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
              Expanded(child: c1),
              const SizedBox(width: 12),
              Expanded(child: c2),
              const SizedBox(width: 12),
              Expanded(child: c3),
              const SizedBox(width: 12),
              Expanded(child: c4),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // BALANCED 2-COLUMN T-ACCOUNT LEDGER
  // ==========================================
  Widget _buildTAccountLedger(
    Map<String, dynamic> inflows,
    Map<String, dynamic> outflows,
  ) {
    // 19 Authoritative Inflow Items (app.py L11022-11042)
    final inflowItems = [
      ('Opening Balance', (inflows['opening_balance'] ?? 0.0) as num),
      ('Savings Deposit', (inflows['savings_deposit'] ?? 0.0) as num),
      ('Credit Rep (Daily)', (inflows['rep_daily'] ?? 0.0) as num),
      ('Credit Rep (12 Weeks)', (inflows['rep_12_weeks'] ?? 0.0) as num),
      ('Credit Rep (24 Weeks)', (inflows['rep_24_weeks'] ?? 0.0) as num),
      ('Credit Rep (Monthly)', (inflows['rep_monthly'] ?? 0.0) as num),
      ('Laps Reserve', (inflows['laps_reserve'] ?? 0.0) as num),
      ('Asset Credit Sales', (inflows['asset_credit_sales'] ?? 0.0) as num),
      ('Cash & Carry', (inflows['cash_and_carry'] ?? 0.0) as num),
      ('Daily 11% Markup', (inflows['daily_11_pct'] ?? 0.0) as num),
      ('Weekly 11% Markup', (inflows['weekly_11_pct'] ?? 0.0) as num),
      ('Weekly 20% Markup', (inflows['weekly_20_pct'] ?? 0.0) as num),
      ('Monthly / 20% Markup', (inflows['risk_premium_returns'] ?? 0.0) as num),
      ('Contingency (1%)', (inflows['contingency'] ?? 0.0) as num),
      ('Credit Form / App Fee', (inflows['app_fee'] ?? 0.0) as num),
      ('Credit Form Damage', (inflows['credit_form_damage'] ?? 0.0) as num),
      ('Pass Book', (inflows['passbook'] ?? 0.0) as num),
      ('Bonus', (inflows['bonus'] ?? 0.0) as num),
      ('Bank Withdrawal', (inflows['bank_withdrawal'] ?? 0.0) as num),
    ];

    // 8 Authoritative Outflow Items (app.py L11044-11053)
    final outflowItems = [
      ('Active Loan (Daily)', (outflows['active_loan_daily'] ?? 0.0) as num),
      ('Active Loan (12 Weeks)', (outflows['active_loan_12w'] ?? 0.0) as num),
      ('Active Loan (24 Weeks)', (outflows['active_loan_24w'] ?? 0.0) as num),
      ('Active Loan (Monthly)', (outflows['active_loan_monthly'] ?? 0.0) as num),
      ('Product / Savings Withdrawal', (outflows['product_withdrawal'] ?? 0.0) as num),
      ('Office Expenses', (outflows['office_expenses'] ?? 0.0) as num),
      ('LAPS Returns / Payouts', (outflows['laps_returns'] ?? 0.0) as num),
      ('Bank Deposit', (outflows['bank_deposit'] ?? 0.0) as num),
    ];

    return IcareCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Title (app.py L11020)
          const IcareSectionHeader(
            title: 'Daily Cashbook Ledger',
          ),
          const SizedBox(height: 12),

          // Double-Entry Balanced Table (app.py L11055-11066)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 650),
                  child: Table(
                  border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 1),
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(3),
                    3: FlexColumnWidth(2),
                  },
                  children: [
                    // Header Row
                    const TableRow(
                      decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                      children: [
                        _TableHeaderCell('Inflows (Left / Debit)', color: Color(0xFF065F46)),
                        _TableHeaderCell('Amount (₦)', align: TextAlign.right, color: Color(0xFF065F46)),
                        _TableHeaderCell('Outflows (Right / Credit)', color: Color(0xFF991B1B)),
                        _TableHeaderCell('Amount (₦)', align: TextAlign.right, color: Color(0xFF991B1B)),
                      ],
                    ),
                    // 19 Data Rows
                    for (int i = 0; i < inflowItems.length; i++) ...[
                      TableRow(
                        decoration: BoxDecoration(color: i % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA)),
                        children: [
                          // Inflow item name
                          _TableCell(inflowItems[i].$1, fontWeight: FontWeight.w500),
                          // Inflow item amount
                          _TableCell(
                            _formatLedgerAmount(inflowItems[i].$2),
                            align: TextAlign.right,
                            fontWeight: FontWeight.w700,
                          ),
                          // Outflow item name
                          _TableCell(
                            i < outflowItems.length ? outflowItems[i].$1 : '',
                            fontWeight: FontWeight.w500,
                          ),
                          // Outflow item amount
                          _TableCell(
                            i < outflowItems.length ? _formatLedgerAmount(outflowItems[i].$2) : '',
                            align: TextAlign.right,
                            fontWeight: FontWeight.w700,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  }

  String _formatLedgerAmount(num val) {
    if (val == 0) return '₦0';
    return CurrencyFormatter.formatNaira(val);
  }

  Widget _buildSummaryKpiCard(String label, String value, Color color) {
    return IcareCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      topAccentColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          const SizedBox(height: 4),
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
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosingCard(num closing) {
    final isPos = closing >= 0;
    final accentCol = isPos ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final textCol = isPos ? const Color(0xFF065F46) : const Color(0xFF991B1B);

    return IcareCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      topAccentColor: accentCol,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CLOSING BALANCE',
            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w700, letterSpacing: 0.4),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.formatNaira(closing),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: textCol,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ERROR CORRECTION & REVERSAL HUB
  // ==========================================
  Widget _buildCorrectionHub(
    List<Map<String, dynamic>> reversalOptions,
    List<Map<String, dynamic>> submittedReversals, {
    bool isMobile = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Caption (app.py L11081-11082)
          const Text(
            'Error Corrections & Reversals',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          const Text(
            'Request BM approval to reverse an erroneous fee, expense, or deposit.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          // Expander: Flag an EOD Fee / Expense / Deposit for Reversal (app.py L11084-11153)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Theme(
              data: ThemeData(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: isMobile,
                title: const Text(
                  'Request Transaction Reversal',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info banner (app.py L11085)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFF0369A1), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Select a recent EOD transaction to flag for BM approval.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF0369A1)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        if (reversalOptions.isNotEmpty) ...[
                          // Select Transaction Dropdown (app.py L11132)
                          const Text(
                            'Select Transaction',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: reversalOptions.any((o) => o['record_id'] == _selectedRevOptionId)
                                    ? _selectedRevOptionId
                                    : reversalOptions.first['record_id'] as String,
                                icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                                items: reversalOptions.map((o) {
                                  final id = o['record_id'] as String;
                                  final label = (o['label'] ?? id).toString();
                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(
                                      label,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final found = reversalOptions.firstWhere((o) => o['record_id'] == val);
                                    setState(() {
                                      _selectedRevOptionId = val;
                                      _selectedRevOptionType = found['record_type'] as String?;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Reason Text Input (app.py L11134)
                          const Text(
                            'Reason for Reversal',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: TextField(
                              controller: _revReasonCtrl,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: const InputDecoration(
                                hintText: 'e.g., Typo in expense amount',
                                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Submit Button (app.py L11135)
                          ElevatedButton.icon(
                            onPressed: _isSubmittingReversal ? null : _handleReversalRequest,
                            icon: _isSubmittingReversal
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_outlined, size: 16),
                            label: Text(
                              _isSubmittingReversal ? 'Submitting...' : 'Submit Reversal Request',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF064E3B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                          ),
                        ] else ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No recent EOD transactions available to flag.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
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
          const SizedBox(height: 18),

          // Submitted Reversal Requests History (app.py L11156-11182)
          const Text(
            'Submitted Requests',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),

          if (submittedReversals.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No reversal requests submitted yet.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
              ),
            ),
          ] else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 700),
                  child: Table(
                    border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 1),
                    columnWidths: const {
                      0: FlexColumnWidth(2.2),
                      1: FlexColumnWidth(1.2),
                      2: FlexColumnWidth(1.4),
                      3: FlexColumnWidth(3.5),
                      4: FlexColumnWidth(1.4),
                      5: FlexColumnWidth(1.8),
                    },
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                        children: [
                          _TableHeaderCell('Date'),
                          _TableHeaderCell('Type'),
                          _TableHeaderCell('Record Ref'),
                          _TableHeaderCell('Reason'),
                          _TableHeaderCell('Status'),
                          _TableHeaderCell('Approved By'),
                        ],
                      ),
                      ...submittedReversals.map((r) {
                        final date = (r['date'] ?? '').toString();
                        final type = (r['record_type'] ?? '').toString();
                        final refId = (r['record_id'] ?? '').toString();
                        final reason = (r['reason'] ?? '').toString();
                        final status = (r['status'] ?? 'Pending').toString();
                        final approver = (r['approved_by'] ?? '—').toString();
                        return TableRow(
                          children: [
                            _TableCell(date),
                            _TableCell(type, fontWeight: FontWeight.w600),
                            _TableCell(refId),
                            _TableCell(reason),
                            _TableStatusBadgeCell(status),
                            _TableCell(approver),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Error loading cashbook projection: $error',
              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
            ),
          ),
          ElevatedButton(
            onPressed: () => ref.refresh(coCashbookDataProvider(_currentKey)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TABLE HELPER WIDGETS
// ==========================================
class _TableHeaderCell extends StatelessWidget {
  final String text;
  final TextAlign align;
  final Color? color;

  const _TableHeaderCell(this.text, {this.align = TextAlign.left, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color ?? const Color(0xFF334155),
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final TextAlign align;
  final Color? textColor;
  final FontWeight fontWeight;

  const _TableCell(
    this.text, {
    this.align = TextAlign.left,
    this.textColor,
    this.fontWeight = FontWeight.w400,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          color: textColor ?? const Color(0xFF0F172A),
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}

class _TableStatusBadgeCell extends StatelessWidget {
  final String status;

  const _TableStatusBadgeCell(this.status);

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFFFEF3C7);
    Color text = const Color(0xFF92400E);

    final sLower = status.toLowerCase();
    if (sLower.contains('approved') || sLower.contains('active')) {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF065F46);
    } else if (sLower.contains('reject') || sLower.contains('denied')) {
      bg = const Color(0xFFFEF2F2);
      text = const Color(0xFF991B1B);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: text),
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const IcareTableSkeleton(rowCount: 8, hasFilterBar: false, padding: EdgeInsets.zero);
  }
}

