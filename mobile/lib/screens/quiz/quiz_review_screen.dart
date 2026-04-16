import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Review Answers'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
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

  @override
  Widget build(BuildContext context) {
    final userAnswer = widget.userAnswer;
    final isCorrect = userAnswer?.isCorrect ?? false;
    final question = widget.question;
    const optionLabels = ['A', 'B', 'C', 'D'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCorrect ? AppColors.primary.withOpacity(0.3) : AppColors.red.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: isCorrect ? AppColors.primary.withOpacity(0.08) : AppColors.red.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? AppColors.primary : AppColors.red,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Question ${widget.questionIndex + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isCorrect ? AppColors.primary : AppColors.red,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCorrect ? AppColors.primary : AppColors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCorrect ? '+${question.points} pts' : '0 pts',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(question.questionText, style: AppTextStyles.labelBold),
          ),
          // Options
          ...question.options.asMap().entries.map((entry) {
            final i = entry.key;
            final option = entry.value;
            final isCorrectOption = i == question.correctAnswerIndex;
            final isUserSelected = userAnswer?.selectedAnswerIndex == i;

            Color? bg;
            Color? border;

            if (isCorrectOption) {
              bg = AppColors.primary.withOpacity(0.08);
              border = AppColors.primary;
            } else if (isUserSelected && !isCorrectOption) {
              bg = AppColors.red.withOpacity(0.08);
              border = AppColors.red;
            }

            return Container(
              margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bg ?? const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: border ?? AppColors.border,
                  width: (isCorrectOption || isUserSelected) ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (border ?? AppColors.border).withOpacity(0.15),
                    ),
                    child: Center(
                      child: Text(
                        optionLabels[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: border ?? AppColors.textGray,
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
                        color: border != null ? border : AppColors.textGray,
                        fontWeight: (isCorrectOption || isUserSelected) ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (isCorrectOption)
                    const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
                  if (isUserSelected && !isCorrectOption)
                    const Icon(Icons.cancel, color: AppColors.red, size: 16),
                ],
              ),
            );
          }),
          // Explanation toggle
          if (question.explanation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showExplanation = !_showExplanation),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.orange),
                        const SizedBox(width: 6),
                        Text(
                          _showExplanation ? 'Hide Explanation' : 'Show Explanation',
                          style: const TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _showExplanation ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: AppColors.orange,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                  if (_showExplanation) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.orange.withOpacity(0.2)),
                      ),
                      child: Text(question.explanation, style: AppTextStyles.bodySmall.copyWith(height: 1.5)),
                    ),
                  ],
                ],
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}
