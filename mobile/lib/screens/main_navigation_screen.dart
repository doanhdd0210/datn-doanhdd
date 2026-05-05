import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../providers/user_provider.dart';
import '../services/notification_service.dart';
import '../widgets/app_snackbar.dart';
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

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  StreamSubscription<RemoteMessage>? _fgSub;
  StreamSubscription<String>? _navSub;
  StreamSubscription<Map<String, dynamic>>? _dataSub;

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

  static const _screenIndex = {
    'lessons': 0,
    'practice': 1,
    'qa': 2,
    'friends': 3,
    'profile': 4,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final ns = NotificationService();

    _fgSub = ns.foregroundMessages.stream.listen((msg) {
      if (!mounted) return;
      final title = msg.notification?.title ?? 'Thông báo';
      final body = msg.notification?.body ?? '';
      final displayMsg = body.isNotEmpty ? '$title\n$body' : title;
      final screen = msg.data['screen'] as String?;
      AppSnackBar.info(
        context,
        displayMsg,
        actionLabel: screen != null && _screenIndex.containsKey(screen) ? 'Xem' : null,
        onAction: screen != null && _screenIndex.containsKey(screen)
            ? () => setState(() => _currentIndex = _screenIndex[screen]!)
            : null,
      );
    });

    _navSub = ns.navigationRequests.stream.listen((screen) {
      if (!mounted) return;
      final idx = _screenIndex[screen];
      if (idx != null) setState(() => _currentIndex = idx);
    });

    _dataSub = ns.dataMessages.stream.listen((data) {
      if (!mounted) return;
      _handleDataRefresh(data);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Refresh stats + poll achievements when user returns to app from background
      final provider = context.read<UserProvider>();
      provider.loadStats();
      provider.pollNewAchievements();
    }
  }

  void _handleDataRefresh(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final screen = data['screen'] as String?;
    final provider = context.read<UserProvider>();

    if (type == 'daily_goal') {
      final bonusXp = int.tryParse(data['bonusXp']?.toString() ?? '') ?? 0;
      provider.handleDailyGoalBonusReceived(bonusXp);
      return;
    }

    if (type == 'achievement' || screen == 'profile') {
      provider.pollNewAchievements();
      provider.loadStats();
    }

    if (screen == 'qa' || type == 'follow' || screen == 'friends') {
      provider.loadStats();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fgSub?.cancel();
    _navSub?.cancel();
    _dataSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: qaUnreadNotifier,
        builder: (context, unreadCount, _) => _QuizzoBottomNav(
          currentIndex: _currentIndex,
          items: _navItems,
          badgeCounts: {2: unreadCount},
          onTap: (index) => setState(() => _currentIndex = index),
        ),
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
  final Map<int, int> badgeCounts;

  const _QuizzoBottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.badgeCounts = const {},
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final navBg = context.navBgColor;
    final navBorder = context.navBorderColor;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: navBg,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: navBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: List.generate(items.length, (i) {
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: _NavTabItem(
                    icon: items[i].icon,
                    label: items[i].label,
                    isActive: isActive,
                    badgeCount: badgeCounts[i] ?? 0,
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
  final int badgeCount;

  const _NavTabItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: isActive ? 52 : 40,
              height: isActive ? 36 : 32,
              decoration: isActive
                  ? BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    )
                  : null,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    icon,
                    key: ValueKey(isActive),
                    size: 22,
                    color: isActive ? Colors.white : AppColors.navInactive,
                  ),
                ),
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: isActive ? 10 : 9,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            color: isActive ? AppColors.primary : AppColors.navInactive,
          ),
          child: Text(label),
        ),
      ],
    );
  }
}
