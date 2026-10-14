// lib/features/discovery/providers/discovery_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../auth/providers/auth_providers.dart';
import '../../filters/providers/filter_providers.dart';
import '../services/car_discovery_service.dart';
import '../services/local_swipe_store.dart';

/// Rebuilt whenever the signed-in user changes, so everything downstream
/// (deck exclusions, Saved list) re-reads that user's own history.
final localSwipeStoreProvider = Provider<LocalSwipeStore>((ref) {
  final userId = ref.watch(currentProfileProvider.select((p) => p?.id));
  return LocalSwipeStore(userId);
});

final carDiscoveryServiceProvider = Provider<CarDiscoveryService>(
  (ref) => CarDiscoveryService(SupabaseService.client),
);

/// The full, unfiltered pool of available listings for this session — the
/// single network fetch that both the deck and the filter matrix's
/// make/model/body-type option lists are derived from, so filtering never
/// triggers a second round trip.
final availableCarsProvider = FutureProvider<List<CarModel>>((ref) {
  return ref.read(carDiscoveryServiceProvider).fetchAvailableCars();
});

/// The deck for this session: `availableCarsProvider`, minus already-decided
/// cars, minus anything `vehicleFiltersProvider` excludes.
///
/// Swipes don't recompute this mid-session (`CardSwiper` owns its own
/// internal index/stack once built, so a silently-changing list would desync
/// from it); changing filters or the signed-in user does, and the UI remounts
/// `CardSwiper` via a key tied to `vehicleFiltersProvider` — see
/// `swipe_deck_screen.dart`.
final carDeckProvider = FutureProvider<List<CarModel>>((ref) async {
  final decidedIds = await ref.watch(localSwipeStoreProvider).loadDecidedIds();
  final cars = await ref.watch(availableCarsProvider.future);
  final filters = ref.watch(vehicleFiltersProvider);
  return cars.where((c) => !decidedIds.contains(c.id) && filters.matches(c)).toList();
});
