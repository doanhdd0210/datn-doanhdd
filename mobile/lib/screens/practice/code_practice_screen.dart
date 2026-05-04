import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/cs.dart';
import 'package:highlight/languages/cpp.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/api_code_snippet.dart';
import '../../services/api_service.dart';
import '../../services/ai_service.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_snackbar.dart';
import 'practice_result_screen.dart';

// Ký tự hay dùng khi gõ code
const _shortcuts = [
  ('⇥ Tab', '    '),
  ('{', '{'),
  ('}', '}'),
  ('(', '('),
  (')', ')'),
  ('[', '['),
  (']', ']'),
  (';', ';'),
  ('"', '"'),
  ("'", "'"),
  ('=', '='),
  ('==', '=='),
  ('!=', '!='),
  ('+', '+'),
  ('-', '-'),
  ('*', '*'),
  ('/', '/'),
  ('.', '.'),
  (',', ','),
  ('<', '<'),
  ('>', '>'),
  ('!', '!'),
  ('#', '#'),
  ('%', '%'),
  (':', ':'),
];

dynamic _resolveLanguage(String lang) {
  switch (lang.toLowerCase()) {
    case 'python': return python;
    case 'javascript':
    case 'js': return javascript;
    case 'c#':
    case 'csharp': return cs;
    case 'c++':
    case 'cpp': return cpp;
    case 'java':
    default: return java;
  }
}

class CodePracticeScreen extends StatefulWidget {
  final ApiCodeSnippet snippet;

  const CodePracticeScreen({super.key, required this.snippet});

  @override
  State<CodePracticeScreen> createState() => _CodePracticeScreenState();
}

class _CodePracticeScreenState extends State<CodePracticeScreen> {
  final _api = ApiService();
  final _aiService = AiService();
  final _scrollController = ScrollController();
  late final CodeController _codeController;

  bool _isSubmitting = false;
  bool _showReference = false;
  bool _showHint = false;
  Timer? _timer;
  int _elapsedSeconds = 0;

