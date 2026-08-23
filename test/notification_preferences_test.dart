import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/services/notification_preferences_service.dart';

void main() {
  test('missing notification preferences default to enabled', () {
    final preferences = NotificationPreferences.fromMap(null);

    expect(preferences.wakeUp, isTrue);
    expect(preferences.friendRequest, isTrue);
    expect(preferences.friendAccepted, isTrue);
  });

  test('only explicit false disables a notification', () {
    final preferences = NotificationPreferences.fromMap({
      'wakeUp': false,
      'friendRequest': true,
      'friendAccepted': false,
    });

    expect(preferences.wakeUp, isFalse);
    expect(preferences.friendRequest, isTrue);
    expect(preferences.friendAccepted, isFalse);
  });
}
