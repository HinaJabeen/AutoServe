// lib/features/admin/admin_providers.dart
//
// Platform-wide reads/writes for super admins. Every query here relies on
// the "super_admin_full_access_*" RLS policies — a non-admin running them
// would simply see only their own dealership (or nothing).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDealerRow {
  const AdminDealerRow({
    required this.dealer,
    required this.carCount,
    required this.leadCount,
    this.ownerName,
    this.submittedAt,
    this.rejectionReason,
    this.isApplication = false,
  });
  final DealershipModel dealer;
  final int carCount;
  final int leadCount;

  /// From the private dealer_verifications row (applications only).
  final String? ownerName;
  final DateTime? submittedAt;
  final String? rejectionReason;

  /// Came in through the customer app's "Become a dealer" flow, as opposed
  /// to being registered directly by an admin.
  final bool isApplication;

  String get status => dealer.status;
}

class PlatformSummary {
  const PlatformSummary(this.dealers);
  final List<AdminDealerRow> dealers;

  int get totalDealers => dealers.length;
  int get approvedDealers => dealers.where((d) => d.status == 'approved').length;
  int get pendingDealers => dealers.where((d) => d.status == 'pending').length;
  int get totalCars => dealers.fold(0, (sum, d) => sum + d.carCount);
  int get totalLeads => dealers.fold(0, (sum, d) => sum + d.leadCount);

  List<AdminDealerRow> withStatus(String status) =>
      dealers.where((d) => d.status == status).toList();
}

int _embeddedCount(Object? embed) {
  if (embed is List && embed.isNotEmpty && embed.first is Map) {
    return ((embed.first as Map)['count'] as num?)?.toInt() ?? 0;
  }
  return 0;
}

/// PostgREST returns a one-to-one embed as an object (or a 1-element list
/// on older versions); null when there's no row.
Map<String, dynamic>? _embeddedOne(Object? embed) {
  if (embed is Map) return Map<String, dynamic>.from(embed);
  if (embed is List && embed.isNotEmpty && embed.first is Map) {
    return Map<String, dynamic>.from(embed.first as Map);
  }
  return null;
}

