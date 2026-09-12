import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/friend.dart';
import '../models/friend_request.dart';
import '../models/public_profile.dart';

class FriendServiceException implements Exception {
  const FriendServiceException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class FriendSearchResult {
  const FriendSearchResult({
    required this.profile,
    required this.canRequest,
    this.reason,
  });

  final PublicProfile profile;
  final bool canRequest;
  final String? reason;
}

class FriendService {
  FriendService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const FriendServiceException('unauthenticated', '로그인이 필요합니다.');
    }
    return uid;
  }

  String canonicalPairId(String firstUid, String secondUid) {
    return firstUid.compareTo(secondUid) < 0
        ? '${firstUid}_$secondUid'
        : '${secondUid}_$firstUid';
  }

  Future<void> migrateCurrentUser() async {
    final uid = _uid;
    try {
      final userRef = _firestore.collection('users').doc(uid);
      final user = await userRef.get();
      final data = user.data();
      if (data == null) {
        throw const FriendServiceException(
          'user-not-found',
          '사용자 정보를 찾을 수 없습니다.',
        );
      }

      final code = (data['friendCode'] as String? ?? '').trim().toUpperCase();
      final name = (data['name'] as String? ?? '').trim();
      final experienceStartDate = data['experienceStartDate'];
      if (code.isEmpty || name.isEmpty) {
        throw const FriendServiceException(
          'invalid-profile',
          '사용자 정보를 확인해주세요.',
        );
      }

      final codeRef = _firestore.collection('friendCodes').doc(code);
      final profileRef = _firestore.collection('publicProfiles').doc(uid);
      final needsFriendCount = data['friendCount'] is! int;

      await _firestore.runTransaction((transaction) async {
        final codeDocument = await transaction.get(codeRef);
        if (codeDocument.exists && codeDocument.data()?['uid'] != uid) {
          throw const FriendServiceException(
            'friend-code-conflict',
            '친구 코드가 중복되었습니다. 고객센터에 문의해주세요.',
          );
        }

        if (!codeDocument.exists) {
          transaction.set(codeRef, {
            'uid': uid,
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        transaction.set(profileRef, {
          'uid': uid,
          'name': name,
          'friendCode': code,
          'active': true,
          'experienceStartDate': experienceStartDate is Timestamp
              ? experienceStartDate
              : null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (needsFriendCount) {
          transaction.update(userRef, {'friendCount': 0});
        }
      });
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[FriendMigration] FirebaseException 실패 '
        'plugin=${error.plugin} code=${error.code} message=${error.message}',
      );
      debugPrintStack(
        label: '[FriendMigration] FirebaseException stackTrace',
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(error, stackTrace);
    } catch (error, stackTrace) {
      debugPrint('[FriendMigration] 일반 예외 실패 exception=$error');
      debugPrintStack(
        label: '[FriendMigration] 일반 예외 stackTrace',
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<FriendSearchResult> searchByFriendCode(String rawCode) async {
    final uid = _uid;
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      throw const FriendServiceException('empty-code', '친구 코드를 입력해주세요.');
    }

    final currentUser = await _firestore.collection('users').doc(uid).get();
    if ((currentUser.data()?['friendCode'] as String?)?.toUpperCase() == code) {
      throw const FriendServiceException('self', '자기 자신은 친구로 추가할 수 없습니다.');
    }

    final codeDocument = await _firestore
        .collection('friendCodes')
        .doc(code)
        .get();
    final codeData = codeDocument.data();
    if (codeData == null || codeData['active'] != true) {
      throw const FriendServiceException('not-found', '해당 친구 코드를 찾을 수 없습니다.');
    }
    final targetUid = codeData['uid'] as String?;
    if (targetUid == null || targetUid == uid) {
      throw const FriendServiceException('self', '자기 자신은 친구로 추가할 수 없습니다.');
    }

    final profileDocument = await _firestore
        .collection('publicProfiles')
        .doc(targetUid)
        .get();
    final profile = PublicProfile.fromFirestore(profileDocument);
    if (!profileDocument.exists || !profile.active || profile.name.isEmpty) {
      throw const FriendServiceException('not-found', '해당 사용자를 찾을 수 없습니다.');
    }

    final friendDocument = await _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .doc(targetUid)
        .get();
    if (friendDocument.exists) {
      return FriendSearchResult(
        profile: profile,
        canRequest: false,
        reason: '이미 친구인 사용자예요.',
      );
    }

    final hasPendingRequest = await _hasPendingRequestWith(targetUid);
    if (hasPendingRequest) {
      return FriendSearchResult(
        profile: profile,
        canRequest: false,
        reason: '이미 친구 요청을 보냈거나 받은 사용자예요.',
      );
    }
    return FriendSearchResult(profile: profile, canRequest: true);
  }

  Future<void> sendFriendRequest(PublicProfile target) async {
    final uid = _uid;
    if (target.uid == uid) {
      throw const FriendServiceException('self', '자기 자신에게 요청할 수 없습니다.');
    }
    final requestRef = _firestore
        .collection('friendRequests')
        .doc(canonicalPairId(uid, target.uid));
    final ownFriendRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .doc(target.uid);
    final targetProfileRef = _firestore
        .collection('publicProfiles')
        .doc(target.uid);

    await _firestore.runTransaction((transaction) async {
      final friend = await transaction.get(ownFriendRef);
      final profile = await transaction.get(targetProfileRef);
      if (!profile.exists || profile.data()?['active'] != true) {
        throw const FriendServiceException(
          'inactive-user',
          '탈퇴했거나 사용할 수 없는 사용자입니다.',
        );
      }
      if (friend.exists) {
        throw const FriendServiceException('already-friend', '이미 친구인 사용자예요.');
      }
      transaction.set(requestRef, {
        'fromUid': uid,
        'toUid': target.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<bool> _hasPendingRequestWith(String targetUid) async {
    final uid = _uid;
    final requests = _firestore.collection('friendRequests');
    final results = await Future.wait([
      requests
          .where('fromUid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get(),
      requests
          .where('toUid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get(),
    ]);
    return results.expand((snapshot) => snapshot.docs).any((document) {
      final data = document.data();
      return data['fromUid'] == targetUid || data['toUid'] == targetUid;
    });
  }

  Future<void> acceptFriendRequest(FriendRequest request) async {
    final uid = _uid;
    if (request.toUid != uid) {
      throw const FriendServiceException('not-recipient', '받은 요청만 수락할 수 있습니다.');
    }
    final requestRef = _firestore.collection('friendRequests').doc(request.id);
    final ownUserRef = _firestore.collection('users').doc(uid);
    final otherUserRef = _firestore.collection('users').doc(request.fromUid);
    final ownFriendRef = ownUserRef.collection('friends').doc(request.fromUid);
    final otherFriendRef = otherUserRef.collection('friends').doc(uid);
    final batch = _firestore.batch();
    batch.update(requestRef, {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(ownFriendRef, {
      'friendUid': request.fromUid,
      'requestId': request.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(otherFriendRef, {
      'friendUid': uid,
      'requestId': request.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(ownUserRef, {
      'friendCount': FieldValue.increment(1),
      '_friendMutation': {
        'type': 'accept',
        'friendUid': request.fromUid,
        'requestId': request.id,
      },
    });
    batch.update(otherUserRef, {
      'friendCount': FieldValue.increment(1),
      '_friendMutation': {
        'type': 'accept',
        'friendUid': uid,
        'requestId': request.id,
      },
    });
    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' ||
          error.code == 'failed-precondition') {
        throw const FriendServiceException(
          'accept-not-allowed',
          '친구 요청 상태 또는 서버의 친구 수 제한으로 수락할 수 없어요. 나와 상대방의 친구 수를 확인해주세요.',
        );
      }
      rethrow;
    }
  }

  Future<void> rejectFriendRequest(FriendRequest request) async {
    if (request.toUid != _uid) {
      throw const FriendServiceException('not-recipient', '받은 요청만 거절할 수 있습니다.');
    }
    await _firestore.collection('friendRequests').doc(request.id).delete();
  }

  Future<void> cancelFriendRequest(FriendRequest request) async {
    if (request.fromUid != _uid) {
      throw const FriendServiceException('not-sender', '보낸 요청만 취소할 수 있습니다.');
    }
    await _firestore.collection('friendRequests').doc(request.id).delete();
  }

  Future<void> removeFriend(Friend friend) async {
    final uid = _uid;
    final ownUserRef = _firestore.collection('users').doc(uid);
    final otherUserRef = _firestore.collection('users').doc(friend.uid);
    final batch = _firestore.batch();
    batch.delete(ownUserRef.collection('friends').doc(friend.uid));
    batch.delete(otherUserRef.collection('friends').doc(uid));
    batch.update(ownUserRef, {
      'friendCount': FieldValue.increment(-1),
      '_friendMutation': {
        'type': 'delete',
        'friendUid': friend.uid,
        'requestId': friend.requestId,
      },
    });
    batch.update(otherUserRef, {
      'friendCount': FieldValue.increment(-1),
      '_friendMutation': {
        'type': 'delete',
        'friendUid': uid,
        'requestId': friend.requestId,
      },
    });
    batch.delete(_firestore.collection('friendRequests').doc(friend.requestId));
    await batch.commit();
  }

  Stream<List<Friend>> watchFriends() {
    final uid = _uid;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final result = <Friend>[];
          for (final document in snapshot.docs) {
            final friendUid =
                document.data()['friendUid'] as String? ?? document.id;
            final profileDocument = await _firestore
                .collection('publicProfiles')
                .doc(friendUid)
                .get();
            if (!profileDocument.exists) continue;
            final profile = PublicProfile.fromFirestore(profileDocument);
            if (!profile.active) continue;
            result.add(
              Friend(
                uid: friendUid,
                requestId:
                    document.data()['requestId'] as String? ??
                    canonicalPairId(uid, friendUid),
                profile: profile,
              ),
            );
          }
          return result;
        });
  }

  Stream<List<FriendRequest>> watchReceivedRequests() =>
      _watchRequests('toUid');
  Stream<List<FriendRequest>> watchSentRequests() => _watchRequests('fromUid');

  Stream<bool> watchHasReceivedPendingRequests() {
    final uid = _uid;
    return _firestore
        .collection('friendRequests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  Stream<List<FriendRequest>> _watchRequests(String uidField) {
    final uid = _uid;
    return _firestore
        .collection('friendRequests')
        .where(uidField, isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
          final result = <FriendRequest>[];
          for (final document in snapshot.docs) {
            final data = document.data();
            final fromUid = data['fromUid'] as String? ?? '';
            final toUid = data['toUid'] as String? ?? '';
            final profileUid = uidField == 'toUid' ? fromUid : toUid;
            final profileDocument = await _firestore
                .collection('publicProfiles')
                .doc(profileUid)
                .get();
            if (!profileDocument.exists) continue;
            final profile = PublicProfile.fromFirestore(profileDocument);
            if (!profile.active) continue;
            result.add(
              FriendRequest(
                id: document.id,
                fromUid: fromUid,
                toUid: toUid,
                status: data['status'] as String? ?? 'pending',
                profile: profile,
              ),
            );
          }
          return result;
        });
  }
}
