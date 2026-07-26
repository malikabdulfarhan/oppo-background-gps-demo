import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:oppo_background_gps_demo/features/tracking/screens/tracking_screen.dart';
import 'package:oppo_background_gps_demo/features/tracking/services/location_service.dart';

void main() {
  testWidgets('tracking screen starts and displays a real position record', (
    tester,
  ) async {
    final service = _FakeLocationService();
    await tester.pumpWidget(
      MaterialApp(home: TrackingScreen(locationService: service)),
    );

    expect(find.text('Map Track Demo'), findsOneWidget);
    expect(find.text('Stopped'), findsOneWidget);
    expect(find.text('5000 ms'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Start Tracking'));
    await tester.pumpAndSettle();

    expect(find.text('Running'), findsOneWidget);

    service.addPosition(_position(latitude: 24.861, longitude: 67.002));
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

class _FakeLocationService implements LocationService {
  final StreamController<Position> _positions =
      StreamController<Position>.broadcast();

  @override
  Future<void> ensureReady() async {}

  @override
  Stream<Position> getPositionStream() => _positions.stream;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  void addPosition(Position position) => _positions.add(position);

  Future<void> close() => _positions.close();
}

Position _position({required double latitude, required double longitude}) {
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
