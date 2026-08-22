import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/services/fcm_token_service.dart';

void main() {
  test('FCM token document id is stable and does not expose the token', () {
    const token = 'sample:fcm/token';
    final first = fcmTokenDocumentId(token);
    expect(first, fcmTokenDocumentId(token));
    expect(first.length, 64);
    expect(first, isNot(contains(token)));
  });
}
