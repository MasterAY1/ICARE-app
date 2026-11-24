import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_metric_card.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../../data/datasources/reports_api_service.dart';
import '../../data/models/report_models.dart';
import 'admin_signed_analytics_charts.dart';
import 'admin_signed_branch_card.dart';
import 'report_export_actions.dart';

/// Filter status options within Admin's AM-Signed Executive Reports Queue.
enum AdminSignedStatusFilter {
  all,
  readyToLock,
  archived,
}

/// Redesigned Executive Admin Reports & Export Workspace.
///
/// Strict governance invariant: displays, inspects, visualizes, locks, and exports
/// ONLY monthly branch reports that have been formally reviewed and signed by
/// an Area Manager (`AM_VERIFIED`, `AREA_SEALED`, or `ADMIN_LOCKED`).
class AdminReportsExportView extends ConsumerStatefulWidget {
  final int selectedYear;
  final int selectedMonth;
  final int activeTabIndex;
  final String? selectedBranchName;
  final String selectedProductName;
  final String selectedOfficerName;
  final ReportsMeta? cachedMeta;
  final Future<List<MonthlyWorkflowPendingBranchModel>>? adminSignedFuture;
  final bool isWorkflowSubmitting;
  final ValueChanged<int> onTabChanged;
  final void Function(int year, int month) onPeriodChanged;
  final ValueChanged<MonthlyWorkflowPendingBranchModel> onSelectBranch;
  final ValueChanged<MonthlyWorkflowPendingBranchModel> onInspectBranch;
  final ValueChanged<MonthlyWorkflowPendingBranchModel> onLockReport;
  final ValueChanged<String> onProductChanged;
  final ValueChanged<String> onOfficerChanged;
  final VoidCallback onRefresh;
  final Widget Function(MonthlyWorkflowPendingBranchModel branch)
      statementsInspectorBuilder;

  const AdminReportsExportView({
    super.key,
    required this.selectedYear,
    required this.selectedMonth,
    required this.activeTabIndex,
    required this.selectedBranchName,
    required this.selectedProductName,
    required this.selectedOfficerName,
    required this.cachedMeta,
    required this.adminSignedFuture,
    required this.isWorkflowSubmitting,
    required this.onTabChanged,
    required this.onPeriodChanged,
    required this.onSelectBranch,
    required this.onInspectBranch,
    required this.onLockReport,
    required this.onProductChanged,
    required this.onOfficerChanged,
    required this.onRefresh,
    required this.statementsInspectorBuilder,
  });

  @override
  ConsumerState<AdminReportsExportView> createState() =>
      _AdminReportsExportViewState();
}

