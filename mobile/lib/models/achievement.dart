import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final Color color;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
  });
}

const List<Achievement> kAchievements = [
  Achievement(
    id: 'first_lesson',
    title: 'Bước đầu tiên',
    description: 'Hoàn thành bài học đầu tiên',
    emoji: '🎓',
    color: Color(0xFF304FFE),
  ),
  Achievement(
    id: 'lessons_10',
    title: 'Chăm học',
    description: 'Hoàn thành 10 bài học',
    emoji: '📚',
    color: Color(0xFF6949FF),
  ),
  Achievement(
    id: 'lessons_25',
    title: 'Tiến sĩ',
    description: 'Hoàn thành 25 bài học',
    emoji: '🏅',
    color: Color(0xFFFFC107),
  ),
  Achievement(
    id: 'xp_100',
    title: 'Tập sự',
    description: 'Kiếm được 100 XP',
    emoji: '⚡',
    color: Color(0xFFFFC107),
  ),
  Achievement(
    id: 'xp_500',
    title: 'Thành thạo',
    description: 'Kiếm được 500 XP',
    emoji: '🔥',
    color: Color(0xFFFF9800),
  ),
  Achievement(
    id: 'xp_1000',
    title: 'Chuyên gia',
    description: 'Kiếm được 1000 XP',
    emoji: '💎',
    color: Color(0xFF00BCD4),
  ),
  Achievement(
    id: 'streak_3',
    title: 'Kiên trì',
    description: 'Học 3 ngày liên tiếp',
    emoji: '🔥',
    color: Color(0xFFFF5722),
  ),
  Achievement(
    id: 'streak_7',
    title: 'Tuần lễ vàng',
    description: 'Học 7 ngày liên tiếp',
    emoji: '🏆',
    color: Color(0xFFFFC107),
  ),
  Achievement(
    id: 'quiz_perfect',
    title: 'Hoàn hảo',
    description: 'Đạt 100% trong một bài quiz',
    emoji: '🎯',
    color: Color(0xFF4CAF50),
  ),
  Achievement(
    id: 'social_1',
    title: 'Kết nối',
    description: 'Theo dõi người đầu tiên',
    emoji: '👥',
    color: Color(0xFF50B0FF),
  ),
];

/// Check which achievements are unlocked based on user stats
Set<String> computeUnlocked({
  required int lessonsCompleted,
  required int totalXp,
  required int streak,
  required bool hasPerfectQuiz,
  required bool hasFollowed,
}) {
  final unlocked = <String>{};
  if (lessonsCompleted >= 1) unlocked.add('first_lesson');
  if (lessonsCompleted >= 10) unlocked.add('lessons_10');
  if (lessonsCompleted >= 25) unlocked.add('lessons_25');
  if (totalXp >= 100) unlocked.add('xp_100');
  if (totalXp >= 500) unlocked.add('xp_500');
  if (totalXp >= 1000) unlocked.add('xp_1000');
  if (streak >= 3) unlocked.add('streak_3');
  if (streak >= 7) unlocked.add('streak_7');
  if (hasPerfectQuiz) unlocked.add('quiz_perfect');
  if (hasFollowed) unlocked.add('social_1');
  return unlocked;
}
