import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';
import '../../models/quiz_result.dart';
import '../../models/question.dart';
import '../../providers/user_provider.dart';
import 'quiz_review_screen.dart';
import 'quiz_screen.dart';

class QuizResultScreen extends StatefulWidget {
  final QuizResult result;
  final List<Question> questions;
  final String lessonTitle;
  final String? lessonId;
  final String? topicId;
  final int xpReward;
  final bool isPerfect;

  const QuizResultScreen({
    super.key,
    required this.result,
    required this.questions,
    required this.lessonTitle,
    this.lessonId,
    this.topicId,
    this.xpReward = 0,
    this.isPerfect = false,
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
    final total = widget.result.totalQuestions;
    final correct = widget.result.correctAnswers;
    final displayXp = widget.result.xpEarned > 0
        ? widget.result.xpEarned
        : (total > 0 ? (correct / total * widget.xpReward).round() : 0);
    _xpAnimation = IntTween(begin: 0, end: displayXp).animate(
      CurvedAnimation(parent: _xpController, curve: Curves.easeOut),
    );

    if (widget.isPerfect) {
      _confettiController.play();
      // Poll twice: server processes CheckAndGrantAsync fire-and-forget,
      // first attempt at 2s, retry at 5s in case server is slow.
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        context.read<UserProvider>().pollNewAchievements();
      });
      Future.delayed(const Duration(milliseconds: 5000), () {
        if (!mounted) return;
        context.read<UserProvider>().pollNewAchievements();
      });
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
    if (widget.isPerfect) return 'Hoàn hảo! 🏆';
    final correct = widget.result.correctAnswers;
    if (correct <= 1) return 'Ôn lại và thử lại nhé! 📖';
    return 'Gần đúng rồi! Thử lại nhé 💪';
  }

  Color get _resultColor {
    if (widget.isPerfect) return AppColors.correct;   // xanh
    final correct = widget.result.correctAnswers;
    if (correct <= 1) return AppColors.red;            // đỏ: 0–1 câu đúng
    return AppColors.orange;                           // vàng: còn lại
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Pass/Fail badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: result.isPassing
                          ? AppColors.correct.withValues(alpha: 0.15)
                          : AppColors.wrong.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: result.isPassing
                            ? AppColors.correct.withValues(alpha: 0.5)
                            : AppColors.wrong.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      result.isPassing ? '✓ ĐẠT' : '✗ KHÔNG ĐẠT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: result.isPassing ? AppColors.correct : AppColors.wrong,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    backgroundColor: _resultColor.withValues(alpha: 0.15),
                    circularStrokeCap: CircularStrokeCap.round,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${result.correctAnswers}/${result.totalQuestions}',
                          style: AppTextStyles.heading2.copyWith(color: _resultColor),
                        ),
                        Text(
                          'đúng',
                          style: AppTextStyles.bodySmall.copyWith(color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // XP earned / preview
                  AnimatedBuilder(
                    animation: _xpAnimation,
                    builder: (context, _) {
                      // earned: lần đầu 100% → vàng
                      // alreadyEarned: 100% nhưng đã nhận trước đó → xám + "Đã nhận rồi"
                      // preview: chưa đủ 100% → xám + "Đúng hết để nhận"
                      final earned = widget.result.xpEarned > 0;
                      final alreadyEarned = widget.result.xpEarned == 0 && widget.isPerfect;
                      final color = earned ? AppColors.xpGold : Colors.grey;
                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: color.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('⚡', style: TextStyle(fontSize: 24, color: earned ? null : Colors.grey)),
                                const SizedBox(width: 8),
                                Text(
                                  '+${_xpAnimation.value} XP',
                                  style: AppTextStyles.heading3.copyWith(color: color),
                                ),
                              ],
                            ),
                          ),
                          if (alreadyEarned) ...[
                            const SizedBox(height: 6),
                            Text('Đã nhận XP ở lần trước',
                                style: AppTextStyles.bodySmall.copyWith(color: Colors.grey)),
                          ] else if (!earned && _xpAnimation.value > 0) ...[
                            const SizedBox(height: 6),
                            Text('Đúng hết để nhận XP này!',
                                style: AppTextStyles.bodySmall.copyWith(color: Colors.grey)),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Stats grid
                  _buildStatsGrid(result),
                  const SizedBox(height: 28),
                  // Buttons
                  if (widget.isPerfect) ...[
                    // 100% → Tiếp tục học (primary, full width)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.correct,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: AppTextStyles.buttonText,
                        ),
                        child: const Text('Tiếp tục học 🎉'),
                      ),
                    ),
                  ] else ...[
                    // Lock warning
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.wrong.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.wrong.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_rounded, color: AppColors.wrong, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cần trả lời đúng 100% để mở khoá bài tiếp theo!',
                              style: TextStyle(
                                color: AppColors.wrong,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Hai nút cùng hàng — IntrinsicHeight đảm bảo cao bằng nhau
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Quay lại ôn bài
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.menu_book_rounded, size: 16),
                              label: const Text('Quay lại'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                          ),
                          if (widget.lessonId != null) ...[
                            const SizedBox(width: 10),
                            // Làm lại ngay
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QuizScreen(
                                        lessonId: widget.lessonId!,
                                        topicId: widget.topicId ?? '',
                                        lessonTitle: widget.lessonTitle,
                                        xpReward: widget.xpReward,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Làm lại'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  // Xem lại câu trả lời — luôn hiện
                  if (widget.questions.isNotEmpty) ...[
                    const SizedBox(height: 10),
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
                          foregroundColor: context.textSecondary,
                          side: BorderSide(color: context.borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        child: const Text('Xem lại câu trả lời'),
                      ),
                    ),
                  ],
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
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tóm tắt kết quả', style: AppTextStyles.heading4),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatItem(
                icon: Icons.check_circle,
                label: 'Đúng',
                value: result.correctAnswers.toString(),
                color: AppColors.primary,
              ),
              _StatItem(
                icon: Icons.cancel,
                label: 'Sai',
                value: (result.totalQuestions - result.correctAnswers).toString(),
                color: AppColors.red,
              ),
              _StatItem(
                icon: Icons.percent,
                label: 'Điểm',
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
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: context.textSecondary)),
        ],
      ),
    );
  }
}
