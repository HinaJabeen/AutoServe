// lib/core/widgets/inspection_badge.dart

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// Collapsible inspection summary for the detail screen. Shows the overall
/// score plus whatever breakdown the dealer recorded in `inspection_details`
/// (engine / suspension scores, body condition, and any other keys).
class InspectionReport extends StatelessWidget {
  const InspectionReport({super.key, required this.car});
  final CarModel car;

  static const _labels = {'engine': 'Engine', 'suspension': 'Suspension', 'body': 'Body condition'};
  static const _order = ['engine', 'suspension', 'body'];

  static String _title(String key) =>
      _labels[key] ??
      key.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  @override
  Widget build(BuildContext context) {
    final score = car.inspectionScore;
    if (score == null) return const SizedBox.shrink();
    final p = context.palette;
    final details = car.inspectionDetails;
    final keys = [
      ..._order.where(details.containsKey),
      ...details.keys.where((k) => !_order.contains(k)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // ExpansionTile draws divider lines by default; the container is the frame.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.fact_check_outlined, color: p.accentSecondary),
          title: Text('Inspection Report',
              style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
          subtitle: Text('Overall ${score.toStringAsFixed(1)} / 10',
              style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
          childrenPadding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingM, 0, AppDimensions.paddingM, AppDimensions.paddingM),
          children: [
            _ScoreRow(label: 'Overall', value: score),
            if (keys.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.paddingS),
                child: Text('No detailed breakdown was provided.',
                    style: AppTextStyles.caption.copyWith(color: p.textTertiary)),
              ),
            for (final k in keys)
              switch (details[k]) {
                final num n => _ScoreRow(label: _title(k), value: n.toDouble()),
                final other => _TextRow(label: _title(k), value: '$other'),
              },
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.paddingS),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(label, style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / 10).clamp(0, 1),
              minHeight: 8,
              backgroundColor: p.border,
              color: value >= 8 ? p.accent : (value >= 5 ? p.warning : p.error),
            ),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text('${value.toStringAsFixed(1)}/10',
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary, fontSize: 13)),
        ),
      ]),
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.paddingS),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(label, style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary, fontSize: 13)),
        ),
      ]),
    );
  }
}

/// "AutoServe Inspected • 9.2/10". Renders nothing for an uninspected car.
class InspectionBadge extends StatelessWidget {
  const InspectionBadge({super.key, required this.car, this.compact = false, this.onDark = false});

  final CarModel car;

  /// Smaller variant for list tiles.
  final bool compact;

  /// Over a photo: solid fill so it stays legible on any image.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final score = car.inspectionScore;
    if (score == null) return const SizedBox.shrink();
    final p = context.palette;
    final label = compact
        ? 'Inspected ${score.toStringAsFixed(1)}/10'
        : 'AutoServe Inspected • ${score.toStringAsFixed(1)}/10';

    return Semantics(
      label: 'AutoServe inspected, score ${score.toStringAsFixed(1)} out of 10',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10, vertical: compact ? 2 : 5),
        decoration: BoxDecoration(
          color: onDark ? p.accent : p.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: onDark ? null : Border.all(color: p.accent.withValues(alpha: 0.45)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified_rounded,
              size: compact ? 12 : 15, color: onDark ? p.onAccent : p.accentSecondary),
          SizedBox(width: compact ? 3 : 5),
          Text(label,
              style: AppTextStyles.caption.copyWith(
                color: onDark ? p.onAccent : p.accentSecondary,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 10.5 : 12,
              )),
        ]),
      ),
    );
  }
}
