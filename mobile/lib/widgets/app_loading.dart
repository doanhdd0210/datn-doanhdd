import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Bouncing-dots loading indicator dùng thay CircularProgressIndicator toàn app.
/// Dùng [AppLoading()] cho full-screen center loading.
/// Dùng [AppLoading.small()] cho inline (ví dụ trong list item).
class AppLoading extends StatefulWidget {
  final Color? color;
  final double dotSize;
  final double spacing;

  const AppLoading({
    super.key,
    this.color,
    this.dotSize = 9,
    this.spacing = 6,
  });

  /// Nhỏ hơn, dùng inline trong list/card
  const AppLoading.small({super.key, this.color})
      : dotSize = 7,
        spacing = 5;

  @override
  State<AppLoading> createState() => _AppLoadingState();
}

class _AppLoadingState extends State<AppLoading> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  static const _count = 3;
  static const _duration = Duration(milliseconds: 500);
  static const _staggerMs = 120;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _count,
      (i) => AnimationController(vsync: this, duration: _duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _controllers[i].reverse();
          } else if (status == AnimationStatus.dismissed) {
            Future.delayed(Duration(milliseconds: _staggerMs * _count), () {
              if (mounted) _controllers[i].forward();
            });
          }
        }),
    );

    _anims = _controllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeInOut))
        .toList();

    for (int i = 0; i < _count; i++) {
      Future.delayed(Duration(milliseconds: _staggerMs * i), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;
    final size = widget.dotSize;
    final jump = size * 1.6;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_count, (i) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
          child: AnimatedBuilder(
            animation: _anims[i],
            builder: (_, __) => Transform.translate(
              offset: Offset(0, -jump * _anims[i].value),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color.withValues(
                      alpha: 0.5 + 0.5 * _anims[i].value),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Full-screen centered loading — thay Center(child: CircularProgressIndicator(...))
class AppLoadingCenter extends StatelessWidget {
  final Color? color;
  const AppLoadingCenter({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(child: AppLoading(color: color));
  }
}
