import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum SnackType { success, error, info, warning }

class AppSnackBar {
  AppSnackBar._();

  // Hiển thị ở trên cùng màn hình (dùng Overlay), dùng cho thông báo push
  static void showTop(
    BuildContext context,
    String message, {
    SnackType type = SnackType.info,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cfg = _config(type, isDark);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopBanner(
        message: message,
        icon: cfg.icon,
        iconColor: cfg.iconColor,
        bgColor: cfg.bgColor,
        textColor: cfg.textColor,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        isDark: isDark,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  static void show(
    BuildContext context,
    String message, {
    SnackType type = SnackType.success,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cfg = _config(type, isDark);

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
            textColor: cfg.textColor,
            isDark: isDark,
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

  static _SnackConfig _config(SnackType type, bool isDark) {
    switch (type) {
      case SnackType.success:
        return _SnackConfig(
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF4CAF50),
          bgColor: isDark ? const Color(0xFF1C2A1E) : const Color(0xFFEDF7ED),
          textColor: isDark ? Colors.white : const Color(0xFF1A1A2E),
        );
      case SnackType.error:
        return _SnackConfig(
          icon: Icons.error_rounded,
          iconColor: AppColors.red,
          bgColor: isDark ? const Color(0xFF2A1C1C) : const Color(0xFFFDECEC),
          textColor: isDark ? Colors.white : const Color(0xFF1A1A2E),
        );
      case SnackType.warning:
        return _SnackConfig(
          icon: Icons.warning_rounded,
          iconColor: const Color(0xFFFFC107),
          bgColor: isDark ? const Color(0xFF2A2518) : const Color(0xFFFFF3E0),
          textColor: isDark ? Colors.white : const Color(0xFF1A1A2E),
        );
      case SnackType.info:
        return _SnackConfig(
          icon: Icons.info_rounded,
          iconColor: AppColors.blue,
          bgColor: isDark ? const Color(0xFF1A2230) : const Color(0xFFE3F2FD),
          textColor: isDark ? Colors.white : const Color(0xFF1A1A2E),
        );
    }
  }
}

class _SnackConfig {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color textColor;
  const _SnackConfig({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.textColor,
  });
}

class _TopBanner extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color textColor;
  final bool isDark;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopBanner({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.textColor,
    required this.isDark,
    required this.duration,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();

    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.iconColor.withValues(alpha: 0.25),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: widget.isDark ? 0.45 : 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.iconColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon, color: widget.iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: widget.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (widget.actionLabel != null && widget.onAction != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          widget.onAction!();
                          _dismiss();
                        },
                        child: Text(
                          widget.actionLabel!,
                          style: TextStyle(
                            color: widget.iconColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SnackContent extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color textColor;
  final bool isDark;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SnackContent({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.textColor,
    required this.isDark,
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
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
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
              style: TextStyle(
                color: textColor,
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
