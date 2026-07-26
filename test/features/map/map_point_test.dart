import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_background_gps_demo/features/map/models/map_point.dart';
import 'package:oppo_background_gps_demo/features/tracking/models/location_record.dart';

void main() {
  test('converts Phase 4 AMap record without changing raw coordinates', () {
    final point = MapPoint.fromLocationRecord(
      LocationRecord(
        timestamp: DateTime.utc(2026),
        latitude: 31.2304,
        longitude: 121.4737,
        accuracyMeters: 5,
        coordinateSystem: 'GCJ02',
      ),
    );

    expect(point.latitude, 31.2304);
    expect(point.longitude, 121.4737);
    expect(point.isLegacy, isFalse);
    expect(point.toPlatformMap()['coordinateSystem'], 'GCJ02');
  });

  test('marks legacy WGS84 point for native display-only conversion', () {
    final record = LocationRecord.tryParse({
      'timestamp': '2026-01-01T00:00:00.000Z',
      'latitude': 39.9,
      'longitude': 116.4,
      'accuracy': 8,
      'locationEngine': 'LEGACY',
      'coordinateSystem': 'WGS84_LEGACY',
    });

    final point = MapPoint.fromLocationRecord(record!);
    expect(point.isLegacy, isTrue);
    expect(point.latitude, 39.9);
    expect(point.toPlatformMap()['coordinateSystem'], 'WGS84_LEGACY');
  });
}
