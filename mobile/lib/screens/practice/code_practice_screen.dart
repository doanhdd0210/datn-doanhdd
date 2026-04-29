import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/api_code_snippet.dart';
import '../../services/api_service.dart';
import '../../services/ai_service.dart';
import 'practice_result_screen.dart';

class CodePracticeScreen extends StatefulWidget {
  final ApiCodeSnippet snippet;

  const CodePracticeScreen({super.key, required this.snippet});

  @override
  State<CodePracticeScreen> createState() => _CodePracticeScreenState();
}

class _CodePracticeScreenState extends State<CodePracticeScreen> {
  final _api = ApiService();
  final _aiService = AiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSubmitting = false;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _showHint = false;

  // AI state
  String? _aiExplanation;
  bool _aiExplaining = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

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

    try {
      await _api.submitPractice(widget.snippet.id, code, stdout, passed);
    } catch (_) {}

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
    final userCode = _controller.text.trim();
    if (userCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy nhập code trước khi hỏi AI'), behavior: SnackBarBehavior.floating),
      );
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thực hành: ${widget.snippet.title}', style: AppTextStyles.labelBold),
            Text(_formatTime(_elapsedSeconds),
                style: const TextStyle(fontSize: 12, color: AppColors.blue, fontWeight: FontWeight.w700)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _showHint = !_showHint),
            icon: const Icon(Icons.lightbulb_outline, size: 18),
            label: Text(_showHint ? 'Ẩn' : 'Gợi ý'),
            style: TextButton.styleFrom(foregroundColor: AppColors.orange),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // Original code (reference, read-only)
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: const Color(0xFF2D2D3F),
                        child: const Row(
                          children: [
                            Icon(Icons.remove_red_eye_outlined, size: 14, color: Color(0xFF4FC3F7)),
                            SizedBox(width: 6),
                            Text('Tham khảo', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: HighlightView(
                            widget.snippet.code,
                            language: widget.snippet.language.toLowerCase() == 'java' ? 'java' : widget.snippet.language.toLowerCase(),
                            theme: vs2015Theme,
                            padding: const EdgeInsets.all(12),
                            textStyle: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Divider
                Container(width: 1, color: const Color(0xFF333355)),
                // User input
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: const Color(0xFF2D2D3F),
                        child: const Row(
                          children: [
                            Icon(Icons.edit, size: 14, color: Color(0xFF23A55A)),
                            SizedBox(width: 6),
                            Text('Code của bạn', style: TextStyle(color: Color(0xFF23A55A), fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: const Color(0xFF1E1E1E),
                          child: TextField(
                            controller: _controller,
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.6,
                              color: Colors.white,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Nhập code vào đây...',
                              hintStyle: TextStyle(
                                color: Color(0xFF555555),
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                              contentPadding: EdgeInsets.all(12),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Hint panel
          if (_showHint) _buildHint(),
          // Submit bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            color: AppColors.surface,
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Nộp bài'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    final userText = _controller.text;
    final original = widget.snippet.code;
    final userLines = userText.split('\n');
    final origLines = original.split('\n');

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Static hint — first differing line
            const Text(
              'Gợi ý: Điểm khác biệt đầu tiên:',
              style: TextStyle(color: AppColors.orange, fontSize: 11, fontWeight: FontWeight.w700),
            ),
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
                            color: AppColors.primary, fontFamily: 'monospace', fontSize: 11)),
                  ];
                }
              }
              return [const Text('Trông tốt lắm!', style: TextStyle(color: AppColors.primary, fontFamily: 'monospace'))];
            }(),

            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2D2D50), height: 1),
            const SizedBox(height: 10),

            // AI explain button
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

            // AI loading
            if (_aiExplaining)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF90CAF9))),
                      SizedBox(width: 8),
                      Text('AI đang phân tích...', style: TextStyle(color: Color(0xFF90CAF9), fontSize: 12)),
                    ],
                  ),
                ),
              ),

            // AI explanation result
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
                    const Row(
                      children: [
                        Text('🤖', style: TextStyle(fontSize: 13)),
                        SizedBox(width: 6),
                        Text('Gemini AI', style: TextStyle(color: Color(0xFF90CAF9), fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _aiExplanation!,
                      style: const TextStyle(color: Color(0xFFCCDDFF), fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _aiExplanation = null),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF90CAF9), padding: EdgeInsets.zero),
                child: const Text('Hỏi lại AI', style: TextStyle(fontSize: 11)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
