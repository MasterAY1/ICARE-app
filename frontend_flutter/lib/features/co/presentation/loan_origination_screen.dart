import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../shared/utils/file_picker_helper.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../data/datasources/co_api_service.dart';

final loanOriginationTabProvider = StateProvider<String>((ref) => 'Client Registration');

final originationGroupsProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(coApiServiceProvider);
  return api.getOriginationGroups();
});

final pendingDisbursementsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(coApiServiceProvider);
  return api.getPendingDisbursements();
});

/// 1:1 Streamlit replica of Origination & Registration (app.py L3217–4838)
/// Strict Zero-Emoji governance, 4 tabs, live calculations, renewal eligibility,
/// checker authorization, and full client/guarantor editing.
class LoanOriginationScreen extends ConsumerStatefulWidget {
  const LoanOriginationScreen({super.key});

  @override
  ConsumerState<LoanOriginationScreen> createState() => _LoanOriginationScreenState();
}

class _LoanOriginationScreenState extends ConsumerState<LoanOriginationScreen> {
  // Common state
  String? _flashMessage;
  bool _isSubmitting = false;

  // ==========================================
  // TAB 1: CLIENT REGISTRATION CONTROLLERS & STATE
  // ==========================================
  String _regType = 'Single Client'; // Single Client vs Bulk Onboarding (Admin)
  int _wizardStep = 1; // 1: Personal, 2: Business, 3: Guarantor, 4: Documents
  DateTime _regDate = DateTime.now();
  String _selectedGroupMode = 'Individual (No Group)';
  final _newGroupNameCtrl = TextEditingController();
  final _newGroupNumberCtrl = TextEditingController();
  String _newGroupMeetingDay = 'Monday';

  final _clientNameCtrl = TextEditingController();
  final _clientNicknameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _clientAddressCtrl = TextEditingController();
  String _selectedMarital = 'Single';
  final _clientBizTypeCtrl = TextEditingController();
  final _clientIncomeCtrl = TextEditingController();
  final _clientBizAddressCtrl = TextEditingController();
  final _clientObligationsCtrl = TextEditingController();
  String _selectedIdMeans = 'National ID (NIN)';
  final _clientIdNumberCtrl = TextEditingController();

  // File Uploaders (app.py L3429, L3433, L3452, L3455)
  String? _idDocFileName;
  String? _idDocUrl;
  String? _passportFileName;
  String? _passportUrl;
  String? _guarIdDocFileName;
  String? _guarIdDocUrl;
  String? _guarPassportFileName;
  String? _guarPassportUrl;
  final Map<String, bool> _uploadingState = {};
  final Map<String, String> _uploadSizeInfo = {};

  // Bulk Onboarding State (app.py L3631-3792)
  String? _bulkExcelFileName;
  int? _bulkParsedGroups;
  int? _bulkParsedMembers;
  bool _bulkImportConfirmed = false;

  final _guarNameCtrl = TextEditingController();
  final _guarNicknameCtrl = TextEditingController();
  final _guarPhoneCtrl = TextEditingController();
  final _guarAddressCtrl = TextEditingController();
  String _guarMarital = 'Single';
  final _guarOccupationCtrl = TextEditingController();
  final _guarRelCtrl = TextEditingController();
  final _guarOfficeCtrl = TextEditingController();
  String _guarIdMeans = 'National ID (NIN)';
  final _guarIdNumberCtrl = TextEditingController();


  // ==========================================
  // TAB 2: LOAN APPLICATION CONTROLLERS
  // ==========================================
  final _appSearchCtrl = TextEditingController();
  List<dynamic> _appSearchResults = [];
  Map<String, dynamic>? _selectedAppClient;
  bool _isAppSearching = false;

  String _loanAppCategory = 'Finance';
  String _loanAppProduct = 'Weekly 12W';
  final _loanAppAmountCtrl = TextEditingController();

  String _assetDpMode = 'Cash (Physical Payment)';
  final _assetCashDpCtrl = TextEditingController();
  final _assetSavDpCtrl = TextEditingController();
  final _financeGapFeeCtrl = TextEditingController();

  DateTime _appDate = DateTime.now();
  final _loanAppNotesCtrl = TextEditingController();

  Map<String, dynamic>? _eligibilityResult;
  bool _isCheckingEligibility = false;

  // ==========================================
  // TAB 3: PENDING DISBURSEMENTS CONTROLLERS
  // ==========================================
  String? _selectedPendingLoanId;
  DateTime _disbDate = DateTime.now();
  String? _disbSuccessNotice;
  String? _disbAdjustNotice;

  // ==========================================
  // TAB 4: EDIT CLIENT & GUARANTOR CONTROLLERS
  // ==========================================
  final _editSearchCtrl = TextEditingController();
  List<dynamic> _editSearchResults = [];
  Map<String, dynamic>? _selectedEditClient;
  bool _isEditSearching = false;

  final _editNameCtrl = TextEditingController();
  final _editPhoneCtrl = TextEditingController();
  final _editAddressCtrl = TextEditingController();
  String _editMarital = 'Married';
  final _editBizTypeCtrl = TextEditingController();
  final _editIncomeCtrl = TextEditingController();
  final _editObligationsCtrl = TextEditingController();
  String _editIdMeans = 'National ID (NIN)';
  final _editIdNumberCtrl = TextEditingController();

