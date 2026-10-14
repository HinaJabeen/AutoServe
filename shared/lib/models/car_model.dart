// shared/lib/models/car_model.dart
// Promoted from apps/dashboard/lib/features/inventory/models/car_model.dart
// so apps/customer (the "Tinder for Cars" swipe deck) can read the same
// `cars` rows the dashboard's inventory manager writes — see
// docs/architecture.md §8.2.
//
// fromJson uses safe null-coercing casts throughout: hard casts like
// `as String` are replaced with `.toString()`/`?.toString()` so a null/int
// field from Supabase can never cause a white-screen crash.

class CarModel {
  const CarModel({
    required this.id,
    required this.dealerId,
    required this.make,
    required this.model,
    required this.year,
    required this.price,
    required this.status,
    this.specs = const {},
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.mileage,
    this.color,
    this.transmission,
    this.fuelType,
    this.condition,
    this.purchasePrice,
    this.retailPrice,
    this.isPublic = true,
    this.features = const [],
    this.reconditioningNotes,
    this.description,
    this.photoUrls = const [],
  });

  final String id;
  final String dealerId;
  final String make;
  final String model;
  final int year;
  final double price;
  final String status;
  final Map<String, dynamic> specs;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  final int? mileage;
  final String? color;
  final String? transmission;
  final String? fuelType;
  final String? condition;

  final double? purchasePrice;
  final double? retailPrice;
  final bool isPublic;
  final List<String> features;
  final String? reconditioningNotes;

  /// Public listing text shown to customers (unlike [reconditioningNotes]).
  final String? description;

  /// Not a DB column — populated separately from `car_photos` join.
  final List<String> photoUrls;

  String get displayTitle => '$year $make $model';

  String get formattedPrice {
    final whole = price.toStringAsFixed(0);
    return 'PKR ${whole.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  int get daysOnLot => DateTime.now().difference(createdAt).inDays;

  double? get profitMargin {
    if (purchasePrice == null) return null;
    return (retailPrice ?? price) - purchasePrice!;
  }

  factory CarModel.fromJson(Map<String, dynamic> json) {
    // ── Safe scalar helpers ───────────────────────────────────────────────────
    // Using these instead of bare `as String` so a DB column that comes back
    // as null (or an unexpected int/bool) never crashes the parse.

    String str(String key, {String fallback = ''}) {
      final v = json[key];
      if (v == null) return fallback;
      return v.toString();
    }

    String? strOrNull(String key) {
      final v = json[key];
      if (v == null) return null;
      return v.toString();
    }

    int intVal(String key, {int fallback = 0}) {
      final v = json[key];
      if (v == null) return fallback;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? fallback;
    }

    double dbl(String key, {double fallback = 0}) {
      final v = json[key];
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    double? dblOrNull(String key) {
      final v = json[key];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? intOrNull(String key) {
      final v = json[key];
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    // ── Parse timestamps safely ───────────────────────────────────────────────
    DateTime parseTs(String key) {
      final v = json[key];
      if (v == null) return DateTime.now();
      try { return DateTime.parse(v.toString()); } catch (_) { return DateTime.now(); }
    }

    // ── specs jsonb ───────────────────────────────────────────────────────────
    final rawSpecs = json['specs'];
    final Map<String, dynamic> specs = (rawSpecs is Map<String, dynamic>)
        ? rawSpecs
        : const {};

    // ── features text[] ──────────────────────────────────────────────────────
    final rawFeatures = json['features'];
    final List<String> features = rawFeatures is List
        ? rawFeatures.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
        : const [];

    // ── photo_urls (not in DB — injected by InventoryService) ─────────────────
    final rawPhotos = json['photo_urls'];
    final List<String> photoUrls = rawPhotos is List
        ? rawPhotos.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
        : const [];

    return CarModel(
      id:                 str('id'),
      dealerId:           str('dealer_id'),
      make:               str('make'),
      model:              str('model'),
      year:               intVal('year'),
      price:              dbl('price'),
      status:             str('status', fallback: 'available'),
      specs:              specs,
      createdBy:          strOrNull('created_by'),
      createdAt:          parseTs('created_at'),
      updatedAt:          parseTs('updated_at'),
      mileage:            intOrNull('mileage'),
      color:              strOrNull('color'),
      transmission:       strOrNull('transmission'),
      fuelType:           strOrNull('fuel_type'),
      condition:          strOrNull('condition'),
      purchasePrice:      dblOrNull('purchase_price'),
      retailPrice:        dblOrNull('retail_price'),
      isPublic:           (json['is_public'] as bool?) ?? true,
      features:           features,
      reconditioningNotes: strOrNull('reconditioning_notes'),
      description:        strOrNull('description'),
      photoUrls:          photoUrls,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'make':                 make,
      'model':                model,
      'year':                 year,
      'price':                price,
      'status':               status,
      'mileage':              mileage,
      'color':                color,
      'transmission':         transmission,
      'fuel_type':            fuelType,
      'condition':            condition,
      'purchase_price':       purchasePrice,
      'retail_price':         retailPrice,
      'is_public':            isPublic,
      'features':             features,
      'reconditioning_notes': reconditioningNotes,
      'description':          description,
    }..removeWhere((_, v) => v == null);
  }

  CarModel copyWith({
    String? make, String? model, int? year, double? price, String? status,
    int? mileage, String? color, String? transmission, String? fuelType,
    String? condition, double? purchasePrice, double? retailPrice,
    bool? isPublic, List<String>? features, String? reconditioningNotes,
    String? description,
    List<String>? photoUrls,
  }) {
    return CarModel(
      id: id, dealerId: dealerId, specs: specs,
      createdBy: createdBy, createdAt: createdAt, updatedAt: updatedAt,
      make:               make               ?? this.make,
      model:              model              ?? this.model,
      year:               year               ?? this.year,
      price:              price              ?? this.price,
      status:             status             ?? this.status,
      mileage:            mileage            ?? this.mileage,
      color:              color              ?? this.color,
      transmission:       transmission       ?? this.transmission,
      fuelType:           fuelType           ?? this.fuelType,
      condition:          condition          ?? this.condition,
      purchasePrice:      purchasePrice      ?? this.purchasePrice,
      retailPrice:        retailPrice        ?? this.retailPrice,
      isPublic:           isPublic           ?? this.isPublic,
      features:           features           ?? this.features,
      reconditioningNotes: reconditioningNotes ?? this.reconditioningNotes,
      description:        description        ?? this.description,
      photoUrls:          photoUrls          ?? this.photoUrls,
    );
  }
}

class CarAuditLog {
  const CarAuditLog({
    required this.id,
    required this.carId,
    required this.action,
    this.oldValue,
    this.newValue,
    required this.createdAt,
  });

  final String id;
  final String carId;
  final String action;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final DateTime createdAt;

  factory CarAuditLog.fromJson(Map<String, dynamic> json) {
    return CarAuditLog(
      id:        json['id']?.toString() ?? '',
      carId:     json['car_id']?.toString() ?? '',
      action:    json['action']?.toString() ?? '',
      oldValue:  json['old_value'] as Map<String, dynamic>?,
      newValue:  json['new_value'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
