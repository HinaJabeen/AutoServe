// lib/core/widgets/glass_container.dart

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../theme/app_theme.dart';

/// Frosted-glass surface: blurs whatever is behind it. White @ 65% in light
/// mode, pine @ 50% in dark mode (the palette's `glassFill`), with a soft
/// white rim.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = AppRadii.glass,
    this.padding = const EdgeInsets.all(AppDimensions.paddingM),
    this.blur = 12,
    this.tint,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double blur;

  /// Overrides the palette fill, e.g. a darker glass over photos.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint ?? p.glassFill,
            borderRadius: radius,
            border: Border.all(color: p.glassBorder, width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Round frosted icon button — readable over photos and plain backgrounds.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final button = GlassContainer(
      borderRadius: 22,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(icon, size: 20, color: iconColor ?? p.textPrimary),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
