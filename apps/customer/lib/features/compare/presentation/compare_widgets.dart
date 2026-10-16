// lib/features/compare/presentation/compare_widgets.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../../core/theme/app_theme.dart';

import '../../../core/router/app_router.dart';
import '../providers/compare_providers.dart';

/// Add/remove [car] from the comparison tray, with feedback.
class CompareToggleButton extends ConsumerWidget {
  const CompareToggleButton({super.key, required this.car, this.color});
  final CarModel car;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(compareProvider.select((cars) => cars.any((c) => c.id == car.id)));
    final p = context.palette;
    return IconButton(
      tooltip: selected ? 'Remove from compare' : 'Compare',
      icon: Icon(
        selected ? Icons.library_add_check_rounded : Icons.compare_arrows_rounded,
        color: selected ? p.accent : (color ?? p.textSecondary),
      ),
      onPressed: () {
        final result = ref.read(compareProvider.notifier).toggle(car);
        final count = ref.read(compareProvider).length;
        final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          content: Text(switch (result) {
            CompareToggleResult.added => 'Added to compare ($count/$maxCompareCars)',
            CompareToggleResult.removed => 'Removed from compare',
            CompareToggleResult.full => 'You can compare up to $maxCompareCars cars — remove one first.',
          }),
          action: count >= 2
              ? SnackBarAction(label: 'Compare', onPressed: () => context.push(AppRoutes.compare))
              : null,
        ));
      },
    );
  }
}

/// Floating "Compare (2/3)" tray above the bottom navigation.
class CompareBar extends ConsumerWidget {
  const CompareBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(compareProvider);
    if (cars.isEmpty) return const SizedBox.shrink();
    final p = context.palette;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppDimensions.paddingM, 0, AppDimensions.paddingM, AppDimensions.paddingS),
      padding: const EdgeInsets.fromLTRB(AppDimensions.paddingM, 6, 6, 6),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(AppRadii.glass),
        border: Border.all(color: p.accent.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: p.shadowColor.withValues(alpha: 0.15), blurRadius: 12)],
      ),
      child: Row(children: [
        Icon(Icons.compare_arrows_rounded, color: p.accent, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            cars.length == 1 ? 'Add 1 more car to compare' : '${cars.length} cars selected',
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: p.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => ref.read(compareProvider.notifier).clear(),
          child: const Text('Clear'),
        ),
        ElevatedButton(
          onPressed: cars.length < 2 ? null : () => context.push(AppRoutes.compare),
          child: Text('Compare (${cars.length}/$maxCompareCars)'),
        ),
      ]),
    );
  }
}
