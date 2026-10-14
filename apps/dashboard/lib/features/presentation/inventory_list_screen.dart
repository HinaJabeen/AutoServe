// apps/dashboard/lib/features/presentation/inventory_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:dashboard/features/providers/vehicle_provider.dart';
import 'package:dashboard/features/presentation/add_vehicle_form.dart';
import 'package:dashboard/features/presentation/widgets/vehicle_qr_code.dart';

// ---------------------------------------------------------------------------
// Local UI state — search query + status filter (screen-scoped, not global)
// ---------------------------------------------------------------------------

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _statusFilterProvider = StateProvider<String?>((ref) => null); // null = All

const _statusFilters = [null, 'available', 'reserved', 'sold', 'inactive'];

// ---------------------------------------------------------------------------
// Root screen
// ---------------------------------------------------------------------------

class InventoryListScreen extends ConsumerWidget {
  const InventoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(dealerVehiclesStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(),
          const SizedBox(height: AppDimensions.paddingL),
          const _SearchFilterBar(),
          const SizedBox(height: AppDimensions.paddingL),
          Expanded(
            child: vehiclesAsync.when(
              data: (vehicles) => _InventoryTable(vehicles: vehicles),
              loading: () => const _TableSkeleton(),
              error: (err, st) => _ErrorState(
                message: err.toString(),
                onRetry: () => ref.invalidate(dealerVehiclesStreamProvider),
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
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Inventory',
            style: AppTextStyles.heading1.copyWith(color: Theme.of(context).colorScheme.onSurface,),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const AddVehicleForm(),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Vehicle'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ambientBlue,
            foregroundColor: AppColors.navyBackground,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            textStyle: AppTextStyles.button.copyWith(
              color: AppColors.navyBackground,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Search + filter bar
// ---------------------------------------------------------------------------

class _SearchFilterBar extends ConsumerWidget {
  const _SearchFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(_statusFilterProvider);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
            style: AppTextStyles.body.copyWith(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by make or model…',
              hintStyle: AppTextStyles.body.copyWith(color: Colors.white24, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30, size: 18),
              filled: true,
              fillColor: AppColors.navySurface.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                borderSide: BorderSide(color: AppColors.navyBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                borderSide: BorderSide(color: AppColors.navyBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                borderSide: const BorderSide(color: AppColors.ambientBlue),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.paddingM),
        ..._statusFilters.map((status) {
          final isActive = activeFilter == status;
          return Padding(
            padding: const EdgeInsets.only(left: AppDimensions.paddingS),
            child: _FilterChip(
              label: status == null ? 'All' : status[0].toUpperCase() + status.substring(1),
              active: isActive,
              onTap: () => ref.read(_statusFilterProvider.notifier).state = status,
            ),
          );
        }),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.ambientBlue.withValues(alpha: 0.16) : AppColors.navySurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(
              color: active ? AppColors.ambientBlue.withValues(alpha: 0.5) : AppColors.navyBorder,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: active ? AppColors.ambientBlue : Colors.white54,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table
// ---------------------------------------------------------------------------

const _colThumb = 56.0;
const _colPrice = 130.0;
const _colStatus = 110.0;
const _colActions = 150.0;

class _InventoryTable extends ConsumerWidget {
  const _InventoryTable({required this.vehicles});
  final List<VehicleModel> vehicles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_searchQueryProvider).toLowerCase();
    final statusFilter = ref.watch(_statusFilterProvider);

    final filtered = vehicles.where((v) {
      final matchesStatus = statusFilter == null || v.status == statusFilter;
      final matchesQuery = query.isEmpty || v.displayTitle.toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();

    if (vehicles.isEmpty) {
      return const _EmptyState();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No vehicles match your search.',
          style: AppTextStyles.body.copyWith(color: Colors.white38),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navySurface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: AppColors.navyBorder.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TableHeaderRow(),
          Divider(color: AppColors.navyBorder.withValues(alpha: 0.6), height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => Divider(
                color: AppColors.navyBorder.withValues(alpha: 0.35),
                height: 1,
              ),
              itemBuilder: (context, i) => _VehicleRow(vehicle: filtered[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: 14),
      child: Row(
        children: [
          const SizedBox(width: _colThumb),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(child: _headerLabel('Vehicle')),
          SizedBox(width: _colPrice, child: _headerLabel('Price')),
          SizedBox(width: _colStatus, child: _headerLabel('Status')),
          SizedBox(width: _colActions, child: _headerLabel('Actions', alignEnd: true)),
        ],
      ),
    );
  }

  Widget _headerLabel(String text, {bool alignEnd = false}) {
    return Text(
      text,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: AppTextStyles.caption.copyWith(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _VehicleRow extends ConsumerWidget {
  const _VehicleRow({required this.vehicle});
  final VehicleModel vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: 10),
      child: Row(
        children: [
          // ── Thumbnail placeholder ──────────────────────────────────
          Container(
            width: _colThumb,
            height: _colThumb,
            decoration: BoxDecoration(
              color: AppColors.navyBorder.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: const Icon(Icons.directions_car_rounded, color: Colors.white24, size: 22),
          ),
          const SizedBox(width: AppDimensions.paddingM),

          // ── Make / Model / Year ───────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.displayTitle,
                  style: AppTextStyles.bodyBold.copyWith(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${vehicle.mileage} km · ${vehicle.transmission}',
                  style: AppTextStyles.caption.copyWith(color: Colors.white30, fontSize: 11),
                ),
              ],
            ),
          ),

          // ── Price ──────────────────────────────────────────────────
          SizedBox(
            width: _colPrice,
            child: Text(
              vehicle.formattedPrice,
              style: AppTextStyles.body.copyWith(color: Colors.white70, fontSize: 12.5),
            ),
          ),

          // ── Status ─────────────────────────────────────────────────
          SizedBox(width: _colStatus, child: _StatusBadge(status: vehicle.status)),

          // ── Actions ────────────────────────────────────────────────
          SizedBox(
            width: _colActions,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 17, color: Colors.white38),
                  tooltip: 'Edit',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AddVehicleForm(vehicleToEdit: vehicle),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.sell_outlined,
                    size: 17,
                    color: vehicle.status == 'sold' ? Colors.white12 : Colors.white38,
                  ),
                  tooltip: 'Mark Sold',
                  onPressed: vehicle.status == 'sold'
                      ? null
                      : () => _confirmMarkSold(context, ref, vehicle),
                ),
                IconButton(
                  icon: Icon(Icons.qr_code_rounded, size: 17, color: AppColors.ambientBlue.withValues(alpha: 0.85)),
                  tooltip: 'View QR — link to customer app',
                  onPressed: () => showDialog(
                    context: context,
                    barrierColor: Colors.black87,
                    builder: (_) => VehicleQRDialog(vehicle: vehicle),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmMarkSold(BuildContext context, WidgetRef ref, VehicleModel vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Mark as sold?',
        message: '${vehicle.displayTitle} will be marked as sold and hidden from active listings.',
        confirmLabel: 'Mark Sold',
      ),
    );
    if (confirmed == true) {
      await ref.read(vehicleNotifierProvider.notifier).markAsSold(vehicle.id);
    }
  }
}

// ---------------------------------------------------------------------------
// Status badge — Green / Orange / Gray, reusing existing AppColors tokens
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color get _color {
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

  String get _label => status.isEmpty ? status : status[0].toUpperCase() + status.substring(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _color),
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: AppTextStyles.caption.copyWith(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Confirm dialog
// ---------------------------------------------------------------------------

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });
  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        decoration: BoxDecoration(
          color: AppColors.navySurface.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          border: Border.all(color: AppColors.navyBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.heading2.copyWith(color: Colors.white, fontSize: 17)),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.body.copyWith(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: AppDimensions.paddingL),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel', style: AppTextStyles.body.copyWith(color: Colors.white54)),
                ),
                const SizedBox(width: AppDimensions.paddingS),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ambientBlue,
                    foregroundColor: AppColors.navyBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                    ),
                  ),
                  child: Text(confirmLabel, style: AppTextStyles.button.copyWith(color: AppColors.navyBackground)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_car_outlined, color: Colors.white24, size: 40),
          const SizedBox(height: AppDimensions.paddingM),
          Text(
            'No vehicles in inventory yet',
            style: AppTextStyles.bodyBold.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your first vehicle to get started.',
            style: AppTextStyles.caption.copyWith(color: Colors.white30),
          ),
          const SizedBox(height: AppDimensions.paddingL),
          ElevatedButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddVehicleForm(),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Vehicle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ambientBlue,
              foregroundColor: AppColors.navyBackground,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

class _TableSkeleton extends StatefulWidget {
  const _TableSkeleton();

  @override
  State<_TableSkeleton> createState() => _TableSkeletonState();
}

class _TableSkeletonState extends State<_TableSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.3, end: 0.55)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Column(
          children: List.generate(6, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.navySurface.withValues(alpha: _pulse.value),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                ),
              ),
            );
          }),
        );
      },
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
          Text('Could not load inventory', style: AppTextStyles.bodyBold.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(message, style: AppTextStyles.caption.copyWith(color: Colors.white38)),
          const SizedBox(height: AppDimensions.paddingM),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.ambientBlue),
            label: Text('Retry', style: AppTextStyles.body.copyWith(color: AppColors.ambientBlue)),
          ),
        ],
      ),
    );
  }
}