DateTime? _ts(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// One query: every dealer plus PostgREST-aggregated car/lead counts and the
/// applicant's name. Falls back to the pre-verification shape when the
/// 20261015120000 migration (dealer_verifications) isn't applied yet.
final platformSummaryProvider = FutureProvider.autoDispose<PlatformSummary>((ref) async {
  final client = SupabaseService.client;
  List<Map<String, dynamic>> rows;
  try {
    rows = await client
        .from('dealers')
        .select('*, cars(count), leads(count), dealer_verifications(owner_full_name)')
        .order('created_at', ascending: false);
  } on PostgrestException catch (e) {
    debugPrint('Admin summary: verification embed unavailable (${e.code}) — falling back');
    rows = await client
        .from('dealers')
        .select('*, cars(count), leads(count)')
        .order('created_at', ascending: false);
  }
  return PlatformSummary([
    for (final raw in rows)
      AdminDealerRow(
        dealer: DealershipModel.fromJson(Map<String, dynamic>.from(raw)),
        carCount: _embeddedCount(raw['cars']),
        leadCount: _embeddedCount(raw['leads']),
        ownerName: _embeddedOne(raw['dealer_verifications'])?['owner_full_name'] as String?,
        submittedAt: _ts(raw['submitted_at'] ?? raw['created_at']),
        rejectionReason: raw['rejection_reason'] as String?,
        isApplication: raw['applicant_user_id'] != null,
      ),
  ]);
});

// ── Application inspection ─────────────────────────────────────────────────

class ApplicationDetail {
  const ApplicationDetail({required this.dealer, required this.verification, required this.urls});

  /// The `dealers` row.
  final Map<String, dynamic> dealer;

  /// The private `dealer_verifications` row; null for admin-registered
  /// dealerships (no application was submitted).
  final Map<String, dynamic>? verification;

  /// Viewable URLs: 'showroom' (public), 'cnic_front' / 'cnic_back' /
  /// 'business_doc' (signed, short-lived — the bucket is private).
  final Map<String, String> urls;

  String? d(String key) => dealer[key]?.toString();
  String? v(String key) => verification?[key]?.toString();
  Map<String, dynamic> get inventory {
    final inv = verification?['initial_inventory_info'];
    return inv is Map ? Map<String, dynamic>.from(inv) : const {};
  }
}

const _signedUrlSeconds = 15 * 60;

final applicationDetailProvider =
    FutureProvider.autoDispose.family<ApplicationDetail, String>((ref, dealerId) async {
  final client = SupabaseService.client;
  final row = await client
      .from('dealers')
      .select('*, dealer_verifications(*)')
      .eq('id', dealerId)
      .single();
  final verification = _embeddedOne(row['dealer_verifications']);

  final urls = <String, String>{};
  final showroom = row['showroom_photo_url'] as String?;
  if (showroom != null && showroom.isNotEmpty) {
    urls['showroom'] = client.storage.from('dealership-photos').getPublicUrl(showroom);
  }
  final docs = {
    'cnic_front': verification?['cnic_front_url'] as String?,
    'cnic_back': verification?['cnic_back_url'] as String?,
    'business_doc': verification?['business_doc_url'] as String?,
  };
  for (final e in docs.entries) {
    final path = e.value;
    if (path == null || path.isEmpty) continue;
    try {
      urls[e.key] = await client.storage
          .from('verification-documents')
          .createSignedUrl(path, _signedUrlSeconds);
    } catch (err) {
      debugPrint('Signed URL for ${e.key} failed: $err');
    }
  }
  return ApplicationDetail(dealer: Map<String, dynamic>.from(row), verification: verification, urls: urls);
});

/// Approves, stamps verified_at/by, and makes the applicant the dealership's
/// owner in dealer_staff — atomically, server-side.
Future<String?> approveApplication(WidgetRef ref, String dealerId) async {
  try {
    await SupabaseService.client.rpc('approve_dealer_application', params: {'p_dealer_id': dealerId});
    ref.invalidate(platformSummaryProvider);
    ref.invalidate(applicationDetailProvider(dealerId));
    return null;
  } on PostgrestException catch (e) {
    return _describe(e);
  }
}

Future<String?> rejectApplication(WidgetRef ref, String dealerId, String reason) async {
  try {
    await SupabaseService.client.rpc('reject_dealer_application',
        params: {'p_dealer_id': dealerId, 'p_reason': reason});
    ref.invalidate(platformSummaryProvider);
    ref.invalidate(applicationDetailProvider(dealerId));
    return null;
  } on PostgrestException catch (e) {
    return _describe(e);
  }
}

String _describe(PostgrestException e) {
  debugPrint('Admin: ${e.code} ${e.message} details=${e.details} hint=${e.hint}');
  return e.message;
}

/// `dealers.status`: 'pending' | 'approved' | 'suspended'. Returns null on
/// success, or an error message.
Future<String?> setDealerStatus(WidgetRef ref, String dealerId, String status) async {
  try {
    await SupabaseService.client.from('dealers').update({'status': status}).eq('id', dealerId);
    ref.invalidate(platformSummaryProvider);
    return null;
  } on PostgrestException catch (e) {
    return _describe(e);
  }
}

/// Creates the dealership record only. The owner's login is separate: an
/// auth account must be created/invited and linked through `dealer_staff`.
/// Live `dealers` has no owner_name/email/phone columns — only name, city,
/// contact_phone, status, business_hours (+ address after its migration).
Future<String?> registerDealer(
  WidgetRef ref, {
  required String name,
  required String phone,
  required String city,
  String? address,
  bool approve = true,
}) async {
  try {
    await SupabaseService.client.from('dealers').insert({
      'name': name,
      'contact_phone': phone,
      'city': city,
      if (address != null && address.isNotEmpty) 'address': address,
      'status': approve ? 'approved' : 'pending',
    });
    ref.invalidate(platformSummaryProvider);
    return null;
  } on PostgrestException catch (e) {
    return _describe(e);
  }
}
