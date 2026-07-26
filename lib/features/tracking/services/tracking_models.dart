import '../models/location_record.dart';

enum TrackingEventType {
  trackingStarted,
  trackingStopped,
  location,
  serviceStatus,
  providerStatus,
  error,
  unknown,
}

class TrackingPermissionStatus {
  const TrackingPermissionStatus({
    required this.locationGranted,
    required this.preciseLocationGranted,
    required this.locationPermanentlyDenied,
    required this.notificationPermissionGranted,
    required this.message,
  });

  final bool locationGranted;
  final bool preciseLocationGranted;
  final bool locationPermanentlyDenied;
  final bool notificationPermissionGranted;
  final String message;

  factory TrackingPermissionStatus.fromMap(Object? value) {
    final map = PlatformMap(value);
    return TrackingPermissionStatus(
      locationGranted: map.boolean('locationGranted'),
      preciseLocationGranted: map.boolean('preciseLocationGranted'),
      locationPermanentlyDenied: map.boolean('locationPermanentlyDenied'),
      notificationPermissionGranted: map.boolean(
        'notificationPermissionGranted',
        fallback: true,
      ),
      message: map.string('message') ?? 'Permission status unavailable.',
    );
  }
}

class TrackingStartResult {
  const TrackingStartResult({
    required this.success,
    required this.isTracking,
    required this.message,
    this.sessionId,
    this.errorCode,
    this.notificationPermissionGranted = true,
  });

  final bool success;
  final bool isTracking;
  final String? sessionId;
  final String message;
  final String? errorCode;
  final bool notificationPermissionGranted;

  factory TrackingStartResult.fromMap(Object? value) {
    final map = PlatformMap(value);
    return TrackingStartResult(
      success: map.boolean('success'),
      isTracking: map.boolean('isTracking'),
      sessionId: map.string('sessionId'),
      message: map.string('message') ?? 'Native service returned no message.',
      errorCode: map.string('errorCode'),
      notificationPermissionGranted: map.boolean(
        'notificationPermissionGranted',
        fallback: true,
      ),
    );
  }
}

class TrackingServiceStatus {
  const TrackingServiceStatus({
    required this.isTracking,
    required this.serviceRunning,
    required this.notificationPermissionGranted,
    this.sessionId,
    this.lastLocationTimestamp,
    this.currentLogPath,
    this.currentProvider,
    this.screenState,
    this.amapApiKeyConfigured = false,
    this.amapPrivacyConsent = AmapPrivacyConsent.notSelected,
    this.amapSdkInitialized = false,
    this.locationEngine = 'UNAVAILABLE',
    this.lastAmapLocationType,
    this.lastAmapErrorCode,
    this.lastAmapErrorMessage,
    this.satelliteCount,
    this.gpsAccuracyStatus,
    this.coordinateSystem,
    this.selectedLocationEngine = LocationEnginePreference.automatic,
    this.activeLocationEngine,
    this.fallbackReason,
    this.amapSdkCompileIntegration = true,
    this.amapRuntimeState = AmapRuntimeState.notAttempted,
    this.amapRuntimeVerification = AmapRuntimeVerification.pendingApiKey,
    this.locationPermissionGranted = false,
    this.csvSchemaVersion = '4',
  });

  const TrackingServiceStatus.stopped()
    : isTracking = false,
      serviceRunning = false,
      notificationPermissionGranted = true,
      sessionId = null,
      lastLocationTimestamp = null,
      currentLogPath = null,
      currentProvider = null,
      screenState = null,
      amapApiKeyConfigured = false,
      amapPrivacyConsent = AmapPrivacyConsent.notSelected,
      amapSdkInitialized = false,
      locationEngine = 'UNAVAILABLE',
      lastAmapLocationType = null,
      lastAmapErrorCode = null,
      lastAmapErrorMessage = null,
      satelliteCount = null,
      gpsAccuracyStatus = null,
      coordinateSystem = null,
      selectedLocationEngine = LocationEnginePreference.automatic,
      activeLocationEngine = null,
      fallbackReason = null,
      amapSdkCompileIntegration = true,
      amapRuntimeState = AmapRuntimeState.notAttempted,
      amapRuntimeVerification = AmapRuntimeVerification.pendingApiKey,
      locationPermissionGranted = false,
      csvSchemaVersion = '4';

