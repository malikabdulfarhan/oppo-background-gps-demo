import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../analytics/route_metrics.dart';
import '../analytics/route_metrics_calculator.dart';
import '../models/location_record.dart';
import '../services/android_tracking_service.dart';
import '../services/tracking_models.dart';
import '../services/tracking_service.dart';

enum TrackingRecoveryAction { none, openAppSettings, openLocationSettings }

class TrackingController extends ChangeNotifier {
  TrackingController({TrackingService? trackingService})
    : _trackingService = trackingService ?? const AndroidTrackingService();

  static const updateInterval = Duration(seconds: 5);

  final TrackingService _trackingService;
  final List<LocationRecord> _allRecords = [];
  final List<LocationRecord> _records = [];
  final List<LocationRecord> _routePoints = [];
  final Set<String> _knownRecordIds = {};
  final Set<String> _hiddenLogIds = {};
  final Set<String> _hiddenRouteIds = {};

  StreamSubscription<TrackingEvent>? _eventSubscription;
  TrackingServiceStatus _serviceStatus = const TrackingServiceStatus.stopped();
  BatteryOptimizationStatus _batteryStatus =
      const BatteryOptimizationStatus.unknown();
  AmapConfiguration _amapConfiguration = const AmapConfiguration.unavailable();
  LocationEngineConfiguration _locationEngineConfiguration =
      const LocationEngineConfiguration();
  TrackingMapPreferences _mapPreferences = const TrackingMapPreferences();
  bool _isInitializing = false;
  bool _isInitialized = false;
  bool _isStarting = false;
  bool _followLocation = true;
  bool _isDisposed = false;
  int _startRequestId = 0;
  int _locationSampleCount = 0;
  LocationRecord? _latestLocation;
  String? _errorMessage;
  String? _warningMessage;
  TrackingRecoveryAction _recoveryAction = TrackingRecoveryAction.none;

  bool get isInitializing => _isInitializing;
  bool get isStarting => _isStarting;
  bool get isTracking => _serviceStatus.isTracking;
  bool get serviceRunning => _serviceStatus.serviceRunning;
  bool get followLocation => _followLocation;
  int get locationSampleCount => _locationSampleCount;
  int get polylinePointCount => _routePoints.length;
  LocationRecord? get latestLocation => _latestLocation;
  String? get errorMessage => _errorMessage;
  String? get warningMessage => _warningMessage;
  TrackingRecoveryAction get recoveryAction => _recoveryAction;
  TrackingServiceStatus get serviceStatus => _serviceStatus;
  BatteryOptimizationStatus get batteryStatus => _batteryStatus;
  AmapConfiguration get amapConfiguration => _amapConfiguration;
  LocationEngineConfiguration get locationEngineConfiguration =>
      _locationEngineConfiguration;
  bool get shouldUseAmapMap =>
      _locationEngineConfiguration.shouldUseAmapMap &&
      _amapConfiguration.canUseAmap &&
      _amapConfiguration.runtimeState != AmapRuntimeState.failed;
  TrackingMapPreferences get mapPreferences => _mapPreferences;
  RouteMetrics get routeMetrics =>
      const RouteMetricsCalculator().calculate(_knownRecordsInTimeOrder);
  List<LocationRecord> get records => List.unmodifiable(_records);
  List<LocationRecord> get routePoints => List.unmodifiable(_routePoints);
  List<LocationRecord> get _knownRecordsInTimeOrder {
    final values = [..._allRecords];
    values.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return values;
  }

