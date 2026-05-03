import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Single source of truth for level data.
/// Used by level_selection_screen and placement_test_screen.
class LevelConfig {
  final String id;
  final String emoji;
  final Color color;
  final Color shadowColor;
  final Color bgColor;
  final int unlockedTopics;

  // level_selection_screen fields
  final String selectionTitle;
  final String selectionSubtitle;
  final String description;

  // placement_test_screen result fields
  final String resultTitle;
  final String resultSubtitle;
  final String levelLabel;
  final String unlockText;

  const LevelConfig({
    required this.id,
    required this.emoji,
    required this.color,
    required this.shadowColor,
    required this.bgColor,
    required this.unlockedTopics,
    required this.selectionTitle,
    required this.selectionSubtitle,
    required this.description,
    required this.resultTitle,
    required this.resultSubtitle,
    required this.levelLabel,
    required this.unlockText,
  });

  static const List<LevelConfig> levels = [
    LevelConfig(
      id: 'beginner',
      emoji: '🌱',
      color: AppColors.primary,
      shadowColor: AppColors.primaryDark,
      bgColor: AppColors.surface,
      unlockedTopics: 1,
      selectionTitle: 'Mới bắt đầu',
      selectionSubtitle: 'Tôi mới học Java',
      description: 'Bắt đầu từ nền tảng cơ bản nhất — biến, vòng lặp và các chương trình đơn giản.',
      resultTitle: 'Bạn đang ở trình độ cơ bản!',
      resultSubtitle: 'Không sao cả — ai cũng phải bắt đầu từ đâu đó. Chúng tôi sẽ xây dựng nền tảng cho bạn từng bước.',
      levelLabel: 'Lộ trình cơ bản',
      unlockText: 'Bắt đầu từ bài học đầu tiên',
    ),
    LevelConfig(
      id: 'intermediate',
      emoji: '🪴',
      color: AppColors.secondary,
      shadowColor: AppColors.secondaryLight,
      bgColor: AppColors.surface,
      unlockedTopics: 2,
      selectionTitle: 'Trung cấp',
      selectionSubtitle: 'Tôi biết một chút Java',
      description: 'Bỏ qua phần cơ bản. Lao vào OOP, collections và design patterns.',
      resultTitle: 'Bạn đang ở trình độ trung cấp!',
      resultSubtitle: 'Tuyệt! Bạn đã nắm cơ bản. Chúng tôi sẽ đưa bạn thẳng vào OOP và hơn thế nữa.',
      levelLabel: 'Lộ trình trung cấp',
      unlockText: 'Đã mở khóa 2 chủ đề đầu tiên',
    ),
    LevelConfig(
      id: 'advanced',
      emoji: '🌳',
      color: AppColors.streakOrange,
      shadowColor: Color(0xFFCC6600),
      bgColor: AppColors.surface,
      unlockedTopics: 3,
      selectionTitle: 'Nâng cao',
      selectionSubtitle: 'Tôi đã code Java',
      description: 'Đi thẳng vào algorithms, concurrency và các tính năng Java nâng cao.',
      resultTitle: 'Bạn đang ở trình độ nâng cao!',
      resultSubtitle: 'Ấn tượng! Tất cả chủ đề đã được mở khóa. Bắt tay vào những thứ khó ngay thôi.',
      levelLabel: 'Lộ trình nâng cao',
      unlockText: 'Đã mở khóa 3 chủ đề đầu tiên',
    ),
  ];

  static LevelConfig byId(String id) =>
      levels.firstWhere((l) => l.id == id, orElse: () => levels.first);
}
