import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../constants/app_theme.dart';
import '../screens/subscription/vip_subscription_screen.dart';

void showAiLimitDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (_) => _AiLimitDialog(message: message),
  );
}

class _AiLimitDialog extends StatelessWidget {
  final String message;
  const _AiLimitDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.heartRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 30))),
          ),
          const SizedBox(height: 14),
          Text('Hết lượt AI hôm nay',
              style: AppTextStyles.heading3, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Nâng cấp VIP để dùng nhiều hơn',
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.borderColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: Text('Đóng',
                    style:
                        TextStyle(color: context.textSecondary, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // đóng dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VipSubscriptionScreen(
                        // Sau khi mua thành công, SubscriptionSuccessScreen
                        // tự pop về — không cần callback thêm ở đây
                        onSuccess: () {},
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: const Text('Nâng cấp 👑',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
