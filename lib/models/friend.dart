import 'public_profile.dart';

class Friend {
  const Friend({
    required this.uid,
    required this.requestId,
    required this.profile,
  });

  final String uid;
  final String requestId;
  final PublicProfile profile;
}
