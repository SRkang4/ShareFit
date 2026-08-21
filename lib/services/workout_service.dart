import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
      'photoCreatedAt': null,
      'photoExpiresAt': null,
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
      'strengthVolumeKg': FieldValue.increment(
        workout.strength?.totalVolumeKg ?? 0,
      ),
      'runningDistanceMeters': FieldValue.increment(
        workout.running?.distanceMeters ?? 0,
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    return document.id;
  }

  Future<String?> updateWorkoutPhoto({
    required String workoutId,
    required String photoUrl,
    required DateTime photoCreatedAt,
    required DateTime photoExpiresAt,
  }) async {
    debugPrint('[WorkoutService][$workoutId] updateWorkoutPhoto 함수 진입');
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: '현재 로그인한 사용자가 없습니다.',
      );
    }

    final workoutRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('workouts')
        .doc(workoutId);
    final activityRef = _firestore.collection('publicActivity').doc(user.uid);

    try {
      debugPrint('[WorkoutService][$workoutId] Firestore transaction 시작');
      final previousPhotoUrl = await _firestore.runTransaction((
        transaction,
      ) async {
        debugPrint('[WorkoutService][$workoutId] workout 문서 조회 시작');
        final workoutDocument = await transaction.get(workoutRef);
        debugPrint(
          '[WorkoutService][$workoutId] workout 문서 조회 완료: '
          'exists=${workoutDocument.exists}',
        );
        if (!workoutDocument.exists) {
          throw StateError('운동 기록을 찾을 수 없습니다.');
        }
        final workoutData = workoutDocument.data()!;
        if (workoutData['userId'] != user.uid ||
            workoutData['status'] != 'completed') {
          throw StateError('수정할 수 없는 운동 기록입니다.');
        }

        debugPrint('[WorkoutService][$workoutId] publicActivity 문서 조회 시작');
        final activityDocument = await transaction.get(activityRef);
        debugPrint(
          '[WorkoutService][$workoutId] publicActivity 문서 조회 완료: '
          'exists=${activityDocument.exists}',
        );
        final previousPhotoUrl = workoutData['photoUrl'] is String
            ? workoutData['photoUrl'] as String
            : null;
        transaction.update(workoutRef, {
          'photoUrl': photoUrl,
          'photoCreatedAt': Timestamp.fromDate(photoCreatedAt),
          'photoExpiresAt': Timestamp.fromDate(photoExpiresAt),
        });

        final workoutEndedAt = workoutData['endedAt'];
        final activityEndedAt = activityDocument.data()?['endedAt'];
        if (activityDocument.exists &&
            workoutEndedAt is Timestamp &&
            activityEndedAt is Timestamp &&
            workoutEndedAt.millisecondsSinceEpoch ==
                activityEndedAt.millisecondsSinceEpoch) {
          transaction.update(activityRef, {
            'photoUrl': photoUrl,
            'photoCreatedAt': Timestamp.fromDate(photoCreatedAt),
            'photoExpiresAt': Timestamp.fromDate(photoExpiresAt),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        return previousPhotoUrl;
      });
      debugPrint('[WorkoutService][$workoutId] Firestore transaction 완료');
      return previousPhotoUrl;
    } catch (e, stackTrace) {
      if (e is FirebaseException) {
        debugPrint(
          '[WorkoutService][$workoutId] FirebaseException: '
          'plugin=${e.plugin}, code=${e.code}, message=${e.message}',
        );
      }
      debugPrint('[WorkoutService][$workoutId] updateWorkoutPhoto 실패: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
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

  Future<List<WorkoutRecord>> getTodayWorkouts() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return const [];
    }

    final seoulNow = DateTime.now().toUtc().add(const Duration(hours: 9));
    final startUtc = DateTime.utc(
      seoulNow.year,
      seoulNow.month,
      seoulNow.day,
    ).subtract(const Duration(hours: 9));
    final endUtc = startUtc.add(const Duration(days: 1));
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('workouts')
        .where('endedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startUtc))
        .where('endedAt', isLessThan: Timestamp.fromDate(endUtc))
        .orderBy('endedAt', descending: true)
        .get();

    return snapshot.docs
        .where((document) => document.data()['status'] == 'completed')
        .map(
          (document) =>
              WorkoutRecord.fromFirestore(document.id, document.data()),
        )
        .whereType<WorkoutRecord>()
        .toList();
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
