import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/workout_record.dart';
import '../utils/workout_deletion.dart';

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
    final publicWorkout = _firestore
        .collection('publicWorkoutActivities')
        .doc(user.uid)
        .collection('days')
        .doc(dateKey)
        .collection('workouts')
        .doc(document.id);
    final batch = _firestore.batch();
    batch.set(document, workout.toFirestore());
    batch.set(publicWorkout, {
      'uid': user.uid,
      'workoutId': document.id,
      'dateKey': dateKey,
      'type': workout.type,
      'startedAt': Timestamp.fromDate(workout.startedAt),
      'endedAt': Timestamp.fromDate(workout.endedAt),
      'durationSeconds': workout.durationSeconds,
      'photoUrl': workout.photoUrl,
      'photoCreatedAt': workout.photoCreatedAt == null
          ? null
          : Timestamp.fromDate(workout.photoCreatedAt!),
      'photoExpiresAt': workout.photoExpiresAt == null
          ? null
          : Timestamp.fromDate(workout.photoExpiresAt!),
      'strengthSummary': workout.strength?.toFirestore(),
      'runningSummary': workout.running == null
          ? null
          : {
              'distanceMeters': workout.running!.distanceMeters,
              'averagePaceSecondsPerKm':
                  workout.running!.averagePaceSecondsPerKm,
            },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
        final workoutEndedAt = workoutData['endedAt'];
        DocumentReference<Map<String, dynamic>>? publicWorkoutRef;
        DocumentSnapshot<Map<String, dynamic>>? publicWorkoutDocument;
        if (workoutEndedAt is Timestamp) {
          final seoulEndedAt = workoutEndedAt.toDate().toUtc().add(
            const Duration(hours: 9),
          );
          final dateKey =
              '${seoulEndedAt.year.toString().padLeft(4, '0')}-'
              '${seoulEndedAt.month.toString().padLeft(2, '0')}-'
              '${seoulEndedAt.day.toString().padLeft(2, '0')}';
          publicWorkoutRef = _firestore
              .collection('publicWorkoutActivities')
              .doc(user.uid)
              .collection('days')
              .doc(dateKey)
              .collection('workouts')
              .doc(workoutId);
          publicWorkoutDocument = await transaction.get(publicWorkoutRef);
        }
        transaction.update(workoutRef, {
          'photoUrl': photoUrl,
          'photoCreatedAt': Timestamp.fromDate(photoCreatedAt),
          'photoExpiresAt': Timestamp.fromDate(photoExpiresAt),
        });

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
        if (publicWorkoutDocument?.exists == true && publicWorkoutRef != null) {
          transaction.update(publicWorkoutRef, {
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

  Future<void> deleteCompletedWorkout(WorkoutRecord workout) async {
    final user = _firebaseAuth.currentUser;
    final workoutId = workout.id;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: '현재 로그인한 사용자가 없습니다.',
      );
    }
    if (workoutId == null || workout.userId != user.uid) {
      throw StateError('삭제할 수 없는 운동 기록입니다.');
    }

    final workouts = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('workouts');
    final latestSnapshot = await workouts
        .orderBy('endedAt', descending: true)
        .limit(2)
        .get();
    WorkoutRecord? latestRemainingWorkout;
    for (final document in latestSnapshot.docs) {
      if (document.id == workoutId ||
          document.data()['status'] != 'completed') {
        continue;
      }
      latestRemainingWorkout = WorkoutRecord.fromFirestore(
        document.id,
        document.data(),
      );
      if (latestRemainingWorkout != null) break;
    }

    final workoutRef = workouts.doc(workoutId);
    final dateKey = _seoulDateKey(workout.endedAt);
    final statsRef = _firestore
        .collection('publicWorkoutStats')
        .doc(user.uid)
        .collection('days')
        .doc(dateKey);
    final publicWorkoutRef = _firestore
        .collection('publicWorkoutActivities')
        .doc(user.uid)
        .collection('days')
        .doc(dateKey)
        .collection('workouts')
        .doc(workoutId);
    final activityRef = _firestore.collection('publicActivity').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final workoutDocument = await transaction.get(workoutRef);
      if (!workoutDocument.exists) {
        throw StateError('이미 삭제되었거나 존재하지 않는 운동 기록입니다.');
      }
      final storedWorkout = WorkoutRecord.fromFirestore(
        workoutDocument.id,
        workoutDocument.data()!,
      );
      if (storedWorkout == null ||
          storedWorkout.userId != user.uid ||
          workoutDocument.data()!['status'] != 'completed') {
        throw StateError('삭제할 수 없는 운동 기록입니다.');
      }

      final storedDateKey = _seoulDateKey(storedWorkout.endedAt);
      if (storedDateKey != dateKey) {
        throw StateError('운동 기록 날짜가 일치하지 않습니다.');
      }

      final statsDocument = await transaction.get(statsRef);
      final activityDocument = await transaction.get(activityRef);

      transaction.delete(workoutRef);
      transaction.delete(publicWorkoutRef);

      if (statsDocument.exists) {
        final data = statsDocument.data()!;
        final after = WorkoutStatsAfterDeletion.calculate(
          workoutCount: (data['workoutCount'] as num?)?.toInt() ?? 0,
          durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
          strengthVolumeKg: (data['strengthVolumeKg'] as num?)?.toDouble() ?? 0,
          runningDistanceMeters:
              (data['runningDistanceMeters'] as num?)?.toDouble() ?? 0,
          removedDurationSeconds: storedWorkout.durationSeconds,
          removedStrengthVolumeKg: storedWorkout.strength?.totalVolumeKg ?? 0,
          removedRunningDistanceMeters:
              storedWorkout.running?.distanceMeters ?? 0,
        );
        if (after.isEmpty) {
          transaction.delete(statsRef);
        } else {
          transaction.update(statsRef, {
            'workoutCount': after.workoutCount,
            'durationSeconds': after.durationSeconds,
            'strengthVolumeKg': after.strengthVolumeKg,
            'runningDistanceMeters': after.runningDistanceMeters,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      final activityData = activityDocument.data();
      final activityEndedAt = activityData?['endedAt'];
      final isDeletedLatest =
          activityData?['status'] != 'workingOut' &&
          activityEndedAt is Timestamp &&
          activityEndedAt.millisecondsSinceEpoch ==
              Timestamp.fromDate(storedWorkout.endedAt).millisecondsSinceEpoch;
      if (activityDocument.exists && isDeletedLatest) {
        if (latestRemainingWorkout == null) {
          transaction.update(activityRef, {
            'status': 'idle',
            'endedAt': null,
            'durationSeconds': null,
            'photoUrl': null,
            'photoCreatedAt': null,
            'photoExpiresAt': null,
            'lastWorkoutAt': null,
            'strengthSummary': null,
            'runningSummary': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(
            activityRef,
            _publicActivityForWorkout(user.uid, latestRemainingWorkout),
          );
        }
      }
    });
  }

  static String _seoulDateKey(DateTime value) {
    final seoul = value.toUtc().add(const Duration(hours: 9));
    return '${seoul.year.toString().padLeft(4, '0')}-'
        '${seoul.month.toString().padLeft(2, '0')}-'
        '${seoul.day.toString().padLeft(2, '0')}';
  }

  static Map<String, dynamic> _publicActivityForWorkout(
    String uid,
    WorkoutRecord workout,
  ) {
    return {
      'uid': uid,
      'status': 'completed',
      'workoutType': workout.type,
      'startedAt': Timestamp.fromDate(workout.startedAt),
      'endedAt': Timestamp.fromDate(workout.endedAt),
      'durationSeconds': workout.durationSeconds,
      'photoUrl': workout.validPhotoUrl,
      'photoCreatedAt': workout.photoCreatedAt == null
          ? null
          : Timestamp.fromDate(workout.photoCreatedAt!),
      'photoExpiresAt': workout.photoExpiresAt == null
          ? null
          : Timestamp.fromDate(workout.photoExpiresAt!),
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
    };
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
