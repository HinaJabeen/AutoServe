// lib/features/presentation/overview_screen.dart
// FIXED: Added import 'package:shared/shared.dart' 
// ALSO FIXED: tooltipBgColor → backgroundColor in LineTouchTooltipData

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import 'package:dashboard/theme/app_palette.dart';
import '../providers/overview_provider.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final dealershipAsync = ref.watch(currentDealershipProvider);
    final dealerName = dealershipAsync.value?.name;
    final palette = Theme.of(context).extension<AppPalette>()!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StaggeredFadeIn(
            delay: Duration.zero,
            child: _Header(dealerName: dealerName, palette: palette),
          ),
          const SizedBox(height: AppDimensions.paddingXL),
          metricsAsync.when(
            data: (m) => _MetricsRow(metrics: m, palette: palette),
            loading: () => const _MetricsSkeleton(),
            error: (err, st) => _MetricsError(
              message: err.toString(),
              onRetry: () => retryDashboardMetrics(ref),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingXL),
          _StaggeredFadeIn(
            delay: const Duration(milliseconds: 200),
            child: const _ChartsRow(),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.dealerName, required this.palette});
  final String? dealerName;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back${dealerName != null ? ', $dealerName' : ''}',
          style: AppTextStyles.heading1.copyWith(
              color: palette.textPrimary, fontSize: 26),
        ),
        const SizedBox(height: 4),
        Text(
          "Here's your dealership overview",
          style: AppTextStyles.caption.copyWith(
              color: palette.textTertiary, fontSize: 13),
        ),
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.metrics, required this.palette});
  final DashboardMetrics metrics;
  final AppPalette palette;

  String get _formattedStockValue {
    final whole = metrics.grossStockValue.toStringAsFixed(0);
    return 'PKR ${whole.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCardData(icon: Icons.account_balance_wallet_outlined, display: _formattedStockValue, label: 'Gross Stock Value'),
      _MetricCardData(icon: Icons.groups_outlined, display: '${metrics.activeLeadsCount}', label: 'Active Leads'),
      _MetricCardData(icon: Icons.sell_outlined, display: '${metrics.soldThisMonth}', label: 'Cars Sold This Month'),
      _MetricCardData(icon: Icons.directions_car_filled_rounded, display: '${metrics.totalVehicles}', label: 'Total Vehicles'),
      _MetricCardData(icon: Icons.check_circle_outline_rounded, display: '${metrics.availableVehicles}', label: 'Available'),
      _MetricCardData(icon: Icons.bookmark_border_rounded, display: '${metrics.reservedVehicles}', label: 'Reserved'),
      _MetricCardData(icon: Icons.person_add_alt_1_rounded, display: '${metrics.newLeadsToday}', label: 'New Leads Today'),
    ];

    return Wrap(
      spacing: AppDimensions.paddingM,
      runSpacing: AppDimensions.paddingM,
      children: List.generate(cards.length, (i) {
        return SizedBox(
          width: 210,
          child: _StaggeredFadeIn(
            delay: Duration(milliseconds: 80 * (i + 1)),
            child: _MetricCard(data: cards[i], palette: palette),
          ),
        );
      }),
    );
  }
}

class _MetricCardData {
  const _MetricCardData({required this.icon, required this.display, required this.label});
  final IconData icon;
  final String display;
  final String label;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data, required this.palette});
  final _MetricCardData data;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
              color: palette.shadowColor.withValues(alpha: 0.35),
              blurRadius: 18, offset: const Offset(0, 6)),
          BoxShadow(
              color: palette.accent.withValues(alpha: 0.04),
              blurRadius: 40, spreadRadius: -4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: Icon(data.icon, color: palette.accent, size: 18),
          ),
          const SizedBox(height: AppDimensions.paddingL),
          Text(data.display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading1.copyWith(
                  color: palette.textPrimary, fontSize: 24)),
          const SizedBox(height: 4),
          Text(data.label,
              style: AppTextStyles.caption.copyWith(
                  color: palette.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ChartsRow extends ConsumerWidget {
  const _ChartsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueAsync = ref.watch(revenueMonthlyProvider);
    final agingAsync = ref.watch(inventoryAgingProvider);
    final conversionAsync = ref.watch(leadConversionRateProvider);
    final palette = Theme.of(context).extension<AppPalette>()!;

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 800;
      final charts = [
        _ChartCard(
          title: 'Revenue Trend',
          subtitle: 'Sold vehicles · last 6 months',
          icon: Icons.trending_up_rounded,
          accentColor: palette.accent,
          palette: palette,
          child: revenueAsync.when(
            data: (data) => data.isEmpty
                ? const _ChartEmpty(message: 'No sold vehicles yet')
                : _RevenueAreaChart(data: data, palette: palette),
            loading: () => const _ChartSkeleton(),
            error: (e, _) => _ChartError(message: e.toString()),
          ),
        ),
        _ChartCard(
          title: 'Inventory Status',
          subtitle: 'Live breakdown by status',
          icon: Icons.donut_large_rounded,
          accentColor: palette.statusAvailable,
          palette: palette,
          child: agingAsync.when(
            data: (data) => data.isEmpty
                ? const _ChartEmpty(message: 'No vehicles in inventory')
                : _InventoryDonutChart(data: data),
            loading: () => const _ChartSkeleton(),
            error: (e, _) => _ChartError(message: e.toString()),
          ),
        ),
        _ChartCard(
          title: 'Lead Conversion',
          subtitle: 'Closed won · % of all leads',
          icon: Icons.insights_rounded,
          accentColor: palette.accent,
          palette: palette,
          child: conversionAsync.when(
            data: (rate) => _LeadConversionGauge(rate: rate, palette: palette),
            loading: () => const _ChartSkeleton(),
            error: (e, _) => _ChartError(message: e.toString()),
          ),
        ),
      ];

      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: charts
              .asMap()
              .entries
              .map((e) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: e.key == charts.length - 1 ? 0 : AppDimensions.paddingM),
                      child: e.value,
                    ),
                  ))
              .toList(),
        );
      }
      return Column(
        children: [
          for (var i = 0; i < charts.length; i++) ...[
            if (i > 0) const SizedBox(height: AppDimensions.paddingM),
            charts[i],
          ],
        ],
      );
    });
  }
}

