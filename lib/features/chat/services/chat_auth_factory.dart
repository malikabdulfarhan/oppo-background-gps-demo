import '../models/chat_auth_configuration.dart';
import 'chat_auth_coordinator.dart';
import 'cloud_chat_auth_api.dart';
import 'secure_chat_refresh_token_store.dart';

class ChatAuthFactory {
  const ChatAuthFactory();

  ChatAuthCoordinator? create(ChatAuthConfiguration configuration) {
    if (!configuration.isConfigured) return null;
    return ChatAuthCoordinator(
      CloudChatAuthApi(configuration: configuration),
      SecureChatRefreshTokenStore(),
    );
  }
}
