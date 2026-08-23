import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.wakeUp = true,
    this.friendRequest = true,
    this.friendAccepted = true,
  });

  final bool wakeUp;
  final bool friendRequest;
  final bool friendAccepted;

  factory NotificationPreferences.fromMap(Object? value) {
    final data = value is Map<String, dynamic> ? value : null;
    return NotificationPreferences(
      wakeUp: data?['wakeUp'] != false,
      friendRequest: data?['friendRequest'] != false,
      friendAccepted: data?['friendAccepted'] != false,
    );
  }

  NotificationPreferences copyWith({
    bool? wakeUp,
    bool? friendRequest,
    bool? friendAccepted,
  }) {
    return NotificationPreferences(
      wakeUp: wakeUp ?? this.wakeUp,
      friendRequest: friendRequest ?? this.friendRequest,
      friendAccepted: friendAccepted ?? this.friendAccepted,
    );
  }

  Map<String, bool> toFirestore() => {
    'wakeUp': wakeUp,
    'friendRequest': friendRequest,
    'friendAccepted': friendAccepted,
  };
}

class NotificationPreferencesService {
  NotificationPreferencesService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  Future<NotificationPreferences> load() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return const NotificationPreferences();
    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    return NotificationPreferences.fromMap(
      snapshot.data()?['notificationPreferences'],
    );
  }

  Future<void> save(NotificationPreferences preferences) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: '현재 로그인한 사용자가 없습니다.',
      );
    }
    await _firestore.collection('users').doc(user.uid).update({
      'notificationPreferences': preferences.toFirestore(),
    });
  }
}
