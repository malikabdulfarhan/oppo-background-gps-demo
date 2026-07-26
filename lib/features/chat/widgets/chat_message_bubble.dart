import 'package:flutter/material.dart';

import '../models/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Align(
    alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 320),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.isMine
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.text),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                TimeOfDay.fromDateTime(
                  message.timestamp.toLocal(),
                ).format(context),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (message.isMine) ...[
                const SizedBox(width: 6),
                Text(
                  message.deliveryState.label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
              if (message.deliveryState == ChatMessageDeliveryState.failed &&
                  onRetry != null)
                IconButton(
                  tooltip: 'Retry',
                  visualDensity: VisualDensity.compact,
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
