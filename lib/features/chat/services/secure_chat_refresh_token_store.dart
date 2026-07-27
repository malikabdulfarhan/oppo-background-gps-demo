import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'chat_auth_api.dart';

class SecureChatRefreshTokenStore implements ChatRefreshTokenStore {
  SecureChatRefreshTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'tencent_chat_refresh_token_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    final token = (await _storage.read(key: _key))?.trim();
    return token?.isNotEmpty == true ? token : null;
  }

  @override
  Future<void> write(String refreshToken) =>
      _storage.write(key: _key, value: refreshToken);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
