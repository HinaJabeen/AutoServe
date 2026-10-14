// lib/features/providers/overview_provider.dart
// FIXED:
//  1. dealerLeadsStreamProvider maps DB columns (customer_name→consumer_name,
//     stage→status, car_id→vehicle_id, dealer_id→dealership_id) before
//     calling LeadModel.fromJson — prevents NoSuchMethodError and TypeError.
//  2. All raw map fields accessed with safe null fallbacks via helper.
//  3. revenueMonthlyProvider skips rows where updated_at is null.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';

import 'auth_provider.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

const _closedLeadStages = {'closed_won', 'closed_lost'};

class DashboardMetrics {
  const DashboardMetrics({
    required this.totalVehicles,
    required this.availableVehicles,
    required this.reservedVehicles,
    required this.newLeadsToday,
    required this.soldVehicles,
    required this.soldThisMonth,
    required this.activeLeadsCount,
    required this.grossStockValue,
    required this.leadsThisMonth,
    required this.leadsByStage,
  });
  final int totalVehicles;
  final int availableVehicles;
  final int reservedVehicles;
  final int newLeadsToday;
  final int soldVehicles;
  /// Cars marked `sold` with `updated_at` in the current calendar month.
  final int soldThisMonth;
  /// Leads not yet in a closed stage (`closed_won`/`closed_lost`).
  final int activeLeadsCount;
  /// sum(price) across all `available` cars — the dealer's current stock value.
  final double grossStockValue;
  /// Leads created since the 1st of the current month.
  final int leadsThisMonth;
  /// Every lead counted by `leads.stage` (all stages present, zero-filled).
  final Map<String, int> leadsByStage;
}

class MonthlyRevenue {
  const MonthlyRevenue({required this.month, required this.revenue, required this.count});
  final DateTime month;
  final double revenue;
  final int count;
}

class InventoryAgingBucket {
  const InventoryAgingBucket({required this.status, required this.count});
  final String status;
  final int count;
}

// ─── Safe field helpers ───────────────────────────────────────────────────────
// Never cast raw Supabase maps with `as String` — the column may be null.

String _s(Map r, String k, {String d = ''}) => r[k]?.toString() ?? d;
double _d(Map r, String k, {double d = 0}) {
  final v = r[k]; if (v == null) return d;
  return v is num ? v.toDouble() : double.tryParse(v.toString()) ?? d;
}
DateTime? _dt(Map r, String k) {
  final v = r[k]; if (v == null) return null;
  try { return DateTime.parse(v.toString()); } catch (_) { return null; }
}

// ─── Cars stream ──────────────────────────────────────────────────────────────

final dealerCarsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final dealerId = ref.watch(currentDealershipIdProvider);
  if (dealerId == null) return const Stream.empty();
  return Supabase.instance.client
      .from('cars')
      .stream(primaryKey: ['id'])
      .eq('dealer_id', dealerId)
      .map((rows) => rows.map((r) => Map<String, dynamic>.from(r)).toList());
});

// Alias for screens that import this name.
final dealerVehiclesStreamProvider = dealerCarsStreamProvider;

// ─── Leads stream ─────────────────────────────────────────────────────────────
// CRITICAL FIX: map DB column names → LeadModel field names before fromJson.
// DB schema (0001_init.sql):  customer_name, stage, car_id, dealer_id
// LeadModel expects:          consumer_name, status, vehicle_id, dealership_id

final dealerLeadsStreamProvider = StreamProvider<List<LeadModel>>((ref) {
  final dealerId = ref.watch(currentDealershipIdProvider);
  if (dealerId == null) return const Stream.empty();

  return Supabase.instance.client
      .from('leads')
      .stream(primaryKey: ['id'])
      .eq('dealer_id', dealerId)
      .order('created_at', ascending: false)
      .map((rows) => rows.map((raw) {
            final r = Map<String, dynamic>.from(raw);
            return LeadModel.fromJson({
              'id':             _s(r, 'id'),
              'dealership_id':  _s(r, 'dealer_id'),
              'vehicle_id':     r['car_id']?.toString(),
              'consumer_id':    null,
              'consumer_name':  _s(r, 'customer_name', d: 'Unknown'),
              'consumer_phone': r['customer_phone']?.toString(),
              'consumer_email': null,
              'type':           'inquiry',
              'status':         _s(r, 'stage', d: 'new'),
              'notes':          r['notes']?.toString(),
              'created_at':     _s(r, 'created_at',
                                    d: DateTime.now().toIso8601String()),
            });
          }).toList());
});

// ─── Dashboard metrics ────────────────────────────────────────────────────────

/// `leads.stage` values in pipeline order.
const leadPipelineStages = [
  'new', 'contacted', 'test_drive_scheduled', 'negotiating', 'closed_won', 'closed_lost',
];

