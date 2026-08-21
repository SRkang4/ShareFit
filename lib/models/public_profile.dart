import 'package:cloud_firestore/cloud_firestore.dart';

import 'profile_customization.dart';

class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.name,
    required this.friendCode,
    required this.active,
    this.experienceStartDate,
    this.customization = ProfileCustomization.defaults,
  });

  final String uid;
  final String name;
  final String friendCode;
  final bool active;
  final DateTime? experienceStartDate;
  final ProfileCustomization customization;

  factory PublicProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return PublicProfile(
      uid: data['uid'] as String? ?? document.id,
      name: data['name'] as String? ?? '',
      friendCode: data['friendCode'] as String? ?? '',
      active: data['active'] == true,
      experienceStartDate: data['experienceStartDate'] is Timestamp
          ? (data['experienceStartDate'] as Timestamp).toDate()
          : null,
      customization: ProfileCustomization.fromPublicProfile(
        titleId: data['profileTitleId'],
        themeId: data['profileThemeId'],
      ),
    );
  }
}
