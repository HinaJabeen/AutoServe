// lib/features/search/services/search_service.dart
//
// Unified search over public listings: `cars` (available, public) matched on
// make/model, and `dealers` (approved) matched on name/city. Both are
// anon/authenticated-readable under the same RLS predicates the deck and
// vehicle detail screen already rely on — see
// backend/supabase/supabase/migrations/20261013160000_customer_profiles.sql
// for the `authenticated_view_approved_dealers` policy this depends on.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';

import '../../../core/car_row_mapper.dart';
import '../models/search_result.dart';

class SearchException implements Exception {
  SearchException(this.message);
  final String message;
  @override
  String toString() => message;
}

const _resultLimit = 20;

class SearchService {
  SearchService(this._client);
  final SupabaseClient _client;

  Future<SearchResults> search(String query) async {
    final term = _sanitize(query);
    if (term.isEmpty) return SearchResults.empty;
    final pattern = '%$term%';

    try {
      final results = await Future.wait([
        _searchVehicles(pattern),
        _searchDealers(pattern),
      ]);
      return SearchResults(
        vehicles: results[0] as List<VehicleSearchResult>,
        dealers: results[1] as List<DealerSearchResult>,
      );
    } on PostgrestException catch (e) {
      throw SearchException('Search failed: ${e.message}');
    }
  }

  Future<List<VehicleSearchResult>> _searchVehicles(String pattern) async {
    final rows = await _client
        .from('cars')
        .select('*, car_photos(storage_path), dealers(name)')
        .eq('is_public', true)
        .eq('status', 'available')
        .or('make.ilike.$pattern,model.ilike.$pattern')
        .order('created_at', ascending: false)
        .limit(_resultLimit);

    return rows.map<VehicleSearchResult>((raw) {
      final row = Map<String, dynamic>.from(raw);
      final dealerName = (row['dealers'] as Map?)?['name']?.toString() ?? 'AutoServe Dealership';
      final clean = Map<String, dynamic>.from(row)..remove('dealers');
      return VehicleSearchResult(
        car: carModelFromRow(clean, _client),
        dealerName: dealerName,
      );
    }).toList();
  }

  Future<List<DealerSearchResult>> _searchDealers(String pattern) async {
    final rows = await _client
        .from('dealers')
        .select('*')
        .eq('status', 'approved')
        .or('name.ilike.$pattern,city.ilike.$pattern')
        .order('name')
        .limit(_resultLimit);

    final dealers = rows
        .map<DealershipModel>((raw) => DealershipModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList();

    final counts = await Future.wait(dealers.map((d) => _activeListingsCount(d.id)));
    return [
      for (var i = 0; i < dealers.length; i++)
        DealerSearchResult(dealer: dealers[i], activeListingsCount: counts[i]),
    ];
  }

  Future<int> _activeListingsCount(String dealerId) async {
    final res = await _client
        .from('cars')
        .select()
        .eq('dealer_id', dealerId)
        .eq('status', 'available')
        .count(CountOption.exact);
    return res.count;
  }

  /// Strips characters that are structurally significant in a PostgREST
  /// `.or(...)` filter string (`,`, `(`, `)`) so typed input can't break out
  /// of the intended ilike conditions, and collapses whitespace.
  String _sanitize(String input) {
    return input
        .replaceAll(RegExp('[,()]'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
