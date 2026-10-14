import 'package:flutter/material.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_palette.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, outline }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isOutline = variant == AppButtonVariant.outline;
    final bgColor = switch (variant) {
      AppButtonVariant.primary => p.accent,
      AppButtonVariant.secondary => p.surfaceElevated,
      AppButtonVariant.outline => Colors.transparent,
    };
    final fgColor =
        variant == AppButtonVariant.primary ? p.onAccent : p.textPrimary;

    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          // Keep the brand fill while loading instead of Material's default
          // grey disabled state — the spinner already signals "busy".
          disabledBackgroundColor:
              isLoading ? bgColor.withValues(alpha: 0.7) : null,
          disabledForegroundColor: isLoading ? fgColor : null,
          elevation: 0,
          side: isOutline
              ? BorderSide(color: p.border, width: 1.5)
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fgColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppDimensions.iconSizeS),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: AppTextStyles.button.copyWith(color: fgColor),
                  ),
                ],
              ),
      ),
    );
  }
}
