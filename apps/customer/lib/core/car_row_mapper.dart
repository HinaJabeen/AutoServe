// lib/core/car_row_mapper.dart
//
// Shared `cars` row → CarModel mapping, used by both CarDiscoveryService
// (the swipe deck's bulk fetch) and VehicleDetailService (the single-car
// deep-dive fetch) so the car_photos -> public URL resolution logic lives
// in exactly one place.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';

const vehiclePhotoBucket = 'vehicle-photos';

/// Expects [raw] to be a `cars` row selected with an embedded
/// `car_photos(storage_path)` join (other embedded resources, like
/// `dealers(*)`, are left in place for the caller to pull out separately —
/// `CarModel.fromJson` ignores unknown keys).
CarModel carModelFromRow(Map<String, dynamic> raw, SupabaseClient client) {
  final row = Map<String, dynamic>.from(raw);
  final photos = (row['car_photos'] as List<dynamic>? ?? [])
      .map((p) => client.storage
          .from(vehiclePhotoBucket)
          .getPublicUrl((p as Map)['storage_path'] as String))
      .toList();
  final clean = Map<String, dynamic>.from(row)..remove('car_photos');
  return CarModel.fromJson({...clean, 'photo_urls': photos});
}
