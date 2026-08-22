import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await ThemeController.instance.load();

  runApp(const ShareFitApp());
  unawaited(
    PushNotificationService.instance.initialize().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint('[FCM][Initialize] $error\n$stackTrace');
    }),
  );
}
