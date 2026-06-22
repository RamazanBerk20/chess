import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/features/game/game_screen.dart';
import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/rust/api/net.dart';
import 'package:chess/src/state/l10n_labels.dart';
import 'package:chess/src/state/lan_controller.dart';
import 'package:chess/src/state/time_control.dart';

enum _HostColor { white, black, random }

class LanSetupScreen extends ConsumerStatefulWidget {
  const LanSetupScreen({super.key});

  @override
  ConsumerState<LanSetupScreen> createState() => _LanSetupScreenState();
}

class _LanSetupScreenState extends ConsumerState<LanSetupScreen> {
  final _nameCtl = TextEditingController(text: 'Player');
  TimeControlOption _tc = const TimeControlOption('5+2', 5, 2);
  _HostColor _color = _HostColor.random; // host's chosen colour
  GameVariant _variant = GameVariant.standard;
  final Map<String, NetHost> _hosts = {};
  StreamSubscription<NetHost>? _browseSub;

  @override
  void initState() {
    super.initState();
    _browseSub = netBrowse().listen((h) {
      setState(() => _hosts[h.addr] = h);
    });
  }

  @override
  void dispose() {
    _browseSub?.cancel();
    netStopBrowse();
    _nameCtl.dispose();
    super.dispose();
  }

  String get _name => _nameCtl.text.trim().isEmpty ? 'Player' : _nameCtl.text.trim();

  String _colorLabel(AppLocalizations t, _HostColor c) => switch (c) {
        _HostColor.white => t.colourWhite,
        _HostColor.black => t.colourBlack,
        _HostColor.random => t.colourRandom,
      };

  @override
  Widget build(BuildContext context) {
    // Navigate into the game once connected.
    ref.listen<LanGameState>(lanProvider, (prev, next) {
      if (next.connected && (prev == null || !prev.connected)) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GameScreen()),
        );
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    final lan = ref.watch(lanProvider);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.lanTitle)),
      body: lan.waiting
          ? _Waiting(onCancel: () => ref.read(lanProvider.notifier).leave())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _nameCtl,
                  decoration: InputDecoration(
                    labelText: t.yourName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(t.hostAGame,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in TimeControlOption.presets)
                      ChoiceChip(
                        label: Text(localizedTc(t, p.label)),
                        selected: _tc.label == p.label,
                        onSelected: (_) => setState(() => _tc = p),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(t.variant, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in playableVariants)
                      ChoiceChip(
                        label: Text(localizedVariant(t, v)),
                        selected: _variant == v,
                        onSelected: (_) => setState(() => _variant = v),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(t.yourColour,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in _HostColor.values)
                      ChoiceChip(
                        label: Text(_colorLabel(t, c)),
                        selected: _color == c,
                        onSelected: (_) => setState(() => _color = c),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.wifi_tethering),
                  label: Text(t.hostGame),
                  onPressed: () {
                    final hostWhite = switch (_color) {
                      _HostColor.white => true,
                      _HostColor.black => false,
                      _HostColor.random => Random().nextBool(),
                    };
                    ref.read(lanProvider.notifier).host(
                          _name,
                          _tc.baseMinutes ?? 0,
                          _tc.incrementSeconds,
                          hostWhite,
                          _variant,
                          _variant == GameVariant.chess960
                              ? Random().nextInt(960)
                              : 0,
                        );
                  },
                ),
                const Divider(height: 40),
                Text(t.joinOnNetwork,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_hosts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Text(t.searchingHosts),
                      ],
                    ),
                  ),
                for (final h in _hosts.values)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.computer),
                      title: Text(h.name),
                      subtitle: Text('${h.addr}  ·  ${h.timeControl}'),
                      trailing: const Icon(Icons.login),
                      onTap: () =>
                          ref.read(lanProvider.notifier).join(h.addr, _name),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Waiting extends StatelessWidget {
  final VoidCallback onCancel;
  const _Waiting({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(t.waitingOpponent),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onCancel, child: Text(t.cancel)),
        ],
      ),
    );
  }
}
