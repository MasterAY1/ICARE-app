import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_section_header.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../../data/datasources/audit_api_service.dart';
import '../../data/models/audit_models.dart';
import '../providers/audit_providers.dart';
import 'audit_shared_widgets.dart';

class AuditIntegrityTab extends ConsumerStatefulWidget {
  final String fallbackBranchId;
  final List<String> branchOptions;
  final String? Function(String selectedName) resolveBranchId;
  final bool canSwitchBranch;

  const AuditIntegrityTab({
    super.key,
    required this.fallbackBranchId,
    required this.branchOptions,
    required this.resolveBranchId,
    required this.canSwitchBranch,
  });

  @override
  ConsumerState<AuditIntegrityTab> createState() => _AuditIntegrityTabState();
}

class _AuditIntegrityTabState extends ConsumerState<AuditIntegrityTab> {
  String? _selectedBranchName;
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    if (widget.branchOptions.isNotEmpty &&
        (_selectedBranchName == null ||
            !widget.branchOptions.contains(_selectedBranchName))) {
      _selectedBranchName = widget.branchOptions.first;
    }

    final effectiveBranchId = (_selectedBranchName != null
            ? widget.resolveBranchId(_selectedBranchName!)
            : null) ??
        widget.fallbackBranchId;

    if (effectiveBranchId.isEmpty) {
      return buildAuditEmptyCard(
        context,
        'No active branch context resolved for 6-Way verification.',
      );
    }

