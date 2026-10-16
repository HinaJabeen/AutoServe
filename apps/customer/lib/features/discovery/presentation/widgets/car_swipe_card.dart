// lib/features/discovery/presentation/widgets/car_swipe_card.dart

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/inspection_badge.dart';

/// Pine @ 55% — the frosted info panel over the photo. Darker than the
/// palette's glassFill so white text stays legible on any image.
const _photoGlass = Color(0x8C0C3B2E);

String _titleCase(String s) => s
    .split('_')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _km(int km) =>
    '${km.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} km';

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
    final p = context.palette;
    final photoUrl = car.photoUrls.isNotEmpty ? car.photoUrls.first : null;

    final likeOpacity = (horizontalPercent / 100).clamp(0.0, 1.0);
    final passOpacity = (-horizontalPercent / 100).clamp(0.0, 1.0);
    final bookOpacity = (-verticalPercent / 100).clamp(0.0, 1.0);
    final radius = BorderRadius.circular(AppRadii.card);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // Layered, pine-tinted shadows lift the top card off the stack.
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(color: Color(0x150C3B2E), blurRadius: 24, offset: Offset(0, 10)),
            BoxShadow(color: Color(0x0D0C3B2E), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Edge-to-edge vehicle image — falls back to a neutral placeholder
              // if the car has no photos yet.
              CarNetworkImage(url: photoUrl, iconSize: 64),

              // Soft bottom vignette under the glass panel.
              const Positioned(
                left: 0, right: 0, bottom: 0,
                child: IgnorePointer(
                  child: SizedBox(
                    height: 160,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x66000000)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (car.isInspected)
                Positioned(
                  top: AppDimensions.paddingM,
                  left: AppDimensions.paddingM,
                  child: InspectionBadge(car: car, onDark: true),
                ),

              Positioned(
                left: AppDimensions.paddingS,
                right: AppDimensions.paddingS,
                bottom: AppDimensions.paddingS,
                child: GlassContainer(
                  tint: _photoGlass,
                  borderRadius: AppRadii.card - 6,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        car.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.title(p, size: 24, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(car.formattedPrice, style: AppType.price(p, size: 19, color: p.highlight)),
                      const SizedBox(height: AppDimensions.paddingS),
                      Wrap(
                        spacing: AppDimensions.paddingS,
                        runSpacing: AppDimensions.paddingS,
                        children: [
                          if (car.mileage != null)
                            _SpecChip(icon: Icons.speed_rounded, label: _km(car.mileage!)),
                          if (car.fuelType != null)
                            _SpecChip(icon: Icons.local_gas_station_rounded, label: _titleCase(car.fuelType!)),
                          if (car.transmission != null)
                            _SpecChip(icon: Icons.settings_rounded, label: _titleCase(car.transmission!)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Drag feedback stamps — fade/scale in proportionally to how far
              // past the swipe threshold the drag has gone, in whichever
              // direction(s) are active.
              if (likeOpacity > 0)
                Positioned(
                  top: 28, right: 20,
                  child: _Stamp(label: 'INTERESTED', color: p.success, opacity: likeOpacity),
                ),
              if (passOpacity > 0)
                Positioned(
                  top: 28, left: 20,
                  child: _Stamp(label: 'PASS', color: p.textTertiary, opacity: passOpacity),
                ),
              if (bookOpacity > 0)
                Positioned(
                  top: 28, left: 0, right: 0,
                  child: Center(
                    child: _Stamp(label: 'TEST DRIVE', color: p.warmAccent, opacity: bookOpacity),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              border: Border.all(color: color, width: 2.5),
            ),
            child: Text(
              label,
              style: AppTextStyles.bodyBold.copyWith(
                  color: color, letterSpacing: 1.4, fontWeight: FontWeight.w800),
            ),
          ),
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
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
