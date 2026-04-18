import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/question.dart';
import '../../models/quiz_result.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import 'quiz_result_screen.dart';

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
        setState(() {
          _questions = questions.isNotEmpty ? questions : _mockQuestions();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _questions = _mockQuestions();
          _isLoading = false;
        });
      }
    }
  }

  List<Question> _mockQuestions() {
    return [
      const Question(
        id: 'q1',
        lessonId: 'mock',
        questionText: 'What is the output of: System.out.println("Hello " + "World");',
        explanation: 'String concatenation with + operator combines the two strings.',
        options: ['Hello', 'World', 'Hello World', 'Error'],
        correctAnswerIndex: 2,
        order: 1,
        points: 10,
      ),
      const Question(
        id: 'q2',
        lessonId: 'mock',
        questionText: 'Which keyword is used to define a class in Java?',
        explanation: 'The "class" keyword is used to declare a class in Java.',
        options: ['object', 'class', 'type', 'define'],
        correctAnswerIndex: 1,
        order: 2,
        points: 10,
      ),
      const Question(
        id: 'q3',
        lessonId: 'mock',
        questionText: 'What is the default value of an int variable in Java?',
        explanation: 'Uninitialized int fields default to 0 in Java.',
        options: ['null', '-1', '0', '1'],
        correctAnswerIndex: 2,
        order: 3,
        points: 10,
      ),
    ];
  }

  void _selectAnswer(int index) {
    if (_hasAnswered) return;

    final question = _questions[_currentIndex];
    final isCorrect = index == question.correctAnswerIndex;

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
      context.read<UserProvider>().loseHeart();
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
    QuizResult? result;

    try {
      result = await _api.submitQuiz(widget.lessonId, _userAnswers, timeSpent);
      if (mounted) {
        context
            .read<UserProvider>()
            .markLessonCompleted(widget.lessonId, widget.topicId);
        context.read<UserProvider>().addXp(result.xpEarned);
      }
    } catch (_) {
      final xpEarned =
          (_correctCount / _questions.length * widget.xpReward).round();
      result = QuizResult(
        id: 'local',
        lessonId: widget.lessonId,
        totalQuestions: _questions.length,
        correctAnswers: _correctCount,
        score: (_correctCount / _questions.length * 100).round(),
        xpEarned: xpEarned,
        answers: _userAnswers,
        completedAt: DateTime.now(),
      );
      if (mounted) {
        context
            .read<UserProvider>()
            .markLessonCompleted(widget.lessonId, widget.topicId);
        context.read<UserProvider>().addXp(xpEarned);
      }
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            result: result!,
            questions: _questions,
            lessonTitle: widget.lessonTitle,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bài trắc nghiệm')),
        body: const Center(child: Text('Không có câu hỏi nào')),
      );
    }

    final question = _questions[_currentIndex];
    final progress = (_currentIndex + (_hasAnswered ? 1 : 0)) / _questions.length;
    final isCorrect = _hasAnswered && _selectedAnswer == question.correctAnswerIndex;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            _QuizHeader(
              progress: progress,
              onClose: _showExitDialog,
            ),
            // ── Question + Options ───────────────────────────
            Expanded(
              child: AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (ctx, child) => Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category label
                      Text(
                        'Chọn câu trả lời đúng',
                        style: AppTextStyles.labelGray,
                      ),
                      const SizedBox(height: 16),
                      // Question text
                      Text(
                        question.questionText,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Answer options
                      ...question.options.asMap().entries.map(
                            (entry) => _AnswerOption(
                              index: entry.key,
                              text: entry.value,
                              hasAnswered: _hasAnswered,
                              selectedAnswer: _selectedAnswer,
                              correctAnswer: question.correctAnswerIndex,
                              onTap: () => _selectAnswer(entry.key),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
            // ── Feedback + CTA ───────────────────────────────
            SizeTransition(
              sizeFactor: _feedbackAnimation,
              axisAlignment: 1,
              child: _hasAnswered
                  ? _FeedbackBar(
                      isCorrect: isCorrect,
                      explanation: question.explanation,
                      isLast: _currentIndex == _questions.length - 1,
                      onContinue: _nextQuestion,
                    )
                  : const SizedBox.shrink(),
            ),
            // ── Idle CTA (no answer yet) ─────────────────────
            if (!_hasAnswered)
              _IdleCheckBar(
                hasSelected: _selectedAnswer != null,
              ),
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
        content: const Text(
          'Tiến độ của bạn sẽ không được lưu.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ở lại',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Thoát',
                style: TextStyle(
                    color: AppColors.heartRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Quiz Header ─────────────────────────────────────────────────────────────

class _QuizHeader extends StatelessWidget {
  final double progress;
  final VoidCallback onClose;

  const _QuizHeader({required this.progress, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        return Container(
          color: AppColors.background,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              // X button
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textGray,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Progress bar
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Hearts
              Row(
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(
                      i < provider.hearts
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 22,
                      color: i < provider.hearts
                          ? AppColors.heartRed
                          : AppColors.border,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

    Color bgColor = AppColors.surface;
    Color borderColor = AppColors.border;
    Color borderBottomColor = AppColors.borderDark;
    Color textColor = AppColors.textDark;
    Color labelBg = AppColors.surfaceElevated;
    Color labelColor = AppColors.textGray;

    if (hasAnswered) {
      if (isCorrectAnswer) {
        bgColor = AppColors.correctBg;
        borderColor = AppColors.correct;
        borderBottomColor = AppColors.correctDark;
        textColor = Colors.white;
        labelBg = AppColors.correct;
        labelColor = Colors.white;
      } else if (isSelected) {
        bgColor = AppColors.wrongBg;
        borderColor = AppColors.wrong;
        borderBottomColor = AppColors.wrongDark;
        textColor = Colors.white;
        labelBg = AppColors.wrong;
        labelColor = Colors.white;
      } else {
        bgColor = AppColors.surface;
        borderColor = AppColors.border;
        borderBottomColor = AppColors.border;
        textColor = AppColors.textMuted;
        labelBg = AppColors.surfaceElevated;
        labelColor = AppColors.textMuted;
      }
    } else if (isSelected) {
      bgColor = AppColors.primary.withOpacity(0.15);
      borderColor = AppColors.primary;
      borderBottomColor = AppColors.primaryDark;
      textColor = AppColors.textDark;
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
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: borderBottomColor,
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Letter label
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
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
              const SizedBox(width: 14),
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
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 22),
              if (hasAnswered && isSelected && !isCorrectAnswer)
                const Icon(Icons.cancel_rounded,
                    color: AppColors.heartRed, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Feedback Bar (correct / incorrect) ──────────────────────────────────────

class _FeedbackBar extends StatelessWidget {
  final bool isCorrect;
  final String explanation;
  final bool isLast;
  final VoidCallback onContinue;

  const _FeedbackBar({
    required this.isCorrect,
    required this.explanation,
    required this.isLast,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isCorrect ? AppColors.correctBg : AppColors.wrongBg;
    final accentColor = isCorrect ? AppColors.correct : AppColors.wrong;
    final btnColor = isCorrect ? AppColors.correct : AppColors.wrong;
    final btnShadow = isCorrect ? AppColors.correctDark : AppColors.wrongDark;
    final icon = isCorrect ? '🎉' : '❌';
    final title = isCorrect ? 'Tuyệt vời!' : 'Sai rồi!';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: accentColor.withOpacity(0.3))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              explanation,
              style: TextStyle(
                color: accentColor.withOpacity(0.8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // CONTINUE button — Duolingo style with 3D border
          GestureDetector(
            onTap: onContinue,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: btnColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: btnShadow,
                    offset: const Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                isLast ? 'XEM KẾT QUẢ' : 'TIẾP TỤC',
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
        ],
      ),
    );
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
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: AnimatedOpacity(
        opacity: hasSelected ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: hasSelected ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: hasSelected ? AppColors.primaryDark : AppColors.borderDark,
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
