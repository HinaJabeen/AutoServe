// lib/features/search/models/search_result.dart

import 'package:shared/shared.dart';

/// A `cars` row matched by the search, with the dealer name pulled out of
/// the `dealers(name)` embed (the detail screen fetches the full dealer
/// separately — a search result only needs the name to render).
class VehicleSearchResult {
  const VehicleSearchResult({required this.car, required this.dealerName});
  final CarModel car;
  final String dealerName;
}

/// A `dealers` row matched by the search, plus how many `available` cars it
/// currently has — not a DB column, filled in by a second count query.
class DealerSearchResult {
  const DealerSearchResult({required this.dealer, required this.activeListingsCount});
  final DealershipModel dealer;
  final int activeListingsCount;
}

class SearchResults {
  const SearchResults({this.vehicles = const [], this.dealers = const []});
  static const empty = SearchResults();

  final List<VehicleSearchResult> vehicles;
  final List<DealerSearchResult> dealers;

  bool get isEmpty => vehicles.isEmpty && dealers.isEmpty;
}
