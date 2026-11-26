import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/errors/app_error_formatter.dart';
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
  showIcareAdaptiveSheet<void>(
    context: context,
    mobileBreakpoint: 600,
    fitContent: true,
    desktopConstraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
    desktopInsetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    builder: (_, isDialog) => OfficerProductivityModalSheet(
      branchId: branchId,
      branchName: branchName,
      period: period,
      dates: resolvedDates,
      isDialog: isDialog,
    ),
  );
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
        _errorMessage = AppErrorDetails.from(e).message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxH = mediaQuery.size.height * 0.85;
    final tokens = IcareSurfaceTokens.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: tokens.surface,
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
                  color: tokens.borderStrong,
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
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: tokens.infoBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: tokens.infoBorder),
                            ),
                            child: Text(
                              widget.period,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.infoText),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Productivity breakdown per active Credit Officer in this branch.',
                        style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, size: 20, color: tokens.textMuted),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.borderSubtle),

          // Body Content
          Flexible(
            child: _isLoading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: tokens.brandPrimary),
                          const SizedBox(height: 12),
                          Text('Loading officer productivity metrics...', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
                        ],
                      ),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Error: $_errorMessage', style: TextStyle(color: tokens.dangerText)),
                        ),
                      )
                    : (_data?.officers.isEmpty ?? true)
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text('No active Credit Officers found for this branch.', style: TextStyle(color: tokens.textMuted)),
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
    final tokens = IcareSurfaceTokens.of(context);
    final isNetPositive = o.netLoanCount >= 0;
    final netColor = isNetPositive ? tokens.successText : tokens.warningText;
    final netBg = isNetPositive ? tokens.successBg : tokens.warningBg;
    final netBorder = isNetPositive ? tokens.successBorder : tokens.warningBorder;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: tokens.isDark ? 0.18 : 0.02), blurRadius: 3, offset: const Offset(0, 1))],
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
                    backgroundColor: tokens.brandPrimary.withValues(alpha: 0.14),
                    child: Text(
                      o.fullName.isNotEmpty ? o.fullName.substring(0, 1).toUpperCase() : 'O',
                      style: TextStyle(fontWeight: FontWeight.bold, color: tokens.brandPrimary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.fullName,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                      ),
                      Text(
                        '@${o.username}',
                        style: TextStyle(fontSize: 11, color: tokens.textMuted),
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
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tokens.borderStrong),
                    ),
                    child: Text(
                      '${o.activeClientsCount} Borrowers',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: tokens.brandSoftBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tokens.brandSoftBorder),
                    ),
                    child: Text(
                      CurrencyFormatter.formatNaira(o.activePortfolio),
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: tokens.brandSoftText),
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
                    color: tokens.successBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Principal Disbursed',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: tokens.successText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatNaira(o.principalDisbursedAmount),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tokens.successText),
                      ),
                      Text(
                        '${o.loansDisbursedCount} Loans Disbursed',
                        style: TextStyle(fontSize: 9, color: tokens.successText),
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
                    color: tokens.infoBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Payments (Closed)',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: tokens.infoText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatNaira(o.fullPaymentsActiveCredit),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tokens.infoText),
                      ),
                      Text(
                        '${o.fullPaymentsCount} Closed Members',
                        style: TextStyle(fontSize: 9, color: tokens.infoText),
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
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${o.compliancePct.toStringAsFixed(1)}% Comp',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                      ),
                      Text(
                        o.parPct,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: o.parPct == '0.0%' ? tokens.successText : tokens.dangerText,
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
