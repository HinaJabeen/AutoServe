import 'package:flutter/material.dart';
import '../models/vehicle_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

class VehicleCard extends StatelessWidget {
  final VehicleModel vehicle;
  final VoidCallback onTap;

  const VehicleCard({super.key, required this.vehicle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: () {
                final imageUrl = vehicle.primaryImageUrl;
                if (imageUrl != null && imageUrl.isNotEmpty) {
                  return Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.shimmerBase,
                      child: const Icon(
                        Icons.directions_car,
                        size: 40,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  );
                }

                return Container(
                  color: AppColors.shimmerBase,
                  child: const Icon(
                    Icons.directions_car,
                    size: 40,
                    color: AppColors.textTertiary,
                  ),
                );
              }(),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicle.displayTitle, style: AppTextStyles.heading3),
                  const SizedBox(height: 4),
                  Text(
                    '${vehicle.mileage} km · ${vehicle.transmission}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 8),
                  Text(vehicle.formattedPrice, style: AppTextStyles.price),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
