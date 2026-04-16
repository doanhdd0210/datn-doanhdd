class Topic {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String color;
  final int order;
  final int totalLessons;
  final bool isActive;

  const Topic({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.order,
    required this.totalLessons,
    required this.isActive,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '📚',
      color: json['color'] as String? ?? '#58CC02',
      order: json['order'] as int? ?? 0,
      totalLessons: json['totalLessons'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'color': color,
      'order': order,
      'totalLessons': totalLessons,
      'isActive': isActive,
    };
  }

  Topic copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    String? color,
    int? order,
    int? totalLessons,
    bool? isActive,
  }) {
    return Topic(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      order: order ?? this.order,
      totalLessons: totalLessons ?? this.totalLessons,
      isActive: isActive ?? this.isActive,
    );
  }
}
