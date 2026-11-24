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
import 'bm_branch_analytics_charts.dart';
import 'report_export_actions.dart';

/// Redesigned Branch Manager (Tier-1) Reports & Export Workspace.
///
/// Strictly scoped to a single branch (`branchName`), combining interactive
/// branch analytics, 3-tier month-end certification tracking, audited
/// 7-statement inspection, and in-app PDF preview / native share / downloads.
class BmReportsExportView extends ConsumerStatefulWidget {
  final String branchName;
  final int selectedYear;
  final int selectedMonth;
  final int activeTabIndex;
  final String selectedProductName;
  final String selectedOfficerName;
  final String dateMode;
  final DateTime asOfDate;
  final DateTime startDate;
  final DateTime endDate;
  final ReportsMeta? cachedMeta;
  final Future<MonthlyParityData>? parityFuture;
  final Future<MonthlyWorkflowStatusModel>? workflowStatusFuture;
  final bool isWorkflowSubmitting;
  final ValueChanged<int> onTabChanged;
  final void Function(int year, int month) onPeriodChanged;
  final ValueChanged<String> onProductChanged;
  final ValueChanged<String> onOfficerChanged;
  final void Function({
    String? mode,
    DateTime? asOf,
    DateTime? start,
    DateTime? end,
  }) onDateFilterChanged;
  final ValueChanged<MonthlyWorkflowStatusModel> onSubmitReport;
  final VoidCallback onRefresh;
  final Widget Function() statementsInspectorBuilder;

  const BmReportsExportView({
    super.key,
    required this.branchName,
    required this.selectedYear,
    required this.selectedMonth,
    required this.activeTabIndex,
    required this.selectedProductName,
    required this.selectedOfficerName,
    required this.dateMode,
    required this.asOfDate,
    required this.startDate,
    required this.endDate,
    required this.cachedMeta,
    required this.parityFuture,
    required this.workflowStatusFuture,
    required this.isWorkflowSubmitting,
    required this.onTabChanged,
    required this.onPeriodChanged,
    required this.onProductChanged,
    required this.onOfficerChanged,
    required this.onDateFilterChanged,
    required this.onSubmitReport,
    required this.onRefresh,
    required this.statementsInspectorBuilder,
  });

  @override
  ConsumerState<BmReportsExportView> createState() =>
      _BmReportsExportViewState();
}

class _BmReportsExportViewState extends ConsumerState<BmReportsExportView> {
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

  final NumberFormat _ngnFmt = NumberFormat('#,##0.00');
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  bool _showMoreMetrics = false;
  bool _showAnalyticsCharts = true;
  String? _busyExportKey;

  String _formatNgn(double value) => '₦${_ngnFmt.format(value)}';

  String _formatDateTime(String? rawIso) {
    if (rawIso == null || rawIso.trim().isEmpty) return '-';
    try {
      final dt = DateTime.parse(rawIso).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return rawIso;
    }
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

  void _openPdfPreview() {
    final api = ref.read(reportsApiServiceProvider);
    final String cleanBranch = widget.branchName.replaceAll(' ', '_');
    final String monthPad = widget.selectedMonth.toString().padLeft(2, '0');
    final String periodLabel =
        '${_monthNames[widget.selectedMonth - 1]} ${widget.selectedYear}';
    final String fileName =
        'Branch_Executive_Statement_${cleanBranch}_${widget.selectedYear}_$monthPad.pdf';

    ReportPdfPreviewSheet.show(
      context,
      title: '${widget.branchName} — Official Executive Statement',
      subtitle: periodLabel,
      signerSummary: 'Branch Operational Return (${widget.branchName})',
      fileName: fileName,
      loadPdfBytes: () => api.downloadMonthlyParityPdf(
        branchName: widget.branchName,
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
    final Duration switchDuration = IcareFluidMotion.resolveDuration(
      context,
      IcareFluidMotion.tabDuration,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBranchHeader(tokens),
        const SizedBox(height: 14),
        _buildPeriodToolbar(tokens),
        const SizedBox(height: 14),
        _buildWorkspaceTabs(tokens),
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
            child: widget.activeTabIndex == 1
                ? _buildExportsTab(tokens)
                : _buildStatementsTab(tokens),
          ),
        ),
      ],
    );
  }

