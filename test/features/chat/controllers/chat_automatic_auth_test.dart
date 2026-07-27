import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_background_gps_demo/features/chat/controllers/chat_controller.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_automatic_auth_state.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_configuration.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_connection_state.dart';
import 'package:oppo_background_gps_demo/features/chat/services/chat_auth_api.dart';
import 'package:oppo_background_gps_demo/features/chat/services/chat_auth_coordinator.dart';
import 'package:oppo_background_gps_demo/features/chat/services/chat_service.dart';

import '../fake_chat_auth.dart';
import '../fake_chat_service.dart';

void main() {
  test('restores a saved login automatically during initialization', () async {
    final api = FakeChatAuthApi();
    final store = MemoryChatRefreshTokenStore('saved_refresh_token_value');
    final tencent = FakeChatService(
      providerType: ChatProviderType.tencentCloud,
    );
    final controller = ChatController(
      configuration: const ChatConfiguration(sdkAppId: 12345),
      localService: FakeChatService(providerType: ChatProviderType.localDemo),
      tencentService: tencent,
      authCoordinator: ChatAuthCoordinator(api, store),
    );

    await controller.initialize();

    expect(api.refreshCalls, 1);
    expect(tencent.loginUserId, 'driver_one');
    expect(tencent.loginUserSig, startsWith('refreshed_usersig_'));
    expect(controller.providerType, ChatProviderType.tencentCloud);
    expect(controller.isTencentLoggedIn, isTrue);
    expect(controller.automaticAuthState, ChatAutomaticAuthState.authenticated);
    expect(controller.hasSavedChatSession, isTrue);
    expect(store.token, startsWith('rotated_refresh_'));
    controller.dispose();
  });

  test(
    'secure login exchanges PIN once and stores only refresh token',
    () async {
      final api = FakeChatAuthApi();
      final store = MemoryChatRefreshTokenStore();
      final controller = ChatController(
        configuration: const ChatConfiguration(sdkAppId: 12345),
        localService: FakeChatService(providerType: ChatProviderType.localDemo),
        tencentService: FakeChatService(
          providerType: ChatProviderType.tencentCloud,
        ),
        authCoordinator: ChatAuthCoordinator(api, store),
      );
      await controller.initialize();

      final result = await controller.loginWithBackend(
        userId: ' driver_one ',
        pin: '2468',
      );

      expect(result.success, isTrue);
      expect(api.receivedUserId, 'driver_one');
      expect(api.receivedPin, '2468');
      expect(store.token, startsWith('refresh_'));
      expect(store.token, isNot(contains('2468')));
      expect(controller.hasSavedChatSession, isTrue);
      controller.dispose();
    },
  );

  test('expired Tencent credential is refreshed once without a PIN', () async {
    final api = FakeChatAuthApi();
    final store = MemoryChatRefreshTokenStore();
    final tencent = FakeChatService(
      providerType: ChatProviderType.tencentCloud,
    );
    final controller = ChatController(
      configuration: const ChatConfiguration(sdkAppId: 12345),
      localService: FakeChatService(providerType: ChatProviderType.localDemo),
      tencentService: tencent,
      authCoordinator: ChatAuthCoordinator(api, store),
    );
    await controller.initialize();
    await controller.loginWithBackend(userId: 'driver_one', pin: '2468');

    tencent.eventController.add(
      const ChatEvent(type: ChatEventType.authenticationExpired),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(api.refreshCalls, 1);
    expect(api.loginCalls, 1);
    expect(controller.automaticAuthState, ChatAutomaticAuthState.authenticated);
    expect(controller.authenticationState, ChatAuthenticationState.loggedIn);
    controller.dispose();
  });

  test('expired backend session is cleared and requires sign-in', () async {
    final api = FakeChatAuthApi()
      ..refreshError = const ChatAuthException(
        'This saved login has expired. Sign in again.',
        code: 'session_expired',
        sessionExpired: true,
      );
    final store = MemoryChatRefreshTokenStore('expired_refresh_token');
    final controller = ChatController(
      configuration: const ChatConfiguration(sdkAppId: 12345),
      localService: FakeChatService(providerType: ChatProviderType.localDemo),
      tencentService: FakeChatService(
        providerType: ChatProviderType.tencentCloud,
      ),
      authCoordinator: ChatAuthCoordinator(api, store),
    );

    await controller.initialize();

    expect(store.token, isNull);
    expect(controller.hasSavedChatSession, isFalse);
    expect(
      controller.automaticAuthState,
      ChatAutomaticAuthState.sessionExpired,
    );
    expect(controller.providerType, ChatProviderType.localDemo);
    controller.dispose();
  });

  test('logout revokes and removes the saved automatic login', () async {
    final api = FakeChatAuthApi();
    final store = MemoryChatRefreshTokenStore();
    final controller = ChatController(
      configuration: const ChatConfiguration(sdkAppId: 12345),
      localService: FakeChatService(providerType: ChatProviderType.localDemo),
      tencentService: FakeChatService(
        providerType: ChatProviderType.tencentCloud,
      ),
      authCoordinator: ChatAuthCoordinator(api, store),
    );
    await controller.initialize();
    await controller.loginWithBackend(userId: 'driver_one', pin: '2468');

    await controller.logoutTencent();

    expect(api.logoutCalls, 1);
    expect(store.token, isNull);
    expect(controller.hasSavedChatSession, isFalse);
    expect(controller.providerType, ChatProviderType.localDemo);
    controller.dispose();
    expect(api.closed, isTrue);
  });

  test(
    'kicked-offline event clears saved login to prevent a retry loop',
    () async {
      final api = FakeChatAuthApi();
      final store = MemoryChatRefreshTokenStore();
      final tencent = FakeChatService(
        providerType: ChatProviderType.tencentCloud,
      );
      final controller = ChatController(
        configuration: const ChatConfiguration(sdkAppId: 12345),
        localService: FakeChatService(providerType: ChatProviderType.localDemo),
        tencentService: tencent,
        authCoordinator: ChatAuthCoordinator(api, store),
      );
      await controller.initialize();
      await controller.loginWithBackend(userId: 'driver_one', pin: '2468');

      tencent.eventController.add(
        const ChatEvent(type: ChatEventType.kickedOffline),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.hasSavedChatSession, isFalse);
      expect(store.token, isNull);
      expect(
        controller.automaticAuthState,
        ChatAutomaticAuthState.sessionExpired,
      );
      controller.dispose();
    },
  );

  test(
    'safe backend errors do not expose internal exception details',
    () async {
      final api = FakeChatAuthApi()
        ..loginError = const ChatAuthException(
          'Invalid User ID or PIN.',
          code: 'invalid_credentials',
        );
      final controller = ChatController(
        configuration: const ChatConfiguration(sdkAppId: 12345),
        localService: FakeChatService(providerType: ChatProviderType.localDemo),
        tencentService: FakeChatService(
          providerType: ChatProviderType.tencentCloud,
        ),
        authCoordinator: ChatAuthCoordinator(
          api,
          MemoryChatRefreshTokenStore(),
        ),
      );
      await controller.initialize();

      final result = await controller.loginWithBackend(
        userId: 'driver_one',
        pin: 'wrong',
      );

      expect(result.success, isFalse);
      expect(result.message, 'Invalid User ID or PIN.');
      expect(controller.providerType, ChatProviderType.localDemo);
      expect(controller.automaticAuthState, ChatAutomaticAuthState.failed);
      controller.dispose();
    },
  );
}
