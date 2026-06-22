import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/features/four/four_lobby_screen.dart';
import 'package:chess/src/features/four/four_player_screen.dart';
import 'package:chess/src/rust/api/four.dart';
import 'package:chess/src/rust/api/net.dart';
import 'package:chess/src/state/four_lan_controller.dart';
import 'package:chess/src/state/four_player_controller.dart';

const _fourPrefix = '[4P] ';

class FourSetupScreen extends ConsumerStatefulWidget {
  const FourSetupScreen({super.key});

  @override
  ConsumerState<FourSetupScreen> createState() => _FourSetupScreenState();
}

class _FourSetupScreenState extends ConsumerState<FourSetupScreen> {
  FourFormat _format = FourFormat.freeForAll;
  FourMode _mode = FourMode.hotSeat;
  final Set<FourPlayer> _humans = {FourPlayer.red};
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
      if (!h.name.startsWith(_fourPrefix)) return;
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

  String get _formatCode => _format == FourFormat.teams ? 'teams' : 'ffa';

  void _startLocal() {
    final config = FourConfig(
      mode: _mode,
      format: _format,
      humanSeats: _mode == FourMode.hotSeat
          ? FourPlayer.values.toSet()
          : (_humans.isEmpty ? {FourPlayer.red} : _humans),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FourPlayerScreen(config: config)),
    );
  }

  void _hostLan() {
    ref.read(fourLanProvider.notifier).host(_nameCtl.text.trim(), _formatCode);
    _stopBrowse();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FourLobbyScreen()),
    );
  }

  void _joinLan(NetHost h) {
    ref.read(fourLanProvider.notifier).join(h.addr, _nameCtl.text.trim());
    _stopBrowse();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FourLobbyScreen()),
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
      appBar: AppBar(title: Text(t.menuFourPlayer)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          heading(t.fourFormat),
          SegmentedButton<FourFormat>(
            segments: [
              ButtonSegment(
                  value: FourFormat.freeForAll, label: Text(t.fourFFA)),
              ButtonSegment(value: FourFormat.teams, label: Text(t.fourTeams)),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
          heading(t.bugMode),
          SegmentedButton<FourMode>(
            segments: [
              ButtonSegment(value: FourMode.hotSeat, label: Text(t.bugHotSeat)),
              ButtonSegment(value: FourMode.vsBots, label: Text(t.fourVsBots)),
              ButtonSegment(value: FourMode.lan, label: Text(t.bugLan)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) {
              setState(() => _mode = s.first);
              if (_mode == FourMode.lan) {
                _startBrowse();
              } else {
                _stopBrowse();
              }
            },
          ),
          if (_mode == FourMode.vsBots) ...[
            heading(t.fourYourSeats),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in FourPlayer.values)
                  FilterChip(
                    label: Text(localizedFourColor(t, p)),
                    selected: _humans.contains(p),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _humans.add(p);
                      } else {
                        _humans.remove(p);
                      }
                    }),
                  ),
              ],
            ),
          ],
          if (_mode == FourMode.lan) ...[
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
            Text(t.bugJoinMatch, style: Theme.of(context).textTheme.titleSmall),
            if (_hosts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            for (final h in _hosts)
              ListTile(
                leading: const Icon(Icons.grid_4x4),
                title: Text(h.name.replaceFirst(_fourPrefix, '')),
                subtitle: Text(h.addr),
                onTap: () => _joinLan(h),
              ),
          ] else ...[
            const SizedBox(height: 28),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text(t.bugStart),
              onPressed: _startLocal,
            ),
          ],
        ],
      ),
    );
  }
}
