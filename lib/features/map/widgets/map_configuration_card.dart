import 'package:flutter/material.dart';

class MapConfigurationCard extends StatelessWidget {
  const MapConfigurationCard({
    this.onContinueWithAndroid,
    this.packageName = 'com.andromind.oppo_background_gps_demo',
    super.key,
  });

  final VoidCallback? onContinueWithAndroid;
  final String packageName;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFFAEB),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.key_off_outlined, color: Color(0xFFB54708)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AMap configuration required',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'A valid AMap Android SDK key is required to enable AMap '
                    'map rendering and AMap location services. Android GPS '
                    'Demo Mode remains available.',
                  ),
                  const SizedBox(height: 8),
                  Text('Package name: $packageName'),
                  const Text('AMap runtime verification: Pending API key'),
                  if (onContinueWithAndroid != null) ...[
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: onContinueWithAndroid,
                      child: const Text('Continue with Android GPS Demo'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
