// lib/features/details/presentation/vehicle_detail_screen.dart
//
// "Digital Showroom" — pushed when a card is tapped (not swiped). Renders
// instantly from `initialCar` (passed via go_router `extra` from the deck,
// so there's no blank flash for data we already have) while
// `vehicleDetailProvider` fetches the fresh car + dealer info in the
// background.
//
// Layout: a full-bleed photo header that collapses as you scroll, with the
// content on a 32px-radius sheet that overlaps it and slides up over the
// imagery; a frosted floating action bar the content scrolls behind.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/inspection_badge.dart';
import '../../compare/presentation/compare_widgets.dart';
import '../../leads/presentation/lead_inquiry_bottom_sheet.dart';
import '../../leads/services/lead_service.dart';
import '../providers/vehicle_detail_providers.dart';

class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({super.key, required this.carId, this.initialCar});

  final String carId;
  final CarModel? initialCar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(vehicleDetailProvider(carId));

    return detailAsync.when(
      data: (detail) => _DetailScaffold(car: detail.car, dealer: detail.dealer),
      error: (e, _) => _DetailError(
        message: e.toString(),
        onRetry: () => ref.invalidate(vehicleDetailProvider(carId)),
      ),
      loading: () => initialCar != null
          ? _DetailScaffold(car: initialCar!, dealer: null, dealerLoading: true)
          : const _DetailSkeleton(),
    );
  }
}

// Desktop/web ceiling so the "digital showroom" reads like a scaled-down
// mobile/tablet layout instead of stretching edge to edge on a laptop.
const _kDetailMaxWidth = 600.0;
const _kHeaderHeight = 400.0;
/// How far the content sheet overlaps the photo header.
const _kSheetOverlap = 32.0;

/// A non-blank string from the `specs` jsonb bucket — body type, trim, etc.
/// have no dedicated `cars` column (see vehicle_filters.dart).
String? _specText(CarModel car, String key) {
  final v = car.specs[key]?.toString().trim();
  return (v == null || v.isEmpty) ? null : v;
}

String _titleCase(String s) => s
    .split('_')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _groupThousands(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );

String? _nice(String? v) => (v == null || v.trim().isEmpty) ? null : _titleCase(v.trim());

/// WhatsApp deep link to the car's dealer, pre-filled; null when the dealer
/// isn't loaded yet or has no usable number.
Uri? _whatsAppUri(CarModel car, DealershipModel? dealer) => dealer == null
    ? null
    : ContactLinks.whatsApp(
        dealer.phone,
        message: 'Hi, I am interested in your ${car.year} ${car.make} ${car.model} '
            'listed on AutoServe.',
      );

void _goBack(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(AppRoutes.deck);

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.car,
    required this.dealer,
    this.dealerLoading = false,
  });
  final CarModel car;
  final DealershipModel? dealer;
  final bool dealerLoading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final whatsApp = _whatsAppUri(car, dealer);

    return Scaffold(
      backgroundColor: p.background,
      // Content scrolls behind the frosted action bar.
      extendBody: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kDetailMaxWidth),
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Photo + sheet in ONE stack, sheet painted last, so the
                  // sheet's rounded top genuinely overlaps the imagery and
                  // slides up over it on scroll. (A pinned SliverAppBar would
                  // paint above the following sliver and hide the overlap.)
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        SizedBox(
                          height: _kHeaderHeight,
                          width: double.infinity,
                          child: _PhotoCarousel(photoUrls: car.photoUrls),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: _kHeaderHeight - _kSheetOverlap),
                          child: _ContentSheet(
                            car: car,
                            dealer: dealer,
                            dealerLoading: dealerLoading,
                            // The bar shows WhatsApp when it can; the inquiry
                            // form is then offered from the dealer card.
                            offerInquiryOnCard: whatsApp != null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Clears the floating action bar. Builder → the MediaQuery
                  // *inside* the Scaffold body, where extendBody has added
                  // the bar's height to the bottom padding (the outer
                  // `context` doesn't include it).
                  SliverToBoxAdapter(
                    child: Builder(
                      builder: (inner) => SizedBox(
                        height: MediaQuery.paddingOf(inner).bottom + AppDimensions.paddingM,
                      ),
                    ),
                  ),
                ],
              ),
              // Frosted controls float above everything and stay put.
              Positioned(
                top: MediaQuery.paddingOf(context).top + AppDimensions.paddingS,
                left: AppDimensions.paddingM,
                child: GlassIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => _goBack(context),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + AppDimensions.paddingS,
                right: AppDimensions.paddingM,
                child: GlassContainer(
                  borderRadius: 22,
                  padding: EdgeInsets.zero,
                  child: CompareToggleButton(car: car, color: p.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _LeadActionBar(car: car, whatsApp: whatsApp),
    );
  }
}

