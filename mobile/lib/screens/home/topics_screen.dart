import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';
import '../../models/topic.dart';
import '../../models/lesson.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import 'lesson_detail_screen.dart';
import 'lessons_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../providers/network_retry_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/football_refresh_indicator.dart';

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
  bool _isRetrying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NetworkRetryProvider>().addListener(_onNetworkRetry);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<UserProvider>();
    if (provider.dailyGoalJustReached) {
      provider.consumeDailyGoalReached();
    }
  }

  void _onNetworkRetry() {
    if (mounted) _loadData();
  }

  @override
  void dispose() {
    context.read<NetworkRetryProvider>().removeListener(_onNetworkRetry);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _isRetrying = false;
      _hasError = false;
    });
    try {
      final topics = await _api.getTopics();
      if (!mounted) return;
      _onTopicsLoaded(topics);
    } catch (_) {
      if (!mounted) return;
      // Lần đầu fail → tự động retry sau 5s (cover cold start Render)
      setState(() {
        _isLoading = false;
        _isRetrying = true;
      });
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      try {
        final topics = await _api.getTopics();
        if (!mounted) return;
        setState(() => _isRetrying = false);
        _onTopicsLoaded(topics);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isRetrying = false;
          _hasError = true;
        });
      }
    }
  }

  void _onTopicsLoaded(List<Topic> topics) {
    setState(() {
      _topics = topics;
      _isLoading = false;
      _isRetrying = false;
    });
    context.read<UserProvider>().loadLevel();
    context.read<UserProvider>().loadTopicProgress();
    context.read<UserProvider>().loadStats();
    _loadAllLessons(topics);
  }

  void _goToProfile(BuildContext context) {
    NotificationService().navigationRequests.add('profile');
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    if (provider.dailyGoalJustReached) {
      provider.consumeDailyGoalReached();
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: context.bgColor,
          body: SafeArea(
            child: FootballRefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(child: _buildStreakBanner()),
                  SliverToBoxAdapter(child: _buildDailyGoalBanner()),
                  if (_isLoading)
                    const SliverToBoxAdapter(child: _PathShimmer())
                  else if (_isRetrying)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildRetryingState(),
                    )
                  else if (_hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildErrorState(),
                    )
                  else
                    SliverToBoxAdapter(
                      child: _SkillPath(
                        topics: _topics,
                        topicLessons: _topicLessons,
                        onTopicTap: (topic) => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => LessonsScreen(topic: topic)),
                        ),
                        onLessonTap: (topic, lesson) => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LessonDetailScreen(
                                lesson: lesson, topic: topic),
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
      ],
    );
  }

  Widget _buildRetryingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Server đang khởi động...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Đang thử kết nối lại, vui lòng chờ.',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: context.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Không tải được dữ liệu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kiểm tra kết nối mạng và thử lại.',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Text('⚽', style: TextStyle(fontSize: 16)),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;
    return Consumer<UserProvider>(builder: (context, provider, _) {
      final subProvider = context.watch<SubscriptionProvider>();
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _goToProfile(context),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: subProvider.isMax
                          ? const LinearGradient(
                              colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : subProvider.isStandard
                              ? const LinearGradient(
                                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: context.surfaceColor,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        child: user?.photoURL != null
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: user!.photoURL!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Text(
                                    (user.displayName ?? 'J').substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16),
                                  ),
                                ),
                              )
                            : Text(
                                (user?.displayName ?? 'J').substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16),
                              ),
                      ),
                    ),
                  ),
                  // Level badge — bottom right
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.xpGold,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.surfaceColor, width: 1.5),
                      ),
                      child: Text(
                        'Lv.${(provider.totalXp / 100).floor() + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ),
                  // VIP crown badge — top left
                  if (subProvider.isPremium)
                    Positioned(
                      top: -2,
                      left: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: subProvider.isMax
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFFD97706),
                          shape: BoxShape.circle,
                          border: Border.all(color: context.surfaceColor, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            subProvider.isMax ? '👑' : '⭐',
                            style: const TextStyle(fontSize: 8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _goToProfile(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.displayName ?? '',
                        style: AppTextStyles.heading4,
                        overflow: TextOverflow.ellipsis),
                    _LevelSubtitle(level: provider.level),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StatChip(
                icon: '🔥',
                value: provider.streak.toString(),
                color: AppColors.streakOrange),
            const SizedBox(width: 8),
            _StatChip(
                icon: '⚡',
                value: provider.totalXp.toString(),
                color: AppColors.xpGold),
            const SizedBox(width: 8),
            _NotifBell(),
          ],
        ),
      );
    });
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
            border:
                Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
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
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.accentGold)),
                    Text('Duy trì nhé — quay lại vào ngày mai!',
                        style: TextStyle(
                            fontSize: 12, color: context.textSecondary)),
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
        final claimed = provider.dailyGoalBonusClaimedToday;
        final bonus = provider.bonusForGoal(provider.dailyGoal);
        String headerText;
        if (claimed) {
          headerText = '🎯 Đã nhận thưởng hôm nay!';
        } else if (reached) {
          headerText = '🎯 Mục tiêu hôm nay đạt rồi!';
        } else {
          headerText = '🎯 Mục tiêu hôm nay';
        }
        final headerColor =
            (reached || claimed) ? AppColors.correct : context.textDark;
        return GestureDetector(
          onTap: () => _showGoalPicker(context, provider),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (reached || claimed)
                    ? AppColors.correct.withValues(alpha: 0.4)
                    : context.borderColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      headerText,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: headerColor),
                    ),
                    const Spacer(),
                    Text(
                      '${provider.todayXp} / ${provider.dailyGoal} XP',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: (reached || claimed)
                              ? AppColors.correct
                              : AppColors.xpGold),
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
                    valueColor: AlwaysStoppedAnimation(
                      (reached || claimed)
                          ? AppColors.correct
                          : AppColors.primary,
                    ),
                  ),
                ),
                if ((reached || claimed) && bonus > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    claimed
                        ? '⚡ +$bonus XP thưởng đã nhận'
                        : '⚡ +$bonus XP thưởng',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.xpGold),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGoalPicker(BuildContext context, UserProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Consumer<UserProvider>(
          builder: (_, provider, __) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chọn mục tiêu hằng ngày',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: context.textDark)),
                    if (provider.isDailyGoalReached ||
                        provider.dailyGoalBonusClaimedToday) ...[
                      const SizedBox(height: 6),
                      Text(
                        provider.dailyGoalBonusClaimedToday
                            ? 'Bạn đã nhận thưởng hôm nay. Thưởng tiếp theo vào ngày mai.'
                            : 'Bạn đã đạt mục tiêu hôm nay. Có thể đổi mục tiêu từ ngày mai.',
                        style: TextStyle(
                            fontSize: 12, color: context.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ...provider.dailyGoalOptions.map((g) {
                      final isSelected = provider.dailyGoal == g;
                      final bonus = provider.bonusForGoal(g);
                      final disabled = provider.isDailyGoalReached ||
                          provider.dailyGoalBonusClaimedToday;
                      return GestureDetector(
                        onTap: disabled
                            ? null
                            : () {
                                provider.setDailyGoal(g);
                                Navigator.pop(context);
                              },
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: disabled
                                ? context.surfaceElevatedColor
                                    .withValues(alpha: 0.5)
                                : isSelected
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : context.surfaceElevatedColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: disabled
                                  ? context.borderColor.withValues(alpha: 0.4)
                                  : isSelected
                                      ? AppColors.primary
                                      : context.borderColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('⚡ $g XP / ngày',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: disabled
                                                ? context.textSecondary
                                                : isSelected
                                                    ? AppColors.primary
                                                    : context.textDark)),
                                    if (bonus > 0)
                                      Text('Thưởng khi đạt: +$bonus XP',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: disabled
                                                  ? context.textSecondary
                                                  : AppColors.xpGold)),
                                  ],
                                ),
                              ),
                              if (isSelected && !disabled)
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.primary, size: 20),
                              if (isSelected && disabled)
                                Icon(Icons.check_circle_rounded,
                                    color: context.textSecondary, size: 20),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              )),
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
  static const List<double> _xPattern = [
    0.5,
    0.67,
    0.78,
    0.67,
    0.5,
    0.33,
    0.22,
    0.33
  ];

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

            // Số topic được mở sẵn theo level
            final preUnlocked = switch (provider.level) {
              'advanced' => 3,
              'intermediate' => 2,
              _ => 1,
            };

            for (int ti = 0; ti < topics.length; ti++) {
              final topic = topics[ti];
              final color = _topicColor(topic, ti);
              final completed = provider.topicCompletedCount(topic.id);
              final total = topic.totalLessons.clamp(1, 999);

              // Unlock: pre-unlock theo level, sau đó progressive (hoàn thành topic trước)
              bool isUnlocked;
              if (ti < preUnlocked) {
                isUnlocked = true;
              } else {
                final prevTopic = topics[ti - 1];
                final prevCompleted =
                    provider.topicCompletedCount(prevTopic.id);
                final prevTotal = prevTopic.totalLessons.clamp(1, 999);
                isUnlocked = prevCompleted >= prevTotal;
              }

              // Topic banner
              rows.add(_TopicBanner(
                topic: topic,
                topicIndex: ti,
                color: color,
                isUnlocked: isUnlocked,
                onTap: isUnlocked
                    ? () => onTopicTap(topic)
                    : () {
                        final prevTitle = topics[ti - 1].title;
                        AppSnackBar.warning(context,
                            '🔒 Hoàn thành "$prevTitle" trước để mở khoá chủ đề này!');
                      },
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
      child: Opacity(
        opacity: isUnlocked ? 1.0 : 0.55,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: Color.lerp(color, Colors.black, 0.35)!,
                      blurRadius: 0,
                      offset: const Offset(0, 5),
                    )
                  ]
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
                        color:
                            isUnlocked ? Colors.white70 : context.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          isUnlocked ? topic.icon : '🔒',
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            topic.title,
                            style: TextStyle(
                              color: isUnlocked
                                  ? Colors.white
                                  : context.textSecondary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (!isUnlocked) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Hoàn thành chủ đề trước để mở khoá',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? Colors.white.withValues(alpha: 0.2)
                      : context.borderColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isUnlocked
                      ? Icons.format_list_bulleted_rounded
                      : Icons.lock_rounded,
                  color: isUnlocked ? Colors.white : context.textTertiary,
                  size: 20,
                ),
              ),
            ],
          ),
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
    final charVisible =
        isCurrent && charLeft >= 0 && charLeft + 40 <= screenWidth;

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
    final isDarkMode = context.isDark;
    final bg = isActive
        ? color
        : isLocked
            ? (isDarkMode ? const Color(0xFF252535) : const Color(0xFFE2E5F0))
            : (isDarkMode ? const Color(0xFF2E2E42) : const Color(0xFFD4D9EA));
    final iconColor = isActive
        ? Colors.white
        : (isDarkMode ? context.textTertiary : context.textSecondary);
    final shadowColor = isActive
        ? Color.lerp(color, Colors.black, isDarkMode ? 0.38 : 0.25)!
        : Colors.black.withValues(alpha: isDarkMode ? 0.45 : 0.10);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.7)
        : color.withValues(alpha: 0.8);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: isCurrent
            ? Border.all(color: borderColor, width: 3.5)
            : (!isActive && !isDarkMode)
                ? Border.all(color: const Color(0xFFCBD0E0), width: 1.5)
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

