import 'package:cloud_firestore/cloud_firestore.dart';

class PublicActivity {
  const PublicActivity({
    required this.uid,
    required this.status,
    this.workoutType,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.photoUrl,
    this.lastWorkoutAt,
    this.strengthSummary,
    this.runningSummary,
  });

  final String uid;
  final String status;
  final String? workoutType;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final String? photoUrl;
  final DateTime? lastWorkoutAt;
  final PublicStrengthSummary? strengthSummary;
  final PublicRunningSummary? runningSummary;

  factory PublicActivity.fromFirestore(String uid, Map<String, dynamic>? data) {
    DateTime? date(String key) =>
        data?[key] is Timestamp ? (data![key] as Timestamp).toDate() : null;
    return PublicActivity(
      uid: uid,
      status: data?['status'] as String? ?? 'idle',
      workoutType: data?['workoutType'] as String?,
      startedAt: date('startedAt'),
      endedAt: date('endedAt'),
      durationSeconds: (data?['durationSeconds'] as num?)?.toInt(),
      photoUrl: data?['photoUrl'] as String?,
      lastWorkoutAt: date('lastWorkoutAt'),
      strengthSummary: data?['strengthSummary'] is Map
          ? PublicStrengthSummary.fromMap(
              Map<String, dynamic>.from(data!['strengthSummary'] as Map),
            )
          : null,
      runningSummary: data?['runningSummary'] is Map
          ? PublicRunningSummary.fromMap(
              Map<String, dynamic>.from(data!['runningSummary'] as Map),
            )
          : null,
    );
  }
}

class PublicStrengthSummary {
  const PublicStrengthSummary({
    required this.bodyParts,
    required this.completedSetCount,
    required this.totalVolumeKg,
  });
  final List<String> bodyParts;
  final int completedSetCount;
  final double totalVolumeKg;

  factory PublicStrengthSummary.fromMap(Map<String, dynamic> data) =>
      PublicStrengthSummary(
        bodyParts:
            (data['bodyParts'] as List?)?.whereType<String>().toList() ??
            const [],
        completedSetCount: (data['completedSetCount'] as num?)?.toInt() ?? 0,
        totalVolumeKg: (data['totalVolumeKg'] as num?)?.toDouble() ?? 0,
      );
}

class PublicRunningSummary {
  const PublicRunningSummary({
    required this.distanceMeters,
    required this.averagePaceSecondsPerKm,
  });
  final double distanceMeters;
  final double? averagePaceSecondsPerKm;

  factory PublicRunningSummary.fromMap(Map<String, dynamic> data) =>
      PublicRunningSummary(
        distanceMeters: (data['distanceMeters'] as num?)?.toDouble() ?? 0,
        averagePaceSecondsPerKm: (data['averagePaceSecondsPerKm'] as num?)
            ?.toDouble(),
      );
}
