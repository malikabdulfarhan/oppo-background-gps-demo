class ChatAuthSession {
  const ChatAuthSession({
    required this.userId,
    required this.userSig,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String userId;
  final String userSig;
  final String refreshToken;
  final DateTime expiresAt;

  static ChatAuthSession? tryParse(Object? value) {
    if (value is! Map) return null;
    final map = Map<Object?, Object?>.from(value);
    final userId = map['userId'] is String
        ? (map['userId'] as String).trim()
        : '';
    final userSig = map['userSig'] is String
        ? (map['userSig'] as String).trim()
        : '';
    final refreshToken = map['refreshToken'] is String
        ? (map['refreshToken'] as String).trim()
        : '';
    final expiresAt = DateTime.tryParse('${map['expiresAt'] ?? ''}');
    if (!RegExp(r'^[A-Za-z0-9_-]{1,32}$').hasMatch(userId) ||
        userSig.length < 40 ||
        refreshToken.length < 40 ||
        expiresAt == null) {
      return null;
    }
    return ChatAuthSession(
      userId: userId,
      userSig: userSig,
      refreshToken: refreshToken,
      expiresAt: expiresAt.toUtc(),
    );
  }
}
