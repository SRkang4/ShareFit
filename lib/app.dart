import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class ShareFitApp extends StatelessWidget {
  const ShareFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, child) => MaterialApp(
        title: 'ShareFit',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(ThemeController.instance.accent),
        darkTheme: AppTheme.dark(ThemeController.instance.accent),
        themeMode: ThemeController.instance.mode,
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
