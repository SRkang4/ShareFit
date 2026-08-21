import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/utils/competition_ranking.dart';

void main() {
  test('assigns competition ranks for integer ties', () {
    final ranked = assignCompetitionRanks<int>([5, 5, 3], (value) => value);
    expect(ranked.map((item) => item.rank), [1, 1, 3]);
  });

  test('skips the next rank after a middle tie', () {
    final ranked = assignCompetitionRanks<int>([5, 4, 4, 2], (value) => value);
    expect(ranked.map((item) => item.rank), [1, 2, 2, 4]);
  });

  test('uses exact double values rather than display rounding', () {
    final ranked = assignCompetitionRanks<double>([
      12450.04,
      12450.04,
      12450.03,
    ], (value) => value);
    expect(ranked.map((item) => item.rank), [1, 1, 3]);
  });

  test('assigns every zero value the same rank', () {
    final ranked = assignCompetitionRanks<double>([0, 0, 0], (value) => value);
    expect(ranked.map((item) => item.rank), [1, 1, 1]);
  });
}
