import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../models/workout_record.dart';
import '../services/location_tracking_service.dart';
import '../services/workout_service.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with WidgetsBindingObserver {
  final Color pointColor = const Color(0xFF5B5FFF);
  final Color subPointColor = const Color(0xFF7C82FF);

  String selectedWorkoutType = '헬스';
  bool isWorkoutStarted = false;
  bool isWorkoutFinished = false;

  final List<String> bodyParts = ['가슴', '등', '어깨', '하체', '이두', '삼두'];
  final Set<String> selectedBodyParts = {};

  final List<ExerciseCardData> exercises = [ExerciseCardData()];
  final List<FinishedWorkoutSummary> finishedWorkouts = [];
  final TextEditingController runningGoalController = TextEditingController();
  final LocationTrackingService locationTrackingService =
      LocationTrackingService();
  final WorkoutService workoutService = WorkoutService();
  double runningDistanceMeters = 0.0;
  Position? lastRunningPosition;
  int validRunningLocationCount = 0;
  Timer? timer;
  Timer? weakGpsTimer;
  int seconds = 0;
  bool isPaused = false;
  bool isStartingWorkout = false;
  bool isChangingPauseState = false;
  bool isFinishingWorkout = false;
  bool hasShownWeakGpsMessage = false;
  DateTime? workoutStartedAt;
  String? lastErrorMessage;
  DateTime? lastErrorShownAt;

  double get runningDistanceKm => runningDistanceMeters / 1000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    weakGpsTimer?.cancel();
    unawaited(locationTrackingService.dispose());
    runningGoalController.dispose();
    for (final exercise in exercises) {
      exercise.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused) &&
        isWorkoutStarted &&
        selectedWorkoutType == '러닝' &&
        !isPaused) {
      setState(() {
        isPaused = true;
      });
      unawaited(_stopRunningLocationTracking());
    }
  }

  Future<void> startWorkout() async {
    if (isStartingWorkout) {
      return;
    }

    if (selectedWorkoutType == '러닝') {
      setState(() {
        isStartingWorkout = true;
      });
      runningDistanceMeters = 0.0;
      lastRunningPosition = null;
      validRunningLocationCount = 0;

      try {
        await _startRunningLocationTracking();
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showLocationError(error);
        setState(() {
          isStartingWorkout = false;
        });
        return;
      }

      if (!mounted) {
        await locationTrackingService.stop();
        return;
      }
    }

    setState(() {
      if (isWorkoutFinished) {
        resetCurrentWorkout();
        isWorkoutFinished = false;
      }

      isWorkoutStarted = true;
      isPaused = false;
      seconds = 0;
      workoutStartedAt = DateTime.now();
      if (selectedWorkoutType != '러닝') {
        runningDistanceMeters = 0.0;
        lastRunningPosition = null;
        validRunningLocationCount = 0;
      }
      isStartingWorkout = false;
    });

    _startActiveTimer();
  }

  void increaseRunningGoal() {
    final current = double.tryParse(runningGoalController.text) ?? 0;

    setState(() {
      runningGoalController.text = (current + 1).toStringAsFixed(0);
    });
  }

  void decreaseRunningGoal() {
    final current = double.tryParse(runningGoalController.text) ?? 0;

    if (current <= 1) return;

    setState(() {
      runningGoalController.text = (current - 1).toStringAsFixed(0);
    });
  }

  Future<void> togglePause() async {
    if (isChangingPauseState) {
      return;
    }

    if (selectedWorkoutType != '러닝') {
      setState(() {
        isPaused = !isPaused;
      });
      return;
    }

    isChangingPauseState = true;

    if (!isPaused) {
      setState(() {
        isPaused = true;
      });
      await _stopRunningLocationTracking();
      isChangingPauseState = false;
      return;
    }

    try {
      await _startRunningLocationTracking();
    } catch (error) {
      if (mounted) {
        _showLocationError(error);
      }
      isChangingPauseState = false;
      return;
    }

    if (!mounted) {
      await locationTrackingService.stop();
      return;
    }
    setState(() {
      isPaused = false;
    });
    isChangingPauseState = false;
  }

  Future<void> finishWorkout() async {
    if (isFinishingWorkout) {
      return;
    }

    final endedAt = DateTime.now();
    final durationSeconds = seconds;
    late final WorkoutRecord workoutRecord;

    try {
      workoutRecord = _createWorkoutRecord(
        endedAt: endedAt,
        durationSeconds: durationSeconds,
      );
    } on WorkoutValidationException catch (error) {
      _showError(error.message);
      return;
    } catch (_) {
      _showError('운동 기록을 확인해주세요.');
      return;
    }

    final wasPaused = isPaused;
    setState(() {
      isFinishingWorkout = true;
      isPaused = true;
    });
    timer?.cancel();

    if (selectedWorkoutType == '러닝') {
      try {
        await _stopRunningLocationTracking();
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          isFinishingWorkout = false;
          isPaused = true;
        });
        _showError('위치 추적을 종료하지 못했습니다. 잠시 후 다시 시도해주세요.');
        return;
      }
      if (!mounted) {
        return;
      }
    }

    try {
      await workoutService.saveCompletedWorkout(workoutRecord);
    } catch (_) {
      if (!mounted) {
        return;
      }

      var resumed = wasPaused;
      if (!wasPaused) {
        if (selectedWorkoutType == '러닝') {
          try {
            await _startRunningLocationTracking();
            resumed = true;
          } catch (error) {
            resumed = false;
            if (mounted) {
              _showLocationError(error);
            }
          }
        } else {
          resumed = true;
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        isFinishingWorkout = false;
        isPaused = wasPaused || !resumed;
      });
      if (!isPaused) {
        _startActiveTimer();
      }
      _showError('운동 기록을 저장하지 못했습니다. 다시 시도해주세요.');
      return;
    }

    final strength = workoutRecord.strength;
    final running = workoutRecord.running;
    final averagePace = running?.averagePaceSecondsPerKm;

    setState(() {
      finishedWorkouts.insert(
        0,
        FinishedWorkoutSummary(
          workoutType: selectedWorkoutType,
          duration: _formatDuration(durationSeconds),
          exerciseCount: strength?.exercises.length ?? 0,
          totalSets: strength?.completedSetCount ?? 0,
          runningDistance: (running?.distanceMeters ?? 0) / 1000,
          runningPace: averagePace == null ? '-' : _formatPace(averagePace),
        ),
      );
      isWorkoutStarted = false;
      isPaused = false;
      isWorkoutFinished = true;
      isFinishingWorkout = false;
      workoutStartedAt = null;
    });
  }

  WorkoutRecord _createWorkoutRecord({
    required DateTime endedAt,
    required int durationSeconds,
  }) {
    final userId = workoutService.currentUserId;
    if (userId == null) {
      throw const WorkoutValidationException('로그인 정보를 확인해주세요.');
    }

    final startedAt =
        workoutStartedAt ??
        endedAt.subtract(Duration(seconds: durationSeconds));

    if (selectedWorkoutType == '헬스') {
      final strength = _createStrengthWorkoutData();
      return WorkoutRecord(
        userId: userId,
        type: 'strength',
        startedAt: startedAt,
        endedAt: endedAt,
        durationSeconds: durationSeconds,
        strength: strength,
      );
    }

    final targetDistanceKm =
        double.tryParse(runningGoalController.text.trim()) ?? 0;
    if (!targetDistanceKm.isFinite || targetDistanceKm < 0) {
      throw const WorkoutValidationException('목표 거리를 올바르게 입력해주세요.');
    }
    final averagePaceSecondsPerKm = runningDistanceMeters > 0
        ? durationSeconds / (runningDistanceMeters / 1000)
        : null;

    return WorkoutRecord(
      userId: userId,
      type: 'running',
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: durationSeconds,
      running: RunningWorkoutData(
        targetDistanceMeters: targetDistanceKm * 1000,
        distanceMeters: runningDistanceMeters,
        acceptedLocationCount: validRunningLocationCount,
        averagePaceSecondsPerKm: averagePaceSecondsPerKm,
      ),
    );
  }

  StrengthWorkoutData _createStrengthWorkoutData() {
    final savedExercises = <StrengthExerciseData>[];
    var completedSetCount = 0;
    var totalVolumeKg = 0.0;

    for (final exercise in exercises) {
      final completedSets = exercise.sets.where((set) => set.isDone).toList();
      if (completedSets.isEmpty) {
        continue;
      }

      final exerciseName = exercise.exerciseNameController.text.trim();
      if (exerciseName.isEmpty) {
        throw const WorkoutValidationException('완료한 세트의 운동 종목을 입력해주세요.');
      }

      final savedSets = <StrengthSetData>[];
      for (final set in completedSets) {
        final weightText = set.weightController.text.trim();
        final repsText = set.repsController.text.trim();
        if (weightText.isEmpty || repsText.isEmpty) {
          throw const WorkoutValidationException('완료한 세트의 무게와 횟수를 입력해주세요.');
        }

        final weightKg = double.tryParse(weightText);
        final reps = int.tryParse(repsText);
        if (weightKg == null ||
            !weightKg.isFinite ||
            weightKg < 0 ||
            reps == null ||
            reps < 1) {
          throw const WorkoutValidationException(
            '무게는 0 이상, 횟수는 1 이상의 숫자로 입력해주세요.',
          );
        }

        savedSets.add(StrengthSetData(weightKg: weightKg, reps: reps));
        completedSetCount++;
        totalVolumeKg += weightKg * reps;
      }

      savedExercises.add(
        StrengthExerciseData(name: exerciseName, sets: savedSets),
      );
    }

    return StrengthWorkoutData(
      bodyParts: bodyParts
          .where((bodyPart) => selectedBodyParts.contains(bodyPart))
          .toList(),
      exercises: savedExercises,
      completedSetCount: completedSetCount,
      totalVolumeKg: totalVolumeKg,
    );
  }

  void _startActiveTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || isPaused) {
        return;
      }
      setState(() {
        seconds++;
      });
    });
  }

  String _formatDuration(int durationSeconds) {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  String _formatPace(double paceSecondsPerKm) {
    final totalSeconds = paceSecondsPerKm.round();
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return '$min\'${sec.toString().padLeft(2, '0')}"';
  }

  Future<void> _startRunningLocationTracking() async {
    lastRunningPosition = null;
    hasShownWeakGpsMessage = false;

    try {
      await locationTrackingService.start(
        onPosition: _handleRunningPosition,
        onError: _handleRunningLocationError,
      );
      if (lastRunningPosition == null) {
        _scheduleWeakGpsWarning();
      }
    } catch (_) {
      weakGpsTimer?.cancel();
      rethrow;
    }
  }

  Future<void> _stopRunningLocationTracking() async {
    weakGpsTimer?.cancel();
    lastRunningPosition = null;
    await locationTrackingService.stop();
  }

  void _handleRunningPosition(Position position) {
    if (!mounted || isPaused || selectedWorkoutType != '러닝') {
      return;
    }

    final now = DateTime.now();
    if (position.accuracy < 0 || position.accuracy > 25) {
      _scheduleWeakGpsWarning();
      return;
    }
    if (now.difference(position.timestamp) > const Duration(seconds: 10)) {
      _scheduleWeakGpsWarning();
      return;
    }

    final previousPosition = lastRunningPosition;
    if (previousPosition == null) {
      weakGpsTimer?.cancel();
      setState(() {
        lastRunningPosition = position;
        validRunningLocationCount++;
      });
      return;
    }

    if (!position.timestamp.isAfter(previousPosition.timestamp)) {
      return;
    }

    final segmentMeters = Geolocator.distanceBetween(
      previousPosition.latitude,
      previousPosition.longitude,
      position.latitude,
      position.longitude,
    );
    if (segmentMeters < 3) {
      return;
    }

    final elapsedSeconds =
        position.timestamp
            .difference(previousPosition.timestamp)
            .inMilliseconds /
        1000;
    if (elapsedSeconds <= 0 || segmentMeters / elapsedSeconds >= 12) {
      _scheduleWeakGpsWarning();
      return;
    }

    weakGpsTimer?.cancel();
    setState(() {
      runningDistanceMeters += segmentMeters;
      lastRunningPosition = position;
      validRunningLocationCount++;
    });
  }

  void _handleRunningLocationError(Object error) {
    if (!mounted) {
      return;
    }

    if (isWorkoutStarted && !isPaused) {
      setState(() {
        isPaused = true;
      });
    }
    unawaited(_stopRunningLocationTracking());
    _showLocationError(error);
  }

  void _scheduleWeakGpsWarning() {
    if (hasShownWeakGpsMessage || weakGpsTimer?.isActive == true) {
      return;
    }

    weakGpsTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || isPaused || selectedWorkoutType != '러닝') {
        return;
      }
      hasShownWeakGpsMessage = true;
      _showError('GPS 신호가 약합니다. 하늘이 잘 보이는 곳에서 다시 시도해주세요.');
    });
  }

  void _showLocationError(Object error) {
    if (error is LocationTrackingException) {
      switch (error.type) {
        case LocationTrackingFailureType.serviceDisabled:
          _showError('위치 서비스가 꺼져 있습니다. 기기 설정에서 GPS를 켜주세요.');
          return;
        case LocationTrackingFailureType.permissionDenied:
          _showError('러닝 거리 측정을 위해 위치 권한이 필요합니다.');
          return;
        case LocationTrackingFailureType.permissionDeniedForever:
          _showError('위치 권한이 영구적으로 거부되었습니다. 앱 설정에서 위치 권한을 허용해주세요.');
          return;
        case LocationTrackingFailureType.positionUnavailable:
          _showError('위치 정보를 가져오지 못했습니다. 잠시 후 다시 시도해주세요.');
          return;
      }
    }

    _showError('위치 정보를 가져오지 못했습니다. 잠시 후 다시 시도해주세요.');
  }

  void _showError(String message) {
    final now = DateTime.now();
    if (lastErrorMessage == message &&
        lastErrorShownAt != null &&
        now.difference(lastErrorShownAt!) < const Duration(seconds: 2)) {
      return;
    }
    lastErrorMessage = message;
    lastErrorShownAt = now;

    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: pointColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      displayDuration: const Duration(seconds: 2),
    );
  }

  Future<void> pickWorkoutImage(FinishedWorkoutSummary workout) async {
    final picker = ImagePicker();

    final pickedImage = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedImage == null) return;

    setState(() {
      workout.imageFile = File(pickedImage.path);
    });
  }

  void resetCurrentWorkout() {
    for (final exercise in exercises) {
      exercise.dispose();
    }

    exercises
      ..clear()
      ..add(ExerciseCardData());

    selectedBodyParts.clear();
  }

  void addExerciseCard() {
    setState(() {
      exercises.add(ExerciseCardData());
    });
  }

  void removeExerciseCard() {
    if (exercises.length <= 1) return;

    setState(() {
      final removed = exercises.removeLast();
      removed.dispose();
    });
  }

  String get formattedTime {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          children: [
            _buildHeader(),
            const SizedBox(height: 26),

            if (!isWorkoutStarted) ...[
              ...finishedWorkouts.map(
                (workout) => _buildFinishedWorkoutCard(workout),
              ),

              if (finishedWorkouts.isNotEmpty) const SizedBox(height: 30),

              _buildWorkoutTypeSelector(),
              const SizedBox(height: 26),

              if (selectedWorkoutType == '헬스') ...[
                _buildBodyPartSelector(),
                const SizedBox(height: 32),
              ],
              if (selectedWorkoutType == '러닝') ...[
                _buildRunningGoalInput(),
                const SizedBox(height: 32),
              ],

              _buildStartButton(),
            ] else ...[
              if (selectedWorkoutType == '헬스') ...[
                _buildExerciseController(),
                const SizedBox(height: 18),

                ...exercises.map(
                  (exercise) => ExerciseRecordCard(
                    data: exercise,
                    pointColor: pointColor,
                    onChanged: () {
                      setState(() {});
                    },
                  ),
                ),
              ] else ...[
                _buildRunningWorkoutView(),
              ],
            ],
          ],
        ),
      ),
      bottomNavigationBar: isWorkoutStarted
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: isChangingPauseState || isFinishingWorkout
                              ? null
                              : togglePause,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF5B5FFF),
                            side: const BorderSide(
                              color: Color(0xFF5B5FFF),
                              width: 1.4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Icon(
                            isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isFinishingWorkout ? null : finishWorkout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5A76),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: isFinishingWorkout
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '운동 종료',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '운동',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                ),
              ),

              if (!isWorkoutStarted) ...[
                const SizedBox(height: 8),
                const Text(
                  '오늘의 운동을 시작해보세요.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF666666)),
                ),
              ],
            ],
          ),
        ),

        if (isWorkoutStarted && selectedWorkoutType == '헬스')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: pointColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              formattedTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWorkoutTypeSelector() {
    return Row(
      children: [
        _WorkoutTypeChip(
          title: '헬스',
          selected: selectedWorkoutType == '헬스',
          pointColor: pointColor,
          onTap: () {
            setState(() {
              selectedWorkoutType = '헬스';
            });
          },
        ),
        const SizedBox(width: 12),
        _WorkoutTypeChip(
          title: '러닝',
          selected: selectedWorkoutType == '러닝',
          pointColor: pointColor,
          onTap: () {
            setState(() {
              selectedWorkoutType = '러닝';
            });
          },
        ),
      ],
    );
  }

  Widget _buildBodyPartSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '운동 부위 선택',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 14),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: bodyParts.map((part) {
            final selected = selectedBodyParts.contains(part);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    selectedBodyParts.remove(part);
                  } else {
                    selectedBodyParts.add(part);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: selected ? pointColor : const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  part,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF111111),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRunningGoalInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '목표 거리',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: runningGoalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '예: 5',
                  suffixText: 'km',
                  filled: true,
                  fillColor: const Color(0xFFF4F5F7),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SmallCircleButton(
              icon: Icons.add,
              color: pointColor,
              onTap: increaseRunningGoal,
            ),
            const SizedBox(width: 10),
            _SmallCircleButton(
              icon: Icons.remove,
              color: const Color(0xFFFF5A76),
              onTap: decreaseRunningGoal,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: isStartingWorkout ? null : startWorkout,
        style: ElevatedButton.styleFrom(
          backgroundColor: pointColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: const Text(
          '운동 시작',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildFinishedWorkoutCard(FinishedWorkoutSummary workout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘 운동 완료',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 28),

          if (workout.workoutType == '헬스') ...[
            _buildSummaryItem(title: '운동 종류', value: workout.workoutType),
            const SizedBox(height: 18),
            _buildSummaryItem(title: '운동 시간', value: workout.duration),
            const SizedBox(height: 18),
            _buildSummaryItem(
              title: '운동 종목',
              value: '${workout.exerciseCount}개',
            ),
            const SizedBox(height: 18),
            _buildSummaryItem(title: '완료 세트', value: '${workout.totalSets}세트'),
          ] else ...[
            _buildSummaryItem(title: '운동 종류', value: workout.workoutType),
            const SizedBox(height: 18),
            _buildSummaryItem(title: '운동 시간', value: workout.duration),
            const SizedBox(height: 18),
            _buildSummaryItem(
              title: '거리',
              value: '${workout.runningDistance.toStringAsFixed(2)} km',
            ),
            const SizedBox(height: 18),
            _buildSummaryItem(
              title: '평균 페이스',
              value: '${workout.runningPace}/km',
            ),
          ],
          const SizedBox(height: 24),

          if (workout.imageFile != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.file(
                workout.imageFile!,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 14),
          ],

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                pickWorkoutImage(workout);
              },
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(workout.imageFile == null ? '인증샷 추가' : '인증샷 변경'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5B5FFF),
                side: const BorderSide(color: Color(0xFF5B5FFF), width: 1.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({required String title, required String value}) {
    return Row(
      children: [
        Text(
          title,

          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF666666),
            fontWeight: FontWeight.w600,
          ),
        ),

        const Spacer(),

        Text(
          value,

          style: const TextStyle(
            fontSize: 20,
            color: Color(0xFF111111),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseController() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '운동 기록',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
            ),
          ),
        ),
        _SmallCircleButton(
          icon: Icons.add,
          color: pointColor,
          onTap: addExerciseCard,
        ),
        const SizedBox(width: 8),
        _SmallCircleButton(
          icon: Icons.remove,
          color: const Color(0xFFFF5A76),
          onTap: removeExerciseCard,
        ),
      ],
    );
  }

  Widget _buildRunningWorkoutView() {
    final goalKm = double.tryParse(runningGoalController.text) ?? 0.0;
    final remainingKm = goalKm - runningDistanceKm;
    final safeRemainingKm = remainingKm < 0 ? 0.0 : remainingKm;

    final pace = runningDistanceKm > 0 ? seconds / 60 / runningDistanceKm : 0.0;

    final paceMin = pace.floor();
    final paceSec = ((pace - paceMin) * 60).round();

    final paceText = runningDistanceKm > 0
        ? '$paceMin\'${paceSec.toString().padLeft(2, '0')}"'
        : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '러닝 중',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 18),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            children: [
              _buildMainRunningValue(
                title: '시간',
                value: formattedTime,
                fontSize: 58,
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFD8DCE3),
                ),
              ),

              _buildMainRunningValue(
                title: '거리',
                value: runningDistanceKm.toStringAsFixed(2),
                unit: 'km',
                fontSize: 64,
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFD8DCE3),
                ),
              ),

              Row(
                children: [
                  Expanded(
                    child: _buildSmallRunningValue(
                      title: '평균 페이스',
                      value: paceText,
                      unit: '/km',
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 86,
                    color: const Color(0xFFD8DCE3),
                  ),

                  Expanded(
                    child: _buildSmallRunningValue(
                      title: '목표까지',
                      value: goalKm > 0
                          ? safeRemainingKm.toStringAsFixed(2)
                          : '-',
                      unit: goalKm > 0 ? 'km' : '',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainRunningValue({
    required String title,
    required String value,
    String unit = '',
    required double fontSize,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF111111),
            height: 1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          unit.isEmpty ? title : '$title · $unit',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF666666),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallRunningValue({
    required String title,
    required String value,
    String unit = '',
  }) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111111),
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          unit.isEmpty ? title : '$title $unit',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF666666),
          ),
        ),
      ],
    );
  }
}

