import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/controllers/workout_session_controller.dart';
import 'package:sharefit/widgets/active_workout_timer_pill.dart';

void main() {
  late WorkoutSessionController session;

  setUp(() {
    session = WorkoutSessionController(enableTicker: false);
  });

  tearDown(() => session.dispose());

  testWidgets('운동이 없으면 전역 timer pill을 숨긴다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [ActiveWorkoutTimerPill(controller: session, onTap: () {})],
        ),
      ),
    );

    expect(find.text('00:00:00'), findsNothing);
  });

  testWidgets('운동 중 다른 화면에서는 timer pill을 표시한다', (tester) async {
    session.start(workoutType: 'strength', startedAt: DateTime.now());
    session.setWorkoutViewVisible(false);
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [ActiveWorkoutTimerPill(controller: session, onTap: () {})],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('00:00:00'), findsOneWidget);
  });

  testWidgets('진행 중 운동 화면에서는 전역 timer pill을 숨긴다', (tester) async {
    session.start(workoutType: 'strength', startedAt: DateTime.now());
    session.setWorkoutViewVisible(true);
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [ActiveWorkoutTimerPill(controller: session, onTap: () {})],
        ),
      ),
    );

    expect(find.text('00:00:00'), findsNothing);
  });
}
