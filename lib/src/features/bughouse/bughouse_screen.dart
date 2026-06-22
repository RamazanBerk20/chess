import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/state/bughouse_controller.dart';
import 'package:chess/src/state/bughouse_lan_controller.dart';
import 'package:chess/src/state/settings.dart';
import 'package:chess/src/widgets/board_widget.dart';
import 'package:chess/src/widgets/captured_tray.dart';
import 'package:chess/src/widgets/clock_widget.dart';
import 'package:chess/src/widgets/hand_tray.dart';
import 'package:chess/src/widgets/promotion_dialog.dart';

/// A two-board Bughouse match (local hot-seat or vs-AI).
class BughouseScreen extends ConsumerStatefulWidget {
  final BugConfig config;
  const BughouseScreen({super.key, required this.config});

  @override
  ConsumerState<BughouseScreen> createState() => _BughouseScreenState();
}

class _BughouseScreenState extends ConsumerState<BughouseScreen> {
  late final BughouseController _ctl;
  BugBoard _shown = BugBoard.a; // portrait toggle
  bool _promoOpen = false;

  @override
  void initState() {
    super.initState();
    _ctl = BughouseController(widget.config);
    if (widget.config.mode == BughouseMode.lan) {
      ref.read(bughouseLanProvider.notifier).register(_ctl);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  // Surface a promotion picker for whichever board is awaiting a choice.
  void _maybePromo() {
    if (_promoOpen) return;
    for (final board in BugBoard.values) {
      if (_ctl.pendingPromoOf(board) == null) continue;
      _promoOpen = true;
      final color = _ctl.viewOf(board).sideToMove;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final kind = await showPromotionDialog(context, color);
        _promoOpen = false;
        if (kind != null) {
          _ctl.completePromotion(board, kind);
        } else {
          _ctl.cancelPromotion(board);
        }
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.menuBughouse)),
      body: AnimatedBuilder(
        animation: _ctl,
        builder: (context, _) {
          _maybePromo();
          return Column(
            children: [
              if (_ctl.result != null) _ResultBanner(result: _ctl.result!),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final sideBySide =
                        c.maxWidth > c.maxHeight && c.maxWidth > 720;
                    if (sideBySide) {
                      return Row(
                        children: [
                          Expanded(child: _pane(BugBoard.a, settings)),
                          Expanded(child: _pane(BugBoard.b, settings)),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: SegmentedButton<BugBoard>(
                            segments: [
                              ButtonSegment(
                                  value: BugBoard.a, label: Text(t.bugBoardA)),
                              ButtonSegment(
                                  value: BugBoard.b, label: Text(t.bugBoardB)),
                            ],
                            selected: {_shown},
                            onSelectionChanged: (s) =>
                                setState(() => _shown = s.first),
                          ),
                        ),
                        Expanded(child: _pane(_shown, settings)),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pane(BugBoard board, Settings settings) {
    final t = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final view = _ctl.viewOf(board);
        final flipped = _ctl.flippedOf(board);
        final snap = _ctl.clockOf(board);
        final bottom = flipped ? PieceColor.black : PieceColor.white;
        final top = bottom == PieceColor.white
            ? PieceColor.black
            : PieceColor.white;
        final advWhite =
            materialAdvantage(view.capturedByWhite, view.capturedByBlack);

        const rowH = 38.0, handH = 40.0;
        final chrome = (rowH + handH) * 2 + 28;
        final side = (c.maxHeight.isFinite
                ? min(c.maxWidth - 12, c.maxHeight - chrome)
                : c.maxWidth - 12)
            .clamp(120.0, 900.0);

        Widget infoRow(PieceColor owner) {
          final captured = owner == PieceColor.white
              ? view.capturedByWhite
              : view.capturedByBlack;
          final adv = owner == PieceColor.white ? advWhite : -advWhite;
          return SizedBox(
            height: rowH,
            child: Row(
              children: [
                Expanded(
                  child: CapturedTray(
                      owner: owner, captured: captured, advantage: adv),
                ),
                ClockText(snap: snap, color: owner),
              ],
            ),
          );
        }

        Widget hand(PieceColor owner) {
          final counts = owner == PieceColor.white
              ? view.whiteHand
              : view.blackHand;
          final interactive =
              _ctl.humanToMove(board) && owner == view.sideToMove;
          return SizedBox(
            height: handH,
            child: HandTray(
              owner: owner,
              counts: counts,
              interactive: interactive,
              selected: _ctl.handPieceOf(board),
              onTap: (p) => _ctl.selectHand(board, p),
            ),
          );
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(board == BugBoard.a ? t.bugBoardA : t.bugBoardB,
                    style: Theme.of(context).textTheme.labelMedium),
                infoRow(top),
                hand(top),
                SizedBox(
                  width: side,
                  height: side,
                  child: BoardWidget(
                    view: view,
                    flipped: flipped,
                    selected: _ctl.selectedOf(board),
                    targets: _ctl.targetsOf(board),
                    premoves: _ctl.premovesOf(board),
                    premoveFrom: _ctl.premoveFromOf(board),
                    premoveTargets: _ctl.premoveTargetsOf(board),
                    light: settings.theme.light,
                    dark: settings.theme.dark,
                    showHints: settings.showHints,
                    animMs: settings.animationMs,
                    onTap: (sq) => _ctl.tapSquare(board, sq),
                    onDrop: (f, to) => _ctl.dragMove(board, f, to),
                  ),
                ),
                hand(bottom),
                infoRow(bottom),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final BugResult result;
  const _ResultBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.blue.shade200,
      child: Text(
        t.bugTeamWins(result.winningTeam.toString()),
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }
}
