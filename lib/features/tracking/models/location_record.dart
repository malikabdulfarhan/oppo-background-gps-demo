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
    this.locationEngine = 'AMAP',
    this.amapLocationType,
    this.amapErrorCode,
    this.amapErrorInfo,
    this.gpsAccuracyStatus,
    this.satelliteCount,
    this.isMock,
    this.coordinateSystem = 'GCJ02',
    this.country,
    this.province,
    this.city,
    this.district,
    this.street,
    this.address,
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
  final String locationEngine;
  final int? amapLocationType;
  final int? amapErrorCode;
  final String? amapErrorInfo;
  final int? gpsAccuracyStatus;
  final int? satelliteCount;
  final bool? isMock;
  final String coordinateSystem;
  final String? country;
  final String? province;
  final String? city;
  final String? district;
  final String? street;
  final String? address;
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
      locationEngine: _stringValue(map['locationEngine']) ?? 'LEGACY',
      amapLocationType: _intValue(map['amapLocationType']),
      amapErrorCode: _intValue(map['amapErrorCode']),
      amapErrorInfo: _stringValue(map['amapErrorInfo']),
      gpsAccuracyStatus: _intValue(map['gpsAccuracyStatus']),
      satelliteCount: _intValue(map['satelliteCount']),
      isMock: map['isMock'] is bool ? map['isMock'] as bool : null,
      coordinateSystem: _stringValue(map['coordinateSystem']) ?? 'WGS84_LEGACY',
      country: _stringValue(map['country']),
      province: _stringValue(map['province']),
      city: _stringValue(map['city']),
      district: _stringValue(map['district']),
      street: _stringValue(map['street']),
      address: _stringValue(map['address']),
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
