import 'package:flutter/material.dart';

enum AppAccentColor { blue, green, purple, coral }

extension AppAccentColorX on AppAccentColor {
  String get label => switch (this) {
    AppAccentColor.blue => '블루',
    AppAccentColor.green => '그린',
    AppAccentColor.purple => '퍼플',
    AppAccentColor.coral => '코랄',
  };

  Color get color => switch (this) {
    AppAccentColor.blue => const Color(0xFF5267E8),
    AppAccentColor.green => const Color(0xFF2E8B70),
    AppAccentColor.purple => const Color(0xFF7656C9),
    AppAccentColor.coral => const Color(0xFFE06B52),
  };
}
