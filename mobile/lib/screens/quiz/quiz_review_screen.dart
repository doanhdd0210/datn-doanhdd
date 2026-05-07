import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';
import '../../models/quiz_result.dart';
import '../../models/question.dart';

class QuizReviewScreen extends StatelessWidget {
  final QuizResult result;
  final List<Question> questions;

  const QuizReviewScreen({
    super.key,
    required this.result,
    required this.questions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Xem lại câu trả lời'),
        backgroundColor: context.bgColor,
        foregroundColor: context.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.borderColor),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final question = questions[index];
          final userAnswer = result.answers.cast<UserAnswer?>().firstWhere(
            (a) => a?.questionId == question.id,
            orElse: () => null,
          );
          return _ReviewItem(
            question: question,
            questionIndex: index,
            userAnswer: userAnswer,
          );
        },
      ),
    );
  }
}

class _ReviewItem extends StatefulWidget {
  final Question question;
  final int questionIndex;
  final UserAnswer? userAnswer;

  const _ReviewItem({
    required this.question,
    required this.questionIndex,
    required this.userAnswer,
  });

  @override
  State<_ReviewItem> createState() => _ReviewItemState();
}

class _ReviewItemState extends State<_ReviewItem> {
  bool _showExplanation = false;

  static const _correctColor = Color(0xFF4CAF50);
  static const _wrongColor   = Color(0xFFF44336);

  @override
  Widget build(BuildContext context) {
    final userAnswer  = widget.userAnswer;
    final isCorrect   = userAnswer?.isCorrect ?? false;
    final question    = widget.question;
    const labels      = ['A', 'B', 'C', 'D'];

    final accentColor = isCorrect ? _correctColor : _wrongColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header strip ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            color: accentColor.withValues(alpha: 0.07),
            child: Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCorrect ? Icons.check_rounded : Icons.close_rounded,
                    color: accentColor, size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Câu hỏi ${widget.questionIndex + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),

          // ── Question text ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(question.questionText, style: AppTextStyles.labelBold.copyWith(height: 1.5)),
          ),

          // ── Options ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Column(
              children: question.options.asMap().entries.map((entry) {
                final i             = entry.key;
                final option        = entry.value;
                final isCorrectOpt  = i == question.correctAnswerIndex;
                final isUserPick    = userAnswer?.selectedAnswerIndex == i;

                Color bgColor     = context.surfaceElevatedColor;
                Color borderColor = context.borderColor;
                Color textColor   = context.textSecondary;
                Color labelBg     = context.surfaceElevatedColor;
                Color labelColor  = context.textTertiary;
                Color stripColor  = Colors.transparent;
                Widget? trailing;

                if (isCorrectOpt) {
                  bgColor     = _correctColor.withValues(alpha: 0.07);
                  borderColor = _correctColor.withValues(alpha: 0.45);
                  textColor   = const Color(0xFF2E7D32);
                  labelBg     = _correctColor;
                  labelColor  = Colors.white;
                  stripColor  = _correctColor;
                  trailing    = const Icon(Icons.check_circle_rounded,
                      color: _correctColor, size: 18);
                } else if (isUserPick) {
                  bgColor     = _wrongColor.withValues(alpha: 0.06);
                  borderColor = _wrongColor.withValues(alpha: 0.4);
                  textColor   = const Color(0xFFC62828);
                  labelBg     = _wrongColor;
                  labelColor  = Colors.white;
                  stripColor  = _wrongColor;
                  trailing    = const Icon(Icons.cancel_rounded,
                      color: _wrongColor, size: 18);
                } else {
                  textColor   = context.textSecondary.withValues(alpha: 0.5);
                  labelColor  = context.textTertiary.withValues(alpha: 0.5);
                  borderColor = context.borderColor.withValues(alpha: 0.4);
                }

                final showStrip = stripColor != Colors.transparent;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: showStrip ? 3 : 0,
                        color: stripColor,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          child: Row(
                            children: [
                              Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  color: labelBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    labels[i],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: labelColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textColor,
                                    fontWeight: (isCorrectOpt || isUserPick)
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              if (trailing != null) ...[
                                const SizedBox(width: 6),
                                trailing,
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Explanation toggle ───────────────────────────────────────────
          if (question.explanation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => setState(() => _showExplanation = !_showExplanation),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded,
                              size: 15, color: AppColors.orange),
                          const SizedBox(width: 6),
                          Text(
                            _showExplanation ? 'Ẩn giải thích' : 'Xem giải thích',
                            style: const TextStyle(
                              color: AppColors.orange,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _showExplanation
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: AppColors.orange, size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: _showExplanation
                        ? Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.orange.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              question.explanation,
                              style: AppTextStyles.bodySmall.copyWith(color: context.textSecondary, height: 1.6),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}
