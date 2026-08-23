import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/models/workout_record.dart';
import 'package:sharefit/widgets/workout_record_detail.dart';

void main() {
  final workout = WorkoutRecord(
    id: 'workout-1',
    userId: 'owner',
    type: 'strength',
    startedAt: DateTime.utc(2026, 8, 23, 12),
    endedAt: DateTime.utc(2026, 8, 23, 13),
    durationSeconds: 3600,
    strength: const StrengthWorkoutData(
      bodyParts: ['가슴'],
      exercises: [
        StrengthExerciseData(
          name: '인클라인 벤치프레스',
          sets: [StrengthSetData(weightKg: 80, reps: 10)],
        ),
      ],
      completedSetCount: 1,
      totalVolumeKg: 800,
    ),
  );

  testWidgets('헬스 상세가 저장된 종목과 세트 데이터를 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutRecordDetailSheet(
            workout: workout,
            onDelete: () async {},
          ),
        ),
      ),
    );

    expect(find.text('헬스 기록'), findsOneWidget);
    expect(find.text('인클라인 벤치프레스'), findsOneWidget);
    expect(find.text('1세트'), findsAtLeastNWidgets(2));
    expect(find.text('80kg × 10회'), findsOneWidget);
    expect(find.text('800kg'), findsOneWidget);
  });

  testWidgets('삭제 취소 시 삭제 콜백을 호출하지 않고 상세를 유지한다', (tester) async {
    var deleteCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutRecordDetailSheet(
            workout: workout,
            onDelete: () async => deleteCalls++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.text('운동 기록을 삭제할까요?'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(deleteCalls, 0);
    expect(find.text('헬스 기록'), findsOneWidget);
  });
}
