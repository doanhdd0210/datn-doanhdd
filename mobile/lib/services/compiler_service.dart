import 'api_service.dart';

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
  final _api = ApiService();

  Future<CompileResult> run({
    required String language,
    required String version,
    required String code,
    String stdin = '',
  }) async {
    try {
      final result = await _api.runCode(
        language: language,
        code: code,
        stdin: stdin,
      );
      return CompileResult(
        stdout: result['stdout'] as String? ?? '',
        stderr: result['stderr'] as String? ?? '',
        exitCode: result['exitCode'] as int? ?? 0,
        isSuccess: result['isSuccess'] as bool? ?? false,
      );
    } catch (e) {
      return CompileResult(
        stdout: '',
        stderr: 'Lỗi kết nối compiler: $e',
        exitCode: -1,
        isSuccess: false,
      );
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
