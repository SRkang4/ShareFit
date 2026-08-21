import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/models/profile_customization.dart';

void main() {
  test('uses safe defaults for missing or invalid customization data', () {
    expect(ProfileCustomization.fromMap(null).titleId, ProfileTitleIds.none);
    expect(
      ProfileCustomization.fromMap({'titleId': 'unknown'}).themeId,
      ProfileThemeIds.defaultTheme,
    );
  });

  test('restores valid title and profile theme IDs', () {
    final customization = ProfileCustomization.fromMap({
      'titleId': ProfileTitleIds.runningLover,
      'themeId': ProfileThemeIds.purple,
    });

    expect(customization.titleLabel, '러닝 러버');
    expect(customization.themeId, ProfileThemeIds.purple);
  });

  test('title none has no visible label', () {
    expect(ProfileCustomization.defaults.titleLabel, isNull);
  });
}