  final bool isTracking;
  final bool serviceRunning;
  final bool notificationPermissionGranted;
  final String? sessionId;
  final DateTime? lastLocationTimestamp;
  final String? currentLogPath;
  final String? currentProvider;
  final String? screenState;
  final bool amapApiKeyConfigured;
  final AmapPrivacyConsent amapPrivacyConsent;
  final bool amapSdkInitialized;
  final String locationEngine;
  final int? lastAmapLocationType;
  final int? lastAmapErrorCode;
  final String? lastAmapErrorMessage;
  final int? satelliteCount;
  final int? gpsAccuracyStatus;
  final String? coordinateSystem;
  final LocationEnginePreference selectedLocationEngine;
  final LocationEngineType? activeLocationEngine;
  final String? fallbackReason;
  final bool amapSdkCompileIntegration;
  final AmapRuntimeState amapRuntimeState;
  final AmapRuntimeVerification amapRuntimeVerification;
  final bool locationPermissionGranted;
  final String csvSchemaVersion;

  String? get currentLogFileName {
    final path = currentLogPath;
    if (path == null || path.isEmpty) {
      return null;
    }
    return path.replaceAll(r'\', '/').split('/').last;
  }

  factory TrackingServiceStatus.fromMap(Object? value) {
    final map = PlatformMap(value);
    return TrackingServiceStatus(
      isTracking: map.boolean('isTracking'),
      serviceRunning: map.boolean('serviceRunning'),
      notificationPermissionGranted: map.boolean(
        'notificationPermissionGranted',
        fallback: true,
      ),
      sessionId: map.string('sessionId'),
      lastLocationTimestamp: map.dateTime('lastLocationTimestamp'),
      currentLogPath: map.string('currentLogPath'),
      currentProvider: map.string('currentProvider'),
      screenState: map.string('screenState'),
      amapApiKeyConfigured: map.boolean('amapApiKeyConfigured'),
      amapPrivacyConsent: AmapPrivacyConsent.fromWire(
        map.string('amapPrivacyConsent'),
      ),
      amapSdkInitialized: map.boolean('amapSdkInitialized'),
      locationEngine: map.string('locationEngine') ?? 'UNAVAILABLE',
      lastAmapLocationType: map.integer('lastAmapLocationType'),
      lastAmapErrorCode: map.integer('lastAmapErrorCode'),
      lastAmapErrorMessage: map.string('lastAmapErrorMessage'),
      satelliteCount: map.integer('satelliteCount'),
      gpsAccuracyStatus: map.integer('gpsAccuracyStatus'),
      coordinateSystem: map.string('coordinateSystem'),
      selectedLocationEngine: LocationEnginePreference.fromWire(
        map.string('selectedLocationEngine'),
      ),
      activeLocationEngine: LocationEngineType.tryFromWire(
        map.string('activeLocationEngine'),
      ),
      fallbackReason: map.string('fallbackReason'),
      amapSdkCompileIntegration: map.boolean(
        'amapSdkCompileIntegration',
        fallback: true,
      ),
      amapRuntimeState: AmapRuntimeState.fromWire(
        map.string('amapRuntimeState'),
      ),
      amapRuntimeVerification: AmapRuntimeVerification.fromWire(
        map.string('amapRuntimeVerification'),
      ),
      locationPermissionGranted: map.boolean('locationPermissionGranted'),
      csvSchemaVersion: map.string('csvSchemaVersion') ?? '4',
    );
  }

  TrackingServiceStatus copyWith({
    bool? isTracking,
    bool? serviceRunning,
    bool? notificationPermissionGranted,
    String? sessionId,
    DateTime? lastLocationTimestamp,
    String? currentLogPath,
    String? currentProvider,
    String? screenState,
    bool? amapApiKeyConfigured,
    AmapPrivacyConsent? amapPrivacyConsent,
    bool? amapSdkInitialized,
    String? locationEngine,
    int? lastAmapLocationType,
    int? lastAmapErrorCode,
    String? lastAmapErrorMessage,
    int? satelliteCount,
    int? gpsAccuracyStatus,
    String? coordinateSystem,
    LocationEnginePreference? selectedLocationEngine,
    LocationEngineType? activeLocationEngine,
    String? fallbackReason,
    bool? amapSdkCompileIntegration,
    AmapRuntimeState? amapRuntimeState,
    AmapRuntimeVerification? amapRuntimeVerification,
    bool? locationPermissionGranted,
    String? csvSchemaVersion,
  }) {
    return TrackingServiceStatus(
      isTracking: isTracking ?? this.isTracking,
      serviceRunning: serviceRunning ?? this.serviceRunning,
      notificationPermissionGranted:
          notificationPermissionGranted ?? this.notificationPermissionGranted,
      sessionId: sessionId ?? this.sessionId,
      lastLocationTimestamp:
          lastLocationTimestamp ?? this.lastLocationTimestamp,
      currentLogPath: currentLogPath ?? this.currentLogPath,
      currentProvider: currentProvider ?? this.currentProvider,
      screenState: screenState ?? this.screenState,
      amapApiKeyConfigured: amapApiKeyConfigured ?? this.amapApiKeyConfigured,
      amapPrivacyConsent: amapPrivacyConsent ?? this.amapPrivacyConsent,
      amapSdkInitialized: amapSdkInitialized ?? this.amapSdkInitialized,
      locationEngine: locationEngine ?? this.locationEngine,
      lastAmapLocationType: lastAmapLocationType ?? this.lastAmapLocationType,
      lastAmapErrorCode: lastAmapErrorCode ?? this.lastAmapErrorCode,
      lastAmapErrorMessage: lastAmapErrorMessage ?? this.lastAmapErrorMessage,
      satelliteCount: satelliteCount ?? this.satelliteCount,
      gpsAccuracyStatus: gpsAccuracyStatus ?? this.gpsAccuracyStatus,
      coordinateSystem: coordinateSystem ?? this.coordinateSystem,
      selectedLocationEngine:
          selectedLocationEngine ?? this.selectedLocationEngine,
      activeLocationEngine: activeLocationEngine ?? this.activeLocationEngine,
      fallbackReason: fallbackReason ?? this.fallbackReason,
      amapSdkCompileIntegration:
          amapSdkCompileIntegration ?? this.amapSdkCompileIntegration,
      amapRuntimeState: amapRuntimeState ?? this.amapRuntimeState,
      amapRuntimeVerification:
          amapRuntimeVerification ?? this.amapRuntimeVerification,
      locationPermissionGranted:
          locationPermissionGranted ?? this.locationPermissionGranted,
      csvSchemaVersion: csvSchemaVersion ?? this.csvSchemaVersion,
    );
  }
}

class TrackingEvent {
  const TrackingEvent({
    required this.type,
    this.location,
    this.status,
    this.message,
    this.sessionId,
    this.provider,
    this.providerEnabled,
  });

