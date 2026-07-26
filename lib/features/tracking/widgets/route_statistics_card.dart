import 'package:flutter/material.dart';

import '../analytics/route_metrics.dart';

class RouteStatisticsCard extends StatelessWidget {
  const RouteStatisticsCard({required this.metrics, super.key});

  final RouteMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final values = <(String, String)>[
      ('Duration', RouteMetrics.formatDuration(metrics.duration)),
      ('Samples', '${metrics.totalSamples}'),
      ('Route points', '${metrics.uniqueRoutePoints}'),
      ('Distance', RouteMetrics.formatDistance(metrics.distanceMeters)),
      ('Current speed', _speed(metrics.currentSpeedMetersPerSecond)),
      ('Average speed', _speed(metrics.averageSpeedMetersPerSecond)),
      ('Maximum speed', _speed(metrics.maximumSpeedMetersPerSecond)),
      ('Latest accuracy', _meters(metrics.latestAccuracyMeters)),
      ('Average accuracy', _meters(metrics.averageAccuracyMeters)),
      ('Best accuracy', _meters(metrics.bestAccuracyMeters)),
      ('Longest gap', RouteMetrics.formatDuration(metrics.longestUpdateGap)),
      (
        'Since update',
        RouteMetrics.formatDuration(metrics.timeSinceLastUpdate),
      ),
      ('Locked samples', '${metrics.lockedScreenSamples}'),
      ('GPS samples', '${metrics.gpsSamples}'),
      ('Network samples', '${metrics.networkSamples}'),
      ('AMap errors', '${metrics.amapErrorCount}'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Route statistics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 190,
                mainAxisExtent: 68,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: values.length,
              itemBuilder: (context, index) {
                final (label, value) = values[index];
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _speed(double metersPerSecond) =>
      '${(metersPerSecond * 3.6).toStringAsFixed(1)} km/h';

  String _meters(double meters) => '${meters.toStringAsFixed(1)} m';
}
