class RouteMetrics {
  const RouteMetrics({
    required this.duration,
    required this.totalSamples,
    required this.uniqueRoutePoints,
    required this.distanceMeters,
    required this.currentSpeedMetersPerSecond,
    required this.averageSpeedMetersPerSecond,
    required this.maximumSpeedMetersPerSecond,
    required this.latestAccuracyMeters,
    required this.averageAccuracyMeters,
    required this.bestAccuracyMeters,
    required this.longestUpdateGap,
    required this.timeSinceLastUpdate,
    required this.lockedScreenSamples,
    required this.gpsSamples,
    required this.networkSamples,
    required this.amapErrorCount,
  });

  const RouteMetrics.empty()
    : duration = Duration.zero,
      totalSamples = 0,
      uniqueRoutePoints = 0,
      distanceMeters = 0,
      currentSpeedMetersPerSecond = 0,
      averageSpeedMetersPerSecond = 0,
      maximumSpeedMetersPerSecond = 0,
      latestAccuracyMeters = 0,
      averageAccuracyMeters = 0,
      bestAccuracyMeters = 0,
      longestUpdateGap = Duration.zero,
      timeSinceLastUpdate = Duration.zero,
      lockedScreenSamples = 0,
      gpsSamples = 0,
      networkSamples = 0,
      amapErrorCount = 0;

  final Duration duration;
  final int totalSamples;
  final int uniqueRoutePoints;
  final double distanceMeters;
  final double currentSpeedMetersPerSecond;
  final double averageSpeedMetersPerSecond;
  final double maximumSpeedMetersPerSecond;
  final double latestAccuracyMeters;
  final double averageAccuracyMeters;
  final double bestAccuracyMeters;
  final Duration longestUpdateGap;
  final Duration timeSinceLastUpdate;
  final int lockedScreenSamples;
  final int gpsSamples;
  final int networkSamples;
  final int amapErrorCount;

  static String formatDistance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(2)} km'
      : '${meters.toStringAsFixed(0)} m';

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}
