import 'package:flutter/foundation.dart';
import '../services/ai_service.dart';

class AiUsageProvider extends ChangeNotifier {
  int _used = 0;
  int _limit = 10;
  bool _loaded = false;
  String? _planType; // "standard" | "max" | null

  int get used => _used;
  int get limit => _limit;
  bool get loaded => _loaded;
  String? get planType => _planType;
  bool get isUnlimited => _planType == 'max';
  bool get isExhausted => _loaded && !isUnlimited && _used >= _limit;

  Future<void> load() async {
    try {
      final info = await AiService().getUsage();
      _used = info['used'] as int;
      _limit = info['limit'] as int;
      _planType = info['planType'] as String?;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Không chặn UI nếu network lỗi
    }
  }

  void reset() {
    _used = 0;
    _limit = 10;
    _loaded = false;
    _planType = null;
    notifyListeners();
  }
}
