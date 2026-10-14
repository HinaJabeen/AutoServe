// lib/features/inventory/providers/bulk_actions_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dashboard/features/inventory/providers/inventory_providers.dart';

class BulkSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String carId) {
    final next = {...state};
    if (!next.remove(carId)) next.add(carId);
    state = next;
  }

  void selectAll(Iterable<String> ids) => state = {...ids};

  void clear() => state = {};

  bool isSelected(String carId) => state.contains(carId);
}

final bulkSelectionProvider = NotifierProvider<BulkSelectionNotifier, Set<String>>(
  BulkSelectionNotifier.new,
);

class BulkActionState {
  const BulkActionState({this.isProcessing = false, this.errorMessage});
  final bool isProcessing;
  final String? errorMessage;
}

class BulkActionNotifier extends Notifier<BulkActionState> {
  @override
  BulkActionState build() => const BulkActionState();

  Future<bool> updateStatus(String status) async {
    final service = ref.read(inventoryServiceProvider);
    final selected = ref.read(bulkSelectionProvider);
    if (service == null || selected.isEmpty) return false;

    state = const BulkActionState(isProcessing: true);
    try {
      await service.bulkUpdateStatus(selected, status);
      ref.read(inventoryListProvider.notifier).refresh();
      ref.read(bulkSelectionProvider.notifier).clear();
      state = const BulkActionState();
      return true;
    } catch (e) {
      state = BulkActionState(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteSelected() async {
    final service = ref.read(inventoryServiceProvider);
    final selected = ref.read(bulkSelectionProvider);
    if (service == null || selected.isEmpty) return false;

    state = const BulkActionState(isProcessing: true);
    try {
      final deleted = await service.bulkDelete(selected);
      ref.read(inventoryListProvider.notifier).removeCars(deleted);
      ref.read(bulkSelectionProvider.notifier).clear();
      if (deleted.length < selected.length) {
        state = BulkActionState(
            errorMessage:
                '${selected.length - deleted.length} vehicle(s) could not be deleted.');
        return false;
      }
      state = const BulkActionState();
      return true;
    } catch (e) {
      state = BulkActionState(errorMessage: e.toString());
      return false;
    }
  }

  void clearError() => state = const BulkActionState();
}

final bulkActionProvider = NotifierProvider<BulkActionNotifier, BulkActionState>(
  BulkActionNotifier.new,
);