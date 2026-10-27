import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../data/datasources/am_api_service.dart';
import '../data/models/am_dashboard_models.dart';

/// Helper to calculate period dates (Today, This Week, This Month)
(String, String) getPeriodDates(String period) {
  final now = DateTime.now();
  final todayStr = DateFormat('yyyy-MM-dd').format(now);
  if (period == 'Today') {
    return (todayStr, todayStr);
  } else if (period == 'This Week') {
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final s = DateFormat('yyyy-MM-dd').format(monday);
    return (s, todayStr);
  } else {
    // This Month (default)
    final firstDay = DateTime(now.year, now.month, 1);
    final s = DateFormat('yyyy-MM-dd').format(firstDay);
    return (s, todayStr);
  }
}

/// Dedicated launcher for Officer Productivity Drill-Down popup
void showOfficerProductivitySheet({
  required BuildContext context,
  required String branchId,
  required String branchName,
  String period = 'This Month',
  (String, String)? dates,
}) {
  final resolvedDates = dates ?? getPeriodDates(period);
  final screenWidth = MediaQuery.of(context).size.width;
  if (screenWidth >= 600) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: OfficerProductivityModalSheet(
              branchId: branchId,
              branchName: branchName,
              period: period,
              dates: resolvedDates,
              isDialog: true,
            ),
          ),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OfficerProductivityModalSheet(
        branchId: branchId,
        branchName: branchName,
        period: period,
        dates: resolvedDates,
      ),
    );
  }
}

/// Officer Productivity Modal Sheet Component
class OfficerProductivityModalSheet extends ConsumerStatefulWidget {
  final String branchId;
  final String branchName;
  final String period;
  final (String, String) dates;
  final bool isDialog;

  const OfficerProductivityModalSheet({
    super.key,
    required this.branchId,
    required this.branchName,
    required this.period,
    required this.dates,
    this.isDialog = false,
  });

  @override
  ConsumerState<OfficerProductivityModalSheet> createState() => _OfficerProductivityModalSheetState();
}

class _OfficerProductivityModalSheetState extends ConsumerState<OfficerProductivityModalSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  BranchOfficerProductivityResponseModel? _data;

  @override
  void initState() {
    super.initState();
    _fetchOfficers();
  }

  Future<void> _fetchOfficers() async {
    try {
      final apiService = ref.read(amApiServiceProvider);
      final (startDate, endDate) = widget.dates;
      final res = await apiService.getBranchOfficerProductivity(
        branchId: widget.branchId,
        startDate: startDate,
        endDate: endDate,
      );
      if (!mounted) return;
      setState(() {
        _data = res;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxH = mediaQuery.size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isDialog
            ? BorderRadius.circular(16)
            : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grabber Handle (Mobile bottom sheet only)
          if (!widget.isDialog)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${widget.branchName} — Officer Productivity',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              widget.period,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Productivity breakdown per active Credit Officer in this branch.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Body Content
          Flexible(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF0F766E)),
                          SizedBox(height: 12),
                          Text('Loading officer productivity metrics...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Error: $_errorMessage', style: const TextStyle(color: Color(0xFFDC2626))),
                        ),
                      )
                    : (_data?.officers.isEmpty ?? true)
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('No active Credit Officers found for this branch.', style: TextStyle(color: Color(0xFF64748B))),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            shrinkWrap: true,
                            itemCount: _data!.officers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final o = _data!.officers[idx];
                              return _buildOfficerCard(o);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerCard(OfficerProductivityItemModel o) {
    final isNetPositive = o.netLoanCount >= 0;
    final netColor = isNetPositive ? const Color(0xFF059669) : const Color(0xFFD97706);
    final netBg = isNetPositive ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);
    final netBorder = isNetPositive ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Officer Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    child: Text(
                      o.fullName.isNotEmpty ? o.fullName.substring(0, 1).toUpperCase() : 'O',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E), fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.fullName,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '@${o.username}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      '${o.activeClientsCount} Borrowers',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF99F6E4)),
                    ),
                    child: Text(
                      CurrencyFormatter.formatNaira(o.activePortfolio),
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dynamics: Capital Principal Disbursed vs Active Credit Disbursed vs Full Payments
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Principal Disbursed',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatNaira(o.principalDisbursedAmount),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF14532D)),
                      ),
                      Text(
                        '${o.loansDisbursedCount} Loans Disbursed',
                        style: const TextStyle(fontSize: 9, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Full Payments (Closed)',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatNaira(o.fullPaymentsActiveCredit),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                      ),
                      Text(
                        '${o.fullPaymentsCount} Closed Members',
                        style: const TextStyle(fontSize: 9, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Net Progress Pill & Compliance
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: netBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: netBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(isNetPositive ? Icons.trending_up : Icons.trending_down, size: 12, color: netColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Net: ${o.netLoanCount >= 0 ? "+" : ""}${o.netLoanCount} Loans (${o.netActiveCreditVolume >= 0 ? "+" : ""}${CurrencyFormatter.formatNaira(o.netActiveCreditVolume)} Active Credit)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: netColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${o.compliancePct.toStringAsFixed(1)}% Comp',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      Text(
                        o.parPct,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: o.parPct == '0.0%' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
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
