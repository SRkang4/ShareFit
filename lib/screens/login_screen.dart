import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../services/auth_service.dart';
import '../services/google_auth_client.dart';
import '../widgets/google_sign_in_button.dart';
import 'email_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isGoogleLoading = false;

  Future<void> _signInWithGoogle() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);
    try {
      final outcome = await _authService.signInWithGoogle();
      if (outcome == GoogleSignInOutcome.canceled) return;
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_firebaseErrorMessage(error.code));
    } on GoogleAuthConfigurationException {
      if (mounted) {
        _showError('Google 로그인 설정을 확인해주세요.');
      }
    } catch (error, stackTrace) {
      debugPrint('[GoogleSignIn] $error\n$stackTrace');
      if (mounted) {
        _showError('Google 로그인 중 오류가 발생했습니다. 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return '같은 이메일로 가입된 계정이 있어요. 기존 로그인 방식을 이용해주세요.';
      case 'operation-not-allowed':
        return '현재 Google 로그인을 사용할 수 없습니다.';
      case 'user-disabled':
        return '사용이 중지된 계정입니다.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해주세요.';
      case 'invalid-credential':
        return 'Google 로그인 정보가 올바르지 않습니다. 다시 시도해주세요.';
      default:
        return 'Google 로그인 중 오류가 발생했습니다. 다시 시도해주세요.';
    }
  }

  void _showError(String message) {
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      displayDuration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pointColor = colors.primary;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              Text(
                'ShareFit',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                  letterSpacing: -1.2,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                '친구와 운동을 공유하고\n함께 꾸준해지는 공간',
                style: TextStyle(
                  fontSize: 20,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                '운동 중인 친구를 확인하고, 완료 기록으로 서로 자극받아보세요.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                  letterSpacing: -0.2,
                ),
              ),

              const Spacer(),

              GoogleSignInButton(
                isLoading: _isGoogleLoading,
                onPressed: _signInWithGoogle,
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmailLoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pointColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text(
                    '이메일로 로그인',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
