import 'dart:async';

import 'package:flutter/material.dart';

import '../models/friend.dart';
import '../models/public_activity.dart';
import '../services/friend_service.dart';
import '../services/public_activity_service.dart';
import '../theme/app_theme.dart';
import '../widgets/section_title.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FriendService _friendService = FriendService();
  final PublicActivityService _activityService = PublicActivityService();
  final Map<String, PublicActivity> _activities = {};
  final Map<String, StreamSubscription<PublicActivity>> _activitySubscriptions =
      {};
  final Set<String> _expandedFriendIds = {};
  StreamSubscription<List<Friend>>? _friendsSubscription;
  Timer? _clock;
  List<Friend> _friends = const [];

  @override
  void initState() {
    super.initState();
    _friendsSubscription = _friendService.watchFriends().listen(
      _handleFriends,
      onError: (_) {
        if (mounted) setState(() => _friends = const []);
      },
    );
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted &&
          (_friends.any(
                (friend) => _activities[friend.uid]?.status == 'workingOut',
              ) ||
              _activities.values.any(
                (activity) => activity.photoUrl != null,
              ))) {
        setState(() {});
      }
    });
  }

  void _handleFriends(List<Friend> friends) {
    final ids = friends.map((friend) => friend.uid).toSet();
    for (final uid in _activitySubscriptions.keys.toList()) {
      if (!ids.contains(uid)) {
        _activitySubscriptions.remove(uid)?.cancel();
        _activities.remove(uid);
        _expandedFriendIds.remove(uid);
      }
    }
    for (final friend in friends) {
      _activitySubscriptions.putIfAbsent(
        friend.uid,
        () => _activityService
            .watchActivity(friend.uid)
            .listen(
              (activity) {
                if (mounted) setState(() => _activities[friend.uid] = activity);
              },
              onError: (_) {
                if (mounted) setState(() => _activities.remove(friend.uid));
              },
            ),
      );
    }
    if (mounted) setState(() => _friends = friends);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _friendsSubscription?.cancel();
    for (final subscription in _activitySubscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  bool _isToday(DateTime? value) {
    if (value == null) return false;
    final korea = value.toUtc().add(const Duration(hours: 9));
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    return korea.year == now.year &&
        korea.month == now.month &&
        korea.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final working = <Friend>[];
    final completed = <Friend>[];
    final resting = <Friend>[];
    for (final friend in _friends) {
      final activity = _activities[friend.uid];
      if (activity?.status == 'workingOut' && activity?.startedAt != null) {
        working.add(friend);
      } else if (_isToday(activity?.endedAt)) {
        completed.add(friend);
      } else {
        resting.add(friend);
      }
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Text(
              'ShareFit',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '친구들의 운동 상태를 확인해보세요.',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 36),
            const SectionTitle(title: '현재 운동 중'),
            const SizedBox(height: 16),
            if (working.isEmpty)
              const _EmptyHomeCard(message: '운동 중인 친구가 없어요.'),
            ...working.map(
              (friend) => _WorkingOutCard(
                friend: friend,
                activity: _activities[friend.uid]!,
              ),
            ),
            const SizedBox(height: 30),
            const SectionTitle(title: '오늘 운동 완료'),
            const SizedBox(height: 16),
            if (completed.isEmpty)
              const _EmptyHomeCard(message: '운동 완료한 친구가 없어요.'),
            ...completed.map((friend) {
              final expanded = _expandedFriendIds.contains(friend.uid);
              return _CompletedWorkoutCard(
                key: ValueKey(friend.uid),
                friend: friend,
                activity: _activities[friend.uid]!,
                expanded: expanded,
                onToggle: () => setState(() {
                  expanded
                      ? _expandedFriendIds.remove(friend.uid)
                      : _expandedFriendIds.add(friend.uid);
                }),
              );
            }),
            const SizedBox(height: 30),
            const SectionTitle(title: '오늘 운동 안 한 친구'),
            const SizedBox(height: 16),
            if (resting.isEmpty)
              const _EmptyHomeCard(message: '오늘 운동 안 한 친구가 없어요.'),
            ...resting.map(
              (friend) => _RestingFriendCard(
                friend: friend,
                activity: _activities[friend.uid],
              ),
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
  Widget build(BuildContext context) => const CircleAvatar(
    radius: 26,
    backgroundColor: Color(0xFFE5E7EB),
    child: Icon(Icons.person_rounded, color: Color(0xFF9CA3AF), size: 30),
  );
}

class _WorkingOutCard extends StatelessWidget {
  const _WorkingOutCard({required this.friend, required this.activity});
  final Friend friend;
  final PublicActivity activity;

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now()
        .difference(activity.startedAt!)
        .inMinutes
        .clamp(0, 1000000);
    final time = elapsed >= 60
        ? '${elapsed ~/ 60}시간 ${elapsed % 60}분째'
        : '$elapsed분째';
    final type = activity.workoutType == 'running' ? '러닝' : '근력 운동';
    return _BaseCard(
      child: Row(
        children: [
          const _DefaultProfile(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.profile.name, style: _nameStyle),
                const SizedBox(height: 5),
                Text('$type · $time', style: _subStyle),
              ],
            ),
          ),
          _pill('운동 중', Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }
}

class _CompletedWorkoutCard extends StatelessWidget {
  const _CompletedWorkoutCard({
    super.key,
    required this.friend,
    required this.activity,
    required this.expanded,
    required this.onToggle,
  });
  final Friend friend;
  final PublicActivity activity;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final strength = activity.strengthSummary;
    final running = activity.runningSummary;
    final photoUrl = activity.validPhotoUrl;
    final isRunning = activity.workoutType == 'running';
    final title = isRunning
        ? '러닝'
        : (strength?.bodyParts.isNotEmpty == true
              ? strength!.bodyParts.join(', ')
              : '근력 운동');
    return _BaseCard(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Column(
          children: [
            Row(
              children: [
                const _DefaultProfile(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(friend.profile.name, style: _nameStyle),
                      const SizedBox(height: 5),
                      Text(
                        '$title · ${_duration(activity.durationSeconds ?? 0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (photoUrl != null) _Photo(url: photoUrl),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tooltip: expanded ? '운동 정보 접기' : '운동 정보 펼치기',
                    onPressed: onToggle,
                    icon: Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 18),
              const Divider(height: 1, color: Color(0xFFE0E0E0)),
              const SizedBox(height: 16),
              if (!isRunning) ...[
                _detail('운동 부위', strength?.bodyParts.join(', ') ?? '-'),
                _detail('운동 시간', _duration(activity.durationSeconds ?? 0)),
                _detail('완료 세트', '${strength?.completedSetCount ?? 0}세트'),
                _detail('총 볼륨', '${_number(strength?.totalVolumeKg ?? 0)}kg'),
              ] else ...[
                _detail('운동 시간', _duration(activity.durationSeconds ?? 0)),
                _detail(
                  '거리',
                  '${((running?.distanceMeters ?? 0) / 1000).toStringAsFixed(2)}km',
                ),
                _detail('평균 페이스', _pace(running?.averagePaceSecondsPerKm)),
              ],
              if (photoUrl != null) ...[
                const SizedBox(height: 12),
                _Photo(url: photoUrl, large: true),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RestingFriendCard extends StatelessWidget {
  const _RestingFriendCard({required this.friend, required this.activity});
  final Friend friend;
  final PublicActivity? activity;
  @override
  Widget build(BuildContext context) => _BaseCard(
    child: Row(
      children: [
        const _DefaultProfile(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(friend.profile.name, style: _nameStyle),
              const SizedBox(height: 5),
              Text(_lastWorkout(activity?.lastWorkoutAt), style: _subStyle),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5A76),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: const Text(
              '깨우기',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    ),
  );
}

class _BaseCard extends StatelessWidget {
  const _BaseCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url, this.large = false});
  final String url;
  final bool large;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Image.network(
      url,
      width: large ? double.infinity : 66,
      height: large ? 180 : 66,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );
}

class _EmptyHomeCard extends StatelessWidget {
  const _EmptyHomeCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        color: context.secondaryForegroundFor(
          Theme.of(context).colorScheme.surfaceContainer,
        ),
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

const _nameStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w900);
const _subStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
Widget _pill(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(100),
  ),
  child: Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w900,
    ),
  ),
);
Widget _detail(String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    children: [
      Expanded(child: Text(label, style: _subStyle)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  ),
);
String _duration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return h > 0 ? '$h시간 $m분' : '$m분';
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
String _pace(double? seconds) => seconds == null
    ? '-'
    : '${seconds ~/ 60}\'${(seconds.round() % 60).toString().padLeft(2, '0')}"/km';
String _lastWorkout(DateTime? date) {
  if (date == null) return '아직 운동 기록 없음';
  final now = DateTime.now().toUtc().add(const Duration(hours: 9));
  final local = date.toUtc().add(const Duration(hours: 9));
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (today.difference(day).inDays == 1) return '마지막 운동: 어제';
  return '마지막 운동: ${local.month}월 ${local.day}일';
}
