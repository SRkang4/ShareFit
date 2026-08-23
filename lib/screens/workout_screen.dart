import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../data/exercise_catalog.dart';
import '../controllers/workout_session_controller.dart';
import '../models/workout_record.dart';
import '../services/auth_service.dart';
import '../services/location_tracking_service.dart';
import '../services/public_activity_service.dart';
import '../services/workout_progress_notification_service.dart';
import '../services/workout_photo_service.dart';
import '../services/workout_photo_save_service.dart';
import '../services/workout_service.dart';
import '../utils/workout_exercise_plan.dart';
import '../widgets/active_workout_timer_pill.dart';
import '../widgets/exercise_picker_sheet.dart';
import '../widgets/sharefit_sliding_segmented_control.dart';
import '../widgets/sharefit_ui.dart';
import '../widgets/workout_record_detail.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with WidgetsBindingObserver {
  static const double _floatingNavigationClearance = 104;
  static const double _idleBottomScrollPadding =
      _floatingNavigationClearance + 32;

  Color get pointColor => Theme.of(context).colorScheme.primary;
  Color get subPointColor => Theme.of(context).colorScheme.primaryContainer;

  String selectedWorkoutType = '헬스';
  int selectedIdleViewIndex = 0;
  bool isWorkoutFinished = false;

  final List<String> bodyParts = ['가슴', '등', '어깨', '하체', '팔'];
  final Set<String> selectedBodyParts = {};
  final Set<String> activeWorkoutBodyParts = {};
  final List<String?> plannedExerciseNames = [];

  final List<ExerciseCardData> exercises = [ExerciseCardData()];
  final Map<String, WorkoutRecord> locallyCompletedWorkouts = {};
  final Map<String, File> workoutImages = {};
  final Set<String> uploadingPhotoWorkoutIds = {};
  final TextEditingController runningGoalController = TextEditingController();
  final LocationTrackingService locationTrackingService =
      LocationTrackingService();
  final AuthService authService = AuthService();
  final WorkoutService workoutService = WorkoutService();
  final PublicActivityService publicActivityService = PublicActivityService();
  final WorkoutProgressNotificationService progressNotificationService =
      WorkoutProgressNotificationService();
  final WorkoutPhotoService workoutPhotoService = WorkoutPhotoService();
  final WorkoutPhotoSaveService workoutPhotoSaveService =
      WorkoutPhotoSaveService();
  late final Stream<List<WorkoutRecord>> todayWorkoutsStream;
  late final Future<bool> isProFuture;
  String? justCompletedWorkoutId;
  double runningDistanceMeters = 0.0;
  Position? lastRunningPosition;
  int validRunningLocationCount = 0;
  Timer? weakGpsTimer;
  bool isStartingWorkout = false;
  bool isChangingPauseState = false;
  bool isFinishingWorkout = false;
  bool hasShownWeakGpsMessage = false;
  AppLifecycleState appLifecycleState = AppLifecycleState.resumed;
  String? lastErrorMessage;
  DateTime? lastErrorShownAt;

  final WorkoutSessionController workoutSession =
      WorkoutSessionController.instance;

  bool get isWorkoutStarted => workoutSession.isActive;
  bool get isPaused => workoutSession.isPaused;
  int get seconds => workoutSession.elapsedSeconds;
  DateTime? get workoutStartedAt => workoutSession.startedAt;

  double get runningDistanceKm => runningDistanceMeters / 1000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    workoutSession.addListener(_handleWorkoutSessionChanged);
    todayWorkoutsStream = workoutService.watchTodayWorkouts();
    isProFuture = _loadIsPro();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWorkoutViewVisibility();
    });
  }

  Future<bool> _loadIsPro() async {
    final userData = await authService.getCurrentUserData();
    return userData?['isPro'] == true;
  }

  bool _hasWorkoutPhoto(WorkoutRecord workout) {
    return workout.hasValidPhoto;
  }

  Future<bool> _canStartPhotoUpload(String workoutId) async {
    final userData = await authService.getCurrentUserData();
    final isPro = userData?['isPro'] == true;
    debugPrint('[WorkoutPhoto][$workoutId] 업로드 전 isPro=$isPro');
    if (isPro) return true;

    final todayWorkouts = await workoutService.getTodayWorkouts();
    WorkoutRecord? targetWorkout;
    for (final workout in todayWorkouts) {
      if (workout.id == workoutId) {
        targetWorkout = workout;
        break;
      }
    }

    if (targetWorkout != null && _hasWorkoutPhoto(targetWorkout)) {
      debugPrint('[WorkoutPhoto][$workoutId] 기존 사진 교체이므로 Free 제한 제외');
      return true;
    }

    final hasAnotherPhoto = todayWorkouts.any(
      (workout) => workout.id != workoutId && _hasWorkoutPhoto(workout),
    );
    final hasAnotherUpload = uploadingPhotoWorkoutIds.any(
      (uploadingId) => uploadingId != workoutId,
    );
    final canUpload = !hasAnotherPhoto && !hasAnotherUpload;
    debugPrint(
      '[WorkoutPhoto][$workoutId] Free 업로드 검사: '
      'hasAnotherPhoto=$hasAnotherPhoto, '
      'hasAnotherUpload=$hasAnotherUpload, canUpload=$canUpload',
    );
    return canUpload;
  }

  @override
  void didUpdateWidget(covariant WorkoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive &&
        !widget.isActive &&
        justCompletedWorkoutId != null) {
      setState(() {
        justCompletedWorkoutId = null;
      });
    }
    _syncWorkoutViewVisibility();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    workoutSession.removeListener(_handleWorkoutSessionChanged);
    workoutSession.finish();
    weakGpsTimer?.cancel();
    unawaited(locationTrackingService.dispose());
    unawaited(progressNotificationService.stop());
    runningGoalController.dispose();
    for (final exercise in exercises) {
      exercise.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appLifecycleState = state;
    if (state == AppLifecycleState.resumed &&
        isWorkoutStarted &&
        !isPaused &&
        mounted) {
      workoutSession.refresh();
      unawaited(_updateProgressNotification(force: true));
    }
  }

  void _handleWorkoutSessionChanged() {
    if (!mounted) return;
    setState(() {});
    if (isWorkoutStarted && !isFinishingWorkout) {
      unawaited(_updateProgressNotification());
    }
  }

  void _syncWorkoutViewVisibility() {
    workoutSession.setWorkoutViewVisible(widget.isActive && isWorkoutStarted);
  }

  Future<void> startWorkout() async {
    if (isStartingWorkout) {
      return;
    }
    final preparedExerciseNames = normalizePlannedExerciseNames(
      plannedExerciseNames,
    );
    final preparedBodyParts = Set<String>.of(selectedBodyParts);
    setState(() {
      isStartingWorkout = true;
    });

    if (selectedWorkoutType == '러닝') {
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

    final startedAt = DateTime.now();
    try {
      await publicActivityService.markWorkoutStarted(
        workoutType: selectedWorkoutType == '러닝' ? 'running' : 'strength',
        startedAt: startedAt,
      );
    } catch (_) {
      if (selectedWorkoutType == '러닝') {
        await _stopRunningLocationTracking();
      }
      if (!mounted) return;
      setState(() => isStartingWorkout = false);
      _showError('운동 상태를 시작하지 못했습니다. 다시 시도해주세요.');
      return;
    }
    if (!mounted) return;
    setState(() {
      if (selectedWorkoutType == '헬스') {
        _replaceActiveExercises(preparedExerciseNames);
      }

      isWorkoutFinished = false;
      if (selectedWorkoutType != '러닝') {
        runningDistanceMeters = 0.0;
        lastRunningPosition = null;
        validRunningLocationCount = 0;
      }
      activeWorkoutBodyParts
        ..clear()
        ..addAll(preparedBodyParts);
      selectedBodyParts.clear();
      plannedExerciseNames.clear();
      isStartingWorkout = false;
    });
    workoutSession.start(
      workoutType: selectedWorkoutType == '러닝' ? 'running' : 'strength',
      startedAt: startedAt,
    );
    _syncWorkoutViewVisibility();
    unawaited(_startProgressNotification());
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
      final now = DateTime.now();
      if (isPaused) {
        workoutSession.resume(now);
      } else {
        workoutSession.pause(now);
      }
      unawaited(_updateProgressNotification(force: true));
      return;
    }

    isChangingPauseState = true;

    if (!isPaused) {
      final now = DateTime.now();
      workoutSession.pause(now);
      await _stopRunningLocationTracking();
      await _updateProgressNotification(force: true);
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
    final resumedAt = DateTime.now();
    workoutSession.resume(resumedAt);
    await _updateProgressNotification(force: true);
    isChangingPauseState = false;
  }

  Future<void> finishWorkout() async {
    if (isFinishingWorkout) {
      return;
    }

    final endedAt = DateTime.now();
    final finalActiveDuration = workoutSession.elapsedAt(endedAt);
    final durationSeconds = finalActiveDuration.inSeconds;
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
    workoutSession.pause(endedAt);
    setState(() {
      isFinishingWorkout = true;
    });

    if (selectedWorkoutType == '러닝') {
      try {
        await _stopRunningLocationTracking();
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          isFinishingWorkout = false;
        });
        _showError('위치 추적을 종료하지 못했습니다. 잠시 후 다시 시도해주세요.');
        return;
      }
      if (!mounted) {
        return;
      }
    }
    await _updateProgressNotification(force: true);

    late final String workoutId;
    try {
      workoutId = await workoutService.saveCompletedWorkout(workoutRecord);
    } catch (_) {
      if (!mounted) {
        return;
      }

      var resumed = wasPaused;
      if (!wasPaused) {
        if (selectedWorkoutType == '러닝') {
          if (_isAppInForeground) {
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
            resumed = false;
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
      });
      if (!wasPaused && resumed) {
        workoutSession.resume(DateTime.now());
      }
      await _updateProgressNotification(force: true);
      _showError('운동 기록을 저장하지 못했습니다. 다시 시도해주세요.');
      return;
    }

    try {
      await progressNotificationService.stop();
    } catch (_) {
      // Notification cleanup must not turn a successfully saved workout into
      // a failed workout session.
    }

    setState(() {
      locallyCompletedWorkouts[workoutId] = WorkoutRecord(
        id: workoutId,
        userId: workoutRecord.userId,
        type: workoutRecord.type,
        startedAt: workoutRecord.startedAt,
        endedAt: workoutRecord.endedAt,
        durationSeconds: workoutRecord.durationSeconds,
        photoUrl: workoutRecord.photoUrl,
        photoCreatedAt: workoutRecord.photoCreatedAt,
        photoExpiresAt: workoutRecord.photoExpiresAt,
        strength: workoutRecord.strength,
        running: workoutRecord.running,
      );
      isWorkoutFinished = true;
      justCompletedWorkoutId = workoutId;
      selectedIdleViewIndex = 1;
      isFinishingWorkout = false;
    });
    workoutSession.finish();
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
          .where((bodyPart) => activeWorkoutBodyParts.contains(bodyPart))
          .toList(),
      exercises: savedExercises,
      completedSetCount: completedSetCount,
      totalVolumeKg: totalVolumeKg,
    );
  }

  bool get _isAppInForeground => appLifecycleState == AppLifecycleState.resumed;

  String _formatDuration(int durationSeconds) {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  String _formatPace(double paceSecondsPerKm) {
    return WorkoutProgressNotificationService.formatPace(paceSecondsPerKm);
  }

  Future<void> _startProgressNotification() async {
    try {
      if (selectedWorkoutType == '러닝') {
        await progressNotificationService.startRunning(
          durationSeconds: seconds,
          distanceMeters: runningDistanceMeters,
        );
      } else {
        await progressNotificationService.startStrength(
          durationSeconds: seconds,
          bodyParts: activeWorkoutBodyParts,
        );
      }
    } catch (_) {
      // Notification permission or platform failures do not block workouts.
    }
  }

  Future<void> _updateProgressNotification({bool force = false}) async {
    if (!isWorkoutStarted) return;
    try {
      if (selectedWorkoutType == '러닝') {
        await progressNotificationService.updateRunning(
          durationSeconds: seconds,
          distanceMeters: runningDistanceMeters,
          isPaused: isPaused,
          force: force,
        );
      } else {
        await progressNotificationService.updateStrength(
          durationSeconds: seconds,
          bodyParts: activeWorkoutBodyParts,
          isPaused: isPaused,
          force: force,
        );
      }
    } catch (_) {
      // The exercise session remains the source of truth when notification
      // delivery is unavailable or permission has been denied.
    }
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
    unawaited(_updateProgressNotification());
  }

  void _handleRunningLocationError(Object error) {
    if (!mounted) {
      return;
    }

    if (isWorkoutStarted && !isPaused) {
      workoutSession.pause();
    }
    unawaited(_pauseAfterLocationFailure());
    _showLocationError(error);
  }

  Future<void> _pauseAfterLocationFailure() async {
    await _stopRunningLocationTracking();
    await _updateProgressNotification(force: true);
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

  Future<void> pickWorkoutImage(String workoutId) async {
    debugPrint('[WorkoutPhoto][$workoutId] 인증사진 버튼 클릭');
    if (uploadingPhotoWorkoutIds.contains(workoutId)) {
      debugPrint(
        '[WorkoutPhoto][$workoutId] 중복 업로드 방지 조건 진입: '
        '이미 처리 중이므로 반환',
      );
      return;
    }
    uploadingPhotoWorkoutIds.add(workoutId);
    debugPrint(
      '[WorkoutPhoto][$workoutId] 처리 상태 등록 완료: '
      'contains=${uploadingPhotoWorkoutIds.contains(workoutId)}',
    );
    final picker = ImagePicker();
    String? uploadedUrl;

    try {
      debugPrint('[WorkoutPhoto][$workoutId] Free/Pro 업로드 제한 재검사 시작');
      final canUpload = await _canStartPhotoUpload(workoutId);
      debugPrint(
        '[WorkoutPhoto][$workoutId] Free/Pro 업로드 제한 재검사 완료: '
        'canUpload=$canUpload',
      );
      if (!canUpload) return;

      debugPrint('[WorkoutPhoto][$workoutId] ImagePicker 카메라 실행 직전');
      final pickedImage = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      debugPrint(
        '[WorkoutPhoto][$workoutId] XFile 반환 여부: '
        '${pickedImage == null ? 'null(촬영 취소)' : '반환됨'}',
      );
      if (pickedImage == null) return;
      debugPrint(
        '[WorkoutPhoto][$workoutId] pickedImage.path=${pickedImage.path}',
      );

      final imageFile = File(pickedImage.path);
      final fileExists = await imageFile.exists();
      debugPrint('[WorkoutPhoto][$workoutId] File.exists()=$fileExists');
      if (fileExists) {
        final fileLength = await imageFile.length();
        debugPrint('[WorkoutPhoto][$workoutId] 파일 크기=$fileLength bytes');
      }
      debugPrint('[WorkoutPhoto][$workoutId] Storage 업로드 함수 호출 직전');
      final uploadResult = await workoutPhotoService.uploadCompletionPhoto(
        workoutId: workoutId,
        image: imageFile,
      );
      uploadedUrl = uploadResult.downloadUrl;
      final photoCreatedAt = uploadResult.createdAt;
      final photoExpiresAt = photoCreatedAt.add(const Duration(days: 30));
      debugPrint(
        '[WorkoutPhoto][$workoutId] Storage 업로드 함수 완료: '
        'downloadUrl=$uploadedUrl, photoCreatedAt=$photoCreatedAt, '
        'photoExpiresAt=$photoExpiresAt',
      );
      debugPrint('[WorkoutPhoto][$workoutId] Firestore updateWorkoutPhoto 시작');
      final previousPhotoUrl = await workoutService.updateWorkoutPhoto(
        workoutId: workoutId,
        photoUrl: uploadedUrl,
        photoCreatedAt: photoCreatedAt,
        photoExpiresAt: photoExpiresAt,
      );
      debugPrint(
        '[WorkoutPhoto][$workoutId] Firestore updateWorkoutPhoto 완료: '
        'previousPhotoUrl=$previousPhotoUrl',
      );
      if (previousPhotoUrl != null && previousPhotoUrl != uploadedUrl) {
        try {
          debugPrint('[WorkoutPhoto][$workoutId] 이전 Storage 사진 삭제 시작');
          await workoutPhotoService.deleteByDownloadUrl(previousPhotoUrl);
          debugPrint('[WorkoutPhoto][$workoutId] 이전 Storage 사진 삭제 완료');
        } catch (e, stackTrace) {
          debugPrint('[WorkoutPhoto][$workoutId] 이전 Storage 사진 삭제 실패: $e');
          debugPrintStack(stackTrace: stackTrace);
          // The new Firestore URL is already valid; stale-file cleanup can be
          // retried independently without failing the user's photo update.
        }
      }

      if (!mounted) {
        debugPrint('[WorkoutPhoto][$workoutId] UI setState 생략: mounted=false');
        return;
      }
      debugPrint('[WorkoutPhoto][$workoutId] UI setState 직전');
      setState(() {
        workoutImages[workoutId] = imageFile;
      });
      debugPrint('[WorkoutPhoto][$workoutId] UI setState 완료');
    } catch (e, stackTrace) {
      if (e is FirebaseException) {
        debugPrint(
          '[WorkoutPhoto][$workoutId] FirebaseException: '
          'plugin=${e.plugin}, code=${e.code}, message=${e.message}',
        );
      }
      debugPrint('[WorkoutPhoto][$workoutId] 인증사진 처리 실패: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (uploadedUrl != null) {
        try {
          debugPrint('[WorkoutPhoto][$workoutId] 실패 후 업로드 파일 정리 시작');
          await workoutPhotoService.deleteByDownloadUrl(uploadedUrl);
          debugPrint('[WorkoutPhoto][$workoutId] 실패 후 업로드 파일 정리 완료');
        } catch (cleanupError, cleanupStackTrace) {
          if (cleanupError is FirebaseException) {
            debugPrint(
              '[WorkoutPhoto][$workoutId] 정리 FirebaseException: '
              'plugin=${cleanupError.plugin}, code=${cleanupError.code}, '
              'message=${cleanupError.message}',
            );
          }
          debugPrint(
            '[WorkoutPhoto][$workoutId] 실패 후 업로드 파일 정리 실패: '
            '$cleanupError',
          );
          debugPrintStack(stackTrace: cleanupStackTrace);
          // Preserve the original upload error shown to the user.
        }
      }
      if (mounted) {
        _showError('인증 사진을 저장하지 못했습니다. 다시 시도해주세요.');
      }
    } finally {
      debugPrint('[WorkoutPhoto][$workoutId] finally 진입');
      final removed = uploadingPhotoWorkoutIds.remove(workoutId);
      debugPrint(
        '[WorkoutPhoto][$workoutId] 처리 상태 제거 결과: '
        'removed=$removed, '
        'contains=${uploadingPhotoWorkoutIds.contains(workoutId)}',
      );
    }
  }

  Future<void> _saveWorkoutPhoto(WorkoutRecord workout) async {
    final workoutId = workout.id;
    final photoUrl = workout.validPhotoUrl;
    if (workoutId == null ||
        photoUrl == null ||
        workout.userId != workoutService.currentUserId) {
      return;
    }

    try {
      await workoutPhotoSaveService.save(
        workoutId: workoutId,
        photoUrl: photoUrl,
      );
      if (mounted) _showError('사진을 저장했습니다.');
    } on WorkoutPhotoSaveException catch (error) {
      if (mounted) _showError(error.userMessage);
    } catch (_) {
      if (mounted) _showError('사진을 저장하지 못했습니다. 다시 시도해주세요.');
    }
  }

  void _replaceActiveExercises(List<String> exerciseNames) {
    for (final exercise in exercises) {
      exercise.dispose();
    }

    exercises.clear();
    if (exerciseNames.isEmpty) {
      exercises.add(ExerciseCardData());
      return;
    }
    exercises.addAll(
      exerciseNames.map(
        (exerciseName) => ExerciseCardData(exerciseName: exerciseName),
      ),
    );
  }

  void addExerciseCard() {
    setState(() {
      exercises.add(ExerciseCardData());
    });
  }

  void removeExerciseCard() {
    if (exercises.isEmpty) return;

    setState(() {
      final removed = exercises.removeLast();
      removed.dispose();
    });
  }

  Future<void> _selectActiveExercise(int index) async {
    if (index < 0 || index >= exercises.length) return;
    if (activeWorkoutBodyParts.isEmpty) {
      _showError('먼저 운동 부위를 선택해주세요.');
      return;
    }

    final exercise = exercises[index];
    final selectedExercise = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (context) => ExercisePickerSheet(
        exercises: ExerciseCatalog.forBodyParts(activeWorkoutBodyParts),
        selectedExercise: exercise.exerciseNameController.text.trim(),
      ),
    );

    if (!mounted || selectedExercise == null) return;
    if (index >= exercises.length || !identical(exercises[index], exercise)) {
      return;
    }
    setState(() {
      exercise.updateExerciseName(selectedExercise);
    });
  }

  String get formattedTime => formatWorkoutDuration(seconds);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dangerColor = colors.error.withValues(alpha: 0.72);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  45,
                  20,
                  isWorkoutStarted ? 28 : _idleBottomScrollPadding,
                ),
                children: [
                  _buildHeader(),
                  SizedBox(height: isWorkoutStarted ? 32 : 22),

                  if (!isWorkoutStarted) ...[
                    _buildIdleViewSelector(),
                    const SizedBox(height: 24),
                    _buildIdleWorkoutContent(),
                  ] else ...[
                    if (selectedWorkoutType == '헬스') ...[
                      _buildExerciseController(),
                      const SizedBox(height: 18),

                      ...List.generate(
                        exercises.length,
                        (index) => ExerciseRecordCard(
                          key: ObjectKey(exercises[index]),
                          data: exercises[index],
                          pointColor: pointColor,
                          onExerciseNameTap: () => _selectActiveExercise(index),
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
          ),
          if (isWorkoutStarted && selectedWorkoutType == '헬스')
            Positioned(
              top: WorkoutTimerPillLayout.screenTop(context),
              right: WorkoutTimerPillLayout.right,
              child: WorkoutTimerPill(
                elapsedSeconds: seconds,
                isPaused: isPaused,
                semanticLabel: isPaused ? '일시정지된 운동 시간' : '진행 중인 운동 시간',
              ),
            ),
        ],
      ),
      bottomNavigationBar: isWorkoutStarted
          ? SafeArea(
              top: false,
              minimum: const EdgeInsets.only(
                bottom: _floatingNavigationClearance,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                color: Theme.of(context).colorScheme.surface,
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
                            foregroundColor: pointColor,
                            side: BorderSide(color: pointColor, width: 1.4),
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
                            backgroundColor: colors.surfaceContainerHigh,
                            foregroundColor: dangerColor,
                            disabledBackgroundColor:
                                colors.surfaceContainerHigh,
                            disabledForegroundColor: dangerColor.withValues(
                              alpha: 0.45,
                            ),
                            elevation: 0,
                            side: BorderSide(color: colors.outlineVariant),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: isFinishingWorkout
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: dangerColor,
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
              Text(
                '운동',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 41,
                  height: 1.08,
                  letterSpacing: -1.4,
                ),
              ),
              if (!isWorkoutStarted) ...[
                const SizedBox(height: 9),
                Text(
                  selectedIdleViewIndex == 0
                      ? '오늘의 운동을 시작해보세요.'
                      : '오늘 완료한 운동이에요.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdleViewSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final controlWidth = (constraints.maxWidth * 0.48).clamp(156.0, 180.0);
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: controlWidth,
            child: ShareFitSlidingSegmentedControl(
              labels: const ['운동 준비', '오늘 기록'],
              icons: const [
                Icons.fitness_center_rounded,
                Icons.menu_book_rounded,
              ],
              selectedIndex: selectedIdleViewIndex,
              height: 54,
              onChanged: (index) {
                if (selectedIdleViewIndex == index) return;
                setState(() {
                  selectedIdleViewIndex = index;
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkoutTypeSelector() {
    return ShareFitSlidingSegmentedControl(
      labels: const ['헬스', '러닝'],
      selectedIndex: selectedWorkoutType == '헬스' ? 0 : 1,
      height: 60,
      onChanged: (index) {
        setState(() {
          selectedWorkoutType = index == 0 ? '헬스' : '러닝';
        });
      },
    );
  }

  Widget _buildBodyPartSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '운동 부위 선택',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
                  color: selected
                      ? pointColor
                      : Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  part,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
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
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
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
              color: pointColor,
              destructive: true,
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

  void _addPlannedExerciseSlot() {
    setState(() {
      plannedExerciseNames.add(null);
    });
  }

  void _removePlannedExerciseSlot() {
    if (plannedExerciseNames.isEmpty) return;
    setState(() {
      plannedExerciseNames.removeLast();
    });
  }

  Future<void> _onPlannedExerciseSlotTap(int index) async {
    if (selectedBodyParts.isEmpty) {
      _showError('먼저 운동 부위를 선택해주세요.');
      return;
    }
    if (index < 0 || index >= plannedExerciseNames.length) return;

    final availableExercises = ExerciseCatalog.forBodyParts(selectedBodyParts);
    final selectedExercise = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (context) => ExercisePickerSheet(
        exercises: availableExercises,
        selectedExercise: plannedExerciseNames[index],
      ),
    );

    if (!mounted || selectedExercise == null) return;
    if (index >= plannedExerciseNames.length) return;
    setState(() {
      plannedExerciseNames[index] = selectedExercise;
    });
  }

  Widget _buildPlannedExerciseSection() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '종목',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            _PlannedExerciseActionButton(
              icon: Icons.add_rounded,
              semanticLabel: '종목 추가',
              onPressed: _addPlannedExerciseSlot,
            ),
            const SizedBox(width: 8),
            _PlannedExerciseActionButton(
              icon: Icons.remove_rounded,
              semanticLabel: '종목 제거',
              onPressed: plannedExerciseNames.isEmpty
                  ? null
                  : _removePlannedExerciseSlot,
            ),
          ],
        ),
        if (plannedExerciseNames.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (var index = 0; index < plannedExerciseNames.length; index++) ...[
            Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    '${index + 1}.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Material(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: () => _onPlannedExerciseSlotTap(index),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 54),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                plannedExerciseNames[index] ?? '운동 종목 선택',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: colors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (index != plannedExerciseNames.length - 1)
              const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _buildIdleWorkoutContent() {
    return FutureBuilder<bool>(
      future: isProFuture,
      builder: (context, proSnapshot) {
        final isPro = proSnapshot.data == true;
        return StreamBuilder<List<WorkoutRecord>>(
          stream: todayWorkoutsStream,
          initialData: const [],
          builder: (context, snapshot) {
            final records =
                snapshot.data?.toList(growable: true) ?? <WorkoutRecord>[];
            final hasTodayPhoto = records.any(_hasWorkoutPhoto);
            final justCompletedId = justCompletedWorkoutId;
            WorkoutRecord? justCompleted;
            if (justCompletedId != null) {
              for (final record in records) {
                if (record.id == justCompletedId) {
                  justCompleted = record;
                  break;
                }
              }
              justCompleted ??= locallyCompletedWorkouts[justCompletedId];
            }
            final previousRecords = records
                .where((record) => record.id != justCompletedId)
                .toList();
            final workoutSetup = ShareFitCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '운동 종류',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 14),
                  _buildWorkoutTypeSelector(),
                  const SizedBox(height: 26),
                  if (selectedWorkoutType == '헬스') ...[
                    _buildBodyPartSelector(),
                    const SizedBox(height: 28),
                    _buildPlannedExerciseSection(),
                    const SizedBox(height: 32),
                  ],
                  if (selectedWorkoutType == '러닝') ...[
                    _buildRunningGoalInput(),
                    const SizedBox(height: 32),
                  ],
                  _buildStartButton(),
                ],
              ),
            );

            if (selectedIdleViewIndex == 0) {
              return workoutSetup;
            }

            final allRecords = previousRecords.toList(growable: true);
            if (justCompleted != null) {
              allRecords.insert(0, justCompleted);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘 운동 완료',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 16),
                if (allRecords.isEmpty)
                  ShareFitCard(
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Column(
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 34,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '오늘 완료한 운동이 없어요.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  for (final record in allRecords)
                    WorkoutRecordSummaryCard(
                      key: ValueKey(record.id),
                      workout: record,
                      onTap: () => _openWorkoutRecordDetail(
                        record,
                        canShowPhotoButton:
                            isPro || _hasWorkoutPhoto(record) || !hasTodayPhoto,
                      ),
                    ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openWorkoutRecordDetail(
    WorkoutRecord workout, {
    required bool canShowPhotoButton,
  }) async {
    final workoutId = workout.id;
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (context) => WorkoutRecordDetailSheet(
        workout: workout,
        onDelete: () => _deleteWorkoutRecord(workout),
        onPhotoPressed: workoutId == null || !canShowPhotoButton
            ? null
            : () => pickWorkoutImage(workoutId),
        onSavePhotoPressed:
            workoutId != null &&
                workout.userId == workoutService.currentUserId &&
                workout.hasValidPhoto
            ? () => _saveWorkoutPhoto(workout)
            : null,
      ),
    );
    if (!mounted || deleted != true) return;
    _showError('운동 기록을 삭제했어요.');
  }

  Future<void> _deleteWorkoutRecord(WorkoutRecord workout) async {
    try {
      await workoutService.deleteCompletedWorkout(workout);
      final photoUrl = workout.validPhotoUrl;
      if (photoUrl != null) {
        try {
          await workoutPhotoService.deleteByDownloadUrl(photoUrl);
        } catch (error, stackTrace) {
          debugPrint('[WorkoutDelete][${workout.id}] Storage 정리 실패: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      if (!mounted) return;
      setState(() {
        locallyCompletedWorkouts.remove(workout.id);
        workoutImages.remove(workout.id);
        if (justCompletedWorkoutId == workout.id) {
          justCompletedWorkoutId = null;
        }
      });
    } catch (error, stackTrace) {
      debugPrint('[WorkoutDelete][${workout.id}] 기록 삭제 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showError('운동 기록을 삭제하지 못했습니다. 다시 시도해주세요.');
      }
      rethrow;
    }
  }

  // Legacy adapter retained for local image compatibility.
  // ignore: unused_element
  FinishedWorkoutSummary _summaryFromRecord(WorkoutRecord record) {
    final strength = record.strength;
    final running = record.running;
    final averagePace = running?.averagePaceSecondsPerKm;
    return FinishedWorkoutSummary(
      id: record.id,
      workoutType: record.type == 'running' ? '러닝' : '헬스',
      duration: _formatDuration(record.durationSeconds),
      exerciseCount: strength?.exercises.length ?? 0,
      totalSets: strength?.completedSetCount ?? 0,
      totalVolumeKg: strength?.totalVolumeKg ?? 0,
      runningDistance: (running?.distanceMeters ?? 0) / 1000,
      runningPace: averagePace == null ? '-' : _formatPace(averagePace),
      photoUrl: record.validPhotoUrl,
      imageFile: record.id == null ? null : workoutImages[record.id],
    );
  }

  // ignore: unused_element
  Widget _buildFinishedWorkoutCard(FinishedWorkoutSummary workout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘 운동 완료',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
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
            const SizedBox(height: 18),
            _buildSummaryItem(
              title: '운동 볼륨',
              value: '${workout.totalVolumeKg.toStringAsFixed(1)} kg',
            ),
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
          ] else if (workout.photoUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.network(
                workout.photoUrl!,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 14),
          ],

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                final workoutId = workout.id;
                if (workoutId != null) {
                  pickWorkoutImage(workoutId);
                }
              },
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(
                workout.imageFile == null && workout.photoUrl == null
                    ? '인증사진 촬영'
                    : '인증사진 다시 촬영',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: pointColor,
                side: BorderSide(color: pointColor, width: 1.3),
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

          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),

        const Spacer(),

        Text(
          value,

          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
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
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
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
          color: pointColor,
          destructive: true,
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
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            children: [
              _buildMainRunningValue(
                title: '시간',
                value: formattedTime,
                fontSize: 58,
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),

              _buildMainRunningValue(
                title: '거리',
                value: runningDistanceKm.toStringAsFixed(2),
                unit: 'km',
                fontSize: 64,
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
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
                    color: Theme.of(context).colorScheme.outlineVariant,
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
            height: 1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          unit.isEmpty ? title : '$title · $unit',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          unit.isEmpty ? title : '$title $unit',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class ExerciseRecordCard extends StatefulWidget {
  final ExerciseCardData data;
  final Color pointColor;
  final VoidCallback onChanged;
  final VoidCallback onExerciseNameTap;

  const ExerciseRecordCard({
    super.key,
    required this.data,
    required this.pointColor,
    required this.onChanged,
    required this.onExerciseNameTap,
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
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onExerciseNameTap,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.data.exerciseNameController.text
                                      .trim()
                                      .isEmpty
                                  ? '운동 종목 선택'
                                  : widget.data.exerciseNameController.text
                                        .trim(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
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
                color: widget.pointColor,
                destructive: true,
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
                        color: set.isDone
                            ? widget.pointColor
                            : Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        border: set.isDone
                            ? null
                            : Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
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
);

class _RecordInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _RecordInput({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(color: colorScheme.onSurface),
      cursorColor: colorScheme.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _SmallCircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool destructive;

  const _SmallCircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dangerColor = colors.error.withValues(alpha: 0.72);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: destructive ? colors.surfaceContainerHigh : color,
          shape: BoxShape.circle,
          border: destructive ? Border.all(color: colors.outlineVariant) : null,
        ),
        child: Icon(
          icon,
          color: destructive ? dangerColor : Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _PlannedExerciseActionButton extends StatelessWidget {
  const _PlannedExerciseActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        color: colors.surfaceContainerHigh.withValues(
          alpha: enabled ? 1 : 0.55,
        ),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 22,
              color: enabled
                  ? colors.onSurface
                  : colors.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class ExerciseCardData {
  ExerciseCardData({String? exerciseName})
    : exerciseNameController = TextEditingController(text: exerciseName);

  final TextEditingController exerciseNameController;
  final List<ExerciseSetData> sets = [ExerciseSetData()];

  void updateExerciseName(String exerciseName) {
    exerciseNameController.text = exerciseName.trim();
  }

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
  final String? id;
  final String workoutType;
  final String duration;

  final int exerciseCount;
  final int totalSets;
  final double totalVolumeKg;

  final double runningDistance;
  final String runningPace;
  final String? photoUrl;

  File? imageFile;

  FinishedWorkoutSummary({
    this.id,
    required this.workoutType,
    required this.duration,

    required this.exerciseCount,
    required this.totalSets,
    required this.totalVolumeKg,

    required this.runningDistance,
    required this.runningPace,
    this.photoUrl,
    this.imageFile,
  });
}

class WorkoutValidationException implements Exception {
  const WorkoutValidationException(this.message);

  final String message;
}
