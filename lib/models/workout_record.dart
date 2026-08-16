import 'package:cloud_firestore/cloud_firestore.dart';

import 'photo_expiration.dart';

class WorkoutRecord {
  const WorkoutRecord({
    this.id,
    required this.userId,
    required this.type,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    this.photoUrl,
    this.photoCreatedAt,
    this.photoExpiresAt,
    this.strength,
    this.running,
  });

  final String? id;
  final String userId;
  final String type;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final String? photoUrl;
  final DateTime? photoCreatedAt;
  final DateTime? photoExpiresAt;
  final StrengthWorkoutData? strength;
  final RunningWorkoutData? running;

  bool get hasValidPhoto =>
      PhotoExpiration.isValid(photoUrl: photoUrl, expiresAt: photoExpiresAt);

  String? get validPhotoUrl =>
      PhotoExpiration.validUrl(photoUrl: photoUrl, expiresAt: photoExpiresAt);

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type,
      'status': 'completed',
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': Timestamp.fromDate(endedAt),
      'durationSeconds': durationSeconds,
      'createdAt': FieldValue.serverTimestamp(),
      'photoUrl': photoUrl,
      'photoCreatedAt': photoCreatedAt == null
          ? null
          : Timestamp.fromDate(photoCreatedAt!),
      'photoExpiresAt': photoExpiresAt == null
          ? null
          : Timestamp.fromDate(photoExpiresAt!),
      if (strength != null) 'strength': strength!.toFirestore(),
      if (running != null) 'running': running!.toFirestore(),
    };
  }

  static WorkoutRecord? fromFirestore(String id, Map<String, dynamic> data) {
    final startedAt = data['startedAt'];
    final endedAt = data['endedAt'];
    final durationSeconds = data['durationSeconds'];
    final userId = data['userId'];
    final type = data['type'];

    if (startedAt is! Timestamp ||
        endedAt is! Timestamp ||
        durationSeconds is! num ||
        userId is! String ||
        type is! String) {
      return null;
    }

    return WorkoutRecord(
      id: id,
      userId: userId,
      type: type,
      startedAt: startedAt.toDate(),
      endedAt: endedAt.toDate(),
      durationSeconds: durationSeconds.toInt(),
      photoUrl: data['photoUrl'] is String ? data['photoUrl'] as String : null,
      photoCreatedAt: data['photoCreatedAt'] is Timestamp
          ? (data['photoCreatedAt'] as Timestamp).toDate()
          : null,
      photoExpiresAt: data['photoExpiresAt'] is Timestamp
          ? (data['photoExpiresAt'] as Timestamp).toDate()
          : null,
      strength: data['strength'] is Map<String, dynamic>
          ? StrengthWorkoutData.fromFirestore(
              data['strength'] as Map<String, dynamic>,
            )
          : null,
      running: data['running'] is Map<String, dynamic>
          ? RunningWorkoutData.fromFirestore(
              data['running'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class StrengthWorkoutData {
  const StrengthWorkoutData({
    required this.bodyParts,
    required this.exercises,
    required this.completedSetCount,
    required this.totalVolumeKg,
  });

  final List<String> bodyParts;
  final List<StrengthExerciseData> exercises;
  final int completedSetCount;
  final double totalVolumeKg;

  Map<String, dynamic> toFirestore() {
    return {
      'bodyParts': bodyParts,
      'exercises': exercises.map((exercise) => exercise.toFirestore()).toList(),
      'completedSetCount': completedSetCount,
      'totalVolumeKg': totalVolumeKg,
    };
  }

  factory StrengthWorkoutData.fromFirestore(Map<String, dynamic> data) {
    final rawBodyParts = data['bodyParts'];
    final rawExercises = data['exercises'];
    return StrengthWorkoutData(
      bodyParts: rawBodyParts is List
          ? rawBodyParts.whereType<String>().toList()
          : const [],
      exercises: rawExercises is List
          ? rawExercises
                .whereType<Map>()
                .map(
                  (exercise) => StrengthExerciseData.fromFirestore(
                    Map<String, dynamic>.from(exercise),
                  ),
                )
                .toList()
          : const [],
      completedSetCount: (data['completedSetCount'] as num?)?.toInt() ?? 0,
      totalVolumeKg: (data['totalVolumeKg'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StrengthExerciseData {
  const StrengthExerciseData({required this.name, required this.sets});

  final String name;
  final List<StrengthSetData> sets;

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'sets': sets.map((set) => set.toFirestore()).toList(),
    };
  }

  factory StrengthExerciseData.fromFirestore(Map<String, dynamic> data) {
    final rawSets = data['sets'];
    return StrengthExerciseData(
      name: data['name'] is String ? data['name'] as String : '',
      sets: rawSets is List
          ? rawSets
                .whereType<Map>()
                .map(
                  (set) => StrengthSetData.fromFirestore(
                    Map<String, dynamic>.from(set),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class StrengthSetData {
  const StrengthSetData({required this.weightKg, required this.reps});

  final double weightKg;
  final int reps;

  Map<String, dynamic> toFirestore() {
    return {'weightKg': weightKg, 'reps': reps};
  }

  factory StrengthSetData.fromFirestore(Map<String, dynamic> data) {
    return StrengthSetData(
      weightKg: (data['weightKg'] as num?)?.toDouble() ?? 0,
      reps: (data['reps'] as num?)?.toInt() ?? 0,
    );
  }
}

class RunningWorkoutData {
  const RunningWorkoutData({
    required this.targetDistanceMeters,
    required this.distanceMeters,
    required this.acceptedLocationCount,
    required this.averagePaceSecondsPerKm,
  });

  final double targetDistanceMeters;
  final double distanceMeters;
  final int acceptedLocationCount;
  final double? averagePaceSecondsPerKm;

  Map<String, dynamic> toFirestore() {
    return {
      'targetDistanceMeters': targetDistanceMeters,
      'distanceMeters': distanceMeters,
      'acceptedLocationCount': acceptedLocationCount,
      'averagePaceSecondsPerKm': averagePaceSecondsPerKm,
    };
  }

  factory RunningWorkoutData.fromFirestore(Map<String, dynamic> data) {
    return RunningWorkoutData(
      targetDistanceMeters:
          (data['targetDistanceMeters'] as num?)?.toDouble() ?? 0,
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble() ?? 0,
      acceptedLocationCount:
          (data['acceptedLocationCount'] as num?)?.toInt() ?? 0,
      averagePaceSecondsPerKm: (data['averagePaceSecondsPerKm'] as num?)
          ?.toDouble(),
    );
  }
}
