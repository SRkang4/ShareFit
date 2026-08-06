import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
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

      final friendCode = await _generateUniqueFriendCode();

      await _firestore.collection('users').doc(createdUser.uid).set({
        'uid': createdUser.uid,
        'email': email,
        'name': name,
        'friendCode': friendCode,
        'isPro': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
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

  Future<String> _generateUniqueFriendCode() async {
    while (true) {
      final friendCode = _createFriendCode();
      final existingUsers = await _firestore
          .collection('users')
          .where('friendCode', isEqualTo: friendCode)
          .limit(1)
          .get();

      if (existingUsers.docs.isEmpty) {
        return friendCode;
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

    await _firestore.collection('users').doc(user.uid).update({
      'name': name,
      'experienceStartDate': Timestamp.fromDate(experienceStartDate),
    });
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

    await userDocument.delete();

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
