class LeaderboardEntry {
  final String userId;
  final String name;
  final String avatar;
  final int totalXp;
  final int streak;
  final int rank;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.avatar,
    required this.totalXp,
    required this.streak,
    required this.rank,
    required this.isCurrentUser,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, {bool isCurrentUser = false}) {
    return LeaderboardEntry(
      userId: json['userId'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      avatar: json['avatar'] as String? ?? '',
      totalXp: json['totalXp'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      rank: json['rank'] as int? ?? 0,
      isCurrentUser: isCurrentUser,
    );
  }
}
