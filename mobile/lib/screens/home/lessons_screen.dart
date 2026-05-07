import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';
import '../../models/topic.dart';
import '../../models/lesson.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import 'lesson_detail_screen.dart';

class LessonsScreen extends StatefulWidget {
  final Topic topic;

  const LessonsScreen({super.key, required this.topic});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final _api = ApiService();
  List<Lesson> _lessons = [];
  bool _isLoading = true;
  String? _error;

  Color get _topicColor {
    if (widget.topic.color.startsWith('#')) {
      try {
        return Color(int.parse('FF${widget.topic.color.substring(1)}', radix: 16));
      } catch (_) {}
    }
    return AppColors.primary;
  }

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final lessons = await _api.getLessonsByTopic(widget.topic.id);
      if (mounted) {
        setState(() {
          _lessons = lessons;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _lessons = _mockLessons();
        });
      }
    }
  }

  List<Lesson> _mockLessons() {
    return List.generate(
      6,
      (i) => Lesson(
        id: 'mock_lesson_$i',
        topicId: widget.topic.id,
        title: 'Lesson ${i + 1}: ${_mockTitles[i % _mockTitles.length]}',
        content: 'Nội dung bài học mẫu cho bài ${i + 1}',
        summary: 'Tìm hiểu các kiến thức cơ bản về ${widget.topic.title}',
        order: i + 1,
        xpReward: 10 + i * 5,
        estimatedMinutes: 5 + i * 2,
        isActive: true,
      ),
    );
  }

  static const _mockTitles = [
    'Giới thiệu',
    'Biến & Kiểu dữ liệu',
    'Luồng điều khiển',
    'Phương thức',
    'Mảng',
    'Lớp',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          if (_isLoading)
            SliverToBoxAdapter(child: _buildShimmer())
          else if (_error != null && _lessons.isEmpty)
            SliverToBoxAdapter(child: _buildError())
          else ...[
            SliverToBoxAdapter(child: _buildProgressHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _LessonItem(
                    lesson: _lessons[index],
                    index: index,
                    topicColor: _topicColor,
                    isLast: index == _lessons.length - 1,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LessonDetailScreen(
                            lesson: _lessons[index],
                            topic: widget.topic,
                          ),
                        ),
                      );
                    },
                  ),
                  childCount: _lessons.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      elevation: 0,
      backgroundColor: _topicColor,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        // title chỉ dùng ở đây — background KHÔNG render title nữa
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
        title: Text(
          widget.topic.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
        collapseMode: CollapseMode.parallax,
        background: _buildHeaderBackground(),
      ),
    );
  }

  Widget _buildHeaderBackground() {
    final color = _topicColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            Color.lerp(color, Colors.black, 0.25)!,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          // bottom padding lớn để không đè lên FlexibleSpaceBar.title
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 52),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    widget.topic.icon,
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Consumer<UserProvider>(
                      builder: (_, provider, __) {
                        if (_lessons.isEmpty) {
                          return Text(
                            '${widget.topic.totalLessons} bài học',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                        final done = _lessons
                            .where((l) => provider.isLessonCompleted(l.id))
                            .length;
                        final total = _lessons.length;
                        final pct = total > 0 ? done / total : 0.0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$done / $total bài hoàn thành',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: Colors.white.withValues(alpha: 0.25),
                                valueColor: AlwaysStoppedAnimation(
                                  done == total ? Colors.greenAccent : AppColors.xpGold,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Consumer<UserProvider>(
      builder: (_, provider, __) {
        if (_lessons.isEmpty) return const SizedBox.shrink();
        final done =
            _lessons.where((l) => provider.isLessonCompleted(l.id)).length;
        final total = _lessons.length;
        final totalXp = _lessons.fold(0, (sum, l) => sum + l.xpReward);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              _StatChip(
                icon: Icons.check_circle_rounded,
                label: '$done/$total bài',
                color: AppColors.correct,
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.bolt_rounded,
                label: '$totalXp XP',
                color: AppColors.xpGold,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Builder(
      builder: (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(5, (_) {
          return Shimmer.fromColors(
            baseColor: context.surfaceColor,
            highlightColor: context.surfaceElevatedColor,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 88,
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        }),
      ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.textGray),
            const SizedBox(height: 16),
            Text('Không thể tải bài học', style: AppTextStyles.heading4),
            const SizedBox(height: 8),
            const Text(
              'Kiểm tra kết nối mạng và thử lại',
              style: TextStyle(color: AppColors.textGray, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadLessons,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _topicColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(140, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonItem extends StatelessWidget {
  final Lesson lesson;
  final int index;
  final Color topicColor;
  final bool isLast;
  final VoidCallback onTap;

  const _LessonItem({
    required this.lesson,
    required this.index,
    required this.topicColor,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        final isCompleted = provider.isLessonCompleted(lesson.id);

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCompleted
                        ? AppColors.correct.withValues(alpha: 0.4)
                        : context.borderColor,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Colored left stripe
                        Container(
                          width: 4,
                          color: isCompleted
                              ? AppColors.correct
                              : topicColor.withValues(alpha: 0.6),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                            child: Row(
                              children: [
                                // Number / check circle
                                _LessonNumberBadge(
                                  index: index,
                                  isCompleted: isCompleted,
                                  topicColor: topicColor,
                                ),
                                const SizedBox(width: 14),
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lesson.title,
                                        style: AppTextStyles.labelBold.copyWith(
                                          color: isCompleted
                                              ? AppColors.textGray
                                              : context.textDark,
                                          decoration: isCompleted
                                              ? TextDecoration.none
                                              : null,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lesson.summary,
                                        style: AppTextStyles.bodySmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          _MetaBadge(
                                            icon: Icons.bolt_rounded,
                                            label: '${lesson.xpReward} XP',
                                            color: AppColors.xpGold,
                                          ),
                                          if (isCompleted) ...[
                                            const SizedBox(width: 8),
                                            _MetaBadge(
                                              icon: Icons.check_rounded,
                                              label: 'Hoàn thành',
                                              color: AppColors.correct,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: isCompleted
                                      ? AppColors.correct.withValues(alpha: 0.6)
                                      : AppColors.textGray,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LessonNumberBadge extends StatelessWidget {
  final int index;
  final bool isCompleted;
  final Color topicColor;

  const _LessonNumberBadge({
    required this.index,
    required this.isCompleted,
    required this.topicColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? AppColors.correct.withValues(alpha: 0.15)
            : topicColor.withValues(alpha: 0.12),
        border: Border.all(
          color: isCompleted
              ? AppColors.correct.withValues(alpha: 0.5)
              : topicColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Center(
        child: isCompleted
            ? Icon(Icons.check_rounded, color: AppColors.correct, size: 20)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  color: topicColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
