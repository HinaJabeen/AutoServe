// lib/features/inventory/presentation/inventory_grid_screen.dart
// Full Module B grid: checkboxes, days-on-lot, profit margin, QR/sticker
// button, crash-safe delete, empty-state guard, infinite scroll.
//
// Every color comes from `context.palette` so the screen follows the
// light/dark toggle — no hard-coded navy/white values.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

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
          const _Header(),
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
              loading: () => const Center(child: CircularProgressIndicator()),
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: Text('Inventory',
              style: AppTextStyles.heading1.copyWith(color: p.textPrimary, fontSize: 26)),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              showDialog(context: context, builder: (_) => const CsvImportDialog()),
          icon: Icon(Icons.upload_file_rounded, size: 16, color: p.textSecondary),
          label: Text('Import CSV',
              style: AppTextStyles.body.copyWith(color: p.textSecondary, fontSize: 12.5)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: p.border)),
        ),
        const SizedBox(width: AppDimensions.paddingS),
        ElevatedButton.icon(
          onPressed: () =>
              showDialog(context: context, builder: (_) => const VehicleFormV2()),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Vehicle'),
          style: ElevatedButton.styleFrom(
            backgroundColor: p.accent,
            foregroundColor: p.onAccent,
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
    final p = context.palette;

    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        borderSide: BorderSide(color: color, width: width));

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            onChanged: (v) => ref.read(inventorySearchProvider.notifier).state = v,
            style: AppTextStyles.body.copyWith(color: p.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by make or model…',
              hintStyle: AppTextStyles.body.copyWith(color: p.textMuted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: p.textTertiary, size: 18),
              filled: true,
              fillColor: p.card,
              border: border(p.border),
              enabledBorder: border(p.border),
              focusedBorder: border(p.accent, 1.5),
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
              showCheckmark: false,
              selectedColor: p.accent,
              backgroundColor: p.card,
              side: BorderSide(color: isActive ? p.accent : p.border),
              labelStyle: AppTextStyles.caption.copyWith(
                  color: isActive ? p.onAccent : p.textSecondary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12),
            ),
          );
        }),
        const Spacer(),
        DropdownButton<InventorySort>(
          value: sort,
          dropdownColor: p.card,
          underline: const SizedBox.shrink(),
          iconEnabledColor: p.textSecondary,
          style: AppTextStyles.caption.copyWith(color: p.textSecondary),
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
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM, vertical: 10),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        border: Border.all(color: p.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text('$selectedCount selected',
              style: AppTextStyles.body.copyWith(color: p.textPrimary, fontSize: 12.5)),
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
            child: Text('Delete', style: TextStyle(color: p.error)),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: p.textTertiary),
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
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
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

  Color _statusColor(AppPalette p, String status) {
    switch (status) {
      case 'available':
        return p.statusAvailable;
      case 'reserved':
        return p.statusReserved;
      case 'sold':
        return p.statusSold;
      default:
        return p.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(bulkSelectionProvider).contains(car.id);
    final margin = car.profitMargin;
    final dealershipAsync = ref.watch(currentDealershipProvider);
    final dealerName = dealershipAsync.value?.name ?? 'AutoServe';
    final p = context.palette;
    final statusColor = _statusColor(p, car.status);

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: isSelected ? p.accent : p.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: p.shadowColor.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Photo + overlays ─────────────────────────────────────
          // The checkbox and days-on-lot badge sit on the photo, so they keep
          // fixed dark-scrim colors in both themes.
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppDimensions.radiusL)),
                  child: CarNetworkImage(url: car.photoUrls.firstOrNull),
                ),
              ),
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
                        color: isSelected ? p.accent : Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
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
                      .copyWith(color: p.textPrimary, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  car.formattedPrice,
                  style: AppTextStyles.body
                      .copyWith(color: p.textSecondary, fontSize: 12.5),
                ),
                if (margin != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Margin: PKR ${margin.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d)(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}',
                    style: AppTextStyles.caption.copyWith(
                      color: margin >= 0 ? p.statusAvailable : p.error,
                      fontSize: 10.5,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusFull),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        car.status[0].toUpperCase() + car.status.substring(1),
                        style: AppTextStyles.caption.copyWith(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    _IconBtn(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit',
                      onPressed: () => showDialog(
                          context: context,
                          builder: (_) => VehicleFormV2(carToEdit: car)),
                    ),
                    _IconBtn(
                      icon: Icons.qr_code_2_rounded,
                      tooltip: 'Window Sticker / QR',
                      color: p.accent,
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
    // Grid may have rebuilt (search/sort/refresh) while the dialog was open —
    // using `ref` on a disposed element throws, so re-check before using it.
    if (!context.mounted) return;

    try {
      await ref.read(inventoryListProvider.notifier).deleteCar(car.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle deleted')),
      );
    } catch (e) {
      // Never let a failed delete (RLS block, network error, etc.) bubble up
      // as an unhandled exception — surface it instead of crashing the app.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: context.palette.error,
        ),
      );
    }
  }
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
      icon: Icon(icon, size: 17, color: color ?? context.palette.textTertiary),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_outlined, color: p.textTertiary, size: 40),
          const SizedBox(height: AppDimensions.paddingM),
          Text('No vehicles found',
              style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
          const SizedBox(height: 4),
          Text(
            'Add your first vehicle or adjust the search filters.',
            style: AppTextStyles.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: AppDimensions.paddingL),
          ElevatedButton.icon(
            onPressed: () => showDialog(
                context: context, builder: (_) => const VehicleFormV2()),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Vehicle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
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
    final p = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: p.error, size: 28),
          const SizedBox(height: AppDimensions.paddingS),
          Text('Could not load inventory',
              style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
          const SizedBox(height: 4),
          Text(message,
              style: AppTextStyles.caption.copyWith(color: p.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: AppDimensions.paddingM),
          TextButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh_rounded, size: 16, color: p.accent),
            label: Text('Retry', style: AppTextStyles.body.copyWith(color: p.accent)),
          ),
        ],
      ),
    );
  }
}
