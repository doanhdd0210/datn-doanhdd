import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/api_code_snippet.dart';

class PracticeResultScreen extends StatelessWidget {
  final ApiCodeSnippet snippet;
  final String userCode;
  final String output;
  final bool passed;
  final double matchPercent;
  final int timeSpent;

  const PracticeResultScreen({
    super.key,
    required this.snippet,
    required this.userCode,
    required this.output,
    required this.passed,
    required this.matchPercent,
    required this.timeSpent,
  });

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  String get _resultMessage {
    if (matchPercent == 1.0) return 'Khớp hoàn hảo! 🏆';
    if (matchPercent >= 0.8) return 'Gần hoàn hảo! 🎉';
    if (matchPercent >= 0.6) return 'Cố gắng tốt! 💪';
    return 'Tiếp tục luyện tập! 📚';
  }

  Color get _resultColor {
    if (matchPercent >= 0.8) return AppColors.primary;
    if (matchPercent >= 0.6) return AppColors.blue;
    return AppColors.orange;
  }

  int get _xpEarned {
    return (snippet.xpReward * matchPercent).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: const Text('Kết quả thực hành', style: AppTextStyles.heading4),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Result message
            Text(_resultMessage, style: AppTextStyles.heading2.copyWith(color: _resultColor), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            // Match ring
            CircularPercentIndicator(
              radius: 80,
              lineWidth: 12,
              percent: matchPercent,
              animation: true,
              animationDuration: 1000,
              progressColor: _resultColor,
              backgroundColor: _resultColor.withOpacity(0.15),
              circularStrokeCap: CircularStrokeCap.round,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(matchPercent * 100).round()}%',
                    style: AppTextStyles.heading2.copyWith(color: _resultColor),
                  ),
                  Text('khớp', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // XP earned
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.xpGold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.xpGold.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text('+$_xpEarned XP kiếm được',
                      style: AppTextStyles.heading4.copyWith(color: AppColors.xpGold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tóm tắt', style: AppTextStyles.heading4),
                  const SizedBox(height: 14),
                  _StatRow(icon: Icons.timer, label: 'Thời gian', value: _formatTime(timeSpent), color: AppColors.blue),
                  const SizedBox(height: 10),
                  _StatRow(
                    icon: Icons.code,
                    label: 'Khớp code',
                    value: '${(matchPercent * 100).round()}%',
                    color: _resultColor,
                  ),
                  const SizedBox(height: 10),
                  _StatRow(
                    icon: passed ? Icons.check_circle : Icons.cancel,
                    label: 'Kết quả đầu ra',
                    value: passed ? 'Đạt' : 'Chưa đạt',
                    color: passed ? AppColors.correct : AppColors.wrong,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Output diff
            if (output.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0C0C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kết quả của bạn',
                        style: TextStyle(color: Color(0xFF4FC3F7), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(output.trim(),
                        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12, height: 1.6)),
                    if (snippet.expectedOutput.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFF333333)),
                      const SizedBox(height: 8),
                      const Text('Kết quả dự kiến',
                          style: TextStyle(color: Color(0xFF23A55A), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(snippet.expectedOutput.trim(),
                          style: const TextStyle(color: Color(0xFF4EC9B0), fontFamily: 'monospace', fontSize: 12, height: 1.6)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            // Actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context)
                    .popUntil((route) => route.isFirst || route.settings.name == '/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: AppTextStyles.buttonText,
                ),
                child: const Text('Quay lại thực hành'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                child: const Text('Thử lại'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: AppTextStyles.bodyMedium),
        const Spacer(),
        Text(value, style: AppTextStyles.labelBold.copyWith(color: color)),
      ],
    );
  }
}
