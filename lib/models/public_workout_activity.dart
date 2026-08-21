import 'package:cloud_firestore/cloud_firestore.dart';

import 'photo_expiration.dart';
import 'public_activity.dart';

class PublicWorkoutActivity {
  const PublicWorkoutActivity({
    required this.uid,
    required this.workoutId,
    required this.dateKey,
    required this.type,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    this.photoUrl,
    this.photoCreatedAt,
    this.photoExpiresAt,
    this.strengthSummary,
    this.runningSummary,
  });

  final String uid;
  final String workoutId;
  final String dateKey;
  final String type;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final String? photoUrl;
  final DateTime? photoCreatedAt;
  final DateTime? photoExpiresAt;
  final PublicStrengthSummary? strengthSummary;
  final PublicRunningSummary? runningSummary;

  String? get validPhotoUrl =>
      PhotoExpiration.validUrl(photoUrl: photoUrl, expiresAt: photoExpiresAt);

  factory PublicWorkoutActivity.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime? date(String key) =>
        data[key] is Timestamp ? (data[key] as Timestamp).toDate() : null;
    return PublicWorkoutActivity(
      uid: data['uid'] as String? ?? '',
      workoutId: data['workoutId'] as String? ?? id,
      dateKey: data['dateKey'] as String? ?? '',
      type: data['type'] as String? ?? 'strength',
      startedAt: date('startedAt') ?? DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: date('endedAt') ?? DateTime.fromMillisecondsSinceEpoch(0),
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String?,
      photoCreatedAt: date('photoCreatedAt'),
      photoExpiresAt: date('photoExpiresAt'),
      strengthSummary: data['strengthSummary'] is Map
          ? PublicStrengthSummary.fromMap(
              Map<String, dynamic>.from(data['strengthSummary'] as Map),
            )
          : null,
      runningSummary: data['runningSummary'] is Map
          ? PublicRunningSummary.fromMap(
              Map<String, dynamic>.from(data['runningSummary'] as Map),
            )
          : null,
    );
  }

  factory PublicWorkoutActivity.fromLegacy(PublicActivity activity) {
    final endedAt = activity.endedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final seoulEndedAt = endedAt.toUtc().add(const Duration(hours: 9));
    final dateKey =
        '${seoulEndedAt.year.toString().padLeft(4, '0')}-'
        '${seoulEndedAt.month.toString().padLeft(2, '0')}-'
        '${seoulEndedAt.day.toString().padLeft(2, '0')}';
    return PublicWorkoutActivity(
      uid: activity.uid,
      workoutId: 'legacy-${endedAt.millisecondsSinceEpoch}',
      dateKey: dateKey,
      type: activity.workoutType ?? 'strength',
      startedAt: activity.startedAt ?? endedAt,
      endedAt: endedAt,
      durationSeconds: activity.durationSeconds ?? 0,
      photoUrl: activity.photoUrl,
      photoCreatedAt: activity.photoCreatedAt,
      photoExpiresAt: activity.photoExpiresAt,
      strengthSummary: activity.strengthSummary,
      runningSummary: activity.runningSummary,
    );
  }
}
