import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/utils/workout_deletion.dart';

void main() {
  test('운동 삭제 시 공개 일별 합계를 정확히 차감한다', () {
    final result = WorkoutStatsAfterDeletion.calculate(
      workoutCount: 3,
      durationSeconds: 5400,
      strengthVolumeKg: 9200,
      runningDistanceMeters: 5100,
      removedDurationSeconds: 1800,
      removedStrengthVolumeKg: 1200,
      removedRunningDistanceMeters: 0,
    );

    expect(result.workoutCount, 2);
    expect(result.durationSeconds, 3600);
    expect(result.strengthVolumeKg, 8000);
    expect(result.runningDistanceMeters, 5100);
    expect(result.isEmpty, isFalse);
  });

  test('마지막 운동 삭제 시 합계를 0으로 만들고 빈 집계로 판단한다', () {
    final result = WorkoutStatsAfterDeletion.calculate(
      workoutCount: 1,
      durationSeconds: 900,
      strengthVolumeKg: 0,
      runningDistanceMeters: 2400,
      removedDurationSeconds: 900,
      removedStrengthVolumeKg: 0,
      removedRunningDistanceMeters: 2400,
    );

    expect(result.workoutCount, 0);
    expect(result.durationSeconds, 0);
    expect(result.runningDistanceMeters, 0);
    expect(result.isEmpty, isTrue);
  });

  test('오래된 비정상 집계도 삭제 시 음수가 되지 않는다', () {
    final result = WorkoutStatsAfterDeletion.calculate(
      workoutCount: 1,
      durationSeconds: 30,
      strengthVolumeKg: 100,
      runningDistanceMeters: 0,
      removedDurationSeconds: 60,
      removedStrengthVolumeKg: 200,
      removedRunningDistanceMeters: 0,
    );

    expect(result.durationSeconds, 0);
    expect(result.strengthVolumeKg, 0);
  });
}
