import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_background_gps_demo/features/chat/controllers/chat_controller.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_configuration.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_connection_state.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_conversation.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_user.dart';
import 'package:oppo_background_gps_demo/features/chat/services/chat_call_service.dart';
import 'package:oppo_background_gps_demo/features/chat/services/chat_service.dart';

import '../fake_chat_call_service.dart';
import '../fake_chat_service.dart';

void main() {
  test(
    'starts in Local Demo without SDKAppID and loads conversations',
    () async {
      final local = FakeChatService(
        providerType: ChatProviderType.localDemo,
        conversations: const [
          ChatConversation(
            id: 'local_dispatch',
            participant: ChatUser(userId: 'dispatch'),
            providerType: ChatProviderType.localDemo,
            unreadCount: 2,
          ),
        ],
      );
      final tencent = FakeChatService(
        providerType: ChatProviderType.tencentCloud,
        isConfigured: false,
      );
      final controller = ChatController(
        localService: local,
        tencentService: tencent,
      );

      await controller.initialize();

      expect(controller.providerType, ChatProviderType.localDemo);
      expect(controller.isTencentConfigured, isFalse);
      expect(controller.conversationCount, 1);
      expect(controller.totalUnreadCount, 2);
      expect(tencent.initializeCalls, 0);
      controller.dispose();
    },
  );

  test('Tencent initialization failure leaves Local Demo active', () async {
    final local = FakeChatService(providerType: ChatProviderType.localDemo);
    final tencent = FakeChatService(
      providerType: ChatProviderType.tencentCloud,
      initializeError: const ChatServiceException('Safe init failure', code: 7),
    );
    final controller = ChatController(
      configuration: const ChatConfiguration(sdkAppId: 1),
      localService: local,
      tencentService: tencent,
    );
    await controller.initialize();

    final initialized = await controller.initializeTencent();

    expect(initialized, isFalse);
    expect(controller.providerType, ChatProviderType.localDemo);
    expect(
      controller.sdkInitializationState,
      ChatSdkInitializationState.failed,
    );
    expect(controller.lastErrorSummary, 'Safe init failure');
    controller.dispose();
  });

  test('login validation and expired UserSig are handled safely', () async {
    final local = FakeChatService(providerType: ChatProviderType.localDemo);
    final tencent = FakeChatService(
      providerType: ChatProviderType.tencentCloud,
      loginResult: const ChatLoginResult(
        success: false,
        errorCode: 6206,
        message: 'expired',
      ),
    );
    final controller = ChatController(
      configuration: const ChatConfiguration(sdkAppId: 1),
      localService: local,
      tencentService: tencent,
    );
    await controller.initialize();

    final blank = await controller.loginTencent(userId: ' ', userSig: ' ');
    final expired = await controller.loginTencent(
      userId: 'user_a',
      userSig: 'temporary-value',
    );

    expect(blank.success, isFalse);
    expect(expired.isExpiredCredential, isTrue);
    expect(
      controller.authenticationState,
      ChatAuthenticationState.authenticationExpired,
    );
    expect(controller.userSigState, ChatUserSigState.expired);
    expect(controller.lastErrorSummary, contains('Request a new UserSig'));
    controller.dispose();
  });

  test(
    'network, unread, kicked offline, send, read and dispose events work',
    () async {
      final local = FakeChatService(providerType: ChatProviderType.localDemo);
      final tencent = FakeChatService(
        providerType: ChatProviderType.tencentCloud,
      );
      final controller = ChatController(
        configuration: const ChatConfiguration(sdkAppId: 1),
        localService: local,
        tencentService: tencent,
      );
      await controller.initialize();
      expect(
        (await controller.loginTencent(
          userId: 'user_a',
          userSig: 'temporary-value',
        )).success,
        isTrue,
      );
      expect(tencent.initializeCalls, 1);

      tencent.eventController.add(
        const ChatEvent(
          type: ChatEventType.networkChanged,
          networkState: ChatNetworkState.connected,
        ),
      );
      tencent.eventController.add(
        const ChatEvent(
          type: ChatEventType.unreadCountChanged,
          totalUnreadCount: 4,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.networkState, ChatNetworkState.connected);
      expect(controller.totalUnreadCount, 4);

      await controller.sendTextMessage(
        recipientUserId: 'user_b',
        text: 'hello',
      );
      await controller.markConversationAsRead('tencentCloud_user_b');
      expect(tencent.sendCalls, 1);
      expect(tencent.markReadCalls, 1);

      tencent.eventController.add(
        const ChatEvent(type: ChatEventType.kickedOffline),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.authenticationState,
        ChatAuthenticationState.kickedOffline,
      );
      expect(controller.loggedInUserId, isNull);

      controller.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(local.disposeCalls, 1);
      expect(tencent.disposeCalls, 1);
    },
  );

  test(
    'local conversation, send, simulation, pagination, read and reset work',
    () async {
      final local = FakeChatService(providerType: ChatProviderType.localDemo);
      final tencent = FakeChatService(
        providerType: ChatProviderType.tencentCloud,
      );
      final controller = ChatController(
        localService: local,
        tencentService: tencent,
      );
      await controller.initialize();
      final conversation = await controller.createLocalConversation(
        recipientUserId: 'dispatch',
        displayName: 'Dispatch Coordinator',
      );
      await controller.sendTextMessage(
        recipientUserId: 'dispatch',
        text: 'Local only',
      );
      await controller.simulateIncomingMessage(conversation.id);
      await Future<void>.delayed(Duration.zero);
      final history = await controller.getMessages(
        conversationId: conversation.id,
      );
      expect(history, hasLength(2));
      expect(history.first.text, 'Local only');

      await controller.markConversationAsRead(conversation.id);
      expect(local.markReadCalls, 1);
      await controller.resetLocalDemoData();
      expect(local.resetCalls, 1);
      expect(controller.conversationCount, 0);
      controller.dispose();
    },
  );

  test(
    'audio and video calls share the secure Tencent login session',
    () async {
      final local = FakeChatService(providerType: ChatProviderType.localDemo);
      final tencent = FakeChatService(
        providerType: ChatProviderType.tencentCloud,
      );
      final calls = FakeChatCallService();
      final controller = ChatController(
        configuration: const ChatConfiguration(sdkAppId: 20045530),
        localService: local,
        tencentService: tencent,
        callService: calls,
      );
      await controller.initialize();

      final login = await controller.loginTencent(
        userId: 'malikabdulfarhan',
        userSig: 'temporary-value',
      );
      final audio = await controller.startAudioCall('malikabdulsalam');
      final video = await controller.startVideoCall('malikabdulsalam');

      expect(login.success, isTrue);
      expect(calls.loginCalls, 1);
      expect(calls.sdkAppId, 20045530);
      expect(calls.loginUserId, 'malikabdulfarhan');
      expect(controller.isCallingAvailable, isTrue);
      expect(audio.success, isTrue);
      expect(video.success, isTrue);
      expect(calls.startCalls, 2);
      expect(calls.recipientUserId, 'malikabdulsalam');
      expect(calls.mediaType, ChatCallMediaType.video);

      await controller.logoutTencent();
      expect(calls.logoutCalls, 1);
      expect(tencent.loggedIn, isFalse);
      controller.dispose();
    },
  );

  test('call initialization failure does not block text chat', () async {
    final calls = FakeChatCallService(
      loginResult: const ChatCallResult(
        success: false,
        errorCode: -1001,
        message: 'Call trial is inactive.',
      ),
    );
    final controller = ChatController(
      configuration: const ChatConfiguration(sdkAppId: 1),
      localService: FakeChatService(providerType: ChatProviderType.localDemo),
      tencentService: FakeChatService(
        providerType: ChatProviderType.tencentCloud,
      ),
      callService: calls,
    );
    await controller.initialize();

    final login = await controller.loginTencent(
      userId: 'user_a',
      userSig: 'temporary-value',
    );
    final call = await controller.startAudioCall('user_b');

    expect(login.success, isTrue);
    expect(controller.isTencentLoggedIn, isTrue);
    expect(controller.isCallingAvailable, isFalse);
    expect(call.success, isFalse);
    expect(call.message, 'Call trial is inactive.');
    controller.dispose();
  });
}
