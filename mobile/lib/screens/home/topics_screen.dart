import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/topic.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import 'lessons_screen.dart';

class TopicsScreen extends StatefulWidget {
  const TopicsScreen({super.key});

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  final _api = ApiService();
  List<Topic> _topics = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final topics = await _api.getTopics();
      if (mounted) {
        setState(() {
          _topics = topics;
          _isLoading = false;
        });
        context.read<UserProvider>().loadTopicProgress();
        context.read<UserProvider>().loadStats();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _topics = _mockTopics();
        });
      }
    }
  }

  List<Topic> _mockTopics() {
    return [
      const Topic(
        id: 'mock1',
        title: 'Java Basics',
        description: 'Variables, data types, operators and control flow',
        icon: '☕',
        color: '#58CC02',
        order: 1,
        totalLessons: 8,
        isActive: true,
      ),
      const Topic(
        id: 'mock2',
        title: 'Object-Oriented',
        description: 'Classes, objects, inheritance and polymorphism',
        icon: '🏗️',
        color: '#1CB0F6',
        order: 2,
        totalLessons: 10,
        isActive: true,
      ),
      const Topic(
        id: 'mock3',
        title: 'Data Structures',
        description: 'Arrays, lists, stacks, queues and maps',
        icon: '📊',
        color: '#FF9600',
        order: 3,
        totalLessons: 12,
        isActive: true,
      ),
      const Topic(
        id: 'mock4',
        title: 'Algorithms',
        description: 'Sorting, searching and recursion',
        icon: '🔄',
        color: '#CE82FF',
        order: 4,
        totalLessons: 8,
        isActive: true,
      ),
      const Topic(
        id: 'mock5',
        title: 'Exception Handling',
        description: 'Try-catch, custom exceptions and best practices',
        icon: '⚠️',
        color: '#FF4B4B',
        order: 5,
        totalLessons: 6,
        isActive: true,
      ),
      const Topic(
        id: 'mock6',
        title: 'Collections & Streams',
        description: 'Java Collections Framework and Stream API',
        icon: '🌊',
        color: '#00CD9C',
        order: 6,
        totalLessons: 10,
        isActive: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildStreakBanner()),
              if (_isLoading)
                SliverToBoxAdapter(child: _buildShimmer())
              else
                SliverToBoxAdapter(
                  child: _SkillPath(
                    topics: _topics,
                    onTopicTap: (topic) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LessonsScreen(topic: topic),
                        ),
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          color: AppColors.background,
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                backgroundColor: AppColors.primary.withOpacity(0.25),
                child: user?.photoURL == null
                    ? Text(
                        (user?.displayName ?? 'J').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Java Learning',
                      style: AppTextStyles.heading3,
                    ),
                    Text(
                      user?.displayName ?? 'Keep learning every day!',
                      style: AppTextStyles.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Level badge
              _LevelChip(level: provider.level),
              const SizedBox(width: 8),
              // Streak badge
              _StatChip(
                icon: '🔥',
                value: provider.streak.toString(),
                color: AppColors.streakOrange,
              ),
              const SizedBox(width: 8),
              // XP badge
              _StatChip(
                icon: '⚡',
                value: provider.totalXp.toString(),
                color: AppColors.xpGold,
              ),
            ],
          ),
        );
      },
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
            gradient: LinearGradient(
              colors: [
                AppColors.accentGold.withOpacity(0.15),
                AppColors.streakOrange.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accentGold.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${provider.streak} Day Streak!',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.accentGold,
                      ),
                    ),
                    const Text(
                      'Keep it up — come back tomorrow!',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: List.generate(3, (i) {
          final isLeft = i % 2 == 0;
          return Padding(
            padding: EdgeInsets.only(
              left: isLeft ? 60 : 0,
              right: isLeft ? 0 : 60,
              bottom: 24,
            ),
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Skill Path Widget ────────────────────────────────────────────────────────

class _SkillPath extends StatelessWidget {
  final List<Topic> topics;
  final ValueChanged<Topic> onTopicTap;

  const _SkillPath({required this.topics, required this.onTopicTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (int i = 0; i < topics.length; i++) ...[
                _buildNodeRow(context, provider, i),
                if (i < topics.length - 1)
                  _PathConnector(isLeft: i % 2 == 0),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNodeRow(
      BuildContext context, UserProvider provider, int index) {
    final topic = topics[index];
    final completed = provider.topicCompletedCount(topic.id);
    final total = topic.totalLessons > 0 ? topic.totalLessons : 1;
    final progress = (completed / total).clamp(0.0, 1.0);

    final isCompleted = progress >= 1.0;
    // Unlock nếu index < unlockedTopicCount theo level
    final levelUnlocked = index < provider.unlockedTopicCount;
    final isCurrent = !isCompleted && levelUnlocked;
    final isLocked = !isCompleted && !levelUnlocked;

    final color = _topicColor(topic, index);
    final shadowColor = AppColors.topicShadowColors[index % AppColors.topicShadowColors.length];

    // Ziczac: even index → node on left side; odd → right side
    final isLeft = index % 2 == 0;

    return Row(
      mainAxisAlignment:
          isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        _SkillNode(
          topic: topic,
          color: isLocked ? AppColors.nodeLocked : color,
          shadowColor: isLocked ? AppColors.nodeShadowLocked : shadowColor,
          progress: progress,
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          isLocked: isLocked,
          onTap: isLocked ? null : () => onTopicTap(topic),
        ),
      ],
    );
  }

  Color _topicColor(Topic topic, int index) {
    if (topic.color.startsWith('#')) {
      try {
        return Color(int.parse('FF${topic.color.substring(1)}', radix: 16));
      } catch (_) {}
    }
    return AppColors.topicColors[index % AppColors.topicColors.length];
  }
}

class _SkillNode extends StatelessWidget {
  final Topic topic;
  final Color color;
  final Color shadowColor;
  final double progress;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLocked;
  final VoidCallback? onTap;

  const _SkillNode({
    required this.topic,
    required this.color,
    required this.shadowColor,
    required this.progress,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // Glow ring for current node
          if (isCurrent)
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
              ),
              child: Center(child: _nodeCircle()),
            )
          else
            _nodeCircle(),
          const SizedBox(height: 8),
          // Topic name
          SizedBox(
            width: 110,
            child: Text(
              topic.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isLocked ? AppColors.textLight : AppColors.textDark,
              ),
            ),
          ),
          // Progress label
          if (!isLocked && !isCompleted) ...[
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
          if (isCompleted) ...[
            const SizedBox(height: 4),
            const Text(
              'Complete!',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _nodeCircle() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isLocked ? AppColors.surfaceElevated : color,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 4),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
        border: isCurrent
            ? Border.all(color: Colors.white, width: 3)
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress arc for in-progress nodes
          if (!isCompleted && !isLocked && progress > 0)
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          // Icon
          Text(
            isCompleted ? '✓' : (isLocked ? '🔒' : topic.icon),
            style: TextStyle(
              fontSize: isCompleted ? 28 : 30,
              color: isCompleted || !isLocked ? Colors.white : AppColors.textLight,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PathConnector extends StatelessWidget {
  final bool isLeft;

  const _PathConnector({required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: CustomPaint(
        size: const Size(double.infinity, 56),
        painter: _ConnectorPainter(isLeft: isLeft),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final bool isLeft;

  _ConnectorPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dashPaint = Paint()
      ..color = AppColors.borderDark
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Node center x positions (offset from edges to match node alignment)
    const nodeOffset = 60.0; // center of 80px node within 20px padding
    final leftX = nodeOffset;
    final rightX = size.width - nodeOffset;

    final startX = isLeft ? leftX : rightX;
    final endX = isLeft ? rightX : leftX;
    const startY = 0.0;
    const endY = 56.0;

    final path = Path();
    path.moveTo(startX, startY);
    path.cubicTo(
      startX, startY + 28,
      endX, endY - 28,
      endX, endY,
    );

    // Draw dashed path
    _drawDashedPath(canvas, path, dashPaint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      const dashLength = 8.0;
      const gapLength = 6.0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLength : gapLength;
        if (draw) {
          canvas.drawPath(
            metric.extractPath(distance, distance + len),
            paint,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) => old.isLeft != isLeft;
}

// ─── Level Chip ───────────────────────────────────────────────────────────────

class _LevelChip extends StatelessWidget {
  final String level;
  const _LevelChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final Map<String, _LevelStyle> styles = {
      'beginner': const _LevelStyle('🌱', AppColors.correct, AppColors.surfaceElevated),
      'intermediate': const _LevelStyle('⚡', AppColors.accentBlue, AppColors.surfaceElevated),
      'advanced': const _LevelStyle('🔥', AppColors.streakOrange, AppColors.surfaceElevated),
    };
    final s = styles[level] ?? styles['beginner']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: s.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 3),
          Text(
            level[0].toUpperCase() + level.substring(1),
            style: TextStyle(
              color: s.color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
