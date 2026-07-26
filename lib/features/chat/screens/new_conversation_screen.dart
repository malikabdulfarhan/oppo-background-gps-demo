import 'package:flutter/material.dart';

import '../controllers/chat_controller.dart';
import '../models/chat_configuration.dart';

class NewConversationScreen extends StatefulWidget {
  const NewConversationScreen({required this.controller, super.key});
  final ChatController controller;

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  final _recipient = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _recipient.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final id = _recipient.text.trim();
    if (id.isEmpty ||
        id.length > 64 ||
        !RegExp(r'^[A-Za-z0-9_.@-]+$').hasMatch(id)) {
      setState(() => _error = 'Enter a valid recipient User ID.');
      return;
    }
    final conversation = await widget.controller.createLocalConversation(
      recipientUserId: id,
    );
    if (mounted) Navigator.pop(context, conversation);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New Conversation')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _recipient,
          decoration: InputDecoration(
            labelText:
                'Recipient ${widget.controller.providerType == ChatProviderType.tencentCloud ? 'Tencent ' : ''}UserID',
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _open(),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _open,
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Open conversation'),
        ),
        if (widget.controller.providerType == ChatProviderType.localDemo) ...[
          const SizedBox(height: 20),
          const Text('Demo users'),
          for (final user in const [
            ('dispatch', 'Dispatch Coordinator'),
            ('field_ops', 'Field Operations'),
            ('support', 'Technical Support'),
          ])
            ListTile(
              title: Text(user.$2),
              subtitle: Text(user.$1),
              onTap: () async {
                final result = await widget.controller.createLocalConversation(
                  recipientUserId: user.$1,
                  displayName: user.$2,
                );
                if (context.mounted) Navigator.pop(context, result);
              },
            ),
        ],
      ],
    ),
  );
}
