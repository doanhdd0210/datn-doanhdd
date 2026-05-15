import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';

class SubscriptionSuccessScreen extends StatefulWidget {
  final String planName;
  final String planIcon;
  final DateTime? expiresAt;
  final bool isTrial;
  final VoidCallback? onDone;

  const SubscriptionSuccessScreen({
    super.key,
    required this.planName,
    required this.planIcon,
    this.expiresAt,
    this.isTrial = false,
    this.onDone,
  });

  @override
  State<SubscriptionSuccessScreen> createState() =>
      _SubscriptionSuccessScreenState();
}

class _SubscriptionSuccessScreenState extends State<SubscriptionSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  void _done() {
    widget.onDone?.call();
    // Pop về màn hình gốc trước VipSubscriptionScreen
    Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name != null && route.settings.name != '/vip');
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isMax = widget.planName.toLowerCase() == 'max';
    final color = isMax ? const Color(0xFFFFC107) : AppColors.secondary;

    final perks = [
      ('🤖', 'AI giải thích code', 'Hiểu lỗi nhanh, học nhanh hơn'),
      ('💡', 'Gợi ý quiz thông minh', 'Ôn tập hiệu quả mỗi ngày'),
      ('💬', 'Trợ lý QA cộng đồng', 'Câu trả lời tức thì'),
    ];

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                const Spacer(),
                // Icon
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 4)
                      ],
                    ),
                    child: Center(
                      child: Text(widget.planIcon,
                          style: const TextStyle(fontSize: 46)),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Chào mừng bạn đến với\n${widget.planName} ${widget.planIcon}',
                  style: AppTextStyles.heading2.copyWith(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (widget.isTrial && widget.expiresAt != null)
                  Text(
                    'Dùng thử miễn phí đến ${_formatDate(widget.expiresAt!)}\nSau đó tự động gia hạn hàng tháng',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                    textAlign: TextAlign.center,
                  )
                else if (widget.expiresAt != null)
                  Text(
                    'Tự động gia hạn ${_formatDate(widget.expiresAt!)}',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 32),
                // Perks
                ...perks.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                                child: Text(p.$1,
                                    style:
                                        const TextStyle(fontSize: 20))),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.$2,
                                  style: AppTextStyles.labelBold
                                      .copyWith(fontSize: 14)),
                              Text(p.$3,
                                  style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    )),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _done,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Bắt đầu sử dụng',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
