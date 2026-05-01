import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final Color color;
  final String conditionType;
  final int conditionValue;
  final int xpReward;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
    required this.conditionType,
    required this.conditionValue,
    required this.xpReward,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  /// Color theo conditionType — chỉ thứ duy nhất hardcode ở mobile
  static Color colorForType(String conditionType) {
    switch (conditionType) {
      case 'lessonCount':  return const Color(0xFF6949FF);
      case 'xpRequired':  return const Color(0xFFFFC107);
      case 'streakDays':  return const Color(0xFFFF5722);
      case 'perfectQuiz': return const Color(0xFF4CAF50);
      case 'followAny':   return const Color(0xFF50B0FF);
      default:            return const Color(0xFF9E9E9E);
    }
  }

  factory Achievement.fromJson(Map<String, dynamic> json) {
    final conditionType = json['conditionType'] as String? ?? '';
    return Achievement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      emoji: json['icon'] as String? ?? '🏅',
      color: colorForType(conditionType),
      conditionType: conditionType,
      conditionValue: json['conditionValue'] as int? ?? 0,
      xpReward: json['xpReward'] as int? ?? 0,
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.tryParse(json['unlockedAt'] as String)
          : null,
    );
  }

  Achievement copyWith({bool? isUnlocked, DateTime? unlockedAt}) => Achievement(
    id: id,
    title: title,
    description: description,
    emoji: emoji,
    color: color,
    conditionType: conditionType,
    conditionValue: conditionValue,
    xpReward: xpReward,
    isUnlocked: isUnlocked ?? this.isUnlocked,
    unlockedAt: unlockedAt ?? this.unlockedAt,
  );
}
