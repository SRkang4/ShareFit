class RankingEntry {
  const RankingEntry({
    required this.uid,
    required this.name,
    required this.isCurrentUser,
    required this.workoutDays,
    required this.durationSeconds,
    required this.strengthVolumeKg,
    required this.runningDistanceMeters,
  });

  final String uid;
  final String name;
  final bool isCurrentUser;
  final int workoutDays;
  final int durationSeconds;
  final double strengthVolumeKg;
  final double runningDistanceMeters;
}

enum RankingPeriod { week, month }
