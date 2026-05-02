import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';
import '../../models/question.dart';
import '../../models/quiz_result.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../services/ai_service.dart';
import 'quiz_result_screen.dart';

/// Câu hỏi đã được shuffle đáp án
class _ShuffledQuestion {
  final List<String> options;      // đáp án đã xáo trộn
  final int correctIndex;          // vị trí đúng sau khi xáo (dùng để hiển thị UI)
  final List<int> originalIndices; // originalIndices[shuffledPos] = originalPos

  _ShuffledQuestion({
    required this.options,
    required this.correctIndex,
    required this.originalIndices,
  });

  /// Chuyển shuffled index → original index để gửi lên server
  int toOriginalIndex(int shuffledIndex) => originalIndices[shuffledIndex];

  static _ShuffledQuestion from(Question q) {
    final indexed = q.options.asMap().entries.toList()
      ..shuffle(Random());
    final newCorrect = indexed.indexWhere((e) => e.key == q.correctAnswerIndex);
    return _ShuffledQuestion(
      options: indexed.map((e) => e.value).toList(),
      correctIndex: newCorrect,
      originalIndices: indexed.map((e) => e.key).toList(),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final String lessonId;
  final String topicId;
  final String lessonTitle;
  final int xpReward;

  const QuizScreen({
    super.key,
    required this.lessonId,
    required this.topicId,
    required this.lessonTitle,
    required this.xpReward,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  final _api = ApiService();
  List<Question> _questions = [];
  List<_ShuffledQuestion> _shuffled = [];  // đáp án đã xáo trộn
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _hasAnswered = false;
  int _correctCount = 0;
  final List<UserAnswer> _userAnswers = [];
  int _startTimestamp = 0;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _feedbackController;
  late Animation<double> _feedbackAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _feedbackAnimation = CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.easeOut,
    );

    _startTimestamp = DateTime.now().millisecondsSinceEpoch;
    _loadQuestions();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _api.getQuestions(widget.lessonId);
      if (mounted) {
        final qs = questions.isNotEmpty ? questions : _mockQuestions();
        setState(() {
          _questions = qs;
          _shuffled = qs.map(_ShuffledQuestion.from).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        final qs = _mockQuestions();
        setState(() {
          _questions = qs;
          _shuffled = qs.map(_ShuffledQuestion.from).toList();
          _isLoading = false;
        });
      }
    }
  }

  List<Question> _mockQuestions() {
    return [
      const Question(
        id: 'q1', lessonId: 'mock',
        questionText: 'What is the output of: System.out.println("Hello " + "World");',
        explanation: 'String concatenation with + operator combines the two strings.',
        options: ['Hello', 'World', 'Hello World', 'Error'],
        correctAnswerIndex: 2, order: 1, points: 10,
      ),
      const Question(
        id: 'q2', lessonId: 'mock',
        questionText: 'Which keyword is used to define a class in Java?',
        explanation: 'The "class" keyword is used to declare a class in Java.',
        options: ['object', 'class', 'type', 'define'],
        correctAnswerIndex: 1, order: 2, points: 10,
      ),
      const Question(
        id: 'q3', lessonId: 'mock',
        questionText: 'What is the default value of an int variable in Java?',
        explanation: 'Uninitialized int fields default to 0 in Java.',
        options: ['null', '-1', '0', '1'],
        correctAnswerIndex: 2, order: 3, points: 10,
      ),
    ];
  }

  void _selectAnswer(int index) {
    if (_hasAnswered) return;

    final question = _questions[_currentIndex];
    final isCorrect = index == _shuffled[_currentIndex].correctIndex;

    setState(() {
      _selectedAnswer = index;
      _hasAnswered = true;
    });

    _feedbackController.forward(from: 0);

    // Gửi original index lên server (không phải shuffled index)
    final originalIndex = _shuffled[_currentIndex].toOriginalIndex(index);
    _userAnswers.add(UserAnswer(
      questionId: question.id,
      selectedAnswerIndex: originalIndex,
      isCorrect: isCorrect,
    ));

    if (isCorrect) {
      _correctCount++;
    } else {
      _shakeController.forward(from: 0);
    }
  }

  void _nextQuestion() {
    _feedbackController.reverse();
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _hasAnswered = false;
      });
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    setState(() => _isSubmitting = true);
    final timeSpent =
        ((DateTime.now().millisecondsSinceEpoch - _startTimestamp) / 1000)
            .round();

    // Tính kết quả local làm fallback
    final ratio = _questions.isNotEmpty ? _correctCount / _questions.length : 0.0;
    final isPerfect = _questions.isNotEmpty && _correctCount == _questions.length;
    final localXp = isPerfect ? widget.xpReward : 0;
    QuizResult result = QuizResult(
      id: 'local',
      lessonId: widget.lessonId,
      totalQuestions: _questions.length,
      correctAnswers: _correctCount,
      score: (ratio * 100).round(),
      xpEarned: localXp,
      answers: _userAnswers,
      completedAt: DateTime.now(),
    );

    // Mark perfect quiz achievement
    if (isPerfect) {
      context.read<UserProvider>().markPerfectQuiz();
    }

    try {
      final serverResult = await _api.submitQuiz(widget.lessonId, _userAnswers, timeSpent);
      result = serverResult;
      if (mounted && isPerfect) {
        await _api.completeLesson(widget.lessonId, widget.topicId, timeSpentSeconds: timeSpent);
      }
      if (mounted) {
        if (isPerfect) {
          context.read<UserProvider>().markLessonCompleted(widget.lessonId, widget.topicId);
        }
        if (result.xpEarned > 0) {
          context.read<UserProvider>().addXp(result.xpEarned);
        }
      }
    } catch (_) {
      if (mounted) {
        if (isPerfect) {
          final provider = context.read<UserProvider>();
          final alreadyDone = provider.isLessonCompleted(widget.lessonId);
          provider.markLessonCompleted(widget.lessonId, widget.topicId);
          _api.completeLesson(widget.lessonId, widget.topicId, timeSpentSeconds: timeSpent).catchError((_) {});
          // Fallback XP chỉ khi lần đầu hoàn thành (offline)
          if (!alreadyDone) {
            provider.addXp(localXp);
          }
        }
      }
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            result: result,
            questions: _questions,
            lessonTitle: widget.lessonTitle,
            lessonId: widget.lessonId,
            topicId: widget.topicId,
            xpReward: widget.xpReward,
            isPerfect: isPerfect,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _QuizLoadingScreen(lessonTitle: widget.lessonTitle);
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bài trắc nghiệm')),
        body: const Center(child: Text('Không có câu hỏi nào')),
      );
    }

    final question = _questions[_currentIndex];
    final shuffled = _shuffled[_currentIndex];
    final progress = (_currentIndex + (_hasAnswered ? 1 : 0)) / _questions.length;
    final isCorrect = _hasAnswered && _selectedAnswer == shuffled.correctIndex;

    return Stack(
      children: [
        Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _QuizHeader(progress: progress, onClose: _showExitDialog),
            Expanded(
              child: AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (ctx, child) => Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Câu hỏi số mấy
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Câu ${_currentIndex + 1}/${_questions.length}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Chọn câu trả lời đúng', style: AppTextStyles.labelGray),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        question.questionText,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...shuffled.options.asMap().entries.map(
                        (entry) => _AnswerOption(
                          index: entry.key,
                          text: entry.value,
                          hasAnswered: _hasAnswered,
                          selectedAnswer: _selectedAnswer,
                          correctAnswer: shuffled.correctIndex,
                          onTap: () => _selectAnswer(entry.key),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Feedback bar (sau khi trả lời)
            SizeTransition(
              sizeFactor: _feedbackAnimation,
              axisAlignment: 1,
              child: _hasAnswered
                  ? _FeedbackBar(
                      key: ValueKey(_currentIndex),
                      isCorrect: isCorrect,
                      explanation: question.explanation,
                      isLast: _currentIndex == _questions.length - 1,
                      onContinue: _nextQuestion,
                      question: question,
                    )
                  : const SizedBox.shrink(),
            ),
            // Nút kiểm tra (trước khi trả lời)
            if (!_hasAnswered)
              _IdleCheckBar(hasSelected: _selectedAnswer != null),
          ],
        ),
      ),
        ),
        // Submitting overlay
        if (_isSubmitting)
          Positioned.fill(
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              child: Center(
                child: Material(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  elevation: 8,
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Đang tính kết quả...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Thoát bài trắc nghiệm?', style: AppTextStyles.heading4),
        content: const Text('Tiến độ của bạn sẽ không được lưu.', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ở lại',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Text('Thoát',
                style: TextStyle(color: AppColors.heartRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

}

// ─── Quiz Header ──────────────────────────────────────────────────────────────

class _QuizHeader extends StatelessWidget {
  final double progress;
  final VoidCallback onClose;

  const _QuizHeader({required this.progress, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // X button
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: context.surfaceElevatedColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.borderColor),
              ),
              child: Icon(Icons.close_rounded, color: context.textSecondary, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Progress bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: context.borderColor,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Answer Option ────────────────────────────────────────────────────────────

class _AnswerOption extends StatelessWidget {
  final int index;
  final String text;
  final bool hasAnswered;
  final int? selectedAnswer;
  final int correctAnswer;
  final VoidCallback onTap;

  const _AnswerOption({
    required this.index,
    required this.text,
    required this.hasAnswered,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedAnswer == index;
    final isCorrectAnswer = index == correctAnswer;

    // ── State colours ──────────────────────────────────────────────────────
    Color bgColor      = context.surfaceColor;
    Color borderColor  = context.borderColor;
    Color textColor    = context.textPrimary;
    Color labelBg      = context.surfaceElevatedColor;
    Color labelColor   = context.textSecondary;
    Color accentStrip  = Colors.transparent;
    Widget? trailingIcon;

    if (hasAnswered) {
      if (isCorrectAnswer) {
        bgColor     = const Color(0xFF4CAF50).withValues(alpha: 0.08);
        borderColor = const Color(0xFF4CAF50).withValues(alpha: 0.5);
        textColor   = const Color(0xFF2E7D32);
        labelBg     = const Color(0xFF4CAF50);
        labelColor  = Colors.white;
        accentStrip = const Color(0xFF4CAF50);
        trailingIcon = const Icon(Icons.check_circle_rounded,
            color: Color(0xFF4CAF50), size: 20);
      } else if (isSelected) {
        bgColor     = const Color(0xFFF44336).withValues(alpha: 0.07);
        borderColor = const Color(0xFFF44336).withValues(alpha: 0.4);
        textColor   = const Color(0xFFC62828);
        labelBg     = const Color(0xFFF44336);
        labelColor  = Colors.white;
        accentStrip = const Color(0xFFF44336);
        trailingIcon = const Icon(Icons.cancel_rounded,
            color: Color(0xFFF44336), size: 20);
      } else {
        // unselected, wrong — dim out
        borderColor = context.borderColor.withValues(alpha: 0.35);
        textColor   = context.textSecondary.withValues(alpha: 0.4);
        labelColor  = context.textTertiary.withValues(alpha: 0.4);
      }
    } else if (isSelected) {
      bgColor     = AppColors.primary.withValues(alpha: 0.06);
      borderColor = AppColors.primary.withValues(alpha: 0.7);
      textColor   = AppColors.primary;
      labelBg     = AppColors.primary;
      labelColor  = Colors.white;
      accentStrip = AppColors.primary;
    }

    const labels = ['A', 'B', 'C', 'D'];
    final showStrip = accentStrip != Colors.transparent;

    return GestureDetector(
      onTap: hasAnswered ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Row(
            children: [
              // Left accent strip
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: showStrip ? 4 : 0,
                color: accentStrip,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  child: Row(
                    children: [
                      // Label badge
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: labelBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            labels[index],
                            style: TextStyle(
                              color: labelColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: 8),
                        trailingIcon,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Feedback Bar ─────────────────────────────────────────────────────────────

class _FeedbackBar extends StatefulWidget {
  final bool isCorrect;
  final String explanation;
  final bool isLast;
  final VoidCallback onContinue;
  final Question question;

  const _FeedbackBar({
    super.key,
    required this.isCorrect,
    required this.explanation,
    required this.isLast,
    required this.onContinue,
    required this.question,
  });

  @override
  State<_FeedbackBar> createState() => _FeedbackBarState();
}

class _FeedbackBarState extends State<_FeedbackBar> {
  final _aiService = AiService();
  String? _aiHint;
  bool _aiLoading = false;
  bool _aiRequested = false;

  Future<void> _askAiHint() async {
    setState(() { _aiLoading = true; _aiRequested = true; });
    final hint = await _aiService.generateQuizHint(
      question: widget.question.questionText,
      options: widget.question.options,
      correctIndex: widget.question.correctAnswerIndex,
    );
    if (!mounted) return;
    setState(() { _aiLoading = false; _aiHint = hint; });
  }

  @override
  Widget build(BuildContext context) {
    final isCorrect = widget.isCorrect;
    final accentColor = isCorrect ? AppColors.correct : AppColors.wrong;
    final bgColor = isCorrect
        ? AppColors.correct.withValues(alpha: 0.08)
        : AppColors.wrong.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          top: BorderSide(color: accentColor, width: 2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Colored header strip ──
          Container(
            color: bgColor,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      isCorrect ? '🎉' : '❌',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCorrect ? 'Tuyệt vời!' : 'Sai rồi!',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      if (widget.explanation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.explanation,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── AI hint section (chỉ khi sai) ──
          if (!isCorrect)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _buildAiSection(context),
            ),

          // ── Button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: GestureDetector(
              onTap: widget.onContinue,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isCorrect ? AppColors.correctDark : AppColors.wrongDark,
                      offset: const Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  widget.isLast ? 'XEM KẾT QUẢ' : 'TIẾP TỤC',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSection(BuildContext context) {
    if (_aiLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surfaceElevatedColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            SizedBox(width: 10),
            Text('AI đang phân tích...', style: TextStyle(fontSize: 13, color: AppColors.textGray)),
          ],
        ),
      );
    }

    if (_aiHint != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🤖', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                const Text('AI Gợi ý',
                    style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() { _aiHint = null; _aiRequested = false; }),
                  child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textGray),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_aiHint!, style: TextStyle(color: context.textPrimary, fontSize: 13, height: 1.45)),
          ],
        ),
      );
    }

    // Nút gọi AI
    if (!_aiRequested) {
      return GestureDetector(
        onTap: _askAiHint,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: context.surfaceElevatedColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🤖', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Text('Hỏi AI tại sao sai?',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: context.textSecondary),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ─── Idle Check Bar ───────────────────────────────────────────────────────────

class _IdleCheckBar extends StatelessWidget {
  final bool hasSelected;

  const _IdleCheckBar({required this.hasSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.surfaceColor,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: AnimatedOpacity(
        opacity: hasSelected ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: hasSelected ? AppColors.primary : context.borderColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: hasSelected ? AppColors.primaryDark : Colors.transparent,
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: const Text(
            'KIỂM TRA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Quiz Loading Screen ──────────────────────────────────────────────────────

class _QuizLoadingScreen extends StatefulWidget {
  final String lessonTitle;

  const _QuizLoadingScreen({required this.lessonTitle});

  @override
  State<_QuizLoadingScreen> createState() => _QuizLoadingScreenState();
}

class _QuizLoadingScreenState extends State<_QuizLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: false);

    _fadeAnim = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Icon bài kiểm tra
              FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Text('📝', style: TextStyle(fontSize: 40)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Tiêu đề bài
              Text(
                widget.lessonTitle,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Bài trắc nghiệm',
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),
              // Loading dots
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final delay = i / 3;
                      final raw = (_controller.value - delay) % 1.0;
                      final t = raw < 0.5 ? raw * 2 : (1.0 - raw) * 2;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: 8 + t * 4,
                        height: 8 + t * 4,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.4 + t * 0.6),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Đang tải câu hỏi...',
                style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(flex: 2),
              // Tips card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cần trả lời đúng 100% để mở khoá bài học tiếp theo!',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
