import 'package:flutter/foundation.dart';

enum SocialNotificationType {
  wakeUp('wake_up'),
  friendRequest('friend_request'),
  friendAccepted('friend_request_accepted');

  const SocialNotificationType(this.value);

  final String value;

  static SocialNotificationType? fromValue(String? value) {
    for (final type in values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

class AppNavigationController extends ChangeNotifier {
  AppNavigationController._();

  static final AppNavigationController instance = AppNavigationController._();

  int? _requestedMainTab;
  bool _friendRequestsRequested = false;

  int? takeRequestedMainTab() {
    final value = _requestedMainTab;
    _requestedMainTab = null;
    return value;
  }

  bool takeFriendRequestsRequest() {
    final value = _friendRequestsRequested;
    _friendRequestsRequested = false;
    return value;
  }

  void requestMainTab(int index) {
    _requestedMainTab = index;
    notifyListeners();
  }

  void handleNotificationData(Map<String, dynamic> data) {
    switch (SocialNotificationType.fromValue(data['type'] as String?)) {
      case SocialNotificationType.friendRequest:
        _requestedMainTab = 2;
        _friendRequestsRequested = true;
        break;
      case SocialNotificationType.friendAccepted:
        _requestedMainTab = 2;
        break;
      case SocialNotificationType.wakeUp:
        _requestedMainTab = 0;
        break;
      case null:
        return;
    }
    notifyListeners();
  }
}
