import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

String fcmTokenDocumentId(String token) =>
    sha256.convert(utf8.encode(token)).toString();

class FcmTokenService {
  FcmTokenService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  String? _currentToken;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (token) async {
        _currentToken = token;
        try {
          await _register(token);
        } catch (error, stackTrace) {
          debugPrint('[FCM][TokenRefresh] $error\n$stackTrace');
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[FCM][TokenRefresh] $error\n$stackTrace');
      },
    );
    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user == null) return;
      await registerCurrentToken();
    });
    await registerCurrentToken();
  }

  Future<void> registerCurrentToken() async {
    if (_auth.currentUser == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      _currentToken = token;
      await _register(token);
    } catch (error, stackTrace) {
      debugPrint('[FCM][Register] $error\n$stackTrace');
    }
  }

  Future<void> unregisterCurrentToken() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final token = _currentToken ?? await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(fcmTokenDocumentId(token))
          .delete();
    } catch (error, stackTrace) {
      debugPrint('[FCM][Unregister] $error\n$stackTrace');
    }
  }

  Future<void> _register(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final reference = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('fcmTokens')
        .doc(fcmTokenDocumentId(token));
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      transaction.set(reference, {
        'token': token,
        'platform': _platformName,
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }
}
