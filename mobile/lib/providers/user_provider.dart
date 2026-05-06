import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
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
  bool _statsInitialized = false;
  String? _error;
  String _level = 'beginner';

  // Daily goal tracking
  int _todayXp = 0;
  int _dailyGoal = 20;
  bool _dailyGoalJustReached = false;
  int _pendingBonusXp = 0;
  bool _dailyGoalBonusClaimedToday = false;
  List<Map<String, dynamic>> _dailyGoalBonusConfigs = [];
  bool _bonusConfigsLoaded = false;

  // Achievement tracking — server-driven
  List<Achievement> _achievements = [];           // full list từ server
  bool _achievementsLoaded = false;               // đã fetch xong (dù thành hay thất bại)

  /// Danh sách định nghĩa thành tích local — hiển thị khi API không phản hồi
  // Fallback khi server không trả về — phải khớp đúng 10 achievements trong DbSeeder
  static final List<Achievement> _localAchievementDefs = [
    Achievement(id: 'first_lesson', title: 'Bước đầu tiên', description: 'Hoàn thành bài học đầu tiên',  emoji: '🎓', color: Color(0xFF6949FF), conditionType: 'lessonCount', conditionValue: 1,   xpReward: 20),
    Achievement(id: 'lessons_5',    title: 'Khởi đầu tốt',  description: 'Hoàn thành 5 bài học',         emoji: '✨', color: Color(0xFF6949FF), conditionType: 'lessonCount', conditionValue: 5,   xpReward: 30),
    Achievement(id: 'lessons_10',   title: 'Chăm học',       description: 'Hoàn thành 10 bài học',        emoji: '📚', color: Color(0xFF6949FF), conditionType: 'lessonCount', conditionValue: 10,  xpReward: 50),
    Achievement(id: 'xp_50',        title: 'Khởi động',      description: 'Kiếm được 50 XP',              emoji: '⭐', color: Color(0xFFFFC107), conditionType: 'xpRequired',  conditionValue: 50,  xpReward: 5),
    Achievement(id: 'xp_100',       title: 'Tập sự',         description: 'Kiếm được 100 XP',             emoji: '⚡', color: Color(0xFFFFC107), conditionType: 'xpRequired',  conditionValue: 100, xpReward: 10),
    Achievement(id: 'xp_500',       title: 'Thành thạo',     description: 'Kiếm được 500 XP',             emoji: '🔥', color: Color(0xFFFFC107), conditionType: 'xpRequired',  conditionValue: 500, xpReward: 30),
    Achievement(id: 'streak_3',     title: 'Kiên trì',       description: 'Học 3 ngày liên tiếp',         emoji: '🗓️', color: Color(0xFFFF5722), conditionType: 'streakDays',  conditionValue: 3,   xpReward: 20),
    Achievement(id: 'streak_7',     title: 'Tuần lễ vàng',   description: 'Học 7 ngày liên tiếp',         emoji: '🏆', color: Color(0xFFFF5722), conditionType: 'streakDays',  conditionValue: 7,   xpReward: 70),
    Achievement(id: 'quiz_perfect', title: 'Hoàn hảo',       description: 'Đạt 100% trong một bài quiz',  emoji: '🎯', color: Color(0xFF4CAF50), conditionType: 'perfectQuiz', conditionValue: 1,   xpReward: 30),
    Achievement(id: 'social_1',     title: 'Kết nối',        description: 'Theo dõi một người dùng',      emoji: '👥', color: Color(0xFF50B0FF), conditionType: 'followAny',   conditionValue: 1,   xpReward: 10),
  ];

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
  bool get dailyGoalBonusClaimedToday => _dailyGoalBonusClaimedToday;

  int bonusForGoal(int goal) {
    for (final config in _dailyGoalBonusConfigs) {
      if (config['goalXp'] == goal) return config['bonusXp'] as int? ?? 0;
    }
    return 0;
  }

  bool get achievementsLoaded => _achievementsLoaded;
  List<Achievement> get achievements => List.unmodifiable(
    _achievements.isNotEmpty ? _achievements : _localAchievementDefs,
  );
  Set<String> get unlockedAchievements =>
      _achievements.where((a) => a.isUnlocked).map((a) => a.id).toSet();
  /// Số topic được mở khoá theo level
  int get unlockedTopicCount {
    switch (_level) {
      case 'advanced':
        return 3;
      case 'intermediate':
        return 2;
      default: // beginner
        return 1;
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
    // Sync lên BE (fire-and-forget, không block UI)
    _api.setMyLevel(level).catchError((_) {});
    notifyListeners();
  }

  Future<void> setDailyGoal(int goal) async {
    _dailyGoal = goal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_uidPrefix()}daily_goal', goal);
    notifyListeners();
    // Sync to BE (fire-and-forget)
    _api.setDailyGoal(goal).catchError((_) {});
  }

  final _api = ApiService();

  Future<void> refreshStats() async {
    await loadLevel();
    await Future.wait([loadStats(), loadAchievements()]);
  }

  Future<void> loadStats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (!_statsInitialized) {
      await _loadFromCache();
    }

    try {
      final stats = await _api.getUserStats();
      _totalXp = stats['totalXp'] as int? ?? 0;
      _todayXp = stats['todayXp'] as int? ?? 0;
      _streak = stats['currentStreak'] as int? ?? stats['streak'] as int? ?? 0;
      _longestStreak = stats['longestStreak'] as int? ?? 0;
      _lessonsCompleted = stats['lessonsCompleted'] as int? ?? 0;
      _rank = stats['rank']?.toString() ?? '-';
      final beLevel = stats['level'] as String?;
      if (beLevel != null && beLevel.isNotEmpty && (beLevel != 'beginner' || _level == 'beginner')) {
        _level = beLevel;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final prefs = await SharedPreferences.getInstance();
        if (uid != null) await prefs.setString('user_level_$uid', beLevel);
      }
      // Sync daily goal target from BE (source of truth)
      final beGoal = stats['dailyGoalTarget'] as int?;
      if (beGoal != null && beGoal > 0) {
        _dailyGoal = beGoal;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('${_uidPrefix()}daily_goal', beGoal);
      }
      // Sync claimed-today state from BE
      final beClaimedToday = stats['dailyGoalBonusClaimedToday'] as bool? ?? false;
      if (beClaimedToday && !_dailyGoalBonusClaimedToday) {
        _dailyGoalBonusClaimedToday = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('${_uidPrefix()}daily_goal_claimed_date', _todayKey());
      }
      _statsInitialized = true;
      await _saveToCache();
      // Load bonus configs once per session
      if (!_bonusConfigsLoaded) _loadBonusConfigs();
      // Fallback: if goal reached but bonus not yet claimed, trigger via manual endpoint
      // (covers cases where BE push notification was missed or XP was earned before new BE code)
      if (_todayXp >= _dailyGoal && !_dailyGoalBonusClaimedToday) {
        _triggerDailyGoalClaimFallback();
      }
    } catch (e) {
      _error = e.toString();
      if (!_statsInitialized) {
        await _loadFromCache();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTopicProgress() async {
    try {
      // Backend trả về List<UserProgress>: [{ lessonId, topicId, isCompleted, score }]
      final list = await _api.getTopicProgress();
      _topicProgressMap.clear();
      _completedLessons.clear();
      for (final map in list) {
        final topicId  = map['topicId']    as String? ?? '';
        final lessonId = map['lessonId']   as String? ?? '';
        final isCompleted = map['isCompleted'] as bool? ?? false;
        if (isCompleted && lessonId.isNotEmpty) {
          _completedLessons.add(lessonId);
          if (topicId.isNotEmpty) {
            _topicProgressMap[topicId] = (_topicProgressMap[topicId] ?? 0) + 1;
          }
        }
      }
    } catch (_) {}
    notifyListeners();
  }


  Future<void> _triggerDailyGoalClaimFallback() async {
    try {
      final result = await _api.claimDailyGoalBonus(_dailyGoal);
      final success = result['success'] == true;
      final bonusXp = result['bonusXp'] as int? ?? 0;
      if (success && bonusXp > 0) {
        handleDailyGoalBonusReceived(bonusXp);
      }
    } catch (_) {}
  }

  Future<void> _loadBonusConfigs() async {
    _bonusConfigsLoaded = true;
    try {
      final configs = await _api.getDailyGoalBonusConfigs();
      if (configs.isNotEmpty) {
        _dailyGoalBonusConfigs = configs;
        notifyListeners();
      }
    } catch (_) {}
  }

  void consumeDailyGoalReached() {
    _dailyGoalJustReached = false;
    _pendingBonusXp = 0;
  }

  /// Called when push notification for daily_goal is received.
  void handleDailyGoalBonusReceived(int bonusXp) {
    if (_dailyGoalBonusClaimedToday) return;
    _dailyGoalBonusClaimedToday = true;
    _pendingBonusXp = bonusXp;
    _dailyGoalJustReached = true;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('${_uidPrefix()}daily_goal_claimed_date', _todayKey());
    });
    loadStats();
  }

  void markLessonCompleted(String lessonId, String topicId) {
    // Idempotent: không tăng counter nếu đã completed rồi
    if (_completedLessons.contains(lessonId)) return;
    _completedLessons.add(lessonId);
    _topicProgressMap[topicId] = (_topicProgressMap[topicId] ?? 0) + 1;
    _lessonsCompleted++;
    pollNewAchievements();
    notifyListeners();
  }

  void markPerfectQuiz() => pollNewAchievements();
  void markFollowed() => pollNewAchievements();

  /// Poll server for newly unlocked achievements and credit their XP to today's total.
  Future<void> pollNewAchievements() async {
    try {
      final newOnes = await _api.consumeNewAchievements();
      if (newOnes.isEmpty) return;
      bool changed = false;
      int bonusXpFromAchievements = 0;
      for (final json in newOnes) {
        final achievement = Achievement.fromJson(json);
        final idx = _achievements.indexWhere((a) => a.id == achievement.id);
        if (idx >= 0) {
          _achievements[idx] = _achievements[idx].copyWith(
            isUnlocked: true,
            unlockedAt: achievement.unlockedAt,
          );
        } else {
          _achievements.add(achievement);
        }
        bonusXpFromAchievements += achievement.xpReward;
        changed = true;
      }
      if (bonusXpFromAchievements > 0) {
        _totalXp += bonusXpFromAchievements;
        _todayXp += bonusXpFromAchievements;
        _saveToCache();
      }
      if (changed) notifyListeners();
    } catch (_) {}
  }

  /// Load toàn bộ achievements từ server (định nghĩa + trạng thái unlock)
  Future<void> loadAchievements() async {
    try {
      final list = await _api.getMyAchievements();
      if (list.isNotEmpty) {
        _achievements = list.map((json) => Achievement.fromJson(json)).toList();
      }
    } catch (_) {
      // Silently fall back to local definitions (all locked)
    } finally {
      _achievementsLoaded = true;
      notifyListeners();
    }
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
      // _totalXp intentionally not cached — always authoritative from server
      _streak = prefs.getInt('${p}user_streak') ?? 0;
      _longestStreak = prefs.getInt('${p}user_longest_streak') ?? 0;
      _lessonsCompleted = prefs.getInt('${p}user_lessons_completed') ?? 0;
      _hearts = prefs.getInt('${p}user_hearts') ?? maxHearts;
      _dailyGoal = prefs.getInt('${p}daily_goal') ?? 20;

      // Load todayXp — reset if stored date differs from today
      final today = _todayKey();
      final claimedDate = prefs.getString('${p}daily_goal_claimed_date') ?? '';
      _dailyGoalBonusClaimedToday = claimedDate == today;
      final storedDate = prefs.getString('${p}today_xp_date') ?? '';
      _todayXp = storedDate == today ? (prefs.getInt('${p}today_xp') ?? 0) : 0;

      // achievements được load từ server qua loadAchievements()
    } catch (_) {}
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = _uidPrefix();
      await prefs.setInt('${p}user_streak', _streak);
      await prefs.setInt('${p}user_longest_streak', _longestStreak);
      await prefs.setInt('${p}user_lessons_completed', _lessonsCompleted);
      await prefs.setInt('${p}user_hearts', _hearts);
      await prefs.setInt('${p}daily_goal', _dailyGoal);
      await prefs.setInt('${p}today_xp', _todayXp);
      await prefs.setString('${p}today_xp_date', _todayKey());
    } catch (_) {}
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Xoá toàn bộ state khi logout — gọi trước khi navigate về LoginScreen
  void reset() {
    _heartTimer?.cancel();
    _heartTimer = null;
    _totalXp = 0;
    _streak = 0;
    _longestStreak = 0;
    _hearts = maxHearts;
    _lessonsCompleted = 0;
    _rank = '-';
    _isLoading = false;
    _error = null;
    _level = 'beginner';
    _todayXp = 0;
    _dailyGoal = 20;
    _dailyGoalJustReached = false;
    _pendingBonusXp = 0;
    _dailyGoalBonusClaimedToday = false;
    _dailyGoalBonusConfigs = [];
    _bonusConfigsLoaded = false;
    _achievements = [];
    _achievementsLoaded = false;
    _completedLessons.clear();
    _topicProgressMap.clear();
    _lastHeartLostAt = null;
    _statsInitialized = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _heartTimer?.cancel();
    super.dispose();
  }
}
