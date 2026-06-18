import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_theme.dart';
import 'firebase_options.dart';
import 'providers/ai_usage_provider.dart';
import 'providers/network_retry_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'widgets/no_internet_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('[FCM] init failed: $e');
  }
  runApp(const MyApp());
}

// Key helpers — gắn với UID để mỗi tài khoản có trạng thái onboarding riêng
String onboardingDoneKey(String uid) => 'onboarding_done_$uid';
String userLevelKey(String uid) => 'user_level_$uid';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AiUsageProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => NetworkRetryProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) => MaterialApp(
          title: 'JavaUp',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: themeProvider.mode,
          home: Builder(
            builder: (context) => NoInternetBanner(
              onReconnected: () {
                context.read<UserProvider>().refreshStats();
                context.read<AiUsageProvider>().load();
                context.read<SubscriptionProvider>().load();
                context.read<NetworkRetryProvider>().retry();
              },
              child: const AuthWrapper(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnim;
  late Animation<double> _shadowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0, end: -40).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _shadowAnim = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon/app_icon_new.png', width: 96, height: 96),
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: Offset(0, _bounceAnim.value),
                    child: const Text('⚽', style: TextStyle(fontSize: 40)),
                  ),
                  const SizedBox(height: 8),
                  Transform.scale(
                    scaleX: _shadowAnim.value,
                    child: Container(
                      width: 32,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Dùng currentUser ngay lập tức — không chờ stream, không bị treo offline
  User? _user = FirebaseAuth.instance.currentUser;
  bool _prevHadUser = FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() => _user = user);
      if (user != null && !_prevHadUser) {
        _prevHadUser = true;
        context.read<UserProvider>().refreshStats();
        context.read<AiUsageProvider>().load();
        context.read<SubscriptionProvider>().load();
        NotificationService().syncToken();
      } else if (user == null) {
        _prevHadUser = false;
        context.read<UserProvider>().reset();
        context.read<AiUsageProvider>().reset();
        context.read<SubscriptionProvider>().clear();
      }
    });

    if (_user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<UserProvider>().refreshStats();
        context.read<AiUsageProvider>().load();
        context.read<SubscriptionProvider>().load();
        NotificationService().syncToken();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user != null) return const _OnboardingGate();
    return const LoginScreen();
  }
}

/// Kiểm tra xem user đã qua onboarding chưa
class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate();

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _onboardingDone = false);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    var done = prefs.getBool(onboardingDoneKey(uid)) ?? false;

    // Nếu chưa có flag local (cài lại app / thiết bị mới), hỏi backend
    if (!done) {
      try {
        final stats = await ApiService().getUserStats();
        final levelSet = stats['levelSet'] as bool? ?? false;
        if (levelSet) {
          await prefs.setBool(onboardingDoneKey(uid), true);
          done = true;
        }
      } catch (_) {
        // Network error → giữ nguyên done = false, hiển thị onboarding
      }
    }

    if (mounted) setState(() => _onboardingDone = done);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null) {
      return const _SplashScreen();
    }
    if (_onboardingDone!) {
      return const MainNavigationScreen();
    }
    return OnboardingScreen(onComplete: () {
      if (mounted) setState(() => _onboardingDone = true);
    });
  }
}