  final TrackingEventType type;
  final LocationRecord? location;
  final TrackingServiceStatus? status;
  final String? message;
  final String? sessionId;
  final String? provider;
  final bool? providerEnabled;

  static TrackingEvent? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = PlatformMap(value);
    final rawType = map.string('type');
    final type = switch (rawType) {
      'trackingStarted' => TrackingEventType.trackingStarted,
      'trackingStopped' => TrackingEventType.trackingStopped,
      'location' => TrackingEventType.location,
      'serviceStatus' => TrackingEventType.serviceStatus,
      'providerStatus' => TrackingEventType.providerStatus,
      'error' => TrackingEventType.error,
      _ => TrackingEventType.unknown,
    };
    if (type == TrackingEventType.unknown) {
      return null;
    }
    final location = type == TrackingEventType.location
        ? LocationRecord.tryParse(value)
        : null;
    if (type == TrackingEventType.location && location == null) {
      return null;
    }
    return TrackingEvent(
      type: type,
      location: location,
      status: type == TrackingEventType.serviceStatus
          ? TrackingServiceStatus.fromMap(value)
          : null,
      message: map.string('message'),
      sessionId: map.string('sessionId'),
      provider: map.string('provider'),
      providerEnabled: map.nullableBoolean('enabled'),
    );
  }
}

class TrackingError {
  const TrackingError({required this.code, required this.message});

  final String code;
  final String message;
}

