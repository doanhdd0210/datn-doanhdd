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

  // Animation controllers
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 8).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_shakeController);

    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

    _startTimestamp = DateTime.now().millisecondsSinceEpoch;
    _loadQuestions();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _progressController.dispose();
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
    final timeSpent = ((DateTime.now().millisecondsSinceEpoch - _startTimestamp) / 1000).round();
    QuizResult? result;

    try {
      result = await _api.submitQuiz(widget.lessonId, _userAnswers, timeSpent);
      if (mounted) {
        context.read<UserProvider>().markLessonCompleted(widget.lessonId, widget.topicId);
        context.read<UserProvider>().addXp(result.xpEarned);
      }
    } catch (_) {
      // Build result locally
      final xpEarned = (_correctCount / _questions.length * widget.xpReward).round();
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
        context.read<UserProvider>().markLessonCompleted(widget.lessonId, widget.topicId);
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
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: Text('No questions available')),
      );
    }

    final question = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(progress),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildQuestionCard(question),
                    const SizedBox(height: 20),
                    ..._buildAnswerOptions(question),
                    if (_hasAnswered) ...[
                      const SizedBox(height: 16),
                      _buildExplanation(question),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Next button
            if (_hasAnswered) _buildNextButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double progress) {
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _showExitDialog(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 10,
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
                          Icons.favorite,
                          size: 20,
                          color: i < provider.hearts
                              ? AppColors.red
                              : AppColors.border,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_currentIndex + 1} / ${_questions.length}',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuestionCard(Question question) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value * ((_currentIndex % 2 == 0) ? 1 : -1), 0),
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Question ${_currentIndex + 1}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              question.questionText,
              style: AppTextStyles.heading4.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAnswerOptions(Question question) {
    const labels = ['A', 'B', 'C', 'D'];
    return question.options.asMap().entries.map((entry) {
      final i = entry.key;
      final option = entry.value;
      Color? bgColor;
      Color? borderColor;
      Color? textColor;

      if (_hasAnswered) {
        if (i == question.correctAnswerIndex) {
          bgColor = AppColors.primary.withOpacity(0.1);
          borderColor = AppColors.primary;
          textColor = AppColors.primary;
        } else if (i == _selectedAnswer && i != question.correctAnswerIndex) {
          bgColor = AppColors.red.withOpacity(0.1);
          borderColor = AppColors.red;
          textColor = AppColors.red;
        } else {
          bgColor = Colors.white;
          borderColor = AppColors.border;
          textColor = AppColors.textGray;
        }
      } else {
        bgColor = Colors.white;
        borderColor = AppColors.border;
        textColor = AppColors.textDark;
      }

      return GestureDetector(
        onTap: () => _selectAnswer(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor ?? AppColors.border,
              width: _hasAnswered && (i == question.correctAnswerIndex || i == _selectedAnswer) ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (borderColor ?? AppColors.border).withOpacity(0.15),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: borderColor ?? AppColors.textGray,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              if (_hasAnswered && i == question.correctAnswerIndex)
                const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
              if (_hasAnswered && i == _selectedAnswer && i != question.correctAnswerIndex)
                const Icon(Icons.cancel, color: AppColors.red, size: 20),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildExplanation(Question question) {
    final isCorrect = _selectedAnswer == question.correctAnswerIndex;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.primary.withOpacity(0.08)
            : AppColors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? AppColors.primary.withOpacity(0.3) : AppColors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCorrect ? '🎉' : '💡',
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCorrect ? 'Correct!' : 'Not quite!',
                  style: TextStyle(
                    color: isCorrect ? AppColors.primary : AppColors.red,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                if (question.explanation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    question.explanation,
                    style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    final isLast = _currentIndex == _questions.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _nextQuestion,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: AppTextStyles.buttonText,
          ),
          child: Text(isLast ? 'See Results' : 'Next Question'),
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Exit Quiz?', style: AppTextStyles.heading4),
        content: const Text(
          'Your progress will not be saved.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay', style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Exit', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}
