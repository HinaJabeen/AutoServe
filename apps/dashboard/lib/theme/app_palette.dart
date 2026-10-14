// lib/theme/app_palette.dart
//
// Moved to shared/lib/theme/app_palette.dart so apps/customer (Module 2) can
// use the same light palette for its storefront theme. Re-exported here so
// every existing relative import in this app keeps working unchanged.

export 'package:shared/shared.dart' show AppPalette, AppPaletteContext;
