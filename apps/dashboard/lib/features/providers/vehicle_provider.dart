// lib/features/providers/vehicle_provider.dart
// PART 5: Safe deletion — closes dialog BEFORE await, try/catch, invalidate.
// All Supabase raw map fields accessed safely with ?.toString() ?? ''.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'auth_provider.dart';

// ── Mock data ──────────────────────────────────────────────────────────────────

final _mockVehicles = <VehicleModel>[
  VehicleModel(
    id: 'aaaaaaaa-bbbb-cccc-dddd-000000000001',
    dealershipId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    make: 'Toyota', model: 'Corolla', year: 2021, color: 'White',
    price: 4850000, mileage: 42000, condition: 'good', fuelType: 'petrol',
    transmission: 'automatic', bodyType: 'sedan', description: 'Well maintained.',
    status: 'available', images: const [], createdAt: DateTime(2024, 1, 10), viewsCount: 0,
  ),
  VehicleModel(
    id: 'aaaaaaaa-bbbb-cccc-dddd-000000000002',
    dealershipId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    make: 'Honda', model: 'Civic', year: 2020, color: 'Black',
    price: 6200000, mileage: 38000, condition: 'excellent', fuelType: 'petrol',
    transmission: 'automatic', bodyType: 'sedan', description: 'One owner.',
    status: 'available', images: const [], createdAt: DateTime(2024, 2, 5), viewsCount: 0,
  ),
  VehicleModel(
    id: 'aaaaaaaa-bbbb-cccc-dddd-000000000003',
    dealershipId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    make: 'Suzuki', model: 'Swift', year: 2019, color: 'Red',
    price: 3150000, mileage: 51000, condition: 'fair', fuelType: 'petrol',
    transmission: 'manual', bodyType: 'hatchback', description: 'Good condition.',
    status: 'reserved', images: const [], createdAt: DateTime(2024, 3, 1), viewsCount: 0,
  ),
];

// ── Stream ─────────────────────────────────────────────────────────────────────

final dealerVehiclesStreamProvider = StreamProvider<List<VehicleModel>>((ref) {
  final dealershipId = ref.watch(currentDealershipIdProvider);
  if (dealershipId == null) return Stream.value(_mockVehicles);

  return SupabaseService.client
      .from('cars')
      .stream(primaryKey: ['id'])
      .eq('dealer_id', dealershipId)
      .map((rows) => rows.map((raw) {
            // PART 5 FIX: cast to typed map before any field access.
            final r = Map<String, dynamic>.from(raw);
            final specs = (r['specs'] as Map<String, dynamic>?) ?? {};
            return VehicleModel.fromJson({
              'id':            r['id']?.toString()           ?? '',
              'dealership_id': r['dealer_id']?.toString()    ?? '',
              'make':          r['make']?.toString()          ?? '',
              'model':         r['model']?.toString()         ?? '',
              'year':          r['year'] is int ? r['year'] : int.tryParse(r['year']?.toString() ?? '') ?? 0,
              'price':         r['price'] is num ? (r['price'] as num).toDouble() : double.tryParse(r['price']?.toString() ?? '') ?? 0.0,
              'status':        r['status']?.toString()        ?? 'available',
              'mileage':       r['mileage'] is int ? r['mileage'] : int.tryParse(r['mileage']?.toString() ?? ''),
              'color':         r['color']?.toString(),
              'transmission':  r['transmission']?.toString(),
              'fuel_type':     r['fuel_type']?.toString(),
              'condition':     r['condition']?.toString(),
              'body_type':     specs['body_type']?.toString(),
              'description':   specs['description']?.toString(),
              'images':        List<String>.from(
                                 (specs['images'] as List?) ?? []),
              'created_at':    r['created_at']?.toString()   ??
                                   DateTime.now().toIso8601String(),
            });
          }).toList());
});

// ── Mutation state ─────────────────────────────────────────────────────────────

class VehicleMutationState {
  const VehicleMutationState({this.isSubmitting = false, this.errorMessage});
  final bool isSubmitting;
  final String? errorMessage;
  VehicleMutationState copyWith({bool? isSubmitting, String? errorMessage}) =>
      VehicleMutationState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        errorMessage: errorMessage,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class VehicleNotifier extends StateNotifier<VehicleMutationState> {
  VehicleNotifier(this._ref) : super(const VehicleMutationState());
  final Ref _ref;

  void clearError() =>
      state = state.copyWith(isSubmitting: false, errorMessage: null);

  Future<bool> addVehicle({
    required String make, required String model, required int year,
    required String color, required int mileage, required double price,
    required String condition, required String fuelType,
    required String transmission, required String bodyType,
    required String description,
  }) async {
    final dealerId = _ref.read(currentDealershipIdProvider);
    if (dealerId == null) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'No dealership linked. Contact your administrator.',
      );
      return false;
    }
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await SupabaseService.client.from('cars').insert({
        'dealer_id':    dealerId,
        'make':         make,
        'model':        model,
        'year':         year,
        'price':        price,
        'status':       'available',
        'mileage':      mileage,
        'color':        color,
        'transmission': transmission,
        'fuel_type':    fuelType,
        'condition':    condition,
        'specs': {
          'body_type':   bodyType,
          'description': description,
          'images':      <String>[],
        },
      });
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ addVehicle: $e');
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateVehicle({
    required String id, required String make, required String model,
    required int year, required String color, required int mileage,
    required double price, required String condition, required String fuelType,
    required String transmission, required String bodyType,
    required String description,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await SupabaseService.client.from('cars').update({
        'make':         make,
        'model':        model,
        'year':         year,
        'price':        price,
        'mileage':      mileage,
        'color':        color,
        'transmission': transmission,
        'fuel_type':    fuelType,
        'condition':    condition,
        'specs': {
          'body_type':   bodyType,
          'description': description,
        },
      }).eq('id', id);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ updateVehicle: $e');
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> markAsSold(String id) async {
    try {
      await SupabaseService.client
          .from('cars').update({'status': 'sold'}).eq('id', id);
    } catch (e) {
      if (kDebugMode) print('❌ markAsSold: $e');
    }
  }

  /// PART 5 FIX: Dismiss dialog FIRST, then delete.
  /// Prevents _ElementLifecycle.inactive crash from awaiting inside a
  /// dialog whose parent was already unmounted.
  Future<void> deleteVehicle(BuildContext context, String carId) async {
    // Close the confirmation dialog immediately before any async work.
    Navigator.of(context, rootNavigator: true).pop();

    try {
      // Delete associated photos first (cascade not always guaranteed).
      await SupabaseService.client
          .from('car_photos').delete().eq('car_id', carId);

      // Delete the car row — DB cascade handles car_audit_logs.
      await SupabaseService.client
          .from('cars').delete().eq('id', carId);

      // Invalidate stream so UI updates immediately.
      _ref.invalidate(dealerVehiclesStreamProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle removed successfully')),
        );
      }
    } catch (e) {
      if (kDebugMode) print('❌ deleteVehicle: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete vehicle: $e')),
        );
      }
    }
  }
}

final vehicleNotifierProvider =
    StateNotifierProvider<VehicleNotifier, VehicleMutationState>(
  (ref) => VehicleNotifier(ref),
);