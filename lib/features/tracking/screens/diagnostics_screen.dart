import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/tracking_controller.dart';
import '../services/tracking_models.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({required this.controller, super.key});

  final TrackingController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.serviceStatus;
    final battery = controller.batteryStatus;
    final prefs = controller.mapPreferences;
    final engine = controller.locationEngineConfiguration;
    final amap = controller.amapConfiguration;
    final metrics = controller.routeMetrics;
    final rows = <(String, String)>[
      ('AMap API key configured', amap.apiKeyConfigured ? 'Yes' : 'No'),
      (
        'AMap SDK compile integration',
        amap.sdkCompileIntegration ? 'Present' : 'Absent',
      ),
      ('AMap SDK runtime verification', amap.runtimeVerification.label),
      (
        'AMap runtime initialized',
        switch (amap.runtimeState) {
          AmapRuntimeState.verified => 'Yes',
          AmapRuntimeState.failed => 'No',
          AmapRuntimeState.notAttempted => 'Not attempted',
        },
      ),
      ('AMap privacy consent', _consent(status.amapPrivacyConsent)),
      ('AMap SDK initialized', status.amapSdkInitialized ? 'Yes' : 'No'),
      ('Selected location engine', engine.selected.label),
      (
        'Active location engine',
        status.activeLocationEngine?.label ?? engine.resolved.label,
      ),
      ('Fallback reason', engine.fallbackReason ?? 'None'),
      (
        'Location permission',
        status.locationPermissionGranted ? 'Granted' : 'Not granted',
      ),
      (
        'Notification permission',
        status.notificationPermissionGranted ? 'Granted' : 'Not granted',
      ),
      (
        'Native foreground service running',
        status.serviceRunning ? 'Yes' : 'No',
      ),
      ('Current session', status.sessionId ?? 'No active session'),
      (
        'Last location timestamp',
        status.lastLocationTimestamp?.toLocal().toIso8601String() ?? 'None',
      ),
      ('Longest update gap', '${metrics.longestUpdateGap.inSeconds} seconds'),
      ('CSV schema version', engine.csvSchemaVersion),
      (
        'Last AMap location type',
        '${status.lastAmapLocationType ?? 'Unknown'}',
      ),
      ('Last AMap error code', '${status.lastAmapErrorCode ?? 'None'}'),
      ('Last AMap error', status.lastAmapErrorMessage ?? 'None'),
      ('Satellite count', '${status.satelliteCount ?? 'Unknown'}'),
      ('GPS accuracy status', '${status.gpsAccuracyStatus ?? 'Unknown'}'),
      ('Coordinate system', status.coordinateSystem ?? 'Unknown'),
      ('Current map type', prefs.mapType.wireValue),
      ('Traffic layer', prefs.trafficEnabled ? 'On' : 'Off'),
      (
        'Battery optimization',
        battery.isIgnoringBatteryOptimizations ? 'Ignored' : 'Optimized',
      ),
      ('OPPO detected', battery.isOppo ? 'Yes' : 'No'),
      ('Android manufacturer', battery.manufacturer),
      ('Android model', battery.model),
      ('Android version', battery.androidVersion),
      ('ColorOS / build display', battery.buildDisplay),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Card(
          color: const Color(0xFFECFDF3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demo status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const _DemoStatusRow(label: 'Background GPS', value: 'Ready'),
                const _DemoStatusRow(
                  label: 'Locked-screen foreground service',
                  value: 'Ready for device testing',
                ),
                const _DemoStatusRow(
                  label: 'CSV continuous logs',
                  value: 'Ready',
                ),
                const _DemoStatusRow(label: 'Session history', value: 'Ready'),
                const _DemoStatusRow(label: 'Route replay', value: 'Ready'),
                const _DemoStatusRow(
                  label: 'AMap integration',
                  value: 'Prepared — API key required for runtime verification',
                ),
                const _DemoStatusRow(
                  label: 'Tencent/NetEase IM',
                  value: 'Not included in this phase',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final (label, value) in rows)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(label),
                    subtitle: Text(value),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            final report = rows
                .map((entry) => '${entry.$1}: ${entry.$2}')
                .join('\n');
            await Clipboard.setData(ClipboardData(text: report));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Diagnostic report copied.')),
              );
            }
          },
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Copy Diagnostic Report'),
        ),
        const SizedBox(height: 8),
        const Text(
          'The report excludes the AMap key, signing certificates, and '
          'absolute app-private file paths.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  static String _consent(Object value) {
    final text = value.toString().split('.').last;
    return text == 'notSelected'
        ? 'Not selected'
        : '${text[0].toUpperCase()}${text.substring(1)}';
  }
}

class _DemoStatusRow extends StatelessWidget {
  const _DemoStatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
