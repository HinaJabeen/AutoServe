// lib/features/details/presentation/vehicle_detail_screen.dart
//
// "Digital Showroom" — pushed when a card is tapped (not swiped). Renders
// instantly from `initialCar` (passed via go_router `extra` from the deck,
// so there's no blank flash for data we already have) while
// `vehicleDetailProvider` fetches the fresh car + dealer info in the
// background; the dealer section and the bottom bar's "book" action key off
// whichever car is most current once that lands.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../leads/presentation/lead_inquiry_bottom_sheet.dart';
import '../../leads/services/lead_service.dart';
import '../providers/vehicle_detail_providers.dart';

class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({super.key, required this.carId, this.initialCar});

  final String carId;
  final CarModel? initialCar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(vehicleDetailProvider(carId));

    return detailAsync.when(
      data: (detail) => _DetailScaffold(car: detail.car, dealer: detail.dealer),
      error: (e, _) => _DetailError(
        message: e.toString(),
        onRetry: () => ref.invalidate(vehicleDetailProvider(carId)),
      ),
      loading: () => initialCar != null
          ? _DetailScaffold(car: initialCar!, dealer: null, dealerLoading: true)
          : const _DetailSkeleton(),
    );
  }
}

/// First paint when there's no `initialCar` to show (deep link, refresh).
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget block(double height, {double? width, double radius = AppDimensions.radiusM}) =>
        LoadingShimmer(
          height: height,
          width: width,
          borderRadius: radius,
          baseColor: p.surfaceElevated,
          highlightColor: p.border,
        );

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kDetailMaxWidth),
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              block(360, radius: 0),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    block(28, width: 240),
                    const SizedBox(height: AppDimensions.paddingS),
                    block(24, width: 140),
                    const SizedBox(height: AppDimensions.paddingL),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppDimensions.paddingM,
                      crossAxisSpacing: AppDimensions.paddingM,
                      childAspectRatio: 2.6,
                      children: List.generate(6, (_) => block(0)),
                    ),
                    const SizedBox(height: AppDimensions.paddingL),
                    block(64),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Desktop/web ceiling so the "digital showroom" reads like a scaled-down
// mobile/tablet layout instead of stretching edge to edge on a laptop —
// same idea as the swipe deck's and auth screens' own max-width caps.
const _kDetailMaxWidth = 600.0;

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.car, required this.dealer, this.dealerLoading = false});
  final CarModel car;
  final DealershipModel? dealer;
  final bool dealerLoading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kDetailMaxWidth),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PhotoCarousel(photoUrls: car.photoUrls),
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(car.displayTitle,
                          style: AppTextStyles.heading1.copyWith(color: p.textPrimary)),
                      if (_specText(car, 'trim') case final trim?) ...[
                        const SizedBox(height: 2),
                        Text(trim,
                            style: AppTextStyles.body.copyWith(color: p.textSecondary)),
                      ],
                      const SizedBox(height: AppDimensions.paddingS),
                      Text(car.formattedPrice,
                          style: AppTextStyles.price.copyWith(color: p.accentSecondary)),
                      const SizedBox(height: AppDimensions.paddingL),
                      Text('Specifications',
                          style: AppTextStyles.heading3.copyWith(color: p.textPrimary)),
                      const SizedBox(height: AppDimensions.paddingM),
                      _SpecsGrid(car: car),
                      const SizedBox(height: AppDimensions.paddingL),
                      Text('Dealer', style: AppTextStyles.heading3.copyWith(color: p.textPrimary)),
                      const SizedBox(height: AppDimensions.paddingM),
                      if (dealerLoading)
                        const _DealerSkeleton()
                      else if (dealer != null)
                        _DealerCard(dealer: dealer!),
                    ],
                  ),
                ),
                // Clears the sticky bottom bar instead of content hiding under it.
                const SizedBox(height: 88),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _LeadActionBar(car: car),
    );
  }
}

/// A non-blank string from the `specs` jsonb bucket — body type, trim, etc.
/// have no dedicated `cars` column (see vehicle_filters.dart).
String? _specText(CarModel car, String key) {
  final v = car.specs[key]?.toString().trim();
  return (v == null || v.isEmpty) ? null : v;
}

