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
  final bool isNew;

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
    this.isNew = false,
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
      authorId: author?['_id'] as String? ?? json['authorId'] as String? ?? json['userId'] as String? ?? '',
      authorName: author?['name'] as String?
          ?? json['authorName'] as String?
          ?? json['userName'] as String?
          ?? '',
      authorAvatar: author?['avatar'] as String?
          ?? json['authorAvatar'] as String?
          ?? json['userAvatar'] as String?
          ?? '',
      tags: tagList,
      lessonId: json['lessonId'] as String?,
      answerCount: json['answerCount'] as int? ?? 0,
      upvotes: json['upvoteCount'] as int? ?? json['upvotes'] as int? ?? 0,
      isSolved: json['isSolved'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isNew: json['isNew'] as bool? ?? false,
    );
  }
}
