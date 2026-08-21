import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/public_profile.dart';
import '../models/ranking_entry.dart';
import 'friend_service.dart';

class RankingService {
  RankingService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FriendService? friendService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _friendService = friendService ?? FriendService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FriendService _friendService;

  Stream<List<RankingEntry>> watchRankings(RankingPeriod period) {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return Stream.value(const []);

    late StreamController<List<RankingEntry>> controller;
    StreamSubscription? friendsSubscription;
    StreamSubscription? ownProfileSubscription;
    final statsSubscriptions = <StreamSubscription>[];
    PublicProfile? ownProfile;
    var friendProfiles = <PublicProfile>[];
    final stats =
        <
          String,
          ({
            int days,
            int seconds,
            double strengthVolumeKg,
            double runningDistanceMeters,
          })
        >{};
    var statsGeneration = 0;

    void emit() {
      final profile = ownProfile;
      if (profile == null || controller.isClosed) return;
      final profiles = <PublicProfile>[profile, ...friendProfiles];
      controller.add(
        profiles.map((participant) {
          final value = stats[participant.uid];
          return RankingEntry(
            uid: participant.uid,
            name: participant.name.isEmpty ? '이름 미설정' : participant.name,
            isCurrentUser: participant.uid == currentUid,
            workoutDays: value?.days ?? 0,
            durationSeconds: value?.seconds ?? 0,
            strengthVolumeKg: value?.strengthVolumeKg ?? 0,
            runningDistanceMeters: value?.runningDistanceMeters ?? 0,
          );
        }).toList(),
      );
    }

    Future<void> subscribeStats() async {
      final generation = ++statsGeneration;
      for (final subscription in statsSubscriptions) {
        await subscription.cancel();
      }
      if (generation != statsGeneration) return;
      statsSubscriptions.clear();
      stats.clear();
      final profile = ownProfile;
      if (profile == null) return;

      final range = _dateKeyRange(period);
      for (final participant in <PublicProfile>[profile, ...friendProfiles]) {
        final subscription = _firestore
            .collection('publicWorkoutStats')
            .doc(participant.uid)
            .collection('days')
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: range.start)
            .where(FieldPath.documentId, isLessThan: range.end)
            .snapshots()
            .listen((snapshot) {
              if (generation != statsGeneration) return;
              var days = 0;
              var seconds = 0;
              var strengthVolumeKg = 0.0;
              var runningDistanceMeters = 0.0;
              for (final document in snapshot.docs) {
                final data = document.data();
                final count = (data['workoutCount'] as num?)?.toInt() ?? 0;
                if (count > 0) days++;
                seconds += (data['durationSeconds'] as num?)?.toInt() ?? 0;
                strengthVolumeKg +=
                    (data['strengthVolumeKg'] as num?)?.toDouble() ?? 0;
                runningDistanceMeters +=
                    (data['runningDistanceMeters'] as num?)?.toDouble() ?? 0;
              }
              stats[participant.uid] = (
                days: days,
                seconds: seconds,
                strengthVolumeKg: strengthVolumeKg,
                runningDistanceMeters: runningDistanceMeters,
              );
              emit();
            }, onError: controller.addError);
        statsSubscriptions.add(subscription);
      }
      emit();
    }

    controller = StreamController<List<RankingEntry>>(
      onListen: () {
        ownProfileSubscription = _firestore
            .collection('publicProfiles')
            .doc(currentUid)
            .snapshots()
            .listen((snapshot) {
              if (!snapshot.exists) return;
              ownProfile = PublicProfile.fromFirestore(snapshot);
              subscribeStats();
            }, onError: controller.addError);
        friendsSubscription = _friendService.watchFriends().listen((friends) {
          friendProfiles = friends.map((friend) => friend.profile).toList();
          subscribeStats();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await ownProfileSubscription?.cancel();
        await friendsSubscription?.cancel();
        for (final subscription in statsSubscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  ({String start, String end}) _dateKeyRange(RankingPeriod period) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    late final DateTime start;
    late final DateTime end;
    if (period == RankingPeriod.week) {
      start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - DateTime.monday));
      end = start.add(const Duration(days: 7));
    } else {
      start = DateTime(now.year, now.month);
      end = DateTime(now.year, now.month + 1);
    }
    return (start: _dateKey(start), end: _dateKey(end));
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
