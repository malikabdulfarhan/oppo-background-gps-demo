import 'package:flutter/material.dart';

import '../controllers/chat_controller.dart';

class ChatLoginScreen extends StatefulWidget {
  const ChatLoginScreen({required this.controller, super.key});

  final ChatController controller;

  @override
  State<ChatLoginScreen> createState() => _ChatLoginScreenState();
}

class _ChatLoginScreenState extends State<ChatLoginScreen> {
  final _userId = TextEditingController();
  final _userSig = TextEditingController();
  bool _obscure = true;
  String? _validation;

  @override
  void dispose() {
    _userId.dispose();
    _userSig.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!widget.controller.isTencentConfigured) {
      setState(() => _validation = 'SDKAppID must be greater than zero.');
      return;
    }
    if (_userId.text.trim().isEmpty || _userSig.text.trim().isEmpty) {
      setState(
        () => _validation = 'User ID and temporary UserSig are required.',
      );
      return;
    }
    setState(() => _validation = null);
    final result = await widget.controller.loginTencent(
      userId: _userId.text,
      userSig: _userSig.text,
    );
    _userSig.clear();
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
    } else {
      setState(() => _validation = result.message ?? 'Tencent login failed.');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Tencent Cloud Chat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.controller.isTencentConfigured
                        ? 'Configuration status'
                        : 'Tencent Cloud configuration required',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!widget.controller.isTencentConfigured)
                    const Text(
                      'A Tencent SDKAppID, UserID, and temporary UserSig are '
                      'required for real cloud messaging. Local Chat Demo '
                      'Mode remains available.',
                    ),
                  _Status('SDK integrated', 'Yes'),
                  _Status(
                    'SDKAppID',
                    widget.controller.isTencentConfigured
                        ? 'Configured'
                        : 'Missing',
                  ),
                  _Status(
                    'SDK',
                    widget.controller.sdkInitializationState.label,
                  ),
                  _Status('Login', widget.controller.authenticationState.label),
                  _Status('Network', widget.controller.networkState.label),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _userId,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'User ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _userSig,
            obscureText: _obscure,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Temporary UserSig',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show UserSig' : 'Hide UserSig',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'UserSig is a temporary Tencent authentication credential. '
            'Production apps should request it from a secure backend.',
          ),
          if (_validation case final message?) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: widget.controller.isLoginSubmitting ? null : _connect,
            icon: widget.controller.isLoginSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_done_outlined),
            label: const Text('Connect to Tencent Cloud'),
          ),
          OutlinedButton(
            onPressed: () async {
              await widget.controller.switchToLocalDemo();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Continue with Local Chat Demo'),
          ),
          TextButton(
            onPressed: () {
              _userId.clear();
              _userSig.clear();
              widget.controller.clearCredentialsState();
            },
            child: const Text('Clear credentials'),
          ),
          TextButton(
            onPressed: widget.controller.isTencentConfigured
                ? widget.controller.initializeTencent
                : null,
            child: const Text('Retry initialization'),
          ),
        ],
      ),
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
