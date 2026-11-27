import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_metric_card.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../data/datasources/am_api_service.dart';
import 'widgets/am_subpage_charts.dart';

class BranchInspectionScreen extends ConsumerStatefulWidget {
  final String branchId;
  final String branchName;
  final String businessDate;

  const BranchInspectionScreen({
    super.key,
    required this.branchId,
    required this.branchName,
    required this.businessDate,
  });

  @override
  ConsumerState<BranchInspectionScreen> createState() => _BranchInspectionScreenState();
}

class _BranchInspectionScreenState extends ConsumerState<BranchInspectionScreen> {
  late Future<Map<String, dynamic>> _inspectionFuture;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    setState(() {
      _inspectionFuture = ref.read(amApiServiceProvider).getBranchInspection(
        branchId: widget.branchId,
        businessDate: widget.businessDate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final tokens = IcareSurfaceTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        backgroundColor: tokens.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tokens.textPrimary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back to Regional Dashboard',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Branch Inspection — ${widget.branchName}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Supervisory drill-down as viewed by Branch Manager for ${widget.businessDate}',
              style: TextStyle(
                fontSize: 12,
                color: tokens.textMuted,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: tokens.borderSubtle),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: tokens.textSecondary),
            tooltip: 'Refresh Inspection Data',
            onPressed: _fetchData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _inspectionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 28, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: const IcareTableSkeleton(rowCount: 6, hasFilterBar: false),
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            final errDetails = AppErrorDetails.from(snapshot.error);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: IcareCard(
                    padding: const EdgeInsets.all(24),
                    topAccentColor: tokens.dangerDot,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 40, color: tokens.dangerDot),
                        const SizedBox(height: 12),
                        Text(
                          errDetails.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tokens.dangerText),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          errDetails.message,
                          style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchData,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.brandPrimaryDark,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final officers = (data['officer_collection_status'] as List<dynamic>?) ?? [];
          final summary = data['branch_summary'] ?? {};
          final cashPos = data['branch_cash_position'] ?? {};

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 28,
              vertical: isMobile ? 16 : 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Summary Banner
                    IcareCard(
                      padding: const EdgeInsets.all(16),
                      topAccentColor: tokens.brandPrimary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: tokens.infoBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.analytics_outlined, color: tokens.infoDot, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${widget.branchName} Operational Status',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Business Day: ${widget.businessDate}',
                                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Inspection Mini Cards
                          if (isMobile)
                            Column(
                              children: [
                                _buildInspectionCard(
                                  'Active Borrowers',
                                  '${summary['active_clients'] ?? 0}',
                                  Icons.people_alt_outlined,
                                  tokens.infoDot,
                                ),
                                const SizedBox(height: 10),
                                _buildInspectionCard(
                                  'Vault Cash',
                                  CurrencyFormatter.format((cashPos['closing_balance'] as num?)?.toDouble() ?? 0.0),
                                  Icons.account_balance_wallet_outlined,
                                  tokens.successDot,
                                ),
                                const SizedBox(height: 10),
                                _buildInspectionCard(
                                  'Cashbook Status',
                                  cashPos['status'] ?? 'Unverified',
                                  Icons.verified_outlined,
                                  tokens.brandPrimary,
                                  isStatus: true,
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInspectionCard(
                                    'Active Borrowers',
                                    '${summary['active_clients'] ?? 0}',
                                    Icons.people_alt_outlined,
                                    tokens.infoDot,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInspectionCard(
                                    'Vault Cash',
                                    CurrencyFormatter.format((cashPos['closing_balance'] as num?)?.toDouble() ?? 0.0),
                                    Icons.account_balance_wallet_outlined,
                                    tokens.successDot,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInspectionCard(
                                    'Cashbook Status',
                                    cashPos['status'] ?? 'Unverified',
                                    Icons.verified_outlined,
                                    tokens.brandPrimary,
                                    isStatus: true,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    BranchInspectionOfficerChart(officers: officers),
                    const SizedBox(height: 18),

                    // Credit Officers Scheduled Today Section
                    IcareCard(
                      padding: const EdgeInsets.all(20),
                      topAccentColor: tokens.infoDot,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.group_outlined, size: 20, color: tokens.brandPrimary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Credit Officers Scheduled Today',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IcareStatusBadge(
                                label: '${officers.length} Assigned',
                                variant: IcareBadgeVariant.neutral,
                                showDot: false,
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          if (officers.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Icon(Icons.event_busy_outlined, size: 36, color: tokens.textLight),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No credit officers scheduled for this branch today.',
                                    style: TextStyle(color: tokens.textMuted, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: officers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final o = officers[index];
                                final officerName = o['Officer Name'] ?? o['Officer'] ?? 'Credit Officer';
                                final expected = (o['Expected'] as num?)?.toDouble() ?? 0.0;
                                final collected = (o['Collected'] as num?)?.toDouble() ?? 0.0;
                                final compliance = (o['Compliance %'] as num?)?.toDouble() ?? 0.0;

                                final isHighCompliance = compliance >= 80.0;
                                final complianceColor = isHighCompliance
                                    ? tokens.successText
                                    : (compliance >= 50.0 ? tokens.warningText : tokens.dangerText);

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: tokens.borderSubtle),
                                  ),
                                  child: isMobile
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    officerName,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13.5,
                                                      color: tokens.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: complianceColor.withValues(alpha: 0.14),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '${compliance.toStringAsFixed(1)}%',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      fontFeatures: const [FontFeature.tabularFigures()],
                                                      color: complianceColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 4,
                                              children: [
                                                Text(
                                                  'Expected: ${CurrencyFormatter.format(expected)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: tokens.textMuted,
                                                    fontFeatures: const [FontFeature.tabularFigures()],
                                                  ),
                                                ),
                                                Text(
                                                  'Collected: ${CurrencyFormatter.format(collected)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    fontFeatures: const [FontFeature.tabularFigures()],
                                                    color: tokens.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                officerName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                  color: tokens.textPrimary,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'Expected: ${CurrencyFormatter.format(expected)}',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  color: tokens.textMuted,
                                                  fontFeatures: const [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'Collected: ${CurrencyFormatter.format(collected)}',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: tokens.textPrimary,
                                                  fontFeatures: const [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: complianceColor.withValues(alpha: 0.14),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${compliance.toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: complianceColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInspectionCard(
    String label,
    String value,
    IconData icon,
    Color accentColor, {
    bool isStatus = false,
  }) {
    final tokens = IcareSurfaceTokens.of(context);
    final statusColor = value == 'Balanced' ? tokens.successText : tokens.dangerText;

    return IcareMetricCard(
      label: label,
      value: value,
      icon: icon,
      topBorderColor: accentColor,
      statusTextColor: isStatus ? statusColor : null,
    );
  }
}