class _ContentSheet extends StatelessWidget {
  const _ContentSheet({
    required this.car,
    required this.dealer,
    required this.dealerLoading,
    required this.offerInquiryOnCard,
  });
  final CarModel car;
  final DealershipModel? dealer;
  final bool dealerLoading;
  final bool offerInquiryOnCard;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final description = (car.description ?? _specText(car, 'description'))?.trim();
    final extraSpecs = car.specs.entries
        .where((e) => !const {'body_type', 'trim', 'description'}.contains(e.key))
        .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        boxShadow: [
          BoxShadow(
            color: p.shadowColor.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingL, AppDimensions.paddingM, AppDimensions.paddingL, AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grabber — signals the sheet sits over the photos.
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingL),
          Text(
            [car.condition, car.specs['body_type']?.toString()]
                .whereType<String>()
                .where((s) => s.trim().isNotEmpty)
                .map((s) => _titleCase(s).toUpperCase())
                .join('  ·  '),
            style: AppType.eyebrow(p, color: p.warmAccent),
          ),
          const SizedBox(height: 6),
          Text(car.displayTitle, style: AppType.title(p, size: 28)),
          if (_specText(car, 'trim') case final trim?) ...[
            const SizedBox(height: 4),
            Text(trim, style: AppTextStyles.body.copyWith(color: p.textSecondary)),
          ],
          const SizedBox(height: AppDimensions.paddingM),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppDimensions.paddingM,
            runSpacing: AppDimensions.paddingS,
            children: [
              Text(car.formattedPrice, style: AppType.price(p, size: 24)),
              if (car.isInspected) InspectionBadge(car: car),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),
          _SpecStrip(car: car),
          if (extraSpecs.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.paddingL),
            _SectionTitle('More details'),
            for (final e in extraSpecs)
              _DetailRow(label: _titleCase(e.key), value: e.value.toString()),
          ],
          if (car.isInspected) ...[
            const SizedBox(height: AppDimensions.paddingL),
            InspectionReport(car: car),
          ],
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.paddingL),
            _SectionTitle('About this car'),
            Text(description,
                style: AppTextStyles.body.copyWith(color: p.textSecondary, height: 1.6)),
          ],
          const SizedBox(height: AppDimensions.paddingL),
          _SectionTitle('Showroom'),
          if (dealerLoading)
            const _DealerSkeleton()
          else if (dealer != null)
            _DealerCard(dealer: dealer!, car: car, offerInquiry: offerInquiryOnCard),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
        child: Text(text,
            style: AppTextStyles.heading3.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            )),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(
          width: 130,
          child: Text(label, style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
        ),
      ]),
    );
  }
}

/// Horizontal "amenities row" of key specs. The first four tiles always
/// show (a missing value reads "—", so bulk-imported listings never leave
/// a gap); colour/body type/condition follow when known.
class _SpecStrip extends StatelessWidget {
  const _SpecStrip({required this.car});
  final CarModel car;

