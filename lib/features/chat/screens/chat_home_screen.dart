import 'package:flutter/material.dart';

import '../../tracking/controllers/tracking_controller.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_conversation.dart';
import '../widgets/chat_configuration_card.dart';
import '../widgets/chat_status_banner.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/empty_chat_state.dart';
import 'chat_login_screen.dart';
import 'chat_settings_screen.dart';
import 'conversation_screen.dart';
import 'new_conversation_screen.dart';

class ChatHomeScreen extends StatelessWidget {
  const ChatHomeScreen({
    required this.controller,
    required this.trackingController,
    super.key,
  });

  final ChatController controller;
  final TrackingController trackingController;

  Future<void> _openConversation(
    BuildContext context,
    ChatConversation conversation,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          controller: controller,
          conversation: conversation,
          trackingController: trackingController,
        ),
      ),
    );
    await controller.refreshConversations();
  }

  Future<void> _newConversation(BuildContext context) async {
    final conversation = await Navigator.push<ChatConversation>(
      context,
      MaterialPageRoute<ChatConversation>(
        builder: (_) => NewConversationScreen(controller: controller),
      ),
    );
    if (conversation != null && context.mounted) {
      await _openConversation(context, conversation);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              ChatStatusBanner(provider: controller.providerType),
              if (!controller.isTencentLoggedIn) ...[
                const SizedBox(height: 8),
                ChatConfigurationCard(
                  sdkAppIdConfigured: controller.isTencentConfigured,
                  onOpenLogin: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ChatLoginScreen(controller: controller),
                    ),
                  ),
                ),
              ],
              if (controller.lastErrorSummary case final error?) ...[
                const SizedBox(height: 8),
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(error),
                    trailing: TextButton(
                      onPressed: controller.refreshConversations,
                      child: const Text('Retry'),
                    ),
                  ),
                ),
              ],
              Row(
                children: [
                  Text(
                    'Conversations',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Chat settings',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ChatSettingsScreen(controller: controller),
                      ),
                    ),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'New conversation',
                    onPressed: () => _newConversation(context),
                    icon: const Icon(Icons.add_comment_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: controller.isLoading && controller.conversations.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : controller.conversations.isEmpty
              ? EmptyChatState(
                  onNewConversation: () => _newConversation(context),
                )
              : RefreshIndicator(
                  onRefresh: controller.refreshConversations,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: controller.conversations.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final conversation = controller.conversations[index];
                      return ConversationTile(
                        conversation: conversation,
                        onTap: () => _openConversation(context, conversation),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  );
}
