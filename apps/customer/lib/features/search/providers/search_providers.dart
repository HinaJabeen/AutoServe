// lib/features/search/providers/search_providers.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../models/search_result.dart';
import '../services/search_service.dart';

final searchServiceProvider =
    Provider.autoDispose<SearchService>((ref) => SearchService(SupabaseService.client));

const _searchDebounce = Duration(milliseconds: 350);

/// The query that actually drives a network fetch — updated 350ms after the
/// user stops typing. `autoDispose` + the `ref.onDispose` below means the
/// pending [Timer] is always cancelled, whether the user types again before
/// it fires or simply leaves the search screen.
class DebouncedSearchQueryNotifier extends AutoDisposeNotifier<String> {
  Timer? _timer;

  @override
  String build() {
    ref.onDispose(() => _timer?.cancel());
    return '';
  }

  void onQueryChanged(String value) {
    _timer?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = ''; // nothing to debounce — clear results immediately
      return;
    }
    _timer = Timer(_searchDebounce, () => state = trimmed);
  }

  void clear() {
    _timer?.cancel();
    state = '';
  }
}

final debouncedSearchQueryProvider =
    AutoDisposeNotifierProvider<DebouncedSearchQueryNotifier, String>(
        DebouncedSearchQueryNotifier.new);

/// Below this length a query is treated as "not searching yet" — avoids
/// firing a near-useless single-character fetch on every search session.
const minSearchQueryLength = 2;

final searchResultsProvider = FutureProvider.autoDispose<SearchResults>((ref) async {
  final query = ref.watch(debouncedSearchQueryProvider);
  if (query.length < minSearchQueryLength) return SearchResults.empty;
  return ref.read(searchServiceProvider).search(query);
});
