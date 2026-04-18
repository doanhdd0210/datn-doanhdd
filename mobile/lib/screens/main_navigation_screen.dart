import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'home/topics_screen.dart';
import 'practice/code_demo_list_screen.dart';
import 'social/qa_screen.dart';
import 'social/friends_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TopicsScreen(),
    CodeDemoListScreen(),
    QaScreen(),
    FriendsScreen(),
    ProfileScreen(),
  ];

  static const _navItems = [
    _NavItem(icon: Icons.auto_stories_rounded, label: 'Học'),
    _NavItem(icon: Icons.code_rounded, label: 'Thực hành'),
    _NavItem(icon: Icons.forum_rounded, label: 'Cộng đồng'),
    _NavItem(icon: Icons.emoji_events_rounded, label: 'Xếp hạng'),
    _NavItem(icon: Icons.person_rounded, label: 'Hồ sơ'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _QuizzoBottomNav(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _QuizzoBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _QuizzoBottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navBackground,
        border: Border(
          top: BorderSide(color: AppColors.navBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: _NavTabItem(
                    icon: item.icon,
                    label: item.label,
                    isActive: isActive,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _NavTabItem({
    required this.icon,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: isActive
              ? BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                )
              : null,
          child: Icon(
            icon,
            size: 24,
            color: isActive ? AppColors.navActive : AppColors.navInactive,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            color: isActive ? AppColors.navActive : AppColors.navInactive,
          ),
          child: Text(label),
        ),
      ],
    );
  }
}
