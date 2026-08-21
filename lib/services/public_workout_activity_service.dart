import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/public_workout_activity.dart';

class PublicWorkoutActivityService {
  PublicWorkoutActivityService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<PublicWorkoutActivity>> watchToday(String uid) {
    final dateKey = seoulDateKey(DateTime.now());
    return _firestore
        .collection('publicWorkoutActivities')
        .doc(uid)
        .collection('days')
        .doc(dateKey)
        .collection('workouts')
        .orderBy('endedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final byWorkoutId = <String, PublicWorkoutActivity>{};
          for (final document in snapshot.docs) {
            final workout = PublicWorkoutActivity.fromFirestore(
              document.id,
              document.data(),
            );
            if (workout.uid == uid && workout.dateKey == dateKey) {
              byWorkoutId[workout.workoutId] = workout;
            }
          }
          final workouts = byWorkoutId.values.toList()
            ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
          return workouts;
        });
  }

  static String seoulDateKey(DateTime value) {
    final seoul = value.toUtc().add(const Duration(hours: 9));
    return '${seoul.year.toString().padLeft(4, '0')}-'
        '${seoul.month.toString().padLeft(2, '0')}-'
        '${seoul.day.toString().padLeft(2, '0')}';
  }
}
