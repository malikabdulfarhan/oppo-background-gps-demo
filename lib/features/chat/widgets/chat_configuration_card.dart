import 'package:flutter/material.dart';

class ChatConfigurationCard extends StatelessWidget {
  const ChatConfigurationCard({
    required this.sdkAppIdConfigured,
    this.secureAuthConfigured = false,
    required this.onOpenLogin,
    super.key,
  });

  final bool sdkAppIdConfigured;
  final bool secureAuthConfigured;
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
                ? secureAuthConfigured
                      ? 'Sign in once with your demo account. Future launches '
                            'restore Chat automatically.'
                      : 'Secure automatic sign-in is not configured. Debug '
                            'builds can use a temporary UserSig.'
                : 'A Tencent SDKAppID and secure authentication backend are '
                      'required for real cloud messaging. Local Chat Demo '
                      'Mode remains available.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenLogin,
            icon: const Icon(Icons.cloud_outlined),
            label: Text(
              secureAuthConfigured ? 'Sign in to Tencent' : 'Chat setup',
            ),
          ),
        ],
      ),
    ),
  );
}
