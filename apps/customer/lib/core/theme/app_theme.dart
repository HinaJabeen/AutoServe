// lib/core/theme/app_theme.dart
//
// Binds the deep jewel emerald palettes (AppPalette.emeraldLight/emeraldDark,
// in shared/) into ThemeData. Widgets read colors via `context.palette.xxx`,
// never a hex literal — see docs/design.md §4–5.2.

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppPalette.emeraldLight, Brightness.light);
  static ThemeData dark() => _build(AppPalette.emeraldDark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

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
        error: p.error,
        onError: p.background,
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
        titleTextStyle: AppTextStyles.heading3.copyWith(color: p.textPrimary),
      ),
      cardColor: p.card,
      dividerColor: p.border,
      dividerTheme: DividerThemeData(color: p.borderSubtle, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: p.textSecondary),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.textPrimary,
        contentTextStyle: AppTextStyles.body.copyWith(color: p.background),
      ),
      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: p.accentSecondary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceElevated,
        contentPadding: const EdgeInsets.all(AppDimensions.paddingM),
        border: _inputBorder(p.border),
        enabledBorder: _inputBorder(p.border),
        focusedBorder: _inputBorder(p.accentSecondary, 1.5),
        errorBorder: _inputBorder(p.error),
        focusedErrorBorder: _inputBorder(p.error, 1.5),
        hintStyle: AppTextStyles.body.copyWith(color: p.textMuted),
        labelStyle: AppTextStyles.body.copyWith(color: p.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          elevation: 0,
          shape: buttonShape,
          padding: buttonPadding,
          textStyle: AppTextStyles.button,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          shape: buttonShape,
          padding: buttonPadding,
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.border),
          shape: buttonShape,
          padding: buttonPadding,
          textStyle: AppTextStyles.button,
        ),
      ),
      // Emerald as text / thin lines uses accentSecondary — the deep `accent`
      // is too dark to read on the charcoal dark-mode background (see
      // AppPalette's emerald notes).
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accentSecondary),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: p.textSecondary,
          selectedForegroundColor: p.badgeText,
          selectedBackgroundColor: p.badgeBackground,
          side: BorderSide(color: p.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.badgeBackground,
        labelStyle: AppTextStyles.caption.copyWith(color: p.textSecondary),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: AppTextStyles.heading1.copyWith(color: p.textPrimary),
        headlineMedium: AppTextStyles.heading2.copyWith(color: p.textPrimary),
        titleLarge: AppTextStyles.heading3.copyWith(color: p.textPrimary),
        bodyLarge: AppTextStyles.body.copyWith(color: p.textPrimary),
        bodyMedium: AppTextStyles.body.copyWith(color: p.textSecondary),
        labelLarge: AppTextStyles.button.copyWith(color: p.textPrimary),
        bodySmall: AppTextStyles.caption.copyWith(color: p.textMuted),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        borderSide: BorderSide(color: color, width: width),
      );
}
