import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/app_url_helper.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../data/onboarding_api_service.dart';
import 'branch_onboarding_portal_screen.dart';
import 'widgets/successful_delete_dialog.dart';

/// Modal dialog allowing Admins, Directors, and Area Managers to generate
/// a cryptographically secure 14-day branch onboarding link.
Future<void> showGenerateOnboardingLinkDialog(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onCreated,
}) async {
  final nameCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final personCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  final formKey = GlobalKey<FormState>();
  bool isCreating = false;
  String? generatedUrl;
  String? generatedToken;
  String? errorMessage;
  bool isCopied = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(24),
              child: generatedUrl != null
                  ? _buildSuccessView(
                      context: context,
                      token: generatedToken!,
                      url: generatedUrl!,
                      isCopied: isCopied,
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: generatedUrl!));
                        setDialogState(() => isCopied = true);
                        Future.delayed(const Duration(seconds: 3), () {
                          if (context.mounted) setDialogState(() => isCopied = false);
                        });
                      },
                      onOpen: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BranchOnboardingPortalScreen(token: generatedToken!),
                          ),
                        );
                      },
                      onClose: () {
                        Navigator.of(ctx).pop();
                        onCreated?.call();
                      },
                    )
                  : _buildFormView(
                      formKey: formKey,
                      nameCtrl: nameCtrl,
                      codeCtrl: codeCtrl,
                      personCtrl: personCtrl,
                      phoneCtrl: phoneCtrl,
                      isCreating: isCreating,
                      errorMessage: errorMessage,
                      onCancel: () => Navigator.of(ctx).pop(),
                      onSubmit: () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isCreating = true;
                          errorMessage = null;
                        });

                        try {
                          final api = ref.read(onboardingApiServiceProvider);
                          final res = await api.createAdminSession(
                            branchName: nameCtrl.text.trim(),
                            branchCode: codeCtrl.text.trim().toUpperCase(),
                            contactPerson: personCtrl.text.trim().isEmpty ? null : personCtrl.text.trim(),
                            contactPhone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          );

                          final session = res['session'] as Map<String, dynamic>? ?? {};
                          final token = session['token']?.toString() ?? '';
                          final origin = getAppPublicOrigin();
                          final fullUrl = '$origin/#/onboarding?token=$token';

                          setDialogState(() {
                            isCreating = false;
                            generatedToken = token;
                            generatedUrl = fullUrl;
                          });
                        } catch (e) {
                          setDialogState(() {
                            isCreating = false;
                            errorMessage = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                    ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildFormView({
  required GlobalKey<FormState> formKey,
  required TextEditingController nameCtrl,
  required TextEditingController codeCtrl,
  required TextEditingController personCtrl,
  required TextEditingController phoneCtrl,
  required bool isCreating,
  required String? errorMessage,
  required VoidCallback onCancel,
  required VoidCallback onSubmit,
}) {
  return Form(
    key: formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Bar
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Icon(Icons.domain_add, size: 20, color: Color(0xFF1D4ED8)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generate Branch Onboarding Invitation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Issues a secure 14-day digital ingestion link for a new branch.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        if (errorMessage != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(errorMessage, style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
                ),
              ],
            ),
          ),

        // Branch Name Field
        TextFormField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Branch Name *',
            hintText: 'e.g. Sagamu Branch, Ikorodu Branch',
            prefixIcon: Icon(Icons.apartment, size: 16),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Branch name is required' : null,
        ),
        const SizedBox(height: 14),

        // Branch Code Field
        TextFormField(
          controller: codeCtrl,
          textCapitalization: TextCapitalization.characters,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: 'Branch Code (2-4 Letters) *',
            hintText: 'e.g. SAG, IKD, IJB',
            prefixIcon: Icon(Icons.tag, size: 16),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            counterText: '',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Branch code is required';
            if (v.trim().length < 2) return 'Code must be at least 2 characters';
            return null;
          },
        ),
        const SizedBox(height: 14),

        // Coordinator Name Field
        TextFormField(
          controller: personCtrl,
          decoration: const InputDecoration(
            labelText: 'Coordinator / Branch Manager (Optional)',
            hintText: 'e.g. Adebayo Adeleke',
            prefixIcon: Icon(Icons.person_outline, size: 16),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        // Coordinator Phone Field
        TextFormField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Contact Phone Number (Optional)',
            hintText: 'e.g. 08012345678',
            prefixIcon: Icon(Icons.phone_outlined, size: 16),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),

        // Policy Note
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 15, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The generated link will be valid for 14 days and automatically extends whenever the branch saves draft progress. Staged data remains isolated until administrative approval.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: isCreating ? null : onCancel,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: IcareColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              ),
              onPressed: isCreating ? null : onSubmit,
              icon: isCreating
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.link, size: 16),
              label: Text(
                isCreating ? 'Generating...' : 'Generate Secure Link',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildSuccessView({
  required BuildContext context,
  required String token,
  required String url,
  required bool isCopied,
  required VoidCallback onCopy,
  required VoidCallback onOpen,
  required VoidCallback onClose,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Icon(Icons.check_circle_outline, size: 22, color: Color(0xFF059669)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Onboarding Invitation Generated!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                ),
                Text(
                  'Share this direct link with the branch coordinator.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),

      const Text('PUBLIC ONBOARDING LINK', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
      const SizedBox(height: 6),

      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                url,
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCopied ? const Color(0xFF059669) : IcareColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: onCopy,
              icon: Icon(isCopied ? Icons.done : Icons.copy, size: 14),
              label: Text(isCopied ? 'Copied!' : 'Copy Link', style: const TextStyle(fontSize: 11.5)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      Row(
        children: [
          const Text('Invitation Token: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          SelectableText(
            token,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
          ),
        ],
      ),
      const SizedBox(height: 20),

      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: onClose,
            child: const Text('Close'),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: IcareColors.primaryDark,
              foregroundColor: Colors.white,
            ),
            onPressed: onOpen,
            icon: const Icon(Icons.launch, size: 14),
            label: const Text('Open Portal Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ],
  );
}

/// Dedicated Admin & Area Manager screen for managing digital onboarding sessions.
class BranchOnboardingAdminScreen extends ConsumerStatefulWidget {
  const BranchOnboardingAdminScreen({super.key});

  @override
  ConsumerState<BranchOnboardingAdminScreen> createState() => _BranchOnboardingAdminScreenState();
}

class _BranchOnboardingAdminScreenState extends ConsumerState<BranchOnboardingAdminScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _sessions = [];
  String _statusFilter = 'All'; // 'All', 'draft', 'submitted', 'approved'
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _deletingSessionIds = {};

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(onboardingApiServiceProvider);
      final sessions = await api.listAdminSessions();
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove(Map<String, dynamic> session) async {
    final branchName = session['branch_name'] ?? 'Branch';
    final sessionId = session['id']?.toString() ?? '';
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve & Activate $branchName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action will atomically commit all staged solidarity groups, members, savings balances, loans, and schedules into live core banking tables.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Approval Notes / Audit Remark (Optional)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Approve & Commit to Core Banking'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = ref.read(onboardingApiServiceProvider);
      await api.approveAdminSession(sessionId, notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Branch $branchName successfully activated into live banking!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
      _loadSessions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve session: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(Map<String, dynamic> session) async {
    final branchName = session['branch_name'] ?? 'Branch';
    final branchCode = session['branch_code'] ?? '';
    final sessionId = session['id']?.toString() ?? '';
    final status = (session['status'] ?? 'draft').toString().toLowerCase();

    if (status == 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Approved onboarding packages cannot be deleted because core banking records have already been committed.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $branchName ($branchCode)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete the onboarding session for $branchName ($branchCode)?',
              style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'All draft groups, credit officer rosters, and unposted member records will be permanently removed. This action cannot be undone.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete Session'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _deletingSessionIds.add(sessionId);
    });

    try {
      final api = ref.read(onboardingApiServiceProvider);
      await api.deleteAdminSession(sessionId);
      if (mounted) {
        await SuccessfulDeleteAnimationDialog.show(
          context,
          branchName: branchName,
          branchCode: branchCode,
        );
      }
      _loadSessions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete session: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingSessionIds.remove(sessionId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _sessions.where((s) {
      final matchesFilter = _statusFilter == 'All' || s['status'] == _statusFilter.toLowerCase();
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isEmpty) return matchesFilter;
      final name = (s['branch_name'] ?? '').toString().toLowerCase();
      final code = (s['branch_code'] ?? '').toString().toLowerCase();
      final token = (s['token'] ?? '').toString().toLowerCase();
      final person = (s['contact_person'] ?? '').toString().toLowerCase();
      return matchesFilter && (name.contains(q) || code.contains(q) || token.contains(q) || person.contains(q));
    }).toList();

    final totalCount = _sessions.length;
    final draftCount = _sessions.where((s) => s['status'] == 'draft').length;
    final submittedCount = _sessions.where((s) => s['status'] == 'submitted').length;
    final approvedCount = _sessions.where((s) => s['status'] == 'approved').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Header Banner
        _buildPageHeader(),
        const SizedBox(height: 16),

        // KPI Metric Cards
        _buildMetricCards(totalCount, draftCount, submittedCount, approvedCount),
        const SizedBox(height: 20),

        // Filter and Search Bar
        _buildFilterBar(),
        const SizedBox(height: 14),

        // Content Area with Living Skeleton Shimmer
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _isLoading
              ? const IcareOnboardingSkeleton(
                  key: ValueKey('onboarding_skeleton'),
                  cardCount: 3,
                )
              : _errorMessage != null
                  ? _buildErrorNotice()
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : Column(
                          key: const ValueKey('onboarding_sessions_list'),
                          children: filtered.map((s) => _buildSessionCard(s)).toList(),
                        ),
        ),
      ],
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;
          const titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Branch Digital Onboarding Management',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              SizedBox(height: 4),
              Text(
                'Active branch digital onboarding and core banking activations.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
            ],
          );

          final generateBtn = ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: IcareColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              showGenerateOnboardingLinkDialog(
                context,
                ref,
                onCreated: _loadSessions,
              );
            },
            icon: const Icon(Icons.add_link, size: 18),
            label: const Text(
              'Generate Branch Link',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 12),
                generateBtn,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: titleBlock),
              const SizedBox(width: 12),
              generateBtn,
            ],
          );
        },
      ),
    );
  }


  Widget _buildMetricCards(int total, int drafts, int submitted, int approved) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final cards = [
          _buildKpiCard('Total Invitations', total.toString(), Icons.link, const Color(0xFF64748B)),
          _buildKpiCard('Active Drafts', drafts.toString(), Icons.edit_note, const Color(0xFFD97706)),
          _buildKpiCard('Awaiting Sign-Off', submitted.toString(), Icons.pending_actions, const Color(0xFF2563EB)),
          _buildKpiCard('Activated Branches', approved.toString(), Icons.verified, const Color(0xFF059669)),
        ];

        if (isNarrow) {
          return Column(
            children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c)).toList(),
          );
        }

        return Row(
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
        // Filter Chips
        ...['All', 'Draft', 'Submitted', 'Approved'].map((f) {
          final isSelected = _statusFilter.toLowerCase() == f.toLowerCase();
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (_) => setState(() => _statusFilter = f),
              selectedColor: const Color(0xFFECFDF5),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF065F46) : const Color(0xFF475569),
              ),
            ),
          );
        }),
        const Spacer(),

        // Search Field
        SizedBox(
          width: 240,
          height: 38,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search branches or tokens...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
              contentPadding: EdgeInsets.zero,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          onPressed: _loadSessions,
          tooltip: 'Refresh Sessions',
        ),
      ],
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> s) {
    final sessionId = s['id']?.toString() ?? '';
    final branchName = s['branch_name'] ?? 'Branch';
    final branchCode = s['branch_code'] ?? 'BR';
    final token = s['token'] ?? '';
    final status = (s['status'] ?? 'draft').toString().toLowerCase();
    final person = s['contact_person'] ?? '';
    final phone = s['contact_phone'] ?? '';
    final groupsCount = s['total_groups'] ?? 0;
    final membersCount = s['total_members'] ?? 0;
    final savings = double.tryParse(s['total_savings']?.toString() ?? '0') ?? 0.0;
    final activeCredit = double.tryParse(s['total_active_credit']?.toString() ?? '0') ?? 0.0;
    final balance = double.tryParse(s['total_current_balance']?.toString() ?? '0') ?? 0.0;
    final expiresAt = s['expires_at'] != null ? DateTime.tryParse(s['expires_at']) : null;

    final origin = getAppPublicOrigin();
    final fullUrl = '$origin/#/onboarding?token=$token';

    Color badgeBg;
    Color badgeText;
    if (status == 'approved') {
      badgeBg = const Color(0xFFECFDF5);
      badgeText = const Color(0xFF065F46);
    } else if (status == 'submitted') {
      badgeBg = const Color(0xFFEFF6FF);
      badgeText = const Color(0xFF1D4ED8);
    } else {
      badgeBg = const Color(0xFFFFFBEB);
      badgeText = const Color(0xFFB45309);
    }

    final isDeletingThis = _deletingSessionIds.contains(sessionId);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isDeletingThis ? 0.45 : 1.0,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDeletingThis
                    ? const Color(0xFFFCA5A5)
                    : (status == 'submitted' ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
                width: status == 'submitted' ? 1.4 : 1.0,
              ),
            ),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2744),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(branchCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branchName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    if (person.isNotEmpty || phone.isNotEmpty)
                      Text(
                        'Coordinator: $person ${phone.isNotEmpty ? "($phone)" : ""}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeText),
                ),
              ),
              if (status != 'approved') ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Delete Onboarding Package',
                  child: InkWell(
                    onTap: _deletingSessionIds.contains(sessionId) ? null : () => _handleDelete(s),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _deletingSessionIds.contains(sessionId)
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
                            )
                          : const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Aggregates Grid
          LayoutBuilder(
            builder: (context, cardConstraints) {
              final isNarrow = cardConstraints.maxWidth < 620;
              final metricItems = [
                _buildCardMetricItem('Groups', '$groupsCount'),
                _buildCardMetricItem('Members', '$membersCount'),
                _buildCardMetricItem('Savings', CurrencyFormatter.formatNaira(savings)),
                _buildCardMetricItem('Active Credit', CurrencyFormatter.formatNaira(activeCredit)),
                _buildCardMetricItem('Outstanding', CurrencyFormatter.formatNaira(balance)),
              ];

              if (isNarrow) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: metricItems.map((item) {
                      final itemWidth = (cardConstraints.maxWidth - 56) / 2 > 130
                          ? (cardConstraints.maxWidth - 56) / 2
                          : 130.0;
                      return SizedBox(width: itemWidth, child: item);
                    }).toList(),
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: metricItems.map((item) => Expanded(child: item)).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Footer Row with Actions
          LayoutBuilder(
            builder: (context, footerConstraints) {
              final timerBadge = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: expiresAt != null && expiresAt.isBefore(DateTime.now()) ? Colors.red : const Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    expiresAt != null
                        ? (expiresAt.isBefore(DateTime.now())
                            ? 'Expired on ${DateFormat('MMM dd, yyyy').format(expiresAt)}'
                            : 'Expires ${DateFormat('MMM dd, yyyy').format(expiresAt)}')
                        : 'Active',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: expiresAt != null && expiresAt.isBefore(DateTime.now()) ? Colors.red : const Color(0xFF64748B),
                    ),
                  ),
                ],
              );

              final actionButtons = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: fullUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Onboarding link copied to clipboard!'), duration: Duration(seconds: 2)),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 13),
                    label: const Text('Copy Link', style: TextStyle(fontSize: 11)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F2744),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BranchOnboardingPortalScreen(token: token, isAmView: true),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_browser, size: 14),
                    label: const Text('Open Portal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  if (status == 'submitted')
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: () => _handleApprove(s),
                      icon: const Icon(Icons.verified, size: 14),
                      label: const Text('Review & Activate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  if (status != 'approved')
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        backgroundColor: const Color(0xFFFEF2F2),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: _deletingSessionIds.contains(sessionId) ? null : () => _handleDelete(s),
                      icon: _deletingSessionIds.contains(sessionId)
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
                            )
                          : const Icon(Icons.delete_outline, size: 14, color: Color(0xFFDC2626)),
                      label: Text(
                        _deletingSessionIds.contains(sessionId) ? 'Deleting...' : 'Delete',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                      ),
                    ),
                ],
              );

              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  timerBadge,
                  actionButtons,
                ],
              );
            },
          ),
        ],
      ),
    ),
    if (isDeletingThis)
      Positioned.fill(
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xB3FFFFFF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
                ),
                SizedBox(width: 10),
                Text(
                  'Deleting session...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
  ],
      ),
    );
  }

  Widget _buildCardMetricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          softWrap: true,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          softWrap: true,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }


  Widget _buildErrorNotice() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadSessions, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.domain_verification, size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text('No Branch Onboarding Sessions Found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            SizedBox(height: 6),
            Text('Click "Generate Branch Link" above to issue an invitation to a new branch.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}
