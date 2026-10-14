// lib/features/saved/providers/saved_cars_providers.dart
//
// The signed-in customer's saved cars (right-swipes, plus any car they've
// sent a lead for), newest first. Ids persist per user in LocalSwipeStore;
// the cars themselves are re-fetched so price/photos are current and
// sold/unlisted ones drop out.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../discovery/providers/discovery_providers.dart';
import '../services/saved_cars_service.dart';

final savedCarsServiceProvider =
    Provider<SavedCarsService>((ref) => SavedCarsService(SupabaseService.client));

class SavedCarsNotifier extends AsyncNotifier<List<CarModel>> {
  // Cars saved while `build` was still loading — its id read may have
  // happened before they were persisted, so they're merged in at the end.
  final _savedDuringLoad = <CarModel>[];

  @override
  Future<List<CarModel>> build() async {
    _savedDuringLoad.clear();
    final store = ref.watch(localSwipeStoreProvider);
    final ids = await store.loadInterestedIds();
    final cars = await ref
        .read(savedCarsServiceProvider)
        .fetchByIds(ids.reversed.toList());
    final pending = _savedDuringLoad.where((c) => !cars.any((s) => s.id == c.id));
    return [...pending, ...cars];
  }

  Future<void> add(CarModel car) async {
    final current = state.valueOrNull;
    if (current == null) {
      _savedDuringLoad.add(car);
    } else {
      state = AsyncData([car, ...current.where((c) => c.id != car.id)]);
    }
    await ref.read(localSwipeStoreProvider).markInterested(car.id);
  }

  Future<void> remove(String carId) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.where((c) => c.id != carId).toList());
    }
    await ref.read(localSwipeStoreProvider).unmarkInterested(carId);
  }

  /// Puts a just-removed car back at [index] (the Saved screen's Undo).
  Future<void> restore(CarModel car, int index) async {
    final current = [...?state.valueOrNull]..removeWhere((c) => c.id == car.id);
    current.insert(index.clamp(0, current.length), car);
    state = AsyncData(current);
    await ref.read(localSwipeStoreProvider).markInterested(car.id);
  }
}

final savedCarsProvider =
    AsyncNotifierProvider<SavedCarsNotifier, List<CarModel>>(SavedCarsNotifier.new);

/// For the nav-bar badge; 0 while loading or on error.
final savedCarsCountProvider = Provider<int>(
    (ref) => ref.watch(savedCarsProvider).valueOrNull?.length ?? 0);
