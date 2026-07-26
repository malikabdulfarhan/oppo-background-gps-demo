import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/location_record.dart';

class TrackingController extends ChangeNotifier {
  static const updateInterval = Duration(milliseconds: 5000);
  static const _initialLatitude = 24.860735;
  static const _initialLongitude = 67.001137;

  final List<LocationRecord> _records = [];
  final List<LocationRecord> _routePoints = [];

  Timer? _timer;
  bool _isTracking = false;
  bool _followLocation = true;
  int _locationSampleCount = 0;
  LocationRecord? _latestLocation;

  bool get isTracking => _isTracking;
  bool get followLocation => _followLocation;
  int get locationSampleCount => _locationSampleCount;
  int get polylinePointCount => _routePoints.length;
  LocationRecord? get latestLocation => _latestLocation;
  List<LocationRecord> get records => List.unmodifiable(_records);
  List<LocationRecord> get routePoints => List.unmodifiable(_routePoints);

  void startTracking() {
    if (_isTracking) {
      return;
    }

    _isTracking = true;
    _timer = Timer.periodic(updateInterval, (_) => _addFakeLocation());
    notifyListeners();
  }

  void stopTracking() {
    if (!_isTracking) {
      return;
    }

    _timer?.cancel();
    _timer = null;
    _isTracking = false;
    notifyListeners();
  }

  void setFollowLocation(bool value) {
    if (_followLocation == value) {
      return;
    }

    _followLocation = value;
    notifyListeners();
  }

  void clearRoute() {
    if (_routePoints.isEmpty) {
      return;
    }

    _routePoints.clear();
    notifyListeners();
  }

  void clearLogs() {
    if (_records.isEmpty) {
      return;
    }

    _records.clear();
    notifyListeners();
  }

  void _addFakeLocation() {
    _locationSampleCount += 1;
    final step = _locationSampleCount.toDouble();
    final record = LocationRecord(
      timestamp: DateTime.now(),
      latitude:
          _initialLatitude +
          (step * 0.00012) +
          (math.sin(step * 0.85) * 0.00005),
      longitude:
          _initialLongitude +
          (step * 0.00015) +
          (math.cos(step * 0.65) * 0.00006),
      accuracyMeters: 4.8 + ((_locationSampleCount % 5) * 0.7),
    );

    _latestLocation = record;
    _routePoints.add(record);
    _records.insert(0, record);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
