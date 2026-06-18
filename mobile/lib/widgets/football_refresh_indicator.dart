import 'dart:math';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

/// Pull-to-refresh indicator với quả bóng ⚽.
/// - Kéo xuống: bóng hiện dần + xoay theo lực kéo
/// - Đang load: bóng spin liên tục mượt
/// - Xong: fade out
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
      duration: const Duration(milliseconds: 700),
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
    return CustomRefreshIndicator(
      onRefresh: widget.onRefresh,
      onStateChanged: _onStateChanged,
      builder: (context, child, controller) {
        return AnimatedBuilder(
          animation: Listenable.merge([controller, _spin]),
          builder: (_, __) {
            final pull = controller.value.clamp(0.0, 1.5);
            final visible = pull.clamp(0.0, 1.0);
            final isLoading = controller.state == IndicatorState.loading ||
                controller.state == IndicatorState.complete;

            // Khi loading: spin liên tục; khi kéo: xoay theo pull
            final angle = isLoading
                ? _spin.value * 2 * pi
                : pull * 2 * pi;

            final ballSize = 28.0;
            final offsetY = visible * 70;

            return Stack(
              children: [
                Transform.translate(
                  offset: Offset(0, offsetY),
                  child: child,
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: offsetY,
                    child: Center(
                      child: Opacity(
                        opacity: visible.clamp(0.0, 1.0),
                        child: Transform.rotate(
                          angle: angle,
                          child: Text(
                            '⚽',
                            style: TextStyle(fontSize: ballSize),
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
