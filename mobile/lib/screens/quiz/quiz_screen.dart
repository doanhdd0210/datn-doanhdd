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
  final List<String> options;     // đáp án đã xáo trộn
  final int correctIndex;         // vị trí đúng sau khi xáo

  _ShuffledQuestion({required this.options, required this.correctIndex});

  static _ShuffledQuestion from(Question q) {
    final indexed = q.options.asMap().entries.toList()
      ..shuffle(Random());
    final newCorrect = indexed.indexWhere((e) => e.key == q.correctAnswerIndex);
    return _ShuffledQuestion(
      options: indexed.map((e) => e.value).toList(),
      correctIndex: newCorrect,
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

    _userAnswers.add(UserAnswer(
      questionId: question.id,
      selectedAnswerIndex: index,
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
    final timeSpent =
        ((DateTime.now().millisecondsSinceEpoch - _startTimestamp) / 1000)
            .round();

    // Tính kết quả local làm fallback
    final totalPoints = _questions.fold(0, (sum, q) => sum + q.points);
    final ratio = _questions.isNotEmpty ? _correctCount / _questions.length : 0.0;
    final localXp = (ratio * totalPoints).round();
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

    // Mark perfect quiz nếu không sai câu nào
    if (_correctCount == _questions.length && _questions.isNotEmpty) {
      context.read<UserProvider>().markPerfectQuiz();
    }

    try {
      final serverResult = await _api.submitQuiz(widget.lessonId, _userAnswers, timeSpent);
      result = serverResult;
      if (mounted) {
        context.read<UserProvider>().markLessonCompleted(widget.lessonId, widget.topicId);
        context.read<UserProvider>().addXp(result.xpEarned);
      }
    } catch (_) {
      if (mounted) {
        context.read<UserProvider>().markLessonCompleted(widget.lessonId, widget.topicId);
        context.read<UserProvider>().addXp(localXp);
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
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.bgColor,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
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

    return Scaffold(
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

    Color bgColor = context.surfaceColor;
    Color borderColor = context.borderColor;
    Color shadowColor = context.borderColor;
    Color textColor = context.textPrimary;
    Color labelBg = context.surfaceElevatedColor;
    Color labelColor = context.textSecondary;

    if (hasAnswered) {
      if (isCorrectAnswer) {
        bgColor = AppColors.correct.withValues(alpha: 0.12);
        borderColor = AppColors.correct;
        shadowColor = AppColors.correctDark;
        textColor = AppColors.correct;
        labelBg = AppColors.correct;
        labelColor = Colors.white;
      } else if (isSelected) {
        bgColor = AppColors.wrong.withValues(alpha: 0.1);
        borderColor = AppColors.wrong;
        shadowColor = AppColors.wrongDark;
        textColor = AppColors.wrong;
        labelBg = AppColors.wrong;
        labelColor = Colors.white;
      } else {
        // Các option không chọn và không đúng — mờ nhẹ
        bgColor = context.surfaceColor;
        borderColor = context.borderColor.withValues(alpha: 0.5);
        shadowColor = Colors.transparent;
        textColor = context.textSecondary.withValues(alpha: 0.5);
        labelBg = context.surfaceElevatedColor;
        labelColor = context.textTertiary;
      }
    } else if (isSelected) {
      bgColor = AppColors.primary.withValues(alpha: 0.08);
      borderColor = AppColors.primary;
      shadowColor = AppColors.primaryDark;
      textColor = AppColors.primary;
      labelBg = AppColors.primary;
      labelColor = Colors.white;
    }

    const labels = ['A', 'B', 'C', 'D'];

    return GestureDetector(
      onTap: hasAnswered ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: shadowColor != Colors.transparent
              ? [BoxShadow(color: shadowColor, offset: const Offset(0, 3), blurRadius: 0)]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32, height: 32,
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
                      fontSize: 14,
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
              if (hasAnswered && isCorrectAnswer)
                const Icon(Icons.check_circle_rounded, color: AppColors.correct, size: 22),
              if (hasAnswered && isSelected && !isCorrectAnswer)
                const Icon(Icons.cancel_rounded, color: AppColors.wrong, size: 22),
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
                const Text('Gemini AI',
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
