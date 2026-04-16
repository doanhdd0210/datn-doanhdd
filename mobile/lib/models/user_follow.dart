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
    final user = json['user'] as Map<String, dynamic>?;

    return UserFollow(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      userId: user?['_id'] as String? ?? json['userId'] as String? ?? '',
      name: user?['name'] as String? ?? json['name'] as String? ?? 'Unknown',
      avatar: user?['avatar'] as String? ?? json['avatar'] as String? ?? '',
      totalXp: user?['totalXp'] as int? ?? json['totalXp'] as int? ?? 0,
      streak: user?['streak'] as int? ?? json['streak'] as int? ?? 0,
    );
  }
}
