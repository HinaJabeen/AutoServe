// lib/features/inventory/services/vin_decoder_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class DecodedVin {
  const DecodedVin({
    this.make,
    this.model,
    this.year,
    this.bodyClass,
    this.fuelType,
    this.transmission,
  });

  final String? make;
  final String? model;
  final int? year;
  final String? bodyClass;
  final String? fuelType;
  final String? transmission;

  bool get hasUsableData => make != null || model != null || year != null;
}

class VinDecoderException implements Exception {
  VinDecoderException(this.message);
  final String message;
  @override
  String toString() => message;
}

class VinDecoderService {
  static const _baseUrl = 'https://vpic.nhtsa.dot.gov/api/vehicles/decodevinvalues';

  bool isValidVin(String vin) {
    final v = vin.trim().toUpperCase();
    if (v.length != 17) return false;
    // VINs never contain I, O, or Q.
    return RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(v);
  }

  Future<DecodedVin> decode(String vin) async {
    final v = vin.trim().toUpperCase();
    if (!isValidVin(v)) {
      throw VinDecoderException('VIN must be exactly 17 characters (no I, O, or Q).');
    }

    late final http.Response response;
    try {
      response = await http.get(Uri.parse('$_baseUrl/$v?format=json')).timeout(const Duration(seconds: 10));
    } catch (_) {
      throw VinDecoderException('Could not reach the VIN decoder service. Check your connection.');
    }

    if (response.statusCode != 200) {
      throw VinDecoderException('VIN lookup failed (${response.statusCode}).');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['Results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw VinDecoderException('No data found for that VIN.');
    }

    final r = results.first as Map<String, dynamic>;
    String? field(String key) {
      final val = r[key];
      if (val == null) return null;
      final s = val.toString().trim();
      return s.isEmpty ? null : s;
    }

    final yearStr = field('ModelYear');

    return DecodedVin(
      make: field('Make'),
      model: field('Model'),
      year: yearStr != null ? int.tryParse(yearStr) : null,
      bodyClass: field('BodyClass'),
      fuelType: field('FuelTypePrimary'),
      transmission: field('TransmissionStyle'),
    );
  }
}