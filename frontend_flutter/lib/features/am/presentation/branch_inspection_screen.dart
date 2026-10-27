import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../data/datasources/am_api_service.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back to Regional Dashboard',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Branch Inspection — ${widget.branchName}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Supervisory drill-down as viewed by Branch Manager for ${widget.businessDate}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF475569)),
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
            return const Center(
              child: SizedBox(
                height: 48,
                width: 48,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: Color(0xFFDC2626)),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load branch inspection data',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchData,
                      icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                      label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF065F46)),
                    ),
                  ],
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.analytics_outlined, color: Color(0xFF2563EB), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${widget.branchName} Operational Status',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Business Day: ${widget.businessDate}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                                  const Color(0xFF2563EB),
                                ),
                                const SizedBox(height: 10),
                                _buildInspectionCard(
                                  'Vault Cash',
                                  CurrencyFormatter.format((cashPos['closing_balance'] as num?)?.toDouble() ?? 0.0),
                                  Icons.account_balance_wallet_outlined,
                                  const Color(0xFF059669),
                                ),
                                const SizedBox(height: 10),
                                _buildInspectionCard(
                                  'Cashbook Status',
                                  cashPos['status'] ?? 'Balanced',
                                  Icons.verified_outlined,
                                  const Color(0xFF0F766E),
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
                                    const Color(0xFF2563EB),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInspectionCard(
                                    'Vault Cash',
                                    CurrencyFormatter.format((cashPos['closing_balance'] as num?)?.toDouble() ?? 0.0),
                                    Icons.account_balance_wallet_outlined,
                                    const Color(0xFF059669),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInspectionCard(
                                    'Cashbook Status',
                                    cashPos['status'] ?? 'Balanced',
                                    Icons.verified_outlined,
                                    const Color(0xFF0F766E),
                                    isStatus: true,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Credit Officers Scheduled Today Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.group_outlined, size: 20, color: Color(0xFF065F46)),
                              const SizedBox(width: 8),
                              const Text(
                                'Credit Officers Scheduled Today',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${officers.length} Assigned',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          if (officers.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              alignment: Alignment.center,
                              child: const Column(
                                children: [
                                  Icon(Icons.event_busy_outlined, size: 36, color: Color(0xFF94A3B8)),
                                  SizedBox(height: 8),
                                  Text(
                                    'No credit officers scheduled for this branch today.',
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
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
                                    ? const Color(0xFF16A34A)
                                    : (compliance >= 50.0 ? const Color(0xFFD97706) : const Color(0xFFDC2626));

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13.5,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: complianceColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
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
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Text(
                                                  'Expected: ${CurrencyFormatter.format(expected)}',
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Collected: ${CurrencyFormatter.format(collected)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF0F172A),
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
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'Expected: ${CurrencyFormatter.format(expected)}',
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: Color(0xFF64748B),
                                                  fontFeatures: [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'Collected: ${CurrencyFormatter.format(collected)}',
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF0F172A),
                                                  fontFeatures: [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: complianceColor.withValues(alpha: 0.1),
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
    final statusColor = value == 'Balanced' ? const Color(0xFF15803D) : const Color(0xFFDC2626);

    return Container(
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
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isStatus ? statusColor : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