class TrackingSession {
  const TrackingSession({
    required this.sessionId,
    required this.fileName,
    this.path,
    this.lastModified,
    this.sizeBytes,
    this.startTimestamp,
    this.endTimestamp,
    this.isActive = false,
    this.locationEngine = 'LEGACY',
    this.sampleCount = 0,
    this.routePointCount = 0,
    this.skippedRows = 0,
    this.amapErrorCount = 0,
  });

  final String sessionId;
  final String fileName;
  final String? path;
  final DateTime? lastModified;
  final int? sizeBytes;
  final DateTime? startTimestamp;
  final DateTime? endTimestamp;
  final bool isActive;
  final String locationEngine;
  final int sampleCount;
  final int routePointCount;
  final int skippedRows;
  final int amapErrorCount;

  static TrackingSession? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = PlatformMap(value);
    final sessionId = map.string('sessionId');
    final fileName = map.string('fileName');
    if (sessionId == null || fileName == null) {
      return null;
    }
    final modifiedMillis = map.integer('lastModified');
    return TrackingSession(
      sessionId: sessionId,
      fileName: fileName,
      path: map.string('path'),
      lastModified: modifiedMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(modifiedMillis),
      sizeBytes: map.integer('sizeBytes'),
      startTimestamp: map.dateTime('startTimestamp'),
      endTimestamp: map.dateTime('endTimestamp'),
      isActive: map.boolean('isActive'),
      locationEngine: map.string('locationEngine') ?? 'LEGACY',
      sampleCount: map.integer('sampleCount') ?? 0,
      routePointCount: map.integer('routePointCount') ?? 0,
      skippedRows: map.integer('skippedRows') ?? 0,
      amapErrorCount: map.integer('amapErrorCount') ?? 0,
    );
  }
}

class BatteryOptimizationStatus {
  const BatteryOptimizationStatus({
    required this.isIgnoringBatteryOptimizations,
    required this.isOptimized,
    required this.manufacturer,
    required this.model,
    required this.androidVersion,
    required this.isOppo,
    this.buildDisplay = 'Unknown',
  });

  const BatteryOptimizationStatus.unknown()
    : isIgnoringBatteryOptimizations = false,
      isOptimized = true,
      manufacturer = 'Unknown',
      model = 'Unknown',
      androidVersion = 'Unknown',
      isOppo = false,
      buildDisplay = 'Unknown';

  final bool isIgnoringBatteryOptimizations;
  final bool isOptimized;
  final String manufacturer;
  final String model;
  final String androidVersion;
  final bool isOppo;
  final String buildDisplay;

  factory BatteryOptimizationStatus.fromMap(Object? value) {
    final map = PlatformMap(value);
    return BatteryOptimizationStatus(
      isIgnoringBatteryOptimizations: map.boolean(
        'isIgnoringBatteryOptimizations',
      ),
      isOptimized: map.boolean('isOptimized', fallback: true),
      manufacturer: map.string('manufacturer') ?? 'Unknown',
      model: map.string('model') ?? 'Unknown',
      androidVersion: map.string('androidVersion') ?? 'Unknown',
      isOppo: map.boolean('isOppo'),
      buildDisplay: map.string('buildDisplay') ?? 'Unknown',
    );
  }
}

enum AmapPrivacyConsent {
  accepted,
  declined,
  notSelected;

  String get wireValue => switch (this) {
    accepted => 'ACCEPTED',
    declined => 'DECLINED',
    notSelected => 'NOT_SELECTED',
  };

  static AmapPrivacyConsent fromWire(String? value) => switch (value) {
    'ACCEPTED' => accepted,
    'DECLINED' => declined,
    _ => notSelected,
  };
}

enum AmapRuntimeState {
  notAttempted,
  verified,
  failed;

  static AmapRuntimeState fromWire(String? value) => switch (value) {
    'VERIFIED' => verified,
    'FAILED' => failed,
    _ => notAttempted,
  };
}

enum AmapRuntimeVerification {
  verified,
  pendingApiKey,
  failed,
  notAttempted;

  static AmapRuntimeVerification fromWire(String? value) => switch (value) {
    'VERIFIED' => verified,
    'FAILED' => failed,
    'NOT_ATTEMPTED' => notAttempted,
    _ => pendingApiKey,
  };

  String get label => switch (this) {
    verified => 'Verified',
    pendingApiKey => 'Pending API key',
    failed => 'Failed',
    notAttempted => 'Not attempted',
  };
}

