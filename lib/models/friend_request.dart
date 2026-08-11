import 'public_profile.dart';

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
    required this.profile,
  });

  final String id;
  final String fromUid;
  final String toUid;
  final String status;
  final PublicProfile profile;
}
