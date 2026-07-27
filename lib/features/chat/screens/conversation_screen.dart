import 'dart:async';

import 'package:flutter/material.dart';

import '../../tracking/controllers/tracking_controller.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_configuration.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/tracking_share_summary.dart';
import '../services/chat_call_service.dart';
import '../services/chat_service.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/message_composer.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    required this.controller,
    required this.conversation,
    required this.trackingController,
    super.key,
  });

  final ChatController controller;
  final ChatConversation conversation;
  final TrackingController trackingController;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = const [];
  StreamSubscription<ChatEvent>? _subscription;
  bool _loading = true;
  bool _loadingEarlier = false;
  bool _startingCall = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = widget.controller.events.listen((event) {
      if (event.type == ChatEventType.newMessage &&
          event.message?.conversationId == widget.conversation.id) {
        unawaited(_load());
      }
    });
    unawaited(widget.controller.markConversationAsRead(widget.conversation.id));
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool earlier = false}) async {
    if (earlier && (_loadingEarlier || _messages.isEmpty)) return;
    if (earlier) setState(() => _loadingEarlier = true);
    try {
      final loaded = await widget.controller.getMessages(
        conversationId: widget.conversation.id,
        cursor: earlier ? _messages.first.id : null,
      );
      if (!mounted) return;
      setState(() {
        _messages = earlier
            ? [...loaded.reversed, ..._messages]
            : loaded.reversed.toList(growable: false);
        _loading = false;
        _loadingEarlier = false;
        _error = null;
      });
      if (!earlier) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollLatest());
      }
    } on ChatServiceException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingEarlier = false;
          _error = error.summary;
        });
      }
    }
  }

  Future<void> _send(String text) async {
    try {
      await widget.controller.sendTextMessage(
        recipientUserId: widget.conversation.participant.userId,
        text: text,
      );
      await _load();
    } on ChatServiceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.summary)));
      }
      rethrow;
    }
  }

  Future<void> _sendIgnoringFailure(String text) async {
    try {
      await _send(text);
    } on ChatServiceException {
      // _send already presented the provider-safe error.
    }
  }

  Future<void> _startCall(ChatCallMediaType mediaType) async {
    if (_startingCall) return;
    setState(() => _startingCall = true);
    final recipient = widget.conversation.participant.userId;
    final result = mediaType == ChatCallMediaType.audio
        ? await widget.controller.startAudioCall(recipient)
        : await widget.controller.startVideoCall(recipient);
    if (!mounted) return;
    setState(() => _startingCall = false);
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Unable to start the call.'),
          showCloseIcon: true,
        ),
      );
    }
  }

  Future<void> _shareTrackingStatus() async {
    final record = widget.trackingController.latestLocation;
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location sample is available yet.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share current tracking status?'),
        content: const Text(
          'Only the latest tracking status and location will be shared.\n\n'
          'Only share location information with a trusted recipient.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Share'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final status = widget.trackingController.serviceStatus;
    final engine =
        status.activeLocationEngine?.label ??
        widget.trackingController.locationEngineConfiguration.resolved.label;
    final summary = TrackingShareSummary(
      isTracking: widget.trackingController.isTracking,
      latitude: record.latitude,
      longitude: record.longitude,
      accuracyMeters: record.accuracyMeters,
      timestamp: record.timestamp,
      activeEngine: engine,
      sessionId: status.sessionId,
    );
    await _sendIgnoringFailure(
      summary.toShareText(
        localDemo: widget.controller.providerType == ChatProviderType.localDemo,
      ),
    );
  }

  void _scrollLatest() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.conversation.participant.title),
      actions: [
        if (widget.controller.providerType == ChatProviderType.tencentCloud &&
            widget.controller.isTencentLoggedIn) ...[
          if (_startingCall)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Start audio call',
              onPressed: () => _startCall(ChatCallMediaType.audio),
              icon: const Icon(Icons.call_outlined),
            ),
            IconButton(
              tooltip: 'Start video call',
              onPressed: () => _startCall(ChatCallMediaType.video),
              icon: const Icon(Icons.videocam_outlined),
            ),
          ],
        ],
        IconButton(
          tooltip: 'Share current tracking status',
          onPressed: _shareTrackingStatus,
          icon: const Icon(Icons.location_on_outlined),
        ),
        if (widget.controller.providerType == ChatProviderType.localDemo)
          IconButton(
            tooltip: 'Simulate incoming message',
            onPressed: () => widget.controller.simulateIncomingMessage(
              widget.conversation.id,
            ),
            icon: const Icon(Icons.mark_chat_unread_outlined),
          ),
      ],
    ),
    body: Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.privacy_tip_outlined, size: 18),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Only share location information with a trusted recipient.',
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: FilledButton(
                    onPressed: _load,
                    child: Text('Retry: $_error'),
                  ),
                )
              : _messages.isEmpty
              ? const Center(child: Text('No messages yet'))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Center(
                        child: TextButton(
                          onPressed: _loadingEarlier
                              ? null
                              : () => _load(earlier: true),
                          child: Text(
                            _loadingEarlier
                                ? 'Loading…'
                                : 'Load earlier messages',
                          ),
                        ),
                      );
                    }
                    final message = _messages[index - 1];
                    return ChatMessageBubble(
                      message: message,
                      onRetry:
                          message.deliveryState ==
                              ChatMessageDeliveryState.failed
                          ? () => unawaited(_sendIgnoringFailure(message.text))
                          : null,
                    );
                  },
                ),
        ),
        MessageComposer(onSend: _send),
      ],
    ),
  );
}
