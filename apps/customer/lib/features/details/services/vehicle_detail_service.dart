// lib/features/details/services/vehicle_detail_service.dart
//
// Single-car deep-dive fetch: the car itself (fresh, in case it went off
// the market since the deck was fetched), all its photos, and its dealer's
// public info. `dealers` is anon-readable only where `status = 'approved'`
// (see the RLS migration) — a null embed there means the dealer isn't
// public, which we treat as "can't show this listing" rather than guessing.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';

import '../../../core/car_row_mapper.dart';

class VehicleDetailException implements Exception {
  VehicleDetailException(this.message);
  final String message;
  @override
  String toString() => message;
}

class VehicleDetail {
  const VehicleDetail({required this.car, required this.dealer});
  final CarModel car;
  final DealershipModel dealer;
}

class VehicleDetailService {
  VehicleDetailService(this._client);
  final SupabaseClient _client;

  Future<VehicleDetail> fetchDetail(String carId) async {
    try {
      final raw = await _client
          .from('cars')
          .select('*, car_photos(storage_path), dealers(*)')
          .eq('id', carId)
          .eq('is_public', true)
          .eq('status', 'available')
          .single();

      final row = Map<String, dynamic>.from(raw);
      final dealerJson = row['dealers'] as Map?;
      if (dealerJson == null) {
        throw VehicleDetailException('This listing is no longer available.');
      }

      final car = carModelFromRow(row, _client);
      final dealer = DealershipModel.fromJson(Map<String, dynamic>.from(dealerJson));
      return VehicleDetail(car: car, dealer: dealer);
    } on PostgrestException catch (e) {
      throw VehicleDetailException('Could not load this vehicle: ${e.message}');
    }
  }
}
