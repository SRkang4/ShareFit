import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/profile_customization.dart';
import '../utils/auth_profile_defaults.dart';
import 'fcm_token_service.dart';
import 'google_auth_client.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    Random? random,
    GoogleAuthClient? googleAuthClient,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _random = random ?? Random.secure(),
       _googleAuthClient = googleAuthClient ?? DefaultGoogleAuthClient();

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final Random _random;
  final GoogleAuthClient _googleAuthClient;

  bool get hasCurrentUser => _firebaseAuth.currentUser != null;
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  Future<void> signIn({required String email, required String password}) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<GoogleSignInOutcome> signInWithGoogle() {
    return GoogleAuthFlow(_googleAuthClient).run((identity) async {
      User? authenticatedUser;
      try {
        final credential = GoogleAuthProvider.credential(
          idToken: identity.idToken,
        );
        final userCredential = await _firebaseAuth.signInWithCredential(
          credential,
        );
        authenticatedUser = userCredential.user;
        if (authenticatedUser == null) {
          throw FirebaseAuthException(
            code: 'google-user-not-found',
            message: 'Google 로그인 결과에 사용자 정보가 없습니다.',
          );
        }

        await ensureCurrentUserProfile(
          providerEmail: identity.email,
          providerDisplayName: identity.displayName,
        );
      } catch (error, stackTrace) {
        if (authenticatedUser != null) {
          try {
            await _firebaseAuth.signOut();
          } catch (_) {
            // Preserve the profile/bootstrap failure.
          }
          try {
            await _googleAuthClient.signOut();
          } catch (_) {
            // The next login still retries the idempotent profile bootstrap.
          }
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  Future<void> ensureCurrentUserProfile({
    String? providerEmail,
    String? providerDisplayName,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: '현재 로그인한 사용자가 없습니다.',
      );
    }
    final email = AuthProfileDefaults.email(
      firebaseEmail: user.email,
      providerEmail: providerEmail,
    );
    final name = AuthProfileDefaults.name(
      displayName: user.displayName ?? providerDisplayName,
      email: email,
    );
    await _createUserDocuments(uid: user.uid, email: email, name: name);
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
        final userDocument = await transaction.get(userRef);
        if (userDocument.exists) {
          return true;
        }
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

  Future<void> updateCurrentUserAppleSubscription({
    required bool active,
    required String productId,
    String? purchaseId,
    String? transactionDate,
    required String verificationSource,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: '현재 로그인한 사용자가 없습니다.',
      );
    }
    await _firestore.collection('users').doc(user.uid).update({
      'isPro': active,
      'proSubscription': {
        'active': active,
        'platform': 'ios',
        'source': 'apple_store',
        'productId': productId,
        'purchaseId': purchaseId,
        'transactionDate': transactionDate,
        'verificationSource': verificationSource,
        'verificationMode': 'local_storekit_test',
        'updatedAt': FieldValue.serverTimestamp(),
      },
    });
  }

  Future<void> deactivateExpiredAppleSubscription() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    final reference = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final subscription = snapshot.data()?['proSubscription'];
      if (subscription is! Map || subscription['source'] != 'apple_store') {
        return;
      }
      transaction.update(reference, {
        'isPro': false,
        'proSubscription.active': false,
        'proSubscription.verificationMode': 'local_storekit_test',
        'proSubscription.updatedAt': FieldValue.serverTimestamp(),
      });
    });
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
    await FcmTokenService().unregisterCurrentToken();
    await _firebaseAuth.signOut();
    try {
      await _googleAuthClient.signOut();
    } catch (error, stackTrace) {
      debugPrint('[AuthService] Google signOut 정리 실패: $error\n$stackTrace');
    }
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
    final fcmTokens = await userDocument.collection('fcmTokens').get();
    final cleanup = _firestore.batch();
    for (final request in [...receivedRequests.docs, ...sentRequests.docs]) {
      cleanup.delete(request.reference);
    }
    for (final token in fcmTokens.docs) {
      cleanup.delete(token.reference);
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