class _WorkoutTypeChip extends StatelessWidget {
  final String title;
  final bool selected;
  final Color pointColor;
  final VoidCallback onTap;

  const _WorkoutTypeChip({
    required this.title,
    required this.selected,
    required this.pointColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? pointColor : const Color(0xFFF4F5F7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF111111),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class ExerciseRecordCard extends StatefulWidget {
  final ExerciseCardData data;
  final Color pointColor;
  final VoidCallback onChanged;

  const ExerciseRecordCard({
    super.key,
    required this.data,
    required this.pointColor,
    required this.onChanged,
  });

  @override
  State<ExerciseRecordCard> createState() => _ExerciseRecordCardState();
}

class _ExerciseRecordCardState extends State<ExerciseRecordCard> {
  void addSet() {
    setState(() {
      widget.data.sets.add(ExerciseSetData());
    });
    widget.onChanged();
  }

  void removeSet() {
    if (widget.data.sets.length <= 1) return;

    setState(() {
      final removed = widget.data.sets.removeLast();
      removed.dispose();
    });

    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.data.exerciseNameController,
                  decoration: const InputDecoration(
                    hintText: '운동 종목',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
              _SmallCircleButton(
                icon: Icons.add,
                color: widget.pointColor,
                onTap: addSet,
              ),
              const SizedBox(width: 8),
              _SmallCircleButton(
                icon: Icons.remove,
                color: const Color(0xFFFF5A76),
                onTap: removeSet,
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Row(
            children: [
              SizedBox(width: 54, child: Text('세트', style: _tableHeaderStyle)),
              Expanded(child: Text('무게', style: _tableHeaderStyle)),
              SizedBox(width: 12),
              Expanded(child: Text('횟수', style: _tableHeaderStyle)),
              SizedBox(width: 12),
              SizedBox(width: 32),
            ],
          ),

          const SizedBox(height: 8),

          ...List.generate(widget.data.sets.length, (index) {
            final set = widget.data.sets[index];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 54,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _RecordInput(
                      controller: set.weightController,
                      hint: 'kg',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RecordInput(
                      controller: set.repsController,
                      hint: '회',
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        set.isDone = !set.isDone;
                      });
                      widget.onChanged();
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: set.isDone ? widget.pointColor : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 16,
                        color: set.isDone
                            ? Colors.white
                            : const Color(0xFFB8B8B8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

const TextStyle _tableHeaderStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: Color(0xFF777777),
);

class _RecordInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _RecordInput({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SmallCircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallCircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 18,
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class ExerciseCardData {
  final TextEditingController exerciseNameController = TextEditingController();
  final List<ExerciseSetData> sets = [ExerciseSetData()];

  void dispose() {
    exerciseNameController.dispose();

    for (final set in sets) {
      set.dispose();
    }
  }
}

class ExerciseSetData {
  final TextEditingController weightController = TextEditingController();
  final TextEditingController repsController = TextEditingController();

  bool isDone = false;

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}

class FinishedWorkoutSummary {
  final String workoutType;
  final String duration;

  final int exerciseCount;
  final int totalSets;

  final double runningDistance;
  final String runningPace;

  File? imageFile;

  FinishedWorkoutSummary({
    required this.workoutType,
    required this.duration,

    required this.exerciseCount,
    required this.totalSets,

    required this.runningDistance,
    required this.runningPace,
  });
}

class WorkoutValidationException implements Exception {
  const WorkoutValidationException(this.message);

  final String message;
}
