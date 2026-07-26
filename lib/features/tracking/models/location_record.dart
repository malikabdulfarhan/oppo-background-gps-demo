class LocationRecord {
  const LocationRecord({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    this.movementType = 'MOV 5s',
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String movementType;

  String get formattedTimestamp {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${timestamp.year}-'
        '${twoDigits(timestamp.month)}-'
        '${twoDigits(timestamp.day)} '
        '${twoDigits(timestamp.hour)}:'
        '${twoDigits(timestamp.minute)}:'
        '${twoDigits(timestamp.second)}';
  }
}
