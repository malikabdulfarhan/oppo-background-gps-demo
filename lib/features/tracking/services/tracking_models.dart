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
  });

  const TrackingServiceStatus.stopped()
    : isTracking = false,
      serviceRunning = false,
      notificationPermissionGranted = true,
      sessionId = null,
      lastLocationTimestamp = null,
      currentLogPath = null,
      currentProvider = null,
      screenState = null;

  final bool isTracking;
  final bool serviceRunning;
  final bool notificationPermissionGranted;
  final String? sessionId;
  final DateTime? lastLocationTimestamp;
  final String? currentLogPath;
  final String? currentProvider;
  final String? screenState;

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
  });

  final String sessionId;
  final String fileName;
  final String? path;
  final DateTime? lastModified;
  final int? sizeBytes;

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
  });

  const BatteryOptimizationStatus.unknown()
    : isIgnoringBatteryOptimizations = false,
      isOptimized = true,
      manufacturer = 'Unknown',
      model = 'Unknown',
      androidVersion = 'Unknown',
      isOppo = false;

  final bool isIgnoringBatteryOptimizations;
  final bool isOptimized;
  final String manufacturer;
  final String model;
  final String androidVersion;
  final bool isOppo;

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
}
