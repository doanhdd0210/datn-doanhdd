import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
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
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          if (_isLoading)
            SliverToBoxAdapter(child: _buildShimmer())
          else if (_error != null && _lessons.isEmpty)
            SliverToBoxAdapter(child: _buildError())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _LessonItem(
                    lesson: _lessons[index],
                    index: index,
                    topicColor: _topicColor,
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
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: _topicColor,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _topicColor,
                _topicColor.withOpacity(0.7),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              child: Row(
                children: [
                  Text(widget.topic.icon, style: const TextStyle(fontSize: 48)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(widget.topic.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            )),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.topic.totalLessons} bài học',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        title: Text(widget.topic.title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
      ),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(5, (_) {
          return Shimmer.fromColors(
            baseColor: AppColors.surface,
            highlightColor: AppColors.surfaceElevated,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }),
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
            const Icon(Icons.error_outline, size: 48, color: AppColors.textGray),
            const SizedBox(height: 12),
            Text('Không thể tải bài học', style: AppTextStyles.heading4),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLessons,
              style: ElevatedButton.styleFrom(
                backgroundColor: _topicColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonItem extends StatelessWidget {
  final Lesson lesson;
  final int index;
  final Color topicColor;
  final VoidCallback onTap;

  const _LessonItem({
    required this.lesson,
    required this.index,
    required this.topicColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        final isCompleted = provider.isLessonCompleted(lesson.id);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: isCompleted
                  ? Border.all(color: AppColors.primary.withOpacity(0.5))
                  : Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Lesson number circle
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppColors.primary
                        : topicColor.withOpacity(0.12),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: topicColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.title, style: AppTextStyles.labelBold),
                      const SizedBox(height: 3),
                      Text(
                        lesson.summary,
                        style: AppTextStyles.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _MetaBadge(
                            icon: '⚡',
                            label: '${lesson.xpReward} XP',
                            color: AppColors.xpGold,
                          ),
                          const SizedBox(width: 8),
                          _MetaBadge(
                            icon: '⏱',
                            label: '${lesson.estimatedMinutes} min',
                            color: AppColors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isCompleted ? AppColors.primary : AppColors.textGray,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;

  const _MetaBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 10)),
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
