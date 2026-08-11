String formatWorkoutExperience(DateTime? startDate, {DateTime? now}) {
  if (startDate == null) {
    return '운동 경력 미설정';
  }

  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final normalizedStart = DateTime(
    startDate.year,
    startDate.month,
    startDate.day,
  );
  if (normalizedStart.isAfter(today)) {
    return '운동 경력 미설정';
  }

  var completedYears = today.year - normalizedStart.year;
  final anniversary = DateTime(
    today.year,
    normalizedStart.month,
    normalizedStart.day,
  );
  if (today.isBefore(anniversary)) {
    completedYears--;
  }
  return '운동 ${completedYears + 1}년차';
}
