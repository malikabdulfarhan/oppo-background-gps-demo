import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/chat_configuration.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import 'chat_service.dart';

class LocalDemoChatService implements ChatService, LocalDemoChatOperations {
  LocalDemoChatService({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const _fileName = 'local_chat_demo.json';
  static const _currentUserId = 'local_demo_operator';

  final Future<Directory> Function() _directoryProvider;
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();
  final List<ChatConversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messages = {};
  bool _initialized = false;
  bool _disposed = false;
  int _sequence = 0;

  @override
  ChatProviderType get providerType => ChatProviderType.localDemo;

  @override
  bool get isConfigured => true;

  @override
  String get sdkVersion => 'Local demo';

  @override
  bool get advancedListenerRegistered => false;

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    await _load();
    if (_conversations.isEmpty) {
      _seed();
      await _persist();
    }
    _initialized = true;
    _emit(const ChatEvent(type: ChatEventType.initialized));
  }

  @override
  Future<ChatLoginResult> login({
    required String userId,
    required String userSig,
  }) async => const ChatLoginResult(success: true);

  @override
  Future<void> logout() async {}

  @override
  Future<List<ChatConversation>> getConversations() async {
    await initialize();
    final values = [..._conversations]
      ..sort(
        (a, b) => (b.lastMessageTimestamp ?? DateTime(1970)).compareTo(
          a.lastMessageTimestamp ?? DateTime(1970),
        ),
      );
    return List.unmodifiable(values);
  }

  @override
  Future<List<ChatMessage>> getMessages({
    required String conversationId,
    String? cursor,
  }) async {
    await initialize();
    final values = [...?_messages[conversationId]]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    var start = 0;
    if (cursor != null) {
      final index = values.indexWhere((message) => message.id == cursor);
      start = index < 0 ? values.length : index + 1;
    }
    return values.skip(start).take(30).toList(growable: false);
  }

  @override
  Future<ChatMessage> sendTextMessage({
    required String recipientUserId,
    required String text,
  }) async {
    await initialize();
    final cleanRecipient = _validateUserId(recipientUserId);
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      throw const ChatServiceException('Message cannot be empty.');
    }
    final conversation = await createConversation(
      recipientUserId: cleanRecipient,
    );
    final message = ChatMessage(
      id: _nextId(),
      conversationId: conversation.id,
      senderUserId: _currentUserId,
      recipientUserId: cleanRecipient,
      text: cleanText,
      timestamp: DateTime.now(),
      isMine: true,
      providerType: ChatProviderType.localDemo,
      deliveryState: ChatMessageDeliveryState.localOnly,
      isGpsStatusShare: cleanText.contains('Tracking active:'),
    );
    _messages.putIfAbsent(conversation.id, () => []).add(message);
    _updateConversation(conversation.id, message, unreadCount: 0);
    await _persist();
    _emit(ChatEvent(type: ChatEventType.newMessage, message: message));
    _emit(const ChatEvent(type: ChatEventType.conversationsChanged));
    return message;
  }

  @override
  Future<void> markConversationAsRead(String conversationId) async {
    final index = _conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
    if (index < 0 || _conversations[index].unreadCount == 0) return;
    _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
    await _persist();
    _emit(
      ChatEvent(
        type: ChatEventType.unreadCountChanged,
        totalUnreadCount: _totalUnread,
      ),
    );
  }

  @override
  Future<ChatConversation> createConversation({
    required String recipientUserId,
    String? displayName,
  }) async {
    await initialize();
    final cleanId = _validateUserId(recipientUserId);
    final existing = _conversations.where(
      (conversation) => conversation.participant.userId == cleanId,
    );
    if (existing.isNotEmpty) return existing.first;
    final conversation = ChatConversation(
      id: 'local_$cleanId',
      participant: ChatUser(
        userId: cleanId,
        displayName: displayName?.trim().isEmpty == true
            ? null
            : displayName?.trim(),
      ),
      providerType: ChatProviderType.localDemo,
    );
    _conversations.add(conversation);
    _messages[conversation.id] = [];
    await _persist();
    _emit(const ChatEvent(type: ChatEventType.conversationsChanged));
    return conversation;
  }

