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
import 'am_regional_analytics_charts.dart';
import 'am_submitted_branch_card.dart';
import 'report_export_actions.dart';

/// Filter options within Area Manager's BM-Submitted Review & Sign-Off Queue.
enum AmSubmissionQueueFilter {
  submittedOnly,
  awaitingSignOff,
  endorsedAndSealed,
  pendingBm,
}

/// Redesigned Area Manager (Tier-2) Reports & Export Workspace.
///
/// Combines regional comparative analytics, a strictly tiered BM-submitted
/// sign-off queue (defaulting to reports submitted by Branch Managers),
/// audited 7-statement branch inspection, regional package sealing, and
/// in-app PDF preview / native share / workbook exports.
class AmReportsExportView extends ConsumerStatefulWidget {
  final int selectedYear;
  final int selectedMonth;
  final int activeTabIndex;
  final String? selectedBranchName;
  final String selectedProductName;
  final String selectedOfficerName;
  final String dateMode;
  final DateTime asOfDate;
  final DateTime startDate;
  final DateTime endDate;
  final ReportsMeta? cachedMeta;
  final Future<AreaComparisonData>? areaFuture;
  final Future<List<MonthlyWorkflowPendingBranchModel>>?
      pendingSubmissionsFuture;
  final Future<MonthlyParityData>? parityFuture;
  final Future<MonthlyWorkflowStatusModel>? workflowStatusFuture;
  final bool isWorkflowSubmitting;
  final ValueChanged<int> onTabChanged;
  final void Function(int year, int month) onPeriodChanged;
  final ValueChanged<String> onSelectBranchName;
  final ValueChanged<String> onInspectBranchName;
  final ValueChanged<String> onProductChanged;
  final ValueChanged<String> onOfficerChanged;
  final void Function({
    String? mode,
    DateTime? asOf,
    DateTime? start,
    DateTime? end,
  }) onDateFilterChanged;
  final ValueChanged<MonthlyWorkflowStatusModel> onEndorseStatus;
  final ValueChanged<MonthlyWorkflowStatusModel> onReturnStatus;
  final ValueChanged<MonthlyWorkflowPendingBranchModel> onEndorseQueueItem;
  final ValueChanged<MonthlyWorkflowPendingBranchModel> onReturnQueueItem;
  final VoidCallback onSealRegionalPackage;
  final VoidCallback onRefresh;
  final Widget Function() statementsInspectorBuilder;

  const AmReportsExportView({
    super.key,
    required this.selectedYear,
    required this.selectedMonth,
    required this.activeTabIndex,
    required this.selectedBranchName,
    required this.selectedProductName,
    required this.selectedOfficerName,
    required this.dateMode,
    required this.asOfDate,
    required this.startDate,
    required this.endDate,
    required this.cachedMeta,
    required this.areaFuture,
    required this.pendingSubmissionsFuture,
    required this.parityFuture,
    required this.workflowStatusFuture,
    required this.isWorkflowSubmitting,
    required this.onTabChanged,
    required this.onPeriodChanged,
    required this.onSelectBranchName,
    required this.onInspectBranchName,
    required this.onProductChanged,
    required this.onOfficerChanged,
    required this.onDateFilterChanged,
    required this.onEndorseStatus,
    required this.onReturnStatus,
    required this.onEndorseQueueItem,
    required this.onReturnQueueItem,
    required this.onSealRegionalPackage,
    required this.onRefresh,
    required this.statementsInspectorBuilder,
  });

  @override
  ConsumerState<AmReportsExportView> createState() =>
      _AmReportsExportViewState();
}

class _AmReportsExportViewState extends ConsumerState<AmReportsExportView> {
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

  final TextEditingController _searchCtrl = TextEditingController();
  final NumberFormat _ngnFmt = NumberFormat('#,##0.00');
  final NumberFormat _intFmt = NumberFormat('#,##0');
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  AmSubmissionQueueFilter _queueFilter = AmSubmissionQueueFilter.submittedOnly;
  bool _showMoreRegionalMetrics = false;
  bool _showMoreBranchMetrics = false;
  bool _showRawMatrixTableOnMobile = false;
  String? _busyExportKey;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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

  String _resolveSingleBranchName([
    List<MonthlyWorkflowPendingBranchModel> submissions = const [],
    List<AreaBranchRow> areaRows = const [],
  ]) {
    final String? current = widget.selectedBranchName;
    if (current != null && current.isNotEmpty && !current.startsWith('All')) {
      return current;
    }
    if (widget.cachedMeta?.branches.isNotEmpty ?? false) {
      return widget.cachedMeta!.branches.first.name;
    }
    if (submissions.isNotEmpty) {
      return submissions.first.branchName;
    }
    if (areaRows.isNotEmpty) {
      return areaRows.first.branch;
    }
    return 'Assigned Branch';
  }

