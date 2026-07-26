import '../models/location_record.dart';
import 'tracking_models.dart';

abstract interface class TrackingService {
  Future<TrackingPermissionStatus> ensurePermissions();

  Future<TrackingStartResult> startTracking();

  Future<void> stopTracking();

  Future<TrackingServiceStatus> getStatus();

  Stream<TrackingEvent> get events;

  Future<TrackingSession?> getCurrentSession();

  Future<List<LocationRecord>> getCurrentSessionRecords();

  Future<List<TrackingSession>> listTrackingSessions();

  Future<BatteryOptimizationStatus> getBatteryOptimizationStatus();

  Future<bool> openBatteryOptimizationSettings();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();

  Future<bool> shareCurrentLog();
}
