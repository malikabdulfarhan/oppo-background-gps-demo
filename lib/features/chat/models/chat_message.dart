import 'chat_configuration.dart';

enum ChatMessageDeliveryState {
  sending,
  sent,
  failed,
  localOnly;

  String get label => switch (this) {
    sending => 'Sending',
    sent => 'Sent',
    failed => 'Failed',
    localOnly => 'Local demonstration only',
  };
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.recipientUserId,
    required this.text,
    required this.timestamp,
    required this.isMine,
    required this.providerType,
    required this.deliveryState,
    this.isGpsStatusShare = false,
  });

  final String id;
  final String conversationId;
  final String senderUserId;
  final String recipientUserId;
  final String text;
  final DateTime timestamp;
  final bool isMine;
  final ChatProviderType providerType;
  final ChatMessageDeliveryState deliveryState;
  final bool isGpsStatusShare;

  ChatMessage copyWith({ChatMessageDeliveryState? deliveryState}) =>
      ChatMessage(
        id: id,
        conversationId: conversationId,
        senderUserId: senderUserId,
        recipientUserId: recipientUserId,
        text: text,
        timestamp: timestamp,
        isMine: isMine,
        providerType: providerType,
        deliveryState: deliveryState ?? this.deliveryState,
        isGpsStatusShare: isGpsStatusShare,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderUserId': senderUserId,
    'recipientUserId': recipientUserId,
    'text': text,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'isMine': isMine,
    'deliveryState': deliveryState.name,
    'isGpsStatusShare': isGpsStatusShare,
  };

  static ChatMessage? fromJson(Object? value) {
    if (value is! Map) return null;
    final map = Map<Object?, Object?>.from(value);
    final timestamp = DateTime.tryParse('${map['timestamp'] ?? ''}');
    if (timestamp == null) return null;
    final delivery = ChatMessageDeliveryState.values.firstWhere(
      (item) => item.name == map['deliveryState'],
      orElse: () => ChatMessageDeliveryState.localOnly,
    );
    return ChatMessage(
      id: '${map['id'] ?? ''}',
      conversationId: '${map['conversationId'] ?? ''}',
      senderUserId: '${map['senderUserId'] ?? ''}',
      recipientUserId: '${map['recipientUserId'] ?? ''}',
      text: '${map['text'] ?? ''}',
      timestamp: timestamp,
      isMine: map['isMine'] == true,
      providerType: ChatProviderType.localDemo,
      deliveryState: delivery,
      isGpsStatusShare: map['isGpsStatusShare'] == true,
    );
  }
}
