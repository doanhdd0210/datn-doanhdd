class LeaderboardEntry {
  final String userId;
  final String name;
  final String avatar;
  final int totalXp;
  final int streak;
  final int rank;
  final int lessonsCompleted;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.avatar,
    required this.totalXp,
    required this.streak,
    required this.rank,
    this.lessonsCompleted = 0,
    required this.isCurrentUser,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, {bool isCurrentUser = false}) {
    return LeaderboardEntry(
      userId: json['userId'] as String? ?? json['_id'] as String? ?? '',
      name: json['displayName'] as String? ?? json['name'] as String? ?? 'Unknown',
      avatar: json['photoUrl'] as String? ?? json['avatar'] as String? ?? '',
      totalXp: json['totalXp'] as int? ?? 0,
      streak: json['currentStreak'] as int? ?? json['streak'] as int? ?? 0,
      rank: (json['rank'] as int?) ?? 0,
      lessonsCompleted: json['lessonsCompleted'] as int? ?? 0,
      isCurrentUser: isCurrentUser,
    );
  }
}
