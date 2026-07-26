import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_background_gps_demo/features/map/models/map_display_state.dart';
import 'package:oppo_background_gps_demo/features/map/models/map_point.dart';
import 'package:oppo_background_gps_demo/features/map/widgets/map_configuration_card.dart';
import 'package:oppo_background_gps_demo/features/map/widgets/fallback_route_map.dart';
import 'package:oppo_background_gps_demo/features/tracking/analytics/route_metrics.dart';
import 'package:oppo_background_gps_demo/features/tracking/controllers/tracking_controller.dart';
import 'package:oppo_background_gps_demo/features/tracking/models/location_record.dart';
import 'package:oppo_background_gps_demo/features/tracking/screens/route_replay_screen.dart';
import 'package:oppo_background_gps_demo/features/tracking/screens/diagnostics_screen.dart';
import 'package:oppo_background_gps_demo/features/tracking/screens/session_history_screen.dart';
import 'package:oppo_background_gps_demo/features/tracking/screens/tracking_settings_screen.dart';
import 'package:oppo_background_gps_demo/features/tracking/services/tracking_models.dart';
import 'package:oppo_background_gps_demo/features/tracking/services/tracking_service.dart';
import 'package:oppo_background_gps_demo/features/tracking/widgets/amap_privacy_dialog.dart';
import 'package:oppo_background_gps_demo/features/tracking/widgets/route_statistics_card.dart';

