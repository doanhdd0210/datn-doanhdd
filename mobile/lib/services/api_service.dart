import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/topic.dart';
import '../models/lesson.dart';
import '../models/question.dart';
import '../models/quiz_result.dart';
import '../models/api_code_snippet.dart';
import '../models/qa_post.dart';
import '../models/qa_answer.dart';
import '../models/user_follow.dart';
import '../models/daily_progress.dart';
import '../models/leaderboard_entry.dart';

class ApiService {
  static const String _defaultBaseUrl = 'https://datn-doanhdd.onrender.com/api';
  static const String _baseUrlKey = 'api_base_url';

  static String _baseUrl = _defaultBaseUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }

  static String get baseUrl => _baseUrl;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _log(String method, String path, http.Response response) {
    if (!kDebugMode) return;
    final code = response.statusCode;
    final ok = code >= 200 && code < 300;
    final icon = ok ? '✓' : '✗';

    String body;
    try {
      final decoded = jsonDecode(response.body);
      body = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      body = response.body;
    }
    if (body.length > 800) body = '${body.substring(0, 800)}\n  ... [truncated]';

    dev.log(
      '$icon $method $path [$code]\n$body',
      name: 'API',
    );
  }

  Future<Map<String, String>> _getHeaders() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final token = await user.getIdToken();
        return {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };
      } catch (_) {}
    }
    return {'Content-Type': 'application/json'};
  }

  /// Unwrap ApiResponse<T> wrapper từ backend:
  /// { "success": true, "data": ..., "message": "..." }
  dynamic _unwrap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      if (raw.containsKey('success') && raw.containsKey('data')) {
        return raw['data'];
      }
      // Old Node.js format: { "err": 0, "data": ... }
      if (raw.containsKey('err') && raw.containsKey('data')) {
        return raw['data'];
      }
    }
    return raw;
  }

  Future<dynamic> _get(String path) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$_baseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 20));
      _log('GET', path, response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return _unwrap(jsonDecode(response.body));
      }
      throw ApiException('HTTP ${response.statusCode}: ${response.body}', response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: $e', 0);
    }
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      _log('POST', path, response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return {};
        return _unwrap(jsonDecode(response.body));
      }
      throw ApiException('HTTP ${response.statusCode}: ${response.body}', response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: $e', 0);
    }
  }

  Future<dynamic> _delete(String path) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(Uri.parse('$_baseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 20));
      _log('DELETE', path, response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return {};
        return _unwrap(jsonDecode(response.body));
      }
      throw ApiException('HTTP ${response.statusCode}: ${response.body}', response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: $e', 0);
    }
  }

  // ── Topics ────────────────────────────────────────────────────────────────

  Future<List<Topic>> getTopics() async {
    final data = await _get('/topics');
    final list = (data as List<dynamic>?) ?? [];
    return list.map((e) => Topic.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Topic> getTopic(String id) async {
    final data = await _get('/topics/$id');
    return Topic.fromJson(data as Map<String, dynamic>);
  }

  // ── Lessons ───────────────────────────────────────────────────────────────

  Future<List<Lesson>> getLessonsByTopic(String topicId) async {
    final data = await _get('/lessons?topicId=$topicId');
    final list = (data as List<dynamic>?) ?? [];
    return list.map((e) => Lesson.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Lesson> getLesson(String id) async {
    final data = await _get('/lessons/$id');
    return Lesson.fromJson(data as Map<String, dynamic>);
  }

  // ── Questions ─────────────────────────────────────────────────────────────

  Future<List<Question>> getQuestions(String lessonId) async {
    final data = await _get('/questions?lessonId=$lessonId');
    final list = (data as List<dynamic>?) ?? [];
    return list.map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Progress ──────────────────────────────────────────────────────────────

  /// Backend trả về List<UserProgress> — chuyển thành Map để provider parse
  Future<List<Map<String, dynamic>>> getTopicProgress() async {
    final data = await _get('/progress/topics');
    if (data == null) return [];
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getLessonProgress(String topicId) async {
    final data = await _get('/progress/lessons?topicId=$topicId');
    if (data == null) return {};
    return data as Map<String, dynamic>;
  }

  // Backend: POST /api/progress/complete-lesson
  // Body: { lessonId, topicId, timeSpentSeconds }
  Future<void> completeLesson(String lessonId, String topicId, {int timeSpentSeconds = 0}) async {
    await _post('/progress/complete-lesson', {
      'lessonId': lessonId,
      'topicId': topicId,
      'timeSpentSeconds': timeSpentSeconds,
    });
  }

  // Backend: POST /api/progress/quiz-submit
  // Body: { lessonId, answers: [...], timeSpentSeconds }
  Future<QuizResult> submitQuiz(
    String lessonId,
    List<UserAnswer> answers,
    int timeSpent,
  ) async {
    final data = await _post('/progress/quiz-submit', {
      'lessonId': lessonId,
      'answers': answers.map((a) => a.toJson()).toList(),
      'timeSpentSeconds': timeSpent,
    });
    return QuizResult.fromJson(data as Map<String, dynamic>);
  }

  // Backend: POST /api/progress/claim-daily-goal-bonus
  // Body: { goalTarget }
  // Returns: { success, bonusXp, message }
  Future<Map<String, dynamic>> claimDailyGoalBonus(int goalTarget) async {
    try {
      final data = await _post('/progress/claim-daily-goal-bonus', {'goalTarget': goalTarget});
      if (data is Map<String, dynamic>) return data;
      return {'success': false, 'bonusXp': 0, 'message': 'Invalid response'};
    } catch (_) {
      return {'success': false, 'bonusXp': 0, 'message': 'Network error'};
    }
  }

  Future<List<Map<String, dynamic>>> getDailyGoalBonusConfigs() async {
    try {
      final data = await _get('/settings/daily-goal-bonuses');
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<DailyProgress>> getDailyProgress() async {
    final data = await _get('/progress/daily');
    final list = (data as List<dynamic>?) ?? [];
    return list
        .map((e) => DailyProgress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getUserStats() async {
    final data = await _get('/progress/stats');
    if (data == null) return {};
    return data as Map<String, dynamic>;
  }

  // ── Code Snippets ─────────────────────────────────────────────────────────

  Future<List<ApiCodeSnippet>> getCodeSnippets({String? topicId}) async {
    final query = topicId != null ? '?topicId=$topicId' : '';
    final data = await _get('/code-snippets$query');
    final list = (data as List<dynamic>?) ?? [];
    return list
        .map((e) => ApiCodeSnippet.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ApiCodeSnippet> getCodeSnippet(String id) async {
    final data = await _get('/code-snippets/$id');
    return ApiCodeSnippet.fromJson(data as Map<String, dynamic>);
  }

  // Backend: POST /api/code-snippets/run (proxy to Piston)
  Future<Map<String, dynamic>> runCode({
    required String language,
    required String code,
    String stdin = '',
  }) async {
    final data = await _post('/code-snippets/run', {
      'language': language,
      'code': code,
      'stdin': stdin,
    });
    if (data is Map<String, dynamic>) return data;
    return {'stdout': '', 'stderr': 'Invalid response', 'exitCode': -1, 'isSuccess': false};
  }

  Future<Set<String>> getPassedSnippetIds() async {
    try {
      final data = await _get('/code-snippets/my-passed');
      return (data as List<dynamic>).map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  // Backend: POST /api/code-snippets/practice-submit
  // Body: { codeSnippetId, submittedCode, actualOutput, isPassed }
  Future<int> submitPractice(
    String snippetId,
    String code,
    String output,
    bool passed,
  ) async {
    final res = await _post('/code-snippets/practice-submit', {
      'codeSnippetId': snippetId,
      'submittedCode': code,
      'actualOutput': output,
      'isPassed': passed,
    });
    return (res?['data']?['xpEarned'] as int?) ?? 0;
  }

  // ── QA ────────────────────────────────────────────────────────────────────

  Future<List<QaPost>> getQaPosts({String? lessonId, int page = 1}) async {
    final query = StringBuffer('?page=$page');
    if (lessonId != null) query.write('&lessonId=$lessonId');
    final data = await _get('/qa$query');
    List<dynamic> list;
    if (data is Map) {
      list = data['posts'] as List<dynamic>? ?? data['data'] as List<dynamic>? ?? [];
    } else {
      list = (data as List<dynamic>?) ?? [];
    }
    return list.map((e) => QaPost.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<QaPost> getQaPost(String id) async {
    final data = await _get('/qa/$id') as Map<String, dynamic>;
    // Response is QaPostDetail: { post: {...}, answers: [...] }
    final postJson = (data['post'] ?? data['Post']) as Map<String, dynamic>? ?? data;
    return QaPost.fromJson(postJson);
  }

  Future<void> createQaPost(
    String title,
    String content, {
    String? lessonId,
    List<String>? tags,
  }) async {
    await _post('/qa', {
      'title': title,
      'content': content,
      if (lessonId != null) 'lessonId': lessonId,
      if (tags != null) 'tags': tags,
    });
  }

  Future<List<QaAnswer>> getQaAnswers(String postId) async {
    final data = await _get('/qa/$postId/answers');
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      list = data['answers'] as List<dynamic>? ?? [];
    } else {
      list = [];
    }
    return list.map((e) => QaAnswer.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Backend: POST /api/qa/answers
  // Body: { postId, content }
  Future<void> createQaAnswer(String postId, String content) async {
    await _post('/qa/answers', {
      'postId': postId,
      'content': content,
    });
  }

  Future<void> upvotePost(String postId) async {
    await _post('/qa/$postId/upvote', {});
  }

  Future<void> unupvotePost(String postId) async {
    await _delete('/qa/$postId/upvote');
  }

  Future<void> upvoteAnswer(String answerId) async {
    await _post('/qa/answers/$answerId/upvote', {});
  }

  Future<void> unupvoteAnswer(String answerId) async {
    await _delete('/qa/answers/$answerId/upvote');
  }

  Future<void> acceptAnswer(String answerId) async {
    await _post('/qa/answers/$answerId/accept', {});
  }

  // ── Friends / Leaderboard ─────────────────────────────────────────────────
  // Backend route: /api/friends/... (không phải /social/...)

  Future<List<UserFollow>> getFollowing() async {
    final data = await _get('/friends/following');
    final list = (data as List<dynamic>?) ?? [];
    return list.map((e) => UserFollow.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<UserFollow>> getFollowers() async {
    final data = await _get('/friends/followers');
    final list = (data as List<dynamic>?) ?? [];
    return list.map((e) => UserFollow.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> followUser(String userId, String name, String avatar) async {
    await _post('/friends/follow', {
      'followingId': userId,
      'followingName': name,
      'followingAvatar': avatar,
    });
  }

  Future<void> unfollowUser(String userId) async {
    await _delete('/friends/follow/$userId');
  }

  Future<List<LeaderboardEntry>> getWeeklyLeaderboard() async {
    final data = await _get('/friends/leaderboard/weekly');
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      list = data['leaderboard'] as List<dynamic>? ?? [];
    } else {
      list = [];
    }
    final currentUserId = _auth.currentUser?.uid ?? '';
    return list.asMap().entries.map((entry) {
      final e = entry.value as Map<String, dynamic>;
      return LeaderboardEntry.fromJson(
        e,
        isCurrentUser: (e['userId'] ?? e['id'] ?? e['_id']) == currentUserId,
      );
    }).toList();
  }

  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final data = await _get('/friends/leaderboard');
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      list = data['leaderboard'] as List<dynamic>? ?? [];
    } else {
      list = [];
    }
    final currentUserId = _auth.currentUser?.uid ?? '';
    return list.asMap().entries.map((entry) {
      final e = entry.value as Map<String, dynamic>;
      return LeaderboardEntry.fromJson(
        e,
        isCurrentUser: (e['userId'] ?? e['id'] ?? e['_id']) == currentUserId,
      );
    }).toList();
  }

  // ── AI (Groq qua BE) ─────────────────────────────────────────────────────

  Future<String> aiExplainCode({
    required String language,
    required String referenceCode,
    required String userCode,
    required String expectedOutput,
    required String actualOutput,
  }) async {
    try {
      final data = await _post('/ai/explain', {
        'language': language,
        'referenceCode': referenceCode,
        'userCode': userCode,
        'expectedOutput': expectedOutput,
        'actualOutput': actualOutput,
      });
      return data?.toString() ?? 'Không có phản hồi từ AI.';
    } catch (_) {
      return 'Không thể kết nối AI lúc này. Thử lại sau.';
    }
  }

  Future<String> aiQuizHint({
    required String question,
    required List<String> options,
    required int correctIndex,
  }) async {
    try {
      final data = await _post('/ai/hint', {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
      });
      return data?.toString() ?? 'Không có gợi ý từ AI.';
    } catch (_) {
      return 'Không thể kết nối AI lúc này. Thử lại sau.';
    }
  }

  Future<String> aiQaSuggest({
    required String title,
    required String body,
  }) async {
    try {
      final data = await _post('/ai/qa', {
        'title': title,
        'body': body,
      });
      return data?.toString() ?? 'Không có gợi ý từ AI.';
    } catch (_) {
      return 'Không thể kết nối AI lúc này. Thử lại sau.';
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotificationHistory() async {
    try {
      final data = await _get('/notifications/history');
      if (data is List) return data.cast<Map<String, dynamic>>();
      if (data is Map && data['data'] is List) return (data['data'] as List).cast<Map<String, dynamic>>();
      return [];
    } catch (_) { return []; }
  }

  /// In-app notifications của user hiện tại
  Future<Map<String, dynamic>> getMyNotifications({int limit = 30}) async {
    try {
      final data = await _get('/notifications/me?limit=$limit');
      if (data is Map) {
        final inner = data['data'] as Map<String, dynamic>? ?? data as Map<String, dynamic>;
        return inner;
      }
      return {'notifications': [], 'unreadCount': 0};
    } catch (_) {
      return {'notifications': [], 'unreadCount': 0};
    }
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final data = await _get('/notifications/me/unread-count');
      final inner = data is Map ? (data['data'] ?? data) : data;
      return (inner as Map?)?['count'] as int? ?? 0;
    } catch (_) { return 0; }
  }

  Future<void> markNotificationRead(String id) async {
    try { await _post('/notifications/me/$id/read', {}); } catch (_) {}
  }

  Future<void> markAllNotificationsRead() async {
    try { await _post('/notifications/me/read-all', {}); } catch (_) {}
  }

  // ── Achievements ──────────────────────────────────────────────────────────

  Future<void> syncAchievements() async {
    try { await _post('/achievements/me/sync', {}); } catch (_) {}
  }

  /// Lấy danh sách tất cả achievements kèm trạng thái unlock của user
  Future<List<Map<String, dynamic>>> getMyAchievements() async {
    try {
      final data = await _get('/achievements/me');
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [];
    } catch (_) { return []; }
  }

  /// Lấy và đánh dấu đã đọc các achievement mới vừa unlock (chưa thông báo)
  Future<List<Map<String, dynamic>>> consumeNewAchievements() async {
    try {
      final data = await _post('/achievements/me/consume-new', {});
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [];
    } catch (_) { return []; }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
