import 'package:flutter/material.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({required this.onSend, super.key});

  static const maxLength = 2000;
  final Future<void> Function(String text) onSend;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (_sending || text.isEmpty || text.length > MessageComposer.maxLength) {
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
      _controller.clear();
    } on Object {
      // The conversation screen presents the provider-safe failure message.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLength: MessageComposer.maxLength,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Message',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    ),
  );
}