  @override
  Widget build(BuildContext context) {
    final mileage = car.mileage;
    final fuel = _nice(car.fuelType);
    final tiles = <(IconData, String?, String)>[
      (Icons.speed_rounded, mileage == null ? null : '${_groupThousands(mileage)} km', 'Mileage'),
      (Icons.settings_rounded, _nice(car.transmission), 'Gearbox'),
      (
        car.fuelType == 'electric' ? Icons.ev_station_rounded : Icons.local_gas_station_rounded,
        fuel,
        'Fuel'
      ),
      if (car.isInspected)
        (Icons.verified_user_rounded, '${car.inspectionScore!.toStringAsFixed(1)}/10', 'Inspected')
      else
        (Icons.workspace_premium_outlined, _nice(car.condition), 'Condition'),
      if (car.isInspected && _nice(car.condition) != null)
        (Icons.workspace_premium_outlined, _nice(car.condition), 'Condition'),
      if (_nice(car.color) != null) (Icons.palette_outlined, _nice(car.color), 'Color'),
      if (_nice(_specText(car, 'body_type')) != null)
        (Icons.directions_car_outlined, _nice(_specText(car, 'body_type')), 'Body'),
    ];

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppDimensions.paddingS),
        itemBuilder: (context, i) {
          final (icon, value, label) = tiles[i];
          return _SpecTile(icon: icon, value: value, label: label);
        },
      ),
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.borderSubtle),
        boxShadow: [
          BoxShadow(color: p.shadowColor.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: p.accentSecondary),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              value ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyBold.copyWith(
                color: value == null ? p.textMuted : p.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: p.textTertiary, fontSize: 11)),
          ]),
        ],
      ),
    );
  }
}

class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.photoUrls});
  final List<String> photoUrls;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photoUrls;
    final p = context.palette;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (photos.isEmpty)
          ColoredBox(
            color: p.surface,
            child: Icon(Icons.directions_car_rounded, size: 72, color: p.textTertiary),
          )
        else
          PageView.builder(
            controller: _pageController,
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => CarNetworkImage(url: photos[i], iconSize: 48),
          ),

        // Top scrim keeps the glass buttons legible over bright photos.
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: SizedBox(
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66000000), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        ),

        if (photos.length > 1)
          Positioned(
            // Sits just above where the content sheet overlaps the photo.
            bottom: _kSheetOverlap + AppDimensions.paddingM,
            left: 0,
            right: 0,
            child: Center(
              child: GlassContainer(
                borderRadius: 20,
                tint: Colors.black.withValues(alpha: 0.25),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(photos.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: active ? 0.95 : 0.5),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DealerCard extends StatelessWidget {
  const _DealerCard({required this.dealer, required this.car, required this.offerInquiry});
  final DealershipModel dealer;
  final CarModel car;
  final bool offerInquiry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Only `approved` dealers are readable by customers at all (RLS), so in
    // practice every dealer shown here is verified; checked anyway so a
    // policy change can't silently award the badge.
    final verified = dealer.status == 'approved';
    final location = [dealer.address, dealer.city]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
    final hours = dealer.businessHours?.trim();

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.glass),
        border: Border.all(color: p.borderSubtle),
        boxShadow: [
          BoxShadow(color: p.shadowColor.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: p.accentSecondary,
                child: Text(
                  dealer.name.isNotEmpty ? dealer.name[0].toUpperCase() : '?',
                  style: AppTextStyles.heading3.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: AppDimensions.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            dealer.name,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyBold.copyWith(
                              color: p.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 4),
                          Tooltip(
                            message: 'Verified dealer',
                            child: Icon(Icons.verified_rounded, size: 16, color: p.highlight),
                          ),
                        ],
                      ],
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: p.textSecondary),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(color: p.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (hours != null && hours.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.paddingM),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: p.warmAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(hours, style: AppTextStyles.caption.copyWith(color: p.textPrimary)),
                  ),
                ],
              ),
            ),
          ],
          if (offerInquiry) ...[
            const SizedBox(height: AppDimensions.paddingS),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showLeadInquiryBottomSheet(context, car: car, type: LeadType.inquiry),
                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                label: const Text('Send an inquiry instead'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DealerSkeleton extends StatelessWidget {
  const _DealerSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        decoration: BoxDecoration(
          color: context.palette.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.glass),
        ),
      );
}

