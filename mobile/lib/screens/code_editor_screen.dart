import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/javascript.dart';
import '../models/code_snippet.dart';
import '../services/compiler_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF1E1E1E);         // VS Code editor bg
  static const surface = Color(0xFF252526);     // panel bg
  static const toolbar = Color(0xFF2D2D2D);     // toolbar / tab bar
  static const border = Color(0xFF3E3E42);      // dividers
  static const termBg = Color(0xFF0C0C0C);      // terminal bg
  static const runGreen = Color(0xFF23A55A);    // Run button green
  static const runGreenHover = Color(0xFF1E9150);
  static const accentBlue = Color(0xFF4FC3F7);
  static const lineNum = Color(0xFF858585);
  static const white70 = Color(0xFFBBBBBB);
  static const white40 = Color(0xFF666666);
  static const successGreen = Color(0xFF4EC9B0);
  static const errorRed = Color(0xFFF14C4C);
  static const warnYellow = Color(0xFFCCA700);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class CodeEditorScreen extends StatefulWidget {
  const CodeEditorScreen({super.key});

  @override
  State<CodeEditorScreen> createState() => _CodeEditorScreenState();
}

class _CodeEditorScreenState extends State<CodeEditorScreen>
    with SingleTickerProviderStateMixin {
  final _compiler = CompilerService();

  late TabController _tabController;
  late CodeController _codeController;
  SupportedLanguage _lang = supportedLanguages.first;

  bool _isRunning = false;
  CompileResult? _result;
  int _outputTabBadge = 0; // shows dot when new result

  // Execution timer
  Stopwatch _stopwatch = Stopwatch();
  Timer? _tickTimer;
  Duration _elapsed = Duration.zero;

  // Stdin
  final _stdinController = TextEditingController();
  bool _showStdin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _codeController = CodeController(
      text: javaSnippets.first.code,
      language: java,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _stdinController.dispose();
    _tickTimer?.cancel();
    super.dispose();
  }

  void _changeLanguage(SupportedLanguage lang) {
    final code = _codeController.text;
    _codeController.dispose();
    setState(() {
      _lang = lang;
      _result = null;
      _outputTabBadge = 0;
      _codeController = CodeController(
        text: code,
        language: _langMode(lang.id),
      );
    });
  }

  dynamic _langMode(String id) {
    switch (id) {
      case 'python':
        return python;
      case 'javascript':
        return javascript;
      default:
        return java;
    }
  }

  Future<void> _runCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    // Switch to Output tab
    _tabController.animateTo(1);

    setState(() {
      _isRunning = true;
      _result = null;
      _elapsed = Duration.zero;
      _outputTabBadge = 0;
    });

    // Start timer
    _stopwatch = Stopwatch()..start();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() => _elapsed = _stopwatch.elapsed);
    });

    final result = await _compiler.run(
      language: _lang.id,
      version: _lang.version,
      code: code,
      stdin: _stdinController.text,
    );

    _stopwatch.stop();
    _tickTimer?.cancel();

    if (mounted) {
      setState(() {
        _isRunning = false;
        _result = result;
        _elapsed = _stopwatch.elapsed;
        _outputTabBadge = 1;
      });
    }
  }

  void _loadSnippet(CodeSnippet snippet) {
    _codeController.text = snippet.code;
    setState(() {
      _result = null;
      _outputTabBadge = 0;
    });
    Navigator.pop(context);
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildLangRunBar(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildEditorTab(),
                _buildOutputTab(),
              ],
            ),
          ),
          _buildStatusBar(),
        ],
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _C.surface,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(left: 4, right: 10),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _C.toolbar,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('</>', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.accentBlue)),
          ),
          const Text('Code Editor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _C.border),
      ),
      actions: [
        _iconBtn(Icons.format_list_bulleted, 'Snippets mẫu', _showSnippetPicker),
        _iconBtn(Icons.content_copy_outlined, 'Sao chép', () {
          Clipboard.setData(ClipboardData(text: _codeController.text));
          _toast('Đã sao chép code');
        }),
        _iconBtn(Icons.delete_sweep_outlined, 'Xoá', _confirmClear),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Language + Run bar ──────────────────────────────────────────────────────
  Widget _buildLangRunBar() {
    return Container(
      height: 44,
      color: _C.toolbar,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Language selector (pill style)
          _LangSelector(current: _lang, onChanged: _changeLanguage),
          const SizedBox(width: 10),
          // stdin toggle
          GestureDetector(
            onTap: () => setState(() => _showStdin = !_showStdin),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _showStdin ? _C.accentBlue.withOpacity(0.15) : Colors.transparent,
                border: Border.all(
                    color: _showStdin ? _C.accentBlue : _C.border),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'stdin',
                style: TextStyle(
                  color: _showStdin ? _C.accentBlue : _C.white70,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const Spacer(),
          // RUN button
          _RunButton(isRunning: _isRunning, onPressed: _runCode),
        ],
      ),
    );
  }

  // ── Tab bar ─────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: _C.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: _C.accentBlue,
            indicatorWeight: 2,
            labelColor: _C.accentBlue,
            unselectedLabelColor: _C.white70,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            dividerColor: Colors.transparent,
            tabs: [
              const Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note, size: 16),
                    SizedBox(width: 6),
                    Text('Code'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.terminal, size: 16),
                    const SizedBox(width: 6),
                    const Text('Output'),
                    if (_outputTabBadge > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _C.runGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Container(height: 1, color: _C.border),
        ],
      ),
    );
  }

  // ── Editor tab ──────────────────────────────────────────────────────────────
  Widget _buildEditorTab() {
    return Column(
      children: [
        // stdin field
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _showStdin
              ? Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  color: _C.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('  stdin  ',
                          style: TextStyle(
                              color: _C.accentBlue,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _stdinController,
                        style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 13),
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Nhập stdin (mỗi dòng = 1 input)...',
                          hintStyle: const TextStyle(
                              color: _C.white40, fontSize: 12),
                          filled: true,
                          fillColor: _C.termBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: _C.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: _C.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide:
                                const BorderSide(color: _C.accentBlue),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Code field
        Expanded(
          child: CodeTheme(
            data: CodeThemeData(styles: vs2015Theme),
            child: SingleChildScrollView(
              child: CodeField(
                controller: _codeController,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13.5,
                  height: 1.55,
                  letterSpacing: 0.3,
                ),
                minLines: 40,
                expands: false,
                wrap: false,
                background: _C.bg,
                lineNumberStyle: const LineNumberStyle(
                  width: 44,
                  margin: 8,
                  textStyle: TextStyle(
                    color: _C.lineNum,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Output tab ──────────────────────────────────────────────────────────────
  Widget _buildOutputTab() {
    return Container(
      color: _C.termBg,
      child: Column(
        children: [
          // Terminal title bar (macOS style)
          _TerminalTitleBar(
            result: _result,
            isRunning: _isRunning,
            elapsed: _elapsed,
          ),
          // Content
          Expanded(
            child: _isRunning
                ? _RunningState(elapsed: _elapsed)
                : _result == null
                    ? _EmptyOutputState(onRun: _runCode)
                    : _TerminalOutput(result: _result!, lang: _lang.label),
          ),
        ],
      ),
    );
  }

  // ── Status bar ──────────────────────────────────────────────────────────────
  Widget _buildStatusBar() {
    final lineCount = '\n'.allMatches(_codeController.text).length + 1;
    return Container(
      height: 22,
      color: _C.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: _C.runGreen),
          const SizedBox(width: 6),
          Text(
            'Piston Engine',
            style: const TextStyle(
                color: _C.white40, fontSize: 10, fontFamily: 'monospace'),
          ),
          const Spacer(),
          Text(
            'Ln $lineCount',
            style: const TextStyle(
                color: _C.white40, fontSize: 10, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 12),
          Text(
            _lang.label,
            style: const TextStyle(
                color: _C.white40, fontSize: 10, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  // ── Snippet picker ──────────────────────────────────────────────────────────
  void _showSnippetPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _C.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  const Text('📚',
                      style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  const Text('Code mẫu Java',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${javaSnippets.length} snippets',
                      style: const TextStyle(
                          color: _C.white40, fontSize: 12)),
                ],
              ),
            ),
            Container(height: 1, color: _C.border),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: javaSnippets.length,
                separatorBuilder: (_, __) =>
                    Container(height: 1, color: _C.border.withOpacity(0.5)),
                itemBuilder: (_, i) {
                  final s = javaSnippets[i];
                  return _SnippetTile(
                    snippet: s,
                    onTap: () => _loadSnippet(s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // helpers
  void _confirmClear() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Xoá code?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('Toàn bộ code hiện tại sẽ bị xoá.',
            style: TextStyle(color: _C.white70, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ')),
          TextButton(
            onPressed: () {
              _codeController.text = '';
              setState(() {
                _result = null;
                _outputTabBadge = 0;
              });
              Navigator.pop(context);
              _tabController.animateTo(0);
            },
            child: const Text('Xoá', style: TextStyle(color: _C.errorRed)),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      color: _C.white70,
      onPressed: onPressed,
    );
  }
}

// ─── Run Button ───────────────────────────────────────────────────────────────
class _RunButton extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onPressed;

  const _RunButton({required this.isRunning, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isRunning ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isRunning ? _C.runGreen.withOpacity(0.5) : _C.runGreen,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isRunning
              ? []
              : [
                  BoxShadow(
                    color: _C.runGreen.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRunning)
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            else
              const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              isRunning ? 'Running...' : 'Run ▶',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Language selector ────────────────────────────────────────────────────────
class _LangSelector extends StatelessWidget {
  final SupportedLanguage current;
  final ValueChanged<SupportedLanguage> onChanged;

  const _LangSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _C.bg,
        border: Border.all(color: _C.border),
        borderRadius: BorderRadius.circular(5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SupportedLanguage>(
          value: current,
          dropdownColor: const Color(0xFF2D2D2D),
          isDense: true,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: _C.white70, size: 16),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: supportedLanguages
              .map((l) => DropdownMenuItem(
                    value: l,
                    child: Text('${l.icon}  ${l.label}'),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ─── Terminal title bar (macOS dots style) ────────────────────────────────────
class _TerminalTitleBar extends StatelessWidget {
  final CompileResult? result;
  final bool isRunning;
  final Duration elapsed;

  const _TerminalTitleBar(
      {required this.result, required this.isRunning, required this.elapsed});

  @override
  Widget build(BuildContext context) {
    final ms = elapsed.inMilliseconds;
    final timeStr = ms >= 1000
        ? '${(ms / 1000).toStringAsFixed(1)}s'
        : '${ms}ms';

    return Container(
      height: 36,
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // macOS traffic lights (decorative)
          _dot(const Color(0xFFFF5F57)),
          const SizedBox(width: 6),
          _dot(const Color(0xFFFFBD2E)),
          const SizedBox(width: 6),
          _dot(const Color(0xFF28C840)),
          const SizedBox(width: 12),
          const Text('bash',
              style: TextStyle(
                  color: _C.white40,
                  fontSize: 12,
                  fontFamily: 'monospace')),
          const Spacer(),
          if (isRunning)
            Row(children: [
              const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                      color: _C.warnYellow, strokeWidth: 1.5)),
              const SizedBox(width: 6),
              Text(timeStr,
                  style: const TextStyle(
                      color: _C.warnYellow,
                      fontSize: 11,
                      fontFamily: 'monospace')),
            ])
          else if (result != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: result!.isSuccess
                    ? _C.runGreen.withOpacity(0.15)
                    : _C.errorRed.withOpacity(0.15),
                border: Border.all(
                  color: result!.isSuccess ? _C.runGreen : _C.errorRed,
                  width: 0.5,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                result!.isSuccess
                    ? '✓  exit 0 · $timeStr'
                    : '✗  exit ${result!.exitCode} · $timeStr',
                style: TextStyle(
                  color: result!.isSuccess ? _C.runGreen : _C.errorRed,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dot(Color c) =>
      Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

// ─── Terminal Output ──────────────────────────────────────────────────────────
class _TerminalOutput extends StatelessWidget {
  final CompileResult result;
  final String lang;

  const _TerminalOutput({required this.result, required this.lang});

  @override
  Widget build(BuildContext context) {
    final stdout = result.stdout;
    final stderr = result.stderr;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Command line
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 13, height: 1.5),
              children: [
                const TextSpan(
                    text: '→  ',
                    style: TextStyle(color: _C.accentBlue, fontWeight: FontWeight.w700)),
                TextSpan(
                    text: 'javac Main.java && java Main',
                    style: const TextStyle(color: _C.white70)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: _C.border.withOpacity(0.6)),
          const SizedBox(height: 10),
          // stdout
          if (stdout.isNotEmpty) ...[
            ...stdout.trimRight().split('\n').map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13, height: 1.55),
                      children: [
                        const TextSpan(
                            text: '  ',
                            style: TextStyle(color: _C.white40)),
                        TextSpan(
                            text: line,
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 8),
          ],
          // stderr
          if (stderr.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _C.errorRed.withOpacity(0.08),
                border: Border(
                    left: BorderSide(color: _C.errorRed, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('STDERR',
                      style: TextStyle(
                          color: _C.errorRed,
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  ...stderr.trimRight().split('\n').map((line) => Text(
                        line,
                        style: const TextStyle(
                            color: Color(0xFFFF8A80),
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                            height: 1.5),
                      )),
                ],
              ),
            ),
          ],
          // Empty stdout
          if (stdout.isEmpty && stderr.isEmpty)
            const Text(
              '(no output)',
              style: TextStyle(
                  color: _C.white40,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 12),
          // Exit info
          Text(
            result.isSuccess
                ? 'Process finished with exit code 0'
                : 'Process finished with exit code ${result.exitCode}',
            style: TextStyle(
              color: result.isSuccess
                  ? _C.white40
                  : _C.errorRed.withOpacity(0.7),
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Running state ────────────────────────────────────────────────────────────
class _RunningState extends StatelessWidget {
  final Duration elapsed;

  const _RunningState({required this.elapsed});

  @override
  Widget build(BuildContext context) {
    final ms = elapsed.inMilliseconds;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
                color: _C.runGreen, strokeWidth: 2.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Compiling & running...',
            style: const TextStyle(
                color: _C.white70, fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            ms >= 1000
                ? '${(ms / 1000).toStringAsFixed(1)}s elapsed'
                : '${ms}ms elapsed',
            style: const TextStyle(
                color: _C.white40, fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Empty output state ───────────────────────────────────────────────────────
class _EmptyOutputState extends StatelessWidget {
  final VoidCallback onRun;

  const _EmptyOutputState({required this.onRun});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(r'$', style: TextStyle(color: _C.white40, fontSize: 32, fontFamily: 'monospace')),
          const SizedBox(height: 12),
          const Text(
            'Chưa có output.\nNhấn Run ▶ để chạy chương trình.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _C.white40,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.6),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRun,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _C.runGreen.withOpacity(0.15),
                border: Border.all(color: _C.runGreen.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Run ▶',
                style: TextStyle(
                    color: _C.runGreen,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Snippet tile ─────────────────────────────────────────────────────────────
class _SnippetTile extends StatelessWidget {
  final CodeSnippet snippet;
  final VoidCallback onTap;

  const _SnippetTile({required this.snippet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Lấy 2 dòng đầu của code làm preview
    final previewLines = snippet.code.split('\n').take(2).join('\n');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Code preview box
            Container(
              width: 60,
              height: 44,
              decoration: BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _C.border),
              ),
              padding: const EdgeInsets.all(5),
              child: Text(
                previewLines,
                style: const TextStyle(
                  color: _C.accentBlue,
                  fontFamily: 'monospace',
                  fontSize: 7,
                  height: 1.4,
                ),
                overflow: TextOverflow.fade,
                maxLines: 3,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(snippet.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(snippet.description,
                      style: const TextStyle(
                          color: _C.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 13, color: _C.white40),
          ],
        ),
      ),
    );
  }
}
