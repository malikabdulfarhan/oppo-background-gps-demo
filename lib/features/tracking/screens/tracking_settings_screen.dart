import 'package:flutter/material.dart';

import '../controllers/tracking_controller.dart';
import '../services/tracking_models.dart';
import '../widgets/amap_privacy_dialog.dart';

class TrackingSettingsScreen extends StatelessWidget {
  const TrackingSettingsScreen({required this.controller, super.key});

  final TrackingController controller;

  @override
  Widget build(BuildContext context) {
    final consent = controller.amapConfiguration.privacyConsent;
    final engine = controller.locationEngineConfiguration;
    final activeAmap =
        controller.isTracking &&
        controller.serviceStatus.activeLocationEngine ==
            LocationEngineType.amap;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location engine',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.isTracking
                      ? 'Stop tracking before changing engines.'
                      : 'Automatic uses AMap when ready and otherwise falls back to Android GPS.',
                ),
                RadioGroup<LocationEnginePreference>(
                  groupValue: engine.selected,
                  onChanged: (value) {
                    if (value != null &&
                        !controller.isTracking &&
                        (value != LocationEnginePreference.amap ||
                            engine.amapOptionAvailable)) {
                      controller.setLocationEnginePreference(value);
                    }
                  },
                  child: Column(
                    children: [
                      for (final preference in LocationEnginePreference.values)
                        RadioListTile<LocationEnginePreference>(
                          contentPadding: EdgeInsets.zero,
                          value: preference,
                          enabled:
                              !controller.isTracking &&
                              (preference != LocationEnginePreference.amap ||
                                  engine.amapOptionAvailable),
                          title: Text(preference.label),
                          subtitle:
                              preference == LocationEnginePreference.amap &&
                                  !engine.amapOptionAvailable
                              ? Text(
                                  engine.amapUnavailableReason ??
                                      'A valid AMap Android SDK key is required.',
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
                if (engine.fallbackReason case final reason?) ...[
                  Text(
                    reason,
                    style: const TextStyle(color: Color(0xFFB54708)),
                  ),
                  const SizedBox(height: 8),
                ],
                if (controller.amapConfiguration.runtimeState ==
                    AmapRuntimeState.failed)
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: controller.retryAmapInitialization,
                        child: const Text('Retry AMap'),
                      ),
                      TextButton(
                        onPressed: controller.isTracking
                            ? null
                            : () => controller.setLocationEnginePreference(
                                LocationEnginePreference.androidGpsDemo,
                              ),
                        child: const Text('Use Android GPS'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('AMap privacy consent'),
                subtitle: Text(
                  '${_label(consent)} — applies only to AMap SDK features',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _review(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Review AMap privacy information'),
                onTap: () => showAmapPrivacyDetails(context),
              ),
              if (consent == AmapPrivacyConsent.accepted) ...[
                const Divider(height: 1),
                ListTile(
                  enabled: !activeAmap,
                  leading: const Icon(Icons.no_accounts_outlined),
                  title: const Text('Revoke consent'),
                  subtitle: Text(
                    activeAmap
                        ? 'Stop AMap tracking before revoking consent.'
                        : 'Only AMap map and location features will be disabled.',
                  ),
                  onTap: activeAmap ? null : () => _revoke(context),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.battery_saver_outlined),
                title: const Text('Battery optimization settings'),
                onTap: controller.openBatteryOptimizationSettings,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.app_settings_alt_outlined),
                title: const Text('Android app settings'),
                onTap: controller.openAppSettings,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.location_searching_outlined),
                title: const Text('Android location settings'),
                onTap: controller.openLocationSettings,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _review(BuildContext context) async {
    final decision = await showAmapPrivacyDialog(context);
    if (decision != null) {
      await controller.setAmapPrivacyConsent(decision);
    }
  }

  Future<void> _revoke(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke AMap consent?'),
        content: const Text(
          'The map and AMap location engine will be disabled until consent is '
          'accepted again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.setAmapPrivacyConsent(AmapPrivacyConsent.declined);
    }
  }

  String _label(AmapPrivacyConsent value) => switch (value) {
    AmapPrivacyConsent.accepted => 'Accepted',
    AmapPrivacyConsent.declined => 'Declined',
    AmapPrivacyConsent.notSelected => 'Not selected',
  };
}
