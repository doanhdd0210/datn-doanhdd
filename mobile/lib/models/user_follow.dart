class UserFollow {
  final String id;
  final String userId;
  final String name;
  final String avatar;
  final int totalXp;
  final int streak;

  const UserFollow({
    required this.id,
    required this.userId,
    required this.name,
    required this.avatar,
    required this.totalXp,
    required this.streak,
  });

  static String? _nonEmpty(dynamic v) {
    final s = v?.toString() ?? '';
    return s.isNotEmpty ? s : null;
  }

  factory UserFollow.fromJson(Map<String, dynamic> json) {
    return UserFollow(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      userId: json['followingId'] as String? ?? json['userId'] as String? ?? '',
      name: _nonEmpty(json['followingName']) ?? _nonEmpty(json['name']) ?? _nonEmpty(json['userName']) ?? 'Người dùng',
      avatar: json['followingAvatar'] as String? ?? json['avatar'] as String? ?? '',
      totalXp: json['totalXp'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
    );
  }
}
