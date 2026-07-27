import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_configuration.dart';
import '../models/chat_connection_state.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/chat_automatic_auth_state.dart';
import '../models/chat_user.dart';
import '../services/chat_auth_api.dart';
import '../services/chat_auth_coordinator.dart';
import '../services/chat_call_service.dart';
import '../services/chat_service.dart';
import '../services/chat_service_factory.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    ChatConfiguration configuration = const ChatConfiguration(),
    ChatServiceFactory factory = const ChatServiceFactory(),
    ChatService? localService,
    ChatService? tencentService,
    ChatAuthCoordinator? authCoordinator,
    ChatCallService? callService,
  }) : configuration = configuration,
       _localService = localService ?? factory.createLocalDemo(),
       _tencentService = tencentService ?? factory.createTencent(configuration),
       _authCoordinator = authCoordinator,
       _callService = callService ?? const DisabledChatCallService(),
       _automaticAuthState = authCoordinator == null
           ? ChatAutomaticAuthState.unavailable
           : ChatAutomaticAuthState.idle {
    _activeService = _localService;
  }

  final ChatConfiguration configuration;
  final ChatService _localService;
  final ChatService _tencentService;
  final ChatAuthCoordinator? _authCoordinator;
  final ChatCallService _callService;
  late ChatService _activeService;
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  StreamSubscription<ChatEvent>? _serviceSubscription;
  List<ChatConversation> _conversations = const [];
  ChatProviderType _providerType = ChatProviderType.localDemo;
  ChatSdkInitializationState _sdkInitializationState =
      ChatSdkInitializationState.notAttempted;
  ChatNetworkState _networkState = ChatNetworkState.unknown;
  ChatAuthenticationState _authenticationState =
      ChatAuthenticationState.loggedOut;
  ChatUserSigState _userSigState = ChatUserSigState.notAvailable;
  ChatAutomaticAuthState _automaticAuthState;
  bool _initialized = false;
  bool _loading = false;
  bool _loginSubmitting = false;
  bool _disposed = false;
  bool _hasSavedChatSession = false;
  bool _automaticRecoveryRunning = false;
  int _totalUnreadCount = 0;
  int? _lastErrorCode;
  String? _lastErrorSummary;
  String? _automaticAuthMessage;
  String? _callErrorMessage;
  String? _loggedInUserId;
  DateTime? _lastIncomingMessageTimestamp;

  ChatProviderType get providerType => _providerType;
  ChatSdkInitializationState get sdkInitializationState =>
      _sdkInitializationState;
  ChatNetworkState get networkState => _networkState;
  ChatAuthenticationState get authenticationState => _authenticationState;
  ChatUserSigState get userSigState => _userSigState;
  ChatAutomaticAuthState get automaticAuthState => _automaticAuthState;
  bool get isInitialized => _initialized;
  bool get isLoading => _loading;
  bool get isLoginSubmitting => _loginSubmitting;
  bool get isTencentConfigured => configuration.isTencentConfigured;
  bool get isAutomaticAuthAvailable => _authCoordinator != null;
  bool get hasSavedChatSession => _hasSavedChatSession;
  bool get isTencentLoggedIn =>
      _authenticationState == ChatAuthenticationState.loggedIn;
  bool get isCallingSupported => _callService.isSupported;
  bool get isCallingAvailable => isTencentLoggedIn && _callService.isLoggedIn;
  bool get advancedListenerRegistered =>
      _tencentService.advancedListenerRegistered;
  int get totalUnreadCount => _totalUnreadCount;
  int get conversationCount => _conversations.length;
  int? get lastErrorCode => _lastErrorCode;
  String? get lastErrorSummary => _lastErrorSummary;
  String? get automaticAuthMessage => _automaticAuthMessage;
  String? get callErrorMessage => _callErrorMessage;
  String? get loggedInUserId => _loggedInUserId;
  String? get sdkVersion => _tencentService.sdkVersion;
  DateTime? get lastIncomingMessageTimestamp => _lastIncomingMessageTimestamp;
  List<ChatConversation> get conversations => List.unmodifiable(_conversations);
  Stream<ChatEvent> get events => _events.stream;

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    await _activateService(_localService);
    if (isTencentConfigured && isAutomaticAuthAvailable) {
      await restoreAutomaticLogin();
    }
  }

  Future<bool> restoreAutomaticLogin() async {
    final coordinator = _authCoordinator;
    if (coordinator == null ||
        !isTencentConfigured ||
        _disposed ||
        _automaticAuthState == ChatAutomaticAuthState.restoring ||
        _automaticAuthState == ChatAutomaticAuthState.signingIn) {
      return false;
    }
    _automaticAuthState = ChatAutomaticAuthState.restoring;
    _automaticAuthMessage = null;
    _notify();
    try {
      _hasSavedChatSession = await coordinator.hasSavedSession();
      if (!_hasSavedChatSession) {
        _automaticAuthState = ChatAutomaticAuthState.idle;
        _notify();
        return false;
      }
      final session = await coordinator.restore();
      if (session == null) {
        _hasSavedChatSession = false;
        _automaticAuthState = ChatAutomaticAuthState.idle;
        _notify();
        return false;
      }
      final result = await loginTencent(
        userId: session.userId,
        userSig: session.userSig,
      );
      if (result.success) {
        _hasSavedChatSession = true;
        _automaticAuthState = ChatAutomaticAuthState.authenticated;
        _automaticAuthMessage = null;
        _notify();
        return true;
      }
      _automaticAuthState = ChatAutomaticAuthState.failed;
      _automaticAuthMessage =
          result.message ?? 'Tencent Chat could not restore your login.';
    } on ChatAuthException catch (error) {
      _hasSavedChatSession = !error.sessionExpired;
      _automaticAuthState = error.sessionExpired
          ? ChatAutomaticAuthState.sessionExpired
          : ChatAutomaticAuthState.failed;
      _automaticAuthMessage = error.message;
    } on Object {
      _automaticAuthState = ChatAutomaticAuthState.failed;
      _automaticAuthMessage =
          'Automatic Chat sign-in is temporarily unavailable.';
    }
    _notify();
    return false;
  }

  Future<ChatLoginResult> loginWithBackend({
    required String userId,
    required String pin,
  }) async {
    final coordinator = _authCoordinator;
    final cleanUserId = userId.trim();
    if (coordinator == null) {
      return const ChatLoginResult(
        success: false,
        message: 'Secure Chat authentication is not configured.',
      );
    }
    if (!isTencentConfigured) {
      return const ChatLoginResult(
        success: false,
        message: 'Tencent SDKAppID is not configured.',
      );
    }
    if (cleanUserId.isEmpty || pin.isEmpty) {
      return const ChatLoginResult(
        success: false,
        message: 'User ID and demo PIN are required.',
      );
    }
    if (_loginSubmitting ||
        _automaticAuthState == ChatAutomaticAuthState.signingIn ||
        _automaticAuthState == ChatAutomaticAuthState.restoring) {
      return const ChatLoginResult(
        success: false,
        message: 'Chat sign-in is already running.',
      );
    }

    _automaticAuthState = ChatAutomaticAuthState.signingIn;
    _automaticAuthMessage = null;
    _notify();
    try {
      final session = await coordinator.signIn(userId: cleanUserId, pin: pin);
      _hasSavedChatSession = true;
      final result = await loginTencent(
        userId: session.userId,
        userSig: session.userSig,
      );
      if (result.success) {
        _automaticAuthState = ChatAutomaticAuthState.authenticated;
        _automaticAuthMessage = null;
      } else {
        _automaticAuthState = ChatAutomaticAuthState.failed;
        _automaticAuthMessage =
            result.message ?? 'Tencent Chat sign-in failed.';
      }
      _notify();
      return result;
    } on ChatAuthException catch (error) {
      _automaticAuthState = error.sessionExpired
          ? ChatAutomaticAuthState.sessionExpired
          : ChatAutomaticAuthState.failed;
      _automaticAuthMessage = error.message;
      _setError(null, error.message);
      _notify();
      return ChatLoginResult(success: false, message: error.message);
    } on Object {
      const message = 'Secure Chat sign-in is temporarily unavailable.';
      _automaticAuthState = ChatAutomaticAuthState.failed;
      _automaticAuthMessage = message;
      _setError(null, message);
      _notify();
      return const ChatLoginResult(success: false, message: message);
    }
  }

  Future<void> _activateService(
    ChatService service, {
    bool initializeService = true,
  }) async {
    await _serviceSubscription?.cancel();
    _activeService = service;
    _providerType = service.providerType;
    _serviceSubscription = service.events.listen(
      _handleEvent,
      onError: (_) =>
          _setError(null, 'The chat event connection was interrupted.'),
    );
    try {
      if (initializeService) await service.initialize();
      await refreshConversations();
    } on ChatServiceException catch (error) {
      _setError(error.code, error.summary);
    } on Object {
      _setError(null, 'Chat could not initialize.');
    }
    _notify();
  }

  Future<void> refreshConversations() async {
    if (_disposed || _loading) return;
    _loading = true;
    _notify();
    try {
      _conversations = await _activeService.getConversations();
      _totalUnreadCount = _conversations.fold(
        0,
        (total, item) => total + item.unreadCount,
      );
      _clearError();
    } on ChatServiceException catch (error) {
      _setError(error.code, error.summary);
    } on Object {
      _setError(null, 'Unable to load conversations.');
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<bool> initializeTencent() async {
    if (!isTencentConfigured || _disposed) {
      _setError(null, 'Tencent SDKAppID is not configured.');
      _notify();
      return false;
    }
    _sdkInitializationState = ChatSdkInitializationState.initializing;
    _clearError();
    _notify();
    try {
      await _tencentService.initialize();
      _sdkInitializationState = ChatSdkInitializationState.initialized;
      _networkState = ChatNetworkState.disconnected;
      _notify();
      return true;
    } on ChatServiceException catch (error) {
      _sdkInitializationState = ChatSdkInitializationState.failed;
      _setError(error.code, error.summary);
    } on Object {
      _sdkInitializationState = ChatSdkInitializationState.failed;
      _setError(null, 'Tencent Chat SDK could not initialize.');
    }
    _notify();
    return false;
  }

  Future<ChatLoginResult> loginTencent({
    required String userId,
    required String userSig,
  }) async {
    final cleanUserId = userId.trim();
    final cleanUserSig = userSig.trim();
    if (_loginSubmitting) {
      return const ChatLoginResult(
        success: false,
        message: 'Tencent login is already running.',
      );
    }
    if (!isTencentConfigured) {
      return const ChatLoginResult(
        success: false,
        message: 'Tencent SDKAppID is not configured.',
      );
    }
    if (cleanUserId.isEmpty || cleanUserSig.isEmpty) {
      return const ChatLoginResult(
        success: false,
        message: 'User ID and temporary UserSig are required.',
      );
    }
    _loginSubmitting = true;
    _authenticationState = ChatAuthenticationState.loggingIn;
    _clearError();
    _notify();
    var callSessionStarted = false;
    try {
      final initialized =
          _sdkInitializationState == ChatSdkInitializationState.initialized ||
          await initializeTencent();
      if (!initialized) {
        return ChatLoginResult(
          success: false,
          errorCode: _lastErrorCode,
          message: _lastErrorSummary,
        );
      }
      if (_callService.isSupported) {
        final callLogin = await _callService.login(
          sdkAppId: configuration.sdkAppId,
          userId: cleanUserId,
          userSig: cleanUserSig,
        );
        callSessionStarted = callLogin.success;
        _callErrorMessage = callLogin.success ? null : callLogin.message;
      }
      final result = await _tencentService.login(
        userId: cleanUserId,
        userSig: cleanUserSig,
      );
      if (!result.success) {
        if (callSessionStarted) await _detachCallSession();
        _authenticationState = result.isExpiredCredential
            ? ChatAuthenticationState.authenticationExpired
            : ChatAuthenticationState.loggedOut;
        _userSigState = result.isExpiredCredential
            ? ChatUserSigState.expired
            : ChatUserSigState.notAvailable;
        _setError(
          result.errorCode,
          result.isExpiredCredential
              ? 'Tencent login expired. Request a new UserSig.'
              : result.message ?? 'Tencent login failed.',
        );
        return result;
      }
      _authenticationState = ChatAuthenticationState.loggedIn;
      _userSigState = ChatUserSigState.availableInMemory;
      _loggedInUserId = cleanUserId;
      await _activateService(_tencentService, initializeService: false);
      return const ChatLoginResult(success: true);
    } on ChatServiceException catch (error) {
      if (callSessionStarted) await _detachCallSession();
      _authenticationState = ChatAuthenticationState.loggedOut;
      _userSigState = ChatUserSigState.notAvailable;
      _setError(error.code, error.summary);
      return ChatLoginResult(
        success: false,
        errorCode: error.code,
        message: error.summary,
      );
    } on Object {
      if (callSessionStarted) await _detachCallSession();
      _authenticationState = ChatAuthenticationState.loggedOut;
      _userSigState = ChatUserSigState.notAvailable;
      _setError(null, 'Tencent login failed.');
      return const ChatLoginResult(
        success: false,
        message: 'Tencent login failed.',
      );
    } finally {
      _loginSubmitting = false;
      _notify();
    }
  }

  Future<void> switchToLocalDemo() async {
    if (_disposed || _providerType == ChatProviderType.localDemo) return;
    await _activateService(_localService);
  }

  Future<void> logoutTencent() async {
    try {
      await _authCoordinator?.signOut();
    } on Object {
      try {
        await _authCoordinator?.clearLocalSession();
      } on Object {
        // Logout still clears all in-memory credentials below.
      }
    }
    _hasSavedChatSession = false;
    _automaticAuthState = isAutomaticAuthAvailable
        ? ChatAutomaticAuthState.idle
        : ChatAutomaticAuthState.unavailable;
    _automaticAuthMessage = null;
    try {
      if (_callService.isLoggedIn) {
        await _detachCallSession();
      } else {
        await _tencentService.logout();
      }
    } on ChatServiceException catch (error) {
      _setError(error.code, error.summary);
    } on Object {
      _setError(null, 'Tencent logout did not complete cleanly.');
    }
    _authenticationState = ChatAuthenticationState.loggedOut;
    _userSigState = ChatUserSigState.notAvailable;
    _loggedInUserId = null;
    _callErrorMessage = null;
    await switchToLocalDemo();
    _notify();
  }

  void clearCredentialsState() {
    _authenticationState = ChatAuthenticationState.loggedOut;
    _userSigState = ChatUserSigState.notAvailable;
    _loggedInUserId = null;
    _automaticAuthMessage = null;
    _clearError();
    _notify();
  }

  Future<void> clearSavedAuthentication() async {
    if (isTencentLoggedIn || _providerType == ChatProviderType.tencentCloud) {
      await logoutTencent();
      return;
    }
    try {
      await _authCoordinator?.clearLocalSession();
    } on Object {
      _automaticAuthMessage = 'Unable to clear the saved Chat session.';
      _notify();
      return;
    }
    _hasSavedChatSession = false;
    _automaticAuthState = isAutomaticAuthAvailable
        ? ChatAutomaticAuthState.idle
        : ChatAutomaticAuthState.unavailable;
    clearCredentialsState();
  }

  Future<List<ChatMessage>> getMessages({
    required String conversationId,
    String? cursor,
  }) => _activeService.getMessages(
    conversationId: conversationId,
    cursor: cursor,
  );

  Future<ChatMessage> sendTextMessage({
    required String recipientUserId,
    required String text,
  }) async {
    try {
      final message = await _activeService.sendTextMessage(
        recipientUserId: recipientUserId,
        text: text,
      );
      await refreshConversations();
      return message;
    } on ChatServiceException catch (error) {
      _setError(error.code, error.summary);
      _notify();
      rethrow;
    }
  }

  Future<ChatCallResult> startAudioCall(String recipientUserId) =>
      _startCall(recipientUserId, ChatCallMediaType.audio);

  Future<ChatCallResult> startVideoCall(String recipientUserId) =>
      _startCall(recipientUserId, ChatCallMediaType.video);

  Future<ChatCallResult> _startCall(
    String recipientUserId,
    ChatCallMediaType mediaType,
  ) async {
    if (!isTencentLoggedIn) {
      return const ChatCallResult(
        success: false,
        message: 'Sign in to Tencent Chat before starting a call.',
      );
    }
    if (!_callService.isLoggedIn) {
      return ChatCallResult(
        success: false,
        message:
            _callErrorMessage ??
            'Audio/video calling is not ready. Sign in again.',
      );
    }
    final result = await _callService.startCall(
      recipientUserId: recipientUserId,
      mediaType: mediaType,
    );
    _callErrorMessage = result.success ? null : result.message;
    _notify();
    return result;
  }

  Future<void> markConversationAsRead(String conversationId) async {
    try {
      await _activeService.markConversationAsRead(conversationId);
      await refreshConversations();
    } on ChatServiceException catch (error) {
      _setError(error.code, error.summary);
      _notify();
    }
  }

  Future<ChatConversation> createLocalConversation({
    required String recipientUserId,
    String? displayName,
  }) async {
    final service = _activeService;
    if (service is! LocalDemoChatOperations) {
      return ChatConversation(
        id: 'c2c_${recipientUserId.trim()}',
        participant: ChatUser(
          userId: recipientUserId.trim(),
          displayName: displayName,
        ),
        providerType: ChatProviderType.tencentCloud,
      );
    }
    final operations = service as LocalDemoChatOperations;
    final conversation = await operations.createConversation(
      recipientUserId: recipientUserId,
      displayName: displayName,
    );
    await refreshConversations();
    return conversation;
  }

  Future<void> simulateIncomingMessage(String conversationId) async {
    final service = _activeService;
    if (service is! LocalDemoChatOperations) {
      throw const ChatServiceException(
        'Simulation is available only in Local Chat Demo Mode.',
      );
    }
    await (service as LocalDemoChatOperations).simulateIncomingMessage(
      conversationId,
    );
  }

  Future<void> resetLocalDemoData() async {
    if (_localService is LocalDemoChatOperations) {
      final operations = _localService as LocalDemoChatOperations;
      await operations.resetLocalData();
      if (_providerType == ChatProviderType.localDemo) {
        await refreshConversations();
      }
    }
  }

  Future<void> handleAppResumed() async {
    if (_providerType == ChatProviderType.tencentCloud &&
        _authenticationState == ChatAuthenticationState.loggedIn) {
      await refreshConversations();
    }
  }

  void _handleEvent(ChatEvent event) {
    if (_disposed) return;
    switch (event.type) {
      case ChatEventType.networkChanged:
        _networkState = event.networkState ?? ChatNetworkState.unknown;
        if (_networkState == ChatNetworkState.connected &&
            _providerType == ChatProviderType.tencentCloud &&
            _authenticationState == ChatAuthenticationState.loggedIn) {
          unawaited(refreshConversations());
        }
      case ChatEventType.authenticationExpired:
        _authenticationState = ChatAuthenticationState.authenticationExpired;
        _userSigState = ChatUserSigState.expired;
        if (isAutomaticAuthAvailable && _hasSavedChatSession) {
          _setError(null, 'Tencent login expired. Refreshing securely.');
          unawaited(_recoverAutomaticAuthentication());
        } else {
          _setError(null, 'Tencent login expired. Sign in again.');
        }
      case ChatEventType.kickedOffline:
        _authenticationState = ChatAuthenticationState.kickedOffline;
        _userSigState = ChatUserSigState.notAvailable;
        _loggedInUserId = null;
        _hasSavedChatSession = false;
        _automaticAuthState = isAutomaticAuthAvailable
            ? ChatAutomaticAuthState.sessionExpired
            : ChatAutomaticAuthState.unavailable;
        _automaticAuthMessage =
            'This user signed in on another device. Sign in again to continue.';
        unawaited(_detachCallSession());
        unawaited(_clearSavedSessionAfterKick());
        _setError(
          null,
          'This Tencent user was signed in elsewhere and was kicked offline.',
        );
      case ChatEventType.newMessage:
        if (event.message?.isMine == false) {
          _lastIncomingMessageTimestamp = event.message?.timestamp;
        }
        unawaited(refreshConversations());
      case ChatEventType.conversationsChanged:
        unawaited(refreshConversations());
      case ChatEventType.unreadCountChanged:
        _totalUnreadCount = event.totalUnreadCount ?? _totalUnreadCount;
      case ChatEventType.error:
        _setError(event.errorCode, event.errorSummary ?? 'Chat error.');
      case ChatEventType.initialized:
        break;
    }
    if (!_events.isClosed) _events.add(event);
    _notify();
  }

  Future<void> _recoverAutomaticAuthentication() async {
    if (_automaticRecoveryRunning || _disposed) return;
    _automaticRecoveryRunning = true;
    try {
      await _detachCallSession();
      await restoreAutomaticLogin();
    } finally {
      _automaticRecoveryRunning = false;
    }
  }

  Future<void> _detachCallSession() async {
    if (_callService.isLoggedIn) {
      await _callService.logout();
    }
    final service = _tencentService;
    if (service is ExternallyAuthenticatedChatService) {
      (service as ExternallyAuthenticatedChatService)
          .resetAfterExternalLogout();
      _sdkInitializationState = ChatSdkInitializationState.notAttempted;
    } else {
      await service.logout();
    }
  }

  Future<void> _clearSavedSessionAfterKick() async {
    try {
      await _authCoordinator?.clearLocalSession();
    } on Object {
      // In-memory state is still cleared to prevent a retry loop.
    }
  }

  void _setError(int? code, String summary) {
    _lastErrorCode = code;
    _lastErrorSummary = summary;
  }

  void _clearError() {
    _lastErrorCode = null;
    _lastErrorSummary = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_disposeServices());
    _authCoordinator?.dispose();
    unawaited(_events.close());
    super.dispose();
  }

  Future<void> _disposeServices() async {
    await _serviceSubscription?.cancel();
    final externallyAuthenticated = _callService.isLoggedIn;
    try {
      await _callService.dispose();
    } on Object {
      // Disposal is best-effort and must not surface plugin details.
    }
    if (externallyAuthenticated &&
        _tencentService is ExternallyAuthenticatedChatService) {
      (_tencentService as ExternallyAuthenticatedChatService)
          .resetAfterExternalLogout();
    }
    await _localService.dispose();
    await _tencentService.dispose();
  }
}
