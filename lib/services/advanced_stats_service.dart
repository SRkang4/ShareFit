import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/advanced_stats.dart';
import '../models/workout_record.dart';

class AdvancedStatsService {
  AdvancedStatsService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  static const bodyParts = ['가슴', '등', '어깨', '하체', '팔'];
  static const _seoulOffset = Duration(hours: 9);

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  Stream<AdvancedStats> watchRecentSixMonths(DateTime selectedMonth) {
    final user = _firebaseAuth.currentUser;
    final normalizedMonth = DateTime(selectedMonth.year, selectedMonth.month);
    if (user == null) {
      return Stream.value(calculate(const [], normalizedMonth));
    }

    final range = queryRangeForSixMonths(normalizedMonth);
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('workouts')
        .where(
          'endedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.startUtc),
        )
        .where('endedAt', isLessThan: Timestamp.fromDate(range.endUtc))
        .orderBy('endedAt')
        .snapshots()
        .map((snapshot) {
          final workouts = snapshot.docs
              .where((document) => document.data()['status'] == 'completed')
              .map(
                (document) =>
                    WorkoutRecord.fromFirestore(document.id, document.data()),
              )
              .whereType<WorkoutRecord>()
              .toList();
          return calculate(workouts, normalizedMonth);
        });
  }

  static AdvancedStats calculate(
    Iterable<WorkoutRecord> workouts,
    DateTime selectedMonth,
  ) {
    final normalizedMonth = DateTime(selectedMonth.year, selectedMonth.month);
    final months = List.generate(
      6,
      (index) =>
          DateTime(normalizedMonth.year, normalizedMonth.month - 5 + index),
    );
    final accumulators = {
      for (final month in months)
        _monthKey(month): _MonthlyAccumulator(month: month),
    };
    final bodyPartVolumes = {for (final part in bodyParts) part: 0.0};
    var unassignedVolume = 0.0;

    for (final workout in workouts) {
      final seoulEndedAt = workout.endedAt.toUtc().add(_seoulOffset);
      final accumulator = accumulators[_monthKey(seoulEndedAt)];
      if (accumulator == null) continue;

      final strength = workout.strength;
      if (workout.type == 'strength' && strength != null) {
        final volume =
            strength.totalVolumeKg.isFinite && strength.totalVolumeKg > 0
            ? strength.totalVolumeKg
            : 0.0;
        accumulator.strengthVolumeKg += volume;

        if (seoulEndedAt.year == normalizedMonth.year &&
            seoulEndedAt.month == normalizedMonth.month &&
            volume > 0) {
          final normalizedParts = strength.bodyParts
              .map(_normalizeBodyPart)
              .whereType<String>()
              .toSet();
          if (normalizedParts.length == 1) {
            final part = normalizedParts.single;
            bodyPartVolumes[part] = bodyPartVolumes[part]! + volume;
          } else {
            unassignedVolume += volume;
          }
        }
      }

      final running = workout.running;
      if (workout.type == 'running' && running != null) {
        final distance =
            running.distanceMeters.isFinite && running.distanceMeters > 0
            ? running.distanceMeters
            : 0.0;
        accumulator.runningDistanceMeters += distance;
        if (distance > 0 && workout.durationSeconds > 0) {
          accumulator.runningDurationSeconds += workout.durationSeconds;
        }
      }
    }

    return AdvancedStats(
      selectedMonth: normalizedMonth,
      months: months
          .map((month) => accumulators[_monthKey(month)]!.toStats())
          .toList(growable: false),
      bodyPartVolumeKg: Map.unmodifiable(bodyPartVolumes),
      unassignedStrengthVolumeKg: unassignedVolume,
    );
  }

  static AdvancedStatsQueryRange queryRangeForSixMonths(
    DateTime selectedMonth,
  ) {
    final firstMonth = DateTime(selectedMonth.year, selectedMonth.month - 5);
    final nextMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);
    return AdvancedStatsQueryRange(
      startUtc: DateTime.utc(
        firstMonth.year,
        firstMonth.month,
      ).subtract(_seoulOffset),
      endUtc: DateTime.utc(
        nextMonth.year,
        nextMonth.month,
      ).subtract(_seoulOffset),
    );
  }

  static String _monthKey(DateTime date) => '${date.year}-${date.month}';

  static String? _normalizeBodyPart(String rawPart) {
    final part = rawPart.trim();
    if (part == '이두' || part == '삼두' || part == '팔') return '팔';
    return bodyParts.contains(part) ? part : null;
  }
}

class AdvancedStatsQueryRange {
  const AdvancedStatsQueryRange({required this.startUtc, required this.endUtc});

  final DateTime startUtc;
  final DateTime endUtc;
}

class _MonthlyAccumulator {
  _MonthlyAccumulator({required this.month});

  final DateTime month;
  double strengthVolumeKg = 0;
  double runningDistanceMeters = 0;
  int runningDurationSeconds = 0;

  MonthlyAdvancedStats toStats() => MonthlyAdvancedStats(
    month: month,
    strengthVolumeKg: strengthVolumeKg,
    runningDistanceMeters: runningDistanceMeters,
    runningDurationSeconds: runningDurationSeconds,
  );
}
