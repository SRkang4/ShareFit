import 'dart:async';

import 'package:flutter/material.dart';

import '../models/friend.dart';
import '../models/public_activity.dart';
import '../models/public_workout_activity.dart';
import '../services/friend_service.dart';
import '../services/public_activity_service.dart';
import '../services/public_workout_activity_service.dart';
import '../theme/app_theme.dart';
import '../theme/profile_card_theme.dart';
import '../widgets/section_title.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FriendService _friendService = FriendService();
  final PublicActivityService _activityService = PublicActivityService();
  final PublicWorkoutActivityService _publicWorkoutActivityService =
      PublicWorkoutActivityService();
  final Map<String, PublicActivity> _activities = {};
  final Map<String, List<PublicWorkoutActivity>> _publicWorkouts = {};
  final Map<String, StreamSubscription<PublicActivity>> _activitySubscriptions =
      {};
  final Map<String, StreamSubscription<List<PublicWorkoutActivity>>>
  _publicWorkoutSubscriptions = {};
  StreamSubscription<List<Friend>>? _friendsSubscription;
  Timer? _clock;
  List<Friend> _friends = const [];
  late String _todayDateKey;

  @override
  void initState() {
    super.initState();
    _todayDateKey = PublicWorkoutActivityService.seoulDateKey(DateTime.now());
    _friendsSubscription = _friendService.watchFriends().listen(
      _handleFriends,
      onError: (_) {
        if (mounted) setState(() => _friends = const []);
      },
    );
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      final currentDateKey = PublicWorkoutActivityService.seoulDateKey(
        DateTime.now(),
      );
      if (currentDateKey != _todayDateKey) {
        _todayDateKey = currentDateKey;
        _restartPublicWorkoutSubscriptions();
        return;
      }
      if (mounted &&
          (_friends.any(
                (friend) => _activities[friend.uid]?.status == 'workingOut',
              ) ||
              _activities.values.any((activity) => activity.photoUrl != null) ||
              _publicWorkouts.values.any(
                (workouts) =>
                    workouts.any((workout) => workout.photoUrl != null),
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
        _publicWorkoutSubscriptions.remove(uid)?.cancel();
        _activities.remove(uid);
        _publicWorkouts.remove(uid);
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
      _subscribeToPublicWorkouts(friend.uid);
    }
    if (mounted) setState(() => _friends = friends);
  }

  void _subscribeToPublicWorkouts(String uid) {
    _publicWorkoutSubscriptions.putIfAbsent(
      uid,
      () => _publicWorkoutActivityService
          .watchToday(uid)
          .listen(
            (workouts) {
              if (mounted) setState(() => _publicWorkouts[uid] = workouts);
            },
            onError: (_) {
              if (mounted) setState(() => _publicWorkouts.remove(uid));
            },
          ),
    );
  }

  void _restartPublicWorkoutSubscriptions() {
    for (final subscription in _publicWorkoutSubscriptions.values) {
      subscription.cancel();
    }
    _publicWorkoutSubscriptions.clear();
    _publicWorkouts.clear();
    for (final friend in _friends) {
      _subscribeToPublicWorkouts(friend.uid);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clock?.cancel();
    _friendsSubscription?.cancel();
    for (final subscription in _activitySubscriptions.values) {
      subscription.cancel();
    }
    for (final subscription in _publicWorkoutSubscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  List<PublicWorkoutActivity> _todayWorkoutsFor(Friend friend) {
    final publicWorkouts = _publicWorkouts[friend.uid] ?? const [];
    if (publicWorkouts.isNotEmpty) return publicWorkouts;
    final activity = _activities[friend.uid];
    if (_isToday(activity?.endedAt)) {
      return [PublicWorkoutActivity.fromLegacy(activity!)];
    }
    return const [];
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
      } else if (_todayWorkoutsFor(friend).isNotEmpty) {
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
              return _CompletedWorkoutCard(
                key: ValueKey(friend.uid),
                friend: friend,
                workouts: _todayWorkoutsFor(friend),
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
      friend: friend,
      child: Row(
        children: [
          const _DefaultProfile(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FriendIdentity(friend: friend),
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

class _CompletedWorkoutCard extends StatefulWidget {
  const _CompletedWorkoutCard({
    super.key,
    required this.friend,
    required this.workouts,
  });
  final Friend friend;
  final List<PublicWorkoutActivity> workouts;

  @override
  State<_CompletedWorkoutCard> createState() => _CompletedWorkoutCardState();
}

class _CompletedWorkoutCardState extends State<_CompletedWorkoutCard> {
  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void didUpdateWidget(covariant _CompletedWorkoutCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= widget.workouts.length) {
      _page = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.workouts.any(
      (workout) => workout.validPhotoUrl != null,
    );
    final pageHeight = hasPhoto ? 286.0 : 120.0;
    return _BaseCard(
      friend: widget.friend,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _DefaultProfile(),
              const SizedBox(width: 16),
              Expanded(child: _FriendIdentity(friend: widget.friend)),
              _pill(
                '오늘 ${widget.workouts.length}회',
                Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          SizedBox(
            height: pageHeight,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.workouts.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) => _CompletedWorkoutPage(
                key: ValueKey(widget.workouts[index].workoutId),
                workout: widget.workouts[index],
              ),
            ),
          ),
          if (widget.workouts.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.workouts.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == _page ? 8 : 6,
                  height: index == _page ? 8 : 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == _page
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletedWorkoutPage extends StatelessWidget {
  const _CompletedWorkoutPage({super.key, required this.workout});

  final PublicWorkoutActivity workout;

  @override
  Widget build(BuildContext context) {
    final strength = workout.strengthSummary;
    final running = workout.runningSummary;
    final photoUrl = workout.validPhotoUrl;
    final isRunning = workout.type == 'running';
    final title = isRunning
        ? '러닝'
        : (strength?.bodyParts.isNotEmpty == true
              ? strength!.bodyParts.join(', ')
              : '근력 운동');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title · ${_duration(workout.durationSeconds)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (isRunning) ...[
          _detail(
            '거리',
            '${((running?.distanceMeters ?? 0) / 1000).toStringAsFixed(2)}km',
          ),
          _detail('평균 페이스', _pace(running?.averagePaceSecondsPerKm)),
        ] else ...[
          _detail('완료 세트', '${strength?.completedSetCount ?? 0}세트'),
          _detail('총 볼륨', '${_number(strength?.totalVolumeKg ?? 0)}kg'),
        ],
        if (photoUrl != null) ...[
          const SizedBox(height: 8),
          _Photo(url: photoUrl, large: true),
        ],
      ],
    );
  }
}

class _RestingFriendCard extends StatelessWidget {
  const _RestingFriendCard({required this.friend, required this.activity});
  final Friend friend;
  final PublicActivity? activity;
  @override
  Widget build(BuildContext context) => _BaseCard(
    friend: friend,
    child: Row(
      children: [
        const _DefaultProfile(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FriendIdentity(friend: friend),
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
  const _BaseCard({required this.friend, required this.child});
  final Friend friend;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final profilePalette = ProfileCardPalette.resolve(
      context,
      friend.profile.customization.themeId,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: profilePalette.border),
      ),
      child: child,
    );
  }
}

class _FriendIdentity extends StatelessWidget {
  const _FriendIdentity({required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context) {
    final title = friend.profile.customization.titleLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(friend.profile.name, style: _nameStyle),
        if (title != null) ...[
          const SizedBox(height: 3),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
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