final dashboardMetricsProvider = Provider<AsyncValue<DashboardMetrics>>((ref) {
  final carsAsync  = ref.watch(dealerCarsStreamProvider);
  final leadsAsync = ref.watch(dealerLeadsStreamProvider);

  if (carsAsync.isLoading || leadsAsync.isLoading) return const AsyncValue.loading();
  if (carsAsync.hasError)
    return AsyncValue.error(carsAsync.error!, carsAsync.stackTrace ?? StackTrace.current);
  if (leadsAsync.hasError)
    return AsyncValue.error(leadsAsync.error!, leadsAsync.stackTrace ?? StackTrace.current);

  final cars  = carsAsync.value  ?? [];
  final leads = leadsAsync.value ?? [];
  final now          = DateTime.now();
  final startOfDay   = DateTime(now.year, now.month, now.day);
  final startOfMonth = DateTime(now.year, now.month, 1);

  return AsyncValue.data(DashboardMetrics(
    totalVehicles:     cars.length,
    availableVehicles: cars.where((c) => _s(c, 'status') == 'available').length,
    reservedVehicles:  cars.where((c) => _s(c, 'status') == 'reserved').length,
    soldVehicles:      cars.where((c) => _s(c, 'status') == 'sold').length,
    soldThisMonth: cars.where((c) {
      if (_s(c, 'status') != 'sold') return false;
      final dt = _dt(c, 'updated_at');
      return dt != null && !dt.toLocal().isBefore(startOfMonth);
    }).length,
    grossStockValue: cars
        .where((c) => _s(c, 'status') == 'available')
        .fold(0.0, (sum, c) => sum + _d(c, 'price')),
    activeLeadsCount:
        leads.where((l) => !_closedLeadStages.contains(l.status)).length,
    newLeadsToday: leads.where((l) {
      try { return l.createdAt.toLocal().isAfter(startOfDay); } catch (_) { return false; }
    }).length,
    leadsThisMonth:
        leads.where((l) => !l.createdAt.toLocal().isBefore(startOfMonth)).length,
    leadsByStage: {
      for (final stage in leadPipelineStages)
        stage: leads.where((l) => l.status == stage).length,
    },
  ));
});

// ─── Revenue trend ────────────────────────────────────────────────────────────
// Derived from dealerCarsStreamProvider (not a one-shot query) so it updates
// live the moment a car's status/price changes, same as the other charts.

final revenueMonthlyProvider =
    Provider<AsyncValue<List<MonthlyRevenue>>>((ref) {
  final carsAsync = ref.watch(dealerCarsStreamProvider);
  return carsAsync.whenData((cars) {
    final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
    final Map<String, ({double revenue, int count})> buckets = {};

    for (final c in cars) {
      if (_s(c, 'status') != 'sold') continue;
      final dt = _dt(c, 'updated_at');
      if (dt == null || dt.isBefore(sixMonthsAgo)) continue;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      final p   = _d(c, 'price');
      final ex  = buckets[key];
      buckets[key] = ex == null
          ? (revenue: p, count: 1)
          : (revenue: ex.revenue + p, count: ex.count + 1);
    }

    return buckets.entries.map((e) {
      final parts = e.key.split('-');
      return MonthlyRevenue(
        month:   DateTime(int.parse(parts[0]), int.parse(parts[1])),
        revenue: e.value.revenue,
        count:   e.value.count,
      );
    }).toList()..sort((a, b) => a.month.compareTo(b.month));
  });
});

// ─── Lead conversion rate ─────────────────────────────────────────────────────
// Share of leads that closed won, out of all leads — live off the same
// dealerLeadsStreamProvider the Kanban board already watches.

final leadConversionRateProvider = Provider<AsyncValue<double>>((ref) {
  final leadsAsync = ref.watch(dealerLeadsStreamProvider);
  return leadsAsync.whenData((leads) {
    if (leads.isEmpty) return 0.0;
    final won = leads.where((l) => l.status == 'closed_won').length;
    return won / leads.length * 100;
  });
});

// ─── Inventory aging ──────────────────────────────────────────────────────────

final inventoryAgingProvider = Provider<AsyncValue<List<InventoryAgingBucket>>>((ref) {
  final carsAsync = ref.watch(dealerCarsStreamProvider);
  return carsAsync.whenData((cars) {
    final counts = <String, int>{};
    for (final c in cars) {
      final s = _s(c, 'status', d: 'unknown');
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts.entries
        .map((e) => InventoryAgingBucket(status: e.key, count: e.value))
        .toList();
  });
});

// ─── Dealership info ──────────────────────────────────────────────────────────

final currentDealershipProvider = FutureProvider<DealershipModel?>((ref) async {
  final dealerId = ref.watch(currentDealershipIdProvider);
  if (dealerId == null) return null;
  try {
    final data = await Supabase.instance.client
        .from('dealers')
        .select()
        .eq('id', dealerId)
        .single();
    return DealershipModel.fromJson(Map<String, dynamic>.from(data));
  } catch (_) {
    return null;
  }
});

void retryDashboardMetrics(WidgetRef ref) {
  // revenueMonthlyProvider and leadConversionRateProvider are derived from
  // these two streams, so invalidating the streams is enough to recompute
  // everything downstream.
  ref.invalidate(dealerCarsStreamProvider);
  ref.invalidate(dealerLeadsStreamProvider);
}