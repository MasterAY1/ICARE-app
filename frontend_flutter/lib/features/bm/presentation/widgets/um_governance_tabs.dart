import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_data_table.dart';
import '../../../../core/widgets/icare_metric_card.dart';
import '../../../../core/widgets/icare_section_header.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../../data/datasources/user_management_api_service.dart';
import '../providers/user_management_providers.dart';
import 'um_shared_widgets.dart';

class UmProductAssignmentTab extends ConsumerStatefulWidget {
  final UmFlashCallback onFlash;

  const UmProductAssignmentTab({super.key, required this.onFlash});

  @override
  ConsumerState<UmProductAssignmentTab> createState() =>
      _UmProductAssignmentTabState();
}

class _UmProductAssignmentTabState
    extends ConsumerState<UmProductAssignmentTab> {
  String? _selectedOfficerUsername;
  List<String> _selectedProducts = [];
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final asyncMeta = ref.watch(productAssignmentMetaProvider);

    return asyncMeta.when(
      loading: () => const IcareFormSkeleton(fieldCount: 4),
      error: (err, _) => buildUmErrorCard(
        context,
        err,
        onRetry: () => ref.invalidate(productAssignmentMetaProvider),
      ),
      data: (data) {
        final officers = data.creditOfficers;
        final products = data.availableProducts;

        if (officers.isEmpty) {
          return buildUmInfoCard(
            context,
            'No Credit Officers found in your scope for product assignment.',
          );
        }

        if (_selectedOfficerUsername == null ||
            !officers.any((o) => o.username == _selectedOfficerUsername)) {
          _selectedOfficerUsername = officers.first.username;
          _selectedProducts = List<String>.from(officers.first.allowedProducts);
        }

        final selectedOfficer = officers.firstWhere(
          (o) => o.username == _selectedOfficerUsername,
          orElse: () => officers.first,
        );

        return IcareCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IcareSectionHeader(
                title: 'Credit Officer Loan Product Access',
                subtitle: 'Restrict an officer to specific loan products or leave empty to allow all active products.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedOfficer.username,
                isExpanded: true,
                dropdownColor: tokens.surfaceElevated,
                decoration:
                    umInputDecoration(context, label: 'Select Credit Officer'),
                items: officers
                    .map(
                      (o) => DropdownMenuItem(
                        value: o.username,
                        child: Text(
                          '${o.username} — ${o.fullName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  final target = officers.firstWhere(
                    (o) => o.username == val,
                    orElse: () => officers.first,
                  );
                  setState(() {
                    _selectedOfficerUsername = target.username;
                    _selectedProducts =
                        List<String>.from(target.allowedProducts);
                  });
                },
              ),
              const SizedBox(height: 14),
              if (products.isEmpty)
                buildUmInfoCard(
                  context,
                  'No active loan products are currently configured in the catalog.',
                )
              else ...[
                Text(
                  'Permitted Loan Products (${_selectedProducts.isEmpty ? 'All Products Unrestricted' : '${_selectedProducts.length} selected'})',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: products.map((prod) {
                    final checked = _selectedProducts.contains(prod);
                    return FilterChip(
                      label: Text(prod),
                      selected: checked,
                      selectedColor: tokens.successBg,
                      backgroundColor: tokens.surfaceSubtle,
                      checkmarkColor: tokens.successText,
                      side: BorderSide(
                        color: checked
                            ? tokens.successBorder
                            : tokens.borderSubtle,
                      ),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            checked ? FontWeight.w700 : FontWeight.w500,
                        color: checked
                            ? tokens.successText
                            : tokens.textSecondary,
                      ),
                      onSelected: (on) {
                        setState(() {
                          if (on && !_selectedProducts.contains(prod)) {
                            _selectedProducts.add(prod);
                          } else if (!on) {
                            _selectedProducts.remove(prod);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(
                    _saving ? 'Saving...' : 'Save Product Assignments',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final uname = _selectedOfficerUsername;
    if (uname == null) return;
    setState(() => _saving = true);
    try {
      final res = await ref
          .read(userManagementApiServiceProvider)
          .assignProducts(
            username: uname,
            allowedProducts: _selectedProducts,
          );
      invalidateAllUserManagementProviders(ref);
      widget.onFlash(res.message, isError: false);
    } catch (e) {
      widget.onFlash(
        'Failed to assign products: ${AppErrorDetails.from(e).message}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class UmAmAssignmentsTab extends ConsumerStatefulWidget {
  final UmFlashCallback onFlash;

  const UmAmAssignmentsTab({super.key, required this.onFlash});

  @override
  ConsumerState<UmAmAssignmentsTab> createState() => _UmAmAssignmentsTabState();
}

class _UmAmAssignmentsTabState extends ConsumerState<UmAmAssignmentsTab> {
  String? _selectedAmId;
  List<String> _selectedBranchIds = [];
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final asyncAm = ref.watch(amAssignmentsProvider);

    return asyncAm.when(
      loading: () => const IcareFormSkeleton(fieldCount: 5),
      error: (err, _) => buildUmErrorCard(
        context,
        err,
        onRetry: () => ref.invalidate(amAssignmentsProvider),
      ),
      data: (data) {
        final ams = data.areaManagers;
        final branches = data.allBranches;

        if (ams.isEmpty) {
          return buildUmInfoCard(
            context,
            'No Area Managers registered yet. Provision an Area Manager under Create User first.',
          );
        }

        if (_selectedAmId == null ||
            !ams.any((a) => a.userId == _selectedAmId)) {
          _selectedAmId = ams.first.userId;
          _selectedBranchIds = List<String>.from(ams.first.assignedBranchIds);
        }

        final selectedAm = ams.firstWhere(
          (a) => a.userId == _selectedAmId,
          orElse: () => ams.first,
        );

        final count = _selectedBranchIds.length;
        final isCompliant = count >= 5 && count <= 7;

        return IcareCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IcareSectionHeader(
                title: 'Area Manager Supervisory Span',
                subtitle: 'Governance Policy: Each Area Manager supervises 5 to 7 active operational branches.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedAm.userId,
                isExpanded: true,
                dropdownColor: tokens.surfaceElevated,
                decoration:
                    umInputDecoration(context, label: 'Select Area Manager'),
                items: ams
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.userId,
                        child: Text(
                          '${a.username} — ${a.fullName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  final target = ams.firstWhere(
                    (a) => a.userId == val,
                    orElse: () => ams.first,
                  );
                  setState(() {
                    _selectedAmId = target.userId;
                    _selectedBranchIds =
                        List<String>.from(target.assignedBranchIds);
                  });
                },
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCompliant
                        ? tokens.successBorder
                        : tokens.warningBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Supervisory Span: $count of 5–7 Required Branches',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                        IcareStatusBadge(
                          label: isCompliant ? 'Compliant' : 'Requires 5–7',
                          variant: isCompliant
                              ? IcareBadgeVariant.success
                              : IcareBadgeVariant.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (count / 7).clamp(0.0, 1.0),
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(999),
                      backgroundColor: tokens.borderSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCompliant ? tokens.successDot : tokens.warningDot,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (branches.isEmpty)
                buildUmInfoCard(context, 'No active branches returned.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: branches.map((b) {
                    final selected = _selectedBranchIds.contains(b.branchId);
                    return FilterChip(
                      label: Text(b.name),
                      selected: selected,
                      selectedColor: tokens.brandSoftBg,
                      backgroundColor: tokens.surfaceSubtle,
                      checkmarkColor: tokens.brandPrimary,
                      side: BorderSide(
                        color: selected
                            ? tokens.brandPrimary
                            : tokens.borderSubtle,
                      ),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? tokens.brandPrimary
                            : tokens.textSecondary,
                      ),
                      onSelected: (on) {
                        setState(() {
                          if (on && !_selectedBranchIds.contains(b.branchId)) {
                            _selectedBranchIds.add(b.branchId);
                          } else if (!on) {
                            _selectedBranchIds.remove(b.branchId);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(
                    _saving ? 'Saving Assignments...' : 'Save Area Assignments',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final amId = _selectedAmId;
    if (amId == null) return;
    setState(() => _saving = true);
    try {
      final res = await ref
          .read(userManagementApiServiceProvider)
          .saveAmAssignments(amId: amId, branchIds: _selectedBranchIds);
      invalidateAllUserManagementProviders(ref);
      widget.onFlash(res.message, isError: false);
    } catch (e) {
      widget.onFlash(
        'Failed to save AM assignments: ${AppErrorDetails.from(e).message}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class UmBranchClosuresTab extends ConsumerStatefulWidget {
  final bool isAdmin;
  final bool isBm;
  final bool isAm;
  final String callerBranchName;
  final UmFlashCallback onFlash;

  const UmBranchClosuresTab({
    super.key,
    required this.isAdmin,
    required this.isBm,
    required this.isAm,
    required this.callerBranchName,
    required this.onFlash,
  });

  @override
  ConsumerState<UmBranchClosuresTab> createState() =>
      _UmBranchClosuresTabState();
}

class _UmBranchClosuresTabState extends ConsumerState<UmBranchClosuresTab> {
  final _reasonCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedBranchId;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final asyncClosures = ref.watch(branchClosuresProvider);

    return asyncClosures.when(
      loading: () => const IcareTableSkeleton(rowCount: 6, hasFilterBar: false),
      error: (err, _) => buildUmErrorCard(
        context,
        err,
        onRetry: () => ref.invalidate(branchClosuresProvider),
      ),
      data: (data) {
        final closures = data.closures;
        final branches = data.availableBranches;

        if (_selectedBranchId != null &&
            !branches.any((b) => b.branchId == _selectedBranchId)) {
          _selectedBranchId = null;
        }
        if (widget.isAm && _selectedBranchId == null && branches.isNotEmpty) {
          _selectedBranchId = branches.first.branchId;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 820;

            final formCard = IcareCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IcareSectionHeader(
                    title: 'Schedule Branch Closure',
                    subtitle: 'Automatically shifts scheduled loan repayments around non-operational dates.',
                  ),
                  const SizedBox(height: 14),
                  _dateField(
                    label: 'Start Date',
                    value: _startDate,
                    onPick: (d) => setState(() => _startDate = d),
                  ),
                  const SizedBox(height: 12),
                  _dateField(
                    label: 'End Date',
                    value: _endDate,
                    onPick: (d) => setState(() => _endDate = d),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reasonCtrl,
                    decoration: umInputDecoration(
                      context,
                      label: 'Reason / Holiday Title',
                      hint: 'e.g. Regional Public Holiday',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.isAdmin || widget.isAm) ...[
                    if (widget.isAm && branches.isEmpty)
                      buildUmInfoCard(
                        context,
                        'No assigned branches found for closure scheduling.',
                      )
                    else
                      DropdownButtonFormField<String?>(
                        value: _selectedBranchId,
                        isExpanded: true,
                        dropdownColor: tokens.surfaceElevated,
                        decoration: umInputDecoration(
                          context,
                          label: widget.isAm
                              ? 'Target Supervised Branch'
                              : 'Target Branch Scope',
                        ),
                        items: [
                          if (widget.isAdmin)
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Branches (Global Holiday)'),
                            ),
                          ...branches.map(
                            (b) => DropdownMenuItem<String?>(
                              value: b.branchId,
                              child: Text(b.name),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedBranchId = val),
                      ),
                  ] else
                    buildUmInfoCard(
                      context,
                      'Scoped Branch: ${widget.callerBranchName}',
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _createClosure,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.event_busy_outlined, size: 18),
                      label: Text(
                        _submitting ? 'Saving...' : 'Save Closure & Reschedule',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );

            final listCard = IcareCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IcareSectionHeader(
                    title: 'Configured Closures',
                    subtitle: '${closures.length} scheduled non-working window${closures.length == 1 ? '' : 's'}',
                  ),
                  const SizedBox(height: 14),
                  if (closures.isEmpty)
                    buildUmInfoCard(context, 'No branch closures recorded.')
                  else if (isMobile)
                    Column(
                      children: closures.map((c) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: IcareCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.reason,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${c.startDate} to ${c.endDate} • ${c.branchName ?? 'Global'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: tokens.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: tokens.dangerDot,
                                  ),
                                  onPressed: () => _deleteClosure(c.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    IcareDataTable(
                      minWidth: 500,
                      columns: const [
                        DataColumn(label: Text('Start Date')),
                        DataColumn(label: Text('End Date')),
                        DataColumn(label: Text('Reason')),
                        DataColumn(label: Text('Branch')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: closures.map((c) {
                        return DataRow(
                          cells: [
                            DataCell(Text(c.startDate)),
                            DataCell(Text(c.endDate)),
                            DataCell(Text(c.reason)),
                            DataCell(
                              IcareStatusBadge(
                                label: c.branchName ?? 'Global',
                                variant: (c.branchId == null ||
                                        c.branchId!.isEmpty)
                                    ? IcareBadgeVariant.info
                                    : IcareBadgeVariant.neutral,
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: tokens.dangerDot,
                                ),
                                onPressed: () => _deleteClosure(c.id),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                ],
              ),
            );

            if (isMobile) {
              return Column(
                children: [
                  formCard,
                  const SizedBox(height: 14),
                  listCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: formCard),
                const SizedBox(width: 16),
                Expanded(flex: 7, child: listCard),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPick,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: umInputDecoration(
          context,
          label: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
        ),
        child: Text(
          value != null ? DateFormat('yyyy-MM-dd').format(value) : 'Select date',
          style: TextStyle(
            fontSize: 13.5,
            color: value != null ? tokens.textPrimary : tokens.textLight,
          ),
        ),
      ),
    );
  }

  Future<void> _createClosure() async {
    final s = _startDate;
    final e = _endDate;
    final reason = _reasonCtrl.text.trim();
    if (s == null || e == null || reason.isEmpty) {
      widget.onFlash(
        'Select both start and end dates and provide a closure reason.',
        isError: true,
      );
      return;
    }
    if (widget.isAm && _selectedBranchId == null) {
      widget.onFlash(
        'Select a target supervised branch.',
        isError: true,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final res =
          await ref.read(userManagementApiServiceProvider).createBranchClosure(
                startDate: DateFormat('yyyy-MM-dd').format(s),
                endDate: DateFormat('yyyy-MM-dd').format(e),
                reason: reason,
                branchId: _selectedBranchId,
              );
      _reasonCtrl.clear();
      setState(() {
        _startDate = null;
        _endDate = null;
      });
      invalidateAllUserManagementProviders(ref);
      widget.onFlash(
        '${res.message} (${res.rescheduledLoans} installments adjusted)',
        isError: false,
      );
    } catch (err) {
      widget.onFlash(
        'Failed to create closure: ${AppErrorDetails.from(err).message}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteClosure(String closureId) async {
    final confirm = await showIcareDialog<bool>(
      context: context,
      builder: (ctx) {
        final tokens = IcareSurfaceTokens.of(ctx);
        return AlertDialog(
          backgroundColor: tokens.surfaceElevated,
          title: Text(
            'Remove Branch Closure',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          content: Text(
            'Delete this custom branch closure entry?',
            style: TextStyle(color: tokens.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    try {
      final res = await ref
          .read(userManagementApiServiceProvider)
          .deleteBranchClosure(closureId: closureId);
      invalidateAllUserManagementProviders(ref);
      widget.onFlash(res.message, isError: false);
    } catch (err) {
      widget.onFlash(
        'Failed to delete closure: ${AppErrorDetails.from(err).message}',
        isError: true,
      );
    }
  }
}

class UmAuditLogsTab extends ConsumerStatefulWidget {
  final bool isBm;
  final String branchName;

  const UmAuditLogsTab({
    super.key,
    required this.isBm,
    required this.branchName,
  });

  @override
  ConsumerState<UmAuditLogsTab> createState() => _UmAuditLogsTabState();
}

class _UmAuditLogsTabState extends ConsumerState<UmAuditLogsTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final asyncLogs = ref.watch(userAuditLogsProvider);

    return asyncLogs.when(
      loading: () => const IcareTableSkeleton(rowCount: 7, hasFilterBar: true),
      error: (err, _) => buildUmErrorCard(
        context,
        err,
        onRetry: () => ref.invalidate(userAuditLogsProvider),
      ),
      data: (data) {
        final q = _searchCtrl.text.trim().toLowerCase();
        final logs = data.logs.where((l) {
          if (q.isEmpty) return true;
          return l.username.toLowerCase().contains(q) ||
              l.action.toLowerCase().contains(q) ||
              (l.branch ?? '').toLowerCase().contains(q) ||
              (l.module ?? '').toLowerCase().contains(q);
        }).toList();

        final moduleCounts = <String, int>{};
        for (final l in logs) {
          final mod = (l.module?.isNotEmpty == true ? l.module! : l.action)
              .split('_')
              .first;
          moduleCounts[mod] = (moduleCounts[mod] ?? 0) + 1;
        }
        final topModules = moduleCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final displayModules = topModules.take(6).toList();
        final maxVal =
            displayModules.fold<int>(0, (m, e) => math.max(m, e.value));

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 740;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IcareSectionHeader(
                  title: widget.isBm
                      ? '${widget.branchName} Activity Audit Logs'
                      : 'System Activity Audit Logs',
                  subtitle: '${logs.length} scoped event record${logs.length == 1 ? '' : 's'}',
                ),
                const SizedBox(height: 12),
                if (displayModules.isNotEmpty) ...[
                  IcareCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top Activity Categories',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 145,
                          child: BarChart(
                            BarChartData(
                              maxY: maxVal > 0
                                  ? (maxVal * 1.25).ceilToDouble()
                                  : 4,
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
                                    reservedSize: 30,
                                    getTitlesWidget: (v, _) {
                                      final idx = v.toInt();
                                      if (idx < 0 ||
                                          idx >= displayModules.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          displayModules[idx].key,
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
                                displayModules.length,
                                (i) => BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: displayModules[i].value.toDouble(),
                                      width: isMobile ? 18 : 26,
                                      color: tokens.brandPrimary,
                                      borderRadius:
                                          const BorderRadius.vertical(
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
                  const SizedBox(height: 12),
                ],
                IcareCard(
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: umInputDecoration(
                      context,
                      hint: 'Filter logs by username, action, module, or branch...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (logs.isEmpty)
                  buildUmInfoCard(context, 'No activity audit logs recorded.')
                else if (isMobile)
                  Column(
                    children: logs.map((l) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: IcareCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      l.action,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                  ),
                                  IcareStatusBadge.fromStatus(
                                    l.status ?? 'LOGGED',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${l.username} (${l.role ?? 'Staff'}) • ${l.branch ?? 'HQ'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l.timestamp,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: tokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  IcareDataTable(
                    minWidth: math.max(constraints.maxWidth - 4, 720),
                    columns: const [
                      DataColumn(label: Text('Timestamp')),
                      DataColumn(label: Text('Username')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Branch')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: logs.map((l) {
                      return DataRow(
                        cells: [
                          DataCell(Text(l.timestamp)),
                          DataCell(
                            Text(
                              l.username,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataCell(Text(l.role ?? '')),
                          DataCell(Text(l.branch ?? 'Head Office')),
                          DataCell(Text(l.action)),
                          DataCell(
                            IcareStatusBadge.fromStatus(l.status ?? 'LOGGED'),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class UmLoginHistoryTab extends ConsumerWidget {
  const UmLoginHistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = IcareSurfaceTokens.of(context);
    final asyncHist = ref.watch(loginHistoryProvider);

    return asyncHist.when(
      loading: () => const IcareTableSkeleton(rowCount: 7, hasFilterBar: false),
      error: (err, _) => buildUmErrorCard(
        context,
        err,
        onRetry: () => ref.invalidate(loginHistoryProvider),
      ),
      data: (data) {
        final history = data.history;
        final successCount = history
            .where((h) => h.status.toUpperCase() == 'SUCCESS')
            .length;
        final failedCount = history.length - successCount;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isMobile = width < 740;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IcareSectionHeader(
                  title: 'Authentication & Login History',
                  subtitle: 'System-wide sign-in telemetry, failures, and active session audits.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: isMobile ? width : (width - 24) / 3,
                      child: IcareMetricCard(
                        label: 'Total Auth Events',
                        value: '${history.length}',
                        icon: Icons.security_outlined,
                        isFullEmerald: true,
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? (width - 12) / 2 : (width - 24) / 3,
                      child: IcareMetricCard(
                        label: 'Successful Logins',
                        value: '$successCount',
                        topBorderColor: tokens.successDot,
                        statusTextColor: tokens.successText,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? (width - 12) / 2 : (width - 24) / 3,
                      child: IcareMetricCard(
                        label: 'Failed Attempts',
                        value: '$failedCount',
                        topBorderColor: tokens.dangerDot,
                        statusTextColor: failedCount > 0
                            ? tokens.dangerText
                            : tokens.textPrimary,
                        icon: Icons.gpp_maybe_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (history.isNotEmpty) ...[
                  IcareCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Authentication Outcome Split',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 145,
                          child: BarChart(
                            BarChartData(
                              maxY: math
                                      .max(successCount, failedCount)
                                      .toDouble() *
                                  1.25 +
                                  1,
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
                                    reservedSize: 30,
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
                                    reservedSize: 28,
                                    getTitlesWidget: (v, _) => Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        v.toInt() == 0 ? 'Success' : 'Failed',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: tokens.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              barGroups: [
                                BarChartGroupData(
                                  x: 0,
                                  barRods: [
                                    BarChartRodData(
                                      toY: successCount.toDouble(),
                                      width: 34,
                                      color: tokens.successDot,
                                      borderRadius:
                                          const BorderRadius.vertical(
                                        top: Radius.circular(6),
                                      ),
                                    ),
                                  ],
                                ),
                                BarChartGroupData(
                                  x: 1,
                                  barRods: [
                                    BarChartRodData(
                                      toY: failedCount.toDouble(),
                                      width: 34,
                                      color: tokens.dangerDot,
                                      borderRadius:
                                          const BorderRadius.vertical(
                                        top: Radius.circular(6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (history.isEmpty)
                  buildUmInfoCard(context, 'No login history recorded yet.')
                else if (isMobile)
                  Column(
                    children: history.map((h) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: IcareCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    h.username,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  IcareStatusBadge.fromStatus(h.status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Login: ${h.loginTime}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.textSecondary,
                                ),
                              ),
                              if (h.failedAttempts > 0)
                                Text(
                                  'Failed Attempts: ${h.failedAttempts}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: tokens.dangerText,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  IcareDataTable(
                    minWidth: math.max(width - 4, 720),
                    columns: const [
                      DataColumn(label: Text('Login Time')),
                      DataColumn(label: Text('Username')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Session ID')),
                      DataColumn(label: Text('Logout Time')),
                      DataColumn(label: Text('Failed Attempts')),
                    ],
                    rows: history.map((h) {
                      return DataRow(
                        cells: [
                          DataCell(Text(h.loginTime)),
                          DataCell(
                            Text(
                              h.username,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataCell(IcareStatusBadge.fromStatus(h.status)),
                          DataCell(
                            Text(
                              h.sessionId ?? 'N/A',
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          DataCell(Text(h.logoutTime ?? 'Active / Unknown')),
                          DataCell(Text('${h.failedAttempts}')),
                        ],
                      );
                    }).toList(),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
