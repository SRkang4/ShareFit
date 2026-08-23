class ExerciseCatalog {
  const ExerciseCatalog._();

  static const Map<String, List<String>> byBodyPart = {
    '가슴': [
      '벤치프레스',
      '인클라인 벤치프레스',
      '디클라인 벤치프레스',
      '덤벨 벤치프레스',
      '인클라인 덤벨프레스',
      '체스트프레스',
      '펙덱 플라이',
      '케이블 플라이',
      '딥스',
      '푸시업',
    ],
    '등': [
      '랫풀다운',
      '풀업',
      '친업',
      '바벨 로우',
      '덤벨 로우',
      '원암 덤벨 로우',
      '시티드 케이블 로우',
      '티바 로우',
      '스트레이트암 풀다운',
      '머신 로우',
    ],
    '어깨': [
      '오버헤드 프레스',
      '바벨 숌더프레스',
      '덤벨 숌더프레스',
      '아놀드 프레스',
      '사이드 레터럴 레이즈',
      '프론트 레이즈',
      '리어 델트 플라이',
      '페이스 풀',
      '머신 숌더프레스',
      '업라이트 로우',
    ],
    '하체': [
      '스쿼트',
      '프론트 스쿼트',
      '레그프레스',
      '레그 익스텐션',
      '레그 컬',
      '런지',
      '불가리안 스플릿 스쿼트',
      '루마니안 데드리프트',
      '힙 쓰러스트',
      '카프 레이즈',
    ],
    '팔': [
      '바벨 컬',
      '덤벨 컬',
      '해머 컬',
      '프리처 컬',
      '케이블 컬',
      '트라이셉스 푸시다운',
      '오버헤드 트라이셉스 익스텐션',
      '스컬 크러셔',
      '클로즈그립 벤치프레스',
      '킥백',
    ],
  };

  static List<String> forBodyParts(Iterable<String> bodyParts) {
    final exercises = <String>{};
    for (final bodyPart in byBodyPart.keys) {
      if (bodyParts.contains(bodyPart)) {
        exercises.addAll(byBodyPart[bodyPart]!);
      }
    }
    return exercises.toList(growable: false);
  }
}
