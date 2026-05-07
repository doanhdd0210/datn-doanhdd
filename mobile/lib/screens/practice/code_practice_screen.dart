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
import '../../constants/app_theme.dart';
import '../../constants/app_text_styles.dart';
import '../../models/api_code_snippet.dart';
import '../../services/api_service.dart';
import '../../services/ai_service.dart';
import '../../services/compiler_service.dart';
import 'package:provider/provider.dart';
import '../../providers/ai_usage_provider.dart';
import '../../providers/user_provider.dart';
import '../../constants/code_editor_style.dart';
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
  final _compiler = CompilerService();
  final _aiService = AiService();
  late final CodeController _codeController;

  bool _isSubmitting = false;
  bool _isRunning = false;
  bool _showHint = false;
  CompileResult? _runResult;
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

  Future<void> _runCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _isRunning = true; _runResult = null; });
    final result = await _compiler.run(
      language: widget.snippet.language,
      version: '*',
      code: code,
    );
    if (mounted) setState(() { _isRunning = false; _runResult = result; });
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    FocusScope.of(context).unfocus();
    _timer?.cancel();
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
    int bestScore = 0;
    try {
      final result = await _api.submitPractice(widget.snippet.id, code, stdout, passed, matchPercent);
      xpEarned = result.xpEarned;
      bestScore = result.bestScore;
    } catch (_) {}

    if (mounted) {
      context.read<UserProvider>().loadStats();
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
            bestScore: bestScore,
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
    try {
      final result = await _aiService.explainCodeError(
        referenceCode: widget.snippet.code,
        userCode: userCode,
        actualOutput: '',
        expectedOutput: widget.snippet.expectedOutput,
        language: widget.snippet.language,
      );
      if (!mounted) return;
      context.read<AiUsageProvider>().increment();
      setState(() { _aiExplaining = false; _aiExplanation = result; });
    } on AiLimitException catch (e) {
      if (!mounted) return;
      setState(() => _aiExplaining = false);
      AppSnackBar.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: context.textDark,
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
            onPressed: _showReferenceSheet,
            icon: const Icon(Icons.remove_red_eye_outlined, size: 20,
                color: AppColors.textGray),
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
          // Panel gợi ý / AI
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _showHint ? _buildHint() : const SizedBox.shrink(),
          ),

          // Editor chiếm toàn bộ không gian còn lại
          Expanded(child: _buildEditor()),

          // Output panel sau khi chạy
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _runResult != null || _isRunning
                ? _buildOutputPanel()
                : const SizedBox.shrink(),
          ),

          // Toolbar phím tắt ký tự đặc biệt
          _buildShortcutsBar(),

          // Action bar: Chạy + Nộp bài
          _buildActionBar(),
        ],
      ),
    );
  }

  void _showReferenceSheet() {
    final lines = widget.snippet.code.split('\n');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF555566),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header – bấm vào để đóng sheet
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF4FC3F7)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Code tham khảo',
                          style: TextStyle(
                            color: Color(0xFF4FC3F7),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Text(
                        'Chạm để đóng',
                        style: TextStyle(color: Color(0xFF555577), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: Color(0xFF333344), height: 1),
              // Code viewer – dùng ListView thay vì CodeField để tránh GlobalKey conflict
              Expanded(
                child: Container(
                  color: const Color(0xFF1E1E1E),
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: lines.length,
                    itemBuilder: (_, i) => _CodeLineRow(
                      lineNumber: i + 1,
                      code: lines[i],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return CodeTheme(
      data: CodeThemeData(styles: vs2015Theme),
      child: CodeField(
        controller: _codeController,
        textStyle: CodeEditorStyle.codeTextStyle,
        expands: true,
        background: CodeEditorStyle.bgEditor,
        gutterStyle: CodeEditorStyle.gutterStyle,
        decoration: CodeEditorStyle.fieldDecoration,
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

  Widget _buildOutputPanel() {
    final expected = _normalize(widget.snippet.expectedOutput);
    final actual = _runResult != null ? _normalize(_runResult!.stdout) : '';
    final isPassed = _runResult != null && actual == expected;
    final hasError = _runResult != null && _runResult!.stderr.isNotEmpty && _runResult!.stdout.isEmpty;

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C0C),
        border: Border(top: BorderSide(color: Color(0xFF333333))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF1A1A1A),
            child: Row(
              children: [
                if (_isRunning) ...[
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF23A55A)),
                  ),
                  const SizedBox(width: 8),
                  const Text('Đang chạy...', style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 11)),
                ] else ...[
                  Icon(
                    isPassed ? Icons.check_circle : (hasError ? Icons.error_outline : Icons.cancel_outlined),
                    size: 14,
                    color: isPassed ? const Color(0xFF23A55A) : (hasError ? AppColors.orange : AppColors.wrong),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPassed ? 'Kết quả đúng!' : (hasError ? 'Lỗi biên dịch' : 'Kết quả sai'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPassed ? const Color(0xFF23A55A) : (hasError ? AppColors.orange : AppColors.wrong),
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _runResult = null),
                  child: const Icon(Icons.close, size: 16, color: Color(0xFF666666)),
                ),
              ],
            ),
          ),
          // Output content
          if (!_isRunning && _runResult != null)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stdout hoặc stderr
                    if (_runResult!.stdout.isNotEmpty) ...[
                      const Text('Output:', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(_runResult!.stdout.trim(),
                          style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12, height: 1.5)),
                    ],
                    if (hasError) ...[
                      const Text('Lỗi:', style: TextStyle(color: AppColors.orange, fontSize: 10, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(_runResult!.stderr.trim(),
                          style: const TextStyle(color: Color(0xFFFFAB40), fontFamily: 'monospace', fontSize: 12, height: 1.5)),
                    ],
                    // So sánh expected nếu có stdout và không pass
                    if (!isPassed && !hasError && widget.snippet.expectedOutput.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(color: Color(0xFF333333), height: 1),
                      const SizedBox(height: 8),
                      const Text('Kết quả mong đợi:', style: TextStyle(color: Color(0xFF23A55A), fontSize: 10, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(widget.snippet.expectedOutput.trim(),
                          style: const TextStyle(color: Color(0xFF4EC9B0), fontFamily: 'monospace', fontSize: 12, height: 1.5)),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nút Chạy
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_isRunning || _isSubmitting) ? null : _runCode,
                icon: _isRunning
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(_isRunning ? 'Đang chạy...' : 'Chạy'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Nút Nộp bài
            Expanded(
              flex: 2,
              child: ElevatedButton(

                onPressed: (_isSubmitting || _isRunning) ? null : _submit,
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
          ],
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
              Builder(builder: (ctx) {
                final aiUsage = ctx.watch<AiUsageProvider>();
                final exhausted = aiUsage.isExhausted;
                return GestureDetector(
                  onTap: exhausted ? null : _askAi,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
                    decoration: BoxDecoration(
                      color: exhausted
                          ? const Color(0xFF2D2D2D)
                          : const Color(0xFF1565C0).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: exhausted
                            ? const Color(0xFF444444)
                            : const Color(0xFF1565C0).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🤖', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          exhausted ? 'Hết lượt AI hôm nay' : 'AI phân tích lỗi của tôi',
                          style: TextStyle(
                            color: exhausted ? const Color(0xFF666666) : const Color(0xFF90CAF9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (aiUsage.loaded) ...[
                          const Spacer(),
                          Text(
                            '${aiUsage.used}/${aiUsage.limit}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF666666)),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),

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

/// Widget render 1 dòng code + số thứ tự trong reference sheet.
/// Dùng Text thuần để tránh GlobalKey conflict với CodeField ở editor.
class _CodeLineRow extends StatelessWidget {
  final int lineNumber;
  final String code;

  const _CodeLineRow({required this.lineNumber, required this.code});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Số dòng
          Container(
            width: CodeEditorStyle.gutterWidth - CodeEditorStyle.gutterMargin * 2,
            color: CodeEditorStyle.bgGutter,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 10),
            child: Text(
              '$lineNumber',
              style: const TextStyle(
                color: CodeEditorStyle.textGutter,
                fontFamily: CodeEditorStyle.fontFamily,
                fontSize: CodeEditorStyle.gutterFontSize,
                height: CodeEditorStyle.lineHeight,
              ),
            ),
          ),
          // Code
          Expanded(
            child: Container(
              color: CodeEditorStyle.bgEditor,
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                code.isEmpty ? ' ' : code,
                style: const TextStyle(
                  color: CodeEditorStyle.textCode,
                  fontFamily: CodeEditorStyle.fontFamily,
                  fontSize: CodeEditorStyle.fontSize,
                  height: CodeEditorStyle.lineHeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
