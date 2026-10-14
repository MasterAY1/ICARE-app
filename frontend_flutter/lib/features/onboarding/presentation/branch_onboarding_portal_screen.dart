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
  List<dynamic> get loanProducts => _sessionData != null ? (_sessionData!['loan_products'] as List<dynamic>? ?? []) : [];
  List<dynamic> get meetingDays => _sessionData != null ? (_sessionData!['meeting_days'] as List<dynamic>? ?? []) : [];

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

  // Group helpers
  void _addGroup() {
    final nextNum = _groups.length + 1;
    final nextRef = 'GRP-${nextNum.toString().padLeft(2, '0')}';
    setState(() {
      _groups.add({
        'group_reference': nextRef,
        'group_name': 'New Solidarity Group $nextNum',
        'meeting_day': 'Daily',
        'leader_name': '',
        'officer_name': '',
        'officer_phone': '',
        'group_savings': 0.0,
      });
    });
    _saveDraft();
  }

  void _addMember() {
    final groupRef = _selectedGroupFilter == 'All'
        ? (_groups.isNotEmpty ? _groups.first['group_reference'] : 'GRP-01')
        : _selectedGroupFilter;

    final nextSeq = _members.length + 1;
    final branchCode = _sessionData?['branch_code'] ?? 'BR';
    final targetRef = '$branchCode-${groupRef.replaceAll('GRP-', '')}-${nextSeq.toString().padLeft(3, '0')}';

    setState(() {
      _members.add({
        'member_reference': targetRef,
        'group_reference': groupRef,
        'member_number': nextSeq,
        'full_name': 'Client Name',
        'phone_number': '',
        'home_address': '',
        'savings_balance': 0.0,
        'loan_type': 'Daily 60 Days',
        'principal_loan': 0.0,
        'active_credit': 0.0,
        'current_credit_balance': 0.0,
      });
    });
  }

  double get _totalSavings => _members.fold(0.0, (sum, m) => sum + (double.tryParse(m['savings_balance']?.toString() ?? '0') ?? 0.0));
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
              child: TabBar(
                controller: _tabController,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Institutional Logo / Badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Icon(Icons.account_balance, size: 20, color: Color(0xFF0F766E)),
          ),
          const SizedBox(width: 12),

          // Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'ICARE Core Banking',
                      style: IcareTypography.caption.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSubmitted ? const Color(0xFF065F46) : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '$branchName ($branchCode) — Branch Onboarding Portal',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Action Buttons
          if (!isSubmitted) ...[
            if (_lastSavedTime != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  'Saved ${DateFormat('HH:mm').format(_lastSavedTime!)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _saveDraft,
              icon: _isSaving
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save Draft', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: IcareColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSaving ? null : _submitPackage,
              icon: const Icon(Icons.send_outlined, size: 15),
              label: const Text('Submit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
                  SizedBox(width: 6),
                  Text('Submitted for Administrative Review', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryMetricsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;
          final items = [
            _buildMetricItem('Groups', _groups.length.toString(), Icons.hub_outlined, const Color(0xFF475569)),
            _buildMetricItem('Members', _members.length.toString(), Icons.people_outline, const Color(0xFF475569)),
            _buildMetricItem('Total Savings', CurrencyFormatter.formatNaira(_totalSavings), Icons.savings_outlined, const Color(0xFF059669)),
            _buildMetricItem('Disbursed Credit', CurrencyFormatter.formatNaira(_totalActiveCredit), Icons.credit_card_outlined, const Color(0xFF2563EB)),
            _buildMetricItem('Outstanding Balance', CurrencyFormatter.formatNaira(_totalCurrentBalance), Icons.account_balance_wallet_outlined, const Color(0xFFD97706)),
          ];

          if (isNarrow) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: items.map((e) => Padding(padding: const EdgeInsets.only(right: 20), child: e)).toList(),
              ),
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: items,
          );
        },
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
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
          // Filter Bar
          Row(
            children: [
              // Group Selector Filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedGroupFilter,
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
              ),
              const SizedBox(width: 12),

              // Search Textfield
              Expanded(
                child: SizedBox(
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
                ),
              ),
              const SizedBox(width: 12),

              if (!isSubmitted)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: IcareColors.primary, foregroundColor: Colors.white),
                  onPressed: _addMember,
                  icon: const Icon(Icons.person_add_alt_1, size: 15),
                  label: const Text('Add Member', style: TextStyle(fontSize: 12)),
                ),
            ],
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
                              ? 'No members added yet. Click "Add Member" or upload your Excel template.'
                              : 'No members match the current filter.',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : Container(
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
                          return _buildMemberRow(m, isSubmitted);
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRow(Map<String, dynamic> m, bool isSubmitted) {
    final refCode = m['member_reference'] ?? 'Pending Code';
    final gRef = m['group_reference'] ?? 'GRP-01';
    final name = m['full_name'] ?? '';
    final phone = m['phone_number'] ?? '';
    final savings = double.tryParse(m['savings_balance']?.toString() ?? '0') ?? 0.0;
    final activeCred = double.tryParse(m['active_credit']?.toString() ?? '0') ?? 0.0;
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
              icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
              tooltip: 'Remove member',
              onPressed: () {
                setState(() => _members.remove(m));
                _saveDraft();
              },
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
                  label: const Text('Add Group', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _groups.isEmpty
                ? const Center(child: Text('No groups added yet.'))
                : ListView.separated(
                    itemCount: _groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final g = _groups[idx];
                      final gRef = g['group_reference'] ?? 'GRP-${idx + 1}';
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
                          ],
                        ),
                      );
                    },
                  ),
          ),
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
                    const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    _buildReviewRow('Total Active Credit Disbursed', CurrencyFormatter.formatNaira(_totalActiveCredit)),
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
