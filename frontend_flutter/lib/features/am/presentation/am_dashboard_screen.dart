// lib/features/am/presentation/am_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_database_service.dart';
import '../data/datasources/am_api_service.dart';
import '../data/models/am_dashboard_models.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import '../../shared/utils/file_download_helper.dart';
import '../../onboarding/presentation/branch_onboarding_admin_screen.dart';
import '../../reports/data/datasources/reports_api_service.dart';
import '../../reports/presentation/reports_export_screen.dart';

/// Provider for selected business date in AM dashboard
final amSelectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Provider for loading AM Dashboard data
final amDashboardDataProvider = FutureProvider.autoDispose<AmDashboardDataModel>((ref) async {
  final api = ref.watch(amApiServiceProvider);
  final isOnline = ref.read(isOnlineProvider);
  final dbService = ref.watch(offlineDatabaseServiceProvider);
  final selectedDate = ref.watch(amSelectedDateProvider);
  final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

  if (!isOnline) {
    final cached = await dbService.getCachedDashboardData(role: 'am');
    if (cached != null) {
      return AmDashboardDataModel.fromJson(cached);
    }
  }

  try {
    final raw = await api.getAmDashboardDataRaw(businessDate: dateStr);
    dbService.cacheDashboardData(raw, role: 'am').ignore();
    return AmDashboardDataModel.fromJson(raw);
  } catch (err) {
    final cached = await dbService.getCachedDashboardData(role: 'am');
    if (cached != null) {
      return AmDashboardDataModel.fromJson(cached);
    }
    rethrow;
  }
});

class AmDashboardScreen extends ConsumerStatefulWidget {
  const AmDashboardScreen({super.key});

  @override
  ConsumerState<AmDashboardScreen> createState() => _AmDashboardScreenState();
}

class _AmDashboardScreenState extends ConsumerState<AmDashboardScreen> {
  String? _flashMessage;
  bool _isProcessing = false;

  // Approvals Hub Active Tab
  String _activeApprovalTab = 'Branch EOD Sign-Off';

  // Mobile Section Navigation: 'Overview', 'Branches', 'Approvals'
  String _mobileSectionTab = 'Overview';

  void _showFlash(String msg) {
    if (!mounted) return;
    setState(() => _flashMessage = msg);
  }

  void _clearFlash() {
    if (!mounted) return;
    setState(() => _flashMessage = null);
  }

