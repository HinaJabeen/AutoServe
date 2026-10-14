// lib/features/inventory/services/vehicle_storage_service.dart
// PART 4: Flutter Web safe image upload — no dart:io, uses XFile.readAsBytes()
// Uploads to the 'vehicle-photos' bucket and records each photo as a row in
// car_photos — the same bucket/table InventoryService reads from to build
// public URLs for the inventory grid. (Previously this wrote to a different
// bucket and appended URLs into cars.specs.images, which InventoryService
// never read — uploaded photos silently never showed up in the grid.)

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleStorageService {
  VehicleStorageService(this._client, this._dealerId);

  final SupabaseClient _client;
  final String _dealerId;

  static const _bucket = 'vehicle-photos';

  Future<List<XFile>> pickImages({int max = 10}) async {
    final picker = ImagePicker();
    final files  = await picker.pickMultiImage(imageQuality: 85);
    return files.take(max).toList();
  }

  /// Upload a single image and return its storage path (not a public URL —
  /// callers that need a URL should go through car_photos + getPublicUrl,
  /// same as InventoryService._withPhotoUrls).
  /// Uses uploadBinary (Uint8List) — safe on Flutter Web.
  Future<String> uploadImage({
    required String carId,
    required XFile file,
  }) async {
    // PART 4 FIX: readAsBytes() works on Web — no dart:io File needed.
    final Uint8List bytes = await file.readAsBytes();

    final path =
        '$_dealerId/$carId/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

    await _client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: file.mimeType ?? 'image/jpeg',
        upsert: false,
      ),
    );

    return path;
  }

  /// Upload all picked images and insert one car_photos row per upload.
  /// The first photo uploaded for a car with no existing photos is marked
  /// primary; subsequent uploads are appended at the next display_order.
  Future<List<String>> uploadAll({
    required String carId,
    required List<XFile> files,
  }) async {
    final paths = <String>[];

    for (final file in files) {
      try {
        final path = await uploadImage(carId: carId, file: file);
        paths.add(path);
      } catch (e) {
        if (kDebugMode) print('❌ uploadImage failed for ${file.name}: $e');
        // Continue uploading remaining files — partial success is acceptable.
      }
    }

    if (paths.isEmpty) return paths;

    try {
      final existing = await _client
          .from('car_photos')
          .select('id, display_order')
          .eq('car_id', carId)
          .order('display_order', ascending: false)
          .limit(1);

      final hasExisting = existing.isNotEmpty;
      final nextOrder = hasExisting
          ? ((existing.first['display_order'] as int?) ?? 0) + 1
          : 0;

      final rows = paths.asMap().entries.map((e) => {
            'car_id': carId,
            'storage_path': e.value,
            'is_primary': !hasExisting && e.key == 0,
            'display_order': nextOrder + e.key,
          }).toList();

      await _client.from('car_photos').insert(rows);
    } catch (e) {
      if (kDebugMode) print('❌ inserting car_photos rows: $e');
    }

    return paths;
  }

  /// Delete a single image: removes the storage object and its car_photos row.
  Future<void> deleteImage(String storagePath) async {
    try {
      await _client.storage.from(_bucket).remove([storagePath]);
      await _client.from('car_photos').delete().eq('storage_path', storagePath);
    } catch (e) {
      if (kDebugMode) print('❌ deleteImage: $e');
    }
  }
}
