import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/public_activity.dart';

class PublicActivityService {
  PublicActivityService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('로그인이 필요합니다.');
    return uid;
  }

  Future<void> markWorkoutStarted({
    required String workoutType,
    required DateTime startedAt,
  }) {
    final uid = _uid;
    return _firestore.collection('publicActivity').doc(uid).set({
      'uid': uid,
      'status': 'workingOut',
      'workoutType': workoutType,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': null,
      'durationSeconds': null,
      'photoUrl': null,
      'strengthSummary': null,
      'runningSummary': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<PublicActivity> watchActivity(String uid) {
    return _firestore
        .collection('publicActivity')
        .doc(uid)
        .snapshots()
        .map((document) => PublicActivity.fromFirestore(uid, document.data()));
  }
}
