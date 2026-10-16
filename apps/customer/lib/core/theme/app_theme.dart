// lib/core/theme/app_theme.dart
//
// Luxury earthy theme: deep pine / sage / caramel / gold on porcelain
// (AppPalette.forestLight / forestDark, in shared/). Widgets read colors via
// `context.palette.xxx`, never a hex literal. Buttons are pills
// (StadiumBorder); cards and sheets use generous radii.

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// Corner radii for the redesigned surfaces.
class AppRadii {
  AppRadii._();
  static const card = 28.0;
  static const sheet = 32.0;
  static const glass = 24.0;
  static const field = 16.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppPalette.forestLight, Brightness.light);
  static ThemeData dark() => _build(AppPalette.forestDark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    const pill = StadiumBorder();
    const pillPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    final buttonText = AppTextStyles.button.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: p.background,
      extensions: [p],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.accent,
        onPrimary: p.onAccent,
        secondary: p.accentSecondary,
        onSecondary: p.background,
        tertiary: p.warmAccent,
        error: p.error,
        onError: Colors.white,
        surface: p.surface,
        onSurface: p.textPrimary,
        onSurfaceVariant: p.textSecondary,
        outline: p.border,
        outlineVariant: p.borderSubtle,
        shadow: p.shadowColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: p.textPrimary),
        titleTextStyle: AppTextStyles.heading3.copyWith(
          color: p.textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
      ),
      cardColor: p.card,
      dividerColor: p.border,
      dividerTheme: DividerThemeData(color: p.borderSubtle, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: p.textSecondary),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.light ? const Color(0xFF0C3B2E) : p.surfaceElevated,
        contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
        actionTextColor: p.highlight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.field)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: _inputBorder(p.border),
        enabledBorder: _inputBorder(p.border),
        focusedBorder: _inputBorder(p.accent, 1.8),
        errorBorder: _inputBorder(p.error),
        focusedErrorBorder: _inputBorder(p.error, 1.8),
        hintStyle: AppTextStyles.body.copyWith(color: p.textMuted),
        labelStyle: AppTextStyles.body.copyWith(color: p.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.border,
          disabledForegroundColor: p.textMuted,
          elevation: 0,
          shape: pill,
          padding: pillPadding,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          shape: pill,
          padding: pillPadding,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accentSecondary,
          side: BorderSide(color: p.accentSecondary.withValues(alpha: 0.35), width: 1.4),
          shape: pill,
          padding: pillPadding,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentSecondary,
          shape: pill,
          textStyle: AppTextStyles.bodyBold,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: p.textSecondary,
          selectedForegroundColor: p.onAccent,
          selectedBackgroundColor: p.accent,
          side: BorderSide(color: p.border),
          shape: pill,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceElevated,
        selectedColor: p.accent,
        labelStyle: AppTextStyles.caption.copyWith(color: p.textPrimary, fontWeight: FontWeight.w600),
        secondaryLabelStyle: AppTextStyles.caption.copyWith(color: p.onAccent, fontWeight: FontWeight.w700),
        side: BorderSide(color: p.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      textTheme: TextTheme(
        headlineLarge: AppType.title(p, size: 30),
        headlineMedium: AppType.title(p, size: 24),
        titleLarge: AppTextStyles.heading3.copyWith(color: p.textPrimary, fontWeight: FontWeight.w800),
        bodyLarge: AppTextStyles.body.copyWith(color: p.textPrimary),
        bodyMedium: AppTextStyles.body.copyWith(color: p.textSecondary),
        labelLarge: buttonText.copyWith(color: p.textPrimary),
        bodySmall: AppTextStyles.caption.copyWith(color: p.textMuted),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Display typography for the luxury look: heavy, tightly-tracked sans for
/// vehicle titles and prices; spaced caps for small "eyebrow" labels.
class AppType {
  AppType._();

  static TextStyle title(AppPalette p, {double size = 26, Color? color}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.04 * size,
        height: 1.12,
        color: color ?? p.textPrimary,
      );

  static TextStyle price(AppPalette p, {double size = 22, Color? color}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.02 * size,
        height: 1.2,
        color: color ?? p.accentSecondary,
      );

  static TextStyle eyebrow(AppPalette p, {Color? color}) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: color ?? p.textTertiary,
      );
}
