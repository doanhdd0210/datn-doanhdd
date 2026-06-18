import 'dart:math';
import 'package:flutter/material.dart';

/// Loading indicator chính toàn app — cầu thủ sút bóng.
/// [AppLoading()] cho full-size, [AppLoading.small()] cho inline.
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

  // Ball X: 0 (player) → 1 (right edge) → 0 (back)
  late final Animation<double> _ballX;
  // Ball Y: parabolic arc up-down khi sút
  late final Animation<double> _ballY;
  // Ball rotation
  late final Animation<double> _ballRot;
  // Player kick (forward lean lúc t=0→0.1, rồi return)
  late final Animation<double> _kick;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    // Nửa đầu: bóng bay sang phải, nửa sau: lăn về
    _ballX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
    ]).animate(_ctrl);

    // Bóng bay lên (arc) khi sút, lăn phẳng khi về
    _ballY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 27,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.0),
        weight: 45,
      ),
    ]).animate(_ctrl);

    // Bóng xoay liên tục
    _ballRot = Tween<double>(begin: 0, end: 2 * pi).animate(_ctrl);

    // Cầu thủ: chân đá nhanh lúc đầu rồi đứng yên
    _kick = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.35)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.35, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.0),
        weight: 80,
      ),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.small) return _buildSmall();

    const w = 130.0;
    const h = 56.0;
    const playerSize = 34.0;
    const ballSize = 20.0;
    const arcHeight = 22.0;
    // Bóng bắt đầu ngay cạnh chân cầu thủ
    const ballStartX = playerSize - 4.0;
    const ballTravelW = w - ballStartX - ballSize;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final bx = ballStartX + _ballX.value * ballTravelW;
        final by = h * 0.62 + _ballY.value * arcHeight;

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Cầu thủ
              Positioned(
                left: 0,
                top: h * 0.18,
                child: Transform.rotate(
                  angle: _kick.value,
                  alignment: Alignment.bottomCenter,
                  child: const Text('🏃‍♂️',
                      style: TextStyle(fontSize: playerSize)),
                ),
              ),
              // Bóng
              Positioned(
                left: bx,
                top: by,
                child: Transform.rotate(
                  angle: _ballRot.value,
                  child: const Text('⚽',
                      style: TextStyle(fontSize: ballSize)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSmall() {
    // Inline nhỏ: chỉ bóng lăn qua lại
    const w = 56.0;
    const ballSize = 14.0;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final bx = _ballX.value * (w - ballSize);
        return SizedBox(
          width: w,
          height: 20,
          child: Stack(
            children: [
              Positioned(
                left: bx,
                top: 3,
                child: Transform.rotate(
                  angle: _ballRot.value,
                  child: const Text('⚽',
                      style: TextStyle(fontSize: ballSize)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Full-screen centered loading
class AppLoadingCenter extends StatelessWidget {
  final Color? color;
  const AppLoadingCenter({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return const Center(child: AppLoading());
  }
}
