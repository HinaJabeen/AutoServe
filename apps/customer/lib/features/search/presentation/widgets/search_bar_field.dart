// lib/features/search/presentation/widgets/search_bar_field.dart
//
// The decoy field shown at the top of the Home/Discovery screen — read-only
// so tapping it never pops the on-screen keyboard behind the navigation,
// it just opens /search where the real, debounced field lives.

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

class SearchBarField extends StatelessWidget {
  const SearchBarField({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          child: Material(
            color: p.surfaceElevated,
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              onTap: onTap,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: AppDimensions.iconSizeM, color: p.textTertiary),
                    const SizedBox(width: AppDimensions.paddingS),
                    Expanded(
                      child: Text(
                        'Search make, model, or dealership...',
                        style: AppTextStyles.body.copyWith(color: p.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
