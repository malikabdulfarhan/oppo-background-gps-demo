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
      expect(event?.location?.locationEngine, 'LEGACY');
      expect(event?.location?.coordinateSystem, 'WGS84_LEGACY');
    });

    test('parses Phase 4 AMap location fields', () {
      final record = LocationRecord.tryParse({
        'timestamp': '2026-07-26T12:00:00.000Z',
        'latitude': 24.861,
        'longitude': 67.002,
        'accuracy': 4.5,
        'locationEngine': 'AMAP',
        'amapLocationType': 1,
        'gpsAccuracyStatus': 1,
        'satelliteCount': 9,
        'isMock': false,
        'coordinateSystem': 'GCJ02',
      });

      expect(record?.locationEngine, 'AMAP');
      expect(record?.amapLocationType, 1);
      expect(record?.satelliteCount, 9);
      expect(record?.isMock, isFalse);
      expect(record?.coordinateSystem, 'GCJ02');
      expect(record?.address, isNull);
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

    test(
      'parses partially readable session metadata and skips invalid items',
      () {
        final result = TrackingSessionRecords.fromMap({
          'records': [
            {
              'timestamp': '2026-07-26T12:00:00.000Z',
              'latitude': 24.861,
              'longitude': 67.002,
              'accuracy': 4.5,
            },
            {'timestamp': 'broken'},
          ],
          'skippedRows': 2,
          'locationEngine': 'LEGACY',
        });

        expect(result.records, hasLength(1));
        expect(result.skippedRows, 2);
        expect(result.locationEngine, 'LEGACY');
      },
    );

    test('invalid platform channel maps use safe defaults', () {
      expect(AmapConfiguration.fromMap('invalid').apiKeyConfigured, isFalse);
      expect(
        TrackingMapPreferences.fromMap({'mapType': 'INVALID'}).mapType,
        AmapMapType.standard,
      );
      expect(TrackingSessionRecords.fromMap(null).records, isEmpty);
    });

    test('parses keyless engine fallback and runtime verification', () {
      final config = LocationEngineConfiguration.fromMap({
        'selectedLocationEngine': 'AUTOMATIC',
        'resolvedLocationEngine': 'ANDROID_LOCATION_MANAGER',
        'fallbackReason': 'AMap API key is not configured.',
        'amapOptionAvailable': false,
        'csvSchemaVersion': '4',
      });
      final amap = AmapConfiguration.fromMap({
        'apiKeyConfigured': false,
        'sdkCompileIntegration': true,
        'runtimeState': 'NOT_ATTEMPTED',
        'runtimeVerification': 'PENDING_API_KEY',
      });

      expect(config.selected, LocationEnginePreference.automatic);
      expect(config.resolved, LocationEngineType.androidLocationManager);
      expect(config.shouldUseAmapMap, isFalse);
      expect(config.fallbackReason, contains('not configured'));
      expect(config.csvSchemaVersion, '4');
      expect(amap.sdkCompileIntegration, isTrue);
      expect(amap.runtimeVerification, AmapRuntimeVerification.pendingApiKey);
    });
  });
}
