class UserProgress {
  final String lessonId;
  final String topicId;
  final bool isCompleted;
  final int score;
  final int xpEarned;
  final DateTime? completedAt;

  const UserProgress({
    required this.lessonId,
    required this.topicId,
    required this.isCompleted,
    required this.score,
    required this.xpEarned,
    this.completedAt,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      lessonId: json['lessonId'] as String? ?? '',
      topicId: json['topicId'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      score: json['score'] as int? ?? 0,
      xpEarned: json['xpEarned'] as int? ?? 0,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lessonId': lessonId,
      'topicId': topicId,
      'isCompleted': isCompleted,
      'score': score,
      'xpEarned': xpEarned,
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}
