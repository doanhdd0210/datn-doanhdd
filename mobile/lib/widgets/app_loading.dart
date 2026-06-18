import 'package:flutter/material.dart';

/// Bouncing ⚽ với squish + shadow — dùng toàn app thay CircularProgressIndicator.
class AppLoading extends StatefulWidget {
  final bool small;

  const AppLoading({super.key}) : small = false;
  const AppLoading.small({super.key}) : small = true;

  @override
  State<AppLoading> createState() => _AppLoadingState();
}

class _AppLoadingState extends State<AppLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _ballY;
  late final Animation<double> _scaleX;
  late final Animation<double> _scaleY;
  late final Animation<double> _shadow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat();

    // Bóng bay lên (easeOut) rồi rơi xuống (easeIn)
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
    ]).animate(_ctrl);

    // Squish khi chạm đất (cuối chu kỳ và đầu chu kỳ)
    _scaleX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 8),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 84),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 8),
    ]).animate(_ctrl);

    _scaleY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 8),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 84),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 8),
    ]).animate(_ctrl);

    // Shadow: lớn khi bóng ở dưới, nhỏ khi bóng lên cao
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
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.small ? _small() : _full();

  Widget _full() {
    const ballSize = 44.0;
    const bounceH = 44.0;
    const shadowW = 32.0;
    const totalH = ballSize + bounceH + 10;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => SizedBox(
        width: ballSize + 16,
        height: totalH,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Shadow
            Positioned(
              bottom: 0,
              child: Transform.scale(
                scaleX: _shadow.value,
                child: Container(
                  width: shadowW,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18 * _shadow.value),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            // Ball
            Positioned(
              bottom: 7 + (_ballY.value + 1) * bounceH / 2 * (-1) + bounceH,
              child: Transform.scale(
                scaleX: _scaleX.value,
                scaleY: _scaleY.value,
                child: const Text('⚽', style: TextStyle(fontSize: ballSize)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _small() {
    const ballSize = 16.0;
    const bounceH = 10.0;
    const shadowW = 12.0;
    const totalH = ballSize + bounceH + 6.0;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => SizedBox(
        width: ballSize + 8,
        height: totalH,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: 0,
              child: Transform.scale(
                scaleX: _shadow.value,
                child: Container(
                  width: shadowW,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15 * _shadow.value),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 3 + (_ballY.value + 1) * bounceH / 2 * (-1) + bounceH,
              child: Transform.scale(
                scaleX: _scaleX.value,
                scaleY: _scaleY.value,
                child: const Text('⚽', style: TextStyle(fontSize: ballSize)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen centered loading
class AppLoadingCenter extends StatelessWidget {
  final Color? color;
  const AppLoadingCenter({super.key, this.color});

  @override
  Widget build(BuildContext context) => const Center(child: AppLoading());
}
