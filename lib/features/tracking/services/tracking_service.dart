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

  Future<TrackingSessionRecords> getSessionRecords(String sessionId);

  Future<bool> shareSessionLog(String sessionId);

  Future<SessionOperationResult> deleteSession(String sessionId);

  Future<AmapConfiguration> getAmapConfiguration();

  Future<LocationEngineConfiguration> getLocationEngineConfiguration();

  Future<LocationEngineConfiguration> setLocationEnginePreference(
    LocationEnginePreference preference,
  );

  Future<LocationEngineConfiguration> retryAmapInitialization();

  Future<AmapConfiguration> setAmapPrivacyConsent(AmapPrivacyConsent consent);

  Future<TrackingMapPreferences> getMapPreferences();

  Future<TrackingMapPreferences> setMapPreferences(
    TrackingMapPreferences preferences,
  );

  Future<BatteryOptimizationStatus> getBatteryOptimizationStatus();

  Future<bool> openBatteryOptimizationSettings();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();

  Future<bool> shareCurrentLog();
}
