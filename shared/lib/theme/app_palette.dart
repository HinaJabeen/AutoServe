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
  // Text/icon color for content sitting on an `accent` fill (button labels).
  final Color onAccent;
  final Color badgeBackground;
  final Color badgeText;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;

  final Color success;
  final Color warning;
  final Color error;

  final Color shadowColor;
  final Color statusAvailable;
  final Color statusReserved;
  final Color statusSold;
  final Color glassFill;
  final Color glassBorder;

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
    required this.onAccent,
    required this.badgeBackground,
    required this.badgeText,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.error,
    required this.shadowColor,
    required this.statusAvailable,
    required this.statusReserved,
    required this.statusSold,
    required this.glassFill,
    required this.glassBorder,
  });

  // Premium "Control Room" dark mode — Deep Obsidian + Mercedes Ambient Blue.
  // See docs/design.md §5.1.
  static const dark = AppPalette(
    background: Color(0xFF050505),
    surface: Color(0xFF121212),
    surfaceElevated: Color(0xFF212121),
    card: Color(0xFF1A1A1A),
    border: Color(0xFF2A2A2E),
    borderSubtle: Color(0xFF1F1F23),
    accent: Color(0xFF0066FF),
    accentSecondary: Color(0xFF3385FF),
    accentGlow: Color(0x330066FF),
    onAccent: Color(0xFFFFFFFF),
    badgeBackground: Color(0xFF0A1F3D),
    badgeText: Color(0xFF3385FF),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFF8E8E93),
    textTertiary: Color(0xFF6E6E73),
    textMuted: Color(0xFF5A5A60),
    success: Color(0xFF00E5A3),
    warning: Color(0xFFFFB703),
    error: Color(0xFFFF4D4D),
    shadowColor: Color(0xFF000000),
    statusAvailable: Color(0xFF00E5A3),
    statusReserved: Color(0xFFFFB703),
    statusSold: Color(0xFF9775FA),
    glassFill: Color(0xFF1A1A1A),
    glassBorder: Color(0xFF2A2A2E),
  );

  // Premium light mode — Pearl White + Matte Silver, same Ambient Blue accent.
  // See docs/design.md §5.1.
  static const light = AppPalette(
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFF3F4F6),
    surfaceElevated: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE2E4E9),
    borderSubtle: Color(0xFFECEDF0),
    accent: Color(0xFF0066FF),
    accentSecondary: Color(0xFF3385FF),
    accentGlow: Color(0x330066FF),
    onAccent: Color(0xFFFFFFFF),
    badgeBackground: Color(0xFFE6EFFF),
    badgeText: Color(0xFF0052CC),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF4B5563),
    textTertiary: Color(0xFF6B7280),
    textMuted: Color(0xFF8A8F98),
    success: Color(0xFF2E8B57),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    shadowColor: Color(0xFF111111),
    statusAvailable: Color(0xFF2E8B57),
    statusReserved: Color(0xFFD97706),
    statusSold: Color(0xFF7C4DFF),
    glassFill: Color(0xFFFFFFFF),
    glassBorder: Color(0xFFE2E4E9),
  );

  // ── apps/customer — deep jewel emerald ─────────────────────────────────────
  // The consumer app's own brand palette (the dashboard keeps Ambient Blue
  // above). See docs/design.md §5.2.
  //
  // The brand color is a dark, slightly bluish gemstone emerald (#006A4E),
  // not a bright/neon green. It is dark enough to carry white text, so
  // `onAccent` is white in both modes. On the charcoal dark background that
  // same depth makes it hard to see as *text* or a thin line, so
  // `accentSecondary` is the shade for emerald text/icons/focus rings on the
  // page background: a touch brighter than `accent` in light mode, a soft
  // jewel tint in dark mode.

  // Dark mode — charcoal + slate surfaces, emerald accent (lifted one step
  // from the light-mode brand color so fills don't sink into the charcoal).
  static const emeraldDark = AppPalette(
    background: Color(0xFF0F1315),
    surface: Color(0xFF171C1F),
    surfaceElevated: Color(0xFF222A2E),
    card: Color(0xFF1B2124),
    border: Color(0xFF2C353A),
    borderSubtle: Color(0xFF222A2E),
    accent: Color(0xFF00755E),
    accentSecondary: Color(0xFF3DBE98),
    accentGlow: Color(0x4000A37F),
    onAccent: Color(0xFFFFFFFF),
    badgeBackground: Color(0xFF0B2A22),
    badgeText: Color(0xFF3DBE98),
    textPrimary: Color(0xFFF2F5F4),
    textSecondary: Color(0xFFA3AEB3),
    textTertiary: Color(0xFF7C878C),
    textMuted: Color(0xFF5E686D),
    success: Color(0xFF34D399),
    warning: Color(0xFFFFB703),
    error: Color(0xFFFF5A5A),
    shadowColor: Color(0xFF000000),
    statusAvailable: Color(0xFF34D399),
    statusReserved: Color(0xFFFFB703),
    statusSold: Color(0xFF9775FA),
    glassFill: Color(0xFF1B2124),
    glassBorder: Color(0xFF2C353A),
  );

  // Light mode — pearl white surfaces, emerald accent.
  static const emeraldLight = AppPalette(
    background: Color(0xFFFAFAF8),
    surface: Color(0xFFF2F4F3),
    surfaceElevated: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFDFE4E1),
    borderSubtle: Color(0xFFECEFED),
    accent: Color(0xFF006A4E),
    accentSecondary: Color(0xFF00755E),
    accentGlow: Color(0x33006A4E),
    onAccent: Color(0xFFFFFFFF),
    badgeBackground: Color(0xFFE0F2EC),
    badgeText: Color(0xFF005A43),
    textPrimary: Color(0xFF101513),
    textSecondary: Color(0xFF4A5551),
    textTertiary: Color(0xFF6A7571),
    textMuted: Color(0xFF8B9692),
    success: Color(0xFF1E8E4E),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    shadowColor: Color(0xFF101513),
    statusAvailable: Color(0xFF1E8E4E),
    statusReserved: Color(0xFFD97706),
    statusSold: Color(0xFF7C4DFF),
    glassFill: Color(0xFFFFFFFF),
    glassBorder: Color(0xFFDFE4E1),
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
    Color? onAccent,
    Color? badgeBackground,
    Color? badgeText,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? error,
    Color? shadowColor,
    Color? statusAvailable,
    Color? statusReserved,
    Color? statusSold,
    Color? glassFill,
    Color? glassBorder,
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
      onAccent: onAccent ?? this.onAccent,
      badgeBackground: badgeBackground ?? this.badgeBackground,
      badgeText: badgeText ?? this.badgeText,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      shadowColor: shadowColor ?? this.shadowColor,
      statusAvailable: statusAvailable ?? this.statusAvailable,
      statusReserved: statusReserved ?? this.statusReserved,
      statusSold: statusSold ?? this.statusSold,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
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
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      badgeBackground: Color.lerp(badgeBackground, other.badgeBackground, t)!,
      badgeText: Color.lerp(badgeText, other.badgeText, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      statusAvailable: Color.lerp(statusAvailable, other.statusAvailable, t)!,
      statusReserved: Color.lerp(statusReserved, other.statusReserved, t)!,
      statusSold: Color.lerp(statusSold, other.statusSold, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}