import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_auth_configuration.dart';
import 'package:oppo_background_gps_demo/features/chat/services/chat_auth_api.dart';
import 'package:oppo_background_gps_demo/features/chat/services/chat_auth_coordinator.dart';
import 'package:oppo_background_gps_demo/features/chat/services/cloud_chat_auth_api.dart';

import '../fake_chat_auth.dart';

void main() {
  test('cloud auth parses a valid session over HTTPS', () async {
    late http.Request captured;
    final api = CloudChatAuthApi(
      configuration: const ChatAuthConfiguration(
        baseUrl: 'https://auth.example.test/',
      ),
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'userId': 'driver_one',
            'userSig': 'usersig_abcdefghijklmnopqrstuvwxyz_1234567890',
            'refreshToken': 'refresh_abcdefghijklmnopqrstuvwxyz_1234567890',
            'expiresAt': '2026-07-28T00:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final session = await api.login(userId: ' driver_one ', pin: '2468');

    expect(captured.url.path, '/v1/auth/login');
    expect(captured.headers['content-type'], 'application/json');
    expect(jsonDecode(captured.body), {'userId': 'driver_one', 'pin': '2468'});
    expect(session.userId, 'driver_one');
    expect(session.refreshToken, startsWith('refresh_'));
    api.close();
  });

  test('cloud auth rejects insecure endpoint configuration', () async {
    final api = CloudChatAuthApi(
      configuration: const ChatAuthConfiguration(
        baseUrl: 'http://auth.example.test/',
      ),
      client: MockClient(
        (_) async => throw StateError('HTTP client must not be called'),
      ),
    );

    await expectLater(
      api.login(userId: 'driver_one', pin: '2468'),
      throwsA(
        isA<ChatAuthException>().having(
          (error) => error.code,
          'code',
          'configuration_missing',
        ),
      ),
    );
    api.close();
  });

  test('cloud auth maps an expired refresh token to safe state', () async {
    final api = CloudChatAuthApi(
      configuration: const ChatAuthConfiguration(
        baseUrl: 'https://auth.example.test/',
      ),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {
              'code': 'session_expired',
              'message': 'This saved login has expired. Sign in again.',
            },
          }),
          401,
        ),
      ),
    );

    await expectLater(
      api.refresh(refreshToken: 'expired_refresh_token_value'),
      throwsA(
        isA<ChatAuthException>()
            .having((error) => error.sessionExpired, 'sessionExpired', isTrue)
            .having(
              (error) => error.message,
              'message',
              isNot(contains('expired_refresh_token_value')),
            ),
      ),
    );
    api.close();
  });

  test('coordinator rotates tokens and clears an expired session', () async {
    final api = FakeChatAuthApi();
    final store = MemoryChatRefreshTokenStore('old_refresh_token');
    final coordinator = ChatAuthCoordinator(api, store);

    await coordinator.restore();
    expect(store.token, startsWith('rotated_refresh_'));

    api.refreshError = const ChatAuthException(
      'Sign in again.',
      code: 'session_expired',
      sessionExpired: true,
    );
    await expectLater(coordinator.restore(), throwsA(isA<ChatAuthException>()));
    expect(store.token, isNull);
    coordinator.dispose();
  });
}
