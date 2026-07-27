class ChatAuthConfiguration {
  const ChatAuthConfiguration({
    this.baseUrl = environmentBaseUrl,
    this.requestTimeout = const Duration(seconds: 12),
  });

  static const environmentBaseUrl = String.fromEnvironment(
    'TENCENT_CHAT_AUTH_BASE_URL',
  );

  final String baseUrl;
  final Duration requestTimeout;

  Uri? get validatedBaseUri {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return uri;
  }

  bool get isConfigured => validatedBaseUri != null;
}
