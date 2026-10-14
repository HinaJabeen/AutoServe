// lib/features/search/presentation/widgets/search_result_tiles.dart

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../../models/search_result.dart';

class VehicleResultTile extends StatelessWidget {
  const VehicleResultTile({super.key, required this.result, required this.onTap});
  final VehicleSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final car = result.car;
    final thumb = car.photoUrls.isNotEmpty ? car.photoUrls.first : null;

    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        child: SizedBox(
          width: 56,
          height: 56,
          child: thumb == null
              ? Container(
                  color: p.surfaceElevated,
                  child: Icon(Icons.directions_car_rounded, color: p.textTertiary),
                )
              : Image.network(
                  thumb,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: p.surfaceElevated,
                    child: Icon(Icons.directions_car_rounded, color: p.textTertiary),
                  ),
                ),
        ),
      ),
      title: Text(car.displayTitle, style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
      subtitle: Text(result.dealerName,
          style: AppTextStyles.caption.copyWith(color: p.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: Text(car.formattedPrice,
          style: AppTextStyles.bodyBold.copyWith(color: p.accentSecondary)),
    );
  }
}

class DealerResultTile extends StatelessWidget {
  const DealerResultTile({super.key, required this.result, required this.onTap});
  final DealerSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dealer = result.dealer;
    final location = [dealer.city, dealer.address].where((s) => s != null && s.isNotEmpty).join(', ');

    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: p.accent.withValues(alpha: 0.12),
        child: Icon(Icons.storefront_rounded, color: p.accentSecondary),
      ),
      title: Text(dealer.name, style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
      subtitle: Text(location.isEmpty ? 'Location unavailable' : location,
          style: AppTextStyles.caption.copyWith(color: p.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS, vertical: 4),
        decoration: BoxDecoration(
          color: p.badgeBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        ),
        child: Text(
          '${result.activeListingsCount} listing${result.activeListingsCount == 1 ? '' : 's'}',
          style: AppTextStyles.caption.copyWith(color: p.badgeText, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class SearchSectionHeader extends StatelessWidget {
  const SearchSectionHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingXS),
      child: Text(
        title,
        style: AppTextStyles.caption
            .copyWith(color: context.palette.textTertiary, fontWeight: FontWeight.w700, letterSpacing: 0.6),
      ),
    );
  }
}

class SearchResultShimmer extends StatelessWidget {
  const SearchResultShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.paddingS),
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              child: LoadingShimmer(height: 56, width: 56),
            ),
            const SizedBox(width: AppDimensions.paddingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoadingShimmer(height: 14, width: 160),
                  const SizedBox(height: 8),
                  LoadingShimmer(height: 12, width: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
