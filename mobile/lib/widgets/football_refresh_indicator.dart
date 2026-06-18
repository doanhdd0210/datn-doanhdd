import 'dart:math';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

/// Pull-to-refresh: kéo xuống thì bóng lăn vào từ trên, đang load thì lăn liên tục.
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

  @override
  void initState() {
    super.initState();
    _roll = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  void _onStateChanged(IndicatorStateChange change) {
    if (change.currentState == IndicatorState.loading) {
      _roll.repeat();
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

            // Khi loading: bóng lăn trái→phải; khi kéo: bóng ở giữa scale dần
            double ballX;
            double angle;
            const trackW = 120.0;
            if (isLoading) {
              final t = Curves.easeInOut.transform(_roll.value);
              ballX = t * (trackW - ballSize);
              angle = (ballX / (ballSize * pi)) * 2 * pi;
            } else {
              ballX = (trackW - ballSize) / 2;
              angle = pull * pi; // xoay nhẹ khi kéo
            }

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
                  child: Opacity(
                    opacity: pull,
                    child: SizedBox(
                      height: pull * indicatorH,
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
