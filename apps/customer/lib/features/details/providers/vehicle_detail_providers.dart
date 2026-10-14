// lib/features/details/providers/vehicle_detail_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../services/vehicle_detail_service.dart';

final vehicleDetailServiceProvider = Provider<VehicleDetailService>(
  (ref) => VehicleDetailService(SupabaseService.client),
);

final vehicleDetailProvider =
    FutureProvider.family<VehicleDetail, String>((ref, carId) {
  return ref.read(vehicleDetailServiceProvider).fetchDetail(carId);
});
