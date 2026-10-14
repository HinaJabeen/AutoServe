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
  });
  final DealershipModel dealer;
  final int carCount;
  final int leadCount;
}

class PlatformSummary {
  const PlatformSummary(this.dealers);
  final List<AdminDealerRow> dealers;

  int get totalDealers => dealers.length;
  int get approvedDealers => dealers.where((d) => d.dealer.status == 'approved').length;
  int get pendingDealers => dealers.where((d) => d.dealer.status == 'pending').length;
  int get totalCars => dealers.fold(0, (sum, d) => sum + d.carCount);
  int get totalLeads => dealers.fold(0, (sum, d) => sum + d.leadCount);
}

int _embeddedCount(Object? embed) {
  if (embed is List && embed.isNotEmpty && embed.first is Map) {
    return ((embed.first as Map)['count'] as num?)?.toInt() ?? 0;
  }
  return 0;
}

/// One query: every dealer plus PostgREST-aggregated car/lead counts.
final platformSummaryProvider = FutureProvider.autoDispose<PlatformSummary>((ref) async {
  final rows = await SupabaseService.client
      .from('dealers')
      .select('*, cars(count), leads(count)')
      .order('created_at', ascending: false);
  return PlatformSummary([
    for (final raw in rows)
      AdminDealerRow(
        dealer: DealershipModel.fromJson(Map<String, dynamic>.from(raw)),
        carCount: _embeddedCount(raw['cars']),
        leadCount: _embeddedCount(raw['leads']),
      ),
  ]);
});

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