String _titleCase(String s) => s
    .split('_')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _groupThousands(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.photoUrls});
  final List<String> photoUrls;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photoUrls;

    final p = context.palette;
    return SizedBox(
      height: 360,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isEmpty)
            Container(
              color: p.surfaceElevated,
              child: Icon(Icons.directions_car_rounded, size: 72, color: p.textTertiary),
            )
          else
            PageView.builder(
              controller: _pageController,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => Image.network(
                photos[i],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: p.surfaceElevated,
                  child: Icon(Icons.broken_image_outlined, size: 48, color: p.textTertiary),
                ),
              ),
            ),

          // Legibility for the back button over whatever photo is showing.
          const Positioned(
            left: 0, right: 0, top: 0,
            child: SizedBox(
              height: 100,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black45, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),

          if (photos.length > 1)
            Positioned(
              bottom: AppDimensions.paddingM,
              left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(photos.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: active ? 0.95 : 0.5),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpecsGrid extends StatelessWidget {
  const _SpecsGrid({required this.car});
  final CarModel car;

  @override
  Widget build(BuildContext context) {
    // The six headline specs first, then whatever else a dealer put in the
    // flexible `specs` jsonb bucket (engine, VIN, etc. — no dedicated column).
    // `body_type` and `trim` are shown above, so they're skipped in the tail.
    final bodyType = _specText(car, 'body_type');
    final entries = <MapEntry<String, String>>[
      if (car.mileage != null) MapEntry('Mileage', '${_groupThousands(car.mileage!)} km'),
      if (car.transmission != null) MapEntry('Transmission', _titleCase(car.transmission!)),
      if (car.fuelType != null) MapEntry('Fuel type', _titleCase(car.fuelType!)),
      if (bodyType != null) MapEntry('Body type', _titleCase(bodyType)),
      if (car.condition != null) MapEntry('Condition', _titleCase(car.condition!)),
      if (car.color != null) MapEntry('Exterior color', _titleCase(car.color!)),
      ...car.specs.entries
          .where((e) => e.key != 'body_type' && e.key != 'trim')
          .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
          .map((e) => MapEntry(_titleCase(e.key), e.value.toString())),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();
    final p = context.palette;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppDimensions.paddingM,
        crossAxisSpacing: AppDimensions.paddingM,
        childAspectRatio: 2.6,
      ),
      itemBuilder: (context, i) {
        final entry = entries[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
          decoration: BoxDecoration(
            color: p.surfaceElevated,
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            border: Border.all(color: p.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.key, style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
              const SizedBox(height: 2),
              Text(entry.value,
                  style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }
}

class _DealerCard extends StatelessWidget {
  const _DealerCard({required this.dealer});
  final DealershipModel dealer;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Only `approved` dealers are readable by customers at all (RLS), so in
    // practice every dealer shown here is verified; checked anyway so a
    // policy change can't silently award the badge.
    final verified = dealer.status == 'approved';
    final location = [dealer.address, dealer.city]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: p.accent.withValues(alpha: 0.12),
            child: Text(
              dealer.name.isNotEmpty ? dealer.name[0].toUpperCase() : '?',
              style: AppTextStyles.heading3.copyWith(color: p.accentSecondary),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(dealer.name,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Verified dealer',
                        child: Icon(Icons.verified_rounded, size: 16, color: p.accent),
                      ),
                    ],
                  ],
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: p.textSecondary),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(location,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DealerSkeleton extends StatelessWidget {
  const _DealerSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 64,
        decoration: BoxDecoration(
          color: context.palette.surfaceElevated,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
      );
}

class _LeadActionBar extends StatelessWidget {
  const _LeadActionBar({required this.car});
  final CarModel car;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingL, AppDimensions.paddingM, AppDimensions.paddingL,
        AppDimensions.paddingM + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
        boxShadow: [
          BoxShadow(color: p.shadowColor, blurRadius: 12, offset: const Offset(0, -2)),
        ],
      ),
      // heightFactor: 1 — the bottomNavigationBar slot allows the full screen
      // height, and a plain Center would expand to fill it, covering the body.
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kDetailMaxWidth),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showLeadInquiryBottomSheet(
                      context, car: car, type: LeadType.inquiry),
                  icon: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: p.accentSecondary),
                  label: Text('Send Inquiry',
                      style: AppTextStyles.button.copyWith(color: p.accentSecondary)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: p.accentSecondary),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.paddingM),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => showLeadInquiryBottomSheet(
                      context, car: car, type: LeadType.testDrive),
                  icon: Icon(Icons.directions_car_filled_rounded, size: 18, color: p.onAccent),
                  label: Text('Book Test Drive',
                      style: AppTextStyles.button.copyWith(color: p.onAccent)),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: p.error),
              const SizedBox(height: AppDimensions.paddingM),
              Text(message,
                  style: AppTextStyles.body.copyWith(color: p.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppDimensions.paddingM),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