  // AI state
  String? _aiExplanation;
  bool _aiExplaining = false;

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(
      language: _resolveLanguage(widget.snippet.language),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _insertText(String text) {
    final sel = _codeController.selection;
    final src = _codeController.text;
    final start = sel.isValid ? sel.start : src.length;
    final end = sel.isValid ? sel.end : src.length;
    final next = src.replaceRange(start, end, text);
    _codeController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    String stdout = '';
    try {
      final runResult = await _api.runCode(
        language: widget.snippet.language,
        code: code,
      );
      stdout = runResult['stdout'] as String? ?? '';
    } catch (e) {
      dev.log('runCode error: $e', name: 'Practice');
    }

    final expectedOutput = _normalize(widget.snippet.expectedOutput);
    final actualOutput = _normalize(stdout);
    final passed = actualOutput == expectedOutput;
    final matchPercent = _calculateMatch(code, widget.snippet.code);

    int xpEarned = 0;
    try {
      xpEarned = await _api.submitPractice(widget.snippet.id, code, stdout, passed);
    } catch (_) {}

    if (mounted && xpEarned > 0) {
      context.read<UserProvider>().addXp(xpEarned);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PracticeResultScreen(
            snippet: widget.snippet,
            userCode: code,
            output: stdout,
            passed: passed,
            matchPercent: matchPercent,
            timeSpent: _elapsedSeconds,
            xpEarned: xpEarned,
          ),
        ),
      );
    }
  }

  String _normalize(String s) => s
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((l) => l.trimRight())
      .join('\n')
      .trim();

  double _calculateMatch(String userCode, String originalCode) {
    final userLines = userCode.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final origLines = originalCode.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (origLines.isEmpty) return 1.0;
    int matches = 0;
    for (final line in userLines) {
      if (origLines.contains(line)) matches++;
    }
    return (matches / origLines.length).clamp(0.0, 1.0);
  }

  Future<void> _askAi() async {
    final userCode = _codeController.text.trim();
    if (userCode.isEmpty) {
      AppSnackBar.warning(context, 'Hãy nhập code trước khi hỏi AI');
      return;
    }
    setState(() { _aiExplaining = true; _aiExplanation = null; });
    final result = await _aiService.explainCodeError(
      referenceCode: widget.snippet.code,
      userCode: userCode,
      actualOutput: '',
      expectedOutput: widget.snippet.expectedOutput,
      language: widget.snippet.language,
    );
    if (mounted) setState(() { _aiExplaining = false; _aiExplanation = result; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.snippet.title,
                style: AppTextStyles.labelBold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(_formatTime(_elapsedSeconds),
                style: const TextStyle(fontSize: 12, color: AppColors.blue, fontWeight: FontWeight.w700)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showReference = !_showReference),
            icon: Icon(Icons.remove_red_eye_outlined, size: 20,
                color: _showReference ? AppColors.primary : AppColors.textGray),
            tooltip: 'Tham khảo',
          ),
          IconButton(
            onPressed: () => setState(() => _showHint = !_showHint),
            icon: Icon(Icons.lightbulb_outline, size: 20,
                color: _showHint ? AppColors.orange : AppColors.textGray),
            tooltip: 'Gợi ý',
          ),
        ],
      ),
      body: Column(
        children: [
          // Panel tham khảo – read-only CodeField với syntax highlight
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _showReference ? _buildReferencePanel() : const SizedBox.shrink(),
          ),

          // Panel gợi ý / AI
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _showHint ? _buildHint() : const SizedBox.shrink(),
          ),

          // Editor chiếm toàn bộ không gian còn lại
          Expanded(child: _buildEditor()),

          // Toolbar phím tắt ký tự đặc biệt
          _buildShortcutsBar(),

          // Submit bar
          _buildSubmitBar(),
        ],
      ),
    );
  }

  Widget _buildReferencePanel() {
    final refController = CodeController(
      text: widget.snippet.code,
      language: _resolveLanguage(widget.snippet.language),
    );
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C16),
        border: Border(bottom: BorderSide(color: Color(0xFF333355))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            color: const Color(0xFF2D2D3F),
            child: const Row(
              children: [
                Icon(Icons.remove_red_eye_outlined, size: 13, color: Color(0xFF4FC3F7)),
                SizedBox(width: 6),
                Text('Code tham khảo',
                    style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Flexible(
            child: CodeTheme(
              data: CodeThemeData(styles: vs2015Theme),
              child: SingleChildScrollView(
                child: CodeField(
                  controller: refController,
                  readOnly: true,
                  textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.6),
                  background: const Color(0xFF0C0C16),
                  gutterStyle: const GutterStyle(
                    width: 36,
                    margin: 6,
                    textStyle: TextStyle(color: Color(0xFF555577), fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return CodeTheme(
      data: CodeThemeData(styles: vs2015Theme),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: CodeField(
          controller: _codeController,
          textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.65),
          minLines: 30,
          expands: false,
          background: const Color(0xFF1E1E1E),
          gutterStyle: const GutterStyle(
            width: 44,
            margin: 8,
            textStyle: TextStyle(
              color: Color(0xFF858585),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
        ),
      ),
    );
  }

  Widget _buildShortcutsBar() {
    return Container(
      height: 42,
      color: const Color(0xFF2D2D2D),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        itemCount: _shortcuts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) {
          final (label, value) = _shortcuts[i];
          return GestureDetector(
            onTap: () => _insertText(value),
            child: Container(
              constraints: const BoxConstraints(minWidth: 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF3C3C3C),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF555555)),
              ),
              alignment: Alignment.center,
              child: Text(label,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFFD4D4D4),
                    fontWeight: FontWeight.w500,
                  )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubmitBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Nộp bài'),
          ),
        ),
      ),
    );
  }

  Widget _buildHint() {
    final userLines = _codeController.text.split('\n');
    final origLines = widget.snippet.code.split('\n');

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Điểm khác biệt đầu tiên:',
                style: TextStyle(color: AppColors.orange, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...() {
              for (int i = 0; i < origLines.length; i++) {
                final origLine = origLines[i].trim();
                final userLine = i < userLines.length ? userLines[i].trim() : '';
                if (origLine != userLine) {
                  return [
                    Text('Dòng ${i + 1} cần là:',
                        style: const TextStyle(color: Color(0xFF888888), fontSize: 10)),
                    Text(origLines[i],
                        style: const TextStyle(
                            color: AppColors.primary, fontFamily: 'monospace', fontSize: 12)),
                  ];
                }
              }
              return [const Text('Trông tốt lắm!',
                  style: TextStyle(color: AppColors.primary, fontFamily: 'monospace'))];
            }(),

            const SizedBox(height: 10),
            const Divider(color: Color(0xFF2D2D50), height: 1),
            const SizedBox(height: 8),

            if (_aiExplanation == null && !_aiExplaining)
              GestureDetector(
                onTap: _askAi,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🤖', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text('AI phân tích lỗi của tôi',
                          style: TextStyle(color: Color(0xFF90CAF9), fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

            if (_aiExplaining)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF90CAF9))),
                      SizedBox(width: 8),
                      Text('AI đang phân tích...', style: TextStyle(color: Color(0xFF90CAF9), fontSize: 12)),
                    ],
                  ),
                ),
              ),

            if (_aiExplanation != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Text('🤖', style: TextStyle(fontSize: 13)),
                      SizedBox(width: 6),
                      Text('AI Giải thích',
                          style: TextStyle(color: Color(0xFF90CAF9), fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 6),
                    Text(_aiExplanation!,
                        style: const TextStyle(color: Color(0xFFCCDDFF), fontSize: 12, height: 1.5)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _aiExplanation = null),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF90CAF9), padding: EdgeInsets.zero),
                child: const Text('Hỏi lại AI', style: TextStyle(fontSize: 11)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