  Future<void> _handleConfirmBranchEod(String branchId, String branchName, String closureDate) async {
    final notesController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm EOD — $branchName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to sign off on the daily EOD reconciliation for $branchName on $closureDate?',
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Supervisory Notes (Optional)',
                hintText: 'e.g. Vault cash reconciled with zero variance.',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF065F46)),
            child: const Text('Confirm EOD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final api = ref.read(amApiServiceProvider);
      final res = await api.confirmBranchEod(
        branchId: branchId,
        closureDate: closureDate,
        notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
      );
      _showFlash(res['message'] ?? 'Branch EOD confirmed successfully.');
      ref.invalidate(amDashboardDataProvider);
    } catch (e) {
      _showFlash('Failed to confirm branch EOD: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleConfirmAreaClosure(String areaName, String closureDate) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Lock & Seal Daily Closure — $areaName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'All operational branches in $areaName have been confirmed with zero variance.\n\nDo you want to finalize and lock the daily regional operations for $closureDate?',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF064E3B)),
            child: Text('Lock & Seal $areaName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final api = ref.read(amApiServiceProvider);
      final res = await api.confirmAreaClosure(areaName: areaName, closureDate: closureDate);
      _showFlash(res['message'] ?? '$areaName closure locked successfully.');
      ref.invalidate(amDashboardDataProvider);
    } catch (e) {
      _showFlash('Failed to lock Area closure: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleApproveHighValueLoan(String loanId, String clientName, double amount) async {
    DateTime disbursementDate = DateTime.now();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Confirm High-Value Loan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Client: $clientName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Amount: ${CurrencyFormatter.format(amount)}', style: const TextStyle(fontSize: 14, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Disbursement Operational Date:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: disbursementDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2027),
                  );
                  if (picked != null) {
                    setDlgState(() => disbursementDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(DateFormat('yyyy-MM-dd').format(disbursementDate)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Approve & Disburse', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final api = ref.read(amApiServiceProvider);
      final res = await api.approveHighValueLoan(
        loanId: loanId,
        disbursementDate: DateFormat('yyyy-MM-dd').format(disbursementDate),
      );
      _showFlash(res['message'] ?? 'Loan approved successfully.');
      ref.invalidate(amDashboardDataProvider);
    } catch (e) {
      _showFlash('Failed to approve loan: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRejectHighValueLoan(String loanId, String clientName) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Loan — $clientName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide the justification reason for rejection:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final api = ref.read(amApiServiceProvider);
      final res = await api.rejectHighValueLoan(
        loanId: loanId,
        reason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : 'Rejected by Area Manager',
      );
      _showFlash(res['message'] ?? 'Loan rejected.');
      ref.invalidate(amDashboardDataProvider);
    } catch (e) {
      _showFlash('Failed to reject loan: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleSignOffTransfer(String transferId, String clientName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Off Client Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Confirm and approve inter-branch client transfer for $clientName?\n\nClient loan balance and savings ledger will be transferred to the destination branch.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF065F46)),
            child: const Text('Sign Off Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final api = ref.read(amApiServiceProvider);
      final res = await api.signOffTransfer(transferId: transferId);
      _showFlash(res['message'] ?? 'Transfer approved.');
      ref.invalidate(amDashboardDataProvider);
    } catch (e) {
      _showFlash('Failed to sign off transfer: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleDownloadAreaExcel() async {
    setState(() => _isProcessing = true);
    try {
      final api = ref.read(amApiServiceProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(ref.read(amSelectedDateProvider));
      final bytes = await api.downloadAreaExcel(businessDate: dateStr);
      final areaData = ref.read(amDashboardDataProvider).value;
      final areaName = areaData?.regionalSummary.areaName ?? 'Regional';
      final cleanArea = areaName.replaceAll(' ', '_');
      final fileName = '${cleanArea}_Report_$dateStr.xlsx';
      downloadBlobFile(bytes, fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      _showFlash('$areaName report downloaded successfully.');
    } catch (e) {
      _showFlash('Failed to download Area Excel: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _navigateToBranchReport(String reportType, String branchName) {
    ref.read(reportsTargetBranchProvider.notifier).state = branchName;

    if (reportType == 'collections_workbook') {
      ref.read(reportsTargetTabProvider.notifier).state = 2; // Data Exports & Downloads
    } else if (reportType == 'master_cashbook_ledger') {
      ref.read(reportsTargetTabProvider.notifier).state = 0; // Monthly Executive Statements
      ref.read(reportsTargetSubTabProvider.notifier).state = 2; // Receipts & Payments Account
    } else if (reportType == 'executive_parity') {
      ref.read(reportsTargetTabProvider.notifier).state = 0; // Monthly Executive Statements
      ref.read(reportsTargetSubTabProvider.notifier).state = 4; // Official Trial Balance
    } else if (reportType == 'officer_portfolio') {
      ref.read(reportsTargetTabProvider.notifier).state = 0; // Monthly Executive Statements
      ref.read(reportsTargetSubTabProvider.notifier).state = 5; // Credit Officers Summary
    } else {
      ref.read(reportsTargetTabProvider.notifier).state = 0;
    }

    ref.read(activeCoPageProvider.notifier).state = 'Reports & Export';
  }

  Future<void> _handleDownloadHandoverReport(String reportType, String branchName) async {
    setState(() => _isProcessing = true);
    try {
      final reportsApi = ref.read(reportsApiServiceProvider);
      final selectedDate = ref.read(amSelectedDateProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final cleanBranch = branchName.replaceAll(' ', '_');

      if (reportType == 'executive_parity') {
        final bytes = await reportsApi.downloadMonthlyParityExcel(
          branchName: branchName,
          year: selectedDate.year,
          month: selectedDate.month,
        );
        downloadBlobFile(
          bytes,
          'Executive_Monthly_Report_${cleanBranch}_${selectedDate.year}_${selectedDate.month.toString().padLeft(2, '0')}.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      } else if (reportType == 'officer_portfolio') {
        final bytes = await reportsApi.downloadMonthlyParityCsv(
          branchName: branchName,
          year: selectedDate.year,
          month: selectedDate.month,
        );
        downloadBlobFile(
          bytes,
          'CO_Monthly_Summary_${cleanBranch}_${selectedDate.year}_${selectedDate.month.toString().padLeft(2, '0')}.csv',
          'text/csv',
        );
      } else {
        // collections_workbook or master_cashbook_ledger
        final bytes = await reportsApi.downloadExcel(
          branchName: branchName,
          asOfDate: dateStr,
        );
        downloadBlobFile(
          bytes,
          'Master_Report_${cleanBranch}_$dateStr.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      }
      _showFlash('$branchName report downloaded successfully.');
    } catch (e) {
      _showFlash('Failed to download report: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showBranchHandoverModal(String branchId, String branchName) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(ref.read(amSelectedDateProvider));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: const BoxConstraints(maxWidth: 680),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<BranchHandoverSummaryModel>(
          future: ref.read(amApiServiceProvider).getBranchHandover(branchId: branchId, businessDate: dateStr),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Error loading handover reports: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
              );
            }
            final handover = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_outlined, color: Color(0xFF064E3B), size: 22),
                        const SizedBox(width: 8),
                        Text('Branch Handover — $branchName', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Branch Manager: ${handover.bmName} | Date: $dateStr', style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                const Divider(height: 24),
                const Text('Available Official Books (Read-Only)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                ...handover.availableReports.map((rep) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 450;
                          final actionRow = Row(
                            mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _navigateToBranchReport(rep.reportType, branchName);
                                },
                                icon: const Icon(Icons.visibility_outlined, size: 14),
                                label: const Text('View', style: TextStyle(fontSize: 11.5)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _isProcessing
                                    ? null
                                    : () {
                                        Navigator.pop(ctx);
                                        _handleDownloadHandoverReport(rep.reportType, branchName);
                                      },
                                icon: const Icon(Icons.download, size: 14, color: Colors.white),
                                label: const Text('Download', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF065F46),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ],
                          );

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                                      child: const Icon(Icons.file_present_outlined, color: Color(0xFF065F46), size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(rep.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                                          Text(rep.description, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                actionRow,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.file_present_outlined, color: Color(0xFF065F46), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(rep.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                                    Text(rep.description, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              actionRow,
                            ],
                          );
                        },
                      ),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showBranchInspectionModal(String branchId, String branchName) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(ref.read(amSelectedDateProvider));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: FutureBuilder<Map<String, dynamic>>(
            future: ref.read(amApiServiceProvider).getBranchInspection(branchId: branchId, businessDate: dateStr),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Error loading branch inspection: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                );
              }
              final data = snapshot.data!;
              final officers = (data['officer_collection_status'] as List<dynamic>?) ?? [];
              final summary = data['branch_summary'] ?? {};
              final cashPos = data['branch_cash_position'] ?? {};

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.analytics_outlined, color: Color(0xFF2563EB), size: 22),
                          const SizedBox(width: 8),
                          Text('Branch Inspection — $branchName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  Text('Supervisory drill-down as viewed by Branch Manager for $dateStr', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const Divider(height: 20),

                  // Quick metrics (Responsive for mobile viewports)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isModalMobile = constraints.maxWidth < 450;
                      if (isModalMobile) {
                        return Column(
                          children: [
                            _buildInspectionMiniCard('Active Borrowers', '${summary['active_clients'] ?? 0}'),
                            const SizedBox(height: 8),
                            _buildInspectionMiniCard('Branch Vault Cash', CurrencyFormatter.format((cashPos['closing_balance'] as num?)?.toDouble() ?? 0.0)),
                            const SizedBox(height: 8),
                            _buildInspectionMiniCard('Cashbook Status', cashPos['status'] ?? 'Balanced', isStatus: true),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: _buildInspectionMiniCard('Active Borrowers', '${summary['active_clients'] ?? 0}')),
                          const SizedBox(width: 10),
                          Expanded(child: _buildInspectionMiniCard('Branch Vault Cash', CurrencyFormatter.format((cashPos['closing_balance'] as num?)?.toDouble() ?? 0.0))),
                          const SizedBox(width: 10),
                          Expanded(child: _buildInspectionMiniCard('Cashbook Status', cashPos['status'] ?? 'Balanced', isStatus: true)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Credit Officers Scheduled Today', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (officers.isEmpty)
                    const Text('No credit officers scheduled for this branch today.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))
                  else
                    ...officers.map((o) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(o['Officer Name'] ?? o['Officer'] ?? 'Officer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Exp: ₦${o['Expected'] ?? 0} | Coll: ₦${o['Collected'] ?? 0} (${o['Compliance %'] ?? 0}%)', style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                            ],
                          ),
                        )),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInspectionMiniCard(String label, String value, {bool isStatus = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isStatus ? (value == 'Balanced' ? const Color(0xFF15803D) : const Color(0xFFDC2626)) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(amDashboardDataProvider);
    final selectedDate = ref.watch(amSelectedDateProvider);

    return dashboardAsync.when(
      loading: () => const IcareDashboardSkeleton(),
      error: (err, stack) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 48),
              const SizedBox(height: 16),
              const Text('Failed to Load Area Manager Console', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
              const SizedBox(height: 8),
              Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(amDashboardDataProvider),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;

        return SingleChildScrollView(
          padding: isMobile ? EdgeInsets.zero : const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_flashMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_flashMessage!, style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF))),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Color(0xFF1E40AF)),
                        onPressed: _clearFlash,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Header Row
              _buildHeaderRow(data.regionalSummary, selectedDate, isMobile),
              const SizedBox(height: 16),

              // Mobile Segmented Switcher
              if (isMobile) ...[
                _buildMobileSectionSwitcher(data.approvalsHub, data.branchPerformance.length),
                const SizedBox(height: 16),
              ],

              // Content based on platform and mobile tab
              if (!isMobile || _mobileSectionTab == 'Overview') ...[
                _buildRegionalExecutiveKpiRow(data.regionalSummary),
                const SizedBox(height: 16),
                _buildOnboardingQuickActionCard(context, ref, isMobile),
                const SizedBox(height: 24),
              ],

              if (!isMobile || _mobileSectionTab == 'Approvals') ...[
                _buildAreaApprovalsHub(data.approvalsHub, isMobile, areaName: data.regionalSummary.areaName),
                const SizedBox(height: 24),
              ],

              if (!isMobile || _mobileSectionTab == 'Branches') ...[
                _buildBranchPerformanceMatrix(data.branchPerformance, isMobile),
                const SizedBox(height: 24),
              ],
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // HEADER ROW
  // =========================================================================
  Widget _buildHeaderRow(RegionalSummaryModel reg, DateTime selectedDate, bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(reg.areaName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5)),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Regional Console',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2027),
                        );
                        if (picked != null) {
                          ref.read(amSelectedDateProvider.notifier).state = picked;
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 12, color: Color(0xFF475569)),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM dd').format(selectedDate),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.domain_add, size: 18, color: Color(0xFF0F766E)),
                      tooltip: 'Branch Onboarding',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        ref.read(activeCoPageProvider.notifier).state = 'Branch Onboarding';
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.download, size: 18, color: Color(0xFF065F46)),
                      tooltip: 'Download Regional Report',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: _isProcessing ? null : _handleDownloadAreaExcel,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Supervising: ${reg.assignedBranches.join(' • ')}',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF0F766E), borderRadius: BorderRadius.circular(6)),
                      child: Text('${reg.areaName} Supervision', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Regional Operations Console',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Supervised Branches: ${reg.assignedBranches.join(', ')}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2027),
                  );
                  if (picked != null) {
                    ref.read(amSelectedDateProvider.notifier).state = picked;
                  }
                },
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(DateFormat('yyyy-MM-dd').format(selectedDate), style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(activeCoPageProvider.notifier).state = 'Branch Onboarding';
                },
                icon: const Icon(Icons.domain_add, size: 14, color: Color(0xFF0F766E)),
                label: const Text('Branch Onboarding', style: TextStyle(color: Color(0xFF0F766E), fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0F766E)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _handleDownloadAreaExcel,
                icon: const Icon(Icons.download, size: 15, color: Colors.white),
                label: const Text('Regional Report (.xlsx)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF064E3B), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MOBILE SECTION SWITCHER
  // =========================================================================
  Widget _buildMobileSectionSwitcher(AreaApprovalsHubModel approvals, int branchCount) {
    final pendingCount = approvals.pendingBranchEods.length + approvals.pendingHighValueLoans.length + approvals.pendingBranchTransfers.length;
    final sections = [
      (label: 'Overview', badge: null),
      (label: 'Branches', badge: '$branchCount'),
      (label: 'Approvals', badge: pendingCount > 0 ? '$pendingCount' : null),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: sections.map((s) {
          final isSel = _mobileSectionTab == s.label;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _mobileSectionTab = s.label),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSel ? const [BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1))] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        color: isSel ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                    if (s.badge != null) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          s.badge!,
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // =========================================================================
  // SECTION 1: REGIONAL EXECUTIVE KPI ROW
  // =========================================================================
  Widget _buildRegionalExecutiveKpiRow(RegionalSummaryModel reg) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCollectionsCard(reg),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildModernMetricCard(
                      title: 'Active Portfolio',
                      value: CurrencyFormatter.format(reg.activeCredit),
                      subtitle: 'Total Gross Credit',
                      icon: Icons.pie_chart_outline,
                      iconColor: const Color(0xFF0F766E),
                      iconBg: const Color(0xFFF0FDFA),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModernMetricCard(
                      title: 'Vault Cash Reserve',
                      value: CurrencyFormatter.format(reg.vaultCashAcct1000),
                      subtitle: 'Ledger Cash Position',
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: const Color(0xFF2563EB),
                      iconBg: const Color(0xFFEFF6FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildModernMetricCard(
                      title: 'Active Borrowers',
                      value: '${reg.activeClients} Clients',
                      subtitle: 'People on Loan',
                      icon: Icons.people_outline,
                      iconColor: const Color(0xFF7C3AED),
                      iconBg: const Color(0xFFF5F3FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModernMetricCard(
                      title: 'Regional PAR > 30d',
                      value: reg.par,
                      subtitle: '${reg.defaultersCount} Defaulters',
                      icon: Icons.warning_amber_rounded,
                      iconColor: const Color(0xFFDC2626),
                      iconBg: const Color(0xFFFEF2F2),
                      isAlert: reg.defaultersCount > 0,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        // Tablet & Desktop layout
        final c1 = _buildModernMetricCard(
          title: 'Active Branches',
          value: '${reg.openBranchesCount} / ${reg.branchesCount}',
          subtitle: 'Operational Status',
          icon: Icons.storefront_outlined,
          iconColor: const Color(0xFF2563EB),
          iconBg: const Color(0xFFEFF6FF),
        );
        final c2 = _buildModernMetricCard(
          title: 'Regional Borrowers',
          value: '${reg.activeClients} Clients',
          subtitle: 'Active Loan Borrowers',
          icon: Icons.people_alt_outlined,
          iconColor: const Color(0xFF7C3AED),
          iconBg: const Color(0xFFF5F3FF),
        );
        final c3 = _buildModernMetricCard(
          title: 'Active Portfolio',
          value: CurrencyFormatter.format(reg.activeCredit),
          subtitle: 'Gross Active Credit',
          icon: Icons.account_balance_outlined,
          iconColor: const Color(0xFF0F766E),
          iconBg: const Color(0xFFF0FDFA),
        );
        final c4 = _buildModernMetricCard(
          title: 'Today\'s Collections',
          value: CurrencyFormatter.format(reg.todayCollected),
          subtitle: '${reg.compliancePct.toStringAsFixed(1)}% Compliance',
          icon: Icons.payments_outlined,
          iconColor: const Color(0xFF10B981),
          iconBg: const Color(0xFFECFDF5),
        );
        final c5 = _buildModernMetricCard(
          title: 'Vault Cash Reserve',
          value: CurrencyFormatter.format(reg.vaultCashAcct1000),
          subtitle: '${reg.areaName} Cash Position',
          icon: Icons.account_balance_wallet_outlined,
          iconColor: const Color(0xFFD97706),
          iconBg: const Color(0xFFFFFBEB),
        );
        final c6 = _buildModernMetricCard(
          title: 'Regional PAR > 30d',
          value: reg.par,
          subtitle: '${reg.defaultersCount} Defaulters',
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFDC2626),
          iconBg: const Color(0xFFFEF2F2),
          isAlert: reg.defaultersCount > 0,
        );

        if (w < 1500) {
          return Column(
            children: [
              Row(children: [Expanded(child: c1), const SizedBox(width: 10), Expanded(child: c2), const SizedBox(width: 10), Expanded(child: c3)]),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: c4), const SizedBox(width: 10), Expanded(child: c5), const SizedBox(width: 10), Expanded(child: c6)]),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: c1),
            const SizedBox(width: 12),
            Expanded(child: c2),
            const SizedBox(width: 12),
            Expanded(child: c3),
            const SizedBox(width: 12),
            Expanded(child: c4),
            const SizedBox(width: 12),
            Expanded(child: c5),
            const SizedBox(width: 12),
            Expanded(child: c6),
          ],
        );
      },
    );
  }

  // =========================================================================
  // ONBOARDING QUICK ACTION & MIGRATION CONSOLE CARD
  // =========================================================================
  Widget _buildOnboardingQuickActionCard(BuildContext context, WidgetRef ref, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCCFBF1)),
                      ),
                      child: const Icon(Icons.domain_add, color: Color(0xFF0F766E), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Branch Digital Onboarding',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Issue 14-day links & manage branch activation',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref.read(activeCoPageProvider.notifier).state = 'Branch Onboarding';
                        },
                        icon: const Icon(Icons.tune, size: 14, color: Color(0xFF0F766E)),
                        label: const Text('Manage Sessions', style: TextStyle(color: Color(0xFF0F766E), fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0F766E)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => showGenerateOnboardingLinkDialog(context, ref),
                        icon: const Icon(Icons.add_link, size: 14, color: Colors.white),
                        label: const Text('+ Generate Link', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCCFBF1)),
                  ),
                  child: const Icon(Icons.domain_add, color: Color(0xFF0F766E), size: 26),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Branch Digital Onboarding & Migration Console',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Issue 14-day links, inspect rosters, and sign off on branch activation.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(activeCoPageProvider.notifier).state = 'Branch Onboarding';
                  },
                  icon: const Icon(Icons.tune, size: 15, color: Color(0xFF0F766E)),
                  label: const Text('Open Console', style: TextStyle(color: Color(0xFF0F766E), fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => showGenerateOnboardingLinkDialog(context, ref),
                  icon: const Icon(Icons.add_link, size: 15, color: Colors.white),
                  label: const Text('+ Generate Branch Link', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroCollectionsCard(RegionalSummaryModel reg) {
    final progress = (reg.compliancePct / 100.0).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18064E3B),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TODAY\'S REGIONAL COLLECTIONS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFA7F3D0),
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x30FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x40FFFFFF)),
                ),
                child: Text(
                  '${reg.compliancePct.toStringAsFixed(1)}% Compliance',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(reg.todayCollected),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontFamily: 'monospace',
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0x30FFFFFF),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target: ${CurrencyFormatter.format(reg.todayExpected)}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w500),
              ),
              Text(
                'Open: ${reg.openBranchesCount} of ${reg.branchesCount} Branches',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFFA7F3D0), fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAlert ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isAlert ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION 2: AREA APPROVALS HUB
  // =========================================================================
  Widget _buildAreaApprovalsHub(AreaApprovalsHubModel approvals, bool isMobile, {String areaName = 'Area 1'}) {
    final eodCount = approvals.pendingBranchEods.length;
    final loanCount = approvals.pendingHighValueLoans.length;
    final transferCount = approvals.pendingBranchTransfers.length;

    final tabs = [
      'Branch EOD Sign-Off ($eodCount)',
      'High-Value Loans > ₦300k ($loanCount)',
      'Inter-Branch Transfers ($transferCount)',
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Area Governance & Approvals Hub', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 3),
                const Text('Operational sign-off, loan escalations, and branch transfers.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                if (approvals.canLockArea) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _handleConfirmAreaClosure(areaName, DateFormat('yyyy-MM-dd').format(ref.read(amSelectedDateProvider))),
                      icon: const Icon(Icons.lock, size: 15, color: Colors.white),
                      label: Text('Lock & Seal $areaName EOD', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF064E3B),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Area Governance & Approvals Hub', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    SizedBox(height: 3),
                    Text('Operational sign-off, loan escalations, and branch transfers.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                if (approvals.canLockArea)
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _handleConfirmAreaClosure(areaName, DateFormat('yyyy-MM-dd').format(ref.read(amSelectedDateProvider))),
                    icon: const Icon(Icons.lock, size: 15, color: Colors.white),
                    label: Text('Lock & Seal $areaName EOD', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF064E3B)),
                  ),
              ],
            ),
          const SizedBox(height: 14),

          // Tabs (Scrollable on mobile)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: tabs.map((t) {
                final tabKey = t.split(' (')[0];
                final isSel = _activeApprovalTab.startsWith(tabKey);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _activeApprovalTab = tabKey),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF064E3B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSel ? const Color(0xFF064E3B) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),

          if (_activeApprovalTab.startsWith('Branch EOD'))
            _buildBranchEodApprovalsTab(approvals.pendingBranchEods, isMobile)
          else if (_activeApprovalTab.startsWith('High-Value Loans'))
            _buildHighValueLoansApprovalsTab(approvals.pendingHighValueLoans, isMobile)
          else
            _buildTransfersApprovalsTab(approvals.pendingBranchTransfers, isMobile),
        ],
      ),
    );
  }

  Widget _buildBranchEodApprovalsTab(List<PendingBranchEodItemModel> eods, bool isMobile) {
    if (eods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No branch EOD submissions pending for today.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))),
      );
    }

    return Column(
      children: eods.map((e) {
        final isConfirmed = e.isConfirmed;

        if (isMobile) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isConfirmed ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isConfirmed ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isConfirmed ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            isConfirmed ? Icons.check_circle : Icons.pending_actions,
                            color: isConfirmed ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(e.branchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isConfirmed ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isConfirmed ? 'CONFIRMED' : e.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isConfirmed ? const Color(0xFF15803D) : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Primary Vault Cash', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(e.vaultCash),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              fontFamily: 'monospace',
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Cash Variance', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(e.cashVariance),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: e.cashVariance == 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                              fontFamily: 'monospace',
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (!isConfirmed)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _handleConfirmBranchEod(e.branchId, e.branchName, e.closureDate),
                      icon: const Icon(Icons.check, size: 15, color: Colors.white),
                      label: const Text('Confirm & Sign Off Branch EOD', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF065F46),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.verified, size: 14, color: Color(0xFF15803D)),
                      const SizedBox(width: 4),
                      Text('Signed by ${e.confirmedBy ?? "AM"}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                    ],
                  ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isConfirmed ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isConfirmed ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isConfirmed ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isConfirmed ? Icons.check_circle : Icons.pending_actions,
                  color: isConfirmed ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(e.branchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isConfirmed ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isConfirmed ? 'CONFIRMED' : e.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isConfirmed ? const Color(0xFF15803D) : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vault Cash: ${CurrencyFormatter.format(e.vaultCash)} | Variance: ${CurrencyFormatter.format(e.cashVariance)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (!isConfirmed)
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _handleConfirmBranchEod(e.branchId, e.branchName, e.closureDate),
                  icon: const Icon(Icons.check, size: 14, color: Colors.white),
                  label: const Text('Confirm EOD', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF065F46)),
                )
              else
                Text('Signed by ${e.confirmedBy ?? "AM"}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHighValueLoansApprovalsTab(List<PendingHighValueLoanItemModel> loans, bool isMobile) {
    if (loans.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Zero high-value loans (> ₦300k) awaiting Area Manager confirmation.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))),
      );
    }

    return Column(
      children: loans.map((l) {
        if (isMobile) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.trending_up, color: Color(0xFFB45309), size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(l.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                      child: Text(l.branchName, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Officer: ${l.officer} • Product: ${l.loanProduct}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Amount: ${CurrencyFormatter.format(l.loanAmount)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF2563EB), fontFamily: 'monospace'),
                ),
                if (l.escalationReason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(l.escalationReason, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : () => _handleRejectHighValueLoan(l.loanId, l.clientName),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : () => _handleApproveHighValueLoan(l.loanId, l.clientName, l.loanAmount),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Confirm Loan', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.trending_up, color: Color(0xFFB45309), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(l.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Text('(${l.branchName} — ${l.officer})', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Amount: ${CurrencyFormatter.format(l.loanAmount)} | Product: ${l.loanProduct}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    Text(l.escalationReason, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                  ],
                ),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _isProcessing ? null : () => _handleRejectHighValueLoan(l.loanId, l.clientName),
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                    child: const Text('Reject', style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : () => _handleApproveHighValueLoan(l.loanId, l.clientName, l.loanAmount),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                    child: const Text('Confirm', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTransfersApprovalsTab(List<PendingBranchTransferItemModel> transfers, bool isMobile) {
    if (transfers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Zero inter-branch client transfers awaiting Area sign-off.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))),
      );
    }

    return Column(
      children: transfers.map((t) {
        if (isMobile) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.swap_horiz, color: Color(0xFF2563EB), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Route: ${t.sourceBranchName} ➔ ${t.destBranchName}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Balance: ${CurrencyFormatter.format(t.outstandingBalance)} | Savings: ${CurrencyFormatter.format(t.savingsBalance)}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () => _handleSignOffTransfer(t.transferId, t.clientName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF065F46),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Sign Off Client Transfer', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.swap_horiz, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Route: ${t.sourceBranchName} ➔ ${t.destBranchName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Balance: ${CurrencyFormatter.format(t.outstandingBalance)} | Savings: ${CurrencyFormatter.format(t.savingsBalance)}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _isProcessing ? null : () => _handleSignOffTransfer(t.transferId, t.clientName),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF065F46)),
                child: const Text('Sign Off', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // =========================================================================
  // SECTION 3: BRANCH COMPARATIVE PERFORMANCE MATRIX
  // =========================================================================
  Widget _buildBranchPerformanceMatrix(List<BranchPerformanceItemModel> branches, bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.table_chart_outlined, size: 16, color: Color(0xFF065F46)),
                    ),
                    const SizedBox(width: 8),
                    const Text('Branch Comparative Performance Matrix', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  ],
                ),
                Text('${branches.length} Supervised Branches', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          if (isMobile)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: branches.map((b) => _buildMobileBranchCard(b)).toList(),
              ),
            )
          else
            Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Branch Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Branch Manager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Expected (₦)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Collected (₦)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Compliance %', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Vault Cash (₦)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('PAR %', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                  rows: branches.map((b) {
                    final isHealthy = b.compliancePct >= 85.0 && b.cashVariance == 0.0;
                    return DataRow(
                      cells: [
                        DataCell(Text(b.branchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                        DataCell(Text(b.bmName, style: const TextStyle(fontSize: 12))),
                        DataCell(Text(CurrencyFormatter.format(b.expectedCollection), style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(CurrencyFormatter.format(b.collected), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D), fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isHealthy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('${b.compliancePct}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isHealthy ? const Color(0xFF15803D) : const Color(0xFFDC2626), fontFeatures: const [FontFeature.tabularFigures()])),
                          ),
                        ),
                        DataCell(Text(CurrencyFormatter.format(b.vaultCashAcct1000), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontFeatures: [FontFeature.tabularFigures()]))),
                        DataCell(Text(b.par, style: const TextStyle(fontSize: 12))),
                        DataCell(Text(b.operationalStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isHealthy ? const Color(0xFF15803D) : const Color(0xFFDC2626)))),
                        DataCell(
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showBranchInspectionModal(b.branchId, b.branchName),
                                icon: const Icon(Icons.search, size: 12),
                                label: const Text('Inspect', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                onPressed: () => _showBranchHandoverModal(b.branchId, b.branchName),
                                icon: const Icon(Icons.folder_open, size: 12, color: Colors.white),
                                label: const Text('Reports', style: TextStyle(fontSize: 11, color: Colors.white)),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF065F46), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileBranchCard(BranchPerformanceItemModel b) {
    final isHealthy = b.compliancePct >= 85.0 && b.cashVariance == 0.0;
    final progress = (b.expectedCollection > 0)
        ? (b.collected / b.expectedCollection).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_city, color: Color(0xFF0F172A), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.branchName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      Text('BM: ${b.bmName}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isHealthy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  b.operationalStatus,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isHealthy ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Collection Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collection: ${CurrencyFormatter.format(b.collected)}',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontFamily: 'monospace'),
              ),
              Text(
                '${b.compliancePct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isHealthy ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isHealthy ? const Color(0xFF059669) : const Color(0xFFD97706),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 2 mini tiles: Vault Cash & PAR
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vault Cash', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.format(b.vaultCashAcct1000),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                            fontFamily: 'monospace',
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PAR > 30d', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text(
                        b.par,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: b.par == '0.0%' ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showBranchInspectionModal(b.branchId, b.branchName),
                  icon: const Icon(Icons.search, size: 14),
                  label: const Text('Inspect Branch', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showBranchHandoverModal(b.branchId, b.branchName),
                  icon: const Icon(Icons.folder_open, size: 14, color: Colors.white),
                  label: const Text('Reports', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF065F46),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
