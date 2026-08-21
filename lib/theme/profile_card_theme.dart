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
      case ProfileThemeIds.pink:
        return ProfileCardPalette(
          background: isDark
              ? const Color(0xFF3A2730)
              : const Color(0xFFFCECF2),
          foreground: isDark
              ? const Color(0xFFFFF7FA)
              : const Color(0xFF3B202A),
          secondaryForeground: isDark
              ? const Color(0xFFE3C9D3)
              : const Color(0xFF6F4B59),
          accent: isDark ? const Color(0xFFE8A2B8) : const Color(0xFFD8799A),
          border: isDark ? const Color(0xFF7B5261) : const Color(0xFFE7A9BC),
        );
      case ProfileThemeIds.yellow:
        return ProfileCardPalette(
          background: isDark
              ? const Color(0xFF3A3424)
              : const Color(0xFFFFF7D9),
          foreground: isDark
              ? const Color(0xFFFFF9E8)
              : const Color(0xFF3A321B),
          secondaryForeground: isDark
              ? const Color(0xFFDDD2B3)
              : const Color(0xFF6B6040),
          accent: isDark ? const Color(0xFFE3C36D) : const Color(0xFFD3A93D),
          border: isDark ? const Color(0xFF746543) : const Color(0xFFE7CD7B),
        );
      case ProfileThemeIds.mint:
        return ProfileCardPalette(
          background: isDark
              ? const Color(0xFF243630)
              : const Color(0xFFE8F5EF),
          foreground: isDark
              ? const Color(0xFFF4FFF9)
              : const Color(0xFF20372F),
          secondaryForeground: isDark
              ? const Color(0xFFC5DBD1)
              : const Color(0xFF4C695E),
          accent: isDark ? const Color(0xFF83C6AA) : const Color(0xFF72B89D),
          border: isDark ? const Color(0xFF4E7565) : const Color(0xFFA7D7C4),
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
