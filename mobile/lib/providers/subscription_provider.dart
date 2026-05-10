import 'package:flutter/foundation.dart';
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
