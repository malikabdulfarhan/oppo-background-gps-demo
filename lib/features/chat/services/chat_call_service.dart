enum ChatCallMediaType { audio, video }

class ChatCallResult {
  const ChatCallResult({required this.success, this.errorCode, this.message});

  const ChatCallResult.success()
    : success = true,
      errorCode = null,
      message = null;

  final bool success;
  final int? errorCode;
  final String? message;
}

abstract interface class ChatCallService {
  bool get isSupported;

  bool get isLoggedIn;

  Future<ChatCallResult> login({
    required int sdkAppId,
    required String userId,
    required String userSig,
  });

  Future<void> logout();

  Future<ChatCallResult> startCall({
    required String recipientUserId,
    required ChatCallMediaType mediaType,
  });

  Future<void> dispose();
}

class DisabledChatCallService implements ChatCallService {
  const DisabledChatCallService();

  @override
  bool get isSupported => false;

  @override
  bool get isLoggedIn => false;

  @override
  Future<ChatCallResult> login({
    required int sdkAppId,
    required String userId,
    required String userSig,
  }) async => const ChatCallResult(
    success: false,
    message: 'Audio/video calling is not available in this build.',
  );

  @override
  Future<void> logout() async {}

  @override
  Future<ChatCallResult> startCall({
    required String recipientUserId,
    required ChatCallMediaType mediaType,
  }) async => const ChatCallResult(
    success: false,
    message: 'Audio/video calling is not available in this build.',
  );

  @override
  Future<void> dispose() async {}
}
