import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_background_gps_demo/features/tracking/analytics/route_metrics_calculator.dart';
import 'package:oppo_background_gps_demo/features/tracking/models/location_record.dart';

void main() {
  const calculator = RouteMetricsCalculator();

  test('handles zero and one location records', () {
    expect(calculator.calculate(const []).totalSamples, 0);

    final metrics = calculator.calculate([
      _record(0, latitude: 24.86, longitude: 67.0, accuracy: 6),
    ], now: DateTime.utc(2026, 1, 1, 0, 0, 10));

    expect(metrics.totalSamples, 1);
    expect(metrics.uniqueRoutePoints, 1);
    expect(metrics.distanceMeters, 0);
    expect(metrics.bestAccuracyMeters, 6);
  });

  test('calculates distance, accuracy, speed, and update gaps', () {
    final metrics = calculator.calculate([
      _record(0, latitude: 24.8600, longitude: 67.0000, accuracy: 8, speed: 1),
      _record(5, latitude: 24.8610, longitude: 67.0000, accuracy: 4, speed: 3),
      _record(20, latitude: 24.8620, longitude: 67.0000, accuracy: 6, speed: 2),
    ]);

    expect(metrics.distanceMeters, closeTo(222.4, 2));
    expect(metrics.averageAccuracyMeters, 6);
    expect(metrics.bestAccuracyMeters, 4);
    expect(metrics.averageSpeedMetersPerSecond, 2);
    expect(metrics.maximumSpeedMetersPerSecond, 3);
    expect(metrics.longestUpdateGap, const Duration(seconds: 15));
  });

  test('stationary samples count but duplicate polyline points do not', () {
    final metrics = calculator.calculate([
      _record(0, latitude: 24.86, longitude: 67, accuracy: 5),
      _record(5, latitude: 24.86, longitude: 67, accuracy: 5),
      _record(10, latitude: 24.861, longitude: 67, accuracy: 5),
    ]);

    expect(metrics.totalSamples, 3);
    expect(metrics.uniqueRoutePoints, 2);
    expect(metrics.distanceMeters, greaterThan(100));
  });
}

LocationRecord _record(
  int seconds, {
  required double latitude,
  required double longitude,
  required double accuracy,
  double? speed,
}) => LocationRecord(
  timestamp: DateTime.utc(2026, 1, 1).add(Duration(seconds: seconds)),
  latitude: latitude,
  longitude: longitude,
  accuracyMeters: accuracy,
  speedMetersPerSecond: speed,
);
