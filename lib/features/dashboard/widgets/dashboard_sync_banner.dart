import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/connectivity_service.dart';
import 'dashboard_status.dart';

class DashboardSyncBanner extends StatelessWidget {
  const DashboardSyncBanner({
    super.key,
    required this.network,
    required this.pendingCount,
    required this.syncing,
    required this.loading,
    required this.actionsEnabled,
    required this.hasRejections,
    required this.onSync,
    required this.onRetry,
    required this.onCheckNetwork,
    this.syncMessage,
    this.serverMessage,
  });

  final NetworkStatus network;
  final int? pendingCount;
  final bool syncing;
  final bool loading;
  final bool actionsEnabled;
  final bool hasRejections;
  final String? syncMessage;
  final String? serverMessage;
  final VoidCallback onSync;
  final VoidCallback onRetry;
  final VoidCallback onCheckNetwork;

  @override
  Widget build(BuildContext context) {
    final connected = network == NetworkStatus.connected;
    final pending = pendingCount ?? 0;
    final networkLabel = switch (network) {
      NetworkStatus.connected => 'Network connected',
      NetworkStatus.disconnected => 'Offline — saved data remains available',
      NetworkStatus.unknown => 'Network status unavailable',
    };
    final detail = connected ? serverMessage ?? syncMessage : null;
    final needsAttention =
        pending > 0 ||
        pendingCount == null ||
        !connected ||
        syncing ||
        detail != null ||
        hasRejections;
    if (!needsAttention) {
      return Row(
        children: [
          const Icon(Icons.wifi, size: 18, color: AppColors.secondaryText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              networkLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    final tone = hasRejections || (connected && serverMessage != null)
        ? StatusTone.error
        : pending > 0 || !connected || pendingCount == null
        ? StatusTone.warning
        : StatusTone.info;
    final title = loading
        ? 'Loading saved attendance…'
        : syncing
        ? 'Synchronizing attendance…'
        : pendingCount == null
        ? 'Pending attendance unavailable'
        : pending > 0
        ? '$pending attendance ${pending == 1 ? 'event' : 'events'} pending sync'
        : hasRejections
        ? 'Attendance needs attention'
        : connected && serverMessage != null
        ? 'Could not refresh dashboard'
        : networkLabel;
    return DashboardMessage(
      tone: loading || syncing ? StatusTone.info : tone,
      message: title,
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != networkLabel) ...[
            const SizedBox(height: 6),
            Text(networkLabel, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (pending > 0) ...[
            const SizedBox(height: 6),
            Text(
              connected
                  ? 'Saved on this device.'
                  : 'Saved on this device. Reconnect to sync.',
            ),
          ],
          if (hasRejections) ...[
            const SizedBox(height: 6),
            const Text(
              'Review the rejection details in your attendance records.',
            ),
          ],
          if (detail != null && !loading && !syncing) ...[
            const SizedBox(height: 6),
            Text(detail),
          ],
          if (syncing) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              semanticsLabel: 'Synchronizing attendance',
            ),
          ],
          if (pending > 0)
            TextButton.icon(
              key: const ValueKey('sync-now'),
              onPressed: actionsEnabled && connected && !syncing && !loading
                  ? onSync
                  : null,
              icon: const Icon(Icons.sync, size: 18),
              label: Text(syncing ? 'Syncing…' : 'Sync Now'),
            ),
          if (!loading &&
              (pendingCount == null || (connected && serverMessage != null)))
            TextButton(
              onPressed: actionsEnabled && !syncing ? onRetry : null,
              child: const Text('Retry'),
            ),
          if (network == NetworkStatus.unknown)
            TextButton(
              onPressed: loading || syncing ? null : onCheckNetwork,
              child: const Text('Check connection'),
            ),
        ],
      ),
    );
  }
}