enum LocationEnginePreference {
  automatic('AUTOMATIC', 'Automatic'),
  androidGpsDemo('ANDROID_GPS_DEMO', 'Android GPS Demo'),
  amap('AMAP', 'AMap');

  const LocationEnginePreference(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static LocationEnginePreference fromWire(String? value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => automatic,
  );
}

enum LocationEngineType {
  androidLocationManager('ANDROID_LOCATION_MANAGER', 'Android GPS Demo'),
  amap('AMAP', 'AMap');

  const LocationEngineType(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static LocationEngineType? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) {
        return item;
      }
    }
    return null;
  }
}

class AmapConfiguration {
  const AmapConfiguration({
    required this.apiKeyConfigured,
    required this.privacyConsent,
    required this.sdkInitialized,
    required this.locationEngine,
    this.networkAvailable = true,
    this.sdkCompileIntegration = true,
    this.runtimeState = AmapRuntimeState.notAttempted,
    this.runtimeVerification = AmapRuntimeVerification.pendingApiKey,
    this.runtimeFailureReason,
  });

  const AmapConfiguration.unavailable()
    : apiKeyConfigured = false,
      privacyConsent = AmapPrivacyConsent.notSelected,
      sdkInitialized = false,
      locationEngine = 'UNAVAILABLE',
      networkAvailable = true,
      sdkCompileIntegration = true,
      runtimeState = AmapRuntimeState.notAttempted,
      runtimeVerification = AmapRuntimeVerification.pendingApiKey,
      runtimeFailureReason = null;

  final bool apiKeyConfigured;
  final AmapPrivacyConsent privacyConsent;
  final bool sdkInitialized;
  final String locationEngine;
  final bool networkAvailable;
  final bool sdkCompileIntegration;
  final AmapRuntimeState runtimeState;
  final AmapRuntimeVerification runtimeVerification;
  final String? runtimeFailureReason;

  bool get canUseAmap =>
      apiKeyConfigured && privacyConsent == AmapPrivacyConsent.accepted;

  factory AmapConfiguration.fromMap(Object? value) {
    final map = PlatformMap(value);
    return AmapConfiguration(
      apiKeyConfigured: map.boolean('apiKeyConfigured'),
      privacyConsent: AmapPrivacyConsent.fromWire(map.string('privacyConsent')),
      sdkInitialized: map.boolean('sdkInitialized'),
      locationEngine: map.string('locationEngine') ?? 'UNAVAILABLE',
      networkAvailable: map.boolean('networkAvailable', fallback: true),
      sdkCompileIntegration: map.boolean(
        'sdkCompileIntegration',
        fallback: true,
      ),
      runtimeState: AmapRuntimeState.fromWire(map.string('runtimeState')),
      runtimeVerification: AmapRuntimeVerification.fromWire(
        map.string('runtimeVerification'),
      ),
      runtimeFailureReason: map.string('runtimeFailureReason'),
    );
  }
}

class LocationEngineConfiguration {
  const LocationEngineConfiguration({
    this.selected = LocationEnginePreference.automatic,
    this.resolved = LocationEngineType.androidLocationManager,
    this.fallbackReason,
    this.amapOptionAvailable = false,
    this.amapUnavailableReason = 'A valid AMap Android SDK key is required.',
    this.csvSchemaVersion = '4',
  });

  final LocationEnginePreference selected;
  final LocationEngineType resolved;
  final String? fallbackReason;
  final bool amapOptionAvailable;
  final String? amapUnavailableReason;
  final String csvSchemaVersion;

  bool get shouldUseAmapMap =>
      selected != LocationEnginePreference.androidGpsDemo &&
      resolved == LocationEngineType.amap;

  factory LocationEngineConfiguration.fromMap(Object? value) {
    final map = PlatformMap(value);
    return LocationEngineConfiguration(
      selected: LocationEnginePreference.fromWire(
        map.string('selectedLocationEngine'),
      ),
      resolved:
          LocationEngineType.tryFromWire(
            map.string('resolvedLocationEngine'),
          ) ??
          LocationEngineType.androidLocationManager,
      fallbackReason: map.string('fallbackReason'),
      amapOptionAvailable: map.boolean('amapOptionAvailable'),
      amapUnavailableReason: map.string('amapUnavailableReason'),
      csvSchemaVersion: map.string('csvSchemaVersion') ?? '4',
    );
  }
}

