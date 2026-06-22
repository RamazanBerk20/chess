import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A selectable time control. `baseMinutes == null` means no clock (Infinite).
class TimeControlOption {
  final String label;
  final int? baseMinutes;
  final int incrementSeconds;

  const TimeControlOption(this.label, this.baseMinutes, this.incrementSeconds);

  bool get isInfinite => baseMinutes == null;

  static const infinite = TimeControlOption('Infinite', null, 0);

  /// Presets from the build spec (§6).
  static const presets = <TimeControlOption>[
    infinite,
    TimeControlOption('1+0', 1, 0),
    TimeControlOption('3+2', 3, 2),
    TimeControlOption('5+0', 5, 0),
    TimeControlOption('5+2', 5, 2),
    TimeControlOption('10+0', 10, 0),
    TimeControlOption('10+5', 10, 5),
    TimeControlOption('15+10', 15, 10),
    TimeControlOption('30+0', 30, 0),
  ];
}

/// The time control the next/current game uses. The setup screen sets it; the
/// game and clock controllers read it.
final selectedTimeControlProvider =
    NotifierProvider<SelectedTimeControl, TimeControlOption>(
        SelectedTimeControl.new);

class SelectedTimeControl extends Notifier<TimeControlOption> {
  @override
  TimeControlOption build() => TimeControlOption.infinite;

  void set(TimeControlOption tc) => state = tc;
}
