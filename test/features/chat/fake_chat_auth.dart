import 'package:oppo_background_gps_demo/features/chat/models/chat_auth_session.dart';
import 'package:oppo_background_gps_demo/features/chat/services/chat_auth_api.dart';

ChatAuthSession fakeChatSession({
  String userId = 'driver_one',
  String userSig = 'usersig_abcdefghijklmnopqrstuvwxyz_1234567890',
  String refreshToken = 'refresh_abcdefghijklmnopqrstuvwxyz_1234567890',
}) => ChatAuthSession(
  userId: userId,
  userSig: userSig,
  refreshToken: refreshToken,
  expiresAt: DateTime.utc(2026, 7, 28),
);

class FakeChatAuthApi implements ChatAuthApi {
  ChatAuthSession loginSession = fakeChatSession();
  ChatAuthSession refreshSession = fakeChatSession(
    userSig: 'refreshed_usersig_abcdefghijklmnopqrstuvwxyz_1234567890',
    refreshToken: 'rotated_refresh_abcdefghijklmnopqrstuvwxyz_1234567890',
  );
  ChatAuthException? loginError;
  ChatAuthException? refreshError;
  int loginCalls = 0;
  int refreshCalls = 0;
  int logoutCalls = 0;
  bool closed = false;
  String? receivedUserId;
  String? receivedPin;
  String? receivedRefreshToken;

  @override
  Future<ChatAuthSession> login({
    required String userId,
    required String pin,
  }) async {
    loginCalls += 1;
    receivedUserId = userId;
    receivedPin = pin;
    if (loginError case final error?) throw error;
    return loginSession;
  }

  @override
  Future<ChatAuthSession> refresh({required String refreshToken}) async {
    refreshCalls += 1;
    receivedRefreshToken = refreshToken;
    if (refreshError case final error?) throw error;
    return refreshSession;
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    logoutCalls += 1;
    receivedRefreshToken = refreshToken;
  }

  @override
  void close() => closed = true;
}

class MemoryChatRefreshTokenStore implements ChatRefreshTokenStore {
  MemoryChatRefreshTokenStore([this.token]);

  String? token;
  int writes = 0;
  int clears = 0;

  @override
  Future<void> clear() async {
    clears += 1;
    token = null;
  }

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String refreshToken) async {
    writes += 1;
    token = refreshToken;
  }
}
