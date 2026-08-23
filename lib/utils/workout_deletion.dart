class WorkoutStatsAfterDeletion {
  const WorkoutStatsAfterDeletion({
    required this.workoutCount,
    required this.durationSeconds,
    required this.strengthVolumeKg,
    required this.runningDistanceMeters,
  });

  final int workoutCount;
  final int durationSeconds;
  final double strengthVolumeKg;
  final double runningDistanceMeters;

  bool get isEmpty => workoutCount == 0;

  factory WorkoutStatsAfterDeletion.calculate({
    required int workoutCount,
    required int durationSeconds,
    required double strengthVolumeKg,
    required double runningDistanceMeters,
    required int removedDurationSeconds,
    required double removedStrengthVolumeKg,
    required double removedRunningDistanceMeters,
  }) {
    return WorkoutStatsAfterDeletion(
      workoutCount: (workoutCount - 1).clamp(0, 1 << 31).toInt(),
      durationSeconds: (durationSeconds - removedDurationSeconds)
          .clamp(0, 1 << 31)
          .toInt(),
      strengthVolumeKg: (strengthVolumeKg - removedStrengthVolumeKg)
          .clamp(0, double.infinity)
          .toDouble(),
      runningDistanceMeters:
          (runningDistanceMeters - removedRunningDistanceMeters)
              .clamp(0, double.infinity)
              .toDouble(),
    );
  }
}
