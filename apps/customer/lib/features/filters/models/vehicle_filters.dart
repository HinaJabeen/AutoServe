// lib/features/filters/models/vehicle_filters.dart
//
// Client-side filter criteria for the swipe deck. `cars` has no `body_type`
// column in the live schema, so body type is matched against the flexible
// `specs` jsonb bucket (`specs['body_type']`) instead of inventing a column
// — it only filters usefully for listings a dealer has actually tagged that
// way, same tradeoff as everywhere else we've leaned on `specs` this module.

import 'package:shared/shared.dart';

class VehicleFilters {
  const VehicleFilters({
    this.make,
    this.model,
    this.minPrice,
    this.maxPrice,
    this.bodyType,
    this.transmission,
    this.fuelType,
    this.dealerId,
    this.dealerName,
  });

  final String? make;
  final String? model;
  final double? minPrice;
  final double? maxPrice;
  final String? bodyType;
  final String? transmission;
  final String? fuelType;

  /// Set when a "Dealerships" search result was tapped — restricts the deck
  /// to that dealer's own listings. [dealerName] is display-only (for the
  /// "Showing this dealer" chip), never used to filter.
  final String? dealerId;
  final String? dealerName;

  /// Each argument is a thunk so a field can be cleared: `copyWith(model: () => null)`.
  /// Omitted fields — including the dealer filter — are kept.
  VehicleFilters copyWith({
    String? Function()? make,
    String? Function()? model,
    double? Function()? minPrice,
    double? Function()? maxPrice,
    String? Function()? bodyType,
    String? Function()? transmission,
    String? Function()? fuelType,
  }) =>
      VehicleFilters(
        make: make != null ? make() : this.make,
        model: model != null ? model() : this.model,
        minPrice: minPrice != null ? minPrice() : this.minPrice,
        maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
        bodyType: bodyType != null ? bodyType() : this.bodyType,
        transmission: transmission != null ? transmission() : this.transmission,
        fuelType: fuelType != null ? fuelType() : this.fuelType,
        dealerId: dealerId,
        dealerName: dealerName,
      );

  bool get isActive =>
      make != null ||
      model != null ||
      minPrice != null ||
      maxPrice != null ||
      bodyType != null ||
      transmission != null ||
      fuelType != null ||
      dealerId != null;

  bool matches(CarModel car) {
    if (make != null && car.make != make) return false;
    if (model != null && car.model != model) return false;
    if (minPrice != null && car.price < minPrice!) return false;
    if (maxPrice != null && car.price > maxPrice!) return false;
    if (transmission != null && car.transmission != transmission) return false;
    if (fuelType != null && car.fuelType != fuelType) return false;
    if (bodyType != null && (car.specs['body_type'] as String?) != bodyType) {
      return false;
    }
    if (dealerId != null && car.dealerId != dealerId) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is VehicleFilters &&
      other.make == make &&
      other.model == model &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.bodyType == bodyType &&
      other.transmission == transmission &&
      other.fuelType == fuelType &&
      other.dealerId == dealerId;

  @override
  int get hashCode => Object.hash(
      make, model, minPrice, maxPrice, bodyType, transmission, fuelType, dealerId);
}
