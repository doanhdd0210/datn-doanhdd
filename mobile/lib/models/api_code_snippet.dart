/// API-backed CodeSnippet model (different from the local CodeSnippet in models/code_snippet.dart)
class ApiCodeSnippet {
  final String id;
  final String topicId;
  final String title;
  final String description;
  final String code;
  final String language;
  final String expectedOutput;
  final int order;
  final int xpReward;

  const ApiCodeSnippet({
    required this.id,
    required this.topicId,
    required this.title,
    required this.description,
    required this.code,
    required this.language,
    required this.expectedOutput,
    required this.order,
    required this.xpReward,
  });

  factory ApiCodeSnippet.fromJson(Map<String, dynamic> json) {
    return ApiCodeSnippet(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      topicId: json['topicId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      code: json['code'] as String? ?? '',
      language: json['language'] as String? ?? 'java',
      expectedOutput: json['expectedOutput'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      xpReward: json['xpReward'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topicId': topicId,
      'title': title,
      'description': description,
      'code': code,
      'language': language,
      'expectedOutput': expectedOutput,
      'order': order,
      'xpReward': xpReward,
    };
  }
}
