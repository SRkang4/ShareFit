import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'navigation/app_navigation_controller.dart';
import 'widgets/active_workout_timer_pill.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

class ShareFitApp extends StatelessWidget {
  const ShareFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, child) => MaterialApp(
        navigatorKey: _rootNavigatorKey,
        title: 'ShareFit',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(ThemeController.instance.accent),
        darkTheme: AppTheme.dark(ThemeController.instance.accent),
        themeMode: ThemeController.instance.mode,
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            ?child,
            ActiveWorkoutTimerPill(
              onTap: () {
                AppNavigationController.instance.requestMainTab(1);
                _rootNavigatorKey.currentState?.popUntil(
                  (route) => route.isFirst,
                );
              },
            ),
          ],
        ),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return snapshot.hasData ? const MainScreen() : const LoginScreen();
          },
        ),
      ),
    );
  }
}