  Future<void> initialize() async {
    if (_isInitializing || _isInitialized || _isDisposed) {
      return;
    }
    _isInitializing = true;
    notifyListeners();
    _ensureEventSubscription();
    try {
      await refreshNativeState(restoreRecords: true);
      _isInitialized = true;
    } on Object catch (error, stackTrace) {
      debugPrint('Native tracking initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setError('Unable to read the native tracking service status.');
    } finally {
      if (!_isDisposed) {
        _isInitializing = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshNativeState({bool restoreRecords = true}) async {
    if (_isDisposed) {
      return;
    }
    _ensureEventSubscription();
    final results = await Future.wait<Object>([
      _trackingService.getStatus(),
      _trackingService.getBatteryOptimizationStatus(),
      _trackingService.getAmapConfiguration(),
      _trackingService.getLocationEngineConfiguration(),
      _trackingService.getMapPreferences(),
      if (restoreRecords) _trackingService.getCurrentSessionRecords(),
    ]);
    if (_isDisposed) {
      return;
    }
    _serviceStatus = results[0] as TrackingServiceStatus;
    _batteryStatus = results[1] as BatteryOptimizationStatus;
    _amapConfiguration = results[2] as AmapConfiguration;
    _locationEngineConfiguration = results[3] as LocationEngineConfiguration;
    _mapPreferences = results[4] as TrackingMapPreferences;
    if (_serviceStatus.isTracking && !_serviceStatus.serviceRunning) {
      final recoveryResult = await _trackingService.startTracking();
      if (!_isDisposed) {
        if (recoveryResult.success) {
          _serviceStatus = _serviceStatus.copyWith(
            isTracking: recoveryResult.isTracking,
            serviceRunning: recoveryResult.isTracking,
            sessionId: recoveryResult.sessionId,
            notificationPermissionGranted:
                recoveryResult.notificationPermissionGranted,
          );
        } else {
          _applyStartFailure(recoveryResult);
        }
      }
    }
    if (restoreRecords) {
      _mergePersistedRecords(results[5] as List<LocationRecord>);
    }
    _syncNotificationWarning();
    notifyListeners();
  }

  Future<void> startTracking() async {
    if (_isStarting || isTracking || _isDisposed) {
      return;
    }
    if (!_isInitialized) {
      await initialize();
      if (_isDisposed || isTracking) {
        return;
      }
    }
    final requestId = ++_startRequestId;
    _isStarting = true;
    _errorMessage = null;
    _recoveryAction = TrackingRecoveryAction.none;
    notifyListeners();

    try {
      final permissions = await _trackingService.ensurePermissions();
      if (!_isCurrentStartRequest(requestId)) {
        return;
      }
      if (!permissions.locationGranted) {
        _setError(
          permissions.message,
          recoveryAction: permissions.locationPermanentlyDenied
              ? TrackingRecoveryAction.openAppSettings
              : TrackingRecoveryAction.none,
        );
        return;
      }
      _warningMessage = _permissionWarning(permissions);

      final result = await _trackingService.startTracking();
      if (!_isCurrentStartRequest(requestId)) {
        return;
      }
      if (!result.success) {
        _applyStartFailure(result);
        return;
      }
      _serviceStatus = _serviceStatus.copyWith(
        isTracking: result.isTracking,
        serviceRunning: result.isTracking,
        sessionId: result.sessionId,
        notificationPermissionGranted: result.notificationPermissionGranted,
      );
      await _refreshEngineConfiguration();
      _syncNotificationWarning();
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'Native tracking start failed [${error.code}]: ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      _setError(_friendlyPlatformError(error));
    } on Object catch (error, stackTrace) {
      debugPrint('Native tracking start failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setError(
        'Unable to start background location tracking. Please try again.',
      );
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
    try {
      await _trackingService.stopTracking();
      _serviceStatus = _serviceStatus.copyWith(
        isTracking: false,
        serviceRunning: false,
      );
      _errorMessage = null;
      _recoveryAction = TrackingRecoveryAction.none;
    } on Object catch (error, stackTrace) {
      debugPrint('Native tracking stop failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setError('Unable to stop the native tracking service.');
    }
    notifyListeners();
  }

  Future<bool> openAppSettings() => _trackingService.openAppSettings();

  Future<bool> openLocationSettings() =>
      _trackingService.openLocationSettings();

  Future<bool> openBatteryOptimizationSettings() =>
      _trackingService.openBatteryOptimizationSettings();

  Future<bool> shareCurrentLog() => _trackingService.shareCurrentLog();

  Future<List<TrackingSession>> listTrackingSessions() =>
      _trackingService.listTrackingSessions();

  Future<TrackingSessionRecords> getSessionRecords(String sessionId) =>
      _trackingService.getSessionRecords(sessionId);

  Future<bool> shareSessionLog(String sessionId) =>
      _trackingService.shareSessionLog(sessionId);

  Future<SessionOperationResult> deleteSession(String sessionId) =>
      _trackingService.deleteSession(sessionId);

  Future<void> setAmapPrivacyConsent(AmapPrivacyConsent consent) async {
    _errorMessage = null;
    try {
      _amapConfiguration = await _trackingService.setAmapPrivacyConsent(
        consent,
      );
      await _refreshEngineConfiguration();
    } on PlatformException catch (error) {
      _setError(
        error.code == 'TRACKING_ACTIVE'
            ? 'Stop tracking before revoking AMap privacy consent.'
            : 'Unable to update AMap privacy consent.',
      );
    }
    notifyListeners();
  }

  Future<void> setLocationEnginePreference(
    LocationEnginePreference preference,
  ) async {
    if (isTracking) {
      _setError('Stop tracking before changing the location engine.');
      notifyListeners();
      return;
    }
    _errorMessage = null;
    try {
      _locationEngineConfiguration = await _trackingService
          .setLocationEnginePreference(preference);
    } on PlatformException catch (error) {
      _setError(
        error.code == 'ENGINE_UNAVAILABLE'
            ? 'AMap is unavailable. Add a valid API key and accept AMap privacy consent, or use Android GPS Demo Mode.'
            : 'Unable to change the location engine.',
      );
    }
    notifyListeners();
  }

  Future<void> retryAmapInitialization() async {
    _errorMessage = null;
    try {
      _locationEngineConfiguration = await _trackingService
          .retryAmapInitialization();
      _amapConfiguration = await _trackingService.getAmapConfiguration();
    } on Object catch (error) {
      debugPrint('Unable to retry AMap initialization: $error');
      _setError('Unable to retry AMap initialization.');
    }
    notifyListeners();
  }

  Future<void> handleAmapInitializationFailure() async {
    try {
      _amapConfiguration = await _trackingService.getAmapConfiguration();
      await _refreshEngineConfiguration();
    } on Object catch (error) {
      debugPrint('Unable to refresh AMap fallback state: $error');
    }
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> _refreshEngineConfiguration() async {
    _locationEngineConfiguration = await _trackingService
        .getLocationEngineConfiguration();
  }

  Future<void> updateMapPreferences(TrackingMapPreferences preferences) async {
    _mapPreferences = preferences;
    notifyListeners();
    try {
      _mapPreferences = await _trackingService.setMapPreferences(preferences);
    } on Object catch (error) {
      debugPrint('Unable to persist map preferences: $error');
    }
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
    _hiddenRouteIds.addAll(_routePoints.map((record) => record.identity));
    _routePoints.clear();
    notifyListeners();
  }

  void clearLogs() {
    if (_records.isEmpty) {
      return;
    }
    _hiddenLogIds.addAll(_records.map((record) => record.identity));
    _records.clear();
    notifyListeners();
  }

  bool _isCurrentStartRequest(int requestId) =>
      !_isDisposed && requestId == _startRequestId;

  void _ensureEventSubscription() {
    _eventSubscription ??= _trackingService.events.listen(
      _handleEvent,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Native tracking event stream failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (!_isDisposed) {
          _setError(
            'The live service connection was interrupted. Reopen the app to reconnect.',
          );
          notifyListeners();
        }
      },
    );
  }

  void _handleEvent(TrackingEvent event) {
    if (_isDisposed) {
      return;
    }
    switch (event.type) {
      case TrackingEventType.location:
        final location = event.location;
        if (location != null) {
          _addLocation(location);
          _serviceStatus = _serviceStatus.copyWith(
            isTracking: true,
            serviceRunning: true,
            lastLocationTimestamp: location.timestamp,
            currentProvider: location.provider,
            screenState: location.screenState,
          );
        }
      case TrackingEventType.trackingStarted:
        _serviceStatus = _serviceStatus.copyWith(
          isTracking: true,
          serviceRunning: true,
          sessionId: event.sessionId,
        );
      case TrackingEventType.trackingStopped:
        _serviceStatus = _serviceStatus.copyWith(
          isTracking: false,
          serviceRunning: false,
        );
      case TrackingEventType.serviceStatus:
        final status = event.status;
        if (status != null) {
          _serviceStatus = status;
          _syncNotificationWarning();
        }
      case TrackingEventType.providerStatus:
        if (event.providerEnabled == false) {
          _warningMessage =
              '${event.provider ?? 'Location'} provider is disabled. Tracking will resume when a provider is available.';
        } else if (_warningMessage?.contains('provider is disabled') ?? false) {
          _warningMessage = null;
        }
      case TrackingEventType.error:
        _setError(
          event.message ?? 'The native location service reported an error.',
        );
      case TrackingEventType.unknown:
        break;
    }
    notifyListeners();
  }

  void _mergePersistedRecords(List<LocationRecord> records) {
    final sorted = [...records]
      ..sort((a, b) {
        final sequenceComparison = (a.sequence ?? 0).compareTo(b.sequence ?? 0);
        return sequenceComparison != 0
            ? sequenceComparison
            : a.timestamp.compareTo(b.timestamp);
      });
    for (final record in sorted) {
      _addLocation(record, notify: false);
    }
  }

  void _addLocation(LocationRecord record, {bool notify = true}) {
    if (!_knownRecordIds.add(record.identity)) {
      return;
    }
    _latestLocation = record;
    _locationSampleCount += 1;
    _allRecords.add(record);
    if (!_hiddenLogIds.contains(record.identity)) {
      _records.insert(0, record);
    }
    if (!_hiddenRouteIds.contains(record.identity)) {
      final previous = _routePoints.lastOrNull;
      final duplicateCoordinate =
          previous != null &&
          previous.latitude == record.latitude &&
          previous.longitude == record.longitude;
      if (!duplicateCoordinate) {
        _routePoints.add(record);
      }
    }
    if (notify) {
      notifyListeners();
    }
  }

  String? _permissionWarning(TrackingPermissionStatus permissions) {
    if (!permissions.preciseLocationGranted) {
      return 'Approximate location is active. Enable precise location in app settings for better routes.';
    }
    if (!permissions.notificationPermissionGranted) {
      return 'Notification permission is denied. Open app settings so Android can show the required persistent tracking notification.';
    }
    return null;
  }

  void _syncNotificationWarning() {
    if (!_serviceStatus.notificationPermissionGranted) {
      _warningMessage =
          'Notification permission is denied. Open app settings so Android can show the required persistent tracking notification.';
    } else if (_warningMessage?.startsWith('Notification permission') ??
        false) {
      _warningMessage = null;
    }
  }

  void _applyStartFailure(TrackingStartResult result) {
    final action = switch (result.errorCode) {
      'GPS_DISABLED' => TrackingRecoveryAction.openLocationSettings,
      'PERMISSION_DENIED' => TrackingRecoveryAction.openAppSettings,
      _ => TrackingRecoveryAction.none,
    };
    _serviceStatus = _serviceStatus.copyWith(
      isTracking: false,
      serviceRunning: false,
    );
    _setError(result.message, recoveryAction: action);
  }

  String _friendlyPlatformError(PlatformException error) {
    return switch (error.code) {
      'PERMISSION_REQUEST_ACTIVE' =>
        'A permission request is already open. Complete it and try again.',
      'TRACKING_ACTIVE' =>
        'Stop tracking before changing the AMap privacy setting.',
      _ => 'Android could not start the native tracking service.',
    };
  }

  void _setError(
    String message, {
    TrackingRecoveryAction recoveryAction = TrackingRecoveryAction.none,
  }) {
    _errorMessage = message;
    _recoveryAction = recoveryAction;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _startRequestId += 1;
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
    super.dispose();
  }
}
