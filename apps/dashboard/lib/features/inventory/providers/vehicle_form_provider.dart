// lib/features/inventory/providers/vehicle_form_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:shared/shared.dart';
import 'package:dashboard/features/inventory/providers/inventory_providers.dart';
import 'package:dashboard/features/inventory/services/vin_decoder_service.dart';

class VehicleFormState {
  const VehicleFormState({
    this.isSubmitting = false,
    this.isDecodingVin = false,
    this.isUploadingPhotos = false,
    this.errorMessage,
    this.decodedVin,
  });

  final bool isSubmitting;
  final bool isDecodingVin;
  final bool isUploadingPhotos;
  final String? errorMessage;
  final DecodedVin? decodedVin;

  VehicleFormState copyWith({
    bool? isSubmitting,
    bool? isDecodingVin,
    bool? isUploadingPhotos,
    String? errorMessage,
    DecodedVin? decodedVin,
  }) {
    return VehicleFormState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isDecodingVin: isDecodingVin ?? this.isDecodingVin,
      isUploadingPhotos: isUploadingPhotos ?? this.isUploadingPhotos,
      errorMessage: errorMessage,
      decodedVin: decodedVin ?? this.decodedVin,
    );
  }
}

class VehicleFormNotifier extends Notifier<VehicleFormState> {
  final _vinService = VinDecoderService();

  @override
  VehicleFormState build() => const VehicleFormState();

  void clearError() => state = state.copyWith(errorMessage: null);

  bool isValidVin(String vin) => _vinService.isValidVin(vin);

  Future<DecodedVin?> decodeVin(String vin) async {
    state = state.copyWith(isDecodingVin: true, errorMessage: null);
    try {
      final result = await _vinService.decode(vin);
      state = state.copyWith(isDecodingVin: false, decodedVin: result);
      return result;
    } on VinDecoderException catch (e) {
      state = state.copyWith(isDecodingVin: false, errorMessage: e.message);
      return null;
    }
  }

  Future<CarModel?> createCar(CarModel car) async {
    final service = ref.read(inventoryServiceProvider);
    if (service == null) {
      state = state.copyWith(errorMessage: 'No active dealership session.');
      return null;
    }
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final created = await service.createCar(car);
      state = state.copyWith(isSubmitting: false);
      ref.read(inventoryListProvider.notifier).refresh();
      return created;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<CarModel?> updateCar(String carId, CarModel car, {Set<String> clear = const {}}) async {
    final service = ref.read(inventoryServiceProvider);
    if (service == null) {
      state = state.copyWith(errorMessage: 'No active dealership session.');
      return null;
    }
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final updated = await service.updateCar(carId, car, clear: clear);
      state = state.copyWith(isSubmitting: false);
      ref.read(inventoryListProvider.notifier).patchCar(updated);
      return updated;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return null;
    }
  }

  /// Returns null on success, or a message describing what failed. Always
  /// refreshes the inventory list afterwards: createCar/updateCar refresh it
  /// before photos exist, so without this a new car's card shows no photo.
  Future<String?> uploadPhotos(String carId, List<XFile> files) async {
    final storage = ref.read(vehicleStorageServiceProvider);
    if (storage == null) return 'No active dealership session — photos were not uploaded.';
    if (files.isEmpty) return null;
    state = state.copyWith(isUploadingPhotos: true, errorMessage: null);
    String? error;
    try {
      await storage.uploadAll(carId: carId, files: files);
    } catch (e) {
      error = e.toString();
    }
    state = state.copyWith(isUploadingPhotos: false, errorMessage: error);
    ref.read(inventoryListProvider.notifier).refresh();
    return error;
  }
}

final vehicleFormProvider = NotifierProvider<VehicleFormNotifier, VehicleFormState>(
  VehicleFormNotifier.new,
);