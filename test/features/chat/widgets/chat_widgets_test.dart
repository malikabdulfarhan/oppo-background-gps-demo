import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_background_gps_demo/features/chat/controllers/chat_controller.dart';
import 'package:oppo_background_gps_demo/features/chat/models/chat_configuration.dart';
import 'package:oppo_background_gps_demo/features/chat/screens/chat_login_screen.dart';
import 'package:oppo_background_gps_demo/features/chat/widgets/chat_configuration_card.dart';
import 'package:oppo_background_gps_demo/features/chat/widgets/chat_status_banner.dart';

import '../fake_chat_service.dart';

void main() {
  testWidgets('missing SDKAppID keeps Local Chat Demo available', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ChatStatusBanner(provider: ChatProviderType.localDemo),
              ChatConfigurationCard(
                sdkAppIdConfigured: false,
                onOpenLogin: _noop,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.text('Local UI Demo — Not connected to Tencent Cloud'),
      findsOneWidget,
    );
    expect(find.text('Tencent Cloud configuration required'), findsOneWidget);
    expect(find.textContaining('Local Chat Demo Mode remains'), findsOneWidget);
  });

  testWidgets('login validates fields and hides UserSig by default', (
    tester,
  ) async {
    final controller = ChatController(
      configuration: const ChatConfiguration(sdkAppId: 1),
      localService: FakeChatService(providerType: ChatProviderType.localDemo),
      tencentService: FakeChatService(
        providerType: ChatProviderType.tencentCloud,
      ),
    );
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(home: ChatLoginScreen(controller: controller)),
    );

    final userSig = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Temporary UserSig'),
    );
    expect(userSig.obscureText, isTrue);
    expect(
      find.textContaining('request it from a secure backend'),
      findsOneWidget,
    );

    await tester.tap(find.text('Connect to Tencent Cloud'));
    await tester.pump();
    expect(
      find.text('User ID and temporary UserSig are required.'),
      findsOneWidget,
    );
    controller.dispose();
  });
}

void _noop() {}
