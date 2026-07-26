class ChatUser {
  const ChatUser({required this.userId, this.displayName, this.avatarUrl});

  final String userId;
  final String? displayName;
  final String? avatarUrl;

  String get title =>
      displayName?.trim().isNotEmpty == true ? displayName!.trim() : userId;

  String get initials {
    final words = title
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2);
    return words.map((word) => word[0].toUpperCase()).join();
  }
}
