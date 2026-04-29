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

  factory UserFollow.fromJson(Map<String, dynamic> json) {
    return UserFollow(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      userId: json['followingId'] as String? ?? json['userId'] as String? ?? '',
      name: json['followingName'] as String? ?? json['name'] as String? ?? 'Unknown',
      avatar: json['followingAvatar'] as String? ?? json['avatar'] as String? ?? '',
      totalXp: json['totalXp'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
    );
  }
}
