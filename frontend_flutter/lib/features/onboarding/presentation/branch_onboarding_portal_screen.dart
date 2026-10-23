import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_colors.dart';
import '../../../../core/theme/icare_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../auth/presentation/login_screen.dart';
import '../../../../core/auth/auth_controller.dart';
import '../../../../core/auth/auth_state.dart';
import '../data/onboarding_api_service.dart';
import 'credit_officer_portal_screen.dart';

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
      String msg = e.toString().replaceAll('Exception: ', '');
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
      _showBanner('Failed to save draft: $e', isSuccess: false);
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
      _showBanner('Error uploading Excel: $e', isSuccess: false);
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Roster to Branch Manager', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to submit your completed roster to your Branch Manager for review and branch sign-off?',
              style: TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Officer: $_scopedOfficer', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Solidarity Groups: ${myGroups.length}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('Registered Members: ${myMembers.length}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('Portfolio Savings: ${CurrencyFormatter.formatNaira(_displayTotalSavings)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Once submitted, your roster will be locked for review by the Branch Manager.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm & Submit to BM'),
          ),
        ],
      ),
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
      _showBanner('Failed to submit roster: $e', isSuccess: false);
    }
  }

  Future<void> _submitPackage() async {
    final unsubmitted = _officers.where((o) => (o['status'] ?? 'draft') != 'submitted').length;
    final warningNotice = unsubmitted > 0
        ? '\n\nNote: $unsubmitted credit officer(s) have not yet marked their rosters as submitted to BM.'
        : '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Submission to Area Manager'),
        content: Text(
          'You are about to submit ${_groups.length} groups, ${_members.length} members, and ${_officers.length} credit officers to the Area Manager for final sign-off and database posting.$warningNotice',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Submit to Area Manager', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
      _showBanner('Submission error: $e', isSuccess: false);
    }
  }

  Future<void> _amApprovePackage() async {
    final notesCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Area Manager Sign-Off'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to commit ${_groups.length} groups, ${_members.length} members, and ${_officers.length} officers directly into the live core banking database. This operation is permanent.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Approval Notes (Optional)',
                hintText: 'e.g. Verified and approved by Area Manager',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Approve & Commit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final api = ref.read(onboardingApiServiceProvider);
      final res = await api.amApprovePackage(
        _currentToken,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
      setState(() {
        _isSaving = false;
        _sessionData?['status'] = 'approved';
      });
      _showBanner(res['message']?.toString() ?? 'Branch onboarding successfully committed to live core database!', isSuccess: true);
    } catch (e) {
      setState(() => _isSaving = false);
      _showBanner('Approval error: $e', isSuccess: false);
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
        ? (groupToEdit['group_reference']?.toString() ?? 'GRP-01')
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isMobileModal = MediaQuery.of(ctx).size.width < 500;
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
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
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.hub_outlined, color: Color(0xFF2563EB), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEditing ? 'Edit Solidarity Group' : 'Add Solidarity Group',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Define group identity, meeting schedule, and leadership',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
                            style: const TextStyle(fontSize: 13),
                            validator: (val) =>
                                (val == null || val.trim().isEmpty) ? 'Please enter a group name' : null,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: selectedDay,
                            decoration: const InputDecoration(
                              labelText: 'Meeting Day *',
                              labelStyle: TextStyle(fontSize: 12),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              border: OutlineInputBorder(),
                            ),
                            items: availableDays.map((d) {
                              return DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)));
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
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (_scopedOfficer != null && _scopedOfficer!.isNotEmpty) ...[
                            TextFormField(
                              controller: officerCtrl,
                              enabled: false,
                              decoration: const InputDecoration(
                                labelText: 'Assigned Credit Officer (Your Workspace)',
                                labelStyle: TextStyle(fontSize: 12),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Color(0xFFF1F5F9),
                              ),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ] else if (officerNames.isNotEmpty) ...[
                            DropdownButtonFormField<String>(
                              initialValue: selectedOfficerDropdown,
                              decoration: const InputDecoration(
                                labelText: 'Assigned Credit Officer',
                                labelStyle: TextStyle(fontSize: 12),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                ...officerNames.map((name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name, style: const TextStyle(fontSize: 13)),
                                )),
                                const DropdownMenuItem(
                                  value: '__custom__',
                                  child: Text('+ Custom / Enter New Officer', style: TextStyle(fontSize: 13, color: Color(0xFF2563EB))),
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
                                style: const TextStyle(fontSize: 13),
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
                              style: const TextStyle(fontSize: 13),
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
                            style: const TextStyle(fontSize: 13),
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
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
                                  style: const TextStyle(fontSize: 13),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Meeting Day *',
                                    labelStyle: TextStyle(fontSize: 12),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: availableDays.map((d) {
                                    return DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)));
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
                                  style: const TextStyle(fontSize: 13),
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
                                        decoration: const InputDecoration(
                                          labelText: 'Assigned Credit Officer (Your Workspace)',
                                          labelStyle: TextStyle(fontSize: 12),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                          border: OutlineInputBorder(),
                                          filled: true,
                                          fillColor: Color(0xFFF1F5F9),
                                        ),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                      ),
                                    ] else if (officerNames.isNotEmpty) ...[
                                      DropdownButtonFormField<String>(
                                        initialValue: selectedOfficerDropdown,
                                        decoration: const InputDecoration(
                                          labelText: 'Assigned Credit Officer',
                                          labelStyle: TextStyle(fontSize: 12),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                          border: OutlineInputBorder(),
                                        ),
                                        items: [
                                          ...officerNames.map((name) => DropdownMenuItem(
                                            value: name,
                                            child: Text(name, style: const TextStyle(fontSize: 13)),
                                          )),
                                          const DropdownMenuItem(
                                            value: '__custom__',
                                            child: Text('+ Custom / Enter New Officer', style: TextStyle(fontSize: 13, color: Color(0xFF2563EB))),
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
                                          style: const TextStyle(fontSize: 13),
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
                                        style: const TextStyle(fontSize: 13),
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
                                  style: const TextStyle(fontSize: 13),
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
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: IcareColors.primary,
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
              ),
            );
          },
        );
      },
    );
  }

  void _showMemberModal({Map<String, dynamic>? memberToEdit}) {
    final availableGroups = _scopedGroups;
    if (availableGroups.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text('Create a Group First', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            _scopedOfficer != null
                ? 'You do not have any solidarity groups created yet for your portfolio ($_scopedOfficer). Please add at least one solidarity group before registering members.'
                : 'Members must belong to a Solidarity Group. Please add at least one group before registering members.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: IcareColors.primary,
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

    // Available loan products
    final List<String> productOptions = _loanProducts.isNotEmpty
        ? _loanProducts.map((p) => p['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList()
        : ['Daily 60 Days', 'Weekly 16 Weeks', 'Monthly 6 Months'];

    String selectedProduct = isEditing
        ? (memberToEdit['loan_type']?.toString() ?? productOptions.first)
        : productOptions.first;
    if (!productOptions.contains(selectedProduct)) {
      selectedProduct = productOptions.first;
    }

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
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
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 560),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
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
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isEditing ? Icons.edit_outlined : Icons.person_add_alt_1,
                                color: const Color(0xFF059669),
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
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Solidarity group membership, savings, and loan balances',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 16),

                        // Section 1: Group Assignment & Code
                        if (isMobileModal) ...[
                          DropdownButtonFormField<String>(
                            initialValue: selectedGroupRef,
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
                                  style: const TextStyle(fontSize: 13),
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
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
                                        style: const TextStyle(fontSize: 13),
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
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                            style: const TextStyle(fontSize: 13),
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
                            style: const TextStyle(fontSize: 13),
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
                                  style: const TextStyle(fontSize: 13),
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
                                  style: const TextStyle(fontSize: 13),
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
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 16),

                        // Existing Loan Section Toggle
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: hasActiveLoan ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: hasActiveLoan ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.credit_card_outlined,
                                size: 18,
                                color: hasActiveLoan ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Client Has Pre-Existing / Active Loan',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      'Enable to migrate an existing active loan running before onboarding.',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: hasActiveLoan,
                                activeThumbColor: const Color(0xFF2563EB),
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
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: selectedProduct,
                                  decoration: const InputDecoration(
                                    labelText: 'Loan Product *',
                                    labelStyle: TextStyle(fontSize: 12),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: productOptions.map((prod) {
                                    return DropdownMenuItem(value: prod, child: Text(prod, style: const TextStyle(fontSize: 13)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setModalState(() => selectedProduct = val);
                                  },
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
                                    style: const TextStyle(fontSize: 13),
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
                                    style: const TextStyle(fontSize: 13),
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
                                        style: const TextStyle(fontSize: 13),
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
                                        style: const TextStyle(fontSize: 13),
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
                                  style: const TextStyle(fontSize: 13),
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
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFDBEAFE)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calculate_outlined, size: 16, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Scheduled Installment: ${CurrencyFormatter.formatNaira(calcInstallment)} / period ($prodInstallments total)'
                                            '${enteredBal > 0 ? ' • ~$estRemainingCount remaining' : ''}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1D4ED8),
                                              fontFeatures: [FontFeature.tabularFigures()],
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
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: IcareColors.primary,
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
                                final cleanProd = hasActiveLoan ? selectedProduct : productOptions.first;

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
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteMember(Map<String, dynamic> m) {
    final name = m['full_name'] ?? 'Client';
    final refCode = m['member_reference'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 20),
            SizedBox(width: 8),
            Text('Remove Member', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "$name" ($refCode) from this branch onboarding package?',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _members.remove(m));
              _saveDraft();
              _showBanner('Member "$name" removed.', isSuccess: true);
            },
            child: const Text('Delete Member', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(Map<String, dynamic> g) {
    final gRef = g['group_reference'] ?? '';
    final gName = g['group_name'] ?? 'Group';
    final memberCount = _members.where((m) => m['group_reference'] == gRef).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
            SizedBox(width: 8),
            Text('Delete Solidarity Group', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          memberCount > 0
              ? 'Warning: Group "$gName" ($gRef) currently has $memberCount member(s) registered. Deleting this group will also remove all $memberCount member(s) from the roster.\n\nAre you sure you want to proceed?'
              : 'Are you sure you want to delete group "$gName" ($gRef)?',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
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
            child: const Text('Delete Group', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: IcareColors.canvas,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: IcareColors.primary),
              SizedBox(height: 16),
              Text('Connecting to Branch Onboarding Session...', style: TextStyle(color: IcareColors.textMuted)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: IcareColors.canvas,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      color: const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 26,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Branch Onboarding Access',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _tokenCtrl,
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
                        backgroundColor: IcareColors.primary,
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
                    icon: const Icon(Icons.arrow_back, size: 14),
                    label: const Text(
                      'Return to Staff Login',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
      backgroundColor: IcareColors.canvas,
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
                color: _isSuccessBanner ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                child: Row(
                  children: [
                    Icon(
                      _isSuccessBanner ? Icons.check_circle_outline : Icons.error_outline,
                      size: 16,
                      color: _isSuccessBanner ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _bannerMessage!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _isSuccessBanner ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14),
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
                      color: const Color(0xFFEFF6FF),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_pin_outlined, size: 15, color: Color(0xFF1E40AF)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Workspace: $_scopedOfficer',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
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
                                child: const Text('Show All (AM)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Showing your assigned groups and members. Uploads and edits are merged safely.',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF3B82F6)),
                          ),
                        ],
                      ),
                    );
                  }
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFFEFF6FF),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_pin_outlined, size: 14, color: Color(0xFF1E40AF)),
                              const SizedBox(width: 4),
                              Text(
                                'Credit Officer Workspace: $_scopedOfficer',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Showing groups and members assigned to your portfolio. Edits and uploads merge safely without clobbering other officers.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF3B82F6)),
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
                            icon: const Icon(Icons.remove_red_eye_outlined, size: 13, color: Color(0xFF2563EB)),
                            label: const Text('View All Branch Data (AM Mode)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
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
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: LayoutBuilder(
                builder: (context, tabConstraints) {
                  final isTabScrollable = tabConstraints.maxWidth < 650;
                  final isOfficer = _scopedOfficer != null && _scopedOfficer!.isNotEmpty;
                  return TabBar(
                    controller: _tabController,
                    isScrollable: isTabScrollable,
                    tabAlignment: isTabScrollable ? TabAlignment.start : TabAlignment.fill,
                    labelColor: IcareColors.primary,
                    unselectedLabelColor: const Color(0xFF64748B),
                    indicatorColor: IcareColors.primary,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
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
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Icon(Icons.account_balance, size: 18, color: Color(0xFF0F766E)),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ICARE Core Banking',
                          style: IcareTypography.caption.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSubmitted ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSubmitted ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isSubmitted ? const Color(0xFF065F46) : const Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        if (_scopedOfficer == null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F2744),
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
                      ],
                    ),
                    Text(
                      _scopedOfficer == null
                          ? '$branchName ($branchCode) — Branch Manager Portal'
                          : '$branchName ($branchCode) — Credit Officer: $_scopedOfficer',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );

          final actionsSection = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSubmitted) ...[
                if (_lastSavedTime != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'Saved ${DateFormat('HH:mm').format(_lastSavedTime!)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _isSaving ? null : _saveDraft,
                  icon: _isSaving
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 14),
                  label: const Text('Save Draft', style: TextStyle(fontSize: 11.5)),
                ),
                if (_scopedOfficer != null) ...[
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IcareColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: (_isSaving || isSubmitted) ? null : _submitScopedOfficerRoster,
                    icon: const Icon(Icons.send_outlined, size: 14),
                    label: const Text('Submit to BM', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IcareColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _isSaving ? null : _submitPackage,
                    icon: const Icon(Icons.send_outlined, size: 14),
                    label: const Text('Submit to AM', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ] else if (status.toLowerCase() == 'submitted') ...[
                if (_scopedOfficer == null && _isAmOrAdmin) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
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
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 13, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text('Submitted to AM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 13, color: Color(0xFF059669)),
                      SizedBox(width: 4),
                      Text('Committed to Core Banking', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
                    ],
                  ),
                ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [actionsSection],
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
    return Container(
      width: double.infinity,
      color: Colors.white,
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
                  _buildMetricCardChip('Portfolio Officer', _scopedOfficer!, Icons.badge_outlined, const Color(0xFF0F766E), const Color(0xFFF0FDFA))
                else if (!isFiltered)
                  _buildMetricCardChip('Officers', _officers.length.toString(), Icons.badge_outlined, const Color(0xFF0F766E), const Color(0xFFF0FDFA)),

                if (isFiltered)
                  _buildMetricCardChip('Filtered Group', _selectedGroupFilter, Icons.filter_alt_outlined, const Color(0xFF2563EB), const Color(0xFFEFF6FF))
                else
                  _buildMetricCardChip(isScoped ? 'My Groups' : 'Groups', _currentFilteredGroups.length.toString(), Icons.hub_outlined, const Color(0xFF475569), const Color(0xFFF1F5F9)),

                _buildMetricCardChip(isFiltered ? 'Group Members' : (isScoped ? 'My Members' : 'Members'), _currentFilteredMembers.length.toString(), Icons.people_outline, const Color(0xFF475569), const Color(0xFFF1F5F9)),

                if (isFiltered) ...[
                  _buildMetricCardChip('Group Savings', CurrencyFormatter.formatNaira(_displayGroupSavings), Icons.savings_outlined, const Color(0xFF0D9488), const Color(0xFFCCFBF1)),
                  _buildMetricCardChip('Member Savings', CurrencyFormatter.formatNaira(_displayMemberSavings), Icons.savings_outlined, const Color(0xFF10B981), const Color(0xFFECFDF5)),
                ],

                _buildMetricCardChip(isFiltered ? 'Total Group Savings' : 'Total Savings', CurrencyFormatter.formatNaira(_displayTotalSavings), Icons.savings_outlined, const Color(0xFF059669), const Color(0xFFECFDF5)),

                if (!isFiltered && _scopedOfficer == null && _miscSavings > 0)
                  _buildMetricCardChip('Misc Savings', CurrencyFormatter.formatNaira(_miscSavings), Icons.account_balance_wallet_outlined, const Color(0xFF0D9488), const Color(0xFFCCFBF1)),

                if (_displayPrincipalLoan > 0)
                  _buildMetricCardChip('Principal Disbursed', CurrencyFormatter.formatNaira(_displayPrincipalLoan), Icons.account_balance_outlined, const Color(0xFF4F46E5), const Color(0xFFEEF2FF)),

                _buildMetricCardChip('Active Credit', CurrencyFormatter.formatNaira(_displayActiveCredit), Icons.credit_card_outlined, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                _buildMetricCardChip('Outstanding Balance', CurrencyFormatter.formatNaira(_displayCurrentBalance), Icons.account_balance_wallet_outlined, const Color(0xFFD97706), const Color(0xFFFFFBEB)),
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

  Widget _buildMetricCardChip(String label, String value, IconData icon, Color color, Color bgIcon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgIcon,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.3),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedOfficerFilter,
                          isExpanded: isNarrow,
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedGroupFilter,
                    isExpanded: isNarrow,
                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
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
                  decoration: InputDecoration(
                    hintText: 'Search members by name, phone or code...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
              );

              final addMemberBtn = ifBtn(!isSubmitted, () {
                return ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IcareColors.primary,
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
                    officerDropdown,
                    const SizedBox(width: 8),
                  ],
                  groupDropdown,
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
                        const Icon(Icons.people_outline, size: 40, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text(
                          _members.isEmpty
                              ? 'No members registered yet. Click "Add Member" or upload your Excel template.'
                              : (_scopedOfficer != null
                                  ? 'No members found for $_scopedOfficer matching current filters.'
                                  : 'No members match the current search or filter criteria.'),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        if (_members.isEmpty && !isSubmitted) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
    final refCode = m['member_reference'] ?? 'Pending';
    final gRef = m['group_reference'] ?? 'GRP-01';
    final name = m['full_name'] ?? '';
    final phone = m['phone_number'] ?? '';
    final savings = double.tryParse(m['savings_balance']?.toString() ?? '0') ?? 0.0;
    final activeCred = double.tryParse(m['active_credit']?.toString() ?? '0') ?? 0.0;
    final princLoan = double.tryParse(m['principal_loan']?.toString() ?? '') ?? activeCred;
    final curBal = double.tryParse(m['current_credit_balance']?.toString() ?? '0') ?? 0.0;
    final prod = m['loan_type'] ?? 'Daily 60 Days';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(refCode, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(gRef, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8))),
              ),
              const Spacer(),
              if (!isSubmitted) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                  tooltip: 'Edit member',
                  onPressed: () => _showMemberModal(memberToEdit: m),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
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
          Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 12, color: phone.isNotEmpty ? const Color(0xFF64748B) : const Color(0xFFDC2626)),
              const SizedBox(width: 4),
              Text(
                phone.isNotEmpty ? phone : 'No phone entered',
                style: TextStyle(
                  fontSize: 11.5,
                  color: phone.isNotEmpty ? const Color(0xFF64748B) : const Color(0xFFDC2626),
                ),
              ),
              if (activeCred > 0) ...[
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    prod,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
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
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SAVINGS', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                      Text(
                        CurrencyFormatter.formatNaira(savings),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF059669), fontFeatures: [FontFeature.tabularFigures()]),
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
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ACTIVE CREDIT', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                      Text(
                        activeCred > 0 ? CurrencyFormatter.formatNaira(activeCred) : 'None',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: activeCred > 0 ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (activeCred > 0 && princLoan > 0)
                        Text(
                          'Prin: ${CurrencyFormatter.formatNaira(princLoan)}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            fontFeatures: [FontFeature.tabularFigures()],
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
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFEF3C7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('REMAINING', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                      Text(
                        curBal > 0 ? CurrencyFormatter.formatNaira(curBal) : '₦0.00',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: curBal > 0 ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
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
    final refCode = m['member_reference'] ?? 'Pending Code';
    final gRef = m['group_reference'] ?? 'GRP-01';
    final name = m['full_name'] ?? '';
    final phone = m['phone_number'] ?? '';
    final savings = double.tryParse(m['savings_balance']?.toString() ?? '0') ?? 0.0;
    final activeCred = double.tryParse(m['active_credit']?.toString() ?? '0') ?? 0.0;
    final princLoan = double.tryParse(m['principal_loan']?.toString() ?? '') ?? activeCred;
    final curBal = double.tryParse(m['current_credit_balance']?.toString() ?? '0') ?? 0.0;
    final prod = m['loan_type'] ?? 'Daily 60 Days';

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
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(refCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                Text(gRef, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
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
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                Text(
                  phone.isNotEmpty ? phone : 'No phone entered',
                  style: TextStyle(
                    fontSize: 11,
                    color: phone.isNotEmpty ? const Color(0xFF64748B) : const Color(0xFFDC2626),
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
                const Text('SAVINGS', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                Text(
                  CurrencyFormatter.formatNaira(savings),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF059669), fontFeatures: [FontFeature.tabularFigures()]),
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
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  activeCred > 0 ? CurrencyFormatter.formatNaira(activeCred) : 'No Loan',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: activeCred > 0 ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (activeCred > 0 && princLoan > 0)
                  Text(
                    'Prin: ${CurrencyFormatter.formatNaira(princLoan)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      fontFeatures: [FontFeature.tabularFigures()],
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
                const Text('REMAINING', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                Text(
                  curBal > 0 ? CurrencyFormatter.formatNaira(curBal) : '₦0.00',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: curBal > 0 ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          if (!isSubmitted) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
              tooltip: 'Edit member',
              onPressed: () => _showMemberModal(memberToEdit: m),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
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
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (!isSubmitted)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
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
                        const Icon(Icons.hub_outlined, size: 40, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text(
                          _scopedOfficer != null
                              ? 'No groups added yet for $_scopedOfficer. Click "Add Group" to create your first solidarity group.'
                              : (_selectedOfficerFilter != 'All'
                                  ? 'No groups assigned to $_selectedOfficerFilter.'
                                  : 'No groups added yet. Create your first solidarity group.'),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        if (!isSubmitted) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
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
    final gRef = g['group_reference'] ?? 'GRP-01';
    final gName = g['group_name'] ?? '';
    final mDay = g['meeting_day'] ?? 'Daily';
    final officer = g['officer_name'] ?? 'Unassigned';
    final gSav = double.tryParse(g['group_savings']?.toString() ?? '0') ?? 0.0;
    final memberCount = _members.where((m) => m['group_reference'] == gRef).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(gRef, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$memberCount Members', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              ),
              const Spacer(),
              if (!isSubmitted) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                  tooltip: 'Edit group',
                  onPressed: () => _showGroupModal(groupToEdit: g),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
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
          Text(gName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text('Meeting: $mDay', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              const SizedBox(width: 12),
              const Icon(Icons.person_outline, size: 12, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Officer: $officer',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
                const Text('Group Savings: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                Text(
                  CurrencyFormatter.formatNaira(gSav),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF059669), fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupRowDesktop(Map<String, dynamic> g, bool isSubmitted) {
    final gRef = g['group_reference'] ?? 'GRP-01';
    final gName = g['group_name'] ?? '';
    final mDay = g['meeting_day'] ?? 'Daily';
    final officer = g['officer_name'] ?? 'Unassigned';
    final gSav = double.tryParse(g['group_savings']?.toString() ?? '0') ?? 0.0;
    final memberCount = _members.where((m) => m['group_reference'] == gRef).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Text(gRef, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                Text('Meeting: $mDay • Officer: $officer', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$memberCount Members', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('GROUP SAVINGS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
              Text(
                CurrencyFormatter.formatNaira(gSav),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669), fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          if (!isSubmitted) ...[
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
              tooltip: 'Edit group',
              onPressed: () => _showGroupModal(groupToEdit: g),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
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
    // Find designated misc manager name
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
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF1D4ED8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Branch Pooled Reserves & Accounting Buffers',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Branch Pooled Reserves Cards (Misc Savings & LAPS)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  final isOfficerScoped = _scopedOfficer != null;

                  final miscCard = _buildReserveCard(
                    title: 'Branch Misc Savings',
                    badge: 'Branch Reserve',
                    badgeColor: const Color(0xFF059669),
                    badgeBg: const Color(0xFFECFDF5),
                    amount: _miscSavings,
                    subtitle: isOfficerScoped
                        ? 'Managed by Area Manager & Designated Officer'
                        : 'Exclusive managing officer: $designatedMgrName',
                    description: '',
                    icon: Icons.savings_outlined,
                    iconColor: const Color(0xFF059669),
                    iconBg: const Color(0xFFECFDF5),
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
                    badgeColor: const Color(0xFF2563EB),
                    badgeBg: const Color(0xFFEFF6FF),
                    amount: _lapsSavings,
                    subtitle: 'Official Risk Protection Reserve',
                    description: '',
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFFEFF6FF),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(Icons.badge_outlined, color: Color(0xFF334155), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credit Officers Roster (${_officers.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),

                    ],
                  ),
                  if (!isSubmitted)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
                      onPressed: () => _openOfficerDialog(),
                      icon: const Icon(Icons.person_add_alt, size: 16),
                      label: const Text('Add Credit Officer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Officers List or Empty State
              if (_officers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.person_outline, size: 40, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      const Text(
                        'No Credit Officers Registered Yet',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'You can add credit officers manually here or upload your branch Excel template. Assigned officers in groups will also be auto-registered.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      if (!isSubmitted) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
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

                    // Compute assigned groups count
                    final assignedGroups = _groups.where((g) {
                      final gOff = (g['officer_name'] ?? '').toString().trim().toLowerCase();
                      return gOff.isNotEmpty && gOff == name.trim().toLowerCase();
                    }).length;

                    return LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final isMobileCard = cardConstraints.maxWidth < 620;

                        final avatarWidget = CircleAvatar(
                          radius: 20,
                          backgroundColor: isMiscMgr ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                          child: Text(
                            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'CO',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isMiscMgr ? const Color(0xFF059669) : const Color(0xFF1D4ED8),
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
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: const Text(
                                'Credit Officer',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (off['status'] == 'submitted') ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: (off['status'] == 'submitted') ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                (off['status'] == 'submitted') ? 'SUBMITTED TO BM' : 'DRAFTING',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: (off['status'] == 'submitted') ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                            if (isMiscMgr)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_user, size: 12, color: Color(0xFF059669)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Designated Misc Manager',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                    ),
                                  ],
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.hub_outlined, size: 11, color: Color(0xFF475569)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$assignedGroups assigned groups',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
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
                                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                tooltip: 'Edit officer details',
                                onPressed: () => _openOfficerDialog(officerToEdit: off),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                tooltip: 'Remove officer',
                                onPressed: () => _confirmDeleteOfficer(off),
                              ),
                            ],
                          ],
                        );

                        final linkAndMiscActions = Row(
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                final origin = (kIsWeb && Uri.base.origin.isNotEmpty && !Uri.base.origin.startsWith('file://'))
                                    ? Uri.base.origin
                                    : 'http://localhost:8000';
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
                            if (off['status'] == 'submitted' && !isSubmitted) ...[
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFD97706),
                                  side: const BorderSide(color: Color(0xFFFCD34D)),
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
                                      _showBanner('Failed to unlock officer: $e', isSuccess: false);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.lock_open_outlined, size: 13),
                                label: const Text('Unlock Roster', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                            const Spacer(),
                            if (!isSubmitted && !isMiscMgr && _scopedOfficer == null)
                              TextButton.icon(
                                style: TextButton.styleFrom(
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
                        );


                        if (isMobileCard) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isMiscMgr ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
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
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            phone.isNotEmpty ? phone : 'No phone registered',
                                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isMiscMgr ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
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
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(child: badgesWrap),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF64748B)),
                                            const SizedBox(width: 4),
                                            Text(
                                              phone.isNotEmpty ? phone : 'No phone registered',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontFeatures: [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
            ),
          ],

          if (!isSubmitted) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ruleDescription, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 14),
              TextFormField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
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
    );
  }

  void _openOfficerDialog({Map<String, dynamic>? officerToEdit}) {
    final isEditing = officerToEdit != null;
    final nameCtrl = TextEditingController(text: isEditing ? (officerToEdit['name'] ?? officerToEdit['officer_name'] ?? '') : '');
    final phoneCtrl = TextEditingController(text: isEditing ? (officerToEdit['phone'] ?? officerToEdit['phone_number'] ?? '') : '');
    bool isMiscMgr = isEditing ? (officerToEdit['is_misc_savings_manager'] == true) : (_officers.isEmpty);

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Credit Officer' : 'Add Credit Officer', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter credit officer credentials for branch field operations.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
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
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Designated Misc Savings Manager', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              SizedBox(height: 2),
                              Text('Assigns exclusive custody of branch internal misc savings pool.', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Switch(
                          value: isMiscMgr,
                          activeThumbColor: IcareColors.primary,
                          onChanged: (val) => setDialogState(() => isMiscMgr = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
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
                    final origin = (kIsWeb && Uri.base.origin.isNotEmpty && !Uri.base.origin.startsWith('file://'))
                        ? Uri.base.origin
                        : 'http://localhost:8000';
                    final coUrl = '$origin/#/onboarding/officer?token=$generatedCoId';
                    _showOfficerLinkModal(cleanName, coUrl);
                  }
                }
              },
              child: Text(isEditing ? 'Save Changes' : 'Add Officer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOfficerLinkModal(String name, String coUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.link, size: 18, color: Color(0xFF1D4ED8)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Dedicated Link for $name',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A dedicated, cryptographically isolated onboarding workspace has been created for $name. Copy and deliver this link to the officer:',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: SelectableText(
                coUrl,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When the officer opens this link, they will see strictly their own groups and members, with zero visibility into other officers.',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: IcareColors.primary,
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
    );
  }

  void _confirmDeleteOfficer(Map<String, dynamic> officer) {
    final name = (officer['name'] ?? officer['officer_name'] ?? 'Officer').toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Officer Removal'),
        content: Text('Are you sure you want to remove credit officer "$name"? Any assigned groups will remain but will require re-assignment.', style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
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
    );
  }

  // =========================================================================
  // TAB 4: EXCEL UPLOADER
  // =========================================================================

  Widget _buildExcelUploaderTab(bool isSubmitted) {
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 54, color: IcareColors.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Direct Excel Workbook Ingestion',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload your completed "icare-group-member-onboarding-template.xlsx" workbook. '
                    'The system will parse Groups and Members sheets instantly, run automated validation, and populate your digital onboarding roster.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                  ),
                  if (_scopedOfficer != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_pin_outlined, size: 14, color: Color(0xFF1E40AF)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Scoped Ingestion Mode: Groups and members in your workbook will be attributed to $_scopedOfficer.',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
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
                        backgroundColor: IcareColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _isSaving ? null : _handleExcelUpload,
                      icon: const Icon(Icons.file_open_outlined, size: 18),
                      label: const Text('Choose Excel File (.xlsx)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    )
                  else
                    const Text('Onboarding package is already submitted.', style: TextStyle(fontSize: 12, color: Color(0xFF059669))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _tabController.animateTo(0),
                  icon: const Icon(Icons.arrow_back, size: 14),
                  label: const Text('View Member Roster', style: TextStyle(fontSize: 12)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IcareColors.primary,
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
    final status = (_sessionData?['status'] as String? ?? 'draft').toLowerCase();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Onboarding Pre-Flight Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              const Text('Review your branch data totals before submitting for administrative activation.', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    if (_scopedOfficer != null) ...[
                      _buildReviewRow('Portfolio Credit Officer', _scopedOfficer!),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildReviewRow('Solidarity Groups', '${_scopedGroups.length} groups'),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildReviewRow('Registered Members', '${_scopedMembers.length} clients'),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildReviewRow('Individual Member Savings', CurrencyFormatter.formatNaira(_displayMemberSavings)),
                      if (_displayGroupSavings > 0) ...[
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        _buildReviewRow('Group Savings Pool', CurrencyFormatter.formatNaira(_displayGroupSavings)),
                      ],
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildReviewRow('Total Portfolio Savings', CurrencyFormatter.formatNaira(_displayTotalSavings)),
                      if (_displayPrincipalLoan > 0) ...[
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        _buildReviewRow('Total Principal Disbursed', CurrencyFormatter.formatNaira(_displayPrincipalLoan)),
                      ],
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildReviewRow('Total Active Credit (With Interest)', CurrencyFormatter.formatNaira(_displayActiveCredit)),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildReviewRow('Total Current Balance', CurrencyFormatter.formatNaira(_displayCurrentBalance)),
                    ] else ...[
                      _buildReviewRow('Credit Officers Provisioned', '${_officers.length} officers'),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildReviewRow('Solidarity Groups', '${_groups.length} groups created'),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildReviewRow('Registered Members', '${_members.length} clients'),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildReviewRow('Individual Member Savings', CurrencyFormatter.formatNaira(_totalMemberSavings)),
                      if (_totalGroupSavings > 0) ...[
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        _buildReviewRow('Group Savings Pool', CurrencyFormatter.formatNaira(_totalGroupSavings)),
                      ],
                      if (_miscSavings > 0) ...[
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        _buildReviewRow('Branch Misc Savings', CurrencyFormatter.formatNaira(_miscSavings)),
                      ],
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildReviewRow('Total Combined Savings', CurrencyFormatter.formatNaira(_totalSavings)),
                      if (_lapsSavings > 0) ...[
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        _buildReviewRow('Branch LAPS Risk Reserve', CurrencyFormatter.formatNaira(_lapsSavings)),
                      ],
                      if (_totalPrincipalLoan > 0) ...[
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        _buildReviewRow('Total Principal Disbursed', CurrencyFormatter.formatNaira(_totalPrincipalLoan)),
                      ],
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildReviewRow('Total Active Credit (With Interest)', CurrencyFormatter.formatNaira(_totalActiveCredit)),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
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
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Credit Officer Workspace Status',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You are viewing your scoped roster ($_scopedOfficer). Your groups and members are saved to the branch draft. Final administrative submission and branch sign-off is completed by the Area Manager once all officers have completed their rosters.',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF3B82F6)),
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
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
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
                            style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
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
                      style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
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
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified_user_outlined, size: 20, color: Color(0xFF16A34A)),
                            SizedBox(width: 8),
                            Text(
                              'Area Manager Review & Commitment',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Branch Manager has verified officer rosters and combined balances. As Area Manager, you can complete the final review and commit all groups, members, savings, and loan portfolios into the live core database.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                            onPressed: _isSaving ? null : _amApprovePackage,
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Approve & Commit to Live Core Database', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.hourglass_top_outlined, size: 18, color: Color(0xFF1D4ED8)),
                            SizedBox(width: 8),
                            Text(
                              'Submitted to Area Manager',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Your branch onboarding package has been confirmed and submitted to your Area Manager for final supervisory sign-off and live database activation. Your workspace is locked while awaiting approval.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF1D4ED8), height: 1.4),
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
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified, size: 24, color: Color(0xFF059669)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Branch Onboarding Completed',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'All solidarity groups, member accounts, savings reserves, and active loan balances have been committed to the live database.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF047857)),
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
                  icon: const Icon(Icons.arrow_back, size: 14),
                  label: const Text('Return to Member Roster', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontFeatures: [FontFeature.tabularFigures()])),
      ],
    );
  }
}
