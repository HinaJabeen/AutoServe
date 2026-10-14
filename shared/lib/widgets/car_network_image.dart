import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_palette.dart';

/// A vehicle photo from a public URL, with a shimmer while it loads and a
/// car-icon fallback when there's no URL or it fails. Failures are printed
/// to the console (once per URL) so broken storage links are diagnosable.
class CarNetworkImage extends StatelessWidget {
  const CarNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.iconSize = 32,
  });

  final String? url;
  final BoxFit fit;
  final double iconSize;

  static final _loggedFailures = <String>{};

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fallback = ColoredBox(
      color: p.surface,
      child: Center(
        child: Icon(Icons.directions_car_rounded, size: iconSize, color: p.textTertiary),
      ),
    );

    final src = url;
    if (src == null || src.isEmpty) return fallback;

    return Image.network(
      src,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Shimmer.fromColors(
          baseColor: p.surface,
          highlightColor: p.border,
          child: ColoredBox(color: p.surface, child: const SizedBox.expand()),
        );
      },
      errorBuilder: (context, error, _) {
        if (_loggedFailures.add(src)) {
          debugPrint('CarNetworkImage: failed to load $src — $error');
        }
        return fallback;
      },
    );
  }
}
