import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

/// Pull-to-refresh indicator với quả bóng ⚽ xoay theo lực kéo.
/// Dùng thay thế RefreshIndicator trên tất cả các màn hình.
class FootballRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const FootballRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      builder: (context, child, controller) {
        return AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final pull = controller.value.clamp(0.0, 1.0);
            return Stack(
              children: [
                Transform.translate(
                  offset: Offset(0, pull * 70),
                  child: child,
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: pull * 70,
                    child: Center(
                      child: Transform.rotate(
                        angle: controller.value * 6.28,
                        child: Text(
                          '⚽',
                          style: TextStyle(
                            fontSize: 28 * pull.clamp(0.3, 1.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
      child: child,
    );
  }
}
