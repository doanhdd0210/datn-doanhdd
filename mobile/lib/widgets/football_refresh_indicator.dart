import 'dart:math';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

/// Pull-to-refresh với ⚽ lăn trên cỏ.
/// - Kéo: bóng di chuyển theo lực kéo (0→phải)
/// - Loading: bóng lăn liên tục bắt đầu từ đúng vị trí cuối kéo
class FootballRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const FootballRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  State<FootballRefreshIndicator> createState() =>
      _FootballRefreshIndicatorState();
}

class _FootballRefreshIndicatorState extends State<FootballRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll;
  double _lastPull = 0.5; // vị trí bóng lúc nhả tay (0.0 – 1.0)

  @override
  void initState() {
    super.initState();
    _roll = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  void _onStateChanged(IndicatorStateChange change) {
    if (change.currentState == IndicatorState.loading) {
      // Bắt đầu từ đúng vị trí bóng lúc nhả tay → không jump
      _roll.value = _lastPull;
      _roll.repeat(reverse: true);
    } else if (change.currentState == IndicatorState.complete ||
        change.currentState == IndicatorState.idle) {
      _roll.stop();
      _roll.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    const indicatorH = 64.0;
    const ballSize = 28.0;
    const grassH = 2.5;
    const trackW = 120.0;
    const maxBallX = trackW - ballSize;

    return CustomRefreshIndicator(
      onRefresh: widget.onRefresh,
      onStateChanged: _onStateChanged,
      builder: (context, child, controller) {
        return AnimatedBuilder(
          animation: Listenable.merge([controller, _roll]),
          builder: (_, __) {
            final pull = controller.value.clamp(0.0, 1.0);
            final isLoading = controller.state == IndicatorState.loading ||
                controller.state == IndicatorState.complete;

            double ballX;
            if (isLoading) {
              ballX = _roll.value * maxBallX;
            } else {
              // Kéo: bóng đi từ trái sang phải theo pull
              ballX = pull * maxBallX;
              _lastPull = pull; // lưu vị trí để loading bắt đầu từ đây
            }

            // Rotation đồng bộ với vị trí — physically correct
            final angle = (ballX / (ballSize * pi)) * 2 * pi;

            return Stack(
              children: [
                Transform.translate(
                  offset: Offset(0, pull * indicatorH),
                  child: child,
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: pull * indicatorH,
                    child: Opacity(
                      opacity: pull.clamp(0.0, 1.0),
                      child: Center(
                        child: SizedBox(
                          width: trackW,
                          height: ballSize + grassH + 4,
                          child: Stack(
                            children: [
                              // Sân cỏ
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: grassH,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50)
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              // Bóng
                              Positioned(
                                left: ballX,
                                bottom: grassH + 1,
                                child: Transform.rotate(
                                  angle: angle,
                                  child: const Text('⚽',
                                      style: TextStyle(
                                          fontSize: ballSize, height: 1)),
                                ),
                              ),
                            ],
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
      child: widget.child,
    );
  }
}
