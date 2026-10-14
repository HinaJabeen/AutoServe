// lib/features/discovery/presentation/swipe_deck_screen.dart
//
// "Tinder for Cars" — right = interested (saved locally), left = pass
// (skipped locally), up = book a test drive. See docs/architecture.md §8.2.

import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../../core/router/app_router.dart';
import '../../filters/presentation/filter_sheet.dart';
import '../../filters/providers/filter_providers.dart';
import '../../search/presentation/widgets/search_bar_field.dart';
import '../providers/discovery_providers.dart';
import 'widgets/car_swipe_card.dart';
import 'widgets/book_test_drive_sheet.dart';

class SwipeDeckScreen extends ConsumerWidget {
  const SwipeDeckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deckAsync = ref.watch(carDeckProvider);
    final filters = ref.watch(vehicleFiltersProvider);

    // Background/AppBar chrome (including the title style) comes from the
    // app-wide theme — core/theme/app_theme.dart — rather than being
    // hard-coded per screen.
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.account_circle_outlined),
          tooltip: 'Profile',
          onPressed: () => context.push(AppRoutes.profile),
        ),
        title: const Text('AutoServe'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Filters',
                onPressed: () => showFilterSheet(context),
              ),
              if (filters.isActive)
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppDimensions.paddingS),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SearchBarField(onTap: () => context.push(AppRoutes.search)),
            if (filters.dealerId != null) _DealerFilterChip(dealerName: filters.dealerName),
            Expanded(
              child: deckAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(carDeckProvider),
                ),
                data: (cars) => cars.isEmpty
                    ? _EmptyDeck(filtersActive: filters.isActive)
                    // Keyed by the active filters so changing them remounts
                    // `CardSwiper` from scratch — see carDeckProvider's doc
                    // comment for why reusing its element across a filter
                    // change (which silently swaps the underlying `cars`
                    // list length/contents out from under the swiper's own
                    // internal index) would desync its internal state
                    // instead of giving a clean fresh deck.
                    : _Deck(key: ValueKey(filters), cars: cars),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DealerFilterChip extends ConsumerWidget {
  const _DealerFilterChip({required this.dealerName});
  final String? dealerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingM, 0, AppDimensions.paddingM, AppDimensions.paddingS),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          avatar: Icon(Icons.storefront_rounded, size: AppDimensions.iconSizeS, color: p.accentSecondary),
          label: Text('Showing ${dealerName ?? 'this dealer'}',
              style: AppTextStyles.caption.copyWith(color: p.textPrimary)),
          backgroundColor: p.badgeBackground,
          onDeleted: () => ref.read(vehicleFiltersProvider.notifier).clear(),
          deleteIcon: Icon(Icons.close_rounded, size: AppDimensions.iconSizeS, color: p.textSecondary),
        ),
      ),
    );
  }
}

class _Deck extends ConsumerWidget {
  const _Deck({super.key, required this.cars});
  final List<CarModel> cars;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: CardSwiper(
              cardsCount: cars.length,
              numberOfCardsDisplayed: cars.length < 2 ? 1 : 2,
              isLoop: false,
              duration: const Duration(milliseconds: 280),
              scale: 0.94,
              backCardOffset: const Offset(0, 24),
              padding: EdgeInsets.zero,
              allowedSwipeDirection:
                  const AllowedSwipeDirection.only(left: true, right: true, up: true),
              onSwipe: (previousIndex, currentIndex, direction) {
                final car = cars[previousIndex];
                final store = ref.read(localSwipeStoreProvider);

                if (direction.isCloseTo(CardSwiperDirection.right)) {
                  store.markInterested(car.id); // fire-and-forget persist
                  ref.read(savedCarsProvider.notifier).add(car);
                } else if (direction.isCloseTo(CardSwiperDirection.left)) {
                  store.markPassed(car.id);
                } else if (direction.isCloseTo(CardSwiperDirection.top)) {
                  // "Up" — swipe completes and the modal opens concurrently;
                  // the modal records its own local decision on submit.
                  showBookTestDriveSheet(context, car);
                }
                return true;
              },
              onEnd: () {},
              cardBuilder: (context, index, horizontalPercent, verticalPercent) {
                final car = cars[index];
                return CarSwipeCard(
                  car: car,
                  horizontalPercent: horizontalPercent,
                  verticalPercent: verticalPercent,
                  onTap: () => context.push(
                    '/vehicle/${car.id}',
                    extra: car,
                  ),
                );
              },
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: AppDimensions.paddingL),
          child: _SwipeHint(),
        ),
      ],
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint();
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _hint(Icons.close_rounded, 'Pass', AppColors.textTertiary),
          const SizedBox(width: AppDimensions.paddingL),
          _hint(Icons.directions_car_filled_rounded, 'Test drive', AppColors.secondary),
          const SizedBox(width: AppDimensions.paddingL),
          _hint(Icons.favorite_rounded, 'Interested', AppColors.success),
        ],
      );

  Widget _hint(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.caption.copyWith(color: color)),
        ],
      );
}

class _EmptyDeck extends ConsumerWidget {
  const _EmptyDeck({required this.filtersActive});
  final bool filtersActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                filtersActive ? Icons.filter_alt_off_outlined : Icons.directions_car_outlined,
                size: 56, color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppDimensions.paddingM),
              Text(
                filtersActive ? 'No cars match your filters' : "You've seen every available car",
                style: AppTextStyles.heading3, textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingS),
              Text(
                filtersActive
                    ? 'Try widening your search criteria'
                    : 'Check back later for new listings',
                style: AppTextStyles.caption, textAlign: TextAlign.center,
              ),
              if (filtersActive) ...[
                const SizedBox(height: AppDimensions.paddingM),
                TextButton(
                  onPressed: () => ref.read(vehicleFiltersProvider.notifier).clear(),
                  child: const Text('Clear filters'),
                ),
              ],
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: AppDimensions.paddingM),
              const Text('Could not load cars', style: AppTextStyles.heading3),
              const SizedBox(height: AppDimensions.paddingS),
              Text(message, style: AppTextStyles.caption, textAlign: TextAlign.center),
              const SizedBox(height: AppDimensions.paddingM),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
