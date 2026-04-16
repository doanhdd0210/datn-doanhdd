import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/quiz_result.dart';
import '../../models/question.dart';
import 'quiz_review_screen.dart';

class QuizResultScreen extends StatefulWidget {
  final QuizResult result;
  final List<Question> questions;
  final String lessonTitle;

  const QuizResultScreen({
    super.key,
    required this.result,
    required this.questions,
    required this.lessonTitle,
  });

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _xpController;
  late Animation<int> _xpAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _xpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _xpAnimation = IntTween(begin: 0, end: widget.result.xpEarned).animate(
      CurvedAnimation(parent: _xpController, curve: Curves.easeOut),
    );

    if (widget.result.isPassing) {
      _confettiController.play();
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      _xpController.forward();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _xpController.dispose();
    super.dispose();
  }

  String get _resultMessage {
    final pct = widget.result.percentage;
    if (pct == 1.0) return 'Perfect! 🏆';
    if (pct >= 0.8) return 'Excellent! 🎉';
    if (pct >= 0.7) return 'Good job! 👏';
    if (pct >= 0.5) return 'Keep going! 💪';
    return 'Try again! 📚';
  }

  Color get _resultColor {
    final pct = widget.result.percentage;
    if (pct >= 0.8) return AppColors.primary;
    if (pct >= 0.6) return AppColors.blue;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Result message
                  Text(
                    _resultMessage,
                    style: AppTextStyles.heading1.copyWith(color: _resultColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Score ring
                  CircularPercentIndicator(
                    radius: 90,
                    lineWidth: 14,
                    percent: result.percentage,
                    animation: true,
                    animationDuration: 1000,
                    progressColor: _resultColor,
                    backgroundColor: _resultColor.withOpacity(0.15),
                    circularStrokeCap: CircularStrokeCap.round,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${result.correctAnswers}/${result.totalQuestions}',
                          style: AppTextStyles.heading2.copyWith(color: _resultColor),
                        ),
                        Text(
                          'correct',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // XP earned
                  AnimatedBuilder(
                    animation: _xpAnimation,
                    builder: (context, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.xpGold.withOpacity(0.15), AppColors.xpGold.withOpacity(0.05)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.xpGold.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚡', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Text(
                              '+${_xpAnimation.value} XP',
                              style: AppTextStyles.heading3.copyWith(color: AppColors.xpGold),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Stats grid
                  _buildStatsGrid(result),
                  const SizedBox(height: 28),
                  // Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: AppTextStyles.buttonText,
                      ),
                      child: const Text('Continue Learning'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.questions.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuizReviewScreen(
                                result: widget.result,
                                questions: widget.questions,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        child: const Text('Review Answers'),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Confetti
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              AppColors.primary,
              AppColors.secondary,
              AppColors.blue,
              AppColors.purple,
              AppColors.orange,
            ],
            numberOfParticles: 30,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(QuizResult result) {
    final percentage = (result.percentage * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Results Summary', style: AppTextStyles.heading4),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatItem(
                icon: Icons.check_circle,
                label: 'Correct',
                value: result.correctAnswers.toString(),
                color: AppColors.primary,
              ),
              _StatItem(
                icon: Icons.cancel,
                label: 'Wrong',
                value: (result.totalQuestions - result.correctAnswers).toString(),
                color: AppColors.red,
              ),
              _StatItem(
                icon: Icons.percent,
                label: 'Score',
                value: '$percentage%',
                color: _resultColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.heading3.copyWith(color: color)),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
