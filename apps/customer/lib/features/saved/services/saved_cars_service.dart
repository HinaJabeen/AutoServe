// lib/features/saved/services/saved_cars_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';

import '../../../core/car_row_mapper.dart';

class SavedCarsException implements Exception {
  SavedCarsException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SavedCarsService {
  SavedCarsService(this._client);
  final SupabaseClient _client;

  /// The still-listed cars among [ids], in the same order as [ids]. A saved
  /// car that has since sold or been unlisted is silently dropped — RLS
  /// wouldn't return it to a customer anyway.
  Future<List<CarModel>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      final rows = await _client
          .from('cars')
          .select('*, car_photos(storage_path)')
          .inFilter('id', ids)
          .eq('is_public', true)
          .eq('status', 'available');
      final byId = {
        for (final raw in rows)
          (raw['id'] as String): carModelFromRow(raw, _client),
      };
      return [for (final id in ids) ?byId[id]];
    } on PostgrestException catch (e) {
      throw SavedCarsException('Could not load your saved cars: ${e.message}');
    }
  }
}
