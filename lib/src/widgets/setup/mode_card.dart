import 'package:flutter/material.dart';

import 'package:chess/src/theme/spacing.dart';

/// A selectable game-mode card for the New Game hub. Flat by default; the
/// selected card fills with the primary container colour.
class ModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;

  /// Shows a trailing chevron, signalling the card navigates to its own screen
  /// (advanced modes) rather than revealing inline options.
  final bool chevron;
  final VoidCallback onTap;
  const ModeCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.chevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.primaryContainer : cs.surface;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurface;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? cs.primary : cs.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: selected
                                  ? fg.withValues(alpha: 0.8)
                                  : cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (chevron)
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
