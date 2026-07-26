import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:oppo_background_gps_demo/features/tracking/controllers/tracking_controller.dart';
import 'package:oppo_background_gps_demo/features/tracking/services/location_service.dart';

void main() {
  group('TrackingController', () {
    late FakeLocationService service;
    late TrackingController controller;

    setUp(() {
      service = FakeLocationService();
      controller = TrackingController(locationService: service);
    });

    tearDown(() async {
      controller.dispose();
      await service.close();
    });

    test('starts tracking with one active position subscription', () async {
      await controller.startTracking();
      await controller.startTracking();

      expect(service.ensureReadyCalls, 1);
      expect(service.streamListenCount, 1);
      expect(controller.isStarting, isFalse);
      expect(controller.isTracking, isTrue);
      expect(controller.errorMessage, isNull);
    });

    test(
      'receives a valid position and ignores a duplicate route point',
      () async {
        await controller.startTracking();
        final position = createPosition(latitude: 24.861, longitude: 67.002);

        service.addPosition(position);
        service.addPosition(position);
        await pumpEventQueue();

        expect(controller.locationSampleCount, 2);
        expect(controller.records, hasLength(2));
        expect(controller.routePoints, hasLength(1));
        expect(controller.latestLocation?.latitude, 24.861);
        expect(controller.records.first.accuracyMeters, 4.2);
        expect(controller.records.first.timestamp, position.timestamp);
      },
    );

    test('stops tracking before or after the first position safely', () async {
      await controller.startTracking();
      await controller.stopTracking();
      await controller.stopTracking();

      expect(controller.isTracking, isFalse);
      expect(service.hasListener, isFalse);

      service.addPosition(createPosition(latitude: 24.9, longitude: 67.1));
      await pumpEventQueue();
      expect(controller.locationSampleCount, 0);
    });

    test(
      'clears logs and route independently while tracking continues',
      () async {
        await controller.startTracking();
        service.addPosition(
          createPosition(latitude: 24.861, longitude: 67.002),
        );
        await pumpEventQueue();

        controller.clearLogs();
        expect(controller.records, isEmpty);
        expect(controller.routePoints, hasLength(1));
        expect(controller.isTracking, isTrue);

        controller.clearRoute();
        expect(controller.routePoints, isEmpty);
        expect(controller.isTracking, isTrue);
      },
    );

    test('exposes permission and settings recovery errors', () async {
      service.initializationError = const LocationServiceException(
        LocationServiceFailure.permissionDeniedForever,
      );

      await controller.startTracking();

      expect(controller.isTracking, isFalse);
      expect(controller.errorMessage, contains('permanently denied'));
      expect(controller.recoveryAction, TrackingRecoveryAction.openAppSettings);
    });

    test('handles location service disabled errors', () async {
      service.initializationError = const LocationServiceException(
        LocationServiceFailure.serviceDisabled,
      );

      await controller.startTracking();

      expect(controller.errorMessage, contains('turned off'));
      expect(
        controller.recoveryAction,
        TrackingRecoveryAction.openLocationSettings,
      );
    });

    test('handles stream failures without exposing raw errors', () async {
      await controller.startTracking();

      service.addError(StateError('sensitive implementation detail'));
      await pumpEventQueue();

      expect(controller.isTracking, isFalse);
      expect(controller.errorMessage, contains('stopped unexpectedly'));
      expect(
        controller.errorMessage,
        isNot(contains('sensitive implementation detail')),
      );
    });
  });
}

class FakeLocationService implements LocationService {
  FakeLocationService() {
    _positions = StreamController<Position>.broadcast(
      onListen: () => streamListenCount += 1,
    );
  }

  late final StreamController<Position> _positions;

  Object? initializationError;
  int ensureReadyCalls = 0;
  int streamListenCount = 0;

  bool get hasListener => _positions.hasListener;

  @override
  Future<void> ensureReady() async {
    ensureReadyCalls += 1;
    final error = initializationError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Stream<Position> getPositionStream() => _positions.stream;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  void addPosition(Position position) => _positions.add(position);

  void addError(Object error) => _positions.addError(error);

  Future<void> close() => _positions.close();
}

Position createPosition({required double latitude, required double longitude}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026, 7, 26, 12),
    accuracy: 4.2,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
