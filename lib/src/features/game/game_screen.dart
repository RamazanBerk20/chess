import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/features/analysis/analysis_screen.dart';
import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/state/pgn.dart';
import 'package:chess/src/widgets/pgn_export.dart';
import 'package:chess/src/state/ai_provider.dart';
import 'package:chess/src/state/difficulty.dart';
import 'package:chess/src/state/game_mode.dart';
import 'package:chess/src/state/game_providers.dart';
import 'package:chess/src/state/l10n_labels.dart';
import 'package:chess/src/state/lan_controller.dart';
import 'package:chess/src/state/settings.dart';
import 'package:chess/src/widgets/board_widget.dart';
import 'package:chess/src/widgets/hand_tray.dart';
import 'package:chess/src/widgets/captured_tray.dart';
import 'package:chess/src/widgets/clock_widget.dart';
import 'package:chess/src/widgets/game_result_panel.dart';
import 'package:chess/src/widgets/move_list.dart';
import 'package:chess/src/widgets/promotion_dialog.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  // Whether a promotion picker is currently on screen, so it can be dismissed
  // if the game ends underneath it (e.g. a flag-fall while choosing a piece).
  bool _promoOpen = false;
  // Fog of War 2-player hot-seat: the colour currently allowed to see the board.
  PieceColor? _fogRevealedFor;

  @override
  void initState() {
    super.initState();
    // Kick off the engine's first reply when it is the side to move at the
    // start (AI plays White). Later replies are driven by the listener in build,
    // so there is no per-build trigger that would double-fire _maybeAiMove.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAiMove(ref));
  }

  void _showChat(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _ChatSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Surface the promotion picker when the engine asks for one, and dismiss it
    // if the game ends while it is still open.
    ref.listen<GameUiState>(gameControllerProvider, (prev, next) {
      if (next.pendingPromotion != null && prev?.pendingPromotion == null) {
        final color = next.view.sideToMove;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          _promoOpen = true;
          final choice = await showPromotionDialog(context, color);
          _promoOpen = false;
          if (!context.mounted) return;
          final c = ref.read(gameControllerProvider.notifier);
          if (choice == null) {
            c.cancelPromotion();
          } else {
            c.completePromotion(choice);
          }
        });
      }
      if (next.isOver && _promoOpen) {
        _promoOpen = false;
        Navigator.of(context).maybePop(); // close the stale promotion dialog
      }
    });

    final s = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final ai = ref.watch(aiControllerProvider);
    final mode = ref.watch(gameModeProvider);
    final t = AppLocalizations.of(context);
    // Face-to-face table play (2P same-device on mobile) handles orientation by
    // rotating the far side's pieces, so per-turn auto-flip is pointless there.
    final faceToFace =
        !mode.vsAi && !mode.lan && (Platform.isAndroid || Platform.isIOS);

    // In vs-AI mode, let the engine reply when it is its turn.
    ref.listen<GameUiState>(gameControllerProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAiMove(ref));
    });

    // Surface an incoming LAN draw offer.
    ref.listen<LanGameState>(lanProvider, (prev, next) {
      if (next.drawOfferIncoming && !(prev?.drawOfferIncoming ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final accept = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(t.drawOfferTitle),
              content: Text(t.drawOfferBody),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(t.decline)),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(t.accept)),
              ],
            ),
          );
          if (!context.mounted) return;
          ref.read(lanProvider.notifier).respondDraw(accept ?? false);
        });
      }
    });

    // Fog of War, same-device 2-player: hide the board between turns so the
    // next player can't see the previous player's view.
    final is2pFog = s.view.variant == GameVariant.fogOfWar &&
        !mode.vsAi &&
        !mode.lan;
    if (is2pFog && !s.isOver && _fogRevealedFor != s.view.sideToMove) {
      return _FogPassScreen(
        color: s.view.sideToMove,
        onReveal: () =>
            setState(() => _fogRevealedFor = s.view.sideToMove),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(mode.lan ? t.lanGame : t.game),
        actions: [
          if (mode.lan) ...[
            IconButton(
              tooltip: AppLocalizations.of(context).chat,
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => _showChat(context),
            ),
            IconButton(
              tooltip: t.offerDraw,
              icon: const Icon(Icons.handshake),
              onPressed: s.isOver
                  ? null
                  : () => ref.read(lanProvider.notifier).offerDraw(),
            ),
            IconButton(
              tooltip: t.resign,
              icon: const Icon(Icons.flag),
              onPressed: s.isOver
                  ? null
                  : () => ref.read(lanProvider.notifier).resign(),
            ),
          ],
          if (!mode.lan)
            IconButton(
              tooltip: t.aiMove,
              icon: ai.active
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.smart_toy),
              onPressed: (s.isOver || s.isBusy || ai.active)
                  ? null
                  : () {
                      final seed =
                          DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
                      ref.read(aiControllerProvider.notifier).requestMove(
                            config: Difficulty.medium.toConfig(seed),
                          );
                    },
            ),
          if (!mode.lan)
            IconButton(
              tooltip: t.saveGame,
              icon: const Icon(Icons.save_alt),
              onPressed: () async {
                final name = await _promptSaveName(context);
                if (name == null) return;
                controller.saveGame(name);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.gameSaved)),
                  );
                }
              },
            ),
          if (!mode.lan && !faceToFace)
            IconButton(
              tooltip: s.autoFlip ? t.autoFlipOn : t.autoFlipOff,
              icon: Icon(s.autoFlip ? Icons.sync : Icons.sync_disabled),
              onPressed:
                  (s.isBusy || ai.active) ? null : controller.toggleAutoFlip,
            ),
          IconButton(
            tooltip: t.flipBoard,
            icon: const Icon(Icons.flip),
            onPressed: (s.isBusy || ai.active) ? null : controller.toggleFlip,
          ),
          if (!mode.lan)
            IconButton(
              tooltip: t.takeBack,
              icon: const Icon(Icons.undo),
              onPressed: (s.isBusy || ai.active) ? null : controller.undo,
            ),
          if (!mode.lan)
            IconButton(
              tooltip: t.newGame,
              icon: const Icon(Icons.refresh),
              onPressed: (s.isBusy || ai.active) ? null : controller.newGame,
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 720;
            // Block input during a promotion choice. While the AI thinks in
            // vs-AI mode the board stays live for premoves; the 2P manual-AI
            // button still locks the board.
            final boardArea = AbsorbPointer(
              absorbing: s.isBusy || (ai.active && !mode.vsAi),
              child: _BoardArea(state: s),
            );
            final panel = _SidePanel(state: s);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Center(child: boardArea)),
                  SizedBox(width: 280, child: panel),
                ],
              );
            }
            return SingleChildScrollView(
              child: Column(
                children: [
                  boardArea,
                  SizedBox(height: 260, child: panel),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Prompt for a save name. Returns null if cancelled.
Future<String?> _promptSaveName(BuildContext context) {
  final t = AppLocalizations.of(context);
  final ctl = TextEditingController(text: t.myGame);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(t.saveGame),
      content: TextField(
        controller: ctl,
        autofocus: true,
        decoration: InputDecoration(labelText: t.name),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(c, ctl.text), child: Text(t.save)),
      ],
    ),
  );
}

