import '../models/chat_auth_session.dart';

class ChatAuthException implements Exception {
  const ChatAuthException(
    this.message, {
    this.code,
    this.sessionExpired = false,
  });

  final String message;
  final String? code;
  final bool sessionExpired;

  @override
  String toString() => message;
}

abstract interface class ChatAuthApi {
  Future<ChatAuthSession> login({required String userId, required String pin});

  Future<ChatAuthSession> refresh({required String refreshToken});

  Future<void> logout({required String refreshToken});

  void close();
}

abstract interface class ChatRefreshTokenStore {
  Future<String?> read();

  Future<void> write(String refreshToken);

  Future<void> clear();
}
