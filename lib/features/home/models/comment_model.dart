class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String authorLevel;
  final String body;
  final bool isAcceptedAnswer;
  final int helpfulCount; // needed for "Most helpful" sort
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.authorLevel,
    required this.body,
    this.isAcceptedAnswer = false,
    this.helpfulCount = 0,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String? ?? 'Unknown',
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorLevel: json['author_level'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isAcceptedAnswer: json['is_accepted_answer'] as bool? ?? false,
      helpfulCount: json['helpful_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
