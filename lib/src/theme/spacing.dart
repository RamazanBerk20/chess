import 'package:flutter/widgets.dart';

/// Single spacing scale for the app, so padding/gaps are consistent instead of
/// ad-hoc `SizedBox(height: 8/12/16/24/28)` literals scattered per screen.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Common gaps (const so they can sit directly in child lists).
  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gap = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);

  static const EdgeInsets page = EdgeInsets.all(md);
}
