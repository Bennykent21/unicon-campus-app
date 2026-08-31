class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String authorUsername;
  final String? authorAvatarUrl;
  final String authorLevel;
  final bool isFollowingAuthor;
  final String type;
  final String title;
  final String body;
  final List<String> tags;
  final List<String> imageUrls;
  final DateTime createdAt;

  final int helpfulCount;
  final int commentCount;
  final bool isSavedByMe;
  final bool isHelpfulByMe;
  final bool hasAcceptedAnswer;

  // Marketplace
  final num? price;
  // Job
  final String? jobLocation;
  final bool? isInternship;
  final String? salary;
  // Event
  final DateTime? eventDate;
  final String? eventLocation;

  const PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorUsername = '',
    this.authorAvatarUrl,
    required this.authorLevel,
    this.isFollowingAuthor = false,
    required this.type,
    required this.title,
    required this.body,
    this.tags = const [],
    this.imageUrls = const [],
    required this.createdAt,
    this.helpfulCount = 0,
    this.commentCount = 0,
    this.isSavedByMe = false,
    this.isHelpfulByMe = false,
    this.hasAcceptedAnswer = false,
    this.price,
    this.jobLocation,
    this.isInternship,
    this.salary,
    this.eventDate,
    this.eventLocation,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String? ?? 'Unknown',
      authorUsername: json['author_username'] as String? ?? '',
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorLevel: json['author_level'] as String? ?? '',
      isFollowingAuthor: json['is_following_author'] as bool? ?? false,
      type: json['type'] as String? ?? 'general',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      imageUrls:
          (json['image_urls'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      createdAt: DateTime.parse(json['created_at'] as String),
      helpfulCount: json['helpful_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      isSavedByMe: json['is_saved_by_me'] as bool? ?? false,
      isHelpfulByMe: json['is_helpful_by_me'] as bool? ?? false,
      hasAcceptedAnswer: json['has_accepted_answer'] as bool? ?? false,
      price: json['price'] as num?,
      jobLocation: json['job_location'] as String?,
      isInternship: json['is_internship'] as bool?,
      salary: json['salary'] as String?,
      eventDate: json['event_date'] != null
          ? DateTime.parse(json['event_date'] as String)
          : null,
      eventLocation: json['event_location'] as String?,
    );
  }

  PostModel copyWith({
    int? helpfulCount,
    int? commentCount,
    bool? isSavedByMe,
    bool? isHelpfulByMe,
    bool? isFollowingAuthor,
  }) {
    return PostModel(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      authorLevel: authorLevel,
      isFollowingAuthor: isFollowingAuthor ?? this.isFollowingAuthor,
      type: type,
      title: title,
      body: body,
      tags: tags,
      imageUrls: imageUrls,
      createdAt: createdAt,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      commentCount: commentCount ?? this.commentCount,
      isSavedByMe: isSavedByMe ?? this.isSavedByMe,
      isHelpfulByMe: isHelpfulByMe ?? this.isHelpfulByMe,
      hasAcceptedAnswer: hasAcceptedAnswer,
      price: price,
      jobLocation: jobLocation,
      isInternship: isInternship,
      salary: salary,
      eventDate: eventDate,
      eventLocation: eventLocation,
    );
  }
}
