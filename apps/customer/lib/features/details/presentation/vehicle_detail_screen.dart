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

import '../../discovery/presentation/widgets/book_test_drive_sheet.dart';
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
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
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
                      const SizedBox(height: 4),
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
      bottomNavigationBar: _BookTestDriveBar(car: car),
    );
  }
}

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
    // Always-known fields from CarModel, plus whatever a dealer put in the
    // flexible `specs` jsonb bucket (engine, trim, VIN, etc. all live there —
    // there's no dedicated column for any of them in the live schema).
    final entries = <MapEntry<String, String>>[
      MapEntry('Year', '${car.year}'),
      if (car.mileage != null) MapEntry('Mileage', '${car.mileage} km'),
      if (car.condition != null) MapEntry('Condition', _titleCase(car.condition!)),
      if (car.transmission != null) MapEntry('Transmission', _titleCase(car.transmission!)),
      if (car.fuelType != null) MapEntry('Fuel type', _titleCase(car.fuelType!)),
      if (car.color != null) MapEntry('Color', _titleCase(car.color!)),
      ...car.specs.entries
          .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
          .map((e) => MapEntry(_titleCase(e.key), e.value.toString())),
    ];
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

  String _titleCase(String s) =>
      s.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

class _DealerCard extends StatelessWidget {
  const _DealerCard({required this.dealer});
  final DealershipModel dealer;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
                Text(dealer.name, style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
                const SizedBox(height: 2),
                Text(dealer.city, style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.call_outlined, size: 18, color: p.accentSecondary),
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

class _BookTestDriveBar extends StatelessWidget {
  const _BookTestDriveBar({required this.car});
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kDetailMaxWidth),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => showBookTestDriveSheet(context, car),
              icon: Icon(Icons.directions_car_filled_rounded, size: 18, color: p.onAccent),
              label: Text('Book Test Drive',
                  style: AppTextStyles.button.copyWith(color: p.onAccent)),
            ),
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
