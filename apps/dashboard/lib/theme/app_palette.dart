import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color card;
  final Color border;
  final Color borderSubtle;

  final Color accent;
  final Color accentSecondary;
  final Color accentGlow;
  final Color badgeBackground;
  final Color badgeText;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;

  final Color success;
  final Color warning;
  final Color error;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.card,
    required this.border,
    required this.borderSubtle,
    required this.accent,
    required this.accentSecondary,
    required this.accentGlow,
    required this.badgeBackground,
    required this.badgeText,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.error,
  });

  static const dark = AppPalette(
    background: Color(0xFF090B0D),
    surface: Color(0xFF101317),
    surfaceElevated: Color(0xFF161A20),
    card: Color(0xFF12161B),
    border: Color(0xFF222831),
    borderSubtle: Color(0xFF1A1F26),
    accent: Color(0xFF00E5FF),
    accentSecondary: Color(0xFF00B4D8),
    accentGlow: Color(0x3300E5FF),
    badgeBackground: Color(0xFF0E2229),
    badgeText: Color(0xFF00E5FF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8B98A5),
    textTertiary: Color(0xFF4B5663),
    textMuted: Color(0xFF5A6573),
    success: Color(0xFF00E5A3),
    warning: Color(0xFFFFB703),
    error: Color(0xFFFF4D4D),
  );

  static const light = AppPalette(
    background: Color(0xFFF3ECE5),
    surface: Color(0xFFEBE2DA),
    surfaceElevated: Color(0xFFFFFFFF),
    card: Color(0xFFFAF7F3),
    border: Color(0xFFDECFC3),
    borderSubtle: Color(0xFFEADFD6),
    accent: Color(0xFFE59235),
    accentSecondary: Color(0xFFC8751B),
    accentGlow: Color(0x33E59235),
    badgeBackground: Color(0xFFFCECDA),
    badgeText: Color(0xFFB06208),
    textPrimary: Color(0xFF1E1A16),
    textSecondary: Color(0xFF6E645A),
    textTertiary: Color(0xFF9E9286),
    textMuted: Color(0xFF85796E),
    success: Color(0xFF2E8B57),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
  );

  @override
  ThemeExtension<AppPalette> copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? card,
    Color? border,
    Color? borderSubtle,
    Color? accent,
    Color? accentSecondary,
    Color? accentGlow,
    Color? badgeBackground,
    Color? badgeText,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      card: card ?? this.card,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      accent: accent ?? this.accent,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      accentGlow: accentGlow ?? this.accentGlow,
      badgeBackground: badgeBackground ?? this.badgeBackground,
      badgeText: badgeText ?? this.badgeText,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  ThemeExtension<AppPalette> lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      badgeBackground: Color.lerp(badgeBackground, other.badgeBackground, t)!,
      badgeText: Color.lerp(badgeText, other.badgeText, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}