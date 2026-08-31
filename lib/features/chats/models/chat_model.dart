/// Type of conversation: direct message, group chat, or broadcast channel.
enum ChatKind { dm, group, channel }

class ChatModel {
  final String id;
  final ChatKind kind;
  final String title; // other user's name, or group/channel name
  final String? avatarUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isPinned;

  const ChatModel({
    required this.id,
    required this.kind,
    required this.title,
    this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isPinned = false,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String,
      kind: ChatKind.values.firstWhere(
        (k) => k.name == (json['kind'] as String? ?? 'dm'),
        orElse: () => ChatKind.dm,
      ),
      title: json['title'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      lastMessage: json['last_message'] as String? ?? '',
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      unreadCount: json['unread_count'] as int? ?? 0,
      isPinned: json['is_pinned'] as bool? ?? false,
    );
  }
}
