import 'dart:async';

import 'package:flutter/material.dart';

import '../../map/controllers/tracking_map_controller.dart';
import '../../map/models/map_display_state.dart';
import '../../map/models/map_point.dart';
import '../../map/services/tracking_map_adapter.dart';
import '../../map/widgets/map_configuration_card.dart';
import '../../map/widgets/map_control_panel.dart';
import '../controllers/tracking_controller.dart';
import '../models/location_record.dart';
import '../services/tracking_models.dart';
import '../widgets/location_log_list.dart';
import '../widgets/route_statistics_card.dart';
import '../widgets/service_status_card.dart';
import '../widgets/tracking_header.dart';

class LiveTrackingView extends StatefulWidget {
  const LiveTrackingView({
    required this.controller,
    required this.onReviewPrivacy,
    this.mapBuilder,
    this.trackingMapAdapter,
    super.key,
  });

  final TrackingController controller;
  final VoidCallback onReviewPrivacy;
  final Widget Function(MapDisplayState state)? mapBuilder;
  final TrackingMapAdapter? trackingMapAdapter;

  @override
  State<LiveTrackingView> createState() => _LiveTrackingViewState();
}

class _LiveTrackingViewState extends State<LiveTrackingView> {
  final TrackingMapController _mapController = TrackingMapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final configuration = controller.amapConfiguration;
    final engineConfiguration = controller.locationEngineConfiguration;
    final displayState = MapDisplayState(
      routePoints: _displayPoints(controller.routePoints),
      currentLocation: controller.latestLocation == null
          ? null
          : MapPoint.fromLocationRecord(controller.latestLocation!),
      followLocation: controller.followLocation,
      preferences: controller.mapPreferences,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        TrackingHeader(
          isStarting: controller.isStarting || controller.isInitializing,
          isTracking: controller.isTracking,
          hasServiceError: controller.errorMessage != null,
          polylinePointCount: controller.polylinePointCount,
          locationSampleCount: controller.locationSampleCount,
          updateIntervalMs: TrackingController.updateInterval.inMilliseconds,
          followLocation: controller.followLocation,
          onFollowChanged: controller.setFollowLocation,
        ),
        if (controller.errorMessage != null) ...[
          const SizedBox(height: 12),
          _MessageCard(
            message: controller.errorMessage!,
            isError: true,
            actionLabel: switch (controller.recoveryAction) {
              TrackingRecoveryAction.openAppSettings => 'Open Settings',
              TrackingRecoveryAction.openLocationSettings => 'Enable GPS',
              TrackingRecoveryAction.none => null,
            },
            onActionPressed: () => switch (controller.recoveryAction) {
              TrackingRecoveryAction.openAppSettings =>
                controller.openAppSettings(),
              TrackingRecoveryAction.openLocationSettings =>
                controller.openLocationSettings(),
              TrackingRecoveryAction.none => Future.value(false),
            },
          ),
        ],
        if (controller.warningMessage != null) ...[
          const SizedBox(height: 12),
          _MessageCard(message: controller.warningMessage!),
        ],
        if (controller.isTracking) ...[
          const SizedBox(height: 12),
          const _BackgroundTrackingNotice(),
        ],
        const SizedBox(height: 12),
        _TrackingControls(controller: controller),
        const SizedBox(height: 12),
        ServiceStatusCard(
          status: controller.serviceStatus,
          batteryStatus: controller.batteryStatus,
        ),
        const SizedBox(height: 16),
        if (!configuration.apiKeyConfigured)
          MapConfigurationCard(
            onContinueWithAndroid: () => unawaited(
              controller.setLocationEnginePreference(
                LocationEnginePreference.androidGpsDemo,
              ),
            ),
          )
        else if (configuration.privacyConsent != AmapPrivacyConsent.accepted &&
            engineConfiguration.selected !=
                LocationEnginePreference.androidGpsDemo)
          _MessageCard(
            message: configuration.privacyConsent == AmapPrivacyConsent.declined
                ? 'AMap privacy consent was declined. Android GPS Demo Mode remains available.'
                : 'Review AMap privacy consent to enable AMap. Android GPS Demo Mode remains available.',
            actionLabel: 'Review',
            onActionPressed: () async => widget.onReviewPrivacy(),
          ),
        const SizedBox(height: 10),
        if (configuration.canUseAmap &&
            controller.shouldUseAmapMap &&
            !configuration.networkAvailable) ...[
          const _MessageCard(
            message:
                'No internet connection is available. AMap tiles may be '
                'unavailable until connectivity returns.',
          ),
          const SizedBox(height: 10),
        ],
        if (widget.mapBuilder case final builder?)
          builder(displayState)
        else
          _mapAdapter(controller).buildLiveMap(
            state: displayState,
            controller: _mapController,
            onUserGesture: () => controller.setFollowLocation(false),
            onInitializationFailed: () {
              unawaited(controller.handleAmapInitializationFailure());
            },
          ),
        const SizedBox(height: 10),
        _CurrentLocationBar(controller: controller),
        const SizedBox(height: 10),
        MapControlPanel(
          preferences: controller.mapPreferences,
          followLocation: controller.followLocation,
          onRecenter: () {
            controller.setFollowLocation(true);
            _mapController.recenter();
          },
          onFitRoute: () => _mapController.fitRoute(),
          onFollowChanged: controller.setFollowLocation,
          onPreferencesChanged: controller.updateMapPreferences,
        ),
        const SizedBox(height: 16),
        RouteStatisticsCard(metrics: controller.routeMetrics),
        const SizedBox(height: 20),
        Text(
          'Location log',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        LocationLogList(records: controller.records),
      ],
    );
  }

  TrackingMapAdapter _mapAdapter(TrackingController controller) {
    final injected = widget.trackingMapAdapter;
    if (injected != null) {
      return injected;
    }
    if (controller.shouldUseAmapMap) {
      return const AmapTrackingMapAdapter();
    }
    final reason = !controller.amapConfiguration.apiKeyConfigured
        ? 'AMap key not configured'
        : controller.locationEngineConfiguration.fallbackReason ??
              controller.locationEngineConfiguration.amapUnavailableReason ??
              'Android GPS Demo Mode';
    return FallbackRouteMapAdapter(reason: reason);
  }
}

