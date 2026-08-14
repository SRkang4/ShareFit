import 'dart:io';

import 'package:flutter/services.dart';

class WorkoutProgressNotificationService {
  static const MethodChannel _channel = MethodChannel(
    'com.sharefit.app.sharefit/workout_progress_notification',
  );
  static const Duration _minimumUpdateInterval = Duration(seconds: 10);

  DateTime? _lastUpdateAt;
  bool _isActive = false;

  Future<void> startStrength({
    required int durationSeconds,
    required Iterable<String> bodyParts,
  }) async {
    await _start(
      title: '헬스 운동 중',
      content: _strengthContent(durationSeconds, bodyParts),
      durationSeconds: durationSeconds,
      isPaused: false,
    );
  }

  Future<void> startRunning({
    required int durationSeconds,
    required double distanceMeters,
  }) async {
    await _start(
      title: '러닝 운동 중',
      content: runningContent(durationSeconds, distanceMeters),
      durationSeconds: durationSeconds,
      isPaused: false,
    );
  }

  Future<void> updateStrength({
    required int durationSeconds,
    required Iterable<String> bodyParts,
    required bool isPaused,
    bool force = false,
  }) {
    return _update(
      title: isPaused ? '헬스 일시정지' : '헬스 운동 중',
      content: _strengthContent(durationSeconds, bodyParts),
      durationSeconds: durationSeconds,
      isPaused: isPaused,
      force: force,
    );
  }

  Future<void> updateRunning({
    required int durationSeconds,
    required double distanceMeters,
    required bool isPaused,
    bool force = false,
  }) {
    return _update(
      title: isPaused ? '러닝 일시정지' : '러닝 운동 중',
      content: runningContent(
        durationSeconds,
        distanceMeters,
        includePace: !isPaused,
      ),
      durationSeconds: durationSeconds,
      isPaused: isPaused,
      force: force,
    );
  }

  Future<void> stop() async {
    _isActive = false;
    _lastUpdateAt = null;
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('stop');
  }

  static double? averagePaceSecondsPerKm(
    int durationSeconds,
    double distanceMeters,
  ) {
    if (durationSeconds <= 0 || distanceMeters <= 0) return null;
    return durationSeconds / (distanceMeters / 1000);
  }

  static String formatPace(double paceSecondsPerKm) {
    final totalSeconds = paceSecondsPerKm.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes\'${seconds.toString().padLeft(2, '0')}"';
  }

  static String runningContent(
    int durationSeconds,
    double distanceMeters, {
    bool includePace = true,
  }) {
    final values = <String>[
      _formatElapsed(durationSeconds),
      _formatDistance(distanceMeters),
    ];
    if (includePace) {
      final pace = averagePaceSecondsPerKm(durationSeconds, distanceMeters);
      values.add(pace == null ? '페이스 측정 중' : '${formatPace(pace)}/km');
    }
    return values.join(' · ');
  }

  Future<void> _start({
    required String title,
    required String content,
    required int durationSeconds,
    required bool isPaused,
  }) async {
    _isActive = true;
    _lastUpdateAt = DateTime.now();
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('requestPermission');
    await _channel.invokeMethod<void>('show', {
      'title': title,
      'content': content,
      'durationSeconds': durationSeconds,
      'isPaused': isPaused,
    });
  }

  Future<void> _update({
    required String title,
    required String content,
    required int durationSeconds,
    required bool isPaused,
    required bool force,
  }) async {
    if (!_isActive || !Platform.isAndroid) return;
    final now = DateTime.now();
    if (!force &&
        _lastUpdateAt != null &&
        now.difference(_lastUpdateAt!) < _minimumUpdateInterval) {
      return;
    }
    _lastUpdateAt = now;
    await _channel.invokeMethod<void>('show', {
      'title': title,
      'content': content,
      'durationSeconds': durationSeconds,
      'isPaused': isPaused,
    });
  }

  static String _strengthContent(
    int durationSeconds,
    Iterable<String> bodyParts,
  ) {
    final parts = bodyParts.where((part) => part.trim().isNotEmpty).join(', ');
    final shortenedParts = parts.length > 24
        ? '${parts.substring(0, 23)}…'
        : parts;
    if (shortenedParts.isEmpty) return _formatElapsed(durationSeconds);
    return '${_formatElapsed(durationSeconds)} · $shortenedParts';
  }

  static String _formatElapsed(int durationSeconds) {
    final safeSeconds = durationSeconds < 0 ? 0 : durationSeconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    return hours > 0 ? '$hours시간 $minutes분' : '$minutes분';
  }

  static String _formatDistance(double distanceMeters) {
    if (!distanceMeters.isFinite || distanceMeters <= 0) return '0m';
    if (distanceMeters < 1000) return '${distanceMeters.round()}m';
    final kilometers = distanceMeters / 1000;
    return '${kilometers.toStringAsFixed(kilometers < 10 ? 2 : 1)}km';
  }
}