/// Trigger an AI reply when it is the engine's turn in vs-AI mode.
void _maybeAiMove(WidgetRef ref) {
  final mode = ref.read(gameModeProvider);
  if (!mode.vsAi) return;
  final g = ref.read(gameControllerProvider);
  final ai = ref.read(aiControllerProvider);
  if (g.isOver || ai.active || g.isBusy) return;
  if (g.view.sideToMove == mode.aiColor) {
    final seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    ref
        .read(aiControllerProvider.notifier)
        .requestMove(config: mode.difficulty.toConfig(seed));
  }
}

class _BoardArea extends ConsumerWidget {
  final GameUiState state;
  const _BoardArea({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    final view = state.view;
    final flipped = state.isFlipped;
    final bottom = flipped ? PieceColor.black : PieceColor.white;
    final top = bottom == PieceColor.white ? PieceColor.black : PieceColor.white;
    final advWhite =
        materialAdvantage(view.capturedByWhite, view.capturedByBlack);

    Widget tray(PieceColor owner) {
      final captured = owner == PieceColor.white
          ? view.capturedByWhite
          : view.capturedByBlack;
      final adv = owner == PieceColor.white ? advWhite : -advWhite;
      return Row(
        children: [
          Expanded(
            child: CapturedTray(owner: owner, captured: captured, advantage: adv),
          ),
          PlayerClock(color: owner),
        ],
      );
    }

    // Crazyhouse reserve ("hand") rows, droppable by the side to move.
    final cz = view.variant == GameVariant.crazyhouse;
    final mode = ref.watch(gameModeProvider);
    final faceToFace =
        !mode.vsAi && !mode.lan && (Platform.isAndroid || Platform.isIOS);
    Widget handTray(PieceColor owner, bool upsideDown) {
      final counts = owner == PieceColor.white ? view.whiteHand : view.blackHand;
      final interactive = !state.isOver &&
          owner == view.sideToMove &&
          (!mode.vsAi || owner != mode.aiColor);
      return HandTray(
        owner: owner,
        counts: counts,
        interactive: interactive,
        selected: state.handPiece,
        onTap: controller.selectHand,
        upsideDown: upsideDown,
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        // Fixed-height tray rows keep the vertical chrome deterministic so the
        // board never overflows: 2*44 trays + 2*4 gaps + 2*8 padding = 112,
        // plus two reserve rows in Crazyhouse.
        const trayHeight = 44.0;
        const handHeight = 40.0;
        final chrome =
            trayHeight * 2 + 8 + 16 + (cz ? handHeight * 2 + 8 : 0.0);
        final side = (c.maxHeight.isFinite
                ? min(c.maxWidth - 16, c.maxHeight - chrome)
                : c.maxWidth - 16)
            .clamp(120.0, 1000.0);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: trayHeight, child: tray(top)),
                const SizedBox(height: 4),
                if (cz) ...[
                  SizedBox(height: handHeight, child: handTray(top, faceToFace)),
                  const SizedBox(height: 4),
                ],
                SizedBox(
                  width: side,
                  height: side,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final settings = ref.watch(settingsProvider);
                      final mode = ref.watch(gameModeProvider);
                      // Two players facing each other on a phone/tablet: rotate
                      // the far side's pieces so each reads them upright.
                      final faceToFace = !mode.vsAi &&
                          !mode.lan &&
                          (Platform.isAndroid || Platform.isIOS);
                      return BoardWidget(
                        view: state.view,
                        flipped: state.isFlipped,
                        selected: state.selected,
                        targets: state.targets,
                        animate: state.animateLast,
                        premoves: state.premoves,
                        premoveFrom: state.premoveFrom,
                        premoveTargets: state.premoveTargets,
                        light: settings.theme.light,
                        dark: settings.theme.dark,
                        showHints: settings.showHints,
                        animMs: settings.animationMs,
                        faceToFace: faceToFace,
                        fogMask: controller.fogMask(),
                        onTap: controller.tapSquare,
                        onDrop: controller.dragMove,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                if (cz) ...[
                  SizedBox(height: handHeight, child: handTray(bottom, false)),
                  const SizedBox(height: 4),
                ],
                SizedBox(height: trayHeight, child: tray(bottom)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Reserve-piece order matching the Rust hand index (Pawn..Queen).

class _SidePanel extends StatelessWidget {
  final GameUiState state;
  const _SidePanel({required this.state});

  @override
  Widget build(BuildContext context) {
    // Fog of War: the move list and the AI's line leak the opponent's hidden
    // moves — hide them while the game is in progress (revealed once it ends).
    final fogHide =
        state.view.variant == GameVariant.fogOfWar && !state.isOver;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusBanner(state: state),
          if (!fogHide) const _AiBanner(),
          if (state.isOver)
            Consumer(
              builder: (context, ref, _) {
                final mode = ref.read(gameModeProvider);
                final ctrl = ref.read(gameControllerProvider.notifier);
                return GameResultPanel(
                  onAnalyze: () {
                    final moves = ctrl.movesUci();
                    if (moves.isEmpty) return;
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AnalysisScreen(moves: moves),
                    ));
                  },
                  onPlayAgain: () {
                    if (mode.lan) {
                      Navigator.of(context).maybePop();
                    } else {
                      ctrl.newGame();
                    }
                  },
                  onMainMenu: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  onExportPgn: () => showPgnExport(
                    context,
                    buildPgn(
                      sanMoves: state.view.sanMoves,
                      status: state.view.status,
                      startFen: ctrl.startFen,
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          Expanded(
            child: fogHide
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_off,
                            size: 40, color: Colors.white38),
                        const SizedBox(height: 8),
                        Text(AppLocalizations.of(context).vFogOfWar,
                            style: const TextStyle(color: Colors.white54)),
                      ],
                    ),
                  )
                : MoveList(sanMoves: state.view.sanMoves),
          ),
        ],
      ),
    );
  }
}

class _ChatSheet extends ConsumerStatefulWidget {
  const _ChatSheet();
  @override
  ConsumerState<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<_ChatSheet> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _send() {
    ref.read(lanProvider.notifier).sendChat(_ctl.text);
    _ctl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final chat = ref.watch(lanProvider).chat;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: 360,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(t.chat,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
              child: chat.isEmpty
                  ? Center(
                      child: Text(t.typeMessage,
                          style: TextStyle(color: cs.outline)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: chat.length,
                      itemBuilder: (_, i) {
                        final m = chat[i];
                        return Align(
                          alignment: m.mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: m.mine
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(m.text),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctl,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: t.typeMessage,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiBanner extends ConsumerWidget {
  const _AiBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ai = ref.watch(aiControllerProvider);
    if (!ai.active) return const SizedBox.shrink();
    final eval = (ai.scoreCp / 100).toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ai.depth == 0
                    ? 'AI thinking…'
                    : 'AI: depth ${ai.depth}, eval $eval'
                        '${ai.pv.isNotEmpty ? '  ${ai.pv.take(4).join(' ')}' : ''}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final GameUiState state;
  const _StatusBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final view = state.view;
    final t = AppLocalizations.of(context);
    if (state.overlayResult != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          localizeLanResult(t, state.overlayResult!),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
    }
    String text;
    Color color = Theme.of(context).colorScheme.secondaryContainer;
    switch (view.status) {
      case GameOutcome.ongoing:
        final w = view.sideToMove == PieceColor.white;
        text = view.inCheck
            ? (w ? t.whiteToMoveCheck : t.blackToMoveCheck)
            : (w ? t.whiteToMove : t.blackToMove);
      case GameOutcome.whiteWins:
        text = t.checkmateWhiteWins;
        color = Colors.green.shade200;
      case GameOutcome.blackWins:
        text = t.checkmateBlackWins;
        color = Colors.green.shade200;
      case GameOutcome.whiteWinsOnTime:
        text = t.whiteWinsOnTime;
        color = Colors.green.shade200;
      case GameOutcome.blackWinsOnTime:
        text = t.blackWinsOnTime;
        color = Colors.green.shade200;
      case GameOutcome.stalemate:
        text = t.drawStalemate;
        color = Colors.amber.shade200;
      case GameOutcome.drawFiftyMove:
        text = t.drawFiftyMove;
        color = Colors.amber.shade200;
      case GameOutcome.drawThreefold:
        text = t.drawThreefold;
        color = Colors.amber.shade200;
      case GameOutcome.drawInsufficientMaterial:
        text = t.drawInsufficient;
        color = Colors.amber.shade200;
    }
    // Three-check: show each side's delivered-check tally.
    if (view.variant == GameVariant.threeCheck) {
      text = '$text  ·  ${t.checksLabel} ${view.whiteChecks}–${view.blackChecks}';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }
}

/// Fog of War (2-player hot-seat): a full-screen veil shown between turns so the
/// next player can't see the previous player's board. Tap to reveal.
class _FogPassScreen extends StatelessWidget {
  final PieceColor color;
  final VoidCallback onReveal;
  const _FogPassScreen({required this.color, required this.onReveal});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final name = color == PieceColor.white ? t.colourWhite : t.colourBlack;
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: GestureDetector(
        onTap: onReveal,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility_off, size: 72, color: Colors.white70),
              const SizedBox(height: 16),
              Text(
                t.fogPassDevice(name),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(t.fogTapReveal,
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
