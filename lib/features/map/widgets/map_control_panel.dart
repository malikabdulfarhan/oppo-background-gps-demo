import 'package:flutter/material.dart';

import '../../tracking/services/tracking_models.dart';

class MapControlPanel extends StatelessWidget {
  const MapControlPanel({
    required this.preferences,
    required this.followLocation,
    required this.onRecenter,
    required this.onFitRoute,
    required this.onFollowChanged,
    required this.onPreferencesChanged,
    super.key,
  });

  final TrackingMapPreferences preferences;
  final bool followLocation;
  final VoidCallback onRecenter;
  final VoidCallback onFitRoute;
  final ValueChanged<bool> onFollowChanged;
  final ValueChanged<TrackingMapPreferences> onPreferencesChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onRecenter,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Recenter'),
                ),
                OutlinedButton.icon(
                  onPressed: onFitRoute,
                  icon: const Icon(Icons.fit_screen),
                  label: const Text('Fit Route'),
                ),
                FilterChip(
                  selected: followLocation,
                  onSelected: onFollowChanged,
                  label: const Text('Follow'),
                  avatar: const Icon(Icons.gps_fixed, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<AmapMapType>(
              segments: const [
                ButtonSegment(
                  value: AmapMapType.standard,
                  label: Text('Standard'),
                ),
                ButtonSegment(
                  value: AmapMapType.satellite,
                  label: Text('Satellite'),
                ),
                ButtonSegment(value: AmapMapType.night, label: Text('Night')),
              ],
              selected: {preferences.mapType},
              onSelectionChanged: (selection) => onPreferencesChanged(
                preferences.copyWith(mapType: selection.first),
              ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Traffic layer'),
              value: preferences.trafficEnabled,
              onChanged: (value) => onPreferencesChanged(
                preferences.copyWith(trafficEnabled: value),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Compass'),
                  selected: preferences.compassEnabled,
                  onSelected: (value) => onPreferencesChanged(
                    preferences.copyWith(compassEnabled: value),
                  ),
                ),
                FilterChip(
                  label: const Text('Scale'),
                  selected: preferences.scaleEnabled,
                  onSelected: (value) => onPreferencesChanged(
                    preferences.copyWith(scaleEnabled: value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
