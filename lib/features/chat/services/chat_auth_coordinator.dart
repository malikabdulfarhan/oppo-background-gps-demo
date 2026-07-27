import '../models/chat_auth_session.dart';
import 'chat_auth_api.dart';

class ChatAuthCoordinator {
  ChatAuthCoordinator(this._api, this._store);

  final ChatAuthApi _api;
  final ChatRefreshTokenStore _store;

  Future<bool> hasSavedSession() async => (await _store.read()) != null;

  Future<ChatAuthSession?> restore() async {
    final token = await _store.read();
    if (token == null) return null;
    try {
      final session = await _api.refresh(refreshToken: token);
      await _store.write(session.refreshToken);
      return session;
    } on ChatAuthException catch (error) {
      if (error.sessionExpired) await _store.clear();
      rethrow;
    }
  }

  Future<ChatAuthSession> signIn({
    required String userId,
    required String pin,
  }) async {
    final session = await _api.login(userId: userId, pin: pin);
    await _store.write(session.refreshToken);
    return session;
  }

  Future<void> signOut() async {
    final token = await _store.read();
    try {
      if (token != null) {
        await _api.logout(refreshToken: token);
      }
    } on Object {
      // Local removal still prevents another automatic login on this device.
    } finally {
      await _store.clear();
    }
  }

  Future<void> clearLocalSession() => _store.clear();

  void dispose() => _api.close();
}
