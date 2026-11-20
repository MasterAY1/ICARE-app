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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final twoColMetrics = constraints.maxWidth >= 280;
        final twoColActions = constraints.maxWidth >= 320;
        final visibleActivity = recentActivity.take(3).toList();

        final statusTile = Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                size: 16,
                color: isOnline ? tokens.successDot : tokens.warningDot,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync Status',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isOnline
                            ? tokens.successText
                            : tokens.warningText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        final outboxTile = InkWell(
          onTap: pendingOutboxCount > 0 ? onOpenOutboxSync : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sync_outlined,
                  size: 16,
                  color: pendingOutboxCount > 0
                      ? tokens.warningDot
                      : tokens.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Outbox',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: tokens.textMuted,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$pendingOutboxCount queued',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        final clearBtn = OutlinedButton.icon(
          onPressed: onClearLocalCache,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          icon: const Icon(Icons.cleaning_services_outlined, size: 15),
          label: const Text('Clear Read Cache',
              overflow: TextOverflow.ellipsis),
        );

        final signOutBtn = OutlinedButton.icon(
          onPressed: onSignOut,
          style: OutlinedButton.styleFrom(
            foregroundColor: tokens.dangerText,
            side: BorderSide(color: tokens.dangerBorder),
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          icon: const Icon(Icons.logout, size: 15),
          label: const Text('Sign Out', overflow: TextOverflow.ellipsis),
        );

        return IcareCard(
          padding: EdgeInsets.all(isCompact ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: tokens.brandSoftBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.brandSoftBorder),
                    ),
                    child: Icon(
                      Icons.devices_outlined,
                      size: 17,
                      color: tokens.brandSoftText,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Device & Session',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (twoColMetrics)
                Row(
                  children: [
                    Expanded(child: statusTile),
                    const SizedBox(width: 8),
                    Expanded(child: outboxTile),
                  ],
                )
              else ...[
                statusTile,
                const SizedBox(height: 8),
                outboxTile,
              ],

              const SizedBox(height: 10),
              if (twoColActions)
                Row(
                  children: [
                    Expanded(child: clearBtn),
                    const SizedBox(width: 8),
                    Expanded(child: signOutBtn),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    clearBtn,
                    const SizedBox(height: 8),
                    signOutBtn,
                  ],
                ),

              const SizedBox(height: 14),
              Divider(color: tokens.borderSubtle, height: 1),
              const SizedBox(height: 10),

              Text(
                'Recent Sign-Ins',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              if (visibleActivity.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Text(
                    'No recent sign-in records.',
                    softWrap: true,
                    style: TextStyle(fontSize: 12, color: tokens.textMuted),
                  ),
                )
              else
                Column(
                  children: visibleActivity.map((entry) {
                    final deviceSummary = [
                      entry.deviceName,
                      entry.browser,
                      entry.operatingSystem,
                    ]
                        .where((s) => s != null && s.trim().isNotEmpty)
                        .join(' · ');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 15,
                            color: entry.status.toUpperCase() == 'SUCCESS'
                                ? tokens.successDot
                                : tokens.warningDot,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatTimestamp(entry.loginTime),
                                  style: TextStyle(
                                    fontSize: 12,
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
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
      },
    );
  }
}
