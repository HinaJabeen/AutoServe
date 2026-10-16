// lib/features/dealer_application/services/dealer_application_service.dart

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dealer_application.dart';

enum UploadBucket {
  /// Public — the showroom facade is shown to customers once approved.
  showroomPhotos('dealership-photos'),

  /// Private — CNIC and business proof; only the applicant and admins.
  verificationDocs('verification-documents');

  const UploadBucket(this.id);
  final String id;
}

class DealerApplicationException implements Exception {
  DealerApplicationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DealerApplicationService {
  DealerApplicationService(this._client);
  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 60);

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw DealerApplicationException('Please sign in again.');
    return id;
  }

  /// The user's own application, or null if they haven't applied.
  Future<DealerApplication?> fetchMine() async {
    try {
      final row = await _client
          .from('dealers')
          .select('*, dealer_verifications(*)')
          .eq('applicant_user_id', _uid)
          .maybeSingle();
      return row == null ? null : DealerApplication.fromRow(row);
    } on PostgrestException catch (e) {
      debugPrint('DealerApplicationService.fetchMine: ${e.code} ${e.message}');
      // 42703 = the verification migration hasn't been applied yet; treat as
      // "no application" so the profile still renders.
      if (e.code == '42703') return null;
      throw DealerApplicationException('Could not load your dealership application.');
    }
  }

  /// Uploads [file] under `uid/slot_timestamp.ext` (the storage policies
  /// only allow writes inside the caller's own uid folder) and returns the
  /// storage path.
  Future<String> upload(UploadBucket bucket, String slot, XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      throw DealerApplicationException('That image is over 10 MB. Please choose a smaller one.');
    }
    final mime = (file.mimeType ?? '').toLowerCase();
    final name = file.name.toLowerCase();
    final (ext, type) = mime == 'image/png' || name.endsWith('.png')
        ? ('png', 'image/png')
        : mime == 'image/webp' || name.endsWith('.webp')
            ? ('webp', 'image/webp')
            : ('jpg', 'image/jpeg');
    final path = '$_uid/${slot}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      await _client.storage
          .from(bucket.id)
          .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: type))
          .timeout(_timeout);
      return path;
    } on StorageException catch (e) {
      debugPrint('Upload to ${bucket.id} failed: ${e.statusCode} ${e.message}');
      throw DealerApplicationException('Upload failed: ${e.message}');
    } catch (e) {
      debugPrint('Upload to ${bucket.id} failed: $e');
      throw DealerApplicationException('Upload failed. Check your connection and try again.');
    }
  }

  String publicUrl(String path) =>
      _client.storage.from(UploadBucket.showroomPhotos.id).getPublicUrl(path);

  Future<void> submit(DealerApplicationDraft draft) async {
    try {
      await _client
          .rpc('submit_dealer_application', params: draft.toRpcParams())
          .timeout(_timeout);
    } on PostgrestException catch (e) {
      debugPrint('submit_dealer_application: ${e.code} ${e.message} details=${e.details}');
      throw DealerApplicationException(e.message);
    }
  }
}
