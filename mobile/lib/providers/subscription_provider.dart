import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../models/user_subscription.dart';
import '../services/api_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  UserSubscription? _subscription;
  bool _loaded = false;

  UserSubscription? get subscription => _subscription;
  bool get isLoaded => _loaded;
  bool get isPremium => _subscription != null && _subscription!.isActive;
  bool get isMax => _subscription?.isMax ?? false;
  bool get isStandard => _subscription?.isStandard ?? false;

  Future<void> load() async {
    try {
      final data = await ApiService().getMySubscription();
      if (data != null) {
        _subscription = UserSubscription.fromJson(data);
      } else {
        _subscription = null;
      }
    } catch (_) {
      _subscription = null;
    } finally {
      _loaded = true;
      notifyListeners();
    }

    // Nếu backend nói inactive hoặc ExpiresAt sắp hết (≤ 3 ngày) → hỏi Google Play
    // để lấy ExpiresAt mới nhất (xử lý trường hợp gia hạn tự động)
    await _syncWithGooglePlay();
  }

  /// So sánh trạng thái từ Google Play với backend.
  /// Nếu Google Play có purchase nhưng backend stale → re-verify để refresh ExpiresAt.
  Future<void> _syncWithGooglePlay() async {
    if (!Platform.isAndroid) return;

    final needsSync = _subscription == null ||
        !_subscription!.isActive ||
        (_subscription!.expiresAt != null &&
            _subscription!.expiresAt!
                .isBefore(DateTime.now().add(const Duration(days: 3))));

    if (!needsSync) return;

    try {
      final iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) return;

      final androidAddition =
          iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await androidAddition.queryPastPurchases();

      if (response.pastPurchases.isEmpty) return;

      // Lấy subscription purchase mới nhất
      final purchase = response.pastPurchases.firstOrNull;
      if (purchase == null) return;

      final token = purchase.verificationData.serverVerificationData;
      if (token.isEmpty) return;

      // Nếu token trùng với backend VÀ ExpiresAt còn hạn → không cần verify lại
      if (_subscription != null &&
          _subscription!.purchaseToken == token &&
          _subscription!.isActive &&
          _subscription!.expiresAt != null &&
          _subscription!.expiresAt!
              .isAfter(DateTime.now().add(const Duration(days: 3)))) {
        return;
      }

      // Re-verify với backend để lấy ExpiresAt mới từ Google Play
      final data = await ApiService().verifySubscription(
        purchaseToken: token,
        productId: purchase.productID,
        orderId: purchase.purchaseID ?? '',
        productType: 'subscription',
      );

      final inner = data['data'];
      if (inner != null) {
        _subscription = UserSubscription.fromJson(inner as Map<String, dynamic>);
        notifyListeners();
      }
    } catch (_) {
      // Sync thất bại không ảnh hưởng luồng chính
    }
  }

  void setSubscription(UserSubscription sub) {
    _subscription = sub;
    _loaded = true;
    notifyListeners();
  }

  void clear() {
    _subscription = null;
    _loaded = false;
    notifyListeners();
  }
}
