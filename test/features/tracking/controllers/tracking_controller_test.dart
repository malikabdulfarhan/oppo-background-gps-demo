import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_background_gps_demo/features/tracking/controllers/tracking_controller.dart';
import 'package:oppo_background_gps_demo/features/tracking/models/location_record.dart';
import 'package:oppo_background_gps_demo/features/tracking/services/tracking_models.dart';
import 'package:oppo_background_gps_demo/features/tracking/services/tracking_service.dart';

void main() {
  group('TrackingController', () {
    late FakeTrackingService service;
    late TrackingController controller;

    setUp(() {
      service = FakeTrackingService();
      controller = TrackingController(trackingService: service);
    });

    tearDown(() async {
      controller.dispose();
      await service.close();
    });

    test(
      'starts native tracking successfully and prevents duplicate starts',
      () async {
        await controller.initialize();
        await controller.startTracking();
        await controller.startTracking();

        expect(service.permissionCalls, 1);
        expect(service.startCalls, 1);
        expect(controller.isStarting, isFalse);
        expect(controller.isTracking, isTrue);
        expect(controller.errorMessage, isNull);
      },
    );

    test(
      'surfaces a native start failure without raw platform details',
      () async {
        service.startResult = const TrackingStartResult(
          success: false,
          isTracking: false,
          message: 'Android denied the foreground location service.',
          errorCode: 'SERVICE_START_FAILED',
        );

        await controller.startTracking();

        expect(controller.isTracking, isFalse);
        expect(controller.errorMessage, contains('Android denied'));
      },
    );

    test('receives a native location event', () async {
      await controller.initialize();
      service.emitLocation(record(sequence: 1));
      await pumpEventQueue();

      expect(controller.locationSampleCount, 1);
      expect(controller.records, hasLength(1));
      expect(controller.routePoints, hasLength(1));
      expect(controller.latestLocation?.provider, 'gps');
    });

    test('deduplicates overlap between persisted and live records', () async {
      final restored = record(sequence: 7);
      service.persistedRecords = [restored];
      await controller.initialize();
      service.emitLocation(restored);
      await pumpEventQueue();

      expect(controller.records, hasLength(1));
      expect(controller.routePoints, hasLength(1));
      expect(controller.locationSampleCount, 1);
    });

    test('restores persisted current-session records', () async {
      service.persistedRecords = [
        record(sequence: 1),
        record(sequence: 2, latitude: 24.862),
      ];

      await controller.initialize();

      expect(controller.records.map((item) => item.sequence), [2, 1]);
      expect(controller.routePoints, hasLength(2));
      expect(controller.latestLocation?.sequence, 2);
    });

    test('reconnects while native service is already running', () async {
      service.status = const TrackingServiceStatus(
        isTracking: true,
        serviceRunning: true,
        notificationPermissionGranted: true,
        sessionId: 'session-active',
      );

      await controller.initialize();
      await controller.startTracking();

      expect(controller.isTracking, isTrue);
      expect(controller.serviceRunning, isTrue);
      expect(service.startCalls, 0);
    });

    test(
      'recovers an active persisted session when service is not running',
      () async {
        service.status = const TrackingServiceStatus(
          isTracking: true,
          serviceRunning: false,
          notificationPermissionGranted: true,
          sessionId: 'session-active',
        );

        await controller.initialize();

        expect(service.startCalls, 1);
        expect(controller.isTracking, isTrue);
        expect(controller.serviceRunning, isTrue);
      },
    );

    test('stops native tracking only when explicitly requested', () async {
      await controller.startTracking();
      await controller.stopTracking();

      expect(service.stopCalls, 1);
      expect(controller.isTracking, isFalse);
    });

    test(
      'dispose cancels Dart events without stopping native service',
      () async {
        await controller.initialize();
        controller.dispose();
        await pumpEventQueue();

        expect(service.stopCalls, 0);
        expect(service.hasEventListener, isFalse);
        controller = TrackingController(trackingService: service);
      },
    );

    test('clears UI route while native tracking continues', () async {
      await controller.startTracking();
      service.emitLocation(record(sequence: 1));
      await pumpEventQueue();

      controller.clearRoute();
      service.emitLocation(record(sequence: 2, latitude: 24.862));
      await pumpEventQueue();

      expect(controller.isTracking, isTrue);
      expect(controller.routePoints.map((item) => item.sequence), [2]);
      expect(service.stopCalls, 0);
    });

    test('clears visible logs without deleting the native session', () async {
      await controller.startTracking();
      service.emitLocation(record(sequence: 1));
      await pumpEventQueue();

      controller.clearLogs();

      expect(controller.records, isEmpty);
      expect(controller.locationSampleCount, 1);
      expect(controller.isTracking, isTrue);
    });
  });
}

class FakeTrackingService implements TrackingService {
  final StreamController<TrackingEvent> _events =
      StreamController<TrackingEvent>.broadcast();

  TrackingPermissionStatus permissionStatus = const TrackingPermissionStatus(
    locationGranted: true,
    preciseLocationGranted: true,
    locationPermanentlyDenied: false,
    notificationPermissionGranted: true,
    message: 'Permissions granted',
  );
  TrackingStartResult startResult = const TrackingStartResult(
    success: true,
    isTracking: true,
    sessionId: 'session-1',
    message: 'Tracking started',
  );
  TrackingServiceStatus status = const TrackingServiceStatus.stopped();
  List<LocationRecord> persistedRecords = [];
  int permissionCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;

  bool get hasEventListener => _events.hasListener;

  @override
  Future<TrackingPermissionStatus> ensurePermissions() async {
    permissionCalls += 1;
    return permissionStatus;
  }

  @override
  Future<TrackingStartResult> startTracking() async {
    startCalls += 1;
    return startResult;
  }

  @override
  Future<void> stopTracking() async {
    stopCalls += 1;
  }

  @override
  Future<TrackingServiceStatus> getStatus() async => status;

  @override
  Stream<TrackingEvent> get events => _events.stream;

  @override
  Future<TrackingSession?> getCurrentSession() async => null;

  @override
  Future<List<LocationRecord>> getCurrentSessionRecords() async =>
      persistedRecords;

  @override
  Future<List<TrackingSession>> listTrackingSessions() async => const [];

  @override
  Future<BatteryOptimizationStatus> getBatteryOptimizationStatus() async =>
      const BatteryOptimizationStatus(
        isIgnoringBatteryOptimizations: false,
        isOptimized: true,
        manufacturer: 'OPPO',
        model: 'V2409',
        androidVersion: '15',
        isOppo: true,
      );

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

LocationRecord record({
  required int sequence,
  double latitude = 24.861,
  double longitude = 67.002,
}) {
  return LocationRecord(
    sequence: sequence,
    timestamp: DateTime.utc(2026, 7, 26, 12, 0, sequence),
    latitude: latitude,
    longitude: longitude,
    accuracyMeters: 4.2,
    provider: 'gps',
    screenState: 'UNLOCKED',
  );
}