enum AmapMapType {
  standard('STANDARD'),
  satellite('SATELLITE'),
  night('NIGHT');

  const AmapMapType(this.wireValue);
  final String wireValue;

  static AmapMapType fromWire(String? value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => standard,
  );
}

class TrackingMapPreferences {
  const TrackingMapPreferences({
    this.mapType = AmapMapType.standard,
    this.trafficEnabled = false,
    this.compassEnabled = true,
    this.scaleEnabled = true,
  });

  final AmapMapType mapType;
  final bool trafficEnabled;
  final bool compassEnabled;
  final bool scaleEnabled;

  factory TrackingMapPreferences.fromMap(Object? value) {
    final map = PlatformMap(value);
    return TrackingMapPreferences(
      mapType: AmapMapType.fromWire(map.string('mapType')),
      trafficEnabled: map.boolean('trafficEnabled'),
      compassEnabled: map.boolean('compassEnabled', fallback: true),
      scaleEnabled: map.boolean('scaleEnabled', fallback: true),
    );
  }

  Map<String, Object> toMap() => {
    'mapType': mapType.wireValue,
    'trafficEnabled': trafficEnabled,
    'compassEnabled': compassEnabled,
    'scaleEnabled': scaleEnabled,
  };

  TrackingMapPreferences copyWith({
    AmapMapType? mapType,
    bool? trafficEnabled,
    bool? compassEnabled,
    bool? scaleEnabled,
  }) => TrackingMapPreferences(
    mapType: mapType ?? this.mapType,
    trafficEnabled: trafficEnabled ?? this.trafficEnabled,
    compassEnabled: compassEnabled ?? this.compassEnabled,
    scaleEnabled: scaleEnabled ?? this.scaleEnabled,
  );
}

class TrackingSessionRecords {
  const TrackingSessionRecords({
    required this.records,
    this.skippedRows = 0,
    this.lifecycleRows = 0,
    this.amapErrorCount = 0,
    this.startTimestamp,
    this.endTimestamp,
    this.locationEngine = 'LEGACY',
  });

  final List<LocationRecord> records;
  final int skippedRows;
  final int lifecycleRows;
  final int amapErrorCount;
  final DateTime? startTimestamp;
  final DateTime? endTimestamp;
  final String locationEngine;

  factory TrackingSessionRecords.fromMap(Object? value) {
    final map = PlatformMap(value);
    final rawRecords = map.list('records');
    return TrackingSessionRecords(
      records: rawRecords
          .map(LocationRecord.tryParse)
          .whereType<LocationRecord>()
          .toList(growable: false),
      skippedRows: map.integer('skippedRows') ?? 0,
      lifecycleRows: map.integer('lifecycleRows') ?? 0,
      amapErrorCount: map.integer('amapErrorCount') ?? 0,
      startTimestamp: map.dateTime('startTimestamp'),
      endTimestamp: map.dateTime('endTimestamp'),
      locationEngine: map.string('locationEngine') ?? 'LEGACY',
    );
  }
}

class SessionOperationResult {
  const SessionOperationResult({required this.success, required this.message});

  final bool success;
  final String message;

  factory SessionOperationResult.fromMap(Object? value) {
    final map = PlatformMap(value);
    return SessionOperationResult(
      success: map.boolean('success'),
      message: map.string('message') ?? 'Session operation failed.',
    );
  }
}

class PlatformMap {
  PlatformMap(Object? value)
    : _value = value is Map ? Map<Object?, Object?>.from(value) : const {};

  final Map<Object?, Object?> _value;

  bool boolean(String key, {bool fallback = false}) =>
      _value[key] is bool ? _value[key] as bool : fallback;

  bool? nullableBoolean(String key) =>
      _value[key] is bool ? _value[key] as bool : null;

  String? string(String key) {
    final value = _value[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  int? integer(String key) {
    final value = _value[key];
    return value is num && value.isFinite ? value.toInt() : null;
  }

  DateTime? dateTime(String key) {
    final value = string(key);
    return value == null ? null : DateTime.tryParse(value);
  }

  List<Object?> list(String key) {
    final value = _value[key];
    return value is List ? List<Object?>.from(value) : const [];
  }
}
