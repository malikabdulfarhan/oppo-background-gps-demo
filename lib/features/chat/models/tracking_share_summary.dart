class TrackingShareSummary {
  const TrackingShareSummary({
    required this.isTracking,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
    required this.activeEngine,
    this.sessionId,
  });

  final bool isTracking;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
  final String activeEngine;
  final String? sessionId;

  String toShareText({required bool localDemo}) {
    final suffix = localDemo ? '\n\nLocal demonstration only' : '';
    return 'Tracking active: ${isTracking ? 'Yes' : 'No'}\n'
        'Latest latitude: ${latitude.toStringAsFixed(6)}\n'
        'Latest longitude: ${longitude.toStringAsFixed(6)}\n'
        'Accuracy: ${accuracyMeters.toStringAsFixed(1)} m\n'
        'Latest update: ${timestamp.toLocal().toIso8601String()}\n'
        'Active location engine: $activeEngine\n'
        'Current session: ${sessionId ?? 'None'}$suffix';
  }
}
