import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/profile_customization.dart';

class ProfileCustomizationException implements Exception {
  const ProfileCustomizationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileCustomizationService {
  ProfileCustomizationService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  Future<void> save(ProfileCustomization customization) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const ProfileCustomizationException('로그인이 필요합니다.');
    }
    if (!ProfileTitleIds.isValid(customization.titleId) ||
        !ProfileThemeIds.isValid(customization.themeId)) {
      throw const ProfileCustomizationException('선택한 프로필 설정을 확인해주세요.');
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    final userDocument = await userRef.get();
    if (!userDocument.exists) {
      throw const ProfileCustomizationException('사용자 정보를 찾을 수 없습니다.');
    }
    if (userDocument.data()?['isPro'] != true) {
      throw const ProfileCustomizationException('Pro 사용자만 이용할 수 있어요.');
    }

    final publicProfileRef = _firestore
        .collection('publicProfiles')
        .doc(user.uid);
    final batch = _firestore.batch();
    batch.update(userRef, {
      'profileCustomization': customization.toFirestore(),
    });
    batch.update(publicProfileRef, {
      'profileTitleId': customization.titleId,
      'profileThemeId': customization.themeId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
