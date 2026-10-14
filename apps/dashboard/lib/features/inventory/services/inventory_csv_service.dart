// lib/features/inventory/services/inventory_csv_service.dart

import 'package:csv/csv.dart';
import 'package:shared/shared.dart';

class CsvRowError {
  const CsvRowError(this.rowNumber, this.message);
  final int rowNumber;
  final String message;
  @override
  String toString() => 'Row $rowNumber: $message';
}

class CsvImportResult {
  const CsvImportResult({
    required this.validCars,
    required this.errors,
    this.ignoredColumns = const [],
  });
  final List<CarModel> validCars;
  final List<CsvRowError> errors;
  /// Header names that matched no known column — their data is NOT imported.
  final List<String> ignoredColumns;
  bool get hasErrors => errors.isNotEmpty;
}

class InventoryCsvService {
  static const _headers = [
    'make', 'model', 'year', 'price', 'status', 'mileage', 'color',
    'transmission', 'fuel_type', 'condition', 'purchase_price', 'retail_price',
  ];

  // Matches the import dialog's "Required columns" text; every other
  // column is optional and may be left out of the file entirely.
  static const _requiredHeaders = ['make', 'model', 'year', 'price', 'status'];

  static const _knownHeaders = {..._headers, 'body_type'};

  // Common spreadsheet spellings (after normalizeHeader) → our column.
  static const _headerAliases = {
    'brand': 'make', 'manufacturer': 'make',
    'model_year': 'year',
    'asking_price': 'price', 'sale_price': 'price', 'price_pkr': 'price',
    'km': 'mileage', 'kms': 'mileage', 'km_driven': 'mileage', 'mileage_km': 'mileage',
    'odometer': 'mileage',
    'colour': 'color', 'exterior_color': 'color', 'exterior_colour': 'color',
    'gear': 'transmission', 'gearbox': 'transmission',
    'fuel': 'fuel_type', 'fueltype': 'fuel_type',
    'body': 'body_type', 'bodytype': 'body_type', 'body_style': 'body_type',
    'cost_price': 'purchase_price',
  };

  // Accepted spellings (already trimmed + lowercased) → the exact value the
  // LIVE `cars` check constraints allow. Note the live condition constraint
  // is 'excellent'/'good'/'fair' — 20260630062555_initial_schema.sql says
  // 'new'/'used'/'certified', but live rows and VehicleFormV2 both use the
  // former, and inserting the latter fails with a 400.
  static const _statusAliases = {
    'available': 'available',
    'active': 'available',
    'reserved': 'reserved',
    'sold': 'sold',
  };
  static const _transmissionAliases = {
    'manual': 'manual',
    'm/t': 'manual',
    'mt': 'manual',
    'automatic': 'automatic',
    'auto': 'automatic',
    'a/t': 'automatic',
    'at': 'automatic',
  };
  static const _fuelTypeAliases = {
    'petrol': 'petrol',
    'gasoline': 'petrol',
    'diesel': 'diesel',
    'hybrid': 'hybrid',
    'electric': 'electric',
    'ev': 'electric',
    'cng': 'cng',
  };
  static const _conditionAliases = {
    'excellent': 'excellent',
    'good': 'good',
    'fair': 'fair',
    'new': 'excellent',
    'certified': 'excellent',
    'cpo': 'excellent',
    'used': 'good',
  };