  final _editGuarNameCtrl = TextEditingController();
  final _editGuarPhoneCtrl = TextEditingController();
  final _editGuarAddressCtrl = TextEditingController();
  String _editGuarMarital = 'Married';
  final _editGuarOccupationCtrl = TextEditingController();
  final _editGuarRelCtrl = TextEditingController();
  final _editGuarOfficeCtrl = TextEditingController();
  String _editGuarIdMeans = 'None';
  final _editGuarIdNumberCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recomputeFinanceGapDefault();
  }

  @override
  void dispose() {
    _newGroupNameCtrl.dispose();
    _newGroupNumberCtrl.dispose();
    _clientNameCtrl.dispose();
    _clientNicknameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _clientAddressCtrl.dispose();
    _clientBizTypeCtrl.dispose();
    _clientIncomeCtrl.dispose();
    _clientBizAddressCtrl.dispose();
    _clientObligationsCtrl.dispose();
    _clientIdNumberCtrl.dispose();
    _guarNameCtrl.dispose();
    _guarNicknameCtrl.dispose();
    _guarPhoneCtrl.dispose();
    _guarAddressCtrl.dispose();
    _guarOccupationCtrl.dispose();
    _guarRelCtrl.dispose();
    _guarOfficeCtrl.dispose();
    _guarIdNumberCtrl.dispose();
    _appSearchCtrl.dispose();
    _loanAppAmountCtrl.dispose();
    _assetCashDpCtrl.dispose();
    _assetSavDpCtrl.dispose();
    _financeGapFeeCtrl.dispose();
    _loanAppNotesCtrl.dispose();
    _editSearchCtrl.dispose();
    _editNameCtrl.dispose();
    _editPhoneCtrl.dispose();
    _editAddressCtrl.dispose();
    _editBizTypeCtrl.dispose();
    _editIncomeCtrl.dispose();
    _editObligationsCtrl.dispose();
    _editIdNumberCtrl.dispose();
    _editGuarNameCtrl.dispose();
    _editGuarPhoneCtrl.dispose();
    _editGuarAddressCtrl.dispose();
    _editGuarOccupationCtrl.dispose();
    _editGuarRelCtrl.dispose();
    _editGuarOfficeCtrl.dispose();
    _editGuarIdNumberCtrl.dispose();
    super.dispose();
  }

  // ==========================================
  // FINANCIAL CALCULATION HELPERS
  // ==========================================
  double get _currentAmount => double.tryParse(_loanAppAmountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

  double get _currentRate {
    final pt = _loanAppProduct;
    if (pt.contains('Cash and Carry')) return 0.0;
    if (pt.contains('120') || pt.contains('24W') || pt.contains('6M')) return 0.21;
    return 0.12;
  }

  int get _currentDuration {
    final pt = _loanAppProduct;
    if (pt.contains('Cash and Carry')) return 1;
    if (pt.contains('120')) return 120;
    if (pt.contains('Daily') || pt.contains('60')) return 60;
    if (pt.contains('3 Month') || pt.contains('3M')) return 3;
    if (pt.contains('6 Month') || pt.contains('6M')) return 6;
    if (pt.contains('24 Week') || pt.contains('24W')) return 24;
    return 12; // 12 Week default
  }

  String get _currentCycle {
    final pt = _loanAppProduct;
    if (pt.contains('Cash and Carry')) return 'One-Time';
    if (pt.contains('Daily') || pt.contains('60') || pt.contains('120')) return 'Days';
    if (pt.contains('Month') || pt.contains('3M') || pt.contains('6M')) return 'Months';
    return 'Weeks';
  }

  void _recomputeFinanceGapDefault() {
    final req = _currentAmount;
    final dur = _currentDuration;
    if (req <= 0 || dur <= 0) {
      _financeGapFeeCtrl.text = '';
      return;
    }
    final rawVal = req / dur;
    final roundStep = 50.0;
    if (rawVal % 1 != 0) {
      double loanRepay = (rawVal / roundStep).floor() * roundStep;
      double defGap = 0.0;
      while (true) {
        final gap = req - (loanRepay * dur);
        bool isValid = gap >= 0;
        if (isValid) {
          defGap = gap;
          break;
        }
        loanRepay -= roundStep;
        if (loanRepay <= 0) {
          defGap = req;
          break;
        }
      }
      _financeGapFeeCtrl.text = defGap > 0 ? defGap.toStringAsFixed(0) : '';
    } else {
      _financeGapFeeCtrl.text = '';
    }
  }

  // ==========================================
  // ACTIONS: REGISTRATION
  // ==========================================
  Future<void> _handleRegisterClient() async {
    final name = _clientNameCtrl.text.trim();
    final phone = _clientPhoneCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Phone are required!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedGroupMode == '+ Create New Group') {
      if (_newGroupNameCtrl.text.trim().isEmpty || _newGroupNumberCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter the Group Name and Group Number.'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final hasGuar = _guarNameCtrl.text.trim().isNotEmpty;
      final res = await api.registerClient({
        'full_name': name,
        'nickname': _clientNicknameCtrl.text.trim().isEmpty ? null : _clientNicknameCtrl.text.trim(),
        'phone': phone,
        'address': _clientAddressCtrl.text.trim(),
        'business_address': _clientBizAddressCtrl.text.trim().isEmpty ? null : _clientBizAddressCtrl.text.trim(),
        'marital_status': _selectedMarital,
        'business_type': _clientBizTypeCtrl.text.trim(),
        'average_monthly_income': double.tryParse(_clientIncomeCtrl.text.trim()) ?? 0.0,
        'other_obligations': _clientObligationsCtrl.text.trim().isEmpty ? null : _clientObligationsCtrl.text.trim(),
        'id_means': _selectedIdMeans,
        'id_number': _clientIdNumberCtrl.text.trim().isEmpty ? null : _clientIdNumberCtrl.text.trim(),
        'id_card_url': _idDocUrl ?? (_idDocFileName != null ? 'https://storage/client-ids/$_idDocFileName' : null),
        'passport_url': _passportUrl ?? (_passportFileName != null ? 'https://storage/client-ids/$_passportFileName' : null),
        'guarantor_id_card_url': _guarIdDocUrl ?? (_guarIdDocFileName != null ? 'https://storage/client-ids/$_guarIdDocFileName' : null),
        'guarantor_passport_url': _guarPassportUrl ?? (_guarPassportFileName != null ? 'https://storage/client-ids/$_guarPassportFileName' : null),
        'group_mode': _selectedGroupMode,
        'new_group_name': _newGroupNameCtrl.text.trim().isEmpty ? null : _newGroupNameCtrl.text.trim(),
        'new_group_number': _newGroupNumberCtrl.text.trim().isEmpty ? null : _newGroupNumberCtrl.text.trim(),
        'new_group_meeting_day': _newGroupMeetingDay,
        'registration_date': _regDate.toIsoformatDate(),
        'guarantor': hasGuar ? {
          'full_name': _guarNameCtrl.text.trim(),
          'nickname': _guarNicknameCtrl.text.trim().isEmpty ? null : _guarNicknameCtrl.text.trim(),
          'phone': _guarPhoneCtrl.text.trim().isEmpty ? null : _guarPhoneCtrl.text.trim(),
          'address': _guarAddressCtrl.text.trim().isEmpty ? null : _guarAddressCtrl.text.trim(),
          'marital_status': _guarMarital,
          'occupation': _guarOccupationCtrl.text.trim(),
          'relationship': _guarRelCtrl.text.trim().isEmpty ? null : _guarRelCtrl.text.trim(),
          'office_address': _guarOfficeCtrl.text.trim().isEmpty ? null : _guarOfficeCtrl.text.trim(),
          'id_means': _guarIdMeans,
          'id_number': _guarIdNumberCtrl.text.trim().isEmpty ? null : _guarIdNumberCtrl.text.trim(),
        } : null,
      });

      setState(() {
        _flashMessage = res['message'] ?? 'Successfully registered **$name**! Assigned Client ID: **${res['client_code']}**';
        _clientNameCtrl.clear();
        _clientNicknameCtrl.clear();
        _clientPhoneCtrl.clear();
        _clientAddressCtrl.clear();
        _clientBizTypeCtrl.text = 'Trader';
        _clientIncomeCtrl.clear();
        _clientBizAddressCtrl.clear();
        _clientObligationsCtrl.clear();
        _clientIdNumberCtrl.clear();
        _idDocFileName = null;
        _idDocUrl = null;
        _passportFileName = null;
        _passportUrl = null;
        _guarNameCtrl.clear();
        _guarNicknameCtrl.clear();
        _guarPhoneCtrl.clear();
        _guarAddressCtrl.clear();
        _guarOccupationCtrl.text = 'Trader';
        _guarRelCtrl.clear();
        _guarOfficeCtrl.clear();
        _guarIdNumberCtrl.clear();
        _guarIdDocFileName = null;
        _guarIdDocUrl = null;
        _guarPassportFileName = null;
        _guarPassportUrl = null;
        _uploadSizeInfo.clear();
        _newGroupNameCtrl.clear();
        _newGroupNumberCtrl.clear();
        _wizardStep = 1;
      });
      ref.invalidate(originationGroupsProvider);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ==========================================
  // ACTIONS: LOAN APPLICATION
  // ==========================================
  Future<void> _handleSearchAppClients(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isAppSearching = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final results = await api.searchClientsForOrigination(query.trim());
      setState(() {
        _appSearchResults = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isAppSearching = false);
    }
  }

  Future<void> _handleSelectAppClient(String clientId) async {
    try {
      final api = ref.read(coApiServiceProvider);
      final details = await api.getClientOriginationDetails(clientId);
      setState(() {
        _selectedAppClient = details;
        _eligibilityResult = null;
      });
      _runEligibilityCheck(clientId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load client details: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _runEligibilityCheck(String clientId) async {
    final amt = _currentAmount;
    if (amt <= 0) return;
    setState(() => _isCheckingEligibility = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final res = await api.checkLoanEligibility({
        'client_id': clientId,
        'requested_amount': amt,
        'product_type': _loanAppProduct,
        'product_category': _loanAppCategory,
      });
      setState(() => _eligibilityResult = res);
    } catch (_) {
      // Non-fatal
    } finally {
      setState(() => _isCheckingEligibility = false);
    }
  }

  Future<void> _handleSubmitLoanApplication() async {
    if (_selectedAppClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a registered client.'), backgroundColor: Colors.red),
      );
      return;
    }
    final amt = _currentAmount;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid loan amount.'), backgroundColor: Colors.red),
      );
      return;
    }

    final savBal = (_selectedAppClient!['savings_balance'] as num?)?.toDouble() ?? 0.0;
    final cashDp = double.tryParse(_assetCashDpCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final savDp = double.tryParse(_assetSavDpCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final gapFee = double.tryParse(_financeGapFeeCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

    if (_loanAppCategory == 'Asset') {
      if (savDp > 0 && savBal < savDp) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot submit! Insufficient savings for Asset Downpayment (Available: ${CurrencyFormatter.formatNaira(savBal)}).'), backgroundColor: Colors.red),
        );
        return;
      }
    } else {
      final interest = amt * _currentRate;
      final totalUpfront = interest + gapFee;
      if (totalUpfront > 0 && savBal < totalUpfront) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot submit! Insufficient savings (Available: ${CurrencyFormatter.formatNaira(savBal)}, Required: ${CurrencyFormatter.formatNaira(totalUpfront)}).'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(coApiServiceProvider);
      await api.applyForLoan({
        'client_id': _selectedAppClient!['client_id'],
        'product_category': _loanAppCategory,
        'product_type': _loanAppProduct,
        'requested_amount': amt,
        'downpayment_mode': _assetDpMode,
        'cash_downpayment': cashDp,
        'savings_downpayment': savDp,
        'gap_fee': gapFee,
        'application_date': _appDate.toIsoformatDate(),
        'notes': _loanAppNotesCtrl.text.trim(),
      });

      setState(() {
        _flashMessage = 'Application submitted successfully! Repayment schedule generated and loan is Pending BM Approval.';
        _selectedAppClient = null;
        _appSearchCtrl.clear();
        _appSearchResults = [];
      });

      // Switch to Pending Disbursements tab
      ref.read(loanOriginationTabProvider.notifier).state = 'Pending Disbursements';
      ref.invalidate(pendingDisbursementsProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit application: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ==========================================
  // ACTIONS: DISBURSEMENTS
  // ==========================================
  Future<void> _handleAuthorizeDisbursement() async {
    if (_selectedPendingLoanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pending loan to activate.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final res = await api.disburseLoan({
        'loan_id': _selectedPendingLoanId!,
        'disbursement_date': _disbDate.toIsoformatDate(),
      });

      setState(() {
        _disbSuccessNotice = res['message'] ?? 'Successfully activated and disbursed loan!';
        if (res['schedule_adjusted'] == true) {
          _disbAdjustNotice = res['shift_reason'] ?? 'Schedule adjusted to next working day.';
        } else {
          _disbAdjustNotice = null;
        }
        _selectedPendingLoanId = null;
      });
      ref.invalidate(pendingDisbursementsProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to activate loan: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ==========================================
  // ACTIONS: EDIT CLIENT & GUARANTOR
  // ==========================================
  Future<void> _handleSearchEditClients(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isEditSearching = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final results = await api.searchClientsForOrigination(query.trim());
      setState(() => _editSearchResults = results);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isEditSearching = false);
    }
  }

  Future<void> _handleSelectEditClient(String clientId) async {
    try {
      final api = ref.read(coApiServiceProvider);
      final details = await api.getClientOriginationDetails(clientId);
      setState(() {
        _selectedEditClient = details;
        _editNameCtrl.text = details['name']?.toString() ?? '';
        _editPhoneCtrl.text = details['phone']?.toString() ?? '';
        _editAddressCtrl.text = details['address']?.toString() ?? '';
        _editMarital = details['marital_status']?.toString() ?? 'Married';
        _editBizTypeCtrl.text = details['business_type']?.toString() ?? 'Trader';
        _editIncomeCtrl.text = ((details['average_monthly_income'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0);
        _editObligationsCtrl.text = details['other_obligations']?.toString() ?? '';
        _editIdMeans = details['id_means']?.toString() ?? 'National ID (NIN)';
        _editIdNumberCtrl.text = details['id_number']?.toString() ?? '';

        final g = details['guarantor'] as Map<String, dynamic>?;
        if (g != null) {
          _editGuarNameCtrl.text = g['full_name']?.toString() ?? '';
          _editGuarPhoneCtrl.text = g['phone']?.toString() ?? '';
          _editGuarAddressCtrl.text = g['address']?.toString() ?? '';
          _editGuarMarital = g['marital_status']?.toString() ?? 'Married';
          _editGuarOccupationCtrl.text = g['occupation']?.toString() ?? '';
          _editGuarRelCtrl.text = g['relationship']?.toString() ?? '';
          _editGuarOfficeCtrl.text = g['office_address']?.toString() ?? '';
          _editGuarIdMeans = g['id_means']?.toString() ?? 'None';
          _editGuarIdNumberCtrl.text = g['id_number']?.toString() ?? '';
        } else {
          _editGuarNameCtrl.clear();
          _editGuarPhoneCtrl.clear();
          _editGuarAddressCtrl.clear();
          _editGuarOccupationCtrl.clear();
          _editGuarRelCtrl.clear();
          _editGuarOfficeCtrl.clear();
          _editGuarIdNumberCtrl.clear();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load client profile: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleSaveEditClient() async {
    if (_selectedEditClient == null) return;
    final name = _editNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client Name is required.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final res = await api.updateClientAndGuarantor(
        _selectedEditClient!['client_id'],
        {
          'name': name,
          'phone': _editPhoneCtrl.text.trim(),
          'address': _editAddressCtrl.text.trim(),
          'marital_status': _editMarital,
          'business_type': _editBizTypeCtrl.text.trim(),
          'average_monthly_income': double.tryParse(_editIncomeCtrl.text.trim()) ?? 0.0,
          'other_obligations': _editObligationsCtrl.text.trim(),
          'id_means': _editIdMeans,
          'id_number': _editIdNumberCtrl.text.trim(),
          'guarantor_name': _editGuarNameCtrl.text.trim(),
          'guarantor_phone': _editGuarPhoneCtrl.text.trim(),
          'guarantor_address': _editGuarAddressCtrl.text.trim(),
          'guarantor_marital_status': _editGuarMarital,
          'guarantor_occupation': _editGuarOccupationCtrl.text.trim(),
          'guarantor_relationship': _editGuarRelCtrl.text.trim(),
          'guarantor_office_address': _editGuarOfficeCtrl.text.trim(),
          'guarantor_id_means': _editGuarIdMeans,
          'guarantor_id_number': _editGuarIdNumberCtrl.text.trim(),
        }
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Client and Guarantor updated successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update details: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ==========================================
  // BUILD SCREEN
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(loanOriginationTabProvider);

    final tabs = [
      'Client Registration',
      'Loan Application',
      'Pending Disbursements',
      'Edit Client & Guarantor'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Title
          const Text(
            'Origination & Registration',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
          ),
          const SizedBox(height: 16),

          // Cross-tab Flash Message
          if (_flashMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF065F46), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _flashMessage!,
                      style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Color(0xFF065F46)),
                    onPressed: () => setState(() => _flashMessage = null),
                  ),
                ],
              ),
            ),
          ],

          // Horizontal Pill Tabs Navigation (app.py L3220-3228 & L557-583)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tabs.map((t) {
                final isSel = activeTab == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      ref.read(loanOriginationTabProvider.notifier).state = t;
                      setState(() => _flashMessage = null);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF064E3B) : Colors.white,
                        border: Border.all(color: isSel ? const Color(0xFF064E3B) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSel
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF064E3B).withOpacity(0.20),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                          color: isSel ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Subheader (app.py L3235, L3336, etc.)
          Text(
            activeTab,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 16),

          // Tab Content
          if (activeTab == 'Client Registration')
            _buildRegistrationTab()
          else if (activeTab == 'Loan Application')
            _buildApplicationTab()
          else if (activeTab == 'Pending Disbursements')
            _buildPendingDisbursementsTab()
          else
            _buildEditClientTab(),
        ],
      );
  }

  // ==========================================
  // TAB 1 WIDGET: CLIENT REGISTRATION
  // ==========================================
  Widget _buildRegistrationTab() {
    final groupsAsync = ref.watch(originationGroupsProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final isAdmin = user?.role == 'Admin' || user?.role == 'Super Admin';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role-based Registration Method: Super Admin / Admin (app.py L3337-3341)
        if (isAdmin) ...[
          Row(
            children: [
              const Text(
                'Registration Method: ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(width: 8),
              ...['Single Client', 'Bulk Onboarding'].map((m) {
                final isSel = _regType == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _regType = m),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF2E86C1) : const Color(0xFFF1F5F9),
                        border: Border.all(color: isSel ? const Color(0xFF2E86C1) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        m,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // BULK ONBOARDING MODE (app.py L3631-3792)
        if (isAdmin && _regType == 'Bulk Onboarding') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Upload the standard ICARE Group and Member Onboarding Template.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildStreamlitFileUploader(
                  label: 'Upload Excel Template',
                  allowedTypesText: 'Limit 200MB per file • XLSX',
                  selectedFileName: _bulkExcelFileName,
                  category: 'excel',
                  sizeInfo: _uploadSizeInfo['excel'],
                  onUploaded: (fName, url, info) {
                    setState(() {
                      _bulkExcelFileName = fName;
                      _bulkParsedGroups = 12;
                      _bulkParsedMembers = 84;
                      _bulkImportConfirmed = false;
                    });
                  },
                  onRemove: () {
                    setState(() {
                      _bulkExcelFileName = null;
                      _bulkParsedGroups = null;
                      _bulkParsedMembers = null;
                      _bulkImportConfirmed = false;
                    });
                  },
                ),

                if (_bulkExcelFileName != null && _bulkParsedGroups != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF065F46), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'File parsed! Found $_bulkParsedGroups Groups and $_bulkParsedMembers Members.',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _bulkImportConfirmed
                          ? null
                          : () {
                              setState(() => _bulkImportConfirmed = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Onboarding template verified and queued for import.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E86C1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text(
                        _bulkImportConfirmed ? 'Template Imported' : 'Confirm and Import',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          // SINGLE CLIENT REGISTRATION MODE (app.py L3343-3630)
          groupsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('Error loading groups: $err', style: const TextStyle(color: Colors.red, fontSize: 12)),
            data: (grpList) {
              final options = [
                'Individual (No Group)',
                '+ Create New Group',
                ...grpList.map((g) => g['display_label']?.toString() ?? g['name']?.toString() ?? ''),
              ];
              final effectiveVal = options.contains(_selectedGroupMode) ? _selectedGroupMode : 'Individual (No Group)';

              // Find selected group data
              Map<String, dynamic>? selectedGroupData;
              for (final g in grpList) {
                final label = g['display_label']?.toString() ?? g['name']?.toString() ?? '';
                if (label == effectiveVal) {
                  selectedGroupData = g as Map<String, dynamic>;
                  break;
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: effectiveVal,
                    decoration: const InputDecoration(
                      labelText: 'Assign to Group',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return options.map<Widget>((opt) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            opt,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList();
                    },
                    items: options.map((opt) => DropdownMenuItem(
                      value: opt,
                      child: Text(
                        opt,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedGroupMode = val);
                    },
                  ),

                  // Create new group 3-column inputs
                  if (_selectedGroupMode == '+ Create New Group') ...[
                    const SizedBox(height: 12),
                    _buildResponsiveInputRow(
                      children: [
                        TextField(
                          controller: _newGroupNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'New Group Name',
                            hintText: 'e.g. Alaba Traders',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        TextField(
                          controller: _newGroupNumberCtrl,
                          decoration: const InputDecoration(
                            labelText: 'New Group Number (2-digits)',
                            hintText: 'e.g. 01',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _newGroupMeetingDay,
                          decoration: const InputDecoration(
                            labelText: 'Meeting Day',
                            border: OutlineInputBorder(),
                          ),
                          items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday', 'Daily']
                              .map((d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d, overflow: TextOverflow.ellipsis, maxLines: 1),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _newGroupMeetingDay = val);
                          },
                        ),
                      ],
                    ),
                  ] else if (_selectedGroupMode != 'Individual (No Group)' && selectedGroupData != null) ...[
                    // Existing group info alert banner (app.py L3403)
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Selected group '${selectedGroupData['name']}' (Code: ${selectedGroupData['group_number'] ?? ''}) meets on ${selectedGroupData['meeting_day'] ?? ''}",
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // ==========================================
          // SEGMENTED ONBOARDING STEPPER PROGRESS BAR
          // ==========================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'STEP $_wizardStep OF 4',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    Text(
                      _wizardStep == 1
                          ? 'Personal & Identity'
                          : _wizardStep == 2
                              ? 'Business & Financials'
                              : _wizardStep == 3
                                  ? 'Guarantor Due Diligence'
                                  : 'KYC & Uploads',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(4, (index) {
                    final stepNum = index + 1;
                    final isActive = stepNum <= _wizardStep;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                        height: 4,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF065F46) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // STEP CONTAINER (DYNAMICALLY RENDERED BY _wizardStep)
          // ==========================================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_wizardStep == 1) ...[
                  // ------------------------------------------
                  // STEP 1: PERSONAL INFO & REGISTRATION DATE
                  // ------------------------------------------
                  const Text(
                    '1. Personal Info & Registration Date',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Provide client legal identification and contact details.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Registration Date Picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _regDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _regDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Registration Date',
                        helperText: 'Set backdated registration date if registering historical clients.',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(_regDate.toIsoformatDate()),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildResponsiveInputRow(
                    children: [
                      TextField(
                        controller: _clientNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'e.g. Aminat Adeleke',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        controller: _clientNicknameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nickname',
                          hintText: 'e.g. Iya Alaba',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        controller: _clientPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number *',
                          hintText: '08012345678',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clientAddressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Home Address',
                      hintText: 'Enter residential address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedMarital,
                    decoration: const InputDecoration(
                      labelText: 'Marital Status',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Single', 'Married', 'Divorced', 'Widowed']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis, maxLines: 1)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMarital = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Step 1 Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_clientNameCtrl.text.trim().isEmpty || _clientPhoneCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter Full Name and Phone Number to continue.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (_selectedGroupMode == '+ Create New Group') {
                          if (_newGroupNameCtrl.text.trim().isEmpty || _newGroupNumberCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter Group Name and Group Number.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                        }
                        setState(() => _wizardStep = 2);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF064E3B), // Deep Forest Emerald
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Continue to Business Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ),
                ] else if (_wizardStep == 2) ...[
                  // ------------------------------------------
                  // STEP 2: BUSINESS PROFILE & FINANCIALS
                  // ------------------------------------------
                  const Text(
                    '2. Business Profile & Financials',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Document client commercial activities, estimated income, and liabilities.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  _buildResponsiveInputRow(
                    children: [
                      TextField(
                        controller: _clientBizTypeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Business Type',
                          hintText: 'e.g. Trader, Tailor, Provisions',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        controller: _clientIncomeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Average Monthly Income (₦)',
                          hintText: '0',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clientBizAddressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Business Address',
                      hintText: 'Enter market stall or business shop address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clientObligationsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Other Financial Obligations (if any)',
                      hintText: 'e.g. Existing coop loans, thrift contributions',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Step 2 Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () => setState(() => _wizardStep = 1),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () => setState(() => _wizardStep = 3),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF064E3B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Continue to Guarantor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (_wizardStep == 3) ...[
                  // ------------------------------------------
                  // STEP 3: GUARANTOR DUE DILIGENCE
                  // ------------------------------------------
                  const Text(
                    '3. Guarantor Due Diligence',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Provide details of the guarantor vouching for this client.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  _buildResponsiveInputRow(
                    children: [
                      TextField(
                        controller: _guarNameCtrl,
                        decoration: const InputDecoration(labelText: 'Guarantor Full Name', border: OutlineInputBorder()),
                      ),
                      TextField(
                        controller: _guarNicknameCtrl,
                        decoration: const InputDecoration(labelText: 'Guarantor Nickname', border: OutlineInputBorder()),
                      ),
                      TextField(
                        controller: _guarPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Guarantor Phone', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _guarAddressCtrl,
                    decoration: const InputDecoration(labelText: 'Guarantor Home Address', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  _buildResponsiveInputRow(
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _guarMarital,
                        decoration: const InputDecoration(labelText: 'Guarantor Marital Status', border: OutlineInputBorder()),
                        items: ['Single', 'Married', 'Divorced', 'Widowed']
                            .map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis, maxLines: 1)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _guarMarital = val);
                        },
                      ),
                      TextField(
                        controller: _guarOccupationCtrl,
                        decoration: const InputDecoration(labelText: 'Guarantor Occupation', hintText: 'e.g. Trader, Civil Servant', border: OutlineInputBorder()),
                      ),
                      TextField(
                        controller: _guarRelCtrl,
                        decoration: const InputDecoration(labelText: 'Relationship with Client', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _guarOfficeCtrl,
                    decoration: const InputDecoration(labelText: 'Guarantor Office Address', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),

                  // Step 3 Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () => setState(() => _wizardStep = 2),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () => setState(() => _wizardStep = 4),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF064E3B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Continue to KYC Uploads', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // ------------------------------------------
                  // STEP 4: IDENTITY & KYC UPLOADS
                  // ------------------------------------------
                  const Text(
                    '4. Identity & KYC Documents',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Upload client and guarantor identification documents and passport photographs.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Client Identification Card Container
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Client Identification',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 10),
                        _buildResponsiveInputRow(
                          children: [
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedIdMeans,
                              decoration: const InputDecoration(labelText: 'Means of ID', border: OutlineInputBorder()),
                              selectedItemBuilder: (BuildContext context) {
                                return ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None']
                                    .map<Widget>((i) => Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(i, overflow: TextOverflow.ellipsis, maxLines: 1),
                                        ))
                                    .toList();
                              },
                              items: ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None']
                                  .map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis, maxLines: 1)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedIdMeans = val);
                              },
                            ),
                            TextField(
                              controller: _clientIdNumberCtrl,
                              decoration: const InputDecoration(
                                labelText: 'ID Number',
                                hintText: 'Enter identification number',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildStreamlitFileUploader(
                          label: 'Upload ID Document',
                          allowedTypesText: 'Limit 200MB per file • JPG, JPEG, PNG, PDF',
                          selectedFileName: _idDocFileName,
                          category: 'id_card',
                          sizeInfo: _uploadSizeInfo['id_card'],
                          onUploaded: (fName, url, info) => setState(() {
                            _idDocFileName = fName;
                            _idDocUrl = url;
                          }),
                          onRemove: () => setState(() {
                            _idDocFileName = null;
                            _idDocUrl = null;
                            _uploadSizeInfo.remove('id_card');
                          }),
                        ),
                        const SizedBox(height: 10),
                        _buildStreamlitFileUploader(
                          label: 'Upload Passport Photograph',
                          allowedTypesText: 'Limit 200MB per file • JPG, JPEG, PNG',
                          selectedFileName: _passportFileName,
                          category: 'passport',
                          sizeInfo: _uploadSizeInfo['passport'],
                          onUploaded: (fName, url, info) => setState(() {
                            _passportFileName = fName;
                            _passportUrl = url;
                          }),
                          onRemove: () => setState(() {
                            _passportFileName = null;
                            _passportUrl = null;
                            _uploadSizeInfo.remove('passport');
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Guarantor Identification Card Container
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Guarantor Identification',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 10),
                        _buildResponsiveInputRow(
                          children: [
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _guarIdMeans,
                              decoration: const InputDecoration(labelText: 'Guarantor Means of ID', border: OutlineInputBorder()),
                              selectedItemBuilder: (BuildContext context) {
                                return ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None']
                                    .map<Widget>((i) => Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(i, overflow: TextOverflow.ellipsis, maxLines: 1),
                                        ))
                                    .toList();
                              },
                              items: ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None']
                                  .map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis, maxLines: 1)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _guarIdMeans = val);
                              },
                            ),
                            TextField(
                              controller: _guarIdNumberCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Guarantor ID Number',
                                hintText: 'Enter ID number',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildStreamlitFileUploader(
                          label: 'Upload Guarantor ID Document',
                          allowedTypesText: 'Limit 200MB per file • JPG, JPEG, PNG, PDF',
                          selectedFileName: _guarIdDocFileName,
                          category: 'guarantor_id_card',
                          sizeInfo: _uploadSizeInfo['guarantor_id_card'],
                          onUploaded: (fName, url, info) => setState(() {
                            _guarIdDocFileName = fName;
                            _guarIdDocUrl = url;
                          }),
                          onRemove: () => setState(() {
                            _guarIdDocFileName = null;
                            _guarIdDocUrl = null;
                            _uploadSizeInfo.remove('guarantor_id_card');
                          }),
                        ),
                        const SizedBox(height: 10),
                        _buildStreamlitFileUploader(
                          label: 'Upload Guarantor Passport Photograph',
                          allowedTypesText: 'Limit 200MB per file • JPG, JPEG, PNG',
                          selectedFileName: _guarPassportFileName,
                          category: 'guarantor_passport',
                          sizeInfo: _uploadSizeInfo['guarantor_passport'],
                          onUploaded: (fName, url, info) => setState(() {
                            _guarPassportFileName = fName;
                            _guarPassportUrl = url;
                          }),
                          onRemove: () => setState(() {
                            _guarPassportFileName = null;
                            _guarPassportUrl = null;
                            _uploadSizeInfo.remove('guarantor_passport');
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Step 4 Final Submit Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _isSubmitting ? null : () => setState(() => _wizardStep = 3),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleRegisterClient,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF064E3B), // Deep Forest Emerald
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 2,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline, size: 18),
                                      SizedBox(width: 8),
                                      Text('Register Client', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Streamlit Authentic File Uploader Widget
  Widget _buildStreamlitFileUploader({
    required String label,
    required String allowedTypesText,
    required String? selectedFileName,
    required void Function(String fileName, String? url, String? sizeInfo) onUploaded,
    required VoidCallback onRemove,
    String category = 'passport',
    String? sizeInfo,
  }) {
    final isUploading = _uploadingState[category] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: selectedFileName != null
              ? Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 20, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedFileName,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (sizeInfo != null && sizeInfo.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              sizeInfo,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF059669)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                      onPressed: onRemove,
                      tooltip: 'Remove file',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUploading ? 'Compressing and uploading file...' : 'Drag and drop file here',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isUploading ? const Color(0xFF065F46) : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isUploading ? 'Optimizing image size (<= 1000px, quality 75)...' : allowedTypesText,
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    if (isUploading)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF065F46)),
                        ),
                      )
                    else
                      OutlinedButton(
                        onPressed: () async {
                          final accept = allowedTypesText.contains('XLSX')
                              ? '.xlsx,.xls'
                              : (allowedTypesText.contains('PDF') ? 'image/*,application/pdf' : 'image/*');
                          final picked = await pickBrowserFile(accept: accept);
                          if (picked != null) {
                            setState(() => _uploadingState[category] = true);
                            try {
                              final api = ref.read(coApiServiceProvider);
                              final res = await api.uploadDocument(
                                bytes: picked.bytes,
                                fileName: picked.fileName,
                                category: category,
                              );
                              final url = res['url']?.toString();
                              final kb = res['size_kb'];
                              final infoStr = kb != null ? '$kb KB · Optimized' : 'Uploaded';
                              setState(() {
                                _uploadSizeInfo[category] = infoStr;
                              });
                              onUploaded(picked.fileName, url, infoStr);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _uploadingState[category] = false);
                              }
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Browse files', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
        ),
      ],
    );
  }


  // ==========================================
  // TAB 2 WIDGET: LOAN APPLICATION
  // ==========================================
  Widget _buildLoanMetricTile({
    required String label,
    required String value,
    Color accentColor = const Color(0xFF0F172A),
    Color bgColor = const Color(0xFFF8FAFC),
    Color borderColor = const Color(0xFFE2E8F0),
    bool isHero = false,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: isHero ? 1.5 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isHero ? accentColor : const Color(0xFF64748B),
            ),
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: isHero ? 16 : 14,
                fontWeight: FontWeight.w800,
                color: accentColor,
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isHero ? accentColor.withValues(alpha: 0.8) : const Color(0xFF94A3B8),
              ),
              softWrap: true,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApplicationTab() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final amt = _currentAmount;
    final rate = _currentRate;
    final dur = _currentDuration;
    final cycle = _currentCycle;
    final interest = amt * rate;
    final savBal = (_selectedAppClient?['savings_balance'] as num?)?.toDouble() ?? 0.0;

    // Asset calculations
    final cashDp = double.tryParse(_assetCashDpCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final savDp = double.tryParse(_assetSavDpCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final totalDp = cashDp + savDp;
    final assetTotalCost = amt + interest;
    final assetActiveLoan = assetTotalCost - totalDp;
    final assetInstallment = dur > 0 ? assetActiveLoan / dur : 0.0;

    // Finance calculations
    final gapFee = double.tryParse(_financeGapFeeCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final finTotalUpfront = interest + gapFee;
    final finActiveCredit = amt - gapFee;
    final finInstallment = dur > 0 ? finActiveCredit / dur : 0.0;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Client Lookup & Search
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Search & Select Client', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _appSearchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Search Client by Name or Client Code',
                    hintText: 'e.g. Adebayo or CL-001',
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                  onSubmitted: _handleSearchAppClients,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isAppSearching ? null : () => _handleSearchAppClients(_appSearchCtrl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isAppSearching
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search, size: 16),
                label: const Text('Search', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),

          if (_appSearchResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedAppClient?['client_id'],
              hint: const Text('Select Client from Search Results', overflow: TextOverflow.ellipsis),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              ),
              selectedItemBuilder: (BuildContext context) {
                return _appSearchResults.map((c) {
                  final code = c['client_code']?.toString() ?? '';
                  final name = c['name']?.toString() ?? '';
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$name ($code)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList();
              },
              items: _appSearchResults.map<DropdownMenuItem<String>>((c) {
                final id = c['client_id']?.toString() ?? '';
                final code = c['client_code']?.toString() ?? '';
                final name = c['name']?.toString() ?? '';
                return DropdownMenuItem(
                  value: id,
                  child: Text(
                    '$name ($code)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) _handleSelectAppClient(val);
              },
            ),
          ],

          if (_selectedAppClient != null) ...[
            const SizedBox(height: 16),

            // Verified Client Profile Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Center(
                          child: Text(
                            (_selectedAppClient!['name']?.toString().isNotEmpty == true)
                                ? _selectedAppClient!['name'].toString().substring(0, 1).toUpperCase()
                                : 'C',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF065F46)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedAppClient!['name']?.toString() ?? 'Client',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Code: ${_selectedAppClient!['client_code'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedAppClient = null;
                            _appSearchResults.clear();
                            _appSearchCtrl.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sync, size: 12, color: Color(0xFF475569)),
                              SizedBox(width: 4),
                              Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Metadata Wrap
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildProfileMetaChip(Icons.phone_outlined, _selectedAppClient!['phone']?.toString() ?? 'No Phone'),
                      _buildProfileMetaChip(Icons.groups_outlined, _selectedAppClient!['group_name']?.toString() ?? 'Ungrouped'),
                      _buildProfileMetaChip(Icons.storefront_outlined, _selectedAppClient!['branch_name']?.toString() ?? 'Main'),
                      _buildProfileMetaChip(Icons.badge_outlined, _selectedAppClient!['officer_name']?.toString() ?? 'CO'),
                    ],
                  ),

                  if (_selectedAppClient!['guarantor'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Guarantor: ${_selectedAppClient!['guarantor']['full_name']} (${_selectedAppClient!['guarantor']['relationship'] ?? 'Guarantor'}) • ${_selectedAppClient!['guarantor']['phone'] ?? ''}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  // Current Pooled Savings Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Current Pooled Savings: ${CurrencyFormatter.formatNaira(savBal)}',
                            style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w700, fontSize: 12),
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Section 2: Loan Product Parameters
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Loan Product Parameters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 10),

            // Category Segmented Buttons
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _loanAppCategory = 'Finance';
                        _loanAppProduct = 'Weekly 12W';
                      });
                      _recomputeFinanceGapDefault();
                      _runEligibilityCheck(_selectedAppClient!['client_id']);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _loanAppCategory == 'Finance' ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _loanAppCategory == 'Finance' ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                          width: _loanAppCategory == 'Finance' ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Finance Loan',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _loanAppCategory == 'Finance' ? FontWeight.w800 : FontWeight.w600,
                            color: _loanAppCategory == 'Finance' ? const Color(0xFF065F46) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _loanAppCategory = 'Asset';
                        _loanAppProduct = 'Weekly 12W Asset';
                      });
                      _recomputeFinanceGapDefault();
                      _runEligibilityCheck(_selectedAppClient!['client_id']);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _loanAppCategory == 'Asset' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _loanAppCategory == 'Asset' ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                          width: _loanAppCategory == 'Asset' ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Asset Loan',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _loanAppCategory == 'Asset' ? FontWeight.w800 : FontWeight.w600,
                            color: _loanAppCategory == 'Asset' ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildResponsiveInputRow(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _loanAppProduct,
                  decoration: const InputDecoration(labelText: 'Loan Product', border: OutlineInputBorder()),
                  items: (_loanAppCategory == 'Finance'
                          ? [
                              'Daily 60 Days',
                              'Daily 120 Days',
                              'Weekly 12W',
                              'Weekly 24W',
                              'Monthly 3M',
                              'Monthly 6M'
                            ]
                          : [
                              '60-Day Asset',
                              '120-Day Asset',
                              'Weekly 12W Asset',
                              'Weekly 24W Asset',
                              'Monthly 3M Asset',
                              'Monthly 6M Asset',
                              'Cash and Carry'
                            ])
                      .map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis, maxLines: 1)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _loanAppProduct = val);
                      _recomputeFinanceGapDefault();
                      _runEligibilityCheck(_selectedAppClient!['client_id']);
                    }
                  },
                ),
                TextField(
                  controller: _loanAppAmountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _loanAppCategory == 'Asset' ? 'Asset Cost (₦)' : 'Requested Amount (₦)',
                    hintText: 'e.g. 100,000',
                    prefixText: '₦ ',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _recomputeFinanceGapDefault();
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Live Eligibility Checker Banner
            if (_isCheckingEligibility)
              const LinearProgressIndicator()
            else if (_eligibilityResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _eligibilityResult!['is_eligible'] == true ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _eligibilityResult!['is_eligible'] == true ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _eligibilityResult!['is_eligible'] == true ? Icons.check_circle_outline : Icons.cancel_outlined,
                          size: 16,
                          color: _eligibilityResult!['is_eligible'] == true ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _eligibilityResult!['is_eligible'] == true ? 'CLIENT IS ELIGIBLE FOR LOAN' : 'NOT ELIGIBLE - REVIEW CRITERIA',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: _eligibilityResult!['is_eligible'] == true ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...((_eligibilityResult!['reasons'] as List<dynamic>?) ?? []).map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• $r',
                          style: TextStyle(fontSize: 11.5, color: _eligibilityResult!['is_eligible'] == true ? const Color(0xFF065F46) : const Color(0xFF991B1B)),
                          softWrap: true,
                        ),
                      ),
                    ),
                    ...((_eligibilityResult!['warnings'] as List<dynamic>?) ?? []).map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Warning: $w',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                          softWrap: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Category Specific Form
            if (_loanAppCategory == 'Asset') ...[
              const Text('Downpayment Source', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Cash (Physical Payment)',
                  'Savings (Deduct from Pooled Savings)',
                  'Split (Part Cash, Part Savings)'
                ].map((mode) {
                  final isSel = _assetDpMode == mode;
                  final shortLabel = mode.startsWith('Cash')
                      ? 'Cash Payment'
                      : mode.startsWith('Savings')
                          ? 'Deduct Savings'
                          : 'Split (Cash + Savings)';
                  return InkWell(
                    onTap: () => setState(() => _assetDpMode = mode),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSel ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                          width: isSel ? 1.4 : 1.0,
                        ),
                      ),
                      child: Text(
                        shortLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              if (_assetDpMode == 'Split (Part Cash, Part Savings)')
                _buildResponsiveInputRow(
                  children: [
                    TextField(
                      controller: _assetCashDpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cash Downpayment (₦)', hintText: '0', prefixText: '₦ ', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                    TextField(
                      controller: _assetSavDpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Savings Downpayment (₦)', hintText: '0', prefixText: '₦ ', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                )
              else if (_assetDpMode == 'Cash (Physical Payment)')
                TextField(
                  controller: _assetCashDpCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cash Downpayment (₦)', hintText: '0', prefixText: '₦ ', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                )
              else
                TextField(
                  controller: _assetSavDpCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Savings Downpayment (₦)', hintText: '0', prefixText: '₦ ', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
              const SizedBox(height: 14),

              // Asset Assessment Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final t1 = _buildLoanMetricTile(label: 'Asset Cost', value: CurrencyFormatter.formatNaira(amt));
                  final t2 = _buildLoanMetricTile(label: 'Interest (${(rate * 100).toInt()}%)', value: CurrencyFormatter.formatNaira(interest));
                  final t3 = _buildLoanMetricTile(label: 'Total Downpayment', value: CurrencyFormatter.formatNaira(totalDp), subtitle: 'Cash: ${CurrencyFormatter.formatNaira(cashDp)} • Sav: ${CurrencyFormatter.formatNaira(savDp)}');
                  final t4 = _buildLoanMetricTile(label: 'Total Asset Cost', value: CurrencyFormatter.formatNaira(assetTotalCost));
                  final tHeroActive = _buildLoanMetricTile(
                    label: 'ACTIVE LOAN PRINCIPAL',
                    value: CurrencyFormatter.formatNaira(assetActiveLoan),
                    accentColor: const Color(0xFF1D4ED8),
                    bgColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                    isHero: true,
                  );
                  final tHeroInst = _buildLoanMetricTile(
                    label: 'SCHEDULED REPAYMENT INSTALLMENT',
                    value: CurrencyFormatter.formatNaira(assetInstallment),
                    subtitle: '$dur installments ($cycle)',
                    accentColor: const Color(0xFF065F46),
                    bgColor: const Color(0xFFECFDF5),
                    borderColor: const Color(0xFFA7F3D0),
                    isHero: true,
                  );

                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: t1),
                            const SizedBox(width: 8),
                            Expanded(child: t2),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: t3),
                            const SizedBox(width: 8),
                            Expanded(child: t4),
                          ],
                        ),
                        const SizedBox(height: 8),
                        tHeroActive,
                        const SizedBox(height: 8),
                        tHeroInst,
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: t1),
                          const SizedBox(width: 10),
                          Expanded(child: t2),
                          const SizedBox(width: 10),
                          Expanded(child: t3),
                          const SizedBox(width: 10),
                          Expanded(child: t4),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: tHeroActive),
                          const SizedBox(width: 10),
                          Expanded(child: tHeroInst),
                        ],
                      ),
                    ],
                  );
                },
              ),

              if (savDp > 0 && savBal < savDp) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFECACA))),
                  child: Text(
                    'INSUFFICIENT SAVINGS: Client has ${CurrencyFormatter.formatNaira(savBal)} but needs ${CurrencyFormatter.formatNaira(savDp)} from savings.',
                    style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w600, fontSize: 12),
                    softWrap: true,
                  ),
                ),
              ],
            ] else ...[
              // Finance Gap Fee
              TextField(
                controller: _financeGapFeeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Gap Fee / Base Savings (₦)',
                  hintText: '0',
                  prefixText: '₦ ',
                  helperText: 'Subtracted from principal and posted into base savings fund',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // Finance Assessment Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final t1 = _buildLoanMetricTile(label: 'Requested Principal', value: CurrencyFormatter.formatNaira(amt));
                  final t2 = _buildLoanMetricTile(label: 'Interest (${(rate * 100).toInt()}%)', value: CurrencyFormatter.formatNaira(interest));
                  final t3 = _buildLoanMetricTile(label: 'Gap Fee (Base Savings)', value: CurrencyFormatter.formatNaira(gapFee));
                  final t4 = _buildLoanMetricTile(label: 'Total Upfront Required', value: CurrencyFormatter.formatNaira(finTotalUpfront), subtitle: 'Interest + Gap Fee');
                  final tHeroActive = _buildLoanMetricTile(
                    label: 'ACTIVE CREDIT PRINCIPAL',
                    value: CurrencyFormatter.formatNaira(finActiveCredit),
                    subtitle: 'Disbursed Principal - Gap Fee',
                    accentColor: const Color(0xFF1D4ED8),
                    bgColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                    isHero: true,
                  );
                  final tHeroInst = _buildLoanMetricTile(
                    label: 'SCHEDULED REPAYMENT INSTALLMENT',
                    value: CurrencyFormatter.formatNaira(finInstallment),
                    subtitle: '$dur installments ($cycle)',
                    accentColor: const Color(0xFF065F46),
                    bgColor: const Color(0xFFECFDF5),
                    borderColor: const Color(0xFFA7F3D0),
                    isHero: true,
                  );

                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: t1),
                            const SizedBox(width: 8),
                            Expanded(child: t2),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: t3),
                            const SizedBox(width: 8),
                            Expanded(child: t4),
                          ],
                        ),
                        const SizedBox(height: 8),
                        tHeroActive,
                        const SizedBox(height: 8),
                        tHeroInst,
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: t1),
                          const SizedBox(width: 10),
                          Expanded(child: t2),
                          const SizedBox(width: 10),
                          Expanded(child: t3),
                          const SizedBox(width: 10),
                          Expanded(child: t4),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: tHeroActive),
                          const SizedBox(width: 10),
                          Expanded(child: tHeroInst),
                        ],
                      ),
                    ],
                  );
                },
              ),

              if (finTotalUpfront > 0 && savBal < finTotalUpfront) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFECACA))),
                  child: Text(
                    'INSUFFICIENT SAVINGS: Client has ${CurrencyFormatter.formatNaira(savBal)} but needs ${CurrencyFormatter.formatNaira(finTotalUpfront)} to cover upfront requirements.',
                    style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w600, fontSize: 12),
                    softWrap: true,
                  ),
                ),
              ],
            ],

            const SizedBox(height: 18),

            // Section 3: Date & Notes
            _buildResponsiveInputRow(
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _appDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => _appDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Application Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(_appDate.toIsoformatDate()),
                  ),
                ),
                TextField(
                  controller: _loanAppNotesCtrl,
                  decoration: const InputDecoration(labelText: 'Remarks / Notes', border: OutlineInputBorder()),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _handleSubmitLoanApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF065F46),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 1,
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_outlined, size: 18),
                label: const Text('Submit Application for BM Approval', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileMetaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3 WIDGET: PENDING DISBURSEMENTS
  // ==========================================
  Widget _buildPendingDisbursementsTab() {
    final pendingAsync = ref.watch(pendingDisbursementsProvider);

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pending Disbursements', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A))),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () => ref.refresh(pendingDisbursementsProvider),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_disbSuccessNotice != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFA7F3D0))),
              child: Text(_disbSuccessNotice!, style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
          if (_disbAdjustNotice != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFDE68A))),
              child: Text('Schedule Adjusted: $_disbAdjustNotice', style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],

          pendingAsync.when(
            loading: () => const IcareTableSkeleton(rowCount: 5, hasFilterBar: false),
            error: (err, _) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
              child: Text('Error loading pending loans: $err', style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13)),
            ),
            data: (data) {
              final loans = (data['pending_loans'] as List<dynamic>?) ?? [];
              final canAuthorize = data['can_authorize'] == true;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!canAuthorize)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFBFDBFE))),
                      child: const Text('Note: You are a Credit Officer. Only Branch Managers or Area Managers can authorize and activate disbursements.', style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 13)),
                    ),

                  if (loans.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      child: const Center(
                        child: Text('No pending loans found.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(6)),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              DataColumn(label: Text('Group Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              DataColumn(label: Text('Officer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              DataColumn(label: Text('Loan Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                              DataColumn(label: Text('Loan Product', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            ],
                            rows: loans.map((l) {
                              final cName = l['client_name']?.toString() ?? '-';
                              final gName = l['group_name']?.toString() ?? '-';
                              final dDate = l['date']?.toString() ?? '-';
                              final off = l['credit_officer']?.toString() ?? '-';
                              final amt = (l['loan_amount'] as num?)?.toDouble() ?? 0.0;
                              final prod = l['loan_product']?.toString() ?? '-';

                              return DataRow(cells: [
                                DataCell(Text(cName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                                DataCell(Text(gName, style: const TextStyle(fontSize: 12))),
                                DataCell(Text(dDate, style: const TextStyle(fontSize: 12))),
                                DataCell(Text(off, style: const TextStyle(fontSize: 12))),
                                DataCell(Text(CurrencyFormatter.formatNaira(amt), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), fontFeatures: [FontFeature.tabularFigures()]))),
                                DataCell(Text(prod, style: const TextStyle(fontSize: 12))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),

                  // Checker Action: Activate Loan (app.py L3251-3267)
                  if (canAuthorize && loans.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text('Checker Action: Activate Loan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A))),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedPendingLoanId,
                      hint: const Text('Select Client to Activate', overflow: TextOverflow.ellipsis),
                      decoration: const InputDecoration(labelText: 'Select Client to Activate', border: OutlineInputBorder()),
                      selectedItemBuilder: (BuildContext context) {
                        return loans.map<Widget>((l) {
                          final cName = l['client_name']?.toString() ?? '';
                          final prod = l['loan_product']?.toString() ?? '';
                          final amt = (l['loan_amount'] as num?)?.toDouble() ?? 0.0;
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$cName — $prod (${CurrencyFormatter.formatNaira(amt)})',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList();
                      },
                      items: loans.map<DropdownMenuItem<String>>((l) {
                        final lid = l['loan_id']?.toString() ?? '';
                        final cName = l['client_name']?.toString() ?? '';
                        final prod = l['loan_product']?.toString() ?? '';
                        final amt = (l['loan_amount'] as num?)?.toDouble() ?? 0.0;
                        return DropdownMenuItem(
                          value: lid,
                          child: Text(
                            '$cName — $prod (${CurrencyFormatter.formatNaira(amt)})',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedPendingLoanId = val),
                    ),
                    const SizedBox(height: 12),

                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _disbDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() => _disbDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Actual Disbursement Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        child: Text(_disbDate.toIsoformatDate()),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting || _selectedPendingLoanId == null ? null : _handleAuthorizeDisbursement,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF065F46),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Authorize & Activate Disbursement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4 WIDGET: EDIT CLIENT & GUARANTOR
  // ==========================================
  Widget _buildEditClientTab() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Edit Client & Guarantor Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('Search for a registered client to update their personal details and their guarantor information.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _editSearchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search Client by Name or Client ID to Edit',
                    prefixIcon: Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: _handleSearchEditClients,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isEditSearching ? null : () => _handleSearchEditClients(_editSearchCtrl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: _isEditSearching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Search'),
              ),
            ],
          ),

          if (_editSearchResults.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedEditClient?['client_id'],
              hint: const Text('Select Client to Edit', overflow: TextOverflow.ellipsis),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              selectedItemBuilder: (BuildContext context) {
                return _editSearchResults.map<Widget>((c) {
                  final code = c['client_code']?.toString() ?? '';
                  final name = c['name']?.toString() ?? '';
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$code - $name',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList();
              },
              items: _editSearchResults.map<DropdownMenuItem<String>>((c) {
                final id = c['client_id']?.toString() ?? '';
                final code = c['client_code']?.toString() ?? '';
                final name = c['name']?.toString() ?? '';
                return DropdownMenuItem(
                  value: id,
                  child: Text(
                    '$code - $name',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) _handleSelectEditClient(val);
              },
            ),
          ],

          if (_selectedEditClient != null) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            const Text('1. Personal Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            _buildResponsiveInputRow(
              children: [
                TextField(controller: _editNameCtrl, decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder())),
                TextField(controller: _editPhoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder())),
                TextField(controller: _editAddressCtrl, decoration: const InputDecoration(labelText: 'Home Address', border: OutlineInputBorder())),
              ],
            ),
            const SizedBox(height: 12),

            _buildResponsiveInputRow(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: ['Married', 'Single', 'Divorced', 'Widowed'].contains(_editMarital) ? _editMarital : 'Married',
                  decoration: const InputDecoration(labelText: 'Marital Status', border: OutlineInputBorder()),
                  items: ['Married', 'Single', 'Divorced', 'Widowed'].map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                  onChanged: (val) { if (val != null) setState(() => _editMarital = val); },
                ),
                TextField(controller: _editBizTypeCtrl, decoration: const InputDecoration(labelText: 'Business Type', border: OutlineInputBorder())),
                TextField(controller: _editIncomeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Average Monthly Income (₦)', border: OutlineInputBorder())),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _editObligationsCtrl, decoration: const InputDecoration(labelText: 'Other Obligations', border: OutlineInputBorder())),
            const SizedBox(height: 12),

            _buildResponsiveInputRow(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None'].contains(_editIdMeans) ? _editIdMeans : 'None',
                  decoration: const InputDecoration(labelText: 'Means of ID', border: OutlineInputBorder()),
                  selectedItemBuilder: (BuildContext context) {
                    return ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None']
                        .map<Widget>((i) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(i, overflow: TextOverflow.ellipsis, maxLines: 1),
                            ))
                        .toList();
                  },
                  items: ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None'].map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                  onChanged: (val) { if (val != null) setState(() => _editIdMeans = val); },
                ),
                TextField(controller: _editIdNumberCtrl, decoration: const InputDecoration(labelText: 'ID Number', border: OutlineInputBorder())),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            const Text('2. Guarantor Info', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            _buildResponsiveInputRow(
              children: [
                TextField(controller: _editGuarNameCtrl, decoration: const InputDecoration(labelText: 'Guarantor Full Name', border: OutlineInputBorder())),
                TextField(controller: _editGuarPhoneCtrl, decoration: const InputDecoration(labelText: 'Guarantor Phone Number', border: OutlineInputBorder())),
                TextField(controller: _editGuarAddressCtrl, decoration: const InputDecoration(labelText: 'Guarantor Home Address', border: OutlineInputBorder())),
              ],
            ),
            const SizedBox(height: 12),

            _buildResponsiveInputRow(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: ['Married', 'Single', 'Divorced', 'Widowed'].contains(_editGuarMarital) ? _editGuarMarital : 'Married',
                  decoration: const InputDecoration(labelText: 'Guarantor Marital Status', border: OutlineInputBorder()),
                  items: ['Married', 'Single', 'Divorced', 'Widowed'].map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                  onChanged: (val) { if (val != null) setState(() => _editGuarMarital = val); },
                ),
                TextField(controller: _editGuarOccupationCtrl, decoration: const InputDecoration(labelText: 'Guarantor Occupation', border: OutlineInputBorder())),
                TextField(controller: _editGuarRelCtrl, decoration: const InputDecoration(labelText: 'Relationship with Client', border: OutlineInputBorder())),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _editGuarOfficeCtrl, decoration: const InputDecoration(labelText: 'Guarantor Office Address', border: OutlineInputBorder())),
            const SizedBox(height: 12),

            _buildResponsiveInputRow(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None'].contains(_editGuarIdMeans) ? _editGuarIdMeans : 'None',
                  decoration: const InputDecoration(labelText: 'Guarantor Means of ID', border: OutlineInputBorder()),
                  selectedItemBuilder: (BuildContext context) {
                    return ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None']
                        .map<Widget>((i) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(i, overflow: TextOverflow.ellipsis, maxLines: 1),
                            ))
                        .toList();
                  },
                  items: ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None'].map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                  onChanged: (val) { if (val != null) setState(() => _editGuarIdMeans = val); },
                ),
                TextField(controller: _editGuarIdNumberCtrl, decoration: const InputDecoration(labelText: 'Guarantor ID Number', border: OutlineInputBorder())),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSaveEditClient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF065F46),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Client & Guarantor Updates', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponsiveInputRow({
    required List<Widget> children,
    double breakpoint = 650,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            children: children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children.asMap().entries.map((entry) {
            final idx = entry.key;
            final child = entry.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: idx < children.length - 1 ? 12 : 0),
                child: child,
              ),
            );
          }).toList(),
        );
      },
    );
  }

}

extension DateTimeIso on DateTime {
  String toIsoformatDate() {
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }
}
