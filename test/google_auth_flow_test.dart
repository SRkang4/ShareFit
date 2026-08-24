import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/services/google_auth_client.dart';

void main() {
  test('passes a Google identity to Firebase authentication', () async {
    final identity = GoogleAuthIdentity(
      idToken: 'id-token',
      email: 'google@example.com',
      displayName: 'Google User',
    );
    final client = _FakeGoogleAuthClient(identity: identity);
    GoogleAuthIdentity? received;

    final outcome = await GoogleAuthFlow(client).run((value) async {
      received = value;
    });

    expect(outcome, GoogleSignInOutcome.signedIn);
    expect(received, same(identity));
  });

  test('returns canceled without invoking Firebase authentication', () async {
    final client = _FakeGoogleAuthClient(canceled: true);
    var invoked = false;

    final outcome = await GoogleAuthFlow(client).run((_) async {
      invoked = true;
    });

    expect(outcome, GoogleSignInOutcome.canceled);
    expect(invoked, isFalse);
  });
}

class _FakeGoogleAuthClient implements GoogleAuthClient {
  _FakeGoogleAuthClient({this.identity, this.canceled = false});

  final GoogleAuthIdentity? identity;
  final bool canceled;

  @override
  Future<GoogleAuthIdentity> authenticate() async {
    if (canceled) throw const GoogleAuthCanceledException();
    return identity!;
  }

  @override
  Future<void> signOut() async {}
}