  /// `" Fuel Type"`, `"FUEL-TYPE"`, `"﻿make"` (Excel's UTF-8 BOM) →
  /// `fuel_type` / `make`.
  static String normalizeHeader(Object? raw) => raw
      .toString()
      .replaceAll('﻿', '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-]+'), '_');

  /// Maps a cell to its DB enum value via [aliases]; null for an empty cell.
  /// Throws a row error naming the accepted spellings otherwise.
  static String? _enumCell(String field, String? raw, Map<String, String> aliases) {
    if (raw == null) return null;
    final mapped = aliases[raw.trim().toLowerCase()];
    if (mapped == null) {
      throw '$field "$raw" is not recognised — use one of: ${aliases.keys.join(', ')}';
    }
    return mapped;
  }

  /// Accepts thousands separators ("4,850,000").
  static String? _numeric(String? raw) => raw?.replaceAll(RegExp(r'[,\s]'), '');

  String export(List<CarModel> cars) {
    final rows = <List<dynamic>>[_headers];
    for (final c in cars) {
      rows.add([
        c.make, c.model, c.year, c.price, c.status, c.mileage ?? '', c.color ?? '',
        c.transmission ?? '', c.fuelType ?? '', c.condition ?? '',
        c.purchasePrice ?? '', c.retailPrice ?? '',
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }

  /// Parses raw CSV text (must include the header row) into cars,
  /// validating every field against the same DB check constraints
  /// so we never send a row Postgres would reject anyway.
  CsvImportResult import(String csvText) {
    final rows = const CsvToListConverter(eol: '\n').convert(csvText, shouldParseNumbers: false);
    if (rows.isEmpty) return const CsvImportResult(validCars: [], errors: []);

    final rawHeader = rows.first.map(normalizeHeader).toList();
    final header = [for (final h in rawHeader) _headerAliases[h] ?? h];
    final ignored = [
      for (final h in rawHeader)
        if (h.isNotEmpty && !_knownHeaders.contains(_headerAliases[h] ?? h)) h,
    ];
    final colIndex = {for (var i = 0; i < header.length; i++) header[i]: i};

    final missing = _requiredHeaders.where((h) => !colIndex.containsKey(h));
    if (missing.isNotEmpty) {
      return CsvImportResult(validCars: const [], errors: [CsvRowError(0, 'Missing required column(s): ${missing.join(', ')}')]);
    }

    final cars = <CarModel>[];
    final errors = <CsvRowError>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((c) => c.toString().trim().isEmpty)) continue;
      final rowNum = i + 1;

      String? cell(String key) {
        final idx = colIndex[key];
        if (idx == null || idx >= row.length) return null;
        final v = row[idx].toString().trim();
        return v.isEmpty ? null : v;
      }

      try {
        final make = cell('make');
        final model = cell('model');
        final yearStr = cell('year');
        final priceStr = cell('price');
        final status =
            _enumCell('status', cell('status'), _statusAliases) ?? 'available';

        if (make == null) throw 'make is required';
        if (model == null) throw 'model is required';
        final year = int.tryParse(yearStr ?? '');
        if (year == null || year < 1980 || year > 2030) throw 'year must be between 1980-2030';
        final price = double.tryParse(_numeric(priceStr) ?? '');
        if (price == null || price <= 0) throw 'price must be a positive number';

        final transmission =
            _enumCell('transmission', cell('transmission'), _transmissionAliases);
        final fuelType = _enumCell('fuel_type', cell('fuel_type'), _fuelTypeAliases);
        final condition = _enumCell('condition', cell('condition'), _conditionAliases);
        final mileageStr = _numeric(cell('mileage'));
        final mileage = mileageStr != null ? int.tryParse(mileageStr) : null;
        if (mileageStr != null && mileage == null) throw 'mileage must be a whole number';
        if (mileage != null && mileage < 0) throw 'mileage cannot be negative';

        final bodyType = cell('body_type')?.toLowerCase();

        final now = DateTime.now();
        cars.add(CarModel(
          id: '', // assigned by DB on insert
          dealerId: '', // injected by service layer at insert time
          make: make,
          model: model,
          year: year,
          price: price,
          status: status,
          specs: {if (bodyType != null) 'body_type': bodyType},
          createdAt: now,
          updatedAt: now,
          mileage: mileage,
          color: cell('color'),
          transmission: transmission,
          fuelType: fuelType,
          condition: condition,
          purchasePrice: double.tryParse(_numeric(cell('purchase_price')) ?? ''),
          retailPrice: double.tryParse(_numeric(cell('retail_price')) ?? ''),
        ));
      } catch (e) {
        errors.add(CsvRowError(rowNum, e.toString()));
      }
    }

    return CsvImportResult(validCars: cars, errors: errors, ignoredColumns: ignored);
  }
}