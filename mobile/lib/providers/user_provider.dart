import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  int _totalXp = 0;
  int _streak = 0;
  int _longestStreak = 0;
  int _hearts = 5;
  int _lessonsCompleted = 0;
  String _rank = '-';
  bool _isLoading = false;
  String? _error;
  String _level = 'beginner'; // beginner | intermediate | advanced

  // Completed lesson IDs set
  final Set<String> _completedLessons = {};
  // Topic progress map: topicId -> completedLessons count
  final Map<String, int> _topicProgressMap = {};

  int get totalXp => _totalXp;
  int get streak => _streak;
  int get longestStreak => _longestStreak;
  int get hearts => _hearts;
  int get lessonsCompleted => _lessonsCompleted;
  String get rank => _rank;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<String> get completedLessons => _completedLessons;
  String get level => _level;

  /// Số topic được mở khoá theo level
  int get unlockedTopicCount {
    switch (_level) {
      case 'advanced':
        return 999;
      case 'intermediate':
        return 4;
      default:
        return 2;
    }
  }

  int topicCompletedCount(String topicId) => _topicProgressMap[topicId] ?? 0;

  bool isLessonCompleted(String lessonId) => _completedLessons.contains(lessonId);

  Future<void> loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    _level = prefs.getString('user_level') ?? 'beginner';
    notifyListeners();
  }

  Future<void> setLevel(String level) async {
    _level = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_level', level);
    notifyListeners();
  }

  final _api = ApiService();

  Future<void> refreshStats() async {
    await loadLevel();
    await loadStats();
  }

  Future<void> loadStats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final stats = await _api.getUserStats();
      _totalXp = stats['totalXp'] as int? ?? 0;
      _streak = stats['currentStreak'] as int? ?? stats['streak'] as int? ?? 0;
      _longestStreak = stats['longestStreak'] as int? ?? 0;
      _lessonsCompleted = stats['lessonsCompleted'] as int? ?? 0;
      _rank = stats['rank']?.toString() ?? '-';
    } catch (e) {
      _error = e.toString();
      // Load from local cache
      await _loadFromCache();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTopicProgress() async {
    try {
      final data = await _api.getTopicProgress();
      final progress = data['progress'] as List<dynamic>? ?? [];
      for (final item in progress) {
        final map = item as Map<String, dynamic>;
        final topicId = map['topicId'] as String? ?? '';
        final completed = map['completedLessons'] as int? ?? 0;
        final lessonIds = (map['completedLessonIds'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toSet();
        _topicProgressMap[topicId] = completed;
        _completedLessons.addAll(lessonIds);
      }
    } catch (_) {
      // Ignore - use local state
    }
    notifyListeners();
  }

  void addXp(int xp) {
    _totalXp += xp;
    _saveToCache();
    notifyListeners();
  }

  void markLessonCompleted(String lessonId, String topicId) {
    _completedLessons.add(lessonId);
    _topicProgressMap[topicId] = (_topicProgressMap[topicId] ?? 0) + 1;
    _lessonsCompleted++;
    notifyListeners();
  }

  void loseHeart() {
    if (_hearts > 0) {
      _hearts--;
      notifyListeners();
    }
  }

  void restoreHearts() {
    _hearts = 5;
    notifyListeners();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalXp = prefs.getInt('user_xp') ?? 0;
      _streak = prefs.getInt('user_streak') ?? 0;
      _longestStreak = prefs.getInt('user_longest_streak') ?? 0;
      _lessonsCompleted = prefs.getInt('user_lessons_completed') ?? 0;
    } catch (_) {}
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_xp', _totalXp);
      await prefs.setInt('user_streak', _streak);
      await prefs.setInt('user_longest_streak', _longestStreak);
      await prefs.setInt('user_lessons_completed', _lessonsCompleted);
    } catch (_) {}
  }
}
