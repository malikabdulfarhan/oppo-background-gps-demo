import '../models/chat_configuration.dart';
import 'chat_service.dart';
import 'local_demo_chat_service.dart';
import 'tencent_chat_service.dart';

class ChatServiceFactory {
  const ChatServiceFactory();

  ChatService createLocalDemo() => LocalDemoChatService();

  ChatService createTencent(ChatConfiguration configuration) =>
      TencentChatService(sdkAppId: configuration.sdkAppId);
}