  Widget _buildBranchHeader(IcareSurfaceTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tokens.isDark
              ? const [Color(0xFF0B1F33), Color(0xFF042821)]
              : const [Color(0xFF0F2942), Color(0xFF064E3B)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF34D399).withValues(alpha: 0.30),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 680;
          final Widget scopeChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF93C5FD).withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 16,
                  color: Color(0xFF93C5FD),
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'SINGLE BRANCH • TIER-1 CERTIFICATION',
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: Color(0xFFF0FDF4),
                    ),
                  ),
                ),
              ],
            ),
          );

          final Widget headerText = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Branch Operational Reports — ${widget.branchName}',
                softWrap: true,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Single-branch double-entry statements, treasury reconciliation, and month-end certification.',
                softWrap: true,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFBFDBFE),
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
                scopeChip,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: headerText),
              const SizedBox(width: 16),
              scopeChip,
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
              'Refresh Statements',
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
      (
        label: 'Monthly Executive Statements',
        icon: Icons.receipt_long_outlined
      ),
      (label: 'Data Exports & Downloads', icon: Icons.download_outlined),
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
                  color: isSelected ? const Color(0xFF1D4ED8) : tokens.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1D4ED8)
                        : tokens.borderSubtle,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 16,
                      color:
                          isSelected ? Colors.white : const Color(0xFF1D4ED8),
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

  Widget _buildStatementsTab(IcareSurfaceTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWorkflowProgressCard(tokens),
        const SizedBox(height: 14),
        _buildFilterAndQuickActionsCard(tokens),
        const SizedBox(height: 14),
        _buildBranchKpisAndCharts(tokens),
        const SizedBox(height: 16),
        widget.statementsInspectorBuilder(),
      ],
    );
  }

  Widget _buildWorkflowProgressCard(IcareSurfaceTokens tokens) {
    if (widget.workflowStatusFuture == null) {
      return const IcareSkeletonLoader(height: 110);
    }

    return FutureBuilder<MonthlyWorkflowStatusModel>(
      future: widget.workflowStatusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IcareSkeletonLoader(height: 110);
        }

        if (snapshot.hasError) {
          return _buildErrorBanner(tokens, snapshot.error!);
        }

        final MonthlyWorkflowStatusModel? st = snapshot.data;
        if (st == null) return const SizedBox.shrink();

        final String status = st.status;
        late final Color accentColor;
        late final Color bgTint;
        late final Color borderTint;
        late final IcareBadgeVariant badgeVariant;
        late final String pillLabel;
        late final IconData icon;
        late final String title;
        late final String description;
        late final int tierCompletedCount;
        Widget? actionWidget;

        switch (status) {
          case 'BM_SUBMITTED':
            accentColor = tokens.warningDot;
            bgTint = tokens.warningBg;
            borderTint = tokens.warningBorder;
            badgeVariant = IcareBadgeVariant.warning;
            pillLabel = 'SUBMITTED FOR AM SIGN-OFF';
            icon = Icons.pending_actions_rounded;
            title = 'Submitted for Area Manager Endorsement';
            description =
                'Certified by ${st.bmName ?? "Branch Manager"} on ${_formatDateTime(st.bmSubmittedAt)}. Books are locked pending Area Manager review.';
            tierCompletedCount = 1;
            actionWidget = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.warningBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.warningBorder),
              ),
              child: Text(
                'Awaiting Supervisory Endorsement',
                softWrap: true,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.warningText,
                ),
              ),
            );
            break;

          case 'RETURNED_FOR_CORRECTION':
            accentColor = tokens.dangerDot;
            bgTint = tokens.dangerBg;
            borderTint = tokens.dangerBorder;
            badgeVariant = IcareBadgeVariant.danger;
            pillLabel = 'RETURNED FOR CORRECTION';
            icon = Icons.assignment_return_outlined;
            title = 'Returned with Supervisory Queries';
            description =
                'Area Manager ${st.amName != null ? "(${st.amName}) " : ""}requested adjustments before sign-off.';
            tierCompletedCount = 0;
            actionWidget = ElevatedButton.icon(
              onPressed: widget.isWorkflowSubmitting
                  ? null
                  : () => widget.onSubmitReport(st),
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: Text(
                widget.isWorkflowSubmitting
                    ? 'Submitting...'
                    : 'Re-verify & Resubmit',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.brandPrimaryDark,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            );
            break;

          case 'AM_VERIFIED':
            accentColor = tokens.successDot;
            bgTint = tokens.successBg;
            borderTint = tokens.successBorder;
            badgeVariant = IcareBadgeVariant.success;
            pillLabel = 'ENDORSED BY AREA MANAGER';
            icon = Icons.verified_rounded;
            title = 'Supervisory Sign-Off Granted';
            description =
                'Endorsed by ${st.amName ?? "Area Manager"} on ${_formatDateTime(st.amEndorsedAt)}. Awaiting regional seal and archival lock.';
            tierCompletedCount = 2;
            actionWidget = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.successBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.successBorder),
              ),
              child: Text(
                'Endorsed • Awaiting Regional Seal',
                softWrap: true,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.successText,
                ),
              ),
            );
            break;

          case 'AREA_SEALED':
            accentColor = tokens.infoDot;
            bgTint = tokens.infoBg;
            borderTint = tokens.infoBorder;
            badgeVariant = IcareBadgeVariant.info;
            pillLabel = 'REGIONAL PACKAGE SEALED';
            icon = Icons.folder_special_rounded;
            title = 'Regional Month-End Package Sealed';
            description =
                'Sealed by Area Manager. Forwarded to Executive Admin for permanent archival lock.';
            tierCompletedCount = 2;
            actionWidget = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.infoBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.infoBorder),
              ),
              child: Text(
                'Sealed • Awaiting Admin Archival',
                softWrap: true,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.infoText,
                ),
              ),
            );
            break;

          case 'ADMIN_LOCKED':
            accentColor = tokens.textPrimary;
            bgTint = tokens.surfaceSubtle;
            borderTint = tokens.borderStrong;
            badgeVariant = IcareBadgeVariant.neutral;
            pillLabel = 'LOCKED & ARCHIVED';
            icon = Icons.lock_rounded;
            title = 'Permanent Institutional Record';
            description =
                'Permanently archived by ${st.adminName ?? "Administrator"} on ${_formatDateTime(st.adminLockedAt)}. Books are permanently closed.';
            tierCompletedCount = 3;
            actionWidget = const IcareStatusBadge(
              label: 'Permanent Audit Record',
              variant: IcareBadgeVariant.neutral,
            );
            break;

          default:
            accentColor = const Color(0xFF1D4ED8);
            bgTint = tokens.surfaceSubtle;
            borderTint = tokens.borderSubtle;
            badgeVariant = IcareBadgeVariant.info;
            pillLabel = 'DRAFT — BOOKS OPEN';
            icon = Icons.edit_note_rounded;
            title = 'Month-End Statements in Preparation';
            description =
                'Complete treasury reconciliation and review all 7 statements, then certify and submit to your Area Manager.';
            tierCompletedCount = 0;
            actionWidget = ElevatedButton.icon(
              onPressed: widget.isWorkflowSubmitting
                  ? null
                  : () => widget.onSubmitReport(st),
              icon: const Icon(Icons.assignment_turned_in_outlined, size: 15),
              label: Text(
                widget.isWorkflowSubmitting
                    ? 'Submitting...'
                    : 'Verify & Submit to Area Manager',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.brandPrimaryDark,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            );
            break;
        }

        return IcareCard(
          topAccentColor: accentColor,
          backgroundColor: bgTint,
          border: Border.all(color: borderTint),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 3-Tier Progress Stepper
              _ThreeTierProgressStrip(
                completedTiers: tierCompletedCount,
                isReturned: status == 'RETURNED_FOR_CORRECTION',
                tokens: tokens,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isCompact = constraints.maxWidth < 840;
                  final Widget detailsBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: tokens.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderTint),
                            ),
                            child: Icon(icon, size: 18, color: accentColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  softWrap: true,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: IcareStatusBadge(
                                    label: pillLabel,
                                    variant: badgeVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      if (st.amQueryNotes != null &&
                          st.amQueryNotes!.trim().isNotEmpty &&
                          status == 'RETURNED_FOR_CORRECTION') ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: tokens.dangerBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.help_outline_rounded,
                                size: 16,
                                color: tokens.dangerDot,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Query: ${st.amQueryNotes!.trim()}',
                                  softWrap: true,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.dangerText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        detailsBlock,
                        if (actionWidget != null) ...[
                          const SizedBox(height: 12),
                          actionWidget,
                        ],
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: detailsBlock),
                      if (actionWidget != null) ...[
                        const SizedBox(width: 16),
                        actionWidget,
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterAndQuickActionsCard(IcareSurfaceTokens tokens) {
    final api = ref.read(reportsApiServiceProvider);
    final List<String> products = widget.cachedMeta != null
        ? ['All Products', ...widget.cachedMeta!.products]
        : ['All Products'];
    final List<String> officers = widget.cachedMeta != null
        ? [
            'All Officers',
            ...widget.cachedMeta!.officers.map((o) => o.fullName),
          ]
        : ['All Officers'];
    final String monthPad = widget.selectedMonth.toString().padLeft(2, '0');
    final String cleanBranch = widget.branchName.replaceAll(' ', '_');
    final String periodLabel =
        '${_monthNames[widget.selectedMonth - 1]} ${widget.selectedYear}';

    return IcareCard(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 8,
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
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _openPdfPreview,
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
              _ExportActionBtn(
                actionKey: 'bm_quick_share_xlsx',
                busyKey: _busyExportKey,
                icon: Icons.ios_share_outlined,
                label: 'Share Workbook',
                tokens: tokens,
                onPressed: () => _runExportAction(
                  actionKey: 'bm_quick_share_xlsx',
                  fetchBytes: () => api.downloadMonthlyParityExcel(
                    branchName: widget.branchName,
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
                  shareTitle: '${widget.branchName} Workbook — $periodLabel',
                ),
              ),
              _ExportActionBtn(
                actionKey: 'bm_quick_save_xlsx',
                busyKey: _busyExportKey,
                icon: Icons.table_view_outlined,
                label: 'Save Excel',
                tokens: tokens,
                onPressed: () => _runExportAction(
                  actionKey: 'bm_quick_save_xlsx',
                  fetchBytes: () => api.downloadMonthlyParityExcel(
                    branchName: widget.branchName,
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBranchKpisAndCharts(IcareSurfaceTokens tokens) {
    if (widget.parityFuture == null) {
      return const IcareTableSkeleton(rowCount: 2, hasFilterBar: false);
    }

    return FutureBuilder<MonthlyParityData>(
      future: widget.parityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IcareSkeletonLoader(height: 100),
              SizedBox(height: 12),
              IcareSkeletonLoader(height: 210),
            ],
          );
        }

        if (snapshot.hasError) {
          return _buildErrorBanner(tokens, snapshot.error!);
        }

        final MonthlyParityData? data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final cards = data.summaryCards;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Executive Monthly Summary — ${data.branchName} (${data.monthLabel})',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    TextButton.icon(
                      icon: Icon(
                        _showAnalyticsCharts
                            ? Icons.bar_chart_rounded
                            : Icons.insert_chart_outlined_rounded,
                        size: 16,
                        color: tokens.brandPrimary,
                      ),
                      label: Text(
                        _showAnalyticsCharts ? 'Hide Charts' : 'Show Charts',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: tokens.brandPrimary,
                        ),
                      ),
                      onPressed: () => setState(
                        () => _showAnalyticsCharts = !_showAnalyticsCharts,
                      ),
                    ),
                    TextButton.icon(
                      icon: Icon(
                        _showMoreMetrics
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: tokens.brandPrimary,
                      ),
                      label: Text(
                        _showMoreMetrics ? 'Less Metrics' : 'More Metrics (4)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: tokens.brandPrimary,
                        ),
                      ),
                      onPressed: () => setState(
                        () => _showMoreMetrics = !_showMoreMetrics,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
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
                        label: 'Principal Disbursed',
                        value: _formatNgn(cards.disbursedPrincipal),
                        delta: '${cards.activeLoans} active loans',
                        isFullEmerald: true,
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    SizedBox(
                      width: cardW,
                      child: IcareMetricCard(
                        label: 'Period Collections',
                        value: _formatNgn(cards.collections),
                        delta: 'Cash repayments collected',
                        topBorderColor: const Color(0xFF10B981),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    SizedBox(
                      width: cardW,
                      child: IcareMetricCard(
                        label: 'Net Active Credit',
                        value: _formatNgn(cards.netActiveCredit),
                        delta: 'Branch credit volume',
                        topBorderColor: tokens.brandPrimary,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    SizedBox(
                      width: cardW,
                      child: IcareMetricCard(
                        label: 'General Ledger Balance',
                        value:
                            cards.isGlBalanced ? 'Balanced' : 'Out of Balance',
                        delta: cards.isGlBalanced
                            ? 'Debits equal Credits'
                            : 'Variance: ${_formatNgn(cards.glDiff)}',
                        topBorderColor: cards.isGlBalanced
                            ? tokens.successDot
                            : tokens.dangerDot,
                        statusTextColor: cards.isGlBalanced
                            ? tokens.successText
                            : tokens.dangerText,
                        icon: Icons.balance_outlined,
                      ),
                    ),
                    if (_showMoreMetrics) ...[
                      SizedBox(
                        width: cardW,
                        child: IcareMetricCard(
                          label: 'Upfront Fees',
                          value: _formatNgn(cards.upfrontFees),
                          topBorderColor: tokens.infoDot,
                        ),
                      ),
                      SizedBox(
                        width: cardW,
                        child: IcareMetricCard(
                          label: 'Closing Credit Portfolio',
                          value: _formatNgn(cards.closingCredit),
                          topBorderColor: tokens.brandPrimaryDark,
                        ),
                      ),
                      SizedBox(
                        width: cardW,
                        child: IcareMetricCard(
                          label: 'Closing Savings Balance',
                          value: _formatNgn(cards.closingSavings),
                          delta: '${cards.activeSavers} active savers',
                          topBorderColor: const Color(0xFF10B981),
                        ),
                      ),
                      SizedBox(
                        width: cardW,
                        child: IcareMetricCard(
                          label: 'Transit Bank Deposits',
                          value: _formatNgn(cards.bankDeposits),
                          topBorderColor: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            if (_showAnalyticsCharts) ...[
              const SizedBox(height: 16),
              BmBranchAnalyticsCharts(parityData: data),
            ],
          ],
        );
      },
    );
  }

  Widget _buildExportsTab(IcareSurfaceTokens tokens) {
    final api = ref.read(reportsApiServiceProvider);
    final String monthPad = widget.selectedMonth.toString().padLeft(2, '0');
    final String cleanBranch = widget.branchName.replaceAll(' ', '_');
    final String periodLabel =
        '${_monthNames[widget.selectedMonth - 1]} ${widget.selectedYear}';

    final String? asOfStr = widget.dateMode == 'As of Date'
        ? _dateFmt.format(widget.asOfDate)
        : null;
    final String? startStr = widget.dateMode == 'Date Range'
        ? _dateFmt.format(widget.startDate)
        : null;
    final String? endStr = widget.dateMode == 'Date Range'
        ? _dateFmt.format(widget.endDate)
        : null;

    final List<String> products = widget.cachedMeta != null
        ? ['All Products', ...widget.cachedMeta!.products]
        : ['All Products'];
    final List<String> officers = widget.cachedMeta != null
        ? [
            'All Officers',
            ...widget.cachedMeta!.officers.map((o) => o.fullName),
          ]
        : ['All Officers'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Collapsible Export Parameters Card
        IcareCard(
          padding: EdgeInsets.zero,
          child: Material(
            type: MaterialType.transparency,
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(
                  'Customize Export Parameters (Product, Officer, Date Window)',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                subtitle: Text(
                  '${widget.branchName} • ${widget.selectedProductName} • ${widget.selectedOfficerName} • ${widget.dateMode}',
                  softWrap: true,
                  style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _CompactDropdownChip(
                          tokens: tokens,
                          value: products.contains(widget.selectedProductName)
                              ? widget.selectedProductName
                              : products.first,
                          items: products,
                          onChanged: widget.onProductChanged,
                        ),
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
                          value: widget.dateMode,
                          items: const ['As of Date', 'Date Range', 'All Time'],
                          onChanged: (mode) => widget.onDateFilterChanged(
                            mode: mode,
                          ),
                        ),
                        if (widget.dateMode == 'As of Date')
                          _DatePickerChip(
                            label: 'As of ${_dateFmt.format(widget.asOfDate)}',
                            tokens: tokens,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: widget.asOfDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                widget.onDateFilterChanged(asOf: picked);
                              }
                            },
                          ),
                        if (widget.dateMode == 'Date Range') ...[
                          _DatePickerChip(
                            label: 'From ${_dateFmt.format(widget.startDate)}',
                            tokens: tokens,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: widget.startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                widget.onDateFilterChanged(start: picked);
                              }
                            },
                          ),
                          _DatePickerChip(
                            label: 'To ${_dateFmt.format(widget.endDate)}',
                            tokens: tokens,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: widget.endDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                widget.onDateFilterChanged(end: picked);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Card 1: Official Monthly Statements & Print Pack
        IcareCard(
          topAccentColor: const Color(0xFF1D4ED8),
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
                      Icons.picture_as_pdf_outlined,
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
                          'Official Monthly Statements & Print Pack',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Preview, print, share, or save statutory month-end financial packs for ${widget.branchName} ($periodLabel).',
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
                    actionKey: 'bm_pdf_preview',
                    busyKey: _busyExportKey,
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'Preview & Print PDF',
                    isPrimary: true,
                    tokens: tokens,
                    onPressed: _openPdfPreview,
                  ),
                  _ExportActionBtn(
                    actionKey: 'bm_pdf_share',
                    busyKey: _busyExportKey,
                    icon: Icons.share_outlined,
                    label: 'Share PDF',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'bm_pdf_share',
                      fetchBytes: () => api.downloadMonthlyParityPdf(
                        branchName: widget.branchName,
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
                          '${widget.branchName} Statement — $periodLabel',
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'bm_pdf_save',
                    busyKey: _busyExportKey,
                    icon: Icons.download_outlined,
                    label: 'Save Official PDF',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'bm_pdf_save',
                      fetchBytes: () => api.downloadMonthlyParityPdf(
                        branchName: widget.branchName,
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
                    actionKey: 'bm_xlsx_save',
                    busyKey: _busyExportKey,
                    icon: Icons.table_chart_outlined,
                    label: 'Branch Excel Workbook (.xlsx)',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'bm_xlsx_save',
                      fetchBytes: () => api.downloadMonthlyParityExcel(
                        branchName: widget.branchName,
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
                    actionKey: 'bm_xlsx_share',
                    busyKey: _busyExportKey,
                    icon: Icons.ios_share_outlined,
                    label: 'Share Workbook',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'bm_xlsx_share',
                      fetchBytes: () => api.downloadMonthlyParityExcel(
                        branchName: widget.branchName,
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
                          '${widget.branchName} Workbook — $periodLabel',
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'bm_co_csv',
                    busyKey: _busyExportKey,
                    icon: Icons.people_alt_outlined,
                    label: 'Credit Officer Summary (.csv)',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'bm_co_csv',
                      fetchBytes: () => api.downloadMonthlyParityCsv(
                        branchName: widget.branchName,
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
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card 2: Operational Registers & Audit Extracts
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
                      Icons.account_balance_outlined,
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
                          'Branch Operational Registers & Ledger Extracts',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Export filtered loan ledgers, repayment registers, and master operational sheets for ${widget.branchName}.',
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
                    actionKey: 'bm_master_xlsx',
                    busyKey: _busyExportKey,
                    icon: Icons.table_view_outlined,
                    label: 'Download Master Branch Report (.xlsx)',
                    isPrimary: true,
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'bm_master_xlsx',
                      fetchBytes: () => api.downloadExcel(
                        branchName: widget.branchName,
                        productName: widget.selectedProductName,
                        officerName: widget.selectedOfficerName,
                        asOfDate: asOfStr,
                        startDate: startStr,
                        endDate: endStr,
                      ),
                      fileName:
                          'Branch_Master_Report_${cleanBranch}_${widget.selectedYear}_$monthPad.xlsx',
                      mimeType:
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                      shareInsteadOfSave: false,
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'bm_master_share',
                    busyKey: _busyExportKey,
                    icon: Icons.share_outlined,
                    label: 'Share Master Report',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'bm_master_share',
                      fetchBytes: () => api.downloadExcel(
                        branchName: widget.branchName,
                        productName: widget.selectedProductName,
                        officerName: widget.selectedOfficerName,
                        asOfDate: asOfStr,
                        startDate: startStr,
                        endDate: endStr,
                      ),
                      fileName:
                          'Branch_Master_Report_${cleanBranch}_${widget.selectedYear}_$monthPad.xlsx',
                      mimeType:
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                      shareInsteadOfSave: true,
                      shareTitle:
                          '${widget.branchName} Master Report — $periodLabel',
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'bm_loans_csv',
                    busyKey: _busyExportKey,
                    icon: Icons.file_download_outlined,
                    label: 'Branch Loans Register (.csv)',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'bm_loans_csv',
                      fetchBytes: () => api.downloadCsv(
                        reportType: 'loans',
                        branchName: widget.branchName,
                        productName: widget.selectedProductName,
                        officerName: widget.selectedOfficerName,
                        asOfDate: asOfStr,
                        startDate: startStr,
                        endDate: endStr,
                      ),
                      fileName:
                          '${cleanBranch}_Loans_${widget.selectedYear}_$monthPad.csv',
                      mimeType: 'text/csv',
                      shareInsteadOfSave: false,
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'bm_repayments_csv',
                    busyKey: _busyExportKey,
                    icon: Icons.file_download_outlined,
                    label: 'Branch Repayments Register (.csv)',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'bm_repayments_csv',
                      fetchBytes: () => api.downloadCsv(
                        reportType: 'repayments',
                        branchName: widget.branchName,
                        productName: widget.selectedProductName,
                        officerName: widget.selectedOfficerName,
                        asOfDate: asOfStr,
                        startDate: startStr,
                        endDate: endStr,
                      ),
                      fileName:
                          '${cleanBranch}_Repayments_${widget.selectedYear}_$monthPad.csv',
                      mimeType: 'text/csv',
                      shareInsteadOfSave: false,
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'bm_savings_csv',
                    busyKey: _busyExportKey,
                    icon: Icons.savings_outlined,
                    label: 'Branch Savings Summary (.csv)',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'bm_savings_csv',
                      fetchBytes: () => api.downloadCsv(
                        reportType: 'savings',
                        branchName: widget.branchName,
                        productName: widget.selectedProductName,
                        officerName: widget.selectedOfficerName,
                        asOfDate: asOfStr,
                        startDate: startStr,
                        endDate: endStr,
                      ),
                      fileName:
                          '${cleanBranch}_Savings_${widget.selectedYear}_$monthPad.csv',
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
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.dangerText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details.message,
                  softWrap: true,
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

class _ThreeTierProgressStrip extends StatelessWidget {
  final int completedTiers;
  final bool isReturned;
  final IcareSurfaceTokens tokens;

  const _ThreeTierProgressStrip({
    required this.completedTiers,
    required this.isReturned,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    const List<String> labels = [
      '1. Branch Certify',
      '2. AM Review',
      '3. Executive Archive',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: List<Widget>.generate(labels.length, (idx) {
          final bool isDone = completedTiers > idx;
          final bool isCurrent = completedTiers == idx;
          final Color badgeColor = isDone
              ? tokens.successDot
              : (isCurrent && isReturned
                  ? tokens.dangerDot
                  : (isCurrent ? tokens.brandPrimary : tokens.textLight));

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDone
                    ? Icons.check_circle_rounded
                    : (isCurrent
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded),
                size: 14,
                color: badgeColor,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  labels[idx],
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: (isDone || isCurrent)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: (isDone || isCurrent)
                        ? tokens.textPrimary
                        : tokens.textMuted,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
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
      width: 210,
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
          isExpanded: true,
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

class _DatePickerChip extends StatelessWidget {
  final String label;
  final IcareSurfaceTokens tokens;
  final VoidCallback onTap;

  const _DatePickerChip({
    required this.label,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.calendar_today_outlined,
          size: 14, color: tokens.textMuted),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: tokens.borderStrong),
        visualDensity: VisualDensity.compact,
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
