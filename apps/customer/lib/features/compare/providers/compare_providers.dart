// lib/features/compare/providers/compare_providers.dart
//
// In-memory comparison tray (max 3 cars) — deliberately not persisted; it's
// a short-lived shopping aid, cleared on sign-out.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

const maxCompareCars = 3;

enum CompareToggleResult { added, removed, full }

class CompareNotifier extends Notifier<List<CarModel>> {
  @override
  List<CarModel> build() => const [];

  bool contains(String carId) => state.any((c) => c.id == carId);

  CompareToggleResult toggle(CarModel car) {
    if (contains(car.id)) {
      remove(car.id);
      return CompareToggleResult.removed;
    }
    if (state.length >= maxCompareCars) return CompareToggleResult.full;
    state = [...state, car];
    return CompareToggleResult.added;
  }

  void remove(String carId) => state = state.where((c) => c.id != carId).toList();

  void clear() => state = const [];
}

final compareProvider =
    NotifierProvider<CompareNotifier, List<CarModel>>(CompareNotifier.new);

/// Dealers of the compared cars, keyed by dealer id (for WhatsApp buttons).
/// Only approved dealers are readable — exactly the ones with live listings.
final compareDealersProvider = FutureProvider<Map<String, DealershipModel>>((ref) async {
  final ids = ref.watch(compareProvider.select((cars) => cars.map((c) => c.dealerId).toSet()));
  if (ids.isEmpty) return const {};
  final rows = await SupabaseService.client.from('dealers').select().inFilter('id', ids.toList());
  return {
    for (final r in rows)
      r['id'].toString(): DealershipModel.fromJson(Map<String, dynamic>.from(r)),
  };
});
