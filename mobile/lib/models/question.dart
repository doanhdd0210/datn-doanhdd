class Question {
  final String id;
  final String lessonId;
  final String questionText;
  final String explanation;
  final List<String> options;
  final int correctAnswerIndex;
  final int order;
  final int points;

  const Question({
    required this.id,
    required this.lessonId,
    required this.questionText,
    required this.explanation,
    required this.options,
    required this.correctAnswerIndex,
    required this.order,
    required this.points,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final optionsList = (json['options'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return Question(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      lessonId: json['lessonId'] as String? ?? '',
      questionText: json['questionText'] as String? ?? json['question'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      options: optionsList,
      correctAnswerIndex: json['correctAnswerIndex'] as int? ?? json['correctIndex'] as int? ?? 0,
      order: json['order'] as int? ?? 0,
      points: json['points'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lessonId': lessonId,
      'questionText': questionText,
      'explanation': explanation,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'order': order,
      'points': points,
    };
  }
}
