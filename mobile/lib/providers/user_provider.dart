import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  static const int maxHearts = 3;
  static const List<int> dailyGoalOptions = [20, 50, 100];

  int _totalXp = 0;
  int _streak = 0;
  int _longestStreak = 0;
  int _hearts = maxHearts;
  int _lessonsCompleted = 0;
  String _rank = '-';
  bool _isLoading = false;
  String? _error;
  String _level = 'beginner';

  // Daily goal tracking
  int _todayXp = 0;
  int _dailyGoal = 20;
  bool _dailyGoalJustReached = false;
  int _pendingBonusXp = 0;

  // Achievement tracking
  bool _hasPerfectQuiz = false;
  bool _hasFollowed = false;
  Set<String> _seenAchievements = {};
  final List<String> _pendingAchievements = [];

  // Hearts restore: 1 heart per 30 min after losing one
  static const _heartRestoreMinutes = 30;
  DateTime? _lastHeartLostAt;
  Timer? _heartTimer;

  // Completed lesson IDs set
  final Set<String> _completedLessons = {};
  // Topic progress map: topicId -> completedLessons count
  final Map<String, int> _topicProgressMap = {};

  /// Số phút còn lại cho đến khi phục hồi 1 tim tiếp theo
  int get minutesUntilNextHeart {
    if (_hearts >= maxHearts || _lastHeartLostAt == null) return 0;
    final elapsed = DateTime.now().difference(_lastHeartLostAt!).inMinutes;
    return (_heartRestoreMinutes - elapsed).clamp(0, _heartRestoreMinutes);
  }

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
  int get todayXp => _todayXp;
  int get dailyGoal => _dailyGoal;
  bool get isDailyGoalReached => _todayXp >= _dailyGoal;
  double get dailyGoalProgress => _dailyGoal > 0 ? (_todayXp / _dailyGoal).clamp(0.0, 1.0) : 0.0;
  bool get dailyGoalJustReached => _dailyGoalJustReached;
  int get pendingBonusXp => _pendingBonusXp;

  bool get hasPerfectQuiz => _hasPerfectQuiz;
  bool get hasFollowed => _hasFollowed;
  Set<String> get unlockedAchievements => computeUnlocked(
        lessonsCompleted: _lessonsCompleted,
        totalXp: _totalXp,
        streak: _streak,
        hasPerfectQuiz: _hasPerfectQuiz,
        hasFollowed: _hasFollowed,
      );
  List<String> get pendingAchievements => List.unmodifiable(_pendingAchievements);

  void consumePendingAchievements() {
    _pendingAchievements.clear();
  }

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    _level = (uid != null ? prefs.getString('user_level_$uid') : null)
        ?? prefs.getString('user_level')
        ?? 'beginner';
    notifyListeners();
  }

  Future<void> setLevel(String level) async {
    _level = level;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    if (uid != null) {
      await prefs.setString('user_level_$uid', level);
    } else {
      await prefs.setString('user_level', level);
    }
    notifyListeners();
  }

  Future<void> setDailyGoal(int goal) async {
    _dailyGoal = goal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_uidPrefix()}daily_goal', goal);
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

    await _loadFromCache();

    try {
      final stats = await _api.getUserStats();
      _totalXp = stats['totalXp'] as int? ?? 0;
      _streak = stats['currentStreak'] as int? ?? stats['streak'] as int? ?? 0;
      _longestStreak = stats['longestStreak'] as int? ?? 0;
      _lessonsCompleted = stats['lessonsCompleted'] as int? ?? 0;
      _rank = stats['rank']?.toString() ?? '-';
    } catch (e) {
      _error = e.toString();
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
    } catch (_) {}
    notifyListeners();
  }

  void addXp(int xp) {
    final wasBelow = _todayXp < _dailyGoal;
    _totalXp += xp;
    _todayXp += xp;
    final nowReached = _todayXp >= _dailyGoal;

    // Detect first time crossing the goal today
    if (wasBelow && nowReached) {
      _claimDailyGoalBonus();
    }

    _checkNewAchievements();
    _saveToCache();
    notifyListeners();
  }

  Future<void> _claimDailyGoalBonus() async {
    try {
      final result = await _api.claimDailyGoalBonus(_dailyGoal);
      final success = result['success'] == true;
      final bonusXp = result['bonusXp'] as int? ?? 0;
      if (success && bonusXp > 0) {
        _totalXp += bonusXp;
        _todayXp += bonusXp;
        _pendingBonusXp = bonusXp;
        _dailyGoalJustReached = true;
        _saveToCache();
        notifyListeners();
      }
    } catch (_) {}
  }

  void consumeDailyGoalReached() {
    _dailyGoalJustReached = false;
    _pendingBonusXp = 0;
  }

  void markLessonCompleted(String lessonId, String topicId) {
    _completedLessons.add(lessonId);
    _topicProgressMap[topicId] = (_topicProgressMap[topicId] ?? 0) + 1;
    _lessonsCompleted++;
    _checkNewAchievements();
    notifyListeners();
  }

  void markPerfectQuiz() {
    if (_hasPerfectQuiz) return;
    _hasPerfectQuiz = true;
    _checkNewAchievements();
    _saveToCache();
    notifyListeners();
  }

  void markFollowed() {
    if (_hasFollowed) return;
    _hasFollowed = true;
    _checkNewAchievements();
    _saveToCache();
    notifyListeners();
  }

  void _checkNewAchievements() {
    final unlocked = unlockedAchievements;
    for (final id in unlocked) {
      if (!_seenAchievements.contains(id)) {
        _pendingAchievements.add(id);
        _seenAchievements.add(id);
      }
    }
    _saveSeenAchievements();
  }

  Future<void> _saveSeenAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('${_uidPrefix()}seen_achievements', _seenAchievements.toList());
    } catch (_) {}
  }

  void loseHeart() {
    if (_hearts > 0) {
      _hearts--;
      _lastHeartLostAt = DateTime.now();
      _startHeartTimer();
      _saveToCache();
      notifyListeners();
    }
  }

  void restoreHearts() {
    _hearts = maxHearts;
    _lastHeartLostAt = null;
    _heartTimer?.cancel();
    _heartTimer = null;
    _saveToCache();
    notifyListeners();
  }

  void _startHeartTimer() {
    _heartTimer?.cancel();
    _heartTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_hearts >= maxHearts) {
        _heartTimer?.cancel();
        _heartTimer = null;
        return;
      }
      final lost = _lastHeartLostAt;
      if (lost == null) return;
      final elapsed = DateTime.now().difference(lost).inMinutes;
      if (elapsed >= _heartRestoreMinutes) {
        _hearts = (_hearts + 1).clamp(0, maxHearts);
        _lastHeartLostAt = _hearts < maxHearts ? DateTime.now() : null;
        _saveToCache();
        notifyListeners();
      }
    });
  }

  String _uidPrefix() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null ? '${uid}_' : '';
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = _uidPrefix();
      _totalXp = prefs.getInt('${p}user_xp') ?? 0;
      _streak = prefs.getInt('${p}user_streak') ?? 0;
      _longestStreak = prefs.getInt('${p}user_longest_streak') ?? 0;
      _lessonsCompleted = prefs.getInt('${p}user_lessons_completed') ?? 0;
      _hearts = prefs.getInt('${p}user_hearts') ?? maxHearts;
      _dailyGoal = prefs.getInt('${p}daily_goal') ?? 20;

      // Load todayXp — reset if stored date differs from today
      final today = _todayKey();
      final storedDate = prefs.getString('${p}today_xp_date') ?? '';
      _todayXp = storedDate == today ? (prefs.getInt('${p}today_xp') ?? 0) : 0;

      // Achievement flags
      _hasPerfectQuiz = prefs.getBool('${p}has_perfect_quiz') ?? false;
      _hasFollowed = prefs.getBool('${p}has_followed') ?? false;
      final seen = prefs.getStringList('${p}seen_achievements') ?? [];
      _seenAchievements = seen.toSet();
    } catch (_) {}
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = _uidPrefix();
      await prefs.setInt('${p}user_xp', _totalXp);
      await prefs.setInt('${p}user_streak', _streak);
      await prefs.setInt('${p}user_longest_streak', _longestStreak);
      await prefs.setInt('${p}user_lessons_completed', _lessonsCompleted);
      await prefs.setInt('${p}user_hearts', _hearts);
      await prefs.setInt('${p}today_xp', _todayXp);
      await prefs.setString('${p}today_xp_date', _todayKey());
      await prefs.setBool('${p}has_perfect_quiz', _hasPerfectQuiz);
      await prefs.setBool('${p}has_followed', _hasFollowed);
    } catch (_) {}
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _heartTimer?.cancel();
    super.dispose();
  }
}
