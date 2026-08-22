import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../navigation/app_navigation_controller.dart';
import 'fcm_token_service.dart';

const socialNotificationChannelId = 'sharefit_social_notifications';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FcmTokenService _tokenService = FcmTokenService();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const androidChannel = AndroidNotificationChannel(
      socialNotificationChannelId,
      '친구 알림',
      description: '깨우기와 친구 요청 및 수락 알림',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          AppNavigationController.instance.handleNotificationData(data);
        } catch (error) {
          debugPrint('[FCM][LocalTap] $error');
        }
      },
    );

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _openMessage(initialMessage);
    await _tokenService.initialize();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          socialNotificationChannelId,
          '친구 알림',
          channelDescription: '깨우기와 친구 요청 및 수락 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _openMessage(RemoteMessage message) {
    AppNavigationController.instance.handleNotificationData(message.data);
  }
}
