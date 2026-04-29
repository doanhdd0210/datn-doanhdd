import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

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
    print('[AI] POST $url');
    try {
      final res = await http
          .post(
            Uri.parse(url),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      print('[AI] status=${res.statusCode} body=${res.body.substring(0, res.body.length.clamp(0, 200))}');
      final json = jsonDecode(res.body);
      if (json is Map && json['success'] == true) {
        return json['data']?.toString() ?? '';
      }
      if (json is Map && json['message'] != null) {
        return json['message'].toString();
      }
      return 'Lỗi ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 100))}';
    } on Exception catch (e) {
      print('[AI] exception: $e');
      return 'Lỗi: $e';
    }
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
