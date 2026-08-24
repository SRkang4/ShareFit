import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services/auth_service.dart';
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
          initialData: FirebaseAuth.instance.currentUser,
          builder: (context, snapshot) {
            final user = snapshot.data;
            return user == null
                ? const LoginScreen()
                : _AuthenticatedHome(key: ValueKey(user.uid));
          },
        ),
      ),
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  const _AuthenticatedHome({super.key});

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  final AuthService _authService = AuthService();
  late Future<void> _profileReady = _authService.ensureCurrentUserProfile();

  void _retry() {
    setState(() {
      _profileReady = _authService.ensureCurrentUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _profileReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MainScreen();
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '사용자 정보를 준비하지 못했어요.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '네트워크 연결을 확인하고 다시 시도해주세요.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text('다시 시도'),
                      ),
                      TextButton(
                        onPressed: _authService.signOut,
                        child: const Text('로그아웃'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return const MainScreen();
      },
    );
  }
}
