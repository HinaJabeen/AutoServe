// lib/features/search/presentation/search_screen.dart
//
// Dedicated search view (pushed from the Home/Discovery search bar) rather
// than an overlay on top of the deck: keeps the debounce timer and the text
// controller scoped to one screen's lifecycle, and keeps GoRouter's routes
// (not ad-hoc Overlay/OverlayEntry juggling) the single source of navigation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../../core/router/app_router.dart';
import '../../filters/providers/filter_providers.dart';
import '../models/search_result.dart';
import '../providers/search_providers.dart';
import 'widgets/search_result_tiles.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // repaint the clear button
    ref.read(debouncedSearchQueryProvider.notifier).onQueryChanged(value);
  }

  void _clear() {
    _controller.clear();
    setState(() {});
    ref.read(debouncedSearchQueryProvider.notifier).clear();
    _focusNode.requestFocus();
  }

  void _openVehicle(VehicleSearchResult result) {
    context.push(AppRoutes.vehicleDetailPath(result.car.id), extra: result.car);
  }

  void _openDealer(DealerSearchResult result) {
    ref
        .read(vehicleFiltersProvider.notifier)
        .filterByDealer(result.dealer.id, result.dealer.name);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final resultsAsync = ref.watch(searchResultsProvider);
    final hasText = _controller.text.isNotEmpty;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              onChanged: _onChanged,
              style: AppTextStyles.body.copyWith(color: p.textPrimary),
              cursorColor: p.accentSecondary,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search make, model, or dealership...',
                hintStyle: AppTextStyles.body.copyWith(color: p.textMuted),
                prefixIcon: Icon(Icons.search_rounded, color: p.textTertiary),
                suffixIcon: hasText
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: p.textTertiary),
                        onPressed: _clear,
                      )
                    : null,
                filled: true,
                fillColor: p.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: _Body(
            hasQuery: _controller.text.trim().length >= minSearchQueryLength,
            resultsAsync: resultsAsync,
            onOpenVehicle: _openVehicle,
            onOpenDealer: _openDealer,
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.hasQuery,
    required this.resultsAsync,
    required this.onOpenVehicle,
    required this.onOpenDealer,
  });

  final bool hasQuery;
  final AsyncValue<SearchResults> resultsAsync;
  final void Function(VehicleSearchResult) onOpenVehicle;
  final void Function(DealerSearchResult) onOpenDealer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hasQuery) {
      return EmptyState(
        message: 'Search for a make, model, or dealership.',
        icon: Icons.search_rounded,
      );
    }

    return resultsAsync.when(
      loading: () => const SearchResultShimmer(),
      error: (e, _) => ErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(searchResultsProvider),
      ),
      data: (results) {
        if (results.isEmpty) {
          final query = ref.read(debouncedSearchQueryProvider);
          return EmptyState(
            message: "No vehicles or dealers found for '$query'",
            icon: Icons.search_off_rounded,
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: AppDimensions.paddingL),
          children: [
            if (results.vehicles.isNotEmpty) ...[
              const SearchSectionHeader('VEHICLES'),
              for (final v in results.vehicles)
                VehicleResultTile(result: v, onTap: () => onOpenVehicle(v)),
            ],
            if (results.dealers.isNotEmpty) ...[
              const SearchSectionHeader('DEALERSHIPS'),
              for (final d in results.dealers)
                DealerResultTile(result: d, onTap: () => onOpenDealer(d)),
            ],
          ],
        );
      },
    );
  }
}
