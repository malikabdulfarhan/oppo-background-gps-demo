import 'dart:isolate';

import 'package:flutter/services.dart';

import '../models/location_record.dart';
import 'tracking_models.dart';
import 'tracking_service.dart';

class AndroidTrackingService implements TrackingService {
  const AndroidTrackingService();

  static const _control = MethodChannel(
    'com.andromind.oppo_background_gps_demo/tracking_control',
  );
  static const _events = EventChannel(
    'com.andromind.oppo_background_gps_demo/tracking_events',
  );

  @override
  Future<TrackingPermissionStatus> ensurePermissions() async {
    final value = await _control.invokeMethod<Object?>('ensurePermissions');
    return TrackingPermissionStatus.fromMap(value);
  }

  @override
  Future<TrackingStartResult> startTracking() async {
    final value = await _control.invokeMethod<Object?>('startTracking');
    return TrackingStartResult.fromMap(value);
  }

  @override
  Future<void> stopTracking() => _control.invokeMethod<void>('stopTracking');

  @override
  Future<TrackingServiceStatus> getStatus() async {
    final value = await _control.invokeMethod<Object?>('getTrackingStatus');
    return TrackingServiceStatus.fromMap(value);
  }

  @override
  Stream<TrackingEvent> get events => _events
      .receiveBroadcastStream()
      .map(TrackingEvent.tryParse)
      .where((event) => event != null)
      .cast<TrackingEvent>();

  @override
  Future<TrackingSession?> getCurrentSession() async {
    final value = await _control.invokeMethod<Object?>('getCurrentSession');
    return TrackingSession.tryParse(value);
  }

  @override
  Future<List<LocationRecord>> getCurrentSessionRecords() async {
    final values =
        await _control.invokeListMethod<Object?>('getCurrentSessionRecords') ??
        const [];
    return values
        .map(LocationRecord.tryParse)
        .whereType<LocationRecord>()
        .toList();
  }

  @override
  Future<List<TrackingSession>> listTrackingSessions() async {
    final values =
        await _control.invokeListMethod<Object?>('listTrackingSessions') ??
        const [];
    return values
        .map(TrackingSession.tryParse)
        .whereType<TrackingSession>()
        .toList();
  }

  @override
  Future<TrackingSessionRecords> getSessionRecords(String sessionId) async {
    final value = await _control.invokeMethod<Object?>('getSessionRecords', {
      'sessionId': sessionId,
    });
    return Isolate.run(() => TrackingSessionRecords.fromMap(value));
  }

  @override
  Future<bool> shareSessionLog(String sessionId) =>
      _invokeBoolean('shareSessionLog', {'sessionId': sessionId});

  @override
  Future<SessionOperationResult> deleteSession(String sessionId) async {
    final value = await _control.invokeMethod<Object?>('deleteSession', {
      'sessionId': sessionId,
    });
    return SessionOperationResult.fromMap(value);
  }

  @override
  Future<AmapConfiguration> getAmapConfiguration() async {
    final value = await _control.invokeMethod<Object?>('getAmapConfiguration');
    return AmapConfiguration.fromMap(value);
  }

  @override
  Future<LocationEngineConfiguration> getLocationEngineConfiguration() async {
    final value = await _control.invokeMethod<Object?>(
      'getLocationEngineConfiguration',
    );
    return LocationEngineConfiguration.fromMap(value);
  }

  @override
  Future<LocationEngineConfiguration> setLocationEnginePreference(
    LocationEnginePreference preference,
  ) async {
    final value = await _control.invokeMethod<Object?>(
      'setLocationEnginePreference',
      {'preference': preference.wireValue},
    );
    return LocationEngineConfiguration.fromMap(value);
  }

  @override
  Future<LocationEngineConfiguration> retryAmapInitialization() async {
    final value = await _control.invokeMethod<Object?>(
      'retryAmapInitialization',
    );
    return LocationEngineConfiguration.fromMap(value);
  }

  @override
  Future<AmapConfiguration> setAmapPrivacyConsent(
    AmapPrivacyConsent consent,
  ) async {
    final value = await _control.invokeMethod<Object?>(
      'setAmapPrivacyConsent',
      {'decision': consent.wireValue},
    );
    return AmapConfiguration.fromMap(value);
  }

  @override
  Future<TrackingMapPreferences> getMapPreferences() async {
    final value = await _control.invokeMethod<Object?>('getMapPreferences');
    return TrackingMapPreferences.fromMap(value);
  }

  @override
  Future<TrackingMapPreferences> setMapPreferences(
    TrackingMapPreferences preferences,
  ) async {
    final value = await _control.invokeMethod<Object?>(
      'setMapPreferences',
      preferences.toMap(),
    );
    return TrackingMapPreferences.fromMap(value);
  }

  @override
  Future<BatteryOptimizationStatus> getBatteryOptimizationStatus() async {
    final value = await _control.invokeMethod<Object?>(
      'getBatteryOptimizationStatus',
    );
    return BatteryOptimizationStatus.fromMap(value);
  }

  @override
  Future<bool> openBatteryOptimizationSettings() =>
      _invokeBoolean('openBatteryOptimizationSettings');

  @override
  Future<bool> openAppSettings() => _invokeBoolean('openAppSettings');

  @override
  Future<bool> openLocationSettings() => _invokeBoolean('openLocationSettings');

  @override
  Future<bool> shareCurrentLog() => _invokeBoolean('shareCurrentLog');

  Future<bool> _invokeBoolean(
    String method, [
    Map<String, Object?>? arguments,
  ]) async => await _control.invokeMethod<bool>(method, arguments) ?? false;
}
