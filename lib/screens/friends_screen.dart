import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final Color pointColor = const Color(0xFF5B5FFF);
  final TextEditingController friendCodeController = TextEditingController();
  final AuthService _authService = AuthService();

  final int maxFreeFriends = 5;
  String selectedTab = '내 친구';

  final List<FriendData> friends = [];
  final List<FriendRequestData> receivedRequests = [];
  final List<FriendRequestData> sentRequests = [];
  late final Future<Map<String, dynamic>?> _currentUserData;

  @override
  void initState() {
    super.initState();
    _currentUserData = _authService.getCurrentUserData();
  }

  @override
  void dispose() {
    friendCodeController.dispose();
    super.dispose();
  }

  void showAddFriendDialog() {
    friendCodeController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '친구 추가',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '친구 코드를 입력해 요청을 보내세요.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: friendCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: '예: A1234567',
                    filled: true,
                    fillColor: const Color(0xFFF4F5F7),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF666666),
                            side: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: pointColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            '요청',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void removeFriend(int index) {
    setState(() {
      friends.removeAt(index);
    });
  }

  void acceptRequest(int index) {
    setState(() {
      final request = receivedRequests.removeAt(index);

      if (friends.length < maxFreeFriends) {
        friends.add(
          FriendData(
            displayName: request.displayName,
            career: request.career,
          ),
        );
      }
    });
  }

  void rejectRequest(int index) {
    setState(() {
      receivedRequests.removeAt(index);
    });
  }

  void cancelSentRequest(int index) {
    setState(() {
      sentRequests.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLimitReached = friends.length >= maxFreeFriends;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '친구',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111111),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: isLimitReached ? null : showAddFriendDialog,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isLimitReached
                          ? const Color(0xFFE4E7EC)
                          : pointColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: isLimitReached
                          ? const Color(0xFF999999)
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            _buildTabSelector(),

            const SizedBox(height: 24),

            if (selectedTab == '내 친구')
              _buildMyFriendsTab(isLimitReached)
            else
              _buildFriendRequestsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _FriendTabButton(
            title: '내 친구',
            selected: selectedTab == '내 친구',
            pointColor: pointColor,
            onTap: () {
              setState(() {
                selectedTab = '내 친구';
              });
            },
          ),
          _FriendTabButton(
            title: '친구 요청',
            selected: selectedTab == '친구 요청',
            pointColor: pointColor,
            onTap: () {
              setState(() {
                selectedTab = '친구 요청';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMyFriendsTab(bool isLimitReached) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${friends.length} / $maxFreeFriends 친구 사용 중',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),

        if (isLimitReached)
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F4),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Text(
              '무료 버전은 친구 5명까지 추가할 수 있어요.',
              style: TextStyle(
                color: Color(0xFFFF5A76),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

        if (friends.isEmpty)
          const _EmptyFriendsCard(message: '아직 친구가 없어요.'),

        ...List.generate(
          friends.length,
              (index) => _FriendCard(
            friend: friends[index],
            onDelete: () => removeFriend(index),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendRequestsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFriendCodeCard(),

        const SizedBox(height: 26),

        _buildRequestSectionTitle(
          '받은 요청',
          receivedRequests.length,
        ),

        const SizedBox(height: 14),

        ...List.generate(
          receivedRequests.length,
              (index) => _ReceivedRequestCard(
            request: receivedRequests[index],
            onAccept: () => acceptRequest(index),
            onReject: () => rejectRequest(index),
          ),
        ),

        const SizedBox(height: 26),

        _buildRequestSectionTitle(
          '보낸 요청',
          sentRequests.length,
        ),

        const SizedBox(height: 14),

        ...List.generate(
          sentRequests.length,
              (index) => _SentRequestCard(
            request: sentRequests[index],
            onCancel: () => cancelSentRequest(index),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendCodeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Text(
            '내 친구 코드',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          FutureBuilder<Map<String, dynamic>?>(
            future: _currentUserData,
            builder: (context, snapshot) {
              final friendCode = snapshot.data?['friendCode'] as String?;
              return Text(
                friendCode ?? (snapshot.hasError ? '불러오기 실패' : '불러오는 중'),
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF111111),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.copy_rounded,
            color: pointColor,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestSectionTitle(String title, int count) {
    return Text(
      '$title ($count)',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: Color(0xFF111111),
      ),
    );
  }
}

class _EmptyFriendsCard extends StatelessWidget {
  final String message;

  const _EmptyFriendsCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF777777),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FriendTabButton extends StatelessWidget {
  final String title;
  final bool selected;
  final Color pointColor;
  final VoidCallback onTap;

  const _FriendTabButton({
    required this.title,
    required this.selected,
    required this.pointColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? pointColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF666666),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final FriendData friend;
  final VoidCallback onDelete;

  const _FriendCard({
    required this.friend,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseUserCard(
      name: friend.displayName,
      career: friend.career,
      trailing: TextButton(
        onPressed: onDelete,
        child: const Text(
          '삭제',
          style: TextStyle(
            color: Color(0xFFFF5A76),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ReceivedRequestCard extends StatelessWidget {
  final FriendRequestData request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ReceivedRequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseUserCard(
      name: request.displayName,
      career: request.career,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: onReject,
            child: const Text(
              '거절',
              style: TextStyle(
                color: Color(0xFF999999),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: onAccept,
            child: const Text(
              '수락',
              style: TextStyle(
                color: Color(0xFF5B5FFF),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SentRequestCard extends StatelessWidget {
  final FriendRequestData request;
  final VoidCallback onCancel;

  const _SentRequestCard({
    required this.request,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseUserCard(
      name: request.displayName,
      career: '요청 대기중',
      trailing: TextButton(
        onPressed: onCancel,
        child: const Text(
          '취소',
          style: TextStyle(
            color: Color(0xFFFF5A76),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BaseUserCard extends StatelessWidget {
  final String name;
  final String career;
  final Widget trailing;

  const _BaseUserCard({
    required this.name,
    required this.career,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFF5B5FFF),
            child: Text(
              name.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  career,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class FriendData {
  final String displayName;
  final String career;

  FriendData({
    required this.displayName,
    required this.career,
  });
}

class FriendRequestData {
  final String displayName;
  final String career;

  FriendRequestData({
    required this.displayName,
    required this.career,
  });
}
