import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/profile_customization.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    Random? random,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _random = random ?? Random.secure();

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final Random _random;

  Future<void> signIn({required String email, required String password}) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    User? createdUser;

    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      createdUser = credential.user;

      if (createdUser == null) {
        throw FirebaseAuthException(
          code: 'user-creation-failed',
          message: 'Firebase Auth 계정 생성 결과에 사용자 정보가 없습니다.',
        );
      }

      await _createUserDocuments(
        uid: createdUser.uid,
        email: email,
        name: name,
      );
    } catch (error, stackTrace) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {
          // Preserve the original signup error after attempting rollback.
        }
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _createUserDocuments({
    required String uid,
    required String email,
    required String name,
  }) async {
    while (true) {
      final friendCode = _createFriendCode();
      final userRef = _firestore.collection('users').doc(uid);
      final codeRef = _firestore.collection('friendCodes').doc(friendCode);
      final profileRef = _firestore.collection('publicProfiles').doc(uid);

      final created = await _firestore.runTransaction((transaction) async {
        final codeDocument = await transaction.get(codeRef);
        if (codeDocument.exists) {
          return false;
        }

        transaction.set(userRef, {
          'uid': uid,
          'email': email,
          'name': name,
          'friendCode': friendCode,
          'isPro': false,
          'friendCount': 0,
          'profileCustomization': ProfileCustomization.defaults.toFirestore(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(codeRef, {
          'uid': uid,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(profileRef, {
          'uid': uid,
          'name': name,
          'friendCode': friendCode,
          'active': true,
          'profileTitleId': ProfileTitleIds.none,
          'profileThemeId': ProfileThemeIds.defaultTheme,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (created) {
        return;
      }
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return null;
    }

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    return snapshot.data();
  }

  Future<void> updateCurrentUserProfile({
    required String name,
    required DateTime experienceStartDate,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: '현재 로그인한 사용자가 없습니다.',
      );
    }

    final currentUserDocument = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    final friendCode = currentUserDocument.data()?['friendCode'] as String?;
    if (friendCode == null || friendCode.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'friend-code-not-found',
        message: '친구 코드를 확인할 수 없습니다.',
      );
    }

    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(user.uid), {
      'name': name,
      'experienceStartDate': Timestamp.fromDate(experienceStartDate),
    });
    batch.set(
      _firestore.collection('publicProfiles').doc(user.uid),
      {
        'uid': user.uid,
        'name': name,
        'friendCode': friendCode,
        'active': true,
        'experienceStartDate': Timestamp.fromDate(experienceStartDate),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return;
    }

    final userDocument = _firestore.collection('users').doc(user.uid);
    final snapshot = await userDocument.get();
    final userData = snapshot.data();

    final friends = await userDocument.collection('friends').limit(1).get();
    if (friends.docs.isNotEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'friends-exist',
        message: '친구 관계를 먼저 삭제해주세요.',
      );
    }

    final receivedRequests = await _firestore
        .collection('friendRequests')
        .where('toUid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .get();
    final sentRequests = await _firestore
        .collection('friendRequests')
        .where('fromUid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .get();
    final cleanup = _firestore.batch();
    for (final request in [...receivedRequests.docs, ...sentRequests.docs]) {
      cleanup.delete(request.reference);
    }
    final friendCode = userData?['friendCode'] as String?;
    if (friendCode != null && friendCode.isNotEmpty) {
      cleanup.delete(_firestore.collection('friendCodes').doc(friendCode));
    }
    cleanup.delete(_firestore.collection('publicProfiles').doc(user.uid));
    cleanup.delete(userDocument);
    await cleanup.commit();

    try {
      await user.delete();
    } catch (error, stackTrace) {
      if (snapshot.exists && userData != null) {
        try {
          await userDocument.set(userData);
        } catch (_) {
          // Account deletion errors take precedence over best-effort rollback.
        }
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  String _createFriendCode() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final letter = letters[_random.nextInt(letters.length)];
    final digits = List.generate(7, (_) => _random.nextInt(10)).join();
    return '$letter$digits';
  }
}
