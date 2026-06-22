import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/state/puzzle_controller.dart';
import 'package:chess/src/state/settings.dart';
import 'package:chess/src/widgets/board_widget.dart';

class PuzzleScreen extends ConsumerWidget {
  const PuzzleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(puzzleControllerProvider);
    final ctrl = ref.read(puzzleControllerProvider.notifier);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.menuPuzzles),
        actions: [
          async.maybeWhen(
            data: (s) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text(t.puzzlesSolved(s.solvedCount, s.total))),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${t.loadPuzzlesFailed}: $e')),
        data: (s) => _PuzzleBody(state: s, ctrl: ctrl),
      ),
    );
  }
}

class _PuzzleBody extends StatelessWidget {
  final PuzzleUiState state;
  final PuzzleController ctrl;
  const _PuzzleBody({required this.state, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Banner(state: state),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Consumer(
                builder: (context, ref, _) {
                  final settings = ref.watch(settingsProvider);
                  return BoardWidget(
                    view: state.view,
                    flipped: state.flipped,
                    selected: state.selected,
                    targets: state.targets,
                    light: settings.theme.light,
                    dark: settings.theme.dark,
                    showHints: settings.showHints,
                    animMs: settings.animationMs,
                    onTap: ctrl.tapSquare,
                    onDrop: ctrl.dragMove,
                  );
                },
              ),
            ),
          ),
        ),
        _Controls(state: state, ctrl: ctrl),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final PuzzleUiState state;
  const _Banner({required this.state});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final whiteToMove = state.puzzle.sideToMove == 'white';
    String text;
    Color color = Theme.of(context).colorScheme.secondaryContainer;
    switch (state.status) {
      case PuzzleStatus.solving:
        text = (whiteToMove ? t.whiteToMove : t.blackToMove) +
            (state.alreadySolved ? '  ✓ ${t.alreadySolved}' : '');
      case PuzzleStatus.wrong:
        text = t.puzzleWrong;
        color = Colors.red.shade200;
      case PuzzleStatus.solved:
        text = t.puzzleSolvedMsg;
        color = Colors.green.shade200;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: color,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final PuzzleUiState state;
  final PuzzleController ctrl;
  const _Controls({required this.state, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.puzzleFooter(state.index + 1, state.total, state.puzzle.rating,
                state.currentStreak, state.bestStreak),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: t.previous,
                icon: const Icon(Icons.chevron_left),
                onPressed: state.index > 0 ? ctrl.prev : null,
              ),
              IconButton(
                tooltip: t.hint,
                icon: const Icon(Icons.lightbulb_outline),
                onPressed: state.status == PuzzleStatus.solved ? null : ctrl.hint,
              ),
              IconButton(
                tooltip: t.restartPuzzle,
                icon: const Icon(Icons.refresh),
                onPressed: ctrl.retry,
              ),
              IconButton(
                tooltip: t.next,
                icon: const Icon(Icons.chevron_right),
                onPressed: state.index < state.total - 1 ? ctrl.next : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
