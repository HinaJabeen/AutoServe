// lib/features/saved/presentation/saved_cars_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../../core/router/app_router.dart';
import '../../leads/presentation/lead_inquiry_bottom_sheet.dart';
import '../../leads/services/lead_service.dart';
import '../providers/saved_cars_providers.dart';

const _kSavedMaxWidth = 560.0;

class SavedCarsScreen extends ConsumerWidget {
  const SavedCarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedCarsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: SafeArea(
        child: savedAsync.when(
          // A background re-fetch keeps showing the current list.
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _SavedError(
            message: e.toString(),
            onRetry: () => ref.invalidate(savedCarsProvider),
          ),
          data: (cars) => cars.isEmpty
              ? const _EmptySaved()
              : RefreshIndicator(
                  onRefresh: () => ref.refresh(savedCarsProvider.future),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _kSavedMaxWidth),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppDimensions.paddingM),
                        itemCount: cars.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppDimensions.paddingM),
                        itemBuilder: (context, i) => _SavedCarTile(
                          key: ValueKey(cars[i].id),
                          car: cars[i],
                          index: i,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _SavedCarTile extends ConsumerWidget {
  const _SavedCarTile({super.key, required this.car, required this.index});
  final CarModel car;
  final int index;

  void _remove(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(savedCarsProvider.notifier);
    notifier.remove(car.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Removed ${car.displayTitle}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.restore(car, index),
        ),
      ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final radius = BorderRadius.circular(AppDimensions.radiusL);

    return Dismissible(
      key: ValueKey('dismiss-${car.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _remove(context, ref),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppDimensions.paddingL),
        decoration: BoxDecoration(
          color: p.error.withValues(alpha: 0.15),
          borderRadius: radius,
        ),
        child: Icon(Icons.delete_outline_rounded, color: p.error),
      ),
      child: Material(
        color: p.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: p.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.vehicleDetailPath(car.id), extra: car),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  child: SizedBox(
                    width: 104,
                    height: 84,
                    child: CarNetworkImage(url: car.photoUrls.firstOrNull, iconSize: 24),
                  ),
                ),
                const SizedBox(width: AppDimensions.paddingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(car.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
                      const SizedBox(height: 2),
                      Text(car.formattedPrice,
                          style: AppTextStyles.bodyBold.copyWith(color: p.accentSecondary)),
                      const SizedBox(height: AppDimensions.paddingS),
                      SizedBox(
                        height: 32,
                        child: OutlinedButton.icon(
                          onPressed: () => showLeadInquiryBottomSheet(
                              context, car: car, type: LeadType.inquiry),
                          icon: Icon(Icons.chat_bubble_outline_rounded,
                              size: 16, color: p.accentSecondary),
                          label: Text('Inquire',
                              style: AppTextStyles.caption.copyWith(
                                  color: p.accentSecondary, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                            side: BorderSide(color: p.accentSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove from saved',
                  icon: Icon(Icons.favorite_rounded, color: p.accent),
                  onPressed: () => _remove(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite_border_rounded, size: 44, color: p.accent),
            ),
            const SizedBox(height: AppDimensions.paddingL),
            Text('No saved cars yet',
                style: AppTextStyles.heading2.copyWith(color: p.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.paddingS),
            Text('Swipe right on listings to save them here.',
                style: AppTextStyles.body.copyWith(color: p.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.paddingL),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.deck),
              icon: Icon(Icons.explore_outlined, size: 18, color: p.onAccent),
              label: Text('Explore cars',
                  style: AppTextStyles.button.copyWith(color: p.onAccent)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedError extends StatelessWidget {
  const _SavedError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: p.error),
            const SizedBox(height: AppDimensions.paddingM),
            Text(message,
                style: AppTextStyles.body.copyWith(color: p.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.paddingM),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
