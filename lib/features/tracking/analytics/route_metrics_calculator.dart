import 'dart:math' as math;

import '../models/location_record.dart';
import 'route_metrics.dart';

class RouteMetricsCalculator {
  const RouteMetricsCalculator();

  RouteMetrics calculate(
    Iterable<LocationRecord> source, {
    DateTime? now,
    int additionalAmapErrors = 0,
  }) {
    final records = source.where(_isValid).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (records.isEmpty) {
      return RouteMetrics(
        duration: Duration.zero,
        totalSamples: 0,
        uniqueRoutePoints: 0,
        distanceMeters: 0,
        currentSpeedMetersPerSecond: 0,
        averageSpeedMetersPerSecond: 0,
        maximumSpeedMetersPerSecond: 0,
        latestAccuracyMeters: 0,
        averageAccuracyMeters: 0,
        bestAccuracyMeters: 0,
        longestUpdateGap: Duration.zero,
        timeSinceLastUpdate: Duration.zero,
        lockedScreenSamples: 0,
        gpsSamples: 0,
        networkSamples: 0,
        amapErrorCount: additionalAmapErrors,
      );
    }

    final unique = <LocationRecord>[];
    for (final record in records) {
      if (unique.isEmpty ||
          unique.last.latitude != record.latitude ||
          unique.last.longitude != record.longitude) {
        unique.add(record);
      }
    }
    var distance = 0.0;
    for (var index = 1; index < unique.length; index += 1) {
      distance += _distanceMeters(unique[index - 1], unique[index]);
    }

    final speeds = records
        .map((record) => record.speedMetersPerSecond)
        .whereType<double>()
        .where((speed) => speed.isFinite && speed >= 0)
        .toList();
    final accuracies = records.map((record) => record.accuracyMeters).toList();
    var longestGap = Duration.zero;
    for (var index = 1; index < records.length; index += 1) {
      final gap = records[index].timestamp.difference(
        records[index - 1].timestamp,
      );
      if (!gap.isNegative && gap > longestGap) {
        longestGap = gap;
      }
    }
    final latest = records.last;
    final referenceTime = now ?? DateTime.now();
    final sinceLast = referenceTime.difference(latest.timestamp);

    return RouteMetrics(
      duration: latest.timestamp.difference(records.first.timestamp),
      totalSamples: records.length,
      uniqueRoutePoints: unique.length,
      distanceMeters: distance.isFinite ? distance : 0,
      currentSpeedMetersPerSecond:
          latest.speedMetersPerSecond?.takeIfFiniteNonNegative ?? 0,
      averageSpeedMetersPerSecond: speeds.isEmpty
          ? 0
          : speeds.reduce((a, b) => a + b) / speeds.length,
      maximumSpeedMetersPerSecond: speeds.isEmpty ? 0 : speeds.reduce(math.max),
      latestAccuracyMeters: latest.accuracyMeters,
      averageAccuracyMeters:
          accuracies.reduce((a, b) => a + b) / accuracies.length,
      bestAccuracyMeters: accuracies.reduce(math.min),
      longestUpdateGap: longestGap,
      timeSinceLastUpdate: sinceLast.isNegative ? Duration.zero : sinceLast,
      lockedScreenSamples: records
          .where((record) => record.screenState == 'LOCKED')
          .length,
      gpsSamples: records.where(_isGps).length,
      networkSamples: records.where(_isNetwork).length,
      amapErrorCount:
          additionalAmapErrors +
          records.where((record) => (record.amapErrorCode ?? 0) != 0).length,
    );
  }

  bool _isValid(LocationRecord record) =>
      record.latitude.isFinite &&
      record.longitude.isFinite &&
      record.accuracyMeters.isFinite &&
      record.latitude >= -90 &&
      record.latitude <= 90 &&
      record.longitude >= -180 &&
      record.longitude <= 180 &&
      record.accuracyMeters >= 0;

  bool _isGps(LocationRecord record) =>
      (record.provider ?? '').toLowerCase().contains('gps') ||
      record.amapLocationType == 1;

  bool _isNetwork(LocationRecord record) =>
      !_isGps(record) &&
      ((record.provider ?? '').toLowerCase().contains('network') ||
          record.amapLocationType != null);

  double _distanceMeters(LocationRecord first, LocationRecord second) {
    const earthRadiusMeters = 6371008.8;
    final lat1 = _radians(first.latitude);
    final lat2 = _radians(second.latitude);
    final deltaLatitude = _radians(second.latitude - first.latitude);
    final deltaLongitude = _radians(second.longitude - first.longitude);
    final a =
        math.sin(deltaLatitude / 2) * math.sin(deltaLatitude / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLongitude / 2) *
            math.sin(deltaLongitude / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}

extension on double? {
  double? get takeIfFiniteNonNegative {
    final value = this;
    return value != null && value.isFinite && value >= 0 ? value : null;
  }
}
