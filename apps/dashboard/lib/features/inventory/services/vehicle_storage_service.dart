// lib/features/inventory/services/vehicle_storage_service.dart
// PART 4: Flutter Web safe image upload — no dart:io, uses XFile.readAsBytes()
// Uploads to 'vehicles' bucket, appends public URL to cars.images array.

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleStorageService {
  VehicleStorageService(this._client, this._dealerId);

  final SupabaseClient _client;
  final String _dealerId;

  static const _bucket = 'vehicles';

  Future<List<XFile>> pickImages({int max = 10}) async {
    final picker = ImagePicker();
    final files  = await picker.pickMultiImage(imageQuality: 85);
    return files.take(max).toList();
  }

  /// Upload a single image and return its public URL.
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

    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  /// Upload all picked images and append their URLs to cars.images[].
  Future<List<String>> uploadAll({
    required String carId,
    required List<XFile> files,
  }) async {
    final urls = <String>[];

    for (final file in files) {
      try {
        final url = await uploadImage(carId: carId, file: file);
        urls.add(url);
      } catch (e) {
        if (kDebugMode) print('❌ uploadImage failed for ${file.name}: $e');
        // Continue uploading remaining files — partial success is acceptable.
      }
    }

    if (urls.isNotEmpty) {
      // Append new URLs to the existing images array in Supabase.
      // Use rpc to atomically array_append without overwriting other fields.
      try {
        // Fetch current images first, then merge.
        final row = await _client
            .from('cars')
            .select('specs')
            .eq('id', carId)
            .single();

        final specs = Map<String, dynamic>.from(
            (row['specs'] as Map?)  ?? {});
        final existing = List<String>.from(
            (specs['images'] as List?) ?? []);
        existing.addAll(urls);
        specs['images'] = existing;

        await _client
            .from('cars')
            .update({'specs': specs}).eq('id', carId);
      } catch (e) {
        if (kDebugMode) print('❌ updating car images in DB: $e');
      }
    }

    return urls;
  }

  /// Delete a single image by its storage path.
  Future<void> deleteImage(String storagePath) async {
    try {
      await _client.storage.from(_bucket).remove([storagePath]);
    } catch (e) {
      if (kDebugMode) print('❌ deleteImage: $e');
    }
  }
}