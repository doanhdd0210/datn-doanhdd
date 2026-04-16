class QaAnswer {
  final String id;
  final String postId;
  final String content;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final int upvotes;
  final bool isAccepted;
  final DateTime createdAt;

  const QaAnswer({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.upvotes,
    required this.isAccepted,
    required this.createdAt,
  });

  factory QaAnswer.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;

    return QaAnswer(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      authorId: author?['_id'] as String? ?? json['authorId'] as String? ?? '',
      authorName: author?['name'] as String? ?? json['authorName'] as String? ?? 'Unknown',
      authorAvatar: author?['avatar'] as String? ?? json['authorAvatar'] as String? ?? '',
      upvotes: json['upvotes'] as int? ?? 0,
      isAccepted: json['isAccepted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
