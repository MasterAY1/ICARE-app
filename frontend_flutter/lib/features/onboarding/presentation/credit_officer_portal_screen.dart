import '../../../../core/utils/platform_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../auth/presentation/login_screen.dart';
import '../data/onboarding_api_service.dart';
import 'branch_onboarding_portal_screen.dart';

/// Dedicated, cryptographically isolated onboarding workspace for Credit Officers.
/// Enforces 100% data privacy: Credit Officers can only view and manage their
/// own solidarity groups and client rosters. Zero access to other officers or branch-wide reserves.
class CreditOfficerPortalScreen extends ConsumerStatefulWidget {
  final String coToken;

  const CreditOfficerPortalScreen({
    super.key,
    required this.coToken,
  });

  @override
  ConsumerState<CreditOfficerPortalScreen> createState() => _CreditOfficerPortalScreenState();
}

class _CreditOfficerPortalScreenState extends ConsumerState<CreditOfficerPortalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _currentToken;
  final TextEditingController _tokenCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Workspace State
  Map<String, dynamic>? _officer;
  String _branchName = '';
  String _branchCode = '';
  String _sessionStatus = 'draft';
  DateTime? _expiresAt;
  bool _isLocked = false;

  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _members = [];
  Map<String, dynamic> _aggregates = {};
  List<Map<String, dynamic>> _loanProducts = [];
  List<String> _meetingDays = ['Daily', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Monthly'];

  String _searchQuery = '';
  String _selectedGroupFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentToken = widget.coToken.trim();

    if (_currentToken.isEmpty) {
      final uri = Uri.base;
      String? tokenFromUrl = uri.queryParameters['token'];
      if (uri.fragment.isNotEmpty) {
        final frag = uri.fragment;
        final fragUri = Uri.tryParse(frag.startsWith('/') ? frag : '/$frag');
        if (fragUri != null && fragUri.queryParameters.containsKey('token')) {
          tokenFromUrl ??= fragUri.queryParameters['token'];
        }
      }
      if (tokenFromUrl != null && tokenFromUrl.trim().isNotEmpty) {
        _currentToken = tokenFromUrl.trim();
      }
    }

    _tokenCtrl.text = _currentToken;

    if (_currentToken.isNotEmpty) {
      _loadWorkspace();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWorkspace() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(onboardingApiServiceProvider);
      final data = await api.getOfficerWorkspace(_currentToken);

      setState(() {
        _officer = Map<String, dynamic>.from(data['officer'] ?? {});
        _branchName = data['branch_name'] ?? 'Branch';
        _branchCode = data['branch_code'] ?? 'BR';
        _sessionStatus = data['session_status'] ?? 'draft';
        if (data['expires_at'] != null) {
          _expiresAt = DateTime.tryParse(data['expires_at']);
        }
        _isLocked = data['is_locked'] == true;

        final rawGroups = data['groups'] as List<dynamic>? ?? [];
        _groups = rawGroups.map((g) => Map<String, dynamic>.from(g as Map)).toList();

        final rawMembers = data['members'] as List<dynamic>? ?? [];
        _members = rawMembers.map((m) => Map<String, dynamic>.from(m as Map)).toList();

        _aggregates = Map<String, dynamic>.from(data['aggregates'] ?? {});

        final rawProds = data['loan_products'] as List<dynamic>? ?? [];
        _loanProducts = rawProds.map((p) => Map<String, dynamic>.from(p as Map)).toList();

        final rawDays = data['meeting_days'] as List<dynamic>? ?? [];
        if (rawDays.isNotEmpty) {
          _meetingDays = rawDays.map((d) => d.toString()).toList();
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDraft() async {
    if (_isLocked) return;

    setState(() => _isSaving = true);
    try {
      final api = ref.read(onboardingApiServiceProvider);
      final payload = {
        'groups': _groups,
        'members': _members,
      };

      final data = await api.saveOfficerDraft(_currentToken, payload);

      if (mounted) {
        setState(() {
          if (data['officer'] != null) {
            _officer = Map<String, dynamic>.from(data['officer'] as Map);
          }
          _aggregates = Map<String, dynamic>.from(data['aggregates'] ?? _aggregates);
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Roster draft saved successfully.'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save draft: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _submitRoster() async {
    if (_isLocked) return;

    if (_groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please register at least one solidarity group before submitting.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Roster to Branch Manager'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to submit your roster to your Branch Manager?',
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
                  Text('Solidarity Groups: ${_groups.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Registered Clients: ${_members.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    'Total Portfolio Savings: ${CurrencyFormatter.formatNaira(double.tryParse(_aggregates['total_portfolio_savings']?.toString() ?? '0') ?? 0.0)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Once submitted, your workspace will be locked for editing. If you need to make changes, your Branch Manager can unlock it for you.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: IcareColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm & Submit to BM'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final api = ref.read(onboardingApiServiceProvider);
      // Auto-save any pending changes first
      await api.saveOfficerDraft(_currentToken, {'groups': _groups, 'members': _members});
      // Submit
      await api.submitOfficerRoster(_currentToken);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your roster has been submitted to your Branch Manager!'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 3),
          ),
        );
        _loadWorkspace();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadExcel() async {
    if (_isLocked) return;

    try {
      final picked = await pickExcelFile();
      if (picked == null) return;

      setState(() => _isSaving = true);

      final api = ref.read(onboardingApiServiceProvider);
      final res = await api.uploadOfficerExcelBytes(
        _currentToken,
        picked.bytes,
        picked.name,
      );

      if (mounted) {
        setState(() {
          final rawGroups = res['groups'] as List<dynamic>? ?? [];
          _groups = rawGroups.map((g) => Map<String, dynamic>.from(g as Map)).toList();

          final rawMembers = res['members'] as List<dynamic>? ?? [];
          _members = rawMembers.map((m) => Map<String, dynamic>.from(m as Map)).toList();

          _aggregates = Map<String, dynamic>.from(res['aggregates'] ?? _aggregates);
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Excel file ingested successfully.'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel upload failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  // =========================================================================
  // GROUP CRUD MODALS
  // =========================================================================

  void _openGroupDialog({Map<String, dynamic>? groupToEdit}) {
    if (_isLocked) return;

    final isEdit = groupToEdit != null;
    final nameCtrl = TextEditingController(text: groupToEdit?['group_name'] ?? '');
    final refCtrl = TextEditingController(text: groupToEdit?['group_reference'] ?? 'GRP-${(_groups.length + 1).toString().padLeft(2, '0')}');
    final leaderCtrl = TextEditingController(text: groupToEdit?['leader_name'] ?? '');
    final existingGroupSavings = isEdit ? (double.tryParse(groupToEdit['group_savings']?.toString() ?? '0') ?? 0.0) : 0.0;
    final savingsCtrl = TextEditingController(text: existingGroupSavings > 0 ? existingGroupSavings.toStringAsFixed(2) : '');
    String selectedDay = groupToEdit?['meeting_day'] ?? _meetingDays.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Solidarity Group' : 'Add New Solidarity Group'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Group Name *',
                      hintText: 'e.g. Progressive Traders Group',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: refCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Group Reference *',
                      hintText: 'e.g. GRP-01',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _meetingDays.contains(selectedDay) ? selectedDay : _meetingDays.first,
                    decoration: const InputDecoration(labelText: 'Weekly Meeting Day'),
                    items: _meetingDays.map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedDay = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: leaderCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Group Leader / Representative',
                      hintText: 'e.g. Mrs. Aminat Adeleke',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: savingsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Initial Group Opening Savings (₦)',
                      hintText: '0.00',
                      prefixText: '₦ ',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
              onPressed: () {
                final gName = nameCtrl.text.trim();
                final gRef = refCtrl.text.trim().toUpperCase();
                final gSav = double.tryParse(savingsCtrl.text.trim()) ?? 0.0;

                if (gName.isEmpty || gRef.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group Name and Reference are required.')),
                  );
                  return;
                }

                // Check duplicate reference in this officer's groups
                if (!isEdit && _groups.any((g) => (g['group_reference'] ?? '').toString().toUpperCase() == gRef)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Group Reference "$gRef" already exists in your roster.')),
                  );
                  return;
                }

                final updatedGroup = {
                  'group_reference': gRef,
                  'group_name': gName,
                  'meeting_day': selectedDay,
                  'leader_name': leaderCtrl.text.trim().isEmpty ? null : leaderCtrl.text.trim(),
                  'group_savings': gSav,
                  'officer_name': _officer?['name'] ?? '',
                };

                setState(() {
                  if (isEdit) {
                    final idx = _groups.indexOf(groupToEdit);
                    if (idx >= 0) _groups[idx] = updatedGroup;
                  } else {
                    _groups.add(updatedGroup);
                  }
                });

                Navigator.of(ctx).pop();
                _saveDraft();
              },
              child: Text(isEdit ? 'Save Changes' : 'Create Group'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteGroup(Map<String, dynamic> group) {
    if (_isLocked) return;

    final gRef = (group['group_reference'] ?? '').toString();
    final memberCount = _members.where((m) => (m['group_reference'] ?? '').toString().toUpperCase() == gRef.toUpperCase()).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Solidarity Group'),
        content: Text(
          memberCount > 0
              ? 'Warning: This group currently has $memberCount assigned clients. Deleting it will also remove these clients from your roster. Proceed?'
              : 'Are you sure you want to delete group "$gRef"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _groups.remove(group);
                if (memberCount > 0) {
                  _members.removeWhere((m) => (m['group_reference'] ?? '').toString().toUpperCase() == gRef.toUpperCase());
                }
              });
              Navigator.of(ctx).pop();
              _saveDraft();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MEMBER CRUD MODALS
  // =========================================================================

  void _openMemberDialog({Map<String, dynamic>? memberToEdit}) {
    if (_isLocked) return;

    if (_groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create at least one solidarity group first.')),
      );
      return;
    }

    final isEdit = memberToEdit != null;
    final nameCtrl = TextEditingController(text: memberToEdit?['full_name'] ?? '');
    final phoneCtrl = TextEditingController(text: memberToEdit?['phone_number'] ?? '');
    final addrCtrl = TextEditingController(text: memberToEdit?['home_address'] ?? '');

    final sVal = double.tryParse(memberToEdit?['savings_balance']?.toString() ?? '0') ?? 0.0;
    final pVal = double.tryParse((memberToEdit?['principal'] ?? memberToEdit?['principal_loan'] ?? memberToEdit?['loan_amount'])?.toString() ?? '0') ?? 0.0;
    final acVal = double.tryParse(memberToEdit?['active_credit']?.toString() ?? '0') ?? 0.0;
    final cbVal = double.tryParse((memberToEdit?['current_credit_balance'] ?? memberToEdit?['current_balance'])?.toString() ?? '0') ?? 0.0;

    final savingsCtrl = TextEditingController(text: sVal > 0 ? sVal.toStringAsFixed(2) : '');
    final principalCtrl = TextEditingController(text: pVal > 0 ? pVal.toStringAsFixed(2) : '');
    final activeCreditCtrl = TextEditingController(text: acVal > 0 ? acVal.toStringAsFixed(2) : '');
    final currentBalCtrl = TextEditingController(text: cbVal > 0 ? cbVal.toStringAsFixed(2) : '');

    String selectedGroupRef = memberToEdit?['group_reference'] ?? _groups.first['group_reference'];
    String? selectedLoanProduct = memberToEdit?['loan_type'];
    if (selectedLoanProduct == null && _loanProducts.isNotEmpty) {
      selectedLoanProduct = _loanProducts.first['name'];
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Client Roster Record' : 'Register New Client'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Client Full Name *', hintText: 'e.g. Babatunde Adeleke'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _groups.any((g) => g['group_reference'] == selectedGroupRef) ? selectedGroupRef : _groups.first['group_reference'],
                    decoration: const InputDecoration(labelText: 'Assigned Solidarity Group *'),
                    items: _groups.map<DropdownMenuItem<String>>((g) {
                      final ref = g['group_reference']?.toString() ?? '';
                      final name = g['group_name']?.toString() ?? '';
                      return DropdownMenuItem<String>(value: ref, child: Text('$ref — $name'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedGroupRef = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Phone Number', hintText: '08012345678'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: savingsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Savings Balance (₦)', hintText: '0.00', prefixText: '₦ '),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addrCtrl,
                    decoration: const InputDecoration(labelText: 'Residential Address', hintText: 'e.g. 14 Market Street'),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Active Loan Position (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _loanProducts.any((p) => p['name'] == selectedLoanProduct) ? selectedLoanProduct : null,
                    decoration: const InputDecoration(labelText: 'Loan Product Category'),
                    items: _loanProducts.map<DropdownMenuItem<String>>((p) {
                      final pName = p['name']?.toString() ?? '';
                      return DropdownMenuItem<String>(value: pName, child: Text(pName));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedLoanProduct = val),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: principalCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Principal Disbursed (₦)', hintText: '0.00', prefixText: '₦ '),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: activeCreditCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Active Credit (₦)', hintText: '0.00', prefixText: '₦ '),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: currentBalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Current Loan Balance (₦)', hintText: '0.00', prefixText: '₦ '),
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
                final fName = nameCtrl.text.trim();
                if (fName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client name is required.')));
                  return;
                }

                final sBal = double.tryParse(savingsCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                final pAmount = double.tryParse(principalCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                final aCred = double.tryParse(activeCreditCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                final cBal = double.tryParse(currentBalCtrl.text.replaceAll(',', '').trim()) ?? (aCred > 0 ? aCred : 0.0);

                final updatedMember = {
                  'full_name': fName,
                  'group_reference': selectedGroupRef,
                  'phone_number': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  'home_address': addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
                  'savings_balance': sBal,
                  'principal': pAmount > 0 ? pAmount : (aCred > 0 ? aCred : 0.0),
                  'principal_loan': pAmount > 0 ? pAmount : (aCred > 0 ? aCred : 0.0),
                  'active_credit': aCred,
                  'current_credit_balance': cBal,
                  'loan_type': (pAmount > 0 || aCred > 0 || cBal > 0) ? selectedLoanProduct : null,
                  'officer_name': _officer?['name'] ?? '',
                };

                setState(() {
                  if (isEdit) {
                    final idx = _members.indexOf(memberToEdit);
                    if (idx >= 0) _members[idx] = updatedMember;
                  } else {
                    _members.add(updatedMember);
                  }
                });

                Navigator.of(ctx).pop();
                _saveDraft();
              },
              child: Text(isEdit ? 'Save Changes' : 'Register Client'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMember(Map<String, dynamic> member) {
    if (_isLocked) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client Record'),
        content: Text('Are you sure you want to remove "${member['full_name']}" from your roster?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () {
              setState(() => _members.remove(member));
              Navigator.of(ctx).pop();
              _saveDraft();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MAIN BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: IcareColors.primary),
        ),
      );
    }

    if (_currentToken.isEmpty || _errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
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
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(Icons.badge_outlined, size: 26, color: Color(0xFF1D4ED8)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Credit Officer Portal Access',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Please provide your dedicated Credit Officer invitation token to access your assigned workspace.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _errorMessage != null ? const Color(0xFFDC2626) : const Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _tokenCtrl,
                    decoration: InputDecoration(
                      labelText: 'Credit Officer Token',
                      hintText: 'e.g. onb_co_...',
                      prefixIcon: const Icon(Icons.key, size: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        final input = _tokenCtrl.text.trim();
                        if (input.startsWith('onb_branch_')) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => BranchOnboardingPortalScreen(token: input)),
                          );
                          return;
                        }
                        setState(() {
                          _currentToken = input;
                        });
                        _loadWorkspace();
                      },
                      icon: const Icon(Icons.login, size: 16),
                      label: const Text('Access Officer Workspace', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                    label: const Text('Return to Staff Login', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final officerName = _officer?['name'] ?? 'Credit Officer';
    final isSubmitted = _officer?['status'] == 'submitted';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Officer Identity Bar
            _buildTopAppBar(officerName, isSubmitted),

            // Portfolio KPI Summary Ribbon
            _buildPortfolioSummaryRibbon(),

            // Tab Navigation
            Container(
              color: Colors.white,
              child: LayoutBuilder(
                builder: (context, tabConstraints) {
                  final isTabScrollable = tabConstraints.maxWidth < 640;
                  return TabBar(
                    controller: _tabController,
                    isScrollable: isTabScrollable,
                    tabAlignment: isTabScrollable ? TabAlignment.start : TabAlignment.fill,
                    labelColor: IcareColors.primary,
                    unselectedLabelColor: const Color(0xFF64748B),
                    indicatorColor: IcareColors.primary,
                    indicatorWeight: 2.5,
                    labelPadding: EdgeInsets.symmetric(horizontal: isTabScrollable ? 14 : 16),
                    labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.groups_outlined, size: 16),
                            const SizedBox(width: 6),
                            Text(isTabScrollable ? 'Groups (${_groups.length})' : 'Solidarity Groups (${_groups.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline, size: 16),
                            const SizedBox(width: 6),
                            Text(isTabScrollable ? 'Clients (${_members.length})' : 'Clients Roster (${_members.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.upload_file_outlined, size: 16),
                            const SizedBox(width: 6),
                            Text(isTabScrollable ? 'Excel' : 'Excel Ingestion'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fact_check_outlined, size: 16),
                            const SizedBox(width: 6),
                            Text(isTabScrollable ? 'Review' : 'Review & Sign-Off'),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Tab View Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGroupsTab(),
                  _buildMembersTab(),
                  _buildExcelTab(),
                  _buildReviewTab(isSubmitted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // APP BAR & IDENTITY
  // =========================================================================

  Widget _buildTopAppBar(String officerName, bool isSubmitted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 620;

          final branchPill = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F2744),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _branchCode,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          );

          final statusPill = Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: isSubmitted ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isSubmitted ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A)),
            ),
            child: Text(
              isSubmitted ? 'SUBMITTED' : 'DRAFTING',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: isSubmitted ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
              ),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Identity Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    branchPill,
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'CREDIT OFFICER',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  officerName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$_branchName Branch${_expiresAt != null ? " • Due: ${DateFormat('dd MMM').format(_expiresAt!.toLocal())}" : ""}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    statusPill,
                  ],
                ),
                const SizedBox(height: 10),

                // Full-width balanced action buttons
                if (!_isLocked)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 36),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: _isSaving ? null : _saveDraft,
                          icon: _isSaving
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save_outlined, size: 14),
                          label: const Text('Save Draft', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: IcareColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: _isSaving ? null : _submitRoster,
                          icon: const Icon(Icons.send_outlined, size: 14),
                          label: const Text('Submit to BM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF059669)),
                        SizedBox(width: 6),
                        Text('Roster Submitted & Locked', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      ],
                    ),
                  ),
              ],
            );
          }

          // Desktop / Wide Header
          final officerTitle = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CREDIT OFFICER PORTAL',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    officerName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 8),
                  statusPill,
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Credit Officer • $_branchName • Branch: ${_sessionStatus.toUpperCase()}${_expiresAt != null ? " • Due: ${DateFormat('dd MMM').format(_expiresAt!.toLocal())}" : ""}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          );

          final actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isLocked) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 34),
                  ),
                  onPressed: _isSaving ? null : _saveDraft,
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 14),
                  label: const Text('Save Draft', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IcareColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 34),
                  ),
                  onPressed: _isSaving ? null : _submitRoster,
                  icon: const Icon(Icons.send_outlined, size: 14),
                  label: const Text('Submit to BM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF059669)),
                      SizedBox(width: 6),
                      Text('Submitted & Locked', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                    ],
                  ),
                ),
              ],
            ],
          );

          return Row(
            children: [
              branchPill,
              const SizedBox(width: 10),
              Expanded(child: officerTitle),
              actionButtons,
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // PORTFOLIO KPI SUMMARY RIBBON
  // =========================================================================

  Widget _buildPortfolioSummaryRibbon() {
    final isGroupFiltered = _selectedGroupFilter != 'All';
    final targetGroups = isGroupFiltered
        ? _groups.where((g) => (g['group_reference'] ?? '').toString().toUpperCase() == _selectedGroupFilter.toUpperCase()).toList()
        : _groups;
    final targetMembers = isGroupFiltered
        ? _members.where((m) => (m['group_reference'] ?? '').toString().toUpperCase() == _selectedGroupFilter.toUpperCase()).toList()
        : _members;

    final indivSav = targetMembers.fold<double>(0.0, (sum, m) => sum + (double.tryParse(m['savings_balance']?.toString() ?? '0') ?? 0.0));
    final grpSav = targetGroups.fold<double>(0.0, (sum, g) => sum + (double.tryParse(g['group_savings']?.toString() ?? '0') ?? 0.0));
    final isMiscMgr = _officer?['is_misc_savings_manager'] == true ||
        _officer?['is_misc_savings_manager']?.toString().toLowerCase() == 'true' ||
        _officer?['is_misc_savings_manager'] == 1;
    final officerMiscVal = double.tryParse(_officer?['misc_savings']?.toString() ?? '') ??
        double.tryParse(_aggregates['misc_savings']?.toString() ?? '') ?? 0.0;
    final miscSav = (!isGroupFiltered && isMiscMgr) ? officerMiscVal : 0.0;
    final totSav = indivSav + grpSav + miscSav;

    final principal = targetMembers.fold<double>(0.0, (sum, m) {
      final p = double.tryParse((m['principal'] ?? m['principal_loan'] ?? m['loan_amount'])?.toString() ?? '');
      final a = double.tryParse(m['active_credit']?.toString() ?? '0') ?? 0.0;
      return sum + (p != null && p > 0 ? p : a);
    });
    final activeCredit = targetMembers.fold<double>(0.0, (sum, m) => sum + (double.tryParse(m['active_credit']?.toString() ?? '0') ?? 0.0));
    final currentBal = targetMembers.fold<double>(0.0, (sum, m) => sum + (double.tryParse((m['current_credit_balance'] ?? m['current_balance'])?.toString() ?? '0') ?? 0.0));

    final items = [
      _buildRibbonCard(
        label: isGroupFiltered ? 'Total Group Savings' : 'Total Savings',
        value: CurrencyFormatter.formatNaira(totSav),
        icon: Icons.account_balance_wallet_outlined,
        isPrimary: true,
      ),
      _buildRibbonCard(
        label: isGroupFiltered ? 'Group Clients' : 'My Clients',
        value: '${targetMembers.length}',
        icon: Icons.people_outline,
      ),
      if (!isGroupFiltered)
        _buildRibbonCard(
          label: 'My Groups',
          value: '${targetGroups.length}',
          icon: Icons.groups_outlined,
        )
      else
        _buildRibbonCard(
          label: 'Filtered Group',
          value: _selectedGroupFilter,
          icon: Icons.filter_alt_outlined,
        ),
      _buildRibbonCard(
        label: 'Client Savings',
        value: CurrencyFormatter.formatNaira(indivSav),
        icon: Icons.savings_outlined,
      ),
      _buildRibbonCard(
        label: 'Group Savings',
        value: CurrencyFormatter.formatNaira(grpSav),
        icon: Icons.group_work_outlined,
      ),
      if (miscSav > 0)
        _buildRibbonCard(
          label: 'Misc Savings',
          value: CurrencyFormatter.formatNaira(miscSav),
          icon: Icons.shield_outlined,
        ),
      if (principal > 0)
        _buildRibbonCard(
          label: 'Principal',
          value: CurrencyFormatter.formatNaira(principal),
          icon: Icons.payments_outlined,
        ),
      _buildRibbonCard(
        label: 'Active Credit',
        value: CurrencyFormatter.formatNaira(activeCredit),
        icon: Icons.credit_score_outlined,
      ),
      _buildRibbonCard(
        label: 'Loan Balance',
        value: CurrencyFormatter.formatNaira(currentBal),
        icon: Icons.monetization_on_outlined,
        isAlert: currentBal > 0,
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;

          if (isNarrow) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 58,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, idx) => items[idx],
                ),
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: items.map((w) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: w))).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRibbonCard({
    required String label,
    required String value,
    required IconData icon,
    bool isPrimary = false,
    bool isAlert = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPrimary
              ? const Color(0xFF10B981)
              : (isAlert ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1)),
          width: isPrimary ? 1.4 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 11,
                color: isPrimary
                    ? const Color(0xFF059669)
                    : (isAlert ? const Color(0xFFDC2626) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: isPrimary
                        ? const Color(0xFF065F46)
                        : (isAlert ? const Color(0xFF991B1B) : const Color(0xFF64748B)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: isPrimary
                  ? const Color(0xFF047857)
                  : (isAlert ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: SOLIDARITY GROUPS
  // =========================================================================

  Widget _buildGroupsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Solidarity Groups',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (!_isLocked)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
                  onPressed: () => _openGroupDialog(),
                  icon: const Icon(Icons.group_add_outlined, size: 16),
                  label: const Text('Add Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_groups.isEmpty)
            _buildEmptyState('No solidarity groups registered yet.', 'Create your first group to start adding member accounts.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final g = _groups[idx];
                final gRef = (g['group_reference'] ?? '').toString();
                final gName = (g['group_name'] ?? '').toString();
                final day = (g['meeting_day'] ?? 'Daily').toString();
                final sav = double.tryParse(g['group_savings']?.toString() ?? '0') ?? 0.0;
                final leader = g['leader_name'];
                final clientCount = _members.where((m) => (m['group_reference'] ?? '').toString().toUpperCase() == gRef.toUpperCase()).length;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, cardConstraints) {
                      final isCardNarrow = cardConstraints.maxWidth < 520;

                      if (isCardNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    gRef,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    gName,
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!_isLocked) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                    onPressed: () => _openGroupDialog(groupToEdit: g),
                                    tooltip: 'Edit group',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFDC2626)),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                    onPressed: () => _confirmDeleteGroup(g),
                                    tooltip: 'Delete group',
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Meeting: $day • $clientCount clients ${leader != null ? "• Rep: $leader" : ""}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pool: ${CurrencyFormatter.formatNaira(sav)}',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              gRef,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(gName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                const SizedBox(height: 2),
                                Text(
                                  'Meeting: $day • $clientCount registered clients ${leader != null ? "• Rep: $leader" : ""}',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Group Savings Pool', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              Text(
                                CurrencyFormatter.formatNaira(sav),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                          if (!_isLocked) ...[
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _openGroupDialog(groupToEdit: g),
                              tooltip: 'Edit group',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _confirmDeleteGroup(g),
                              tooltip: 'Delete group',
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: CLIENTS ROSTER
  // =========================================================================

  Widget _buildMembersTab() {
    final filteredMembers = _members.where((m) {
      final matchesGroup = _selectedGroupFilter == 'All' || (m['group_reference'] ?? '').toString().toUpperCase() == _selectedGroupFilter.toUpperCase();
      final q = _searchQuery.trim().toLowerCase();
      if (q.isEmpty) return matchesGroup;
      final name = (m['full_name'] ?? '').toString().toLowerCase();
      final phone = (m['phone_number'] ?? '').toString().toLowerCase();
      final ref = (m['group_reference'] ?? '').toString().toLowerCase();
      return matchesGroup && (name.contains(q) || phone.contains(q) || ref.contains(q));
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Clients Roster',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (!_isLocked)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
                  onPressed: () => _openMemberDialog(),
                  icon: const Icon(Icons.person_add_alt_outlined, size: 16),
                  label: const Text('Register Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search client name or phone...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedGroupFilter,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    items: [
                      const DropdownMenuItem(value: 'All', child: Text('All Groups')),
                      ..._groups.map((g) => DropdownMenuItem(
                            value: g['group_reference'] ?? '',
                            child: Text(g['group_reference'] ?? ''),
                          )),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedGroupFilter = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (filteredMembers.isEmpty)
            _buildEmptyState('No clients found.', _members.isEmpty ? 'Click "Register Client" to add members to your groups.' : 'No clients match your filter.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredMembers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final m = filteredMembers[idx];
                final name = (m['full_name'] ?? '').toString();
                final gRef = (m['group_reference'] ?? '').toString();
                final phone = (m['phone_number'] ?? '').toString();
                final sav = double.tryParse(m['savings_balance']?.toString() ?? '0') ?? 0.0;
                final credit = double.tryParse(m['active_credit']?.toString() ?? '0') ?? 0.0;
                final bal = double.tryParse((m['current_credit_balance'] ?? m['current_balance'])?.toString() ?? '0') ?? 0.0;
                final lType = m['loan_type'];

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, cardConstraints) {
                      final isCardNarrow = cardConstraints.maxWidth < 500;

                      if (isCardNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  child: Text(
                                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'C',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'Group $gRef${phone.isNotEmpty ? " • $phone" : ""}${lType != null ? " • $lType" : ""}',
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_isLocked) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                    onPressed: () => _openMemberDialog(memberToEdit: m),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFDC2626)),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                    onPressed: () => _confirmDeleteMember(m),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Savings: ${CurrencyFormatter.formatNaira(sav)}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                                  ),
                                  if (credit > 0 || bal > 0)
                                    Text(
                                      'Balance: ${CurrencyFormatter.formatNaira(bal)}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFF1F5F9),
                            child: Text(
                              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'C',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                const SizedBox(height: 2),
                                Text(
                                  'Group $gRef ${phone.isNotEmpty ? "• $phone" : ""} ${lType != null ? "• $lType" : ""}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Savings: ${CurrencyFormatter.formatNaira(sav)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                              if (credit > 0 || bal > 0)
                                Text('Balance: ${CurrencyFormatter.formatNaira(bal)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                            ],
                          ),
                          if (!_isLocked) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _openMemberDialog(memberToEdit: m),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFDC2626)),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _confirmDeleteMember(m),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: EXCEL UPLOAD
  // =========================================================================

  Widget _buildExcelTab() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.upload_file_outlined, size: 36, color: IcareColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload Credit Officer Excel Template',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select an Excel workbook (.xlsx) containing your Groups and Members sheets. Groups and accounts will automatically be tagged to your officer profile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            if (!_isLocked)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: IcareColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _pickAndUploadExcel,
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: const Text('Choose Excel File (.xlsx)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              )
            else
              const Text(
                'Workspace is locked. Excel upload disabled.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 4: REVIEW & SIGN-OFF
  // =========================================================================

  Widget _buildReviewTab(bool isSubmitted) {
    final indivSav = double.tryParse(_aggregates['individual_member_savings']?.toString() ?? '0') ?? 0.0;
    final grpSav = double.tryParse(_aggregates['group_savings_pool']?.toString() ?? '0') ?? 0.0;
    final miscSav = double.tryParse(_aggregates['misc_savings']?.toString() ?? _officer?['misc_savings']?.toString() ?? '0') ?? 0.0;
    final totSav = double.tryParse(_aggregates['total_portfolio_savings']?.toString() ?? '0') ?? 0.0;
    final activeCredit = double.tryParse(_aggregates['active_credit']?.toString() ?? '0') ?? 0.0;
    final currentBal = double.tryParse(_aggregates['outstanding_balance']?.toString() ?? '0') ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSubmitted)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF059669), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Roster Submitted to Branch Manager',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Submitted on ${_officer?['submitted_at'] != null ? DateFormat('MMM dd, yyyy h:mm a').format(DateTime.parse(_officer!['submitted_at'])) : "recently"}. Awaiting Branch Manager verification and package consolidation.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const Text(
                'My Portfolio Reconciliation Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Solidarity Groups', '${_groups.length} groups'),
                    const Divider(height: 1),
                    _buildSummaryRow('Registered Client Accounts', '${_members.length} clients'),
                    const Divider(height: 1),
                    _buildSummaryRow('Individual Member Savings', CurrencyFormatter.formatNaira(indivSav)),
                    const Divider(height: 1),
                    _buildSummaryRow('Group Solidarity Savings Pool', CurrencyFormatter.formatNaira(grpSav)),
                    const Divider(height: 1),
                    if (miscSav > 0) ...[
                      _buildSummaryRow('Branch Misc Savings (Designated)', CurrencyFormatter.formatNaira(miscSav)),
                      const Divider(height: 1),
                    ],
                    _buildSummaryRow('Total Portfolio Savings', CurrencyFormatter.formatNaira(totSav), isHighlight: true),
                    const Divider(height: 1),
                    _buildSummaryRow('Total Active Loan Credit', CurrencyFormatter.formatNaira(activeCredit)),
                    const Divider(height: 1),
                    _buildSummaryRow('Total Outstanding Loan Balance', CurrencyFormatter.formatNaira(currentBal)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (!_isLocked)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IcareColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSaving ? null : _submitRoster,
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text(
                      'Submit My Roster to Branch Manager',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: isHighlight ? const Color(0xFF0F172A) : const Color(0xFF64748B), fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isHighlight ? const Color(0xFF059669) : const Color(0xFF0F172A),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 36, color: Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}
