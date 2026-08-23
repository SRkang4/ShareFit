import 'package:flutter/material.dart';

import '../controllers/workout_session_controller.dart';

abstract final class WorkoutTimerPillLayout {
  static const double safeAreaOffset = 7;
  static const double right = 20;
  static const double height = 38;
  static const double horizontalPadding = 13;
  static const double radius = 100;

  static double screenTop(BuildContext context) {
    return MediaQuery.paddingOf(context).top + safeAreaOffset;
  }
}

class WorkoutTimerPill extends StatelessWidget {
  const WorkoutTimerPill({
    super.key,
    required this.elapsedSeconds,
    required this.isPaused,
    this.onTap,
    this.semanticLabel,
  });

  final int elapsedSeconds;
  final bool isPaused;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: WorkoutTimerPillLayout.height,
      padding: const EdgeInsets.symmetric(
        horizontal: WorkoutTimerPillLayout.horizontalPadding,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPaused) ...[
            const Icon(Icons.pause_rounded, size: 17, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Text(
            formatWorkoutDuration(elapsedSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(WorkoutTimerPillLayout.radius),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.16),
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(
                  WorkoutTimerPillLayout.radius,
                ),
                child: content,
              ),
      ),
    );
  }
}

class ActiveWorkoutTimerPill extends StatelessWidget {
  const ActiveWorkoutTimerPill({
    super.key,
    required this.onTap,
    this.controller,
  });

  final VoidCallback onTap;
  final WorkoutSessionController? controller;

  @override
  Widget build(BuildContext context) {
    final session = controller ?? WorkoutSessionController.instance;
    return Positioned(
      top: WorkoutTimerPillLayout.screenTop(context),
      right: WorkoutTimerPillLayout.right,
      child: AnimatedBuilder(
        animation: session,
        builder: (context, child) {
          final visible = session.isActive && !session.isWorkoutViewVisible;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.0).animate(animation),
                alignment: Alignment.topRight,
                child: child,
              ),
            ),
            child: visible
                ? WorkoutTimerPill(
                    key: const ValueKey('active-workout-timer'),
                    elapsedSeconds: session.elapsedSeconds,
                    isPaused: session.isPaused,
                    semanticLabel: session.isPaused
                        ? '일시정지된 운동으로 돌아가기'
                        : '진행 중인 운동으로 돌아가기',
                    onTap: onTap,
                  )
                : const SizedBox.shrink(
                    key: ValueKey('inactive-workout-timer'),
                  ),
          );
        },
      ),
    );
  }
}

String formatWorkoutDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${remainingSeconds.toString().padLeft(2, '0')}';
}
