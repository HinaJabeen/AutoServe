// lib/features/discovery/providers/discovery_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../filters/providers/filter_providers.dart';
import '../services/car_discovery_service.dart';
import '../services/local_swipe_store.dart';

final localSwipeStoreProvider = Provider<LocalSwipeStore>((ref) => LocalSwipeStore());

final carDiscoveryServiceProvider = Provider<CarDiscoveryService>(
  (ref) => CarDiscoveryService(SupabaseService.client),
);

/// The full, unfiltered pool of available listings for this session — the
/// single network fetch that both the deck and the filter matrix's
/// make/model/body-type option lists are derived from, so filtering never
/// triggers a second round trip.
final availableCarsProvider = FutureProvider<List<CarModel>>((ref) {
  return ref.read(carDiscoveryServiceProvider).fetchAvailableCars();
});

/// The deck for this session: `availableCarsProvider`, minus already-decided
/// cars, minus anything `vehicleFiltersProvider` excludes.
///
/// Unlike Step 1–3 (where this never recomputed mid-session — `CardSwiper`
/// owns its own internal index/stack once built, so a silently-changing list
/// would desync from it), changing filters is a deliberate user action that
/// *should* give a fresh deck. The UI remounts `CardSwiper` via a key tied to
/// `vehicleFiltersProvider` so its internal state doesn't go stale across
/// that intentional reset — see `swipe_deck_screen.dart`.
final carDeckProvider = FutureProvider<List<CarModel>>((ref) async {
  final decidedIds = await ref.read(localSwipeStoreProvider).loadDecidedIds();
  final cars = await ref.watch(availableCarsProvider.future);
  final filters = ref.watch(vehicleFiltersProvider);
  return cars.where((c) => !decidedIds.contains(c.id) && filters.matches(c)).toList();
});

// ─── Saved cars (swipe right) ──────────────────────────────────────────────────
//
// In-memory, reactive mirror of the user's right-swipes for this session —
// separate from `LocalSwipeStore`, which persists *ids* to SharedPreferences
// so a swiped car doesn't reappear in `carDeckProvider` after a cold start.
// This notifier holds the full `CarModel`s so a "Saved" screen (later step)
// can render them without re-fetching; it never talks to Supabase itself.

class SavedCarsNotifier extends Notifier<List<CarModel>> {
  @override
  List<CarModel> build() => const [];

  void add(CarModel car) {
    if (state.any((c) => c.id == car.id)) return;
    state = [...state, car];
  }
}

final savedCarsProvider =
    NotifierProvider<SavedCarsNotifier, List<CarModel>>(SavedCarsNotifier.new);

// ─── Lead mutation (swipe-up → book test drive) ───────────────────────────────

class TestDriveRequestState {
  const TestDriveRequestState({this.isSubmitting = false, this.errorMessage});
  final bool isSubmitting;
  final String? errorMessage;

  TestDriveRequestState copyWith({bool? isSubmitting, String? errorMessage}) =>
      TestDriveRequestState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        errorMessage: errorMessage,
      );
}

class TestDriveRequestNotifier extends StateNotifier<TestDriveRequestState> {
  TestDriveRequestNotifier() : super(const TestDriveRequestState());

  /// Returns true on success. Matches the insert shape in
  /// docs/api_contracts.md "Creating a Lead" — allowed for `anon` callers,
  /// see docs/security.md §2 (leads accepts open insert; no consumer account
  /// exists in the live schema).
  ///
  /// `leads` has no `customer_email`/`preferred_date` column in the live
  /// schema — adding one is a migration we weren't asked for, so both are
  /// folded into the existing nullable `notes` text column instead of
  /// inventing new columns the dashboard's lead inbox wouldn't know to show.
  Future<bool> submit({
    required CarModel car,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required DateTime preferredDate,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await SupabaseService.client.from('leads').insert({
        'dealer_id': car.dealerId,
        'car_id': car.id,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'source': 'test_drive_request',
        'stage': 'new',
        'notes': 'Test drive requested for ${_formatDate(preferredDate)}. '
            'Contact email: $customerEmail',
      });
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void clearError() => state = state.copyWith(errorMessage: null);
}

final testDriveRequestProvider =
    StateNotifierProvider<TestDriveRequestNotifier, TestDriveRequestState>(
  (ref) => TestDriveRequestNotifier(),
);
