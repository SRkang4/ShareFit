class CompetitionRank<T> {
  const CompetitionRank({required this.entry, required this.rank});

  final T entry;
  final int rank;
}

List<CompetitionRank<T>> assignCompetitionRanks<T>(
  List<T> sortedEntries,
  num Function(T entry) valueOf,
) {
  final rankedEntries = <CompetitionRank<T>>[];
  num? previousValue;
  var currentRank = 0;

  for (var index = 0; index < sortedEntries.length; index++) {
    final entry = sortedEntries[index];
    final value = valueOf(entry);
    if (index == 0 || value != previousValue) {
      currentRank = index + 1;
    }
    rankedEntries.add(CompetitionRank(entry: entry, rank: currentRank));
    previousValue = value;
  }

  return rankedEntries;
}
