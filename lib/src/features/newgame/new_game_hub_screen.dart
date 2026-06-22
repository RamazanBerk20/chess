import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/features/setup/bughouse_setup_screen.dart' as bh;
import 'package:chess/src/features/four/four_setup_screen.dart';
import 'package:chess/src/features/game/game_screen.dart';
import 'package:chess/src/features/setup/lan_setup_screen.dart';
import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/state/clock_provider.dart';
import 'package:chess/src/state/difficulty.dart';
import 'package:chess/src/state/game_mode.dart';
import 'package:chess/src/state/game_providers.dart';
import 'package:chess/src/state/l10n_labels.dart';
import 'package:chess/src/state/settings.dart';
import 'package:chess/src/state/time_control.dart';
import 'package:chess/src/theme/spacing.dart';
import 'package:chess/src/widgets/setup/choice_chip_row.dart';
import 'package:chess/src/widgets/setup/difficulty_picker.dart';
import 'package:chess/src/widgets/setup/mode_card.dart';
import 'package:chess/src/widgets/setup/setup_section.dart';
import 'package:chess/src/widgets/setup/time_control_picker.dart';

const _standardFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Which side the human plays in vs-Computer.
enum _Side { white, black, random }

/// The single hub all games start from. Common modes (vs Computer, Two Players,
/// Custom Position) configure inline on shared widgets; the advanced networked /
/// multi-board modes (LAN, Bughouse, 4-Player) are first-class cards that open
/// their own setup screens. Replaces the scattered setup screens + hidden chips.
enum HubMode { computer, twoPlayer, custom, lan, bughouse, fourPlayer }

class NewGameHubScreen extends ConsumerStatefulWidget {
  const NewGameHubScreen({super.key});

  @override
  ConsumerState<NewGameHubScreen> createState() => _NewGameHubScreenState();
}

