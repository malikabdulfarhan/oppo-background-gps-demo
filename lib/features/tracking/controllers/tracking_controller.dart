import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location_record.dart';
import '../services/location_service.dart';

enum TrackingRecoveryAction { none, openAppSettings, openLocationSettings }

class TrackingController extends ChangeNotifier {
  TrackingController({LocationService? locationService})
    : _locationService = locationService ?? LocationService();

  static const updateInterval = LocationService.updateInterval;

  final LocationService _locationService;
  final List<LocationRecord> _records = [];
  final List<LocationRecord> _routePoints = [];

  StreamSubscription<Position>? _positionSubscription;
  bool _isStarting = false;
  bool _isTracking = false;
  bool _followLocation = true;
  bool _isDisposed = false;
  int _startRequestId = 0;
  int _locationSampleCount = 0;
  LocationRecord? _latestLocation;
  String? _errorMessage;
  TrackingRecoveryAction _recoveryAction = TrackingRecoveryAction.none;

  bool get isStarting => _isStarting;
  bool get isTracking => _isTracking;
  bool get followLocation => _followLocation;
  int get locationSampleCount => _locationSampleCount;
  int get polylinePointCount => _routePoints.length;
  LocationRecord? get latestLocation => _latestLocation;
  String? get errorMessage => _errorMessage;
  TrackingRecoveryAction get recoveryAction => _recoveryAction;
  List<LocationRecord> get records => List.unmodifiable(_records);
  List<LocationRecord> get routePoints => List.unmodifiable(_routePoints);

  Future<void> startTracking() async {
    if (_isStarting || _isTracking || _isDisposed) {
      return;
    }

    final requestId = ++_startRequestId;
    _isStarting = true;
    _errorMessage = null;
    _recoveryAction = TrackingRecoveryAction.none;
    notifyListeners();

    try {
      await _locationService.ensureReady();
      if (!_isCurrentStartRequest(requestId)) {
        return;
      }

      final stream = _locationService.getPositionStream();
      _positionSubscription = stream.listen(
        _handlePosition,
        onError: (Object error) {
          unawaited(_handleStreamError(error));
        },
      );
      _isTracking = true;
    } on LocationServiceException catch (error) {
      if (_isCurrentStartRequest(requestId)) {
        _applyLocationServiceFailure(error.failure);
      }
    } on Object {
      if (_isCurrentStartRequest(requestId)) {
        _errorMessage = 'Unable to start location tracking. Please try again.';
        _recoveryAction = TrackingRecoveryAction.none;
      }
    } finally {
      if (_isCurrentStartRequest(requestId)) {
        _isStarting = false;
        notifyListeners();
      }
    }
  }

  Future<void> stopTracking() async {
    if (_isDisposed) {
      return;
    }

    _startRequestId += 1;
    _isStarting = false;
    _isTracking = false;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    notifyListeners();

    await subscription?.cancel();
  }

  Future<bool> openAppSettings() => _locationService.openAppSettings();

  Future<bool> openLocationSettings() =>
      _locationService.openLocationSettings();

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

  bool _isCurrentStartRequest(int requestId) {
    return !_isDisposed && requestId == _startRequestId;
  }

  void _handlePosition(Position position) {
    if (_isDisposed || !_isValidPosition(position)) {
      return;
    }

    final record = LocationRecord(
      timestamp: position.timestamp,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
    );

    _latestLocation = record;
    _records.insert(0, record);
    _locationSampleCount += 1;

    final previousPoint = _routePoints.lastOrNull;
    final isDuplicate =
        previousPoint != null &&
        previousPoint.latitude == record.latitude &&
        previousPoint.longitude == record.longitude;
    if (!isDuplicate) {
      _routePoints.add(record);
    }

    notifyListeners();
  }

  bool _isValidPosition(Position position) {
    return position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.accuracy.isFinite &&
        position.latitude >= -90 &&
        position.latitude <= 90 &&
        position.longitude >= -180 &&
        position.longitude <= 180 &&
        position.accuracy >= 0;
  }

  Future<void> _handleStreamError(Object error) async {
    if (_isDisposed) {
      return;
    }

    final subscription = _positionSubscription;
    _positionSubscription = null;
    _isTracking = false;

    if (error is LocationServiceDisabledException) {
      _errorMessage =
          'Location services are turned off. Enable GPS to continue.';
      _recoveryAction = TrackingRecoveryAction.openLocationSettings;
    } else {
      _errorMessage =
          'Location updates stopped unexpectedly. Please start tracking again.';
      _recoveryAction = TrackingRecoveryAction.none;
    }
    notifyListeners();

    await subscription?.cancel();
  }

  void _applyLocationServiceFailure(LocationServiceFailure failure) {
    _isTracking = false;
    switch (failure) {
      case LocationServiceFailure.serviceDisabled:
        _errorMessage =
            'Location services are turned off. Enable GPS to continue.';
        _recoveryAction = TrackingRecoveryAction.openLocationSettings;
        break;
      case LocationServiceFailure.permissionDenied:
        _errorMessage =
            'Location permission was denied. Allow access and try again.';
        _recoveryAction = TrackingRecoveryAction.none;
        break;
      case LocationServiceFailure.permissionDeniedForever:
        _errorMessage =
            'Location permission is permanently denied. Open app settings to allow it.';
        _recoveryAction = TrackingRecoveryAction.openAppSettings;
        break;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _startRequestId += 1;
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
    super.dispose();
  }
}
