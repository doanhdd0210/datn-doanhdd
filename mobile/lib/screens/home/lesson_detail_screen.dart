import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/lesson.dart';
import '../../models/topic.dart';
import '../quiz/quiz_screen.dart';

class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;
  final Topic topic;

  const LessonDetailScreen({super.key, required this.lesson, required this.topic});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  double _readProgress = 0.0;

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
    _scrollController.addListener(_updateProgress);
  }

  void _updateProgress() {
    final max = _scrollController.position.maxScrollExtent;
    if (max > 0) {
      setState(() {
        _readProgress = (_scrollController.offset / max).clamp(0.0, 1.0);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateProgress);
    _scrollController.dispose();
    super.dispose();
  }

  void _startQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          lessonId: widget.lesson.id,
          topicId: widget.topic.id,
          lessonTitle: widget.lesson.title,
          xpReward: widget.lesson.xpReward,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.topic.title,
              style: AppTextStyles.bodySmall.copyWith(color: _topicColor),
            ),
            Text(widget.lesson.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                )),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 1, color: AppColors.border),
              LinearProgressIndicator(
                value: _readProgress,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(_topicColor),
                minHeight: 3,
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lesson header card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    color: AppColors.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _topicColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.topic.icon,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.lesson.title,
                                style: AppTextStyles.heading3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(widget.lesson.summary, style: AppTextStyles.bodyMedium),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _InfoChip(
                              icon: Icons.bolt,
                              label: '${widget.lesson.xpReward} XP',
                              color: AppColors.xpGold,
                            ),
                            const SizedBox(width: 8),
                            _InfoChip(
                              icon: Icons.timer_outlined,
                              label: '${widget.lesson.estimatedMinutes} min',
                              color: AppColors.blue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Content body
                  Container(
                    width: double.infinity,
                    color: AppColors.background,
                    padding: const EdgeInsets.all(20),
                    child: _buildContent(widget.lesson.content),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          // Bottom action bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startQuiz,
                  icon: const Icon(Icons.quiz),
                  label: const Text('Start Quiz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: AppTextStyles.buttonText,
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String content) {
    // Simple content renderer that supports basic markdown-like patterns
    final paragraphs = content.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((para) {
        if (para.startsWith('```')) {
          // Code block
          final code = para.replaceAll(RegExp(r'^```[a-z]*\n?'), '').replaceAll('```', '').trim();
          return _CodeBlock(code: code);
        } else if (para.startsWith('# ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(para.substring(2), style: AppTextStyles.heading3),
          );
        } else if (para.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(para.substring(3), style: AppTextStyles.heading4),
          );
        } else if (para.startsWith('- ') || para.startsWith('* ')) {
          final items = para.split('\n').where((l) => l.startsWith('- ') || l.startsWith('* ')).toList();
          return Column(
            children: items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7, right: 8),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(item.substring(2), style: AppTextStyles.bodyMedium),
                  ),
                ],
              ),
            )).toList(),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildInlineText(para),
          );
        }
      }).toList(),
    );
  }

  Widget _buildInlineText(String text) {
    // Basic bold support with **text**
    if (!text.contains('**') && !text.contains('`')) {
      return Text(text, style: AppTextStyles.bodyMedium);
    }
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*|`(.*?)`');
    int lastEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: AppTextStyles.bodyMedium,
        ));
      }
      if (match.group(1) != null) {
        // Bold
        spans.add(TextSpan(
          text: match.group(1),
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ));
      } else if (match.group(2) != null) {
        // Inline code
        spans.add(TextSpan(
          text: match.group(2),
          style: AppTextStyles.codeStyle.copyWith(
            backgroundColor: AppColors.surfaceElevated,
            fontSize: 13,
          ),
        ));
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: AppTextStyles.bodyMedium,
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;

  const _CodeBlock({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title bar
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D3F),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Text('Java', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 11, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: const Icon(Icons.content_copy_outlined, size: 14, color: Color(0xFF666666)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.55,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
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
