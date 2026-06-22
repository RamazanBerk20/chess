import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/rust/api/four.dart';
import 'package:chess/src/state/four_lan_controller.dart';
import 'package:chess/src/state/four_player_controller.dart';
import 'package:chess/src/widgets/four_board_widget.dart';
import 'package:chess/src/widgets/four_pieces.dart';

String localizedFourColor(AppLocalizations t, FourPlayer p) => switch (p) {
      FourPlayer.red => t.fourRed,
      FourPlayer.blue => t.fourBlue,
      FourPlayer.yellow => t.fourYellow,
      FourPlayer.green => t.fourGreen,
    };

class FourPlayerScreen extends ConsumerStatefulWidget {
  final FourConfig config;
  const FourPlayerScreen({super.key, required this.config});

  @override
  ConsumerState<FourPlayerScreen> createState() => _FourPlayerScreenState();
}

class _FourPlayerScreenState extends ConsumerState<FourPlayerScreen> {
  late final FourPlayerController _ctl;
  bool _promoOpen = false;

  @override
  void initState() {
    super.initState();
    _ctl = FourPlayerController(widget.config);
    if (widget.config.mode == FourMode.lan) {
      ref.read(fourLanProvider.notifier).register(_ctl);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _maybePromo() {
    if (_promoOpen || _ctl.pendingPromo == null) return;
    _promoOpen = true;
    final color = _ctl.view().turn;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final kind = await _showFourPromotion(context, color);
      _promoOpen = false;
      if (kind != null) {
        _ctl.completePromotion(kind);
      } else {
        _ctl.cancelPromotion();
      }
    });
  }

  String _resultText(AppLocalizations t, String result) {
    if (result.startsWith('team:')) {
      final winners = result == 'team:red_yellow'
          ? '${t.fourRed} + ${t.fourYellow}'
          : '${t.fourBlue} + ${t.fourGreen}';
      return t.fourTeamWins(winners);
    }
    if (result.startsWith('ffa:')) {
      final code = result.substring(4);
      final p = switch (code) {
        'red' => FourPlayer.red,
        'blue' => FourPlayer.blue,
        'yellow' => FourPlayer.yellow,
        _ => FourPlayer.green,
      };
      return t.fourWins(localizedFourColor(t, p));
    }
    return t.menuFourPlayer; // forfeit / unknown → generic
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.menuFourPlayer)),
      body: AnimatedBuilder(
        animation: _ctl,
        builder: (context, _) {
          _maybePromo();
          final v = _ctl.view();
          final result = _ctl.resultString();
          final over = result != 'ongoing';
          return Column(
            children: [
              if (over)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.shade200,
                  child: Text(
                    _resultText(t, result),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final p in v.players) _PlayerChip(t: t, panel: p, turn: v.turn),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: FourBoardWidget(
                      view: v,
                      selected: _ctl.selected,
                      targets: _ctl.targets,
                      premoves: _ctl.premoves,
                      premoveFrom: _ctl.premoveFrom,
                      premoveTargets: _ctl.premoveTargets,
                      onTap: _ctl.tapSquare,
                      onDrop: _ctl.dragMove,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final AppLocalizations t;
  final FourPlayerPanel panel;
  final FourPlayer turn;
  const _PlayerChip({required this.t, required this.panel, required this.turn});

  @override
  Widget build(BuildContext context) {
    final color = fourColors[panel.player]!;
    final isTurn = panel.player == turn;
    final dead = panel.status != FourPlayerStatus.active;
    final tag = switch (panel.status) {
      FourPlayerStatus.checkmated => ' #',
      FourPlayerStatus.stalemated => ' ½',
      FourPlayerStatus.resigned => ' ✕',
      FourPlayerStatus.active => panel.inCheck ? ' +' : '',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dead ? 0.25 : 0.85),
        borderRadius: BorderRadius.circular(8),
        border: isTurn
            ? Border.all(color: Colors.white, width: 2)
            : Border.all(color: Colors.transparent, width: 2),
      ),
      child: Text(
        '${localizedFourColor(t, panel.player)}  ${panel.score}$tag',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          decoration: dead ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

Future<FourPieceKind?> _showFourPromotion(BuildContext context, FourPlayer color) {
  const choices = [
    FourPieceKind.queen,
    FourPieceKind.rook,
    FourPieceKind.bishop,
    FourPieceKind.knight,
  ];
  return showDialog<FourPieceKind>(
    context: context,
    builder: (context) => AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final k in choices)
            IconButton(
              iconSize: 48,
              onPressed: () => Navigator.of(context).pop(k),
              icon: FourPieceGlyph(player: color, kind: k, size: 44),
            ),
        ],
      ),
    ),
  );
}
