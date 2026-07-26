import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_configuration.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_message.dart';
import 'package:oppo_background_gps_demo/features/chat/services/local_demo_chat_service.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'oppo_chat_demo_test_',
    );
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('seeds neutral conversations without Tencent credentials', () async {
    final service = LocalDemoChatService(
      directoryProvider: () async => temporaryDirectory,
    );
    await service.initialize();

    final conversations = await service.getConversations();

    expect(conversations, hasLength(3));
    expect(
      conversations.map((item) => item.participant.title),
      containsAll([
        'Dispatch Coordinator',
        'Field Operations',
        'Technical Support',
      ]),
    );
    expect(
      conversations.every(
        (item) => item.providerType == ChatProviderType.localDemo,
      ),
      isTrue,
    );
    await service.dispose();
  });

  test('persists local-only send and explicit incoming simulation', () async {
    final service = LocalDemoChatService(
      directoryProvider: () async => temporaryDirectory,
    );
    await service.initialize();
    final conversation = (await service.getConversations()).first;

    final sent = await service.sendTextMessage(
      recipientUserId: conversation.participant.userId,
      text: 'Local test',
    );
    await service.simulateIncomingMessage(conversation.id);
    final messages = await service.getMessages(conversationId: conversation.id);

    expect(sent.deliveryState, ChatMessageDeliveryState.localOnly);
    expect(messages, hasLength(greaterThanOrEqualTo(3)));
    expect(messages.where((item) => !item.isMine), isNotEmpty);
    await service.dispose();

    final restored = LocalDemoChatService(
      directoryProvider: () async => temporaryDirectory,
    );
    await restored.initialize();
    expect(
      await restored.getMessages(conversationId: conversation.id),
      isNotEmpty,
    );
    await restored.dispose();
  });

  test('mark read and reset restore seeded state', () async {
    final service = LocalDemoChatService(
      directoryProvider: () async => temporaryDirectory,
    );
    await service.initialize();
    final conversation = (await service.getConversations()).first;
    await service.simulateIncomingMessage(conversation.id);
    await service.markConversationAsRead(conversation.id);
    expect(
      (await service.getConversations())
          .firstWhere((item) => item.id == conversation.id)
          .unreadCount,
      0,
    );

    await service.resetLocalData();
    expect(await service.getConversations(), hasLength(3));
    await service.dispose();
  });
}
