import 'package:flutter/material.dart';
import 'level_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  static const _slides = [
    _SlideData(
      emoji: '☕',
      title: 'Chinh phục Java\ntheo cách thú vị',
      subtitle: 'Học lập trình Java qua các bài học ngắn gọn, câu đố tương tác và thử thách code thực tế.',
      bgColor: Color(0xFF304FFE),
      cardColor: Color(0xFF2438CC),
      accentColor: Colors.white,
    ),
    _SlideData(
      emoji: '🗺️',
      title: 'Lộ trình học\nriêng của bạn',
      subtitle: 'Theo cây kỹ năng được cá nhân hóa theo trình độ. Mở khóa chủ đề từng bước khi bạn tiến bộ.',
      bgColor: Color(0xFF6949FF),
      cardColor: Color(0xFF4A2FDD),
      accentColor: Colors.white,
    ),
    _SlideData(
      emoji: '⚡',
      title: 'Kiếm XP &\nduy trì streak',
      subtitle: 'Giữ động lực với streak hàng ngày, phần thưởng XP và leo bảng xếp hạng cùng bạn bè.',
      bgColor: Color(0xFFFF9800),
      cardColor: Color(0xFFCC6600),
      accentColor: Colors.white,
    ),
    _SlideData(
      emoji: '🚀',
      title: 'Sẵn sàng bắt đầu\nhành trình chưa?',
      subtitle: 'Chúng tôi sẽ thiết lập lộ trình học phù hợp với trình độ Java hiện tại của bạn.',
      bgColor: Color(0xFF181A20),
      cardColor: Color(0xFF262A35),
      accentColor: Colors.white,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: -12, end: 12).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _goToLevelSelection();
    }
  }

  void _goToLevelSelection() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LevelSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];

    return Scaffold(
      backgroundColor: slide.bgColor,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        color: slide.bgColor,
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 20, 0),
                  child: _currentPage < _slides.length - 1
                      ? TextButton(
                          onPressed: _goToLevelSelection,
                          child: Text(
                            'Bỏ qua',
                            style: TextStyle(
                              color: slide.accentColor.withOpacity(0.8),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        )
                      : const SizedBox(height: 44),
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    return _SlidePage(
                      slide: _slides[index],
                      bounceAnimation: _bounceAnimation,
                    );
                  },
                ),
              ),

              // Dots + buttons
              _buildBottomSection(slide),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection(_SlideData slide) {
    final isLast = _currentPage == _slides.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? slide.accentColor
                      : slide.accentColor.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),

          // CTA button — Duolingo 3D style
          GestureDetector(
            onTap: _next,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: slide.accentColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: slide.cardColor,
                    offset: const Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                isLast ? 'BẮT ĐẦU THÔI!' : 'TIẾP TỤC',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: slide.bgColor,
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

class _SlidePage extends StatelessWidget {
  final _SlideData slide;
  final Animation<double> bounceAnimation;

  const _SlidePage({required this.slide, required this.bounceAnimation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big emoji with bounce
          AnimatedBuilder(
            animation: bounceAnimation,
            builder: (ctx, child) => Transform.translate(
              offset: Offset(0, bounceAnimation.value),
              child: child,
            ),
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: slide.cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: slide.cardColor.withOpacity(0.6),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  slide.emoji,
                  style: const TextStyle(fontSize: 72),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: slide.accentColor,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: slide.accentColor.withOpacity(0.85),
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  final String emoji;
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color cardColor;
  final Color accentColor;

  const _SlideData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.cardColor,
    required this.accentColor,
  });
}
