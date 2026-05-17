import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'package:scorvoai/screens/main_shell.dart';
import 'package:scorvoai/screens/onboarding_screen.dart';
import 'package:scorvoai/services/firestore_service.dart';
import 'package:scorvoai/services/rag_service.dart';
import 'package:scorvoai/theme/app_theme.dart';
import 'package:scorvoai/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.load(); // Restores saved light/dark preference
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await RagService().initialize();
  } catch (_) {}
  runApp(const ProviderScope(child: ScorvoAIApp()));
}

class ScorvoAIApp extends StatelessWidget {
  const ScorvoAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        // Keep AppColors in sync with the effective mode for system mode users
        final isDark = mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        AppColors.setDark(isDark);
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: AppColors.bgElevated,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp(
          title: 'ScorvoAI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const _AuthGate(),
        );
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const OnboardingScreen();
        return FutureBuilder(
          future: FirestoreService.getProfile(user.uid),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final profile = profileSnap.data;
            if (profile == null || !profile.onboardingComplete) return const OnboardingScreen();
            return const MainShell();
          },
        );
      },
    );
  }
}
