import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';
import '../../models/topic.dart';
import '../../models/lesson.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import 'lesson_detail_screen.dart';
import 'lessons_screen.dart';
import '../notifications/notifications_screen.dart';

class TopicsScreen extends StatefulWidget {
  const TopicsScreen({super.key});

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  final _api = ApiService();
  List<Topic> _topics = [];
  final Map<String, List<Lesson>> _topicLessons = {};
  bool _isLoading = true;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<UserProvider>();
    if (provider.dailyGoalJustReached) {
      provider.consumeDailyGoalReached();
      final bonus = provider.pendingBonusXp;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGoalReachedPopup(bonus);
      });
    }
  }

  void _showGoalReachedPopup(int bonusXp) {
    _confettiController.play();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DailyGoalPopup(
        bonusXp: bonusXp,
        confettiController: _confettiController,
        onClose: () {
          _confettiController.stop();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final topics = await _api.getTopics();
      if (mounted) {
        setState(() {
          _topics = topics;
          _isLoading = false;
        });
        context.read<UserProvider>().loadLevel();
        context.read<UserProvider>().loadTopicProgress();
        context.read<UserProvider>().loadStats();
        _loadAllLessons(topics);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _topics = _mockTopics();
        });
      }
    }
  }

  Future<void> _loadAllLessons(List<Topic> topics) async {
    for (final topic in topics) {
      try {
        final lessons = await _api.getLessonsByTopic(topic.id);
        if (mounted) {
          setState(() => _topicLessons[topic.id] = lessons);
        }
      } catch (_) {}
    }
  }

  List<Topic> _mockTopics() {
    return [
      const Topic(id: 'mock1', title: 'Java Basics', description: 'Biến, kiểu dữ liệu, toán tử', icon: '☕', color: '#58CC02', order: 1, totalLessons: 8, isActive: true),
      const Topic(id: 'mock2', title: 'Object-Oriented', description: 'Lớp, đối tượng, kế thừa', icon: '🏗️', color: '#1CB0F6', order: 2, totalLessons: 10, isActive: true),
      const Topic(id: 'mock3', title: 'Data Structures', description: 'Mảng, danh sách, ngăn xếp', icon: '📊', color: '#FF9600', order: 3, totalLessons: 12, isActive: true),
      const Topic(id: 'mock4', title: 'Algorithms', description: 'Sắp xếp, tìm kiếm, đệ quy', icon: '🔄', color: '#CE82FF', order: 4, totalLessons: 8, isActive: true),
      const Topic(id: 'mock5', title: 'Exception Handling', description: 'Try-catch, ngoại lệ tùy chỉnh', icon: '⚠️', color: '#FF4B4B', order: 5, totalLessons: 6, isActive: true),
      const Topic(id: 'mock6', title: 'Collections & Streams', description: 'Collections Framework', icon: '🌊', color: '#00CD9C', order: 6, totalLessons: 10, isActive: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Listen for async goal-reached event (fired after API claim returns)
    final provider = context.watch<UserProvider>();
    if (provider.dailyGoalJustReached) {
      provider.consumeDailyGoalReached();
      final bonus = provider.pendingBonusXp;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGoalReachedPopup(bonus);
      });
    }

    return Stack(
      children: [
        Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildStreakBanner()),
              SliverToBoxAdapter(child: _buildDailyGoalBanner()),
              if (_isLoading)
                const SliverToBoxAdapter(child: _PathShimmer())
              else
                SliverToBoxAdapter(
                  child: _SkillPath(
                    topics: _topics,
                    topicLessons: _topicLessons,
                    onTopicTap: (topic) => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => LessonsScreen(topic: topic)),
                    ),
                    onLessonTap: (topic, lesson) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LessonDetailScreen(lesson: lesson, topic: topic),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
        ),
        // Confetti overlay — positioned at top center
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.05,
            numberOfParticles: 25,
            gravity: 0.3,
            colors: const [
              AppColors.primary,
              AppColors.xpGold,
              AppColors.correct,
              Colors.pink,
              Colors.purple,
              Colors.orange,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;
    return Consumer<UserProvider>(
      builder: (context, provider, _) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        color: context.bgColor,
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: user?.photoURL != null ? CachedNetworkImageProvider(user!.photoURL!) : null,
              backgroundColor: AppColors.primary.withValues(alpha: 0.25),
              child: user?.photoURL == null
                  ? Text(
                      (user?.displayName ?? 'J').substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.displayName ?? '', style: AppTextStyles.heading4, overflow: TextOverflow.ellipsis),
                  Text(user?.email ?? 'Tiếp tục học mỗi ngày!', style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            _LevelChip(level: provider.level),
            const SizedBox(width: 8),
            _StatChip(icon: '🔥', value: provider.streak.toString(), color: AppColors.streakOrange),
            const SizedBox(width: 8),
            _StatChip(icon: '⚡', value: provider.totalXp.toString(), color: AppColors.xpGold),
            const SizedBox(width: 8),
            _NotifBell(),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakBanner() {
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        if (provider.streak == 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.accentGold.withValues(alpha: 0.15),
              AppColors.streakOrange.withValues(alpha: 0.1),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${provider.streak} ngày liên tiếp!',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.accentGold)),
                    const Text('Duy trì nhé — quay lại vào ngày mai!',
                        style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyGoalBanner() {
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        final reached = provider.isDailyGoalReached;
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: reached ? AppColors.correct.withValues(alpha: 0.4) : context.borderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    reached ? '🎯 Mục tiêu hôm nay đạt rồi!' : '🎯 Mục tiêu hôm nay',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                        color: reached ? AppColors.correct : AppColors.textDark),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showGoalPicker(context, provider),
                    child: Text(
                      '${provider.todayXp} / ${provider.dailyGoal} XP',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
                          color: reached ? AppColors.correct : AppColors.xpGold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: provider.dailyGoalProgress,
                  minHeight: 8,
                  backgroundColor: context.borderColor,
                  valueColor: AlwaysStoppedAnimation(reached ? AppColors.correct : AppColors.primary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGoalPicker(BuildContext context, UserProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn mục tiêu hằng ngày',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
            const SizedBox(height: 16),
            ...UserProvider.dailyGoalOptions.map((g) {
              final isSelected = provider.dailyGoal == g;
              return GestureDetector(
                onTap: () { provider.setDailyGoal(g); Navigator.pop(context); },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : context.surfaceElevatedColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? AppColors.primary : context.borderColor),
                  ),
                  child: Row(
                    children: [
                      Text('⚡ $g XP / ngày',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                              color: isSelected ? AppColors.primary : AppColors.textDark)),
                      const Spacer(),
                      if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Skill Path ───────────────────────────────────────────────────────────────

class _SkillPath extends StatelessWidget {
  final List<Topic> topics;
  final Map<String, List<Lesson>> topicLessons;
  final ValueChanged<Topic> onTopicTap;
  final void Function(Topic, Lesson) onLessonTap;

  const _SkillPath({
    required this.topics,
    required this.topicLessons,
    required this.onTopicTap,
    required this.onLessonTap,
  });

  // Zigzag x positions as fraction (0=leftmost, 1=rightmost within margins)
  static const List<double> _xPattern = [0.5, 0.67, 0.78, 0.67, 0.5, 0.33, 0.22, 0.33];

  Color _topicColor(Topic topic, int index) {
    if (topic.color.startsWith('#')) {
      try {
        return Color(int.parse('FF${topic.color.substring(1)}', radix: 16));
      } catch (_) {}
    }
    return AppColors.topicColors[index % AppColors.topicColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final List<Widget> rows = [];
            int globalIdx = 0;

            for (int ti = 0; ti < topics.length; ti++) {
              final topic = topics[ti];
              final color = _topicColor(topic, ti);
              final isUnlocked = ti < provider.unlockedTopicCount;
              final completed = provider.topicCompletedCount(topic.id);
              final total = topic.totalLessons.clamp(1, 999);

              // Topic banner
              rows.add(_TopicBanner(
                topic: topic,
                topicIndex: ti,
                color: color,
                isUnlocked: isUnlocked,
                onTap: isUnlocked ? () => onTopicTap(topic) : null,
              ));

              // Lesson nodes
              final lessons = topicLessons[topic.id] ?? [];
              for (int li = 0; li < total; li++) {
                final isDone = isUnlocked && li < completed;
                final isCurrent = isUnlocked && li == completed;
                final xFrac = _xPattern[globalIdx % _xPattern.length];
                final lesson = li < lessons.length ? lessons[li] : null;

                rows.add(_LessonNodeRow(
                  xFraction: xFrac,
                  screenWidth: width,
                  isDone: isDone,
                  isCurrent: isCurrent,
                  isTopicLocked: !isUnlocked,
                  color: color,
                  iconIndex: globalIdx,
                  onTap: lesson != null
                      ? () => onLessonTap(topic, lesson)
                      : () => onTopicTap(topic),
                ));
                globalIdx++;
              }

              // Divider between topics
              if (ti < topics.length - 1) {
                rows.add(const SizedBox(height: 4));
                rows.add(_SectionDivider(nextTopic: topics[ti + 1]));
                rows.add(const SizedBox(height: 4));
              }
            }

            return Column(children: rows);
          },
        );
      },
    );
  }
}

// ─── Topic Banner ─────────────────────────────────────────────────────────────

class _TopicBanner extends StatelessWidget {
  final Topic topic;
  final int topicIndex;
  final Color color;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const _TopicBanner({
    required this.topic,
    required this.topicIndex,
    required this.color,
    required this.isUnlocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isUnlocked ? color : context.surfaceElevatedColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isUnlocked
              ? [BoxShadow(
                  color: Color.lerp(color, Colors.black, 0.35)!,
                  blurRadius: 0,
                  offset: const Offset(0, 5),
                )]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHỦ ĐỀ ${topicIndex + 1}',
                    style: TextStyle(
                      color: isUnlocked ? Colors.white70 : context.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(topic.icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          topic.title,
                          style: TextStyle(
                            color: isUnlocked ? Colors.white : context.textSecondary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isUnlocked ? Colors.white.withValues(alpha: 0.2) : context.borderColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isUnlocked ? Icons.format_list_bulleted_rounded : Icons.lock_rounded,
                color: isUnlocked ? Colors.white : context.textTertiary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Lesson Node Row ──────────────────────────────────────────────────────────

class _LessonNodeRow extends StatelessWidget {
  final double xFraction;
  final double screenWidth;
  final bool isDone;
  final bool isCurrent;
  final bool isTopicLocked;
  final Color color;
  final int iconIndex;
  final VoidCallback? onTap;

  static const double _nodeSize = 72;
  static const double _rowHeight = 100;
  static const List<IconData> _icons = [
    Icons.menu_book_rounded,
    Icons.code_rounded,
    Icons.quiz_rounded,
    Icons.lightbulb_rounded,
    Icons.psychology_rounded,
    Icons.terminal_rounded,
    Icons.extension_rounded,
    Icons.emoji_events_rounded,
  ];

  const _LessonNodeRow({
    required this.xFraction,
    required this.screenWidth,
    required this.isDone,
    required this.isCurrent,
    required this.isTopicLocked,
    required this.color,
    required this.iconIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _icons[iconIndex % _icons.length];
    // Position node within 16px margin on each side
    final usable = screenWidth - 32 - _nodeSize;
    final nodeLeft = 16 + usable * xFraction;
    // Character goes on opposite side of center
    final charOnLeft = xFraction > 0.5;
    final charLeft = charOnLeft ? nodeLeft - 52 : nodeLeft + _nodeSize + 8;
    final charVisible = isCurrent &&
        charLeft >= 0 &&
        charLeft + 40 <= screenWidth;

    return SizedBox(
      height: _rowHeight,
      child: Stack(
        children: [
          Positioned(
            left: nodeLeft,
            top: 8,
            child: GestureDetector(
              onTap: (isDone || isCurrent) && !isTopicLocked ? onTap : null,
              child: Column(
                children: [
                  _NodeCircle(
                    isDone: isDone,
                    isCurrent: isCurrent,
                    isLocked: isTopicLocked,
                    isUpcoming: !isDone && !isCurrent && !isTopicLocked,
                    color: color,
                    icon: icon,
                  ),
                  const SizedBox(height: 6),
                  _StarsRow(isDone: isDone, show: !isTopicLocked),
                ],
              ),
            ),
          ),
          if (charVisible)
            Positioned(
              left: charLeft,
              top: 4,
              child: const Text('☕', style: TextStyle(fontSize: 34)),
            ),
        ],
      ),
    );
  }
}

// ─── Node Circle ─────────────────────────────────────────────────────────────

class _NodeCircle extends StatelessWidget {
  final bool isDone;
  final bool isCurrent;
  final bool isLocked;
  final bool isUpcoming;
  final Color color;
  final IconData icon;

  static const double size = 72;

  const _NodeCircle({
    required this.isDone,
    required this.isCurrent,
    required this.isLocked,
    required this.isUpcoming,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = isDone || isCurrent;
    // Slightly darker bg for locked topic vs upcoming lesson
    final bg = isActive
        ? color
        : isLocked
            ? const Color(0xFF252535)
            : const Color(0xFF2E2E42);
    final iconColor = isActive ? Colors.white : context.textTertiary;
    final shadowColor = isActive
        ? Color.lerp(color, Colors.black, 0.38)!
        : Colors.black.withValues(alpha: 0.45);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: isCurrent
            ? Border.all(color: Colors.white.withValues(alpha: 0.7), width: 3.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 32)
            : isLocked
                ? Icon(Icons.lock_rounded, color: iconColor, size: 24)
                : Icon(icon, color: iconColor, size: 28),
      ),
    );
  }
}

// ─── Stars Row ───────────────────────────────────────────────────────────────

class _StarsRow extends StatelessWidget {
  final bool isDone;
  final bool show;

  const _StarsRow({required this.isDone, required this.show});

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox(height: 14);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Icon(
          isDone ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 13,
          color: isDone
              ? AppColors.xpGold
              : context.textTertiary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ─── Section Divider ─────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  final Topic nextTopic;

  const _SectionDivider({required this.nextTopic});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: context.borderColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              nextTopic.title,
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: context.borderColor)),
        ],
      ),
    );
  }
}

// ─── Path Shimmer ────────────────────────────────────────────────────────────

class _PathShimmer extends StatelessWidget {
  const _PathShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: List.generate(5, (i) {
          final positions = [0.5, 0.67, 0.78, 0.67, 0.5];
          final xFrac = positions[i];
          return LayoutBuilder(
            builder: (context, c) {
              final left = 16 + (c.maxWidth - 32 - 72) * xFrac;
              return SizedBox(
                height: 100,
                child: Stack(
                  children: [
                    Positioned(
                      left: left,
                      top: 8,
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.surfaceElevatedColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ─── Level Chip ───────────────────────────────────────────────────────────────

class _LevelChip extends StatelessWidget {
  final String level;
  const _LevelChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final Map<String, _LevelStyle> styles = {
      'beginner': _LevelStyle('🌱', AppColors.correct, context.surfaceElevatedColor),
      'intermediate': _LevelStyle('⚡', AppColors.accentBlue, context.surfaceElevatedColor),
      'advanced': _LevelStyle('🔥', AppColors.streakOrange, context.surfaceElevatedColor),
    };
    final s = styles[level] ?? styles['beginner']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: s.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 3),
          Text(
            level[0].toUpperCase() + level.substring(1),
            style: TextStyle(color: s.color, fontWeight: FontWeight.w800, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _LevelStyle {
  final String icon;
  final Color color;
  final Color bg;
  const _LevelStyle(this.icon, this.color, this.bg);
}

// ─── Stat Chip ───────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String icon;
  final String value;
  final Color color;

  const _StatChip({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Daily Goal Reached Popup ──────────────────────────────────────────────────

class _DailyGoalPopup extends StatelessWidget {
  final int bonusXp;
  final ConfettiController confettiController;
  final VoidCallback onClose;

  const _DailyGoalPopup({
    required this.bonusXp,
    required this.confettiController,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              'Mục tiêu hoàn thành!',
              style: AppTextStyles.heading2.copyWith(color: AppColors.correct),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đã đạt mục tiêu XP hôm nay.\nCứ tiếp tục như vậy! 💪',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textGray),
              textAlign: TextAlign.center,
            ),
            if (bonusXp > 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      '+$bonusXp XP Thưởng!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.correct,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tuyệt vời! 🎉', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notification Bell ─────────────────────────────────────────────────────────

class _NotifBell extends StatefulWidget {
  @override
  State<_NotifBell> createState() => _NotifBellState();
}

class _NotifBellState extends State<_NotifBell> {
  final _api = ApiService();
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _fetchCount();
  }

  Future<void> _fetchCount() async {
    final count = await _api.getUnreadNotificationCount();
    if (mounted) setState(() => _unread = count);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        _fetchCount();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: context.surfaceColor,
              shape: BoxShape.circle,
              border: Border.all(color: context.borderColor),
            ),
            child: Icon(
              Icons.notifications_rounded,
              size: 18,
              color: _unread > 0 ? AppColors.primary : context.textSecondary,
            ),
          ),
          if (_unread > 0)
            Positioned(
              top: -4, right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.bgColor, width: 1.5),
                ),
                child: Text(
                  _unread > 9 ? '9+' : '$_unread',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
