import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/icare_motion.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../../reports/data/datasources/reports_api_service.dart';
import '../../reports/data/models/report_models.dart';
import '../../reports/presentation/widgets/bank_reconciliation_form_widget.dart';
import '../data/datasources/admin_api_service.dart';

/// Admin Statutory Reconciliation & Brought Forward (B/F) Portal
/// Gives Head Office Administrator direct authority to view, input, and save
/// monthly reconciliations, bank statement balances, and opening B/F schedules
/// for any branch based on physical paper returns.
class AdminBranchReconciliationSheet extends ConsumerStatefulWidget {
  final String? initialBranchId;
  final String? initialBranchName;
  final int? initialYear;
  final int? initialMonth;

  const AdminBranchReconciliationSheet({
    super.key,
    this.initialBranchId,
    this.initialBranchName,
    this.initialYear,
    this.initialMonth,
  });

  static Future<void> show(
    BuildContext context, {
    String? branchId,
    String? branchName,
    int? initialYear,
    int? initialMonth,
  }) {
    return showIcareAdaptiveSheet<void>(
      context: context,
      mobileHeightFactor: 0.92,
      enablePeekSnap: false,
      desktopConstraints: const BoxConstraints(maxWidth: 860, maxHeight: 820),
      desktopInsetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      builder: (_, __) => AdminBranchReconciliationSheet(
        initialBranchId: branchId,
        initialBranchName: branchName,
        initialYear: initialYear,
        initialMonth: initialMonth,
      ),
    );
  }

  @override
  ConsumerState<AdminBranchReconciliationSheet> createState() => _AdminBranchReconciliationSheetState();
}

class _AdminBranchReconciliationSheetState extends ConsumerState<AdminBranchReconciliationSheet> {
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  String? _selectedBranchName;
  late int _selectedYear;
  late int _selectedMonth;

  Future<MonthlyReconciliationData>? _reconFuture;
  ReportsMeta? _cachedMeta;

  @override
  void initState() {
    super.initState();
    _selectedBranchName = widget.initialBranchName;
    _selectedYear = widget.initialYear ?? DateTime.now().year;
    _selectedMonth = widget.initialMonth ?? DateTime.now().month;

    final api = ref.read(reportsApiServiceProvider);
    api.getReportsMeta().then((meta) {
      if (mounted) {
        setState(() {
          _cachedMeta = meta;
          _selectedBranchName ??= meta.branches.isNotEmpty ? meta.branches.first.name : null;
          _loadReconciliation();
        });
      }
      return meta;
    });

    if (_selectedBranchName != null) {
      _loadReconciliation();
    }
  }

  void _loadReconciliation() {
    if (_selectedBranchName == null) return;
    final api = ref.read(reportsApiServiceProvider);
    setState(() {
      _reconFuture = api.getMonthlyReconciliation(
        branchName: _selectedBranchName,
        year: _selectedYear,
        month: _selectedMonth,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final tokens = IcareSurfaceTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle on mobile
          if (isMobile)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.brandSoftBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.brandSoftBorder),
                  ),
                  child: Icon(Icons.account_balance_outlined, size: 20, color: tokens.brandPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statutory Reconciliation & Opening B/F',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Head Office Authority • Paper Returns Custody',
                        style: TextStyle(fontSize: 12, color: tokens.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: tokens.textMuted, size: 20),
                  splashRadius: 20,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.borderSubtle),

          // Scope Control Bar (Branch Dropdown & Period Stepper)
          _buildScopeControlBar(isMobile),
          Divider(height: 1, color: tokens.borderSubtle),

          // Body Content
          Expanded(
            child: _reconFuture == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: IcareTableSkeleton(rowCount: 6, hasFilterBar: false),
                    ),
                  )
                : FutureBuilder<MonthlyReconciliationData>(
                    future: _reconFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: IcareTableSkeleton(rowCount: 6, hasFilterBar: false),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, size: 36, color: tokens.dangerDot),
                                const SizedBox(height: 12),
                                Text(
                                  'Unable to load reconciliation baseline',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tokens.textPrimary),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  snapshot.error.toString(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: tokens.textMuted),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadReconciliation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: tokens.brandPrimary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final data = snapshot.data;
                      if (data == null) {
                        return Center(
                          child: Text(
                            'No reconciliation data found for this period.',
                            style: TextStyle(fontSize: 13, color: tokens.textMuted),
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        physics: const BouncingScrollPhysics(),
                        child: BankReconciliationFormWidget(
                          initialData: data,
                          branchName: _selectedBranchName,
                          year: _selectedYear,
                          month: _selectedMonth,
                          isReadOnly: false, // Full Administrative Write & Override Authority
                          onSaved: () {
                            ref.invalidate(adminOperationsProvider);
                            _loadReconciliation();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeControlBar(bool isMobile) {
    final branches = _cachedMeta?.branches ?? [];
    final branchNames = branches.map((b) => b.name).toList();
    final tokens = IcareSurfaceTokens.of(context);

    return Container(
      color: tokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBranchDropdown(branchNames),
                const SizedBox(height: 8),
                _buildPeriodStepper(),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildBranchDropdown(branchNames)),
                const SizedBox(width: 16),
                _buildPeriodStepper(),
              ],
            ),
    );
  }

  Widget _buildBranchDropdown(List<String> branchNames) {
    final currentVal = branchNames.contains(_selectedBranchName)
        ? _selectedBranchName
        : (branchNames.isNotEmpty ? branchNames.first : null);
    final tokens = IcareSurfaceTokens.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.borderStrong),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentVal,
          dropdownColor: tokens.surfaceElevated,
          isDense: true,
          hint: Text('Select Branch', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
          items: branchNames.map((b) {
            return DropdownMenuItem<String>(
              value: b,
              child: Row(
                children: [
                  Icon(Icons.domain_outlined, size: 14, color: tokens.brandPrimary),
                  const SizedBox(width: 6),
                  Text(
                    b,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null && val != _selectedBranchName) {
              setState(() {
                _selectedBranchName = val;
                _loadReconciliation();
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildPeriodStepper() {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.borderStrong),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, size: 18, color: tokens.brandPrimary),
            visualDensity: VisualDensity.compact,
            tooltip: 'Previous Month',
            onPressed: () {
              setState(() {
                if (_selectedMonth == 1) {
                  _selectedMonth = 12;
                  _selectedYear -= 1;
                } else {
                  _selectedMonth -= 1;
                }
                _loadReconciliation();
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${_monthNames[_selectedMonth - 1]} $_selectedYear',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, size: 18, color: tokens.brandPrimary),
            visualDensity: VisualDensity.compact,
            tooltip: 'Next Month',
            onPressed: () {
              setState(() {
                if (_selectedMonth == 12) {
                  _selectedMonth = 1;
                  _selectedYear += 1;
                } else {
                  _selectedMonth += 1;
                }
                _loadReconciliation();
              });
            },
          ),
        ],
      ),
    );
  }
}
