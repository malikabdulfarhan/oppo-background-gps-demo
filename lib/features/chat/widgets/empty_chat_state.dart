import 'package:flutter/material.dart';

class EmptyChatState extends StatelessWidget {
  const EmptyChatState({required this.onNewConversation, super.key});

  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 54,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'No conversations yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onNewConversation,
            child: const Text('Start conversation'),
          ),
        ],
      ),
    ),
  );
}