class _LeadConversionGauge extends StatelessWidget {
  const _LeadConversionGauge({required this.rate, required this.palette});
  final double rate;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: (rate / 100).clamp(0.0, 1.0),
                    strokeWidth: 10,
                    backgroundColor: palette.border,
                    valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                  ),
                ),
                Text('${rate.toStringAsFixed(0)}%',
                    style: AppTextStyles.heading1.copyWith(
                        color: palette.textPrimary, fontSize: 22)),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          Text('leads closed won',
              style: AppTextStyles.caption.copyWith(
                  color: palette.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.palette,
    required this.child,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final AppPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: accentColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28, offset: const Offset(0, 10)),
          BoxShadow(
              color: accentColor.withValues(alpha: 0.07),
              blurRadius: 50, spreadRadius: -6, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.bodyBold.copyWith(
                          color: palette.textPrimary, fontSize: 13.5)),
                  Text(subtitle,
                      style: AppTextStyles.caption.copyWith(
                          color: palette.textTertiary, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),
          SizedBox(height: 220, child: child),
        ],
      ),
    );
  }
}

class _RevenueAreaChart extends StatefulWidget {
  const _RevenueAreaChart({required this.data, required this.palette});
  final List<MonthlyRevenue> data;
  final AppPalette palette;

  @override
  State<_RevenueAreaChart> createState() => _RevenueAreaChartState();
}

class _RevenueAreaChartState extends State<_RevenueAreaChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final maxY = data.map((d) => d.revenue).fold(0.0, math.max) * 1.25;
    final fmt = NumberFormat.compact(locale: 'en_PK');
    final monthFmt = DateFormat('MMM');

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final spots = data.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), e.value.revenue * _anim.value);
        }).toList();

        return LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY == 0 ? 1 : maxY,
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  getTitlesWidget: (v, _) => Text(fmt.format(v),
                      style: const TextStyle(
                          color: Color(0xFF4A5568), fontSize: 9)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length)
                      return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(monthFmt.format(data[i].month),
                          style: const TextStyle(
                              color: Color(0xFF4A5568), fontSize: 9)),
                    );
                  },
                ),
              ),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (touchedSpot) => Colors.black87,
                getTooltipItems: (spots) => spots.map((s) {
                  final i = s.spotIndex;
                  if (i >= data.length) return null;
                  return LineTooltipItem(
                    'PKR ${NumberFormat('#,###').format(data[i].revenue)}\n${data[i].count} sold',
                    TextStyle(
                        color: widget.palette.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.4,
                color: widget.palette.accent,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3.5,
                    color: widget.palette.accent,
                    strokeWidth: 2,
                    strokeColor: Colors.black87,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      widget.palette.accent.withValues(alpha: 0.22),
                      widget.palette.accent.withValues(alpha: 0.0)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
          duration: Duration.zero,
        );
      },
    );
  }
}

class _InventoryDonutChart extends StatefulWidget {
  const _InventoryDonutChart({required this.data});
  final List<InventoryAgingBucket> data;

  @override
  State<_InventoryDonutChart> createState() => _InventoryDonutChartState();
}

