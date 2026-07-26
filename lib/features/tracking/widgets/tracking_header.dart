import 'package:flutter/material.dart';

class TrackingHeader extends StatelessWidget {
  const TrackingHeader({
    required this.isStarting,
    required this.isTracking,
    required this.hasServiceError,
    required this.polylinePointCount,
    required this.locationSampleCount,
    required this.updateIntervalMs,
    required this.followLocation,
    required this.onFollowChanged,
    super.key,
  });

  final bool isStarting;
  final bool isTracking;
  final bool hasServiceError;
  final int polylinePointCount;
  final int locationSampleCount;
  final int updateIntervalMs;
  final bool followLocation;
  final ValueChanged<bool> onFollowChanged;

  @override
  Widget build(BuildContext context) {
    final statusColor = hasServiceError
        ? const Color(0xFFD92D20)
        : isTracking
        ? const Color(0xFF12B76A)
        : isStarting
        ? const Color(0xFFF79009)
        : const Color(0xFF98A2B3);
    final statusText = hasServiceError
        ? 'Service error'
        : isTracking
        ? 'Running in background'
        : isStarting
        ? 'Starting…'
        : 'Stopped';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: Color(0xFF155EEF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tracking status',
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 9, color: statusColor),
                          const SizedBox(width: 7),
                          Text(
                            statusText,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'UPDATE INTERVAL',
                      style: TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$updateIntervalMs ms',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Polyline points',
                    value: '$polylinePointCount',
                    icon: Icons.timeline_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Metric(
                    label: 'Location samples',
                    value: '$locationSampleCount',
                    icon: Icons.location_searching_rounded,
                  ),
                ),
              ],
            ),
            const Divider(height: 25),
            Row(
              children: [
                const Icon(
                  Icons.center_focus_strong_rounded,
                  size: 20,
                  color: Color(0xFF475467),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Follow Location',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Keep the current marker centered',
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(value: followLocation, onChanged: onFollowChanged),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF155EEF)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
