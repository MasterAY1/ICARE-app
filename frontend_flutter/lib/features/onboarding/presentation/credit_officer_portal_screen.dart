import '../../../../core/utils/platform_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../data/onboarding_api_service.dart';

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
    _loadWorkspace();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkspace() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(onboardingApiServiceProvider);
      final data = await api.getOfficerWorkspace(widget.coToken);

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

      final data = await api.saveOfficerDraft(widget.coToken, payload);

      if (mounted) {
        setState(() {
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
      await api.saveOfficerDraft(widget.coToken, {'groups': _groups, 'members': _members});
      // Submit
      await api.submitOfficerRoster(widget.coToken);

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
        widget.coToken,
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
    final savingsCtrl = TextEditingController(text: (groupToEdit?['group_savings'] ?? 0.0).toString());
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
    final savingsCtrl = TextEditingController(text: (memberToEdit?['savings_balance'] ?? 0.0).toString());
    final activeCreditCtrl = TextEditingController(text: (memberToEdit?['active_credit'] ?? 0.0).toString());
    final currentBalCtrl = TextEditingController(text: (memberToEdit?['current_credit_balance'] ?? 0.0).toString());

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
                          decoration: const InputDecoration(labelText: 'Savings Balance (₦)', prefixText: '₦ '),
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
                          controller: activeCreditCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Active Credit (₦)', prefixText: '₦ '),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: currentBalCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Current Balance (₦)', prefixText: '₦ '),
                        ),
                      ),
                    ],
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

                final sBal = double.tryParse(savingsCtrl.text.trim()) ?? 0.0;
                final aCred = double.tryParse(activeCreditCtrl.text.trim()) ?? 0.0;
                final cBal = double.tryParse(currentBalCtrl.text.trim()) ?? (aCred > 0 ? aCred : 0.0);

                final updatedMember = {
                  'full_name': fName,
                  'group_reference': selectedGroupRef,
                  'phone_number': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  'home_address': addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
                  'savings_balance': sBal,
                  'active_credit': aCred,
                  'current_credit_balance': cBal,
                  'loan_type': (aCred > 0 || cBal > 0) ? selectedLoanProduct : null,
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

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
                const SizedBox(height: 16),
                const Text(
                  'Access Restriction',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
                  onPressed: _loadWorkspace,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry Connection'),
                ),
              ],
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
              child: TabBar(
                controller: _tabController,
                labelColor: IcareColors.primary,
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: IcareColors.primary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.groups_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text('Solidarity Groups (${_groups.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_outline, size: 16),
                        const SizedBox(width: 6),
                        Text('Clients Roster (${_members.length})'),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('Excel Ingestion'),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fact_check_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('Review & Sign-Off'),
                      ],
                    ),
                  ),
                ],
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

          final officerTitle = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    officerName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSubmitted ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isSubmitted ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      isSubmitted ? 'SUBMITTED TO BM' : 'DRAFTING',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isSubmitted ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Credit Officer • $_branchName • Branch: ${_sessionStatus.toUpperCase()}${_expiresAt != null ? " • Due: ${DateFormat('dd MMM').format(_expiresAt!.toLocal())}" : ""}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          );

          final actionButtons = Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
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

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    branchPill,
                    const SizedBox(width: 8),
                    Expanded(child: officerTitle),
                  ],
                ),
                const SizedBox(height: 10),
                actionButtons,
              ],
            );
          }

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
    final indivSav = double.tryParse(_aggregates['individual_member_savings']?.toString() ?? '0') ?? 0.0;
    final grpSav = double.tryParse(_aggregates['group_savings_pool']?.toString() ?? '0') ?? 0.0;
    final totSav = double.tryParse(_aggregates['total_portfolio_savings']?.toString() ?? '0') ?? 0.0;
    final activeCredit = double.tryParse(_aggregates['active_credit']?.toString() ?? '0') ?? 0.0;
    final currentBal = double.tryParse(_aggregates['outstanding_balance']?.toString() ?? '0') ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;
          final items = [
            _buildRibbonKpi('My Groups', '${_groups.length}'),
            _buildRibbonKpi('My Clients', '${_members.length}'),
            _buildRibbonKpi('Client Savings', CurrencyFormatter.formatNaira(indivSav)),
            _buildRibbonKpi('Group Savings', CurrencyFormatter.formatNaira(grpSav)),
            _buildRibbonKpi('Total Savings', CurrencyFormatter.formatNaira(totSav), isPrimary: true),
            _buildRibbonKpi('Active Credit', CurrencyFormatter.formatNaira(activeCredit)),
            _buildRibbonKpi('Current Balance', CurrencyFormatter.formatNaira(currentBal)),
          ];

          if (isNarrow) {
            return Wrap(
              spacing: 14,
              runSpacing: 8,
              children: items.map((w) => SizedBox(width: (constraints.maxWidth - 44) / 2 > 120 ? (constraints.maxWidth - 44) / 2 : 120, child: w)).toList(),
            );
          }

          return Row(
            children: items.map((w) => Expanded(child: w)).toList(),
          );
        },
      ),
    );
  }

  Widget _buildRibbonKpi(String label, String value, {bool isPrimary = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          softWrap: true,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isPrimary ? const Color(0xFF0F2744) : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          softWrap: true,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isPrimary ? const Color(0xFF059669) : const Color(0xFF0F172A),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
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
                  padding: const EdgeInsets.all(14),
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
                    decoration: const InputDecoration(
                      hintText: 'Search client name or phone...',
                      prefixIcon: Icon(Icons.search, size: 16),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _selectedGroupFilter,
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All Groups')),
                  ..._groups.map((g) => DropdownMenuItem(value: g['group_reference'] ?? '', child: Text(g['group_reference'] ?? ''))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedGroupFilter = val);
                },
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
                final bal = double.tryParse(m['current_credit_balance']?.toString() ?? '0') ?? 0.0;
                final lType = m['loan_type'];

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
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
