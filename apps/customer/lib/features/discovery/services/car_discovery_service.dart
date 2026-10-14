// lib/features/discovery/services/car_discovery_service.dart
//
// Public, anonymous-readable car listing for the consumer swipe deck.
// Mirrors InventoryService._withPhotoUrls (apps/dashboard) so photo URLs are
// built the same way: car_photos.storage_path -> getPublicUrl in the
// 'vehicle-photos' bucket.
//
// This is a one-shot select + join, not a realtime `.stream()`, because
// Supabase's realtime stream API does not support embedded/joined selects
// (`car_photos(storage_path)`) — only flat columns of the primary table.
// Live realtime isn't a hard requirement for a consumer browse deck the way
// it is for the dealer CRM, so a plain fetch (matching InventoryService's
// own pattern) is the right tradeoff here, not a shortcut.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';

import '../../../core/car_row_mapper.dart';

class CarDiscoveryException implements Exception {
  CarDiscoveryException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CarDiscoveryService {
  CarDiscoveryService(this._client);

  final SupabaseClient _client;

  Future<List<CarModel>> fetchAvailableCars() async {
    try {
      final rows = await _client
          .from('cars')
          .select('*, car_photos(storage_path)')
          .eq('is_public', true)
          .eq('status', 'available')
          .order('created_at', ascending: false);

      return rows.map<CarModel>((raw) => carModelFromRow(raw, _client)).toList();
    } on PostgrestException catch (e) {
      throw CarDiscoveryException('Could not load cars: ${e.message}');
    }
  }
}
