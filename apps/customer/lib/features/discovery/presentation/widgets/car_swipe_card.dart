// lib/features/discovery/presentation/widgets/car_swipe_card.dart

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

class CarSwipeCard extends StatelessWidget {
  const CarSwipeCard({
    super.key,
    required this.car,
    this.horizontalPercent = 0,
    this.verticalPercent = 0,
    this.onTap,
  });

  final CarModel car;

  /// From `CardSwiper.cardBuilder`: `100 * dragOffset / threshold`, so it
  /// already reaches ±100 right at the swipe threshold rather than needing
  /// normalizing — positive is a right/down drag, negative left/up.
  final int horizontalPercent;
  final int verticalPercent;

  /// Tap (not swipe) → push the deep-dive screen. `CardSwiper`'s own
  /// GestureDetector only drives pan/drag; a plain tap on this nested
  /// GestureDetector wins the gesture arena without any conflict, so no
  /// `isDisabled`/`onTapDisabled` plumbing from the package is needed.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final photoUrl = car.photoUrls.isNotEmpty ? car.photoUrls.first : null;

    final likeOpacity = (horizontalPercent / 100).clamp(0.0, 1.0);
    final passOpacity = (-horizontalPercent / 100).clamp(0.0, 1.0);
    final bookOpacity = (-verticalPercent / 100).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
      // Soft drop-shadow so the top card visibly lifts off the stack behind
      // it, instead of the deck reading as flat, stacked rectangles.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Edge-to-edge vehicle image — falls back to a neutral placeholder
            // if the car has no photos yet.
            if (photoUrl != null)
              Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _PhotoPlaceholder(),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const _PhotoPlaceholder(loading: true),
              )
            else
              const _PhotoPlaceholder(),

            // Bottom gradient so the spec overlay stays legible over any photo.
            const Positioned(
              left: 0, right: 0, bottom: 0,
              child: SizedBox(
                height: 180,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: AppDimensions.paddingL,
              right: AppDimensions.paddingL,
              bottom: AppDimensions.paddingL,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.displayTitle,
                    style: AppTextStyles.heading1.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    car.formattedPrice,
                    style: AppTextStyles.heading3.copyWith(
                        color: Colors.white.withValues(alpha: 0.92)),
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  Wrap(
                    spacing: AppDimensions.paddingS,
                    runSpacing: AppDimensions.paddingS,
                    children: [
                      if (car.mileage != null)
                        _SpecChip(icon: Icons.speed_rounded, label: '${car.mileage} km'),
                      if (car.fuelType != null)
                        _SpecChip(icon: Icons.local_gas_station_rounded, label: car.fuelType!),
                      if (car.transmission != null)
                        _SpecChip(icon: Icons.settings_rounded, label: car.transmission!),
                    ],
                  ),
                ],
              ),
            ),

            // Drag feedback stamps — fade/scale in proportionally to how far
            // past the swipe threshold the drag has gone, in whichever
            // direction(s) are active.
            if (likeOpacity > 0)
              Positioned(
                top: 28, right: 20,
                child: _Stamp(label: 'INTERESTED', color: AppColors.success, opacity: likeOpacity),
              ),
            if (passOpacity > 0)
              Positioned(
                top: 28, left: 20,
                child: _Stamp(label: 'PASS', color: AppColors.textTertiary, opacity: passOpacity),
              ),
            if (bookOpacity > 0)
              Positioned(
                top: 28, left: 0, right: 0,
                child: Center(
                  child: _Stamp(label: 'TEST DRIVE', color: AppColors.secondary, opacity: bookOpacity),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.label, required this.color, required this.opacity});
  final String label;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: 0.85 + (0.15 * opacity),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              border: Border.all(color: color, width: 2.5),
            ),
            child: Text(
              label,
              style: AppTextStyles.bodyBold.copyWith(color: color, letterSpacing: 1.1),
            ),
          ),
        ),
      );
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.loading = false});
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.shimmerBase,
        child: Center(
          child: loading
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Icon(Icons.directions_car_rounded,
                  size: 64, color: AppColors.textTertiary),
        ),
      );
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.caption.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      );
}
