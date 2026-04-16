class QaPost {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final List<String> tags;
  final String? lessonId;
  final int answerCount;
  final int upvotes;
  final bool isSolved;
  final DateTime createdAt;

  const QaPost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.tags,
    this.lessonId,
    required this.answerCount,
    required this.upvotes,
    required this.isSolved,
    required this.createdAt,
  });

  factory QaPost.fromJson(Map<String, dynamic> json) {
    final tagList = (json['tags'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    final author = json['author'] as Map<String, dynamic>?;

    return QaPost(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      authorId: author?['_id'] as String? ?? json['authorId'] as String? ?? '',
      authorName: author?['name'] as String? ?? json['authorName'] as String? ?? 'Unknown',
      authorAvatar: author?['avatar'] as String? ?? json['authorAvatar'] as String? ?? '',
      tags: tagList,
      lessonId: json['lessonId'] as String?,
      answerCount: json['answerCount'] as int? ?? 0,
      upvotes: json['upvotes'] as int? ?? 0,
      isSolved: json['isSolved'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
