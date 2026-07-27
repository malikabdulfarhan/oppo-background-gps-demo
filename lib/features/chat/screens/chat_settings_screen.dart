import 'package:flutter/material.dart';

import '../controllers/chat_controller.dart';
import 'chat_login_screen.dart';

class ChatSettingsScreen extends StatelessWidget {
  const ChatSettingsScreen({required this.controller, super.key});
  final ChatController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Chat Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row('Active chat provider', controller.providerType.label),
          _row(
            'SDKAppID configured',
            controller.isTencentConfigured ? 'Yes' : 'No',
          ),
          _row(
            'Tencent initialization',
            controller.sdkInitializationState.label,
          ),
          _row('Secure authentication', controller.automaticAuthState.label),
          _row(
            'Saved automatic login',
            controller.hasSavedChatSession ? 'Yes' : 'No',
          ),
          _row('Login status', controller.authenticationState.label),
          _row('Logged-in UserID', controller.loggedInUserId ?? 'None'),
          _row('Network state', controller.networkState.label),
          _row('Total unread count', '${controller.totalUnreadCount}'),
          _row('Offline push', 'Not configured'),
          const Divider(height: 32),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ChatLoginScreen(controller: controller),
              ),
            ),
            icon: const Icon(Icons.cloud_outlined),
            label: const Text('Open Chat sign-in'),
          ),
          OutlinedButton(
            onPressed: controller.switchToLocalDemo,
            child: const Text('Switch to Local Demo'),
          ),
          OutlinedButton(
            onPressed:
                controller.isTencentLoggedIn || controller.hasSavedChatSession
                ? controller.logoutTencent
                : null,
            child: const Text('Sign out and forget login'),
          ),
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset local demo data?'),
                  content: const Text(
                    'Local conversations will return to their seeded state.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await controller.resetLocalDemoData();
            },
            child: const Text('Reset local demo data'),
          ),
        ],
      ),
    ),
  );

  Widget _row(String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value),
  );
}
