class ProfileCustomization {
  const ProfileCustomization({
    this.titleId = ProfileTitleIds.none,
    this.themeId = ProfileThemeIds.defaultTheme,
  });

  final String titleId;
  final String themeId;

  static const defaults = ProfileCustomization();

  String? get titleLabel => ProfileTitleIds.labelFor(titleId);

  Map<String, dynamic> toFirestore() => {
    'titleId': ProfileTitleIds.isValid(titleId)
        ? titleId
        : ProfileTitleIds.none,
    'themeId': ProfileThemeIds.isValid(themeId)
        ? themeId
        : ProfileThemeIds.defaultTheme,
  };

  factory ProfileCustomization.fromMap(Object? rawData) {
    if (rawData is! Map) return defaults;
    final data = Map<String, dynamic>.from(rawData);
    final rawTitleId = data['titleId'];
    final rawThemeId = data['themeId'];
    return ProfileCustomization(
      titleId: rawTitleId is String && ProfileTitleIds.isValid(rawTitleId)
          ? rawTitleId
          : ProfileTitleIds.none,
      themeId: rawThemeId is String && ProfileThemeIds.isValid(rawThemeId)
          ? rawThemeId
          : ProfileThemeIds.defaultTheme,
    );
  }

  factory ProfileCustomization.fromPublicProfile({
    Object? titleId,
    Object? themeId,
  }) {
    return ProfileCustomization.fromMap({
      'titleId': titleId,
      'themeId': themeId,
    });
  }
}

class ProfileTitleIds {
  static const none = 'none';
  static const consistent = 'consistent';
  static const completedToday = 'completedToday';
  static const strengthLover = 'strengthLover';
  static const runningLover = 'runningLover';
  static const shareFitPro = 'shareFitPro';

  static const labels = <String, String>{
    none: '칭호 없음',
    consistent: '꾸준한 운동인',
    completedToday: '오늘도 완료',
    strengthLover: '헬스 러버',
    runningLover: '러닝 러버',
    shareFitPro: 'ShareFit Pro',
  };

  static bool isValid(String id) => labels.containsKey(id);
  static String? labelFor(String id) => id == none ? null : labels[id];
}

class ProfileThemeIds {
  static const defaultTheme = 'default';
  static const pink = 'pink';
  static const yellow = 'yellow';
  static const mint = 'mint';

  static const labels = <String, String>{
    defaultTheme: '기본',
    pink: '핑크',
    yellow: '옐로',
    mint: '민트',
  };

  static bool isValid(String id) => labels.containsKey(id);
}
