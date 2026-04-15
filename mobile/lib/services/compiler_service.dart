import 'dart:convert';
import 'package:http/http.dart' as http;

class CompileResult {
  final String stdout;
  final String stderr;
  final int exitCode;
  final bool isSuccess;

  const CompileResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.isSuccess,
  });

  String get output {
    if (stderr.isNotEmpty && stdout.isEmpty) return stderr;
    if (stderr.isNotEmpty) return '$stdout\n--- stderr ---\n$stderr';
    return stdout;
  }
}

class CompilerService {
  static const _pistonUrl = 'https://emkc.org/api/v2/piston/execute';

  // Piston API: miễn phí, không cần API key
  // Docs: https://github.com/engineer-man/piston
  Future<CompileResult> run({
    required String language,
    required String version,
    required String code,
    String stdin = '',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_pistonUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'language': language,
              'version': version,
              'files': [
                {'name': _fileName(language), 'content': code},
              ],
              'stdin': stdin,
              'compile_timeout': 10000,
              'run_timeout': 5000,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return CompileResult(
          stdout: '',
          stderr: 'Lỗi server: ${response.statusCode}',
          exitCode: -1,
          isSuccess: false,
        );
      }

      final data = jsonDecode(response.body);
      final run = data['run'] as Map<String, dynamic>? ?? {};
      final compile = data['compile'] as Map<String, dynamic>?;

      // Nếu compile error
      if (compile != null && (compile['code'] as int? ?? 0) != 0) {
        return CompileResult(
          stdout: '',
          stderr: compile['stderr'] as String? ?? compile['output'] as String? ?? '',
          exitCode: compile['code'] as int? ?? 1,
          isSuccess: false,
        );
      }

      final exitCode = run['code'] as int? ?? 0;
      return CompileResult(
        stdout: run['stdout'] as String? ?? '',
        stderr: run['stderr'] as String? ?? '',
        exitCode: exitCode,
        isSuccess: exitCode == 0,
      );
    } on Exception catch (e) {
      return CompileResult(
        stdout: '',
        stderr: 'Không thể kết nối. Kiểm tra mạng.\n$e',
        exitCode: -1,
        isSuccess: false,
      );
    }
  }

  String _fileName(String language) {
    switch (language) {
      case 'java':
        return 'Main.java';
      case 'python':
        return 'main.py';
      case 'javascript':
        return 'main.js';
      default:
        return 'main.$language';
    }
  }
}

// Các ngôn ngữ được hỗ trợ
class SupportedLanguage {
  final String id;
  final String label;
  final String version;
  final String icon;

  const SupportedLanguage({
    required this.id,
    required this.label,
    required this.version,
    required this.icon,
  });
}

const supportedLanguages = [
  SupportedLanguage(id: 'java', label: 'Java', version: '*', icon: '☕'),
  SupportedLanguage(id: 'python', label: 'Python', version: '*', icon: '🐍'),
  SupportedLanguage(
      id: 'javascript', label: 'JavaScript', version: '*', icon: '🟨'),
];
