import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/tracking_controller.dart';
import '../services/tracking_service.dart';
import '../widgets/location_log_list.dart';
import '../widgets/map_placeholder.dart';
import '../widgets/service_status_card.dart';
import '../widgets/tracking_header.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({this.trackingService, super.key});

  final TrackingService? trackingService;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with WidgetsBindingObserver {
  late final TrackingController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TrackingController(trackingService: widget.trackingService);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.refreshNativeState());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Map Track Demo',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              TextButton.icon(
                onPressed: _controller.isTracking
                    ? () => _controller.stopTracking()
                    : null,
                icon: const Icon(Icons.stop_circle_outlined, size: 20),
                label: const Text('Stop'),
              ),
              IconButton(
                tooltip: 'Clear visible route',
                onPressed: _controller.polylinePointCount > 0
                    ? _controller.clearRoute
                    : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                TrackingHeader(
                  isStarting:
                      _controller.isStarting || _controller.isInitializing,
                  isTracking: _controller.isTracking,
                  hasServiceError: _controller.errorMessage != null,
                  polylinePointCount: _controller.polylinePointCount,
                  locationSampleCount: _controller.locationSampleCount,
                  updateIntervalMs:
                      TrackingController.updateInterval.inMilliseconds,
                  followLocation: _controller.followLocation,
                  onFollowChanged: _controller.setFollowLocation,
                ),
                if (_controller.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _MessageCard(
                    message: _controller.errorMessage!,
                    isError: true,
                    actionLabel: switch (_controller.recoveryAction) {
                      TrackingRecoveryAction.openAppSettings => 'Open Settings',
                      TrackingRecoveryAction.openLocationSettings =>
                        'Enable GPS',
                      TrackingRecoveryAction.none => null,
                    },
                    onActionPressed: _openRecoverySettings,
                  ),
                ],
                if (_controller.warningMessage != null) ...[
                  const SizedBox(height: 12),
                  _MessageCard(
                    message: _controller.warningMessage!,
                    actionLabel:
                        _controller.warningMessage!.startsWith(
                          'Notification permission',
                        )
                        ? 'Open Settings'
                        : null,
                    onActionPressed: () =>
                        _openSettings(_controller.openAppSettings),
                  ),
                ],
                if (_controller.isTracking) ...[
                  const SizedBox(height: 12),
                  const _BackgroundTrackingNotice(),
                ],
                const SizedBox(height: 12),
                _TrackingControls(
                  controller: _controller,
                  onBatterySettings: () => _openSettings(
                    _controller.openBatteryOptimizationSettings,
                  ),
                  onAppSettings: () =>
                      _openSettings(_controller.openAppSettings),
                  onShareLog: _shareCurrentLog,
                ),
                const SizedBox(height: 12),
                ServiceStatusCard(
                  status: _controller.serviceStatus,
                  batteryStatus: _controller.batteryStatus,
                ),
                const SizedBox(height: 20),
                _SectionHeading(
                  title: 'Route preview',
                  subtitle: 'Live GPS route recorded on this device',
                  trailing: _controller.isTracking ? const _LiveBadge() : null,
                ),
                const SizedBox(height: 10),
                MapPlaceholder(
                  routePoints: _controller.routePoints,
                  latestLocation: _controller.latestLocation,
                  followLocation: _controller.followLocation,
                ),
                const SizedBox(height: 24),
                _SectionHeading(
                  title: 'Location log',
                  subtitle: _controller.records.isEmpty
                      ? 'Persisted samples appear after native GPS updates'
                      : '${_controller.records.length} visible '
                            '${_controller.records.length == 1 ? 'record' : 'records'}',
                ),
                const SizedBox(height: 10),
                LocationLogList(records: _controller.records),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openRecoverySettings() async {
    final action = switch (_controller.recoveryAction) {
      TrackingRecoveryAction.openAppSettings => _controller.openAppSettings,
      TrackingRecoveryAction.openLocationSettings =>
        _controller.openLocationSettings,
      TrackingRecoveryAction.none => null,
    };
    if (action != null) {
      await _openSettings(action);
    }
  }

  Future<void> _openSettings(Future<bool> Function() action) async {
    final opened = await action();
    if (!mounted || opened) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open settings on this device.')),
    );
  }

  Future<void> _shareCurrentLog() async {
    final shared = await _controller.shareCurrentLog();
    if (!mounted || shared) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No current CSV tracking log is available to share.'),
      ),
    );
  }
}

class _TrackingControls extends StatelessWidget {
  const _TrackingControls({
    required this.controller,
    required this.onBatterySettings,
    required this.onAppSettings,
    required this.onShareLog,
  });

  final TrackingController controller;
  final VoidCallback onBatterySettings;
  final VoidCallback onAppSettings;
  final VoidCallback onShareLog;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed:
                  controller.isTracking ||
                      controller.isStarting ||
                      controller.isInitializing
                  ? null
                  : () => controller.startTracking(),
              icon: controller.isStarting || controller.isInitializing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                controller.isStarting
                    ? 'Starting...'
                    : controller.isInitializing
                    ? 'Connecting...'
                    : 'Start Tracking',
              ),
            ),
            OutlinedButton.icon(
              onPressed: controller.isTracking || controller.isStarting
                  ? () => controller.stopTracking()
                  : null,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Stop Tracking'),
            ),
            OutlinedButton.icon(
              onPressed: controller.polylinePointCount > 0
                  ? controller.clearRoute
                  : null,
              icon: const Icon(Icons.route_outlined),
              label: const Text('Clear Route'),
            ),
            TextButton.icon(
              onPressed: controller.records.isNotEmpty
                  ? controller.clearLogs
                  : null,
              icon: const Icon(Icons.notes_rounded),
              label: const Text('Clear Logs'),
            ),
            OutlinedButton.icon(
              onPressed: onBatterySettings,
              icon: const Icon(Icons.battery_saver_outlined),
              label: const Text('Open Battery Settings'),
            ),
            OutlinedButton.icon(
              onPressed: onAppSettings,
              icon: const Icon(Icons.app_settings_alt_outlined),
              label: const Text('Open App Settings'),
            ),
            OutlinedButton.icon(
              onPressed: controller.serviceStatus.currentLogFileName != null
                  ? onShareLog
                  : null,
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Export / Share Current Log'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.onActionPressed,
    this.isError = false,
    this.actionLabel,
  });

  final String message;
  final bool isError;
  final String? actionLabel;
  final VoidCallback onActionPressed;

  @override
  Widget build(BuildContext context) {
    final background = isError
        ? const Color(0xFFFFF4ED)
        : const Color(0xFFFFFAEB);
    final border = isError ? const Color(0xFFFED7AA) : const Color(0xFFFDE68A);
    return Card(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              color: const Color(0xFFB54708),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF7A2E0E),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: onActionPressed, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackgroundTrackingNotice extends StatelessWidget {
  const _BackgroundTrackingNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA6F4C5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_clock_outlined, color: Color(0xFF027A48)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tracking continues while this app is minimized or the screen is locked.',
              style: TextStyle(
                color: Color(0xFF027A48),
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF667085)),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFF12B76A)),
          SizedBox(width: 6),
          Text(
            'LIVE',
            style: TextStyle(
              color: Color(0xFF027A48),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
