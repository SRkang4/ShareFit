import 'dart:async';

import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../models/friend.dart';
import '../models/public_activity.dart';
import '../models/public_workout_activity.dart';
import '../services/friend_service.dart';
import '../services/public_activity_service.dart';
import '../services/public_workout_activity_service.dart';
import '../services/wake_up_service.dart';
import '../theme/app_theme.dart';
import '../theme/profile_card_theme.dart';
import '../widgets/sharefit_ui.dart';

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
  final WakeUpService _wakeUpService = WakeUpService();
  final Set<String> _sendingWakeUps = {};
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

  Future<void> _sendWakeUp(Friend friend) async {
    if (_sendingWakeUps.contains(friend.uid)) return;
    setState(() => _sendingWakeUps.add(friend.uid));
    try {
      await _wakeUpService.send(friend.uid);
      if (mounted) _showTopMessage('깨우기를 보냈습니다.');
    } on WakeUpException catch (error) {
      if (mounted) _showTopMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _sendingWakeUps.remove(friend.uid));
    }
  }

  void _showTopMessage(String message, {bool isError = false}) {
    final colors = Theme.of(context).colorScheme;
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: isError ? colors.error : colors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
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
          padding: const EdgeInsets.fromLTRB(20, 45, 20, 120),
          children: [
            Text(
              'ShareFit',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 41,
                height: 1.08,
                letterSpacing: -1.4,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              '친구들의 오늘 운동 상태를 한눈에 확인해보세요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            _HomeStatusSectionCard(
              title: '운동 중',
              count: working.length,
              children: [
                if (working.isEmpty)
                  const _EmptyHomeCard(message: '지금 운동 중인 친구가 없어요.'),
                ...working.map(
                  (friend) => _WorkingOutCard(
                    friend: friend,
                    activity: _activities[friend.uid]!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _HomeStatusSectionCard(
              title: '운동 완료',
              count: completed.length,
              children: [
                if (completed.isEmpty)
                  const _EmptyHomeCard(message: '오늘 운동을 마친 친구가 없어요.'),
                ...completed.map(
                  (friend) => _CompletedWorkoutCard(
                    key: ValueKey(friend.uid),
                    friend: friend,
                    workouts: _todayWorkoutsFor(friend),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _HomeStatusSectionCard(
              title: '운동 안 한 친구',
              count: resting.length,
              children: [
                if (resting.isEmpty)
                  const _EmptyHomeCard(message: '오늘 아직 운동 기록이 없는 친구가 없어요.'),
                ...resting.map(
                  (friend) => _RestingFriendCard(
                    friend: friend,
                    activity: _activities[friend.uid],
                    isSending: _sendingWakeUps.contains(friend.uid),
                    onWakeUp: () => _sendWakeUp(friend),
                  ),
                ),
              ],
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

class _HomeStatusSectionCard extends StatelessWidget {
  const _HomeStatusSectionCard({
    required this.title,
    required this.count,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return ShareFitCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 21,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$count명',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
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
  final Set<String> _expandedWorkoutIds = {};
  int _page = 0;

  @override
  void didUpdateWidget(covariant _CompletedWorkoutCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= widget.workouts.length) {
      _page = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    }
    final workoutIds = widget.workouts.map((workout) => workout.workoutId);
    _expandedWorkoutIds.retainAll(workoutIds);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentWorkout = widget.workouts[_page];
    final hasPhoto = currentWorkout.validPhotoUrl != null;
    final pageHeight = hasPhoto ? 286.0 : 120.0;
    final isStrength = currentWorkout.type == 'strength';
    final isExpanded =
        isStrength && _expandedWorkoutIds.contains(currentWorkout.workoutId);
    void toggleExpanded() {
      if (!isStrength) return;
      setState(() {
        if (!_expandedWorkoutIds.add(currentWorkout.workoutId)) {
          _expandedWorkoutIds.remove(currentWorkout.workoutId);
        }
      });
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isStrength ? toggleExpanded : null,
      child: _BaseCard(
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: pageHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.workouts.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) => _CompletedWorkoutPage(
                  key: ValueKey(widget.workouts[index].workoutId),
                  workout: widget.workouts[index],
                  isExpanded: _expandedWorkoutIds.contains(
                    widget.workouts[index].workoutId,
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? _StrengthExerciseDetails(
                      key: ValueKey(currentWorkout.workoutId),
                      exercises:
                          currentWorkout.strengthSummary?.exercises ?? const [],
                    )
                  : const SizedBox.shrink(),
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
      ),
    );
  }
}

class _CompletedWorkoutPage extends StatelessWidget {
  const _CompletedWorkoutPage({
    super.key,
    required this.workout,
    required this.isExpanded,
  });

  final PublicWorkoutActivity workout;
  final bool isExpanded;

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
        Row(
          children: [
            Expanded(
              child: Text(
                '$title · ${_duration(workout.durationSeconds)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (!isRunning)
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
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

class _StrengthExerciseDetails extends StatelessWidget {
  const _StrengthExerciseDetails({super.key, required this.exercises});

  final List<PublicStrengthExercise> exercises;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visibleExercises = exercises
        .where(
          (exercise) => exercise.name.isNotEmpty && exercise.sets.isNotEmpty,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Divider(height: 1, color: colors.outline),
        const SizedBox(height: 16),
        if (visibleExercises.isEmpty)
          Text(
            '상세 세트 기록이 없어요.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          for (
            var exerciseIndex = 0;
            exerciseIndex < visibleExercises.length;
            exerciseIndex++
          ) ...[
            if (exerciseIndex > 0) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 14),
            ],
            Text(
              visibleExercises[exerciseIndex].name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _setRow(context, '세트', '무게', '횟수', isHeader: true),
            const SizedBox(height: 6),
            for (
              var setIndex = 0;
              setIndex < visibleExercises[exerciseIndex].sets.length;
              setIndex++
            )
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _setRow(
                  context,
                  '${setIndex + 1}세트',
                  '${_number(visibleExercises[exerciseIndex].sets[setIndex].weightKg)}kg',
                  '${visibleExercises[exerciseIndex].sets[setIndex].reps}회',
                ),
              ),
          ],
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _setRow(
    BuildContext context,
    String set,
    String weight,
    String reps, {
    bool isHeader = false,
  }) {
    final style = TextStyle(
      color: isHeader
          ? Theme.of(context).colorScheme.onSurfaceVariant
          : Theme.of(context).colorScheme.onSurface,
      fontSize: isHeader ? 12 : 13,
      fontWeight: isHeader ? FontWeight.w600 : FontWeight.w700,
    );
    return Row(
      children: [
        Expanded(child: Text(set, style: style)),
        Expanded(
          child: Text(weight, textAlign: TextAlign.center, style: style),
        ),
        Expanded(
          child: Text(reps, textAlign: TextAlign.end, style: style),
        ),
      ],
    );
  }
}

class _RestingFriendCard extends StatelessWidget {
  const _RestingFriendCard({
    required this.friend,
    required this.activity,
    required this.isSending,
    required this.onWakeUp,
  });
  final Friend friend;
  final PublicActivity? activity;
  final bool isSending;
  final VoidCallback onWakeUp;
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
            onPressed: isSending ? null : onWakeUp,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: isSending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
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
        borderRadius: BorderRadius.circular(20),
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
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
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