void main() {
  testWidgets('shows missing-key configuration state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MapConfigurationCard())),
    );

    expect(find.text('AMap configuration required'), findsOneWidget);
    expect(find.textContaining('Android GPS Demo Mode'), findsOneWidget);
    expect(
      find.text('AMap runtime verification: Pending API key'),
      findsOneWidget,
    );
  });

  testWidgets('fallback renderer supports live and replay route states', (
    tester,
  ) async {
    const route = [
      MapPoint(latitude: 24.861, longitude: 67.002, coordinateSystem: 'WGS84'),
      MapPoint(
        latitude: 24.862,
        longitude: 67.003,
        coordinateSystem: 'WGS84',
        accuracyMeters: 5,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FallbackRouteMap(
            state: MapDisplayState(
              routePoints: route,
              currentLocation: route[1],
              selectedPoint: route[0],
              preferences: TrackingMapPreferences(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('ROUTE PREVIEW'), findsOneWidget);
    expect(find.textContaining('Route Preview —'), findsOneWidget);
    expect(find.textContaining('24.861000'), findsOneWidget);
    expect(find.byType(AndroidView), findsNothing);
  });

  testWidgets(
    'keyless settings disable AMap and diagnostics show pending key',
    (tester) async {
      final service = _Phase4FakeService();
      final controller = TrackingController(trackingService: service);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrackingSettingsScreen(controller: controller)),
        ),
      );
      final amapRadio = tester.widget<RadioListTile<LocationEnginePreference>>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RadioListTile<LocationEnginePreference> &&
              widget.value == LocationEnginePreference.amap,
        ),
      );
      expect(amapRadio.enabled, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DiagnosticsScreen(controller: controller)),
        ),
      );
      expect(find.text('Pending API key'), findsOneWidget);

      controller.dispose();
      await service.close();
    },
  );

  testWidgets('privacy consent presents genuine accept and decline actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAmapPrivacyDialog(context),
            child: const Text('Review'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('Accept and Continue'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('View Privacy Details'), findsOneWidget);
  });

  testWidgets('route statistics handles no data', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RouteStatisticsCard(metrics: RouteMetrics.empty()),
          ),
        ),
      ),
    );

    expect(find.text('Route statistics'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('session history renders empty and populated states', (
    tester,
  ) async {
    final service = _Phase4FakeService();
    final controller = TrackingController(trackingService: service);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SessionHistoryScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No previous tracking sessions'), findsOneWidget);

    service.sessions = [
      TrackingSession(
        sessionId: 'session_1',
        fileName: 'tracking_session_session_1.csv',
        startTimestamp: DateTime.utc(2026, 7, 26),
        locationEngine: 'AMAP',
      ),
    ];
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionHistoryScreen(
            key: const ValueKey('reloaded'),
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('View Route'), findsOneWidget);
    expect(find.text('Share CSV'), findsOneWidget);
    controller.dispose();
    await service.close();
  });

  testWidgets('route replay exposes timeline and playback controls', (
    tester,
  ) async {
    final record = LocationRecord(
      timestamp: DateTime.utc(2026, 7, 26),
      latitude: 24.861,
      longitude: 67.002,
      accuracyMeters: 4,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RouteReplayScreen(
          session: const TrackingSession(
            sessionId: 'session_1',
            fileName: 'session.csv',
          ),
          sessionRecords: TrackingSessionRecords(records: [record]),
          configuration: const AmapConfiguration.unavailable(),
          engineConfiguration: const LocationEngineConfiguration(),
          preferences: const TrackingMapPreferences(),
          onShare: () async => true,
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('1x'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    expect(find.text('4x'), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
  });
}

class _Phase4FakeService implements TrackingService {
  final StreamController<TrackingEvent> _events =
      StreamController<TrackingEvent>.broadcast();
  List<TrackingSession> sessions = [];

  @override
  Stream<TrackingEvent> get events => _events.stream;

  @override
  Future<List<TrackingSession>> listTrackingSessions() async => sessions;

  @override
  Future<TrackingSessionRecords> getSessionRecords(String sessionId) async =>
      const TrackingSessionRecords(records: []);

  @override
  Future<BatteryOptimizationStatus> getBatteryOptimizationStatus() async =>
      const BatteryOptimizationStatus.unknown();

  @override
  Future<AmapConfiguration> getAmapConfiguration() async =>
      const AmapConfiguration.unavailable();

  @override
  Future<LocationEngineConfiguration> getLocationEngineConfiguration() async =>
      const LocationEngineConfiguration();

  @override
  Future<LocationEngineConfiguration> setLocationEnginePreference(
    LocationEnginePreference preference,
  ) async => LocationEngineConfiguration(selected: preference);

  @override
  Future<LocationEngineConfiguration> retryAmapInitialization() async =>
      const LocationEngineConfiguration();

  @override
  Future<TrackingMapPreferences> getMapPreferences() async =>
      const TrackingMapPreferences();

  @override
  Future<TrackingServiceStatus> getStatus() async =>
      const TrackingServiceStatus.stopped();

  @override
  Future<List<LocationRecord>> getCurrentSessionRecords() async => const [];

  @override
  Future<TrackingSession?> getCurrentSession() async => null;

  @override
  Future<TrackingPermissionStatus> ensurePermissions() async =>
      const TrackingPermissionStatus(
        locationGranted: true,
        preciseLocationGranted: true,
        locationPermanentlyDenied: false,
        notificationPermissionGranted: true,
        message: 'Granted',
      );

  @override
  Future<TrackingStartResult> startTracking() async =>
      const TrackingStartResult(
        success: false,
        isTracking: false,
        message: 'Unavailable',
      );

  @override
  Future<void> stopTracking() async {}

  @override
  Future<bool> shareCurrentLog() async => false;

  @override
  Future<bool> shareSessionLog(String sessionId) async => true;

  @override
  Future<SessionOperationResult> deleteSession(String sessionId) async =>
      const SessionOperationResult(success: false, message: 'Not deleted');

  @override
  Future<AmapConfiguration> setAmapPrivacyConsent(
    AmapPrivacyConsent consent,
  ) async => const AmapConfiguration.unavailable();

  @override
  Future<TrackingMapPreferences> setMapPreferences(
    TrackingMapPreferences preferences,
  ) async => preferences;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openBatteryOptimizationSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  Future<void> close() => _events.close();
}
