import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_controller.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/auth/role_utils.dart';
import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_data_table.dart';
import '../../../../core/widgets/icare_metric_card.dart';
import '../../../../core/widgets/icare_section_header.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../data/datasources/user_management_api_service.dart';
import '../../data/models/user_management_models.dart';
import '../providers/user_management_providers.dart';
import 'um_shared_widgets.dart';

class UmDirectoryTab extends ConsumerStatefulWidget {
  final bool isAdmin;
  final bool isBm;
  final bool isAm;
  final UmFlashCallback onFlash;

  const UmDirectoryTab({
    super.key,
    required this.isAdmin,
    required this.isBm,
    required this.isAm,
    required this.onFlash,
  });

  @override
  ConsumerState<UmDirectoryTab> createState() => _UmDirectoryTabState();
}

class _UmDirectoryTabState extends ConsumerState<UmDirectoryTab> {
  final _searchCtrl = TextEditingController();
  String _selectedBranchFilter = 'ALL';
  String _statusRoleFilter = 'ALL';
  bool _isMutating = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final asyncUsers = ref.watch(userDirectoryProvider);
    final authState = ref.watch(authControllerProvider);
    final currentUid =
        authState is AuthStateAuthenticated ? authState.user.id : null;

    return asyncUsers.when(
      loading: () => const IcareTableSkeleton(rowCount: 7, hasFilterBar: true),
      error: (err, _) => buildUmErrorCard(
        context,
        err,
        onRetry: () => ref.invalidate(userDirectoryProvider),
      ),
      data: (data) {
        final scopedUsers = filterScopedUsers(
          data.users,
          isBm: widget.isBm,
          isAm: widget.isAm,
          currentUserId: currentUid,
        );

        final branchNames = <String>{
          ...data.availableBranches
              .map((b) => b.name.trim())
              .where((b) => b.isNotEmpty),
          ...scopedUsers
              .map((u) => (u.branchName ?? '').trim())
              .where((b) => b.isNotEmpty),
        }.toList()
          ..sort();

        if (_selectedBranchFilter != 'ALL' &&
            !branchNames.any(
              (b) => b.toLowerCase() == _selectedBranchFilter.toLowerCase(),
            )) {
          _selectedBranchFilter = 'ALL';
        }

        final q = _searchCtrl.text.trim().toLowerCase();
        final filtered = scopedUsers.where((u) {
          if (_selectedBranchFilter != 'ALL' &&
              (u.branchName ?? '').trim().toLowerCase() !=
                  _selectedBranchFilter.trim().toLowerCase()) {
            return false;
          }
          if (_statusRoleFilter == 'ACTIVE' && !u.isActive) return false;
          if (_statusRoleFilter == 'INACTIVE' && u.isActive) return false;
          if (_statusRoleFilter == 'CO' && !IcareRoleUtils.isCo(u.role)) {
            return false;
          }
          if (_statusRoleFilter == 'BM' && !IcareRoleUtils.isBm(u.role)) {
            return false;
          }
          if (_statusRoleFilter == 'AM' && !IcareRoleUtils.isAm(u.role)) {
            return false;
          }
          if (q.isNotEmpty) {
            return u.fullName.toLowerCase().contains(q) ||
                u.username.toLowerCase().contains(q) ||
                u.role.toLowerCase().contains(q) ||
                (u.branchName ?? '').toLowerCase().contains(q);
          }
          return true;
        }).toList();

        final activeCount = scopedUsers.where((u) => u.isActive).length;
        final inactiveCount = scopedUsers.length - activeCount;
        final coCount =
            scopedUsers.where((u) => IcareRoleUtils.isCo(u.role)).length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isMobile = width < 720;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IcareSectionHeader(
                  title: widget.isBm
                      ? 'Branch Staff Directory'
                      : (widget.isAm
                          ? 'Supervised Staff Directory'
                          : 'Enterprise User Directory'),
                  subtitle: widget.isBm
                      ? 'Inspect Credit Officer status, active sessions, and branch account access.'
                      : 'Manage user accounts, role distribution, session security, and operational status.',
                ),
                const SizedBox(height: 14),

                // KPI Metrics Strip
                _buildKpiGrid(
                  width: width,
                  total: scopedUsers.length,
                  active: activeCount,
                  inactive: inactiveCount,
                  officers: coCount,
                  tokens: tokens,
                ),
                const SizedBox(height: 14),

                // Live Role Distribution Chart
                if (scopedUsers.isNotEmpty) ...[
                  _buildRoleDistributionChart(scopedUsers, tokens, isMobile),
                  const SizedBox(height: 14),
                ],

                // Search & Filters Card
                IcareCard(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isMobile) ...[
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: umInputDecoration(
                            context,
                            hint: 'Search name, username, branch...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                        ),
                        if (!widget.isBm && branchNames.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildBranchDropdown(branchNames, tokens),
                        ],
                      ] else
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (_) => setState(() {}),
                                decoration: umInputDecoration(
                                  context,
                                  hint: 'Search by name, username, role, or branch...',
                                  prefixIcon: const Icon(Icons.search, size: 18),
                                  suffixIcon: _searchCtrl.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 16),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            if (!widget.isBm && branchNames.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _buildBranchDropdown(branchNames, tokens),
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip('ALL', 'All (${scopedUsers.length})'),
                            const SizedBox(width: 8),
                            _filterChip('ACTIVE', 'Active ($activeCount)'),
                            const SizedBox(width: 8),
                            _filterChip('INACTIVE', 'Inactive ($inactiveCount)'),
                            if (!widget.isBm) ...[
                              const SizedBox(width: 8),
                              _filterChip('CO', 'Officers'),
                              const SizedBox(width: 8),
                              _filterChip('BM', 'Managers'),
                            ],
                            if (widget.isAdmin) ...[
                              const SizedBox(width: 8),
                              _filterChip('AM', 'Area Managers'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                if (filtered.isEmpty)
                  buildUmInfoCard(
                    context,
                    scopedUsers.isEmpty
                        ? 'No user accounts match your supervisory scope.'
                        : 'No user accounts match the active search or filter criteria.',
                  )
                else if (isMobile)
                  Column(
                    children: filtered
                        .map((u) => _buildMobileUserCard(u, tokens))
                        .toList(),
                  )
                else
                  _buildDesktopTable(filtered, width, tokens),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildKpiGrid({
    required double width,
    required int total,
    required int active,
    required int inactive,
    required int officers,
    required IcareSurfaceTokens tokens,
  }) {
    final cards = [
      IcareMetricCard(
        label: widget.isBm ? 'Branch Staff' : 'Total Accounts',
        value: '$total',
        delta: 'Visible in current scope',
        icon: Icons.people_outline,
        isFullEmerald: true,
      ),
      IcareMetricCard(
        label: 'Active Access',
        value: '$active',
        delta: total > 0
            ? '${((active / total) * 100).toStringAsFixed(0)}% enabled'
            : '0% enabled',
        statusTextColor: tokens.successText,
        topBorderColor: tokens.successDot,
        icon: Icons.verified_user_outlined,
      ),
      IcareMetricCard(
        label: 'Deactivated',
        value: '$inactive',
        delta: inactive > 0 ? 'Requires admin review' : 'All accounts clear',
        statusTextColor:
            inactive > 0 ? tokens.dangerText : tokens.textPrimary,
        topBorderColor: inactive > 0 ? tokens.dangerDot : tokens.borderStrong,
        icon: Icons.block_outlined,
      ),
      IcareMetricCard(
        label: 'Credit Officers',
        value: '$officers',
        delta: 'Field collection officers',
        topBorderColor: tokens.brandPrimary,
        icon: Icons.badge_outlined,
      ),
    ];

    if (width >= 900) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards.map((card) {
        final itemWidth = width >= 540 ? (width - 12) / 2 : width;
        return SizedBox(width: itemWidth, child: card);
      }).toList(),
    );
  }

  Widget _buildRoleDistributionChart(
    List<UserListItemModel> users,
    IcareSurfaceTokens tokens,
    bool isMobile,
  ) {
    final counts = <String, int>{};
    for (final u in users) {
      final label = IcareRoleUtils.displayLabel(u.role);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = entries.fold<int>(0, (m, e) => math.max(m, e.value));

    return IcareCard(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: tokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Role Distribution Across Active Scope',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              Text(
                '${entries.length} roles',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: isMobile ? 165 : 185,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxCount > 0 ? (maxCount * 1.25).ceilToDouble() : 4,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1, (maxCount / 4).ceilToDouble()),
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: tokens.borderSubtle,
                    strokeWidth: 1,
                    dashArray: const [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => tokens.surfaceElevated,
                    getTooltipItem: (group, groupIdx, rod, rodIdx) {
                      final e = entries[group.x];
                      return BarTooltipItem(
                        '${e.key}\n${e.value} account${e.value == 1 ? '' : 's'}',
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
                      reservedSize: 28,
                      interval: math.max(1, (maxCount / 4).ceilToDouble()),
                      getTitlesWidget: (v, meta) => Text(
                        v.toInt().toString(),
                        style: TextStyle(fontSize: 10.5, color: tokens.textMuted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (v, meta) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= entries.length) {
                          return const SizedBox.shrink();
                        }
                        final raw = entries[idx].key;
                        final short = raw
                            .replaceAll('Branch Manager', 'BM')
                            .replaceAll('Area Manager', 'AM')
                            .replaceAll('Credit Officer', 'Officer')
                            .replaceAll('Procurement Officer', 'Procure')
                            .replaceAll('Account Manager', 'Acct Mgr');
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            short,
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
                barGroups: List.generate(entries.length, (i) {
                  final e = entries[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.toDouble(),
                        width: isMobile ? 20 : 28,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        color: umRoleBadgeColor(e.key, isDark: tokens.isDark),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchDropdown(
    List<String> branchNames,
    IcareSurfaceTokens tokens,
  ) {
    final items = ['ALL', ...branchNames];
    return DropdownButtonFormField<String>(
      value: _selectedBranchFilter,
      isExpanded: true,
      dropdownColor: tokens.surfaceElevated,
      decoration: umInputDecoration(context, label: 'Branch Filter'),
      items: items
          .map(
            (b) => DropdownMenuItem(
              value: b,
              child: Text(
                b == 'ALL' ? 'All Branches' : b,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (val) {
        if (val != null) setState(() => _selectedBranchFilter = val);
      },
    );
  }

  Widget _filterChip(String key, String label) {
    final tokens = IcareSurfaceTokens.of(context);
    final selected = _statusRoleFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: tokens.brandSoftBg,
      backgroundColor: tokens.surfaceSubtle,
      side: BorderSide(
        color: selected ? tokens.brandPrimary : tokens.borderSubtle,
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? tokens.brandPrimary : tokens.textSecondary,
      ),
      onSelected: (_) => setState(() => _statusRoleFilter = key),
    );
  }

  Widget _buildDesktopTable(
    List<UserListItemModel> users,
    double width,
    IcareSurfaceTokens tokens,
  ) {
    return IcareDataTable(
      minWidth: math.max(width - 4, 780),
      columns: const [
        DataColumn(label: Text('Staff Member')),
        DataColumn(label: Text('Username')),
        DataColumn(label: Text('Role')),
        DataColumn(label: Text('Branch')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Last Login')),
        DataColumn(label: Text('Actions')),
      ],
      rows: users.map((u) {
        final roleColor = umRoleBadgeColor(u.role, isDark: tokens.isDark);
        return DataRow(
          cells: [
            DataCell(
              InkWell(
                onTap: () => _openUserInspectorSheet(u),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: roleColor.withValues(alpha: 0.14),
                      child: Text(
                        umInitials(u.fullName.isNotEmpty ? u.fullName : u.username),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: roleColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 190),
                      child: Text(
                        u.fullName.isNotEmpty ? u.fullName : u.username,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            DataCell(
              Text(
                u.username,
                style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
              ),
            ),
            DataCell(umRoleBadge(context, u.role)),
            DataCell(Text(u.branchName?.isNotEmpty == true ? u.branchName! : 'Head Office')),
            DataCell(umActiveStatusBadge(u.isActive)),
            DataCell(
              Text(
                u.lastLogin?.isNotEmpty == true ? u.lastLogin! : 'Never',
                style: TextStyle(fontSize: 12, color: tokens.textMuted),
              ),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Inspect Account & Session Controls',
                    icon: Icon(Icons.manage_accounts_outlined,
                        size: 18, color: tokens.brandPrimary),
                    onPressed: () => _openUserInspectorSheet(u),
                  ),
                  IconButton(
                    tooltip: u.isActive ? 'Deactivate Account' : 'Activate Account',
                    icon: Icon(
                      u.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 18,
                      color: u.isActive ? tokens.warningDot : tokens.successDot,
                    ),
                    onPressed: _isMutating
                        ? null
                        : () => _handleToggleStatus(u.id, !u.isActive),
                  ),
                  IconButton(
                    tooltip: 'Revoke Active Sessions',
                    icon: Icon(Icons.logout_rounded,
                        size: 18, color: tokens.dangerDot),
                    onPressed:
                        _isMutating ? null : () => _handleRevokeSessions(u),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMobileUserCard(
    UserListItemModel u,
    IcareSurfaceTokens tokens,
  ) {
    final roleColor = umRoleBadgeColor(u.role, isDark: tokens.isDark);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IcareCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _openUserInspectorSheet(u),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: roleColor.withValues(alpha: 0.14),
                  child: Text(
                    umInitials(u.fullName.isNotEmpty ? u.fullName : u.username),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: roleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.fullName.isNotEmpty ? u.fullName : u.username,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: tokens.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${u.username}  •  ${u.branchName?.isNotEmpty == true ? u.branchName! : 'Head Office'}',
                        style: TextStyle(fontSize: 12, color: tokens.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                umActiveStatusBadge(u.isActive),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                umRoleBadge(context, u.role),
                Text(
                  'Last login: ${u.lastLogin?.isNotEmpty == true ? u.lastLogin! : 'Never'}',
                  style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                ),
              ],
            ),
            Divider(color: tokens.borderSubtle, height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openUserInspectorSheet(u),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Inspect', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton.icon(
                  onPressed: _isMutating
                      ? null
                      : () => _handleToggleStatus(u.id, !u.isActive),
                  icon: Icon(
                    u.isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: 14,
                  ),
                  label: Text(
                    u.isActive ? 'Deactivate' : 'Activate',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _isMutating ? null : () => _handleRevokeSessions(u),
                  icon: Icon(Icons.logout_rounded,
                      size: 14, color: tokens.dangerDot),
                  label: Text(
                    'Revoke',
                    style: TextStyle(fontSize: 12, color: tokens.dangerText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUserInspectorSheet(UserListItemModel u) async {
    final allowedProducts = (u.extraFields?['allowed_products'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    await showIcareAdaptiveSheet<void>(
      context: context,
      builder: (sheetCtx, isDialog) {
        final tokens = IcareSurfaceTokens.of(sheetCtx);
        return Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              borderRadius: isDialog
                  ? BorderRadius.circular(16)
                  : const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.fullName.isNotEmpty ? u.fullName : u.username,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Username: ${u.username}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontFamily: 'JetBrains Mono',
                                color: tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      umRoleBadge(sheetCtx, u.role),
                      umActiveStatusBadge(u.isActive),
                    ],
                  ),
                  Divider(color: tokens.borderSubtle, height: 24),
                  _detailRow(
                    tokens,
                    'Assigned Branch',
                    u.branchName?.isNotEmpty == true
                        ? u.branchName!
                        : 'Head Office / Multi-Branch',
                  ),
                  _detailRow(
                    tokens,
                    'Last Login',
                    u.lastLogin?.isNotEmpty == true ? u.lastLogin! : 'Never',
                  ),
                  _detailRow(
                    tokens,
                    'Created Date',
                    u.createdAt?.isNotEmpty == true ? u.createdAt! : 'Unavailable',
                  ),
                  if (allowedProducts.isNotEmpty)
                    _detailRow(
                      tokens,
                      'Assigned Loan Products',
                      allowedProducts.join(', '),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isMutating
                            ? null
                            : () {
                                Navigator.of(sheetCtx).pop();
                                _handleToggleStatus(u.id, !u.isActive);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.brandPrimaryDark,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(
                          u.isActive
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                          size: 16,
                        ),
                        label: Text(
                          u.isActive ? 'Deactivate Account' : 'Activate Account',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isMutating
                            ? null
                            : () {
                                Navigator.of(sheetCtx).pop();
                                _handleRevokeSessions(u);
                              },
                        icon: Icon(Icons.logout_rounded,
                            size: 16, color: tokens.warningDot),
                        label: Text(
                          'Revoke Active Sessions',
                          style: TextStyle(color: tokens.warningText),
                        ),
                      ),
                      if (widget.isAdmin)
                        OutlinedButton.icon(
                          onPressed: _isMutating
                              ? null
                              : () {
                                  Navigator.of(sheetCtx).pop();
                                  _promptDoubleConfirmDelete(u);
                                },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: tokens.dangerBorder),
                          ),
                          icon: Icon(Icons.delete_forever_outlined,
                              size: 16, color: tokens.dangerDot),
                          label: Text(
                            'Permanent Delete',
                            style: TextStyle(color: tokens.dangerText),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
    IcareSurfaceTokens tokens,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleToggleStatus(String userId, bool activate) async {
    setState(() => _isMutating = true);
    try {
      final res = await ref
          .read(userManagementApiServiceProvider)
          .toggleUserStatus(userId: userId, activate: activate);
      invalidateAllUserManagementProviders(ref);
      widget.onFlash(res.message, isError: false);
    } catch (e) {
      widget.onFlash(
        'Failed to update user status: ${AppErrorDetails.from(e).message}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _handleRevokeSessions(UserListItemModel u) async {
    final confirm = await showIcareDialog<bool>(
      context: context,
      builder: (ctx) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return AlertDialog(
          backgroundColor: tokens.surfaceElevated,
          title: Text(
            'Revoke Active Sessions',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          content: Text(
            'Immediately terminate all active authentication tokens for ${u.username} (${u.fullName})? They will be required to sign in again.',
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
              ),
              child: const Text('Revoke Sessions'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    setState(() => _isMutating = true);
    try {
      final res = await ref
          .read(userManagementApiServiceProvider)
          .revokeUserSessions(userId: u.id);
      invalidateAllUserManagementProviders(ref);
      widget.onFlash(res.message, isError: false);
    } catch (e) {
      widget.onFlash(
        'Failed to revoke sessions: ${AppErrorDetails.from(e).message}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _promptDoubleConfirmDelete(UserListItemModel u) async {
    final confirmCtrl = TextEditingController();
    bool ackPermanent = false;

    final approved = await showIcareDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final tokens = IcareSurfaceTokens.of(ctx);
            final canDelete = ackPermanent &&
                confirmCtrl.text.trim() == u.username.trim();
            return AlertDialog(
              backgroundColor: tokens.surfaceElevated,
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: tokens.dangerDot),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Permanently Delete ${u.username}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: tokens.dangerText,
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
                      'This permanently deletes account "${u.username}" (${u.fullName}). If historical financial records reference this user, deactivation should be used instead.',
                      style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: ackPermanent,
                      onChanged: (v) =>
                          setModalState(() => ackPermanent = v ?? false),
                      title: Text(
                        'I confirm permanent deletion is required.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Type "${u.username}" to unlock deletion:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: confirmCtrl,
                      onChanged: (_) => setModalState(() {}),
                      decoration: umInputDecoration(ctx, hint: u.username),
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
                  onPressed:
                      canDelete ? () => Navigator.of(ctx).pop(true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm Permanent Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    confirmCtrl.dispose();
    if (approved != true) return;

    setState(() => _isMutating = true);
    try {
      final res = await ref
          .read(userManagementApiServiceProvider)
          .deleteUserPermanently(userId: u.id);
      invalidateAllUserManagementProviders(ref);
      widget.onFlash(res.message, isError: false);
    } catch (e) {
      widget.onFlash(
        'Failed to delete user: ${AppErrorDetails.from(e).message}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }
}
