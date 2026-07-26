import 'package:flutter/material.dart';

import '../services/tracking_models.dart';

Future<AmapPrivacyConsent?> showAmapPrivacyDialog(BuildContext context) {
  return showDialog<AmapPrivacyConsent>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _AmapPrivacyDialog(),
  );
}

Future<void> showAmapPrivacyDetails(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('AMap privacy details'),
      content: const SingleChildScrollView(
        child: Text(
          'This demo uses the AMap Map SDK to render routes and the AMap '
          'Location SDK to collect location samples for live and background '
          'tracking. Samples are stored as CSV files in the app-private '
          'directory. A persistent Android notification is shown while '
          'tracking, and tracking can be stopped at any time.\n\n'
          'No public privacy-policy URL is configured for this demo.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _AmapPrivacyDialog extends StatelessWidget {
  const _AmapPrivacyDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.privacy_tip_outlined),
      title: const Text('AMap location privacy'),
      content: const Text(
        'This app uses AMap Map SDK and AMap Location SDK for live and '
        'background route tracking. Location samples are stored in '
        'app-private CSV files. A persistent notification is displayed while '
        'tracking, and you may stop tracking at any time.',
      ),
      actions: [
        TextButton(
          onPressed: () => showAmapPrivacyDetails(context),
          child: const Text('View Privacy Details'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, AmapPrivacyConsent.declined),
          child: const Text('Decline'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, AmapPrivacyConsent.accepted),
          child: const Text('Accept and Continue'),
        ),
      ],
    );
  }
}