  @override
  Future<void> simulateIncomingMessage(String conversationId) async {
    await initialize();
    final conversation = _conversations.where(
      (item) => item.id == conversationId,
    );
    if (conversation.isEmpty) {
      throw const ChatServiceException('Conversation is unavailable.');
    }
    const samples = [
      'Demo reply received. This message did not use Tencent Cloud.',
      'Field status noted for this local UI demonstration.',
      'Thanks. Continue testing the local conversation workflow.',
    ];
    final item = conversation.first;
    final message = ChatMessage(
      id: _nextId(),
      conversationId: conversationId,
      senderUserId: item.participant.userId,
      recipientUserId: _currentUserId,
      text: samples[_sequence % samples.length],
      timestamp: DateTime.now(),
      isMine: false,
      providerType: ChatProviderType.localDemo,
      deliveryState: ChatMessageDeliveryState.localOnly,
    );
    _messages.putIfAbsent(conversationId, () => []).add(message);
    _updateConversation(
      conversationId,
      message,
      unreadCount: item.unreadCount + 1,
    );
    await _persist();
    _emit(ChatEvent(type: ChatEventType.newMessage, message: message));
    _emit(
      ChatEvent(
        type: ChatEventType.unreadCountChanged,
        totalUnreadCount: _totalUnread,
      ),
    );
  }

  @override
  Future<void> resetLocalData() async {
    _conversations.clear();
    _messages.clear();
    _sequence = 0;
    _seed();
    await _persist();
    _emit(const ChatEvent(type: ChatEventType.conversationsChanged));
    _emit(
      ChatEvent(
        type: ChatEventType.unreadCountChanged,
        totalUnreadCount: _totalUnread,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _events.close();
  }

  int get _totalUnread => _conversations.fold(
    0,
    (total, conversation) => total + conversation.unreadCount,
  );

  String _validateUserId(String value) {
    final clean = value.trim();
    if (!RegExp(r'^[A-Za-z0-9_.@-]{1,64}$').hasMatch(clean)) {
      throw const ChatServiceException(
        'Use 1–64 letters, numbers, dots, underscores, @, or hyphens.',
      );
    }
    return clean;
  }

  String _nextId() =>
      'local_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';

  void _updateConversation(
    String conversationId,
    ChatMessage message, {
    required int unreadCount,
  }) {
    final index = _conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
    if (index < 0) return;
    _conversations[index] = _conversations[index].copyWith(
      lastMessagePreview: message.text,
      lastMessageTimestamp: message.timestamp,
      unreadCount: unreadCount,
    );
  }

  void _seed() {
    final now = DateTime.now();
    final seeds = [
      ('dispatch', 'Dispatch Coordinator', 'Route monitoring demo is ready.'),
      (
        'field_ops',
        'Field Operations',
        'Use this thread to test field updates.',
      ),
      (
        'support',
        'Technical Support',
        'This is a local-only support conversation.',
      ),
    ];
    for (var index = 0; index < seeds.length; index++) {
      final seed = seeds[index];
      final conversationId = 'local_${seed.$1}';
      final timestamp = now.subtract(Duration(minutes: (index + 1) * 18));
      final message = ChatMessage(
        id: 'seed_${seed.$1}',
        conversationId: conversationId,
        senderUserId: seed.$1,
        recipientUserId: _currentUserId,
        text: seed.$3,
        timestamp: timestamp,
        isMine: false,
        providerType: ChatProviderType.localDemo,
        deliveryState: ChatMessageDeliveryState.localOnly,
      );
      _conversations.add(
        ChatConversation(
          id: conversationId,
          participant: ChatUser(userId: seed.$1, displayName: seed.$2),
          providerType: ChatProviderType.localDemo,
          lastMessagePreview: seed.$3,
          lastMessageTimestamp: timestamp,
        ),
      );
      _messages[conversationId] = [message];
    }
  }

  Future<File> _dataFile() async {
    final root = await _directoryProvider();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}chat_demo',
    );
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  Future<void> _load() async {
    try {
      final file = await _dataFile();
      if (!await file.exists()) return;
      final value = jsonDecode(await file.readAsString());
      if (value is! Map) return;
      final map = Map<Object?, Object?>.from(value);
      _conversations.addAll(
        (map['conversations'] as List? ?? const [])
            .map(ChatConversation.fromJson)
            .whereType<ChatConversation>(),
      );
      for (final item in (map['messages'] as Map? ?? const {}).entries) {
        final conversationId = '${item.key}';
        final values = item.value is List ? item.value as List : const [];
        _messages[conversationId] = values
            .map(ChatMessage.fromJson)
            .whereType<ChatMessage>()
            .toList();
      }
    } on Object {
      _conversations.clear();
      _messages.clear();
    }
  }

  Future<void> _persist() async {
    final file = await _dataFile();
    final value = {
      'schemaVersion': 1,
      'conversations': _conversations
          .map((conversation) => conversation.toJson())
          .toList(),
      'messages': {
        for (final entry in _messages.entries)
          entry.key: entry.value.map((message) => message.toJson()).toList(),
      },
    };
    await file.writeAsString(jsonEncode(value), flush: true);
  }

  void _emit(ChatEvent event) {
    if (!_disposed) _events.add(event);
  }
}
