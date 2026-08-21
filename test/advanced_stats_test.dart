import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/models/workout_record.dart';
import 'package:sharefit/services/advanced_stats_service.dart';

void main() {
  group('AdvancedStatsService.calculate', () {
    test('calculates monthly totals, body-part volume, and weighted pace', () {
      final workouts = [
        _strengthWorkout(
          endedAt: DateTime.utc(2026, 7, 31, 16),
          volume: 1000,
          bodyParts: const ['가슴'],
        ),
        _strengthWorkout(
          endedAt: DateTime.utc(2026, 8, 2),
          volume: 600,
          bodyParts: const ['이두', '삼두'],
        ),
        _strengthWorkout(
          endedAt: DateTime.utc(2026, 8, 3),
          volume: 400,
          bodyParts: const ['가슴', '등'],
        ),
        _runningWorkout(
          endedAt: DateTime.utc(2026, 8, 4),
          distanceMeters: 1000,
          durationSeconds: 360,
        ),
        _runningWorkout(
          endedAt: DateTime.utc(2026, 8, 5),
          distanceMeters: 3000,
          durationSeconds: 900,
        ),
      ];

      final stats = AdvancedStatsService.calculate(workouts, DateTime(2026, 8));

      expect(stats.selectedMonthStats.strengthVolumeKg, 2000);
      expect(stats.bodyPartVolumeKg['가슴'], 1000);
      expect(stats.bodyPartVolumeKg['팔'], 600);
      expect(stats.unassignedStrengthVolumeKg, 400);
      expect(stats.selectedMonthStats.runningDistanceMeters, 4000);
      expect(stats.selectedMonthStats.averagePaceSecondsPerKm, 315);
    });

    test('creates six ordered months and zero values for empty data', () {
      final stats = AdvancedStatsService.calculate(const [], DateTime(2026, 1));

      expect(stats.months.length, 6);
      expect(stats.months.first.month, DateTime(2025, 8));
      expect(stats.months.last.month, DateTime(2026, 1));
      expect(
        stats.months.every((month) => month.strengthVolumeKg == 0),
        isTrue,
      );
      expect(
        stats.months.every((month) => month.runningDistanceMeters == 0),
        isTrue,
      );
      expect(
        stats.months.every((month) => month.averagePaceSecondsPerKm == null),
        isTrue,
      );
    });

    test('ignores records outside the six-month calculation window', () {
      final stats = AdvancedStatsService.calculate([
        _strengthWorkout(
          endedAt: DateTime.utc(2026, 2, 28, 14, 59),
          volume: 500,
          bodyParts: const ['등'],
        ),
        _strengthWorkout(
          endedAt: DateTime.utc(2026, 2, 28, 15),
          volume: 700,
          bodyParts: const ['등'],
        ),
      ], DateTime(2026, 8));

      expect(stats.months.first.month, DateTime(2026, 3));
      expect(stats.months.first.strengthVolumeKg, 700);
    });
  });

  test('six-month query range uses Seoul month boundaries', () {
    final range = AdvancedStatsService.queryRangeForSixMonths(
      DateTime(2026, 8),
    );

    expect(range.startUtc, DateTime.utc(2026, 2, 28, 15));
    expect(range.endUtc, DateTime.utc(2026, 8, 31, 15));
  });
}

WorkoutRecord _strengthWorkout({
  required DateTime endedAt,
  required double volume,
  required List<String> bodyParts,
}) {
  return WorkoutRecord(
    userId: 'user',
    type: 'strength',
    startedAt: endedAt.subtract(const Duration(hours: 1)),
    endedAt: endedAt,
    durationSeconds: 3600,
    strength: StrengthWorkoutData(
      bodyParts: bodyParts,
      exercises: const [],
      completedSetCount: 1,
      totalVolumeKg: volume,
    ),
  );
}

WorkoutRecord _runningWorkout({
  required DateTime endedAt,
  required double distanceMeters,
  required int durationSeconds,
}) {
  return WorkoutRecord(
    userId: 'user',
    type: 'running',
    startedAt: endedAt.subtract(Duration(seconds: durationSeconds)),
    endedAt: endedAt,
    durationSeconds: durationSeconds,
    running: RunningWorkoutData(
      targetDistanceMeters: 0,
      distanceMeters: distanceMeters,
      acceptedLocationCount: 1,
      averagePaceSecondsPerKm: null,
    ),
  );
}
