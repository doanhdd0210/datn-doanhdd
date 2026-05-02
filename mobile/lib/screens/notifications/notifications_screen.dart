import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';
import '../../models/qa_post.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_loading.dart';
import '../social/qa_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await _api.getMyNotifications();
    if (mounted) {
      setState(() {
        final raw = data['notifications'];
        _notifications = raw is List ? raw.cast<Map<String, dynamic>>() : [];
        _unreadCount = data['unreadCount'] as int? ?? 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await _api.markAllNotificationsRead();
    setState(() {
      _unreadCount = 0;
      for (final n in _notifications) {
        n['isRead'] = true;
      }
    });
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Vừa xong';
      if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
      if (diff.inHours < 24) return '${diff.inHours} giờ trước';
      if (diff.inDays < 7) return '${diff.inDays} ngày trước';
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        title: Row(
          children: [
            Text('Thông báo', style: AppTextStyles.heading3.copyWith(color: context.textPrimary)),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
        foregroundColor: context.textPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.borderColor),
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Đọc tất cả',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const AppLoadingCenter()
          : _notifications.isEmpty
              ? _buildEmpty(context)
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildItem(_notifications[index], context),
                  ),
                ),
    );
  }

  Future<void> _handleTap(Map<String, dynamic> notif) async {
    final type = notif['type'] as String? ?? 'system';
    final refId = notif['refId'] as String?;
    final notifId = notif['id'] as String? ?? notif['Id'] as String?;
    final isRead = notif['isRead'] as bool? ?? false;

    // Mark as read immediately
    if (!isRead && notifId != null) {
      _api.markNotificationRead(notifId);
      setState(() {
        notif['isRead'] = true;
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
      });
    }

    final ns = NotificationService();
    switch (type) {
      case 'qa_answer':
        if (refId != null) {
          final postData = await _api.getQaPost(refId);
          if (postData != null && mounted) {
            final post = QaPost.fromJson(postData);
            Navigator.of(context).pop();
            await Future.delayed(const Duration(milliseconds: 100));
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => QaDetailScreen(post: post)),
              );
            }
          } else if (mounted) {
            ns.navigationRequests.add('qa');
            Navigator.of(context).pop();
          }
        } else {
          ns.navigationRequests.add('qa');
          Navigator.of(context).pop();
        }
        break;
      case 'follow':
        ns.navigationRequests.add('friends');
        Navigator.of(context).pop();
        break;
      case 'achievement':
        ns.navigationRequests.add('profile');
        Navigator.of(context).pop();
        break;
      default:
        break;
    }
  }

  Widget _buildItem(Map<String, dynamic> notif, BuildContext context) {
    final type = notif['type'] as String? ?? 'system';
    final title = notif['title'] as String? ?? 'Thông báo';
    final body = notif['body'] as String? ?? '';
    final actorName = notif['actorName'] as String?;
    final actorAvatar = notif['actorAvatar'] as String? ?? '';
    final isRead = notif['isRead'] as bool? ?? false;
    final createdAt = notif['createdAt'] as String?;

    final config = _typeConfig(type);

    return GestureDetector(
      onTap: () => _handleTap(notif),
      child: Container(
      decoration: BoxDecoration(
        color: isRead ? context.surfaceColor : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? context.borderColor : AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar hoặc icon
            _buildAvatar(type, actorName, actorAvatar, config),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(createdAt),
                    style: TextStyle(fontSize: 11, color: context.textSecondary.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
    );
  }

  Widget _buildAvatar(String type, String? actorName, String actorAvatar, _NotifConfig config) {
    if (type == 'follow' && actorName != null) {
      return Stack(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            backgroundImage: actorAvatar.isNotEmpty
                ? CachedNetworkImageProvider(actorAvatar)
                : null,
            child: actorAvatar.isEmpty
                ? Text(
                    actorName.isNotEmpty ? actorName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                  )
                : null,
          ),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: config.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Icon(config.icon, size: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(config.icon, color: config.color, size: 22),
    );
  }

  _NotifConfig _typeConfig(String type) {
    switch (type) {
      case 'follow':
        return _NotifConfig(Icons.person_add_rounded, AppColors.primary);
      case 'quiz_complete':
        return _NotifConfig(Icons.quiz_rounded, AppColors.correct);
      case 'achievement':
        return _NotifConfig(Icons.emoji_events_rounded, AppColors.xpGold);
      default:
        return _NotifConfig(Icons.notifications_rounded, AppColors.blue);
    }
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: context.surfaceColor,
              shape: BoxShape.circle,
              border: Border.all(color: context.borderColor),
            ),
            child: Icon(Icons.notifications_none_rounded, size: 40, color: context.textSecondary),
          ),
          const SizedBox(height: 16),
          Text('Chưa có thông báo nào',
              style: AppTextStyles.heading4.copyWith(color: context.textPrimary)),
          const SizedBox(height: 8),
          Text('Các thông báo mới sẽ hiển thị ở đây',
              style: AppTextStyles.bodySmall.copyWith(color: context.textSecondary)),
        ],
      ),
    );
  }
}

class _NotifConfig {
  final IconData icon;
  final Color color;
  const _NotifConfig(this.icon, this.color);
}
