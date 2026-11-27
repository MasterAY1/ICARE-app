import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../../auth/presentation/login_screen.dart';
import '../../../../core/auth/auth_controller.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/utils/app_url_helper.dart';
import '../data/onboarding_api_service.dart';
import 'credit_officer_portal_screen.dart';
import 'widgets/onboarding_analytics_charts.dart';
import 'package:frontend_flutter/core/theme/icare_motion.dart';

class BranchOnboardingPortalScreen extends ConsumerStatefulWidget {
  final String token;
  final String? initialOfficer;
  final bool isAmView;

  const BranchOnboardingPortalScreen({
    super.key,
    required this.token,
    this.initialOfficer,
    this.isAmView = false,
  });

  @override
  ConsumerState<BranchOnboardingPortalScreen> createState() =>
      _BranchOnboardingPortalScreenState();
}

class _BranchOnboardingPortalScreenState
    extends ConsumerState<BranchOnboardingPortalScreen>
    with SingleTickerProviderStateMixin {
  bool get _isAmOrAdmin {
    if (widget.isAmView) return true;
    final authState = ref.read(authControllerProvider);
    if (authState is AuthStateAuthenticated) {
      final role = authState.user.role.toLowerCase();
      return role.contains('area') ||
          role.contains('am') ||
          role.contains('admin') ||
          role.contains('director') ||
          role.contains('super');
    }
    return false;
  }
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  String? _bannerMessage;
  bool _isSuccessBanner = true;
  bool _isSaving = false;
  DateTime? _lastSavedTime;

  late String _currentToken;
  late final TextEditingController _tokenCtrl;

  // Credit Officer Scoped Mode & Filtering
  String? _scopedOfficer;
  String _selectedOfficerFilter = 'All';

  Map<String, dynamic>? _sessionData;
  List<dynamic> _loanProducts = [];
  List<dynamic> _meetingDays = [];
  List<dynamic> get loanProducts => _loanProducts;
  List<dynamic> get meetingDays => _meetingDays;

  // Working state
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _officers = [];
  double _miscSavings = 0.0;
  double _lapsSavings = 0.0;
  final TextEditingController _miscSavingsCtrl = TextEditingController();
  final TextEditingController _lapsSavingsCtrl = TextEditingController();
  String _selectedGroupFilter = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  final currencyFmt = NumberFormat("#,##0.00", "en_US");

  bool _isEnforcedOfficerScope = false;

  @override
  void initState() {
    super.initState();
    _currentToken = widget.token.trim();

    // Resolve token and officer scope from constructor, URL query parameters, or hash fragments
    final uri = Uri.base;
    String? tokenFromUrl = uri.queryParameters['token'];
    String? officerFromUrl = uri.queryParameters['officer'];

    if (uri.fragment.isNotEmpty) {
      final frag = uri.fragment;
      final fragUri = Uri.tryParse(frag.startsWith('/') ? frag : '/$frag');
      if (fragUri != null) {
        tokenFromUrl ??= fragUri.queryParameters['token'];
        officerFromUrl ??= fragUri.queryParameters['officer'];
      }
    }

    if (_currentToken.isEmpty && tokenFromUrl != null && tokenFromUrl.trim().isNotEmpty) {
      _currentToken = tokenFromUrl.trim();
    }
    _tokenCtrl = TextEditingController(text: _currentToken);

    if (widget.initialOfficer != null && widget.initialOfficer!.trim().isNotEmpty) {
      _scopedOfficer = widget.initialOfficer!.trim();
      _isEnforcedOfficerScope = true;
    } else if (officerFromUrl != null && officerFromUrl.trim().isNotEmpty) {
      _scopedOfficer = Uri.decodeComponent(officerFromUrl.trim());
      _isEnforcedOfficerScope = true;
    }

    // Auto-redirect to dedicated Credit Officer Portal Screen if an officer token is supplied
    if (_currentToken.startsWith('onb_co_')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => CreditOfficerPortalScreen(coToken: _currentToken)),
          );
        }
      });
      return;
    }

    final isOfficer = _scopedOfficer != null && _scopedOfficer!.isNotEmpty;
    _tabController = TabController(length: isOfficer ? 4 : 5, vsync: this);

    _loadSessionData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _tokenCtrl.dispose();
    _miscSavingsCtrl.dispose();
    _lapsSavingsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    if (_currentToken.startsWith('onb_co_')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => CreditOfficerPortalScreen(coToken: _currentToken)),
          );
        }
      });
      return;
    }

    if (_currentToken.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please provide an onboarding access token to view and manage branch session data.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(onboardingApiServiceProvider);
      final data = await api.getSession(_currentToken, officer: _scopedOfficer);

      final session = data['session'] as Map<String, dynamic>? ?? {};
      final payload = session['payload'] as Map<String, dynamic>? ?? {};
      final products = (data['loan_products'] as List<dynamic>?) ?? [];
      final days = (data['meeting_days'] as List<dynamic>?) ?? [];

      final groupsList = (payload['groups'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final membersList = (payload['members'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final officersList = (payload['officers'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final miscVal = (payload['misc_savings'] as num?)?.toDouble() ?? 0.0;
      final lapsVal = (payload['laps_savings'] as num?)?.toDouble() ?? 0.0;

      final sessionScopedOfficer = data['scoped_officer']?.toString();
      if ((_scopedOfficer == null || _scopedOfficer!.isEmpty) && sessionScopedOfficer != null && sessionScopedOfficer.isNotEmpty) {
        _scopedOfficer = sessionScopedOfficer;
        _isEnforcedOfficerScope = true;
        _tabController.dispose();
        _tabController = TabController(length: 4, vsync: this);
      }

      setState(() {
        _sessionData = session;
        _loanProducts = products;
        _meetingDays = days;
        _groups = groupsList;
        _members = membersList;
        _officers = officersList;
        _miscSavings = miscVal;
        _lapsSavings = lapsVal;
        _miscSavingsCtrl.text = miscVal > 0 ? miscVal.toStringAsFixed(2) : '';
        _lapsSavingsCtrl.text = lapsVal > 0 ? lapsVal.toStringAsFixed(2) : '';
        _isLoading = false;
      });
    } catch (e) {
      String msg = AppErrorDetails.from(e).message;
      if (e is DioException) {
        if (e.response?.data is Map && e.response?.data['detail'] != null) {
          msg = e.response?.data['detail'].toString() ?? msg;
        } else if (e.response?.statusCode == 404) {
          msg = 'Onboarding session not found or link is invalid. Please verify your token below.';
        } else if (e.response?.statusCode == 410) {
          msg = 'This onboarding session has expired (14-day validity). Please request a link extension or new invitation from the Head Office.';
        }
      }
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
    }
  }

  void _showBanner(String msg, {bool isSuccess = true}) {
    setState(() {
      _bannerMessage = msg;
      _isSuccessBanner = isSuccess;
    });
  }

  Future<void> _saveDraft() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final api = ref.read(onboardingApiServiceProvider);
      final payload = {
        'officers': _officers,
        'groups': _groups,
        'members': _members,
        'misc_savings': _miscSavings,
        'laps_savings': _lapsSavings,
      };

      final res = await api.saveDraft(_currentToken, payload, scopedOfficer: _scopedOfficer);
      setState(() {
        _isSaving = false;
        _lastSavedTime = DateTime.now();
      });
      _showBanner(res['message']?.toString() ?? 'Draft saved successfully.', isSuccess: true);
    } catch (e) {
      setState(() => _isSaving = false);
      _showBanner('Failed to save draft: ${AppErrorDetails.from(e).message}', isSuccess: false);
    }
  }

  Future<void> _handleExcelUpload() async {
    try {
      final picked = await pickExcelFile();
      if (picked == null) return;

      setState(() => _isSaving = true);
      _showBanner('Uploading and parsing ${picked.name}...', isSuccess: true);

      final api = ref.read(onboardingApiServiceProvider);
      final res = await api.uploadExcelBytes(
        _currentToken,
        picked.bytes,
        picked.name,
        scopedOfficer: _scopedOfficer,
      );

      final payload = res['payload'] as Map<String, dynamic>? ?? {};
      final groupsList = (payload['groups'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final membersList = (payload['members'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final officersList = (payload['officers'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final miscVal = (payload['misc_savings'] as num?)?.toDouble() ?? 0.0;
      final lapsVal = (payload['laps_savings'] as num?)?.toDouble() ?? 0.0;

      setState(() {
        _groups = groupsList;
        _members = membersList;
        _officers = officersList;
        _miscSavings = miscVal;
        _lapsSavings = lapsVal;
        _miscSavingsCtrl.text = miscVal > 0 ? miscVal.toStringAsFixed(2) : '';
        _lapsSavingsCtrl.text = lapsVal > 0 ? lapsVal.toStringAsFixed(2) : '';
        _isSaving = false;
        _lastSavedTime = DateTime.now();
        _tabController.animateTo(0); // Jump to member roster
      });

      _showBanner(res['message']?.toString() ?? 'Excel parsed and loaded successfully!', isSuccess: true);
    } catch (e) {
      setState(() => _isSaving = false);
      _showBanner('Error uploading Excel: ${AppErrorDetails.from(e).message}', isSuccess: false);
    }
  }

  Future<void> _submitScopedOfficerRoster() async {
    if (_scopedOfficer == null || _scopedOfficer!.isEmpty) return;

    final myGroups = _scopedGroups;
    final myMembers = _scopedMembers;

    if (myGroups.isEmpty) {
      _showBanner('Please register at least one solidarity group before submitting to your Branch Manager.', isSuccess: false);
      return;
    }

    final confirmed = await showIcareAdaptiveSheet<bool>(
      context: context,
      fitContent: true,
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submit Roster to Branch Manager',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to submit your completed roster to your Branch Manager for review and branch sign-off?',
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Officer: $_scopedOfficer',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Solidarity Groups: ${myGroups.length}',
                      style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Registered Members: ${myMembers.length}',
                      style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Portfolio Savings: ${CurrencyFormatter.formatNaira(_displayTotalSavings)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: tokens.successText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Once submitted, your roster will be locked for review by the Branch Manager.',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: TextButton.styleFrom(foregroundColor: tokens.textSecondary),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brandPrimaryDark,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Confirm & Submit to BM'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final off = _officers.firstWhere(
        (o) => (o['name'] ?? o['officer_name'])?.toString().trim().toLowerCase() == _scopedOfficer!.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      final coToken = (off['token'] ?? off['co_token'])?.toString();

      if (coToken != null && coToken.startsWith('onb_co_')) {
        final api = ref.read(onboardingApiServiceProvider);
        await api.saveOfficerDraft(coToken, {'groups': myGroups, 'members': myMembers});
        await api.submitOfficerRoster(coToken);
      } else {
        if (off.isNotEmpty) {
          off['status'] = 'submitted';
        }
        await _saveDraft();
      }

      setState(() {
        _isSaving = false;
        if (off.isNotEmpty) {
          off['status'] = 'submitted';
        }
      });
      _showBanner('Your roster has been successfully submitted to your Branch Manager!', isSuccess: true);
      await _loadSessionData();
    } catch (e) {
      setState(() => _isSaving = false);
      _showBanner('Failed to submit roster: ${AppErrorDetails.from(e).message}', isSuccess: false);
    }
  }

  Future<void> _submitPackage() async {
    final unsubmitted = _officers.where((o) => (o['status'] ?? 'draft') != 'submitted').length;
    final warningNotice = unsubmitted > 0
        ? '\n\nNote: $unsubmitted credit officer(s) have not yet marked their rosters as submitted to BM.'
        : '';

    final confirm = await showIcareAdaptiveSheet<bool>(
      context: context,
      fitContent: true,
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm Submission to Area Manager',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                'You are about to submit ${_groups.length} groups, ${_members.length} members, and ${_officers.length} credit officers to the Area Manager for final sign-off and branch activation.$warningNotice',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: TextButton.styleFrom(foregroundColor: tokens.textSecondary),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brandPrimaryDark,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Submit to Area Manager'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      // 1. Ensure latest draft is saved
      final api = ref.read(onboardingApiServiceProvider);
      final payload = {
        'officers': _officers,
        'groups': _groups,
        'members': _members,
        'misc_savings': _miscSavings,
        'laps_savings': _lapsSavings,
      };
      await api.saveDraft(_currentToken, payload);

      // 2. Submit to AM
      final res = await api.bmSubmitPackage(_currentToken);
      setState(() {
        _isSaving = false;
        _sessionData?['status'] = 'submitted';
      });
      _showBanner(res['message']?.toString() ?? 'Branch package successfully submitted to Area Manager!', isSuccess: true);
    } catch (e) {
      setState(() => _isSaving = false);
      _showBanner('Submission error: ${AppErrorDetails.from(e).message}', isSuccess: false);
    }
  }

  Future<void> _amApprovePackage() async {
    final notesCtrl = TextEditingController();
    final confirm = await showIcareAdaptiveSheet<bool>(
      context: context,
      fitContent: true,
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        final bottomInset = isDialog ? 0.0 : MediaQuery.viewInsetsOf(ctx).bottom;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm Area Manager Sign-Off',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                'You are about to activate ${_groups.length} groups, ${_members.length} members, and ${_officers.length} officers directly into live branch operations. This operation is permanent.',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Approval Notes (Optional)',
                  hintText: 'e.g. Verified and approved by Area Manager',
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: TextButton.styleFrom(foregroundColor: tokens.textSecondary),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brandPrimaryDark,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Approve & Activate Branch'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    final notesText = notesCtrl.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) => notesCtrl.dispose());

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final api = ref.read(onboardingApiServiceProvider);
      final res = await api.amApprovePackage(
        _currentToken,
        notes: notesText.isEmpty ? null : notesText,
      );
      setState(() {
        _isSaving = false;
        _sessionData?['status'] = 'approved';
      });
      _showBanner(res['message']?.toString() ?? 'Branch onboarding successfully activated in live branch operations!', isSuccess: true);
    } catch (e) {
      setState(() => _isSaving = false);
      _showBanner('Approval error: ${AppErrorDetails.from(e).message}', isSuccess: false);
    }
  }

  // =========================================================================
  // INTERACTIVE MODALS & CRUD (GROUPS & MEMBERS)
  // =========================================================================

  void _addGroup() {
    _showGroupModal();
  }

  void _addMember() {
    _showMemberModal();
  }

  void _showGroupModal({Map<String, dynamic>? groupToEdit}) {
    final isEditing = groupToEdit != null;
    int startingNum = (_sessionData?['next_branch_group_number'] as num?)?.toInt() ?? 1;
    int maxInSession = 0;
    for (final g in _groups) {
      final refStr = (g['group_reference'] ?? '').toString();
      final matches = RegExp(r'\d+').allMatches(refStr);
      if (matches.isNotEmpty) {
        final lastNum = int.tryParse(matches.last.group(0) ?? '') ?? 0;
        if (lastNum > maxInSession) {
          maxInSession = lastNum;
        }
      }
    }
    final nextNum = maxInSession >= startingNum ? (maxInSession + 1) : startingNum;
    final defaultRef = isEditing
        ? (groupToEdit['group_reference']?.toString() ?? '')
        : 'GRP-${nextNum.toString().padLeft(2, '0')}';

    final refCtrl = TextEditingController(text: defaultRef);
    final nameCtrl = TextEditingController(text: isEditing ? (groupToEdit['group_name']?.toString() ?? '') : '');
    final leaderCtrl = TextEditingController(text: isEditing ? (groupToEdit['leader_name']?.toString() ?? '') : '');
    final officerNames = _officers
        .map((o) => (o['name'] ?? o['officer_name'] ?? '').toString().trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    String currentOfficerName = (_scopedOfficer != null && _scopedOfficer!.isNotEmpty)
        ? _scopedOfficer!
        : (isEditing
            ? (groupToEdit['officer_name']?.toString() ?? '')
            : (officerNames.isNotEmpty ? officerNames.first : ''));

    final officerCtrl = TextEditingController(text: currentOfficerName);
    final phoneCtrl = TextEditingController(text: isEditing ? (groupToEdit['officer_phone']?.toString() ?? '') : '');

    if (phoneCtrl.text.isEmpty && currentOfficerName.isNotEmpty) {
      final match = _officers.firstWhere(
        (o) => (o['name'] ?? o['officer_name'] ?? '').toString().trim().toLowerCase() == currentOfficerName.toLowerCase(),
        orElse: () => {},
      );
      phoneCtrl.text = (match['phone'] ?? match['phone_number'] ?? '').toString();
    }

    String selectedOfficerDropdown = officerNames.contains(officerCtrl.text.trim())
        ? officerCtrl.text.trim()
        : (officerCtrl.text.trim().isNotEmpty ? '__custom__' : (officerNames.isNotEmpty ? officerNames.first : '__custom__'));

    final existingGroupSavings = isEditing ? (double.tryParse(groupToEdit['group_savings']?.toString() ?? '0') ?? 0.0) : 0.0;
    final savingsCtrl = TextEditingController(
      text: existingGroupSavings > 0 ? existingGroupSavings.toStringAsFixed(2) : '',
    );

    String selectedDay = isEditing ? (groupToEdit['meeting_day']?.toString() ?? 'Daily') : 'Daily';
    final availableDays = ['Daily', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Monthly'];
    if (!availableDays.contains(selectedDay)) {
      selectedDay = 'Daily';
    }

    final formKey = GlobalKey<FormState>();

    showIcareAdaptiveSheet<void>(
      context: context,
      fitContent: true,
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        final bottomInset = isDialog ? 0.0 : MediaQuery.viewInsetsOf(ctx).bottom;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isMobileModal = MediaQuery.of(ctx).size.width < 500;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24 + bottomInset),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: formKey,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Modal Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: tokens.infoBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.hub_outlined, color: tokens.infoDot, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEditing ? 'Edit Solidarity Group' : 'Add Solidarity Group',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Define group identity, meeting schedule, and leadership',
                                    style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: Icon(Icons.close, size: 20, color: tokens.textMuted),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(height: 1, color: tokens.borderSubtle),
                        const SizedBox(height: 16),

                        if (isMobileModal) ...[
                          TextFormField(
                            controller: refCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Group Code *',
                              hintText: 'GRP-01',
                              helperText: 'Branch sequence (auto-offsets to prevent conflicts)',
                              helperMaxLines: 1,
                              labelStyle: TextStyle(fontSize: 12),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              border: OutlineInputBorder(),
                            ),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Required';
                              final clean = val.trim().toUpperCase();
                              final dup = _groups.any((g) =>
                                  g != groupToEdit &&
                                  (g['group_reference'] ?? '').toString().toUpperCase() == clean);
                              if (dup) return 'Code in use';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Group Name *',
                              hintText: 'e.g. Akowonjo Market Traders',
                              labelStyle: TextStyle(fontSize: 12),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              border: OutlineInputBorder(),
                            ),
                            style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                            validator: (val) =>
                                (val == null || val.trim().isEmpty) ? 'Please enter a group name' : null,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: selectedDay,
                            isExpanded: true,
                            dropdownColor: tokens.surfaceElevated,
                            style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Meeting Day *',
                              labelStyle: TextStyle(fontSize: 12),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              border: OutlineInputBorder(),
                            ),
                            items: availableDays.map((d) {
                              return DropdownMenuItem(value: d, child: Text(d, style: TextStyle(fontSize: 13, color: tokens.textPrimary)));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedDay = val);
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: leaderCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Group Leader / Rep',
                              hintText: 'e.g. Alhaja Risikat',
                              labelStyle: TextStyle(fontSize: 12),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              border: OutlineInputBorder(),
                            ),
                            style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                          ),
                          if (_scopedOfficer != null && _scopedOfficer!.isNotEmpty) ...[
                            TextFormField(
                              controller: officerCtrl,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: 'Assigned Credit Officer (Your Workspace)',
                                labelStyle: const TextStyle(fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: tokens.surfaceSubtle,
                              ),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                            ),
                          ] else if (officerNames.isNotEmpty) ...[
                            DropdownButtonFormField<String>(
                              initialValue: selectedOfficerDropdown,
                              isExpanded: true,
                              dropdownColor: tokens.surfaceElevated,
                              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                              decoration: const InputDecoration(
                                labelText: 'Assigned Credit Officer',
                                labelStyle: TextStyle(fontSize: 12),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                ...officerNames.map((name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name, style: TextStyle(fontSize: 13, color: tokens.textPrimary)),
                                )),
                                DropdownMenuItem(
                                  value: '__custom__',
                                  child: Text('+ Custom / Enter New Officer', style: TextStyle(fontSize: 13, color: tokens.infoText)),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    selectedOfficerDropdown = val;
                                    if (val != '__custom__') {
                                      officerCtrl.text = val;
                                      final match = _officers.firstWhere(
                                        (o) => (o['name'] ?? o['officer_name'] ?? '').toString().trim().toLowerCase() == val.toLowerCase(),
                                        orElse: () => {},
                                      );
                                      phoneCtrl.text = (match['phone'] ?? match['phone_number'] ?? '').toString();
                                    } else {
                                      officerCtrl.clear();
                                      phoneCtrl.clear();
                                    }
                                  });
                                }
                              },
                            ),
                            if (selectedOfficerDropdown == '__custom__') ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: officerCtrl,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Credit Officer Name',
                                  hintText: 'e.g. Babatunde Lawal',
                                  labelStyle: TextStyle(fontSize: 12),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  border: OutlineInputBorder(),
                                ),
                                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                              ),
                            ],
                          ] else ...[
                            TextFormField(
                              controller: officerCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Credit Officer Name',
                                hintText: 'e.g. Babatunde Lawal',
                                labelStyle: TextStyle(fontSize: 12),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                border: OutlineInputBorder(),
                              ),
                              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Officer Phone',
                              hintText: 'e.g. 08012345678',
                              labelStyle: TextStyle(fontSize: 12),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              border: OutlineInputBorder(),
                            ),
                            style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                          ),
                        ] else ...[
                          // Group Reference & Name
                          Row(
                            children: [
                              SizedBox(
                                width: 130,
                                child: TextFormField(
                                  controller: refCtrl,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    labelText: 'Group Code *',
                                    hintText: 'GRP-01',
                                    labelStyle: TextStyle(fontSize: 12),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(),
                                  ),
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Required';
                                    final clean = val.trim().toUpperCase();
                                    final dup = _groups.any((g) =>
                                        g != groupToEdit &&
                                        (g['group_reference'] ?? '').toString().toUpperCase() == clean);
                                    if (dup) return 'Code in use';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: nameCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Group Name *',
                                    hintText: 'e.g. Akowonjo Market Traders',
                                    labelStyle: TextStyle(fontSize: 12),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(),
                                  ),
                                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                  validator: (val) =>
                                      (val == null || val.trim().isEmpty) ? 'Please enter a group name' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Meeting Day & Leader Name
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedDay,
                                  isExpanded: true,
                                  dropdownColor: tokens.surfaceElevated,
                                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                  decoration: const InputDecoration(
                                    labelText: 'Meeting Day *',
                                    labelStyle: TextStyle(fontSize: 12),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: availableDays.map((d) {
                                    return DropdownMenuItem(value: d, child: Text(d, style: TextStyle(fontSize: 13, color: tokens.textPrimary)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setModalState(() => selectedDay = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: leaderCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Group Leader / Rep',
                                    hintText: 'e.g. Alhaja Risikat',
                                    labelStyle: TextStyle(fontSize: 12),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(),
                                  ),
                                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Assigned Credit Officer & Phone
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_scopedOfficer != null && _scopedOfficer!.isNotEmpty) ...[
                                      TextFormField(
                                        controller: officerCtrl,
                                        enabled: false,
                                        decoration: InputDecoration(
                                          labelText: 'Assigned Credit Officer (Your Workspace)',
                                          labelStyle: const TextStyle(fontSize: 12),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                          border: const OutlineInputBorder(),
                                          filled: true,
                                          fillColor: tokens.surfaceSubtle,
                                        ),
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                                      ),
                                    ] else if (officerNames.isNotEmpty) ...[
                                      DropdownButtonFormField<String>(
                                        initialValue: selectedOfficerDropdown,
                                        isExpanded: true,
                                        dropdownColor: tokens.surfaceElevated,
                                        style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                        decoration: const InputDecoration(
                                          labelText: 'Assigned Credit Officer',
                                          labelStyle: TextStyle(fontSize: 12),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                          border: OutlineInputBorder(),
                                        ),
                                        items: [
                                          ...officerNames.map((name) => DropdownMenuItem(
                                            value: name,
                                            child: Text(name, style: TextStyle(fontSize: 13, color: tokens.textPrimary)),
                                          )),
                                          DropdownMenuItem(
                                            value: '__custom__',
                                            child: Text('+ Custom / Enter New Officer', style: TextStyle(fontSize: 13, color: tokens.infoText)),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setModalState(() {
                                              selectedOfficerDropdown = val;
                                              if (val != '__custom__') {
                                                officerCtrl.text = val;
                                                final match = _officers.firstWhere(
                                                  (o) => (o['name'] ?? o['officer_name'] ?? '').toString().trim().toLowerCase() == val.toLowerCase(),
                                                  orElse: () => {},
                                                );
                                                phoneCtrl.text = (match['phone'] ?? match['phone_number'] ?? '').toString();
                                              } else {
                                                officerCtrl.clear();
                                                phoneCtrl.clear();
                                              }
                                            });
                                          }
                                        },
                                      ),
                                      if (selectedOfficerDropdown == '__custom__') ...[
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller: officerCtrl,
                                          textCapitalization: TextCapitalization.words,
                                          decoration: const InputDecoration(
                                            labelText: 'Credit Officer Name',
                                            hintText: 'e.g. Babatunde Lawal',
                                            labelStyle: TextStyle(fontSize: 12),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                            border: OutlineInputBorder(),
                                          ),
                                          style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                        ),
                                      ],
                                    ] else ...[
                                      TextFormField(
                                        controller: officerCtrl,
                                        textCapitalization: TextCapitalization.words,
                                        decoration: const InputDecoration(
                                          labelText: 'Credit Officer Name',
                                          hintText: 'e.g. Babatunde Lawal',
                                          labelStyle: TextStyle(fontSize: 12),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                          border: OutlineInputBorder(),
                                        ),
                                        style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Officer Phone',
                                    hintText: 'e.g. 08012345678',
                                    labelStyle: TextStyle(fontSize: 12),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(),
                                  ),
                                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Initial Group Savings (Optional)
                        TextFormField(
                          controller: savingsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Initial Group Savings Deposit (₦)',
                            prefixText: '₦ ',
                            hintText: '0.00',
                            labelStyle: TextStyle(fontSize: 12),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            border: OutlineInputBorder(),
                          ),
                          style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: tokens.textSecondary,
                                side: BorderSide(color: tokens.borderStrong),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tokens.brandPrimaryDark,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              onPressed: () {
                                if (!formKey.currentState!.validate()) return;

                                final cleanRef = refCtrl.text.trim().toUpperCase();
                                final cleanName = nameCtrl.text.trim();
                                final cleanLeader = leaderCtrl.text.trim();
                                final cleanOfficer = officerCtrl.text.trim();
                                final cleanPhone = phoneCtrl.text.trim();
                                final cleanSavings = double.tryParse(savingsCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

                                setState(() {
                                  if (isEditing) {
                                    final oldRef = groupToEdit['group_reference'];
                                    groupToEdit['group_reference'] = cleanRef;
                                    groupToEdit['group_name'] = cleanName;
                                    groupToEdit['meeting_day'] = selectedDay;
                                    groupToEdit['leader_name'] = cleanLeader;
                                    groupToEdit['officer_name'] = cleanOfficer;
                                    groupToEdit['officer_phone'] = cleanPhone;
                                    groupToEdit['group_savings'] = cleanSavings;

                                    // Relational update for members if group reference was renamed
                                    if (oldRef != cleanRef) {
                                      for (final m in _members) {
                                        if (m['group_reference'] == oldRef) {
                                          m['group_reference'] = cleanRef;
                                        }
                                      }
                                      if (_selectedGroupFilter == oldRef) {
                                        _selectedGroupFilter = cleanRef;
                                      }
                                    }
                                  } else {
                                    _groups.add({
                                      'group_reference': cleanRef,
                                      'group_name': cleanName,
                                      'meeting_day': selectedDay,
                                      'leader_name': cleanLeader,
                                      'officer_name': cleanOfficer,
                                      'officer_phone': cleanPhone,
                                      'group_savings': cleanSavings,
                                    });
                                  }

                                  // Auto-register officer into _officers if not present
                                  if (cleanOfficer.isNotEmpty &&
                                      !_officers.any((o) => (o['name'] ?? o['officer_name'] ?? '').toString().trim().toLowerCase() == cleanOfficer.toLowerCase())) {
                                    _officers.add({
                                      'name': cleanOfficer,
                                      'officer_name': cleanOfficer,
                                      'phone': cleanPhone,
                                      'phone_number': cleanPhone,
                                      'role': 'Credit Officer',
                                      'is_misc_savings_manager': _officers.isEmpty,
                                    });
                                  }
                                });

                                Navigator.of(ctx).pop();
                                _saveDraft();
                                _showBanner(
                                  isEditing
                                      ? 'Group "$cleanName" updated.'
                                      : 'Group "$cleanName" created successfully.',
                                  isSuccess: true,
                                );
                              },
                              icon: Icon(isEditing ? Icons.check : Icons.add, size: 16),
                               label: Text(isEditing ? 'Update Group' : 'Add Group', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        refCtrl.dispose();
        nameCtrl.dispose();
        leaderCtrl.dispose();
        officerCtrl.dispose();
        phoneCtrl.dispose();
        savingsCtrl.dispose();
      });
    });
  }

  void _showMemberModal({Map<String, dynamic>? memberToEdit}) {
    final availableGroups = _scopedGroups;
    if (availableGroups.isEmpty) {
      showIcareAdaptiveSheet<void>(
        context: context,
        fitContent: true,
        builder: (ctx, isDialog) {
          final tokens = IcareSurfaceTokens.of(ctx);
          return Padding(
            padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: tokens.infoDot, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Create a Group First',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _scopedOfficer != null
                      ? 'You do not have any solidarity groups created yet for your portfolio ($_scopedOfficer). Please add at least one solidarity group before registering members.'
                      : 'Members must belong to a Solidarity Group. Please add at least one group before registering members.',
                  style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: tokens.textSecondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimaryDark,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showGroupModal();
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Group Now'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
      return;
    }

    final isEditing = memberToEdit != null;
    final branchCode = _sessionData?['branch_code'] ?? 'BR';

    String selectedGroupRef = isEditing
        ? (memberToEdit['group_reference']?.toString() ?? availableGroups.first['group_reference'])
        : (_selectedGroupFilter != 'All' && availableGroups.any((g) => g['group_reference'] == _selectedGroupFilter)
            ? _selectedGroupFilter
            : availableGroups.first['group_reference']);

    // Ensure selected group exists in availableGroups
    if (!availableGroups.any((g) => g['group_reference'] == selectedGroupRef)) {
      selectedGroupRef = availableGroups.first['group_reference'];
    }

    final nextSeq = _members.length + 1;
    final defaultMemberRef = isEditing
        ? (memberToEdit['member_reference']?.toString() ?? '')
        : '$branchCode-${selectedGroupRef.replaceAll('GRP-', '')}-${nextSeq.toString().padLeft(3, '0')}';

    final refCtrl = TextEditingController(text: defaultMemberRef);
    final nameCtrl = TextEditingController(text: isEditing ? (memberToEdit['full_name']?.toString() ?? '') : '');
    final phoneCtrl = TextEditingController(text: isEditing ? (memberToEdit['phone_number']?.toString() ?? '') : '');
    final addressCtrl = TextEditingController(text: isEditing ? (memberToEdit['home_address']?.toString() ?? '') : '');
    final existingSavings = isEditing ? (double.tryParse(memberToEdit['savings_balance']?.toString() ?? '0') ?? 0.0) : 0.0;
    final savingsCtrl = TextEditingController(
      text: existingSavings > 0 ? existingSavings.toStringAsFixed(2) : '',
    );

    // Active loan fields
    final existingPrincipal = isEditing
        ? (double.tryParse(memberToEdit['principal_loan']?.toString() ?? '') ??
            double.tryParse(memberToEdit['active_credit']?.toString() ?? '0') ??
            0.0)
        : 0.0;
    final existingActiveCredit = isEditing ? (double.tryParse(memberToEdit['active_credit']?.toString() ?? '0') ?? 0.0) : 0.0;
    final existingCurBal = isEditing ? (double.tryParse(memberToEdit['current_credit_balance']?.toString() ?? '0') ?? 0.0) : 0.0;
    bool hasActiveLoan = existingPrincipal > 0 || existingActiveCredit > 0 || existingCurBal > 0;

    final principalCtrl = TextEditingController(
      text: existingPrincipal > 0 ? existingPrincipal.toStringAsFixed(2) : '',
    );
    final creditCtrl = TextEditingController(
      text: existingActiveCredit > 0 ? existingActiveCredit.toStringAsFixed(2) : '',
    );
    final balanceCtrl = TextEditingController(
      text: existingCurBal > 0 ? existingCurBal.toStringAsFixed(2) : '',
    );

    // Available loan products from session metadata
    final List<String> productOptions = _loanProducts
        .map((p) => p['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    final existingLoanType = isEditing ? (memberToEdit['loan_type']?.toString() ?? '') : '';
    if (existingLoanType.isNotEmpty && !productOptions.contains(existingLoanType)) {
      productOptions.insert(0, existingLoanType);
    }

    String selectedProduct = existingLoanType.isNotEmpty
        ? existingLoanType
        : (productOptions.isNotEmpty ? productOptions.first : '');

    final formKey = GlobalKey<FormState>();

    showIcareAdaptiveSheet<void>(
      context: context,
      fitContent: true,
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        final bottomInset = isDialog ? 0.0 : MediaQuery.viewInsetsOf(ctx).bottom;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isMobileModal = MediaQuery.of(ctx).size.width < 500;
            final enteredCred = double.tryParse(creditCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
            final enteredBal = double.tryParse(balanceCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
            int prodInstallments = 60;
            final prodLower = selectedProduct.toLowerCase();
            if (prodLower.contains('120')) {
              prodInstallments = 120;
            } else if (prodLower.contains('12') && (prodLower.contains('w') || prodLower.contains('week'))) {
              prodInstallments = 12;
            } else if (prodLower.contains('24') && (prodLower.contains('w') || prodLower.contains('week'))) {
              prodInstallments = 24;
            } else if (prodLower.contains('3') && (prodLower.contains('m') || prodLower.contains('month'))) {
              prodInstallments = 3;
            } else if (prodLower.contains('6') && (prodLower.contains('m') || prodLower.contains('month'))) {
              prodInstallments = 6;
            } else if (prodLower.contains('60')) {
              prodInstallments = 60;
            }
            final calcInstallment = prodInstallments > 0 ? (enteredCred / prodInstallments) : 0.0;
            final estRemainingCount = calcInstallment > 0 ? (enteredBal / calcInstallment).ceil() : 0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24 + bottomInset),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: formKey,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Modal Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: tokens.brandSoftBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isEditing ? Icons.edit_outlined : Icons.person_add_alt_1,
                                color: tokens.brandSoftText,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEditing ? 'Edit Member Details' : 'Register New Member',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Solidarity group membership, savings, and loan balances',
                                    style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: Icon(Icons.close, size: 20, color: tokens.textMuted),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(height: 1, color: tokens.borderSubtle),
                        const SizedBox(height: 16),

                        // Section 1: Group Assignment & Code
                        if (isMobileModal) ...[
                          DropdownButtonFormField<String>(
                            initialValue: selectedGroupRef,
                            isExpanded: true,
                            dropdownColor: tokens.surfaceElevated,
                            style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Solidarity Group *',
                              labelStyle: TextStyle(fontSize: 12),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              border: OutlineInputBorder(),
                            ),
                            items: availableGroups.map((g) {
                              final gRef = g['group_reference'] ?? '';
                              final gName = g['group_name'] ?? '';
                              return DropdownMenuItem(
                                value: gRef.toString(),
                                child: Text(
                                  '$gRef ($gName)',
                                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  selectedGroupRef = val;
                                  if (!isEditing) {
                                    refCtrl.text = '$branchCode-${selectedGroupRef.replaceAll('GRP-', '')}-${nextSeq.toString().padLeft(3, '0')}';
                                  }
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: refCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Member Code *',
                              hintText: 'e.g. BR-01-001',
                              labelStyle: TextStyle(fontSize: 12),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              border: OutlineInputBorder(),
                            ),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Required';
                              final clean = val.trim().toUpperCase();
                              final dup = _members.any((m) =>
                                  m != memberToEdit &&
                                  (m['member_reference'] ?? '').toString().toUpperCase() == clean);
                              if (dup) return 'Code in use';
                              return null;
                            },
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedGroupRef,
                                  isExpanded: true,
                                  dropdownColor: tokens.surfaceElevated,
                                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                  decoration: const InputDecoration(
                                    labelText: 'Solidarity Group *',
                                    labelStyle: TextStyle(fontSize: 12),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: availableGroups.map((g) {
                                    final gRef = g['group_reference'] ?? '';
                                    final gName = g['group_name'] ?? '';
                                    return DropdownMenuItem(
                                      value: gRef.toString(),
                                      child: Text(
                                        '$gRef ($gName)',
                                        style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() {
                                        selectedGroupRef = val;
                                        if (!isEditing) {
                                          refCtrl.text = '$branchCode-${selectedGroupRef.replaceAll('GRP-', '')}-${nextSeq.toString().padLeft(3, '0')}';
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: refCtrl,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    labelText: 'Member Code *',
                                    hintText: 'e.g. BR-01-001',
                                    labelStyle: TextStyle(fontSize: 12),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(),
                                  ),
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Required';
                                    final clean = val.trim().toUpperCase();
                                    final dup = _members.any((m) =>
                                        m != memberToEdit &&
                                        (m['member_reference'] ?? '').toString().toUpperCase() == clean);
                                    if (dup) return 'Code in use';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Full Name
                        TextFormField(
                          controller: nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full Client Name *',
                            hintText: 'e.g. Amina Bello',
                            labelStyle: TextStyle(fontSize: 12),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            border: OutlineInputBorder(),
                          ),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                          validator: (val) =>
                              (val == null || val.trim().isEmpty) ? 'Please enter client name' : null,
                        ),
                        const SizedBox(height: 14),

                        // Phone & Home Address
                        if (isMobileModal) ...[
                          TextFormField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              hintText: 'e.g. 08012345678',
                              labelStyle: TextStyle(fontSize: 12),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              border: OutlineInputBorder(),
                            ),
                            style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: addressCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Residential / Shop Address',
                              hintText: 'e.g. Shop 4B Akowonjo',
                              labelStyle: TextStyle(fontSize: 12),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              border: OutlineInputBorder(),
                            ),
                            style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone Number',
                                    hintText: 'e.g. 08012345678',
                                    labelStyle: TextStyle(fontSize: 12),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(),
                                  ),
                                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: addressCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Residential / Shop Address',
                                    hintText: 'e.g. Shop 4B Akowonjo',
                                    labelStyle: TextStyle(fontSize: 12),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(),
                                  ),
                                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Opening Savings
                        TextFormField(
                          controller: savingsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Opening Savings Deposit (₦)',
                            prefixText: '₦ ',
                            hintText: '0.00',
                            labelStyle: TextStyle(fontSize: 12),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            border: OutlineInputBorder(),
                          ),
                          style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                        ),
                        const SizedBox(height: 16),

                        // Existing Loan Section Toggle
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: hasActiveLoan ? tokens.infoBg : tokens.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: hasActiveLoan ? tokens.infoBorder : tokens.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.credit_card_outlined,
                                size: 18,
                                color: hasActiveLoan ? tokens.infoDot : tokens.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Client Has Pre-Existing / Active Loan',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                                    ),
                                    Text(
                                      'Enable to migrate an existing active loan running before onboarding.',
                                      style: TextStyle(fontSize: 11, color: tokens.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: hasActiveLoan,
                                activeThumbColor: tokens.brandAccent,
                                onChanged: (val) {
                                  setModalState(() {
                                    hasActiveLoan = val;
                                    if (!val) {
                                      principalCtrl.clear();
                                      creditCtrl.clear();
                                      balanceCtrl.clear();
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        // Expanded Loan Details
                        if (hasActiveLoan) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: tokens.surfaceSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: tokens.borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (productOptions.isNotEmpty)
                                  DropdownButtonFormField<String>(
                                    initialValue: selectedProduct,
                                    isExpanded: true,
                                    dropdownColor: tokens.surfaceElevated,
                                    style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                    decoration: const InputDecoration(
                                      labelText: 'Loan Product *',
                                      labelStyle: TextStyle(fontSize: 12),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: productOptions.map((prod) {
                                      return DropdownMenuItem(value: prod, child: Text(prod, style: TextStyle(fontSize: 13, color: tokens.textPrimary)));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => selectedProduct = val);
                                    },
                                  )
                                else
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: tokens.warningBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: tokens.warningBorder),
                                    ),
                                    child: Text(
                                      'Loan products catalog unavailable; enter loan amounts below or refresh session.',
                                      style: TextStyle(fontSize: 12, color: tokens.warningText),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                if (isMobileModal) ...[
                                  TextFormField(
                                    controller: principalCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Principal Loan (₦) *',
                                      prefixText: '₦ ',
                                      hintText: 'e.g. 100,000',
                                      helperText: 'Base capital borrowed or asset cost',
                                      helperMaxLines: 1,
                                      labelStyle: TextStyle(fontSize: 11.5),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                      border: OutlineInputBorder(),
                                    ),
                                    style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                    validator: (val) {
                                      if (!hasActiveLoan) return null;
                                      if (val == null || val.trim().isEmpty) return 'Required';
                                      final amt = double.tryParse(val.replaceAll(',', '').trim()) ?? 0;
                                      if (amt <= 0) return 'Must be > 0';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: creditCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Active Credit Disbursed (₦) *',
                                      prefixText: '₦ ',
                                      hintText: 'e.g. 120,000',
                                      helperText: 'Total scheduled repayable debt',
                                      helperMaxLines: 1,
                                      labelStyle: TextStyle(fontSize: 11.5),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                      border: OutlineInputBorder(),
                                    ),
                                    style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                    onChanged: (_) => setModalState(() {}),
                                    validator: (val) {
                                      if (!hasActiveLoan) return null;
                                      if (val == null || val.trim().isEmpty) return 'Required';
                                      final amt = double.tryParse(val.replaceAll(',', '').trim()) ?? 0;
                                      if (amt <= 0) return 'Must be > 0';
                                      return null;
                                    },
                                  ),
                                ] else ...[
                                  Row(
                                    children: [
                                      Expanded(
                                      child: TextFormField(
                                        controller: principalCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Principal Loan (₦) *',
                                          prefixText: '₦ ',
                                          hintText: 'e.g. 100,000',
                                          helperText: 'Base capital borrowed or asset cost',
                                          helperMaxLines: 1,
                                          labelStyle: TextStyle(fontSize: 11.5),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                          border: OutlineInputBorder(),
                                        ),
                                        style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                        validator: (val) {
                                          if (!hasActiveLoan) return null;
                                          if (val == null || val.trim().isEmpty) return 'Required';
                                          final amt = double.tryParse(val.replaceAll(',', '').trim()) ?? 0;
                                          if (amt <= 0) return 'Must be > 0';
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: creditCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Active Credit Disbursed (₦) *',
                                          prefixText: '₦ ',
                                          hintText: 'e.g. 120,000',
                                          helperText: 'Total scheduled repayable debt',
                                          helperMaxLines: 1,
                                          labelStyle: TextStyle(fontSize: 11.5),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                          border: OutlineInputBorder(),
                                        ),
                                        style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                        onChanged: (_) => setModalState(() {}),
                                        validator: (val) {
                                          if (!hasActiveLoan) return null;
                                          if (val == null || val.trim().isEmpty) return 'Required';
                                          final amt = double.tryParse(val.replaceAll(',', '').trim()) ?? 0;
                                          if (amt <= 0) return 'Must be > 0';
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                                TextFormField(
                                  controller: balanceCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Outstanding Balance (₦) *',
                                    prefixText: '₦ ',
                                    hintText: 'e.g. 45,000',
                                    helperText: 'Current uncollected balance',
                                    helperMaxLines: 1,
                                    labelStyle: TextStyle(fontSize: 11.5),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(),
                                  ),
                                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                  onChanged: (_) => setModalState(() {}),
                                  validator: (val) {
                                    if (!hasActiveLoan) return null;
                                    if (val == null || val.trim().isEmpty) return 'Required';
                                    final bal = double.tryParse(val.replaceAll(',', '').trim()) ?? 0;
                                    final cred = double.tryParse(creditCtrl.text.replaceAll(',', '').trim()) ?? 0;
                                    if (bal < 0) return 'Cannot be negative';
                                    if (bal > cred && cred > 0) return 'Exceeds credit';
                                    return null;
                                  },
                                ),
                                if (enteredCred > 0) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: tokens.infoBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: tokens.infoBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calculate_outlined, size: 16, color: tokens.infoDot),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Scheduled Installment: ${CurrencyFormatter.formatNaira(calcInstallment)} / period ($prodInstallments total)'
                                            '${enteredBal > 0 ? ' • ~$estRemainingCount remaining' : ''}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: tokens.infoText,
                                              fontFeatures: const [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: tokens.textSecondary,
                                side: BorderSide(color: tokens.borderStrong),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tokens.brandPrimaryDark,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              onPressed: () {
                                if (!formKey.currentState!.validate()) return;

                                final cleanRef = refCtrl.text.trim().toUpperCase();
                                final cleanName = nameCtrl.text.trim();
                                final cleanPhone = phoneCtrl.text.trim();
                                final cleanAddress = addressCtrl.text.trim();
                                final cleanSavings = double.tryParse(savingsCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

                                final cleanPrincipal = hasActiveLoan
                                    ? (double.tryParse(principalCtrl.text.replaceAll(',', '').trim()) ?? 0.0)
                                    : 0.0;
                                final cleanActiveCred = hasActiveLoan
                                    ? (double.tryParse(creditCtrl.text.replaceAll(',', '').trim()) ?? cleanPrincipal)
                                    : 0.0;
                                final cleanCurBal = hasActiveLoan
                                    ? (double.tryParse(balanceCtrl.text.replaceAll(',', '').trim()) ?? 0.0)
                                    : 0.0;
                                final cleanProd = hasActiveLoan
                                    ? (selectedProduct.isNotEmpty
                                        ? selectedProduct
                                        : (productOptions.isNotEmpty ? productOptions.first : ''))
                                    : (productOptions.isNotEmpty ? productOptions.first : '');

                                final finalPrincipal = cleanPrincipal > 0 ? cleanPrincipal : cleanActiveCred;

                                setState(() {
                                  if (isEditing) {
                                    memberToEdit['member_reference'] = cleanRef;
                                    memberToEdit['group_reference'] = selectedGroupRef;
                                    memberToEdit['full_name'] = cleanName;
                                    memberToEdit['phone_number'] = cleanPhone;
                                    memberToEdit['home_address'] = cleanAddress;
                                    memberToEdit['savings_balance'] = cleanSavings;
                                    memberToEdit['loan_type'] = cleanProd;
                                    memberToEdit['principal_loan'] = finalPrincipal;
                                    memberToEdit['active_credit'] = cleanActiveCred;
                                    memberToEdit['current_credit_balance'] = cleanCurBal;
                                  } else {
                                    _members.add({
                                      'member_reference': cleanRef,
                                      'group_reference': selectedGroupRef,
                                      'member_number': nextSeq,
                                      'full_name': cleanName,
                                      'phone_number': cleanPhone,
                                      'home_address': cleanAddress,
                                      'savings_balance': cleanSavings,
                                      'loan_type': cleanProd,
                                      'principal_loan': finalPrincipal,
                                      'active_credit': cleanActiveCred,
                                      'current_credit_balance': cleanCurBal,
                                    });
                                  }
                                });

                                Navigator.of(ctx).pop();
                                _saveDraft();
                                _showBanner(
                                  isEditing
                                      ? 'Member "$cleanName" updated.'
                                      : 'Member "$cleanName" registered successfully.',
                                  isSuccess: true,
                                );
                              },
                              icon: Icon(isEditing ? Icons.check : Icons.person_add_alt_1, size: 16),
                               label: Text(isEditing ? 'Update Member' : 'Save Member', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        refCtrl.dispose();
        nameCtrl.dispose();
        phoneCtrl.dispose();
        addressCtrl.dispose();
        savingsCtrl.dispose();
        principalCtrl.dispose();
        creditCtrl.dispose();
        balanceCtrl.dispose();
      });
    });
  }

  void _confirmDeleteMember(Map<String, dynamic> m) {
    final name = m['full_name'] ?? 'Client';
    final refCode = m['member_reference'] ?? '';

    showIcareAdaptiveSheet<void>(
      context: context,
      fitContent: true,
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.delete_outline, color: tokens.dangerDot, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Remove Member',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to remove "$name" ($refCode) from this branch onboarding package?',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: tokens.textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.dangerDot,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() => _members.remove(m));
                      _saveDraft();
                      _showBanner('Member "$name" removed.', isSuccess: true);
                    },
                    child: const Text('Delete Member'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteGroup(Map<String, dynamic> g) {
    final gRef = g['group_reference'] ?? '';
    final gName = g['group_name'] ?? 'Group';
    final memberCount = _members.where((m) => m['group_reference'] == gRef).length;

    showIcareAdaptiveSheet<void>(
      context: context,
      fitContent: true,
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: tokens.dangerDot, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Delete Solidarity Group',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                memberCount > 0
                    ? 'Warning: Group "$gName" ($gRef) currently has $memberCount member(s) registered. Deleting this group will also remove all $memberCount member(s) from the roster.\n\nAre you sure you want to proceed?'
                    : 'Are you sure you want to delete group "$gName" ($gRef)?',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: tokens.textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.dangerDot,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _members.removeWhere((m) => m['group_reference'] == gRef);
                        _groups.remove(g);
                        if (_selectedGroupFilter == gRef) {
                          _selectedGroupFilter = 'All';
                        }
                      });
                      _saveDraft();
                      _showBanner('Group "$gName" and assigned members removed.', isSuccess: true);
                    },
                    child: const Text('Delete Group'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> get _scopedGroups {
    if (_scopedOfficer != null && _scopedOfficer!.isNotEmpty) {
      final name = _scopedOfficer!.trim().toLowerCase();
      return _groups.where((g) => (g['officer_name'] ?? '').toString().trim().toLowerCase() == name).toList();
    }
    if (_selectedOfficerFilter != 'All') {
      final name = _selectedOfficerFilter.trim().toLowerCase();
      return _groups.where((g) => (g['officer_name'] ?? '').toString().trim().toLowerCase() == name).toList();
    }
    return _groups;
  }

  Set<String> get _scopedGroupRefs {
    return _scopedGroups.map((g) => (g['group_reference'] ?? '').toString().toUpperCase()).toSet();
  }

  List<Map<String, dynamic>> get _scopedMembers {
    if (_scopedOfficer != null && _scopedOfficer!.isNotEmpty) {
      final refs = _scopedGroupRefs;
      return _members.where((m) => refs.contains((m['group_reference'] ?? '').toString().toUpperCase())).toList();
    }
    if (_selectedOfficerFilter != 'All') {
      final refs = _scopedGroupRefs;
      return _members.where((m) => refs.contains((m['group_reference'] ?? '').toString().toUpperCase())).toList();
    }
    return _members;
  }

  double get _totalMemberSavings => _members.fold(0.0, (sum, m) => sum + (double.tryParse(m['savings_balance']?.toString() ?? '0') ?? 0.0));
  double get _totalGroupSavings => _groups.fold(0.0, (sum, g) => sum + (double.tryParse(g['group_savings']?.toString() ?? '0') ?? 0.0));
  double get _totalSavings => _totalMemberSavings + _totalGroupSavings + _miscSavings;
  double get _totalPrincipalLoan => _members.fold(0.0, (sum, m) {
    final p = double.tryParse(m['principal_loan']?.toString() ?? '');
    final a = double.tryParse(m['active_credit']?.toString() ?? '0') ?? 0.0;
    return sum + (p != null && p > 0 ? p : a);
  });
  double get _totalActiveCredit => _members.fold(0.0, (sum, m) => sum + (double.tryParse(m['active_credit']?.toString() ?? '0') ?? 0.0));
  double get _totalCurrentBalance => _members.fold(0.0, (sum, m) => sum + (double.tryParse(m['current_credit_balance']?.toString() ?? '0') ?? 0.0));

  bool get _isGroupFiltered => _selectedGroupFilter != 'All';

  List<Map<String, dynamic>> get _currentFilteredGroups {
    final base = _scopedOfficer != null ? _scopedGroups : _groups;
    if (!_isGroupFiltered) return base;
    return base.where((g) => (g['group_reference'] ?? '').toString().toUpperCase() == _selectedGroupFilter.toUpperCase()).toList();
  }

  List<Map<String, dynamic>> get _currentFilteredMembers {
    final base = _scopedOfficer != null ? _scopedMembers : _members;
    if (!_isGroupFiltered) return base;
    return base.where((m) => (m['group_reference'] ?? '').toString().toUpperCase() == _selectedGroupFilter.toUpperCase()).toList();
  }

  double get _displayMemberSavings => _currentFilteredMembers
      .fold(0.0, (sum, m) => sum + (double.tryParse(m['savings_balance']?.toString() ?? '0') ?? 0.0));

  double get _displayGroupSavings => _currentFilteredGroups
      .fold(0.0, (sum, g) => sum + (double.tryParse(g['group_savings']?.toString() ?? '0') ?? 0.0));

  double get _displayTotalSavings {
    if (_isGroupFiltered) {
      return _displayMemberSavings + _displayGroupSavings;
    }
    return _displayMemberSavings + _displayGroupSavings + (_scopedOfficer == null ? (_miscSavings + _lapsSavings) : _displayOfficerMiscSavings);
  }

  double get _displayOfficerMiscSavings {
    if (_scopedOfficer == null) return 0.0;
    final off = _officers.firstWhere(
      (o) => (o['name'] ?? o['officer_name'])?.toString().trim().toLowerCase() == _scopedOfficer!.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    if (off['is_misc_savings_manager'] == true) {
      return _miscSavings;
    }
    return 0.0;
  }

  double get _displayPrincipalLoan => _currentFilteredMembers.fold(0.0, (sum, m) {
    final p = double.tryParse((m['principal'] ?? m['principal_loan'] ?? m['loan_amount'])?.toString() ?? '');
    final a = double.tryParse(m['active_credit']?.toString() ?? '0') ?? 0.0;
    return sum + (p != null && p > 0 ? p : a);
  });

  double get _displayActiveCredit => _currentFilteredMembers
      .fold(0.0, (sum, m) => sum + (double.tryParse(m['active_credit']?.toString() ?? '0') ?? 0.0));

  double get _displayCurrentBalance => _currentFilteredMembers
      .fold(0.0, (sum, m) => sum + (double.tryParse((m['current_credit_balance'] ?? m['current_balance'])?.toString() ?? '0') ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Center(
            child: SizedBox(
              width: 1100,
              child: IcareOnboardingSkeleton(cardCount: 3),
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: tokens.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.borderSubtle),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: tokens.dangerBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: tokens.dangerBorder),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 26,
                      color: tokens.dangerDot,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Branch Onboarding Access',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _tokenCtrl,
                    style: TextStyle(color: tokens.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Branch Manager or Officer Token',
                      hintText: 'e.g. onb_branch_... or onb_co_...',
                      prefixIcon: const Icon(Icons.key, size: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimaryDark,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        final inputToken = _tokenCtrl.text.trim();
                        if (inputToken.startsWith('onb_co_')) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => CreditOfficerPortalScreen(coToken: inputToken)),
                          );
                          return;
                        }
                        setState(() {
                          _currentToken = inputToken;
                        });
                        _loadSessionData();
                      },
                      icon: const Icon(Icons.login, size: 16),
                      label: const Text(
                        'Access Onboarding Session',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    icon: Icon(Icons.arrow_back, size: 14, color: tokens.textMuted),
                    label: Text(
                      'Return to Staff Login',
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final branchName = _sessionData?['branch_name'] ?? 'Branch';
    final branchCode = _sessionData?['branch_code'] ?? 'BR';
    final status = _sessionData?['status'] ?? 'draft';
    final isSubmitted = status == 'submitted' || status == 'approved';

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // Top Institutional App Bar
            _buildInstitutionalHeader(branchName, branchCode, status, isSubmitted),

            // Notification Status Banner
            if (_bannerMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: _isSuccessBanner ? tokens.successBg : tokens.dangerBg,
                child: Row(
                  children: [
                    Icon(
                      _isSuccessBanner ? Icons.check_circle_outline : Icons.error_outline,
                      size: 16,
                      color: _isSuccessBanner ? tokens.successText : tokens.dangerText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _bannerMessage!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _isSuccessBanner ? tokens.successText : tokens.dangerText,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 14, color: tokens.textMuted),
                      onPressed: () => setState(() => _bannerMessage = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  ],
                ),
              ),

            // Summary Metrics Bar
            _buildSummaryMetricsBar(),

            // Scoped Officer Workspace Indicator
            if (_scopedOfficer != null && _scopedOfficer!.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 650;
                  if (isMobile) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: tokens.infoBg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person_pin_outlined, size: 15, color: tokens.infoText),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Workspace: $_scopedOfficer',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.infoText),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => setState(() => _scopedOfficer = null),
                                child: Text('Show All (AM)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.infoText)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Showing your assigned groups and members. Uploads and edits are merged safely.',
                            style: TextStyle(fontSize: 10.5, color: tokens.infoText),
                          ),
                        ],
                      ),
                    );
                  }
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: tokens.infoBg,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: tokens.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tokens.infoBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_pin_outlined, size: 14, color: tokens.infoText),
                              const SizedBox(width: 4),
                              Text(
                                'Credit Officer Workspace: $_scopedOfficer',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.infoText),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Showing groups and members assigned to your portfolio. Edits and uploads merge safely without clobbering other officers.',
                            style: TextStyle(fontSize: 11.5, color: tokens.infoText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!_isEnforcedOfficerScope)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(Icons.remove_red_eye_outlined, size: 13, color: tokens.infoText),
                            label: Text('View All Branch Data (AM Mode)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.infoText)),
                            onPressed: () {
                              setState(() {
                                _scopedOfficer = null;
                                _tabController.dispose();
                                _tabController = TabController(length: 5, vsync: this);
                              });
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),

            // Tab Navigation Header
            Container(
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
              ),
              child: LayoutBuilder(
                builder: (context, tabConstraints) {
                  final isTabScrollable = tabConstraints.maxWidth < 650;
                  final isOfficer = _scopedOfficer != null && _scopedOfficer!.isNotEmpty;
                  return TabBar(
                    controller: _tabController,
                    isScrollable: isTabScrollable,
                    tabAlignment: isTabScrollable ? TabAlignment.start : TabAlignment.fill,
                    labelColor: tokens.brandPrimary,
                    unselectedLabelColor: tokens.textMuted,
                    indicatorColor: tokens.brandPrimary,
                    indicatorWeight: 2.5,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    onTap: (index) => _tabController.animateTo(index),
                    tabs: isOfficer
                        ? [
                            Tab(
                              icon: const Icon(Icons.groups_outlined, size: 18),
                              text: 'My Members (${_scopedMembers.length})',
                            ),
                            Tab(
                              icon: const Icon(Icons.hub_outlined, size: 18),
                              text: 'My Groups (${_scopedGroups.length})',
                            ),
                            const Tab(
                              icon: Icon(Icons.upload_file_outlined, size: 18),
                              text: 'Excel Uploader',
                            ),
                            const Tab(
                              icon: Icon(Icons.verified_outlined, size: 18),
                              text: 'Review & Submit',
                            ),
                          ]
                        : [
                            Tab(
                              icon: const Icon(Icons.badge_outlined, size: 18),
                              text: 'Credit Officers & Links (${_officers.length})',
                            ),
                            Tab(
                              icon: const Icon(Icons.groups_outlined, size: 18),
                              text: 'Member Roster (${_members.length})',
                            ),
                            Tab(
                              icon: const Icon(Icons.hub_outlined, size: 18),
                              text: 'Solidarity Groups (${_groups.length})',
                            ),
                            const Tab(
                              icon: Icon(Icons.upload_file_outlined, size: 18),
                              text: 'Excel Uploader',
                            ),
                            const Tab(
                              icon: Icon(Icons.verified_outlined, size: 18),
                              text: 'Review & Submit to AM',
                            ),
                          ],
                  );
                },
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: (_scopedOfficer != null && _scopedOfficer!.isNotEmpty)
                    ? [
                        _buildMembersGridTab(isSubmitted),
                        _buildGroupsTab(isSubmitted),
                        _buildExcelUploaderTab(isSubmitted),
                        _buildReviewSignOffTab(isSubmitted),
                      ]
                    : [
                        _buildOfficersAndReservesTab(isSubmitted),
                        _buildMembersGridTab(isSubmitted),
                        _buildGroupsTab(isSubmitted),
                        _buildExcelUploaderTab(isSubmitted),
                        _buildReviewSignOffTab(isSubmitted),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstitutionalHeader(String branchName, String branchCode, String status, bool isSubmitted) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 620;

          final titleSection = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: tokens.brandSoftBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.brandSoftBorder),
                ),
                child: Icon(Icons.account_balance, size: 18, color: tokens.brandSoftText),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'ICARE Onboarding Portal',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        IcareStatusBadge.fromStatus(status),
                        if (_scopedOfficer == null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: tokens.brandPrimaryDark,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BRANCH MANAGER PORTAL',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      _scopedOfficer == null
                          ? '$branchName ($branchCode) — Branch Manager Portal'
                          : '$branchName ($branchCode) — Credit Officer: $_scopedOfficer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );

          final actionsSection = Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            children: [
              if (!isSubmitted) ...[
                if (_lastSavedTime != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      'Saved ${DateFormat('HH:mm').format(_lastSavedTime!)}',
                      style: TextStyle(fontSize: 11, color: tokens.textMuted, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                    side: BorderSide(color: tokens.borderStrong),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _isSaving ? null : _saveDraft,
                  icon: _isSaving
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 14),
                  label: const Text('Save Draft', style: TextStyle(fontSize: 11.5)),
                ),
                if (_scopedOfficer != null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brandPrimaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: (_isSaving || isSubmitted) ? null : _submitScopedOfficerRoster,
                    icon: const Icon(Icons.send_outlined, size: 14),
                    label: const Text('Submit to BM', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brandPrimaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _isSaving ? null : _submitPackage,
                    icon: const Icon(Icons.send_outlined, size: 14),
                    label: const Text('Submit to AM', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
              ] else if (status.toLowerCase() == 'submitted') ...[
                if (_scopedOfficer == null && _isAmOrAdmin) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brandPrimaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _isSaving ? null : _amApprovePackage,
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: const Text('Approve & Commit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tokens.borderStrong),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 13, color: tokens.successDot),
                        const SizedBox(width: 4),
                        Text('Submitted to AM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                IcareStatusBadge.fromStatus('approved'),
              ],
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleSection,
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: actionsSection,
                ),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleSection),
              actionsSection,
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryMetricsBar() {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      color: tokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;
              final isScoped = _scopedOfficer != null && _scopedOfficer!.isNotEmpty;
              final isFiltered = _isGroupFiltered;

              final items = <Widget>[
                if (isScoped)
                  _buildMetricCardChip('Portfolio Officer', _scopedOfficer!, Icons.badge_outlined, tokens.brandAccent)
                else if (!isFiltered)
                  _buildMetricCardChip('Officers', _officers.length.toString(), Icons.badge_outlined, tokens.brandAccent),

                if (isFiltered)
                  _buildMetricCardChip('Filtered Group', _selectedGroupFilter, Icons.filter_alt_outlined, tokens.infoDot)
                else
                  _buildMetricCardChip(isScoped ? 'My Groups' : 'Groups', _currentFilteredGroups.length.toString(), Icons.hub_outlined, tokens.textPrimary),

                _buildMetricCardChip(isFiltered ? 'Group Members' : (isScoped ? 'My Members' : 'Members'), _currentFilteredMembers.length.toString(), Icons.people_outline, tokens.textPrimary),

                if (isFiltered) ...[
                  _buildMetricCardChip('Group Savings', CurrencyFormatter.formatNaira(_displayGroupSavings), Icons.savings_outlined, tokens.brandAccent),
                  _buildMetricCardChip('Member Savings', CurrencyFormatter.formatNaira(_displayMemberSavings), Icons.savings_outlined, tokens.successDot),
                ],

                _buildMetricCardChip(isFiltered ? 'Total Group Savings' : 'Total Savings', CurrencyFormatter.formatNaira(_displayTotalSavings), Icons.savings_outlined, tokens.successText),

                if (!isFiltered && _scopedOfficer == null && _miscSavings > 0)
                  _buildMetricCardChip('Misc Savings', CurrencyFormatter.formatNaira(_miscSavings), Icons.account_balance_wallet_outlined, tokens.brandAccent),

                if (_displayPrincipalLoan > 0)
                  _buildMetricCardChip('Principal Disbursed', CurrencyFormatter.formatNaira(_displayPrincipalLoan), Icons.account_balance_outlined, tokens.infoDot),

                _buildMetricCardChip('Active Credit', CurrencyFormatter.formatNaira(_displayActiveCredit), Icons.credit_card_outlined, tokens.infoDot),
                _buildMetricCardChip('Outstanding Balance', CurrencyFormatter.formatNaira(_displayCurrentBalance), Icons.account_balance_wallet_outlined, tokens.warningText),
              ];

              if (isNarrow) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: items.map((e) => Padding(padding: const EdgeInsets.only(right: 10), child: e)).toList(),
                  ),
                );
              }

              return Row(
                children: items.map((e) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: e))).toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCardChip(String label, String value, IconData icon, Color color) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Flexible(
            fit: FlexFit.loose,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: tokens.textMuted, letterSpacing: 0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: MEMBERS ROSTER GRID
  // =========================================================================

  Widget _buildMembersGridTab(bool isSubmitted) {
    final tokens = IcareSurfaceTokens.of(context);
    final availableGroups = _scopedGroups;
    final baseMembers = _scopedMembers;

    final filtered = baseMembers.where((m) {
      if (_selectedGroupFilter != 'All' && m['group_reference'] != _selectedGroupFilter) {
        return false;
      }
      final q = _searchCtrl.text.toLowerCase().trim();
      if (q.isNotEmpty) {
        final name = (m['full_name'] ?? '').toString().toLowerCase();
        final ref = (m['member_reference'] ?? '').toString().toLowerCase();
        final phone = (m['phone_number'] ?? '').toString().toLowerCase();
        return name.contains(q) || ref.contains(q) || phone.contains(q);
      }
      return true;
    }).toList();

    final officerNames = _officers
        .map((o) => (o['name'] ?? o['officer_name'] ?? '').toString().trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Responsive Filter & Search Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 640;

              final officerDropdown = (_scopedOfficer == null && officerNames.isNotEmpty)
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tokens.borderStrong),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedOfficerFilter,
                          isExpanded: isNarrow,
                          dropdownColor: tokens.surfaceElevated,
                          icon: Icon(Icons.arrow_drop_down, size: 18, color: tokens.textMuted),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('All Officers')),
                            ...officerNames.map((n) => DropdownMenuItem(value: n, child: Text(n))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedOfficerFilter = val;
                                _selectedGroupFilter = 'All';
                              });
                            }
                          },
                        ),
                      ),
                    )
                  : null;

              final groupDropdown = Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.borderStrong),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedGroupFilter,
                    isExpanded: isNarrow,
                    dropdownColor: tokens.surfaceElevated,
                    icon: Icon(Icons.arrow_drop_down, size: 18, color: tokens.textMuted),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                    items: [
                      const DropdownMenuItem(value: 'All', child: Text('All Groups')),
                      ...availableGroups.map((g) => DropdownMenuItem(
                            value: g['group_reference']?.toString(),
                            child: Text('${g['group_reference']} (${g['group_name']})'),
                          )),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedGroupFilter = val);
                    },
                  ),
                ),
              );

              final searchField = SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search members by name, phone or code...',
                    hintStyle: TextStyle(fontSize: 12, color: tokens.textMuted),
                    prefixIcon: Icon(Icons.search, size: 16, color: tokens.textMuted),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    filled: true,
                    fillColor: tokens.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
                  ),
                ),
              );

              final addMemberBtn = ifBtn(!isSubmitted, () {
                return ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onPressed: _addMember,
                  icon: const Icon(Icons.person_add_alt_1, size: 15),
                  label: const Text('Add Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                );
              });

              if (isNarrow) {
                return Column(
                  children: [
                    if (officerDropdown != null) ...[
                      Row(
                        children: [
                          Expanded(child: officerDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: groupDropdown),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: searchField),
                          if (addMemberBtn != null) ...[
                            const SizedBox(width: 8),
                            addMemberBtn,
                          ],
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(child: groupDropdown),
                          if (addMemberBtn != null) ...[
                            const SizedBox(width: 8),
                            addMemberBtn,
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      searchField,
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  if (officerDropdown != null) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: officerDropdown,
                    ),
                    const SizedBox(width: 8),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: groupDropdown,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: searchField),
                  if (addMemberBtn != null) ...[
                    const SizedBox(width: 12),
                    addMemberBtn,
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Table / Card Area
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 40, color: tokens.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          _members.isEmpty
                              ? 'No members registered yet. Click "Add Member" or upload your Excel template.'
                              : (_scopedOfficer != null
                                  ? 'No members found for $_scopedOfficer matching current filters.'
                                  : 'No members match the current search or filter criteria.'),
                          style: TextStyle(fontSize: 13, color: tokens.textMuted),
                        ),
                        if (_members.isEmpty && !isSubmitted) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tokens.brandPrimaryDark,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _addMember,
                            icon: const Icon(Icons.person_add_alt_1, size: 16),
                            label: const Text('Add First Member', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, listConstraints) {
                      final isMobile = listConstraints.maxWidth < 650;

                      if (isMobile) {
                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final m = filtered[idx];
                            return _buildMemberCardMobile(m, isSubmitted);
                          },
                        );
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: tokens.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: tokens.borderSubtle),
                            itemBuilder: (context, idx) {
                              final m = filtered[idx];
                              return _buildMemberRowDesktop(m, isSubmitted);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget? ifBtn(bool condition, Widget Function() builder) {
    return condition ? builder() : null;
  }

  Widget _buildMemberCardMobile(Map<String, dynamic> m, bool isSubmitted) {
    final tokens = IcareSurfaceTokens.of(context);
    final refCode = m['member_reference'] ?? 'Pending';
    final gRef = (m['group_reference'] ?? '').toString();
    final name = m['full_name'] ?? '';
    final phone = m['phone_number'] ?? '';
    final savings = double.tryParse(m['savings_balance']?.toString() ?? '0') ?? 0.0;
    final activeCred = double.tryParse(m['active_credit']?.toString() ?? '0') ?? 0.0;
    final princLoan = double.tryParse(m['principal_loan']?.toString() ?? '') ?? activeCred;
    final curBal = double.tryParse(m['current_credit_balance']?.toString() ?? '0') ?? 0.0;
    final prod = (m['loan_type'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges + Actions
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: tokens.borderStrong),
                ),
                child: Text(refCode, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.infoBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: tokens.infoBorder),
                ),
                child: Text(gRef, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tokens.infoText)),
              ),
              const Spacer(),
              if (!isSubmitted) ...[
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 16, color: tokens.infoDot),
                  tooltip: 'Edit member',
                  onPressed: () => _showMemberModal(memberToEdit: m),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 16, color: tokens.dangerDot),
                  tooltip: 'Remove member',
                  onPressed: () => _confirmDeleteMember(m),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Name & Phone
          Text(name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 12, color: phone.isNotEmpty ? tokens.textMuted : tokens.dangerText),
              const SizedBox(width: 4),
              Text(
                phone.isNotEmpty ? phone : 'No phone entered',
                style: TextStyle(
                  fontSize: 11.5,
                  color: phone.isNotEmpty ? tokens.textMuted : tokens.dangerText,
                ),
              ),
              if (activeCred > 0) ...[
                const SizedBox(width: 8),
                Text('•', style: TextStyle(color: tokens.textMuted)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    prod,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.infoText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // 3-Box Metrics Strip
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: tokens.successBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.successBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SAVINGS', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: tokens.successText)),
                      Text(
                        CurrencyFormatter.formatNaira(savings),
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: tokens.successText, fontFeatures: const [FontFeature.tabularFigures()]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: tokens.infoBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.infoBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ACTIVE CREDIT', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: tokens.infoText)),
                      Text(
                        activeCred > 0 ? CurrencyFormatter.formatNaira(activeCred) : 'None',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: activeCred > 0 ? tokens.textPrimary : tokens.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (activeCred > 0 && princLoan > 0)
                        Text(
                          'Prin: ${CurrencyFormatter.formatNaira(princLoan)}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: tokens.textMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: tokens.warningBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.warningBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('REMAINING', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: tokens.warningText)),
                      Text(
                        curBal > 0 ? CurrencyFormatter.formatNaira(curBal) : '₦0.00',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: curBal > 0 ? tokens.warningText : tokens.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRowDesktop(Map<String, dynamic> m, bool isSubmitted) {
    final tokens = IcareSurfaceTokens.of(context);
    final refCode = m['member_reference'] ?? 'Pending Code';
    final gRef = (m['group_reference'] ?? '').toString();
    final name = m['full_name'] ?? '';
    final phone = m['phone_number'] ?? '';
    final savings = double.tryParse(m['savings_balance']?.toString() ?? '0') ?? 0.0;
    final activeCred = double.tryParse(m['active_credit']?.toString() ?? '0') ?? 0.0;
    final princLoan = double.tryParse(m['principal_loan']?.toString() ?? '') ?? activeCred;
    final curBal = double.tryParse(m['current_credit_balance']?.toString() ?? '0') ?? 0.0;
    final prod = (m['loan_type'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Index & Reference
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(refCode, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                Text(gRef, style: TextStyle(fontSize: 9.5, color: tokens.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Client Name & Phone
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                Text(
                  phone.isNotEmpty ? phone : 'No phone entered',
                  style: TextStyle(
                    fontSize: 11,
                    color: phone.isNotEmpty ? tokens.textMuted : tokens.dangerText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Savings Balance
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('SAVINGS', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: tokens.textMuted)),
                Text(
                  CurrencyFormatter.formatNaira(savings),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tokens.successText, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Loan Product & Active Credit
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  prod,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tokens.infoText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  activeCred > 0 ? CurrencyFormatter.formatNaira(activeCred) : 'No Loan',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: activeCred > 0 ? tokens.textPrimary : tokens.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (activeCred > 0 && princLoan > 0)
                  Text(
                    'Prin: ${CurrencyFormatter.formatNaira(princLoan)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: tokens.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Current Outstanding Balance
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('REMAINING', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: tokens.textMuted)),
                Text(
                  curBal > 0 ? CurrencyFormatter.formatNaira(curBal) : '₦0.00',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: curBal > 0 ? tokens.warningText : tokens.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          if (!isSubmitted) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 16, color: tokens.infoDot),
              tooltip: 'Edit member',
              onPressed: () => _showMemberModal(memberToEdit: m),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: tokens.dangerDot),
              tooltip: 'Remove member',
              onPressed: () => _confirmDeleteMember(m),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: SOLIDARITY GROUPS
  // =========================================================================

  Widget _buildGroupsTab(bool isSubmitted) {
    final tokens = IcareSurfaceTokens.of(context);
    final displayedGroups = _scopedGroups;

    final officerNames = _officers
        .map((o) => (o['name'] ?? o['officer_name'] ?? '').toString().trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _scopedOfficer != null
                    ? 'Solidarity Groups ($_scopedOfficer)'
                    : 'Branch Solidarity Groups',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.textPrimary),
              ),
              if (!isSubmitted)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: tokens.brandPrimaryDark, foregroundColor: Colors.white),
                  onPressed: _addGroup,
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Add Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (_scopedOfficer == null && officerNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: _selectedOfficerFilter == 'All',
                      label: const Text('All Officers', style: TextStyle(fontSize: 11)),
                      onSelected: (_) => setState(() {
                        _selectedOfficerFilter = 'All';
                        _selectedGroupFilter = 'All';
                      }),
                    ),
                  ),
                  ...officerNames.map((name) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          selected: _selectedOfficerFilter == name,
                          label: Text(name, style: const TextStyle(fontSize: 11)),
                          onSelected: (_) => setState(() {
                            _selectedOfficerFilter = name;
                            _selectedGroupFilter = 'All';
                          }),
                        ),
                      )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          Expanded(
            child: displayedGroups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hub_outlined, size: 40, color: tokens.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          _scopedOfficer != null
                              ? 'No groups added yet for $_scopedOfficer. Click "Add Group" to create your first solidarity group.'
                              : (_selectedOfficerFilter != 'All'
                                  ? 'No groups assigned to $_selectedOfficerFilter.'
                                  : 'No groups added yet. Create your first solidarity group.'),
                          style: TextStyle(fontSize: 13, color: tokens.textMuted),
                        ),
                        if (!isSubmitted) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: tokens.brandPrimaryDark, foregroundColor: Colors.white),
                            onPressed: _addGroup,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add First Group', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 650;

                      return ListView.separated(
                        itemCount: displayedGroups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final g = displayedGroups[idx];
                          return isMobile
                              ? _buildGroupCardMobile(g, isSubmitted)
                              : _buildGroupRowDesktop(g, isSubmitted);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCardMobile(Map<String, dynamic> g, bool isSubmitted) {
    final tokens = IcareSurfaceTokens.of(context);
    final gRef = g['group_reference'] ?? '';
    final gName = g['group_name'] ?? '';
    final mDay = g['meeting_day'] ?? 'Unassigned';
    final officer = g['officer_name'] ?? 'Unassigned';
    final gSav = double.tryParse(g['group_savings']?.toString() ?? '0') ?? 0.0;
    final memberCount = _members.where((m) => m['group_reference'] == gRef).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.infoBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: tokens.infoBorder),
                ),
                child: Text(gRef, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.infoText)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$memberCount Members', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
              ),
              const Spacer(),
              if (!isSubmitted) ...[
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 16, color: tokens.infoDot),
                  tooltip: 'Edit group',
                  onPressed: () => _showGroupModal(groupToEdit: g),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 16, color: tokens.dangerDot),
                  tooltip: 'Delete group',
                  onPressed: () => _confirmDeleteGroup(g),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(gName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: tokens.textMuted),
              const SizedBox(width: 4),
              Text('Meeting: $mDay', style: TextStyle(fontSize: 11.5, color: tokens.textMuted)),
              const SizedBox(width: 12),
              Icon(Icons.person_outline, size: 12, color: tokens.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Officer: $officer',
                  style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (gSav > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Group Savings: ', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                Text(
                  CurrencyFormatter.formatNaira(gSav),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tokens.successText, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupRowDesktop(Map<String, dynamic> g, bool isSubmitted) {
    final tokens = IcareSurfaceTokens.of(context);
    final gRef = g['group_reference'] ?? '';
    final gName = g['group_name'] ?? '';
    final mDay = g['meeting_day'] ?? 'Unassigned';
    final officer = g['officer_name'] ?? 'Unassigned';
    final gSav = double.tryParse(g['group_savings']?.toString() ?? '0') ?? 0.0;
    final memberCount = _members.where((m) => m['group_reference'] == gRef).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.infoBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: tokens.infoBorder),
            ),
            child: Text(gRef, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.infoText)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                Text('Meeting: $mDay • Officer: $officer', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$memberCount Members', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('GROUP SAVINGS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: tokens.textMuted)),
              Text(
                CurrencyFormatter.formatNaira(gSav),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.successText, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          if (!isSubmitted) ...[
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 16, color: tokens.infoDot),
              tooltip: 'Edit group',
              onPressed: () => _showGroupModal(groupToEdit: g),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: tokens.dangerDot),
              tooltip: 'Delete group',
              onPressed: () => _confirmDeleteGroup(g),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: CREDIT OFFICERS & BRANCH RESERVES
  // =========================================================================

  Widget _buildOfficersAndReservesTab(bool isSubmitted) {
    final tokens = IcareSurfaceTokens.of(context);
    String? designatedMgrName;
    for (final o in _officers) {
      if (o['is_misc_savings_manager'] == true) {
        designatedMgrName = o['name']?.toString() ?? o['officer_name']?.toString();
        break;
      }
    }
    designatedMgrName ??= _officers.isNotEmpty
        ? (_officers.first['name']?.toString() ?? _officers.first['officer_name']?.toString() ?? 'First Active Officer')
        : 'Not Designated';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Branch Pooled Reserves Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tokens.infoBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.infoBorder),
                    ),
                    child: Icon(Icons.account_balance_wallet_outlined, color: tokens.infoDot, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Branch Pooled Reserves & Accounting Buffers',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Branch Pooled Reserves Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  final isOfficerScoped = _scopedOfficer != null;

                  final miscCard = _buildReserveCard(
                    title: 'Branch Misc Savings',
                    badge: 'Branch Reserve',
                    badgeColor: tokens.successText,
                    badgeBg: tokens.successBg,
                    amount: _miscSavings,
                    subtitle: isOfficerScoped
                        ? 'Managed by Area Manager & Designated Officer'
                        : 'Exclusive managing officer: $designatedMgrName',
                    description: '',
                    icon: Icons.savings_outlined,
                    iconColor: tokens.successDot,
                    iconBg: tokens.successBg,
                    isSubmitted: isSubmitted || isOfficerScoped,
                    onEdit: isOfficerScoped ? () {} : () => _openEditReserveDialog(
                      'Branch Misc Savings',
                      'Specify the initial opening balance for the branch internal misc savings pool.',
                      _miscSavings,
                      (val) => setState(() => _miscSavings = val),
                    ),
                  );

                  final lapsCard = _buildReserveCard(
                    title: 'Branch LAPS Risk Reserve',
                    badge: 'Risk Reserve Buffer',
                    badgeColor: tokens.infoText,
                    badgeBg: tokens.infoBg,
                    amount: _lapsSavings,
                    subtitle: 'Official Risk Protection Reserve',
                    description: '',
                    icon: Icons.shield_outlined,
                    iconColor: tokens.infoDot,
                    iconBg: tokens.infoBg,
                    isSubmitted: isSubmitted || isOfficerScoped,
                    onEdit: isOfficerScoped ? () {} : () => _openEditReserveDialog(
                      'Branch LAPS Risk Reserve',
                      'Specify the initial opening balance for the branch LAPS risk reserve buffer.',
                      _lapsSavings,
                      (val) => setState(() => _lapsSavings = val),
                    ),
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: miscCard),
                        const SizedBox(width: 16),
                        Expanded(child: lapsCard),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        miscCard,
                        const SizedBox(height: 12),
                        lapsCard,
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 32),

              // 3. Credit Officers Section Header
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: tokens.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: Icon(Icons.badge_outlined, color: tokens.textSecondary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Credit Officers Roster (${_officers.length})',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    if (!isSubmitted)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: tokens.brandPrimaryDark, foregroundColor: Colors.white),
                        onPressed: () => _openOfficerDialog(),
                        icon: const Icon(Icons.person_add_alt, size: 16),
                        label: const Text('Add Credit Officer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Officers List or Empty State
              if (_officers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.person_outline, size: 40, color: tokens.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'No Credit Officers Registered Yet',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'You can add credit officers manually here or upload your branch Excel template. Assigned officers in groups will also be auto-registered.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: tokens.textMuted),
                      ),
                      if (!isSubmitted) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.brandPrimary,
                            side: BorderSide(color: tokens.borderStrong),
                          ),
                          onPressed: () => _openOfficerDialog(),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add First Credit Officer'),
                        ),
                      ],
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _officers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final off = _officers[idx];
                    final name = (off['name'] ?? off['officer_name'] ?? 'Officer ${idx + 1}').toString();
                    final phone = (off['phone'] ?? off['phone_number'] ?? '').toString();
                    final isMiscMgr = off['is_misc_savings_manager'] == true;

                    final assignedGroups = _groups.where((g) {
                      final gOff = (g['officer_name'] ?? '').toString().trim().toLowerCase();
                      return gOff.isNotEmpty && gOff == name.trim().toLowerCase();
                    }).length;

                    return LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final isMobileCard = cardConstraints.maxWidth < 620;

                        final avatarWidget = CircleAvatar(
                          radius: 20,
                          backgroundColor: isMiscMgr ? tokens.successBg : tokens.infoBg,
                          child: Text(
                            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'CO',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isMiscMgr ? tokens.successText : tokens.infoText,
                            ),
                          ),
                        );

                        final badgesWrap = Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.infoBg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: tokens.infoBorder),
                              ),
                              child: Text(
                                'Credit Officer',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tokens.infoText),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (off['status'] == 'submitted') ? tokens.infoBg : tokens.warningBg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: (off['status'] == 'submitted') ? tokens.infoBorder : tokens.warningBorder),
                              ),
                              child: Text(
                                (off['status'] == 'submitted') ? 'SUBMITTED TO BM' : 'DRAFTING',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: (off['status'] == 'submitted') ? tokens.infoText : tokens.warningText,
                                ),
                              ),
                            ),
                            if (isMiscMgr)
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
                                    Icon(Icons.verified_user, size: 12, color: tokens.successDot),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Designated Misc Manager',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tokens.successText),
                                    ),
                                  ],
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.surfaceSubtle,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: tokens.borderSubtle),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.hub_outlined, size: 11, color: tokens.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$assignedGroups assigned groups',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );

                        final editDeleteActions = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isSubmitted && _scopedOfficer == null) ...[
                              IconButton(
                                icon: Icon(Icons.edit_outlined, size: 16, color: tokens.infoDot),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                tooltip: 'Edit officer details',
                                onPressed: () => _openOfficerDialog(officerToEdit: off),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 16, color: tokens.dangerDot),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                tooltip: 'Remove officer',
                                onPressed: () => _confirmDeleteOfficer(off),
                              ),
                            ],
                          ],
                        );

                        final linkAndMiscActions = SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: tokens.textPrimary,
                                      side: BorderSide(color: tokens.borderStrong),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () {
                                      final origin = getAppPublicOrigin();
                                      final coToken = off['token'] ?? off['co_token'];
                                      final coUrl = (coToken != null && coToken.toString().startsWith('onb_co_'))
                                          ? '$origin/#/onboarding/officer?token=$coToken'
                                          : '$origin/#/onboarding?token=$_currentToken&officer=${Uri.encodeComponent(name.trim())}';
                                      Clipboard.setData(ClipboardData(text: coUrl));
                                      _showBanner('Dedicated officer link for $name copied to clipboard!', isSuccess: true);
                                    },
                                    icon: const Icon(Icons.link, size: 13),
                                    label: const Text('Copy Officer Link', style: TextStyle(fontSize: 11)),
                                  ),
                                  if (off['status'] == 'submitted' && !isSubmitted)
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: tokens.warningText,
                                        side: BorderSide(color: tokens.warningBorder),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () async {
                                        final offId = off['id'] ?? off['officer_id'];
                                        if (offId != null) {
                                          try {
                                            final api = ref.read(onboardingApiServiceProvider);
                                            await api.unlockOfficer(_currentToken, offId.toString());
                                            setState(() {
                                              off['status'] = 'drafting';
                                            });
                                            _showBanner('Unlocked $name for roster edits.', isSuccess: true);
                                          } catch (e) {
                                            _showBanner('Failed to unlock officer: ${AppErrorDetails.from(e).message}', isSuccess: false);
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.lock_open_outlined, size: 13),
                                      label: const Text('Unlock Roster', style: TextStyle(fontSize: 11)),
                                    ),
                                ],
                              ),
                              if (!isSubmitted && !isMiscMgr && _scopedOfficer == null)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: tokens.brandAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      for (var o in _officers) {
                                        o['is_misc_savings_manager'] = false;
                                      }
                                      off['is_misc_savings_manager'] = true;
                                    });
                                    _saveDraft();
                                    _showBanner('$name designated as Misc Savings Manager.');
                                  },
                                  icon: const Icon(Icons.star_outline, size: 13),
                                  label: const Text('Set as Misc Manager', style: TextStyle(fontSize: 11)),
                                ),
                            ],
                          ),
                        );

                        if (isMobileCard) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: tokens.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isMiscMgr ? tokens.successBorder : tokens.borderSubtle,
                                width: isMiscMgr ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    avatarWidget,
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            phone.isNotEmpty ? phone : 'No phone registered',
                                            style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    editDeleteActions,
                                  ],
                                ),
                                const SizedBox(height: 8),
                                badgesWrap,
                                const SizedBox(height: 8),
                                linkAndMiscActions,
                              ],
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isMiscMgr ? tokens.successBorder : tokens.borderSubtle,
                              width: isMiscMgr ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  avatarWidget,
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(child: badgesWrap),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.phone_outlined, size: 13, color: tokens.textMuted),
                                            const SizedBox(width: 4),
                                            Text(
                                              phone.isNotEmpty ? phone : 'No phone registered',
                                              style: TextStyle(fontSize: 12, color: tokens.textMuted),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  editDeleteActions,
                                ],
                              ),
                              const SizedBox(height: 8),
                              linkAndMiscActions,
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReserveCard({
    required String title,
    required String badge,
    required Color badgeColor,
    required Color badgeBg,
    required double amount,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required bool isSubmitted,
    required VoidCallback onEdit,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.formatNaira(amount),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.textSecondary),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 11, color: tokens.textMuted, height: 1.3),
            ),
          ],

          if (!isSubmitted) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.textPrimary,
                side: BorderSide(color: tokens.borderStrong),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Update Fund Amount', style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  void _openEditReserveDialog(String title, String ruleDescription, double currentVal, Function(double) onSave) {
    final ctrl = TextEditingController(text: currentVal > 0 ? currentVal.toStringAsFixed(2) : '');
    final formKey = GlobalKey<FormState>();

    showIcareAdaptiveSheet<void>(
      context: context,
      fitContent: true,
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        final bottomInset = isDialog ? 0.0 : MediaQuery.viewInsetsOf(ctx).bottom;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24 + bottomInset),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                const SizedBox(height: 8),
                Text(ruleDescription, style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: tokens.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Opening Balance (₦) *',
                    prefixText: '₦ ',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter amount';
                    final numVal = double.tryParse(val.replaceAll(',', '').trim());
                    if (numVal == null || numVal < 0) return 'Enter a valid positive number';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: tokens.textSecondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimaryDark,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          final numVal = double.parse(ctrl.text.replaceAll(',', '').trim());
                          onSave(numVal);
                          Navigator.of(ctx).pop();
                          _saveDraft();
                          _showBanner('$title updated to ${CurrencyFormatter.formatNaira(numVal)}.');
                        }
                      },
                      child: const Text('Save Fund'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    });
  }

  void _openOfficerDialog({Map<String, dynamic>? officerToEdit}) {
    final isEditing = officerToEdit != null;
    final nameCtrl = TextEditingController(text: isEditing ? (officerToEdit['name'] ?? officerToEdit['officer_name'] ?? '') : '');
    final phoneCtrl = TextEditingController(text: isEditing ? (officerToEdit['phone'] ?? officerToEdit['phone_number'] ?? '') : '');
    bool isMiscMgr = isEditing ? (officerToEdit['is_misc_savings_manager'] == true) : (_officers.isEmpty);

    final formKey = GlobalKey<FormState>();

    showIcareAdaptiveSheet<void>(
      context: context,
      fitContent: true,
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        final bottomInset = isDialog ? 0.0 : MediaQuery.viewInsetsOf(ctx).bottom;
        return StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24 + bottomInset),
            child: Form(
              key: formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit Credit Officer' : 'Add Credit Officer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter credit officer credentials for branch field operations.',
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(color: tokens.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        hintText: 'e.g. Babatunde Lawal',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Full Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: tokens.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'e.g. 08012345678',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
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
                                Text(
                                  'Designated Misc Savings Manager',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Assigns exclusive custody of branch internal misc savings pool.',
                                  style: TextStyle(fontSize: 10.5, color: tokens.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isMiscMgr,
                            activeThumbColor: tokens.brandAccent,
                            onChanged: (val) => setDialogState(() => isMiscMgr = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: tokens.textSecondary),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.brandPrimaryDark,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              final cleanName = nameCtrl.text.trim();
                              final cleanPhone = phoneCtrl.text.trim();

                              String? generatedCoId;
                              setState(() {
                                if (isMiscMgr) {
                                  for (var o in _officers) {
                                    o['is_misc_savings_manager'] = false;
                                  }
                                }

                                if (isEditing) {
                                  officerToEdit['name'] = cleanName;
                                  officerToEdit['officer_name'] = cleanName;
                                  officerToEdit['phone'] = cleanPhone;
                                  officerToEdit['phone_number'] = cleanPhone;
                                  officerToEdit['is_misc_savings_manager'] = isMiscMgr;
                                } else {
                                  final coId = 'onb_co_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
                                  generatedCoId = coId;
                                  _officers.add({
                                    'id': coId,
                                    'officer_id': coId,
                                    'name': cleanName,
                                    'officer_name': cleanName,
                                    'phone': cleanPhone,
                                    'phone_number': cleanPhone,
                                    'role': 'Credit Officer',
                                    'is_misc_savings_manager': isMiscMgr,
                                    'token': coId,
                                    'co_token': coId,
                                    'status': 'drafting',
                                  });
                                }
                              });

                              Navigator.of(ctx).pop();
                              _saveDraft();
                              _showBanner(isEditing ? 'Officer updated successfully.' : 'Officer added successfully.');
                              if (!isEditing && generatedCoId != null) {
                                final origin = getAppPublicOrigin();
                                final coUrl = '$origin/#/onboarding/officer?token=$generatedCoId';
                                _showOfficerLinkModal(cleanName, coUrl);
                              }
                            }
                          },
                          child: Text(isEditing ? 'Save Changes' : 'Add Officer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameCtrl.dispose();
        phoneCtrl.dispose();
      });
    });
  }

  void _showOfficerLinkModal(String name, String coUrl) {
    showIcareAdaptiveSheet<void>(
      context: context,
      fitContent: true,
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tokens.infoBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.link, size: 18, color: tokens.infoDot),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dedicated Link for $name',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'A dedicated, cryptographically isolated onboarding workspace has been created for $name. Copy and deliver this link to the officer:',
                style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.borderStrong),
                ),
                child: SelectableText(
                  coUrl,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'When the officer opens this link, they will see strictly their own groups and members, with zero visibility into other officers.',
                style: TextStyle(fontSize: 11, color: tokens.textMuted),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: tokens.textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brandPrimaryDark,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: coUrl));
                      Navigator.of(ctx).pop();
                      _showBanner('Dedicated officer link for $name copied to clipboard!', isSuccess: true);
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('Copy Officer Link'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteOfficer(Map<String, dynamic> officer) {
    final name = (officer['name'] ?? officer['officer_name'] ?? 'Officer').toString();
    showIcareAdaptiveSheet<void>(
      context: context,
      fitContent: true,
      builder: (ctx, isDialog) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm Officer Removal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to remove credit officer "$name"? Any assigned groups will remain but will require re-assignment.',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: tokens.textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: tokens.dangerDot, foregroundColor: Colors.white),
                    onPressed: () {
                      setState(() {
                        _officers.remove(officer);
                      });
                      Navigator.of(ctx).pop();
                      _saveDraft();
                      _showBanner('Officer "$name" removed.');
                    },
                    child: const Text('Remove Officer'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // TAB 4: EXCEL UPLOADER
  // =========================================================================

  Widget _buildExcelUploaderTab(bool isSubmitted) {
    final tokens = IcareSurfaceTokens.of(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.borderStrong, style: BorderStyle.solid),
                boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 54, color: tokens.brandPrimary),
                  const SizedBox(height: 16),
                  Text(
                    'Direct Excel Workbook Ingestion',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your completed "icare-group-member-onboarding-template.xlsx" workbook. '
                    'The system will parse Groups and Members sheets instantly, run automated validation, and populate your digital onboarding roster.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: tokens.textMuted, height: 1.4),
                  ),
                  if (_scopedOfficer != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: tokens.infoBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.infoBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_pin_outlined, size: 14, color: tokens.infoText),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Scoped Ingestion Mode: Groups and members in your workbook will be attributed to $_scopedOfficer.',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.infoText),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!isSubmitted)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _isSaving ? null : _handleExcelUpload,
                      icon: const Icon(Icons.file_open_outlined, size: 18),
                      label: const Text('Choose Excel File (.xlsx)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    )
                  else
                    Text('Onboarding package is already submitted.', style: TextStyle(fontSize: 12, color: tokens.successText)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                    side: BorderSide(color: tokens.borderStrong),
                  ),
                  onPressed: () => _tabController.animateTo(0),
                  icon: const Icon(Icons.arrow_back, size: 14),
                  label: const Text('View Member Roster', style: TextStyle(fontSize: 12)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _tabController.animateTo(3),
                  icon: const Icon(Icons.verified_outlined, size: 14),
                  label: const Text('Review & Sign-Off →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 4: REVIEW & SIGN-OFF
  // =========================================================================

  Widget _buildReviewSignOffTab(bool isSubmitted) {
    final tokens = IcareSurfaceTokens.of(context);
    final status = (_sessionData?['status'] as String? ?? 'draft').toLowerCase();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Onboarding Pre-Flight Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
              const SizedBox(height: 6),
              Text('Review your branch data totals before submitting for administrative activation.', style: TextStyle(fontSize: 12.5, color: tokens.textMuted)),
              const SizedBox(height: 16),

              OnboardingPortfolioChartsSection(
                groups: _currentFilteredGroups,
                members: _currentFilteredMembers,
                miscSavings: _scopedOfficer == null ? _miscSavings : 0.0,
                lapsSavings: _scopedOfficer == null ? _lapsSavings : 0.0,
              ),
              const SizedBox(height: 16),

              IcareCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_scopedOfficer != null) ...[
                      _buildReviewRow('Portfolio Credit Officer', _scopedOfficer!),
                      Divider(height: 16, color: tokens.borderSubtle),
                      _buildReviewRow('Solidarity Groups', '${_scopedGroups.length} groups'),
                      Divider(height: 16, color: tokens.borderSubtle),
                      _buildReviewRow('Registered Members', '${_scopedMembers.length} clients'),
                      Divider(height: 16, color: tokens.borderSubtle),
                      _buildReviewRow('Individual Member Savings', CurrencyFormatter.formatNaira(_displayMemberSavings)),
                      if (_displayGroupSavings > 0) ...[
                        Divider(height: 16, color: tokens.borderSubtle),
                        _buildReviewRow('Group Savings Pool', CurrencyFormatter.formatNaira(_displayGroupSavings)),
                      ],
                      Divider(height: 16, color: tokens.borderSubtle),
                      _buildReviewRow('Total Portfolio Savings', CurrencyFormatter.formatNaira(_displayTotalSavings)),
                      if (_displayPrincipalLoan > 0) ...[
                        Divider(height: 16, color: tokens.borderSubtle),
                        _buildReviewRow('Total Principal Disbursed', CurrencyFormatter.formatNaira(_displayPrincipalLoan)),
                      ],
                      Divider(height: 16, color: tokens.borderSubtle),
                      _buildReviewRow('Total Active Credit (With Interest)', CurrencyFormatter.formatNaira(_displayActiveCredit)),
                      Divider(height: 16, color: tokens.borderSubtle),
                      _buildReviewRow('Total Current Balance', CurrencyFormatter.formatNaira(_displayCurrentBalance)),
                    ] else ...[
                      _buildReviewRow('Credit Officers Provisioned', '${_officers.length} officers'),
                      Divider(height: 16, color: tokens.borderSubtle),
                      _buildReviewRow('Solidarity Groups', '${_groups.length} groups created'),
                      Divider(height: 16, color: tokens.borderSubtle),
                      _buildReviewRow('Registered Members', '${_members.length} clients'),
                      Divider(height: 16, color: tokens.borderSubtle),
                      _buildReviewRow('Individual Member Savings', CurrencyFormatter.formatNaira(_totalMemberSavings)),
                      if (_totalGroupSavings > 0) ...[
                        Divider(height: 16, color: tokens.borderSubtle),
                        _buildReviewRow('Group Savings Pool', CurrencyFormatter.formatNaira(_totalGroupSavings)),
                      ],
                      if (_miscSavings > 0) ...[
                        Divider(height: 16, color: tokens.borderSubtle),
                        _buildReviewRow('Branch Misc Savings', CurrencyFormatter.formatNaira(_miscSavings)),
                      ],
                      Divider(height: 16, color: tokens.borderSubtle),
                      _buildReviewRow('Total Combined Savings', CurrencyFormatter.formatNaira(_totalSavings)),
                      if (_lapsSavings > 0) ...[
                        Divider(height: 16, color: tokens.borderSubtle),
                        _buildReviewRow('Branch LAPS Risk Reserve', CurrencyFormatter.formatNaira(_lapsSavings)),
                      ],
                      if (_totalPrincipalLoan > 0) ...[
                        Divider(height: 16, color: tokens.borderSubtle),
                        _buildReviewRow('Total Principal Disbursed', CurrencyFormatter.formatNaira(_totalPrincipalLoan)),
                      ],
                      Divider(height: 16, color: tokens.borderSubtle),
                      _buildReviewRow('Total Active Credit (With Interest)', CurrencyFormatter.formatNaira(_totalActiveCredit)),
                      Divider(height: 16, color: tokens.borderSubtle),
                      _buildReviewRow('Total Current Balance', CurrencyFormatter.formatNaira(_totalCurrentBalance)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (!isSubmitted) ...[
                if (_scopedOfficer != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.infoBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.infoBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Credit Officer Workspace Status',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.infoText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You are viewing your scoped roster ($_scopedOfficer). Your groups and members are saved to the branch draft. Final administrative submission and branch sign-off is completed by the Area Manager once all officers have completed their rosters.',
                          style: TextStyle(fontSize: 11.5, color: tokens.infoText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tokens.textSecondary,
                              side: BorderSide(color: tokens.borderStrong),
                            ),
                            onPressed: _isSaving ? null : _saveDraft,
                            icon: const Icon(Icons.save_outlined, size: 16),
                            label: const Text('Save Progress Draft', style: TextStyle(fontSize: 12.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: tokens.brandPrimaryDark, foregroundColor: Colors.white),
                            onPressed: (_isSaving || isSubmitted) ? null : _submitScopedOfficerRoster,
                            icon: const Icon(Icons.send_outlined, size: 16),
                            label: const Text('Confirm & Submit to BM', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: tokens.brandPrimaryDark, foregroundColor: Colors.white),
                      onPressed: _isSaving ? null : _submitPackage,
                      icon: const Icon(Icons.send_outlined, size: 18),
                      label: const Text('Confirm Totals & Submit to Area Manager', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ] else if (status == 'submitted') ...[
                if (_scopedOfficer == null && _isAmOrAdmin) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.successBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.successBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_user_outlined, size: 20, color: tokens.successDot),
                            const SizedBox(width: 8),
                            Text(
                              'Area Manager Review & Commitment',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.successText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Branch Manager has verified officer rosters and combined balances. As Area Manager, you can complete the final review and activate all groups, members, savings, and loan portfolios into live branch operations.',
                          style: TextStyle(fontSize: 12, color: tokens.successText),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: tokens.brandPrimaryDark, foregroundColor: Colors.white),
                            onPressed: _isSaving ? null : _amApprovePackage,
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Approve & Activate Branch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.infoBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.infoBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.hourglass_top_outlined, size: 18, color: tokens.infoDot),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Submitted to Area Manager',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.infoText),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your branch onboarding package has been confirmed and submitted to your Area Manager for final supervisory sign-off and live database activation. Your workspace is locked while awaiting approval.',
                          style: TextStyle(fontSize: 12.5, color: tokens.infoText, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else if (status == 'approved') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.successBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.successBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, size: 24, color: tokens.successDot),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Branch Onboarding Completed',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.successText),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'All solidarity groups, member accounts, savings reserves, and active loan balances have been committed to the live database.',
                              style: TextStyle(fontSize: 12, color: tokens.successText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () => _tabController.animateTo(0),
                  icon: Icon(Icons.arrow_back, size: 14, color: tokens.textMuted),
                  label: Text('Return to Member Roster', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    final tokens = IcareSurfaceTokens.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label, style: TextStyle(fontSize: 13, color: tokens.textSecondary)),
        ),
        const SizedBox(width: 12),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    );
  }
}
