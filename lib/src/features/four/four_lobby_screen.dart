import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/features/four/four_player_screen.dart';
import 'package:chess/src/rust/api/four.dart';
import 'package:chess/src/rust/api/net.dart';
import 'package:chess/src/state/four_lan_controller.dart';
import 'package:chess/src/state/four_player_controller.dart';

/// Pre-match lobby for networked 4-player: the host assigns the four seats and
/// starts; joiners wait. On start, both push into [FourPlayerScreen] (LAN).
class FourLobbyScreen extends ConsumerStatefulWidget {
  const FourLobbyScreen({super.key});

  @override
  ConsumerState<FourLobbyScreen> createState() => _FourLobbyScreenState();
}

class _FourLobbyScreenState extends ConsumerState<FourLobbyScreen> {
  final List<int> _owner = [-1, -1, -1, -1]; // seatOwner: connection idx or -1 (host)
  bool _navigated = false;

  void _goToMatch(FourLanState s) {
    if (_navigated) return;
    _navigated = true;
    final mySeats = s.mySeats.map((i) => FourPlayer.values[i]).toSet();
    final config = FourConfig(
      mode: FourMode.lan,
      format: s.format == 'teams' ? FourFormat.teams : FourFormat.freeForAll,
      humanSeats: mySeats,
      lanSend: (seat, uci) => netSendFourMove(seat: seat, uci: uci),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => FourPlayerScreen(config: config)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = ref.watch(fourLanProvider);
    if (s.started) _goToMatch(s);

    final seatLabels = [t.fourRed, t.fourBlue, t.fourYellow, t.fourGreen];

    return Scaffold(
      appBar: AppBar(title: Text(t.menuFourPlayer)),
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
                  onChanged: (v) => setState(() => _owner[seat] = v ?? -1),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text(t.bugStart),
              onPressed: () =>
                  ref.read(fourLanProvider.notifier).startAssign(_owner),
            ),
          ],
        ],
      ),
    );
  }
}
