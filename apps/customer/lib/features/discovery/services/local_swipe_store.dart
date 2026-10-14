// lib/features/discovery/services/local_swipe_store.dart
//
// Device-local persistence for swipe decisions — the v1 approach agreed in
// docs/architecture.md §8.2: there's no saved-swipes table, so "saved"/
// "passed" state lives in SharedPreferences, not Supabase. A car that's been
// swiped (either direction) is excluded from future decks; nothing syncs
// across devices.
//
// Keys are namespaced by the signed-in user's id so a second account on the
// same device starts with its own empty deck history and Saved list.

import 'package:shared_preferences/shared_preferences.dart';

class LocalSwipeStore {
  LocalSwipeStore(String? userId) : _scope = userId ?? 'signed_out';

  final String _scope;

  String get _interestedKey => 'autoserve_swiped_interested_$_scope';
  String get _passedKey => 'autoserve_swiped_passed_$_scope';

  Future<Set<String>> loadDecidedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final interested = prefs.getStringList(_interestedKey) ?? const [];
    final passed = prefs.getStringList(_passedKey) ?? const [];
    return {...interested, ...passed};
  }

  /// Oldest first — the order the cars were saved in.
  Future<List<String>> loadInterestedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_interestedKey) ?? const [];
  }

  Future<void> markInterested(String carId) => _update(_interestedKey, (ids) {
        ids.remove(carId);
        ids.add(carId);
      });

  Future<void> unmarkInterested(String carId) =>
      _update(_interestedKey, (ids) => ids.remove(carId));

  Future<void> markPassed(String carId) =>
      _update(_passedKey, (ids) {
        if (!ids.contains(carId)) ids.add(carId);
      });

  Future<void> _update(String key, void Function(List<String> ids) change) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = [...?prefs.getStringList(key)];
    change(ids);
    await prefs.setStringList(key, ids);
  }
}
