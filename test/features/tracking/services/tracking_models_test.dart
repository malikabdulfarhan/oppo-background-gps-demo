import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_background_gps_demo/features/tracking/models/location_record.dart';
import 'package:oppo_background_gps_demo/features/tracking/services/tracking_models.dart';

void main() {
  group('platform map parsing', () {
    test('parses a valid location event with optional fields missing', () {
      final event = TrackingEvent.tryParse({
        'type': 'location',
        'sequence': 3,
        'timestamp': '2026-07-26T12:00:00.000Z',
        'latitude': 24.861,
        'longitude': 67.002,
        'accuracy': 4.5,
      });

      expect(event?.type, TrackingEventType.location);
      expect(event?.location?.sequence, 3);
      expect(event?.location?.provider, isNull);
    });

    test('rejects malformed or invalid location values', () {
      expect(TrackingEvent.tryParse({'type': 'location'}), isNull);
      expect(
        LocationRecord.tryParse({
          'timestamp': 'not-a-date',
          'latitude': 24.8,
          'longitude': 67.0,
          'accuracy': 3,
        }),
        isNull,
      );
      expect(
        LocationRecord.tryParse({
          'timestamp': '2026-07-26T12:00:00Z',
          'latitude': 200,
          'longitude': 67.0,
          'accuracy': 3,
        }),
        isNull,
      );
    });

    test('uses safe defaults for missing status fields', () {
      final status = TrackingServiceStatus.fromMap({'isTracking': true});

      expect(status.isTracking, isTrue);
      expect(status.serviceRunning, isFalse);
      expect(status.currentLogFileName, isNull);
      expect(status.notificationPermissionGranted, isTrue);
    });

    test('rejects sessions missing required identifiers', () {
      expect(TrackingSession.tryParse({'fileName': 'tracking.csv'}), isNull);
      expect(
        TrackingSession.tryParse({
          'sessionId': 'abc',
          'fileName': 'tracking_session_abc.csv',
        })?.fileName,
        'tracking_session_abc.csv',
      );
    });
  });
}
