import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/navigation/app_navigation_controller.dart';

void main() {
  test('friend request opens friends tab and request section', () {
    final controller = AppNavigationController.instance;
    controller.handleNotificationData({'type': 'friend_request'});
    expect(controller.takeRequestedMainTab(), 2);
    expect(controller.takeFriendRequestsRequest(), true);
  });

  test('wake-up opens home tab', () {
    final controller = AppNavigationController.instance;
    controller.handleNotificationData({'type': 'wake_up'});
    expect(controller.takeRequestedMainTab(), 0);
    expect(controller.takeFriendRequestsRequest(), false);
  });
}
