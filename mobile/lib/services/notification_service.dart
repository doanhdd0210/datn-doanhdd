import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

// Handler chạy khi app ở background/terminated — phải là top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] ${message.notification?.title}: ${message.notification?.body}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    // 1. Xin quyền thông báo
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Người dùng từ chối thông báo');
      return;
    }

    // 2. Đăng ký background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3. Lấy FCM token
    final token = await _messaging.getToken(
      // vapidKey chỉ cần cho Web — lấy tại Firebase Console > Project Settings > Cloud Messaging > Web Push certificates
      // vapidKey: 'YOUR_VAPID_KEY',
    );
    debugPrint('[FCM] Token: $token');

    // 4. Lắng nghe khi token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] Token refreshed: $newToken');
      // TODO: Gửi token mới lên server của bạn
    });

    // 5. Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM Foreground] ${message.notification?.title}: ${message.notification?.body}');
      // TODO: Hiển thị in-app notification tại đây
      // Ví dụ: dùng flutter_local_notifications để show banner
    });

    // 6. Khi user tap notification mà app đang background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM Opened] ${message.data}');
      // TODO: Navigate đến màn hình tương ứng dựa vào message.data
    });

    // 7. Kiểm tra notification mở app từ terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM Initial] App mở từ notification: ${initialMessage.data}');
    }
  }

  // Lấy FCM token (dùng để gửi notification đến thiết bị cụ thể)
  Future<String?> getToken() => _messaging.getToken();

  // Đăng ký theo topic (gửi broadcast cho nhóm user)
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('[FCM] Subscribed to topic: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
