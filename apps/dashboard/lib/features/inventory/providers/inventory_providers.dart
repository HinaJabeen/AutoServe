// lib/features/inventory/providers/inventory_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dashboard/features/inventory/models/car_model.dart';
import 'package:dashboard/features/inventory/services/inventory_service.dart';
import 'package:dashboard/features/inventory/services/vehicle_storage_service.dart';
import 'package:dashboard/features/providers/auth_provider.dart';

const _pageSize = 20;

// ---------------------------------------------------------------------------
// Service instances
// ---------------------------------------------------------------------------

final inventoryServiceProvider = Provider<InventoryService?>((ref) {
  final dealerId = ref.watch(currentDealershipIdProvider);
  if (dealerId == null) return null;
  return InventoryService(Supabase.instance.client, dealerId);
});

final vehicleStorageServiceProvider = Provider<VehicleStorageService?>((ref) {
  final dealerId = ref.watch(currentDealershipIdProvider);
  if (dealerId == null) return null;
  return VehicleStorageService(Supabase.instance.client, dealerId);
});

// ---------------------------------------------------------------------------
// Filter / sort state
// ---------------------------------------------------------------------------

final inventorySearchProvider = StateProvider<String>((ref) => '');
final inventoryStatusFilterProvider = StateProvider<String?>((ref) => null);

enum InventorySortField { createdAt, price }

class InventorySort {
  const InventorySort(this.field, this.ascending);
  final InventorySortField field;
  final bool ascending;
  String get column => field == InventorySortField.price ? 'price' : 'created_at';

  @override
  bool operator ==(Object other) =>
      other is InventorySort && other.field == field && other.ascending == ascending;
  @override
  int get hashCode => Object.hash(field, ascending);
}

final inventorySortProvider =
    StateProvider<InventorySort>((ref) => const InventorySort(InventorySortField.createdAt, false));

// ---------------------------------------------------------------------------
// Paginated state
// ---------------------------------------------------------------------------

class InventoryPageState {
  const InventoryPageState({
    required this.cars,
    required this.hasMore,
    required this.isLoadingMore,
    this.errorMessage,
  });

  final List<CarModel> cars;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  bool get isEmpty => cars.isEmpty;

  InventoryPageState copyWith({
    List<CarModel>? cars,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
  }) =>
      InventoryPageState(
        cars: cars ?? this.cars,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        errorMessage: errorMessage,
      );
}

// ---------------------------------------------------------------------------
// Paginated notifier
// ---------------------------------------------------------------------------

class InventoryListNotifier extends AsyncNotifier<InventoryPageState> {
  InventoryService? get _service => ref.read(inventoryServiceProvider);

  @override
  Future<InventoryPageState> build() async {
    final search = ref.watch(inventorySearchProvider);
    final status = ref.watch(inventoryStatusFilterProvider);
    final sort = ref.watch(inventorySortProvider);

    final service = _service;
    if (service == null) {
      return const InventoryPageState(cars: [], hasMore: false, isLoadingMore: false);
    }

    try {
      final cars = await service.fetchPage(
        offset: 0,
        limit: _pageSize,
        searchQuery: search,
        statusFilter: status,
        sortBy: sort.column,
        ascending: sort.ascending,
      );
      return InventoryPageState(
        cars: cars,
        hasMore: cars.length == _pageSize,
        isLoadingMore: false,
      );
    } catch (e) {
      // Surface through AsyncValue.error so the UI shows the error widget.
      rethrow;
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    final service = _service;
    if (current == null || service == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final search = ref.read(inventorySearchProvider);
      final status = ref.read(inventoryStatusFilterProvider);
      final sort = ref.read(inventorySortProvider);

      final next = await service.fetchPage(
        offset: current.cars.length,
        limit: _pageSize,
        searchQuery: search,
        statusFilter: status,
        sortBy: sort.column,
        ascending: sort.ascending,
      );
      state = AsyncValue.data(InventoryPageState(
        cars: [...current.cars, ...next],
        hasMore: next.length == _pageSize,
        isLoadingMore: false,
      ));
    } catch (_) {
      // Restore previous page without crashing; let user retry.
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  void patchCar(CarModel updated) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      cars: [for (final c in current.cars) if (c.id == updated.id) updated else c],
    ));
  }

  /// Safe remove: guards against empty list and out-of-bounds.
  void removeCars(Set<String> ids) {
    final current = state.value;
    if (current == null || current.cars.isEmpty || ids.isEmpty) return;
    final remaining = current.cars.where((c) => !ids.contains(c.id)).toList();
    // Always emit a valid state even when list becomes empty.
    state = AsyncValue.data(current.copyWith(cars: remaining));
  }
}

final inventoryListProvider =
    AsyncNotifierProvider<InventoryListNotifier, InventoryPageState>(InventoryListNotifier.new);