import '../models/chat_configuration.dart';
import '../models/chat_connection_state.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';

class ChatLoginResult {
  const ChatLoginResult({required this.success, this.errorCode, this.message});

  final bool success;
  final int? errorCode;
  final String? message;

  bool get isExpiredCredential => errorCode == 6206 || errorCode == 70001;
}

enum ChatEventType {
  initialized,
  newMessage,
  conversationsChanged,
  unreadCountChanged,
  networkChanged,
  authenticationExpired,
  kickedOffline,
  error,
}

class ChatEvent {
  const ChatEvent({
    required this.type,
    this.message,
    this.networkState,
    this.totalUnreadCount,
    this.errorCode,
    this.errorSummary,
  });

  final ChatEventType type;
  final ChatMessage? message;
  final ChatNetworkState? networkState;
  final int? totalUnreadCount;
  final int? errorCode;
  final String? errorSummary;
}

class ChatServiceException implements Exception {
  const ChatServiceException(this.summary, {this.code});

  final String summary;
  final int? code;

  @override
  String toString() => summary;
}

abstract interface class ChatService {
  ChatProviderType get providerType;

  bool get isConfigured;

  String? get sdkVersion;

  bool get advancedListenerRegistered;

  Future<void> initialize();

  Future<ChatLoginResult> login({
    required String userId,
    required String userSig,
  });

  Future<void> logout();

  Future<List<ChatConversation>> getConversations();

  Future<List<ChatMessage>> getMessages({
    required String conversationId,
    String? cursor,
  });

  Future<ChatMessage> sendTextMessage({
    required String recipientUserId,
    required String text,
  });

  Future<void> markConversationAsRead(String conversationId);

  Stream<ChatEvent> get events;

  Future<void> dispose();
}

abstract interface class LocalDemoChatOperations {
  Future<ChatConversation> createConversation({
    required String recipientUserId,
    String? displayName,
  });

  Future<void> simulateIncomingMessage(String conversationId);

  Future<void> resetLocalData();
}

abstract interface class ExternallyAuthenticatedChatService {
  void resetAfterExternalLogout();
}
