import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';
import '../theme/app_palette.dart';
import '../theme/app_text_styles.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      enabled: enabled,
      style: AppTextStyles.body.copyWith(color: p.textPrimary),
      cursorColor: p.accentSecondary,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTextStyles.body.copyWith(color: p.textSecondary),
        floatingLabelStyle:
            AppTextStyles.caption.copyWith(color: p.accentSecondary),
        hintStyle: AppTextStyles.body.copyWith(color: p.textMuted),
        errorStyle: AppTextStyles.caption.copyWith(color: p.error),
        errorMaxLines: 2,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon,
                size: AppDimensions.iconSizeM, color: p.textTertiary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: p.surfaceElevated,
        border: border(p.border),
        enabledBorder: border(p.border),
        disabledBorder: border(p.borderSubtle),
        focusedBorder: border(p.accentSecondary, 1.5),
        errorBorder: border(p.error),
        focusedErrorBorder: border(p.error, 1.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingM,
        ),
      ),
    );
  }
}
