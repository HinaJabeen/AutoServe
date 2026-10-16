// lib/features/compare/presentation/compare_screen.dart
//
// /compare — side-by-side table of up to 3 cars. Scrolls horizontally on
// narrow phones; the best value in comparable rows (lowest price/mileage,
// highest inspection score) is highlighted.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../providers/compare_providers.dart';

const _labelWidth = 104.0;
const _columnWidth = 168.0;

String _titleCase(String? s) => (s == null || s.trim().isEmpty)
    ? '—'
    : s.trim().split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

String _km(int? km) => km == null
    ? '—'
    : '${km.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} km';

/// Index of the best non-null value, or null when fewer than two are comparable.
int? _bestIndex(List<num?> values, {required bool lowerIsBetter}) {
  int? best;
  var comparable = 0;
  for (var i = 0; i < values.length; i++) {
    final v = values[i];
    if (v == null) continue;
    comparable++;
    final b = best == null ? null : values[best];
    if (b == null || (lowerIsBetter ? v < b : v > b)) best = i;
  }
  return comparable >= 2 ? best : null;
}

class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final cars = ref.watch(compareProvider);
    final dealers = ref.watch(compareDealersProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(
        // Pushed from a listing → normal back. Opened directly (typed URL,
        // page refresh) there's nothing to pop, so go to Explore instead.
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.deck),
        ),
        title: Text('Compare (${cars.length}/$maxCompareCars)'),
        actions: [
          if (cars.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(compareProvider.notifier).clear(),
              child: const Text('Clear all'),
            ),
        ],
      ),
      body: cars.length < 2
          ? _NotEnough(count: cars.length)
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _Table(cars: cars, dealers: dealers, p: p),
                ),
              ),
            ),
    );
  }
}

class _NotEnough extends StatelessWidget {
  const _NotEnough({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXL),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.compare_arrows_rounded, size: 56, color: p.textTertiary),
          const SizedBox(height: AppDimensions.paddingM),
          Text(count == 0 ? 'No cars to compare yet' : 'Add one more car',
              style: AppTextStyles.heading3.copyWith(color: p.textPrimary)),
          const SizedBox(height: AppDimensions.paddingS),
          Text('Tap the compare icon on a listing to add up to $maxCompareCars cars.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: p.textSecondary)),
          const SizedBox(height: AppDimensions.paddingL),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.deck),
            child: const Text('Browse cars'),
          ),
        ]),
      ),
    );
  }
}

class _Table extends ConsumerWidget {
  const _Table({required this.cars, required this.dealers, required this.p});
  final List<CarModel> cars;
  final Map<String, DealershipModel> dealers;
  final AppPalette p;

  Future<void> _whatsApp(BuildContext context, CarModel car, DealershipModel? dealer) async {
    final uri = ContactLinks.whatsApp(dealer?.phone,
        message: 'Hi, I am interested in your ${car.year} ${car.make} ${car.model} listed on AutoServe.');
    final messenger = ScaffoldMessenger.of(context);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(const SnackBar(content: Text("This dealer hasn't added a WhatsApp number.")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bestPrice = _bestIndex([for (final c in cars) c.price], lowerIsBetter: true);
    final bestMileage = _bestIndex([for (final c in cars) c.mileage], lowerIsBetter: true);
    final bestScore = _bestIndex([for (final c in cars) c.inspectionScore], lowerIsBetter: false);

    TableRow row(String label, List<Widget> cells, {bool shaded = false}) => TableRow(
          decoration: BoxDecoration(color: shaded ? p.surfaceElevated : null),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text(label,
                  style: AppTextStyles.caption.copyWith(color: p.textSecondary, fontWeight: FontWeight.w600)),
            ),
            ...cells,
          ],
        );

    Widget text(String value, {bool best = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(children: [
            Flexible(
              child: Text(value,
                  style: (best ? AppTextStyles.bodyBold : AppTextStyles.body)
                      .copyWith(color: best ? p.accentSecondary : p.textPrimary, fontSize: 13.5)),
            ),
            if (best) ...[
              const SizedBox(width: 4),
              Icon(Icons.star_rounded, size: 14, color: p.accentSecondary),
            ],
          ]),
        );

    var shade = false;
    TableRow r(String label, List<Widget> cells) {
      shade = !shade;
      return row(label, cells, shaded: shade);
    }

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        0: const FixedColumnWidth(_labelWidth),
        for (var i = 0; i < cars.length; i++) i + 1: const FixedColumnWidth(_columnWidth),
      },
      border: TableBorder(horizontalInside: BorderSide(color: p.border.withValues(alpha: 0.6))),
      children: [
        row('', [
          for (final c in cars)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Stack(children: [
                  InkWell(
                    onTap: () => context.push(AppRoutes.vehicleDetailPath(c.id), extra: c),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                      child: SizedBox(
                        height: 100,
                        width: double.infinity,
                        child: CarNetworkImage(url: c.photoUrls.firstOrNull, iconSize: 28),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2, right: 2,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => ref.read(compareProvider.notifier).remove(c.id),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(c.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary, fontSize: 13.5)),
              ]),
            ),
        ]),
        r('Make', [for (final c in cars) text(c.make)]),
        r('Model', [for (final c in cars) text(c.model)]),
        r('Year', [for (final c in cars) text('${c.year}')]),
        r('Price', [for (var i = 0; i < cars.length; i++) text(cars[i].formattedPrice, best: i == bestPrice)]),
        r('Mileage', [for (var i = 0; i < cars.length; i++) text(_km(cars[i].mileage), best: i == bestMileage)]),
        r('Transmission', [for (final c in cars) text(_titleCase(c.transmission))]),
        r('Fuel type', [for (final c in cars) text(_titleCase(c.fuelType))]),
        r('Condition', [for (final c in cars) text(_titleCase(c.condition))]),
        r('Color', [for (final c in cars) text(_titleCase(c.color))]),
        r('Inspection', [
          for (var i = 0; i < cars.length; i++)
            text(cars[i].inspectionScore == null
                    ? 'Not inspected'
                    : '${cars[i].inspectionScore!.toStringAsFixed(1)} / 10',
                best: i == bestScore),
        ]),
        row('', [
          for (final c in cars)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: ElevatedButton.icon(
                onPressed: () => _whatsApp(context, c, dealers[c.dealerId]),
                icon: Icon(Icons.chat_rounded, size: 16, color: p.onAccent),
                label: Text('WhatsApp',
                    style: AppTextStyles.button.copyWith(color: p.onAccent, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.success,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
              ),
            ),
        ]),
      ],
    );
  }
}