List<MapPoint> _displayPoints(List<LocationRecord> records) {
  const limit = 2000;
  if (records.isEmpty) {
    return const [];
  }
  final stride = records.length <= limit ? 1 : (records.length / limit).ceil();
  final points = <MapPoint>[
    for (var index = 0; index < records.length; index += stride)
      MapPoint.fromLocationRecord(records[index]),
  ];
  if ((records.length - 1) % stride != 0) {
    points.add(MapPoint.fromLocationRecord(records.last));
  }
  return points;
}

class _CurrentLocationBar extends StatelessWidget {
  const _CurrentLocationBar({required this.controller});
  final TrackingController controller;

  @override
  Widget build(BuildContext context) {
    final location = controller.latestLocation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          location == null
              ? 'Waiting for the first GPS sample'
              : '${location.latitude.toStringAsFixed(6)}, '
                    '${location.longitude.toStringAsFixed(6)} • '
                    '±${location.accuracyMeters.toStringAsFixed(1)} m • '
                    '${location.locationEngine == 'AMAP' ? 'AMap type ${location.amapLocationType ?? 'Unknown'}' : 'Android GPS'}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _TrackingControls extends StatelessWidget {
  const _TrackingControls({required this.controller});

  final TrackingController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  : controller.startTracking,
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
                controller.isStarting ? 'Starting...' : 'Start Tracking',
              ),
            ),
            OutlinedButton.icon(
              onPressed: controller.isTracking || controller.isStarting
                  ? controller.stopTracking
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
              onPressed: controller.serviceStatus.currentLogFileName != null
                  ? () => controller.shareCurrentLog()
                  : null,
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Share Current CSV'),
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
    this.isError = false,
    this.actionLabel,
    this.onActionPressed,
  });

  final String message;
  final bool isError;
  final String? actionLabel;
  final Future<Object?> Function()? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isError ? const Color(0xFFFFF4ED) : const Color(0xFFFFFAEB),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: const Color(0xFFB54708),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            if (actionLabel != null)
              TextButton(
                onPressed: onActionPressed == null
                    ? null
                    : () => onActionPressed!(),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundTrackingNotice extends StatelessWidget {
  const _BackgroundTrackingNotice();

  @override
  Widget build(BuildContext context) => Container(
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
            'Tracking continues while minimized or locked through the native '
            'foreground service. Android may still stop processes under '
            'system or vendor resource policies.',
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
