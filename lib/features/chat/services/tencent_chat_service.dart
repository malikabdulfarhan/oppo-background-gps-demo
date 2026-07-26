import 'dart:async';

import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimConversationListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

import '../models/chat_configuration.dart';
import '../models/chat_connection_state.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import 'chat_service.dart';

class TencentChatService implements ChatService {
  TencentChatService({required this.sdkAppId});

  final int sdkAppId;
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();
  final _manager = TencentImSDKPlugin.v2TIMManager;

  V2TimSDKListener? _sdkListener;
  V2TimAdvancedMsgListener? _messageListener;
  V2TimConversationListener? _conversationListener;
  bool _initialized = false;
  bool _initializing = false;
  bool _listenersRegistered = false;
  bool _disposed = false;
  String? _sdkVersion;

  @override
  ChatProviderType get providerType => ChatProviderType.tencentCloud;

  @override
  bool get isConfigured => sdkAppId > 0;

  @override
  String? get sdkVersion => _sdkVersion;

  @override
  bool get advancedListenerRegistered => _listenersRegistered;

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    if (_initialized || _initializing || _disposed) return;
    if (!isConfigured) {
      throw const ChatServiceException('Tencent SDKAppID is not configured.');
    }
    _initializing = true;
    _sdkListener ??= V2TimSDKListener(
      onConnecting: () => _emit(
        const ChatEvent(
          type: ChatEventType.networkChanged,
          networkState: ChatNetworkState.connecting,
        ),
      ),
      onConnectSuccess: () => _emit(
        const ChatEvent(
          type: ChatEventType.networkChanged,
          networkState: ChatNetworkState.connected,
        ),
      ),
      onConnectFailed: (code, error) {
        _emit(
          ChatEvent(
            type: ChatEventType.networkChanged,
            networkState: ChatNetworkState.disconnected,
            errorCode: code,
            errorSummary: _safeSummary(error),
          ),
        );
      },
      onUserSigExpired: () =>
          _emit(const ChatEvent(type: ChatEventType.authenticationExpired)),
      onKickedOffline: () =>
          _emit(const ChatEvent(type: ChatEventType.kickedOffline)),
    );
    try {
      final result = await _manager.initSDK(
        sdkAppID: sdkAppId,
        listener: _sdkListener,
        showImLog: false,
      );
      if (result.code != 0 || result.data != true) {
        throw ChatServiceException(
          _safeSummary(result.desc),
          code: result.code,
        );
      }
      final version = await _manager.getVersion();
      if (version.code == 0) _sdkVersion = version.data;
      await _registerListeners();
      _initialized = true;
      _emit(const ChatEvent(type: ChatEventType.initialized));
    } on ChatServiceException {
      rethrow;
    } on Object {
      throw const ChatServiceException(
        'Tencent Chat SDK could not initialize.',
      );
    } finally {
      _initializing = false;
    }
  }

  Future<void> _registerListeners() async {
    if (_listenersRegistered) return;
    _messageListener = V2TimAdvancedMsgListener(
      onRecvNewMessage: (message) {
        final mapped = _mapMessage(message);
        if (mapped != null) {
          _emit(ChatEvent(type: ChatEventType.newMessage, message: mapped));
        }
      },
    );
    _conversationListener = V2TimConversationListener(
      onNewConversation: (_) =>
          _emit(const ChatEvent(type: ChatEventType.conversationsChanged)),
      onConversationChanged: (_) =>
          _emit(const ChatEvent(type: ChatEventType.conversationsChanged)),
      onTotalUnreadMessageCountChanged: (count) => _emit(
        ChatEvent(
          type: ChatEventType.unreadCountChanged,
          totalUnreadCount: count,
        ),
      ),
      onSyncServerFinish: () =>
          _emit(const ChatEvent(type: ChatEventType.conversationsChanged)),
    );
    await _manager.v2TIMMessageManager.addAdvancedMsgListener(
      listener: _messageListener!,
    );
    await _manager.v2TIMConversationManager.addConversationListener(
      listener: _conversationListener!,
    );
    _listenersRegistered = true;
  }

  @override
  Future<ChatLoginResult> login({
    required String userId,
    required String userSig,
  }) async {
    await initialize();
    final result = await _manager.login(
      userID: userId.trim(),
      userSig: userSig.trim(),
    );
    if (result.code == 0) return const ChatLoginResult(success: true);
    return ChatLoginResult(
      success: false,
      errorCode: result.code,
      message: _safeSummary(result.desc),
    );
  }

  @override
  Future<void> logout() async {
    if (!_initialized) return;
    final result = await _manager.logout();
    if (result.code != 0) {
      throw ChatServiceException(_safeSummary(result.desc), code: result.code);
    }
  }

  @override
  Future<List<ChatConversation>> getConversations() async {
    _requireInitialized();
    final result = await _manager.v2TIMConversationManager.getConversationList(
      nextSeq: '0',
      count: 100,
    );
    if (result.code != 0) {
      throw ChatServiceException(_safeSummary(result.desc), code: result.code);
    }
    return (result.data?.conversationList ?? const [])
        .where((conversation) => conversation.userID?.isNotEmpty == true)
        .map(_mapConversation)
        .toList(growable: false);
  }

  @override
  Future<List<ChatMessage>> getMessages({
    required String conversationId,
    String? cursor,
  }) async {
    _requireInitialized();
    final recipient = _recipientFromConversationId(conversationId);
    final result = await _manager.v2TIMMessageManager.getC2CHistoryMessageList(
      userID: recipient,
      count: 30,
      lastMsgID: cursor,
    );
    if (result.code != 0) {
      throw ChatServiceException(_safeSummary(result.desc), code: result.code);
    }
    return (result.data ?? const [])
        .map(_mapMessage)
        .whereType<ChatMessage>()
        .toList(growable: false);
  }

  @override
  Future<ChatMessage> sendTextMessage({
    required String recipientUserId,
    required String text,
  }) async {
    _requireInitialized();
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      throw const ChatServiceException('Message cannot be empty.');
    }
    final created = await _manager.v2TIMMessageManager.createTextMessage(
      text: cleanText,
    );
    if (created.code != 0 || created.data?.messageInfo == null) {
      throw ChatServiceException(
        _safeSummary(created.desc),
        code: created.code,
      );
    }
    final sent = await _manager.v2TIMMessageManager.sendMessage(
      message: created.data!.messageInfo,
      receiver: recipientUserId.trim(),
      groupID: '',
      onlineUserOnly: false,
    );
    if (sent.code != 0 || sent.data == null) {
      throw ChatServiceException(_safeSummary(sent.desc), code: sent.code);
    }
    return _mapMessage(sent.data!) ??
        ChatMessage(
          id: sent.data!.msgID ?? created.data!.id ?? 'tencent_message',
          conversationId: 'c2c_${recipientUserId.trim()}',
          senderUserId: '',
          recipientUserId: recipientUserId.trim(),
          text: cleanText,
          timestamp: DateTime.now(),
          isMine: true,
          providerType: ChatProviderType.tencentCloud,
          deliveryState: ChatMessageDeliveryState.sent,
        );
  }

  @override
  Future<void> markConversationAsRead(String conversationId) async {
    _requireInitialized();
    final result = await _manager.v2TIMConversationManager
        .cleanConversationUnreadMessageCount(
          conversationID: conversationId,
          cleanTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          cleanSequence: 0,
        );
    if (result.code != 0) {
      throw ChatServiceException(_safeSummary(result.desc), code: result.code);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_listenersRegistered) {
      await _manager.v2TIMMessageManager.removeAdvancedMsgListener(
        listener: _messageListener,
      );
      await _manager.v2TIMConversationManager.removeConversationListener(
        listener: _conversationListener,
      );
      _listenersRegistered = false;
    }
    if (_sdkListener != null) {
      _manager.removeIMSDKListener(_sdkListener!);
    }
    if (_initialized) await _manager.unInitSDK();
    await _events.close();
  }

  ChatConversation _mapConversation(V2TimConversation value) {
    final userId =
        value.userID ?? _recipientFromConversationId(value.conversationID);
    final last = value.lastMessage;
    return ChatConversation(
      id: value.conversationID,
      participant: ChatUser(
        userId: userId,
        displayName: value.showName,
        avatarUrl: value.faceUrl,
      ),
      providerType: ChatProviderType.tencentCloud,
      lastMessagePreview: last?.textElem?.text ?? 'Unsupported message',
      lastMessageTimestamp: _timestamp(last?.timestamp),
      unreadCount: value.unreadCount ?? 0,
      hasSendingMessage: last?.status == MessageStatus.V2TIM_MSG_STATUS_SENDING,
      hasFailedMessage:
          last?.status == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL,
    );
  }

  ChatMessage? _mapMessage(V2TimMessage value) {
    final text = value.textElem?.text?.trim();
    final recipient = value.userID?.trim();
    if (text == null ||
        text.isEmpty ||
        recipient == null ||
        recipient.isEmpty) {
      return null;
    }
    return ChatMessage(
      id: value.msgID ?? value.id ?? 'tencent_${value.timestamp}_$recipient',
      conversationId: 'c2c_$recipient',
      senderUserId: value.sender ?? '',
      recipientUserId: recipient,
      text: text,
      timestamp: _timestamp(value.timestamp) ?? DateTime.now(),
      isMine: value.isSelf == true,
      providerType: ChatProviderType.tencentCloud,
      deliveryState: switch (value.status) {
        MessageStatus.V2TIM_MSG_STATUS_SENDING =>
          ChatMessageDeliveryState.sending,
        MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL =>
          ChatMessageDeliveryState.failed,
        _ => ChatMessageDeliveryState.sent,
      },
      isGpsStatusShare: text.contains('Tracking active:'),
    );
  }

  DateTime? _timestamp(int? seconds) => seconds == null || seconds <= 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

  String _recipientFromConversationId(String conversationId) =>
      conversationId.startsWith('c2c_')
      ? conversationId.substring(4)
      : conversationId;

  void _requireInitialized() {
    if (!_initialized) {
      throw const ChatServiceException('Tencent Chat SDK is not initialized.');
    }
  }

  String _safeSummary(String value) {
    final clean = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    return clean.isEmpty
        ? 'Tencent Chat operation failed.'
        : clean.substring(0, clean.length > 180 ? 180 : clean.length);
  }

  void _emit(ChatEvent event) {
    if (!_disposed) _events.add(event);
  }
}
