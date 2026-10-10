// apps/dashboard/lib/widgets/theme_toggle_button.dart
//
// Sun / moon theme toggle — a frosted glass pill with two icon targets.
// The active mode gets a soft glow; tapping either icon sets that mode
// directly (rather than just flipping), so it reads correctly regardless
// of which state you're currently in.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:dashboard/theme/app_palette.dart';
import 'package:dashboard/theme/theme_provider.dart';

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final palette = context.palette;
    final isDark = mode == AppThemeMode.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: palette.glassFill.withOpacity(isDark ? 0.06 : 0.55),
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(color: palette.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeIcon(
                icon: Icons.light_mode_rounded,
                active: mode == AppThemeMode.light,
                activeColor: const Color(0xFFC9A227),
                onTap: notifier.setLight,
                tooltip: 'Light theme',
              ),
              _ModeIcon(
                icon: Icons.dark_mode_rounded,
                active: mode == AppThemeMode.dark,
                activeColor: palette.accent,
                onTap: notifier.setDark,
                tooltip: 'Dark theme',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeIcon extends StatelessWidget {
  const _ModeIcon({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? activeColor.withOpacity(0.16) : Colors.transparent,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.35),
                        blurRadius: 12,
                        spreadRadius: -1,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              size: AppDimensions.iconSizeM - 2,
              color: active ? activeColor : palette.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
