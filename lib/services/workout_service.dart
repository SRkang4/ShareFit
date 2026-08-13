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

    final document = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('workouts')
        .doc();
    final activity = _firestore.collection('publicActivity').doc(user.uid);
    final seoulEndedAt = workout.endedAt.toUtc().add(const Duration(hours: 9));
    final dateKey =
        '${seoulEndedAt.year.toString().padLeft(4, '0')}-'
        '${seoulEndedAt.month.toString().padLeft(2, '0')}-'
        '${seoulEndedAt.day.toString().padLeft(2, '0')}';
    final publicStats = _firestore
        .collection('publicWorkoutStats')
        .doc(user.uid)
        .collection('days')
        .doc(dateKey);
    final batch = _firestore.batch();
    batch.set(document, workout.toFirestore());
    batch.set(activity, {
      'uid': user.uid,
      'status': 'completed',
      'workoutType': workout.type,
      'startedAt': Timestamp.fromDate(workout.startedAt),
      'endedAt': Timestamp.fromDate(workout.endedAt),
      'durationSeconds': workout.durationSeconds,
      'photoUrl': null,
      'lastWorkoutAt': Timestamp.fromDate(workout.endedAt),
      'strengthSummary': workout.strength == null
          ? null
          : {
              'bodyParts': workout.strength!.bodyParts,
              'completedSetCount': workout.strength!.completedSetCount,
              'totalVolumeKg': workout.strength!.totalVolumeKg,
            },
      'runningSummary': workout.running == null
          ? null
          : {
              'distanceMeters': workout.running!.distanceMeters,
              'averagePaceSecondsPerKm':
                  workout.running!.averagePaceSecondsPerKm,
            },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(publicStats, {
      'uid': user.uid,
      'dateKey': dateKey,
      'workoutCount': FieldValue.increment(1),
      'durationSeconds': FieldValue.increment(workout.durationSeconds),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
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

  Stream<List<WorkoutRecord>> watchTodayWorkouts() {
    final seoulNow = DateTime.now().toUtc().add(const Duration(hours: 9));
    return watchWorkoutsForDate(seoulNow);
  }

  Stream<List<WorkoutRecord>> watchWorkoutsForDate(DateTime seoulDate) {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return Stream.value(const []);
    }

    final startUtc = DateTime.utc(
      seoulDate.year,
      seoulDate.month,
      seoulDate.day,
    ).subtract(const Duration(hours: 9));
    final endUtc = startUtc.add(const Duration(days: 1));

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('workouts')
        .where('endedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startUtc))
        .where('endedAt', isLessThan: Timestamp.fromDate(endUtc))
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
