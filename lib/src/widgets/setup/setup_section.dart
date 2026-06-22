import 'package:flutter/material.dart';

import 'package:chess/src/theme/spacing.dart';

/// A titled options section: a small uppercase header + its content, with a
/// consistent gap below. Replaces the per-screen `_heading()` helpers.
class SetupSection extends StatelessWidget {
  final String title;
  final Widget child;
  const SetupSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
        ),
        AppSpacing.gapSm,
        child,
        AppSpacing.gapLg,
      ],
    );
  }
}
