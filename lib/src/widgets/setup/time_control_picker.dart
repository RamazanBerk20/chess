import 'package:flutter/material.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/state/l10n_labels.dart';
import 'package:chess/src/state/time_control.dart';
import 'package:chess/src/theme/spacing.dart';

/// Time-control selector: preset chips + a Custom option (base minutes /
/// increment steppers). Emits the chosen [TimeControlOption] and whether it is
/// valid (custom base == 0 is invalid). Lifted from the old two-player setup.
class TimeControlPicker extends StatefulWidget {
  final TimeControlOption initial;
  final void Function(TimeControlOption tc, bool valid) onChanged;
  const TimeControlPicker({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<TimeControlPicker> createState() => _TimeControlPickerState();
}

class _TimeControlPickerState extends State<TimeControlPicker> {
  late TimeControlOption _preset;
  bool _custom = false;
  int _baseMin = 10, _incSec = 0;

  @override
  void initState() {
    super.initState();
    _preset = widget.initial;
  }

  bool get _valid => !_custom || _baseMin > 0;
  TimeControlOption get _effective => _custom
      ? TimeControlOption('$_baseMin+$_incSec', _baseMin, _incSec)
      : _preset;

  void _emit() => widget.onChanged(_effective, _valid);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final p in TimeControlOption.presets)
              ChoiceChip(
                label: Text(localizedTc(t, p.label)),
                selected: !_custom && _preset.label == p.label,
                onSelected: (_) {
                  setState(() {
                    _custom = false;
                    _preset = p;
                  });
                  _emit();
                },
              ),
            ChoiceChip(
              label: Text(t.custom),
              selected: _custom,
              onSelected: (_) {
                setState(() => _custom = true);
                _emit();
              },
            ),
          ],
        ),
        if (_custom) ...[
          AppSpacing.gap,
          _stepper(t.baseMinutes, _baseMin, 0, 180, (v) {
            setState(() => _baseMin = v);
            _emit();
          }),
          _stepper(t.incrementSeconds, _incSec, 0, 60, (v) {
            setState(() => _incSec = v);
            _emit();
          }),
          if (!_valid)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(t.baseTimeError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ],
    );
  }

  Widget _stepper(
      String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Row(
      children: [
        Expanded(child: Text('$label: $value')),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
