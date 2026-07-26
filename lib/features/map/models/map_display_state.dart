import '../../tracking/services/tracking_models.dart';
import 'map_point.dart';

class MapDisplayState {
  const MapDisplayState({
    required this.routePoints,
    required this.preferences,
    this.currentLocation,
    this.selectedPoint,
    this.followLocation = true,
  });

  final List<MapPoint> routePoints;
  final MapPoint? currentLocation;
  final MapPoint? selectedPoint;
  final bool followLocation;
  final TrackingMapPreferences preferences;

  Map<String, Object?> toPlatformMap() => {
    'routePoints': routePoints
        .map((point) => point.toPlatformMap())
        .toList(growable: false),
    'currentLocation': currentLocation?.toPlatformMap(),
    'selectedPoint': selectedPoint?.toPlatformMap(),
    'followLocation': followLocation,
    ...preferences.toMap(),
  };
}
