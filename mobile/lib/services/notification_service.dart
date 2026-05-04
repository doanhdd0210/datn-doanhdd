import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

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

  // false nếu đang chạy trên emulator / thiết bị không có Play Services
  bool _fcmAvailable = false;

  final foregroundMessages = StreamController<RemoteMessage>.broadcast();
  final navigationRequests = StreamController<String>.broadcast();
  // Emits the data payload of every received notification (foreground + opened from bg/terminated)
  final dataMessages = StreamController<Map<String, dynamic>>.broadcast();

  Future<void> init() async {
    // Thử lấy token để kiểm tra FCM có khả dụng không
    // Emulator hoặc thiết bị không có Google Play Services sẽ fail ở đây
    try {
      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      if (token == null) {
        debugPrint('[FCM] Không lấy được token — bỏ qua FCM (emulator?)');
        return;
      }
      _fcmAvailable = true;
      debugPrint('[FCM] Token: $token');
      await _uploadToken(token);
    } catch (e) {
      debugPrint('[FCM] FCM không khả dụng (emulator / no Play Services): $e');
      return; // Bỏ qua toàn bộ setup FCM
    }

    // Chỉ chạy phần dưới nếu FCM khả dụng
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] Token refreshed: $newToken');
      _uploadToken(newToken);
    });

    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('[FCM Foreground] ${msg.notification?.title}: ${msg.notification?.body}');
      foregroundMessages.add(msg);
      dataMessages.add(msg.data);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('[FCM Opened] ${msg.data}');
      _handleNavigationData(msg.data);
      dataMessages.add(msg.data);
    });

    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM Initial] App mở từ notification: ${initialMessage.data}');
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleNavigationData(initialMessage.data);
          dataMessages.add(initialMessage.data);
        });
      }
    } catch (e) {
      debugPrint('[FCM] getInitialMessage failed: $e');
    }
  }

  Future<void> _uploadToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();
      await http.post(
        Uri.parse('${ApiService.baseUrl}/users/me/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'token': token}),
      );
    } catch (e) {
      debugPrint('[FCM] Token upload failed: $e');
    }
  }

  void _handleNavigationData(Map<String, dynamic> data) {
    final screen = data['screen'] as String?;
    if (screen == null) return;
    navigationRequests.add(screen);
  }

  /// Gọi sau khi user đăng nhập để đảm bảo token được sync lên server.
  Future<void> syncToken() async {
    if (!_fcmAvailable) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) await _uploadToken(token);
    } catch (_) {}
  }

  Future<String?> getToken() => _fcmAvailable ? _messaging.getToken() : Future.value(null);

  Future<void> subscribeToTopic(String topic) async {
    if (!_fcmAvailable) return;
    await _messaging.subscribeToTopic(topic);
    debugPrint('[FCM] Subscribed to topic: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_fcmAvailable) return;
    await _messaging.unsubscribeFromTopic(topic);
  }

  void dispose() {
    foregroundMessages.close();
    navigationRequests.close();
    dataMessages.close();
  }
}
