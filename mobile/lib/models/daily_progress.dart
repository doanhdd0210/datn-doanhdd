class DailyProgress {
  final DateTime date;
  final int xpEarned;
  final int lessonsCompleted;
  final int minutesLearned;

  const DailyProgress({
    required this.date,
    required this.xpEarned,
    required this.lessonsCompleted,
    required this.minutesLearned,
  });

  factory DailyProgress.fromJson(Map<String, dynamic> json) {
    return DailyProgress(
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      xpEarned: json['xpEarned'] as int? ?? 0,
      lessonsCompleted: json['lessonsCompleted'] as int? ?? 0,
      minutesLearned: json['minutesLearned'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'xpEarned': xpEarned,
      'lessonsCompleted': lessonsCompleted,
      'minutesLearned': minutesLearned,
    };
  }
}
