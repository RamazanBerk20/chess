import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/features/bughouse/bughouse_lobby_screen.dart';
import 'package:chess/src/features/bughouse/bughouse_screen.dart';
import 'package:chess/src/rust/api/net.dart';
import 'package:chess/src/state/bughouse_controller.dart';
import 'package:chess/src/state/bughouse_lan_controller.dart';
import 'package:chess/src/state/difficulty.dart';
import 'package:chess/src/state/l10n_labels.dart';
import 'package:chess/src/state/time_control.dart';

const _bhPrefix = '[BH] ';

const _difficulties = [
  Difficulty.beginner,
  Difficulty.easy,
  Difficulty.medium,
  Difficulty.hard,
  Difficulty.expert,
];

class BughouseSetupScreen extends ConsumerStatefulWidget {
  const BughouseSetupScreen({super.key});

  @override
  ConsumerState<BughouseSetupScreen> createState() =>
      _BughouseSetupScreenState();
}

class _BughouseSetupScreenState extends ConsumerState<BughouseSetupScreen> {
  BughouseMode _mode = BughouseMode.hotSeat;
  TimeControlOption _tc = TimeControlOption.infinite;
  Difficulty _difficulty = Difficulty.medium;
  BugSeat _seat = BugSeat.aWhite;
  final _nameCtl = TextEditingController(text: 'Player');
  final List<NetHost> _hosts = [];
  StreamSubscription<NetHost>? _browse;

  @override
  void dispose() {
    _browse?.cancel();
    netStopBrowse();
    _nameCtl.dispose();
    super.dispose();
  }

  void _startBrowse() {
    if (_browse != null) return;
    _hosts.clear();
    _browse = netBrowse().listen((h) {
      if (!h.name.startsWith(_bhPrefix)) return; // Bughouse hosts only
      if (_hosts.any((e) => e.addr == h.addr)) return;
      setState(() => _hosts.add(h));
    });
  }

  void _stopBrowse() {
    _browse?.cancel();
    _browse = null;
    netStopBrowse();
    _hosts.clear();
  }

  void _hostLan() {
    ref.read(bughouseLanProvider.notifier).host(_nameCtl.text.trim());
    _stopBrowse();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BughouseLobbyScreen()),
    );
  }

  void _joinLan(NetHost h) {
    ref.read(bughouseLanProvider.notifier).join(h.addr, _nameCtl.text.trim());
    _stopBrowse();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BughouseLobbyScreen()),
    );
  }

  String _seatLabel(AppLocalizations t, BugSeat s) => switch (s) {
        BugSeat.aWhite => '${t.bugBoardA} · ${t.bugWhite}',
        BugSeat.aBlack => '${t.bugBoardA} · ${t.bugBlack}',
        BugSeat.bWhite => '${t.bugBoardB} · ${t.bugWhite}',
        BugSeat.bBlack => '${t.bugBoardB} · ${t.bugBlack}',
      };

  void _start() {
    final config = BugConfig(
      mode: _mode,
      tc: _tc,
      humanSeats: _mode == BughouseMode.vsAi
          ? {_seat}
          : BugSeat.values.toSet(),
      difficulty: _difficulty,
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BughouseScreen(config: config)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    Widget heading(String s) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(s, style: Theme.of(context).textTheme.titleMedium),
        );

    return Scaffold(
      appBar: AppBar(title: Text(t.menuBughouse)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          heading(t.bugMode),
          SegmentedButton<BughouseMode>(
            segments: [
              ButtonSegment(
                  value: BughouseMode.hotSeat, label: Text(t.bugHotSeat)),
              ButtonSegment(value: BughouseMode.vsAi, label: Text(t.bugVsAi)),
              ButtonSegment(value: BughouseMode.lan, label: Text(t.bugLan)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) {
              setState(() => _mode = s.first);
              if (_mode == BughouseMode.lan) {
                _startBrowse();
              } else {
                _stopBrowse();
              }
            },
          ),
          if (_mode == BughouseMode.vsAi) ...[
            heading(t.bugYourSeat),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in BugSeat.values)
                  ChoiceChip(
                    label: Text(_seatLabel(t, s)),
                    selected: _seat == s,
                    onSelected: (_) => setState(() => _seat = s),
                  ),
              ],
            ),
            heading(t.difficulty),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in _difficulties)
                  ChoiceChip(
                    label: Text(localizedDifficulty(t, d.name)),
                    selected: _difficulty.name == d.name,
                    onSelected: (_) => setState(() => _difficulty = d),
                  ),
              ],
            ),
          ],
          if (_mode == BughouseMode.lan) ...[
            heading(t.yourName),
            TextField(
              controller: _nameCtl,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.wifi_tethering),
              label: Text(t.bugHostMatch),
              onPressed: _hostLan,
            ),
            const SizedBox(height: 8),
            Text(t.bugJoinMatch,
                style: Theme.of(context).textTheme.titleSmall),
            if (_hosts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Row(children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
              ),
            for (final h in _hosts)
              ListTile(
                leading: const Icon(Icons.casino),
                title: Text(h.name.replaceFirst(_bhPrefix, '')),
                subtitle: Text(h.addr),
                onTap: () => _joinLan(h),
              ),
          ] else ...[
            heading(t.timeControl),
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
            const SizedBox(height: 28),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text(t.bugStart),
              onPressed: _start,
            ),
          ],
        ],
      ),
    );
  }
}
