import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/data/exercise_catalog.dart';

void main() {
  test('provides ten exercises for every supported body part', () {
    expect(ExerciseCatalog.byBodyPart.keys, ['가슴', '등', '어깨', '하체', '팔']);
    for (final exercises in ExerciseCatalog.byBodyPart.values) {
      expect(exercises, hasLength(10));
    }
  });

  test('combines selected body parts in catalog order without duplicates', () {
    final exercises = ExerciseCatalog.forBodyParts({'팔', '가슴'});

    expect(exercises, hasLength(20));
    expect(exercises.first, '벤치프레스');
    expect(exercises.last, '킥백');
    expect(exercises.toSet(), hasLength(exercises.length));
  });
}
