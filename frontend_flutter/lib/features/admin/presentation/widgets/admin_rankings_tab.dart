import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../data/datasources/admin_api_service.dart';
import '../../data/models/admin_dashboard_models.dart';
import '../admin_branch_detail_sheet.dart';
import '../admin_dashboard_screen.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(year, availableYears),
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
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${errorDetails.title}: ${errorDetails.message}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF991B1B),
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
          data: (data) => _buildRankingsContent(context, data, widget.size),
        ),
      ],
    );
  }

  Widget _buildToolbar(int selectedYear, List<int> availableYears) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Branch & Officer League Rankings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Ranked by loans disbursed, on-time payments, and overdue recovery',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Year:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
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
                            ? const Color(0xFF022C22)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: y == selectedYear
                              ? const Color(0xFF022C22)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        '$y',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: y == selectedYear
                              ? Colors.white
                              : const Color(0xFF475569),
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
    InstitutionPerformanceModel data,
    AdminSize size,
  ) {
    final branches = data.branchRankings;
    final officers = data.officerRankings;

    if (size.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCompactSubToggle(branches.length, officers.length),
          const SizedBox(height: 12),
          if (_compactSectionIndex == 0)
            _buildBranchesCardSection(context, branches, columns: 1)
          else
            _buildOfficersCardSection(officers, columns: 1, initialLimit: 5),
        ],
      );
    }

    if (size.isMedium) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBranchesCardSection(context, branches, columns: 2),
          const SizedBox(height: 18),
          _buildOfficersCardSection(officers, columns: 2, initialLimit: 6),
        ],
      );
    }

    // Expanded (>= 1024px): Side-by-side 2-column layout
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildBranchesCardSection(context, branches, columns: 1),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _buildOfficersCardSection(
            officers,
            columns: 1,
            initialLimit: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSubToggle(int branchCount, int officerCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      ? Colors.white
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
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
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
                      ? Colors.white
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
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
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
    List<BranchPerformanceItemModel> branches, {
    required int columns,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Branch Performance Rankings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                'Tap branch for detail',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (branches.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No branch rankings available for this year.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            AdminResponsiveGrid(
              columns: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 10,
              children: branches
                  .map((b) => _buildBranchRankCard(context, b))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildBranchRankCard(
    BuildContext context,
    BranchPerformanceItemModel b,
  ) {
    final score = b.compositeScore.clamp(0.0, 100.0);
    final isParHigh = b.parPct > 10.0;

    return InkWell(
      onTap: () => AdminBranchDetailSheet.show(
        context,
        branchId: b.branchId,
        branchName: b.branchName,
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        ? const Color(0xFF022C22)
                        : const Color(0xFFE2E8F0),
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
                            : const Color(0xFF475569),
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
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Manager: ${b.bmName} • ${b.activeMembers} clients',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
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
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    'Overall ${score.toStringAsFixed(0)}/100',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF047857),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (score / 100.0).clamp(0.05, 1.0),
                minHeight: 5,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildMetricInline(
                  'Disbursed',
                  CurrencyFormatter.format(b.disbPrincipal),
                  const Color(0xFF0F172A),
                ),
                _buildMetricInline(
                  'Late %',
                  '${b.parPct.toStringAsFixed(1)}%',
                  isParHigh
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF059669),
                ),
                _buildMetricInline(
                  'Paid on time',
                  '${b.compliancePct.toStringAsFixed(0)}%',
                  const Color(0xFF0F766E),
                ),
                if (b.overdueRecovered > 0)
                  _buildMetricInline(
                    'Recovered',
                    CurrencyFormatter.format(b.overdueRecovered),
                    const Color(0xFF0284C7),
                  ),
              ],
            ),
            if (b.topOfficerName.isNotEmpty && b.topOfficerName != 'N/A') ...[
              const SizedBox(height: 6),
              Text(
                'Top officer: ${b.topOfficerName}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOfficersCardSection(
    List<OfficerPerformanceItemModel> officers, {
    required int columns,
    required int initialLimit,
  }) {
    final hasMore = officers.length > initialLimit;
    final displayed = _showAllOfficers
        ? officers
        : officers.take(initialLimit).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Credit Officer Rankings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                '${officers.length} Officers',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (officers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No officer rankings available for this year.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else ...[
            AdminResponsiveGrid(
              columns: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 10,
              children: displayed.map(_buildOfficerRankCard).toList(),
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
                    foregroundColor: const Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildOfficerRankCard(OfficerPerformanceItemModel o) {
    final score = o.compositeScore.clamp(0.0, 100.0);
    final isParHigh = o.parPct > 10.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      ? const Color(0xFF022C22)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '#${o.rank}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: o.rank <= 3
                        ? Colors.white
                        : const Color(0xFF475569),
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${o.branchName} • ${o.activeClients} borrowers',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Overall ${score.toStringAsFixed(0)}/100',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF047857),
                  fontFeatures: [FontFeature.tabularFigures()],
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
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildMetricInline(
                'Disbursed',
                CurrencyFormatter.format(o.disbPrincipal),
                const Color(0xFF0F172A),
              ),
              _buildMetricInline(
                'Late %',
                '${o.parPct.toStringAsFixed(1)}%',
                isParHigh
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF059669),
              ),
              _buildMetricInline(
                'Paid on time',
                '${o.compliancePct.toStringAsFixed(0)}%',
                const Color(0xFF0F766E),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricInline(String label, String value, Color valueColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
