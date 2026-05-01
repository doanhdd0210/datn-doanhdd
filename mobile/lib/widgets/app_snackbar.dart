import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum SnackType { success, error, info, warning }

class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    SnackType type = SnackType.success,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final cfg = _config(type);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: duration,
          content: _SnackContent(
            message: message,
            icon: cfg.icon,
            iconColor: cfg.iconColor,
            bgColor: cfg.bgColor,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        ),
      );
  }

  static void success(BuildContext context, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      show(context, message,
          type: SnackType.success,
          actionLabel: actionLabel,
          onAction: onAction);

  static void error(BuildContext context, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      show(context, message,
          type: SnackType.error,
          actionLabel: actionLabel,
          onAction: onAction);

  static void info(BuildContext context, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      show(context, message, type: SnackType.info);

  static void warning(BuildContext context, String message) =>
      show(context, message, type: SnackType.warning);

  static _SnackConfig _config(SnackType type) {
    switch (type) {
      case SnackType.success:
        return _SnackConfig(
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF4CAF50),
          bgColor: const Color(0xFF1C2A1E),
        );
      case SnackType.error:
        return _SnackConfig(
          icon: Icons.error_rounded,
          iconColor: AppColors.red,
          bgColor: const Color(0xFF2A1C1C),
        );
      case SnackType.warning:
        return _SnackConfig(
          icon: Icons.warning_rounded,
          iconColor: const Color(0xFFFFC107),
          bgColor: const Color(0xFF2A2518),
        );
      case SnackType.info:
        return _SnackConfig(
          icon: Icons.info_rounded,
          iconColor: AppColors.blue,
          bgColor: const Color(0xFF1A2230),
        );
    }
  }
}

class _SnackConfig {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  const _SnackConfig({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });
}

class _SnackContent extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SnackContent({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Icon with subtle glow bg
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
