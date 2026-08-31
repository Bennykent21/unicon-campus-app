class ProfileModel {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String? department;
  final String? level;
  final String? university;
  final String? bio;
  final int reputation;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final DateTime? createdAt;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.department,
    this.level,
    this.university,
    this.bio,
    this.reputation = 0,
    this.postCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.createdAt,
  });

  String get departmentLevel {
    if (department != null && level != null) return '$department · $level';
    if (department != null) return department!;
    if (level != null) return level!;
    return '';
  }

  String get joinedDate {
    if (createdAt == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return 'Joined ${months[createdAt!.month - 1]} ${createdAt!.year}';
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      department: json['department'] as String?,
      level: json['level'] as String?,
      university: json['university'] as String?,
      bio: json['bio'] as String?,
      reputation: json['reputation'] as int? ?? 0,
      postCount: json['post_count'] as int? ?? 0,
      followerCount: json['follower_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  ProfileModel copyWith({
    String? username,
    String? fullName,
    String? avatarUrl,
    String? department,
    String? level,
    String? university,
    String? bio,
    int? reputation,
    int? postCount,
    int? followerCount,
    int? followingCount,
  }) {
    return ProfileModel(
      id: id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      department: department ?? this.department,
      level: level ?? this.level,
      university: university ?? this.university,
      bio: bio ?? this.bio,
      reputation: reputation ?? this.reputation,
      postCount: postCount ?? this.postCount,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      createdAt: createdAt,
    );
  }
}
