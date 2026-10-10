// lib/theme/app_theme.dart
// Binds AppPalette into ThemeData for both light and dark modes.
// main.dart calls AppTheme.dark() and AppTheme.light() for MaterialApp.

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';
import 'app_palette.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);
  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: p.background,
      extensions: [p],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.accent,
        onPrimary: p.background,
        secondary: p.accentSecondary,
        onSecondary: p.background,
        error: p.error,
        onError: Colors.white,
        surface: p.surface,
        onSurface: p.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: p.textPrimary),
        titleTextStyle: AppTextStyles.heading2.copyWith(
            color: p.textPrimary, fontSize: 18),
      ),
      dialogBackgroundColor: p.card,
      cardColor: p.card,
      dividerColor: p.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          borderSide: BorderSide(color: p.error),
        ),
        hintStyle: AppTextStyles.body.copyWith(color: p.textMuted),
        labelStyle: AppTextStyles.caption.copyWith(color: p.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.background,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: AppTextStyles.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accent),
      ),
      iconTheme: IconThemeData(color: p.textSecondary),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.accent.withOpacity(0.2),
        labelStyle: AppTextStyles.caption.copyWith(color: p.textSecondary),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull)),
      ),
      textTheme: TextTheme(
        headlineLarge:  AppTextStyles.heading1.copyWith(color: p.textPrimary),
        headlineMedium: AppTextStyles.heading2.copyWith(color: p.textPrimary),
        bodyLarge:      AppTextStyles.body.copyWith(color: p.textPrimary),
        bodyMedium:     AppTextStyles.body.copyWith(color: p.textSecondary),
        labelLarge:     AppTextStyles.button.copyWith(color: p.textPrimary),
        bodySmall:      AppTextStyles.caption.copyWith(color: p.textMuted),
      ),
    );
  }
}