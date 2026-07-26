class LocationRecord {
  const LocationRecord({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    this.sequence,
    this.provider,
    this.speedMetersPerSecond,
    this.bearingDegrees,
    this.altitudeMeters,
    this.batteryPercent,
    this.screenState,
    this.appProcessState,
    this.movementType = 'MOV 5s',
  });

  final int? sequence;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String? provider;
  final double? speedMetersPerSecond;
  final double? bearingDegrees;
  final double? altitudeMeters;
  final int? batteryPercent;
  final String? screenState;
  final String? appProcessState;
  final String movementType;

  String get identity =>
      '${sequence ?? 'none'}|${timestamp.toUtc().toIso8601String()}|'
      '$latitude|$longitude';

  static LocationRecord? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = Map<Object?, Object?>.from(value);
    final timestampValue = map['timestamp'];
    final latitude = _finiteDouble(map['latitude']);
    final longitude = _finiteDouble(map['longitude']);
    final accuracy = _finiteDouble(map['accuracy']);
    final timestamp = timestampValue is String
        ? DateTime.tryParse(timestampValue)
        : null;
    if (timestamp == null ||
        latitude == null ||
        longitude == null ||
        accuracy == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        accuracy < 0) {
      return null;
    }
    return LocationRecord(
      sequence: _intValue(map['sequence']),
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracy,
      provider: _stringValue(map['provider']),
      speedMetersPerSecond: _finiteDouble(map['speed']),
      bearingDegrees: _finiteDouble(map['bearing']),
      altitudeMeters: _finiteDouble(map['altitude']),
      batteryPercent: _intValue(map['batteryPercent']),
      screenState: _stringValue(map['screenState']),
      appProcessState: _stringValue(map['appProcessState']),
    );
  }

  String get formattedTimestamp {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${timestamp.year}-'
        '${twoDigits(timestamp.month)}-'
        '${twoDigits(timestamp.day)} '
        '${twoDigits(timestamp.hour)}:'
        '${twoDigits(timestamp.minute)}:'
        '${twoDigits(timestamp.second)}';
  }

  static double? _finiteDouble(Object? value) {
    final number = value is num ? value.toDouble() : null;
    return number != null && number.isFinite ? number : null;
  }

  static int? _intValue(Object? value) => value is num ? value.toInt() : null;

  static String? _stringValue(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}
