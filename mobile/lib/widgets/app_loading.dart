import 'dart:math';
import 'package:flutter/material.dart';

/// ⚽ lăn trên sân cỏ từ trái sang phải — World Cup seasonal loading.
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.small ? _SmallRollingBall(ctrl: _ctrl) : _FullRollingBall(ctrl: _ctrl);
}

class _FullRollingBall extends StatelessWidget {
  final AnimationController ctrl;
  const _FullRollingBall({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    const w = 140.0;
    const ballSize = 36.0;
    const grassH = 3.0;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        // Easing: easeInOut để bóng không dừng đột ngột khi reset
        final t = Curves.easeInOut.transform(ctrl.value);
        final ballX = t * (w - ballSize);
        // Bóng xoay đúng chiều lăn — 1 vòng = ballSize * π (circumference)
        final rotations = ballX / (ballSize * pi);
        final angle = rotations * 2 * pi;

        return SizedBox(
          width: w,
          height: ballSize + grassH + 6,
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
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Vạch giữa sân
              Positioned(
                bottom: 0,
                left: w / 2 - 1,
                child: Container(
                  width: 2,
                  height: grassH + 4,
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                ),
              ),
              // Bóng
              Positioned(
                left: ballX,
                bottom: grassH + 2,
                child: Transform.rotate(
                  angle: angle,
                  child: const Text('⚽',
                      style: TextStyle(fontSize: ballSize, height: 1)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SmallRollingBall extends StatelessWidget {
  final AnimationController ctrl;
  const _SmallRollingBall({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    const w = 64.0;
    const ballSize = 18.0;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(ctrl.value);
        final ballX = t * (w - ballSize);
        final angle = (ballX / (ballSize * pi)) * 2 * pi;

        return SizedBox(
          width: w,
          height: ballSize + 4,
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              Positioned(
                left: ballX,
                bottom: 3,
                child: Transform.rotate(
                  angle: angle,
                  child: const Text('⚽',
                      style: TextStyle(fontSize: ballSize, height: 1)),
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
  Widget build(BuildContext context) => const Center(child: AppLoading());
}
