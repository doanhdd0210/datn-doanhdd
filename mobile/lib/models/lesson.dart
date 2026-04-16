class Lesson {
  final String id;
  final String topicId;
  final String title;
  final String content;
  final String summary;
  final int order;
  final int xpReward;
  final int estimatedMinutes;
  final bool isActive;

  const Lesson({
    required this.id,
    required this.topicId,
    required this.title,
    required this.content,
    required this.summary,
    required this.order,
    required this.xpReward,
    required this.estimatedMinutes,
    required this.isActive,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      topicId: json['topicId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      xpReward: json['xpReward'] as int? ?? 10,
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 5,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topicId': topicId,
      'title': title,
      'content': content,
      'summary': summary,
      'order': order,
      'xpReward': xpReward,
      'estimatedMinutes': estimatedMinutes,
      'isActive': isActive,
    };
  }

  Lesson copyWith({
    String? id,
    String? topicId,
    String? title,
    String? content,
    String? summary,
    int? order,
    int? xpReward,
    int? estimatedMinutes,
    bool? isActive,
  }) {
    return Lesson(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      title: title ?? this.title,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      order: order ?? this.order,
      xpReward: xpReward ?? this.xpReward,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      isActive: isActive ?? this.isActive,
    );
  }
}
