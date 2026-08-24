import 'package:google_sign_in/google_sign_in.dart';

enum GoogleSignInOutcome { signedIn, canceled }

class GoogleAuthIdentity {
  const GoogleAuthIdentity({
    required this.idToken,
    required this.email,
    this.displayName,
  });

  final String idToken;
  final String email;
  final String? displayName;
}

abstract interface class GoogleAuthClient {
  Future<GoogleAuthIdentity> authenticate();

  Future<void> signOut();
}

class GoogleAuthCanceledException implements Exception {
  const GoogleAuthCanceledException();
}

class GoogleAuthConfigurationException implements Exception {
  const GoogleAuthConfigurationException([this.description]);

  final String? description;
}

class GoogleAuthTokenException implements Exception {
  const GoogleAuthTokenException();
}

class DefaultGoogleAuthClient implements GoogleAuthClient {
  DefaultGoogleAuthClient({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  static Future<void>? _initialization;

  Future<void> _ensureInitialized() async {
    final initialization = _initialization ??= _googleSignIn.initialize();
    try {
      await initialization;
    } catch (_) {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
      rethrow;
    }
  }

  @override
  Future<GoogleAuthIdentity> authenticate() async {
    await _ensureInitialized();
    if (!_googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError('현재 플랫폼에서는 Google 로그인을 지원하지 않습니다.');
    }

    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleAuthTokenException();
      }
      return GoogleAuthIdentity(
        idToken: idToken,
        email: account.email,
        displayName: account.displayName,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleAuthCanceledException();
      }
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw GoogleAuthConfigurationException(error.description);
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
  }
}

class GoogleAuthFlow {
  const GoogleAuthFlow(this.client);

  final GoogleAuthClient client;

  Future<GoogleSignInOutcome> run(
    Future<void> Function(GoogleAuthIdentity identity) authenticateWithFirebase,
  ) async {
    try {
      final identity = await client.authenticate();
      await authenticateWithFirebase(identity);
      return GoogleSignInOutcome.signedIn;
    } on GoogleAuthCanceledException {
      return GoogleSignInOutcome.canceled;
    }
  }
}
