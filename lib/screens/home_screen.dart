import 'package:flutter/material.dart';

import '../widgets/section_title.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final List<WorkingOutFriend> workingOutFriends = const [
    WorkingOutFriend(
      name: '민수',
      status: '가슴 운동 · 42분째',
    ),
    WorkingOutFriend(
      name: '현우',
      status: '러닝 · 3.2km',
    ),
  ];

  final List<CompletedFriend> completedFriends = const [
    CompletedFriend(
      name: '준호',
      workoutTitle: '하체 운동 완료',
      detail: '1시간 18분 · 18세트',
      hasPhoto: true,
    ),
    CompletedFriend(
      name: '도윤',
      workoutTitle: '러닝 완료',
      detail: '32분 · 3.2km',
      hasPhoto: true,
    ),
  ];

  final List<RestingFriend> restingFriends = const [
    RestingFriend(
      name: '서연',
      restText: '2일째 쉬는 중',
    ),
    RestingFriend(
      name: '지훈',
      restText: '4일째 쉬는 중',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            const Text(
              'ShareFit',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '친구들의 운동 상태를 확인해보세요.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF666666),
              ),
            ),

            const SizedBox(height: 36),

            const SectionTitle(title: '현재 운동 중'),
            const SizedBox(height: 16),

            if (workingOutFriends.isEmpty)
              const _EmptyHomeCard(
                message: '운동 중인 친구가 없어요.',
              )
            else
              ...workingOutFriends.map(
                    (friend) => _WorkingOutCard(friend: friend),
              ),

            const SizedBox(height: 30),

            const SectionTitle(title: '오늘 운동 완료'),
            const SizedBox(height: 16),

            if (completedFriends.isEmpty)
              const _EmptyHomeCard(
                message: '운동 완료한 친구가 없어요.',
              )
            else
              ...completedFriends.map(
                    (friend) => _CompletedWorkoutCard(friend: friend),
              ),

            const SizedBox(height: 30),

            const SectionTitle(title: '오늘 운동 안 한 친구'),
            const SizedBox(height: 16),

            ...restingFriends.map(
                  (friend) => _RestingFriendCard(friend: friend),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultProfile extends StatelessWidget {
  const _DefaultProfile();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 26,
      backgroundColor: Color(0xFFE5E7EB),
      child: Icon(
        Icons.person_rounded,
        color: Color(0xFF9CA3AF),
        size: 30,
      ),
    );
  }
}

class _WorkingOutCard extends StatelessWidget {
  final WorkingOutFriend friend;

  const _WorkingOutCard({
    required this.friend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const _DefaultProfile(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  friend.status,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF5B5FFF),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Text(
              '운동 중',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedWorkoutCard extends StatelessWidget {
  final CompletedFriend friend;

  const _CompletedWorkoutCard({
    required this.friend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const _DefaultProfile(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  friend.workoutTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF111111),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  friend.detail,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _WorkoutPhotoThumb(hasPhoto: friend.hasPhoto),
        ],
      ),
    );
  }
}

class _WorkoutPhotoThumb extends StatelessWidget {
  final bool hasPhoto;

  const _WorkoutPhotoThumb({
    required this.hasPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: hasPhoto ? const Color(0xFFE6E7FF) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        hasPhoto ? Icons.image_rounded : Icons.image_not_supported_rounded,
        color: hasPhoto
            ? const Color(0xFF5B5FFF)
            : const Color(0xFFB8B8B8),
        size: 28,
      ),
    );
  }
}

class _RestingFriendCard extends StatelessWidget {
  final RestingFriend friend;

  const _RestingFriendCard({
    required this.friend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const _DefaultProfile(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  friend.restText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${friend.name}님을 깨웠습니다.',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A76),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: const Text(
                '깨우기',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _EmptyHomeCard extends StatelessWidget {
  final String message;

  const _EmptyHomeCard({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 24,
      ),
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

class WorkingOutFriend {
  final String name;
  final String status;

  const WorkingOutFriend({
    required this.name,
    required this.status,
  });
}

class CompletedFriend {
  final String name;
  final String workoutTitle;
  final String detail;
  final bool hasPhoto;

  const CompletedFriend({
    required this.name,
    required this.workoutTitle,
    required this.detail,
    required this.hasPhoto,
  });
}

class RestingFriend {
  final String name;
  final String restText;

  const RestingFriend({
    required this.name,
    required this.restText,
  });
}