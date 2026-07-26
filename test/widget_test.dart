import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_background_gps_demo/features/map/controllers/tracking_map_controller.dart';
import 'package:oppo_background_gps_demo/features/map/models/map_display_state.dart';
import 'package:oppo_background_gps_demo/features/map/services/tracking_map_adapter.dart';
import 'package:oppo_background_gps_demo/features/tracking/models/location_record.dart';
import 'package:oppo_background_gps_demo/features/tracking/screens/tracking_screen.dart';
import 'package:oppo_background_gps_demo/features/tracking/services/tracking_models.dart';
import 'package:oppo_background_gps_demo/features/tracking/services/tracking_service.dart';

void main() {
  testWidgets('tracking screen starts native service and displays an event', (
    tester,
  ) async {
    final service = _WidgetFakeTrackingService();
    await tester.pumpWidget(
      MaterialApp(
        home: TrackingScreen(
          trackingService: service,
          trackingMapAdapter: const _WidgetFakeMapAdapter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Map Track Demo'), findsOneWidget);
    expect(find.text('Stopped'), findsOneWidget);
    expect(find.text('5000 ms'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Start Tracking'));
    await tester.pumpAndSettle();

    expect(find.text('Running in background'), findsOneWidget);

    service.emitLocation(
      LocationRecord(
        sequence: 1,
        timestamp: DateTime.utc(2026, 7, 26, 12),
        latitude: 24.861,
        longitude: 67.002,
        accuracyMeters: 4.2,
        provider: 'gps',
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('MOV 5s'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('MOV 5s'), findsOneWidget);
    expect(find.textContaining('24.861000'), findsAtLeast(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await service.close();
  });
}

class _WidgetFakeMapAdapter implements TrackingMapAdapter {
  const _WidgetFakeMapAdapter();

  @override
  bool get isAvailable => true;

  @override
  Widget buildLiveMap({
    required MapDisplayState state,
    required TrackingMapController controller,
    required VoidCallback onUserGesture,
    required VoidCallback onInitializationFailed,
  }) => const SizedBox(
    height: 340,
    child: Center(child: Text('Fake map adapter')),
  );

  @override
  Widget buildReplayMap({
    required MapDisplayState state,
    required TrackingMapController controller,
    required VoidCallback onInitializationFailed,
  }) => const SizedBox(
    height: 340,
    child: Center(child: Text('Fake replay adapter')),
  );
}

class _WidgetFakeTrackingService implements TrackingService {
  final StreamController<TrackingEvent> _events =
      StreamController<TrackingEvent>.broadcast();

  @override
  Future<TrackingPermissionStatus> ensurePermissions() async =>
      const TrackingPermissionStatus(
        locationGranted: true,
        preciseLocationGranted: true,
        locationPermanentlyDenied: false,
        notificationPermissionGranted: true,
        message: 'Permissions granted',
      );

  @override
  Future<TrackingStartResult> startTracking() async =>
      const TrackingStartResult(
        success: true,
        isTracking: true,
        sessionId: 'session-1',
        message: 'Tracking started',
      );

  @override
  Future<void> stopTracking() async {}

  @override
  Future<TrackingServiceStatus> getStatus() async =>
      const TrackingServiceStatus.stopped();

  @override
  Stream<TrackingEvent> get events => _events.stream;

  @override
  Future<TrackingSession?> getCurrentSession() async => null;

  @override
  Future<List<LocationRecord>> getCurrentSessionRecords() async => const [];

  @override
  Future<List<TrackingSession>> listTrackingSessions() async => const [];

  @override
  Future<TrackingSessionRecords> getSessionRecords(String sessionId) async =>
      const TrackingSessionRecords(records: []);

  @override
  Future<bool> shareSessionLog(String sessionId) async => true;

  @override
  Future<SessionOperationResult> deleteSession(String sessionId) async =>
      const SessionOperationResult(success: true, message: 'Deleted');

  @override
  Future<AmapConfiguration> getAmapConfiguration() async =>
      const AmapConfiguration(
        apiKeyConfigured: true,
        privacyConsent: AmapPrivacyConsent.accepted,
        sdkInitialized: false,
        locationEngine: 'AMAP',
      );

  @override
  Future<LocationEngineConfiguration> getLocationEngineConfiguration() async =>
      const LocationEngineConfiguration(
        selected: LocationEnginePreference.amap,
        resolved: LocationEngineType.amap,
        amapOptionAvailable: true,
      );

  @override
  Future<LocationEngineConfiguration> setLocationEnginePreference(
    LocationEnginePreference preference,
  ) async => LocationEngineConfiguration(
    selected: preference,
    resolved: preference == LocationEnginePreference.amap
        ? LocationEngineType.amap
        : LocationEngineType.androidLocationManager,
    amapOptionAvailable: true,
  );

  @override
  Future<LocationEngineConfiguration> retryAmapInitialization() =>
      getLocationEngineConfiguration();

  @override
  Future<AmapConfiguration> setAmapPrivacyConsent(
    AmapPrivacyConsent consent,
  ) async => AmapConfiguration(
    apiKeyConfigured: true,
    privacyConsent: consent,
    sdkInitialized: false,
    locationEngine: 'AMAP',
  );

  @override
  Future<TrackingMapPreferences> getMapPreferences() async =>
      const TrackingMapPreferences();

  @override
  Future<TrackingMapPreferences> setMapPreferences(
    TrackingMapPreferences preferences,
  ) async => preferences;

  @override
  Future<BatteryOptimizationStatus> getBatteryOptimizationStatus() async =>
      const BatteryOptimizationStatus.unknown();

  @override
  Future<bool> openBatteryOptimizationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> shareCurrentLog() async => true;

  void emitLocation(LocationRecord location) {
    _events.add(
      TrackingEvent(type: TrackingEventType.location, location: location),
    );
  }

  Future<void> close() => _events.close();
}
