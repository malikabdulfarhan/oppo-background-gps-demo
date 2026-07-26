import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/tracking_controller.dart';
import '../services/location_service.dart';
import '../widgets/location_log_list.dart';
import '../widgets/map_placeholder.dart';
import '../widgets/tracking_header.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({this.locationService, super.key});

  final LocationService? locationService;

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
    _controller = TrackingController(locationService: widget.locationService);
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
    final leftForeground =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (leftForeground && _controller.isTracking) {
      unawaited(_controller.stopTracking());
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
                tooltip: 'Delete route',
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
                  isStarting: _controller.isStarting,
                  isTracking: _controller.isTracking,
                  polylinePointCount: _controller.polylinePointCount,
                  locationSampleCount: _controller.locationSampleCount,
                  updateIntervalMs:
                      TrackingController.updateInterval.inMilliseconds,
                  followLocation: _controller.followLocation,
                  onFollowChanged: _controller.setFollowLocation,
                ),
                if (_controller.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _TrackingErrorCard(
                    message: _controller.errorMessage!,
                    recoveryAction: _controller.recoveryAction,
                    onRecoveryPressed: _openRecoverySettings,
                  ),
                ],
                const SizedBox(height: 12),
                _TrackingControls(controller: _controller),
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
                      ? 'Samples will appear every 5 seconds'
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
    final opened = switch (_controller.recoveryAction) {
      TrackingRecoveryAction.openAppSettings =>
        await _controller.openAppSettings(),
      TrackingRecoveryAction.openLocationSettings =>
        await _controller.openLocationSettings(),
      TrackingRecoveryAction.none => false,
    };

    if (!mounted || opened) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open settings on this device.')),
    );
  }
}

class _TrackingControls extends StatelessWidget {
  const _TrackingControls({required this.controller});

  final TrackingController controller;

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
              onPressed: controller.isTracking || controller.isStarting
                  ? null
                  : () => controller.startTracking(),
              icon: controller.isStarting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                controller.isStarting ? 'Starting…' : 'Start Tracking',
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
          ],
        ),
      ),
    );
  }
}

class _TrackingErrorCard extends StatelessWidget {
  const _TrackingErrorCard({
    required this.message,
    required this.recoveryAction,
    required this.onRecoveryPressed,
  });

  final String message;
  final TrackingRecoveryAction recoveryAction;
  final VoidCallback onRecoveryPressed;

  @override
  Widget build(BuildContext context) {
    final actionLabel = switch (recoveryAction) {
      TrackingRecoveryAction.openAppSettings => 'Open Settings',
      TrackingRecoveryAction.openLocationSettings => 'Enable GPS',
      TrackingRecoveryAction.none => null,
    };

    return Card(
      color: const Color(0xFFFFF4ED),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFED7AA)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFB54708)),
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
              TextButton(
                onPressed: onRecoveryPressed,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
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
