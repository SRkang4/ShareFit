import 'package:flutter/material.dart';

import 'app_theme_color.dart';

class AppTheme {
  static ThemeData light(AppAccentColor accent) => _build(
    accent: accent,
    brightness: Brightness.light,
    scaffold: const Color(0xFFF5F5F7),
    surface: const Color(0xFFEFEFF4),
    card: Colors.white,
  );

  static ThemeData dark(AppAccentColor accent) => _build(
    accent: accent,
    brightness: Brightness.dark,
    scaffold: const Color(0xFF121418),
    surface: const Color(0xFF1D2026),
    card: const Color(0xFF252931),
  );

  static ThemeData _build({
    required AppAccentColor accent,
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color card,
  }) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent.color,
          brightness: brightness,
          surface: scaffold,
        ).copyWith(
          primary: accent.color,
          onPrimary: Colors.white,
          onPrimaryContainer: Colors.white,
          surfaceContainer: surface,
          surfaceContainerHigh: card,
          onSurface: dark ? const Color(0xFFF5F6F8) : const Color(0xFF151515),
          onSurfaceVariant: dark
              ? const Color(0xFFD0D2D6)
              : const Color(0xFF3F444B),
          outline: dark ? const Color(0xFF454A54) : const Color(0xFFD8DCE3),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Pretendard',
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      cardColor: surface,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(
          color: dark ? const Color(0xFF9EA3AC) : const Color(0xFF7A8088),
        ),
      ),
      dividerColor: scheme.outline,
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(foregroundColor: Colors.white),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHigh,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: scheme.primary,
        headerForegroundColor: scheme.onPrimary,
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : scheme.onSurface,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        todayForegroundColor: WidgetStatePropertyAll(scheme.primary),
        todayBorder: BorderSide(color: scheme.primary),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w900,
        ),
        headlineMedium: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w900,
        ),
        titleLarge: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w900,
        ),
        titleMedium: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        bodyLarge: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        bodySmall: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        labelMedium: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

extension ShareFitThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  Color foregroundFor(Color background) => background.computeLuminance() > 0.48
      ? const Color(0xFF1A1A1A)
      : const Color(0xFFF5F6F8);

  Color secondaryForegroundFor(Color background) =>
      background.computeLuminance() > 0.48
      ? const Color(0xFF3F444B)
      : const Color(0xFFD0D2D6);
}
