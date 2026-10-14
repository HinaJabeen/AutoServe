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

class PhotoUploadException implements Exception {
  PhotoUploadException(this.message);
  final String message;
  @override
  String toString() => message;
}

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
  ///
  /// Path layout `dealers/<dealer>/vehicles/<car>/<ts>_<n>.<ext>` matches
  /// every photo that has successfully landed in the live bucket. The
  /// original filename is deliberately not used: device names like
  /// "WhatsApp Image (1).jpeg" or non-ASCII names can be rejected as
  /// invalid storage keys.
  Future<String> uploadImage({
    required String carId,
    required XFile file,
    int index = 0,
  }) async {
    final Uint8List bytes = await file.readAsBytes();
    final (ext, contentType) = _typeOf(file);

    final path = 'dealers/$_dealerId/vehicles/$carId/'
        '${DateTime.now().millisecondsSinceEpoch}_$index.$ext';

    await _client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: false),
    );

    return path;
  }

  static (String, String) _typeOf(XFile file) {
    final mime = file.mimeType?.toLowerCase();
    final name = file.name.toLowerCase();
    if (mime == 'image/png' || name.endsWith('.png')) return ('png', 'image/png');
    if (mime == 'image/webp' || name.endsWith('.webp')) return ('webp', 'image/webp');
    if (mime == 'image/gif' || name.endsWith('.gif')) return ('gif', 'image/gif');
    return ('jpg', 'image/jpeg');
  }

  /// Upload all picked images and insert one car_photos row per upload.
  /// The first photo uploaded for a car with no existing photos is marked
  /// primary; subsequent uploads are appended at the next display_order.
  ///
  /// Every file is attempted and every successful upload gets its row; if
  /// anything failed, throws [PhotoUploadException] afterwards so the caller
  /// can tell the user instead of the photos silently going missing.
  Future<List<String>> uploadAll({
    required String carId,
    required List<XFile> files,
  }) async {
    final paths = <String>[];
    final failures = <String>[];

    for (final (i, file) in files.indexed) {
      try {
        paths.add(await uploadImage(carId: carId, file: file, index: i));
      } catch (e) {
        debugPrint('VehicleStorageService: upload failed for ${file.name} — $e');
        failures.add('${file.name}: $e');
      }
    }

    if (paths.isNotEmpty) {
      try {
        await _insertPhotoRows(carId, paths);
      } catch (e) {
        debugPrint('VehicleStorageService: inserting car_photos rows failed — $e');
        throw PhotoUploadException(
            'Photos uploaded but could not be linked to the vehicle: $e');
      }
    }

    if (failures.isNotEmpty) {
      throw PhotoUploadException(
          '${failures.length} of ${files.length} photo(s) failed to upload. '
          '${failures.first}');
    }
    return paths;
  }

  Future<void> _insertPhotoRows(String carId, List<String> paths) async {
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
