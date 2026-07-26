import 'package:flutter/material.dart';

import '../services/tracking_models.dart';

class ServiceStatusCard extends StatelessWidget {
  const ServiceStatusCard({
    required this.status,
    required this.batteryStatus,
    super.key,
  });

  final TrackingServiceStatus status;
  final BatteryOptimizationStatus batteryStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.settings_suggest_outlined,
                  color: Color(0xFF155EEF),
                ),
                const SizedBox(width: 9),
                Text(
                  'Native service status',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _StatusRow(
              label: 'Native service running',
              value: status.serviceRunning ? 'Yes' : 'No',
            ),
            _StatusRow(
              label: 'Last update',
              value: _formatDate(status.lastLocationTimestamp),
            ),
            _StatusRow(
              label: 'Current provider',
              value: status.currentProvider ?? 'Waiting',
            ),
            _StatusRow(
              label: 'Screen state',
              value: status.screenState ?? 'Unknown',
            ),
            _StatusRow(
              label: 'Current session ID',
              value: status.sessionId ?? 'No active session',
            ),
            _StatusRow(
              label: 'Current log file',
              value: status.currentLogFileName ?? 'Not created',
            ),
            const Divider(height: 25),
            Text(
              'Device diagnostics',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: 'Device',
              value: '${batteryStatus.manufacturer} ${batteryStatus.model}',
            ),
            _StatusRow(label: 'Android', value: batteryStatus.androidVersion),
            _StatusRow(
              label: 'Battery optimization',
              value: batteryStatus.isIgnoringBatteryOptimizations
                  ? 'Unrestricted'
                  : 'Optimized',
            ),
            _StatusRow(
              label: 'OPPO manufacturer',
              value: batteryStatus.isOppo ? 'Yes' : 'No',
            ),
            const SizedBox(height: 10),
            const Text(
              'ColorOS may apply additional background restrictions. Final '
              'stability must be tested on the target OPPO model.',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'No sample yet';
    }
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}:'
        '${twoDigits(local.second)}';
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(
                color: Color(0xFF344054),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
