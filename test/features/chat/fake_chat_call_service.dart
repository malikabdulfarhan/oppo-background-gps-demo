import 'package:oppo_background_gps_demo/features/chat/services/chat_call_service.dart';

class FakeChatCallService implements ChatCallService {
  FakeChatCallService({
    this.loginResult = const ChatCallResult.success(),
    this.startResult = const ChatCallResult.success(),
    this.isSupported = true,
  });

  ChatCallResult loginResult;
  ChatCallResult startResult;

  @override
  final bool isSupported;

  @override
  bool isLoggedIn = false;

  int loginCalls = 0;
  int logoutCalls = 0;
  int startCalls = 0;
  int disposeCalls = 0;
  int? sdkAppId;
  String? loginUserId;
  String? loginUserSig;
  String? recipientUserId;
  ChatCallMediaType? mediaType;

  @override
  Future<ChatCallResult> login({
    required int sdkAppId,
    required String userId,
    required String userSig,
  }) async {
    loginCalls += 1;
    this.sdkAppId = sdkAppId;
    loginUserId = userId;
    loginUserSig = userSig;
    isLoggedIn = loginResult.success;
    return loginResult;
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    isLoggedIn = false;
  }

  @override
  Future<ChatCallResult> startCall({
    required String recipientUserId,
    required ChatCallMediaType mediaType,
  }) async {
    startCalls += 1;
    this.recipientUserId = recipientUserId;
    this.mediaType = mediaType;
    return startResult;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    isLoggedIn = false;
  }
}
