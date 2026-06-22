import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/features/bughouse/bughouse_screen.dart';
import 'package:chess/src/rust/api/net.dart';
import 'package:chess/src/state/bughouse_controller.dart';
import 'package:chess/src/state/bughouse_lan_controller.dart';
import 'package:chess/src/state/time_control.dart';

/// Pre-match lobby for networked Bughouse: the host assigns the four seats and
/// starts; a joiner waits. On start, both push into [BughouseScreen] (LAN mode).
class BughouseLobbyScreen extends ConsumerStatefulWidget {
  const BughouseLobbyScreen({super.key});

  @override
  ConsumerState<BughouseLobbyScreen> createState() =>
      _BughouseLobbyScreenState();
}

class _BughouseLobbyScreenState extends ConsumerState<BughouseLobbyScreen> {
  // seatOwner[seat] = connection index (0-based joiner), or -1 for the host.
  final List<int> _owner = [-1, -1, -1, -1];
  bool _navigated = false;

  void _goToMatch(BughouseLanState s) {
    if (_navigated) return;
    _navigated = true;
    final mySeats = s.mySeats.map((i) => BugSeat.values[i]).toSet();
    final config = BugConfig(
      mode: BughouseMode.lan,
      tc: TimeControlOption.infinite,
      humanSeats: mySeats,
      lanSend: (board, uci, w, b) =>
          netSendBugMove(board: board, uci: uci, whiteMs: w, blackMs: b),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => BughouseScreen(config: config)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = ref.watch(bughouseLanProvider);
    if (s.started) _goToMatch(s);

    final seatLabels = [
      '${t.bugBoardA} · ${t.bugWhite}',
      '${t.bugBoardA} · ${t.bugBlack}',
      '${t.bugBoardB} · ${t.bugWhite}',
      '${t.bugBoardB} · ${t.bugBlack}',
    ];

    return Scaffold(
      appBar: AppBar(title: Text(t.menuBughouse)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (s.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(s.error!, style: const TextStyle(color: Colors.red)),
            ),
          if (!s.isHost) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Center(child: Text(t.bugWaitingHost)),
          ] else ...[
            Text('${t.bugPlayersJoined}: ${s.joiners.length}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(t.bugAssignSeats,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            for (var seat = 0; seat < 4; seat++)
              ListTile(
                dense: true,
                title: Text(seatLabels[seat]),
                trailing: DropdownButton<int>(
                  value: _owner[seat],
                  items: [
                    DropdownMenuItem(value: -1, child: Text(t.bugSeatHost)),
                    for (var i = 0; i < s.joiners.length; i++)
                      DropdownMenuItem(value: i, child: Text(s.joiners[i])),
                  ],
                  onChanged: (v) =>
                      setState(() => _owner[seat] = v ?? -1),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text(t.bugStart),
              onPressed: () =>
                  ref.read(bughouseLanProvider.notifier).startAssign(_owner),
            ),
          ],
        ],
      ),
    );
  }
}
