import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controllers/chat_controller.dart';
import '../models/chat_automatic_auth_state.dart';

class ChatLoginScreen extends StatefulWidget {
  const ChatLoginScreen({required this.controller, super.key});

  final ChatController controller;

  @override
  State<ChatLoginScreen> createState() => _ChatLoginScreenState();
}

class _ChatLoginScreenState extends State<ChatLoginScreen> {
  final _userId = TextEditingController();
  final _pin = TextEditingController();
  final _userSig = TextEditingController();
  bool _obscurePin = true;
  bool _obscureUserSig = true;
  String? _validation;

  @override
  void dispose() {
    _userId.dispose();
    _pin.dispose();
    _userSig.dispose();
    super.dispose();
  }

  Future<void> _connectSecurely() async {
    if (_userId.text.trim().isEmpty || _pin.text.isEmpty) {
      setState(() => _validation = 'User ID and demo PIN are required.');
      return;
    }
    setState(() => _validation = null);
    final result = await widget.controller.loginWithBackend(
      userId: _userId.text,
      pin: _pin.text,
    );
    _pin.clear();
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
    } else {
      setState(
        () => _validation = result.message ?? 'Secure Chat sign-in failed.',
      );
    }
  }

  Future<void> _connectWithUserSig() async {
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
    builder: (context, _) {
      final secureBusy =
          widget.controller.automaticAuthState ==
              ChatAutomaticAuthState.restoring ||
          widget.controller.automaticAuthState ==
              ChatAutomaticAuthState.signingIn;
      return Scaffold(
        appBar: AppBar(title: const Text('Tencent Cloud Chat')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(context),
            const SizedBox(height: 12),
            if (widget.controller.isAutomaticAuthAvailable)
              _buildSecureLogin(context, secureBusy)
            else
              _buildBackendRequired(context),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              _buildDeveloperLogin(context),
            ],
            if (_validation case final message?) ...[
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () async {
                await widget.controller.switchToLocalDemo();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Continue with Local Chat Demo'),
            ),
            if (widget.controller.hasSavedChatSession)
              TextButton(
                onPressed: secureBusy
                    ? null
                    : () async {
                        await widget.controller.clearSavedAuthentication();
                        _pin.clear();
                        _userSig.clear();
                      },
                child: const Text('Forget saved Chat login'),
              ),
            TextButton(
              onPressed: widget.controller.isTencentConfigured
                  ? widget.controller.initializeTencent
                  : null,
              child: const Text('Retry SDK initialization'),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildStatusCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.controller.isTencentConfigured
                ? 'Configuration status'
                : 'Tencent Cloud configuration required',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _Status('SDK integrated', 'Yes'),
          _Status(
            'SDKAppID',
            widget.controller.isTencentConfigured ? 'Configured' : 'Missing',
          ),
          _Status(
            'Secure authentication',
            widget.controller.automaticAuthState.label,
          ),
          _Status(
            'Saved login',
            widget.controller.hasSavedChatSession ? 'Available' : 'None',
          ),
          _Status('SDK', widget.controller.sdkInitializationState.label),
          _Status('Login', widget.controller.authenticationState.label),
          _Status('Network', widget.controller.networkState.label),
          if (widget.controller.automaticAuthMessage case final message?) ...[
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildSecureLogin(BuildContext context, bool secureBusy) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Secure demo sign-in',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter your demo account once. The PIN is sent only to the '
            'authentication backend and is never saved on this device.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _userId,
            enabled: !secureBusy,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              labelText: 'User ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin,
            enabled: !secureBusy,
            obscureText: _obscurePin,
            enableSuggestions: false,
            autocorrect: false,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!secureBusy) _connectSecurely();
            },
            decoration: InputDecoration(
              labelText: 'Demo PIN',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscurePin ? 'Show PIN' : 'Hide PIN',
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
                icon: Icon(
                  _obscurePin ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: secureBusy ? null : _connectSecurely,
            icon: secureBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_outline),
            label: Text(secureBusy ? 'Signing in…' : 'Sign in securely'),
          ),
        ],
      ),
    ),
  );

  Widget _buildBackendRequired(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Secure authentication backend not configured',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Build the app with TENCENT_CHAT_AUTH_BASE_URL to enable '
            'automatic sign-in. Local Chat Demo Mode remains available.',
          ),
        ],
      ),
    ),
  );

  Widget _buildDeveloperLogin(BuildContext context) => Card(
    child: ExpansionTile(
      title: const Text('Developer UserSig login'),
      subtitle: const Text('Debug builds only'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (!widget.controller.isAutomaticAuthAvailable) ...[
          TextField(
            controller: _userId,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'User ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _userSig,
          obscureText: _obscureUserSig,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Temporary UserSig',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _obscureUserSig ? 'Show UserSig' : 'Hide UserSig',
              onPressed: () =>
                  setState(() => _obscureUserSig = !_obscureUserSig),
              icon: Icon(
                _obscureUserSig ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This temporary credential stays in memory only. Production and '
          'release builds use the secure backend instead.',
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: widget.controller.isLoginSubmitting
              ? null
              : _connectWithUserSig,
          icon: const Icon(Icons.developer_mode),
          label: const Text('Connect with UserSig'),
        ),
      ],
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
