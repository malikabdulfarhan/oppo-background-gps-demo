import '../../tracking/models/location_record.dart';

class MapPoint {
  const MapPoint({
    required this.latitude,
    required this.longitude,
    required this.coordinateSystem,
    this.timestamp,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final String coordinateSystem;
  final DateTime? timestamp;
  final double? accuracyMeters;

  factory MapPoint.fromLocationRecord(LocationRecord record) => MapPoint(
    latitude: record.latitude,
    longitude: record.longitude,
    coordinateSystem: record.coordinateSystem,
    timestamp: record.timestamp,
    accuracyMeters: record.accuracyMeters,
  );

  Map<String, Object?> toPlatformMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'coordinateSystem': coordinateSystem,
    'timestamp': timestamp?.toUtc().toIso8601String(),
    'accuracy': accuracyMeters,
  };

  bool get isLegacy => coordinateSystem == 'WGS84_LEGACY';
}
