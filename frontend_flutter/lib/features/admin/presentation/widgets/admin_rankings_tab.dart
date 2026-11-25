import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../data/datasources/admin_api_service.dart';
import '../../data/models/admin_dashboard_models.dart';
import '../admin_branch_detail_sheet.dart';
import '../admin_dashboard_screen.dart';
import 'admin_rankings_charts.dart';
import 'admin_responsive.dart';

class AdminRankingsTab extends ConsumerStatefulWidget {
  final AdminSize size;

  const AdminRankingsTab({
    super.key,
    required this.size,
  });

  @override
  ConsumerState<AdminRankingsTab> createState() => _AdminRankingsTabState();
}

class _AdminRankingsTabState extends ConsumerState<AdminRankingsTab> {
  /// 0 = Branches, 1 = Officers (used on compact screens to avoid long scrolling)
  int _compactSectionIndex = 0;
  bool _showAllOfficers = false;

  @override
  Widget build(BuildContext context) {
    final year = ref.watch(adminPerformanceYearProvider);
    final perfAsync = ref.watch(institutionPerformanceProvider(year));
    final currentYear = DateTime.now().year;
    final availableYears = [currentYear, currentYear - 1, currentYear - 2];
    final tokens = IcareSurfaceTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(tokens, year, availableYears),
        const SizedBox(height: 14),
        perfAsync.when(
          loading: () => const Column(
            children: [
              IcareSkeletonLoader(height: 200),
              SizedBox(height: 14),
              IcareSkeletonLoader(height: 200),
            ],
          ),
          error: (err, _) {
            final errorDetails = AppErrorDetails.from(err);
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.dangerBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.dangerBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: tokens.dangerDot,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${errorDetails.title}: ${errorDetails.message}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: tokens.dangerText,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(institutionPerformanceProvider(year)),
                    child: const Text(
                      'Retry',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          },
          data: (data) => _buildRankingsContent(context, tokens, data, widget.size),
        ),
      ],
    );
  }

  Widget _buildToolbar(
      IcareSurfaceTokens tokens, int selectedYear, List<int> availableYears) {
    return IcareCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Branch & Officer League Rankings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Ranked by loans disbursed, on-time payments, and overdue recovery',
                style: TextStyle(fontSize: 11, color: tokens.textMuted),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Year:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              for (final y in availableYears) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => ref
                        .read(adminPerformanceYearProvider.notifier)
                        .state = y,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: y == selectedYear
                            ? tokens.brandPrimaryDark
                            : tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: y == selectedYear
                              ? tokens.brandPrimaryDark
                              : tokens.borderSubtle,
                        ),
                      ),
                      child: Text(
                        '$y',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: y == selectedYear
                              ? Colors.white
                              : tokens.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankingsContent(
    BuildContext context,
    IcareSurfaceTokens tokens,
    InstitutionPerformanceModel data,
    AdminSize size,
  ) {
    final branches = data.branchRankings;
    final officers = data.officerRankings;
    final chartsSection = AdminRankingsAnalyticsSection(
      performance: data,
      size: size,
    );

    if (size.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          chartsSection,
          const SizedBox(height: 14),
          _buildCompactSubToggle(tokens, branches.length, officers.length),
          const SizedBox(height: 12),
          if (_compactSectionIndex == 0)
            _buildBranchesCardSection(context, tokens, branches, columns: 1)
          else
            _buildOfficersCardSection(tokens, officers, columns: 1, initialLimit: 5),
        ],
      );
    }

    if (size.isMedium) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          chartsSection,
          const SizedBox(height: 18),
          _buildBranchesCardSection(context, tokens, branches, columns: 2),
          const SizedBox(height: 18),
          _buildOfficersCardSection(tokens, officers, columns: 2, initialLimit: 6),
        ],
      );
    }

    // Expanded (>= 1024px): Charts ribbon above side-by-side 2-column leaderboards
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chartsSection,
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildBranchesCardSection(context, tokens, branches, columns: 1),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _buildOfficersCardSection(
                tokens,
                officers,
                columns: 1,
                initialLimit: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactSubToggle(
      IcareSurfaceTokens tokens, int branchCount, int officerCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _compactSectionIndex = 0),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _compactSectionIndex == 0
                      ? tokens.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Branches ($branchCount)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _compactSectionIndex == 0
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _compactSectionIndex == 0
                        ? tokens.textPrimary
                        : tokens.textMuted,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _compactSectionIndex = 1),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _compactSectionIndex == 1
                      ? tokens.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Credit Officers ($officerCount)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _compactSectionIndex == 1
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _compactSectionIndex == 1
                        ? tokens.textPrimary
                        : tokens.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchesCardSection(
    BuildContext context,
    IcareSurfaceTokens tokens,
    List<BranchPerformanceItemModel> branches, {
    required int columns,
  }) {
    return IcareCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Branch Performance Rankings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              Text(
                'Tap branch for detail',
                style: TextStyle(fontSize: 11, color: tokens.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (branches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No branch rankings available for this year.',
                  style: TextStyle(fontSize: 12, color: tokens.textLight),
                ),
              ),
            )
          else
            AdminResponsiveGrid(
              columns: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 10,
              children: branches
                  .map((b) => _buildBranchRankCard(context, tokens, b))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildBranchRankCard(
    BuildContext context,
    IcareSurfaceTokens tokens,
    BranchPerformanceItemModel b,
  ) {
    final score = b.compositeScore.clamp(0.0, 100.0);
    final isParHigh = b.parPct > 10.0;

    return IcareTactileScale(
      child: InkWell(
        onTap: () => AdminBranchDetailSheet.show(
          context,
          branchId: b.branchId,
          branchName: b.branchName,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: b.rank <= 3
                        ? tokens.brandPrimaryDark
                        : tokens.borderSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${b.rank}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: b.rank <= 3
                            ? Colors.white
                            : tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.branchName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Manager: ${b.bmName} • ${b.activeMembers} clients',
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.successBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.successBorder),
                  ),
                  child: Text(
                    'Overall ${score.toStringAsFixed(0)}/100',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tokens.successText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: tokens.textLight,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (score / 100.0).clamp(0.05, 1.0),
                minHeight: 5,
                backgroundColor: tokens.borderSubtle,
                valueColor:
                    AlwaysStoppedAnimation<Color>(tokens.successDot),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildMetricInline(
                  tokens,
                  'Disbursed',
                  CurrencyFormatter.format(b.disbPrincipal),
                  tokens.textPrimary,
                ),
                _buildMetricInline(
                  tokens,
                  'Late %',
                  '${b.parPct.toStringAsFixed(1)}%',
                  isParHigh ? tokens.dangerText : tokens.successText,
                ),
                _buildMetricInline(
                  tokens,
                  'Paid on time',
                  '${b.compliancePct.toStringAsFixed(0)}%',
                  tokens.brandPrimary,
                ),
                if (b.overdueRecovered > 0)
                  _buildMetricInline(
                    tokens,
                    'Recovered',
                    CurrencyFormatter.format(b.overdueRecovered),
                    tokens.infoText,
                  ),
              ],
            ),
            if (b.topOfficerName.isNotEmpty && b.topOfficerName != 'N/A') ...[
              const SizedBox(height: 6),
              Text(
                'Top officer: ${b.topOfficerName}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: tokens.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildOfficersCardSection(
    IcareSurfaceTokens tokens,
    List<OfficerPerformanceItemModel> officers, {
    required int columns,
    required int initialLimit,
  }) {
    final hasMore = officers.length > initialLimit;
    final displayed = _showAllOfficers
        ? officers
        : officers.take(initialLimit).toList();

    return IcareCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Credit Officer Rankings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              Text(
                '${officers.length} Officers',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (officers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No officer rankings available for this year.',
                  style: TextStyle(fontSize: 12, color: tokens.textLight),
                ),
              ),
            )
          else ...[
            AdminResponsiveGrid(
              columns: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 10,
              children: displayed
                  .map((o) => _buildOfficerRankCard(tokens, o))
                  .toList(),
            ),
            if (hasMore) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _showAllOfficers = !_showAllOfficers),
                  icon: Icon(
                    _showAllOfficers ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                  ),
                  label: Text(
                    _showAllOfficers
                        ? 'Show Top $initialLimit'
                        : 'Show All (${officers.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.brandPrimary,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildOfficerRankCard(
      IcareSurfaceTokens tokens, OfficerPerformanceItemModel o) {
    final score = o.compositeScore.clamp(0.0, 100.0);
    final isParHigh = o.parPct > 10.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: o.rank <= 3
                      ? tokens.brandPrimaryDark
                      : tokens.borderSubtle,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '#${o.rank}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: o.rank <= 3
                        ? Colors.white
                        : tokens.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.officerName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${o.branchName} • ${o.activeClients} borrowers',
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Overall ${score.toStringAsFixed(0)}/100',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.successText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 100.0).clamp(0.05, 1.0),
              minHeight: 4,
              backgroundColor: tokens.borderSubtle,
              valueColor:
                  AlwaysStoppedAnimation<Color>(tokens.successDot),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildMetricInline(
                tokens,
                'Disbursed',
                CurrencyFormatter.format(o.disbPrincipal),
                tokens.textPrimary,
              ),
              _buildMetricInline(
                tokens,
                'Late %',
                '${o.parPct.toStringAsFixed(1)}%',
                isParHigh ? tokens.dangerText : tokens.successText,
              ),
              _buildMetricInline(
                tokens,
                'Paid on time',
                '${o.compliancePct.toStringAsFixed(0)}%',
                tokens.brandPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricInline(
      IcareSurfaceTokens tokens, String label, String value, Color valueColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 11, color: tokens.textMuted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
