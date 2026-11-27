import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../shared/presentation/co_app_scaffold.dart';
import '../../data/datasources/admin_api_service.dart';
import 'admin_responsive.dart';

/// Executive Read-Only Asset & Procurement Snapshot Card on Admin Overview.
/// Renders strictly when live `/api/v1/procurement/overview` data is available.
class AdminAssetPortfolioPulseCard extends ConsumerWidget {
  final AdminSize size;

  const AdminAssetPortfolioPulseCard({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final procAsync = ref.watch(adminProcurementPulseProvider);
    final tokens = IcareSurfaceTokens.of(context);

    final proc = procAsync.valueOrNull;
    if (proc == null) {
      return const SizedBox.shrink();
    }

    final inv = Map<String, dynamic>.from(
      (proc['inventory_summary'] as Map?) ?? const {},
    );
    final pnl = Map<String, dynamic>.from(
      (proc['pnl_summary'] as Map?) ?? const {},
    );
    final readiness = Map<String, dynamic>.from(
      (proc['catalog_readiness'] as Map?) ?? const {},
    );

    final availUnits = (inv['units_available'] as num?)?.toInt() ?? 0;
    final reservedUnits = (inv['units_reserved'] as num?)?.toInt() ?? 0;
    final cashVal = (inv['inventory_cash_value'] as num?)?.toDouble() ?? 0.0;
    final costVal = (inv['inventory_cost_value'] as num?)?.toDouble() ?? 0.0;
    final netProfit = (pnl['net_realized_profit'] as num?)?.toDouble() ?? 0.0;
    final unitsSold = (pnl['units_sold'] as num?)?.toInt() ?? 0;
    final configured =
        (readiness['cost_configured_skus'] as num?)?.toInt() ?? 0;
    final totalSkus = (readiness['total_catalog_skus'] as num?)?.toInt() ?? 0;

    return IcareCard(
      padding: EdgeInsets.all(size.isCompact ? 14 : 18),
      topAccentColor: tokens.brandPrimaryLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tokens.brandSoftBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.brandSoftBorder),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: tokens.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Asset Financing & Stock Pulse (Read-Only)',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          '$configured / $totalSkus catalog SKUs cost-configured across branches',
                          style:
                              TextStyle(fontSize: 11.5, color: tokens.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => ref.read(activeCoPageProvider.notifier).state =
                    'Asset & Procurement',
                icon: const Icon(Icons.visibility_outlined, size: 15),
                label: const Text('Inspect Asset Hub'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.brandPrimary,
                  side: BorderSide(color: tokens.brandSoftBorder),
                  backgroundColor: tokens.brandSoftBg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AdminResponsiveGrid(
            columns: size.isCompact ? 2 : 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _MiniAssetStat(
                tokens: tokens,
                label: 'Available Units',
                value: '$availUnits',
                sub: '$reservedUnits reserved on pending loans',
              ),
              _MiniAssetStat(
                tokens: tokens,
                label: 'Retail Stock Value',
                value: CurrencyFormatter.format(cashVal),
                sub: costVal > 0
                    ? 'Wholesale Cost: ${CurrencyFormatter.format(costVal)}'
                    : 'Wholesale cost pending',
              ),
              _MiniAssetStat(
                tokens: tokens,
                label: 'Units Financed / Sold',
                value: '$unitsSold',
                sub: 'Cash & Carry + Easy Buy 60D/120D',
              ),
              _MiniAssetStat(
                tokens: tokens,
                label: 'Net Realized Asset P&L',
                value: CurrencyFormatter.format(netProfit),
                sub: 'After markup & write-off deductions',
                accent: netProfit >= 0 ? tokens.successText : tokens.dangerText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAssetStat extends StatelessWidget {
  final IcareSurfaceTokens tokens;
  final String label;
  final String value;
  final String sub;
  final Color? accent;

  const _MiniAssetStat({
    required this.tokens,
    required this.label,
    required this.value,
    required this.sub,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tokens.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: accent ?? tokens.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: tokens.textLight),
          ),
        ],
      ),
    );
  }
}