/// Frosted floating bar: WhatsApp (or Send Inquiry when the dealer has no
/// usable number) + the primary "Book Test Drive" pill.
class _LeadActionBar extends StatelessWidget {
  const _LeadActionBar({required this.car, required this.whatsApp});
  final CarModel car;
  final Uri? whatsApp;

  static const whatsAppLabel = 'Contact Dealer via WhatsApp';

  Future<void> _openWhatsApp(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't open WhatsApp.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const pillHeight = Size.fromHeight(52);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingM,
        0,
        AppDimensions.paddingM,
        AppDimensions.paddingM + MediaQuery.paddingOf(context).bottom,
      ),
      // heightFactor: 1 — the bottomNavigationBar slot allows the full screen
      // height, and a plain Center would expand to fill it, covering the body.
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kDetailMaxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.card),
              boxShadow: [
                BoxShadow(color: p.shadowColor.withValues(alpha: 0.14), blurRadius: 24, offset: const Offset(0, 10)),
              ],
            ),
            child: GlassContainer(
              borderRadius: AppRadii.card,
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The full label doesn't fit half a phone-width bar.
                  final wide = constraints.maxWidth >= 520;
                  return Row(
                    children: [
                      Expanded(
                        child: whatsApp != null
                            ? Tooltip(
                                message: whatsAppLabel,
                                child: OutlinedButton.icon(
                                  onPressed: () => _openWhatsApp(context, whatsApp!),
                                  icon: Icon(Icons.chat_rounded, size: 18, color: p.success),
                                  label: Text(
                                    wide ? whatsAppLabel : 'WhatsApp',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: pillHeight,
                                    backgroundColor: p.surfaceElevated.withValues(alpha: 0.7),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: () => showLeadInquiryBottomSheet(
                                    context, car: car, type: LeadType.inquiry),
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                                label: const Text('Send Inquiry', maxLines: 1),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: pillHeight,
                                  backgroundColor: p.surfaceElevated.withValues(alpha: 0.7),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                              ),
                      ),
                      const SizedBox(width: AppDimensions.paddingS),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => showLeadInquiryBottomSheet(
                              context, car: car, type: LeadType.testDrive),
                          icon: const Icon(Icons.directions_car_filled_rounded, size: 18),
                          label: const Text('Book Test Drive', maxLines: 1),
                          style: ElevatedButton.styleFrom(
                            minimumSize: pillHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// First paint when there's no `initialCar` to show (deep link, refresh).
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget block(double height, {double? width, double radius = AppDimensions.radiusM}) =>
        LoadingShimmer(
          height: height,
          width: width,
          borderRadius: radius,
          baseColor: p.surfaceElevated,
          highlightColor: p.border,
        );

    return Scaffold(
      backgroundColor: p.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kDetailMaxWidth),
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              block(_kHeaderHeight, radius: 0),
              Transform.translate(
                offset: const Offset(0, -_kSheetOverlap),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  decoration: BoxDecoration(
                    color: p.background,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block(28, width: 240),
                      const SizedBox(height: AppDimensions.paddingS),
                      block(24, width: 140),
                      const SizedBox(height: AppDimensions.paddingL),
                      Row(children: [
                        for (var i = 0; i < 3; i++) ...[
                          block(104, width: 104, radius: 20),
                          const SizedBox(width: AppDimensions.paddingS),
                        ],
                      ]),
                      const SizedBox(height: AppDimensions.paddingL),
                      block(76, radius: AppRadii.glass),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: p.error),
              const SizedBox(height: AppDimensions.paddingM),
              Text(
                message,
                style: AppTextStyles.body.copyWith(color: p.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingM),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
