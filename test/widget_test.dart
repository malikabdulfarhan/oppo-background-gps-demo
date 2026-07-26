import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      MaterialApp(home: TrackingScreen(trackingService: service)),
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
