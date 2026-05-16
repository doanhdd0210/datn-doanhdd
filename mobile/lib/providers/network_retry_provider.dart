import 'package:flutter/foundation.dart';

class NetworkRetryProvider extends ChangeNotifier {
  void retry() => notifyListeners();
}
