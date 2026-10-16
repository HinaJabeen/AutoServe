// lib/features/inventory/services/inventory_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';

class InventoryException implements Exception {
  InventoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

class InventoryService {
  InventoryService(this._client, this._dealerId);

  final SupabaseClient _client;
  final String _dealerId;

  Future<List<CarModel>> fetchPage({
    required int offset,
    required int limit,
    String? searchQuery,
    String? statusFilter,
    String sortBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      var query = _client
          .from('cars')
          .select('*, car_photos(storage_path)')
          .eq('dealer_id', _dealerId);

      if (statusFilter != null) query = query.eq('status', statusFilter);
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query.or('make.ilike.%$q%,model.ilike.%$q%');
      }

      final rows = await query
          .order(sortBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      return rows.map<CarModel>((row) => _withPhotoUrls(row)).toList();
    } on PostgrestException catch (e) {
      throw InventoryException('Could not load inventory: ${e.message}');
    } catch (_) {
      throw InventoryException('Unexpected error loading inventory.');
    }
  }

  CarModel _withPhotoUrls(Map<String, dynamic> row) {
    final photos = (row['car_photos'] as List<dynamic>? ?? [])
        .map((p) => _client.storage
            .from('vehicle-photos')
            .getPublicUrl((p as Map)['storage_path'] as String))
        .toList();
    final clean = Map<String, dynamic>.from(row)..remove('car_photos');
    return CarModel.fromJson({...clean, 'photo_urls': photos});
  }

  /// The exact `cars` insert row. `dealer_id` is NOT NULL and always comes
  /// from the signed-in staff member's dealership, never from the caller.
  /// `specs` (jsonb — holds body_type, which has no column of its own) is
  /// only sent when non-empty so the column default applies otherwise.
  static Map<String, dynamic> buildInsertPayload(CarModel car, String dealerId) => {
        ...car.toInsertJson(),
        if (car.specs.isNotEmpty) 'specs': car.specs,
        'dealer_id': dealerId,
      };

  Future<CarModel> createCar(CarModel car) async {
    try {
      final payload = buildInsertPayload(car, _dealerId);
      final row = await _client.from('cars').insert(payload).select().single();
      return CarModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw InventoryException(_friendlyDbError(e));
    }
  }

  /// [clear] names columns to set to NULL — `toInsertJson` drops nulls, so
  /// without this a field the dealer emptied would keep its old value.
  Future<CarModel> updateCar(String carId, CarModel car, {Set<String> clear = const {}}) async {
    try {
      final row = await _client
          .from('cars')
          .update({...car.toInsertJson(), for (final k in clear) k: null})
          .eq('id', carId)
          .eq('dealer_id', _dealerId)
          // Re-read with photos, or the edited card loses its image.
          .select('*, car_photos(storage_path)')
          .single();
      return _withPhotoUrls(row);
    } on PostgrestException catch (e) {
      throw InventoryException(_friendlyDbError(e));
    }
  }

  Future<void> updateStatus(String carId, String status) async {
    try {
      await _client
          .from('cars')
          .update({'status': status})
          .eq('id', carId)
          .eq('dealer_id', _dealerId);
    } on PostgrestException catch (e) {
      throw InventoryException('Could not update status: ${e.message}');
    }
  }

  /// Deletes the car and its photos. Throws [InventoryException] if the
  /// delete didn't actually happen — including the case where Supabase
  /// returns no error at all: an RLS policy that filters out the row (e.g.
  /// a stale `dealer_id`, or the staff membership isn't `active`) makes the
  /// DELETE match zero rows silently, with no PostgrestException thrown, so
  /// we explicitly check the affected row count via `.select()` instead of
  /// trusting a successful call to mean a row was removed.
  Future<void> deleteCar(String carId) async {
    try {
      await _client.from('car_photos').delete().eq('car_id', carId);
      final deleted = await _client
          .from('cars')
          .delete()
          .eq('id', carId)
          .eq('dealer_id', _dealerId)
          .select('id');
      if (deleted.isEmpty) {
        throw InventoryException(
            'Vehicle was not deleted — it may no longer belong to your '
            'dealership, or you may not have permission to remove it.');
      }
    } on PostgrestException catch (e) {
      throw InventoryException('Could not delete vehicle: ${e.message}');
    }
  }

  Future<void> bulkUpdateStatus(Set<String> carIds, String status) async {
    if (carIds.isEmpty) return;
    try {
      await _client
          .from('cars')
          .update({'status': status})
          .eq('dealer_id', _dealerId)
          .inFilter('id', carIds.toList());
    } on PostgrestException catch (e) {
      throw InventoryException('Bulk update failed: ${e.message}');
    }
  }

  /// Returns the ids actually deleted — may be a subset of [carIds] if RLS
  /// silently filtered some rows out (see [deleteCar] for why that doesn't
  /// throw on its own).
  Future<Set<String>> bulkDelete(Set<String> carIds) async {
    if (carIds.isEmpty) return const {};
    try {
      await _client.from('car_photos').delete().inFilter('car_id', carIds.toList());
      final deleted = await _client
          .from('cars')
          .delete()
          .eq('dealer_id', _dealerId)
          .inFilter('id', carIds.toList())
          .select('id');
      return deleted.map((r) => r['id'] as String).toSet();
    } on PostgrestException catch (e) {
      throw InventoryException('Bulk delete failed: ${e.message}');
    }
  }

  Future<List<CarAuditLog>> fetchAuditLog(String carId) async {
    try {
      final rows = await _client
          .from('car_audit_logs')
          .select()
          .eq('car_id', carId)
          .order('created_at', ascending: false);
      return rows.map<CarAuditLog>((r) => CarAuditLog.fromJson(r)).toList();
    } on PostgrestException catch (e) {
      throw InventoryException('Could not load audit history: ${e.message}');
    }
  }

  String _friendlyDbError(PostgrestException e) {
    debugPrint('InventoryService: PostgrestException code=${e.code} '
        'message=${e.message} details=${e.details} hint=${e.hint}');
    final msg = e.message.toLowerCase();
    // Keep the constraint name (e.g. "cars_condition_check") — it says
    // exactly which field was rejected.
    if (msg.contains('check constraint')) return 'Invalid value — ${e.message}';
    if (msg.contains('violates row-level security')) return 'Permission denied.';
    if (e.code == '23505' && msg.contains('chassis')) {
      return 'Another active listing on AutoServe already uses this chassis number. '
          'Check the number, or mark the other listing sold first.';
    }
    return 'Save failed: ${e.message}';
  }
}