import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/workout_record.dart';

class WorkoutService {
  WorkoutService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  Future<String> saveCompletedWorkout(WorkoutRecord workout) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: '현재 로그인한 사용자가 없습니다.',
      );
    }

    final document = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('workouts')
        .add(workout.toFirestore());
    return document.id;
  }

  Stream<List<WorkoutRecord>> watchCompletedWorkouts() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return Stream.value(const []);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('workouts')
        .orderBy('endedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((document) => document.data()['status'] == 'completed')
              .map(
                (document) =>
                    WorkoutRecord.fromFirestore(document.id, document.data()),
              )
              .whereType<WorkoutRecord>()
              .toList(),
        );
  }
}
