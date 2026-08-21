import 'package:flutter/material.dart';

import '../models/profile_customization.dart';

class ProfileCardPalette {
  const ProfileCardPalette({
    required this.background,
    required this.foreground,
    required this.secondaryForeground,
    required this.accent,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color secondaryForeground;
  final Color accent;
  final Color border;

  static ProfileCardPalette resolve(BuildContext context, String themeId) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (themeId) {
      case ProfileThemeIds.blue:
        return ProfileCardPalette(
          background: isDark
              ? const Color(0xFF1C2948)
              : const Color(0xFFE9EFFF),
          foreground: isDark
              ? const Color(0xFFF6F8FF)
              : const Color(0xFF17213B),
          secondaryForeground: isDark
              ? const Color(0xFFD4DCF2)
              : const Color(0xFF46516D),
          accent: const Color(0xFF5267E8),
          border: const Color(0xFF5267E8),
        );
      case ProfileThemeIds.purple:
        return ProfileCardPalette(
          background: isDark
              ? const Color(0xFF302443)
              : const Color(0xFFF1EAFE),
          foreground: isDark
              ? const Color(0xFFFBF8FF)
              : const Color(0xFF2B1D3B),
          secondaryForeground: isDark
              ? const Color(0xFFDFD3EE)
              : const Color(0xFF5E4B70),
          accent: const Color(0xFF7656C9),
          border: const Color(0xFF7656C9),
        );
      case ProfileThemeIds.dark:
        return const ProfileCardPalette(
          background: Color(0xFF252931),
          foreground: Color(0xFFF7F7F8),
          secondaryForeground: Color(0xFFD0D2D6),
          accent: Color(0xFF8D9AF0),
          border: Color(0xFF4D535E),
        );
      default:
        return ProfileCardPalette(
          background: colors.surfaceContainer,
          foreground: colors.onSurface,
          secondaryForeground: colors.onSurfaceVariant,
          accent: colors.primary,
          border: Colors.transparent,
        );
    }
  }
}
