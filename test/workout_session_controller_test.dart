import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/controllers/workout_session_controller.dart';

void main() {
  late DateTime now;
  late WorkoutSessionController session;

  setUp(() {
    now = DateTime.utc(2026, 8, 23, 1);
    session = WorkoutSessionController(now: () => now, enableTicker: false);
  });

  tearDown(() => session.dispose());

  test('시작 후 실제 시각 차이로 활성 운동 시간을 계산한다', () {
    session.start(workoutType: 'strength', startedAt: now);
    now = now.add(const Duration(minutes: 3, seconds: 12));

    expect(session.isActive, isTrue);
    expect(session.workoutType, 'strength');
    expect(session.elapsedSeconds, 192);
  });

  test('일시정지 중에는 시간이 멈추고 재개 후 이어서 증가한다', () {
    session.start(workoutType: 'running', startedAt: now);
    now = now.add(const Duration(seconds: 40));
    session.pause();

    now = now.add(const Duration(minutes: 5));
    expect(session.isPaused, isTrue);
    expect(session.elapsedSeconds, 40);

    session.resume();
    now = now.add(const Duration(seconds: 20));
    expect(session.isPaused, isFalse);
    expect(session.elapsedSeconds, 60);
  });

  test('종료하면 전역 active 상태와 시간이 초기화된다', () {
    session.start(workoutType: 'strength', startedAt: now);
    now = now.add(const Duration(seconds: 25));
    session.finish();

    expect(session.isActive, isFalse);
    expect(session.elapsedSeconds, 0);
    expect(session.workoutType, isNull);
  });
}
