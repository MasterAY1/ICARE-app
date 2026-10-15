import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_colors.dart';
import '../../../../core/theme/icare_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../auth/presentation/login_screen.dart';
import '../data/onboarding_api_service.dart';

class BranchOnboardingPortalScreen extends ConsumerStatefulWidget {
  final String token;

  const BranchOnboardingPortalScreen({
    super.key,
    required this.token,
  });

  @override
  ConsumerState<BranchOnboardingPortalScreen> createState() =>
      _BranchOnboardingPortalScreenState();
}

class _BranchOnboardingPortalScreenState
    extends ConsumerState<BranchOnboardingPortalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  String? _bannerMessage;
  bool _isSuccessBanner = true;
  bool _isSaving = false;
  DateTime? _lastSavedTime;

  late String _currentToken;
  late final TextEditingController _tokenCtrl;

  Map<String, dynamic>? _sessionData;
  List<dynamic> _loanProducts = [];
  List<dynamic> _meetingDays = [];
  List<dynamic> get loanProducts => _loanProducts;
  List<dynamic> get meetingDays => _meetingDays;

  // Working state
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _officers = [];
  String _selectedGroupFilter = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  final currencyFmt = NumberFormat("#,##0.00", "en_US");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentToken = widget.token.trim();
    _tokenCtrl = TextEditingController(text: _currentToken);
    _loadSessionData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
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
      final data = await api.getSession(_currentToken);

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

      setState(() {
        _sessionData = session;
        _loanProducts = products;
        _meetingDays = days;
        _groups = groupsList;
        _members = membersList;
        _officers = officersList;
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
      };

      final res = await api.saveDraft(_currentToken, payload);
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
      final res = await api.uploadExcelBytes(_currentToken, picked.bytes, picked.name);

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

      setState(() {
        _groups = groupsList;
        _members = membersList;
        _officers = officersList;
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

  Future<void> _submitPackage() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Onboarding Submission'),
        content: Text(
          'You are about to submit ${_groups.length} groups and ${_members.length} members for administrative approval. Once submitted, changes cannot be made until reviewed.',
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
            child: const Text('Submit for Sign-Off', style: TextStyle(color: Colors.white)),
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
      };
      await api.saveDraft(_currentToken, payload);

      // 2. Submit
      final res = await api.submitSession(_currentToken);
      setState(() {
        _isSaving = false;
        _sessionData?['status'] = 'submitted';
      });
      _showBanner(res['message']?.toString() ?? 'Submitted successfully!', isSuccess: true);
    } catch (e) {
      setState(() => _isSaving = false);
      _showBanner('Submission error: $e', isSuccess: false);
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
    final officerCtrl = TextEditingController(text: isEditing ? (groupToEdit['officer_name']?.toString() ?? '') : '');
    final phoneCtrl = TextEditingController(text: isEditing ? (groupToEdit['officer_phone']?.toString() ?? '') : '');
    final savingsCtrl = TextEditingController(
      text: isEditing ? (groupToEdit['group_savings']?.toString() ?? '0.00') : '0.00',
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
                            children: [
                              Expanded(
                                child: TextFormField(
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
    if (_groups.isEmpty) {
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
          content: const Text(
            'Members must belong to a Solidarity Group. Please add at least one group before registering members.',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
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
        ? (memberToEdit['group_reference']?.toString() ?? _groups.first['group_reference'])
        : (_selectedGroupFilter != 'All' ? _selectedGroupFilter : _groups.first['group_reference']);

    // Ensure selected group exists in _groups
    if (!_groups.any((g) => g['group_reference'] == selectedGroupRef)) {
      selectedGroupRef = _groups.first['group_reference'];
    }

    final nextSeq = _members.length + 1;
    final defaultMemberRef = isEditing
        ? (memberToEdit['member_reference']?.toString() ?? '')
        : '$branchCode-${selectedGroupRef.replaceAll('GRP-', '')}-${nextSeq.toString().padLeft(3, '0')}';

    final refCtrl = TextEditingController(text: defaultMemberRef);
    final nameCtrl = TextEditingController(text: isEditing ? (memberToEdit['full_name']?.toString() ?? '') : '');
    final phoneCtrl = TextEditingController(text: isEditing ? (memberToEdit['phone_number']?.toString() ?? '') : '');
    final addressCtrl = TextEditingController(text: isEditing ? (memberToEdit['home_address']?.toString() ?? '') : '');
    final savingsCtrl = TextEditingController(
      text: isEditing ? (memberToEdit['savings_balance']?.toString() ?? '0.00') : '0.00',
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
                            items: _groups.map((g) {
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
                                  items: _groups.map((g) {
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

  double get _totalSavings => _members.fold(0.0, (sum, m) => sum + (double.tryParse(m['savings_balance']?.toString() ?? '0') ?? 0.0));
  double get _totalPrincipalLoan => _members.fold(0.0, (sum, m) {
    final p = double.tryParse(m['principal_loan']?.toString() ?? '');
    final a = double.tryParse(m['active_credit']?.toString() ?? '0') ?? 0.0;
    return sum + (p != null && p > 0 ? p : a);
  });
  double get _totalActiveCredit => _members.fold(0.0, (sum, m) => sum + (double.tryParse(m['active_credit']?.toString() ?? '0') ?? 0.0));
  double get _totalCurrentBalance => _members.fold(0.0, (sum, m) => sum + (double.tryParse(m['current_credit_balance']?.toString() ?? '0') ?? 0.0));

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
                      labelText: 'Onboarding Invitation Token',
                      hintText: 'e.g. onboard_...',
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
                        setState(() {
                          _currentToken = _tokenCtrl.text.trim();
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

            // Tab Navigation Header
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: LayoutBuilder(
                builder: (context, tabConstraints) {
                  final isTabScrollable = tabConstraints.maxWidth < 650;
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
                    tabs: [
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
                        text: 'Review & Sign-Off',
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
                children: [
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
                      ],
                    ),
                    Text(
                      '$branchName ($branchCode) — Branch Onboarding',
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
                  label: const Text('Submit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                      Text('Submitted for Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
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
              final items = [
                _buildMetricCardChip('Groups', _groups.length.toString(), Icons.hub_outlined, const Color(0xFF475569), const Color(0xFFF1F5F9)),
                _buildMetricCardChip('Members', _members.length.toString(), Icons.people_outline, const Color(0xFF475569), const Color(0xFFF1F5F9)),
                _buildMetricCardChip('Total Savings', CurrencyFormatter.formatNaira(_totalSavings), Icons.savings_outlined, const Color(0xFF059669), const Color(0xFFECFDF5)),
                if (_totalPrincipalLoan > 0)
                  _buildMetricCardChip('Principal Disbursed', CurrencyFormatter.formatNaira(_totalPrincipalLoan), Icons.account_balance_outlined, const Color(0xFF4F46E5), const Color(0xFFEEF2FF)),
                _buildMetricCardChip('Active Credit', CurrencyFormatter.formatNaira(_totalActiveCredit), Icons.credit_card_outlined, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                _buildMetricCardChip('Outstanding Balance', CurrencyFormatter.formatNaira(_totalCurrentBalance), Icons.account_balance_wallet_outlined, const Color(0xFFD97706), const Color(0xFFFFFBEB)),
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
    final filtered = _members.where((m) {
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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Responsive Filter & Search Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 640;

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
                      ..._groups.map((g) => DropdownMenuItem(
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
                );
              }

              return Row(
                children: [
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
                              : 'No members match the current search or group filter.',
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Branch Solidarity Groups',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
          const SizedBox(height: 12),

          Expanded(
            child: _groups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.hub_outlined, size: 40, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        const Text(
                          'No groups added yet. Create your first solidarity group.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
                        itemCount: _groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final g = _groups[idx];
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
  // TAB 3: EXCEL UPLOADER
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
                    _buildReviewRow('Solidarity Groups', '${_groups.length} groups created'),
                    const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    _buildReviewRow('Registered Members', '${_members.length} clients'),
                    const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    _buildReviewRow('Initial Opening Savings', CurrencyFormatter.formatNaira(_totalSavings)),
                    if (_totalPrincipalLoan > 0) ...[
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildReviewRow('Total Principal Disbursed', CurrencyFormatter.formatNaira(_totalPrincipalLoan)),
                    ],
                    const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    _buildReviewRow('Total Active Credit (With Interest)', CurrencyFormatter.formatNaira(_totalActiveCredit)),
                    const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    _buildReviewRow('Total Current Balance', CurrencyFormatter.formatNaira(_totalCurrentBalance)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (!isSubmitted)
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
                    onPressed: _isSaving ? null : _submitPackage,
                    icon: const Icon(Icons.verified, size: 18),
                    label: const Text('Submit Package for Administrative Sign-Off', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
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