class _NewGameHubScreenState extends ConsumerState<NewGameHubScreen> {
  HubMode _mode = HubMode.computer;
  GameVariant _variant = GameVariant.standard;
  _Side _side = _Side.white;
  Difficulty _difficulty = Difficulty.medium;
  TimeControlOption _tc = TimeControlOption.infinite;
  bool _tcValid = true;
  final _fenCtl = TextEditingController();
  String? _fenError;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _tc = TimeControlOption.presets.firstWhere(
      (p) => p.label == s.defaultTc,
      orElse: () => TimeControlOption.infinite,
    );
    _difficulty = Difficulty.presets.firstWhere(
      (d) => d.name == s.defaultDifficulty,
      orElse: () => Difficulty.medium,
    );
  }

  @override
  void dispose() {
    _fenCtl.dispose();
    super.dispose();
  }

  void _push(Widget screen) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => screen));

  void _toGame() => Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );

  void _startComputer() {
    final aiColor = switch (_side) {
      _Side.white => PieceColor.black,
      _Side.black => PieceColor.white,
      _Side.random =>
        Random().nextBool() ? PieceColor.white : PieceColor.black,
    };
    ref.read(gameModeProvider.notifier).setVsAi(aiColor, _difficulty);
    ref.read(selectedTimeControlProvider.notifier).set(_tc);
    ref.read(customStartFenProvider.notifier).set(null);
    ref.read(selectedVariantProvider.notifier).set(_variant);
    ref.invalidate(gameControllerProvider);
    ref.invalidate(clockProvider);
    _toGame();
  }

  void _startTwoPlayer() {
    ref.read(gameModeProvider.notifier).setTwoPlayer();
    ref.read(selectedTimeControlProvider.notifier).set(_tc);
    ref.read(customStartFenProvider.notifier).set(null);
    ref.read(selectedVariantProvider.notifier).set(_variant);
    ref.invalidate(gameControllerProvider);
    ref.invalidate(clockProvider);
    _toGame();
  }

  bool _isValidFen(String fen) {
    try {
      ChessGame.fromFen(fen: fen);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _loadCustom(AppLocalizations t) {
    final fen = _fenCtl.text.trim();
    if (fen.isEmpty || !_isValidFen(fen)) {
      setState(() => _fenError = t.invalidFen);
      return;
    }
    ref.read(gameModeProvider.notifier).setTwoPlayer();
    ref.read(selectedTimeControlProvider.notifier).set(TimeControlOption.infinite);
    ref.read(customStartFenProvider.notifier).set(fen);
    ref.read(selectedVariantProvider.notifier).set(GameVariant.standard);
    ref.invalidate(gameControllerProvider);
    ref.invalidate(clockProvider);
    _toGame();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.newGame)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > 720;
            final modes = _modeList(t);
            final options = _options(t);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 300,
                    child: SingleChildScrollView(
                      padding: AppSpacing.page,
                      child: modes,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: AppSpacing.page,
                      child: options,
                    ),
                  ),
                ],
              );
            }
            return SingleChildScrollView(
              padding: AppSpacing.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [modes, AppSpacing.gapLg, options],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _modeList(AppLocalizations t) {
    Widget card(HubMode m, IconData icon, String label,
            {bool chevron = false, VoidCallback? onTap}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ModeCard(
            icon: icon,
            label: label,
            selected: !chevron && _mode == m,
            chevron: chevron,
            onTap: onTap ?? () => setState(() => _mode = m),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(HubMode.computer, Icons.smart_toy, t.menuSinglePlayer),
        card(HubMode.twoPlayer, Icons.people, t.menuTwoPlayers),
        card(HubMode.custom, Icons.dashboard_customize, t.menuPlayFromPosition),
        card(HubMode.lan, Icons.wifi, t.menuLan,
            chevron: true, onTap: () => _push(const LanSetupScreen())),
        card(HubMode.bughouse, Icons.swap_horiz, t.menuBughouse,
            chevron: true, onTap: () => _push(const bh.BughouseSetupScreen())),
        card(HubMode.fourPlayer, Icons.grid_4x4, t.menuFourPlayer,
            chevron: true, onTap: () => _push(const FourSetupScreen())),
      ],
    );
  }

  Widget _options(AppLocalizations t) {
    switch (_mode) {
      case HubMode.computer:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SetupSection(
              title: t.variant,
              child: ChoiceChipRow<GameVariant>(
                items: playableVariants,
                selected: _variant,
                labelOf: (v) => localizedVariant(t, v),
                onSelected: (v) => setState(() => _variant = v),
              ),
            ),
            SetupSection(
              title: t.playAs,
              child: SegmentedButton<_Side>(
                segments: [
                  ButtonSegment(value: _Side.white, label: Text(t.colourWhite)),
                  ButtonSegment(value: _Side.black, label: Text(t.colourBlack)),
                  ButtonSegment(
                      value: _Side.random, label: Text(t.colourRandom)),
                ],
                selected: {_side},
                onSelectionChanged: (s) => setState(() => _side = s.first),
              ),
            ),
            SetupSection(
              title: t.difficulty,
              child: DifficultyPicker(
                initial: _difficulty,
                onChanged: (d) => _difficulty = d,
              ),
            ),
            SetupSection(
              title: t.timeControl,
              child: TimeControlPicker(
                initial: _tc,
                onChanged: (tc, valid) => setState(() {
                  _tc = tc;
                  _tcValid = valid;
                }),
              ),
            ),
            _startButton(t.startGame, _tcValid ? _startComputer : null),
          ],
        );
      case HubMode.twoPlayer:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SetupSection(
              title: t.variant,
              child: ChoiceChipRow<GameVariant>(
                items: playableVariants,
                selected: _variant,
                labelOf: (v) => localizedVariant(t, v),
                onSelected: (v) => setState(() => _variant = v),
              ),
            ),
            SetupSection(
              title: t.timeControl,
              child: TimeControlPicker(
                initial: _tc,
                onChanged: (tc, valid) => setState(() {
                  _tc = tc;
                  _tcValid = valid;
                }),
              ),
            ),
            _startButton(t.startGame, _tcValid ? _startTwoPlayer : null),
          ],
        );
      case HubMode.custom:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SetupSection(
              title: t.pasteFen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _fenCtl,
                    maxLines: 2,
                    autocorrect: false,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: t.fenHint,
                      errorText: _fenError,
                    ),
                    onChanged: (_) {
                      if (_fenError != null) setState(() => _fenError = null);
                    },
                  ),
                  AppSpacing.gapSm,
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt),
                    label: Text(t.useStartPosition),
                    onPressed: () => setState(() {
                      _fenCtl.text = _standardFen;
                      _fenError = null;
                    }),
                  ),
                ],
              ),
            ),
            _startButton(t.loadPosition, () => _loadCustom(t)),
          ],
        );
      case HubMode.lan:
      case HubMode.bughouse:
      case HubMode.fourPlayer:
        return const SizedBox.shrink(); // these navigate to their own screens
    }
  }

  Widget _startButton(String label, VoidCallback? onPressed) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.play_arrow),
          label: Text(label),
        ),
      );
}
