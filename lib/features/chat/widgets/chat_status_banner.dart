import 'package:flutter/material.dart';

import '../models/chat_configuration.dart';

class ChatStatusBanner extends StatelessWidget {
  const ChatStatusBanner({required this.provider, super.key});

  final ChatProviderType provider;

  @override
  Widget build(BuildContext context) {
    final local = provider == ChatProviderType.localDemo;
    return Material(
      color: local
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(local ? Icons.science_outlined : Icons.cloud_done_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                local
                    ? 'Local UI Demo — Not connected to Tencent Cloud'
                    : 'Tencent Cloud Chat',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
