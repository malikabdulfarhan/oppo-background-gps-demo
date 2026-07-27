import 'package:tencent_calls_uikit/tencent_calls_uikit.dart';

import 'chat_call_service.dart';

class TencentCallService implements ChatCallService {
  bool _loggedIn = false;
  bool _disposed = false;
  String? _userId;

  @override
  bool get isSupported => true;

  @override
  bool get isLoggedIn => _loggedIn;

  @override
  Future<ChatCallResult> login({
    required int sdkAppId,
    required String userId,
    required String userSig,
  }) async {
    if (_disposed) {
      return const ChatCallResult(
        success: false,
        message: 'Audio/video calling is unavailable.',
      );
    }
    final cleanUserId = userId.trim();
    final cleanUserSig = userSig.trim();
    if (sdkAppId <= 0 || cleanUserId.isEmpty || cleanUserSig.isEmpty) {
      return const ChatCallResult(
        success: false,
        message: 'Audio/video calling authentication is incomplete.',
      );
    }
    if (_loggedIn && _userId == cleanUserId) {
      return const ChatCallResult.success();
    }

    try {
      if (_loggedIn) await logout();
      final result = await TUICallKit.instance.login(
        sdkAppId,
        cleanUserId,
        cleanUserSig,
      );
      if (!result.isSuccess) {
        return _failure(result.errorCode);
      }
      _loggedIn = true;
      _userId = cleanUserId;
      TUICallKit.instance.enableIncomingBanner(false);
      await TUICallKit.instance.enableFloatWindow(false);
      return const ChatCallResult.success();
    } on Object {
      _loggedIn = false;
      _userId = null;
      return const ChatCallResult(
        success: false,
        message: 'Tencent Call could not initialize.',
      );
    }
  }

  @override
  Future<void> logout() async {
    if (!_loggedIn) return;
    try {
      await TUICallKit.instance.logout();
    } finally {
      _loggedIn = false;
      _userId = null;
    }
  }

  @override
  Future<ChatCallResult> startCall({
    required String recipientUserId,
    required ChatCallMediaType mediaType,
  }) async {
    final recipient = recipientUserId.trim();
    if (!_loggedIn) {
      return const ChatCallResult(
        success: false,
        message: 'Sign in to Tencent Chat before starting a call.',
      );
    }
    if (recipient.isEmpty || recipient == _userId) {
      return const ChatCallResult(
        success: false,
        message: 'Choose another Tencent user to call.',
      );
    }

    try {
      final result = await TUICallKit.instance.calls(
        [recipient],
        mediaType == ChatCallMediaType.audio
            ? CallMediaType.audio
            : CallMediaType.video,
      );
      return result.isSuccess
          ? const ChatCallResult.success()
          : _failure(result.errorCode);
    } on Object {
      return const ChatCallResult(
        success: false,
        message: 'Unable to start the call. Please try again.',
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await logout();
  }

  ChatCallResult _failure(int code) => ChatCallResult(
    success: false,
    errorCode: code,
    message: switch (code) {
      -1001 =>
        'Tencent Call is not activated, or its trial has expired. '
            'Activate Call for this SDKAppID in the Tencent console.',
      -1002 => 'The active Tencent package does not support this call.',
      -1101 =>
        'Camera or microphone permission was denied. Enable it in app settings.',
      -1202 => 'The selected call recipient is invalid.',
      -1203 || -1204 => 'Another call action is already in progress.',
      -1406 => 'Tencent could not send the call invitation.',
      6014 => 'The Tencent Chat session is no longer signed in.',
      6206 => 'The Tencent login has expired. Sign in again.',
      _ => 'Tencent Call failed (code $code).',
    },
  );
}
