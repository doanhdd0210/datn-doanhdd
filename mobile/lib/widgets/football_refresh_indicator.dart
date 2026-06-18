import 'dart:math';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

/// Pull-to-refresh: kéo → bóng scale dần, loading → bóng spin tại chỗ.
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
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _onStateChanged(IndicatorStateChange change) {
    if (change.currentState == IndicatorState.loading) {
      _spin.repeat();
    } else if (change.currentState == IndicatorState.complete ||
        change.currentState == IndicatorState.idle) {
      _spin.stop();
      _spin.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    const indicatorH = 64.0;
    const ballSize = 36.0;

    return CustomRefreshIndicator(
      onRefresh: widget.onRefresh,
      onStateChanged: _onStateChanged,
      builder: (context, child, controller) {
        return AnimatedBuilder(
          animation: Listenable.merge([controller, _spin]),
          builder: (_, __) {
            final pull = controller.value.clamp(0.0, 1.0);
            final isLoading = controller.state == IndicatorState.loading ||
                controller.state == IndicatorState.complete;

            // Khi loading: spin linear; khi kéo: xoay nhẹ theo pull
            final angle = isLoading
                ? _spin.value * 2 * pi
                : pull * pi * 0.8;

            // Scale: 0 → 1 khi kéo, giữ 1 khi loading
            final scale = isLoading ? 1.0 : Curves.easeOut.transform(pull);

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
                    child: Center(
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: pull,
                          child: Transform.rotate(
                            angle: angle,
                            child: const Text(
                              '⚽',
                              style: TextStyle(fontSize: ballSize, height: 1),
                            ),
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
