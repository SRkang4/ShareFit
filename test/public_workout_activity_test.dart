import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/models/public_activity.dart';
import 'package:sharefit/models/public_workout_activity.dart';
import 'package:sharefit/services/public_workout_activity_service.dart';

void main() {
  test('creates a legacy fallback with a Seoul date key', () {
    final activity = PublicActivity(
      uid: 'friend',
      status: 'completed',
      workoutType: 'running',
      startedAt: DateTime.utc(2026, 8, 21, 14),
      endedAt: DateTime.utc(2026, 8, 21, 15, 30),
      durationSeconds: 5400,
      runningSummary: const PublicRunningSummary(
        distanceMeters: 10000,
        averagePaceSecondsPerKm: 540,
      ),
    );

    final workout = PublicWorkoutActivity.fromLegacy(activity);

    expect(workout.dateKey, '2026-08-22');
    expect(
      workout.workoutId,
      'legacy-${activity.endedAt!.millisecondsSinceEpoch}',
    );
    expect(workout.runningSummary?.distanceMeters, 10000);
  });

  test('restores a valid public workout photo and summary', () {
    final workout = PublicWorkoutActivity.fromFirestore('workout-1', {
      'uid': 'friend',
      'workoutId': 'workout-1',
      'dateKey': '2026-08-22',
      'type': 'strength',
      'startedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 22)),
      'endedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 22, 1)),
      'durationSeconds': 3600,
      'photoUrl': 'https://example.com/photo.jpg',
      'photoExpiresAt': Timestamp.fromDate(DateTime.utc(2100)),
      'strengthSummary': {
        'bodyParts': ['가슴'],
        'completedSetCount': 3,
        'totalVolumeKg': 2400,
        'exercises': [
          {
            'name': '벤치프레스',
            'sets': [
              {'weightKg': 80, 'reps': 10},
              {'weightKg': 80, 'reps': 8},
            ],
          },
        ],
      },
    });

    expect(workout.validPhotoUrl, 'https://example.com/photo.jpg');
    expect(workout.strengthSummary?.completedSetCount, 3);
    expect(workout.strengthSummary?.totalVolumeKg, 2400);
    expect(workout.strengthSummary?.exercises.single.name, '벤치프레스');
    expect(workout.strengthSummary?.exercises.single.sets, hasLength(2));
    expect(workout.strengthSummary?.exercises.single.sets.last.reps, 8);
  });

  test(
    'keeps legacy public strength summaries without exercises compatible',
    () {
      final summary = PublicStrengthSummary.fromMap({
        'bodyParts': ['등'],
        'completedSetCount': 2,
        'totalVolumeKg': 1200,
      });

      expect(summary.exercises, isEmpty);
    },
  );

  test('Seoul date key changes at 15:00 UTC', () {
    expect(
      PublicWorkoutActivityService.seoulDateKey(
        DateTime.utc(2026, 8, 21, 14, 59),
      ),
      '2026-08-21',
    );
    expect(
      PublicWorkoutActivityService.seoulDateKey(DateTime.utc(2026, 8, 21, 15)),
      '2026-08-22',
    );
  });
}
