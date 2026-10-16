// lib/features/filters/presentation/filter_sheet.dart
//
// The filter matrix modal. Make/Model/Body Type options are derived from
// `availableCarsProvider` (the deck's own unfiltered fetch) rather than a
// second query, so the picker only ever offers values that actually exist
// in current inventory.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../core/theme/app_theme.dart';

import '../../discovery/providers/discovery_providers.dart';
import '../models/vehicle_filters.dart';
import '../providers/filter_providers.dart';

Future<void> showFilterSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _FilterSheet(),
  );
}

const _transmissions = ['manual', 'automatic'];
const _fuelTypes = ['petrol', 'diesel', 'hybrid', 'electric'];

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();
  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  // Local draft — committed to `vehicleFiltersProvider` only on "Apply", so
  // closing the sheet without applying (swipe-to-dismiss, tapping outside)
  // discards in-progress edits rather than live-filtering the deck per tap.
  late VehicleFilters _draft;

  // Cars this user already swiped — the deck hides them, so the live
  // "Show N cars" count must too.
  Set<String> _decidedIds = const {};

  @override
  void initState() {
    super.initState();
    _draft = ref.read(vehicleFiltersProvider);
    ref.read(localSwipeStoreProvider).loadDecidedIds().then((ids) {
      if (mounted) setState(() => _decidedIds = ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    final carsAsync = ref.watch(availableCarsProvider);
    final p = context.palette;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        ),
        child: carsAsync.when(
          loading: () => const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 160,
            child: Center(
              child: Text('Could not load filter options',
                  style: AppTextStyles.body.copyWith(color: p.textSecondary)),
            ),
          ),
          data: (cars) => _buildForm(cars, p),
        ),
      ),
    );
  }

  Widget _buildForm(List<CarModel> cars, AppPalette p) {
    final matchCount =
        cars.where((c) => !_decidedIds.contains(c.id) && _draft.matches(c)).length;
    final makes = cars.map((c) => c.make).toSet().toList()..sort();
    final models = (_draft.make == null
            ? cars
            : cars.where((c) => c.make == _draft.make))
        .map((c) => c.model)
        .toSet()
        .toList()
      ..sort();
    final bodyTypes = cars
        .map((c) => c.specs['body_type'] as String?)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    final prices = cars.map((c) => c.price).toList();
    final minBound = prices.isEmpty ? 0.0 : prices.reduce((a, b) => a < b ? a : b);
    final maxBound = prices.isEmpty ? 1.0 : prices.reduce((a, b) => a > b ? a : b);
    final priceRange = RangeValues(
      _draft.minPrice ?? minBound,
      _draft.maxPrice ?? maxBound,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingL, AppDimensions.paddingM, AppDimensions.paddingL, AppDimensions.paddingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter cars', style: AppTextStyles.heading2.copyWith(color: p.textPrimary)),
              TextButton(
                onPressed: () => setState(() => _draft = const VehicleFilters()),
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingM),

          _sectionLabel('Make'),
          _chipGroup(
            options: makes,
            selected: _draft.make,
            // Changing make invalidates a model pick that no longer fits.
            onSelected: (v) => setState(
                () => _draft = _draft.copyWith(make: () => v, model: () => null)),
          ),

          if (models.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.paddingM),
            _sectionLabel('Model'),
            _chipGroup(
              options: models,
              selected: _draft.model,
              onSelected: (v) => setState(() => _draft = _draft.copyWith(model: () => v)),
            ),
          ],

          const SizedBox(height: AppDimensions.paddingM),
          _sectionLabel('Price range'),
          if (maxBound > minBound)
            RangeSlider(
              values: priceRange,
              min: minBound,
              max: maxBound,
              divisions: 20,
              labels: RangeLabels(
                _priceLabel(priceRange.start),
                _priceLabel(priceRange.end),
              ),
              onChanged: (v) => setState(() => _draft = _draft.copyWith(
                    minPrice: () => v.start,
                    maxPrice: () => v.end,
                  )),
            )
          else
            Text('Not enough listings to set a price range',
                style: AppTextStyles.caption.copyWith(color: p.textSecondary)),

          if (bodyTypes.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.paddingM),
            _sectionLabel('Body type'),
            _chipGroup(
              options: bodyTypes,
              selected: _draft.bodyType,
              onSelected: (v) => setState(() => _draft = _draft.copyWith(bodyType: () => v)),
            ),
          ],

          const SizedBox(height: AppDimensions.paddingM),
          _sectionLabel('Transmission'),
          _chipGroup(
            options: _transmissions,
            selected: _draft.transmission,
            onSelected: (v) => setState(() => _draft = _draft.copyWith(transmission: () => v)),
          ),

          const SizedBox(height: AppDimensions.paddingM),
          _sectionLabel('Fuel type'),
          _chipGroup(
            options: _fuelTypes,
            selected: _draft.fuelType,
            onSelected: (v) => setState(() => _draft = _draft.copyWith(fuelType: () => v)),
          ),

          const SizedBox(height: AppDimensions.paddingL),
          // Full-width sage pill (StadiumBorder comes from the theme).
          ElevatedButton.icon(
            onPressed: () {
              ref.read(vehicleFiltersProvider.notifier).apply(_draft);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: Icon(Icons.search_rounded, size: 20, color: p.onAccent),
            label: Text(
              matchCount == 1 ? 'Show 1 car' : 'Show $matchCount cars',
              style: AppTextStyles.button.copyWith(
                  color: p.onAccent, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _priceLabel(double v) => v >= 1000000
      ? '${(v / 1000000).toStringAsFixed(1)}M'
      : '${(v / 1000).round()}K';

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
        child: Text(text,
            style: AppTextStyles.bodyBold.copyWith(color: context.palette.textPrimary)),
      );

  Widget _chipGroup({
    required List<String> options,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    final p = context.palette;
    return Wrap(
      spacing: AppDimensions.paddingS,
      runSpacing: AppDimensions.paddingS,
      children: options.map((option) {
        final isSelected = option == selected;
        return ChoiceChip(
          label: Text(_titleCase(option)),
          selected: isSelected,
          onSelected: (_) => onSelected(isSelected ? null : option),
          showCheckmark: false,
          backgroundColor: p.surfaceElevated,
          selectedColor: p.accent,
          labelStyle: AppTextStyles.caption.copyWith(
            color: isSelected ? p.onAccent : p.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
          side: BorderSide(color: isSelected ? p.accent : p.border),
        );
      }).toList(),
    );
  }

  String _titleCase(String s) =>
      s.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}