class _AdminReportsExportViewState
    extends ConsumerState<AdminReportsExportView> {
  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const Set<String> _amSignedStatuses = {
    'AM_VERIFIED',
    'AREA_SEALED',
    'ADMIN_LOCKED',
  };

  final TextEditingController _searchCtrl = TextEditingController();
  final NumberFormat _ngnFmt = NumberFormat('#,##0.00');
  AdminSignedStatusFilter _statusFilter = AdminSignedStatusFilter.all;
  String? _busyExportKey;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatNgn(double value) => '₦${_ngnFmt.format(value)}';

  String _formatDate(String? rawIso) {
    if (rawIso == null || rawIso.trim().isEmpty) return 'Verified';
    try {
      final dt = DateTime.parse(rawIso).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return rawIso;
    }
  }

  List<MonthlyWorkflowPendingBranchModel> _filterStrictlySigned(
    List<MonthlyWorkflowPendingBranchModel> raw,
  ) {
    return raw
        .where((item) => _amSignedStatuses.contains(item.status))
        .toList();
  }

  MonthlyWorkflowPendingBranchModel? _resolveSelectedSubmission(
    List<MonthlyWorkflowPendingBranchModel> signedReports,
  ) {
    if (signedReports.isEmpty) return null;
    for (final s in signedReports) {
      if (s.branchName == widget.selectedBranchName) {
        return s;
      }
    }
    return signedReports.first;
  }

  void _stepMonth(int delta) {
    final DateTime next =
        DateTime(widget.selectedYear, widget.selectedMonth + delta, 1);
    widget.onPeriodChanged(next.year, next.month);
  }

  Future<void> _runExportAction({
    required String actionKey,
    required Future<List<int>> Function() fetchBytes,
    required String fileName,
    required String mimeType,
    required bool shareInsteadOfSave,
    String? shareTitle,
  }) async {
    if (_busyExportKey != null) return;
    setState(() => _busyExportKey = actionKey);
    try {
      final List<int> bytes = await fetchBytes();
      if (!mounted) return;
      if (shareInsteadOfSave) {
        await ReportExportActionHelper.shareBytes(
          context,
          bytes: bytes,
          fileName: fileName,
          mimeType: mimeType,
          subject: shareTitle ?? fileName,
        );
      } else {
        final String? saved = await ReportExportActionHelper.saveBytes(
          bytes: bytes,
          fileName: fileName,
          mimeType: mimeType,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Export ready: $fileName${saved != null ? ' ($saved)' : ''}.',
              ),
              backgroundColor: IcareSurfaceTokens.of(context).brandPrimaryDark,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export failed: ${AppErrorDetails.from(e).message}',
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyExportKey = null);
      }
    }
  }

  void _openPdfPreview(MonthlyWorkflowPendingBranchModel submission) {
    final api = ref.read(reportsApiServiceProvider);
    final String cleanBranch = submission.branchName.replaceAll(' ', '_');
    final String monthPad = widget.selectedMonth.toString().padLeft(2, '0');
    final String fileName =
        'AM_Signed_Executive_Statement_${cleanBranch}_${widget.selectedYear}_$monthPad.pdf';
    final String signer = (submission.amName?.trim().isNotEmpty ?? false)
        ? submission.amName!.trim()
        : 'Area Manager';

    ReportPdfPreviewSheet.show(
      context,
      title: '${submission.branchName} — Official Executive Statement',
      subtitle:
          '${_monthNames[widget.selectedMonth - 1]} ${widget.selectedYear}',
      signerSummary:
          'Reviewed & Signed by $signer (${_formatDate(submission.amEndorsedAt ?? submission.submittedAt)})',
      fileName: fileName,
      loadPdfBytes: () => api.downloadMonthlyParityPdf(
        branchName: submission.branchName,
        year: widget.selectedYear,
        month: widget.selectedMonth,
        officerName: widget.selectedOfficerName,
        productName: widget.selectedProductName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildExecutiveHeader(tokens),
        const SizedBox(height: 14),
        _buildPeriodToolbar(tokens),
        const SizedBox(height: 14),
        _buildWorkspaceTabs(tokens),
        const SizedBox(height: 16),
        FutureBuilder<List<MonthlyWorkflowPendingBranchModel>>(
          future: widget.adminSignedFuture,
          builder: (context, snapshot) {
            if (widget.adminSignedFuture == null ||
                snapshot.connectionState == ConnectionState.waiting) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IcareSkeletonLoader(height: 110),
                  SizedBox(height: 14),
                  IcareSkeletonLoader(height: 240),
                ],
              );
            }

            if (snapshot.hasError) {
              return _buildErrorBanner(tokens, snapshot.error!);
            }

            final List<MonthlyWorkflowPendingBranchModel> signedReports =
                _filterStrictlySigned(snapshot.data ?? const []);

            if (signedReports.isEmpty) {
              return _buildNoSignedReportsState(tokens);
            }

            final MonthlyWorkflowPendingBranchModel selectedSubmission =
                _resolveSelectedSubmission(signedReports)!;

            final Duration switchDuration = IcareFluidMotion.resolveDuration(
              context,
              IcareFluidMotion.tabDuration,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildExecutiveSummaryStrip(tokens, signedReports),
                const SizedBox(height: 16),
                PageTransitionSwitcher(
                  duration: switchDuration,
                  transitionBuilder: (
                    Widget child,
                    Animation<double> animation,
                    Animation<double> secondaryAnimation,
                  ) {
                    return FadeThroughTransition(
                      animation: animation,
                      secondaryAnimation: secondaryAnimation,
                      fillColor: Colors.transparent,
                      child: child,
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(widget.activeTabIndex),
                    child: _buildActiveTabBody(
                      tokens: tokens,
                      signedReports: signedReports,
                      selectedSubmission: selectedSubmission,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildExecutiveHeader(IcareSurfaceTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tokens.isDark
              ? [const Color(0xFF03382B), const Color(0xFF02261D)]
              : [const Color(0xFF064E3B), const Color(0xFF022C22)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 680;
          final Widget verifiedChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF6EE7B7).withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: Color(0xFF6EE7B7),
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'AM-SIGNED REPORTS ONLY',
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: Color(0xFFECFDF5),
                    ),
                  ),
                ),
              ],
            ),
          );

          const Widget headerText = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Executive Financial Reports & Export Vault',
                softWrap: true,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Displays exclusively branch monthly returns reviewed, signed, and endorsed by an Area Manager.',
                softWrap: true,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFA7F3D0),
                  height: 1.4,
                ),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerText,
                const SizedBox(height: 12),
                verifiedChip,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(child: headerText),
              const SizedBox(width: 16),
              verifiedChip,
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeriodToolbar(IcareSurfaceTokens tokens) {
    final int nowYear = DateTime.now().year;
    final int nowMonth = DateTime.now().month;
    final List<DateTime> lookbackPeriods = [
      for (final offset in [3, 2, 1, 0])
        DateTime(nowYear, nowMonth - offset, 1),
    ];

    return IcareCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        size: 20,
                        color: tokens.brandPrimary,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Previous Month',
                      onPressed: () => _stepMonth(-1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${_monthNames[widget.selectedMonth - 1]} ${widget.selectedYear}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: tokens.brandPrimary,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Next Month',
                      onPressed: () => _stepMonth(1),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final dt in lookbackPeriods) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            dt.month == nowMonth && dt.year == nowYear
                                ? '${_monthNames[dt.month - 1].substring(0, 3)} (Now)'
                                : _monthNames[dt.month - 1].substring(0, 3),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: widget.selectedMonth == dt.month &&
                                      widget.selectedYear == dt.year
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: widget.selectedMonth == dt.month &&
                                      widget.selectedYear == dt.year
                                  ? Colors.white
                                  : tokens.textSecondary,
                            ),
                          ),
                          selected: widget.selectedMonth == dt.month &&
                              widget.selectedYear == dt.year,
                          selectedColor: tokens.brandPrimaryDark,
                          backgroundColor: tokens.surfaceHover,
                          visualDensity: VisualDensity.compact,
                          onSelected: (selected) {
                            if (selected) {
                              widget.onPeriodChanged(dt.year, dt.month);
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: widget.onRefresh,
            icon: Icon(
              Icons.refresh_rounded,
              size: 16,
              color: tokens.brandPrimary,
            ),
            label: Text(
              'Refresh Signed Queue',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tokens.brandPrimary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: tokens.brandSoftBorder),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceTabs(IcareSurfaceTokens tokens) {
    const List<({String label, IconData icon})> items = [
      (label: 'AM-Signed Queue & Charts', icon: Icons.verified_outlined),
      (label: 'Audited Statements', icon: Icons.receipt_long_outlined),
      (
        label: 'Verified Export Vault',
        icon: Icons.download_for_offline_outlined
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List<Widget>.generate(items.length, (idx) {
          final item = items[idx];
          final bool isSelected = widget.activeTabIndex == idx;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                IcareFluidMotion.selectionHaptic(true);
                widget.onTabChanged(idx);
              },
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: IcareFluidMotion.resolveDuration(
                  context,
                  IcareFluidMotion.microDuration,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? tokens.brandPrimaryDark : tokens.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? tokens.brandPrimaryDark
                        : tokens.borderSubtle,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 16,
                      color: isSelected ? Colors.white : tokens.brandPrimary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildExecutiveSummaryStrip(
    IcareSurfaceTokens tokens,
    List<MonthlyWorkflowPendingBranchModel> signedReports,
  ) {
    final int totalSigned = signedReports.length;
    final int archivedCount =
        signedReports.where((r) => r.status == 'ADMIN_LOCKED').length;
    final int readyToLockCount = totalSigned - archivedCount;
    final double totalCollections = signedReports.fold(
      0.0,
      (sum, r) => sum + r.collections,
    );
    final double totalDisbursed = signedReports.fold(
      0.0,
      (sum, r) => sum + r.disbursedPrincipal,
    );
    final double totalVaultCash = signedReports.fold(
      0.0,
      (sum, r) => sum + r.vaultCash,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 680;
        final double cardW = isMobile
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: isMobile ? 10 : 12,
          runSpacing: isMobile ? 10 : 12,
          children: [
            SizedBox(
              width: cardW,
              child: IcareMetricCard(
                label: 'AM-Signed Branches',
                value: '$totalSigned Verified',
                delta:
                    '$readyToLockCount ready to lock • $archivedCount archived',
                isFullEmerald: true,
                icon: Icons.verified_user_outlined,
              ),
            ),
            SizedBox(
              width: cardW,
              child: IcareMetricCard(
                label: 'Verified Collections',
                value: _formatNgn(totalCollections),
                delta: 'Sum of AM-signed returns',
                topBorderColor: const Color(0xFF10B981),
                icon: Icons.payments_outlined,
              ),
            ),
            SizedBox(
              width: cardW,
              child: IcareMetricCard(
                label: 'Disbursed Principal',
                value: _formatNgn(totalDisbursed),
                delta: 'Period credit volume',
                topBorderColor: tokens.brandPrimary,
                icon: Icons.trending_up_rounded,
              ),
            ),
            SizedBox(
              width: cardW,
              child: IcareMetricCard(
                label: 'Verified Vault Cash',
                value: _formatNgn(totalVaultCash),
                delta: 'Branch physical reserves',
                topBorderColor: tokens.infoDot,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveTabBody({
    required IcareSurfaceTokens tokens,
    required List<MonthlyWorkflowPendingBranchModel> signedReports,
    required MonthlyWorkflowPendingBranchModel selectedSubmission,
  }) {
    if (widget.activeTabIndex == 1) {
      return _buildStatementsTab(
        tokens: tokens,
        signedReports: signedReports,
        selectedSubmission: selectedSubmission,
      );
    }
    if (widget.activeTabIndex == 2) {
      return _buildExportsTab(
        tokens: tokens,
        signedReports: signedReports,
        selectedSubmission: selectedSubmission,
      );
    }
    return _buildSignedQueueTab(
      tokens: tokens,
      signedReports: signedReports,
      selectedSubmission: selectedSubmission,
    );
  }

  Widget _buildSignedQueueTab({
    required IcareSurfaceTokens tokens,
    required List<MonthlyWorkflowPendingBranchModel> signedReports,
    required MonthlyWorkflowPendingBranchModel selectedSubmission,
  }) {
    final String query = _searchCtrl.text.trim().toLowerCase();
    final int allCount = signedReports.length;
    final int readyCount =
        signedReports.where((r) => r.status != 'ADMIN_LOCKED').length;
    final int archivedCount =
        signedReports.where((r) => r.status == 'ADMIN_LOCKED').length;

    final List<MonthlyWorkflowPendingBranchModel> filtered =
        signedReports.where((item) {
      if (_statusFilter == AdminSignedStatusFilter.readyToLock &&
          item.status == 'ADMIN_LOCKED') {
        return false;
      }
      if (_statusFilter == AdminSignedStatusFilter.archived &&
          item.status != 'ADMIN_LOCKED') {
        return false;
      }
      if (query.isEmpty) return true;
      final hay = [
        item.branchName,
        item.areaName ?? '',
        item.amName ?? '',
        item.bmName ?? '',
        item.amNotes ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSignedAnalyticsCharts(signedReports: signedReports),
        const SizedBox(height: 16),

        // Queue Filter & Search Toolbar
        IcareCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Signed & Reviewed Branch Submissions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _FilterPill(
                        label: 'All Signed ($allCount)',
                        selected: _statusFilter == AdminSignedStatusFilter.all,
                        tokens: tokens,
                        onTap: () => setState(
                          () => _statusFilter = AdminSignedStatusFilter.all,
                        ),
                      ),
                      _FilterPill(
                        label: 'Ready to Lock ($readyCount)',
                        selected: _statusFilter ==
                            AdminSignedStatusFilter.readyToLock,
                        tokens: tokens,
                        onTap: () => setState(
                          () => _statusFilter =
                              AdminSignedStatusFilter.readyToLock,
                        ),
                      ),
                      _FilterPill(
                        label: 'Archived ($archivedCount)',
                        selected:
                            _statusFilter == AdminSignedStatusFilter.archived,
                        tokens: tokens,
                        onTap: () => setState(
                          () =>
                              _statusFilter = AdminSignedStatusFilter.archived,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  hintText:
                      'Filter signed branches by name, area, or AM reviewer...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: tokens.textMuted,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: tokens.textMuted,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          IcareCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No signed branch submissions match your current search or filter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: tokens.textMuted),
                ),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final bool twoCols = constraints.maxWidth >= 980;
              final double cardWidth = twoCols
                  ? (constraints.maxWidth - 14) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: filtered.map((sub) {
                  return SizedBox(
                    width: cardWidth,
                    child: AdminSignedBranchCard(
                      submission: sub,
                      isSelected:
                          sub.branchName == selectedSubmission.branchName,
                      isBusyLocking: widget.isWorkflowSubmitting,
                      onInspectStatements: () => widget.onInspectBranch(sub),
                      onPreviewPdf: () => _openPdfPreview(sub),
                      onShareExcel: () {
                        final cleanBranch = sub.branchName.replaceAll(' ', '_');
                        final monthPad =
                            widget.selectedMonth.toString().padLeft(2, '0');
                        _runExportAction(
                          actionKey: 'share_excel_${sub.branchId}',
                          fetchBytes: () => ref
                              .read(reportsApiServiceProvider)
                              .downloadMonthlyParityExcel(
                                branchName: sub.branchName,
                                year: widget.selectedYear,
                                month: widget.selectedMonth,
                                officerName: widget.selectedOfficerName,
                                productName: widget.selectedProductName,
                              ),
                          fileName:
                              'AM_Signed_Workbook_${cleanBranch}_${widget.selectedYear}_$monthPad.xlsx',
                          mimeType:
                              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                          shareInsteadOfSave: true,
                          shareTitle:
                              '${sub.branchName} (${_monthNames[widget.selectedMonth - 1]} ${widget.selectedYear})',
                        );
                      },
                      onLockArchive: sub.status == 'ADMIN_LOCKED'
                          ? null
                          : () => widget.onLockReport(sub),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildStatementsTab({
    required IcareSurfaceTokens tokens,
    required List<MonthlyWorkflowPendingBranchModel> signedReports,
    required MonthlyWorkflowPendingBranchModel selectedSubmission,
  }) {
    final List<String> products = widget.cachedMeta != null
        ? ['All Products', ...widget.cachedMeta!.products]
        : ['All Products'];
    final List<String> officers = widget.cachedMeta != null
        ? [
            'All Officers',
            ...widget.cachedMeta!.officers.map((o) => o.fullName)
          ]
        : ['All Officers'];

    final bool isLocked = selectedSubmission.status == 'ADMIN_LOCKED';
    final String signerName =
        (selectedSubmission.amName?.trim().isNotEmpty ?? false)
            ? selectedSubmission.amName!.trim()
            : 'Area Manager';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Signed Branch Selector + Product/Officer Controls
        IcareCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SELECT AM-SIGNED BRANCH RETURN',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: signedReports.map((sub) {
                    final bool active =
                        sub.branchName == selectedSubmission.branchName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          sub.status == 'ADMIN_LOCKED'
                              ? Icons.lock_outline_rounded
                              : Icons.verified_outlined,
                          size: 14,
                          color: active ? Colors.white : tokens.brandPrimary,
                        ),
                        label: Text(
                          sub.branchName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : tokens.textPrimary,
                          ),
                        ),
                        selected: active,
                        selectedColor: tokens.brandPrimaryDark,
                        backgroundColor: tokens.surfaceSubtle,
                        onSelected: (picked) {
                          if (picked && !active) {
                            widget.onSelectBranch(sub);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _CompactDropdownChip(
                    tokens: tokens,
                    value: officers.contains(widget.selectedOfficerName)
                        ? widget.selectedOfficerName
                        : officers.first,
                    items: officers,
                    onChanged: widget.onOfficerChanged,
                  ),
                  _CompactDropdownChip(
                    tokens: tokens,
                    value: products.contains(widget.selectedProductName)
                        ? widget.selectedProductName
                        : products.first,
                    items: products,
                    onChanged: widget.onProductChanged,
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openPdfPreview(selectedSubmission),
                    icon: Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 15,
                      color: tokens.dangerText,
                    ),
                    label: Text(
                      'Preview & Print PDF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tokens.dangerText,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: tokens.dangerBorder),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  if (!isLocked)
                    ElevatedButton.icon(
                      onPressed: widget.isWorkflowSubmitting
                          ? null
                          : () => widget.onLockReport(selectedSubmission),
                      icon: const Icon(Icons.lock_outline_rounded, size: 15),
                      label: Text(
                        widget.isWorkflowSubmitting
                            ? 'Locking...'
                            : 'Lock & Archive',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // AM Attestation Callout
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isLocked ? tokens.surfaceSubtle : tokens.successBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isLocked ? tokens.borderStrong : tokens.successBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isLocked ? Icons.lock_rounded : Icons.verified_rounded,
                size: 20,
                color: isLocked ? tokens.textPrimary : tokens.successDot,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLocked
                          ? '${selectedSubmission.branchName} — Permanently Archived by ${selectedSubmission.adminName ?? 'Admin'}'
                          : '${selectedSubmission.branchName} — Signed & Reviewed by $signerName',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Prepared by ${selectedSubmission.bmName ?? 'Branch Manager'} • Endorsed ${_formatDate(selectedSubmission.amEndorsedAt ?? selectedSubmission.submittedAt)}${(selectedSubmission.amNotes?.trim().isNotEmpty ?? false) ? ' • Note: ${selectedSubmission.amNotes!.trim()}' : ''}',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Audited 7-Statement Workbench (reuses verified ICARE statement renderers)
        widget.statementsInspectorBuilder(selectedSubmission),
      ],
    );
  }

  Widget _buildExportsTab({
    required IcareSurfaceTokens tokens,
    required List<MonthlyWorkflowPendingBranchModel> signedReports,
    required MonthlyWorkflowPendingBranchModel selectedSubmission,
  }) {
    final api = ref.read(reportsApiServiceProvider);
    final String monthPad = widget.selectedMonth.toString().padLeft(2, '0');
    final String periodLabel =
        '${_monthNames[widget.selectedMonth - 1]} ${widget.selectedYear}';
    final String cleanBranch =
        selectedSubmission.branchName.replaceAll(' ', '_');
    final String signerName =
        (selectedSubmission.amName?.trim().isNotEmpty ?? false)
            ? selectedSubmission.amName!.trim()
            : 'Area Manager';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card 1: Verified Multi-Branch Consolidated Package
        IcareCard(
          topAccentColor: tokens.brandPrimary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: tokens.successBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.successBorder),
                    ),
                    child: Icon(
                      Icons.hub_outlined,
                      size: 20,
                      color: tokens.successText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AM-Signed Consolidated Enterprise Package',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Aggregates ONLY the ${signedReports.length} branch report${signedReports.length == 1 ? '' : 's'} reviewed and signed by an Area Manager for $periodLabel. Draft or unreviewed branches are excluded on the server.',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ExportActionBtn(
                    actionKey: 'cons_excel_save',
                    busyKey: _busyExportKey,
                    icon: Icons.table_view_outlined,
                    label: 'Download Master Workbook (.xlsx)',
                    isPrimary: true,
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'cons_excel_save',
                      fetchBytes: () => api.downloadExcel(
                        year: widget.selectedYear,
                        month: widget.selectedMonth,
                        productName: widget.selectedProductName,
                        officerName: widget.selectedOfficerName,
                      ),
                      fileName:
                          'ICARE_AM_Signed_Consolidated_${widget.selectedYear}_$monthPad.xlsx',
                      mimeType:
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                      shareInsteadOfSave: false,
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'cons_excel_share',
                    busyKey: _busyExportKey,
                    icon: Icons.ios_share_outlined,
                    label: 'Share Workbook',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'cons_excel_share',
                      fetchBytes: () => api.downloadExcel(
                        year: widget.selectedYear,
                        month: widget.selectedMonth,
                        productName: widget.selectedProductName,
                        officerName: widget.selectedOfficerName,
                      ),
                      fileName:
                          'ICARE_AM_Signed_Consolidated_${widget.selectedYear}_$monthPad.xlsx',
                      mimeType:
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                      shareInsteadOfSave: true,
                      shareTitle:
                          'ICARE Consolidated Signed Report — $periodLabel',
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'cons_area_csv',
                    busyKey: _busyExportKey,
                    icon: Icons.compare_arrows_rounded,
                    label: 'Signed Branch Comparison (.csv)',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'cons_area_csv',
                      fetchBytes: () => api.downloadCsv(
                        reportType: 'area_comparison',
                        year: widget.selectedYear,
                        month: widget.selectedMonth,
                        productName: widget.selectedProductName,
                        officerName: widget.selectedOfficerName,
                      ),
                      fileName:
                          'AM_Signed_Branch_Comparison_${widget.selectedYear}_$monthPad.csv',
                      mimeType: 'text/csv',
                      shareInsteadOfSave: false,
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'cons_loans_csv',
                    busyKey: _busyExportKey,
                    icon: Icons.file_download_outlined,
                    label: 'Signed Loans Register (.csv)',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'cons_loans_csv',
                      fetchBytes: () => api.downloadCsv(
                        reportType: 'loans',
                        year: widget.selectedYear,
                        month: widget.selectedMonth,
                        productName: widget.selectedProductName,
                        officerName: widget.selectedOfficerName,
                      ),
                      fileName:
                          'AM_Signed_Loans_${widget.selectedYear}_$monthPad.csv',
                      mimeType: 'text/csv',
                      shareInsteadOfSave: false,
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'cons_rep_csv',
                    busyKey: _busyExportKey,
                    icon: Icons.file_download_outlined,
                    label: 'Signed Repayments (.csv)',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'cons_rep_csv',
                      fetchBytes: () => api.downloadCsv(
                        reportType: 'repayments',
                        year: widget.selectedYear,
                        month: widget.selectedMonth,
                        productName: widget.selectedProductName,
                        officerName: widget.selectedOfficerName,
                      ),
                      fileName:
                          'AM_Signed_Repayments_${widget.selectedYear}_$monthPad.csv',
                      mimeType: 'text/csv',
                      shareInsteadOfSave: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card 2: Single AM-Signed Branch Statutory Extraction & Preview
        IcareCard(
          topAccentColor: tokens.infoDot,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: tokens.infoBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.infoBorder),
                    ),
                    child: Icon(
                      Icons.verified_outlined,
                      size: 20,
                      color: tokens.infoText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Single AM-Signed Branch Audit Extraction',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Preview, print, share, or download statutory financial packs for a selected AM-endorsed branch.',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.borderStrong),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSubmission.branchName,
                        isDense: true,
                        dropdownColor: tokens.surfaceElevated,
                        items: signedReports
                            .map(
                              (s) => DropdownMenuItem<String>(
                                value: s.branchName,
                                child: Text(
                                  s.branchName,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          final picked = signedReports.firstWhere(
                            (s) => s.branchName == val,
                            orElse: () => selectedSubmission,
                          );
                          widget.onSelectBranch(picked);
                        },
                      ),
                    ),
                  ),
                  IcareStatusBadge(
                    label: 'Signed by $signerName',
                    variant: IcareBadgeVariant.success,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ExportActionBtn(
                    actionKey: 'br_pdf_preview',
                    busyKey: _busyExportKey,
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'Preview & Print PDF',
                    isPrimary: true,
                    tokens: tokens,
                    onPressed: () => _openPdfPreview(selectedSubmission),
                  ),
                  _ExportActionBtn(
                    actionKey: 'br_pdf_share',
                    busyKey: _busyExportKey,
                    icon: Icons.share_outlined,
                    label: 'Share PDF',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'br_pdf_share',
                      fetchBytes: () => api.downloadMonthlyParityPdf(
                        branchName: selectedSubmission.branchName,
                        year: widget.selectedYear,
                        month: widget.selectedMonth,
                        officerName: widget.selectedOfficerName,
                        productName: widget.selectedProductName,
                      ),
                      fileName:
                          'Official_Statement_${cleanBranch}_${widget.selectedYear}_$monthPad.pdf',
                      mimeType: 'application/pdf',
                      shareInsteadOfSave: true,
                      shareTitle:
                          '${selectedSubmission.branchName} Statement — $periodLabel',
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'br_pdf_save',
                    busyKey: _busyExportKey,
                    icon: Icons.download_outlined,
                    label: 'Save PDF',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'br_pdf_save',
                      fetchBytes: () => api.downloadMonthlyParityPdf(
                        branchName: selectedSubmission.branchName,
                        year: widget.selectedYear,
                        month: widget.selectedMonth,
                        officerName: widget.selectedOfficerName,
                        productName: widget.selectedProductName,
                      ),
                      fileName:
                          'Official_Statement_${cleanBranch}_${widget.selectedYear}_$monthPad.pdf',
                      mimeType: 'application/pdf',
                      shareInsteadOfSave: false,
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'br_xlsx_save',
                    busyKey: _busyExportKey,
                    icon: Icons.table_chart_outlined,
                    label: 'Branch Excel (.xlsx)',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'br_xlsx_save',
                      fetchBytes: () => api.downloadMonthlyParityExcel(
                        branchName: selectedSubmission.branchName,
                        year: widget.selectedYear,
                        month: widget.selectedMonth,
                        officerName: widget.selectedOfficerName,
                        productName: widget.selectedProductName,
                      ),
                      fileName:
                          'Branch_Workbook_${cleanBranch}_${widget.selectedYear}_$monthPad.xlsx',
                      mimeType:
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                      shareInsteadOfSave: false,
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'br_xlsx_share',
                    busyKey: _busyExportKey,
                    icon: Icons.ios_share_outlined,
                    label: 'Share Excel',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'br_xlsx_share',
                      fetchBytes: () => api.downloadMonthlyParityExcel(
                        branchName: selectedSubmission.branchName,
                        year: widget.selectedYear,
                        month: widget.selectedMonth,
                        officerName: widget.selectedOfficerName,
                        productName: widget.selectedProductName,
                      ),
                      fileName:
                          'Branch_Workbook_${cleanBranch}_${widget.selectedYear}_$monthPad.xlsx',
                      mimeType:
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                      shareInsteadOfSave: true,
                      shareTitle:
                          '${selectedSubmission.branchName} Workbook — $periodLabel',
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'br_co_csv',
                    busyKey: _busyExportKey,
                    icon: Icons.people_alt_outlined,
                    label: 'Officer Summary (.csv)',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'br_co_csv',
                      fetchBytes: () => api.downloadMonthlyParityCsv(
                        branchName: selectedSubmission.branchName,
                        year: widget.selectedYear,
                        month: widget.selectedMonth,
                        officerName: widget.selectedOfficerName,
                        productName: widget.selectedProductName,
                      ),
                      fileName:
                          'Officer_Summary_${cleanBranch}_${widget.selectedYear}_$monthPad.csv',
                      mimeType: 'text/csv',
                      shareInsteadOfSave: false,
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'br_loans_csv',
                    busyKey: _busyExportKey,
                    icon: Icons.file_download_outlined,
                    label: 'Branch Loans (.csv)',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'br_loans_csv',
                      fetchBytes: () => api.downloadCsv(
                        reportType: 'loans',
                        branchName: selectedSubmission.branchName,
                        year: widget.selectedYear,
                        month: widget.selectedMonth,
                      ),
                      fileName:
                          '${cleanBranch}_Loans_${widget.selectedYear}_$monthPad.csv',
                      mimeType: 'text/csv',
                      shareInsteadOfSave: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoSignedReportsState(IcareSurfaceTokens tokens) {
    final String period =
        '${_monthNames[widget.selectedMonth - 1]} ${widget.selectedYear}';
    return IcareCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tokens.brandSoftBg,
              shape: BoxShape.circle,
              border: Border.all(color: tokens.brandSoftBorder),
            ),
            child: Icon(
              Icons.pending_actions_rounded,
              size: 26,
              color: tokens.brandPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Area Manager-Signed Reports Ready for $period',
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'To protect audit integrity, Executive Admin views and exports only branch reports that have been submitted by the Branch Manager and formally reviewed and signed by the Area Manager.',
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                fontSize: 12.5,
                color: tokens.textMuted,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _stepMonth(-1),
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 16,
                  color: tokens.brandPrimary,
                ),
                label: Text(
                  'Check Previous Month',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.brandPrimary,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Refresh Status',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.brandPrimaryDark,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(IcareSurfaceTokens tokens, Object error) {
    final details = AppErrorDetails.from(error);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.dangerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.dangerBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: tokens.dangerDot, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.dangerText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details.message,
                  style: TextStyle(fontSize: 12, color: tokens.dangerText),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: widget.onRefresh,
            child: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final IcareSurfaceTokens tokens;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? Colors.white : tokens.textSecondary,
        ),
      ),
      selected: selected,
      selectedColor: tokens.brandPrimaryDark,
      backgroundColor: tokens.surfaceHover,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onTap(),
    );
  }
}

class _CompactDropdownChip extends StatelessWidget {
  final IcareSurfaceTokens tokens;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _CompactDropdownChip({
    required this.tokens,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: tokens.surfaceElevated,
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _ExportActionBtn extends StatelessWidget {
  final String actionKey;
  final String? busyKey;
  final IconData icon;
  final String label;
  final bool isPrimary;
  final IcareSurfaceTokens tokens;
  final VoidCallback onPressed;

  const _ExportActionBtn({
    required this.actionKey,
    required this.busyKey,
    required this.icon,
    required this.label,
    this.isPrimary = false,
    required this.tokens,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isBusy = busyKey == actionKey;
    final bool anyBusy = busyKey != null;

    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: anyBusy ? null : onPressed,
        icon: isBusy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 15),
        label: Text(
          isBusy ? 'Preparing...' : label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.brandPrimaryDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: anyBusy ? null : onPressed,
      icon: isBusy
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tokens.brandPrimary,
              ),
            )
          : Icon(icon, size: 15, color: tokens.brandPrimary),
      label: Text(
        isBusy ? 'Preparing...' : label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: tokens.textPrimary,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: tokens.borderStrong),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
