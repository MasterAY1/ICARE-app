import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../../../core/widgets/icare_card.dart';
import '../../../core/widgets/icare_section_header.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/errors/app_error_formatter.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/datasources/co_api_service.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import 'package:frontend_flutter/core/theme/icare_motion.dart';

/// Riverpod family provider using composite String key "$dateStr||$officer" to guarantee value equality and eliminate infinite refetches
final coCashbookDataProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, key) async {
  final parts = key.split('||');
  final dateStr = parts.isNotEmpty && parts[0] != 'null' && parts[0].isNotEmpty ? parts[0] : null;
  final officer = parts.length > 1 && parts[1] != 'null' && parts[1].isNotEmpty ? parts[1] : null;

  final api = ref.watch(coApiServiceProvider);
  return api.getCoCashbook(dateStr: dateStr, officer: officer);
});

/// Riverpod family provider for retrieving today's attributed client fees for the CO
final clientFeesProvider = FutureProvider.family<List<dynamic>, String>((ref, key) async {
  final parts = key.split('||');
  final dateStr = parts.isNotEmpty && parts[0] != 'null' && parts[0].isNotEmpty ? parts[0] : null;
  final officer = parts.length > 1 && parts[1] != 'null' && parts[1].isNotEmpty ? parts[1] : null;

  final api = ref.watch(coApiServiceProvider);
  return api.getClientFees(dateStr: dateStr, officer: officer);
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
  DateTime? _userSelectedDate;
  DateTime _displayDate = DateTime.now();
  String? _selectedOfficer;
  final Map<String, String> _initialEodTexts = {};

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
  String _statusBannerSeverity = 'success';
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

  DateTime get _selectedDate => _userSelectedDate ?? _displayDate;
  String get _dateQueryStr =>
      _userSelectedDate != null ? DateFormat('yyyy-MM-dd').format(_userSelectedDate!) : '';
  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _currentKey => '$_dateQueryStr||${_selectedOfficer ?? ""}';

  String _formatInputNum(num val) {
    if (val == 0) return '';
    return val % 1 == 0 ? val.toStringAsFixed(0) : val.toStringAsFixed(2);
  }

  void _populateEodControllers(Map<String, dynamic> data) {
    final inflows = (data['inflows'] as Map<String, dynamic>?) ?? {};
    final outflows = (data['outflows'] as Map<String, dynamic>?) ?? {};

    final op = (inflows['opening_balance'] ?? 0.0) as num;
    final exp = (outflows['office_expenses'] ?? 0.0) as num;
    final bdep = (outflows['bank_deposit'] ?? 0.0) as num;
    final app = (inflows['app_fee'] ?? 0.0) as num;
    final pb = (inflows['passbook'] ?? 0.0) as num;
    final misc = (inflows['eod_misc_fee'] ?? inflows['misc_fees'] ?? 0.0) as num;
    final cfd = (inflows['credit_form_damage'] ?? 0.0) as num;
    final bon = (inflows['bonus'] ?? 0.0) as num;

    _openingCtrl.text = _formatInputNum(op);
    _expensesCtrl.text = _formatInputNum(exp);
    _bankDepCtrl.text = _formatInputNum(bdep);
    _appFeeCtrl.text = _formatInputNum(app);
    _passbookCtrl.text = _formatInputNum(pb);
    _miscFeeCtrl.text = _formatInputNum(misc);
    _cfdCtrl.text = _formatInputNum(cfd);
    _bonusCtrl.text = _formatInputNum(bon);

    _initialEodTexts
      ..['opening_balance'] = _openingCtrl.text
      ..['office_expenses'] = _expensesCtrl.text
      ..['bank_deposit'] = _bankDepCtrl.text
      ..['app_fee'] = _appFeeCtrl.text
      ..['passbook'] = _passbookCtrl.text
      ..['misc_fee'] = _miscFeeCtrl.text
      ..['credit_form_damage'] = _cfdCtrl.text
      ..['bonus'] = _bonusCtrl.text;
  }

  void _syncReversalDefaults(List<Map<String, dynamic>> reversalOptions) {
    if (reversalOptions.isEmpty) {
      if (_selectedRevOptionId != null || _selectedRevOptionType != null) {
        setState(() {
          _selectedRevOptionId = null;
          _selectedRevOptionType = null;
        });
      }
      return;
    }
    final stillValid = reversalOptions.any((o) => o['record_id'] == _selectedRevOptionId);
    if (!stillValid) {
      final first = reversalOptions.first;
      setState(() {
        _selectedRevOptionId = first['record_id']?.toString();
        _selectedRevOptionType = first['record_type']?.toString() ?? 'Cashbook';
      });
    }
  }

  Widget _buildClientFeesList() {
    final tokens = IcareSurfaceTokens.of(context);
    final feesAsync = ref.watch(clientFeesProvider(_currentKey));
    return feesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => const SizedBox(),
      data: (fees) {
        if (fees.isEmpty) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: tokens.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No client fees recorded for this date yet. Use "Record Client Fee" to attribute a fee directly to a client.',
                    style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recorded Client Fees (${fees.length})',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary),
                    ),
                    Text(
                      'Attributed in Audit View',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.successText),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: tokens.borderSubtle),
              ...fees.map((f) {
                final m = f as Map<String, dynamic>;
                final cName = m['client_name'] ?? 'Unknown';
                final cCode = m['client_code'] ?? 'N/A';
                final fType = m['fee_type'] ?? 'FEE';
                final amt = (m['amount'] as num?)?.toDouble() ?? 0.0;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tokens.infoBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: tokens.infoBorder),
                        ),
                        child: Text(
                          fType,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tokens.infoText),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$cCode — $cName',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatNaira(amt, showDecimals: true),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: tokens.successText),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showRecordClientFeeModal(BuildContext context, bool isOpen, String openReason) {
    if (!isOpen) {
      _showBanner('Cannot record fees today ($openReason).', 'danger', Icons.error_outline);
      return;
    }

    final api = ref.read(coApiServiceProvider);
    List<dynamic> clientsList = [];
    bool isLoadingClients = true;

    showIcareDialog(
      context: context,
      builder: (dialogCtx) {
        String selectedFeeType = 'Credit Form / App Fee';
        Map<String, dynamic>? selectedClient;
        final amountCtrl = TextEditingController();
        final remarksCtrl = TextEditingController();
        bool isSubmittingFee = false;
        String? localError;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final tokens = IcareSurfaceTokens.of(ctx);
            if (isLoadingClients && clientsList.isEmpty) {
              api.getSingleClientOptions().then((res) {
                if (ctx.mounted) {
                  setModalState(() {
                    clientsList = (res['clients'] as List<dynamic>?) ?? [];
                    isLoadingClients = false;
                  });
                }
              }).catchError((err) {
                if (ctx.mounted) {
                  setModalState(() {
                    isLoadingClients = false;
                    localError = 'Failed to load branch clients: ${AppErrorDetails.from(err).message}';
                  });
                }
              });
            }

            final isMobile = MediaQuery.of(ctx).size.width < 600;
            InputDecoration modalInputDec({String? prefixText, String? hintText}) {
              return InputDecoration(
                prefixText: prefixText,
                prefixStyle: TextStyle(color: tokens.textSecondary, fontWeight: FontWeight.w600),
                hintText: hintText,
                hintStyle: TextStyle(fontSize: 13, color: tokens.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: tokens.surfaceSubtle,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.brandPrimary, width: 1.5)),
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 540),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: tokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tokens.borderSubtle),
                    boxShadow: const [
                      BoxShadow(color: Color(0x260F172A), blurRadius: 24, offset: Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tokens.successBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.receipt_long_outlined, size: 20, color: tokens.successText),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Record Client Fee', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary)),
                                const SizedBox(height: 2),
                                Text('Attributed revenue fee linked directly to the client.', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 20, color: tokens.textMuted),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      Divider(height: 24, color: tokens.borderSubtle),

                      if (localError != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: tokens.dangerBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: tokens.dangerBorder),
                          ),
                          child: Text(localError!, style: TextStyle(fontSize: 12, color: tokens.dangerText)),
                        ),

                      Text('Select Client', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                      const SizedBox(height: 6),
                      if (isLoadingClients)
                        const SizedBox(
                          height: 48,
                          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                        )
                      else
                        DropdownButtonFormField<Map<String, dynamic>>(
                          isExpanded: true,
                          value: selectedClient,
                          dropdownColor: tokens.surfaceElevated,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                          hint: Text('Search / Select Client', style: TextStyle(fontSize: 13, color: tokens.textMuted)),
                          decoration: modalInputDec(),
                          items: clientsList.map((c) {
                            final m = c as Map<String, dynamic>;
                            final name = m['client_name'] ?? 'Unknown';
                            final code = m['client_code'] ?? '';
                            final grp = m['group_name'] ?? '';
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: m,
                              child: Text(
                                '$code — $name ($grp)',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedClient = val),
                        ),
                      const SizedBox(height: 14),

                      Text('Fee Category', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedFeeType,
                        dropdownColor: tokens.surfaceElevated,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                        decoration: modalInputDec(),
                        items: [
                          DropdownMenuItem(value: 'Credit Form / App Fee', child: Text('Credit Form / App Fee (Processing)', style: TextStyle(color: tokens.textPrimary))),
                          DropdownMenuItem(value: 'Pass Book', child: Text('Pass Book', style: TextStyle(color: tokens.textPrimary))),
                          DropdownMenuItem(value: 'Misc Fee', child: Text('Misc Fee (Misc Savings)', style: TextStyle(color: tokens.textPrimary))),
                          DropdownMenuItem(value: 'Credit Form Damage', child: Text('Credit Form Damage (Damage Fee)', style: TextStyle(color: tokens.textPrimary))),
                          DropdownMenuItem(value: 'Bonus', child: Text('Bonus', style: TextStyle(color: tokens.textPrimary))),
                        ],
                        onChanged: (v) {
                          if (v != null) setModalState(() => selectedFeeType = v);
                        },
                      ),
                      const SizedBox(height: 14),

                      Text('Fee Amount (₦)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                        decoration: modalInputDec(prefixText: '₦ ', hintText: 'e.g. 500'),
                      ),
                      const SizedBox(height: 14),

                      Text('Transaction Remarks / Reference (Optional)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: remarksCtrl,
                        style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                        decoration: modalInputDec(hintText: 'e.g. Passbook issuance during evening collection'),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmittingFee ? null : () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: tokens.textSecondary,
                                side: BorderSide(color: tokens.borderStrong),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: isSubmittingFee
                                  ? null
                                  : () async {
                                      if (selectedClient == null) {
                                        setModalState(() => localError = 'Please select a client.');
                                        return;
                                      }
                                      final amt = double.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                                      if (amt <= 0) {
                                        setModalState(() => localError = 'Please enter a fee amount greater than ₦0.');
                                        return;
                                      }

                                      setModalState(() {
                                        isSubmittingFee = true;
                                        localError = null;
                                      });

                                      try {
                                        final feePayload = {
                                          'client_id': selectedClient!['client_id'],
                                          'fee_type': selectedFeeType,
                                          'amount': amt,
                                          'date': _dateStr,
                                          if (_selectedOfficer != null && _selectedOfficer!.isNotEmpty) 'officer': _selectedOfficer,
                                          if (remarksCtrl.text.trim().isNotEmpty) 'remarks': remarksCtrl.text.trim(),
                                        };
                                        final feeRes = await api.recordClientFee(feePayload);
                                        if (ctx.mounted) Navigator.of(ctx).pop();
                                        _showBanner(
                                          feeRes['message'] ?? 'Fee recorded successfully.',
                                          'success',
                                          Icons.check_circle_outline,
                                        );
                                        _lastLoadedKey = null;
                                        ref.invalidate(coCashbookDataProvider(_currentKey));
                                        ref.invalidate(clientFeesProvider(_currentKey));
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          setModalState(() {
                                            isSubmittingFee = false;
                                            localError = AppErrorDetails.from(e).message;
                                          });
                                        }
                                      }
                                    },
                              icon: isSubmittingFee
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.check, size: 16),
                              label: Text(isSubmittingFee ? 'Recording...' : 'Post Client Fee'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tokens.brandPrimaryDark,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSaveEod(bool isOpen, String openReason) async {
    if (!isOpen) {
      _showBanner(
        'Cannot update End of Day inputs today ($openReason).',
        'danger',
        Icons.error_outline,
      );
      return;
    }

    double? changedAmount(String key, TextEditingController ctrl) {
      final current = ctrl.text.replaceAll(',', '').trim();
      if (_initialEodTexts[key] == current) {
        return null;
      }
      return current.isEmpty ? 0.0 : (double.tryParse(current) ?? 0.0);
    }

    final opVal = changedAmount('opening_balance', _openingCtrl);
    final expVal = changedAmount('office_expenses', _expensesCtrl);
    final bdepVal = changedAmount('bank_deposit', _bankDepCtrl);
    final appVal = changedAmount('app_fee', _appFeeCtrl);
    final pbVal = changedAmount('passbook', _passbookCtrl);
    final miscVal = changedAmount('misc_fee', _miscFeeCtrl);
    final cfdVal = changedAmount('credit_form_damage', _cfdCtrl);
    final bonVal = changedAmount('bonus', _bonusCtrl);

    setState(() => _isSubmittingEod = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final payload = <String, dynamic>{
        'date': _dateStr,
        if (_selectedOfficer != null && _selectedOfficer!.isNotEmpty) 'officer': _selectedOfficer,
        if (opVal != null) 'opening_balance': opVal,
        if (expVal != null) 'office_expenses': expVal,
        if (bdepVal != null) 'bank_deposit': bdepVal,
        if (appVal != null) 'app_fee': appVal,
        if (pbVal != null) 'passbook': pbVal,
        if (miscVal != null) 'misc_fee': miscVal,
        if (cfdVal != null) 'credit_form_damage': cfdVal,
        if (bonVal != null) 'bonus': bonVal,
      };

      final res = await api.submitEodAdjustments(payload);
      _showBanner(
        res['message'] ?? 'End of Day Outflows & Fees Updated Successfully.',
        'success',
        Icons.check_circle_outline,
      );
      _lastLoadedKey = null;
      ref.invalidate(coCashbookDataProvider(_currentKey));
      ref.invalidate(clientFeesProvider(_currentKey));
    } catch (e) {
      _showBanner(
        'Error updating End of Day inputs: ${AppErrorDetails.from(e).message}',
        'danger',
        Icons.error_outline,
      );
    } finally {
      setState(() => _isSubmittingEod = false);
    }
  }

  Future<void> _handleReversalRequest(bool isOpen, String openReason) async {
    if (!isOpen) {
      _showBanner(
        'Cannot submit reversal request today ($openReason).',
        'danger',
        Icons.error_outline,
      );
      return;
    }

    final reason = _revReasonCtrl.text.trim();
    if (_selectedRevOptionId == null || _selectedRevOptionId!.isEmpty) {
      _showBanner(
        'Please select an EOD transaction to flag for reversal.',
        'warning',
        Icons.warning_amber_rounded,
      );
      return;
    }
    if (reason.isEmpty) {
      _showBanner(
        'Please provide a valid reason for the reversal.',
        'warning',
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
        'success',
        Icons.check_circle_outline,
      );
      _revReasonCtrl.clear();
      _lastLoadedKey = null;
      setState(() {
        _selectedRevOptionId = null;
        _selectedRevOptionType = null;
      });
      ref.invalidate(coCashbookDataProvider(_currentKey));
    } catch (e) {
      _showBanner(
        'Failed to submit reversal request: ${AppErrorDetails.from(e).message}',
        'danger',
        Icons.error_outline,
      );
    } finally {
      setState(() => _isSubmittingReversal = false);
    }
  }

  void _showBanner(String msg, String severity, IconData icon) {
    setState(() {
      _statusBannerText = msg;
      _statusBannerSeverity = severity;
      _statusBannerIcon = icon;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final cashbookAsync = ref.watch(coCashbookDataProvider(_currentKey));

    ref.listen<int>(globalRefreshSignalProvider, (prev, next) {
      if (prev != next) {
        _lastLoadedKey = null;
      }
    });

    final Color bannerFg;
    final Color bannerBg;
    final Color bannerBorder;
    switch (_statusBannerSeverity) {
      case 'danger':
        bannerFg = tokens.dangerText;
        bannerBg = tokens.dangerBg;
        bannerBorder = tokens.dangerBorder;
        break;
      case 'warning':
        bannerFg = tokens.warningText;
        bannerBg = tokens.warningBg;
        bannerBorder = tokens.warningBorder;
        break;
      case 'success':
      default:
        bannerFg = tokens.successText;
        bannerBg = tokens.successBg;
        bannerBorder = tokens.successBorder;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Title & Subtitle (app.py L10749-10750)
        const IcareSectionHeader(
          title: 'Daily Cashbook',
          subtitle: 'Primary Vault Ledger',
        ),
        const SizedBox(height: 14),

        // Status Notification Banner (if any feedback)
        if (_statusBannerText != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: bannerBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: bannerBorder),
            ),
            child: Row(
              children: [
                Icon(_statusBannerIcon, color: bannerFg, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusBannerText!,
                    style: TextStyle(
                      color: bannerFg,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: bannerFg),
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
          error: (err, _) => _buildErrorCard(AppErrorDetails.from(err).message),
          data: (data) {
            // Check if key changed to pre-populate inputs and sync business date / reversal defaults
            if (_lastLoadedKey != _currentKey) {
              _lastLoadedKey = _currentKey;
              final serverDateStr = (data['date'] ?? '').toString();
              final serverDate = DateTime.tryParse(serverDateStr);
              final revOpts = (data['reversal_options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (serverDate != null && _userSelectedDate == null &&
                    DateFormat('yyyy-MM-dd').format(_displayDate) != serverDateStr) {
                  setState(() => _displayDate = serverDate);
                }
                _populateEodControllers(data);
                _syncReversalDefaults(revOpts);
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
            isOpen: isOpen,
            openReason: openReason,
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
        _buildTAccountLedger(inflows, outflows, totalInflows, totalOutflows),
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
        _buildCorrectionHub(
          reversalOptions,
          submittedReversals,
          isOpen: isOpen,
          openReason: openReason,
          isMobile: false,
        ),
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
    final tokens = IcareSurfaceTokens.of(context);
    final dateCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Date',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary),
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
              setState(() {
                _userSelectedDate = picked;
                _displayDate = picked;
                _lastLoadedKey = null;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.borderStrong),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd MMMM yyyy').format(_selectedDate),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                ),
                Icon(Icons.calendar_today_outlined, size: 16, color: tokens.textMuted),
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
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary),
        ),
        const SizedBox(height: 6),
        if (canSelectOfficer && officers.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.borderStrong),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: tokens.surfaceElevated,
                value: officers.any((o) => o['username'] == (_selectedOfficer ?? currentOfficer))
                    ? (_selectedOfficer ?? currentOfficer)
                    : (officers.first['username'] as String),
                icon: Icon(Icons.keyboard_arrow_down, size: 18, color: tokens.textMuted),
                items: officers.map((o) {
                  final u = o['username'] as String;
                  final disp = (o['display'] ?? u).toString();
                  return DropdownMenuItem<String>(
                    value: u,
                    child: Text(
                      disp,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
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
              color: tokens.infoBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.infoBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 15, color: tokens.infoText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$currentOfficer • $branchName Branch',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tokens.infoText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    final refreshBtn = OutlinedButton.icon(
      onPressed: () {
        _lastLoadedKey = null;
        ref.invalidate(coCashbookDataProvider(_currentKey));
        ref.invalidate(clientFeesProvider(_currentKey));
      },
      icon: Icon(Icons.refresh, size: 16, color: tokens.textPrimary),
      label: Text(
        'Refresh',
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tokens.textPrimary),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: BorderSide(color: tokens.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: refreshBtn),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(flex: 1, child: dateCol),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: officerCol),
                const SizedBox(width: 12),
                refreshBtn,
              ],
            ),
    );
  }

  Widget _buildSuspendedBanner(String openReason) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              'Operations Suspended ($openReason) — Read-Only mode.',
              style: TextStyle(fontSize: 13, color: tokens.warningText, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String message) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: tokens.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, color: tokens.textMuted, fontStyle: FontStyle.italic),
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
                          'PRIMARY VAULT CASH',
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
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildCashbookPill(
              tokens: tokens,
              index: 0,
              currentIndex: selectedTab,
              label: 'T-Ledger',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => onSelect(0),
            ),
            const SizedBox(width: 4),
            _buildCashbookPill(
              tokens: tokens,
              index: 1,
              currentIndex: selectedTab,
              label: 'EOD Inputs',
              icon: Icons.tune_outlined,
              onTap: () => onSelect(1),
            ),
            const SizedBox(width: 4),
            _buildCashbookPill(
              tokens: tokens,
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
              tokens: tokens,
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
    required IcareSurfaceTokens tokens,
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
            color: isSelected ? tokens.surfaceElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: tokens.borderSubtle) : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: tokens.isDark ? 0.18 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
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
                color: isSelected ? tokens.brandPrimary : tokens.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? tokens.textPrimary : tokens.textMuted,
                ),
              ),
              if (badgeCount != null && badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAlertBadge
                        ? tokens.dangerBg
                        : (isSelected ? tokens.brandSoftBg : tokens.neutralBg),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isAlertBadge
                          ? tokens.dangerText
                          : (isSelected ? tokens.brandSoftText : tokens.textSecondary),
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
    final tokens = IcareSurfaceTokens.of(context);
    final inflowItems = [
      ('Opening Balance', (inflows['opening_balance'] ?? 0.0) as num),
      ('Savings Deposit', (inflows['savings_deposit'] ?? 0.0) as num),
      ('Credit Rep (Daily)', (inflows['rep_daily'] ?? 0.0) as num),
      ('Credit Rep (120 Days)', (inflows['rep_120_days'] ?? 0.0) as num),
      ('Credit Rep (12 Weeks)', (inflows['rep_12_weeks'] ?? 0.0) as num),
      ('Credit Rep (24 Weeks)', (inflows['rep_24_weeks'] ?? 0.0) as num),
      ('Credit Rep (Monthly)', (inflows['rep_monthly'] ?? 0.0) as num),
      ('Laps Reserve', (inflows['laps_reserve'] ?? 0.0) as num),
      ('Asset Credit Sales', (inflows['asset_credit_sales'] ?? 0.0) as num),
      ('Cash & Carry', (inflows['cash_and_carry'] ?? 0.0) as num),
      ('Daily 11% Markup', (inflows['daily_11_pct'] ?? 0.0) as num),
      ('Daily 20% Markup', (inflows['daily_20_pct'] ?? 0.0) as num),
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
      ('Active Loan (120 Days)', (outflows['active_loan_120d'] ?? 0.0) as num),
      ('Active Loan (12 Weeks)', (outflows['active_loan_12w'] ?? 0.0) as num),
      ('Active Loan (24 Weeks)', (outflows['active_loan_24w'] ?? 0.0) as num),
      ('Active Loan (Monthly)', (outflows['active_loan_monthly'] ?? 0.0) as num),
      ('Product / Savings Withdrawal', (outflows['product_withdrawal'] ?? 0.0) as num),
      ('Office Expenses', (outflows['office_expenses'] ?? 0.0) as num),
      ('LAPS Returns / Payouts', (outflows['laps_returns'] ?? 0.0) as num),
      ('Bank Deposit', (outflows['bank_deposit'] ?? 0.0) as num),
    ];

    final isInflow = _mobileLedgerSubTab == 0;
    final activeInflows = inflowItems.where((i) => i.$2 != 0).length;
    final activeOutflows = outflowItems.where((i) => i.$2 != 0).length;
    final currentItems = isInflow ? inflowItems : outflowItems;
    final displayedItems = _mobileShowAllLedgerItems
        ? currentItems
        : currentItems.where((i) => i.$2 != 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-tab switcher: Inflows (Debit) vs Outflows (Credit)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.borderStrong),
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
                      color: isInflow ? tokens.successBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isInflow ? Border.all(color: tokens.successBorder) : null,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tokens.successDot,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Inflows (Debit)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isInflow ? FontWeight.w700 : FontWeight.w500,
                                color: isInflow ? tokens.successText : tokens.textMuted,
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
                            color: isInflow ? tokens.successText : tokens.textSecondary,
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
                      color: !isInflow ? tokens.dangerBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: !isInflow ? Border.all(color: tokens.dangerBorder) : null,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tokens.dangerDot,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Outflows (Credit)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: !isInflow ? FontWeight.w700 : FontWeight.w500,
                                color: !isInflow ? tokens.dangerText : tokens.textMuted,
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
                            color: !isInflow ? tokens.dangerText : tokens.textSecondary,
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary),
            ),
            InkWell(
              onTap: () => setState(() => _mobileShowAllLedgerItems = !_mobileShowAllLedgerItems),
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
                    Icon(
                      _mobileShowAllLedgerItems ? Icons.filter_list_off : Icons.filter_list,
                      size: 13,
                      color: tokens.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _mobileShowAllLedgerItems
                          ? 'Showing All (${currentItems.length})'
                          : 'Active Only (${isInflow ? activeInflows : activeOutflows})',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textSecondary),
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
            color: tokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: displayedItems.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, size: 28, color: tokens.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'No ${isInflow ? "inflows" : "outflows"} recorded today.',
                          style: TextStyle(fontSize: 12.5, color: tokens.textMuted, fontStyle: FontStyle.italic),
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
                      if (i > 0) Divider(height: 1, color: tokens.borderSubtle),
                      _buildMobileLedgerItemRow(
                        tokens,
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

  Widget _buildMobileLedgerItemRow(IcareSurfaceTokens tokens, String name, num amount, {required bool isInflow}) {
    final isNonZero = amount > 0;
    final color = isNonZero
        ? (isInflow ? tokens.successText : tokens.dangerText)
        : tokens.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isNonZero
            ? (isInflow ? tokens.successBg : tokens.dangerBg).withValues(alpha: tokens.isDark ? 0.35 : 0.45)
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
                      color: isInflow ? tokens.successDot : tokens.dangerDot,
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
                      color: isNonZero ? tokens.textPrimary : tokens.textMuted,
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
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isMobile,
          iconColor: tokens.textMuted,
          collapsedIconColor: tokens.textMuted,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          title: Row(
            children: [
              Icon(Icons.tune_outlined, size: 18, color: tokens.textPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'End of Day Outflows & Fees',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Record branch expenses, bank deposits, and fee collections.',
              style: TextStyle(fontSize: 12, color: tokens.textMuted),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: tokens.borderSubtle, height: 24),

                  // Responsive EOD Form Inputs
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 650;
                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildNumberField('Opening Balance (B/F Cash)', _openingCtrl, step: 500),
                            const SizedBox(height: 12),
                            _buildNumberField('Office Expenses', _expensesCtrl, step: 500),
                            const SizedBox(height: 12),
                            _buildNumberField('Bank Deposited', _bankDepCtrl, step: 500),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Additional Collections & Fees',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textSecondary),
                                ),
                                ElevatedButton.icon(
                                  onPressed: isOpen ? () => _showRecordClientFeeModal(context, isOpen, openReason) : null,
                                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 14),
                                  label: const Text('Record Client Fee', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: tokens.brandPrimaryDark,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: tokens.surfaceSubtle,
                                    disabledForegroundColor: tokens.textMuted,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Additional Collections & Fees',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textSecondary),
                              ),
                              ElevatedButton.icon(
                                onPressed: isOpen ? () => _showRecordClientFeeModal(context, isOpen, openReason) : null,
                                icon: const Icon(Icons.person_add_alt_1_outlined, size: 14),
                                label: const Text('Record Client Fee', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tokens.brandPrimaryDark,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: tokens.surfaceSubtle,
                                  disabledForegroundColor: tokens.textMuted,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  elevation: 0,
                                ),
                              ),
                            ],
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
                  const SizedBox(height: 10),
                  _buildClientFeesList(),
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
                        backgroundColor: tokens.brandPrimaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        disabledBackgroundColor: tokens.surfaceSubtle,
                        disabledForegroundColor: tokens.textMuted,
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
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary),
            ),
            if (help != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: help,
                child: Icon(Icons.help_outline, size: 13, color: tokens.textMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tokens.borderStrong),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: InputBorder.none,
              prefixText: '₦ ',
              prefixStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: tokens.textMuted),
              hintText: '0',
              hintStyle: TextStyle(fontSize: 13, color: tokens.textMuted),
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
    final tokens = IcareSurfaceTokens.of(context);
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
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Subtitle (app.py L1088-1090)
          Text(
            'Collections & Arrears Reconciliation',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tokens.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            'Field collections vs bank deposits & arrears',
            style: TextStyle(fontSize: 12, color: tokens.textMuted),
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
                              tokens.dangerText,
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
                              tokens.successText,
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
                              tokens.dangerText,
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
                              tokens.successText,
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
                        tokens.dangerText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTallyKpi(
                        'Physical Cash Collected',
                        CurrencyFormatter.formatNaira(cashCol),
                        excess > 0 ? '+${CurrencyFormatter.formatNaira(excess)} Excess' : null,
                        tokens.successText,
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
                color: tokens.successBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.successBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: tokens.successDot, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12.5, color: tokens.successText),
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
                color: tokens.infoBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.infoBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: tokens.infoText, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12.5, color: tokens.infoText),
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
                color: tokens.warningBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.warningBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: tokens.warningDot, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12.5, color: tokens.warningText),
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
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: isMobile,
                  iconColor: tokens.textMuted,
                  collapsedIconColor: tokens.textMuted,
                  title: Text(
                    'Non-Paying Clients (${notPaidList.length})',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textSecondary),
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
                                  border: TableBorder.all(color: tokens.borderSubtle, width: 1),
                                  columnWidths: const {
                                    0: FlexColumnWidth(2.5),
                                    1: FlexColumnWidth(1.5),
                                    2: FlexColumnWidth(1.8),
                                    3: FlexColumnWidth(1.8),
                                    4: FlexColumnWidth(2.2),
                                  },
                                  children: [
                                    TableRow(
                                      decoration: BoxDecoration(color: tokens.neutralBg),
                                      children: const [
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
                                          _TableCell(CurrencyFormatter.formatNaira(shortVal), textColor: tokens.dangerText, fontWeight: FontWeight.w700),
                                          _TableCell(isPart ? 'Partial Shortfall' : 'NOT PAID (₦0)', textColor: isPart ? tokens.warningText : tokens.dangerText),
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
                                  side: BorderSide(color: tokens.borderStrong),
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
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary),
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
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: tokens.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary),
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 2),
            Text(
              delta,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: deltaColor ?? tokens.textMuted),
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
    final tokens = IcareSurfaceTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final c1 = _buildSummaryKpiCard('Opening Balance', CurrencyFormatter.formatNaira(openingBalance), tokens.infoText);
        final c2 = _buildSummaryKpiCard('Total Inflows', CurrencyFormatter.formatNaira(totalInflows), tokens.successText);
        final c3 = _buildSummaryKpiCard('Total Outflows', CurrencyFormatter.formatNaira(totalOutflows), tokens.dangerText);
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
    num totalInflows,
    num totalOutflows,
  ) {
    final tokens = IcareSurfaceTokens.of(context);
    // 22 Authoritative Inflow Items
    final inflowItems = [
      ('Opening Balance', (inflows['opening_balance'] ?? 0.0) as num),
      ('Savings Deposit', (inflows['savings_deposit'] ?? 0.0) as num),
      ('Credit Rep (Daily)', (inflows['rep_daily'] ?? 0.0) as num),
      ('Credit Rep (120 Days)', (inflows['rep_120_days'] ?? 0.0) as num),
      ('Credit Rep (12 Weeks)', (inflows['rep_12_weeks'] ?? 0.0) as num),
      ('Credit Rep (24 Weeks)', (inflows['rep_24_weeks'] ?? 0.0) as num),
      ('Credit Rep (Monthly)', (inflows['rep_monthly'] ?? 0.0) as num),
      ('Laps Reserve', (inflows['laps_reserve'] ?? 0.0) as num),
      ('Asset Credit Sales', (inflows['asset_credit_sales'] ?? 0.0) as num),
      ('Cash & Carry', (inflows['cash_and_carry'] ?? 0.0) as num),
      ('Daily 11% Markup', (inflows['daily_11_pct'] ?? 0.0) as num),
      ('Daily 20% Markup', (inflows['daily_20_pct'] ?? 0.0) as num),
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

    // 9 Authoritative Outflow Items
    final outflowItems = [
      ('Active Loan (Daily)', (outflows['active_loan_daily'] ?? 0.0) as num),
      ('Active Loan (120 Days)', (outflows['active_loan_120d'] ?? 0.0) as num),
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
                  border: TableBorder.all(color: tokens.borderSubtle, width: 1),
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(3),
                    3: FlexColumnWidth(2),
                  },
                  children: [
                    // Header Row
                    TableRow(
                      decoration: BoxDecoration(color: tokens.surfaceSubtle),
                      children: [
                        _TableHeaderCell('Inflows (Left / Debit)', color: tokens.successText),
                        _TableHeaderCell('Amount (₦)', align: TextAlign.right, color: tokens.successText),
                        _TableHeaderCell('Outflows (Right / Credit)', color: tokens.dangerText),
                        _TableHeaderCell('Amount (₦)', align: TextAlign.right, color: tokens.dangerText),
                      ],
                    ),
                    // 19 Data Rows
                    for (int i = 0; i < inflowItems.length; i++) ...[
                      TableRow(
                        decoration: BoxDecoration(color: i % 2 == 0 ? tokens.surface : tokens.surfaceSubtle),
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
                    // Totals Footer Row
                    TableRow(
                      decoration: BoxDecoration(color: tokens.neutralBg),
                      children: [
                        _TableCell(
                          'TOTAL INFLOWS (LEFT)',
                          textColor: tokens.successText,
                          fontWeight: FontWeight.w800,
                        ),
                        _TableCell(
                          CurrencyFormatter.formatNaira(totalInflows),
                          align: TextAlign.right,
                          textColor: tokens.successText,
                          fontWeight: FontWeight.w800,
                        ),
                        _TableCell(
                          'TOTAL OUTFLOWS (RIGHT)',
                          textColor: tokens.dangerText,
                          fontWeight: FontWeight.w800,
                        ),
                        _TableCell(
                          CurrencyFormatter.formatNaira(totalOutflows),
                          align: TextAlign.right,
                          textColor: tokens.dangerText,
                          fontWeight: FontWeight.w800,
                        ),
                      ],
                    ),
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
    final tokens = IcareSurfaceTokens.of(context);
    return IcareCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      topAccentColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10.5, color: tokens.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
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
    final tokens = IcareSurfaceTokens.of(context);
    final isPos = closing >= 0;
    final accentCol = isPos ? tokens.successDot : tokens.dangerDot;
    final textCol = isPos ? tokens.successText : tokens.dangerText;

    return IcareCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      topAccentColor: accentCol,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLOSING BALANCE',
            style: TextStyle(fontSize: 10.5, color: tokens.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.4),
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
    required bool isOpen,
    required String openReason,
    bool isMobile = false,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Caption (app.py L11081-11082)
          Text(
            'Error Corrections & Reversals',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            'Request BM approval to reverse an erroneous fee, expense, or deposit.',
            style: TextStyle(fontSize: 12, color: tokens.textMuted),
          ),
          const SizedBox(height: 14),

          // Expander: Flag an EOD Fee / Expense / Deposit for Reversal (app.py L11084-11153)
          Container(
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: isMobile,
                iconColor: tokens.textMuted,
                collapsedIconColor: tokens.textMuted,
                title: Text(
                  'Request Transaction Reversal',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tokens.textPrimary),
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
                            color: tokens.infoBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: tokens.infoBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: tokens.infoText, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Select a recent EOD transaction to flag for BM approval.',
                                  style: TextStyle(fontSize: 12, color: tokens.infoText),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        if (reversalOptions.isNotEmpty) ...[
                          // Select Transaction Dropdown (app.py L11132)
                          Text(
                            'Select Transaction',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: tokens.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: tokens.borderStrong),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                dropdownColor: tokens.surfaceElevated,
                                value: reversalOptions.any((o) => o['record_id'] == _selectedRevOptionId)
                                    ? _selectedRevOptionId
                                    : reversalOptions.first['record_id'] as String,
                                icon: Icon(Icons.keyboard_arrow_down, size: 18, color: tokens.textMuted),
                                items: reversalOptions.map((o) {
                                  final id = o['record_id'] as String;
                                  final label = (o['label'] ?? id).toString();
                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(
                                      label,
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                                    ),
                                  );
                                }).toList(),
                                onChanged: !isOpen
                                    ? null
                                    : (val) {
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
                          Text(
                            'Reason for Reversal',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: isOpen ? tokens.surface : tokens.surfaceSubtle,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: tokens.borderStrong),
                            ),
                            child: TextField(
                              controller: _revReasonCtrl,
                              enabled: isOpen,
                              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'e.g., Typo in expense amount',
                                hintStyle: TextStyle(fontSize: 12, color: tokens.textMuted),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Submit Button (app.py L11135)
                          ElevatedButton.icon(
                            onPressed: (_isSubmittingReversal || !isOpen)
                                ? null
                                : () => _handleReversalRequest(isOpen, openReason),
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
                              backgroundColor: tokens.brandPrimaryDark,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: tokens.surfaceSubtle,
                              disabledForegroundColor: tokens.textMuted,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                          ),
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No recent EOD transactions available to flag.',
                              style: TextStyle(fontSize: 12.5, color: tokens.textMuted, fontStyle: FontStyle.italic),
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
          Text(
            'Submitted Requests',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.textPrimary),
          ),
          const SizedBox(height: 8),

          if (submittedReversals.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No reversal requests submitted yet.',
                style: TextStyle(fontSize: 12.5, color: tokens.textMuted, fontStyle: FontStyle.italic),
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
                    border: TableBorder.all(color: tokens.borderSubtle, width: 1),
                    columnWidths: const {
                      0: FlexColumnWidth(2.2),
                      1: FlexColumnWidth(1.2),
                      2: FlexColumnWidth(1.4),
                      3: FlexColumnWidth(3.5),
                      4: FlexColumnWidth(1.4),
                      5: FlexColumnWidth(1.8),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: tokens.neutralBg),
                        children: const [
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
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
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
              'Error loading cashbook projection: $error',
              style: TextStyle(color: tokens.dangerText, fontSize: 13),
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
    final tokens = IcareSurfaceTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color ?? tokens.textSecondary,
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
    final tokens = IcareSurfaceTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          color: textColor ?? tokens.textPrimary,
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
    final tokens = IcareSurfaceTokens.of(context);
    Color bg = tokens.warningBg;
    Color text = tokens.warningText;

    final sLower = status.toLowerCase();
    if (sLower.contains('approved') || sLower.contains('active')) {
      bg = tokens.successBg;
      text = tokens.successText;
    } else if (sLower.contains('reject') || sLower.contains('denied')) {
      bg = tokens.dangerBg;
      text = tokens.dangerText;
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

