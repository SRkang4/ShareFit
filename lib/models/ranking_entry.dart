class RankingEntry {
  const RankingEntry({
    required this.uid,
    required this.name,
    required this.isCurrentUser,
    required this.workoutDays,
    required this.durationSeconds,
  });

  final String uid;
  final String name;
  final bool isCurrentUser;
  final int workoutDays;
  final int durationSeconds;
}

enum RankingPeriod { week, month }
