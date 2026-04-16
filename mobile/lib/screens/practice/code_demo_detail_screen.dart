import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:highlight/languages/java.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/api_code_snippet.dart';
import '../../services/compiler_service.dart';
import '../../services/api_service.dart';
import 'code_practice_screen.dart';

class CodeDemoDetailScreen extends StatefulWidget {
  final ApiCodeSnippet snippet;

  const CodeDemoDetailScreen({super.key, required this.snippet});

  @override
  State<CodeDemoDetailScreen> createState() => _CodeDemoDetailScreenState();
}

class _CodeDemoDetailScreenState extends State<CodeDemoDetailScreen>
    with SingleTickerProviderStateMixin {
  final _compiler = CompilerService();
  final _api = ApiService();
  late CodeController _codeController;
  late TabController _tabController;

  bool _isRunning = false;
  CompileResult? _result;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _codeController = CodeController(
      text: widget.snippet.code,
      language: java,
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _runCode() async {
    _tabController.animateTo(1);
    setState(() {
      _isRunning = true;
      _result = null;
    });
    final result = await _compiler.run(
      language: widget.snippet.language,
      version: '*',
      code: _codeController.text,
    );
    if (mounted) {
      setState(() {
        _isRunning = false;
        _result = result;
      });
      // Submit practice
      try {
        await _api.submitPractice(
          widget.snippet.id,
          _codeController.text,
          result.stdout,
          result.isSuccess,
        );
      } catch (_) {}
    }
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
            Text(widget.snippet.title, style: AppTextStyles.heading4),
            Text(widget.snippet.language.toUpperCase(),
                style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy_outlined),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.snippet.code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Code copied!'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Info section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.snippet.description, style: AppTextStyles.bodyMedium),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.xpGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚡ ${widget.snippet.xpReward} XP',
                    style: const TextStyle(
                      color: AppColors.xpGold,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Run bar
          Container(
            height: 44,
            color: const Color(0xFF2D2D3F),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Text('Java', style: TextStyle(color: Color(0xFF4FC3F7), fontFamily: 'monospace', fontSize: 12)),
                const Spacer(),
                GestureDetector(
                  onTap: _isRunning ? null : _runCode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: _isRunning ? const Color(0xFF23A55A).withOpacity(0.5) : const Color(0xFF23A55A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isRunning)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        else
                          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _isRunning ? 'Running...' : 'Run ▶',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tab bar
          Container(
            color: const Color(0xFF252526),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF4FC3F7),
              indicatorWeight: 2,
              labelColor: const Color(0xFF4FC3F7),
              unselectedLabelColor: const Color(0xFFBBBBBB),
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Code'),
                Tab(text: 'Output'),
              ],
            ),
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Code editor
                CodeTheme(
                  data: CodeThemeData(styles: vs2015Theme),
                  child: SingleChildScrollView(
                    child: CodeField(
                      controller: _codeController,
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.55,
                      ),
                      minLines: 20,
                      expands: false,
                      background: const Color(0xFF1E1E1E),
                      lineNumberStyle: const LineNumberStyle(
                        width: 44,
                        margin: 8,
                        textStyle: TextStyle(
                          color: Color(0xFF858585),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
                // Output terminal
                Container(
                  color: const Color(0xFF0C0C0C),
                  child: _isRunning
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Color(0xFF23A55A), strokeWidth: 2.5),
                              SizedBox(height: 12),
                              Text(
                                'Running...',
                                style: TextStyle(color: Color(0xFFBBBBBB), fontFamily: 'monospace', fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : _result == null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(r'$',
                                      style: TextStyle(color: Color(0xFF555555), fontSize: 32, fontFamily: 'monospace')),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Press Run ▶ to execute the code',
                                    style: TextStyle(color: Color(0xFF777777), fontFamily: 'monospace', fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Status
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _result!.isSuccess
                                          ? const Color(0xFF23A55A).withOpacity(0.15)
                                          : const Color(0xFFF14C4C).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _result!.isSuccess
                                            ? const Color(0xFF23A55A)
                                            : const Color(0xFFF14C4C),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      _result!.isSuccess ? '✓ Success' : '✗ Error',
                                      style: TextStyle(
                                        color: _result!.isSuccess ? const Color(0xFF23A55A) : const Color(0xFFF14C4C),
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (_result!.stdout.isNotEmpty)
                                    Text(
                                      _result!.stdout,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        height: 1.6,
                                      ),
                                    ),
                                  if (_result!.stderr.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _result!.stderr,
                                      style: const TextStyle(
                                        color: Color(0xFFFF8A80),
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
          // Practice button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            color: Colors.white,
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CodePracticeScreen(snippet: widget.snippet),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Practice Typing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
