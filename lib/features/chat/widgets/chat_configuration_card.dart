import 'package:flutter/material.dart';

class ChatConfigurationCard extends StatelessWidget {
  const ChatConfigurationCard({
    required this.sdkAppIdConfigured,
    required this.onOpenLogin,
    super.key,
  });

  final bool sdkAppIdConfigured;
  final VoidCallback onOpenLogin;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sdkAppIdConfigured
                ? 'Tencent Cloud Chat available'
                : 'Tencent Cloud configuration required',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            sdkAppIdConfigured
                ? 'Enter a User ID and temporary UserSig to connect.'
                : 'A Tencent SDKAppID, UserID, and temporary UserSig are '
                      'required for real cloud messaging. Local Chat Demo '
                      'Mode remains available.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenLogin,
            icon: const Icon(Icons.cloud_outlined),
            label: const Text('Tencent login'),
          ),
        ],
      ),
    ),
  );
}
