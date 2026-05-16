import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_colors.dart';
import 'constants/app_theme.dart';
import 'firebase_options.dart';
import 'providers/ai_usage_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/notification_service.dart';

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
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) => MaterialApp(
          title: 'JavaUp',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: themeProvider.mode,
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon/app_icon_new.png', width: 96, height: 96),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      // Dùng cache ngay lập tức để không bị treo khi không có mạng
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _SplashScreen();
        }

        final user = snapshot.data;
        if (user != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<UserProvider>().refreshStats();
            context.read<AiUsageProvider>().load();
            context.read<SubscriptionProvider>().load();
            // Re-sync FCM token now that the user is confirmed authenticated
            NotificationService().syncToken();
          });
          return const _OnboardingGate();
        }
        // Auth state → null: reset provider as safety net, then show LoginScreen.
        // Logout handlers call reset() explicitly before signOut, but this
        // catches any edge case (token expiry, remote sign-out, etc.).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<UserProvider>().reset();
          context.read<AiUsageProvider>().reset();
          context.read<SubscriptionProvider>().clear();
        });
        return const LoginScreen();
      },
    );
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
    final done = prefs.getBool(onboardingDoneKey(uid)) ?? false;
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
