enum ChatProviderType {
  localDemo,
  tencentCloud;

  String get label => switch (this) {
    localDemo => 'Local Demo',
    tencentCloud => 'Tencent Cloud',
  };
}

class ChatConfiguration {
  const ChatConfiguration({this.sdkAppId = environmentSdkAppId});

  static const int environmentSdkAppId = int.fromEnvironment(
    'TENCENT_IM_SDK_APP_ID',
  );

  final int sdkAppId;

  bool get isTencentConfigured => sdkAppId > 0;
}

enum ChatSdkInitializationState {
  notAttempted,
  initializing,
  initialized,
  failed;

  String get label => switch (this) {
    notAttempted => 'Not attempted',
    initializing => 'Initializing',
    initialized => 'Initialized',
    failed => 'Failed',
  };
}
