import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/utils/auth_profile_defaults.dart';

void main() {
  test('uses a trimmed Google display name when available', () {
    expect(
      AuthProfileDefaults.name(
        displayName: '  Kang Hyeon  ',
        email: 'kang@example.com',
      ),
      'Kang Hyeon',
    );
  });

  test('falls back to the email local part without a display name', () {
    expect(
      AuthProfileDefaults.name(email: 'sharefit.user@example.com'),
      'sharefit.user',
    );
  });

  test('uses a safe fallback when both name and email are empty', () {
    expect(AuthProfileDefaults.name(email: ''), 'ShareFit 사용자');
  });

  test('prefers the Firebase email and falls back to the provider email', () {
    expect(
      AuthProfileDefaults.email(
        firebaseEmail: ' firebase@example.com ',
        providerEmail: 'provider@example.com',
      ),
      'firebase@example.com',
    );
    expect(
      AuthProfileDefaults.email(providerEmail: ' provider@example.com '),
      'provider@example.com',
    );
  });
}
