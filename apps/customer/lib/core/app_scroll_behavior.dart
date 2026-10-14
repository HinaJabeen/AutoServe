// lib/core/app_scroll_behavior.dart

import 'dart:ui';

import 'package:flutter/material.dart';

/// Flutter's default scroll behavior ignores mouse drags, so on a laptop
/// browser a PageView/carousel/list can't be dragged with the pointer the
/// way it can be swiped by touch. This opts every scrollable in the app into
/// mouse (and trackpad/stylus) dragging as well.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
