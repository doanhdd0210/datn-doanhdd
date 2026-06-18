import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

/// Pull-to-refresh với ⚽ bounce.
/// - Kéo xuống: bóng xuất hiện dần + scale theo lực kéo
/// - Đang load: bounce liên tục với squish + shadow
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
  late final AnimationController _bounce;
  late final Animation<double> _ballY;
  late final Animation<double> _scaleX;
  late final Animation<double> _scaleY;
  late final Animation<double> _shadow;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _ballY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_bounce);

    _scaleX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 8),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 84),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 8),
    ]).animate(_bounce);

    _scaleY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 8),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 84),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 8),
    ]).animate(_bounce);

    _shadow = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.25)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_bounce);
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _onStateChanged(IndicatorStateChange change) {
    if (change.currentState == IndicatorState.loading) {
      _bounce.repeat();
    } else if (change.currentState == IndicatorState.complete ||
        change.currentState == IndicatorState.idle) {
      _bounce.stop();
      _bounce.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: widget.onRefresh,
      onStateChanged: _onStateChanged,
      builder: (context, child, controller) {
        const indicatorH = 72.0;
        const ballSize = 32.0;
        const bounceH = 20.0;
        const shadowW = 22.0;

        return AnimatedBuilder(
          animation: Listenable.merge([controller, _bounce]),
          builder: (_, __) {
            final pull = controller.value.clamp(0.0, 1.0);
            final isLoading = controller.state == IndicatorState.loading ||
                controller.state == IndicatorState.complete;

            // Khi loading: dùng bounce animation
            // Khi kéo: bóng nằm giữa, opacity/scale theo pull
            final ballOffsetY = isLoading
                ? bounceH + (_ballY.value + 1) * bounceH / 2 * (-1)
                : bounceH * 0.5;

            final ballScaleX = isLoading ? _scaleX.value : 1.0;
            final ballScaleY = isLoading ? _scaleY.value : 1.0;
            final shadowScale = isLoading ? _shadow.value : 0.8;
            final opacity = pull.clamp(0.0, 1.0);
            final ballScale = isLoading ? 1.0 : (0.5 + pull * 0.5);

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
                    opacity: opacity,
                    child: SizedBox(
                      height: pull * indicatorH,
                      child: Center(
                        child: Transform.scale(
                          scale: ballScale,
                          child: SizedBox(
                            width: ballSize + 16,
                            height: ballSize + bounceH + 8,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                // Shadow
                                Positioned(
                                  bottom: 0,
                                  child: Transform.scale(
                                    scaleX: shadowScale,
                                    child: Container(
                                      width: shadowW,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                            alpha: 0.18 * shadowScale),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                                // Ball
                                Positioned(
                                  bottom: 5 + ballOffsetY,
                                  child: Transform.scale(
                                    scaleX: ballScaleX,
                                    scaleY: ballScaleY,
                                    child: const Text('⚽',
                                        style: TextStyle(fontSize: ballSize)),
                                  ),
                                ),
                              ],
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