  List<String> _resolveSupervisedBranchNames(
    List<MonthlyWorkflowPendingBranchModel> submissions,
  ) {
    final Set<String> names = {};
    for (final b in widget.cachedMeta?.branches ?? const <BranchOption>[]) {
      if (b.name.trim().isNotEmpty) names.add(b.name.trim());
    }
    for (final s in submissions) {
      if (s.branchName.trim().isNotEmpty) names.add(s.branchName.trim());
    }
    final String? curr = widget.selectedBranchName;
    if (curr != null &&
        curr.trim().isNotEmpty &&
        !curr.startsWith('All') &&
        !names.contains(curr)) {
      names.add(curr.trim());
    }
    return names.toList();
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

  void _openBranchPdfPreview(
    String branchName, {
    String? signerSummary,
  }) {
    final api = ref.read(reportsApiServiceProvider);
    final String cleanBranch = branchName.replaceAll(' ', '_');
    final String monthPad = widget.selectedMonth.toString().padLeft(2, '0');
    final String periodLabel =
        '${_monthNames[widget.selectedMonth - 1]} ${widget.selectedYear}';
    final String fileName =
        'Branch_Statement_${cleanBranch}_${widget.selectedYear}_$monthPad.pdf';

    ReportPdfPreviewSheet.show(
      context,
      title: '$branchName — Official Executive Statement',
      subtitle: periodLabel,
      signerSummary:
          signerSummary ?? 'Area Manager Supervisory Inspection ($branchName)',
      fileName: fileName,
      loadPdfBytes: () => api.downloadMonthlyParityPdf(
        branchName: branchName,
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
        _buildRegionalHeader(tokens),
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
            child: _buildActiveTabBody(tokens),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTabBody(IcareSurfaceTokens tokens) {
    if (widget.activeTabIndex == 1) {
      return _buildStatementsAndSignOffTab(tokens);
    }
    if (widget.activeTabIndex == 2) {
      return _buildDataExportsTab(tokens);
    }
    return _buildRegionalComparisonTab(tokens);
  }

  Widget _buildRegionalHeader(IcareSurfaceTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tokens.isDark
              ? const [Color(0xFF042F25), Color(0xFF0B1F33)]
              : const [Color(0xFF064E3B), Color(0xFF0F2942)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
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
                    'BM-SUBMITTED REVIEW & DISTRICT SCOPE',
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
                'Area Manager Regional Reports & Sign-Off',
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
                'Review Branch Manager-submitted monthly returns, compare district performance, and certify regional packages.',
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
                scopeChip,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(child: headerText),
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
              'Refresh District',
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
      (label: 'Regional Comparison', icon: Icons.hub_outlined),
      (label: 'Branch Statements & Sign-Off', icon: Icons.fact_check_outlined),
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

  // ===========================================================================
  // TAB 0: REGIONAL COMPARISON + BM-SUBMITTED SIGN-OFF QUEUE
  // ===========================================================================

  Widget _buildRegionalComparisonTab(IcareSurfaceTokens tokens) {
    final List<String> products = widget.cachedMeta != null
        ? ['All Products', ...widget.cachedMeta!.products]
        : ['All Products'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Comparative Filter Bar
        IcareCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list_rounded,
                      size: 15, color: tokens.brandPrimary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Matrix Filters:',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
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
                value: widget.dateMode,
                items: const ['As of Date', 'Date Range', 'All Time'],
                onChanged: (mode) => widget.onDateFilterChanged(mode: mode),
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
        const SizedBox(height: 14),

        // Area Data + Pending Submissions Combined Visualization
        FutureBuilder<AreaComparisonData>(
          future: widget.areaFuture,
          builder: (context, areaSnapshot) {
            if (widget.areaFuture == null ||
                areaSnapshot.connectionState == ConnectionState.waiting) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IcareSkeletonLoader(height: 110),
                  SizedBox(height: 14),
                  IcareSkeletonLoader(height: 220),
                ],
              );
            }

            if (areaSnapshot.hasError) {
              return _buildErrorBanner(tokens, areaSnapshot.error!);
            }

            final AreaComparisonData? areaData = areaSnapshot.data;
            if (areaData == null) return const SizedBox.shrink();

            return FutureBuilder<List<MonthlyWorkflowPendingBranchModel>>(
              future: widget.pendingSubmissionsFuture,
              builder: (context, subSnapshot) {
                final List<MonthlyWorkflowPendingBranchModel> allSubmissions =
                    subSnapshot.data ?? const [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildRegionalSummaryStrip(tokens, areaData),
                    const SizedBox(height: 16),
                    AmRegionalAnalyticsCharts(
                      branchRows: areaData.rows,
                      submissions: allSubmissions,
                    ),
                    const SizedBox(height: 16),

                    // Tier-2 Governance: BM-Submitted Reports & Sign-Off Queue
                    _buildSubmittedQueueSection(
                      tokens: tokens,
                      subSnapshot: subSnapshot,
                      allSubmissions: allSubmissions,
                    ),
                    const SizedBox(height: 16),

                    // Comparative Branch Matrix
                    _buildComparativeMatrixSection(tokens, areaData),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRegionalSummaryStrip(
    IcareSurfaceTokens tokens,
    AreaComparisonData data,
  ) {
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
              'Regional District Executive Summary (${data.totalBranches} Branches)',
              softWrap: true,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            TextButton.icon(
              icon: Icon(
                _showMoreRegionalMetrics
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: tokens.brandPrimary,
              ),
              label: Text(
                _showMoreRegionalMetrics
                    ? 'Less Metrics'
                    : 'More Regional Metrics',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.brandPrimary,
                ),
              ),
              onPressed: () => setState(
                () => _showMoreRegionalMetrics = !_showMoreRegionalMetrics,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
                    label: 'Regional Collections',
                    value: _formatNgn(data.totalAreaCollections),
                    delta: 'Expected: ${_formatNgn(data.totalAreaExpected)}',
                    isFullEmerald: true,
                    icon: Icons.payments_outlined,
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: IcareMetricCard(
                    label: 'District Efficiency',
                    value: '${data.overallEfficiency.toStringAsFixed(1)}%',
                    delta: 'PAR: ${data.overallPar.toStringAsFixed(1)}%',
                    topBorderColor: const Color(0xFF10B981),
                    icon: Icons.speed_rounded,
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: IcareMetricCard(
                    label: 'Area Credit Portfolio',
                    value: _formatNgn(data.totalAreaPortfolio),
                    delta:
                        '${_intFmt.format(data.totalActiveLoans)} active loans',
                    topBorderColor: tokens.brandPrimary,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: IcareMetricCard(
                    label: 'Area Savings Portfolio',
                    value: _formatNgn(data.totalAreaSavings),
                    delta:
                        '${_intFmt.format(data.totalActiveSavers)} active savers',
                    topBorderColor: tokens.infoDot,
                    icon: Icons.savings_outlined,
                  ),
                ),
                if (_showMoreRegionalMetrics) ...[
                  SizedBox(
                    width: cardW,
                    child: IcareMetricCard(
                      label: 'Supervised Branches',
                      value: '${data.totalBranches}',
                      topBorderColor: tokens.brandPrimaryDark,
                    ),
                  ),
                  SizedBox(
                    width: cardW,
                    child: IcareMetricCard(
                      label: 'People on Loan',
                      value:
                          '${_intFmt.format(data.totalPeopleOnLoan)} Clients',
                      topBorderColor: tokens.brandPrimary,
                    ),
                  ),
                  SizedBox(
                    width: cardW,
                    child: IcareMetricCard(
                      label: 'Expected Collections',
                      value: _formatNgn(data.totalAreaExpected),
                      topBorderColor: tokens.warningDot,
                    ),
                  ),
                  SizedBox(
                    width: cardW,
                    child: IcareMetricCard(
                      label: 'Overall PAR %',
                      value: '${data.overallPar.toStringAsFixed(1)}%',
                      topBorderColor: data.overallPar > 5.0
                          ? tokens.dangerDot
                          : tokens.successDot,
                      statusTextColor: data.overallPar > 5.0
                          ? tokens.dangerText
                          : tokens.successText,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubmittedQueueSection({
    required IcareSurfaceTokens tokens,
    required AsyncSnapshot<List<MonthlyWorkflowPendingBranchModel>> subSnapshot,
    required List<MonthlyWorkflowPendingBranchModel> allSubmissions,
  }) {
    final String monthLabel =
        '${_monthNames[widget.selectedMonth - 1]} ${widget.selectedYear}';

    if (subSnapshot.connectionState == ConnectionState.waiting) {
      return const IcareSkeletonLoader(height: 180);
    }

    if (subSnapshot.hasError) {
      return _buildErrorBanner(tokens, subSnapshot.error!);
    }

    final List<MonthlyWorkflowPendingBranchModel> submittedBranches =
        allSubmissions.where((s) => s.status != 'DRAFT').toList();
    final List<MonthlyWorkflowPendingBranchModel> draftBranches =
        allSubmissions.where((s) => s.status == 'DRAFT').toList();

    final int submittedCount = submittedBranches.length;
    final int awaitingCount =
        allSubmissions.where((s) => s.status == 'BM_SUBMITTED').length;
    final int endorsedCount = allSubmissions
        .where(
          (s) => const {
            'AM_VERIFIED',
            'AREA_SEALED',
            'ADMIN_LOCKED',
          }.contains(s.status),
        )
        .length;
    final int draftCount = draftBranches.length;

    final String query = _searchCtrl.text.trim().toLowerCase();
    final List<MonthlyWorkflowPendingBranchModel> filtered =
        allSubmissions.where((item) {
      switch (_queueFilter) {
        case AmSubmissionQueueFilter.submittedOnly:
          if (item.status == 'DRAFT') return false;
          break;
        case AmSubmissionQueueFilter.awaitingSignOff:
          if (item.status != 'BM_SUBMITTED') return false;
          break;
        case AmSubmissionQueueFilter.endorsedAndSealed:
          if (!const {
            'AM_VERIFIED',
            'AREA_SEALED',
            'ADMIN_LOCKED',
          }.contains(item.status)) {
            return false;
          }
          break;
        case AmSubmissionQueueFilter.pendingBm:
          if (item.status != 'DRAFT') return false;
          break;
      }

      if (query.isEmpty) return true;
      final hay = [
        item.branchName,
        item.areaName ?? '',
        item.bmName ?? '',
        item.amNotes ?? '',
        item.amQueryNotes ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(query);
    }).toList();

    final String singleBranchHint = _resolveSingleBranchName(allSubmissions);
    final String monthPad = widget.selectedMonth.toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.assignment_turned_in_outlined,
                        size: 18,
                        color: tokens.brandPrimary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'BM-Submitted Reports & Sign-Off Queue',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _QueueFilterPill(
                        label: 'Submitted Queue ($submittedCount)',
                        selected: _queueFilter ==
                            AmSubmissionQueueFilter.submittedOnly,
                        tokens: tokens,
                        onTap: () => setState(
                          () => _queueFilter =
                              AmSubmissionQueueFilter.submittedOnly,
                        ),
                      ),
                      _QueueFilterPill(
                        label: 'Awaiting Sign-Off ($awaitingCount)',
                        selected: _queueFilter ==
                            AmSubmissionQueueFilter.awaitingSignOff,
                        tokens: tokens,
                        onTap: () => setState(
                          () => _queueFilter =
                              AmSubmissionQueueFilter.awaitingSignOff,
                        ),
                      ),
                      _QueueFilterPill(
                        label: 'Endorsed & Sealed ($endorsedCount)',
                        selected: _queueFilter ==
                            AmSubmissionQueueFilter.endorsedAndSealed,
                        tokens: tokens,
                        onTap: () => setState(
                          () => _queueFilter =
                              AmSubmissionQueueFilter.endorsedAndSealed,
                        ),
                      ),
                      if (draftCount > 0)
                        _QueueFilterPill(
                          label: 'Pending BM ($draftCount)',
                          selected:
                              _queueFilter == AmSubmissionQueueFilter.pendingBm,
                          tokens: tokens,
                          onTap: () => setState(
                            () => _queueFilter =
                                AmSubmissionQueueFilter.pendingBm,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (draftCount > 0 &&
                  _queueFilter != AmSubmissionQueueFilter.pendingBm) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: tokens.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$draftCount supervised branch${draftCount == 1 ? ' is' : 'es are'} still in Branch Manager preparation and excluded from the active sign-off queue.',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  hintText:
                      'Filter submitted branches by name or Branch Manager...',
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
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          IcareCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                Icon(
                  Icons.pending_actions_rounded,
                  size: 28,
                  color: tokens.brandPrimary,
                ),
                const SizedBox(height: 10),
                Text(
                  submittedCount == 0 &&
                          _queueFilter == AmSubmissionQueueFilter.submittedOnly
                      ? 'No Branch Manager-Submitted Reports Ready for $monthLabel'
                      : 'No branch submissions match the current filter.',
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  submittedCount == 0 &&
                          _queueFilter == AmSubmissionQueueFilter.submittedOnly
                      ? 'Branch monthly returns appear here for supervisory endorsement once a Branch Manager certifies and submits them.'
                      : 'Adjust your filter selection or search query to inspect other supervised branches.',
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(fontSize: 12, color: tokens.textMuted),
                ),
                if (draftCount > 0 &&
                    _queueFilter == AmSubmissionQueueFilter.submittedOnly) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(
                      () => _queueFilter = AmSubmissionQueueFilter.pendingBm,
                    ),
                    child: Text('View $draftCount Branch In Preparation'),
                  ),
                ],
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final bool twoCols = constraints.maxWidth >= 980;
              final double cardW = twoCols
                  ? (constraints.maxWidth - 14) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: filtered.map((sub) {
                  final cleanBranch = sub.branchName.replaceAll(' ', '_');
                  return SizedBox(
                    width: cardW,
                    child: AmSubmittedBranchCard(
                      submission: sub,
                      isSelected: sub.branchName == singleBranchHint,
                      isBusyWorkflow: widget.isWorkflowSubmitting,
                      onInspectStatements: () =>
                          widget.onInspectBranchName(sub.branchName),
                      onPreviewPdf: () => _openBranchPdfPreview(
                        sub.branchName,
                        signerSummary:
                            'Prepared by ${sub.bmName ?? 'Branch Manager'} (${_formatDateTime(sub.submittedAt)})',
                      ),
                      onShareExcel: () => _runExportAction(
                        actionKey: 'am_share_${sub.branchId}',
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
                            'Branch_Workbook_${cleanBranch}_${widget.selectedYear}_$monthPad.xlsx',
                        mimeType:
                            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                        shareInsteadOfSave: true,
                        shareTitle: '${sub.branchName} Workbook — $monthLabel',
                      ),
                      onEndorse: sub.status == 'BM_SUBMITTED'
                          ? () => widget.onEndorseQueueItem(sub)
                          : null,
                      onReturn: sub.status == 'BM_SUBMITTED'
                          ? () => widget.onReturnQueueItem(sub)
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildComparativeMatrixSection(
    IcareSurfaceTokens tokens,
    AreaComparisonData data,
  ) {
    final api = ref.read(reportsApiServiceProvider);
    final String monthPad = widget.selectedMonth.toString().padLeft(2, '0');
    final String? asOfStr = widget.dateMode == 'As of Date'
        ? _dateFmt.format(widget.asOfDate)
        : null;
    final String? startStr = widget.dateMode == 'Date Range'
        ? _dateFmt.format(widget.startDate)
        : null;
    final String? endStr = widget.dateMode == 'Date Range'
        ? _dateFmt.format(widget.endDate)
        : null;

    return IcareCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 680;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.grid_on_rounded,
                        size: 17,
                        color: tokens.brandPrimary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Branch-by-Branch Comparative Matrix',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isMobile)
                    TextButton.icon(
                      icon: Icon(
                        _showRawMatrixTableOnMobile
                            ? Icons.view_agenda_outlined
                            : Icons.table_chart_outlined,
                        size: 15,
                        color: tokens.brandPrimary,
                      ),
                      label: Text(
                        _showRawMatrixTableOnMobile
                            ? 'Show Cards'
                            : 'Show Comparative Table',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: tokens.brandPrimary,
                        ),
                      ),
                      onPressed: () => setState(
                        () => _showRawMatrixTableOnMobile =
                            !_showRawMatrixTableOnMobile,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (data.rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No comparative branch rows available for this period.',
                      style: TextStyle(fontSize: 13, color: tokens.textMuted),
                    ),
                  ),
                )
              else if (isMobile && !_showRawMatrixTableOnMobile)
                Column(
                  children: data.rows
                      .map((r) => _buildMobileMatrixCard(tokens, r))
                      .toList(),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(tokens.surfaceSubtle),
                    headingTextStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary,
                      fontSize: 12,
                    ),
                    dataTextStyle: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                    columns: const [
                      DataColumn(label: Text('Branch')),
                      DataColumn(label: Text('People on Loan')),
                      DataColumn(label: Text('Active Loans')),
                      DataColumn(label: Text('Active Savers')),
                      DataColumn(label: Text('Total Savings')),
                      DataColumn(label: Text('Collections')),
                      DataColumn(label: Text('Expected')),
                      DataColumn(label: Text('Efficiency')),
                      DataColumn(label: Text('Outstanding')),
                      DataColumn(label: Text('PAR %')),
                      DataColumn(label: Text('Health')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: data.rows.map((r) {
                      final bool isHealthy = r.status == 'HEALTHY';
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              r.branch,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ),
                          DataCell(Text(_intFmt.format(r.peopleOnLoan))),
                          DataCell(Text(_intFmt.format(r.activeLoans))),
                          DataCell(Text(_intFmt.format(r.activeSavers))),
                          DataCell(Text(_formatNgn(r.totalSavings))),
                          DataCell(Text(_formatNgn(r.collectionsReceived))),
                          DataCell(Text(_formatNgn(r.expectedCollections))),
                          DataCell(
                            Text(
                                '${r.collectionEfficiency.toStringAsFixed(1)}%'),
                          ),
                          DataCell(Text(_formatNgn(r.outstandingPortfolio))),
                          DataCell(
                              Text('${r.parPercentage.toStringAsFixed(1)}%')),
                          DataCell(
                            IcareStatusBadge(
                              label: r.status,
                              variant: isHealthy
                                  ? IcareBadgeVariant.success
                                  : IcareBadgeVariant.danger,
                            ),
                          ),
                          DataCell(
                            OutlinedButton(
                              onPressed: () =>
                                  widget.onInspectBranchName(r.branch),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: tokens.brandPrimary,
                                side: BorderSide(color: tokens.brandPrimary),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Inspect',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ExportActionBtn(
                    actionKey: 'am_matrix_xlsx',
                    busyKey: _busyExportKey,
                    icon: Icons.table_chart_outlined,
                    label: 'Download Regional Report (.xlsx)',
                    isPrimary: true,
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'am_matrix_xlsx',
                      fetchBytes: () => api.downloadExcel(
                        productName: widget.selectedProductName,
                        asOfDate: asOfStr,
                        startDate: startStr,
                        endDate: endStr,
                        year: widget.selectedYear,
                        month: widget.selectedMonth,
                      ),
                      fileName:
                          'Regional_Operational_Report_${widget.selectedYear}_$monthPad.xlsx',
                      mimeType:
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                      shareInsteadOfSave: false,
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'am_matrix_share_xlsx',
                    busyKey: _busyExportKey,
                    icon: Icons.share_outlined,
                    label: 'Share Regional Workbook',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'am_matrix_share_xlsx',
                      fetchBytes: () => api.downloadExcel(
                        productName: widget.selectedProductName,
                        asOfDate: asOfStr,
                        startDate: startStr,
                        endDate: endStr,
                        year: widget.selectedYear,
                        month: widget.selectedMonth,
                      ),
                      fileName:
                          'Regional_Operational_Report_${widget.selectedYear}_$monthPad.xlsx',
                      mimeType:
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                      shareInsteadOfSave: true,
                      shareTitle: 'ICARE Regional Report',
                    ),
                  ),
                  _ExportActionBtn(
                    actionKey: 'am_matrix_csv',
                    busyKey: _busyExportKey,
                    icon: Icons.file_download_outlined,
                    label: 'Area Comparison (.csv)',
                    tokens: tokens,
                    onPressed: () => _runExportAction(
                      actionKey: 'am_matrix_csv',
                      fetchBytes: () => api.downloadCsv(
                        reportType: 'area_comparison',
                        productName: widget.selectedProductName,
                        asOfDate: asOfStr,
                        startDate: startStr,
                        endDate: endStr,
                        year: widget.selectedYear,
                        month: widget.selectedMonth,
                      ),
                      fileName:
                          'Area_Comparison_${widget.selectedYear}_$monthPad.csv',
                      mimeType: 'text/csv',
                      shareInsteadOfSave: false,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileMatrixCard(
    IcareSurfaceTokens tokens,
    AreaBranchRow r,
  ) {
    final bool isHealthy = r.status == 'HEALTHY';
    final double progress = (r.collectionEfficiency / 100.0).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.branch,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IcareStatusBadge(
                label: r.status,
                variant: isHealthy
                    ? IcareBadgeVariant.success
                    : IcareBadgeVariant.danger,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Collection Efficiency',
                  softWrap: true,
                  style: TextStyle(fontSize: 11, color: tokens.textMuted),
                ),
              ),
              Text(
                '${r.collectionEfficiency.toStringAsFixed(1)}%',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isHealthy ? tokens.successText : tokens.warningText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: tokens.surfaceHover,
              valueColor: AlwaysStoppedAnimation<Color>(
                isHealthy ? tokens.brandPrimary : tokens.warningDot,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Collections: ${_formatNgn(r.collectionsReceived)}',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Expected: ${_formatNgn(r.expectedCollections)}',
                  textAlign: TextAlign.end,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Portfolio: ${_formatNgn(r.outstandingPortfolio)}',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PAR ${r.parPercentage.toStringAsFixed(1)}%',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: r.parPercentage > 5.0
                      ? tokens.dangerText
                      : tokens.successText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => widget.onInspectBranchName(r.branch),
              icon: Icon(
                Icons.description_outlined,
                size: 14,
                color: tokens.brandPrimary,
              ),
              label: Text(
                'Inspect Branch Statements',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tokens.brandPrimary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: tokens.brandPrimary),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: BRANCH STATEMENTS & SUPERVISORY SIGN-OFF
  // ===========================================================================

  Widget _buildStatementsAndSignOffTab(IcareSurfaceTokens tokens) {
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
    final String periodLabel =
        '${_monthNames[widget.selectedMonth - 1]} ${widget.selectedYear}';

    return FutureBuilder<List<MonthlyWorkflowPendingBranchModel>>(
      future: widget.pendingSubmissionsFuture,
      builder: (context, subSnapshot) {
        final List<MonthlyWorkflowPendingBranchModel> submissions =
            subSnapshot.data ?? const [];
        final List<String> branchNames =
            _resolveSupervisedBranchNames(submissions);
        final String activeBranch = _resolveSingleBranchName(submissions);
        final String cleanBranch = activeBranch.replaceAll(' ', '_');

        final Map<String, MonthlyWorkflowPendingBranchModel> statusByBranch = {
          for (final s in submissions) s.branchName: s,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Supervised Branch Switcher + Controls
            IcareCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SUPERVISED BRANCH SWITCHER',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: tokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (branchNames.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: branchNames.map((bName) {
                          final bool active = bName == activeBranch;
                          final sub = statusByBranch[bName];
                          final IconData chipIcon = switch (sub?.status) {
                            'BM_SUBMITTED' => Icons.pending_actions_rounded,
                            'AM_VERIFIED' ||
                            'AREA_SEALED' =>
                              Icons.verified_outlined,
                            'ADMIN_LOCKED' => Icons.lock_outline_rounded,
                            'RETURNED_FOR_CORRECTION' =>
                              Icons.assignment_return_outlined,
                            _ => Icons.storefront_outlined,
                          };
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: Icon(
                                chipIcon,
                                size: 14,
                                color:
                                    active ? Colors.white : tokens.brandPrimary,
                              ),
                              label: Text(
                                bName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: active
                                      ? Colors.white
                                      : tokens.textPrimary,
                                ),
                              ),
                              selected: active,
                              selectedColor: tokens.brandPrimaryDark,
                              backgroundColor: tokens.surfaceSubtle,
                              onSelected: (picked) {
                                if (picked && !active) {
                                  widget.onSelectBranchName(bName);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
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
                        onPressed: () => _openBranchPdfPreview(activeBranch),
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
                        actionKey: 'am_stmt_share_xlsx',
                        busyKey: _busyExportKey,
                        icon: Icons.ios_share_outlined,
                        label: 'Share Workbook',
                        tokens: tokens,
                        onPressed: () => _runExportAction(
                          actionKey: 'am_stmt_share_xlsx',
                          fetchBytes: () => ref
                              .read(reportsApiServiceProvider)
                              .downloadMonthlyParityExcel(
                                branchName: activeBranch,
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
                          shareTitle: '$activeBranch Workbook — $periodLabel',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tier-2 Supervisory Sign-Off Banner
            _buildAmWorkflowStatusBanner(tokens),
            const SizedBox(height: 14),

            // Branch KPI Strip
            _buildBranchSummaryStrip(tokens),
            const SizedBox(height: 16),

            // Shared Audited 7-Statement Workbench
            widget.statementsInspectorBuilder(),
          ],
        );
      },
    );
  }

  Widget _buildAmWorkflowStatusBanner(IcareSurfaceTokens tokens) {
    if (widget.workflowStatusFuture == null) {
      return const IcareSkeletonLoader(height: 95);
    }

    return FutureBuilder<MonthlyWorkflowStatusModel>(
      future: widget.workflowStatusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IcareSkeletonLoader(height: 95);
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
        final List<Widget> actions = [];

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
                'Certified by ${st.bmName ?? "Branch Manager"} on ${_formatDateTime(st.bmSubmittedAt)}. Verify statements below before endorsing.';
            actions.add(
              OutlinedButton.icon(
                onPressed: widget.isWorkflowSubmitting
                    ? null
                    : () => widget.onReturnStatus(st),
                icon: Icon(
                  Icons.assignment_return_outlined,
                  size: 14,
                  color: tokens.dangerText,
                ),
                label: Text(
                  'Query / Return',
                  style: TextStyle(
                    color: tokens.dangerText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.dangerBorder),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                ),
              ),
            );
            actions.add(
              ElevatedButton.icon(
                onPressed: widget.isWorkflowSubmitting
                    ? null
                    : () => widget.onEndorseStatus(st),
                icon: const Icon(Icons.check_circle_outline, size: 15),
                label: const Text(
                  'Endorse & Sign Off',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.brandPrimaryDark,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
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
                'Endorsed by ${st.amName ?? "Area Manager"} on ${_formatDateTime(st.amEndorsedAt)}. Ready for regional package seal once all supervised branches are verified.';
            actions.add(
              OutlinedButton.icon(
                onPressed: widget.isWorkflowSubmitting
                    ? null
                    : widget.onSealRegionalPackage,
                icon: Icon(
                  Icons.folder_special_outlined,
                  size: 14,
                  color: tokens.infoText,
                ),
                label: Text(
                  'Seal Regional Package',
                  style: TextStyle(
                    color: tokens.infoText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.infoBorder),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                'Sealed by Area Manager. Awaiting Executive Admin permanent archival lock.';
            actions.add(
              const IcareStatusBadge(
                label: 'Sealed • Awaiting Admin Archival',
                variant: IcareBadgeVariant.info,
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
                'Awaiting Branch Manager adjustments and resubmission before Area Manager sign-off.';
            actions.add(
              const IcareStatusBadge(
                label: 'Returned to Branch Manager',
                variant: IcareBadgeVariant.danger,
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
                'Permanently archived by ${st.adminName ?? "Administrator"} on ${_formatDateTime(st.adminLockedAt)}.';
            actions.add(
              const IcareStatusBadge(
                label: 'Permanent Audit Record',
                variant: IcareBadgeVariant.neutral,
              ),
            );
            break;

          default: // DRAFT — BM has not yet submitted
            accentColor = tokens.textMuted;
            bgTint = tokens.surfaceSubtle;
            borderTint = tokens.borderSubtle;
            badgeVariant = IcareBadgeVariant.neutral;
            pillLabel = 'DRAFT — BOOKS OPEN';
            icon = Icons.hourglass_empty_rounded;
            title = 'Branch Report Not Yet Submitted by Branch Manager';
            description =
                'Supervisory endorsement unlocks once the Branch Manager certifies and submits the month-end return. Read-only inspection remains available.';
            actions.add(
              const IcareStatusBadge(
                label: 'Awaiting Branch Submission',
                variant: IcareBadgeVariant.neutral,
              ),
            );
            break;
        }

        return IcareCard(
          topAccentColor: accentColor,
          backgroundColor: bgTint,
          border: Border.all(color: borderTint),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxWidth < 840;
              final Widget infoBlock = Column(
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tokens.dangerBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            size: 15,
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

              final Widget actionsWrap = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions,
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoBlock,
                    const SizedBox(height: 12),
                    actionsWrap,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: infoBlock),
                  const SizedBox(width: 16),
                  actionsWrap,
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBranchSummaryStrip(IcareSurfaceTokens tokens) {
    if (widget.parityFuture == null) {
      return const IcareSkeletonLoader(height: 100);
    }

    return FutureBuilder<MonthlyParityData>(
      future: widget.parityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IcareSkeletonLoader(height: 100);
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
                TextButton.icon(
                  icon: Icon(
                    _showMoreBranchMetrics
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: tokens.brandPrimary,
                  ),
                  label: Text(
                    _showMoreBranchMetrics
                        ? 'Less Metrics'
                        : 'More Metrics (4)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: tokens.brandPrimary,
                    ),
                  ),
                  onPressed: () => setState(
                    () => _showMoreBranchMetrics = !_showMoreBranchMetrics,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                        delta: 'Cash repayments received',
                        topBorderColor: const Color(0xFF10B981),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    SizedBox(
                      width: cardW,
                      child: IcareMetricCard(
                        label: 'Net Active Credit',
                        value: _formatNgn(cards.netActiveCredit),
                        delta: 'Branch credit exposure',
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
                    if (_showMoreBranchMetrics) ...[
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
          ],
        );
      },
    );
  }

  // ===========================================================================
  // TAB 2: DATA EXPORTS & DOWNLOADS (REGIONAL + SINGLE-BRANCH PRINT/SHARE VAULT)
  // ===========================================================================

  Widget _buildDataExportsTab(IcareSurfaceTokens tokens) {
    final api = ref.read(reportsApiServiceProvider);
    final String monthPad = widget.selectedMonth.toString().padLeft(2, '0');
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

    return FutureBuilder<List<MonthlyWorkflowPendingBranchModel>>(
      future: widget.pendingSubmissionsFuture,
      builder: (context, subSnapshot) {
        final List<MonthlyWorkflowPendingBranchModel> submissions =
            subSnapshot.data ?? const [];
        final List<String> branchNames =
            _resolveSupervisedBranchNames(submissions);
        final String effectiveSingleBranch =
            _resolveSingleBranchName(submissions);
        final String cleanBranch = effectiveSingleBranch.replaceAll(' ', '_');

        final MonthlyWorkflowPendingBranchModel? selectedSub =
            submissions.cast<MonthlyWorkflowPendingBranchModel?>().firstWhere(
                  (s) => s?.branchName == effectiveSingleBranch,
                  orElse: () => null,
                );

        final List<String> scopeOptions = [
          'All Assigned Branches (Consolidated)',
          ...branchNames,
        ];
        final String currentScopeValue =
            scopeOptions.contains(widget.selectedBranchName)
                ? widget.selectedBranchName!
                : scopeOptions.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Collapsible Export Parameters Card
            IcareCard(
              padding: EdgeInsets.zero,
              child: Material(
                type: MaterialType.transparency,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      'Customize Export Parameters (Branch, Product, Officer, Date Window)',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '$effectiveSingleBranch • ${widget.selectedProductName} • ${widget.selectedOfficerName} • ${widget.dateMode}',
                      softWrap: true,
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _CompactDropdownChip(
                              tokens: tokens,
                              value: currentScopeValue,
                              items: scopeOptions,
                              onChanged: widget.onSelectBranchName,
                            ),
                            _CompactDropdownChip(
                              tokens: tokens,
                              value:
                                  products.contains(widget.selectedProductName)
                                      ? widget.selectedProductName
                                      : products.first,
                              items: products,
                              onChanged: widget.onProductChanged,
                            ),
                            _CompactDropdownChip(
                              tokens: tokens,
                              value:
                                  officers.contains(widget.selectedOfficerName)
                                      ? widget.selectedOfficerName
                                      : officers.first,
                              items: officers,
                              onChanged: widget.onOfficerChanged,
                            ),
                            _CompactDropdownChip(
                              tokens: tokens,
                              value: widget.dateMode,
                              items: const [
                                'As of Date',
                                'Date Range',
                                'All Time'
                              ],
                              onChanged: (mode) =>
                                  widget.onDateFilterChanged(mode: mode),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 1: Regional Consolidated Supervisory Package
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
                              'Regional Consolidated Supervisory Package',
                              softWrap: true,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Multi-branch consolidated workbooks, regional comparison matrices, and operational registers across your supervised district.',
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
                        actionKey: 'am_reg_excel',
                        busyKey: _busyExportKey,
                        icon: Icons.table_view_outlined,
                        label: 'Download Master Regional Report (.xlsx)',
                        isPrimary: true,
                        tokens: tokens,
                        onPressed: () => _runExportAction(
                          actionKey: 'am_reg_excel',
                          fetchBytes: () => api.downloadExcel(
                            productName: widget.selectedProductName,
                            officerName: widget.selectedOfficerName,
                            asOfDate: asOfStr,
                            startDate: startStr,
                            endDate: endStr,
                            year: widget.selectedYear,
                            month: widget.selectedMonth,
                          ),
                          fileName:
                              'Master_Regional_Report_${widget.selectedYear}_$monthPad.xlsx',
                          mimeType:
                              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                          shareInsteadOfSave: false,
                        ),
                      ),
                      _ExportActionBtn(
                        actionKey: 'am_reg_share',
                        busyKey: _busyExportKey,
                        icon: Icons.ios_share_outlined,
                        label: 'Share Regional Workbook',
                        tokens: tokens,
                        onPressed: () => _runExportAction(
                          actionKey: 'am_reg_share',
                          fetchBytes: () => api.downloadExcel(
                            productName: widget.selectedProductName,
                            officerName: widget.selectedOfficerName,
                            asOfDate: asOfStr,
                            startDate: startStr,
                            endDate: endStr,
                            year: widget.selectedYear,
                            month: widget.selectedMonth,
                          ),
                          fileName:
                              'Master_Regional_Report_${widget.selectedYear}_$monthPad.xlsx',
                          mimeType:
                              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                          shareInsteadOfSave: true,
                          shareTitle:
                              'ICARE Regional Operational Report — $periodLabel',
                        ),
                      ),
                      _ExportActionBtn(
                        actionKey: 'am_reg_area_csv',
                        busyKey: _busyExportKey,
                        icon: Icons.compare_arrows_rounded,
                        label: 'Area Comparison (.csv)',
                        tokens: tokens,
                        onPressed: () => _runExportAction(
                          actionKey: 'am_reg_area_csv',
                          fetchBytes: () => api.downloadCsv(
                            reportType: 'area_comparison',
                            productName: widget.selectedProductName,
                            officerName: widget.selectedOfficerName,
                            asOfDate: asOfStr,
                            startDate: startStr,
                            endDate: endStr,
                            year: widget.selectedYear,
                            month: widget.selectedMonth,
                          ),
                          fileName:
                              'Area_Branch_Comparison_${widget.selectedYear}_$monthPad.csv',
                          mimeType: 'text/csv',
                          shareInsteadOfSave: false,
                        ),
                      ),
                      _ExportActionBtn(
                        actionKey: 'am_reg_loans_csv',
                        busyKey: _busyExportKey,
                        icon: Icons.file_download_outlined,
                        label: 'Regional Raw Loans (.csv)',
                        tokens: tokens,
                        onPressed: () => _runExportAction(
                          actionKey: 'am_reg_loans_csv',
                          fetchBytes: () => api.downloadCsv(
                            reportType: 'loans',
                            productName: widget.selectedProductName,
                            officerName: widget.selectedOfficerName,
                            asOfDate: asOfStr,
                            startDate: startStr,
                            endDate: endStr,
                            year: widget.selectedYear,
                            month: widget.selectedMonth,
                          ),
                          fileName:
                              'Regional_Loans_${widget.selectedYear}_$monthPad.csv',
                          mimeType: 'text/csv',
                          shareInsteadOfSave: false,
                        ),
                      ),
                      _ExportActionBtn(
                        actionKey: 'am_reg_rep_csv',
                        busyKey: _busyExportKey,
                        icon: Icons.file_download_outlined,
                        label: 'Regional Raw Repayments (.csv)',
                        tokens: tokens,
                        onPressed: () => _runExportAction(
                          actionKey: 'am_reg_rep_csv',
                          fetchBytes: () => api.downloadCsv(
                            reportType: 'repayments',
                            productName: widget.selectedProductName,
                            officerName: widget.selectedOfficerName,
                            asOfDate: asOfStr,
                            startDate: startStr,
                            endDate: endStr,
                            year: widget.selectedYear,
                            month: widget.selectedMonth,
                          ),
                          fileName:
                              'Regional_Repayments_${widget.selectedYear}_$monthPad.csv',
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

            // Card 2: Single-Branch Statutory Extraction & Print Vault
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
                          Icons.account_balance_outlined,
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
                              'Single-Branch Statutory Extraction & Print Vault',
                              softWrap: true,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Preview, print, share, or download statutory monthly statements and registers for an individual supervised branch.',
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
                      if (branchNames.isNotEmpty)
                        _CompactDropdownChip(
                          tokens: tokens,
                          value: branchNames.contains(effectiveSingleBranch)
                              ? effectiveSingleBranch
                              : branchNames.first,
                          items: branchNames,
                          onChanged: widget.onSelectBranchName,
                        ),
                      if (selectedSub != null)
                        IcareStatusBadge(
                          label: selectedSub.status == 'DRAFT'
                              ? 'Pending BM Submission'
                              : selectedSub.status.replaceAll('_', ' '),
                          variant: selectedSub.status == 'DRAFT'
                              ? IcareBadgeVariant.neutral
                              : (selectedSub.status == 'BM_SUBMITTED'
                                  ? IcareBadgeVariant.warning
                                  : (selectedSub.status ==
                                          'RETURNED_FOR_CORRECTION'
                                      ? IcareBadgeVariant.danger
                                      : IcareBadgeVariant.success)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ExportActionBtn(
                        actionKey: 'am_br_pdf_preview',
                        busyKey: _busyExportKey,
                        icon: Icons.picture_as_pdf_outlined,
                        label: 'Preview & Print PDF',
                        isPrimary: true,
                        tokens: tokens,
                        onPressed: () =>
                            _openBranchPdfPreview(effectiveSingleBranch),
                      ),
                      _ExportActionBtn(
                        actionKey: 'am_br_pdf_share',
                        busyKey: _busyExportKey,
                        icon: Icons.share_outlined,
                        label: 'Share PDF',
                        tokens: tokens,
                        onPressed: () => _runExportAction(
                          actionKey: 'am_br_pdf_share',
                          fetchBytes: () => api.downloadMonthlyParityPdf(
                            branchName: effectiveSingleBranch,
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
                              '$effectiveSingleBranch Statement — $periodLabel',
                        ),
                      ),
                      _ExportActionBtn(
                        actionKey: 'am_br_pdf_save',
                        busyKey: _busyExportKey,
                        icon: Icons.download_outlined,
                        label: 'Save PDF',
                        tokens: tokens,
                        onPressed: () => _runExportAction(
                          actionKey: 'am_br_pdf_save',
                          fetchBytes: () => api.downloadMonthlyParityPdf(
                            branchName: effectiveSingleBranch,
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
                        actionKey: 'am_br_xlsx_save',
                        busyKey: _busyExportKey,
                        icon: Icons.table_chart_outlined,
                        label: 'Branch Excel (.xlsx)',
                        tokens: tokens,
                        onPressed: () => _runExportAction(
                          actionKey: 'am_br_xlsx_save',
                          fetchBytes: () => api.downloadMonthlyParityExcel(
                            branchName: effectiveSingleBranch,
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
                        actionKey: 'am_br_xlsx_share',
                        busyKey: _busyExportKey,
                        icon: Icons.ios_share_outlined,
                        label: 'Share Excel',
                        tokens: tokens,
                        onPressed: () => _runExportAction(
                          actionKey: 'am_br_xlsx_share',
                          fetchBytes: () => api.downloadMonthlyParityExcel(
                            branchName: effectiveSingleBranch,
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
                              '$effectiveSingleBranch Workbook — $periodLabel',
                        ),
                      ),
                      _ExportActionBtn(
                        actionKey: 'am_br_co_csv',
                        busyKey: _busyExportKey,
                        icon: Icons.people_alt_outlined,
                        label: 'Officer Summary (.csv)',
                        tokens: tokens,
                        onPressed: () => _runExportAction(
                          actionKey: 'am_br_co_csv',
                          fetchBytes: () => api.downloadMonthlyParityCsv(
                            branchName: effectiveSingleBranch,
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
                        actionKey: 'am_br_loans_csv',
                        busyKey: _busyExportKey,
                        icon: Icons.file_download_outlined,
                        label: 'Branch Loans (.csv)',
                        tokens: tokens,
                        onPressed: () => _runExportAction(
                          actionKey: 'am_br_loans_csv',
                          fetchBytes: () => api.downloadCsv(
                            reportType: 'loans',
                            branchName: effectiveSingleBranch,
                            year: widget.selectedYear,
                            month: widget.selectedMonth,
                          ),
                          fileName:
                              '${cleanBranch}_Loans_${widget.selectedYear}_$monthPad.csv',
                          mimeType: 'text/csv',
                          shareInsteadOfSave: false,
                        ),
                      ),
                      _ExportActionBtn(
                        actionKey: 'am_br_repay_csv',
                        busyKey: _busyExportKey,
                        icon: Icons.file_download_outlined,
                        label: 'Branch Repayments (.csv)',
                        tokens: tokens,
                        onPressed: () => _runExportAction(
                          actionKey: 'am_br_repay_csv',
                          fetchBytes: () => api.downloadCsv(
                            reportType: 'repayments',
                            branchName: effectiveSingleBranch,
                            year: widget.selectedYear,
                            month: widget.selectedMonth,
                          ),
                          fileName:
                              '${cleanBranch}_Repayments_${widget.selectedYear}_$monthPad.csv',
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
      },
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

class _QueueFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final IcareSurfaceTokens tokens;
  final VoidCallback onTap;

  const _QueueFilterPill({
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
