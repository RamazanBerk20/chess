import 'package:flutter/material.dart';

import 'package:chess/src/theme/spacing.dart';

/// A wrap of single-select [ChoiceChip]s over a list of options of type [T].
/// One styling source for every variant / time-control / difficulty / seat row
/// that used to be a hand-rolled `Wrap` per setup screen.
class ChoiceChipRow<T> extends StatelessWidget {
  final List<T> items;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  const ChoiceChipRow({
    super.key,
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final it in items)
          ChoiceChip(
            label: Text(labelOf(it)),
            selected: selected == it,
            onSelected: (_) => onSelected(it),
          ),
      ],
    );
  }
}
