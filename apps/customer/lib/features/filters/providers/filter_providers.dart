// lib/features/filters/providers/filter_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vehicle_filters.dart';

class VehicleFiltersNotifier extends Notifier<VehicleFilters> {
  @override
  VehicleFilters build() => const VehicleFilters();

  void apply(VehicleFilters filters) => state = filters;

  void clear() => state = const VehicleFilters();

  /// From a tapped "Dealerships" search result — replaces any prior filters
  /// with just this dealer, so the deck shows exactly their inventory.
  void filterByDealer(String dealerId, String dealerName) =>
      state = VehicleFilters(dealerId: dealerId, dealerName: dealerName);
}

final vehicleFiltersProvider =
    NotifierProvider<VehicleFiltersNotifier, VehicleFilters>(VehicleFiltersNotifier.new);
