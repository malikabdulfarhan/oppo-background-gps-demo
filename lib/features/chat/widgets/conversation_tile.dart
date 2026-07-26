import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    required this.conversation,
    required this.onTap,
    super.key,
  });

  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: CircleAvatar(child: Text(conversation.participant.initials)),
    title: Text(
      conversation.participant.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          conversation.lastMessagePreview ?? 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Wrap(
          spacing: 6,
          children: [
            _Badge(conversation.providerType.label),
            if (conversation.hasSendingMessage) const _Badge('Sending'),
            if (conversation.hasFailedMessage) const _Badge('Failed'),
          ],
        ),
      ],
    ),
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (conversation.lastMessageTimestamp case final time?)
          Text(
            TimeOfDay.fromDateTime(time.toLocal()).format(context),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        if (conversation.unreadCount > 0)
          Badge(label: Text('${conversation.unreadCount}')),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    ),
  );
}
