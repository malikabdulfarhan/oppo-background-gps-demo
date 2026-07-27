import 'dart:async';

import 'package:oppo_background_gps_demo/features/chat/models/chat_configuration.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_conversation.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_message.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_user.dart';
import 'package:oppo_background_gps_demo/features/chat/services/chat_service.dart';

class FakeChatService implements ChatService, LocalDemoChatOperations {
  FakeChatService({
    required this.providerType,
    this.isConfigured = true,
    this.initializeError,
    this.loginResult = const ChatLoginResult(success: true),
    List<ChatConversation>? conversations,
  }) : conversations = conversations ?? [];

  @override
  final ChatProviderType providerType;
  @override
  final bool isConfigured;
  final ChatServiceException? initializeError;
  ChatLoginResult loginResult;
  final List<ChatConversation> conversations;
  final Map<String, List<ChatMessage>> messages = {};
  final StreamController<ChatEvent> eventController =
      StreamController<ChatEvent>.broadcast();

  int initializeCalls = 0;
  int disposeCalls = 0;
  int markReadCalls = 0;
  int resetCalls = 0;
  int sendCalls = 0;
  bool loggedIn = false;
  String? loginUserId;
  String? loginUserSig;

  @override
  bool get advancedListenerRegistered => initializeCalls == 1;

  @override
  Stream<ChatEvent> get events => eventController.stream;

  @override
  String get sdkVersion => 'fake-9';

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
    if (initializeError case final error?) throw error;
  }

  @override
  Future<ChatLoginResult> login({
    required String userId,
    required String userSig,
  }) async {
    loginUserId = userId;
    loginUserSig = userSig;
    loggedIn = loginResult.success;
    return loginResult;
  }

  @override
  Future<void> logout() async => loggedIn = false;

  @override
  Future<List<ChatConversation>> getConversations() async =>
      List.unmodifiable(conversations);

  @override
  Future<List<ChatMessage>> getMessages({
    required String conversationId,
    String? cursor,
  }) async {
    final values = messages[conversationId] ?? const [];
    if (cursor == null) return List.unmodifiable(values);
    final index = values.indexWhere((item) => item.id == cursor);
    return index < 0 ? const [] : List.unmodifiable(values.skip(index + 1));
  }

  @override
  Future<ChatMessage> sendTextMessage({
    required String recipientUserId,
    required String text,
  }) async {
    sendCalls += 1;
    final conversation = await createConversation(
      recipientUserId: recipientUserId,
    );
    final message = ChatMessage(
      id: 'message_$sendCalls',
      conversationId: conversation.id,
      senderUserId: 'me',
      recipientUserId: recipientUserId,
      text: text,
      timestamp: DateTime.utc(2026, 7, 26),
      isMine: true,
      providerType: providerType,
      deliveryState: providerType == ChatProviderType.localDemo
          ? ChatMessageDeliveryState.localOnly
          : ChatMessageDeliveryState.sent,
    );
    messages.putIfAbsent(conversation.id, () => []).add(message);
    return message;
  }

  @override
  Future<void> markConversationAsRead(String conversationId) async {
    markReadCalls += 1;
  }

  @override
  Future<ChatConversation> createConversation({
    required String recipientUserId,
    String? displayName,
  }) async {
    final existing = conversations.where(
      (item) => item.participant.userId == recipientUserId,
    );
    if (existing.isNotEmpty) return existing.first;
    final conversation = ChatConversation(
      id: '${providerType.name}_$recipientUserId',
      participant: ChatUser(userId: recipientUserId, displayName: displayName),
      providerType: providerType,
    );
    conversations.add(conversation);
    return conversation;
  }

  @override
  Future<void> simulateIncomingMessage(String conversationId) async {
    final conversation = conversations.firstWhere(
      (item) => item.id == conversationId,
    );
    final message = ChatMessage(
      id: 'incoming',
      conversationId: conversationId,
      senderUserId: conversation.participant.userId,
      recipientUserId: 'me',
      text: 'Explicit simulated reply',
      timestamp: DateTime.utc(2026, 7, 26, 1),
      isMine: false,
      providerType: providerType,
      deliveryState: ChatMessageDeliveryState.localOnly,
    );
    messages.putIfAbsent(conversationId, () => []).add(message);
    eventController.add(
      ChatEvent(type: ChatEventType.newMessage, message: message),
    );
  }

  @override
  Future<void> resetLocalData() async {
    resetCalls += 1;
    conversations.clear();
    messages.clear();
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await eventController.close();
  }
}
