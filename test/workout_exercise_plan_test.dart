import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/screens/workout_screen.dart';
import 'package:sharefit/utils/workout_exercise_plan.dart';

void main() {
  test('removes null, empty, and whitespace-only planned exercises', () {
    final names = normalizePlannedExerciseNames([
      '벤치프레스',
      null,
      '',
      '   ',
      '  인클라인 덤벨프레스  ',
    ]);

    expect(names, ['벤치프레스', '인클라인 덤벨프레스']);
  });

  test('creates active exercise data with the prepared name and one set', () {
    final exercise = ExerciseCardData(exerciseName: '벤치프레스');
    addTearDown(exercise.dispose);

    expect(exercise.exerciseNameController.text, '벤치프레스');
    expect(exercise.sets, hasLength(1));
    expect(exercise.sets.single.weightController.text, isEmpty);
    expect(exercise.sets.single.repsController.text, isEmpty);
  });

  test('changing an exercise name preserves its existing set data', () {
    final exercise = ExerciseCardData(exerciseName: '벤치프레스');
    addTearDown(exercise.dispose);
    final originalSet = exercise.sets.single;
    originalSet.weightController.text = '80';
    originalSet.repsController.text = '10';
    originalSet.isDone = true;

    exercise.updateExerciseName('인클라인 벤치프레스');

    expect(exercise.exerciseNameController.text, '인클라인 벤치프레스');
    expect(exercise.sets.single, same(originalSet));
    expect(exercise.sets.single.weightController.text, '80');
    expect(exercise.sets.single.repsController.text, '10');
    expect(exercise.sets.single.isDone, isTrue);
  });
}
