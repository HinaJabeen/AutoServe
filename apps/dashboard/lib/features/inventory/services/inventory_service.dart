// lib/features/inventory/services/inventory_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dashboard/features/inventory/models/car_model.dart';

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

  Future<CarModel> createCar(CarModel car) async {
    try {
      final payload = car.toInsertJson()..['dealer_id'] = _dealerId;
      final row = await _client.from('cars').insert(payload).select().single();
      return CarModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw InventoryException(_friendlyDbError(e));
    }
  }

  Future<CarModel> updateCar(String carId, CarModel car) async {
    try {
      final row = await _client
          .from('cars')
          .update(car.toInsertJson())
          .eq('id', carId)
          .eq('dealer_id', _dealerId)
          .select()
          .single();
      return CarModel.fromJson(row);
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

  /// Returns true on success, false on failure — never throws to the caller.
  Future<bool> deleteCar(String carId) async {
    try {
      await _client.from('car_photos').delete().eq('car_id', carId);
      await _client.from('cars').delete().eq('id', carId).eq('dealer_id', _dealerId);
      return true;
    } catch (_) {
      return false;
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

  Future<bool> bulkDelete(Set<String> carIds) async {
    if (carIds.isEmpty) return true;
    try {
      await _client.from('car_photos').delete().inFilter('car_id', carIds.toList());
      await _client.from('cars').delete().eq('dealer_id', _dealerId).inFilter('id', carIds.toList());
      return true;
    } catch (_) {
      return false;
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
    final msg = e.message.toLowerCase();
    if (msg.contains('check constraint')) return 'Invalid value — check dropdown selections.';
    if (msg.contains('violates row-level security')) return 'Permission denied.';
    return 'Save failed: ${e.message}';
  }
}