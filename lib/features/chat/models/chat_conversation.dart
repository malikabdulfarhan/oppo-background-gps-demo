import 'chat_configuration.dart';
import 'chat_user.dart';

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.participant,
    required this.providerType,
    this.lastMessagePreview,
    this.lastMessageTimestamp,
    this.unreadCount = 0,
    this.hasSendingMessage = false,
    this.hasFailedMessage = false,
  });

  final String id;
  final ChatUser participant;
  final ChatProviderType providerType;
  final String? lastMessagePreview;
  final DateTime? lastMessageTimestamp;
  final int unreadCount;
  final bool hasSendingMessage;
  final bool hasFailedMessage;

  ChatConversation copyWith({
    String? lastMessagePreview,
    DateTime? lastMessageTimestamp,
    int? unreadCount,
    bool? hasSendingMessage,
    bool? hasFailedMessage,
  }) => ChatConversation(
    id: id,
    participant: participant,
    providerType: providerType,
    lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
    lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
    unreadCount: unreadCount ?? this.unreadCount,
    hasSendingMessage: hasSendingMessage ?? this.hasSendingMessage,
    hasFailedMessage: hasFailedMessage ?? this.hasFailedMessage,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'participantUserId': participant.userId,
    'participantDisplayName': participant.displayName,
    'lastMessagePreview': lastMessagePreview,
    'lastMessageTimestamp': lastMessageTimestamp?.toUtc().toIso8601String(),
    'unreadCount': unreadCount,
  };

  static ChatConversation? fromJson(Object? value) {
    if (value is! Map) return null;
    final map = Map<Object?, Object?>.from(value);
    final id = '${map['id'] ?? ''}'.trim();
    final userId = '${map['participantUserId'] ?? ''}'.trim();
    if (id.isEmpty || userId.isEmpty) return null;
    return ChatConversation(
      id: id,
      participant: ChatUser(
        userId: userId,
        displayName: map['participantDisplayName'] as String?,
      ),
      providerType: ChatProviderType.localDemo,
      lastMessagePreview: map['lastMessagePreview'] as String?,
      lastMessageTimestamp: DateTime.tryParse(
        '${map['lastMessageTimestamp'] ?? ''}',
      ),
      unreadCount: (map['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}
