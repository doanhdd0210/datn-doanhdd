import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../../main.dart' show onboardingDoneKey;
import '../main_navigation_screen.dart';

class PlacementTestScreen extends StatefulWidget {
  const PlacementTestScreen({super.key});

  @override
  State<PlacementTestScreen> createState() => _PlacementTestScreenState();
}

class _PlacementTestScreenState extends State<PlacementTestScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _hasAnswered = false;
  int _score = 0;
  bool _finished = false;
  String _resultLevel = 'beginner';

  late AnimationController _progressController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  static const _questions = [
    // Dễ (0-2)
    _PlacementQuestion(
      text: 'Cách khai báo biến số nguyên trong Java nào là đúng?',
      options: ['int x = 5;', 'integer x = 5;', 'Int x = 5;', 'var x: int = 5;'],
      correct: 0,
      difficulty: 'easy',
    ),
    _PlacementQuestion(
      text: 'Kiểu nào sau đây KHÔNG phải là kiểu nguyên thủy (primitive) trong Java?',
      options: ['int', 'boolean', 'String', 'double'],
      correct: 2,
      difficulty: 'easy',
    ),
    _PlacementQuestion(
      text: 'System.out.println() dùng để làm gì?',
      options: [
        'Đọc dữ liệu nhập từ người dùng',
        'In ra văn bản và xuống dòng mới',
        'Khai báo một biến',
        'Tạo một class mới',
      ],
      correct: 1,
      difficulty: 'easy',
    ),
    // Trung bình (3-5)
    _PlacementQuestion(
      text: 'Từ khóa nào dùng để ngăn một class bị kế thừa (subclassed)?',
      options: ['static', 'abstract', 'final', 'private'],
      correct: 2,
      difficulty: 'medium',
    ),
    _PlacementQuestion(
      text: 'Kết quả của System.out.println(10 / 3); trong Java là gì?',
      options: ['3.33', '3', '3.0', 'Lỗi'],
      correct: 1,
      difficulty: 'medium',
    ),
    _PlacementQuestion(
      text: 'Interface nào một class cần implement để dùng được Collections.sort()?',
      options: ['Sortable', 'Comparable', 'Comparator', 'Iterable'],
      correct: 1,
      difficulty: 'medium',
    ),
    // Khó (6-7)
    _PlacementQuestion(
      text: 'Độ phức tạp thời gian của HashMap.get() trong trường hợp trung bình là?',
      options: ['O(n)', 'O(log n)', 'O(1)', 'O(n²)'],
      correct: 2,
      difficulty: 'hard',
    ),
    _PlacementQuestion(
      text: 'Từ khóa Java nào đảm bảo một khối lệnh luôn được thực thi dù có exception?',
      options: ['catch', 'throws', 'finally', 'try'],
      correct: 2,
      difficulty: 'hard',
    ),
  ];

  static const _difficultyColors = {
    'easy': AppColors.primary,
    'medium': AppColors.blue,
    'hard': AppColors.streakOrange,
  };

  static const _difficultyLabels = {
    'easy': 'DỄ',
    'medium': 'TRUNG BÌNH',
    'hard': 'KHÓ',
  };

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (_hasAnswered) return;
    final q = _questions[_currentIndex];
    final correct = index == q.correct;
    if (correct) _score++;
    if (!correct) _shakeController.forward(from: 0);
    setState(() {
      _selectedAnswer = index;
      _hasAnswered = true;
    });
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _hasAnswered = false;
      });
    } else {
      _finish();
    }
  }

  void _finish() {
    // 0–2 → beginner, 3–5 → intermediate, 6–8 → advanced
    String level;
    if (_score <= 2) {
      level = 'beginner';
    } else if (_score <= 5) {
      level = 'intermediate';
    } else {
      level = 'advanced';
    }
    setState(() {
      _finished = true;
      _resultLevel = level;
    });
  }

  Future<void> _saveAndContinue() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(onboardingDoneKey(uid), true);
    }
    if (mounted) {
      await context.read<UserProvider>().setLevel(_resultLevel);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: _finished ? _buildResult() : _buildTest(),
      ),
    );
  }

  Widget _buildTest() {
    final q = _questions[_currentIndex];
    final progress = (_currentIndex + (_hasAnswered ? 1 : 0)) / _questions.length;
    final diffColor = _difficultyColors[q.difficulty] ?? AppColors.primary;

    return Column(
      children: [
        // Header
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.textGray, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation(diffColor),
                        minHeight: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_currentIndex + 1}/${_questions.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: AnimatedBuilder(
            animation: _shakeAnim,
            builder: (ctx, child) => Transform.translate(
              offset: Offset(_shakeAnim.value, 0),
              child: child,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Difficulty badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: diffColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _difficultyLabels[q.difficulty] ?? q.difficulty.toUpperCase(),
                          style: TextStyle(
                            color: diffColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Chọn đáp án đúng',
                          style: TextStyle(
                              color: AppColors.textGray, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Question
                  Text(
                    q.text,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Options
                  ...q.options.asMap().entries.map((entry) {
                    final i = entry.key;
                    final text = entry.value;
                    final isSelected = _selectedAnswer == i;
                    final isCorrect = i == q.correct;
                    const labels = ['A', 'B', 'C', 'D'];

                    Color bgColor = AppColors.surface;
                    Color borderColor = AppColors.border;
                    Color bottomBorder = AppColors.borderDark;
                    Color labelBg = AppColors.surfaceElevated;
                    Color labelText = AppColors.textGray;
                    Color textColor = AppColors.textDark;

                    if (_hasAnswered) {
                      if (isCorrect) {
                        bgColor = AppColors.correctBg;
                        borderColor = AppColors.correct;
                        bottomBorder = AppColors.correctDark;
                        labelBg = AppColors.correct;
                        labelText = Colors.white;
                        textColor = Colors.white;
                      } else if (isSelected) {
                        bgColor = AppColors.wrongBg;
                        borderColor = AppColors.wrong;
                        bottomBorder = AppColors.wrongDark;
                        labelBg = AppColors.wrong;
                        labelText = Colors.white;
                        textColor = Colors.white;
                      } else {
                        textColor = AppColors.textLight;
                        labelText = AppColors.textLight;
                      }
                    } else if (isSelected) {
                      bgColor = const Color(0xFFEEF9FF);
                      borderColor = AppColors.blue;
                      bottomBorder = AppColors.blueDark;
                      labelBg = AppColors.blue;
                      labelText = Colors.white;
                      textColor = AppColors.blueDark;
                    }

                    return GestureDetector(
                      onTap: () => _select(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: bottomBorder,
                              offset: const Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: labelBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(labels[i],
                                    style: TextStyle(
                                        color: labelText,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(text,
                                  style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      height: 1.4)),
                            ),
                            if (_hasAnswered && isCorrect)
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary, size: 22),
                            if (_hasAnswered && isSelected && !isCorrect)
                              const Icon(Icons.cancel_rounded,
                                  color: AppColors.heartRed, size: 22),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),

        // Continue button
        if (_hasAnswered)
          _FeedbackBar(
            isCorrect: _selectedAnswer == q.correct,
            isLast: _currentIndex == _questions.length - 1,
            onContinue: _next,
          ),
      ],
    );
  }

  Widget _buildResult() {
    final Map<String, _ResultData> results = {
      'beginner': const _ResultData(
        emoji: '🌱',
        title: 'Bạn đang ở trình độ cơ bản!',
        subtitle: 'Không sao cả — ai cũng phải bắt đầu từ đâu đó. Chúng tôi sẽ xây dựng nền tảng cho bạn từng bước.',
        color: AppColors.primary,
        shadowColor: AppColors.primaryDark,
        bgColor: Color(0xFFD7FFB8),
        levelLabel: 'Lộ trình cơ bản',
        unlockText: 'Bắt đầu từ bài học đầu tiên',
      ),
      'intermediate': const _ResultData(
        emoji: '⚡',
        title: 'Bạn đang ở trình độ trung cấp!',
        subtitle: 'Tuyệt! Bạn đã nắm cơ bản. Chúng tôi sẽ đưa bạn thẳng vào OOP và hơn thế nữa.',
        color: AppColors.blue,
        shadowColor: AppColors.blueDark,
        bgColor: Color(0xFFCCEDFF),
        levelLabel: 'Lộ trình trung cấp',
        unlockText: 'Đã mở khóa 4 chủ đề đầu tiên',
      ),
      'advanced': const _ResultData(
        emoji: '🔥',
        title: 'Bạn đang ở trình độ nâng cao!',
        subtitle: 'Ấn tượng! Tất cả chủ đề đã được mở khóa. Bắt tay vào những thứ khó ngay thôi.',
        color: AppColors.streakOrange,
        shadowColor: Color(0xFFCC6600),
        bgColor: Color(0xFFFFDDBB),
        levelLabel: 'Lộ trình nâng cao',
        unlockText: 'Tất cả chủ đề đã mở khóa!',
      ),
    };

    final r = results[_resultLevel]!;

    return Container(
      color: r.bgColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Score circle
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: r.color,
              boxShadow: [
                BoxShadow(
                  color: r.shadowColor,
                  offset: const Offset(0, 6),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.emoji, style: const TextStyle(fontSize: 44)),
                  Text(
                    '$_score/${_questions.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text(
                  r.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: r.shadowColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  r.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: r.shadowColor.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Level badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: r.color,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: r.shadowColor,
                        offset: const Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(r.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.levelLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15)),
                          Text(r.unlockText,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: GestureDetector(
              onTap: _saveAndContinue,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: r.color,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border(bottom: BorderSide(color: r.shadowColor, width: 4)),
                ),
                child: const Text(
                  'BẮT ĐẦU HÀNH TRÌNH',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
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
}

// ─── Feedback Bar ─────────────────────────────────────────────────────────────

class _FeedbackBar extends StatelessWidget {
  final bool isCorrect;
  final bool isLast;
  final VoidCallback onContinue;

  const _FeedbackBar(
      {required this.isCorrect,
      required this.isLast,
      required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isCorrect ? const Color(0xFFD7FFB8) : const Color(0xFFFFDDDD);
    final accentColor =
        isCorrect ? AppColors.primaryDark : AppColors.heartRed;
    final btnColor = isCorrect ? AppColors.primary : AppColors.heartRed;
    final btnShadow =
        isCorrect ? AppColors.primaryDark : const Color(0xFFCC2222);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: accentColor.withOpacity(0.3))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isCorrect ? '🎉' : '❌',
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Chính xác!' : 'Sai rồi!',
                style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                  fontWeight: FontWeight.w900,
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

// ─── Data classes ─────────────────────────────────────────────────────────────

class _PlacementQuestion {
  final String text;
  final List<String> options;
  final int correct;
  final String difficulty;

  const _PlacementQuestion({
    required this.text,
    required this.options,
    required this.correct,
    required this.difficulty,
  });
}

class _ResultData {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final Color shadowColor;
  final Color bgColor;
  final String levelLabel;
  final String unlockText;

  const _ResultData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.shadowColor,
    required this.bgColor,
    required this.levelLabel,
    required this.unlockText,
  });
}
