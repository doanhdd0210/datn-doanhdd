import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/api_code_snippet.dart';
import '../../services/compiler_service.dart';
import '../../services/api_service.dart';
import 'practice_result_screen.dart';

class CodePracticeScreen extends StatefulWidget {
  final ApiCodeSnippet snippet;

  const CodePracticeScreen({super.key, required this.snippet});

  @override
  State<CodePracticeScreen> createState() => _CodePracticeScreenState();
}

class _CodePracticeScreenState extends State<CodePracticeScreen> {
  final _compiler = CompilerService();
  final _api = ApiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSubmitting = false;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _showHint = false;

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

    CompileResult? result;
    try {
      result = await _compiler.run(
        language: widget.snippet.language,
        version: '*',
        code: code,
      );
    } catch (_) {
      result = const CompileResult(stdout: '', stderr: 'Could not execute code', exitCode: -1, isSuccess: false);
    }

    final expectedOutput = widget.snippet.expectedOutput.trim();
    final actualOutput = result.stdout.trim();
    final passed = actualOutput == expectedOutput || result.isSuccess;
    final matchPercent = _calculateMatch(code, widget.snippet.code);

    try {
      await _api.submitPractice(widget.snippet.id, code, result.stdout, passed);
    } catch (_) {}

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PracticeResultScreen(
            snippet: widget.snippet,
            userCode: code,
            output: result!.stdout,
            passed: passed,
            matchPercent: matchPercent,
            timeSpent: _elapsedSeconds,
          ),
        ),
      );
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Practice: ${widget.snippet.title}', style: AppTextStyles.labelBold),
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
            label: Text(_showHint ? 'Hide' : 'Hint'),
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
                            Text('Reference', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: const Color(0xFF1A1A2E),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              widget.snippet.code,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.6,
                                color: Color(0xFFCDD6F4),
                              ),
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
                            Text('Your Code', style: TextStyle(color: Color(0xFF23A55A), fontSize: 11, fontWeight: FontWeight.w600)),
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
                              hintText: 'Type the code here...',
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
            color: Colors.white,
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
                      : const Text('Submit'),
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
      height: 120,
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hint: First difference found:',
              style: TextStyle(color: AppColors.orange, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: () {
                  for (int i = 0; i < origLines.length; i++) {
                    final origLine = origLines[i].trim();
                    final userLine = i < userLines.length ? userLines[i].trim() : '';
                    if (origLine != userLine) {
                      return [
                        Text('Line ${i + 1} expected:',
                            style: const TextStyle(color: Color(0xFF888888), fontSize: 10)),
                        Text(origLines[i],
                            style: const TextStyle(
                                color: AppColors.primary, fontFamily: 'monospace', fontSize: 11)),
                      ];
                    }
                  }
                  return [const Text('Looking good!', style: TextStyle(color: AppColors.primary, fontFamily: 'monospace'))];
                }(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
