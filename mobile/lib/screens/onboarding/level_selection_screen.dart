import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../main_navigation_screen.dart';
import 'placement_test_screen.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedLevel;
  late AnimationController _controller;

  static const _levels = [
    _LevelData(
      id: 'beginner',
      emoji: '🌱',
      title: 'Beginner',
      subtitle: "I'm new to Java",
      description: 'Start from the very basics — variables, loops, and simple programs.',
      color: AppColors.primary,
      shadowColor: AppColors.primaryDark,
      bgColor: AppColors.surface,
      unlockedTopics: 2,
    ),
    _LevelData(
      id: 'intermediate',
      emoji: '⚡',
      title: 'Intermediate',
      subtitle: 'I know some Java',
      description: 'Skip the basics. Dive into OOP, collections, and design patterns.',
      color: AppColors.secondary,
      shadowColor: AppColors.secondaryLight,
      bgColor: AppColors.surface,
      unlockedTopics: 4,
    ),
    _LevelData(
      id: 'advanced',
      emoji: '🔥',
      title: 'Advanced',
      subtitle: 'I code Java regularly',
      description: 'Go straight to algorithms, concurrency, and advanced Java features.',
      color: AppColors.streakOrange,
      shadowColor: Color(0xFFCC6600),
      bgColor: AppColors.surface,
      unlockedTopics: 999,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_selectedLevel == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    await prefs.setString('user_level', _selectedLevel!);
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
              child: Column(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  const Text(
                    'What\'s your Java level?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We\'ll unlock the right lessons for you',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textGray,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Level cards
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                itemCount: _levels.length,
                itemBuilder: (context, i) {
                  final level = _levels[i];
                  final isSelected = _selectedLevel == level.id;
                  return _LevelCard(
                    level: level,
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedLevel = level.id),
                    delay: i * 100,
                    controller: _controller,
                  );
                },
              ),
            ),

            // Bottom actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                children: [
                  // Confirm button
                  AnimatedOpacity(
                    opacity: _selectedLevel != null ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: _selectedLevel != null ? _confirm : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.primaryDark,
                              offset: Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: const Text(
                          'START LEARNING',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Placement test option
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PlacementTestScreen()),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text('📝', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Text(
                            'Take a placement test instead',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final _LevelData level;
  final bool isSelected;
  final VoidCallback onTap;
  final int delay;
  final AnimationController controller;

  const _LevelCard({
    required this.level,
    required this.isSelected,
    required this.onTap,
    required this.delay,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? level.color.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? level.color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Emoji circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected ? level.color : AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(level.emoji,
                    style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        level.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: isSelected ? level.color : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: level.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          level.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: level.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textGray,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Check
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Icon(Icons.check_circle_rounded,
                      key: const ValueKey('checked'),
                      color: level.color,
                      size: 26)
                  : Icon(Icons.circle_outlined,
                      key: const ValueKey('unchecked'),
                      color: AppColors.border,
                      size: 26),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelData {
  final String id;
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final Color shadowColor;
  final Color bgColor;
  final int unlockedTopics;

  const _LevelData({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.shadowColor,
    required this.bgColor,
    required this.unlockedTopics,
  });
}