    final query = Audit6WayQuery(
      branchId: effectiveBranchId,
      postingDate: formatAuditDate(_selectedDate),
    );
    final async6Way = ref.watch(integrity6WayProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IcareSectionHeader(
          title: '6-Way Financial Integrity Verification',
          subtitle: 'Mathematical cross-verification across Primary Vault Ledger, Audit Views, CO Cashbooks, Master Cashbook, Dashboard, and Reports.',
        ),
        const SizedBox(height: 12),
        IcareCard(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.canSwitchBranch && widget.branchOptions.isNotEmpty)
                SizedBox(
                  width: 220,
                  child: buildAuditDropdown(
                    context,
                    label: 'Target Branch',
                    value: _selectedBranchName ?? widget.branchOptions.first,
                    items: widget.branchOptions,
                    onChanged: (v) => setState(() => _selectedBranchName = v),
                  ),
                ),
              SizedBox(
                width: 190,
                child: buildAuditDatePicker(
                  context,
                  label: 'Operations Date',
                  value: _selectedDate,
                  onChanged: (d) => setState(() => _selectedDate = d),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        async6Way.when(
          loading: () =>
              const IcareTableSkeleton(rowCount: 6, hasFilterBar: false),
          error: (err, _) => buildAuditErrorCard(
            context,
            err,
            onRetry: () => ref.invalidate(integrity6WayProvider(query)),
          ),
          data: (data) {
            final isBal = data.isBalanced;
            final sources = [
              ('Ledger', data.ledgerTotal),
              ('Audit Views', data.auditViewsTotal),
              ('CO Cashbook', data.coCashbooksTotal),
              ('Master', data.masterCashbookTotal),
              ('Dashboard', data.dashboardTotal),
              ('Reports', data.reportsTotal),
            ];
            final maxVal = sources.fold<double>(
              0.0,
              (m, e) => math.max(m, e.$2.abs()),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IcareCard(
                  topAccentColor: isBal ? tokens.successDot : tokens.dangerDot,
                  backgroundColor: isBal ? tokens.successBg : tokens.dangerBg,
                  border: Border.all(
                    color: isBal ? tokens.successBorder : tokens.dangerBorder,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isBal ? Icons.verified_outlined : Icons.error_outline,
                        color: isBal ? tokens.successDot : tokens.dangerDot,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBal
                                  ? 'FINANCIAL INTEGRITY VERIFIED'
                                  : 'VARIANCE DETECTED ACROSS PROJECTIONS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: isBal
                                    ? tokens.successText
                                    : tokens.dangerText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data.statusText,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isBal
                                    ? tokens.successText
                                    : tokens.dangerText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IcareStatusBadge(
                        label: data.statusBadge,
                        variant: isBal
                            ? IcareBadgeVariant.success
                            : IcareBadgeVariant.danger,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                buildAuditKpiGrid([
                  AuditKpiItem(
                    'Primary Ledger',
                    formatAuditNaira(data.ledgerTotal),
                    highlightEmerald: true,
                    icon: Icons.account_balance_outlined,
                  ),
                  AuditKpiItem(
                    'Audit Views',
                    formatAuditNaira(data.auditViewsTotal),
                    topBorderColor: tokens.brandPrimary,
                  ),
                  AuditKpiItem(
                    'CO Cashbooks',
                    formatAuditNaira(data.coCashbooksTotal),
                    topBorderColor: tokens.infoDot,
                  ),
                  AuditKpiItem(
                    'Master Cashbook',
                    formatAuditNaira(data.masterCashbookTotal),
                    topBorderColor: tokens.brandPrimaryDark,
                  ),
                  AuditKpiItem(
                    'Dashboard / Reports',
                    formatAuditNaira(data.reportsTotal),
                    delta: 'Dash: ${formatAuditNaira(data.dashboardTotal)}',
                    topBorderColor: isBal ? tokens.successDot : tokens.dangerDot,
                  ),
                ]),
                const SizedBox(height: 14),
                IcareCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '6-Source Total Comparison (₦)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 205,
                        child: maxVal <= 0
                            ? Center(
                                child: Text(
                                  'Zero movement recorded across all 6 sources for ${data.postingDate}.',
                                  style: TextStyle(color: tokens.textMuted),
                                ),
                              )
                            : BarChart(
                                BarChartData(
                                  maxY: maxVal * 1.22,
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (_) => FlLine(
                                      color: tokens.borderSubtle,
                                      strokeWidth: 1,
                                      dashArray: const [4, 4],
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  barTouchData: BarTouchData(
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipColor: (_) =>
                                          tokens.surfaceElevated,
                                      getTooltipItem:
                                          (group, _, rod, __) {
                                        final item = sources[group.x];
                                        return BarTooltipItem(
                                          '${item.$1}\n${formatAuditNaira(item.$2)}',
                                          TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: tokens.textPrimary,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 52,
                                        getTitlesWidget: (v, _) => Text(
                                          v >= 1000
                                              ? '₦${(v / 1000).toStringAsFixed(0)}k'
                                              : '₦${v.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: tokens.textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 32,
                                        getTitlesWidget: (v, _) {
                                          final idx = v.toInt();
                                          if (idx < 0 ||
                                              idx >= sources.length) {
                                            return const SizedBox.shrink();
                                          }
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Text(
                                              sources[idx].$1,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: tokens.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  barGroups: List.generate(
                                    sources.length,
                                    (i) => BarChartGroupData(
                                      x: i,
                                      barRods: [
                                        BarChartRodData(
                                          toY: sources[i].$2.abs(),
                                          width: 24,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(6),
                                          ),
                                          color: i == 0
                                              ? tokens.brandPrimary
                                              : (isBal
                                                  ? tokens.successDot
                                                  : tokens.infoDot),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                if (data.variances.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const IcareSectionHeader(
                    title: 'Itemized Projection Variances',
                    subtitle: 'Detailed mismatch breakdown requiring review.',
                  ),
                  const SizedBox(height: 10),
                  buildAuditDataDisplay(
                    context,
                    forceCardView: false,
                    columns: const [
                      'Source',
                      'Expected',
                      'Actual',
                      'Variance',
                      'Cause',
                      'Status',
                    ],
                    records: data.variances
                        .map((v) => <String, dynamic>{
                              'Source': v.source,
                              'Expected': v.expected,
                              'Actual': v.actual,
                              'Variance': v.variance,
                              'Cause': v.cause,
                              'Status': 'MISMATCH',
                            })
                        .toList(),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class AuditExceptionsTab extends ConsumerWidget {
  final String? branchId;

  const AuditExceptionsTab({super.key, required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = IcareSurfaceTokens.of(context);
    final asyncExc = ref.watch(exceptionReportsProvider(branchId));

    return asyncExc.when(
      loading: () => const IcareTableSkeleton(rowCount: 8, hasFilterBar: false),
      error: (err, _) => buildAuditErrorCard(
        context,
        err,
        onRetry: () => ref.invalidate(exceptionReportsProvider(branchId)),
      ),
      data: (data) {
        final details = data.details;
        final cleanRules =
            details.values.where((list) => list.isEmpty).length;
        final breachedEntries = details.entries
            .where((e) => e.value.isNotEmpty)
            .toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));
        final maxIssue = breachedEntries.fold<int>(
          0,
          (m, e) => math.max(m, e.value.length),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IcareSectionHeader(
              title: 'Automated Audit Exception Controls',
              subtitle: 'Scans core ledgers and operational schedules for integrity breaches or unposted items.',
            ),
            const SizedBox(height: 14),
            buildAuditKpiGrid([
              AuditKpiItem(
                'Total Exceptions',
                '${data.totalExceptions}',
                delta: data.totalExceptions == 0
                    ? 'All automated rules passed'
                    : '${breachedEntries.length} rules flagged',
                isInverseDelta: data.totalExceptions > 0,
                topBorderColor: data.totalExceptions > 0
                    ? tokens.dangerDot
                    : tokens.successDot,
                icon: Icons.warning_amber_rounded,
              ),
              AuditKpiItem(
                'Rules Evaluated',
                '${data.exceptionRulesEvaluated}',
                highlightEmerald: true,
                icon: Icons.rule_folder_outlined,
              ),
              AuditKpiItem(
                'Passing Controls',
                '$cleanRules',
                topBorderColor: tokens.successDot,
                icon: Icons.check_circle_outline,
              ),
            ]),
            if (breachedEntries.isNotEmpty) ...[
              const SizedBox(height: 14),
              IcareCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flagged Exception Volume by Rule',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 165,
                      child: BarChart(
                        BarChartData(
                          maxY: (maxIssue * 1.25).ceilToDouble() + 1,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: tokens.borderSubtle,
                              strokeWidth: 1,
                              dashArray: const [4, 4],
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (v, _) => Text(
                                  v.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: tokens.textMuted,
                                  ),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                getTitlesWidget: (v, _) {
                                  final idx = v.toInt();
                                  if (idx < 0 ||
                                      idx >= breachedEntries.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final label = breachedEntries[idx]
                                      .key
                                      .replaceAll('_', ' ')
                                      .split(' ')
                                      .take(2)
                                      .join(' ');
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: tokens.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: List.generate(
                            breachedEntries.length,
                            (i) => BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: breachedEntries[i]
                                      .value
                                      .length
                                      .toDouble(),
                                  width: 24,
                                  color: tokens.dangerDot,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            ...details.entries.map((entry) {
              final ruleTitle = entry.key
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map((w) => w.isNotEmpty
                      ? '${w[0].toUpperCase()}${w.substring(1)}'
                      : '')
                  .join(' ');
              final issues = entry.value;
              final count = issues.length;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: IcareCard(
                  padding: EdgeInsets.zero,
                  border: Border.all(
                    color: count > 0
                        ? tokens.dangerBorder
                        : tokens.borderSubtle,
                  ),
                  child: ExpansionTile(
                    leading: Icon(
                      count > 0
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      color:
                          count > 0 ? tokens.dangerDot : tokens.successDot,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ruleTitle,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: count > 0
                                  ? tokens.dangerText
                                  : tokens.textPrimary,
                            ),
                          ),
                        ),
                        IcareStatusBadge(
                          label: count == 0 ? 'Clear' : '$count issues',
                          variant: count == 0
                              ? IcareBadgeVariant.success
                              : IcareBadgeVariant.danger,
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: count == 0
                            ? Text(
                                'Zero exceptions detected for this rule.',
                                style: TextStyle(
                                  color: tokens.successText,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : buildAuditDataDisplay(
                                context,
                                forceCardView: false,
                                records: issues,
                                columns: issues.first.keys.take(7).toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class AuditInsightsTab extends ConsumerWidget {
  final String? branchId;

  const AuditInsightsTab({super.key, required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = IcareSurfaceTokens.of(context);
    final asyncRisk = ref.watch(performanceInsightsProvider(branchId));

    return asyncRisk.when(
      loading: () => const IcareTableSkeleton(rowCount: 6, hasFilterBar: false),
      error: (err, _) => buildAuditErrorCard(
        context,
        err,
        onRetry: () => ref.invalidate(performanceInsightsProvider(branchId)),
      ),
      data: (res) {
        final dist = res.distribution;
        final total = dist['total_clients'] ?? 0;
        final tiers = [
          ('Excellent', dist['EXCELLENT'] ?? 0, tokens.successDot),
          ('Good', dist['GOOD'] ?? 0, tokens.brandPrimary),
          ('Fair', dist['FAIR'] ?? 0, tokens.infoDot),
          ('Risky', dist['RISKY'] ?? 0, tokens.warningDot),
          ('High Risk', dist['HIGH_RISK'] ?? 0, tokens.dangerDot),
        ];

        final totalTierSum = tiers.fold<int>(0, (s, t) => s + t.$2);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IcareSectionHeader(
              title: 'Portfolio Risk Rating & Performance Insights',
              subtitle: 'Live 5-tier borrower quality distribution calculated from repayment punctuality and overdue exposure.',
            ),
            const SizedBox(height: 14),
            buildAuditKpiGrid([
              AuditKpiItem(
                'Borrowers Audited',
                '$total',
                highlightEmerald: true,
                icon: Icons.groups_outlined,
              ),
              AuditKpiItem(
                'Excellent',
                '${tiers[0].$2}',
                topBorderColor: tokens.successDot,
              ),
              AuditKpiItem(
                'Good',
                '${tiers[1].$2}',
                topBorderColor: tokens.brandPrimary,
              ),
              AuditKpiItem(
                'Fair',
                '${tiers[2].$2}',
                topBorderColor: tokens.infoDot,
              ),
              AuditKpiItem(
                'Risky',
                '${tiers[3].$2}',
                topBorderColor: tokens.warningDot,
                isInverseDelta: tiers[3].$2 > 0,
              ),
              AuditKpiItem(
                'High Risk',
                '${tiers[4].$2}',
                topBorderColor: tokens.dangerDot,
                isInverseDelta: tiers[4].$2 > 0,
              ),
            ]),
            const SizedBox(height: 16),
            IcareCard(
              padding: const EdgeInsets.all(18),
              child: totalTierSum <= 0
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Text(
                          'No scored client loans exist for this scope yet.',
                          style: TextStyle(color: tokens.textMuted),
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 680;
                        final pieWidget = SizedBox(
                          height: 210,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 48,
                              sections: tiers
                                  .where((t) => t.$2 > 0)
                                  .map(
                                    (t) => PieChartSectionData(
                                      value: t.$2.toDouble(),
                                      color: t.$3,
                                      radius: 44,
                                      title:
                                          '${((t.$2 / totalTierSum) * 100).toStringAsFixed(0)}%',
                                      titleStyle: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        );

                        final legendWidget = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: tiers.map((t) {
                            final pct = totalTierSum > 0
                                ? (t.$2 / totalTierSum)
                                : 0.0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: t.$3,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          t.$1,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: tokens.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${t.$2} (${(pct * 100).toStringAsFixed(1)}%)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: tokens.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(999),
                                    backgroundColor: tokens.surfaceSubtle,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(t.$3),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );

                        if (isMobile) {
                          return Column(
                            children: [
                              pieWidget,
                              const SizedBox(height: 16),
                              legendWidget,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(flex: 5, child: pieWidget),
                            const SizedBox(width: 24),
                            Expanded(flex: 7, child: legendWidget),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class AuditWizardTab extends ConsumerStatefulWidget {
  final bool isAdmin;
  final bool isDirector;
  final String fallbackBranchId;
  final List<String> branchOptions;
  final String? Function(String selectedName) resolveBranchId;

  const AuditWizardTab({
    super.key,
    required this.isAdmin,
    required this.isDirector,
    required this.fallbackBranchId,
    required this.branchOptions,
    required this.resolveBranchId,
  });

  @override
  ConsumerState<AuditWizardTab> createState() => _AuditWizardTabState();
}

class _AuditWizardTabState extends ConsumerState<AuditWizardTab> {
  String? _selectedBranchName;
  DateTime _rwDate = DateTime.now();
  bool _repairing = false;
  ReconciliationRepairResponseModel? _repairResult;
  String? _bannerMsg;
  bool _bannerIsErr = false;

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    if (!widget.isAdmin || widget.isDirector) {
      return IcareCard(
        topAccentColor: tokens.dangerDot,
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: tokens.dangerDot, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Projection repair is restricted strictly to Administrators. Executive Directors have read-only audit oversight.',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.dangerText,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.branchOptions.isNotEmpty &&
        (_selectedBranchName == null ||
            !widget.branchOptions.contains(_selectedBranchName))) {
      _selectedBranchName = widget.branchOptions.first;
    }
    final targetBranchId = (_selectedBranchName != null
            ? widget.resolveBranchId(_selectedBranchName!)
            : null) ??
        widget.fallbackBranchId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IcareSectionHeader(
          title: 'Guided Projection Reconciliation Wizard',
          subtitle: 'Rebuilds derived Officer and Master Cashbook projections deterministically from Primary Vault Ledger events.',
        ),
        const SizedBox(height: 14),
        if (_bannerMsg != null) ...[
          IcareCard(
            topAccentColor:
                _bannerIsErr ? tokens.dangerDot : tokens.successDot,
            backgroundColor: _bannerIsErr ? tokens.dangerBg : tokens.successBg,
            child: Row(
              children: [
                Icon(
                  _bannerIsErr
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  color: _bannerIsErr ? tokens.dangerDot : tokens.successDot,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _bannerMsg!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          _bannerIsErr ? tokens.dangerText : tokens.successText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        IcareCard(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.branchOptions.isNotEmpty)
                SizedBox(
                  width: 220,
                  child: buildAuditDropdown(
                    context,
                    label: 'Target Branch',
                    value: _selectedBranchName ?? widget.branchOptions.first,
                    items: widget.branchOptions,
                    onChanged: (v) => setState(() => _selectedBranchName = v),
                  ),
                ),
              SizedBox(
                width: 190,
                child: buildAuditDatePicker(
                  context,
                  label: 'Reconciliation Date',
                  value: _rwDate,
                  onChanged: (d) => setState(() => _rwDate = d),
                ),
              ),
              ElevatedButton.icon(
                onPressed: (_repairing || targetBranchId.isEmpty)
                    ? null
                    : () => _confirmAndRepair(targetBranchId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                icon: _repairing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.auto_fix_high, size: 18),
                label: Text(
                  _repairing
                      ? 'Rebuilding Projections...'
                      : 'Run Guided Projection Repair',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        if (_repairResult != null) ...[
          const SizedBox(height: 16),
          const IcareSectionHeader(
            title: 'Post-Repair 6-Way Verification',
            subtitle: 'Live cross-check executed immediately after rebuild.',
          ),
          const SizedBox(height: 10),
          buildAuditKpiGrid([
            AuditKpiItem(
              'Ledger Total',
              formatAuditNaira(_repairResult!.verificationAfterRepair.ledgerTotal),
              highlightEmerald: true,
            ),
            AuditKpiItem(
              'CO Cashbooks',
              formatAuditNaira(
                  _repairResult!.verificationAfterRepair.coCashbooksTotal),
              delta: '${_repairResult!.rebuiltOfficerCount} rebuilt',
            ),
            AuditKpiItem(
              'Master Cashbook',
              formatAuditNaira(
                  _repairResult!.verificationAfterRepair.masterCashbookTotal),
              delta: _repairResult!.masterCashbookRebuilt
                  ? 'Master rebuilt'
                  : 'No master change',
            ),
            AuditKpiItem(
              'Integrity Status',
              _repairResult!.verificationAfterRepair.statusBadge,
              topBorderColor:
                  _repairResult!.verificationAfterRepair.isBalanced
                      ? tokens.successDot
                      : tokens.dangerDot,
            ),
          ]),
        ],
      ],
    );
  }

  Future<void> _confirmAndRepair(String targetBranchId) async {
    bool ack = false;
    final confirmed = await showIcareDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final tokens = IcareSurfaceTokens.of(ctx);
          return AlertDialog(
            backgroundColor: tokens.surfaceElevated,
            title: Row(
              children: [
                Icon(Icons.auto_fix_high, color: tokens.dangerDot),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Confirm Projection Repair',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This rebuilds CO Cashbooks and Master Cashbook projections for ${_selectedBranchName ?? 'selected branch'} on ${formatAuditDate(_rwDate)} from immutable ledger transactions.',
                    style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: ack,
                    onChanged: (v) => setModalState(() => ack = v ?? false),
                    title: Text(
                      'I confirm I want to regenerate cashbook projections for this date.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: ack ? () => Navigator.of(ctx).pop(true) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm Repair'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    setState(() => _repairing = true);
    try {
      final res = await ref
          .read(auditApiServiceProvider)
          .executeReconciliationRepair(
            branchId: targetBranchId,
            reconciliationDate: formatAuditDate(_rwDate),
          );
      invalidateAllAuditProviders(ref);
      if (mounted) {
        setState(() {
          _repairResult = res;
          _bannerMsg =
              'Projection repair complete: rebuilt ${res.rebuiltOfficerCount} officer cashbook(s).';
          _bannerIsErr = false;
          _repairing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bannerMsg =
              'Projection repair failed: ${AppErrorDetails.from(e).message}';
          _bannerIsErr = true;
          _repairing = false;
        });
      }
    }
  }
}