class _PathShimmer extends StatefulWidget {
  const _PathShimmer();

  @override
  State<_PathShimmer> createState() => _PathShimmerState();
}

class _PathShimmerState extends State<_PathShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const positions = [0.5, 0.67, 0.78, 0.67, 0.5];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Opacity(
          opacity: _pulse.value,
          child: Column(
            children: List.generate(5, (i) {
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
                          child: const SizedBox(
                            width: 72,
                            height: 72,
                            child: Center(
                              child: Text('⚽', style: TextStyle(fontSize: 40)),
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
        ),
      ),
    );
  }
}

// ─── Level Chip ───────────────────────────────────────────────────────────────

class _LevelSubtitle extends StatelessWidget {
  final String level;
  const _LevelSubtitle({required this.level});

  @override
  Widget build(BuildContext context) {
    const labels = {
      'beginner': ('🌱', 'Người mới bắt đầu', AppColors.correct),
      'intermediate': ('🪴', 'Trung cấp', AppColors.correct),
      'advanced': ('🌳', 'Nâng cao', AppColors.correct),
    };
    final entry = labels[level] ?? labels['beginner']!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(entry.$1, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 3),
        Text(
          entry.$2,
          style: TextStyle(
              fontSize: 12, color: entry.$3, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Stat Chip ───────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String icon;
  final String value;
  final Color color;

  const _StatChip(
      {required this.icon, required this.value, required this.color});

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
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 14)),
        ],
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
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _notifSub;

  @override
  void initState() {
    super.initState();
    _fetchCount();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchCount());
    _notifSub =
        NotificationService().dataMessages.stream.listen((_) => _fetchCount());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notifSub?.cancel();
    super.dispose();
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
            width: 36,
            height: 36,
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
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.bgColor, width: 1.5),
                ),
                child: Text(
                  _unread > 9 ? '9+' : '$_unread',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
