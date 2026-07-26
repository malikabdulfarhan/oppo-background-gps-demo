import 'package:flutter/material.dart';

import '../controllers/tracking_map_controller.dart';
import '../models/map_display_state.dart';
import '../widgets/amap_tracking_map.dart';
import '../widgets/fallback_route_map.dart';

abstract interface class TrackingMapAdapter {
  bool get isAvailable;

  Widget buildLiveMap({
    required MapDisplayState state,
    required TrackingMapController controller,
    required VoidCallback onUserGesture,
    required VoidCallback onInitializationFailed,
  });

  Widget buildReplayMap({
    required MapDisplayState state,
    required TrackingMapController controller,
    required VoidCallback onInitializationFailed,
  });
}

class AmapTrackingMapAdapter implements TrackingMapAdapter {
  const AmapTrackingMapAdapter({this.isAvailable = true});

  @override
  final bool isAvailable;

  @override
  Widget buildLiveMap({
    required MapDisplayState state,
    required TrackingMapController controller,
    required VoidCallback onUserGesture,
    required VoidCallback onInitializationFailed,
  }) => AmapTrackingMap(
    state: state,
    controller: controller,
    onUserGesture: onUserGesture,
    onInitializationFailed: onInitializationFailed,
  );

  @override
  Widget buildReplayMap({
    required MapDisplayState state,
    required TrackingMapController controller,
    required VoidCallback onInitializationFailed,
  }) => AmapTrackingMap(
    state: state,
    controller: controller,
    onUserGesture: () {},
    onInitializationFailed: onInitializationFailed,
  );
}

class FallbackRouteMapAdapter implements TrackingMapAdapter {
  const FallbackRouteMapAdapter({
    this.reason = 'AMap key not configured',
    this.isAvailable = true,
  });

  final String reason;

  @override
  final bool isAvailable;

  @override
  Widget buildLiveMap({
    required MapDisplayState state,
    required TrackingMapController controller,
    required VoidCallback onUserGesture,
    required VoidCallback onInitializationFailed,
  }) => FallbackRouteMap(state: state, reason: reason);

  @override
  Widget buildReplayMap({
    required MapDisplayState state,
    required TrackingMapController controller,
    required VoidCallback onInitializationFailed,
  }) => FallbackRouteMap(state: state, reason: reason);
}
