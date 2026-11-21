import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../shared/utils/file_picker_helper.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../../../core/errors/app_error_formatter.dart';
import '../../../core/offline/offline_database_service.dart';
import '../data/datasources/co_api_service.dart';
import 'widgets/asset_catalog_picker_card.dart';
import 'package:frontend_flutter/core/theme/icare_motion.dart';

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
  String? _selectedGroupId;
  bool _regDateTouched = false;
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
  bool _appDateTouched = false;
  final _loanAppNotesCtrl = TextEditingController();

  Map<String, dynamic>? _eligibilityResult;
  bool _isCheckingEligibility = false;
  Map<String, dynamic>? _schedulePreview;
  bool _isLoadingSchedule = false;
  Timer? _calcDebounce;

  // Asset Catalog & Branch Inventory State
  List<Map<String, dynamic>> _assetCatalogItems = [];
  List<Map<String, dynamic>> _assetCatalogCategories = [];
  Map<String, dynamic> _assetCatalogSummary = {};
  String _assetBranchName = '';
  bool _isLoadingAssetCatalog = false;
  bool _isOfflineAssetCatalog = false;
  String? _assetCatalogError;
  final List<Map<String, dynamic>> _selectedAssetCart = [];

  // ==========================================
  // TAB 3: PENDING DISBURSEMENTS CONTROLLERS
  // ==========================================
  String? _selectedPendingLoanId;
  DateTime _disbDate = DateTime.now();
  bool _disbDateTouched = false;
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
  final _editNicknameCtrl = TextEditingController();
  final _editPhoneCtrl = TextEditingController();
  final _editAddressCtrl = TextEditingController();
  final _editBizAddressCtrl = TextEditingController();
  String _editMarital = 'Married';
  final _editBizTypeCtrl = TextEditingController();
  final _editIncomeCtrl = TextEditingController();
  final _editObligationsCtrl = TextEditingController();
  String _editIdMeans = 'National ID (NIN)';
  final _editIdNumberCtrl = TextEditingController();

  final _editGuarNameCtrl = TextEditingController();
  final _editGuarNicknameCtrl = TextEditingController();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBranchBusinessDate();
      _loadBranchAssetCatalog();
    });
  }

  Future<void> _loadBranchBusinessDate() async {
    try {
      final api = ref.read(coApiServiceProvider);
      final res = await api.getOriginationBusinessDate();
      final raw = res['business_date']?.toString();
      if (raw != null && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null && mounted) {
          setState(() {
            if (!_regDateTouched) _regDate = parsed;
            if (!_appDateTouched) _appDate = parsed;
            if (!_disbDateTouched) _disbDate = parsed;
          });
        }
      }
    } catch (_) {
      // Non-fatal fallback keeps local date
    }
  }

  @override
  void dispose() {
    _calcDebounce?.cancel();
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
    _editNicknameCtrl.dispose();
    _editPhoneCtrl.dispose();
    _editAddressCtrl.dispose();
    _editBizAddressCtrl.dispose();
    _editBizTypeCtrl.dispose();
    _editIncomeCtrl.dispose();
    _editObligationsCtrl.dispose();
    _editIdNumberCtrl.dispose();
    _editGuarNameCtrl.dispose();
    _editGuarNicknameCtrl.dispose();
    _editGuarPhoneCtrl.dispose();
    _editGuarAddressCtrl.dispose();
    _editGuarOccupationCtrl.dispose();
    _editGuarRelCtrl.dispose();
    _editGuarOfficeCtrl.dispose();
    _editGuarIdNumberCtrl.dispose();
    super.dispose();
  }

  bool get _isAssetOrCashAndCarry =>
      _loanAppCategory == 'Asset' ||
      _loanAppProduct.toLowerCase().contains('cash and carry');

  bool _canManageAssetInventory(AuthUser? user) {
    final role = (user?.role ?? '').trim().toLowerCase();
    return role == 'procurement officer' ||
        role == 'procurement_officer' ||
        role == 'asset manager' ||
        role == 'asset_manager' ||
        role == 'admin' ||
        role == 'super admin';
  }

  Future<void> _loadBranchAssetCatalog() async {
    if (_isLoadingAssetCatalog) return;
    setState(() {
      _isLoadingAssetCatalog = true;
      _assetCatalogError = null;
    });
    final authState = ref.read(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final branchKey = user?.branchId ?? user?.branch ?? 'default';
    final offlineDb = ref.read(offlineDatabaseServiceProvider);

    try {
      final api = ref.read(coApiServiceProvider);
      final res = await api.getBranchAssetCatalog(inStockOnly: false);
      await offlineDb.cacheBranchAssetCatalog(branchKey, res);
      if (!mounted) return;
      _applyAssetCatalogPayload(res, isOffline: false);
    } catch (e) {
      final cached = await offlineDb.getCachedBranchAssetCatalog(branchKey);
      if (!mounted) return;
      if (cached != null) {
        _applyAssetCatalogPayload(cached, isOffline: true);
      } else {
        setState(() {
          _assetCatalogError = 'Unable to load branch inventory (${AppErrorDetails.from(e).message}).';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingAssetCatalog = false);
    }
  }

  void _applyAssetCatalogPayload(Map<String, dynamic> res, {required bool isOffline}) {
    final rawItems = (res['items'] as List<dynamic>?) ?? const [];
    final rawCats = (res['categories'] as List<dynamic>?) ?? const [];
    final rawSum = res['summary'];
    setState(() {
      _assetBranchName = res['branch_name']?.toString() ?? '';
      _assetCatalogItems = rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      _assetCatalogCategories = rawCats.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      _assetCatalogSummary = rawSum is Map ? Map<String, dynamic>.from(rawSum) : {};
      _isOfflineAssetCatalog = isOffline;
      _assetCatalogError = null;
    });
  }

  void _syncAmountFromAssetCart() {
    if (_selectedAssetCart.isEmpty) {
      if (_isAssetOrCashAndCarry) {
        _loanAppAmountCtrl.clear();
      }
      setState(() {});
      _scheduleRefreshCalculations(immediate: true);
      return;
    }
    final totalCash = _selectedAssetCart.fold<double>(0.0, (sum, line) {
      final qty = (line['quantity'] as num?)?.toInt() ?? 1;
      final unitCash = (line['unit_cash_price'] as num?)?.toDouble() ?? 0.0;
      return sum + (qty * unitCash);
    });
    _loanAppAmountCtrl.text = totalCash.toStringAsFixed(0);
    setState(() {});
    _recomputeFinanceGapDefault();
    _scheduleRefreshCalculations(immediate: true);
  }

  Future<double?> _promptCustomUnitPrice(String itemName) async {
    final priceCtrl = TextEditingController();
    double? confirmed;
    await showIcareDialog(
      context: context,
      builder: (ctx) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return AlertDialog(
          backgroundColor: tokens.surfaceElevated,
          title: Text('Enter Approved Price', style: TextStyle(fontWeight: FontWeight.w800, color: tokens.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$itemName is a branch-specific stock item without a fixed October 2026 sheet price. Enter the Cash & Carry price (₦):',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Cash & Carry Price (₦)',
                  prefixText: '₦ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(priceCtrl.text.replaceAll(',', '').trim());
                if (val != null && val > 0) {
                  confirmed = val;
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Apply Price'),
            ),
          ],
        );
      },
    );
    priceCtrl.dispose();
    return confirmed;
  }

  Future<void> _addAssetToCart(Map<String, dynamic> catalogItem) async {
    final iid = catalogItem['item_id']?.toString() ?? '';
    final name = catalogItem['item_name']?.toString() ?? '';
    final avail = (catalogItem['quantity_available'] as num?)?.toInt() ?? 0;
    if (avail <= 0) {
      _showErrorSnack('$name is currently out of stock at this branch.');
      return;
    }

    final existingIdx = _selectedAssetCart.indexWhere((e) => e['item_id'] == iid);
    if (existingIdx >= 0) {
      final currQty = (_selectedAssetCart[existingIdx]['quantity'] as num?)?.toInt() ?? 1;
      if (currQty >= avail) {
        _showErrorSnack('Only $avail unit(s) of $name available in branch stock.');
        return;
      }
      _selectedAssetCart[existingIdx]['quantity'] = currQty + 1;
      _syncAmountFromAssetCart();
      return;
    }

    var cashPrice = (catalogItem['cash_and_carry_price'] as num?)?.toDouble() ?? 0.0;
    var p60 = (catalogItem['easy_buy_60d_price'] as num?)?.toDouble() ?? (cashPrice * 1.12);
    var p120 = (catalogItem['easy_buy_120d_price'] as num?)?.toDouble() ?? (cashPrice * 1.21);

    if (cashPrice <= 0) {
      final entered = await _promptCustomUnitPrice(name);
      if (entered == null || entered <= 0) return;
      cashPrice = entered;
      p60 = double.parse((entered * 1.12).toStringAsFixed(2));
      p120 = double.parse((entered * 1.21).toStringAsFixed(2));
    }

    _selectedAssetCart.add({
      'item_id': iid,
      'sku_code': catalogItem['sku_code']?.toString() ?? '',
      'category': catalogItem['category']?.toString() ?? '',
      'item_name': name,
      'quantity': 1,
      'quantity_available': avail,
      'unit_cash_price': cashPrice,
      'unit_easy_buy_60d_price': p60,
      'unit_easy_buy_120d_price': p120,
    });
    _syncAmountFromAssetCart();
  }

  void _updateAssetCartQty(String itemId, int delta) {
    final idx = _selectedAssetCart.indexWhere((e) => e['item_id'] == itemId);
    if (idx < 0) return;
    final curr = (_selectedAssetCart[idx]['quantity'] as num?)?.toInt() ?? 1;
    final avail = (_selectedAssetCart[idx]['quantity_available'] as num?)?.toInt() ?? curr;
    final next = (curr + delta).clamp(1, avail);
    _selectedAssetCart[idx]['quantity'] = next;
    _syncAmountFromAssetCart();
  }

  void _removeAssetCartItem(String itemId) {
    _selectedAssetCart.removeWhere((e) => e['item_id'] == itemId);
    _syncAmountFromAssetCart();
  }

  void _clearAssetCart() {
    _selectedAssetCart.clear();
    _syncAmountFromAssetCart();
  }

  Future<void> _openAssetCatalogModal() async {
    if (_assetCatalogItems.isEmpty && !_isLoadingAssetCatalog) {
      await _loadBranchAssetCatalog();
    }
    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    await showBranchAssetCatalogDialog(
      context: context,
      branchName: _assetBranchName.isNotEmpty ? _assetBranchName : (user?.branch ?? 'Branch'),
      canManageInventory: _canManageAssetInventory(user),
      initialItems: _assetCatalogItems,
      categories: _assetCatalogCategories,
      summary: _assetCatalogSummary,
      onAdjustItem: (itemId, qtyDelta, newPrice, newCostPrice, remarks) async {
        final api = ref.read(coApiServiceProvider);
        return api.adjustBranchAssetInventory({
          'item_id': itemId,
          'quantity_delta': qtyDelta,
          if (newPrice != null) 'new_cash_price': newPrice,
          if (newCostPrice != null) 'new_cost_price': newCostPrice,
          'remarks': remarks,
        });
      },
      onChanged: () => _loadBranchAssetCatalog(),
    );
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
    if (_loanAppCategory == 'Asset' || _loanAppProduct.contains('Cash and Carry')) {
      _financeGapFeeCtrl.clear();
      return;
    }
    final req = _currentAmount;
    final dur = _currentDuration;
    if (req <= 0 || dur <= 0) {
      _financeGapFeeCtrl.text = '';
      return;
    }
    final rawVal = req / dur;
    final roundStep = _currentCycle == 'Months' ? 100.0 : 50.0;
    if (rawVal % 1 != 0) {
      double loanRepay = (rawVal / roundStep).floor() * roundStep;
      double defGap = 0.0;
      while (true) {
        final gap = req - (loanRepay * dur);
        if (gap >= 0) {
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

  List<String> _getCategoryProducts(String category, AuthUser? user) {
    const allFinance = [
      'Daily 60 Days',
      'Daily 120 Days',
      'Weekly 12W',
      'Weekly 24W',
      'Monthly 3M',
      'Monthly 6M',
    ];
    const allAsset = [
      '60-Day Asset',
      '120-Day Asset',
      'Weekly 12W Asset',
      'Weekly 24W Asset',
      'Monthly 3M Asset',
      'Monthly 6M Asset',
      'Cash and Carry',
    ];

    final baseList = category == 'Finance' ? allFinance : allAsset;
    final allowed = user?.allowedProducts ?? [];
    if (allowed.isNotEmpty) {
      final allowedSet = allowed.map((e) => e.trim().toLowerCase()).toSet();
      final filtered = baseList.where((p) => allowedSet.contains(p.trim().toLowerCase())).toList();
      return filtered;
    }
    return baseList;
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  // ==========================================
  // ACTIONS: REGISTRATION
  // ==========================================
  Future<void> _handleRegisterClient() async {
    final name = _clientNameCtrl.text.trim();
    final phone = _clientPhoneCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      _showErrorSnack('Name and Phone are required!');
      return;
    }

    if (_selectedGroupMode == '+ Create New Group') {
      if (_newGroupNameCtrl.text.trim().isEmpty || _newGroupNumberCtrl.text.trim().isEmpty) {
        _showErrorSnack('Please enter the Group Name and Group Number.');
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
        'id_card_url': _idDocUrl,
        'passport_url': _passportUrl,
        'guarantor_id_card_url': _guarIdDocUrl,
        'guarantor_passport_url': _guarPassportUrl,
        'group_id': _selectedGroupId,
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
        final rawMsg = res['message']?.toString() ?? 'Successfully registered $name! Assigned Client ID: ${res['client_code']}';
        _flashMessage = rawMsg.replaceAll('**', '');
        _selectedGroupMode = 'Individual (No Group)';
        _selectedGroupId = null;
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
      _showErrorSnack(AppErrorDetails.from(e).message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
      _showErrorSnack(AppErrorDetails.from(e).message);
    } finally {
      if (mounted) setState(() => _isAppSearching = false);
    }
  }

  Future<void> _handleSelectAppClient(String clientId) async {
    try {
      final api = ref.read(coApiServiceProvider);
      final details = await api.getClientOriginationDetails(clientId);
      if (!mounted) return;
      setState(() {
        _selectedAppClient = details;
        _eligibilityResult = null;
        _schedulePreview = null;
      });
      _scheduleRefreshCalculations(immediate: true);
    } catch (e) {
      _showErrorSnack(AppErrorDetails.from(e).message);
    }
  }

  void _scheduleRefreshCalculations({bool immediate = false}) {
    _calcDebounce?.cancel();
    if (immediate) {
      if (_selectedAppClient != null) {
        _runEligibilityCheck(_selectedAppClient!['client_id'].toString());
      }
      _loadSchedulePreview();
      return;
    }
    _calcDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (_selectedAppClient != null) {
        _runEligibilityCheck(_selectedAppClient!['client_id'].toString());
      }
      _loadSchedulePreview();
    });
  }

  Future<void> _runEligibilityCheck(String clientId) async {
    final amt = _currentAmount;
    if (amt <= 0) {
      setState(() => _eligibilityResult = null);
      return;
    }
    setState(() => _isCheckingEligibility = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final res = await api.checkLoanEligibility({
        'client_id': clientId,
        'requested_amount': amt,
        'product_type': _loanAppProduct,
        'product_category': _loanAppCategory,
      });
      if (mounted) setState(() => _eligibilityResult = res);
    } catch (_) {
      // Non-fatal
    } finally {
      if (mounted) setState(() => _isCheckingEligibility = false);
    }
  }

  Future<void> _loadSchedulePreview() async {
    final amt = _currentAmount;
    if (amt <= 0) {
      setState(() => _schedulePreview = null);
      return;
    }
    setState(() => _isLoadingSchedule = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final cashDp = double.tryParse(_assetCashDpCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
      final savDp = double.tryParse(_assetSavDpCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
      final gapFee = _loanAppCategory == 'Asset'
          ? 0.0
          : (double.tryParse(_financeGapFeeCtrl.text.replaceAll(',', '').trim()) ?? 0.0);
      final res = await api.previewLoanSchedule({
        'product_category': _loanAppCategory,
        'product_type': _loanAppProduct,
        'requested_amount': amt,
        'downpayment_mode': _assetDpMode,
        'cash_downpayment': cashDp,
        'savings_downpayment': savDp,
        'gap_fee': gapFee,
        'application_date': _appDate.toIsoformatDate(),
        if (_selectedAppClient != null) 'client_id': _selectedAppClient!['client_id'],
      });
      if (mounted) setState(() => _schedulePreview = res);
    } catch (_) {
      // Non-fatal
    } finally {
      if (mounted) setState(() => _isLoadingSchedule = false);
    }
  }

  Future<void> _handleSubmitLoanApplication() async {
    if (_selectedAppClient == null) {
      _showErrorSnack('Please select a registered client.');
      return;
    }
    if (_eligibilityResult != null && _eligibilityResult!['is_eligible'] == false) {
      _showErrorSnack('Client does not meet eligibility rules for this loan request.');
      return;
    }
    final amt = _currentAmount;
    final branchStockUnits = (_assetCatalogSummary['total_units_available'] as num?)?.toInt() ?? 0;
    if (_isAssetOrCashAndCarry && _selectedAssetCart.isEmpty && branchStockUnits > 0) {
      _showErrorSnack('Please select at least one asset item from Branch Asset Stock above.');
      return;
    }
    if (amt <= 0) {
      _showErrorSnack('Please enter a valid loan amount.');
      return;
    }

    final savBal = (_selectedAppClient!['savings_balance'] as num?)?.toDouble() ?? 0.0;
    final cashDp = double.tryParse(_assetCashDpCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final savDp = double.tryParse(_assetSavDpCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final rawGap = double.tryParse(_financeGapFeeCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final isCashAndCarry = _loanAppProduct.contains('Cash and Carry');
    final gapFee = (_loanAppCategory == 'Asset' || isCashAndCarry) ? 0.0 : rawGap;

    if (_loanAppCategory == 'Asset') {
      if (savDp > 0 && savBal < savDp) {
        _showErrorSnack('Cannot submit! Insufficient savings for Asset Downpayment (Available: ${CurrencyFormatter.formatNaira(savBal)}).');
        return;
      }
    } else {
      final interest = amt * _currentRate;
      final totalUpfront = isCashAndCarry ? 0.0 : (interest + gapFee);
      if (totalUpfront > 0 && savBal < totalUpfront) {
        _showErrorSnack('Cannot submit! Insufficient savings (Available: ${CurrencyFormatter.formatNaira(savBal)}, Required: ${CurrencyFormatter.formatNaira(totalUpfront)}).');
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
        if (_selectedAssetCart.isNotEmpty)
          'selected_assets': _selectedAssetCart
              .map((line) => {
                    'item_id': line['item_id'],
                    'sku_code': line['sku_code'],
                    'item_name': line['item_name'],
                    'quantity': line['quantity'],
                    'unit_cash_price': line['unit_cash_price'],
                  })
              .toList(),
      });

      setState(() {
        _flashMessage = 'Application submitted successfully! Repayment schedule generated and loan is Pending Approval.';
        _selectedAppClient = null;
        _eligibilityResult = null;
        _schedulePreview = null;
        _appSearchCtrl.clear();
        _appSearchResults = [];
        _selectedAssetCart.clear();
        _loanAppAmountCtrl.clear();
      });

      // Refresh branch stock (reserved qty updated) and switch to Pending Disbursements tab
      _loadBranchAssetCatalog();
      ref.read(loanOriginationTabProvider.notifier).state = 'Pending Disbursements';
      ref.invalidate(pendingDisbursementsProvider);
    } catch (e) {
      _showErrorSnack(AppErrorDetails.from(e).message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ==========================================
  // ACTIONS: DISBURSEMENTS
  // ==========================================
  Future<void> _handleAuthorizeDisbursement() async {
    if (_selectedPendingLoanId == null) {
      _showErrorSnack('Please select a pending loan to activate.');
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
      _loadBranchAssetCatalog();
      ref.invalidate(pendingDisbursementsProvider);
    } catch (e) {
      _showErrorSnack(AppErrorDetails.from(e).message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleRejectPendingLoan() async {
    final loanId = _selectedPendingLoanId;
    if (loanId == null) {
      _showErrorSnack('Please select a pending loan application to reject.');
      return;
    }

    final reasonCtrl = TextEditingController();
    String? confirmedReason;
    await showIcareDialog(
      context: context,
      builder: (ctx) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return AlertDialog(
          backgroundColor: tokens.surfaceElevated,
          title: Text('Reject Loan Application', style: TextStyle(fontWeight: FontWeight.w800, color: tokens.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejecting this application returns the client status to prior state and immediately releases any reserved asset stock back into available branch inventory.',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason',
                  hintText: 'e.g. Client requested change / incomplete verification',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              onPressed: () {
                confirmedReason = reasonCtrl.text.trim().isEmpty ? 'Not approved' : reasonCtrl.text.trim();
                Navigator.of(ctx).pop();
              },
              child: const Text('Confirm Reject'),
            ),
          ],
        );
      },
    );
    reasonCtrl.dispose();
    if (confirmedReason == null) return;

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final res = await api.rejectPendingLoan(loanId: loanId, reason: confirmedReason!);
      setState(() {
        _disbSuccessNotice = res['message']?.toString() ?? 'Loan application rejected and reserved stock released.';
        _disbAdjustNotice = null;
        _selectedPendingLoanId = null;
      });
      _loadBranchAssetCatalog();
      ref.invalidate(pendingDisbursementsProvider);
    } catch (e) {
      _showErrorSnack(AppErrorDetails.from(e).message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
      _showErrorSnack(AppErrorDetails.from(e).message);
    } finally {
      if (mounted) setState(() => _isEditSearching = false);
    }
  }

  Future<void> _handleSelectEditClient(String clientId) async {
    try {
      final api = ref.read(coApiServiceProvider);
      final details = await api.getClientOriginationDetails(clientId);
      setState(() {
        _selectedEditClient = details;
        _editNameCtrl.text = details['name']?.toString() ?? '';
        _editNicknameCtrl.text = details['nickname']?.toString() ?? '';
        _editPhoneCtrl.text = details['phone']?.toString() ?? '';
        _editAddressCtrl.text = details['address']?.toString() ?? '';
        _editBizAddressCtrl.text = details['business_address']?.toString() ?? '';
        _editMarital = details['marital_status']?.toString() ?? 'Married';
        _editBizTypeCtrl.text = details['business_type']?.toString() ?? 'Trader';
        _editIncomeCtrl.text = ((details['average_monthly_income'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0);
        _editObligationsCtrl.text = details['other_obligations']?.toString() ?? '';
        _editIdMeans = details['id_means']?.toString() ?? 'National ID (NIN)';
        _editIdNumberCtrl.text = details['id_number']?.toString() ?? '';

        final g = details['guarantor'] as Map<String, dynamic>?;
        if (g != null) {
          _editGuarNameCtrl.text = g['full_name']?.toString() ?? '';
          _editGuarNicknameCtrl.text = g['nickname']?.toString() ?? '';
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
          _editGuarNicknameCtrl.clear();
          _editGuarPhoneCtrl.clear();
          _editGuarAddressCtrl.clear();
          _editGuarOccupationCtrl.clear();
          _editGuarRelCtrl.clear();
          _editGuarOfficeCtrl.clear();
          _editGuarIdNumberCtrl.clear();
        }
      });
    } catch (e) {
      _showErrorSnack(AppErrorDetails.from(e).message);
    }
  }

  Future<void> _handleSaveEditClient() async {
    if (_selectedEditClient == null) return;
    final name = _editNameCtrl.text.trim();
    if (name.isEmpty) {
      _showErrorSnack('Client Name is required.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(coApiServiceProvider);
      final res = await api.updateClientAndGuarantor(
        _selectedEditClient!['client_id'],
        {
          'name': name,
          'nickname': _editNicknameCtrl.text.trim(),
          'phone': _editPhoneCtrl.text.trim(),
          'address': _editAddressCtrl.text.trim(),
          'business_address': _editBizAddressCtrl.text.trim(),
          'marital_status': _editMarital,
          'business_type': _editBizTypeCtrl.text.trim(),
          'average_monthly_income': double.tryParse(_editIncomeCtrl.text.trim()) ?? 0.0,
          'other_obligations': _editObligationsCtrl.text.trim(),
          'id_means': _editIdMeans,
          'id_number': _editIdNumberCtrl.text.trim(),
          'guarantor_name': _editGuarNameCtrl.text.trim(),
          'guarantor_nickname': _editGuarNicknameCtrl.text.trim(),
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

      final statusStr = res['status']?.toString();
      if (statusStr == 'PENDING_APPROVAL') {
        showIcareDialog(
          context: context,
          builder: (ctx) {
            final dialogTokens = IcareSurfaceTokens.of(ctx);
            return AlertDialog(
              backgroundColor: dialogTokens.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: dialogTokens.warningDot, size: 24),
                  const SizedBox(width: 8),
                  Text('Pending BM Review', style: TextStyle(fontWeight: FontWeight.bold, color: dialogTokens.textPrimary)),
                ],
              ),
              content: Text(
                res['message'] ?? 'Client profile update request has been submitted and is awaiting Branch Manager approval.',
                style: TextStyle(fontSize: 14, color: dialogTokens.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message'] ?? 'Client and Guarantor updated successfully!',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      AppErrorFormatter.showErrorDialog(context, e);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ==========================================
  // BUILD SCREEN
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
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
          // Title & Quick Catalog Access
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            spacing: 12,
            children: [
              Text(
                'Origination & Registration',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: tokens.textPrimary, letterSpacing: -0.5),
              ),
              OutlinedButton.icon(
                onPressed: _openAssetCatalogModal,
                icon: Icon(Icons.inventory_2_outlined, size: 17, color: tokens.infoText),
                label: Text(
                  'Asset Stock & Price List (${(_assetCatalogSummary['total_units_available'] as num?)?.toInt() ?? 0})',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.infoText),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.infoBorder),
                  backgroundColor: tokens.infoBg,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cross-tab Flash Message
          if (_flashMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: tokens.successBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.successBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: tokens.successText, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _flashMessage!,
                      style: TextStyle(color: tokens.successText, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: tokens.successText),
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
                        color: isSel ? tokens.brandPrimaryDark : tokens.surface,
                        border: Border.all(color: isSel ? tokens.brandPrimaryDark : tokens.borderSubtle),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSel
                            ? [
                                BoxShadow(
                                  color: tokens.brandPrimaryDark.withValues(alpha: tokens.isDark ? 0.35 : 0.20),
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
                          color: isSel ? Colors.white : tokens.textSecondary,
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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: tokens.textPrimary),
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
    final tokens = IcareSurfaceTokens.of(context);
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
              Text(
                'Registration Method: ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary),
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
                        color: isSel ? const Color(0xFF1D4ED8) : tokens.surfaceSubtle,
                        border: Border.all(color: isSel ? const Color(0xFF1D4ED8) : tokens.borderSubtle),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        m,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? Colors.white : tokens.textSecondary,
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
              color: tokens.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: tokens.infoBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.infoBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: tokens.infoText, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Upload the standard ICARE Group and Member Onboarding Template.',
                          style: TextStyle(fontSize: 13, color: tokens.infoText, fontWeight: FontWeight.w500),
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
                      color: tokens.successBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.successBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: tokens.successText, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'File parsed! Found $_bulkParsedGroups Groups and $_bulkParsedMembers Members.',
                            style: TextStyle(fontSize: 13, color: tokens.successText, fontWeight: FontWeight.w600),
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
                                  content: Text(
                                    'Onboarding template verified and queued for import.',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: Color(0xFF15803D),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
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
            error: (err, _) => Text('Error loading groups: ${AppErrorDetails.from(err).message}', style: TextStyle(color: tokens.dangerText, fontSize: 12)),
            data: (grpList) {
              final itemEntries = <Map<String, String?>>[
                {'key': 'Individual (No Group)', 'label': 'Individual (No Group)', 'group_id': null},
                {'key': '+ Create New Group', 'label': '+ Create New Group', 'group_id': null},
                ...grpList.map((g) {
                  final gid = g['group_id']?.toString();
                  final label = g['display_label']?.toString() ?? g['name']?.toString() ?? '';
                  return {
                    'key': gid != null && gid.isNotEmpty ? 'group:$gid' : label,
                    'label': label,
                    'group_id': gid,
                  };
                }),
              ];

              final currentKey = _selectedGroupId != null && itemEntries.any((e) => e['key'] == 'group:$_selectedGroupId')
                  ? 'group:$_selectedGroupId'
                  : (itemEntries.any((e) => e['key'] == _selectedGroupMode) ? _selectedGroupMode : 'Individual (No Group)');

              // Find selected group data
              Map<String, dynamic>? selectedGroupData;
              if (_selectedGroupId != null) {
                for (final g in grpList) {
                  if (g['group_id']?.toString() == _selectedGroupId) {
                    selectedGroupData = g as Map<String, dynamic>;
                    break;
                  }
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: currentKey,
                    dropdownColor: tokens.surfaceElevated,
                    style: TextStyle(fontSize: 14, color: tokens.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Assign to Group',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return itemEntries.map<Widget>((opt) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            opt['label'] ?? '',
                            style: TextStyle(fontSize: 14, color: tokens.textPrimary),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList();
                    },
                    items: itemEntries.map((opt) => DropdownMenuItem<String>(
                      value: opt['key'],
                      child: Text(
                        opt['label'] ?? '',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final matched = itemEntries.firstWhere((e) => e['key'] == val, orElse: () => itemEntries.first);
                        setState(() {
                          _selectedGroupId = matched['group_id'];
                          _selectedGroupMode = matched['label'] ?? 'Individual (No Group)';
                        });
                      }
                    },
                  ),

                  // Create new group 3-column inputs
                  if (_selectedGroupMode == '+ Create New Group') ...[
                    const SizedBox(height: 12),
                    _buildResponsiveInputRow(
                      children: [
                        TextField(
                          controller: _newGroupNameCtrl,
                          style: TextStyle(color: tokens.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'New Group Name',
                            hintText: 'e.g. Alaba Traders',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        TextField(
                          controller: _newGroupNumberCtrl,
                          style: TextStyle(color: tokens.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'New Group Number (2-digits)',
                            hintText: 'e.g. 01',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _newGroupMeetingDay,
                          dropdownColor: tokens.surfaceElevated,
                          style: TextStyle(fontSize: 14, color: tokens.textPrimary),
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
                        color: tokens.infoBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.infoBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: tokens.infoText, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Selected group '${selectedGroupData['name']}' (Code: ${selectedGroupData['group_number'] ?? ''}) meets on ${selectedGroupData['meeting_day'] ?? ''}",
                              style: TextStyle(fontSize: 13, color: tokens.infoText, fontWeight: FontWeight.w500),
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
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: tokens.isDark ? 0.16 : 0.02),
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: tokens.brandPrimary,
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
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
                          color: isActive ? tokens.brandPrimary : tokens.borderSubtle,
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
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: tokens.isDark ? 0.18 : 0.02),
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
                  Text(
                    '1. Personal Info & Registration Date',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Provide client legal identification and contact details.',
                    style: TextStyle(fontSize: 12.5, color: tokens.textMuted),
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
                      if (picked != null) setState(() {
                        _regDate = picked;
                        _regDateTouched = true;
                      });
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Registration Date',
                        helperText: 'Set backdated registration date if registering historical clients.',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(_regDate.toIsoformatDate(), style: TextStyle(color: tokens.textPrimary)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildResponsiveInputRow(
                    children: [
                      TextField(
                        controller: _clientNameCtrl,
                        style: TextStyle(color: tokens.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'e.g. Aminat Adeleke',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        controller: _clientNicknameCtrl,
                        style: TextStyle(color: tokens.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Nickname',
                          hintText: 'e.g. Iya Alaba',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        controller: _clientPhoneCtrl,
                        style: TextStyle(color: tokens.textPrimary),
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
                    style: TextStyle(color: tokens.textPrimary),
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
                    dropdownColor: tokens.surfaceElevated,
                    style: TextStyle(fontSize: 14, color: tokens.textPrimary),
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
                              content: Text('Please enter Full Name and Phone Number to continue.', style: TextStyle(color: Colors.white)),
                              backgroundColor: Color(0xFFDC2626),
                            ),
                          );
                          return;
                        }
                        if (_selectedGroupMode == '+ Create New Group') {
                          if (_newGroupNameCtrl.text.trim().isEmpty || _newGroupNumberCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter Group Name and Group Number.', style: TextStyle(color: Colors.white)),
                                backgroundColor: Color(0xFFDC2626),
                              ),
                            );
                            return;
                          }
                        }
                        setState(() => _wizardStep = 2);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimaryDark,
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
                  Text(
                    '2. Business Profile & Financials',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Document client commercial activities, estimated income, and liabilities.',
                    style: TextStyle(fontSize: 12.5, color: tokens.textMuted),
                  ),
                  const SizedBox(height: 16),

                  _buildResponsiveInputRow(
                    children: [
                      TextField(
                        controller: _clientBizTypeCtrl,
                        style: TextStyle(color: tokens.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Business Type',
                          hintText: 'e.g. Trader, Tailor, Provisions',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        controller: _clientIncomeCtrl,
                        style: TextStyle(color: tokens.textPrimary),
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
                    style: TextStyle(color: tokens.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Business Address',
                      hintText: 'Enter market stall or business shop address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clientObligationsCtrl,
                    style: TextStyle(color: tokens.textPrimary),
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
                              foregroundColor: tokens.textPrimary,
                              side: BorderSide(color: tokens.borderStrong),
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
                              backgroundColor: tokens.brandPrimaryDark,
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
                  Text(
                    '3. Guarantor Due Diligence',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Provide details of the guarantor vouching for this client.',
                    style: TextStyle(fontSize: 12.5, color: tokens.textMuted),
                  ),
                  const SizedBox(height: 16),

                  _buildResponsiveInputRow(
                    children: [
                      TextField(
                        controller: _guarNameCtrl,
                        style: TextStyle(color: tokens.textPrimary),
                        decoration: const InputDecoration(labelText: 'Guarantor Full Name', border: OutlineInputBorder()),
                      ),
                      TextField(
                        controller: _guarNicknameCtrl,
                        style: TextStyle(color: tokens.textPrimary),
                        decoration: const InputDecoration(labelText: 'Guarantor Nickname', border: OutlineInputBorder()),
                      ),
                      TextField(
                        controller: _guarPhoneCtrl,
                        style: TextStyle(color: tokens.textPrimary),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Guarantor Phone', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _guarAddressCtrl,
                    style: TextStyle(color: tokens.textPrimary),
                    decoration: const InputDecoration(labelText: 'Guarantor Home Address', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  _buildResponsiveInputRow(
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _guarMarital,
                        dropdownColor: tokens.surfaceElevated,
                        style: TextStyle(fontSize: 14, color: tokens.textPrimary),
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
                        style: TextStyle(color: tokens.textPrimary),
                        decoration: const InputDecoration(labelText: 'Guarantor Occupation', hintText: 'e.g. Trader, Civil Servant', border: OutlineInputBorder()),
                      ),
                      TextField(
                        controller: _guarRelCtrl,
                        style: TextStyle(color: tokens.textPrimary),
                        decoration: const InputDecoration(labelText: 'Relationship with Client', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _guarOfficeCtrl,
                    style: TextStyle(color: tokens.textPrimary),
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
                              foregroundColor: tokens.textPrimary,
                              side: BorderSide(color: tokens.borderStrong),
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
                              backgroundColor: tokens.brandPrimaryDark,
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
                  Text(
                    '4. Identity & KYC Documents',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upload client and guarantor identification documents and passport photographs.',
                    style: TextStyle(fontSize: 12.5, color: tokens.textMuted),
                  ),
                  const SizedBox(height: 16),

                  // Client Identification Card Container
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Client Identification',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: tokens.textPrimary),
                        ),
                        const SizedBox(height: 10),
                        _buildResponsiveInputRow(
                          children: [
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedIdMeans,
                              dropdownColor: tokens.surfaceElevated,
                              style: TextStyle(fontSize: 14, color: tokens.textPrimary),
                              decoration: const InputDecoration(labelText: 'Means of ID', border: OutlineInputBorder()),
                              selectedItemBuilder: (BuildContext context) {
                                return ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None']
                                    .map<Widget>((i) => Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(i, style: TextStyle(fontSize: 14, color: tokens.textPrimary), overflow: TextOverflow.ellipsis, maxLines: 1),
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
                              style: TextStyle(color: tokens.textPrimary),
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
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guarantor Identification',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: tokens.textPrimary),
                        ),
                        const SizedBox(height: 10),
                        _buildResponsiveInputRow(
                          children: [
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _guarIdMeans,
                              dropdownColor: tokens.surfaceElevated,
                              style: TextStyle(fontSize: 14, color: tokens.textPrimary),
                              decoration: const InputDecoration(labelText: 'Guarantor Means of ID', border: OutlineInputBorder()),
                              selectedItemBuilder: (BuildContext context) {
                                return ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None']
                                    .map<Widget>((i) => Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(i, style: TextStyle(fontSize: 14, color: tokens.textPrimary), overflow: TextOverflow.ellipsis, maxLines: 1),
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
                              style: TextStyle(color: tokens.textPrimary),
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
                              foregroundColor: tokens.textPrimary,
                              side: BorderSide(color: tokens.borderStrong),
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
                              backgroundColor: tokens.brandPrimaryDark,
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
    final tokens = IcareSurfaceTokens.of(context);
    final isUploading = _uploadingState[category] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: tokens.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderStrong),
          ),
          child: selectedFileName != null
              ? Row(
                  children: [
                    Icon(Icons.insert_drive_file_outlined, size: 20, color: tokens.infoText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedFileName,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (sizeInfo != null && sizeInfo.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              sizeInfo,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.successText),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: tokens.textMuted),
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
                              color: isUploading ? tokens.brandPrimary : tokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isUploading ? 'Optimizing image size (<= 1000px, quality 75)...' : allowedTypesText,
                            style: TextStyle(fontSize: 10.5, color: tokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (isUploading)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: tokens.brandPrimary),
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
                            final ext = picked.fileName.contains('.')
                                ? picked.fileName.split('.').last.toLowerCase()
                                : '';
                            final allowed = allowedTypesText.contains('XLSX')
                                ? {'xlsx', 'xls'}
                                : (allowedTypesText.contains('PDF')
                                    ? {'jpg', 'jpeg', 'png', 'webp', 'jfif', 'pdf'}
                                    : {'jpg', 'jpeg', 'png', 'webp', 'jfif'});
                            if (!allowed.contains(ext)) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Unsupported file format ".$ext". Allowed: $allowedTypesText', style: const TextStyle(color: Colors.white)),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                              }
                              return;
                            }
                            if (picked.bytes.length > 10 * 1024 * 1024) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('File exceeds the 10 MB maximum upload limit.', style: TextStyle(color: Colors.white)),
                                    backgroundColor: Color(0xFFDC2626),
                                  ),
                                );
                              }
                              return;
                            }
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
                                  SnackBar(content: Text(AppErrorDetails.from(e).message, style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFFDC2626)),
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
                          backgroundColor: tokens.surface,
                          foregroundColor: tokens.textPrimary,
                          side: BorderSide(color: tokens.borderStrong),
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
    Color? accentColor,
    Color? bgColor,
    Color? borderColor,
    bool isHero = false,
    String? subtitle,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    final resolvedAccent = accentColor ?? tokens.textPrimary;
    final resolvedBg = bgColor ?? tokens.surfaceSubtle;
    final resolvedBorder = borderColor ?? tokens.borderSubtle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: resolvedBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: resolvedBorder, width: isHero ? 1.5 : 1.0),
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
              color: isHero ? resolvedAccent : tokens.textMuted,
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
                color: resolvedAccent,
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
                color: isHero ? resolvedAccent.withValues(alpha: 0.85) : tokens.textMuted,
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
    final tokens = IcareSurfaceTokens.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;

    final financeProducts = _getCategoryProducts('Finance', user);
    final assetProducts = _getCategoryProducts('Asset', user);

    if (_loanAppCategory == 'Finance' && financeProducts.isEmpty && assetProducts.isNotEmpty) {
      _loanAppCategory = 'Asset';
    } else if (_loanAppCategory == 'Asset' && assetProducts.isEmpty && financeProducts.isNotEmpty) {
      _loanAppCategory = 'Finance';
    }

    final currentCategoryProducts = _loanAppCategory == 'Finance' ? financeProducts : assetProducts;
    if (currentCategoryProducts.isNotEmpty && !currentCategoryProducts.contains(_loanAppProduct)) {
      _loanAppProduct = currentCategoryProducts.first;
    }

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
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.16 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                decoration: BoxDecoration(
                  color: tokens.brandSoftBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tokens.brandSoftText)),
                ),
              ),
              const SizedBox(width: 8),
              Text('Search & Select Client', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: tokens.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _appSearchCtrl,
                  style: TextStyle(color: tokens.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Search Client by Name or Client Code',
                    hintText: 'e.g. Adebayo or CL-001',
                    prefixIcon: Icon(Icons.search, size: 20, color: tokens.textMuted),
                    filled: true,
                    fillColor: tokens.surfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                  ),
                  onSubmitted: _handleSearchAppClients,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isAppSearching ? null : () => _handleSearchAppClients(_appSearchCtrl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.brandPrimaryDark,
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
              dropdownColor: tokens.surfaceElevated,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
              hint: const Text('Select Client from Search Results', overflow: TextOverflow.ellipsis),
              decoration: InputDecoration(
                filled: true,
                fillColor: tokens.surfaceSubtle,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: tokens.borderStrong)),
              ),
              selectedItemBuilder: (BuildContext context) {
                return _appSearchResults.map((c) {
                  final code = c['client_code']?.toString() ?? '';
                  final name = c['name']?.toString() ?? '';
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$name ($code)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
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
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.borderStrong),
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
                          color: tokens.brandSoftBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: tokens.brandSoftBorder),
                        ),
                        child: Center(
                          child: Text(
                            (_selectedAppClient!['name']?.toString().isNotEmpty == true)
                                ? _selectedAppClient!['name'].toString().substring(0, 1).toUpperCase()
                                : 'C',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: tokens.brandSoftText),
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
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: tokens.textPrimary),
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Code: ${_selectedAppClient!['client_code'] ?? 'N/A'}',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textMuted),
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
                            color: tokens.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: tokens.borderStrong),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sync, size: 12, color: tokens.textSecondary),
                              const SizedBox(width: 4),
                              Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
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
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 13, color: tokens.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Guarantor: ${_selectedAppClient!['guarantor']['full_name']} (${_selectedAppClient!['guarantor']['relationship'] ?? 'Guarantor'}) • ${_selectedAppClient!['guarantor']['phone'] ?? ''}',
                              style: TextStyle(fontSize: 11, color: tokens.textSecondary, fontWeight: FontWeight.w600),
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
                      color: tokens.infoBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tokens.infoBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 16, color: tokens.infoText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Current Pooled Savings: ${CurrencyFormatter.formatNaira(savBal)}',
                            style: TextStyle(color: tokens.infoText, fontWeight: FontWeight.w700, fontSize: 12),
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
                  decoration: BoxDecoration(
                    color: tokens.brandSoftBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tokens.brandSoftText)),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Loan Product Parameters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: tokens.textPrimary)),
                if (user != null && user.allowedProducts.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: tokens.borderStrong),
                    ),
                    child: Text(
                      'Assigned Products (${user.allowedProducts.length})',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Category Segmented Buttons
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: financeProducts.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _loanAppCategory = 'Finance';
                              _selectedAssetCart.clear();
                              if (!financeProducts.contains(_loanAppProduct) && financeProducts.isNotEmpty) {
                                _loanAppProduct = financeProducts.first;
                              }
                            });
                            _recomputeFinanceGapDefault();
                            _scheduleRefreshCalculations(immediate: true);
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Opacity(
                      opacity: financeProducts.isEmpty ? 0.45 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _loanAppCategory == 'Finance' ? tokens.successBg : tokens.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _loanAppCategory == 'Finance' ? tokens.successDot : tokens.borderStrong,
                            width: _loanAppCategory == 'Finance' ? 1.5 : 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Finance Loan',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _loanAppCategory == 'Finance' ? FontWeight.w800 : FontWeight.w600,
                              color: _loanAppCategory == 'Finance' ? tokens.successText : tokens.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: assetProducts.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _loanAppCategory = 'Asset';
                              if (!assetProducts.contains(_loanAppProduct) && assetProducts.isNotEmpty) {
                                _loanAppProduct = assetProducts.first;
                              }
                            });
                            _financeGapFeeCtrl.clear();
                            if (_assetCatalogItems.isEmpty) {
                              _loadBranchAssetCatalog();
                            }
                            _recomputeFinanceGapDefault();
                            _scheduleRefreshCalculations(immediate: true);
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Opacity(
                      opacity: assetProducts.isEmpty ? 0.45 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _loanAppCategory == 'Asset' ? tokens.infoBg : tokens.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _loanAppCategory == 'Asset' ? tokens.infoDot : tokens.borderStrong,
                            width: _loanAppCategory == 'Asset' ? 1.5 : 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Asset Loan',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _loanAppCategory == 'Asset' ? FontWeight.w800 : FontWeight.w600,
                              color: _loanAppCategory == 'Asset' ? tokens.infoText : tokens.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isAssetOrCashAndCarry) ...[
              AssetCatalogPickerSection(
                branchName: _assetBranchName.isNotEmpty ? _assetBranchName : (user?.branch ?? ''),
                selectedProduct: _loanAppProduct,
                catalogItems: _assetCatalogItems,
                categories: _assetCatalogCategories,
                summary: _assetCatalogSummary,
                cartItems: _selectedAssetCart,
                isLoading: _isLoadingAssetCatalog,
                isOfflineCache: _isOfflineAssetCatalog,
                errorMessage: _assetCatalogError,
                onRefresh: _loadBranchAssetCatalog,
                onOpenFullCatalog: _openAssetCatalogModal,
                onAddItem: _addAssetToCart,
                onChangeQty: _updateAssetCartQty,
                onRemoveItem: _removeAssetCartItem,
                onClearCart: _clearAssetCart,
              ),
              const SizedBox(height: 12),
            ],

            _buildResponsiveInputRow(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: currentCategoryProducts.contains(_loanAppProduct)
                      ? _loanAppProduct
                      : (currentCategoryProducts.isNotEmpty ? currentCategoryProducts.first : null),
                  dropdownColor: tokens.surfaceElevated,
                  style: TextStyle(fontSize: 14, color: tokens.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Loan Product',
                    helperText: (user != null && user.allowedProducts.isNotEmpty)
                        ? 'Showing products assigned by Branch Manager'
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  items: currentCategoryProducts
                      .map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis, maxLines: 1)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _loanAppProduct = val);
                      _recomputeFinanceGapDefault();
                      _scheduleRefreshCalculations(immediate: true);
                    }
                  },
                ),
                TextField(
                  controller: _loanAppAmountCtrl,
                  readOnly: _isAssetOrCashAndCarry && _selectedAssetCart.isNotEmpty,
                  style: TextStyle(color: tokens.textPrimary),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _loanAppCategory == 'Asset' ? 'Asset Cost (₦)' : 'Requested Amount (₦)',
                    hintText: _isAssetOrCashAndCarry && _selectedAssetCart.isEmpty ? 'Select items above or enter cost' : 'e.g. 100,000',
                    helperText: _isAssetOrCashAndCarry && _selectedAssetCart.isNotEmpty
                        ? 'Locked to selected October 2026 catalog items'
                        : null,
                    prefixText: '₦ ',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _recomputeFinanceGapDefault();
                    _scheduleRefreshCalculations();
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
                  color: _eligibilityResult!['is_eligible'] == true ? tokens.successBg : tokens.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _eligibilityResult!['is_eligible'] == true ? tokens.successBorder : tokens.dangerBorder,
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
                          color: _eligibilityResult!['is_eligible'] == true ? tokens.successText : tokens.dangerText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _eligibilityResult!['is_eligible'] == true ? 'CLIENT IS ELIGIBLE FOR LOAN' : 'NOT ELIGIBLE - REVIEW CRITERIA',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: _eligibilityResult!['is_eligible'] == true ? tokens.successText : tokens.dangerText,
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
                          style: TextStyle(fontSize: 11.5, color: _eligibilityResult!['is_eligible'] == true ? tokens.successText : tokens.dangerText),
                          softWrap: true,
                        ),
                      ),
                    ),
                    ...((_eligibilityResult!['warnings'] as List<dynamic>?) ?? []).map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Warning: $w',
                          style: TextStyle(fontSize: 11.5, color: tokens.warningText, fontWeight: FontWeight.w600),
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
              Text('Downpayment Source', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tokens.textSecondary)),
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
                        color: isSel ? tokens.infoBg : tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSel ? tokens.infoDot : tokens.borderStrong,
                          width: isSel ? 1.4 : 1.0,
                        ),
                      ),
                      child: Text(
                        shortLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? tokens.infoText : tokens.textSecondary,
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
                      style: TextStyle(color: tokens.textPrimary),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cash Downpayment (₦)', hintText: '0', prefixText: '₦ ', border: OutlineInputBorder()),
                      onChanged: (_) {
                        setState(() {});
                        _scheduleRefreshCalculations();
                      },
                    ),
                    TextField(
                      controller: _assetSavDpCtrl,
                      style: TextStyle(color: tokens.textPrimary),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Savings Downpayment (₦)', hintText: '0', prefixText: '₦ ', border: OutlineInputBorder()),
                      onChanged: (_) {
                        setState(() {});
                        _scheduleRefreshCalculations();
                      },
                    ),
                  ],
                )
              else if (_assetDpMode == 'Cash (Physical Payment)')
                TextField(
                  controller: _assetCashDpCtrl,
                  style: TextStyle(color: tokens.textPrimary),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cash Downpayment (₦)', hintText: '0', prefixText: '₦ ', border: OutlineInputBorder()),
                  onChanged: (_) {
                    setState(() {});
                    _scheduleRefreshCalculations();
                  },
                )
              else
                TextField(
                  controller: _assetSavDpCtrl,
                  style: TextStyle(color: tokens.textPrimary),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Savings Downpayment (₦)', hintText: '0', prefixText: '₦ ', border: OutlineInputBorder()),
                  onChanged: (_) {
                    setState(() {});
                    _scheduleRefreshCalculations();
                  },
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
                    accentColor: tokens.infoText,
                    bgColor: tokens.infoBg,
                    borderColor: tokens.infoBorder,
                    isHero: true,
                  );
                  final tHeroInst = _buildLoanMetricTile(
                    label: 'SCHEDULED REPAYMENT INSTALLMENT',
                    value: CurrencyFormatter.formatNaira(assetInstallment),
                    subtitle: '$dur installments ($cycle)',
                    accentColor: tokens.successText,
                    bgColor: tokens.successBg,
                    borderColor: tokens.successBorder,
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
                  decoration: BoxDecoration(color: tokens.dangerBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: tokens.dangerBorder)),
                  child: Text(
                    'INSUFFICIENT SAVINGS: Client has ${CurrencyFormatter.formatNaira(savBal)} but needs ${CurrencyFormatter.formatNaira(savDp)} from savings.',
                    style: TextStyle(color: tokens.dangerText, fontWeight: FontWeight.w600, fontSize: 12),
                    softWrap: true,
                  ),
                ),
              ],
            ] else ...[
              // Finance Gap Fee
              TextField(
                controller: _financeGapFeeCtrl,
                style: TextStyle(color: tokens.textPrimary),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Gap Fee / Base Savings (₦)',
                  hintText: '0',
                  prefixText: '₦ ',
                  helperText: 'Subtracted from principal and posted into base savings fund',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  setState(() {});
                  _scheduleRefreshCalculations();
                },
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
                    accentColor: tokens.infoText,
                    bgColor: tokens.infoBg,
                    borderColor: tokens.infoBorder,
                    isHero: true,
                  );
                  final tHeroInst = _buildLoanMetricTile(
                    label: 'SCHEDULED REPAYMENT INSTALLMENT',
                    value: CurrencyFormatter.formatNaira(finInstallment),
                    subtitle: '$dur installments ($cycle)',
                    accentColor: tokens.successText,
                    bgColor: tokens.successBg,
                    borderColor: tokens.successBorder,
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
                  decoration: BoxDecoration(color: tokens.dangerBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: tokens.dangerBorder)),
                  child: Text(
                    'INSUFFICIENT SAVINGS: Client has ${CurrencyFormatter.formatNaira(savBal)} but needs ${CurrencyFormatter.formatNaira(finTotalUpfront)} to cover upfront requirements.',
                    style: TextStyle(color: tokens.dangerText, fontWeight: FontWeight.w600, fontSize: 12),
                    softWrap: true,
                  ),
                ),
              ],
            ],

            if (_isLoadingSchedule) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
            ] else if (_schedulePreview != null && _currentAmount > 0) ...[
              const SizedBox(height: 14),
              _buildSchedulePreviewCard(_schedulePreview!),
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
                    if (picked != null) {
                      setState(() {
                        _appDate = picked;
                        _appDateTouched = true;
                      });
                      _scheduleRefreshCalculations(immediate: true);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Application Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(_appDate.toIsoformatDate(), style: TextStyle(color: tokens.textPrimary)),
                  ),
                ),
                TextField(
                  controller: _loanAppNotesCtrl,
                  style: TextStyle(color: tokens.textPrimary),
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
                onPressed: (_isSubmitting || (_eligibilityResult != null && _eligibilityResult!['is_eligible'] == false))
                    ? null
                    : _handleSubmitLoanApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.brandPrimaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 1,
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_outlined, size: 18),
                label: Text(
                  (_eligibilityResult != null && _eligibilityResult!['is_eligible'] == false)
                      ? 'Client Not Eligible — Review Criteria Above'
                      : 'Submit Application for Approval',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileMetaChip(IconData icon, String text) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tokens.textMuted),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textSecondary),
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
    final tokens = IcareSurfaceTokens.of(context);
    final pendingAsync = ref.watch(pendingDisbursementsProvider);

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.16 : 0.02),
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
              Text('Pending Disbursements', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: tokens.textPrimary)),
              IconButton(
                icon: Icon(Icons.refresh, size: 20, color: tokens.textSecondary),
                onPressed: () => ref.refresh(pendingDisbursementsProvider),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_disbSuccessNotice != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: tokens.successBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: tokens.successBorder)),
              child: Text(_disbSuccessNotice!, style: TextStyle(color: tokens.successText, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
          if (_disbAdjustNotice != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: tokens.warningBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: tokens.warningBorder)),
              child: Text('Schedule Adjusted: $_disbAdjustNotice', style: TextStyle(color: tokens.warningText, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],

          pendingAsync.when(
            loading: () => const IcareTableSkeleton(rowCount: 5, hasFilterBar: false),
            error: (err, _) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: tokens.dangerBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: tokens.dangerBorder)),
              child: Text('Error loading pending loans: ${AppErrorDetails.from(err).message}', style: TextStyle(color: tokens.dangerText, fontSize: 13)),
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
                      decoration: BoxDecoration(color: tokens.infoBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: tokens.infoBorder)),
                      child: Text('Note: You are a Credit Officer. Only Branch Managers or Area Managers can authorize and activate disbursements.', style: TextStyle(color: tokens.infoText, fontSize: 13)),
                    ),

                  if (loans.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('No pending loans found.', style: TextStyle(color: tokens.textMuted, fontSize: 13)),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(border: Border.all(color: tokens.borderSubtle), borderRadius: BorderRadius.circular(6)),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(tokens.surfaceSubtle),
                            headingTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tokens.textPrimary),
                            dataTextStyle: TextStyle(fontSize: 12, color: tokens.textSecondary),
                            columns: const [
                              DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              DataColumn(label: Text('Group Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              DataColumn(label: Text('Officer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              DataColumn(label: Text('Loan Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
                              DataColumn(label: Text('Loan Product', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              DataColumn(label: Text('Reserved Assets', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            ],
                            rows: loans.map((l) {
                              final cName = l['client_name']?.toString() ?? '-';
                              final gName = l['group_name']?.toString() ?? '-';
                              final dDate = l['date']?.toString() ?? '-';
                              final off = l['credit_officer']?.toString() ?? '-';
                              final amt = (l['loan_amount'] as num?)?.toDouble() ?? 0.0;
                              final prod = l['loan_product']?.toString() ?? '-';
                              final assetSum = l['asset_summary']?.toString() ?? '—';

                              return DataRow(cells: [
                                DataCell(Text(cName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: tokens.textPrimary))),
                                DataCell(Text(gName, style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                                DataCell(Text(dDate, style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                                DataCell(Text(off, style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                                DataCell(Text(CurrencyFormatter.formatNaira(amt), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.brandPrimary, fontFeatures: const [FontFeature.tabularFigures()]))),
                                DataCell(Text(prod, style: TextStyle(fontSize: 12, color: tokens.textSecondary))),
                                DataCell(Text(assetSum, style: TextStyle(fontSize: 11.5, color: assetSum != '—' ? tokens.infoText : tokens.textMuted, fontWeight: assetSum != '—' ? FontWeight.w600 : FontWeight.w400))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),

                  // Checker Action: Activate Loan (app.py L3251-3267)
                  if (canAuthorize && loans.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Divider(color: tokens.borderSubtle),
                    const SizedBox(height: 16),
                    Text('Checker Action: Activate Loan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: tokens.textPrimary)),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedPendingLoanId,
                      dropdownColor: tokens.surfaceElevated,
                      style: TextStyle(fontSize: 14, color: tokens.textPrimary),
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
                              style: TextStyle(color: tokens.textPrimary),
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
                        final amOnly = l['exceeds_bm_limit'] == true;
                        return DropdownMenuItem(
                          value: lid,
                          child: Text(
                            '$cName — $prod (${CurrencyFormatter.formatNaira(amt)})${amOnly ? ' [Area Manager Approval Required]' : ''}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedPendingLoanId = val),
                    ),
                    const SizedBox(height: 12),

                    if (_selectedPendingLoanId != null &&
                        loans.any((l) => l['loan_id']?.toString() == _selectedPendingLoanId && l['exceeds_bm_limit'] == true)) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: tokens.warningBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tokens.warningBorder),
                        ),
                        child: Text(
                          'Escalation Notice: This loan exceeds the Branch Manager authorization limit (₦300,000) and requires Area Manager approval.',
                          style: TextStyle(color: tokens.warningText, fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                      ),
                    ],

                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _disbDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() {
                          _disbDate = picked;
                          _disbDateTouched = true;
                        });
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Actual Disbursement Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        child: Text(_disbDate.toIsoformatDate(), style: TextStyle(color: tokens.textPrimary)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildResponsiveInputRow(
                      breakpoint: 550,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (_isSubmitting ||
                                    _selectedPendingLoanId == null ||
                                    loans.any((l) => l['loan_id']?.toString() == _selectedPendingLoanId && l['exceeds_bm_limit'] == true))
                                ? null
                                : _handleAuthorizeDisbursement,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tokens.brandPrimaryDark,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Authorize & Activate Disbursement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: (_isSubmitting || _selectedPendingLoanId == null)
                                ? null
                                : _handleRejectPendingLoan,
                            icon: Icon(Icons.cancel_outlined, size: 18, color: tokens.dangerText),
                            label: Text('Reject Application', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tokens.dangerText)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: tokens.dangerBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                      ],
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
    final tokens = IcareSurfaceTokens.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.16 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit Client & Guarantor Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: tokens.textPrimary)),
          const SizedBox(height: 4),
          Text('Search for a registered client to update their personal details and their guarantor information.', style: TextStyle(color: tokens.textMuted, fontSize: 13)),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _editSearchCtrl,
                  style: TextStyle(color: tokens.textPrimary),
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
                  backgroundColor: tokens.brandPrimaryDark,
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
              dropdownColor: tokens.surfaceElevated,
              style: TextStyle(fontSize: 14, color: tokens.textPrimary),
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
                      style: TextStyle(color: tokens.textPrimary),
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
            Divider(color: tokens.borderSubtle),
            const SizedBox(height: 16),

            Text('1. Personal Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: tokens.textPrimary)),
            const SizedBox(height: 12),
            _buildResponsiveInputRow(
              children: [
                TextField(controller: _editNameCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder())),
                TextField(controller: _editNicknameCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Nickname', border: OutlineInputBorder())),
                TextField(controller: _editPhoneCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder())),
              ],
            ),
            const SizedBox(height: 12),
            _buildResponsiveInputRow(
              children: [
                TextField(controller: _editAddressCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Home Address', border: OutlineInputBorder())),
                TextField(controller: _editBizAddressCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Business / Shop Address', border: OutlineInputBorder())),
              ],
            ),
            const SizedBox(height: 12),

            _buildResponsiveInputRow(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: ['Married', 'Single', 'Divorced', 'Widowed'].contains(_editMarital) ? _editMarital : 'Married',
                  dropdownColor: tokens.surfaceElevated,
                  style: TextStyle(fontSize: 14, color: tokens.textPrimary),
                  decoration: const InputDecoration(labelText: 'Marital Status', border: OutlineInputBorder()),
                  items: ['Married', 'Single', 'Divorced', 'Widowed'].map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                  onChanged: (val) { if (val != null) setState(() => _editMarital = val); },
                ),
                TextField(controller: _editBizTypeCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Business Type', border: OutlineInputBorder())),
                TextField(controller: _editIncomeCtrl, style: TextStyle(color: tokens.textPrimary), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Average Monthly Income (₦)', border: OutlineInputBorder())),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _editObligationsCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Other Obligations', border: OutlineInputBorder())),
            const SizedBox(height: 12),

            _buildResponsiveInputRow(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None'].contains(_editIdMeans) ? _editIdMeans : 'None',
                  dropdownColor: tokens.surfaceElevated,
                  style: TextStyle(fontSize: 14, color: tokens.textPrimary),
                  decoration: const InputDecoration(labelText: 'Means of ID', border: OutlineInputBorder()),
                  selectedItemBuilder: (BuildContext context) {
                    return ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None']
                        .map<Widget>((i) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(i, style: TextStyle(color: tokens.textPrimary), overflow: TextOverflow.ellipsis, maxLines: 1),
                            ))
                        .toList();
                  },
                  items: ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None'].map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                  onChanged: (val) { if (val != null) setState(() => _editIdMeans = val); },
                ),
                TextField(controller: _editIdNumberCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'ID Number', border: OutlineInputBorder())),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: tokens.borderSubtle),
            const SizedBox(height: 16),

            Text('2. Guarantor Info', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: tokens.textPrimary)),
            const SizedBox(height: 12),
            _buildResponsiveInputRow(
              children: [
                TextField(controller: _editGuarNameCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Guarantor Full Name', border: OutlineInputBorder())),
                TextField(controller: _editGuarNicknameCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Guarantor Nickname', border: OutlineInputBorder())),
                TextField(controller: _editGuarPhoneCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Guarantor Phone Number', border: OutlineInputBorder())),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _editGuarAddressCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Guarantor Home Address', border: OutlineInputBorder())),
            const SizedBox(height: 12),

            _buildResponsiveInputRow(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: ['Married', 'Single', 'Divorced', 'Widowed'].contains(_editGuarMarital) ? _editGuarMarital : 'Married',
                  dropdownColor: tokens.surfaceElevated,
                  style: TextStyle(fontSize: 14, color: tokens.textPrimary),
                  decoration: const InputDecoration(labelText: 'Guarantor Marital Status', border: OutlineInputBorder()),
                  items: ['Married', 'Single', 'Divorced', 'Widowed'].map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                  onChanged: (val) { if (val != null) setState(() => _editGuarMarital = val); },
                ),
                TextField(controller: _editGuarOccupationCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Guarantor Occupation', border: OutlineInputBorder())),
                TextField(controller: _editGuarRelCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Relationship with Client', border: OutlineInputBorder())),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _editGuarOfficeCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Guarantor Office Address', border: OutlineInputBorder())),
            const SizedBox(height: 12),

            _buildResponsiveInputRow(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None'].contains(_editGuarIdMeans) ? _editGuarIdMeans : 'None',
                  dropdownColor: tokens.surfaceElevated,
                  style: TextStyle(fontSize: 14, color: tokens.textPrimary),
                  decoration: const InputDecoration(labelText: 'Guarantor Means of ID', border: OutlineInputBorder()),
                  selectedItemBuilder: (BuildContext context) {
                    return ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None']
                        .map<Widget>((i) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(i, style: TextStyle(color: tokens.textPrimary), overflow: TextOverflow.ellipsis, maxLines: 1),
                            ))
                        .toList();
                  },
                  items: ['National ID (NIN)', "Voter's Card", "Driver's License", 'International Passport', 'None'].map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                  onChanged: (val) { if (val != null) setState(() => _editGuarIdMeans = val); },
                ),
                TextField(controller: _editGuarIdNumberCtrl, style: TextStyle(color: tokens.textPrimary), decoration: const InputDecoration(labelText: 'Guarantor ID Number', border: OutlineInputBorder())),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSaveEditClient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.brandPrimaryDark,
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

  Widget _buildSchedulePreviewCard(Map<String, dynamic> preview) {
    final tokens = IcareSurfaceTokens.of(context);
    final installments = (preview['installments'] as List<dynamic>?) ?? [];
    final firstDue = preview['first_due_date']?.toString() ?? '-';
    final endDue = preview['expected_end_date']?.toString() ?? '-';
    final dur = preview['duration']?.toString() ?? '${installments.length}';
    final freq = preview['frequency']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Repayment Schedule Preview',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: tokens.textPrimary),
              ),
              Text(
                '$dur installments · $freq',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.brandPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Text('First Repayment Date: $firstDue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
              Text('Expected Maturity Date: $endDue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
            ],
          ),
          if (installments.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 6),
              iconColor: tokens.infoText,
              collapsedIconColor: tokens.infoText,
              title: Text(
                'View All ${installments.length} Projected Due Dates',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.infoText),
              ),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(0.7),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1.3),
                      },
                      border: TableBorder.all(color: tokens.borderSubtle),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: tokens.surface),
                          children: [
                            Padding(padding: const EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textPrimary))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('Due Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textPrimary))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('Installment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: tokens.textPrimary))),
                          ],
                        ),
                        ...installments.map((item) {
                          final row = item as Map<String, dynamic>;
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(6), child: Text('${row['installment_number']}', style: TextStyle(fontSize: 11, color: tokens.textSecondary))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${row['due_date']}', style: TextStyle(fontSize: 11, color: tokens.textSecondary))),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  CurrencyFormatter.formatNaira((row['total_due'] as num?)?.toDouble() ?? 0.0),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textPrimary),
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
