import 'screens/login_screen.dart';
import 'package:flutter/material.dart';

class ShareFitApp extends StatelessWidget {
  const ShareFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShareFit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Pretendard',

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B5FFF),
          brightness: Brightness.light,
        ),

        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w800,
          ),
          bodyLarge: TextStyle(
            color: Color(0xFF111111),
          ),
          bodyMedium: TextStyle(
            color: Color(0xFF555555),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}