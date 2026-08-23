import 'dart:async';

import 'package:flutter/foundation.dart';

class WorkoutSessionController extends ChangeNotifier {
  WorkoutSessionController({DateTime Function()? now, bool enableTicker = true})
    : _now = now ?? DateTime.now,
      _enableTicker = enableTicker;

  static final WorkoutSessionController instance = WorkoutSessionController();

  final DateTime Function() _now;
  final bool _enableTicker;
  Timer? _ticker;
  bool _isActive = false;
  bool _isPaused = false;
  bool _isWorkoutViewVisible = false;
  String? _workoutType;
  DateTime? _startedAt;
  DateTime? _activeSegmentStartedAt;
  Duration _accumulatedActiveDuration = Duration.zero;

  bool get isActive => _isActive;
  bool get isPaused => _isPaused;
  bool get isWorkoutViewVisible => _isWorkoutViewVisible;
  String? get workoutType => _workoutType;
  DateTime? get startedAt => _startedAt;
  Duration get elapsed => elapsedAt(_now());
  int get elapsedSeconds => elapsed.inSeconds;

  void start({required String workoutType, required DateTime startedAt}) {
    _isActive = true;
    _isPaused = false;
    _workoutType = workoutType;
    _startedAt = startedAt;
    _activeSegmentStartedAt = startedAt;
    _accumulatedActiveDuration = Duration.zero;
    _startTicker();
    notifyListeners();
  }

  void pause([DateTime? pausedAt]) {
    if (!_isActive || _isPaused) return;
    final now = pausedAt ?? _now();
    _accumulatedActiveDuration = elapsedAt(now);
    _activeSegmentStartedAt = null;
    _isPaused = true;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void resume([DateTime? resumedAt]) {
    if (!_isActive || !_isPaused) return;
    _activeSegmentStartedAt = resumedAt ?? _now();
    _isPaused = false;
    _startTicker();
    notifyListeners();
  }

  Duration elapsedAt(DateTime now) {
    final segmentStartedAt = _activeSegmentStartedAt;
    if (!_isActive ||
        _isPaused ||
        segmentStartedAt == null ||
        now.isBefore(segmentStartedAt)) {
      return _accumulatedActiveDuration;
    }
    return _accumulatedActiveDuration + now.difference(segmentStartedAt);
  }

  void finish() {
    _ticker?.cancel();
    _ticker = null;
    _isActive = false;
    _isPaused = false;
    _isWorkoutViewVisible = false;
    _workoutType = null;
    _startedAt = null;
    _activeSegmentStartedAt = null;
    _accumulatedActiveDuration = Duration.zero;
    notifyListeners();
  }

  void refresh() {
    if (_isActive) notifyListeners();
  }

  void setWorkoutViewVisible(bool visible) {
    final next = _isActive && visible;
    if (_isWorkoutViewVisible == next) return;
    _isWorkoutViewVisible = next;
    notifyListeners();
  }

  void _startTicker() {
    if (!_enableTicker || _ticker?.isActive == true) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isActive) notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
