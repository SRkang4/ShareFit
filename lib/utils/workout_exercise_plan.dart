List<String> normalizePlannedExerciseNames(Iterable<String?> names) {
  return names
      .whereType<String>()
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
}
