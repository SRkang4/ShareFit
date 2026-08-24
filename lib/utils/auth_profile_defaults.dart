class AuthProfileDefaults {
  const AuthProfileDefaults._();

  static String email({String? firebaseEmail, String? providerEmail}) {
    final firebaseValue = firebaseEmail?.trim() ?? '';
    if (firebaseValue.isNotEmpty) return firebaseValue;
    return providerEmail?.trim() ?? '';
  }

  static String name({String? displayName, required String email}) {
    final displayValue = displayName?.trim() ?? '';
    if (displayValue.isNotEmpty) return displayValue;

    final localPart = email.split('@').first.trim();
    if (localPart.isNotEmpty) return localPart;
    return 'ShareFit 사용자';
  }
}
