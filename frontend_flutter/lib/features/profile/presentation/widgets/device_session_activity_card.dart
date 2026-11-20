import 'package:flutter/material.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_status_badge.dart';
import '../../data/models/profile_models.dart';

class DeviceSessionActivityCard extends StatelessWidget {
  final bool isOnline;
  final int pendingOutboxCount;
  final List<LoginActivityItemModel> recentActivity;
  final VoidCallback? onOpenOutboxSync;
  final VoidCallback onClearLocalCache;
  final VoidCallback onSignOut;

  const DeviceSessionActivityCard({
    super.key,
    required this.isOnline,
    required this.pendingOutboxCount,
    required this.recentActivity,
    this.onOpenOutboxSync,
    required this.onClearLocalCache,
    required this.onSignOut,
  });

  String _formatTimestamp(String raw) {
    final clean = raw.replaceAll('T', ' ').trim();
    if (clean.length >= 16) {
      return clean.substring(0, 16);
    }
    return clean.isEmpty ? 'Unknown time' : clean;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 640;

    return IcareCard(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.brandSoftBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.brandSoftBorder),
                ),
                child: Icon(
                  Icons.devices_outlined,
                  size: 18,
                  color: tokens.brandSoftText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Diagnostics & Recent Sign-Ins',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Offline queue safety, local cache, and session history.',
                      softWrap: true,
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Device telemetry strip
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      isOnline ? Icons.wifi : Icons.wifi_off,
                      size: 17,
                      color: isOnline ? tokens.successDot : tokens.warningDot,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isOnline
                            ? 'Live Server Sync Active'
                            : 'Offline Vault Mode Active',
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    IcareStatusBadge(
                      label: isOnline ? 'Online' : 'Offline',
                      variant: isOnline
                          ? IcareBadgeVariant.success
                          : IcareBadgeVariant.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(color: tokens.borderSubtle, height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.sync_outlined,
                      size: 17,
                      color: pendingOutboxCount > 0
                          ? tokens.warningDot
                          : tokens.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Queued Outbox Transactions: $pendingOutboxCount',
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (pendingOutboxCount > 0 && onOpenOutboxSync != null)
                      TextButton(
                        onPressed: onOpenOutboxSync,
                        child: const Text('Review Queue'),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onClearLocalCache,
                icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                label: const Text('Clear Read Cache'),
              ),
              OutlinedButton.icon(
                onPressed: onSignOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.dangerText,
                  side: BorderSide(color: tokens.dangerBorder),
                ),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Sign Out of Workspace'),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Divider(color: tokens.borderSubtle, height: 1),
          const SizedBox(height: 14),

          Text(
            'Recent Sign-In Activity',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          if (recentActivity.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Text(
                'No recent sign-in records returned for this account.',
                softWrap: true,
                style: TextStyle(fontSize: 12.5, color: tokens.textMuted),
              ),
            )
          else
            Column(
              children: recentActivity.map((entry) {
                final deviceSummary = [
                  entry.deviceName,
                  entry.browser,
                  entry.operatingSystem,
                ]
                    .where((s) => s != null && s.trim().isNotEmpty)
                    .join(' · ');

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 16,
                        color: entry.status.toUpperCase() == 'SUCCESS'
                            ? tokens.successDot
                            : tokens.warningDot,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatTimestamp(entry.loginTime),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            if (deviceSummary.isNotEmpty)
                              Text(
                                deviceSummary,
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: tokens.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IcareStatusBadge.fromStatus(entry.status),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
