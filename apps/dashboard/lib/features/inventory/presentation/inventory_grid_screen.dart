// lib/features/inventory/presentation/inventory_grid_screen.dart
// Full Module B grid: checkboxes, days-on-lot, profit margin, QR/sticker
// button, crash-safe delete, empty-state guard, infinite scroll.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'package:dashboard/features/inventory/models/car_model.dart';
import 'package:dashboard/features/inventory/providers/inventory_providers.dart';
import 'package:dashboard/features/inventory/providers/bulk_actions_provider.dart';
import 'package:dashboard/features/inventory/presentation/vehicle_form_v2.dart';
import 'package:dashboard/features/inventory/presentation/widgets/confirm_delete_dialog.dart';
import 'package:dashboard/features/inventory/presentation/widgets/csv_import_dialog.dart';
import 'package:dashboard/features/inventory/services/window_sticker_pdf_service.dart';
import 'package:dashboard/features/providers/overview_provider.dart';

const _statusFilters = [null, 'available', 'reserved', 'sold'];

class InventoryGridScreen extends ConsumerStatefulWidget {
  const InventoryGridScreen({super.key});

  @override
  ConsumerState<InventoryGridScreen> createState() => _InventoryGridScreenState();
}

class _InventoryGridScreenState extends ConsumerState<InventoryGridScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(inventoryListProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(inventoryListProvider);
    final selection = ref.watch(bulkSelectionProvider);

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(),
          const SizedBox(height: AppDimensions.paddingL),
          const _FilterBar(),
          if (selection.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.paddingM),
            _BulkActionBar(selectedCount: selection.length),
          ],
          const SizedBox(height: AppDimensions.paddingL),
          Expanded(
            child: asyncState.when(
              data: (pageState) {
                if (pageState.isEmpty) return const _EmptyState();
                return _InventoryGridBody(
                  scrollController: _scrollController,
                  cars: pageState.cars,
                  isLoadingMore: pageState.isLoadingMore,
                );
              },
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.pastelPink)),
              error: (err, _) => _ErrorState(
                message: err.toString(),
                onRetry: () => ref.read(inventoryListProvider.notifier).refresh(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: Text('Inventory',
              style: AppTextStyles.heading1.copyWith(color: Colors.white, fontSize: 26)),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              showDialog(context: context, builder: (_) => const CsvImportDialog()),
          icon: const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white54),
          label: Text('Import CSV',
              style: AppTextStyles.body.copyWith(color: Colors.white54, fontSize: 12.5)),
          style:
              OutlinedButton.styleFrom(side: BorderSide(color: AppColors.navyBorder)),
        ),
        const SizedBox(width: AppDimensions.paddingS),
        ElevatedButton.icon(
          onPressed: () =>
              showDialog(context: context, builder: (_) => const VehicleFormV2()),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Vehicle'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.pastelPink,
            foregroundColor: AppColors.navyBackground,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bar
// ---------------------------------------------------------------------------

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(inventoryStatusFilterProvider);
    final sort = ref.watch(inventorySortProvider);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            onChanged: (v) => ref.read(inventorySearchProvider.notifier).state = v,
            style: AppTextStyles.body.copyWith(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by make or model…',
              hintStyle:
                  AppTextStyles.body.copyWith(color: Colors.white24, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Colors.white30, size: 18),
              filled: true,
              fillColor: AppColors.navySurface.withOpacity(0.5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                  borderSide: BorderSide(color: AppColors.navyBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                  borderSide: BorderSide(color: AppColors.navyBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                  borderSide: const BorderSide(color: AppColors.pastelPink)),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.paddingM),
        ..._statusFilters.map((status) {
          final isActive = activeFilter == status;
          final label = status == null ? 'All' : status[0].toUpperCase() + status.substring(1);
          return Padding(
            padding: const EdgeInsets.only(right: AppDimensions.paddingS),
            child: ChoiceChip(
              label: Text(label),
              selected: isActive,
              onSelected: (_) =>
                  ref.read(inventoryStatusFilterProvider.notifier).state = status,
              selectedColor: AppColors.pastelPink.withOpacity(0.2),
              backgroundColor: AppColors.navySurface.withOpacity(0.5),
              side: BorderSide(
                  color: isActive
                      ? AppColors.pastelPink.withOpacity(0.5)
                      : AppColors.navyBorder),
              labelStyle: AppTextStyles.caption.copyWith(
                  color: isActive ? AppColors.pastelPink : Colors.white54,
                  fontSize: 12),
            ),
          );
        }),
        const Spacer(),
        DropdownButton<InventorySort>(
          value: sort,
          dropdownColor: AppColors.navySurface,
          underline: const SizedBox.shrink(),
          style: AppTextStyles.caption.copyWith(color: Colors.white70),
          items: const [
            DropdownMenuItem(
                value: InventorySort(InventorySortField.createdAt, false),
                child: Text('Newest first')),
            DropdownMenuItem(
                value: InventorySort(InventorySortField.createdAt, true),
                child: Text('Oldest first')),
            DropdownMenuItem(
                value: InventorySort(InventorySortField.price, true),
                child: Text('Price: low to high')),
            DropdownMenuItem(
                value: InventorySort(InventorySortField.price, false),
                child: Text('Price: high to low')),
          ],
          onChanged: (v) {
            if (v != null) ref.read(inventorySortProvider.notifier).state = v;
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bulk action bar
// ---------------------------------------------------------------------------

class _BulkActionBar extends ConsumerWidget {
  const _BulkActionBar({required this.selectedCount});
  final int selectedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bulkState = ref.watch(bulkActionProvider);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pastelPink.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        border: Border.all(color: AppColors.pastelPink.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text('$selectedCount selected',
              style: AppTextStyles.body.copyWith(color: Colors.white70, fontSize: 12.5)),
          const Spacer(),
          TextButton(
            onPressed: bulkState.isProcessing
                ? null
                : () => ref.read(bulkActionProvider.notifier).updateStatus('sold'),
            child: const Text('Mark Sold'),
          ),
          TextButton(
            onPressed: bulkState.isProcessing
                ? null
                : () =>
                    ref.read(bulkActionProvider.notifier).updateStatus('available'),
            child: const Text('Mark Available'),
          ),
          TextButton(
            onPressed: bulkState.isProcessing
                ? null
                : () async {
                    final confirmed = await confirmDelete(
                      context,
                      title: 'Delete $selectedCount vehicles?',
                      message:
                          'This permanently removes all selected vehicles. Cannot be undone.',
                    );
                    if (confirmed && context.mounted) {
                      await ref.read(bulkActionProvider.notifier).deleteSelected();
                    }
                  },
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white38),
            onPressed: () => ref.read(bulkSelectionProvider.notifier).clear(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid body
// ---------------------------------------------------------------------------

class _InventoryGridBody extends ConsumerWidget {
  const _InventoryGridBody({
    required this.scrollController,
    required this.cars,
    required this.isLoadingMore,
  });

  final ScrollController scrollController;
  final List<CarModel> cars;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      controller: scrollController,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: cars.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= cars.length) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.pastelPink, strokeWidth: 2));
        }
        return _VehicleCard(car: cars[i]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Vehicle card
// ---------------------------------------------------------------------------

class _VehicleCard extends ConsumerWidget {
  const _VehicleCard({required this.car});
  final CarModel car;

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return AppColors.statusAvailable;
      case 'reserved':
        return AppColors.statusReserved;
      case 'sold':
        return AppColors.statusSold;
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(bulkSelectionProvider).contains(car.id);
    final margin = car.profitMargin;
    final dealershipAsync = ref.watch(currentDealershipProvider);
    final dealerName = dealershipAsync.value?.name ?? 'AutoServe';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navySurface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: isSelected
              ? AppColors.pastelPink.withOpacity(0.6)
              : AppColors.navyBorder.withOpacity(0.6),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Photo + overlays ─────────────────────────────────────
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppDimensions.radiusL)),
                  child: car.photoUrls.isNotEmpty
                      ? Image.network(car.photoUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder())
                      : _placeholder(),
                ),
              ),
              // Checkbox
              Positioned(
                top: 6,
                left: 6,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () =>
                        ref.read(bulkSelectionProvider.notifier).toggle(car.id),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        isSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 18,
                        color: isSelected ? AppColors.pastelPink : Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
              // Days on lot badge
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusFull)),
                  child: Text(
                    '${car.daysOnLot}d on lot',
                    style: AppTextStyles.caption
                        .copyWith(color: Colors.white70, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),

          // ── Card body ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  car.displayTitle,
                  style: AppTextStyles.bodyBold
                      .copyWith(color: Colors.white, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  car.formattedPrice,
                  style: AppTextStyles.body
                      .copyWith(color: Colors.white70, fontSize: 12.5),
                ),
                if (margin != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Margin: PKR ${margin.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d)(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}',
                    style: AppTextStyles.caption.copyWith(
                      color: margin >= 0
                          ? AppColors.statusAvailable
                          : AppColors.error,
                      fontSize: 10.5,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(car.status).withOpacity(0.14),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusFull),
                        border: Border.all(
                            color: _statusColor(car.status).withOpacity(0.4)),
                      ),
                      child: Text(
                        car.status[0].toUpperCase() + car.status.substring(1),
                        style: AppTextStyles.caption.copyWith(
                            color: _statusColor(car.status),
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    // Edit
                    _IconBtn(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit',
                      onPressed: () => showDialog(
                          context: context,
                          builder: (_) => VehicleFormV2(carToEdit: car)),
                    ),
                    // QR / Window Sticker
                    _IconBtn(
                      icon: Icons.qr_code_2_rounded,
                      tooltip: 'Window Sticker / QR',
                      color: AppColors.pastelPink.withOpacity(0.8),
                      onPressed: () async {
                        try {
                          await const WindowStickerPdfService().printSticker(
                            car: car,
                            dealershipName: dealerName,
                            carDetailUrl:
                                'https://autoserve.app/cars/${car.id}',
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Could not generate sticker: $e')));
                          }
                        }
                      },
                    ),
                    // Delete
                    _IconBtn(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Delete',
                      onPressed: () => _handleDelete(context, ref),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete ${car.displayTitle}?',
      message:
          'Permanently removes this vehicle and all its photos. Cannot be undone.',
    );
    if (!confirmed) return;

    final service = ref.read(inventoryServiceProvider);
    if (service == null) return;

    final ok = await service.deleteCar(car.id);

    if (ok) {
      // Remove from UI list — guarded against empty/out-of-bounds in notifier.
      ref.read(inventoryListProvider.notifier).removeCars({car.id});
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed. Please try again.')),
      );
    }
  }

  Widget _placeholder() => Container(
        color: AppColors.navyBorder.withOpacity(0.4),
        child: const Center(
            child: Icon(Icons.directions_car_rounded,
                color: Colors.white24, size: 32)),
      );
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 17, color: color ?? Colors.white38),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state — rendered when cars list is empty after filters/delete
// ---------------------------------------------------------------------------

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_car_outlined,
              color: Colors.white24, size: 40),
          const SizedBox(height: AppDimensions.paddingM),
          Text('No vehicles found',
              style: AppTextStyles.bodyBold.copyWith(color: Colors.white54)),
          const SizedBox(height: 4),
          Text(
            'Add your first vehicle or adjust the search filters.',
            style: AppTextStyles.caption.copyWith(color: Colors.white30),
          ),
          const SizedBox(height: AppDimensions.paddingL),
          ElevatedButton.icon(
            onPressed: () => showDialog(
                context: context, builder: (_) => const VehicleFormV2()),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Vehicle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pastelPink,
              foregroundColor: AppColors.navyBackground,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 28),
          const SizedBox(height: AppDimensions.paddingS),
          Text('Could not load inventory',
              style: AppTextStyles.bodyBold.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(message,
              style: AppTextStyles.caption.copyWith(color: Colors.white38),
              textAlign: TextAlign.center),
          const SizedBox(height: AppDimensions.paddingM),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded,
                size: 16, color: AppColors.pastelPink),
            label: Text('Retry',
                style: AppTextStyles.body.copyWith(color: AppColors.pastelPink)),
          ),
        ],
      ),
    );
  }
}