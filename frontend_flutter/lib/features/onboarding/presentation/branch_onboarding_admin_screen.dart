import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/app_url_helper.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_metric_card.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../../../../core/auth/auth_controller.dart';
import '../../../../core/auth/auth_state.dart';
import '../data/onboarding_api_service.dart';
import 'branch_onboarding_portal_screen.dart';
import 'widgets/onboarding_analytics_charts.dart';
import 'widgets/successful_delete_dialog.dart';
import 'package:frontend_flutter/core/theme/icare_motion.dart';

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

  await showIcareAdaptiveSheet<void>(
    context: context,
    fitContent: true,
    builder: (ctx, isDialog) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final bottomInset = isDialog ? 0.0 : MediaQuery.viewInsetsOf(ctx).bottom;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24 + bottomInset),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
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
                      context: context,
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
                            errorMessage = AppErrorDetails.from(e).message;
                          });
                        }
                      },
                    ),
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
      codeCtrl.dispose();
      personCtrl.dispose();
      phoneCtrl.dispose();
    });
  });
}

Widget _buildFormView({
  required BuildContext context,
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
  final tokens = IcareSurfaceTokens.of(context);
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
                color: tokens.infoBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.infoBorder),
              ),
              child: Icon(Icons.domain_add, size: 20, color: tokens.infoText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generate Branch Onboarding Invitation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                  ),
                  Text(
                    'Issues a secure 14-day digital ingestion link for a new branch.',
                    style: TextStyle(fontSize: 12, color: tokens.textMuted),
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
              color: tokens.dangerBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.dangerBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: tokens.dangerDot),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(errorMessage, style: TextStyle(fontSize: 12, color: tokens.dangerText)),
                ),
              ],
            ),
          ),

        // Branch Name Field
        TextFormField(
          controller: nameCtrl,
          style: TextStyle(color: tokens.textPrimary),
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
          style: TextStyle(color: tokens.textPrimary),
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
          style: TextStyle(color: tokens.textPrimary),
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
          style: TextStyle(color: tokens.textPrimary),
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
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 15, color: tokens.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The generated link will be valid for 14 days and automatically extends whenever the branch saves draft progress. Staged data remains isolated until administrative approval.',
                  style: TextStyle(fontSize: 11, color: tokens.textSecondary, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action Buttons
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: isCreating ? null : onCancel,
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.brandPrimaryDark,
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
  final tokens = IcareSurfaceTokens.of(context);
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tokens.successBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.successBorder),
            ),
            child: Icon(Icons.check_circle_outline, size: 22, color: tokens.successDot),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Onboarding Invitation Generated!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.successText),
                ),
                Text(
                  'Share this direct link with the branch coordinator.',
                  style: TextStyle(fontSize: 12, color: tokens.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),

      Text('PUBLIC ONBOARDING LINK', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: tokens.textMuted, letterSpacing: 0.5)),
      const SizedBox(height: 6),

      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.borderStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              url,
              style: TextStyle(fontSize: 12, color: tokens.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCopied ? tokens.successDot : tokens.brandPrimaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: onCopy,
                icon: Icon(isCopied ? Icons.done : Icons.copy, size: 14),
                label: Text(isCopied ? 'Copied!' : 'Copy Link', style: const TextStyle(fontSize: 11.5)),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          Text('Invitation Token:', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
          SelectableText(
            token,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.infoText),
          ),
        ],
      ),
      const SizedBox(height: 20),

      Wrap(
        alignment: WrapAlignment.end,
        spacing: 10,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: onClose,
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.brandPrimaryDark,
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
        _errorMessage = AppErrorDetails.from(e).message;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove(Map<String, dynamic> session) async {
    final branchName = session['branch_name'] ?? 'Branch';
    final sessionId = session['id']?.toString() ?? '';
    final notesCtrl = TextEditingController();

    final confirmed = await showIcareAdaptiveSheet<bool>(
      context: context,
      fitContent: true,
      builder: (ctx, isDialog) {
        final dialogTokens = IcareSurfaceTokens.of(ctx);
        final bottomInset = isDialog ? 0.0 : MediaQuery.viewInsetsOf(ctx).bottom;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Approve & Activate $branchName',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: dialogTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This action will permanently activate all staged solidarity groups, members, savings balances, loans, and schedules into live branch operations.',
                style: TextStyle(fontSize: 13, height: 1.4, color: dialogTokens.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesCtrl,
                style: TextStyle(color: dialogTokens.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Approval Notes / Audit Remark (Optional)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dialogTokens.brandPrimaryDark,
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

    if (confirmed != true) return;

    try {
      final api = ref.read(onboardingApiServiceProvider);
      await api.approveAdminSession(sessionId, notes: notesText.isEmpty ? null : notesText);
      if (mounted) {
        final tokens = IcareSurfaceTokens.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Branch $branchName successfully activated into live operations!',
              style: TextStyle(color: tokens.successText, fontWeight: FontWeight.w600),
            ),
            backgroundColor: tokens.successBg,
          ),
        );
      }
      _loadSessions();
    } catch (e) {
      if (mounted) {
        final tokens = IcareSurfaceTokens.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to approve session: ${AppErrorDetails.from(e).message}',
              style: TextStyle(color: tokens.dangerText, fontWeight: FontWeight.w600),
            ),
            backgroundColor: tokens.dangerBg,
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
      final tokens = IcareSurfaceTokens.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Approved onboarding packages cannot be deleted because branch records have already been activated.',
            style: TextStyle(color: tokens.dangerText, fontWeight: FontWeight.w600),
          ),
          backgroundColor: tokens.dangerBg,
        ),
      );
      return;
    }

    final confirmed = await showIcareAdaptiveSheet<bool>(
      context: context,
      fitContent: true,
      builder: (ctx, isDialog) {
        final dialogTokens = IcareSurfaceTokens.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(20, isDialog ? 24 : 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete $branchName ($branchCode)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: dialogTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to permanently delete the onboarding session for $branchName ($branchCode)?',
                style: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: dialogTokens.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                'All draft groups, credit officer rosters, and unposted member records will be permanently removed. This action cannot be undone.',
                style: TextStyle(fontSize: 12.5, color: dialogTokens.textMuted, height: 1.4),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dialogTokens.dangerDot,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete Session'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
        final tokens = IcareSurfaceTokens.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete session: ${AppErrorDetails.from(e).message}',
              style: TextStyle(color: tokens.dangerText, fontWeight: FontWeight.w600),
            ),
            backgroundColor: tokens.dangerBg,
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
        if (!_isLoading && _errorMessage == null && _sessions.isNotEmpty) ...[
          const SizedBox(height: 16),
          OnboardingAdminOverviewCharts(sessions: _sessions),
        ],
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
    final tokens = IcareSurfaceTokens.of(context);
    return IcareCard(
      padding: const EdgeInsets.all(18),
      topAccentColor: tokens.brandPrimaryDark,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;
          final auth = ref.watch(authControllerProvider);
          final user = auth is AuthStateAuthenticated ? auth.user : null;
          final role = (user?.role ?? '').trim().toLowerCase();
          final isAm = role == 'area manager' || role == 'am';

          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (isAm)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: tokens.brandPrimaryDark,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'REGIONAL OVERSIGHT',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5),
                      ),
                    ),
                  Text(
                    isAm ? 'Regional Branch Setup Oversight' : 'Branch Digital Onboarding Management',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isAm
                    ? 'Oversee staged branch groups, officer rosters, and authorize live branch activations.'
                    : 'Active branch digital onboarding and operational activations.',
                style: TextStyle(fontSize: 12.5, color: tokens.textMuted),
              ),
            ],
          );

          final generateBtn = ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.brandPrimaryDark,
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
              Expanded(child: titleBlock),
              const SizedBox(width: 12),
              generateBtn,
            ],
          );
        },
      ),
    );
  }


  Widget _buildMetricCards(int total, int drafts, int submitted, int approved) {
    final tokens = IcareSurfaceTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final cards = [
          _buildKpiCard('Total Invitations', total.toString(), Icons.link, tokens.textSecondary),
          _buildKpiCard('Active Drafts', drafts.toString(), Icons.edit_note, tokens.warningDot),
          _buildKpiCard('Awaiting Sign-Off', submitted.toString(), Icons.pending_actions, tokens.infoDot),
          _buildKpiCard('Activated Branches', approved.toString(), Icons.verified, tokens.successDot),
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
    return IcareMetricCard(
      label: label,
      value: value,
      icon: icon,
      topBorderColor: color,
    );
  }

  Widget _buildFilterBar() {
    final tokens = IcareSurfaceTokens.of(context);
    final isWide = MediaQuery.of(context).size.width >= 720;
    final chips = ['All', 'Draft', 'Submitted', 'Approved'].map((f) {
      final isSelected = _statusFilter.toLowerCase() == f.toLowerCase();
      return ChoiceChip(
        label: Text(f),
        selected: isSelected,
        onSelected: (_) => setState(() => _statusFilter = f),
        backgroundColor: tokens.surfaceSubtle,
        selectedColor: tokens.brandSoftBg,
        side: BorderSide(color: isSelected ? tokens.brandSoftBorder : tokens.borderSubtle),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? tokens.brandSoftText : tokens.textSecondary,
        ),
      );
    }).toList();

    final searchBox = SizedBox(
      width: isWide ? 240 : double.infinity,
      height: 38,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: 13, color: tokens.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search branches or tokens...',
          hintStyle: TextStyle(fontSize: 12, color: tokens.textMuted),
          prefixIcon: Icon(Icons.search, size: 16, color: tokens.textMuted),
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: tokens.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.borderStrong)),
        ),
      ),
    );

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, runSpacing: 6, children: chips),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: searchBox),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.refresh, size: 18, color: tokens.textSecondary),
                onPressed: _loadSessions,
                tooltip: 'Refresh Sessions',
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 6, children: chips),
        ),
        const SizedBox(width: 12),
        searchBox,
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.refresh, size: 18, color: tokens.textSecondary),
          onPressed: _loadSessions,
          tooltip: 'Refresh Sessions',
        ),
      ],
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> s) {
    final tokens = IcareSurfaceTokens.of(context);
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

    final isDeletingThis = _deletingSessionIds.contains(sessionId);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isDeletingThis ? 0.45 : 1.0,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IcareCard(
              padding: const EdgeInsets.all(18),
              topAccentColor: status == 'submitted' ? tokens.infoDot : null,
              border: Border.all(
                color: isDeletingThis
                    ? tokens.dangerBorder
                    : (status == 'submitted' ? tokens.infoBorder : tokens.borderSubtle),
                width: status == 'submitted' ? 1.4 : 1.0,
              ),
              child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.brandPrimaryDark,
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
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                    ),
                    if (person.isNotEmpty || phone.isNotEmpty)
                      Text(
                        'Coordinator: $person ${phone.isNotEmpty ? "($phone)" : ""}',
                        style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IcareStatusBadge.fromStatus(status),
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
                        color: tokens.dangerBg,
                        border: Border.all(color: tokens.dangerBorder),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _deletingSessionIds.contains(sessionId)
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: tokens.dangerDot),
                            )
                          : Icon(Icons.delete_outline, color: tokens.dangerDot, size: 16),
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
                    color: tokens.surfaceSubtle,
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
                  color: tokens.surfaceSubtle,
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
              final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
              final timerBadge = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: isExpired ? tokens.dangerText : tokens.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    expiresAt != null
                        ? (isExpired
                            ? 'Expired on ${DateFormat('MMM dd, yyyy').format(expiresAt)}'
                            : 'Expires ${DateFormat('MMM dd, yyyy').format(expiresAt)}')
                        : 'Active',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isExpired ? tokens.dangerText : tokens.textMuted,
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
                      foregroundColor: tokens.textSecondary,
                      side: BorderSide(color: tokens.borderStrong),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: fullUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Onboarding link copied to clipboard!', style: TextStyle(color: Colors.white)),
                          backgroundColor: tokens.brandPrimaryDark,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 13),
                    label: const Text('Copy Link', style: TextStyle(fontSize: 11)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brandPrimaryDark,
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
                        backgroundColor: tokens.brandPrimaryDark,
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
                        foregroundColor: tokens.dangerText,
                        backgroundColor: tokens.dangerBg,
                        side: BorderSide(color: tokens.dangerBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: _deletingSessionIds.contains(sessionId) ? null : () => _handleDelete(s),
                      icon: _deletingSessionIds.contains(sessionId)
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: tokens.dangerDot),
                            )
                          : Icon(Icons.delete_outline, size: 14, color: tokens.dangerDot),
                      label: Text(
                        _deletingSessionIds.contains(sessionId) ? 'Deleting...' : 'Delete',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.dangerText),
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
  ),
    if (isDeletingThis)
      Positioned.fill(
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: tokens.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: tokens.dangerDot),
                ),
                const SizedBox(width: 10),
                Text(
                  'Deleting session...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: tokens.dangerText,
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
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          softWrap: true,
          style: TextStyle(fontSize: 10.5, color: tokens.textMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          softWrap: true,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: tokens.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }


  Widget _buildErrorNotice() {
    final tokens = IcareSurfaceTokens.of(context);
    return IcareCard(
      padding: const EdgeInsets.all(24),
      topAccentColor: tokens.dangerDot,
      child: Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 40, color: tokens.dangerDot),
            const SizedBox(height: 8),
            Text(
              'Unable to Load Onboarding Sessions',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tokens.textSecondary),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.brandPrimaryDark,
                foregroundColor: Colors.white,
              ),
              onPressed: _loadSessions,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final tokens = IcareSurfaceTokens.of(context);
    return IcareCard(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.domain_verification, size: 48, color: tokens.textMuted),
            const SizedBox(height: 12),
            Text('No Branch Onboarding Sessions Found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Click "Generate Branch Link" above to issue an invitation to a new branch.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: tokens.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
