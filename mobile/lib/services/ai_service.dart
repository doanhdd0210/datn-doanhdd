import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AiLimitException implements Exception {
  final String message;
  AiLimitException(this.message);
}

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<String> _post(String path, Map<String, dynamic> body) async {
    final url = '${ApiService.baseUrl}$path';
    try {
      final res = await http
          .post(
            Uri.parse(url),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      final json = jsonDecode(res.body);

      if (res.statusCode == 429) {
        final msg = json['error']?.toString() ?? 'Đã đạt giới hạn AI trong ngày.';
        throw AiLimitException(msg);
      }

      if (json is Map && json['success'] == true) {
        return json['data']?.toString() ?? '';
      }
      if (json is Map && json['message'] != null) {
        return json['message'].toString();
      }
      return 'Lỗi ${res.statusCode}';
    } on AiLimitException {
      rethrow;
    } on Exception catch (e) {
      return 'Lỗi: $e';
    }
  }

  Future<Map<String, dynamic>> getUsage() async {
    final url = '${ApiService.baseUrl}/ai/usage';
    try {
      final res = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      final json = jsonDecode(res.body);
      if (json['success'] == true && json['data'] != null) {
        return {
          'used': json['data']['used'] as int,
          'limit': json['data']['limit'] as int,
          'resetAt': json['data']['resetAt'] as String,
        };
      }
    } catch (_) {}
    return {'used': 0, 'limit': 10, 'resetAt': ''};
  }

  Future<String> explainCodeError({
    required String referenceCode,
    required String userCode,
    required String actualOutput,
    required String expectedOutput,
    required String language,
  }) =>
      _post('/ai/explain', {
        'referenceCode': referenceCode,
        'userCode': userCode,
        'actualOutput': actualOutput,
        'expectedOutput': expectedOutput,
        'language': language,
      });

  Future<String> generateQuizHint({
    required String question,
    required List<String> options,
    required int correctIndex,
  }) =>
      _post('/ai/hint', {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
      });

  Future<String> suggestQaAnswer({
    required String title,
    required String body,
  }) =>
      _post('/ai/qa', {
        'title': title,
        'body': body,
      });
}
