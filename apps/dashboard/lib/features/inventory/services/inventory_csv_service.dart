// lib/features/inventory/services/inventory_csv_service.dart

import 'package:csv/csv.dart';
import 'package:dashboard/features/inventory/models/car_model.dart';

class CsvRowError {
  const CsvRowError(this.rowNumber, this.message);
  final int rowNumber;
  final String message;
  @override
  String toString() => 'Row $rowNumber: $message';
}

class CsvImportResult {
  const CsvImportResult({required this.validCars, required this.errors});
  final List<CarModel> validCars;
  final List<CsvRowError> errors;
  bool get hasErrors => errors.isNotEmpty;
}

class InventoryCsvService {
  static const _headers = [
    'make', 'model', 'year', 'price', 'status', 'mileage', 'color',
    'transmission', 'fuel_type', 'condition', 'purchase_price', 'retail_price',
  ];

  static const _validStatuses = {'available', 'reserved', 'sold'};
  static const _validTransmissions = {'manual', 'automatic'};
  static const _validFuelTypes = {'petrol', 'diesel', 'hybrid', 'electric', 'cng'};
  static const _validConditions = {'excellent', 'good', 'fair'};

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

    final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    final colIndex = {for (var i = 0; i < header.length; i++) header[i]: i};

    final missing = _headers.where((h) => h != 'purchase_price' && h != 'retail_price' && !colIndex.containsKey(h));
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
        final status = cell('status') ?? 'available';

        if (make == null) throw 'make is required';
        if (model == null) throw 'model is required';
        final year = int.tryParse(yearStr ?? '');
        if (year == null || year < 1980 || year > 2030) throw 'year must be between 1980-2030';
        final price = double.tryParse(priceStr ?? '');
        if (price == null || price <= 0) throw 'price must be a positive number';
        if (!_validStatuses.contains(status)) throw 'status must be one of $_validStatuses';

        final transmission = cell('transmission');
        if (transmission != null && !_validTransmissions.contains(transmission)) {
          throw 'transmission must be one of $_validTransmissions';
        }
        final fuelType = cell('fuel_type');
        if (fuelType != null && !_validFuelTypes.contains(fuelType)) {
          throw 'fuel_type must be one of $_validFuelTypes';
        }
        final condition = cell('condition');
        if (condition != null && !_validConditions.contains(condition)) {
          throw 'condition must be one of $_validConditions';
        }
        final mileageStr = cell('mileage');
        final mileage = mileageStr != null ? int.tryParse(mileageStr) : null;
        if (mileageStr != null && mileage == null) throw 'mileage must be a whole number';
        if (mileage != null && mileage < 0) throw 'mileage cannot be negative';

        final now = DateTime.now();
        cars.add(CarModel(
          id: '', // assigned by DB on insert
          dealerId: '', // injected by service layer at insert time
          make: make,
          model: model,
          year: year,
          price: price,
          status: status,
          createdAt: now,
          updatedAt: now,
          mileage: mileage,
          color: cell('color'),
          transmission: transmission,
          fuelType: fuelType,
          condition: condition,
          purchasePrice: double.tryParse(cell('purchase_price') ?? ''),
          retailPrice: double.tryParse(cell('retail_price') ?? ''),
        ));
      } catch (e) {
        errors.add(CsvRowError(rowNum, e.toString()));
      }
    }

    return CsvImportResult(validCars: cars, errors: errors);
  }
}