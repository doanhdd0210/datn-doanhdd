class UserAnswer {
  final String questionId;
  final int selectedAnswerIndex;
  final bool isCorrect;

  const UserAnswer({
    required this.questionId,
    required this.selectedAnswerIndex,
    required this.isCorrect,
  });

  factory UserAnswer.fromJson(Map<String, dynamic> json) {
    return UserAnswer(
      questionId: json['questionId'] as String? ?? '',
      selectedAnswerIndex: json['selectedAnswerIndex'] as int? ?? 0,
      isCorrect: json['isCorrect'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'selectedAnswerIndex': selectedAnswerIndex,
      'isCorrect': isCorrect,
    };
  }
}

class QuizResult {
  final String id;
  final String lessonId;
  final int totalQuestions;
  final int correctAnswers;
  final int score;
  final int xpEarned;
  final List<UserAnswer> answers;
  final DateTime completedAt;

  const QuizResult({
    required this.id,
    required this.lessonId,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.score,
    required this.xpEarned,
    required this.answers,
    required this.completedAt,
  });

  double get percentage =>
      totalQuestions > 0 ? correctAnswers / totalQuestions : 0.0;

  bool get isPassing => percentage >= 0.7;

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    final answerList = (json['answers'] as List<dynamic>? ?? [])
        .map((e) => UserAnswer.fromJson(e as Map<String, dynamic>))
        .toList();

    return QuizResult(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      lessonId: json['lessonId'] as String? ?? '',
      totalQuestions: json['totalQuestions'] as int? ?? 0,
      correctAnswers: json['correctAnswers'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      xpEarned: json['xpEarned'] as int? ?? 0,
      answers: answerList,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lessonId': lessonId,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'score': score,
      'xpEarned': xpEarned,
      'answers': answers.map((a) => a.toJson()).toList(),
      'completedAt': completedAt.toIso8601String(),
    };
  }
}
