// lib/features/providers/lead_provider.dart
// FIXED: Supabase stream maps DB columns to LeadModel fields correctly.
// NoSuchMethodError 'id' on _JsonMap is caused by calling .id on a Map —
// fixed by explicit ['id'] access inside the mapping closure.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'package:dashboard/features/providers/auth_provider.dart';

// ─── Mock leads (only used when not authenticated) ────────────────────────────

final _now = DateTime.now();

final _mockLeads = <LeadModel>[
  LeadModel(
    id: 'lead-0001',
    dealershipId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    vehicleId: 'aaaaaaaa-bbbb-cccc-dddd-000000000001',
    consumerId: null,
    consumerName: 'Ali Khan',
    consumerPhone: '03001112233',
    consumerEmail: null,
    type: 'inquiry',
    status: 'new',
    notes: 'Asked about Corolla financing',
    createdAt: _now,
  ),
  LeadModel(
    id: 'lead-0002',
    dealershipId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    vehicleId: 'aaaaaaaa-bbbb-cccc-dddd-000000000002',
    consumerId: null,
    consumerName: 'Sara Ahmed',
    consumerPhone: '03004445566',
    consumerEmail: null,
    type: 'inquiry',
    status: 'contacted',
    notes: 'Visited Saturday, wants Civic',
    createdAt: _now.subtract(const Duration(hours: 3)),
  ),
  LeadModel(
    id: 'lead-0003',
    dealershipId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    vehicleId: 'aaaaaaaa-bbbb-cccc-dddd-000000000002',
    consumerId: null,
    consumerName: 'Bilal Raza',
    consumerPhone: '03007778899',
    consumerEmail: null,
    type: 'test_drive',
    status: 'contacted',
    notes: 'Offer at 6.0M on Civic',
    createdAt: _now.subtract(const Duration(days: 1)),
  ),
];

// ─── Live stream ──────────────────────────────────────────────────────────────
// CRITICAL FIX: raw Supabase rows are _JsonMap — you cannot call .id on them.
// Access every field with r['key']?.toString() before passing to LeadModel.fromJson.
// DB schema:  customer_name, stage, car_id, dealer_id
// LeadModel:  consumer_name, status, vehicle_id, dealership_id

final dealerLeadsStreamProvider = StreamProvider<List<LeadModel>>((ref) {
  final dealershipId = ref.watch(currentDealershipIdProvider);

  if (dealershipId == null) {
    return Stream.value(_mockLeads);
  }

  return SupabaseService.client
      .from('leads')
      .stream(primaryKey: ['id'])
      .eq('dealer_id', dealershipId)
      .order('created_at', ascending: false)
      .map((rows) => rows.map((raw) {
            // Cast to typed map first so every access is safe.
            final r = Map<String, dynamic>.from(raw);
            return LeadModel.fromJson({
              'id':             r['id']?.toString()           ?? '',
              'dealership_id':  r['dealer_id']?.toString()    ?? '',
              'vehicle_id':     r['car_id']?.toString(),       // nullable — OK
              'consumer_id':    null,
              'consumer_name':  r['customer_name']?.toString() ?? 'Unknown',
              'consumer_phone': r['customer_phone']?.toString(),
              'consumer_email': null,
              // `leads` has no type column; the intake channel lives in
              // `source` ('test_drive_request', 'inquiry', 'walk_in', ...).
              'type':           r['source']?.toString()        ?? 'inquiry',
              // stage → status column rename
              'status':         r['stage']?.toString()         ?? 'new',
              'notes':          r['notes']?.toString(),
              'created_at':     r['created_at']?.toString()    ??
                                    DateTime.now().toIso8601String(),
            });
          }).toList());
});

// ─── Unread count ─────────────────────────────────────────────────────────────

class UnreadLeadCountNotifier extends Notifier<int> {
  @override
  int build() => _mockLeads.where((l) => l.status == 'new').length;
  void clear() => state = 0;
  void increment() => state = state + 1;
}

final unreadLeadCountProvider =
    NotifierProvider<UnreadLeadCountNotifier, int>(UnreadLeadCountNotifier.new);

// ─── Lead mutation ────────────────────────────────────────────────────────────

class LeadMutationState {
  const LeadMutationState({this.isLoading = false, this.errorMessage});
  final bool isLoading;
  final String? errorMessage;
  LeadMutationState copyWith({bool? isLoading, String? errorMessage}) =>
      LeadMutationState(
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class LeadNotifier extends StateNotifier<LeadMutationState> {
  LeadNotifier() : super(const LeadMutationState());

  Future<bool> updateStatus(String leadId, String newStatus) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await SupabaseService.client
          .from('leads')
          .update({'stage': newStatus}).eq('id', leadId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ updateStatus: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final leadNotifierProvider =
    StateNotifierProvider<LeadNotifier, LeadMutationState>(
  (ref) => LeadNotifier(),
);