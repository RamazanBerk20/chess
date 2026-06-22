import 'package:flutter/material.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/state/difficulty.dart';
import 'package:chess/src/state/l10n_labels.dart';
import 'package:chess/src/theme/spacing.dart';

/// Difficulty selector: preset chips + a Custom option exposing the five engine
/// weakening sliders. Emits the effective [Difficulty] via [onChanged].
/// Lifted from the old single-player setup so vs-Computer and Bughouse share it.
class DifficultyPicker extends StatefulWidget {
  final Difficulty initial;
  final ValueChanged<Difficulty> onChanged;
  const DifficultyPicker({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<DifficultyPicker> createState() => _DifficultyPickerState();
}

class _DifficultyPickerState extends State<DifficultyPicker> {
  late Difficulty _preset;
  bool _custom = false;
  int _depth = 5, _timeMs = 800, _topN = 2, _noise = 20;
  double _blunder = 0.05;

  @override
  void initState() {
    super.initState();
    _preset = widget.initial;
  }

  Difficulty get _effective => _custom
      ? Difficulty('Custom',
          maxDepth: _depth,
          moveTimeMs: _timeMs,
          evalNoise: _noise,
          blunderChance: _blunder,
          topNRandom: _topN)
      : _preset;

  void _emit() => widget.onChanged(_effective);

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
            for (final d in Difficulty.presets)
              ChoiceChip(
                label: Text(localizedDifficulty(t, d.name)),
                selected: !_custom && _preset.name == d.name,
                onSelected: (_) {
                  setState(() {
                    _custom = false;
                    _preset = d;
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
          _slider(t.searchDepth, _depth.toDouble(), 1, 12, '$_depth',
              (v) {
            setState(() => _depth = v.round());
            _emit();
          }),
          _slider(t.timePerMove, _timeMs.toDouble(), 100, 5000, '$_timeMs',
              (v) {
            setState(() => _timeMs = v.round());
            _emit();
          }),
          _slider(t.topNRandom, _topN.toDouble(), 1, 5, '$_topN', (v) {
            setState(() => _topN = v.round());
            _emit();
          }),
          _slider(t.blunderChance, _blunder, 0, 0.6,
              _blunder.toStringAsFixed(2), (v) {
            setState(() => _blunder = v);
            _emit();
          }),
          _slider(t.evalNoise, _noise.toDouble(), 0, 200, '$_noise', (v) {
            setState(() => _noise = v.round());
            _emit();
          }),
        ],
      ],
    );
  }

  Widget _slider(String label, double value, double min, double max,
      String display, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 130, child: Text('$label: $display')),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
