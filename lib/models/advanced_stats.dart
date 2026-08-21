class AdvancedStats {
  const AdvancedStats({
    required this.selectedMonth,
    required this.months,
    required this.bodyPartVolumeKg,
    required this.unassignedStrengthVolumeKg,
  });

  final DateTime selectedMonth;
  final List<MonthlyAdvancedStats> months;
  final Map<String, double> bodyPartVolumeKg;
  final double unassignedStrengthVolumeKg;

  MonthlyAdvancedStats get selectedMonthStats => months.last;
}

class MonthlyAdvancedStats {
  const MonthlyAdvancedStats({
    required this.month,
    required this.strengthVolumeKg,
    required this.runningDistanceMeters,
    required this.runningDurationSeconds,
  });

  final DateTime month;
  final double strengthVolumeKg;
  final double runningDistanceMeters;
  final int runningDurationSeconds;

  double? get averagePaceSecondsPerKm {
    if (runningDistanceMeters <= 0 || runningDurationSeconds <= 0) {
      return null;
    }
    return runningDurationSeconds / (runningDistanceMeters / 1000);
  }
}
