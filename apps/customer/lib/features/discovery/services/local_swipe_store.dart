// lib/features/discovery/services/local_swipe_store.dart
//
// Device-local persistence for swipe decisions — the v1 approach agreed in
// docs/architecture.md §8.2: the live schema has no consumer-identity table,
// so "saved"/"passed" state lives in SharedPreferences, not a Supabase table.
// A car that's been swiped (either direction) is excluded from future decks
// on this device; it is not synced anywhere and has no cross-device memory.

import 'package:shared_preferences/shared_preferences.dart';

class LocalSwipeStore {
  static const _interestedKey = 'autoserve_swiped_interested';
  static const _passedKey = 'autoserve_swiped_passed';

  Future<Set<String>> loadDecidedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final interested = prefs.getStringList(_interestedKey) ?? const [];
    final passed = prefs.getStringList(_passedKey) ?? const [];
    return {...interested, ...passed};
  }

  Future<Set<String>> loadInterestedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_interestedKey) ?? const []).toSet();
  }

  Future<void> markInterested(String carId) async {
    await _addTo(_interestedKey, carId);
  }

  Future<void> markPassed(String carId) async {
    await _addTo(_passedKey, carId);
  }

  Future<void> _addTo(String key, String carId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(key) ?? const []).toSet();
    current.add(carId);
    await prefs.setStringList(key, current.toList());
  }
}