class _InventoryDonutChartState extends State<_InventoryDonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _colorFor(String status, AppPalette palette) {
    switch (status) {
      case 'available':
        return palette.statusAvailable;
      case 'reserved':
        return palette.statusReserved;
      case 'sold':
        return palette.statusSold;
      default:
        return palette.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final total = data.fold(0, (s, b) => s + b.count);
    final palette = Theme.of(context).extension<AppPalette>()!;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Row(
          children: [
            Expanded(
              flex: 3,
              child: PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 3,
                  centerSpaceRadius: 52 * _anim.value,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        _touchedIndex = (event is FlTapUpEvent ||
                                event is FlPointerHoverEvent)
                            ? response?.touchedSection?.touchedSectionIndex
                            : null;
                      });
                    },
                  ),
                  sections: data.asMap().entries.map((e) {
                    final isTouched = _touchedIndex == e.key;
                    final color = _colorFor(e.value.status, palette);
                    final pct =
                        total == 0 ? 0.0 : e.value.count / total * 100;
                    return PieChartSectionData(
                      color: color,
                      value: e.value.count.toDouble(),
                      radius: (isTouched ? 52.0 : 44.0) * _anim.value,
                      showTitle: false,
                      borderSide: isTouched
                          ? BorderSide(color: color, width: 2)
                          : BorderSide(
                              color: color.withValues(alpha: 0.3), width: 0.5),
                      badgeWidget: isTouched
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: palette.surface,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 8)
                                ],
                              ),
                              child: Text(
                                '${pct.toStringAsFixed(0)}%',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            )
                          : null,
                      badgePositionPercentageOffset: 1.2,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.paddingM),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...data.map((b) {
                    final pct = total == 0 ? 0.0 : b.count / total * 100;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: _colorFor(b.status, palette),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.status[0].toUpperCase() +
                                      b.status.substring(1),
                                  style: AppTextStyles.caption.copyWith(
                                      color: palette.textSecondary,
                                      fontSize: 11),
                                ),
                                Text(
                                  '${b.count} (${pct.toStringAsFixed(0)}%)',
                                  style: AppTextStyles.caption.copyWith(
                                      color: _colorFor(b.status, palette)
                                          .withValues(alpha: 0.8),
                                      fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (total > 0) ...[
                    Divider(
                        color: palette.border, height: 16),
                    Text('Total: $total',
                        style: AppTextStyles.caption.copyWith(
                            color: palette.textTertiary, fontSize: 10)),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.bar_chart_outlined, color: palette.textTertiary, size: 32),
      const SizedBox(height: 8),
      Text(message,
          style: AppTextStyles.caption.copyWith(
              color: palette.textTertiary, fontSize: 11)),
    ]));
  }
}

class _ChartSkeleton extends StatefulWidget {
  const _ChartSkeleton();

  @override
  State<_ChartSkeleton> createState() => _ChartSkeletonState();
}

class _ChartSkeletonState extends State<_ChartSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.2, end: 0.45)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: _pulse.value),
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        ),
      ),
    );
  }
}

class _ChartError extends StatelessWidget {
  const _ChartError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Center(
      child: Text(message,
          style: AppTextStyles.caption.copyWith(
              color: palette.error, fontSize: 11),
          textAlign: TextAlign.center),
    );
  }
}

class _MetricsSkeleton extends StatefulWidget {
  const _MetricsSkeleton();

  @override
  State<_MetricsSkeleton> createState() => _MetricsSkeletonState();
}

class _MetricsSkeletonState extends State<_MetricsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.35, end: 0.65).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        return Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: i == 3 ? 0 : AppDimensions.paddingM),
                child: Container(
                  height: 132,
                  decoration: BoxDecoration(
                    color: palette.surface.withValues(alpha: _pulse.value),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusL),
                    border: Border.all(color: palette.border),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _MetricsError extends StatelessWidget {
  const _MetricsError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingXL),
      decoration: BoxDecoration(
        color: palette.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: palette.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: palette.error, size: 28),
          const SizedBox(height: AppDimensions.paddingS),
          Text('Could not load dashboard metrics',
              style: AppTextStyles.bodyBold.copyWith(
                  color: palette.textSecondary)),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                  color: palette.textTertiary)),
          const SizedBox(height: AppDimensions.paddingM),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded,
                size: 16, color: AppColors.ambientBlue),
            label: Text('Retry',
                style: AppTextStyles.body.copyWith(
                    color: AppColors.ambientBlue)),
          ),
        ],
      ),
    );
  }
}

class _StaggeredFadeIn extends StatefulWidget {
  const _StaggeredFadeIn({required this.child, required this.delay});
  final Widget child;
  final Duration delay;

  @override
  State<_StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<_StaggeredFadeIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
   Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      offset: _visible ? Offset.zero : const Offset(0, 0.06),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        opacity: _visible ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}